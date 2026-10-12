//! Structs, lowered to plain variables and arrays (one per field).
//!
//! ```python
//! struct Tie:
//!     x: i32
//!     z: i32
//!     hp: u8 = 3
//!
//! player = Tie()          # one Tie: PLAYER__X, PLAYER__Z, PLAYER__HP = 3
//! boss = Tie(0, 9000, 20) # fields in order
//! ties = Tie[8]           # eight: TIES__X: i32[8], TIES__Z: i32[8], TIES__HP: u8[8] = 3s
//!
//! ties[i].hp -= 1         # TIES__HP[i] -= 1
//! player.z = 4000         # PLAYER__Z = 4000
//! n = len(ties)           # 8
//! ```
//!
//! Every field becomes a global of the field's type, named `<variable>__<field>`;
//! for an array of structs, a global array of that type (struct of arrays). So a
//! struct works on every target with the codegen that already exists, a field
//! keeps its own element size (an `i32` x next to a `u8` hp), and the m6809 rules
//! (no 32-bit field) apply unchanged. Struct variables are globals; a function
//! takes the INDEX of an element (`def hit(i): ties[i].hp -= 1`), not the struct.
//! Not lowered (each one a compile error with its line): a struct used as a
//! whole value (passed, assigned, iterated), methods, local struct variables.

use crate::error::Diagnostic;
use std::collections::HashMap;
use vpy_parser::{AssignTarget, CallInfo, Expr, FieldDef, IdentInfo, Item, Module, Stmt, StructDef};

/// A struct variable: its struct, and its length if it is an array.
struct Var<'s> {
    def: &'s StructDef,
    /// `ties = Tie[8]` → Some(8); `player = Tie()` → None.
    len: Option<usize>,
    /// The variable as declared (for field names and messages).
    name: String,
}

fn field_name(var: &str, field: &str) -> String {
    format!("{var}__{field}")
}

