//! `vpy_cli builtins`: the VPy builtin reference, generated from the compiler itself.
//!
//! - NAMES: every UPPER_SNAKE string literal of the codegen/parser sources
//!   (build.rs) is a candidate. Each candidate is compiled as a call
//!   `NAME(args)` for every target; a backend that rejects it as "not a builtin"
//!   (or "not supported on <target>") does not have it. What compiles is a
//!   builtin on that target. So a builtin added to any backend appears here, with
//!   its real per-target availability, without editing a list.
//! - DOCS: the signature and description come from the builtin tables of
//!   docs/MANUAL.md section 9 (embedded at build time). `MATH_X` / `VECTREX_X`
//!   spellings of a documented `X` are reported as aliases. A builtin with no doc
//!   line is listed under `undocumented` — the tests fail on it.
//!
//! The probe runs each backend's code generator only (no assembler, no linker): a
//! builtin listed for a target is one its code generator accepts. Builtins with a
//! known assembly-time limitation say so in their MANUAL doc line.

use std::collections::{BTreeMap, HashMap};
use vpy_codegen::Target;

pub const TARGETS: [&str; 4] = ["m6809", "rp2350", "uvm2", "pitrex"];

const CANDIDATES: &str = include_str!(concat!(env!("OUT_DIR"), "/builtin_candidates.txt"));
const MANUAL: &str = include_str!("../../../docs/MANUAL.md");

/// One documented row of the MANUAL builtin tables.
#[derive(Debug, Clone)]
pub struct DocEntry {
    pub name: String,
    pub signature: String,
    /// Other signatures documented for the same name (PRINT_TEXT with 5 args...).
    pub alternatives: Vec<String>,
    pub doc: String,
    pub category: String,
    /// Row order in the manual (the reference keeps the manual's order).
    pub order: usize,
}

#[derive(Debug, Clone)]
pub struct Builtin {
    pub name: String,
    pub signature: Option<String>,
    pub alternatives: Vec<String>,
    pub doc: Option<String>,
    pub category: Option<String>,
    pub targets: Vec<&'static str>,
    pub alias_of: Option<String>,
    /// Manual row order (undocumented names sort last).
    pub order: usize,
}

#[derive(Debug, Clone)]
pub struct Catalog {
    pub builtins: Vec<Builtin>,
    /// Builtins a backend accepts that have no doc line (and are no alias).
    pub undocumented: Vec<String>,
    /// MANUAL rows naming a builtin no backend accepts.
    pub documented_but_unavailable: Vec<String>,
    /// Notes of the MANUAL builtin section (`> **Note:**` lines, the general rules).
    pub notes: Vec<String>,
}

// ── MANUAL.md section 9 ────────────────────────────────────────────────────

fn strip_md(s: &str) -> String {
    let s = s.replace("**", "").replace('`', "");
    // [text](link) → text
    let mut out = String::new();
    let mut rest = s.as_str();
    while let Some(i) = rest.find('[') {
        out.push_str(&rest[..i]);
        let after = &rest[i + 1..];
        if let Some(close) = after.find("](") {
            if let Some(end) = after[close + 2..].find(')') {
                out.push_str(&after[..close]);
                rest = &after[close + 2 + end + 1..];
                continue;
            }
        }
        out.push('[');
        rest = after;
    }
    out.push_str(rest);
    out.split_whitespace().collect::<Vec<_>>().join(" ")
}

/// `NAME(args)` → (NAME, args).
fn split_call(item: &str) -> Option<(String, String)> {
    let item = item.trim();
    let open = item.find('(')?;
    if !item.ends_with(')') {
        return None;
    }
    let name = &item[..open];
    if name.is_empty() || !name.chars().all(|c| c.is_ascii_alphanumeric() || c == '_') {
        return None;
    }
    Some((name.to_string(), item[open + 1..item.len() - 1].to_string()))
}

