//! `.vpy` line numbers in the ARM assembly, for gdb (`.file` / `.loc` → DWARF line
//! table, written by gas whether or not the `.S` is assembled with `-g`).
//!
//! The emitter marks each statement's start with a comment, `@@loc <file> <line>`:
//! a comment, so the peephole pass (which reads line adjacency and treats directives
//! as barriers) produces exactly the code it produces without debug lines. After the
//! peephole, `finish` turns the marks into `.loc` and puts the `.file` table on top.
//!
//! A function's code ends with line 0 ("no source line"): the runtime routines that
//! follow it in the file are not the last `.vpy` line, and gdb's `step` goes over them.
//!
//! The source of each function comes from the CLI (`set_sources`), keyed by its m6809
//! label (`MAIN`, `UTIL_BUMP`): the unified module no longer knows it. Without it, no
//! marks are written. Per thread, like all codegen state.

use std::cell::{Cell, RefCell};
use std::collections::HashMap;
use std::path::PathBuf;

/// A directive the emitter wrote as a comment: `@@loc 2 4` is `.loc 2 4`.
const MARK: &str = "@@";

thread_local! {
    /// `.file` numbers: index + 1.
    static FILES: RefCell<Vec<PathBuf>> = RefCell::new(Vec::new());
    /// Function label (uppercase) → its `.file` number.
    static FUNC_FILE: RefCell<HashMap<String, usize>> = RefCell::new(HashMap::new());
    /// The `.file` number of the function being emitted; 0 = none.
    static CURRENT: Cell<usize> = Cell::new(0);
}

/// Every function's source file (label → path), before generating; an empty map
/// turns the line marks off.
pub fn set_sources(sources: &HashMap<String, PathBuf>) {
    // Absolute: gdb reads a relative path from the build's own directory (cmake's)
    let sources: HashMap<String, PathBuf> = sources
        .iter()
        .map(|(l, p)| (l.clone(), std::fs::canonicalize(p).or_else(|_| std::path::absolute(p)).unwrap_or_else(|_| p.clone())))
        .collect();
    let mut files: Vec<PathBuf> = sources.values().cloned().collect();
    files.sort();
    files.dedup();
    let func_file = sources
        .iter()
        .map(|(label, path)| (label.to_uppercase(), files.iter().position(|f| f == path).unwrap() + 1))
        .collect();
    FILES.with(|f| *f.borrow_mut() = files);
    FUNC_FILE.with(|m| *m.borrow_mut() = func_file);
    CURRENT.with(|c| c.set(0));
}

/// Start of a function's code: its `def` line (gdb's breakpoint on the function lands
/// on the line after it, past the prologue).
pub fn enter_function(name: &str, def_line: usize) -> String {
    let file = FUNC_FILE.with(|m| m.borrow().get(&name.to_uppercase()).copied().unwrap_or(0));
    CURRENT.with(|c| c.set(file));
    mark(file, def_line)
}

/// A statement's first instruction.
pub fn statement(line: usize) -> String {
    mark(CURRENT.with(|c| c.get()), line)
}

/// End of a function's code: what follows has no `.vpy` line.
pub fn leave_function() -> String {
    let file = CURRENT.with(|c| c.replace(0));
    if file == 0 { String::new() } else { format!("{MARK}loc {file} 0\n") }
}

/// Call-frame information, so gdb can unwind a VPy frame (`bt`, `finish`). The
/// prologue is `push {r4-r7, lr}` (`pushed` bytes), `sub sp, #frame`, `mov r7, sp`:
/// from then on the caller's frame is at r7 + frame + pushed, whatever sp does with
/// temporaries. Each piece goes right after its instruction.
pub fn cfi_start() -> String { format!("{MARK}cfi_startproc\n") }

pub fn cfi_after_push(pushed: u32) -> String {
    let mut s = format!("{MARK}cfi_def_cfa_offset {pushed}\n");
    for (i, r) in ["r4", "r5", "r6", "r7", "lr"].iter().enumerate() {
        s.push_str(&format!("{MARK}cfi_offset {r}, -{}\n", pushed - 4 * i as u32));
    }
    s
}

pub fn cfi_frame_pointer(frame: u32, pushed: u32) -> String {
    format!("{MARK}cfi_def_cfa r7, {}\n", frame + pushed)
}

pub fn cfi_end() -> String { format!("{MARK}cfi_endproc\n") }

// ---- the VPy->C backend (cgen.rs): `#line` instead of `.loc` ----

/// What a function's end writes in C: the CLI turns it into `#line <next line> "<the .c>"`
/// (finish_c), so the C after it is the .c's own again, not the last `.vpy` line's.
const C_RESYNC: &str = "#line __VPY_RESYNC__";

/// Start of a function's C body (nothing is written: its statements carry the lines).
pub fn enter_c(name: &str) {
    let file = FUNC_FILE.with(|m| m.borrow().get(&name.to_uppercase()).copied().unwrap_or(0));
    CURRENT.with(|c| c.set(file));
}

/// `#line` for a statement: its line in its `.vpy`.
pub fn c_line(line: usize) -> String {
    let file = CURRENT.with(|c| c.get());
    if file == 0 || line == 0 {
        return String::new();
    }
    let path = FILES.with(|f| f.borrow()[file - 1].display().to_string().replace('\\', "/").replace('"', "\\\""));
    format!("#line {line} \"{path}\"\n")
}

