//! Stack frames for user functions on the ARM backends (rp2350, uvm2: Thumb-2;
//! pitrex: ARM32 — the same instructions assemble in both modes).
//!
//! Each user function (and `game_main`, which holds the bodies of `main()` and
//! `loop()`) owns a frame on the hardware stack:
//!
//! ```text
//!     push    {r4, …, r7, lr}        saved registers (r7 is callee-saved: AAPCS)
//!     sub     sp, sp, #SIZE          the slots; SIZE keeps sp 8-byte aligned
//!     mov     r7, sp                 r7 = frame pointer for the whole body
//!     …       ldr r0, [r7, #4*k]     slot k = k-th parameter, then the locals
//!   .Lret_F:                         every `return` branches here
//!     mov     sp, r7                 drops anything a `return` left on the stack
//!     add     sp, sp, #SIZE
//!     pop     {r4, …, r7, pc}
//! ```
//!
//! sp moves while an expression is evaluated (operands wait on the stack), so
//! slots are addressed from r7, which only the prologue writes. Every runtime
//! routine the generated code calls saves r7 if it uses it (AAPCS), so r7 is
//! valid across calls. Arguments arrive in r0-r3 (the prologue stores them in
//! their slots); arguments 5+ stay where the caller pushed them, above the
//! saved registers, and are copied into slots too.
//!
//! Which names are parameters and locals (and which are globals) follows the
//! language rules shared with m6809 (`m6809::frames::function_scopes`): a
//! parameter shadows a global, a module-level name is the global, any other
//! assigned name is a local; reading an undeclared name is a compile error.
//! Because every activation has its own frame, recursion works on ARM.
//!
//! The current function's slots are thread-local state set while its body is
//! emitted (`enter` / `leave`), so the expression emitters resolve a name
//! without threading the frame through every call.

use std::cell::RefCell;
use std::collections::HashMap;
use vpy_parser::{Function, Stmt};

use crate::m6809::ast_walk::{self, Visitor};

/// Frame pointer register.
pub const FP: &str = "r7";

/// Largest frame the `[r7, #imm12]` addressing reaches.
const MAX_FRAME: u32 = 4092;

thread_local! {
    /// UPPER-case name → byte offset from r7 of the function being emitted.
    static SCOPE: RefCell<HashMap<String, u32>> = RefCell::new(HashMap::new());
}

/// Slot names of one function body, in slot order.
#[derive(Debug, Clone, Default)]
pub struct Scope {
    pub names: Vec<String>,
}

impl Scope {
    /// Parameters then locals of `func`, as `m6809::frames::function_scopes`
    /// resolved them, plus the hidden locals `for v in array` keeps on ARM
    /// (base pointer and length besides the counter).
    pub fn of(func: &Function, frames: &std::collections::BTreeMap<String, crate::m6809::frames::Frame>) -> Scope {
        let mut names: Vec<String> = Vec::new();
        if let Some(frame) = frames.get(&vpy_parser::symbols::m6809_label(&func.name)) {
            names.extend(frame.slots.iter().map(|s| s.name.to_uppercase()));
        }
        struct ForIns(Vec<usize>);
        impl<'a> Visitor<'a> for ForIns {
            fn stmt(&mut self, stmt: &'a Stmt) {
                if let Stmt::ForIn { source_line, .. } = stmt {
                    self.0.push(*source_line);
                }
            }
        }
        let mut for_ins = ForIns(Vec::new());
        ast_walk::walk_stmts(&func.body, &mut for_ins);
        for line in for_ins.0 {
            for name in [for_in_base(line), for_in_len(line)] {
                if !names.contains(&name) {
                    names.push(name);
                }
            }
        }
        Scope { names }
    }
}

/// Hidden local: base pointer of the array a `for v in array` at `line` walks.
pub fn for_in_base(line: usize) -> String {
    format!("_FI_{line}_BASE")
}

/// Hidden local: length of the array a `for v in array` at `line` walks.
pub fn for_in_len(line: usize) -> String {
    format!("_FI_{line}_LEN")
}

