//! Static call frames for m6809 functions (parameters and locals).
//!
//! The 6809 cartridge has 1 KB of RAM, so parameters and locals do not live on
//! the hardware stack and do not get one RAM slot per name for the whole
//! program. Each function gets a FRAME: one 16-bit slot per parameter and per
//! local, at a fixed RAM address. Frames are overlaid by call graph (the
//! SDCC "overlay" scheme): a function's frame starts right after the highest
//! frame end of every function that can call it, so a frame never overlaps the
//! frame of any function that can be active at the same time (its callers, its
//! callers' callers…), while functions that can never be active together share
//! the same bytes.
//!
//! Calling convention (see `expressions.rs`, user function calls):
//! - the caller evaluates the arguments and stores them straight into the
//!   callee's parameter slots, then `JSR`s; there is no prologue/epilogue;
//! - the return value comes back in D.
//!
//! Name resolution inside a function body:
//! - a parameter is the parameter (it shadows a global or const of the same name);
//! - a name declared at module level (global variable, const, array) is the
//!   global, for reads AND assignments (there is no `global` keyword: assigning
//!   to a global's name from a function writes the global);
//! - any other name assigned in the function (`x = …`, `x += …`, `for x in …`)
//!   is a local of that function;
//! - reading a name that is none of these is a compile error.
//!
//! Static frames cannot hold two activations of one function, so recursion
//! (direct or through other functions) is a compile error.
//!
//! Names are case-insensitive (the unifier upper-cases most of them).

use super::ast_walk::{self, Visitor};
use super::context::VarSize;
use std::collections::{BTreeMap, HashMap, HashSet};
use vpy_parser::{AssignTarget, Expr, Function, Item, Module, Stmt};

/// Parameter or local.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SlotKind {
    Param,
    Local,
}

/// One 16-bit (or 8-bit) slot of a frame.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Slot {
    /// Name as written in the source (for messages and debug info).
    pub name: String,
    /// Assembly label of the slot (`VAR_<FUNC>__<NAME>`).
    pub label: String,
    pub size: VarSize,
    pub kind: SlotKind,
    /// Byte offset inside the frame.
    pub offset: usize,
}

/// The frame of one function.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Frame {
    /// Function name as the unifier wrote it.
    pub function: String,
    /// m6809 label of the function.
    pub label: String,
    /// Parameters (in order) then locals (in order of first assignment).
    pub slots: Vec<Slot>,
    /// Byte offset of the frame inside the frame pool.
    pub offset: usize,
    /// Frame size in bytes.
    pub size: usize,
}

impl Frame {
    pub fn params(&self) -> impl Iterator<Item = &Slot> {
        self.slots.iter().filter(|s| s.kind == SlotKind::Param)
    }

    /// The slot named `name` (case-insensitive).
    pub fn slot(&self, name: &str) -> Option<&Slot> {
        self.slots.iter().find(|s| s.name.eq_ignore_ascii_case(name))
    }
}

/// Frames of every function of the program.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct FrameLayout {
    /// m6809 function label → frame.
    pub frames: BTreeMap<String, Frame>,
    /// Bytes the frame pool needs (highest frame end).
    pub pool_size: usize,
}

impl FrameLayout {
    /// Sum of all frame sizes: what one RAM slot per parameter/local would cost.
    pub fn unshared_size(&self) -> usize {
        self.frames.values().map(|f| f.size).sum()
    }
}

/// A name as the user most likely wrote it: the unifier upper-cases the entry
/// module's names, so an all-upper-case name is shown in lower case.
pub fn display_name(name: &str) -> String {
    if name.chars().any(|c| c.is_ascii_lowercase()) {
        name.to_string()
    } else {
        name.to_lowercase()
    }
}

/// Label of a frame slot.
pub fn slot_label(function_label: &str, name: &str) -> String {
    format!("VAR_{}__{}", function_label, name.to_uppercase())
}

/// Name of the counter `for v in array` keeps per loop (a local of the function).
pub fn for_in_counter_name(source_line: usize) -> String {
    format!("_fi_{source_line}")
}