/// Lower every struct of `module`. Errors are reported against `module_name`.
pub fn lower(module: Module, module_name: &str) -> Result<Module, Vec<Diagnostic>> {
    let mut diags = Vec::new();
    macro_rules! err {
        ($line:expr, $msg:expr) => {
            diags.push(Diagnostic { module: module_name.to_string(), line: $line, message: $msg })
        };
    }

    let defs: HashMap<String, &StructDef> = module
        .items
        .iter()
        .filter_map(|i| match i {
            Item::StructDef(d) => Some((d.name.to_uppercase(), d)),
            _ => None,
        })
        .collect();
    if defs.is_empty() {
        return Ok(module);
    }
    for d in defs.values() {
        if d.fields.is_empty() {
            err!(d.source_line, format!("struct `{}` has no fields", d.name));
        }
        if !d.methods.is_empty() || d.constructor.is_some() {
            err!(d.source_line, format!(
                "struct `{}` has methods: not supported yet. Write functions that take the element's index, \
                 e.g. `def hit(i):` with `ties[i].hp -= 1`",
                d.name
            ));
        }
        let mut seen = std::collections::HashSet::new();
        for f in &d.fields {
            if !seen.insert(f.name.to_uppercase()) {
                err!(f.source_line, format!("struct `{}` has two fields named `{}`", d.name, f.name));
            }
            if let Some(v) = &f.default {
                if !matches!(v, Expr::Number(_)) {
                    err!(f.source_line, format!("field `{}.{}`: a default value must be a number", d.name, f.name));
                }
            }
        }
    }

    // The struct variables.
    let mut vars: HashMap<String, Var> = HashMap::new();
    for item in &module.items {
        let Item::GlobalLet { name, type_annotation, value, source_line } = item else { continue };
        let (def, len, args) = match value {
            Expr::Call(CallInfo { name: s, args, .. }) if defs.contains_key(&s.to_uppercase()) => {
                (defs[&s.to_uppercase()], None, args.as_slice())
            }
            Expr::Index { target, index } => match (target.as_ref(), index.as_ref()) {
                (Expr::Ident(id), Expr::Number(n)) if defs.contains_key(&id.name.to_uppercase()) => {
                    if *n <= 0 {
                        err!(*source_line, format!("`{name} = {}[{n}]`: an array of structs needs at least one element", id.name));
                        continue;
                    }
                    (defs[&id.name.to_uppercase()], Some(*n as usize), &[][..])
                }
                (Expr::Ident(id), _) if defs.contains_key(&id.name.to_uppercase()) => {
                    err!(*source_line, format!(
                        "`{name} = {}[...]`: the number of elements must be a number literal", id.name
                    ));
                    continue;
                }
                _ => continue,
            },
            _ => continue,
        };
        if type_annotation.is_some() {
            err!(*source_line, format!("`{name}` is a `{}`: it takes no type annotation (the fields have theirs)", def.name));
        }
        if args.len() > def.fields.len() {
            err!(*source_line, format!(
                "`{}()` takes at most {} values (one per field, in order), got {}",
                def.name, def.fields.len(), args.len()
            ));
        }
        for (a, f) in args.iter().zip(&def.fields) {
            if !matches!(a, Expr::Number(_)) {
                err!(*source_line, format!("`{}()`: the value for field `{}` must be a number", def.name, f.name));
            }
        }
        vars.insert(name.to_uppercase(), Var { def, len, name: name.clone() });
    }

    // The lowered program: struct definitions dropped, each struct variable
    // replaced by its fields, every use rewritten.
    let taken: std::collections::HashSet<String> = module
        .items
        .iter()
        .filter_map(|i| match i {
            Item::Function(f) => Some(f.name.to_uppercase()),
            Item::GlobalLet { name, .. } | Item::Const { name, .. } => Some(name.to_uppercase()),
            _ => None,
        })
        .collect();
    let mut items = Vec::new();
    for item in &module.items {
        match item {
            Item::StructDef(_) => {}
            Item::GlobalLet { name, value, source_line, .. } if vars.contains_key(&name.to_uppercase()) => {
                let var = &vars[&name.to_uppercase()];
                let args: &[Expr] = match value {
                    Expr::Call(c) => &c.args,
                    _ => &[],
                };
                for (k, f) in var.def.fields.iter().enumerate() {
                    let lowered = field_name(&var.name, &f.name);
                    if taken.contains(&lowered.to_uppercase()) {
                        err!(*source_line, format!(
                            "`{name}.{}` would be the global `{lowered}`, which already exists: rename one of them",
                            f.name
                        ));
                    }
                    let start = args.get(k).or(f.default.as_ref()).cloned().unwrap_or(Expr::Number(0));
                    let value = match var.len {
                        Some(n) => Expr::List(vec![start; n]),
                        None => start,
                    };
                    items.push(Item::GlobalLet {
                        name: lowered,
                        type_annotation: f.type_annotation.clone(),
                        value,
                        source_line: *source_line,
                    });
                }
            }
            Item::Function(func) => {
                let mut func = func.clone();
                let mut rw = Rewriter { vars: &vars, params: &func.params.clone(), diags: Vec::new(), module: module_name };
                func.body = func.body.iter().map(|s| rw.stmt(s)).collect();
                diags.append(&mut rw.diags);
                items.push(Item::Function(func));
            }
            Item::GlobalLet { name, type_annotation, value, source_line } => {
                let mut rw = Rewriter { vars: &vars, params: &[], diags: Vec::new(), module: module_name };
                let value = rw.expr(value, *source_line);
                diags.append(&mut rw.diags);
                items.push(Item::GlobalLet { name: name.clone(), type_annotation: type_annotation.clone(), value, source_line: *source_line });
            }
            other => items.push(other.clone()),
        }
    }
    if diags.is_empty() {
        Ok(Module { items, meta: module.meta, imports: module.imports })
    } else {
        Err(diags)
    }
}

struct Rewriter<'a, 's> {
    vars: &'a HashMap<String, Var<'s>>,
    /// Parameters of the function being rewritten: they shadow struct variables.
    params: &'a [String],
    diags: Vec<Diagnostic>,
    module: &'a str,
}

impl<'a, 's> Rewriter<'a, 's> {
    fn error(&mut self, line: usize, message: String) {
        self.diags.push(Diagnostic { module: self.module.to_string(), line, message });
    }

    fn var(&self, name: &str) -> Option<&'a Var<'s>> {
        if self.params.iter().any(|p| p.eq_ignore_ascii_case(name)) {
            return None;
        }
        self.vars.get(&name.to_uppercase())
    }

