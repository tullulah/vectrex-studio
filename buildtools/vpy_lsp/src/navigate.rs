//! Go to definition, resolved on the parser's AST with the compiler's name rules
//! (`vpy_codegen` m6809/frames.rs): inside a function a parameter comes first, then
//! a module-level name (global, const, enum member, function, struct), then a local
//! (the first statement that assigns it). Also:
//! - `module.name` → `name` in that module's file (`import module [as alias]`);
//! - the module of an `import` / `from … import` line → its file, an imported name →
//!   its definition there;
//! - `value.field` → the field of the one struct that has it;
//! - a string naming an asset (`DRAW_VECTOR("ship")`) → the project's asset file.

use std::path::{Path, PathBuf};

use tower_lsp::lsp_types::{Location, Position, Range, Url};
use vpy_parser::{lex, parse_tokens, AssignTarget, Function, ImportSymbols, Item, Module, Stmt};

use crate::diagnostics::resolve_module_path;

/// Reads a document: the editor's text when it is open, else the file on disk.
pub type Reader<'a> = dyn Fn(&Url) -> Option<String> + 'a;

fn parse(text: &str, uri: &Url) -> Option<Module> {
    let tokens = lex(text).ok()?;
    parse_tokens(&tokens, uri.path()).ok()
}

fn is_word(c: char) -> bool {
    c.is_alphanumeric() || c == '_'
}

/// The range of `name` as a whole word on 1-based `line1`, searched from `from_col`.
fn name_range(text: &str, line1: usize, name: &str, from_col: usize) -> Range {
    let line = text.lines().nth(line1.saturating_sub(1)).unwrap_or("");
    let chars: Vec<char> = line.chars().collect();
    let target: Vec<char> = name.chars().collect();
    let at = |i: usize, case: bool| {
        i + target.len() <= chars.len()
            && chars[i..i + target.len()].iter().zip(&target).all(|(a, b)| if case { a == b } else { a.eq_ignore_ascii_case(b) })
            && (i == 0 || !is_word(chars[i - 1]))
            && chars.get(i + target.len()).is_none_or(|c| !is_word(*c))
    };
    let col = (from_col..chars.len())
        .find(|&i| at(i, true))
        .or_else(|| (from_col..chars.len()).find(|&i| at(i, false)));
    let l = line1.saturating_sub(1) as u32;
    match col {
        Some(c) => Range {
            start: Position { line: l, character: c as u32 },
            end: Position { line: l, character: (c + target.len()) as u32 },
        },
        None => Range { start: Position { line: l, character: 0 }, end: Position { line: l, character: 0 } },
    }
}

fn location(uri: &Url, text: &str, line1: usize, name: &str, from_col: usize) -> Location {
    Location { uri: uri.clone(), range: name_range(text, line1, name, from_col) }
}

fn file_start(uri: Url) -> Location {
    Location { uri, range: Range::default() }
}

fn same(a: &str, b: &str) -> bool {
    a.eq_ignore_ascii_case(b)
}

/// The line of a module-level definition of `name`.
fn top_level(module: &Module, name: &str) -> Option<usize> {
    let exact = |n: &str| n == name;
    let loose = |n: &str| same(n, name);
    for m in [&exact as &dyn Fn(&str) -> bool, &loose] {
        for item in &module.items {
            let hit = match item {
                Item::Function(f) if m(&f.name) => Some(f.line),
                Item::Const { name: n, source_line, .. } | Item::GlobalLet { name: n, source_line, .. } if m(n) => Some(*source_line),
                Item::StructDef(s) if m(&s.name) => Some(s.source_line),
                _ => None,
            };
            if hit.is_some() {
                return hit;
            }
        }
    }
    None
}

/// Every function body of the module: top-level functions, struct methods and constructors.
fn functions(module: &Module) -> Vec<(&Function, Option<&vpy_parser::StructDef>)> {
    let mut out = Vec::new();
    for item in &module.items {
        match item {
            Item::Function(f) => out.push((f, None)),
            Item::StructDef(s) => {
                for f in s.methods.iter().chain(s.constructor.iter()) {
                    out.push((f, Some(s)));
                }
            }
            _ => {}
        }
    }
    out
}

fn indent(line: &str) -> usize {
    line.chars().take_while(|c| c.is_whitespace()).count()
}

/// Is 1-based `line1` inside the function whose `def` is on `def1` (its indented block)?
fn in_block(text: &str, def1: usize, line1: usize) -> bool {
    if line1 < def1 {
        return false;
    }
    let lines: Vec<&str> = text.lines().collect();
    let Some(def) = lines.get(def1 - 1) else { return false };
    let base = indent(def);
    for l in def1..line1 {
        let t = lines.get(l).copied().unwrap_or("");
        let trimmed = t.trim();
        if !trimmed.is_empty() && !trimmed.starts_with('#') && indent(t) <= base {
            return false;
        }
    }
    true
}

