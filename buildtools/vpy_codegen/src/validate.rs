//! Program checks shared by every backend, run before code generation.
//!
//! Each check rejects something a backend would otherwise translate into
//! missing or wrong code while the build still "succeeds".

use vpy_parser::{Expr, Item, Module};

/// Global array literals must hold only number literals or only string literals.
///
/// Every backend lays array literals out as data at compile time: a computed
/// element (`[MAX_X, 2 * 3]`) became 0 on m6809 and was DROPPED from the table
/// on the ARM backends (shifting every later index).
pub fn check_array_literals(module: &Module) -> Result<(), String> {
    let mut errors = Vec::new();
    for item in &module.items {
        let (name, value, line) = match item {
            Item::GlobalLet { name, value, source_line, .. } | Item::Const { name, value, source_line, .. } => {
                (name, value, *source_line)
            }
            _ => continue,
        };
        let Expr::List(elements) = value else { continue };
        let all_strings = !elements.is_empty() && elements.iter().all(|e| matches!(e, Expr::StringLit(_)));
        if all_strings {
            continue;
        }
        for (i, e) in elements.iter().enumerate() {
            if !matches!(e, Expr::Number(_)) {
                errors.push(format!(
                    "line {line}: array `{name}` element {i} is not a number literal — array literals are \
                     laid out at compile time and must contain only numbers (e.g. `[1, -2, 3]`) or only strings"
                ));
            }
        }
    }
    if errors.is_empty() { Ok(()) } else { Err(errors.join("\n")) }
}

/// Every `len(...)` must have a length known at compile time, on every target.
///
/// `len(name)` works when `name` is a global array (a mutable or const list
/// literal) that is not shadowed by a parameter of the enclosing function: it
/// compiles to the `ARRAY_<NAME>_LEN` constant. Any other argument is an error
/// with its line — the ARM backends used to fail at link time on a non-array
/// name and silently return 0 for any other expression.
pub fn check_len_calls(module: &Module, target: &str) -> Result<(), String> {
    use vpy_parser::CallInfo;

    let global_arrays: std::collections::HashSet<&str> = module
        .items
        .iter()
        .filter_map(|item| match item {
            Item::GlobalLet { name, value: Expr::List(_), .. } | Item::Const { name, value: Expr::List(_), .. } => {
                Some(name.as_str())
            }
            _ => None,
        })
        .collect();

    let check = |call: &CallInfo, params: &[String], scope: &str| -> Result<(), String> {
        if !call.name.eq_ignore_ascii_case("LEN") {
            return Ok(());
        }
        let line = call.source_line;
        if call.args.len() != 1 {
            return Err(format!(
                "len() takes exactly 1 argument, got {} (line {line}, in {scope})",
                call.args.len()
            ));
        }
        match &call.args[0] {
            Expr::Ident(id) if params.iter().any(|p| p.eq_ignore_ascii_case(&id.name)) => Err(format!(
                "len({}) is not supported on {target}: '{}' is a parameter of {scope}, so its length \
                 is not known at compile time (line {line}). Pass the length as an extra argument.",
                id.name, id.name
            )),
            Expr::Ident(id) if global_arrays.contains(id.name.as_str()) => Ok(()),
            Expr::Ident(id) => Err(format!(
                "len({}) is not supported on {target}: '{}' is not a global array (line {line}, in {scope}). \
                 len() works on global list literals, e.g. `xs = [1, 2, 3]` or `const XS = [1, 2, 3]`.",
                id.name, id.name
            )),
            _ => Err(format!(
                "len() on {target} needs the name of a global array (line {line}, in {scope}); \
                 its length must be known at compile time."
            )),
        }
    };

    let mut errors = Vec::new();
    for item in &module.items {
        let (params, scope): (&[String], String) = match item {
            Item::Function(func) => (&func.params, format!("function '{}'", func.name)),
            _ => (&[], "a global initializer".to_string()),
        };
        let mut on_expr = |e: &Expr| {
            if let Expr::Call(call) = e {
                if let Err(msg) = check(call, params, &scope) {
                    errors.push(msg);
                }
            }
        };
        // The exhaustive walker reaches every nested body and sub-expression.
        use crate::m6809::ast_walk;
        match item {
            Item::Function(func) => ast_walk::for_each_expr_in_stmts(&func.body, &mut on_expr),
            Item::GlobalLet { value, .. } | Item::Const { value, .. } => {
                ast_walk::walk_expr(value, &mut ast_walk::ExprFn(&mut on_expr))
            }
            Item::VectorList { .. } | Item::ExprStatement(_) | Item::Export(_) | Item::StructDef(_) => {}
        }
    }
    if errors.is_empty() { Ok(()) } else { Err(errors.join("\n")) }
}

