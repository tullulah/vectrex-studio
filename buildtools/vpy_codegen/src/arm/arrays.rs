//! Element type of arrays on the ARM backends (rp2350, uvm2, pitrex).
//!
//! An array element has its declared type, as on m6809: `xs: u8 = [...]` holds
//! bytes, untyped and `u16`/`i16` arrays halfwords, `u32`/`i32` arrays words.
//! Unsigned elements are zero-extended when read, signed ones sign-extended.
//!
//! A global array name evaluates to the address of its data; an indexed
//! parameter takes its element type from the arrays passed at its call sites
//! (`m6809::array_params`, shared). Anything else indexed (a local holding an
//! address, a computed address) has 16-bit elements.

use crate::m6809::context::VarSize;
use std::cell::RefCell;
use std::collections::HashMap;
use vpy_parser::{Expr, Item, Module};

thread_local! {
    /// Global and const arrays: UPPERCASE name → element type.
    static GLOBALS: RefCell<HashMap<String, VarSize>> = RefCell::new(HashMap::new());
    /// Function label → parameter (lower-case) → element type, for the indexed
    /// parameters whose call sites pass typed arrays.
    static PARAMS: RefCell<HashMap<String, HashMap<String, VarSize>>> = RefCell::new(HashMap::new());
    /// The function being generated: its label and parameter names.
    static CURRENT: RefCell<(String, Vec<String>)> = RefCell::new((String::new(), Vec::new()));
}

/// Record the element type of every array of `module` for a fresh compile.
pub fn setup(module: &Module) -> Result<(), String> {
    let globals = module
        .items
        .iter()
        .filter_map(|item| match item {
            Item::GlobalLet { name, value: Expr::List(v), type_annotation, .. }
            | Item::Const { name, value: Expr::List(v), type_annotation, .. } => {
                // a table of strings holds their addresses
                let strings = !v.is_empty() && v.iter().all(|e| matches!(e, Expr::StringLit(_)));
                let size = if strings { VarSize { bytes: 4, signed: false } } else { VarSize::from_annotation(type_annotation) };
                Some((name.to_uppercase(), size))
            }
            _ => None,
        })
        .collect();
    let params = crate::m6809::array_params::analyze(module)?;
    GLOBALS.with(|g| *g.borrow_mut() = globals);
    PARAMS.with(|p| *p.borrow_mut() = params);
    enter_function("", &[]);
    Ok(())
}

/// Generating the body of function `name` with these parameters (main and loop
/// have none).
pub fn enter_function(name: &str, params: &[String]) {
    let label = vpy_parser::symbols::m6809_label(name);
    CURRENT.with(|c| *c.borrow_mut() = (label, params.to_vec()));
}

/// Element type of global array `name` (16-bit if it is not one).
pub fn of_global(name: &str) -> VarSize {
    GLOBALS.with(|g| g.borrow().get(&name.to_uppercase()).copied()).unwrap_or_else(VarSize::default_i16)
}

/// Element type of the array that `target[...]` indexes.
pub fn of(target: &Expr) -> VarSize {
    let Expr::Ident(id) = target else { return VarSize::default_i16() };
    CURRENT.with(|c| {
        let (label, params) = &*c.borrow();
        if params.iter().any(|p| p.eq_ignore_ascii_case(&id.name)) {
            PARAMS.with(|p| p.borrow().get(label).and_then(|ps| ps.get(&id.name.to_lowercase()).copied()))
                .unwrap_or_else(VarSize::default_i16)
        } else {
            of_global(&id.name)
        }
    })
}

/// `lsl` turning an index in `reg` into a byte offset (empty for bytes).
pub fn scale(reg: &str, v: VarSize) -> String {
    match v.bytes {
        1 => String::new(),
        2 => format!("    lsl     {reg}, {reg}, #1     @ index * 2 ({})\n", v.type_name()),
        _ => format!("    lsl     {reg}, {reg}, #2     @ index * 4 ({})\n", v.type_name()),
    }
}

/// Load mnemonic of one element (extends to 32 bits by its signedness).
pub fn load(v: VarSize) -> &'static str {
    match (v.bytes, v.signed) {
        (1, false) => "ldrb ",
        (1, true) => "ldrsb",
        (2, false) => "ldrh ",
        (2, true) => "ldrsh",
        _ => "ldr  ",
    }
}

/// Store mnemonic of one element.
pub fn store(v: VarSize) -> &'static str {
    match v.bytes {
        1 => "strb ",
        2 => "strh ",
        _ => "str  ",
    }
}

/// Data directive of one element in a const table.
pub fn directive(v: VarSize) -> &'static str {
    match v.bytes {
        1 => ".byte ",
        2 => ".hword",
        _ => ".word ",
    }
}