/// Every call the first cell of a table row names, expanded:
/// `GET_X_LEFT()` / `_RIGHT()` → GET_X_LEFT, GET_X_RIGHT; `J2_B_1()` … `J2_B_4()` → J2_B_1..4.
fn calls_in_cell(cell: &str) -> Vec<(String, String)> {
    let mut items: Vec<(String, String, bool)> = Vec::new(); // (name, args, preceded by "…")
    let mut rest = cell;
    let mut pending_range = false;
    while let Some(a) = rest.find('`') {
        let between = &rest[..a];
        if between.contains('…') || between.contains("...") {
            pending_range = true;
        }
        let after = &rest[a + 1..];
        let Some(b) = after.find('`') else { break };
        let item = &after[..b];
        if let Some((name, args)) = split_call(item) {
            let name = if name.starts_with('_') {
                // Suffix shorthand: replace the previous name's last `_SEGMENT`.
                match items.last() {
                    Some((prev, _, _)) => match prev.rfind('_') {
                        Some(i) => format!("{}{}", &prev[..i], name),
                        None => name,
                    },
                    None => name,
                }
            } else {
                name
            };
            items.push((name, args, pending_range));
        }
        pending_range = false;
        rest = &after[b + 1..];
    }
    let mut out: Vec<(String, String)> = Vec::new();
    for (i, (name, args, range)) in items.iter().enumerate() {
        if *range && i > 0 {
            // FOO_1 … FOO_4: add the missing middle members.
            let prev = &items[i - 1].0;
            let split = |s: &str| {
                let d = s.trim_end_matches(|c: char| c.is_ascii_digit()).len();
                (s[..d].to_string(), s[d..].parse::<u32>().ok())
            };
            if let ((p0, Some(a)), (p1, Some(b))) = (split(prev), split(name)) {
                if p0 == p1 && b > a + 1 {
                    for k in a + 1..b {
                        out.push((format!("{p0}{k}"), args.clone()));
                    }
                }
            }
        }
        out.push((name.clone(), args.clone()));
    }
    out
}

/// The builtin tables of MANUAL.md section 9, keyed by upper-case name.
pub fn manual_docs() -> (BTreeMap<String, DocEntry>, Vec<String>) {
    let mut docs: BTreeMap<String, DocEntry> = BTreeMap::new();
    let mut notes = Vec::new();
    let mut in_section = false;
    let mut category = String::new();
    for line in MANUAL.lines() {
        if line.starts_with("## ") {
            in_section = line.contains("Built-in Functions");
            continue;
        }
        if !in_section {
            continue;
        }
        if let Some(h) = line.strip_prefix("#### ").or_else(|| line.strip_prefix("### ")) {
            category = h.trim().to_string();
            continue;
        }
        let t = line.trim();
        if let Some(n) = t.strip_prefix("> ") {
            notes.push(strip_md(n).trim_start_matches("Note:").trim().to_string());
            continue;
        }
        if !t.starts_with('|') || t.starts_with("|--") || t.starts_with("| Function") {
            continue;
        }
        let cells: Vec<&str> = t.trim_matches('|').split(" | ").collect();
        if cells.len() < 2 {
            continue;
        }
        let doc = strip_md(cells[1..].join(" | ").trim());
        for (name, args) in calls_in_cell(cells[0]) {
            let key = name.to_ascii_uppercase();
            let signature = format!("{name}({args})");
            match docs.get_mut(&key) {
                Some(e) => {
                    if e.signature != signature && !e.alternatives.contains(&signature) {
                        e.alternatives.push(signature);
                    }
                }
                None => {
                    let order = docs.len();
                    docs.insert(key, DocEntry { name, signature, alternatives: Vec::new(), doc: doc.clone(), category: category.clone(), order });
                }
            }
        }
    }
    (docs, notes)
}

// ── Probing the backends ──────────────────────────────────────────────────

fn target_of(t: &str) -> Target {
    match t {
        "rp2350" => Target::Rp2350,
        "uvm2" => Target::Uvm2,
        "pitrex" => Target::PiTrex,
        _ => Target::M6809,
    }
}