/// Module-level names (lower-case): globals, consts, arrays.
fn module_names(module: &Module) -> HashSet<String> {
    module
        .items
        .iter()
        .filter_map(|item| match item {
            Item::GlobalLet { name, .. } | Item::Const { name, .. } => Some(name.to_lowercase()),
            _ => None,
        })
        .collect()
}

/// Names a function body assigns and reads, and the user functions it calls.
struct BodyScan<'m> {
    functions: &'m HashSet<String>,
    /// Assigned names in order of first appearance (as written), lower-case set for dedup.
    assigned: Vec<(String, usize)>,
    assigned_set: HashSet<String>,
    /// Read names (as written) with the line of the first read.
    read: Vec<(String, usize)>,
    read_set: HashSet<String>,
    /// Callee label → first call line.
    calls: BTreeMap<String, usize>,
    /// Line of the statement being visited (identifiers carry their own).
    line: usize,
}

impl BodyScan<'_> {
    fn assign(&mut self, name: &str) {
        if self.assigned_set.insert(name.to_lowercase()) {
            self.assigned.push((name.to_string(), self.line));
        }
    }
}

impl<'a> Visitor<'a> for BodyScan<'_> {
    fn stmt(&mut self, stmt: &'a Stmt) {
        self.line = stmt.source_line();
        match stmt {
            Stmt::Assign { target: AssignTarget::Ident { name, .. }, .. }
            | Stmt::CompoundAssign { target: AssignTarget::Ident { name, .. }, .. } => self.assign(name),
            Stmt::Let { name, .. } => self.assign(name),
            Stmt::For { var, .. } => self.assign(var),
            Stmt::ForIn { var, source_line, .. } => {
                self.assign(var);
                self.assign(&for_in_counter_name(*source_line));
            }
            Stmt::Assign { .. }
            | Stmt::CompoundAssign { .. }
            | Stmt::While { .. }
            | Stmt::If { .. }
            | Stmt::Switch { .. }
            | Stmt::Expr(..)
            | Stmt::Return(..)
            | Stmt::Break { .. }
            | Stmt::Continue { .. }
            | Stmt::Pass { .. } => {}
        }
        // `x += v` reads x as well.
        if let Stmt::CompoundAssign { target: AssignTarget::Ident { name, source_line, .. }, .. } = stmt {
            if self.read_set.insert(name.to_lowercase()) {
                self.read.push((name.clone(), *source_line));
            }
        }
    }

    fn expr(&mut self, expr: &'a Expr) {
        match expr {
            Expr::Ident(id) => {
                if self.read_set.insert(id.name.to_lowercase()) {
                    let line = if id.source_line > 0 { id.source_line } else { self.line };
                    self.read.push((id.name.clone(), line));
                }
            }
            Expr::Call(call) => {
                let label = vpy_parser::symbols::m6809_label(&call.name);
                if self.functions.contains(&label) {
                    self.calls.entry(label).or_insert(call.source_line);
                }
            }
            _ => {}
        }
    }
}

