//! Compile-time folding of scalar `const` values (m6809).
//!
//! A scalar const has no RAM slot on m6809: every use is emitted as an
//! immediate (`LDD #value`). So its value must be known at compile time —
//! a literal, another const, or arithmetic / bit operations on those
//! (`const B = A * 2`, `const MASK = ~B & 0xFF`). Consts may refer to consts
//! declared later. A const that cannot be folded is a compile error with its
//! line: it used to get an uninitialised RAM slot and read garbage.

use std::collections::HashMap;
use vpy_parser::{BinOp, CmpOp, Expr, Item, LogicOp, Module};

/// Why an expression did not fold (yet).
enum NotFolded {
    /// Refers to a const that is not folded yet (may fold on a later pass).
    Pending(String),
    /// Can never fold: the message explains why.
    Never(String),
}

/// Fold every scalar const of `module` (array consts are not scalars and are skipped).
///
/// Returns (name as declared, value). `Err` lists every const that cannot be folded.
pub fn fold_consts(module: &Module) -> Result<Vec<(String, i64)>, String> {
    let scalars: Vec<(&String, &Expr, usize)> = module
        .items
        .iter()
        .filter_map(|item| match item {
            Item::Const { value: Expr::List(_), .. } => None,
            Item::Const { name, value, source_line, .. } => Some((name, value, *source_line)),
            _ => None,
        })
        .collect();
    let const_names: HashMap<String, ()> = scalars.iter().map(|(n, _, _)| (n.to_lowercase(), ())).collect();

    // Fixed point: each pass folds the consts whose operands are folded already.
    let mut values: HashMap<String, i64> = HashMap::new();
    loop {
        let mut progress = false;
        for (name, value, _) in &scalars {
            let key = name.to_lowercase();
            if values.contains_key(&key) {
                continue;
            }
            if let Ok(v) = eval(value, &values, &const_names) {
                values.insert(key, v);
                progress = true;
            }
        }
        if !progress {
            break;
        }
    }

    let mut errors = Vec::new();
    let mut out = Vec::new();
    for (name, value, line) in &scalars {
        match values.get(&name.to_lowercase()) {
            Some(v) if (-32768..=65535).contains(v) => out.push(((*name).clone(), *v)),
            Some(v) => errors.push(format!(
                "line {line}: const `{name}` = {v} does not fit in 16 bits (-32768..65535)"
            )),
            None => {
                let why = match eval(value, &values, &const_names) {
                    Err(NotFolded::Never(msg)) => msg,
                    Err(NotFolded::Pending(other)) => format!(
                        "it depends on `{other}`, which is part of a cycle of consts or cannot be computed itself"
                    ),
                    Ok(_) => unreachable!("folded on the last pass"),
                };
                errors.push(format!(
                    "line {line}: const `{name}` cannot be computed at compile time: {why}. A const must be a number, \
                     another const, or arithmetic (+ - * / // %) and bit operations (& | ~) on those."
                ));
            }
        }
    }
    if errors.is_empty() { Ok(out) } else { Err(errors.join("\n")) }
}

/// Value of `e` if it is a compile-time constant expression over literals and the
/// consts already registered in the codegen context (16-bit range), else None.
pub fn fold_expr(e: &Expr) -> Option<i64> {
    fn walk(e: &Expr, values: &mut HashMap<String, i64>) -> bool {
        match e {
            Expr::Ident(id) => match super::context::get_const_value(&id.name) {
                Some(v) => {
                    values.insert(id.name.to_lowercase(), v);
                    true
                }
                None => false,
            },
            Expr::Number(_) => true,
            Expr::Binary { left, right, .. } | Expr::Compare { left, right, .. } | Expr::Logic { left, right, .. } => {
                walk(left, values) && walk(right, values)
            }
            Expr::BitNot(x) | Expr::Not(x) => walk(x, values),
            _ => false,
        }
    }
    let mut values = HashMap::new();
    if !walk(e, &mut values) {
        return None;
    }
    eval(e, &values, &HashMap::new()).ok().filter(|v| (-32768..=65535).contains(v))
}