/// Every `DRAW_VECTOR_ROT(...)` names a `.vec` of the project and has 4 to 6
/// arguments: `("name", x, y, angle [, mirror [, intensity]])`.
///
/// Checked before code generation on every target, so a misspelled sprite is an
/// error with its line instead of an undefined symbol at assembly or link time.
pub fn check_draw_vector_rot_calls(
    module: &Module,
    assets: &[crate::AssetInfo],
    target: &str,
) -> Result<(), String> {
    let mut errors = Vec::new();
    crate::m6809::ast_walk::for_each_call(module, |call| {
        if !call.name.eq_ignore_ascii_case("DRAW_VECTOR_ROT") {
            return;
        }
        let line = call.source_line;
        let n = call.args.len();
        if !(4..=6).contains(&n) {
            errors.push(format!(
                "line {line}: DRAW_VECTOR_ROT takes 4 to 6 arguments (\"name\", x, y, angle [, mirror \
                 [, intensity]]), got {n}"
            ));
            return;
        }
        match &call.args[0] {
            Expr::StringLit(name) => {
                let known = assets
                    .iter()
                    .any(|a| a.name == *name && matches!(a.asset_type, crate::AssetType::Vector));
                if !known {
                    let mut vecs: Vec<&str> = assets
                        .iter()
                        .filter(|a| matches!(a.asset_type, crate::AssetType::Vector))
                        .map(|a| a.name.as_str())
                        .collect();
                    vecs.sort_unstable();
                    errors.push(format!(
                        "line {line}: DRAW_VECTOR_ROT(\"{name}\"): no vector asset named '{name}' on {target} \
                         (a .vec in assets/vectors/; available: {})",
                        if vecs.is_empty() { "none".to_string() } else { vecs.join(", ") }
                    ));
                }
            }
            _ => errors.push(format!(
                "line {line}: DRAW_VECTOR_ROT needs the asset name as a string literal, e.g. \
                 DRAW_VECTOR_ROT(\"ship\", x, y, angle)"
            )),
        }
    });
    if errors.is_empty() { Ok(()) } else { Err(errors.join("\n")) }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn module(src: &str) -> Module {
        vpy_parser::parser::parse(vpy_parser::lex(src).unwrap(), "t.vpy").unwrap()
    }

    #[test]
    fn literal_arrays_pass() {
        assert!(check_array_literals(&module("xs = [1, -2, 3]\nconst NAMES = [\"A\", \"B\"]\n")).is_ok());
    }

    #[test]
    fn len_of_global_arrays_passes_on_every_target() {
        let m = module("xs = [1, 2]\nconst YS = [3]\ndef f():\n    return len(xs) + len(YS)\n");
        for t in ["m6809", "rp2350", "uvm2", "pitrex"] {
            assert!(check_len_calls(&m, t).is_ok(), "{t}");
        }
    }

    #[test]
    fn len_of_anything_else_is_an_error_with_line() {
        let m = module("n = 3\ndef f(a):\n    x = len(n)\n    y = len(a)\n    return len(\"abc\")\n");
        let err = check_len_calls(&m, "rp2350").unwrap_err();
        assert!(err.contains("len(n) is not supported on rp2350") && err.contains("line 3"), "{err}");
        assert!(err.contains("len(a)") && err.contains("parameter") && err.contains("line 4"), "{err}");
        assert!(err.contains("len() on rp2350 needs the name of a global array (line 5"), "{err}");
    }

    #[test]
    fn computed_element_is_an_error() {
        let err = check_array_literals(&module("const W = 4\nxs = [1, W, 3]\n")).unwrap_err();
        assert!(err.contains("array `xs` element 1"), "{err}");
    }
}
