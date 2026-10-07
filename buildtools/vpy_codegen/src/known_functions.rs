//! The user functions of the program being compiled, for every backend.
//!
//! A call whose name is neither a builtin nor one of these functions is a
//! compile error with its line — not an `bl NAME` the linker rejects later
//! without a location, and never a silent no-op. Registered once per compile by
//! [`crate::generate_from_module_with_target`].

use std::cell::RefCell;
use std::collections::HashSet;
use vpy_parser::{Item, Module};

thread_local! {
    static FUNCTIONS: RefCell<HashSet<String>> = RefCell::new(HashSet::new());
}

/// Register the functions defined by `module` (replaces any previous set).
pub fn register(module: &Module) {
    let names = module
        .items
        .iter()
        .filter_map(|item| match item {
            Item::Function(f) => Some(f.name.clone()),
            _ => None,
        })
        .collect();
    FUNCTIONS.with(|f| *f.borrow_mut() = names);
}

/// Is `name` (a unified name, exactly as the call site spells it) defined?
pub fn is_defined(name: &str) -> bool {
    FUNCTIONS.with(|f| f.borrow().contains(name))
}

/// The error every ARM backend reports for an unknown call.
pub fn unknown_call_error(name: &str, line: usize) -> String {
    format!(
        "line {line}: `{name}()` is not a builtin and no function of that name is defined \
         (check the spelling; a function of another module is called as `module.name()`)"
    )
}
