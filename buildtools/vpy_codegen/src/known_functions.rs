//! The user functions of the program being compiled, for every backend.
//!
//! A call whose name is neither a builtin nor one of these functions is a
//! compile error with its line — not an `bl NAME` the linker rejects later
//! without a location, and never a silent no-op. Registered once per compile by
//! [`crate::generate_from_module_with_target`].

use std::cell::RefCell;
use std::collections::HashMap;
use vpy_parser::{Item, Module};

thread_local! {
    /// Function name (as the unifier wrote it) → number of parameters.
    static FUNCTIONS: RefCell<HashMap<String, usize>> = RefCell::new(HashMap::new());
}

/// Register the functions defined by `module` (replaces any previous set).
pub fn register(module: &Module) {
    let names = module
        .items
        .iter()
        .filter_map(|item| match item {
            Item::Function(f) => Some((f.name.clone(), f.params.len())),
            _ => None,
        })
        .collect();
    FUNCTIONS.with(|f| *f.borrow_mut() = names);
}

/// Is `name` (a unified name, exactly as the call site spells it) defined?
pub fn is_defined(name: &str) -> bool {
    FUNCTIONS.with(|f| f.borrow().contains_key(name))
}

/// A call to user function `name` with `args` arguments must pass exactly its
/// parameters (the ARM backends; m6809 reports the same error from its frames).
pub fn check_arity(name: &str, args: usize, line: usize) -> Result<(), String> {
    let Some(params) = FUNCTIONS.with(|f| f.borrow().get(name).copied()) else {
        return Ok(());
    };
    if params == args {
        return Ok(());
    }
    Err(format!(
        "line {line}: `{}()` takes {params} argument{} but is called with {args}",
        crate::m6809::frames::display_name(name),
        if params == 1 { "" } else { "s" },
    ))
}

/// The error every ARM backend reports for an unknown call.
pub fn unknown_call_error(name: &str, line: usize) -> String {
    format!(
        "line {line}: `{name}()` is not a builtin and no function of that name is defined \
         (check the spelling; a function of another module is called as `module.name()`)"
    )
}