/// Build the frame of every function, check for recursion and undefined names,
/// and overlay the frames by call graph.
pub fn analyze(module: &Module) -> Result<FrameLayout, String> {
    let label = |name: &str| vpy_parser::symbols::m6809_label(name);
    let globals = module_names(module);
    let functions: Vec<&Function> = module
        .items
        .iter()
        .filter_map(|item| match item {
            Item::Function(f) => Some(f),
            _ => None,
        })
        .collect();
    let function_labels: HashSet<String> = functions.iter().map(|f| label(&f.name)).collect();

    let mut errors: Vec<String> = Vec::new();
    let mut frames: BTreeMap<String, Frame> = BTreeMap::new();
    // caller label → (callee label → first call line)
    let mut calls: BTreeMap<String, BTreeMap<String, usize>> = BTreeMap::new();
    let mut display: HashMap<String, (String, usize)> = HashMap::new();

    for func in &functions {
        let flabel = label(&func.name);
        display.insert(flabel.clone(), (display_name(&func.name), func.line));
        let mut scan = BodyScan {
            functions: &function_labels,
            assigned: Vec::new(),
            assigned_set: HashSet::new(),
            read: Vec::new(),
            read_set: HashSet::new(),
            calls: BTreeMap::new(),
            line: func.line,
        };
        ast_walk::walk_stmts(&func.body, &mut scan);

        let mut slots: Vec<Slot> = Vec::new();
        let mut offset = 0usize;
        let mut seen: HashSet<String> = HashSet::new();
        for p in &func.params {
            let key = p.to_lowercase();
            if !seen.insert(key) {
                errors.push(format!(
                    "line {}: function `{}` has two parameters named `{p}`",
                    func.line, display_name(&func.name)
                ));
                continue;
            }
            slots.push(Slot {
                name: p.clone(),
                label: slot_label(&flabel, p),
                size: VarSize::default_i16(),
                kind: SlotKind::Param,
                offset,
            });
            offset += 2;
        }
        for (name, _) in &scan.assigned {
            let key = name.to_lowercase();
            if globals.contains(&key) || seen.contains(&key) {
                continue;
            }
            seen.insert(key);
            slots.push(Slot {
                name: name.clone(),
                label: slot_label(&flabel, name),
                size: VarSize::default_i16(),
                kind: SlotKind::Local,
                offset,
            });
            offset += 2;
        }

        // A read must name a parameter, a local, or something declared at module level.
        for (name, line) in &scan.read {
            let key = name.to_lowercase();
            if seen.contains(&key) || globals.contains(&key) {
                continue;
            }
            let name = display_name(name);
            errors.push(format!(
                "line {line}: `{name}` is used in `{}()` but it is not a parameter, it is never assigned in \
                 this function, and it is not declared at module level. Each function has its own variables; \
                 to share a value between functions declare it at top level (e.g. `{name} = 0`)",
                display_name(&func.name)
            ));
        }

        frames.insert(
            flabel.clone(),
            Frame { function: func.name.clone(), label: flabel.clone(), slots, offset: 0, size: offset },
        );
        calls.insert(flabel, scan.calls);
    }

    // Recursion: a cycle in the call graph.
    if let Some(cycle) = find_cycle(&calls) {
        let mut text = String::new();
        for pair in cycle.windows(2) {
            let (caller, callee) = (&pair[0], &pair[1]);
            let line = calls[caller][callee];
            let (cname, _) = &display[caller];
            let (ename, _) = &display[callee];
            if !text.is_empty() {
                text.push_str(", ");
            }
            text.push_str(&format!("`{cname}()` calls `{ename}()` at line {line}"));
        }
        errors.push(format!(
            "recursion is not supported on m6809: {text}. Parameters and locals live at fixed RAM addresses \
             (the 6809 cartridge has 1 KB of RAM), so a function cannot be active twice; rewrite it as a loop"
        ));
    }
    if !errors.is_empty() {
        return Err(errors.join("\n"));
    }

    // Overlay: offset(f) = max over callers c of offset(c) + size(c). Roots (main,
    // loop, functions nobody calls) start at 0. The graph is acyclic here, so the
    // memoised recursion terminates.
    let mut callers: HashMap<&str, Vec<&str>> = HashMap::new();
    for (caller, callees) in &calls {
        for callee in callees.keys() {
            callers.entry(callee.as_str()).or_default().push(caller.as_str());
        }
    }
    fn offset_of<'a>(
        f: &'a str,
        callers: &HashMap<&'a str, Vec<&'a str>>,
        frames: &BTreeMap<String, Frame>,
        memo: &mut HashMap<&'a str, usize>,
    ) -> usize {
        if let Some(&o) = memo.get(f) {
            return o;
        }
        let mut o = 0;
        if let Some(cs) = callers.get(f) {
            for &c in cs {
                o = o.max(offset_of(c, callers, frames, memo) + frames[c].size);
            }
        }
        memo.insert(f, o);
        o
    }
    let mut memo: HashMap<&str, usize> = HashMap::new();
    let labels: Vec<String> = frames.keys().cloned().collect();
    let mut offsets: HashMap<String, usize> = HashMap::new();
    for l in &labels {
        offsets.insert(l.clone(), offset_of(l, &callers, &frames, &mut memo));
    }
    let mut pool_size = 0;
    for (l, frame) in frames.iter_mut() {
        frame.offset = offsets[l];
        pool_size = pool_size.max(frame.offset + frame.size);
    }
    Ok(FrameLayout { frames, pool_size })
}