/// Hidden local: element counter of a `for v in array` at `line` (the same name
/// m6809's frames give it, so it is already one of the function's locals).
pub fn for_in_counter(line: usize) -> String {
    crate::m6809::frames::for_in_counter_name(line).to_uppercase()
}

/// Laid-out frame: byte offset of every slot from r7, and the size to reserve.
#[derive(Debug, Clone)]
pub struct Layout {
    pub offsets: HashMap<String, u32>,
    /// Bytes reserved below the saved registers (slots + alignment padding).
    pub size: u32,
}

/// Lay out `scopes` (slot lists that share one frame, e.g. main's and loop's
/// bodies in `game_main`) one after the other, with 4-byte slots. `pushed` is
/// what the prologue pushes; the size is padded so `pushed + size` is a
/// multiple of 8 (sp 8-byte aligned inside the body, AAPCS).
pub fn layout(scopes: &[&Scope], pushed: u32, function: &str) -> Result<Vec<Layout>, String> {
    layout_aligned(scopes, pushed, 8, function)
}

/// [`layout`] with an explicit stack alignment (a multiple of 8).
pub fn layout_aligned(scopes: &[&Scope], pushed: u32, align: u32, function: &str) -> Result<Vec<Layout>, String> {
    let mut next = 0u32;
    let mut out = Vec::new();
    for scope in scopes {
        let mut offsets = HashMap::new();
        for name in &scope.names {
            offsets.insert(name.clone(), next);
            next += 4;
        }
        out.push(Layout { offsets, size: 0 });
    }
    let mut size = next;
    while (pushed + size) % align != 0 {
        size += 4;
    }
    if size > MAX_FRAME {
        return Err(format!(
            "`{}()` has {} parameters and locals: more than a frame holds ({} bytes)",
            crate::m6809::frames::display_name(function),
            next / 4,
            MAX_FRAME
        ));
    }
    for l in &mut out {
        l.size = size;
    }
    Ok(out)
}

/// Make `layout` the frame names resolve against.
pub fn enter(layout: &Layout) {
    SCOPE.with(|s| *s.borrow_mut() = layout.offsets.clone());
}

/// Leave the current frame (names resolve to globals only).
pub fn leave() {
    SCOPE.with(|s| s.borrow_mut().clear());
}

/// Offset from r7 of `name` in the current frame.
pub fn slot(name: &str) -> Option<u32> {
    SCOPE.with(|s| s.borrow().get(&name.to_uppercase()).copied())
}

/// `sub sp, sp, #size` for the target (ARM32 immediates are rotated 8-bit
/// values, so a large frame goes through r12 there).
pub fn reserve(size: u32, arm32: bool) -> String {
    if size == 0 {
        String::new()
    } else if arm32 && size > 255 {
        format!("    ldr     r12, ={size}\n    sub     sp, sp, r12\n")
    } else {
        format!("    sub     sp, sp, #{size}\n")
    }
}

/// Epilogue body after `mov sp, r7`: `add sp, sp, #size`.
fn release(size: u32, arm32: bool) -> String {
    if size == 0 {
        String::new()
    } else if arm32 && size > 255 {
        format!("    ldr     r12, ={size}\n    add     sp, sp, r12\n")
    } else {
        format!("    add     sp, sp, #{size}\n")
    }
}

/// Prologue after the register push: reserve the frame, set r7, store the
/// parameters (r0-r3, then the caller's stack arguments) in their slots.
pub fn prologue(layout: &Layout, params: &[String], pushed: u32, arm32: bool) -> String {
    let mut s = reserve(layout.size, arm32);
    s.push_str(&format!("    mov     {FP}, sp              @ frame pointer\n"));
    for (i, param) in params.iter().enumerate() {
        let Some(&off) = layout.offsets.get(&param.to_uppercase()) else { continue };
        if i < 4 {
            s.push_str(&format!("    str     r{i}, [{FP}, #{off}]    @ param {param}\n"));
        } else {
            let arg = layout.size + pushed + 4 * (i as u32 - 4);
            s.push_str(&format!(
                "    ldr     r0, [{FP}, #{arg}]    @ stack arg {param}\n    str     r0, [{FP}, #{off}]\n"
            ));
        }
    }
    s
}