/// Arguments for a probe call from a documented signature (`"name", x, y[, mirror]`).
fn probe_args(signature_args: Option<&str>, strings: bool) -> String {
    let Some(a) = signature_args else { return String::new() };
    // Drop optional parts and ellipses.
    let mut s = String::new();
    let mut depth = 0;
    for c in a.chars() {
        match c {
            '[' => depth += 1,
            ']' => depth -= 1,
            _ if depth == 0 => s.push(c),
            _ => {}
        }
    }
    s.split(',')
        .map(str::trim)
        .filter(|p| !p.is_empty() && !p.contains("...") && !p.contains('…'))
        .map(|p| if strings && p.starts_with('"') { "\"probe\"".to_string() } else { "1".to_string() })
        .collect::<Vec<_>>()
        .join(", ")
}

/// Codegen of a program whose loop() calls `name(args)`; Err = the compiler's message.
fn compile(name: &str, args: &str, target: &Target) -> Result<String, String> {
    let src = format!("def main():\n    SET_INTENSITY(127)\n\ndef loop():\n    {name}({args})\n");
    let tokens = vpy_parser::lex(&src).map_err(|e| format!("lex: {e}"))?;
    let module = vpy_parser::parser::parse(tokens, "probe.vpy").map_err(|e| format!("parse: {e}"))?;
    let mut modules = HashMap::new();
    modules.insert("probe".to_string(), module);
    let unified = vpy_unifier::unify_modules(modules, "probe").map_err(|e| format!("unify: {e}"))?;
    let cfg = vpy_codegen::BankConfig::single_bank();
    let r = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        vpy_codegen::generate_from_module_with_target(&unified, &cfg, "PROBE", &[], target)
    }));
    match r {
        Ok(Ok(g)) => Ok(g.asm_source),
        Ok(Err(e)) => Err(e.to_string()),
        Err(p) => Err(p
            .downcast_ref::<String>()
            .cloned()
            .or_else(|| p.downcast_ref::<&str>().map(|s| s.to_string()))
            .unwrap_or_else(|| "panic".to_string())),
    }
}

/// Is `name` an identifier for the lexer (not a keyword such as `case` or `as`)?
fn is_identifier(name: &str) -> bool {
    matches!(
        vpy_parser::lex(name).ok().as_deref(),
        Some([t, ..]) if matches!(&t.kind, vpy_parser::lexer::TokenKind::Identifier(_))
    )
}

fn rejects(err: &str, name: &str) -> bool {
    err.contains("is not a builtin")
        || err.contains(&format!("{name} is not supported on"))
        || err.contains(&format!("{name} is not implemented on"))
}

/// Does `target`'s backend accept `name` as a builtin? With no documented
/// signature the arity is unknown: an emitter can skip a wrong-arity call silently,
/// so the name must not be rejected with 0..=6 arguments either.
fn available(name: &str, sig_args: Option<&str>, target_name: &str) -> bool {
    if !available_with(name, sig_args, target_name) {
        return false;
    }
    if sig_args.is_none() {
        let target = target_of(target_name);
        for n in 1..=6 {
            let args = vec!["1"; n].join(", ");
            if let Err(e) = compile(name, &args, &target) {
                if rejects(&e, name) {
                    return false;
                }
            }
        }
    }
    true
}

fn available_with(name: &str, sig_args: Option<&str>, target_name: &str) -> bool {
    let target = target_of(target_name);
    match compile(name, &probe_args(sig_args, true), &target) {
        Ok(asm) => {
            if target != Target::M6809 {
                return true;
            }
            // m6809 also compiles a call to a BIOS routine by name (`JSR NAME`): that is
            // not a builtin.
            if vpy_codegen::m6809::diagnostics::is_bios_symbol(name)
                && asm.contains(&format!("    JSR {}\n", name.to_ascii_uppercase()))
            {
                return false;
            }
            true
        }
        Err(e) if rejects(&e, name) => false,
        // Another error (an argument the probe got wrong, a missing asset): the
        // backend recognised the name. Retry with plain numbers, since a backend
        // can trip on a string argument before it checks the name.
        Err(_) => match compile(name, &probe_args(sig_args, false), &target) {
            Err(e2) if rejects(&e2, name) => false,
            _ => true,
        },
    }
}

