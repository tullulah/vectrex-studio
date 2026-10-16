//! Array literals with repetition and arrays of more than one dimension,
//! lowered to the flat arrays every backend compiles.
//!
//! ```python
//! xf: i32 = [0] * 12                 # twelve zeros
//! grid = [[0] * 8] * 4               # 4 rows of 8
//! gaps: i16 = [[1, 2, 3], [4, 5, 6]] # 2 x 3
//!
//! grid[r][c] = 1                     # grid[r * 8 + c] = 1
//! n = len(grid)                      # 4 (the first dimension)
//! ```
//!
//! A global or const array literal may repeat a list (`[a, b] * n`) and nest
//! lists; nested lists must be rectangular. An array of N dimensions is stored
//! flat, row after row, and `a[i][j]...` with one index per dimension becomes
//! one index into it. Indexing it with fewer indices (a row as a value), and
//! `for v in` over it, are compile errors. A function parameter is a flat
//! address: index it once.

use crate::error::Diagnostic;
use std::collections::HashMap;
use vpy_parser::{AssignTarget, BinOp, CallInfo, Expr, Item, Module, Stmt};

/// A literal's value: a number or a list of values.
enum Lit {
    Num(Expr),
    List(Vec<Lit>),
}

/// Evaluate a literal with `[..] * n` / `n * [..]` repetition.
fn literal(e: &Expr) -> Result<Lit, String> {
    match e {
        Expr::List(v) => Ok(Lit::List(v.iter().map(literal).collect::<Result<_, _>>()?)),
        Expr::Binary { op: BinOp::Mul, left, right } => {
            let (list, n) = match (left.as_ref(), right.as_ref()) {
                (l @ Expr::List(_), Expr::Number(n)) | (Expr::Number(n), l @ Expr::List(_)) => (l, *n),
                (l @ Expr::Binary { .. }, Expr::Number(n)) if is_list_expr(l) => (l, *n),
                _ => return Ok(Lit::Num(e.clone())),
            };
            if n < 0 {
                return Err(format!("a list repeated {n} times"));
            }
            let Lit::List(items) = literal(list)? else { unreachable!() };
            let mut out = Vec::new();
            for _ in 0..n {
                out.extend(items.iter().map(clone_lit));
            }
            Ok(Lit::List(out))
        }
        other => Ok(Lit::Num(other.clone())),
    }
}

fn is_list_expr(e: &Expr) -> bool {
    match e {
        Expr::List(_) => true,
        Expr::Binary { op: BinOp::Mul, left, right } => is_list_expr(left) || is_list_expr(right),
        _ => false,
    }
}

fn clone_lit(l: &Lit) -> Lit {
    match l {
        Lit::Num(e) => Lit::Num(e.clone()),
        Lit::List(v) => Lit::List(v.iter().map(clone_lit).collect()),
    }
}

/// The dimensions of a rectangular literal and its elements, flat.
fn shape(l: Lit) -> Result<(Vec<usize>, Vec<Expr>), String> {
    match l {
        Lit::Num(e) => Ok((vec![], vec![e])),
        Lit::List(items) => {
            let mut dims: Option<Vec<usize>> = None;
            let mut flat = Vec::new();
            let n = items.len();
            for item in items {
                let (d, mut f) = shape(item)?;
                match &dims {
                    None => dims = Some(d),
                    Some(prev) if *prev != d => {
                        return Err("nested lists of different lengths: an array must be rectangular".into())
                    }
                    _ => {}
                }
                flat.append(&mut f);
            }
            let mut out = vec![n];
            out.extend(dims.unwrap_or_default());
            Ok((out, flat))
        }
    }
}