/// End of a function's C body.
pub fn c_leave() -> String {
    if CURRENT.with(|c| c.replace(0)) == 0 { String::new() } else { format!("{C_RESYNC}\n") }
}

/// The C as written to `c_path`: each function's end goes back to the .c's own lines.
pub fn finish_c(c: &str, c_path: &std::path::Path) -> String {
    if !c.contains(C_RESYNC) {
        return c.to_string();
    }
    let path = std::fs::canonicalize(c_path).or_else(|_| std::path::absolute(c_path)).unwrap_or_else(|_| c_path.to_path_buf());
    let path = path.display().to_string().replace('\\', "/").replace('"', "\\\"");
    let mut out = String::with_capacity(c.len() + 1024);
    for (i, line) in c.lines().enumerate() {
        if line == C_RESYNC {
            // the line after this one is line i + 2 of the file (i is 0-based)
            out.push_str(&format!("#line {} \"{path}\"", i + 2));
        } else {
            out.push_str(line);
        }
        out.push('\n');
    }
    out
}

fn mark(file: usize, line: usize) -> String {
    if file == 0 || line == 0 { String::new() } else { format!("{MARK}loc {file} {line}\n") }
}

/// The marks as directives, and after the `.syntax` line the `.file` table (when there
/// are sources) and `.cfi_sections .debug_frame` (unwind data in a debug section: the
/// default, .eh_frame, would be loaded into the image).
pub fn finish(asm: &str) -> String {
    if !asm.contains(MARK) {
        return asm.to_string();
    }
    let files = FILES.with(|f| f.borrow().clone());
    let mut head: String = files
        .iter()
        .enumerate()
        .map(|(i, p)| format!(".file {} \"{}\"\n", i + 1, p.display().to_string().replace('\\', "/").replace('"', "\\\"")))
        .collect();
    if asm.contains("@@cfi_") {
        head.push_str(".cfi_sections .debug_frame\n");
    }
    let mut out = String::with_capacity(asm.len() + head.len());
    let mut placed = false;
    for line in asm.lines() {
        if let Some(rest) = line.trim_start().strip_prefix(MARK) {
            out.push_str("    .");
            out.push_str(rest);
        } else {
            out.push_str(line);
        }
        out.push('\n');
        if !placed && line.trim_start().starts_with(".syntax") {
            out.push_str(&head);
            placed = true;
        }
    }
    if !placed {
        out.insert_str(0, &head);
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sources() -> HashMap<String, PathBuf> {
        HashMap::from([
            ("MAIN".to_string(), PathBuf::from("/p/src/main.vpy")),
            ("LOOP".to_string(), PathBuf::from("/p/src/main.vpy")),
            ("UTIL_BUMP".to_string(), PathBuf::from("/p/src/util.vpy")),
        ])
    }

    #[test]
    fn marks_become_loc_with_a_file_table() {
        set_sources(&sources());
        let mut asm = String::from(".syntax unified\n");
        asm.push_str(&enter_function("UTIL_bump", 3));
        asm.push_str("UTIL_bump:\n");
        asm.push_str(&statement(4));
        asm.push_str("    add r0, r0, #1\n");
        asm.push_str(&leave_function());
        asm.push_str("vpy_helper:\n    bx lr\n");
        let out = finish(&asm);
        assert_eq!(
            out,
            ".syntax unified\n.file 1 \"/p/src/main.vpy\"\n.file 2 \"/p/src/util.vpy\"\n\
             \x20   .loc 2 3\nUTIL_bump:\n    .loc 2 4\n    add r0, r0, #1\n    .loc 2 0\nvpy_helper:\n    bx lr\n"
        );
    }

    #[test]
    fn c_lines_and_the_way_back_to_the_c_file() {
        set_sources(&sources());
        enter_c("UTIL_bump");
        let mut c = String::from("static int32_t F_UTIL_BUMP(int32_t v)\n{\n");
        c.push_str(&c_line(4));
        c.push_str("    w = v + 1;\n");
        c.push_str(&c_leave());
        c.push_str("    return 0;\n}\n");
        assert_eq!(c_line(5), "", "no file after the function");
        let out = finish_c(&c, std::path::Path::new("/b/game.c"));
        assert_eq!(
            out,
            "static int32_t F_UTIL_BUMP(int32_t v)\n{\n#line 4 \"/p/src/util.vpy\"\n    w = v + 1;\n\
             #line 6 \"/b/game.c\"\n    return 0;\n}\n"
        );
    }

    #[test]
    fn no_sources_no_marks() {
        set_sources(&HashMap::new());
        assert_eq!(enter_function("MAIN", 5), "");
        assert_eq!(statement(6), "");
        assert_eq!(leave_function(), "");
        assert_eq!(finish(".syntax unified\n"), ".syntax unified\n");
    }

    #[test]
    fn a_function_without_a_known_file_gets_no_lines() {
        set_sources(&sources());
        assert_eq!(enter_function("OTHER", 5), "");
        assert_eq!(statement(6), "");
        assert_eq!(leave_function(), "");
    }
}
