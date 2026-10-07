//! Function scopes across modules: a parameter or local must never be taken for
//! a top-level variable of another module (the main program's included), and a
//! module must not silently read the main program's globals.
//!
//! The backends resolve names in ONE namespace, case-insensitively (the entry
//! module's globals unprefixed, an imported module's as `MODULE_symbol`), so
//! the unifier is the only phase that can still tell the two apart.

use std::collections::HashMap;
use vpy_parser::ast::{AssignTarget, Expr, Function, Item, Module, Stmt};
use vpy_unifier::{unify_modules, Diagnostic, UnifierError, UnifierResult};

fn parse(src: &str, file: &str) -> Module {
    let tokens = vpy_parser::lex(src).expect("lex");
    vpy_parser::parser::parse(tokens, file).expect("parse")
}

fn unify(srcs: &[(&str, &str)]) -> UnifierResult<Module> {
    let mut modules = HashMap::new();
    for (name, src) in srcs {
        modules.insert(name.to_string(), parse(src, &format!("{name}.vpy")));
    }
    unify_modules(modules, "main")
}

fn errors(r: UnifierResult<Module>) -> Vec<Diagnostic> {
    match r {
        Err(UnifierError::Unresolved(d)) => d,
        Err(e) => panic!("unexpected error kind: {e}"),
        Ok(_) => panic!("expected an error, unification succeeded"),
    }
}

fn function<'m>(m: &'m Module, name: &str) -> &'m Function {
    m.items
        .iter()
        .find_map(|i| match i {
            Item::Function(f) if f.name == name => Some(f),
            _ => None,
        })
        .unwrap_or_else(|| panic!("no function {name}"))
}

/// Every name a function body reads, writes or declares, upper-cased (the
/// backends compare names case-insensitively).
fn names(f: &Function) -> Vec<String> {
    fn expr(e: &Expr, out: &mut Vec<String>) {
        match e {
            Expr::Ident(i) => out.push(i.name.to_uppercase()),
            Expr::Call(c) => c.args.iter().for_each(|a| expr(a, out)),
            Expr::MethodCall(c) => {
                expr(&c.target, out);
                c.args.iter().for_each(|a| expr(a, out));
            }
            Expr::Binary { left, right, .. } | Expr::Compare { left, right, .. } | Expr::Logic { left, right, .. } => {
                expr(left, out);
                expr(right, out);
            }
            Expr::Not(e) | Expr::BitNot(e) => expr(e, out),
            Expr::List(l) => l.iter().for_each(|x| expr(x, out)),
            Expr::Index { target, index } => {
                expr(target, out);
                expr(index, out);
            }
            Expr::FieldAccess { target, .. } => expr(target, out),
            _ => {}
        }
    }
    fn stmt(s: &Stmt, out: &mut Vec<String>) {
        match s {
            Stmt::Assign { target, value, .. } | Stmt::CompoundAssign { target, value, .. } => {
                match target {
                    AssignTarget::Ident { name, .. } => out.push(name.to_uppercase()),
                    AssignTarget::Index { target, index, .. } => {
                        expr(target, out);
                        expr(index, out);
                    }
                    AssignTarget::FieldAccess { target, .. } => expr(target, out),
                }
                expr(value, out);
            }
            Stmt::Let { name, value, .. } => {
                out.push(name.to_uppercase());
                expr(value, out);
            }
            Stmt::Expr(e, _) | Stmt::Return(Some(e), _) => expr(e, out),
            Stmt::If { cond, body, elifs, else_body, .. } => {
                expr(cond, out);
                body.iter().for_each(|s| stmt(s, out));
                for (c, b) in elifs {
                    expr(c, out);
                    b.iter().for_each(|s| stmt(s, out));
                }
                if let Some(b) = else_body {
                    b.iter().for_each(|s| stmt(s, out));
                }
            }
            Stmt::While { cond, body, .. } => {
                expr(cond, out);
                body.iter().for_each(|s| stmt(s, out));
            }
            Stmt::For { var, start, end, step, body, .. } => {
                out.push(var.to_uppercase());
                expr(start, out);
                expr(end, out);
                if let Some(s) = step {
                    expr(s, out);
                }
                body.iter().for_each(|s| stmt(s, out));
            }
            Stmt::ForIn { var, iterable, body, .. } => {
                out.push(var.to_uppercase());
                expr(iterable, out);
                body.iter().for_each(|s| stmt(s, out));
            }
            _ => {}
        }
    }
    let mut out: Vec<String> = f.params.iter().map(|p| p.to_uppercase()).collect();
    f.body.iter().for_each(|s| stmt(s, &mut out));
    out
}