fn eval(e: &Expr, values: &HashMap<String, i64>, consts: &HashMap<String, ()>) -> Result<i64, NotFolded> {
    let rec = |x: &Expr| eval(x, values, consts);
    match e {
        Expr::Number(n) => Ok(*n as i64),
        Expr::Ident(id) => {
            let key = id.name.to_lowercase();
            if let Some(v) = values.get(&key) {
                Ok(*v)
            } else if consts.contains_key(&key) {
                Err(NotFolded::Pending(id.name.clone()))
            } else {
                Err(NotFolded::Never(format!("`{}` is not a const", id.name)))
            }
        }
        Expr::Binary { op, left, right } => {
            let (l, r) = (rec(left)?, rec(right)?);
            let overflow = || NotFolded::Never("the arithmetic overflows".to_string());
            match op {
                BinOp::Add => l.checked_add(r).ok_or_else(overflow),
                BinOp::Sub => l.checked_sub(r).ok_or_else(overflow),
                BinOp::Mul => l.checked_mul(r).ok_or_else(overflow),
                // Same rounding as the DIV16/MOD16 runtime: truncate toward zero,
                // remainder has the dividend's sign.
                BinOp::Div | BinOp::FloorDiv | BinOp::Mod if r == 0 => {
                    Err(NotFolded::Never("division by zero".to_string()))
                }
                BinOp::Div | BinOp::FloorDiv => Ok(l / r),
                BinOp::Mod => Ok(l % r),
                BinOp::Shl | BinOp::Shr if !(0..=16).contains(&r) => {
                    Err(NotFolded::Never(format!("shift by {r} (must be 0..16)")))
                }
                BinOp::Shl => l.checked_shl(r as u32).ok_or_else(overflow),
                BinOp::Shr => Ok(l >> r),
                BinOp::BitAnd => Ok(l & r),
                BinOp::BitOr => Ok(l | r),
                BinOp::BitXor => Ok(l ^ r),
            }
        }
        Expr::BitNot(inner) => Ok(!rec(inner)?),
        Expr::Not(inner) => Ok((rec(inner)? == 0) as i64),
        Expr::Compare { op, left, right } => {
            let (l, r) = (rec(left)?, rec(right)?);
            Ok(match op {
                CmpOp::Eq => l == r,
                CmpOp::Ne => l != r,
                CmpOp::Lt => l < r,
                CmpOp::Le => l <= r,
                CmpOp::Gt => l > r,
                CmpOp::Ge => l >= r,
            } as i64)
        }
        Expr::Logic { op, left, right } => {
            let (l, r) = (rec(left)? != 0, rec(right)? != 0);
            Ok(match op {
                LogicOp::And => l && r,
                LogicOp::Or => l || r,
            } as i64)
        }
        Expr::StringLit(_) => Err(NotFolded::Never(
            "string consts are not supported on m6809 (use the string literal, or a const array of strings)".to_string(),
        )),
        Expr::Call(c) => Err(NotFolded::Never(format!("`{}()` is a call, evaluated at run time", c.name))),
        Expr::MethodCall(_) | Expr::Index { .. } | Expr::FieldAccess { .. } | Expr::StructInit { .. } | Expr::List(_) => {
            Err(NotFolded::Never("the value is not a constant expression".to_string()))
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn module(src: &str) -> Module {
        vpy_parser::parser::parse(vpy_parser::lex(src).unwrap(), "t.vpy").unwrap()
    }

    fn folded(src: &str) -> HashMap<String, i64> {
        fold_consts(&module(src)).unwrap().into_iter().collect()
    }

    #[test]
    fn folds_consts_of_consts_in_any_order() {
        let v = folded("const B = A * 2 + 1\nconst A = 10\nconst C = (B - A) // 3\nconst D = -B % 4\n");
        assert_eq!(v["A"], 10);
        assert_eq!(v["B"], 21);
        assert_eq!(v["C"], 3);
        assert_eq!(v["D"], -1, "remainder keeps the dividend's sign (MOD16)");
    }

    #[test]
    fn folds_bit_operations() {
        // (The parser has no `<<`, `>>` or `^` yet; the folder handles them anyway.)
        let v = folded("const F = 8\nconst M = ~F & 0xFF\nconst X = F | 3\nconst N = not F\n");
        assert_eq!(v["M"], 0xF7);
        assert_eq!(v["X"], 11);
        assert_eq!(v["N"], 0);
    }

    #[test]
    fn non_constant_value_is_an_error_with_line() {
        let err = fold_consts(&module("speed = 3\n\nconst B = speed * 2\n")).unwrap_err();
        assert!(err.contains("line 3") && err.contains("`B`") && err.contains("`speed` is not a const"), "{err}");
    }

    #[test]
    fn cycle_and_call_are_errors() {
        let err = fold_consts(&module("const A = B\nconst B = A\nconst C = J1_X()\n")).unwrap_err();
        assert!(err.contains("`A`") && err.contains("cycle"), "{err}");
        assert!(err.contains("`C`") && err.contains("J1_X()"), "{err}");
    }

    #[test]
    fn division_by_zero_and_overflow_are_errors() {
        let err = fold_consts(&module("const Z = 0\nconst A = 4 / Z\nconst B = 300 * 300\n")).unwrap_err();
        assert!(err.contains("division by zero"), "{err}");
        assert!(err.contains("`B` = 90000 does not fit"), "{err}");
    }
}
