//! VPy → C, for the uvm2 target (`[uvm2] backend = "c"` in the `.vpyproj`).
//!
//! The ARM backend is a stack machine: every operand goes through r0 and the
//! stack, every global through a literal pool and a load. A program the size of a
//! real game comes out about three times bigger than the same game written in C,
//! and a `.um2` runs from the cartridge's SRAM, code and all. This backend writes
//! the unified program as C instead and lets gcc compile it, against the same
//! runtime C games use: libvpy (the SDK's vpy.c, `vpy_run(setup, loop)`) and, for
//! the 3D/effects/jukebox builtins, the C bridge the ARM backend calls too.
//!
//! The semantics are the ARM backend's, construct by construct: every scalar is a
//! 32-bit signed integer that wraps (the file is compiled with `-fwrapv`); `/`
//! and `//` truncate (sdiv), `%` is a - (a / b) * b; comparisons give 0 or 1,
//! `a and b` gives 0 or 1, `a or b` gives 1 when a is true and b otherwise; arrays
//! keep their declared element type (unknown ones are 16-bit, as on ARM); a
//! `for` re-tests `var < end` on every pass and steps by its literal step (1 when
//! the step is not a literal); `switch` compares case by case; strings are
//! pointers held in integers; a function's name is its address.

use crate::arm::three_d::{AssetData, CPart, Lowered};
use crate::m6809::context::VarSize;
use crate::m6809::frames::Frame;
use crate::{AssetInfo, AssetType};
use std::collections::{BTreeMap, BTreeSet, HashMap};
use std::fmt::Write as _;
use vpy_parser::{AssignTarget, BinOp, CallInfo, CmpOp, Expr, Item, LogicOp, Module, Stmt};

/// What the C backend writes: one C file, and what it needs from the build.
pub struct GeneratedC {
    pub c_source: String,
    /// The program calls a jukebox builtin (vpy_jukebox.c goes in).
    pub uses_jukebox: bool,
}

#[derive(Clone)]
enum Global {
    Scalar,
    Array { elem: VarSize, len: usize },
    Strings { len: usize },
}

struct Gen<'a> {
    assets: &'a [AssetInfo],
    consts: HashMap<String, i64>,
    globals: HashMap<String, Global>,
    functions: HashMap<String, usize>,
    /// a struct's field arrays (`TIE__X`, `TIE__Y`, ...) put back together as one C array of
    /// structs: field array → (struct array, member)
    aos: HashMap<String, (String, String)>,
    frames: BTreeMap<String, Frame>,
    /// the slot names (upper case) of the function being written
    cur_slots: BTreeSet<String>,
    /// assets the program names, by kind
    vecs: BTreeSet<String>,
    sfx: BTreeSet<String>,
    music: BTreeSet<String>,
    mesh_data: BTreeSet<String>,
    scenes: BTreeSet<String>,
    /// prototypes of the C functions the builtins call (name → arity)
    externs: BTreeMap<String, usize>,
    tmp: usize,
    errors: Vec<String>,
}

fn up(name: &str) -> String {
    name.to_uppercase()
}

fn c_type(v: VarSize) -> &'static str {
    match (v.bytes, v.signed) {
        (1, false) => "uint8_t",
        (1, true) => "int8_t",
        (2, false) => "uint16_t",
        (2, true) => "int16_t",
        (_, false) => "uint32_t",
        _ => "int32_t",
    }
}

fn c_string(s: &str) -> String {
    let mut out = String::from("\"");
    for b in s.bytes() {
        match b {
            b'"' => out.push_str("\\\""),
            b'\\' => out.push_str("\\\\"),
            b'\n' => out.push_str("\\n"),
            0x20..=0x7e => out.push(b as char),
            _ => {
                let _ = write!(out, "\\{:03o}", b);
            }
        }
    }
    out.push('"');
    out
}

fn asset_sym(name: &str) -> String {
    name.to_uppercase().replace(['-', ' ', '.'], "_")
}

fn bytes_c(name: &str, bytes: &[u8]) -> String {
    let mut s = format!("static const unsigned char {name}[] __attribute__((aligned(4))) = {{\n");
    for chunk in bytes.chunks(16) {
        s.push_str("    ");
        for b in chunk {
            let _ = write!(s, "0x{b:02X},");
        }
        s.push('\n');
    }
    if bytes.is_empty() {
        s.push_str("    0\n");
    }
    s.push_str("};\n");
    s
}

impl<'a> Gen<'a> {
    fn err(&mut self, line: usize, msg: String) {
        self.errors.push(format!("line {line}: {msg}"));
    }

    fn is_local(&self, name: &str) -> bool {
        self.cur_slots.contains(&up(name))
    }

    fn local(name: &str) -> String {
        format!("l_{}", name.to_lowercase())
    }

    // ---- expressions ---------------------------------------------------------