/// Top-level variable / const names of the unified program, upper-cased.
fn globals(m: &Module) -> Vec<String> {
    m.items
        .iter()
        .filter_map(|i| match i {
            Item::GlobalLet { name, .. } | Item::Const { name, .. } => Some(name.to_uppercase()),
            _ => None,
        })
        .collect()
}

const MAIN: &str = "\
import enemies

x = 5
i = 7
const LIMIT = 3

def main():
    SET_INTENSITY(127)

def loop():
    a = enemies.update(3)
    b = enemies.reset()
    c = enemies.count()
    PRINT_NUMBER(x, i, a + b + c)
";

const ENEMIES: &str = "\
def update(x):
    return x + 1

def reset():
    x = 0
    return x

def count():
    total = 0
    for i in range(0, 3):
        total = total + i
    return total

def nested(n):
    if n > 0:
        while n > 0:
            limit = n
            n -= 1
    return limit
";

// ---- Multi-module: an imported module's locals vs the main program's globals ----

#[test]
fn imported_function_locals_are_not_the_main_programs_globals() {
    let main = format!("{MAIN}    d = enemies.nested(2)\n");
    let unified = unify(&[("main", &main), ("enemies", ENEMIES)]).expect("unify");
    let program_globals = globals(&unified);
    assert!(program_globals.contains(&"X".to_string()) && program_globals.contains(&"I".to_string()));
    for f in ["ENEMIES_update", "ENEMIES_reset", "ENEMIES_count", "ENEMIES_nested"] {
        let used = names(function(&unified, f));
        for name in &used {
            assert!(
                !program_globals.contains(name),
                "{f}: its parameter/local `{name}` would be bound to the program's global of that name ({used:?})"
            );
        }
    }
    // the renamed local is used consistently: declaration, reads and writes
    let reset = names(function(&unified, "ENEMIES_reset"));
    assert_eq!(reset, vec!["X__L", "X__L"]);
    let update = function(&unified, "ENEMIES_update");
    assert_eq!(update.params, vec!["x__L".to_string()]);
    assert_eq!(names(update), vec!["X__L", "X__L"]);
    let count = names(function(&unified, "ENEMIES_count"));
    assert!(count.iter().filter(|n| *n == "I__L").count() == 2, "{count:?}");
    // a local inside nested blocks named like the main program's const
    let nested = names(function(&unified, "ENEMIES_nested"));
    assert!(nested.contains(&"LIMIT__L".to_string()) && !nested.contains(&"LIMIT".to_string()), "{nested:?}");
}

#[test]
fn main_program_still_uses_its_own_globals() {
    let unified = unify(&[("main", MAIN), ("enemies", ENEMIES)]).expect("unify");
    let lp = names(function(&unified, "LOOP"));
    assert!(lp.contains(&"X".to_string()) && lp.contains(&"I".to_string()), "{lp:?}");
}

#[test]
fn renaming_avoids_names_already_taken() {
    // `x__L` is itself a global of the main program: the local becomes `x__L2`
    let main = "import enemies\nx = 1\nx__l = 2\n\ndef main():\n    pass\n\ndef loop():\n    a = enemies.reset() + x + x__l\n";
    let unified = unify(&[("main", main), ("enemies", ENEMIES)]).expect("unify");
    assert_eq!(names(function(&unified, "ENEMIES_reset")), vec!["X__L2", "X__L2"]);
}

#[test]
fn a_modules_own_global_is_still_assigned_from_its_functions() {
    // VPy has no `global` keyword: assigning a name the module defines writes it
    let enemies = "count = 0\n\ndef bump():\n    count = count + 1\n    return count\n";
    let main = "import enemies\ncount = 9\n\ndef main():\n    pass\n\ndef loop():\n    a = enemies.bump() + count\n";
    let unified = unify(&[("main", main), ("enemies", enemies)]).expect("unify");
    assert_eq!(names(function(&unified, "ENEMIES_bump")), vec!["ENEMIES_COUNT"; 3]);
    assert!(names(function(&unified, "LOOP")).contains(&"COUNT".to_string()));
}

#[test]
fn from_import_name_is_module_level_in_the_importer() {
    // `from enemies import level`: `level` is a module-level name of main, so
    // assigning it in a function writes enemies.level; a parameter shadows it.
    let enemies = "level = 0\n";
    let main = "from enemies import level\n\ndef set_to(level):\n    return level\n\ndef main():\n    level = 3\n\ndef loop():\n    a = set_to(level)\n";
    let unified = unify(&[("main", main), ("enemies", enemies)]).expect("unify");
    assert_eq!(names(function(&unified, "MAIN")), vec!["ENEMIES_LEVEL"]);
    assert_eq!(names(function(&unified, "SET_TO")), vec!["LEVEL", "LEVEL"]);
    assert!(names(function(&unified, "LOOP")).contains(&"ENEMIES_LEVEL".to_string()));
}