/// Lower repetition and N-dimensional arrays in `module`.
/// The value of a constant expression: number literals, the module's scalar consts (by
/// their unified name, consts of consts too) and arithmetic over them.
fn fold(e: &Expr, consts: &HashMap<String, Expr>, depth: usize) -> Option<i32> {
    if depth > 32 {
        return None; // a const defined through itself
    }
    match e {
        Expr::Number(n) => Some(*n),
        Expr::Ident(id) => fold(consts.get(&id.name.to_uppercase())?, consts, depth + 1),
        Expr::BitNot(x) => fold(x, consts, depth + 1).map(|v| !v),
        Expr::Binary { op, left, right } => {
            let (l, r) = (fold(left, consts, depth + 1)?, fold(right, consts, depth + 1)?);
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

pub fn lower(module: Module, module_name: &str) -> Result<Module, Vec<Diagnostic>> {
    let mut diags = Vec::new();
    let mut dims: HashMap<String, Vec<usize>> = HashMap::new();
    let mut items = Vec::new();
    // Named constants in an array literal (`[SX_TIE_FLYBY, MAX * 2]`, enum members) are
    // laid out as their values, as C does: every backend needs number literals there.
    let consts: HashMap<String, Expr> = module
        .items
        .iter()
        .filter_map(|i| match i {
            Item::Const { name, value, .. } if !matches!(value, Expr::List(_)) => Some((name.to_uppercase(), value.clone())),
            _ => None,
        })
        .collect();
    for item in module.items {
        match item {
            Item::GlobalLet { ref value, .. } | Item::Const { ref value, .. } if is_list_expr(value) => {
                let (name, line) = match &item {
                    Item::GlobalLet { name, source_line, .. } | Item::Const { name, source_line, .. } => (name.clone(), *source_line),
                    _ => unreachable!(),
                };
                let lowered = literal(value).and_then(shape);
                let (d, flat) = match lowered {
                    Ok(x) => x,
                    Err(msg) => {
                        diags.push(Diagnostic { module: module_name.into(), line, message: format!("array `{name}`: {msg}") });
                        items.push(item);
                        continue;
                    }
                };
                if d.len() > 1 {
                    dims.insert(name.to_uppercase(), d);
                }
                let flat = flat
                    .into_iter()
                    .map(|e| match e {
                        Expr::Number(_) | Expr::StringLit(_) => e,
                        _ => fold(&e, &consts, 0).map(Expr::Number).unwrap_or(e),
                    })
                    .collect();
                let value = Expr::List(flat);
                items.push(match item {
                    Item::GlobalLet { name, type_annotation, source_line, .. } => Item::GlobalLet { name, type_annotation, value, source_line },
                    Item::Const { name, type_annotation, source_line, .. } => Item::Const { name, type_annotation, value, source_line },
                    _ => unreachable!(),
                });
            }
            other => items.push(other),
        }
    }
    if !dims.is_empty() {
        for item in &mut items {
            if let Item::Function(f) = item {
                let mut rw = Rewriter { dims: &dims, params: f.params.clone(), diags: Vec::new(), module: module_name };
                f.body = f.body.iter().map(|s| rw.stmt(s)).collect();
                diags.append(&mut rw.diags);
            }
        }
    }
    if diags.is_empty() {
        Ok(Module { items, meta: module.meta, imports: module.imports })
    } else {
        Err(diags)
    }
}

struct Rewriter<'a> {
    dims: &'a HashMap<String, Vec<usize>>,
    params: Vec<String>,
    diags: Vec<Diagnostic>,
    module: &'a str,
}

impl Rewriter<'_> {
    fn dims_of(&self, name: &str) -> Option<Vec<usize>> {
        if self.params.iter().any(|p| p.eq_ignore_ascii_case(name)) {
            return None;
        }
        self.dims.get(&name.to_uppercase()).cloned()
    }

    fn error(&mut self, line: usize, message: String) {
        self.diags.push(Diagnostic { module: self.module.into(), line, message });
    }

    /// `g[i][j]..` with one index per dimension, as (name, flat index).
    fn flatten(&mut self, e: &Expr, line: usize) -> Option<Expr> {
        // Collect the chain of indices, outermost last.
        let mut indices = Vec::new();
        let mut cur = e;
        while let Expr::Index { target, index } = cur {
            indices.push(index.as_ref());
            cur = target;
        }
        let Expr::Ident(id) = cur else { return None };
        let dims = self.dims_of(&id.name)?;
        indices.reverse();
        if indices.len() != dims.len() {
            let shape: Vec<String> = dims.iter().map(|d| d.to_string()).collect();
            self.error(line, format!(
                "`{}` is a {}-dimensional array ({}): index it {} times, e.g. `{}{}`",
                id.name,
                dims.len(),
                shape.join(" x "),
                dims.len(),
                id.name,
                "[i]".repeat(dims.len())
            ));
            return Some(Expr::Number(0));
        }
        // ((i0 * d1 + i1) * d2 + i2) ...
        let mut flat = self.expr(indices[0], line);
        for (k, idx) in indices.iter().enumerate().skip(1) {
            let scaled = Expr::Binary { op: BinOp::Mul, left: Box::new(flat), right: Box::new(Expr::Number(dims[k] as i32)) };
            flat = Expr::Binary { op: BinOp::Add, left: Box::new(scaled), right: Box::new(self.expr(idx, line)) };
        }
        Some(Expr::Index { target: Box::new(Expr::Ident(id.clone())), index: Box::new(flat) })
    }

    fn expr(&mut self, e: &Expr, line: usize) -> Expr {
        match e {
            Expr::Index { .. } => {
                if let Some(flat) = self.flatten(e, line) {
                    return flat;
                }
                let Expr::Index { target, index } = e else { unreachable!() };
                Expr::Index { target: Box::new(self.expr(target, line)), index: Box::new(self.expr(index, line)) }
            }
            Expr::Call(c) => {
                if c.name.eq_ignore_ascii_case("len") {
                    if let [Expr::Ident(id)] = c.args.as_slice() {
                        if let Some(d) = self.dims_of(&id.name) {
                            return Expr::Number(d[0] as i32);
                        }
                    }
                }
                Expr::Call(CallInfo {
                    name: c.name.clone(),
                    source_line: c.source_line,
                    col: c.col,
                    args: c.args.iter().map(|a| self.expr(a, c.source_line)).collect(),
                })
            }
            Expr::MethodCall(m) => {
                let mut m = m.clone();
                m.target = Box::new(self.expr(&m.target, m.source_line));
                m.args = m.args.iter().map(|a| self.expr(a, m.source_line)).collect();
                Expr::MethodCall(m)
            }
            Expr::Binary { op, left, right } => Expr::Binary { op: *op, left: Box::new(self.expr(left, line)), right: Box::new(self.expr(right, line)) },
            Expr::Compare { op, left, right } => Expr::Compare { op: *op, left: Box::new(self.expr(left, line)), right: Box::new(self.expr(right, line)) },
            Expr::Logic { op, left, right } => Expr::Logic { op: *op, left: Box::new(self.expr(left, line)), right: Box::new(self.expr(right, line)) },
            Expr::Not(x) => Expr::Not(Box::new(self.expr(x, line))),
            Expr::BitNot(x) => Expr::BitNot(Box::new(self.expr(x, line))),
            Expr::List(v) => Expr::List(v.iter().map(|x| self.expr(x, line)).collect()),
            Expr::FieldAccess { target, field, source_line, col } => Expr::FieldAccess {
                target: Box::new(self.expr(target, *source_line)),
                field: field.clone(),
                source_line: *source_line,
                col: *col,
            },
            Expr::Number(_) | Expr::StringLit(_) | Expr::Ident(_) | Expr::StructInit { .. } => e.clone(),
        }
    }

    fn target(&mut self, t: &AssignTarget, line: usize) -> AssignTarget {
        match t {
            AssignTarget::Index { target, index, source_line, col } => {
                let as_expr = Expr::Index { target: target.clone(), index: index.clone() };
                match self.flatten(&as_expr, *source_line) {
                    Some(Expr::Index { target, index }) => AssignTarget::Index { target, index, source_line: *source_line, col: *col },
                    Some(_) => t.clone(),
                    None => AssignTarget::Index {
                        target: Box::new(self.expr(target, line)),
                        index: Box::new(self.expr(index, line)),
                        source_line: *source_line,
                        col: *col,
                    },
                }
            }
            AssignTarget::FieldAccess { target, field, source_line, col } => AssignTarget::FieldAccess {
                target: Box::new(self.expr(target, *source_line)),
                field: field.clone(),
                source_line: *source_line,
                col: *col,
            },
            AssignTarget::Ident { .. } => t.clone(),
        }
    }

    fn body(&mut self, b: &[Stmt]) -> Vec<Stmt> {
        b.iter().map(|s| self.stmt(s)).collect()
    }

    fn stmt(&mut self, s: &Stmt) -> Stmt {
        match s {
            Stmt::Assign { target, value, source_line } => Stmt::Assign {
                target: self.target(target, *source_line),
                value: self.expr(value, *source_line),
                source_line: *source_line,
            },
            Stmt::CompoundAssign { target, op, value, source_line } => Stmt::CompoundAssign {
                target: self.target(target, *source_line),
                op: *op,
                value: self.expr(value, *source_line),
                source_line: *source_line,
            },
            Stmt::Let { name, type_annotation, value, source_line } => Stmt::Let {
                name: name.clone(),
                type_annotation: type_annotation.clone(),
                value: self.expr(value, *source_line),
                source_line: *source_line,
            },
            Stmt::For { var, start, end, step, body, source_line } => Stmt::For {
                var: var.clone(),
                start: self.expr(start, *source_line),
                end: self.expr(end, *source_line),
                step: step.as_ref().map(|x| self.expr(x, *source_line)),
                body: self.body(body),
                source_line: *source_line,
            },
            Stmt::ForIn { var, iterable, body, source_line } => {
                if let Expr::Ident(id) = iterable {
                    if self.dims_of(&id.name).is_some() {
                        self.error(*source_line, format!(
                            "`for {var} in {}`: it is a multi-dimensional array; loop over `range(0, len({}))` and index it",
                            id.name, id.name
                        ));
                    }
                }
                Stmt::ForIn { var: var.clone(), iterable: self.expr(iterable, *source_line), body: self.body(body), source_line: *source_line }
            }
            Stmt::While { cond, body, source_line } => Stmt::While { cond: self.expr(cond, *source_line), body: self.body(body), source_line: *source_line },
            Stmt::Expr(e, line) => Stmt::Expr(self.expr(e, *line), *line),
            Stmt::If { cond, body, elifs, else_body, source_line } => Stmt::If {
                cond: self.expr(cond, *source_line),
                body: self.body(body),
                elifs: elifs.iter().map(|(c, b)| (self.expr(c, *source_line), self.body(b))).collect(),
                else_body: else_body.as_ref().map(|b| self.body(b)),
                source_line: *source_line,
            },
            Stmt::Switch { expr, cases, default, source_line } => Stmt::Switch {
                expr: self.expr(expr, *source_line),
                cases: cases.iter().map(|(c, b)| (self.expr(c, *source_line), self.body(b))).collect(),
                default: default.as_ref().map(|b| self.body(b)),
                source_line: *source_line,
            },
            Stmt::Return(e, line) => Stmt::Return(e.as_ref().map(|x| self.expr(x, *line)), *line),
            Stmt::Break { .. } | Stmt::Continue { .. } | Stmt::Pass { .. } => s.clone(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn unify(src: &str) -> Result<Module, String> {
        let tokens = vpy_parser::lex(src).expect("lex");
        let m = vpy_parser::parse_tokens(&tokens, "main.vpy").expect("parse");
        let mut modules = HashMap::new();
        modules.insert("main".to_string(), m);
        crate::unify_modules(modules, "main").map_err(|e| e.to_string())
    }

    fn list_of(m: &Module, name: &str) -> Vec<i32> {
        m.items
            .iter()
            .find_map(|i| match i {
                Item::GlobalLet { name: n, value: Expr::List(v), .. } | Item::Const { name: n, value: Expr::List(v), .. }
                    if n.eq_ignore_ascii_case(name) =>
                {
                    Some(v.iter().map(|e| if let Expr::Number(n) = e { *n } else { panic!("{e:?}") }).collect())
                }
                _ => None,
            })
            .unwrap_or_else(|| panic!("no array {name}"))
    }

    /// Named constants and enum members in an array literal become their values, as in C
    /// (`static const int8_t FX[] = { SX_TIE_FLYBY, ... }`).
    #[test]
    fn named_constants_in_array_literals_fold() {
        let m = unify("enum Sx:\n    A, B, C\nconst MAX = 4\nconst T = [C, MAX * 2, A, B + MAX]\ndef main():\n    pass\ndef loop():\n    pass\n").unwrap();
        assert_eq!(list_of(&m, "T"), vec![2, 8, 0, 5]);
    }

    #[test]
    fn repetition_and_nesting_flatten() {
        let m = unify("xf: i32 = [0] * 4\ngrid = [[1, 2] * 2] * 2\nconst T = 2 * [[5], [6]]\n").unwrap();
        assert_eq!(list_of(&m, "XF"), vec![0; 4]);
        assert_eq!(list_of(&m, "GRID"), vec![1, 2, 1, 2, 1, 2, 1, 2]);
        assert_eq!(list_of(&m, "T"), vec![5, 6, 5, 6]);
    }

    #[test]
    fn indices_and_len_are_rewritten() {
        let m = unify("g = [[0] * 3] * 2\ndef f(r, c):\n    g[r][c] = len(g)\n    return g[1][c]\n").unwrap();
        let Some(Item::Function(f)) = m.items.iter().find(|i| matches!(i, Item::Function(_))) else { panic!() };
        let Stmt::Assign { target: AssignTarget::Index { index, .. }, value, .. } = &f.body[0] else { panic!("{:?}", f.body[0]) };
        assert_eq!(value, &Expr::Number(2));
        assert!(matches!(index.as_ref(), Expr::Binary { op: BinOp::Add, left, .. }
            if matches!(left.as_ref(), Expr::Binary { op: BinOp::Mul, right, .. } if **right == Expr::Number(3))), "{index:?}");
    }

    #[test]
    fn ragged_and_partial_are_errors() {
        let err = unify("r = [[1, 2], [3]]\n").unwrap_err();
        assert!(err.contains("array `R`: nested lists of different lengths"), "{err}");
        let err = unify("g = [[0] * 3] * 2\ndef f(i):\n    return g[i]\n").unwrap_err();
        assert!(err.contains("`G` is a 2-dimensional array (2 x 3): index it 2 times"), "{err}");
    }
}