    fn expr(&mut self, e: &Expr) -> String {
        match e {
            Expr::Number(n) => {
                if *n == i32::MIN {
                    "(-2147483647 - 1)".to_string()
                } else {
                    format!("{n}")
                }
            }
            Expr::StringLit(s) => format!("((int32_t)(intptr_t){})", c_string(s)),
            Expr::Ident(id) => self.ident(&id.name, id.source_line),
            Expr::Binary { op, left, right } => {
                let (l, r) = (self.expr(left), self.expr(right));
                binop(*op, &l, &r)
            }
            Expr::Compare { op, left, right } => {
                let (l, r) = (self.expr(left), self.expr(right));
                let o = match op {
                    CmpOp::Eq => "==",
                    CmpOp::Ne => "!=",
                    CmpOp::Lt => "<",
                    CmpOp::Le => "<=",
                    CmpOp::Gt => ">",
                    CmpOp::Ge => ">=",
                };
                format!("((int32_t)({l} {o} {r}))")
            }
            Expr::Logic { op, left, right } => {
                let (l, r) = (self.expr(left), self.expr(right));
                match op {
                    LogicOp::And => format!("((int32_t)(({l}) && ({r})))"),
                    // as on ARM: 1 when the left side is true, else the right side's value
                    LogicOp::Or => format!("(({l}) ? 1 : ({r}))"),
                }
            }
            Expr::Not(x) => format!("((int32_t)!({}))", self.expr(x)),
            Expr::BitNot(x) => format!("(~({}))", self.expr(x)),
            Expr::Index { target, index } => {
                let i = self.expr(index);
                match self.array_access(target, &i) {
                    Ok((lv, strings)) => {
                        if strings {
                            format!("((int32_t)(intptr_t){lv})")
                        } else {
                            format!("((int32_t){lv})")
                        }
                    }
                    Err(m) => {
                        self.errors.push(m);
                        "0".into()
                    }
                }
            }
            Expr::Call(info) => self.call(info),
            Expr::MethodCall(m) => {
                let t = self.expr(&m.target);
                let args: Vec<String> = m.args.iter().map(|a| self.expr(a)).collect();
                match (m.method_name.as_str(), args.as_slice()) {
                    ("abs", []) => format!("vpy_abs({t})"),
                    ("min", [a]) => format!("vpy_min({t}, {a})"),
                    ("max", [a]) => format!("vpy_max({t}, {a})"),
                    ("clamp", [lo, hi]) => format!("vpy_clamp({t}, {lo}, {hi})"),
                    (other, _) => {
                        self.err(m.source_line, format!("unsupported method call .{other}()"));
                        "0".into()
                    }
                }
            }
            Expr::List(_) => {
                self.errors.push("a list is only a global's or a constant's value".into());
                "0".into()
            }
            Expr::StructInit { struct_name, source_line, .. } => {
                self.err(*source_line, format!("`{struct_name}(...)` outside a global's value"));
                "0".into()
            }
            Expr::FieldAccess { field, source_line, .. } => {
                self.err(*source_line, format!("field access `.{field}` was not lowered"));
                "0".into()
            }
        }
    }

    fn ident(&mut self, name: &str, line: usize) -> String {
        let u = up(name);
        if self.is_local(name) {
            return Self::local(name);
        }
        if let Some(v) = self.consts.get(&u) {
            return format!("((int32_t){v})");
        }
        if self.functions.contains_key(&u) {
            if u == "MAIN" || u == "LOOP" {
                self.err(line, format!("`{name}` cannot be used as a value"));
            }
            return format!("((int32_t)(intptr_t)F_{u})");
        }
        match self.globals.get(&u) {
            Some(Global::Scalar) => format!("G_{u}"),
            Some(_) => format!("((int32_t)(intptr_t)G_{u})"),
            None => {
                self.err(line, format!("`{name}` is not defined"));
                "0".into()
            }
        }
    }

    /// The C lvalue of `target[index]`, and whether its elements are strings.
    fn array_access(&mut self, target: &Expr, index: &str) -> Result<(String, bool), String> {
        if let Expr::Ident(id) = target {
            if !self.is_local(&id.name) {
                if let Some((base, member)) = self.aos.get(&up(&id.name)) {
                    return Ok((format!("G_{base}[{index}].{member}"), false));
                }
                match self.globals.get(&up(&id.name)) {
                    Some(Global::Array { .. }) => return Ok((format!("G_{}[{index}]", up(&id.name)), false)),
                    Some(Global::Strings { .. }) => return Ok((format!("G_{}[{index}]", up(&id.name)), true)),
                    _ => {}
                }
            }
        }
        // an address held in a variable: the element type the ARM backend gives it
        let elem = crate::arm::arrays::of(target);
        let base = self.expr(target);
        Ok((format!("(({} *)(intptr_t)({base}))[{index}]", c_type(elem)), false))
    }

    fn need(&mut self, f: &str, arity: usize) {
        self.externs.insert(f.to_string(), arity);
    }