    fn field(&mut self, var: &str, def: &'s StructDef, field: &str, line: usize) -> Option<&'s FieldDef> {
        let f = def.fields.iter().find(|f| f.name.eq_ignore_ascii_case(field));
        if f.is_none() {
            let list: Vec<&str> = def.fields.iter().map(|f| f.name.as_str()).collect();
            self.error(line, format!(
                "`{var}.{field}`: struct `{}` has no field `{field}` (its fields: {})",
                def.name,
                list.join(", ")
            ));
        }
        f
    }

    /// `v.f` / `v[i].f` as the lowered expression, if `target.field` is one.
    fn lower_field(&mut self, target: &Expr, field: &str, line: usize) -> Option<Expr> {
        match target {
            Expr::Ident(id) => {
                let (def, len, name) = {
                    let v = self.var(&id.name)?;
                    (v.def, v.len, v.name.clone())
                };
                // An unknown field is reported once; 0 stands in for it.
                let Some(f) = self.field(&name, def, field, line) else { return Some(Expr::Number(0)) };
                if len.is_some() {
                    self.error(line, format!("`{name}` is an array of `{}`: index it, `{name}[i].{field}`", def.name));
                }
                Some(Expr::Ident(IdentInfo { name: field_name(&name, &f.name), source_line: line, col: id.col }))
            }
            Expr::Index { target: inner, index } => {
                let Expr::Ident(id) = inner.as_ref() else { return None };
                let (def, len, name) = {
                    let v = self.var(&id.name)?;
                    (v.def, v.len, v.name.clone())
                };
                let Some(f) = self.field(&name, def, field, line) else { return Some(Expr::Number(0)) };
                if len.is_none() {
                    self.error(line, format!("`{name}` is one `{}`, not an array: write `{name}.{field}`", def.name));
                }
                let index = self.expr(index, line);
                Some(Expr::Index {
                    target: Box::new(Expr::Ident(IdentInfo { name: field_name(&name, &f.name), source_line: line, col: id.col })),
                    index: Box::new(index),
                })
            }
            _ => None,
        }
    }

    fn whole_struct(&mut self, name: &str, line: usize) {
        let (def, var) = {
            let v = self.vars.get(&name.to_uppercase()).expect("struct var");
            (v.def.name.clone(), v.name.clone())
        };
        self.error(line, format!(
            "`{var}` is a `{def}`: a struct cannot be used as a whole value (passed, assigned, compared or \
             iterated). Use its fields, `{var}.field`, or pass an element's index"
        ));
    }

    fn expr(&mut self, e: &Expr, line: usize) -> Expr {
        match e {
            Expr::FieldAccess { target, field, source_line, col } => {
                if let Some(lowered) = self.lower_field(target, field, *source_line) {
                    return lowered;
                }
                Expr::FieldAccess { target: Box::new(self.expr(target, *source_line)), field: field.clone(), source_line: *source_line, col: *col }
            }
            Expr::Ident(id) => {
                if self.var(&id.name).is_some() {
                    self.whole_struct(&id.name, id.source_line);
                }
                e.clone()
            }
            Expr::Call(c) => {
                // len(ties) = the length of any field's array.
                if c.name.eq_ignore_ascii_case("len") {
                    if let [Expr::Ident(id)] = c.args.as_slice() {
                        if let Some(v) = self.var(&id.name) {
                            let (first, name, is_array) = (v.def.fields[0].name.clone(), v.name.clone(), v.len.is_some());
                            if !is_array {
                                self.error(c.source_line, format!("len({name}): `{name}` is one struct, not an array"));
                            }
                            return Expr::Call(CallInfo {
                                name: c.name.clone(),
                                source_line: c.source_line,
                                col: c.col,
                                args: vec![Expr::Ident(IdentInfo { name: field_name(&name, &first), source_line: id.source_line, col: id.col })],
                            });
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
                if let Expr::Ident(id) = m.target.as_ref() {
                    if self.var(&id.name).is_some() {
                        self.error(m.source_line, format!("`{}.{}()`: structs have no methods yet", id.name, m.method_name));
                    }
                }
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
            Expr::Index { target, index } => {
                if let Expr::Ident(id) = target.as_ref() {
                    if self.var(&id.name).is_some() {
                        // `ties[i]` alone (no `.field`) is a whole struct.
                        self.whole_struct(&id.name, line);
                        return e.clone();
                    }
                }
                Expr::Index { target: Box::new(self.expr(target, line)), index: Box::new(self.expr(index, line)) }
            }
            Expr::Number(_) | Expr::StringLit(_) | Expr::StructInit { .. } => e.clone(),
        }
    }

    fn target(&mut self, t: &AssignTarget, line: usize) -> AssignTarget {
        match t {
            AssignTarget::FieldAccess { target, field, source_line, col } => match self.lower_field(target, field, *source_line) {
                Some(Expr::Ident(id)) => AssignTarget::Ident { name: id.name, source_line: *source_line, col: *col },
                Some(Expr::Index { target, index }) => AssignTarget::Index { target, index, source_line: *source_line, col: *col },
                // An unknown field, already reported: keep the target as written.
                Some(_) => t.clone(),
                None => AssignTarget::FieldAccess {
                    target: Box::new(self.expr(target, *source_line)),
                    field: field.clone(),
                    source_line: *source_line,
                    col: *col,
                },
            },
            AssignTarget::Ident { name, source_line, .. } => {
                if self.var(name).is_some() {
                    self.whole_struct(name, *source_line);
                }
                t.clone()
            }
            AssignTarget::Index { target, index, source_line, col } => AssignTarget::Index {
                target: Box::new(self.expr(target, line)),
                index: Box::new(self.expr(index, line)),
                source_line: *source_line,
                col: *col,
            },
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
            Stmt::Let { name, type_annotation, value, source_line } => {
                if self.var(name).is_some() {
                    self.whole_struct(name, *source_line);
                }
                Stmt::Let { name: name.clone(), type_annotation: type_annotation.clone(), value: self.expr(value, *source_line), source_line: *source_line }
            }
            Stmt::For { var, start, end, step, body, source_line } => Stmt::For {
                var: var.clone(),
                start: self.expr(start, *source_line),
                end: self.expr(end, *source_line),
                step: step.as_ref().map(|x| self.expr(x, *source_line)),
                body: self.body(body),
                source_line: *source_line,
            },
            Stmt::ForIn { var, iterable, body, source_line } => Stmt::ForIn {
                var: var.clone(),
                iterable: self.expr(iterable, *source_line),
                body: self.body(body),
                source_line: *source_line,
            },
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

    fn global<'m>(m: &'m Module, name: &str) -> (&'m Option<String>, &'m Expr) {
        m.items
            .iter()
            .find_map(|i| match i {
                Item::GlobalLet { name: n, type_annotation, value, .. } if n.eq_ignore_ascii_case(name) => Some((type_annotation, value)),
                _ => None,
            })
            .unwrap_or_else(|| panic!("no global {name}"))
    }

    const SRC: &str = "\
struct Tie:
    x: i32
    hp: u8 = 3
    tag

ties = Tie[3]
boss = Tie(-7, 20)

def hit(i):
    ties[i].hp -= 1
    boss.x = len(ties)
";

    #[test]
    fn every_field_becomes_a_typed_global() {
        let m = unify(SRC).unwrap();
        assert!(!m.items.iter().any(|i| matches!(i, Item::StructDef(_))));
        let (t, v) = global(&m, "TIES__x");
        assert_eq!((t.as_deref(), v), (Some("i32"), &Expr::List(vec![Expr::Number(0); 3])));
        let (t, v) = global(&m, "TIES__hp");
        assert_eq!((t.as_deref(), v), (Some("u8"), &Expr::List(vec![Expr::Number(3); 3])));
        assert_eq!(global(&m, "TIES__tag"), (&None, &Expr::List(vec![Expr::Number(0); 3])));
        // Values in field order, then the defaults.
        assert_eq!(global(&m, "BOSS__x").1, &Expr::Number(-7));
        assert_eq!(global(&m, "BOSS__hp").1, &Expr::Number(20));
        assert_eq!(global(&m, "BOSS__tag").1, &Expr::Number(0));
    }

    #[test]
    fn field_uses_are_rewritten() {
        let m = unify(SRC).unwrap();
        let Some(Item::Function(f)) = m.items.iter().find(|i| matches!(i, Item::Function(_))) else { panic!() };
        match &f.body[0] {
            Stmt::CompoundAssign { target: AssignTarget::Index { target, .. }, .. } => {
                assert!(matches!(target.as_ref(), Expr::Ident(id) if id.name == "TIES__hp"), "{target:?}");
            }
            other => panic!("{other:?}"),
        }
        match &f.body[1] {
            Stmt::Assign { target: AssignTarget::Ident { name, .. }, value: Expr::Call(c), .. } => {
                assert_eq!(name, "BOSS__x");
                assert!(matches!(&c.args[0], Expr::Ident(id) if id.name == "TIES__x"), "len() of the first field");
            }
            other => panic!("{other:?}"),
        }
    }

    #[test]
    fn misuses_are_errors_with_their_line() {
        let src = "\
struct P:
    x: i16

ps = P[2]
p = P()

def f(a):
    return 0

def main():
    a = ps[0].y
    b = ps.x + f(p)
    p = 1
";
        let err = unify(src).unwrap_err();
        assert!(err.contains("11") && err.contains("struct `P` has no field `y` (its fields: x)"), "{err}");
        assert!(err.contains("is an array of `P`: index it"), "{err}");
        assert!(err.contains("a struct cannot be used as a whole value"), "{err}");
        assert_eq!(err.matches("cannot be used as a whole value").count(), 2, "{err}");
    }

    #[test]
    fn methods_and_bad_sizes_are_refused() {
        let err = unify("struct P:\n    x: i16\n    def f(a):\n        return 0\nps = P[0]\n").unwrap_err();
        assert!(err.contains("has methods: not supported yet"), "{err}");
        assert!(err.contains("an array of structs needs at least one element"), "{err}");
    }
}