/// Epilogue at `ret_label`: drop the frame (and anything a `return` from inside
/// a switch left on the stack) and return; r0 holds the result.
pub fn epilogue(ret_label: &str, layout: &Layout, pop: &str, arm32: bool) -> String {
    let mut s = format!("{ret_label}:\n    mov     sp, {FP}\n");
    s.push_str(&release(layout.size, arm32));
    s.push_str(&format!("    {pop}\n"));
    s
}

/// Code loading variable `name` into r0: its frame slot, else its global address.
pub fn load_r0(name: &str, var_addrs: &HashMap<String, u32>) -> Result<String, String> {
    if let Some(off) = slot(name) {
        return Ok(format!("    ldr     r0, [{FP}, #{off}]    @ {name}\n"));
    }
    match var_addrs.get(&name.to_uppercase()) {
        Some(&addr) => Ok(format!("    ldr     r1, =0x{addr:08X}    @ {name}\n    ldr     r0, [r1]\n")),
        None => Err(format!("Unknown variable: {name}")),
    }
}

/// Code storing r0 into variable `name` (clobbers r1 for a global).
pub fn store_r0(name: &str, var_addrs: &HashMap<String, u32>) -> Result<String, String> {
    if let Some(off) = slot(name) {
        return Ok(format!("    str     r0, [{FP}, #{off}]    @ {name}\n"));
    }
    match var_addrs.get(&name.to_uppercase()) {
        Some(&addr) => Ok(format!("    ldr     r1, =0x{addr:08X}    @ {name}\n    str     r0, [r1]\n")),
        None => Err(format!("Unknown variable: {name}")),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn scope(names: &[&str]) -> Scope {
        Scope { names: names.iter().map(|n| n.to_string()).collect() }
    }

    #[test]
    fn frame_keeps_sp_8_byte_aligned() {
        // push {r4-r7, lr} = 20 bytes: the frame makes it a multiple of 8.
        for n in 0..6 {
            let names: Vec<String> = (0..n).map(|i| format!("V{i}")).collect();
            let s = Scope { names };
            let l = &layout(&[&s], 20, "F").unwrap()[0];
            assert_eq!((20 + l.size) % 8, 0, "{n} slots");
            assert!(l.size >= 4 * n as u32);
        }
        // pitrex pushes 24 bytes: an empty frame needs no padding.
        assert_eq!(layout(&[&scope(&[])], 24, "F").unwrap()[0].size, 0);
    }

    #[test]
    fn scopes_sharing_a_frame_get_distinct_slots() {
        let (m, l) = (scope(&["T"]), scope(&["U", "T"]));
        let ls = layout(&[&m, &l], 20, "GAME_MAIN").unwrap();
        assert_eq!(ls[0].offsets["T"], 0);
        assert_eq!(ls[1].offsets["U"], 4);
        assert_eq!(ls[1].offsets["T"], 8, "loop's t is not main's t");
        assert_eq!(ls[0].size, ls[1].size);
    }

    #[test]
    fn names_resolve_to_the_frame_first() {
        let globals: HashMap<String, u32> = [("X".to_string(), 0x2007_F460)].into();
        let l = &layout(&[&scope(&["X"])], 20, "SHADOW").unwrap()[0];
        enter(l);
        assert_eq!(load_r0("x", &globals).unwrap(), "    ldr     r0, [r7, #0]    @ x\n");
        assert!(store_r0("x", &globals).unwrap().contains("[r7, #0]"));
        leave();
        assert!(load_r0("x", &globals).unwrap().contains("=0x2007F460"));
        assert!(load_r0("nope", &globals).is_err());
    }

    #[test]
    fn oversized_frame_is_an_error() {
        let names: Vec<String> = (0..1100).map(|i| format!("V{i}")).collect();
        let e = layout(&[&Scope { names }], 20, "BIG").unwrap_err();
        assert!(e.contains("`big()`"), "{e}");
    }
}