    fn asset_name<'b>(&mut self, info: &'b CallInfo, i: usize, kind: AssetType, what: &str) -> Option<&'b str> {
        match info.args.get(i) {
            Some(Expr::StringLit(s)) => {
                if !self.assets.iter().any(|a| a.asset_type == kind && a.name == *s) {
                    self.err(info.source_line, format!("{what} \"{s}\" not found"));
                }
                Some(s.as_str())
            }
            _ => {
                self.err(info.source_line, format!("`{}()` needs the {what}'s name as a string literal", info.name));
                None
            }
        }
    }

    fn call(&mut self, info: &CallInfo) -> String {
        let u = up(&info.name);
        // a call through a variable holding a function's address
        let indirect = self.is_local(&info.name)
            || (!self.functions.contains_key(&u) && matches!(self.globals.get(&u), Some(Global::Scalar)));
        if indirect {
            let f = self.ident(&info.name, info.source_line);
            let args: Vec<String> = info.args.iter().map(|a| self.expr(a)).collect();
            let ty = vec!["int32_t"; args.len()].join(", ");
            let ty = if ty.is_empty() { "void".to_string() } else { ty };
            return format!("((int32_t (*)({ty}))(intptr_t)({f}))({})", args.join(", "));
        }
        if let Some(&arity) = self.functions.get(&u) {
            if arity != info.args.len() {
                self.err(info.source_line, format!("`{}()` takes {arity} arguments, got {}", info.name, info.args.len()));
            }
            let args: Vec<String> = info.args.iter().map(|a| self.expr(a)).collect();
            return format!("F_{u}({})", args.join(", "));
        }
        // the 3D / effects / jukebox builtins: the C bridge, as from the ARM backend
        if let Some(lowered) = crate::arm::three_d::lower_call(info) {
            return match lowered {
                Err(m) => {
                    self.errors.push(m);
                    "0".into()
                }
                Ok(Lowered::Slot(n)) => format!("((int32_t){n})"),
                Ok(Lowered::Call(c_fn, parts)) => self.bridge_call(c_fn, parts),
            };
        }
        self.core_builtin(info)
    }

    /// `c_fn(a0..a3)` with the arguments past the fourth in vpyx_args[], every
    /// argument evaluated first (a nested builtin uses vpyx_args[] too).
    fn bridge_call(&mut self, c_fn: &str, parts: Vec<CPart>) -> String {
        let mut vals = Vec::new();
        for p in parts {
            vals.push(match p {
                CPart::Expr(e) => self.expr(e),
                CPart::Imm(n) => format!("{n}"),
                CPart::Data(kind, name) => {
                    let s = asset_sym(&name);
                    match kind {
                        AssetData::Vec => {
                            self.vecs.insert(name.clone());
                            format!("((int32_t)(intptr_t){s}_vec)")
                        }
                        AssetData::Mesh => {
                            self.mesh_data.insert(name.clone());
                            format!("((int32_t)(intptr_t){s}_vmesh)")
                        }
                        AssetData::Scene => {
                            self.scenes.insert(name.clone());
                            format!("((int32_t)(intptr_t){s}_vscene)")
                        }
                        AssetData::SceneMeshes => format!("((int32_t)(intptr_t){s}_vscene_meshes)"),
                    }
                }
            });
        }
        self.need(c_fn, vals.len().min(4));
        if vals.len() <= 4 {
            // nothing goes through vpyx_args[]: a plain call
            return format!("((int32_t){c_fn}({}))", vals.join(", "));
        }
        let mut s = String::from("({ ");
        let mut names = Vec::new();
        for v in &vals {
            self.tmp += 1;
            let t = format!("_t{}", self.tmp);
            let _ = write!(s, "int32_t {t} = {v}; ");
            names.push(t);
        }
        for (k, t) in names.iter().enumerate().skip(4) {
            let _ = write!(s, "vpyx_args[{}] = {t}; ", k - 4);
        }
        let regs: Vec<&String> = names.iter().take(4).collect();
        let _ = write!(s, "(int32_t){c_fn}({}); }})", regs.iter().map(|x| x.as_str()).collect::<Vec<_>>().join(", "));
        s
    }

    /// The 2D builtins, on libvpy (vpy.h): the same calls a C game makes.
    fn core_builtin(&mut self, info: &CallInfo) -> String {
        let u = up(&info.name);
        let line = info.source_line;
        let n = info.args.len();
        let arg = |g: &mut Self, i: usize| -> String {
            match info.args.get(i) {
                Some(e) => g.expr(e),
                None => "0".into(),
            }
        };
        let want = |g: &mut Self, k: usize| -> bool {
            if n != k {
                g.err(line, format!("`{}()` takes {k} arguments, got {n}", info.name));
                false
            } else {
                true
            }
        };
        // libvpy functions with only integer arguments: name, C function, arity
        const PLAIN: &[(&str, &str, usize, bool)] = &[
            // (VPy name, C function, arguments, returns a value)
            ("DRAW_LINE", "vpy_draw_line", 5, false),
            ("DRAW_RECT", "vpy_draw_rect", 5, false),
            ("DRAW_FILLED_RECT", "vpy_draw_filled_rect", 5, false),
            ("DRAW_CIRCLE", "vpy_draw_circle", 4, false),
            ("DRAW_ELLIPSE", "vpy_draw_ellipse", 5, false),
            ("MOVE", "vpy_move", 2, false),
            ("SET_INTENSITY", "vpy_set_intensity", 1, false),
            ("SET_TEXT_SIZE", "vpy_set_text_size", 1, false),
            ("PRINT_NUMBER", "vpy_print_number", 3, false),
            ("J1_X", "vpy_j1_x", 0, true),
            ("J1_Y", "vpy_j1_y", 0, true),
            ("STOP_MUSIC", "vpy_stop_music", 0, false),
            ("SQRT", "vpy_sqrt", 1, true),
            ("ABS", "vpy_abs", 1, true),
            ("MIN", "vpy_min", 2, true),
            ("MAX", "vpy_max", 2, true),
            ("CLAMP", "vpy_clamp", 3, true),
            ("SIN", "vpy_sin", 1, true),
            ("COS", "vpy_cos", 1, true),
            ("ATAN2", "vpy_atan2", 2, true),
            ("RAND", "vpy_rand", 0, true),
            ("RAND_RANGE", "vpy_rand_range", 2, true),
            ("BEEP", "vpy_beep", 1, false),
        ];
        if let Some(&(_, f, k, value)) = PLAIN.iter().find(|p| p.0 == u) {
            if !want(self, k) {
                return "0".into();
            }
            let args: Vec<String> = (0..k).map(|i| arg(self, i)).collect();
            let call = format!("{f}({})", args.join(", "));
            return if value { format!("((int32_t){call})") } else { format!("({call}, 0)") };
        }
        match u.as_str() {
            "J1_BUTTON_1" | "J1_BUTTON_2" | "J1_BUTTON_3" | "J1_BUTTON_4" => {
                let k = &u[10..];
                format!("((int32_t)vpy_j1_button({k}))")
            }
            "PRINT_TEXT" => {
                if !want(self, 3) {
                    return "0".into();
                }
                let (x, y, s) = (arg(self, 0), arg(self, 1), arg(self, 2));
                format!("(vpy_print_text({x}, {y}, (const char *)(intptr_t)({s})), 0)")
            }
            "DRAW_VECTOR" | "DRAW_VECTOR_EX" => {
                let k = if u == "DRAW_VECTOR" { 3 } else { 5 };
                if !want(self, k) {
                    return "0".into();
                }
                let Some(name) = self.asset_name(info, 0, AssetType::Vector, "vector") else { return "0".into() };
                self.vecs.insert(name.to_string());
                let rest: Vec<String> = (1..k).map(|i| arg(self, i)).collect();
                let f = if u == "DRAW_VECTOR" { "vpy_draw_vector" } else { "vpy_draw_vector_ex" };
                format!("({f}({}_vec, {}), 0)", asset_sym(name), rest.join(", "))
            }
            "PLAY_SFX" => {
                if !want(self, 1) {
                    return "0".into();
                }
                let Some(name) = self.asset_name(info, 0, AssetType::Sfx, "sound effect") else { return "0".into() };
                self.sfx.insert(name.to_string());
                format!("(vpy_play_sfx({}_sfx), 0)", asset_sym(name))
            }
            "PLAY_MUSIC" => {
                if !want(self, 1) {
                    return "0".into();
                }
                let Some(name) = self.asset_name(info, 0, AssetType::Music, "music") else { return "0".into() };
                self.music.insert(name.to_string());
                format!("(vpy_play_music({}_music), 0)", asset_sym(name))
            }
            "MUL_SHR" => {
                if !want(self, 3) {
                    return "0".into();
                }
                let (a, b, s) = (arg(self, 0), arg(self, 1), arg(self, 2));
                format!("((int32_t)(((int64_t)({a}) * (int64_t)({b})) >> ({s})))")
            }
            "LEN" => match info.args.as_slice() {
                [Expr::Ident(id)] => match self.globals.get(&up(&id.name)) {
                    Some(Global::Array { len, .. }) | Some(Global::Strings { len }) => format!("((int32_t){len})"),
                    _ => {
                        self.err(line, "len() needs the name of a global array".into());
                        "0".into()
                    }
                },
                _ => {
                    self.err(line, "len() needs the name of a global array".into());
                    "0".into()
                }
            },
            // the frame's housekeeping: vpy_run does it every frame already
            "WAIT_RECAL" | "UPDATE_BUTTONS" | "AUDIO_UPDATE" | "MUSIC_UPDATE" => "0".into(),
            _ => {
                self.err(line, format!("`{}()` is not available with the C backend (uvm2) yet", info.name));
                "0".into()
            }
        }
    }

    // ---- statements ----------------------------------------------------------

    fn block(&mut self, body: &[Stmt], out: &mut String, ind: usize) {
        for s in body {
            self.stmt(s, out, ind);
        }
    }

    fn assign_target(&mut self, t: &AssignTarget) -> Option<String> {
        match t {
            AssignTarget::Ident { name, source_line, .. } => {
                let u = up(name);
                if self.is_local(name) {
                    Some(Self::local(name))
                } else if matches!(self.globals.get(&u), Some(Global::Scalar)) {
                    Some(format!("G_{u}"))
                } else {
                    self.err(*source_line, format!("cannot assign to `{name}`"));
                    None
                }
            }
            AssignTarget::Index { target, index, .. } => {
                let i = self.expr(index);
                match self.array_access(target, &i) {
                    Ok((lv, false)) => Some(lv),
                    Ok((_, true)) => {
                        self.errors.push("a table of strings is constant".into());
                        None
                    }
                    Err(m) => {
                        self.errors.push(m);
                        None
                    }
                }
            }
            AssignTarget::FieldAccess { field, source_line, .. } => {
                self.err(*source_line, format!("field access `.{field}` was not lowered"));
                None
            }
        }
    }

    /// A loop variable: a local, or a global scalar of the module. (Names are
    /// case-insensitive: `for k in ...` next to `const K = [...]` would be the table.)
    fn loop_var(&mut self, var: &str, line: usize) -> String {
        if self.is_local(var) {
            return Self::local(var);
        }
        let u = up(var);
        match self.globals.get(&u) {
            Some(Global::Scalar) => format!("G_{u}"),
            Some(_) => {
                self.err(line, format!(
                    "loop variable `{var}` is the array of the same name (names are case-insensitive): rename one of them"
                ));
                "_bad".into()
            }
            None if self.consts.contains_key(&u) => {
                self.err(line, format!(
                    "loop variable `{var}` is the constant of the same name (names are case-insensitive): rename one of them"
                ));
                "_bad".into()
            }
            None => format!("G_{u}"),
        }
    }

    fn stmt(&mut self, s: &Stmt, out: &mut String, ind: usize) {
        let pad = "    ".repeat(ind);
        match s {
            Stmt::Assign { target, value, .. } => {
                let v = self.expr(value);
                if let Some(lv) = self.assign_target(target) {
                    let _ = writeln!(out, "{pad}{lv} = {v};");
                }
            }
            Stmt::Let { name, value, .. } => {
                let v = self.expr(value);
                let lv = if self.is_local(name) { Self::local(name) } else { format!("G_{}", up(name)) };
                let _ = writeln!(out, "{pad}{lv} = {v};");
            }
            Stmt::CompoundAssign { target, op, value, .. } => {
                let v = self.expr(value);
                if let Some(lv) = self.assign_target(target) {
                    // the element's address once: its index may have side effects
                    if matches!(target, AssignTarget::Index { .. }) {
                        self.tmp += 1;
                        let p = format!("_p{}", self.tmp);
                        let _ = writeln!(out, "{pad}{{ __typeof__({lv}) *{p} = &{lv}; *{p} = {}; }}", binop(*op, &format!("(int32_t)*{p}"), &v));
                    } else {
                        let _ = writeln!(out, "{pad}{lv} = {};", binop(*op, &lv, &v));
                    }
                }
            }
            Stmt::Expr(e, _) => {
                if let Expr::Call(info) = e {
                    if up(&info.name) == "MSG_DEF" {
                        return;
                    }
                }
                let v = self.expr(e);
                let _ = writeln!(out, "{pad}(void)({v});");
            }
            Stmt::If { cond, body, elifs, else_body, .. } => {
                let c = self.expr(cond);
                let _ = writeln!(out, "{pad}if ({c}) {{");
                self.block(body, out, ind + 1);
                for (ec, eb) in elifs {
                    let c = self.expr(ec);
                    let _ = writeln!(out, "{pad}}} else if ({c}) {{");
                    self.block(eb, out, ind + 1);
                }
                if let Some(eb) = else_body {
                    let _ = writeln!(out, "{pad}}} else {{");
                    self.block(eb, out, ind + 1);
                }
                let _ = writeln!(out, "{pad}}}");
            }
            Stmt::While { cond, body, .. } => {
                let c = self.expr(cond);
                let _ = writeln!(out, "{pad}while ({c}) {{");
                self.block(body, out, ind + 1);
                let _ = writeln!(out, "{pad}}}");
            }
            Stmt::For { var, start, end, step, body, source_line } => {
                let v = self.loop_var(var, *source_line);
                let (a, b) = (self.expr(start), self.expr(end));
                let st = match step {
                    Some(Expr::Number(n)) => *n,
                    _ => 1,
                };
                let _ = writeln!(out, "{pad}for ({v} = {a}; {v} < {b}; {v} += {st}) {{");
                self.block(body, out, ind + 1);
                let _ = writeln!(out, "{pad}}}");
            }
            Stmt::ForIn { var, iterable, body, source_line } => {
                let v = self.loop_var(var, *source_line);
                let len = match iterable {
                    Expr::Ident(id) => match self.globals.get(&up(&id.name)) {
                        Some(Global::Array { len, .. }) | Some(Global::Strings { len }) => *len,
                        _ => 0,
                    },
                    _ => 0,
                };
                self.tmp += 1;
                let i = format!("_i{}", self.tmp);
                match self.array_access(iterable, &i) {
                    Ok((lv, strings)) => {
                        let _ = writeln!(out, "{pad}for (int32_t {i} = 0; {i} < {len}; {i}++) {{");
                        if strings {
                            let _ = writeln!(out, "{pad}    {v} = (int32_t)(intptr_t){lv};");
                        } else {
                            let _ = writeln!(out, "{pad}    {v} = (int32_t){lv};");
                        }
                        self.block(body, out, ind + 1);
                        let _ = writeln!(out, "{pad}}}");
                    }
                    Err(m) => self.err(*source_line, m),
                }
            }
            Stmt::Switch { expr, cases, default, .. } => {
                let v = self.expr(expr);
                self.tmp += 1;
                let t = format!("_s{}", self.tmp);
                let _ = writeln!(out, "{pad}{{ int32_t {t} = {v};");
                let mut first = true;
                for (ce, cb) in cases {
                    let c = self.expr(ce);
                    let kw = if first { "if" } else { "} else if" };
                    first = false;
                    let _ = writeln!(out, "{pad}{kw} ({t} == {c}) {{");
                    self.block(cb, out, ind + 1);
                }
                if let Some(db) = default {
                    if first {
                        let _ = writeln!(out, "{pad}{{");
                    } else {
                        let _ = writeln!(out, "{pad}}} else {{");
                    }
                    self.block(db, out, ind + 1);
                    let _ = writeln!(out, "{pad}}}");
                } else if !first {
                    let _ = writeln!(out, "{pad}}}");
                }
                let _ = writeln!(out, "{pad}}}");
            }
            Stmt::Return(Some(e), _) => {
                let v = self.expr(e);
                let _ = writeln!(out, "{pad}return {v};");
            }
            Stmt::Return(None, _) => {
                let _ = writeln!(out, "{pad}return 0;");
            }
            Stmt::Break { .. } => {
                let _ = writeln!(out, "{pad}break;");
            }
            Stmt::Continue { .. } => {
                let _ = writeln!(out, "{pad}continue;");
            }
            Stmt::Pass { .. } => {}
        }
    }

    // ---- constant values of globals ----------------------------------------------

    fn const_value(&self, e: &Expr) -> Option<i64> {
        const_eval(e, &self.consts)
    }
}

