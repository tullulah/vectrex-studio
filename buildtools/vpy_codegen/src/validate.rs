//! Program checks shared by every backend, run before code generation.
//!
//! Each check rejects something a backend would otherwise translate into
//! missing or wrong code while the build still "succeeds".

use vpy_parser::{Expr, Item, Module};

/// The name of a function, global or const (for the file its errors point at).
fn item_name(item: &Item) -> &str {
    match item {
        Item::Function(f) => &f.name,
        Item::GlobalLet { name, .. } | Item::Const { name, .. } => name,
        _ => "",
    }
}

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
                errors.push(crate::origins::locate_for(name, &format!(
                    "line {line}: array `{name}` element {i} is not a number literal — array literals are \
                     laid out at compile time and must contain only numbers (e.g. `[1, -2, 3]`) or only strings"
                )));
            }
        }
    }
    if errors.is_empty() { Ok(()) } else { Err(errors.join("\n")) }
}

/// Bits of an element of the declared type: u8/i8 = 8, untyped/u16/i16 = 16, u32/i32 = 32.
fn element_bits(type_annotation: &Option<String>) -> u32 {
    match type_annotation.as_deref() {
        Some("u8") | Some("i8") => 8,
        Some("u32") | Some("i32") => 32,
        _ => 16,
    }
}

/// Does `v` fit an element of `bits` bits? Signed or unsigned reading of the same
/// bits (`-1` and `255` are the same byte), as the data directives store them.
fn fits(v: i64, bits: u32) -> bool {
    bits >= 32 || (-(1i64 << (bits - 1))..(1i64 << bits)).contains(&v)
}

/// Value of a constant expression over literals and the module's numeric consts.
fn const_value(e: &Expr, consts: &std::collections::HashMap<String, i64>) -> Option<i64> {
    use vpy_parser::BinOp;
    match e {
        Expr::Number(n) => Some(*n as i64),
        Expr::Ident(id) => consts.get(&id.name.to_uppercase()).copied(),
        Expr::BitNot(x) => const_value(x, consts).map(|v| !v),
        Expr::Binary { op, left, right } => {
            let (l, r) = (const_value(left, consts)?, const_value(right, consts)?);
            match op {
                BinOp::Add => l.checked_add(r),
                BinOp::Sub => l.checked_sub(r),
                BinOp::Mul => l.checked_mul(r),
                BinOp::Div | BinOp::FloorDiv => l.checked_div(r),
                BinOp::Mod => l.checked_rem(r),
                BinOp::Shl => u32::try_from(r).ok().filter(|&r| r < 32).map(|r| l << r),
                BinOp::Shr => u32::try_from(r).ok().filter(|&r| r < 32).map(|r| l >> r),
                BinOp::BitAnd => Some(l & r),
                BinOp::BitOr => Some(l | r),
                BinOp::BitXor => Some(l ^ r),
            }
        }
        _ => None,
    }
}