#[test]
fn main_program_local_named_like_a_mangled_module_global_is_renamed() {
    // `enemies.speed` is ENEMIES_speed; a local `enemies_speed` of main must not alias it
    let enemies = "speed = 2\n";
    let main = "import enemies\n\ndef main():\n    pass\n\ndef loop():\n    enemies_speed = 1\n    a = enemies_speed + enemies.speed\n";
    let unified = unify(&[("main", main), ("enemies", enemies)]).expect("unify");
    let lp = names(function(&unified, "LOOP"));
    assert_eq!(lp, vec!["ENEMIES_SPEED__L", "A", "ENEMIES_SPEED__L", "ENEMIES_SPEED"]);
}

#[test]
fn locals_of_main_and_loop_stay_separate_names() {
    // main() and loop() are separate scopes; a local named like an imported
    // module's global is not that global (it is mangled, so no rename either)
    let enemies = "x = 0\n";
    let main = "import enemies\n\ndef main():\n    x = 1\n\ndef loop():\n    x = 2\n    for x in range(0, 2):\n        pass\n";
    let unified = unify(&[("main", main), ("enemies", enemies)]).expect("unify");
    assert_eq!(names(function(&unified, "MAIN")), vec!["X"]);
    assert_eq!(names(function(&unified, "LOOP")), vec!["X", "X"]);
}

#[test]
fn local_named_like_a_function_of_another_module_is_left_alone() {
    // functions are labels, not storage: no clash, no rename
    let enemies = "def update():\n    loop = 1\n    return loop\n";
    let main = "import enemies\n\ndef main():\n    pass\n\ndef loop():\n    a = enemies.update()\n";
    let unified = unify(&[("main", main), ("enemies", enemies)]).expect("unify");
    assert_eq!(names(function(&unified, "ENEMIES_update")), vec!["LOOP", "LOOP"]);
}

// ---- Single module ----

#[test]
fn single_module_parameter_shadowing_a_global_gets_its_own_name() {
    // a parameter is local even when a global has the same name
    let main = "x = 5\n\ndef twice(x):\n    return x + x\n\ndef main():\n    pass\n\ndef loop():\n    x = twice(x)\n";
    let unified = unify(&[("main", main)]).expect("unify");
    assert_eq!(function(&unified, "TWICE").params, vec!["x__L".to_string()]);
    assert_eq!(names(function(&unified, "TWICE")), vec!["X__L", "X__L", "X__L"]);
    // loop() assigns the global (VPy: a module-level name is the global)
    assert_eq!(names(function(&unified, "LOOP")), vec!["X", "X"]);
}

#[test]
fn single_module_without_clashes_is_unchanged() {
    let main = "score = 0\n\ndef add(v):\n    t = v + 1\n    for k in range(0, 2):\n        t += k\n    return t\n\ndef main():\n    pass\n\ndef loop():\n    score = add(score)\n";
    let unified = unify(&[("main", main)]).expect("unify");
    assert_eq!(function(&unified, "ADD").params, vec!["v".to_string()]);
    assert_eq!(names(function(&unified, "ADD")), vec!["V", "T", "V", "K", "T", "K", "T"]);
}

// ---- Error cases ----

#[test]
fn module_reading_a_main_program_global_is_an_error() {
    let enemies = "def peek():\n    return x + 1\n";
    let main = "import enemies\nx = 5\n\ndef main():\n    pass\n\ndef loop():\n    a = enemies.peek()\n";
    let diags = errors(unify(&[("main", main), ("enemies", enemies)]));
    assert_eq!(diags.len(), 1, "{diags:?}");
    assert_eq!(diags[0].module, "enemies");
    assert_eq!(diags[0].line, 2);
    assert!(diags[0].message.contains("global of the main program"), "{}", diags[0].message);
}

#[test]
fn reading_another_modules_global_by_its_assembler_name_is_an_error() {
    let enemies = "speed = 2\n";
    let main = "import enemies\n\ndef main():\n    pass\n\ndef loop():\n    a = enemies_speed\n";
    let diags = errors(unify(&[("main", main), ("enemies", enemies)]));
    assert_eq!(diags.len(), 1, "{diags:?}");
    assert!(diags[0].message.contains("enemies.speed"), "{}", diags[0].message);
}