/// A constant expression's value with 32-bit wrapping arithmetic (the ARM targets'
/// integers), or None.
fn const_eval(e: &Expr, consts: &HashMap<String, i64>) -> Option<i64> {
        Some(match e {
            Expr::Number(n) => *n as i64,
            Expr::Ident(id) => *consts.get(&up(&id.name))?,
            Expr::Binary { op, left, right } => {
                let (a, b) = (const_eval(left, consts)? as i32, const_eval(right, consts)? as i32);
                (match op {
                    BinOp::Add => a.wrapping_add(b),
                    BinOp::Sub => a.wrapping_sub(b),
                    BinOp::Mul => a.wrapping_mul(b),
                    BinOp::Div | BinOp::FloorDiv => {
                        if b == 0 {
                            0
                        } else {
                            a.wrapping_div(b)
                        }
                    }
                    BinOp::Mod => {
                        if b == 0 {
                            a
                        } else {
                            a.wrapping_rem(b)
                        }
                    }
                    BinOp::Shl => a.wrapping_shl(b as u32),
                    BinOp::Shr => a.wrapping_shr(b as u32),
                    BinOp::BitAnd => a & b,
                    BinOp::BitOr => a | b,
                    BinOp::BitXor => a ^ b,
                }) as i64
            }
            Expr::BitNot(x) => !(const_eval(x, consts)? as i32) as i64,
            _ => return None,
        })
}

