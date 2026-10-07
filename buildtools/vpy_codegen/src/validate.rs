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
    fn computed_element_is_an_error() {
        let err = check_array_literals(&module("const W = 4\nxs = [1, W, 3]\n")).unwrap_err();
        assert!(err.contains("array `xs` element 1"), "{err}");
    }
}