/// Probe every candidate on every target and attach the MANUAL docs.
pub fn build_catalog() -> Catalog {
    let (docs, notes) = manual_docs();
    let mut names: Vec<String> = CANDIDATES.lines().map(|s| s.trim().to_string()).filter(|s| !s.is_empty()).collect();
    for k in docs.keys() {
        if !names.contains(k) {
            names.push(k.clone());
        }
    }
    // The probe program defines main() and loop().
    names.retain(|n| n != "MAIN" && n != "LOOP" && is_identifier(n));
    names.sort();
    names.dedup();

    // Probe quietly: backends panic on some bad calls; that is an answer, not output.
    let prev_hook = std::panic::take_hook();
    std::panic::set_hook(Box::new(|_| {}));

    let mut builtins = Vec::new();
    for name in &names {
        let doc = docs.get(name);
        let sig_args = doc.and_then(|d| split_call(&d.signature)).map(|(_, a)| a);
        let targets: Vec<&'static str> =
            TARGETS.iter().copied().filter(|t| available(name, sig_args.as_deref(), t)).collect();
        if targets.is_empty() && doc.is_none() {
            continue;
        }
        let alias_of = if doc.is_none() {
            ["MATH_", "VECTREX_"]
                .iter()
                .find_map(|p| name.strip_prefix(p))
                .filter(|base| docs.contains_key(*base))
                .map(|b| b.to_string())
        } else {
            None
        };
        builtins.push(Builtin {
            name: doc.map(|d| d.name.clone()).unwrap_or_else(|| name.clone()),
            signature: doc.map(|d| d.signature.clone()),
            alternatives: doc.map(|d| d.alternatives.clone()).unwrap_or_default(),
            doc: doc.map(|d| d.doc.clone()),
            category: doc.map(|d| d.category.clone()),
            targets,
            alias_of,
            order: doc.map(|d| d.order).unwrap_or(usize::MAX),
        });
    }
    std::panic::set_hook(prev_hook);
    builtins.sort_by(|a, b| a.order.cmp(&b.order).then_with(|| a.name.cmp(&b.name)));

    let undocumented = builtins
        .iter()
        .filter(|b| b.doc.is_none() && b.alias_of.is_none())
        .map(|b| b.name.clone())
        .collect();
    let documented_but_unavailable = builtins
        .iter()
        .filter(|b| b.doc.is_some() && b.targets.is_empty())
        .map(|b| b.name.clone())
        .collect();
    Catalog { builtins, undocumented, documented_but_unavailable, notes }
}

pub fn catalog_json(c: &Catalog) -> serde_json::Value {
    let builtins: Vec<serde_json::Value> = c
        .builtins
        .iter()
        .map(|b| {
            let mut o = serde_json::json!({
                "name": b.name,
                "targets": b.targets,
            });
            let m = o.as_object_mut().unwrap();
            if let Some(s) = &b.signature { m.insert("signature".into(), s.clone().into()); }
            if !b.alternatives.is_empty() { m.insert("alternatives".into(), b.alternatives.clone().into()); }
            if let Some(d) = &b.doc { m.insert("doc".into(), d.clone().into()); }
            if let Some(k) = &b.category { m.insert("category".into(), k.clone().into()); }
            if let Some(a) = &b.alias_of { m.insert("aliasOf".into(), a.clone().into()); }
            o
        })
        .collect();
    serde_json::json!({
        "ok": true,
        "compiler": env!("CARGO_PKG_VERSION"),
        "targets": TARGETS,
        "source": "names and targets: a call to every candidate compiled for each target by vpy_codegen; docs: docs/MANUAL.md section 9",
        "notes": c.notes,
        "builtins": builtins,
        "undocumented": c.undocumented,
        "documentedButUnavailable": c.documented_but_unavailable,
    })
}