/// Every scalar `const`, folded (in any order: a const may use one declared later).
fn fold_consts32(module: &Module) -> Result<HashMap<String, i64>, String> {
    let scalars: Vec<(&String, &Expr, usize)> = module
        .items
        .iter()
        .filter_map(|item| match item {
            Item::Const { value: Expr::List(_), .. } => None,
            Item::Const { name, value, source_line, .. } => Some((name, value, *source_line)),
            _ => None,
        })
        .collect();
    let mut values = HashMap::new();
    loop {
        let mut progress = false;
        for (name, value, _) in &scalars {
            let key = up(name);
            if values.contains_key(&key) {
                continue;
            }
            if let Some(v) = const_eval(value, &values) {
                values.insert(key, v);
                progress = true;
            }
        }
        if !progress {
            break;
        }
    }
    let missing: Vec<String> = scalars
        .iter()
        .filter(|(n, _, _)| !values.contains_key(&up(n)))
        .map(|(n, _, line)| format!("line {line}: const `{n}` is not a constant expression"))
        .collect();
    if missing.is_empty() { Ok(values) } else { Err(missing.join("\n")) }
}

fn binop(op: BinOp, l: &str, r: &str) -> String {
    match op {
        BinOp::Add => format!("({l} + {r})"),
        BinOp::Sub => format!("({l} - {r})"),
        BinOp::Mul => format!("({l} * {r})"),
        BinOp::Div | BinOp::FloorDiv => format!("({l} / {r})"),
        BinOp::Mod => format!("({l} % {r})"),
        BinOp::Shl => format!("((int32_t)((uint32_t)({l}) << ({r})))"),
        BinOp::Shr => format!("({l} >> {r})"),
        BinOp::BitAnd => format!("({l} & {r})"),
        BinOp::BitOr => format!("({l} | {r})"),
        BinOp::BitXor => format!("({l} ^ {r})"),
    }
}