/// A call cycle as a list of labels whose first and last entries are the same
/// function, or None when the call graph is acyclic.
fn find_cycle(calls: &BTreeMap<String, BTreeMap<String, usize>>) -> Option<Vec<String>> {
    #[derive(Clone, Copy, PartialEq)]
    enum State {
        Open,
        Done,
    }
    fn dfs(
        f: &str,
        calls: &BTreeMap<String, BTreeMap<String, usize>>,
        state: &mut HashMap<String, State>,
        path: &mut Vec<String>,
    ) -> Option<Vec<String>> {
        state.insert(f.to_string(), State::Open);
        path.push(f.to_string());
        if let Some(callees) = calls.get(f) {
            for callee in callees.keys() {
                match state.get(callee.as_str()) {
                    Some(State::Open) => {
                        let start = path.iter().position(|p| p == callee).unwrap_or(0);
                        let mut cycle = path[start..].to_vec();
                        cycle.push(callee.clone());
                        return Some(cycle);
                    }
                    Some(State::Done) => {}
                    None => {
                        if let Some(c) = dfs(callee, calls, state, path) {
                            return Some(c);
                        }
                    }
                }
            }
        }
        path.pop();
        state.insert(f.to_string(), State::Done);
        None
    }
    let mut state: HashMap<String, State> = HashMap::new();
    for f in calls.keys() {
        if !state.contains_key(f.as_str()) {
            let mut path = Vec::new();
            if let Some(c) = dfs(f, calls, &mut state, &mut path) {
                return Some(c);
            }
        }
    }
    None
}

#[cfg(test)]
mod tests {
    use super::*;

    fn parse(src: &str) -> Module {
        let tokens = vpy_parser::lex(src).expect("lex");
        vpy_parser::parse_tokens(&tokens, "test.vpy").expect("parse")
    }

    #[test]
    fn caller_and_callee_frames_do_not_overlap() {
        let m = parse(
            "r = 0\n\ndef g(x):\n    return x + 1\n\ndef f(a):\n    t = g(5)\n    return a + t\n\n\
             def main():\n    pass\n\ndef loop():\n    r = f(100)\n",
        );
        let l = analyze(&m).unwrap();
        let f = &l.frames["F"];
        let g = &l.frames["G"];
        let lp = &l.frames["LOOP"];
        assert_eq!(lp.size, 0, "loop only assigns the global r");
        assert_eq!(f.size, 4, "a + t");
        assert_eq!(g.offset, f.offset + f.size, "g is called by f, so it starts after f's frame");
        assert!(f.slot("t").is_some() && f.slot("a").is_some());
        assert_eq!(f.slot("a").unwrap().label, "VAR_F__A");
    }

    #[test]
    fn siblings_share_ram() {
        let m = parse(
            "def a(x):\n    y = x\n    return y\n\ndef b(x):\n    y = x\n    return y\n\n\
             def main():\n    pass\n\ndef loop():\n    a(1)\n    b(2)\n",
        );
        let l = analyze(&m).unwrap();
        assert_eq!(l.frames["A"].offset, l.frames["B"].offset);
        assert_eq!(l.pool_size, 4);
        assert_eq!(l.unshared_size(), 8);
    }

    #[test]
    fn recursion_is_an_error_naming_the_cycle() {
        let m = parse(
            "def a(n):\n    return b(n)\n\ndef b(n):\n    return a(n)\n\ndef main():\n    pass\n\ndef loop():\n    a(1)\n",
        );
        let e = analyze(&m).unwrap_err();
        assert!(e.contains("recursion"), "{e}");
        assert!(e.contains("`a()` calls `b()` at line 2"), "{e}");
        assert!(e.contains("`b()` calls `a()` at line 5"), "{e}");
    }

    #[test]
    fn undefined_name_is_an_error() {
        let m = parse("def main():\n    t = 5\n\ndef loop():\n    x = t\n");
        let e = analyze(&m).unwrap_err();
        assert!(e.contains("`t` is used in `loop()`"), "{e}");
    }
}