/// The innermost function (or method) containing 1-based `line1`.
fn enclosing<'m>(module: &'m Module, text: &str, line1: usize) -> Option<(&'m Function, Option<&'m vpy_parser::StructDef>)> {
    functions(module)
        .into_iter()
        .filter(|(f, _)| f.line <= line1 && in_block(text, f.line, line1))
        .max_by_key(|(f, _)| f.line)
}

/// The first statement of `body` that makes `name` a local (assignment, `let`, loop variable).
fn first_assignment(body: &[Stmt], name: &str) -> Option<usize> {
    let mut best: Option<usize> = None;
    let mut note = |l: usize| best = Some(best.map_or(l, |b| b.min(l)));
    for s in body {
        match s {
            Stmt::Let { name: n, source_line, .. } if same(n, name) => note(*source_line),
            Stmt::Assign { target: AssignTarget::Ident { name: n, source_line, .. }, .. }
            | Stmt::CompoundAssign { target: AssignTarget::Ident { name: n, source_line, .. }, .. }
                if same(n, name) => note(*source_line),
            Stmt::For { var, source_line, .. } | Stmt::ForIn { var, source_line, .. } if same(var, name) => note(*source_line),
            _ => {}
        }
        let nested: Vec<&[Stmt]> = match s {
            Stmt::For { body, .. } | Stmt::ForIn { body, .. } | Stmt::While { body, .. } => vec![body],
            Stmt::If { body, elifs, else_body, .. } => {
                let mut v: Vec<&[Stmt]> = vec![body];
                v.extend(elifs.iter().map(|(_, b)| b.as_slice()));
                v.extend(else_body.iter().map(|b| b.as_slice()));
                v
            }
            Stmt::Switch { cases, default, .. } => {
                let mut v: Vec<&[Stmt]> = cases.iter().map(|(_, b)| b.as_slice()).collect();
                v.extend(default.iter().map(|b| b.as_slice()));
                v
            }
            _ => vec![],
        };
        for b in nested {
            if let Some(l) = first_assignment(b, name) {
                note(l);
            }
        }
    }
    best
}

/// The file of an imported module (`a.b`, `.sibling`) seen from `uri`.
fn module_uri(uri: &Url, module_path: &str) -> Option<Url> {
    let path = uri.to_file_path().ok()?;
    let file = resolve_module_path(module_path, path.parent()?)?;
    Url::from_file_path(file).ok()
}

fn import_path(decl: &vpy_parser::ImportDecl) -> String {
    ".".repeat(if decl.is_relative { decl.relative_level.max(1) } else { 0 }) + &decl.module_path.join(".")
}

/// `name` defined in another module's file (parsed; a file that does not parse is
/// searched by its `def` / assignment lines).
fn definition_in(target: Url, name: &str, read: &Reader) -> Location {
    let Some(text) = read(&target) else { return file_start(target) };
    if let Some(module) = parse(&text, &target) {
        if let Some(l) = top_level(&module, name) {
            return location(&target, &text, l, name, 0);
        }
        return file_start(target);
    }
    for (i, line) in text.lines().enumerate() {
        let t = line.trim_start();
        let head = t.strip_prefix("def ").or_else(|| t.strip_prefix("const ")).unwrap_or(t);
        if indent(line) == 0 && head.starts_with(name) && !head[name.len()..].starts_with(is_word) {
            return location(&target, &text, i + 1, name, 0);
        }
    }
    file_start(target)
}

/// The word under the cursor and what is written just before it (`x.` qualifier;
/// empty after `]` or `)`).
struct Word {
    name: String,
    qualifier: Option<String>,
    /// Followed by `.`: a module or a struct value, not a value of its own.
    dotted: bool,
}

fn word_at(line: &str, col: usize) -> Option<Word> {
    let chars: Vec<char> = line.chars().collect();
    let col = col.min(chars.len());
    let (mut s, mut e) = (col, col);
    while s > 0 && is_word(chars[s - 1]) {
        s -= 1;
    }
    while e < chars.len() && is_word(chars[e]) {
        e += 1;
    }
    if s >= e {
        return None;
    }
    let qualifier = if s > 0 && chars[s - 1] == '.' {
        let qe = s - 1;
        let mut qs = qe;
        while qs > 0 && is_word(chars[qs - 1]) {
            qs -= 1;
        }
        // `a[i].x`, `f().x`: a member of some value (an empty qualifier)
        Some(chars[qs..qe].iter().collect())
    } else {
        None
    };
    Some(Word { name: chars[s..e].iter().collect(), qualifier, dotted: chars.get(e) == Some(&'.') })
}

/// The string literal around the cursor, if any (no escapes in VPy strings).
fn string_at(line: &str, col: usize) -> Option<String> {
    let chars: Vec<char> = line.chars().collect();
    let mut open: Option<(usize, char)> = None;
    for (i, &c) in chars.iter().enumerate() {
        match open {
            None if c == '#' => return None,
            None if c == '"' || c == '\'' => open = Some((i, c)),
            Some((start, q)) if c == q => {
                if start < col && col <= i {
                    return Some(chars[start + 1..i].iter().collect());
                }
                open = None;
            }
            _ => {}
        }
    }
    None
}