/// The catalog the language server reads (vpy_lsp/src/builtins_catalog.json): name,
/// signatures, doc line, targets, alias. Written by the test below
/// (`VPY_UPDATE_LSP_CATALOG=1 cargo test -p vpy_cli lsp_catalog`), which fails while
/// the file differs from the compiler's builtins.
#[cfg(test)]
pub fn lsp_catalog_json(c: &Catalog) -> String {
    let builtins: Vec<serde_json::Value> = c
        .builtins
        .iter()
        .map(|b| {
            let mut o = serde_json::json!({ "name": b.name, "targets": b.targets });
            let m = o.as_object_mut().unwrap();
            if let Some(s) = &b.signature { m.insert("signature".into(), s.clone().into()); }
            if !b.alternatives.is_empty() { m.insert("alternatives".into(), b.alternatives.clone().into()); }
            if let Some(d) = &b.doc { m.insert("doc".into(), d.clone().into()); }
            if let Some(a) = &b.alias_of { m.insert("aliasOf".into(), a.clone().into()); }
            o
        })
        .collect();
    let mut out = serde_json::to_string_pretty(&serde_json::json!({
        "source": "generated by vpy_cli (builtins_catalog.rs, lsp_catalog_json) from the compiler: do not edit",
        "builtins": builtins,
    }))
    .unwrap();
    out.push('\n');
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    /// The language server's copy of the builtins is the compiler's: a builtin added to a
    /// backend (or a signature changed in docs/MANUAL.md) shows up in the editor only
    /// once the file is regenerated, so this fails until it is.
    #[test]
    fn lsp_catalog_is_current() {
        let path = std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("../vpy_lsp/src/builtins_catalog.json");
        let want = lsp_catalog_json(&build_catalog());
        if std::env::var_os("VPY_UPDATE_LSP_CATALOG").is_some() {
            std::fs::write(&path, &want).unwrap();
            return;
        }
        let have = std::fs::read_to_string(&path).unwrap_or_default();
        assert!(
            have == want,
            "{} is out of date: run `VPY_UPDATE_LSP_CATALOG=1 cargo test -p vpy_cli lsp_catalog`",
            path.display()
        );
    }

    #[test]
    fn manual_rows_expand_shorthands() {
        let (docs, _) = manual_docs();
        assert!(docs.contains_key("DRAW_LINE"));
        assert!(docs.contains_key("GET_SCROLL_LIMIT_RIGHT"), "suffix shorthand `_RIGHT()`");
        assert!(docs.contains_key("J2_BUTTON_2"), "range `J2_BUTTON_1()` … `J2_BUTTON_4()`");
        assert!(docs["PRINT_TEXT"].alternatives.len() >= 1);
    }

    /// Every builtin a backend accepts has a doc line in docs/MANUAL.md section 9
    /// (or is a MATH_/VECTREX_ alias of one), and the manual names no builtin that
    /// no backend has. Add the row to MANUAL.md when a builtin is added.
    #[test]
    fn every_builtin_is_documented_and_every_doc_is_a_builtin() {
        let c = build_catalog();
        assert!(c.builtins.len() > 60, "only {} builtins found", c.builtins.len());
        assert!(c.undocumented.is_empty(), "builtins with no doc line in docs/MANUAL.md section 9: {:?}", c.undocumented);
        assert!(
            c.documented_but_unavailable.is_empty(),
            "docs/MANUAL.md section 9 documents calls no backend accepts: {:?}",
            c.documented_but_unavailable
        );
        let get = |n: &str| c.builtins.iter().find(|b| b.name.eq_ignore_ascii_case(n)).unwrap_or_else(|| panic!("{n} missing"));
        assert_eq!(get("DRAW_LINE").targets, TARGETS.to_vec());
        assert!(!get("PLAY_SAMPLE").targets.contains(&"m6809"), "PLAY_SAMPLE is rejected on m6809");
    }
}