/// Integer types against the target, and array values against their element type.
///
/// - `u32`/`i32` exist on the ARM targets only; on m6809 they are an error.
/// - Every element of an array literal, and every constant stored into a global
///   array (`xs[i] = 100000`), must fit the element: 8 bits for u8/i8, 16 for
///   untyped/u16/i16, 32 for u32/i32. A value that did not fit was truncated in
///   silence (an untyped array keeps 16 bits on every target).
pub fn check_array_types(module: &Module, target: &str) -> Result<(), String> {
    use std::collections::HashMap;
    use vpy_parser::{AssignTarget, Stmt};

    let mut errors = Vec::new();
    let mut consts: HashMap<String, i64> = HashMap::new();
    let mut arrays: HashMap<String, &Option<String>> = HashMap::new();
    for item in &module.items {
        let (name, type_annotation, value, line, is_const) = match item {
            Item::GlobalLet { name, type_annotation, value, source_line } => (name, type_annotation, value, *source_line, false),
            Item::Const { name, type_annotation, value, source_line } => (name, type_annotation, value, *source_line, true),
            _ => continue,
        };
        let ty = type_annotation.as_deref().unwrap_or("i16");
        if target == "m6809" && matches!(ty, "u32" | "i32") {
            errors.push(crate::origins::locate_for(name, &format!(
                "line {line}: `{name}: {ty}` — 32-bit integers exist on the ARM targets (rp2350, uvm2, pitrex) \
                 only; m6809 integers are 8 or 16 bits"
            )));
            continue;
        }
        match value {
            Expr::Number(n) if is_const => {
                consts.insert(name.to_uppercase(), *n as i64);
            }
            Expr::List(elements) => {
                arrays.insert(name.to_uppercase(), type_annotation);
                let bits = element_bits(type_annotation);
                for (i, e) in elements.iter().enumerate() {
                    if let Expr::Number(n) = e {
                        if !fits(*n as i64, bits) {
                            errors.push(crate::origins::locate_for(name, &format!(
                                "line {line}: array `{name}` element {i} = {n} does not fit its {ty} elements \
                                 ({bits} bits){}",
                                if bits < 32 { "; declare the array `i32` (ARM targets) or use smaller values" } else { "" }
                            )));
                        }
                    }
                }
            }
            _ => {}
        }
    }

    // Constants stored into a global array that is not shadowed by a parameter.
    for item in &module.items {
        let Item::Function(func) = item else { continue };
        struct Stores<'a>(Vec<(&'a Expr, &'a Expr, usize)>);
        impl<'a> crate::m6809::ast_walk::Visitor<'a> for Stores<'a> {
            fn stmt(&mut self, stmt: &'a Stmt) {
                if let Stmt::Assign { target: AssignTarget::Index { target, .. }, value, source_line } = stmt {
                    self.0.push((target.as_ref(), value, *source_line));
                }
            }
        }
        let mut stores = Stores(Vec::new());
        crate::m6809::ast_walk::walk_stmts(&func.body, &mut stores);
        for (target, value, source_line) in stores.0 {
            let Expr::Ident(id) = target else { continue };
            if func.params.iter().any(|p| p.eq_ignore_ascii_case(&id.name)) {
                continue;
            }
            let Some(type_annotation) = arrays.get(&id.name.to_uppercase()) else { continue };
            let Some(v) = const_value(value, &consts) else { continue };
            let bits = element_bits(type_annotation);
            if !fits(v, bits) {
                let ty = type_annotation.as_deref().unwrap_or("i16");
                errors.push(crate::origins::locate_for(&func.name, &format!(
                    "line {source_line}: {v} stored into `{}` does not fit its {ty} elements ({bits} bits){}",
                    id.name,
                    if bits < 32 { "; declare the array `i32` (ARM targets) or use smaller values" } else { "" }
                )));
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
                "line {line}: len() takes exactly 1 argument, got {} (in {scope})",
                call.args.len()
            ));
        }
        match &call.args[0] {
            Expr::Ident(id) if params.iter().any(|p| p.eq_ignore_ascii_case(&id.name)) => Err(format!(
                "line {line}: len({}) is not supported on {target}: '{}' is a parameter of {scope}, so its \
                 length is not known at compile time. Pass the length as an extra argument.",
                id.name, id.name
            )),
            Expr::Ident(id) if global_arrays.contains(id.name.as_str()) => Ok(()),
            Expr::Ident(id) => Err(format!(
                "line {line}: len({}) is not supported on {target}: '{}' is not a global array (in {scope}). \
                 len() works on global list literals, e.g. `xs = [1, 2, 3]` or `const XS = [1, 2, 3]`.",
                id.name, id.name
            )),
            _ => Err(format!(
                "line {line}: len() on {target} needs the name of a global array (in {scope}); \
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
                    errors.push(crate::origins::locate_for(item_name(item), &msg));
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
    crate::m6809::ast_walk::for_each_call_in_items(module, |item, call| {
        let start = errors.len();
        #[allow(clippy::redundant_closure_call)]
        (|| {
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
    })();
        crate::origins::locate_new(&mut errors, start, item);
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
        assert!(err.contains("line 5: len() on rp2350 needs the name of a global array"), "{err}");
    }

    #[test]
    fn typed_arrays_in_range_pass() {
        let m = module("a: u8 = [0, 255]\nb: i8 = [-128, 127]\nc = [-32768, 65535]\nd: i32 = [100000, -100000]\n");
        assert!(check_array_types(&m, "uvm2").is_ok());
    }

    #[test]
    fn element_out_of_range_is_an_error() {
        let m = module("xs = [1, 100000]\nys: u8 = [256]\n");
        let err = check_array_types(&m, "uvm2").unwrap_err();
        assert!(err.contains("line 1: array `xs` element 1 = 100000 does not fit its i16 elements (16 bits)"), "{err}");
        assert!(err.contains("array `ys` element 0 = 256 does not fit its u8 elements (8 bits)"), "{err}");
    }

    #[test]
    fn constant_store_out_of_range_is_an_error() {
        let src = "const BIG = 50000\nxs = [0, 0]\nws: i32 = [0]\ndef f(xs2):\n    xs[0] = BIG * 2\n    xs[1] = 1 << 15\n    ws[0] = BIG * 2\n    xs2[0] = 100000\n";
        let err = check_array_types(&module(src), "rp2350").unwrap_err();
        assert!(err.contains("line 5: 100000 stored into `xs` does not fit its i16 elements"), "{err}");
        assert!(!err.contains("line 6") && !err.contains("`ws`") && !err.contains("xs2"), "{err}");
    }

    #[test]
    fn thirty_two_bit_types_are_arm_only() {
        let m = module("n: i32 = 5\nws: u32 = [1]\n");
        assert!(check_array_types(&m, "pitrex").is_ok());
        let err = check_array_types(&m, "m6809").unwrap_err();
        assert!(err.contains("line 1: `n: i32`") && err.contains("line 2: `ws: u32`"), "{err}");
    }

    #[test]
    fn computed_element_is_an_error() {
        let err = check_array_literals(&module("const W = 4\nxs = [1, W, 3]\n")).unwrap_err();
        assert!(err.contains("array `xs` element 1"), "{err}");
    }
}
