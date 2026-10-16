//! Which source file each unified item came from, for error messages.
//!
//! The unifier merges every module into one; AST lines are per file, so a
//! codegen error "line 18: …" in a multi-file project does not say WHICH file.
//! vpy_cli registers the file of every function, global and const (by unified
//! name) with [`set_files`]; a backend [`enter`]s the item it is compiling, and
//! [`locate`] turns each "line N: message" into "file:N: error: message", the
//! form the unifier's errors already have, and writes every unified name in the
//! message as the program spells it (`COMMON_ties__x` → `ties.x`, `R1` → `r1`).
//! Without a registered file the line prefix is left as it is.

use std::cell::RefCell;
use std::collections::HashMap;

thread_local! {
    /// UPPER-case unified name → file, as printed.
    static FILES: RefCell<HashMap<String, String>> = RefCell::new(HashMap::new());
    /// Unified name, exactly as the unifier writes it → the name as written.
    static NAMES: RefCell<HashMap<String, String>> = RefCell::new(HashMap::new());
    /// The file of the item being compiled.
    static CURRENT: RefCell<Option<String>> = const { RefCell::new(None) };
}

/// Register every item for this compile: unified name → (file, name as written).
pub fn set_items(items: HashMap<String, (String, String)>) {
    let files = items.iter().map(|(k, (file, _))| (k.to_uppercase(), file.clone())).collect();
    let names = items.into_iter().map(|(k, (_, written))| (k, written)).collect();
    FILES.with(|f| *f.borrow_mut() = files);
    NAMES.with(|n| *n.borrow_mut() = names);
    CURRENT.with(|c| *c.borrow_mut() = None);
}

/// The name of unified symbol `unified` as the program writes it: a struct
/// field's global (`COMMON_ties__x`) as `ties.x`. None if it is not one.
pub fn source_name(unified: &str) -> Option<String> {
    NAMES.with(|n| {
        let n = n.borrow();
        n.get(unified).cloned().or_else(|| {
            let (var, field) = unified.split_once("__")?;
            Some(format!("{}.{field}", n.get(var)?))
        })
    })
}

/// Every unified name in `msg` as the program writes it.
fn rename(msg: &str) -> String {
    let mut out = String::with_capacity(msg.len());
    let mut word = String::new();
    let flush = |word: &mut String, out: &mut String| {
        if !word.is_empty() {
            out.push_str(&source_name(word).unwrap_or_else(|| word.clone()));
            word.clear();
        }
    };
    for c in msg.chars() {
        if c.is_ascii_alphanumeric() || c == '_' {
            word.push(c);
        } else {
            flush(&mut word, &mut out);
            out.push(c);
        }
    }
    flush(&mut word, &mut out);
    out
}

/// The file of item `name`; a struct field's global (`TIES__HP`) is its variable's.
pub fn file_of(name: &str) -> Option<String> {
    let up = name.to_uppercase();
    FILES.with(|f| {
        let f = f.borrow();
        f.get(&up).cloned().or_else(|| up.split_once("__").and_then(|(var, _)| f.get(var).cloned()))
    })
}

/// Compiling item `name` from now on.
pub fn enter(name: &str) {
    let file = file_of(name);
    CURRENT.with(|c| *c.borrow_mut() = file);
}

/// No item.
pub fn leave() {
    CURRENT.with(|c| *c.borrow_mut() = None);
}

/// Every "line N: message" line of `msg` as "file:N: error: message", with the
/// file of the current item.
pub fn locate(msg: &str) -> String {
    let msg = &rename(msg);
    let Some(file) = CURRENT.with(|c| c.borrow().clone()) else { return msg.to_string() };
    msg.lines()
        .map(|l| match l.strip_prefix("line ").and_then(|r| r.split_once(": ")) {
            Some((n, rest)) if n.chars().all(|c| c.is_ascii_digit()) && !n.is_empty() => {
                format!("{file}:{n}: error: {rest}")
            }
            _ => l.to_string(),
        })
        .collect::<Vec<_>>()
        .join("\n")
}

/// [`locate`] `msg` as an error of item `name`.
pub fn locate_for(name: &str, msg: &str) -> String {
    let saved = CURRENT.with(|c| c.borrow().clone());
    enter(name);
    let out = locate(msg);
    CURRENT.with(|c| *c.borrow_mut() = saved);
    out
}

/// [`locate`] the errors pushed since `start` as errors of item `name`.
pub fn locate_new(errors: &mut [String], start: usize, name: &str) {
    for e in errors.iter_mut().skip(start) {
        *e = locate_for(name, e);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn lines_get_the_items_file() {
        let item = |k: &str, f: &str, w: &str| (k.to_string(), (f.to_string(), w.to_string()));
        set_items(HashMap::from([
            item("SPACE_frame", "src/space.vpy", "frame"),
            item("COMMON_ties", "src/common.vpy", "ties"),
            item("R1", "src/main.vpy", "r1"),
        ]));
        assert_eq!(
            locate_for("SPACE_FRAME", "line 18: `NOPE()` is unknown\nline 20: again\nnot a line"),
            "src/space.vpy:18: error: `NOPE()` is unknown\nsrc/space.vpy:20: error: again\nnot a line"
        );
        assert_eq!(
            locate_for("COMMON_ties__hp", "line 4: `COMMON_ties__hp: i32` in SPACE_frame, len(R1)"),
            "src/common.vpy:4: error: `ties.hp: i32` in frame, len(r1)"
        );
        assert_eq!(locate_for("UNKNOWN", "line 4: x"), "line 4: x");
        set_items(HashMap::new());
    }
}