/// The project directory of a source file: the parent of its `src/`, else its own folder.
fn project_dir(uri: &Url) -> Option<PathBuf> {
    let path = uri.to_file_path().ok()?;
    let dir = path.parent()?;
    let mut d = Some(dir);
    while let Some(x) = d {
        if x.file_name().is_some_and(|n| n == "src") {
            return x.parent().map(Path::to_path_buf);
        }
        d = x.parent();
    }
    Some(dir.to_path_buf())
}

/// An asset of the project named `name` (its file stem), under `assets/`.
fn asset_file(uri: &Url, name: &str) -> Option<Url> {
    if name.is_empty() || name.contains(['/', '\\']) {
        return None;
    }
    let root = project_dir(uri)?.join("assets");
    let mut stack = vec![root];
    let mut found: Vec<PathBuf> = Vec::new();
    while let Some(dir) = stack.pop() {
        let Ok(entries) = std::fs::read_dir(&dir) else { continue };
        for e in entries.flatten() {
            let p = e.path();
            if p.is_dir() {
                stack.push(p);
            } else if p.file_stem().is_some_and(|s| s.to_string_lossy().eq_ignore_ascii_case(name)) {
                found.push(p);
            }
        }
    }
    found.sort();
    Url::from_file_path(found.first()?).ok()
}

/// Go to the definition of what is under `pos`.
pub fn definition(text: &str, pos: Position, uri: &Url, read: &Reader) -> Option<Location> {
    let line_text = text.lines().nth(pos.line as usize)?;
    let col = pos.character as usize;
    let line1 = pos.line as usize + 1;

    if let Some(s) = string_at(line_text, col) {
        return asset_file(uri, &s).map(file_start);
    }
    let word = word_at(line_text, col)?;
    let module = parse(text, uri)?;

    // An import line: its module, or a name it imports
    if let Some(decl) = module.imports.iter().find(|d| d.source_line == line1) {
        let target = module_uri(uri, &import_path(decl))?;
        if let ImportSymbols::Named(names) = &decl.symbols {
            if let Some(s) = names.iter().find(|s| s.name == word.name || s.alias.as_deref() == Some(&word.name)) {
                return Some(definition_in(target, &s.name, read));
            }
        }
        return Some(file_start(target));
    }

    // `import x [as y]` names: the module, or `module.name`
    let module_named = |n: &str| {
        module.imports.iter().find_map(|d| match &d.symbols {
            ImportSymbols::Module { alias } if alias.as_deref().unwrap_or(d.module_path.last()?.as_str()) == n => {
                module_uri(uri, &import_path(d))
            }
            _ => None,
        })
    };
    let here = enclosing(&module, text, line1);

    if let Some(q) = &word.qualifier {
        if let Some(target) = module_named(q) {
            return Some(definition_in(target, &word.name, read));
        }
        // A field of the one struct that has it (struct variables are globals)
        let in_struct = |s: &vpy_parser::StructDef| s.fields.iter().find(|f| same(&f.name, &word.name)).map(|f| f.source_line);
        let hits: Vec<usize> = module.items.iter().filter_map(|i| match i {
            Item::StructDef(s) => in_struct(s),
            _ => None,
        }).collect();
        return (hits.len() == 1).then(|| location(uri, text, hits[0], &word.name, 0));
    }
    if word.dotted {
        if let Some(target) = module_named(&word.name) {
            return Some(file_start(target));
        }
    }

    // Inside a function: its parameters, then module-level names, then its locals
    if let Some((f, _)) = here {
        if f.params.iter().any(|p| same(p, &word.name)) {
            let def = text.lines().nth(f.line - 1).unwrap_or("");
            let paren = def.find('(').map(|i| def[..i].chars().count()).unwrap_or(0);
            return Some(location(uri, text, f.line, &word.name, paren));
        }
    }
    if let Some(l) = top_level(&module, &word.name) {
        return Some(location(uri, text, l, &word.name, 0));
    }
    if let Some((f, _)) = here {
        if let Some(l) = first_assignment(&f.body, &word.name) {
            return Some(location(uri, text, l, &word.name, 0));
        }
    }

    // `from m import name [as alias]`
    for d in &module.imports {
        if let ImportSymbols::Named(names) = &d.symbols {
            if let Some(s) = names.iter().find(|s| s.alias.as_deref().unwrap_or(&s.name) == word.name) {
                let target = module_uri(uri, &import_path(d))?;
                return Some(definition_in(target, &s.name, read));
            }
        }
    }
    None
}

/// The reader the server uses: open documents first, then the disk.
pub fn read_with<'a>(open: &'a std::collections::HashMap<Url, String>) -> impl Fn(&Url) -> Option<String> + 'a {
    move |u: &Url| open.get(u).cloned().or_else(|| std::fs::read_to_string(u.to_file_path().ok()?).ok())
}