/// The unified `module` as one C file for the uvm2 build.
pub fn generate_c(module: &Module, assets: &[AssetInfo]) -> Result<GeneratedC, String> {
    crate::known_functions::register(module);
    crate::arm::three_d::setup(module);
    let consts = fold_consts32(module)?;
    crate::arm::arrays::setup_narrowing(module, Some(&|e: &Expr| const_eval(e, &consts)))?;
    let frames = crate::m6809::frames::function_scopes(module)?;

    let mut g = Gen {
        assets,
        consts,
        globals: HashMap::new(),
        functions: HashMap::new(),
        aos: HashMap::new(),
        frames,
        cur_slots: BTreeSet::new(),
        vecs: BTreeSet::new(),
        sfx: BTreeSet::new(),
        music: BTreeSet::new(),
        mesh_data: BTreeSet::new(),
        scenes: BTreeSet::new(),
        externs: BTreeMap::new(),
        tmp: 0,
        errors: Vec::new(),
    };

    for item in &module.items {
        match item {
            Item::Function(f) => {
                g.functions.insert(up(&f.name), f.params.len());
            }
            Item::GlobalLet { name, value, .. } | Item::Const { name, value, .. } => {
                let u = up(name);
                let kind = match value {
                    Expr::List(v) if !v.is_empty() && v.iter().all(|e| matches!(e, Expr::StringLit(_))) => {
                        Global::Strings { len: v.len() }
                    }
                    Expr::List(v) => Global::Array { elem: crate::arm::arrays::of_global(name), len: v.len() },
                    _ if matches!(item, Item::Const { .. }) => continue, // folded
                    _ => Global::Scalar,
                };
                g.globals.insert(u, kind);
            }
            _ => {}
        }
    }

    // A struct's fields were lowered to one array each (`tie[i].x` -> `TIE__X[i]`): every field
    // then needs its own base address. Put them back as one array of C structs -- one base,
    // fixed offsets, as the C game has them -- when no field array is used as a whole.
    let mut groups: BTreeMap<String, Vec<(String, String)>> = BTreeMap::new();
    {
        let (mut whole, mut indexed) = (HashMap::<String, usize>::new(), HashMap::<String, usize>::new());
        struct Uses<'u> {
            whole: &'u mut HashMap<String, usize>,
            indexed: &'u mut HashMap<String, usize>,
        }
        impl<'a, 'u> crate::m6809::ast_walk::Visitor<'a> for Uses<'u> {
            fn stmt(&mut self, s: &'a Stmt) {
                let t = match s {
                    Stmt::Assign { target: AssignTarget::Index { target, .. }, .. }
                    | Stmt::CompoundAssign { target: AssignTarget::Index { target, .. }, .. } => Some(&**target),
                    Stmt::ForIn { iterable, .. } => Some(iterable),
                    _ => None,
                };
                if let Some(Expr::Ident(id)) = t {
                    *self.indexed.entry(up(&id.name)).or_default() += 1;
                }
            }
            fn expr(&mut self, e: &'a Expr) {
                match e {
                    Expr::Ident(id) => *self.whole.entry(up(&id.name)).or_default() += 1,
                    Expr::Index { target, .. } => {
                        if let Expr::Ident(id) = &**target {
                            *self.indexed.entry(up(&id.name)).or_default() += 1;
                        }
                    }
                    Expr::Call(c) if c.name.eq_ignore_ascii_case("len") => {
                        if let Some(Expr::Ident(id)) = c.args.first() {
                            *self.indexed.entry(up(&id.name)).or_default() += 1;
                        }
                    }
                    _ => {}
                }
            }
        }
        let mut v = Uses { whole: &mut whole, indexed: &mut indexed };
        crate::m6809::ast_walk::walk_code(module, &mut v);
        crate::m6809::ast_walk::walk_global_inits(module, &mut v);
        let mut by_base: BTreeMap<String, Vec<(String, String, usize)>> = BTreeMap::new();
        for item in &module.items {
            let Item::GlobalLet { name, .. } = item else { continue };
            let u = up(name);
            let Some(Global::Array { len, .. }) = g.globals.get(&u) else { continue };
            let Some((base, field)) = u.rsplit_once("__") else { continue };
            if base.is_empty() || field.is_empty() || g.globals.contains_key(base) {
                continue;
            }
            by_base.entry(base.to_string()).or_default().push((u.clone(), field.to_lowercase(), *len));
        }
        for (base, fields) in by_base {
            let same_len = fields.iter().all(|f| f.2 == fields[0].2);
            let only_indexed = fields.iter().all(|f| whole.get(&f.0).copied().unwrap_or(0) <= indexed.get(&f.0).copied().unwrap_or(0));
            let distinct: BTreeSet<&String> = fields.iter().map(|f| &f.0).collect();
            if fields.len() < 2 || !same_len || !only_indexed || distinct.len() != fields.len() {
                continue;
            }
            for (u, member, _) in &fields {
                g.aos.insert(u.clone(), (base.clone(), format!("f_{member}")));
            }
            groups.insert(base, fields.into_iter().map(|(u, m, _)| (u, format!("f_{m}"))).collect());
        }
    }
    let mut emitted_groups = BTreeSet::new();

    // ---- data: globals and constant tables ---------------------------------------
    let mut data = String::new();
    let mut init = String::new(); // values not known at compile time, set before main()
    let mut declared = BTreeSet::new();
    for item in &module.items {
        let (name, value, constant) = match item {
            Item::GlobalLet { name, value, .. } => (name, value, false),
            Item::Const { name, value: value @ Expr::List(_), .. } => (name, value, true),
            _ => continue,
        };
        let u = up(name);
        // declared again: still one variable, the first declaration's (as on ARM)
        if !declared.insert(u.clone()) {
            continue;
        }
        let cq = if constant { "const " } else { "" };
        if let Some((base, _)) = g.aos.get(&u).cloned() {
            // the whole struct array, at its first field
            if emitted_groups.insert(base.clone()) {
                let fields = &groups[&base];
                let mut members = String::new();
                let mut rows: Vec<Vec<String>> = Vec::new();
                let mut n = 0;
                for (fu, member) in fields {
                    let Some(Global::Array { elem, len }) = g.globals.get(fu).cloned() else { continue };
                    n = len;
                    let _ = write!(members, " {} {member};", c_type(elem));
                    let vals = module.items.iter().find_map(|it| match it {
                        Item::GlobalLet { name, value: Expr::List(v), .. } if up(name) == *fu => Some(v.clone()),
                        _ => None,
                    }).unwrap_or_default();
                    for (i, e) in vals.iter().enumerate() {
                        let cv = g.const_value(e);
                        if rows.len() <= i {
                            rows.push(Vec::new());
                        }
                        rows[i].push(cv.unwrap_or(0).to_string());
                        if cv.is_none() {
                            let x = g.expr(e);
                            let _ = writeln!(init, "    G_{base}[{i}].{member} = {x};");
                        }
                    }
                }
                if rows.iter().flatten().all(|v| v == "0") {
                    let _ = writeln!(data, "static struct {{{members} }} G_{base}[{n}];");
                } else {
                    let list: Vec<String> = rows.iter().map(|r| format!("{{ {} }}", r.join(", "))).collect();
                    let _ = writeln!(data, "static struct {{{members} }} G_{base}[{n}] = {{ {} }};", list.join(", "));
                }
            }
            continue;
        }
        match (g.globals.get(&u).cloned(), value) {
            (Some(Global::Strings { len }), Expr::List(v)) => {
                let items: Vec<String> = v
                    .iter()
                    .map(|e| if let Expr::StringLit(s) = e { c_string(s) } else { "0".into() })
                    .collect();
                let _ = writeln!(data, "static const char *const G_{u}[{len}] = {{ {} }};", items.join(", "));
            }
            (Some(Global::Array { elem, len }), Expr::List(v)) => {
                let ty = c_type(elem);
                let vals: Vec<Option<i64>> = v.iter().map(|e| g.const_value(e)).collect();
                if vals.iter().all(|x| x == &Some(0)) {
                    let _ = writeln!(data, "static {cq}{ty} G_{u}[{len}];");
                } else {
                    let list: Vec<String> = vals.iter().map(|x| x.unwrap_or(0).to_string()).collect();
                    let _ = writeln!(data, "static {cq}{ty} G_{u}[{len}] = {{ {} }};", list.join(", "));
                }
                for (i, (e, val)) in v.iter().zip(&vals).enumerate() {
                    if val.is_none() {
                        if constant {
                            g.errors.push(format!("constant `{name}`: element {i} is not a constant"));
                        } else {
                            let x = g.expr(e);
                            let _ = writeln!(init, "    G_{u}[{i}] = {x};");
                        }
                    }
                }
            }
            (Some(Global::Scalar), e) => match g.const_value(e) {
                Some(v) => {
                    let _ = writeln!(data, "static int32_t G_{u} = {};", v as i32);
                }
                None => {
                    let _ = writeln!(data, "static int32_t G_{u};");
                    let x = g.expr(e);
                    let _ = writeln!(init, "    G_{u} = {x};");
                }
            },
            _ => {}
        }
    }

    // ---- functions -----------------------------------------------------------------
    let mut protos = String::new();
    let mut bodies = String::new();
    for item in &module.items {
        let Item::Function(f) = item else { continue };
        let u = up(&f.name);
        let label = vpy_parser::symbols::m6809_label(&f.name);
        let frame = g.frames.get(&label).cloned();
        g.cur_slots = frame
            .as_ref()
            .map(|fr| fr.slots.iter().map(|s| up(&s.name)).collect())
            .unwrap_or_default();
        for p in &f.params {
            g.cur_slots.insert(up(p));
        }
        crate::arm::arrays::enter_function(&f.name, &f.params);
        let params: Vec<String> = f.params.iter().map(|p| format!("int32_t {}", Gen::local(p))).collect();
        let sig = format!(
            "static int32_t F_{u}({})",
            if params.is_empty() { "void".to_string() } else { params.join(", ") }
        );
        let _ = writeln!(protos, "{sig};");
        let _ = writeln!(bodies, "{sig}\n{{");
        let param_set: BTreeSet<String> = f.params.iter().map(|p| up(p)).collect();
        let locals: Vec<String> = g
            .cur_slots
            .iter()
            .filter(|s| !param_set.contains(*s))
            .map(|s| format!("{} = 0", Gen::local(s)))
            .collect();
        if !locals.is_empty() {
            let _ = writeln!(bodies, "    int32_t {};", locals.join(", "));
        }
        let mut body = String::new();
        let start = g.errors.len();
        g.block(&f.body, &mut body, 1);
        crate::origins::locate_new(&mut g.errors, start, &f.name);
        bodies.push_str(&body);
        bodies.push_str("    return 0;\n}\n\n");
    }
    crate::arm::arrays::enter_function("", &[]);

    if !g.functions.contains_key("MAIN") && !g.functions.contains_key("LOOP") {
        g.errors.push("the program has neither main() nor loop()".into());
    }
    if !g.errors.is_empty() {
        let mut seen = BTreeSet::new();
        let errs: Vec<String> = g.errors.into_iter().filter(|e| seen.insert(e.clone())).collect();
        return Err(errs.join("\n"));
    }

    // ---- assets: the images libvpy and vpy3d read (as `vpy_cli compile-asset --format c`) ----
    let path_of = |t: AssetType, n: &str| {
        assets.iter().find(|a| a.asset_type == t && a.name == n).map(|a| std::path::PathBuf::from(&a.path))
    };
    let mut asset_c = String::new();
    let mut mesh_names: BTreeSet<String> = g.mesh_data.clone();
    let mut scene_tables = String::new();
    for name in &g.scenes {
        let path = path_of(AssetType::Scene, name).ok_or_else(|| format!("scene \"{name}\" not found"))?;
        let c = crate::vsceneres::compile_vscene_file_to_bytes(&path).map_err(|e| format!("scene \"{name}\": {e}"))?;
        asset_c.push_str(&bytes_c(&format!("{}_vscene", asset_sym(name)), &c.bytes));
        let list: Vec<String> = c.meshes.iter().map(|m| format!("{}_vmesh", asset_sym(m))).collect();
        let _ = writeln!(
            scene_tables,
            "static const unsigned char *const {}_vscene_meshes[] = {{ {} }};",
            asset_sym(name),
            list.join(", ")
        );
        mesh_names.extend(c.meshes.iter().cloned());
    }
    for name in &mesh_names {
        let path = path_of(AssetType::Mesh, name).ok_or_else(|| format!("mesh \"{name}\" not found"))?;
        let b = crate::vmeshres::compile_vmesh_file_to_bytes(&path).map_err(|e| format!("mesh \"{name}\": {e}"))?;
        asset_c.push_str(&bytes_c(&format!("{}_vmesh", asset_sym(name)), &b));
    }
    asset_c.push_str(&scene_tables);
    for name in &g.vecs {
        let path = path_of(AssetType::Vector, name).ok_or_else(|| format!("vector \"{name}\" not found"))?;
        let b = crate::pitrex::assets::compile_vec_file_to_bytes(&path).map_err(|e| format!("vector \"{name}\": {e}"))?;
        asset_c.push_str(&bytes_c(&format!("{}_vec", asset_sym(name)), &b));
    }
    for name in &g.sfx {
        let path = path_of(AssetType::Sfx, name).ok_or_else(|| format!("sound effect \"{name}\" not found"))?;
        let b = crate::pitrex::assets::compile_vsfx_file_to_bytes(&path).map_err(|e| format!("sfx \"{name}\": {e}"))?;
        asset_c.push_str(&bytes_c(&format!("{}_sfx", asset_sym(name)), &b));
    }
    for name in &g.music {
        let path = path_of(AssetType::Music, name).ok_or_else(|| format!("music \"{name}\" not found"))?;
        let b = crate::pitrex::assets::compile_vmus_file_to_bytes(&path).map_err(|e| format!("music \"{name}\": {e}"))?;
        asset_c.push_str(&bytes_c(&format!("{}_music", asset_sym(name)), &b));
    }

    let uses_jukebox = crate::arm::three_d::uses_jukebox(module);
    let mut c = String::new();
    c.push_str("/* Generated by vpy_cli from a VPy program (the C backend for uvm2): do not edit.\n");
    c.push_str(" * Compiled for size and with wrapping integers, like the ARM backend's arithmetic. */\n");
    c.push_str("#pragma GCC optimize (\"Os\", \"wrapv\", \"no-strict-aliasing\")\n");
    c.push_str("#include <stdint.h>\n#include \"vpy.h\"\n\n");
    c.push_str("extern int32_t vpyx_args[12];\n");
    for (f, arity) in &g.externs {
        let args = vec!["int32_t"; *arity].join(", ");
        let _ = writeln!(c, "extern int32_t {f}({});", if args.is_empty() { "void".to_string() } else { args });
    }
    if uses_jukebox {
        c.push_str("void vpyj_frame(void);\n");
    }
    c.push_str("\n/* ---- assets ---- */\n");
    c.push_str(&asset_c);
    c.push_str("\n/* ---- globals ---- */\n");
    c.push_str(&data);
    c.push_str("\n/* ---- functions ---- */\n");
    c.push_str(&protos);
    c.push('\n');
    c.push_str(&bodies);
    c.push_str("/* ---- the frame: libvpy's vpy_run waits for the beam, reads the buttons and steps\n");
    c.push_str("        the music and effects before every loop() ---- */\n");
    c.push_str("static void vpy_setup(void)\n{\n");
    c.push_str(&init);
    if g.functions.contains_key("MAIN") {
        c.push_str("    F_MAIN();\n");
    }
    c.push_str("}\n\nstatic void vpy_loop(void)\n{\n");
    if uses_jukebox {
        c.push_str("    vpyj_frame();      /* the jukebox: a slice more of the card, the jack topped up */\n");
    }
    if g.functions.contains_key("LOOP") {
        c.push_str("    F_LOOP();\n");
    }
    c.push_str("}\n\nextern void vpyf_install(void);   /* vpy_fault.c: a HardFault that writes its registers and SRAM to the card */\n\nint main(void)\n{\n    vpyf_install();\n    vpy_run(vpy_setup, vpy_loop);\n    return 0;\n}\n");
    Ok(GeneratedC { c_source: c, uses_jukebox })
}
