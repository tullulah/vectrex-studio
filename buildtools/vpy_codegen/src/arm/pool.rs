//! Literal pools inside long functions (ARM targets).
//!
//! `ldr rN, =value` loads from a literal pool, which the assembler places at the next
//! `.ltorg`; the load reaches only about 4 KB. A function gets one `.ltorg` at its end,
//! so a body longer than that — `game_main`, which holds the globals' initialisation,
//! `main()` and `loop()` — failed to assemble ("offset out of range").
//!
//! Between statements, once enough code has piled up since the last pool, an island is
//! emitted: a branch over a `.ltorg`. The branch lands on code (never on the pool: the
//! literal words would run as instructions), and a statement boundary is never inside
//! an IT block.

use std::cell::Cell;

/// Lines of code after which a pool is placed (about 1-2 KB of Thumb-2, well inside
/// the 4 KB reach even with the code a statement adds around a nested one).
const LIMIT: usize = 250;

thread_local! {
    static LINES: Cell<usize> = const { Cell::new(0) };
    static ISLANDS: Cell<usize> = const { Cell::new(0) };
}

/// A function starts: no code since a pool.
pub fn reset() {
    LINES.with(|l| l.set(0));
}

/// `code` was just emitted for one statement (or one global's initialisation): count
/// it, and append an island if a pool is due.
pub fn after(code: &mut String) {
    let tail = match code.rfind(".ltorg") {
        Some(i) => {
            LINES.with(|l| l.set(0));
            &code[i..]
        }
        None => code.as_str(),
    };
    // the debugger's marks (`@@loc`, `@@cfi_…`: debug_lines.rs) are no code
    let n = LINES.with(|l| l.get()) + tail.lines().filter(|l| !l.trim_start().starts_with("@@")).count();
    if n < LIMIT {
        LINES.with(|l| l.set(n));
        return;
    }
    let id = ISLANDS.with(|c| {
        let id = c.get();
        c.set(id + 1);
        id
    });
    code.push_str(&format!(
        "    b       .Lpool_skip_{id}       @ over the literal pool\n    .ltorg\n.Lpool_skip_{id}:\n"
    ));
    LINES.with(|l| l.set(0));
}
