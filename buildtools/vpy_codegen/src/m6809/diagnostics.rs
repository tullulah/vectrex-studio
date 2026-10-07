//! Compile errors found WHILE emitting m6809 code.
//!
//! Most m6809 emitters write into a `String` and return `()`. When one of them
//! meets something it cannot translate (an unknown function, a method that does
//! not exist, a placeholder builtin) it used to emit a `; TODO` / `; Unimplemented`
//! comment and let the build succeed with the code silently missing. Now it calls
//! [`error`]; [`finish`] turns every recorded error into a failed compile.
//!
//! Lifecycle (driven by `generate_m6809_asm`): [`begin`] → emit → [`finish`].

use std::cell::RefCell;
use std::collections::HashSet;
use vpy_parser::{Item, Module};

thread_local! {
    /// m6809 labels of every user function in the unified module.
    static USER_FUNCTIONS: RefCell<HashSet<String>> = RefCell::new(HashSet::new());
    /// Recorded errors, in emission order.
    static ERRORS: RefCell<Vec<String>> = RefCell::new(Vec::new());
    /// Source line of the call / statement being emitted (0 = unknown).
    static CURRENT_LINE: RefCell<usize> = const { RefCell::new(0) };
}

/// Start a compilation unit: register the user functions, clear old errors.
pub fn begin(module: &Module) {
    let names: HashSet<String> = module
        .items
        .iter()
        .filter_map(|item| match item {
            Item::Function(f) => Some(vpy_parser::symbols::m6809_label(&f.name)),
            _ => None,
        })
        .collect();
    USER_FUNCTIONS.with(|u| *u.borrow_mut() = names);
    ERRORS.with(|e| e.borrow_mut().clear());
    CURRENT_LINE.with(|l| *l.borrow_mut() = 0);
}

/// Is `name` (a unified name) a function defined in the program?
pub fn is_user_function(name: &str) -> bool {
    USER_FUNCTIONS.with(|u| u.borrow().contains(&vpy_parser::symbols::m6809_label(name)))
}

/// BIOS symbols (VECTREX.I) the program may call by name: `WAIT_RECAL()` is
/// `JSR WAIT_RECAL`, resolved by the assembler against the `Wait_Recal` equate.
/// Embedded at build time so the check does not depend on the working directory.
const VECTREX_I: &str = include_str!("../../../../ide/frontend/public/include/VECTREX.I");

pub fn is_bios_symbol(name: &str) -> bool {
    use std::sync::OnceLock;
    static SYMBOLS: OnceLock<HashSet<String>> = OnceLock::new();
    SYMBOLS
        .get_or_init(|| {
            VECTREX_I
                .lines()
                .map(str::trim)
                .filter(|l| !l.is_empty() && !l.starts_with(';') && !l.starts_with('*'))
                .filter_map(|l| {
                    let equ = l.find("EQU")?;
                    let sym = l[..equ].trim();
                    (!sym.is_empty()).then(|| sym.to_uppercase())
                })
                .collect()
        })
        .contains(&name.to_uppercase())
}

/// Can `JSR <name>` resolve? (a user function or a BIOS routine)
pub fn is_callable(name: &str) -> bool {
    is_user_function(name) || is_bios_symbol(name)
}

/// Record the source line of the construct being emitted (0 leaves it unchanged).
pub fn set_line(line: usize) {
    if line > 0 {
        CURRENT_LINE.with(|l| *l.borrow_mut() = line);
    }
}

/// Record a compile error at the current line.
pub fn error(message: impl Into<String>) {
    let line = CURRENT_LINE.with(|l| *l.borrow());
    let message = message.into();
    let text = if line > 0 { format!("line {line}: {message}") } else { message };
    ERRORS.with(|e| e.borrow_mut().push(text));
}

/// Record a compile error at an explicit line.
pub fn error_at(line: usize, message: impl Into<String>) {
    set_line(line);
    error(message);
}

/// End the unit: `Err` with every distinct recorded error, if any.
pub fn finish() -> Result<(), String> {
    let errors = ERRORS.with(|e| std::mem::take(&mut *e.borrow_mut()));
    if errors.is_empty() {
        return Ok(());
    }
    // Multibank emits some code more than once; report each error once.
    let mut seen = HashSet::new();
    let unique: Vec<String> = errors.into_iter().filter(|e| seen.insert(e.clone())).collect();
    Err(unique.join("\n"))
}
