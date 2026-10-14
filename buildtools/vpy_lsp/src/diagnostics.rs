//! Document diagnostics: lexer/parser errors from `vpy_parser` (the same
//! front end the compiler uses), import resolution, builtin arity checks,
//! unknown-function checks and variable usage hints.

use std::collections::HashSet;
use std::path::{Path, PathBuf};

use tower_lsp::lsp_types::{Diagnostic, DiagnosticSeverity, Position, Range, Url};
use vpy_parser::{lex, parse_tokens};

use crate::analysis::{analyze_variable_usage, generate_usage_diagnostics, ExternalUse};
use crate::builtins::{is_python_keyword_or_builtin, tr};

/// A front-end error resolved to a 0-based document position.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ErrorLocation {
    pub line: u32,
    pub col: u32,
    pub message: String,
}

fn indent_of(text: &str, line: u32) -> u32 {
    text.lines()
        .nth(line as usize)
        .map(|l| l.chars().take_while(|c| *c == ' ').count() as u32)
        .unwrap_or(0)
}

fn line_len(text: &str, line: u32) -> u32 {
    text.lines().nth(line as usize).map(|l| l.chars().count() as u32).unwrap_or(0)
}

/// Convert a 1-based line reported by the front end into a 0-based document
/// line. Line 0 is what `vpy_parser` reports for EOF-synthesized tokens, so it
/// maps to the last line of the document.
fn doc_line(text: &str, line1: u32) -> u32 {
    if line1 == 0 {
        text.lines().count().saturating_sub(1) as u32
    } else {
        line1 - 1
    }
}

/// Clamp a column (relative to the trimmed line) to the document line, adding
/// back the indentation the lexer strips before tokenizing.
fn doc_col(text: &str, line: u32, trimmed_col: u32) -> u32 {
    (indent_of(text, line) + trimmed_col).min(line_len(text, line))
}

/// Parse a parser error of the form
///   `<path possibly containing colons>:<line>:<col>: error: <detail>`
/// where `<col>` is a 0-based column inside the indentation-stripped line.
/// The sentinel `": error:"` is located first and the numbers are read
/// backwards, so Windows drive letters in the path don't confuse it.
pub fn parse_error_line_col(msg: &str, text: &str) -> Option<ErrorLocation> {
    let err_idx = msg.find(": error:")?;
    let prefix = &msg[..err_idx];
    let colon2 = prefix.rfind(':')?;
    let col: u32 = prefix[colon2 + 1..].trim().parse().ok()?;
    let prefix2 = &prefix[..colon2];
    let colon1 = prefix2.rfind(':')?;
    let line1: u32 = prefix2[colon1 + 1..].trim().parse().ok()?;
    let line = doc_line(text, line1);
    Some(ErrorLocation {
        line,
        col: doc_col(text, line, col),
        message: msg[err_idx + ": error:".len()..].trim().to_string(),
    })
}

/// Parse a lexer error. `vpy_parser::lex` reports two shapes:
///   `"<message> (line N)"`            (indentation errors)
///   `"<message> ... line N:C ..."`   (character/string errors, C is 1-based
///                                      inside the indentation-stripped line)
pub fn parse_lexer_error(msg: &str, text: &str) -> Option<ErrorLocation> {
    if let Some(line_start) = msg.rfind("(line ") {
        let line_part = &msg[line_start + 6..];
        if let Some(close_paren) = line_part.find(')') {
            if let Ok(line1) = line_part[..close_paren].parse::<u32>() {
                return Some(ErrorLocation {
                    line: doc_line(text, line1),
                    col: 0,
                    message: msg[..line_start].trim().to_string(),
                });
            }
        }
    }

    let line_start = msg.rfind("line ")?;
    let rest = &msg[line_start + 5..];
    let line_digits: String = rest.chars().take_while(|c| c.is_ascii_digit()).collect();
    let line1: u32 = line_digits.parse().ok()?;
    let after_line = &rest[line_digits.len()..];
    let col_src = after_line
        .strip_prefix(':')
        .or_else(|| after_line.strip_prefix(" col "));
    let col1: u32 = col_src
        .map(|s| s.chars().take_while(|c| c.is_ascii_digit()).collect::<String>())
        .and_then(|d| d.parse().ok())
        .unwrap_or(1);
    let line = doc_line(text, line1);
    Some(ErrorLocation {
        line,
        col: doc_col(text, line, col1.saturating_sub(1)),
        message: msg.to_string(),
    })
}

fn error_diagnostic(range: Range, message: String) -> Diagnostic {
    Diagnostic {
        range,
        severity: Some(DiagnosticSeverity::ERROR),
        code: None,
        code_description: None,
        source: Some("vpy".into()),
        message,
        related_information: None,
        tags: None,
        data: None,
    }
}

fn whole_line(line_num: u32, line: &str) -> Range {
    Range {
        start: Position { line: line_num, character: 0 },
        end: Position { line: line_num, character: line.len() as u32 },
    }
}

/// Resolve a module path (`utils`, `utils.math`, `.sibling`, `..parent.mod`)
/// relative to `current_dir`. Absolute imports are searched from the nearest
/// enclosing `src/` directory. Returns the `.vpy` file or package
/// `__init__.vpy` that exists on disk.
pub fn resolve_module_path(module_path: &str, current_dir: &Path) -> Option<PathBuf> {
    let (is_relative, level, path_str) = if module_path.starts_with('.') {
        let level = module_path.chars().take_while(|c| *c == '.').count();
        (true, level, module_path.trim_start_matches('.'))
    } else {
        (false, 0, module_path)
    };

    let mut target_dir = current_dir.to_path_buf();

    if is_relative {
        // One dot = current dir; each extra dot goes one level up.
        for _ in 1..level {
            target_dir = target_dir.parent()?.to_path_buf();
        }
    } else {
        let mut search_dir = current_dir.to_path_buf();
        while !search_dir.ends_with("src") && search_dir.parent().is_some() {
            search_dir = search_dir.parent().unwrap().to_path_buf();
        }
        if search_dir.ends_with("src") {
            target_dir = search_dir;
        }
    }

    for part in path_str.split('.') {
        if !part.is_empty() {
            target_dir = target_dir.join(part);
        }
    }

    let with_ext = target_dir.with_extension("vpy");
    if with_ext.exists() {
        return Some(with_ext);
    }
    let init_file = target_dir.join("__init__.vpy");
    if init_file.exists() {
        return Some(init_file);
    }
    None
}

/// Validate `from X import Y` / `import X` lines.
fn validate_import_statement(uri: &Url, line: &str, line_num: u32, diags: &mut Vec<Diagnostic>) {
    let trimmed = line.trim();

    if let Some(after_from) = trimmed.strip_prefix("from ") {
        let parts: Vec<&str> = after_from.splitn(2, " import ").collect();
        if parts.len() == 2 {
            let module_path = parts[0].trim();
            if let Ok(current_path) = uri.to_file_path() {
                if let Some(current_dir) = current_path.parent() {
                    if resolve_module_path(module_path, current_dir).is_none() {
                        diags.push(error_diagnostic(
                            Range {
                                start: Position { line: line_num, character: 5 },
                                end: Position { line: line_num, character: 5 + module_path.len() as u32 },
                            },
                            format!("Cannot resolve module '{}'. Check that the file exists.", module_path),
                        ));
                    }
                }
            }
        } else if !after_from.contains(" import ") {
            diags.push(error_diagnostic(
                whole_line(line_num, line),
                "Invalid import syntax. Use: from module import symbol".to_string(),
            ));
        }
    }

    if trimmed.starts_with("import ") && !trimmed.contains(" as ") {
        if let Some(module_name) = trimmed.strip_prefix("import ") {
            if module_name.trim().is_empty() {
                diags.push(error_diagnostic(
                    whole_line(line_num, line),
                    "Missing module name after 'import'".to_string(),
                ));
            }
        }
    }
}

/// Calls whose name the compiler would not know, and builtins called with an argument
/// count no form of theirs takes — from the parsed module, every call node (the
/// compiler's own AST walker), against the compiler's builtin catalog (catalog.rs).
///
/// Only what this file can tell: a `module.function()` call is the compiler's to check
/// (it sees every module of the project), and so is whether a builtin exists on the
/// selected target. A lowercase name must be a function, struct or variable of this
/// file or imported by name (`from m import *` turns that check off); an UPPERCASE
/// one must be a builtin.
fn check_calls(module: &vpy_parser::Module, text: &str, locale: &str, diags: &mut Vec<Diagnostic>) {
    use vpy_codegen::m6809::ast_walk::{walk_module, Visitor};
    use vpy_parser::{AssignTarget, Expr, ImportSymbols, Item, Stmt};

    // Every name this file binds (case-insensitive, as VPy names are)
    let mut known: HashSet<String> = HashSet::new();
    let mut star_import = false;
    for imp in &module.imports {
        match &imp.symbols {
            ImportSymbols::All => star_import = true,
            ImportSymbols::Named(list) => {
                for sym in list {
                    known.insert(sym.alias.as_ref().unwrap_or(&sym.name).to_ascii_uppercase());
                }
            }
            ImportSymbols::Module { .. } => {}
        }
    }
    for item in &module.items {
        match item {
            Item::Function(f) => {
                known.insert(f.name.to_ascii_uppercase());
                known.extend(f.params.iter().map(|p| p.to_ascii_uppercase()));
            }
            Item::StructDef(st) => { known.insert(st.name.to_ascii_uppercase()); }
            Item::Const { name, .. } | Item::GlobalLet { name, .. } | Item::VectorList { name, .. } => {
                known.insert(name.to_ascii_uppercase());
            }
            _ => {}
        }
    }

    struct Calls<'a> { calls: Vec<&'a vpy_parser::CallInfo>, bound: Vec<String> }
    impl<'a> Visitor<'a> for Calls<'a> {
        fn stmt(&mut self, stmt: &'a Stmt) {
            match stmt {
                Stmt::Let { name, .. } => self.bound.push(name.clone()),
                Stmt::Assign { target: AssignTarget::Ident { name, .. }, .. } => self.bound.push(name.clone()),
                Stmt::For { var, .. } | Stmt::ForIn { var, .. } => self.bound.push(var.clone()),
                _ => {}
            }
        }
        fn expr(&mut self, expr: &'a Expr) {
            if let Expr::Call(info) = expr {
                self.calls.push(info);
            }
        }
    }
    let mut v = Calls { calls: Vec::new(), bound: Vec::new() };
    walk_module(module, &mut v);
    known.extend(v.bound.iter().map(|n| n.to_ascii_uppercase()));

    let lines: Vec<&str> = text.lines().collect();
    for call in v.calls {
        let name = call.name.as_str();
        if name.is_empty() || name.contains('.') || is_python_keyword_or_builtin(name) {
            continue;
        }
        let upper = name.to_ascii_uppercase();
        let line = call.source_line.saturating_sub(1) as u32;
        let line_txt = lines.get(line as usize).copied().unwrap_or("");
        // the name where it is written (the parser's column leaves the indentation out)
        let range = match line_txt.find(&format!("{name}(")) {
            Some(at) => Range {
                start: Position { line, character: at as u32 },
                end: Position { line, character: (at + name.len()) as u32 },
            },
            None => whole_line(line, line_txt),
        };
        if let Some(b) = crate::catalog::lookup(name) {
            if let Some(counts) = crate::catalog::accepted_counts(b) {
                let n = call.args.len();
                if !counts.contains(&n) {
                    let expected = counts.iter().map(|c| c.to_string()).collect::<Vec<_>>().join(" or ");
                    let key = if n < counts[0] { "diagnostic.arity.too_few" } else { "diagnostic.arity.too_many" };
                    let message = tr(locale, key)
                        .replacen("{}", &b.name, 1)
                        .replacen("{}", &expected, 1)
                        .replacen("{}", &n.to_string(), 1);
                    // a warning: the forms come from the manual, the compiler has the last word
                    diags.push(Diagnostic {
                        range,
                        severity: Some(DiagnosticSeverity::WARNING),
                        source: Some("vpy".into()),
                        message: format!("{message} ({})", b.signatures.join("  |  ")),
                        ..Default::default()
                    });
                }
            }
            continue;
        }
        if vpy_parser::builtins::is_known_builtin(&upper) || known.contains(&upper) {
            continue;
        }
        let looks_builtin = name.chars().any(|c| c.is_ascii_uppercase()) && !name.chars().any(|c| c.is_ascii_lowercase());
        if !looks_builtin && star_import {
            continue; // it may come from the `import *`
        }
        let message = if looks_builtin {
            format!("`{name}` is not a VPy builtin")
        } else {
            format!("Unknown function '{name}'")
        };
        diags.push(error_diagnostic(range, message));
    }
}

/// The other `.vpy` files next to `uri` (the project's other modules), read again only
/// when they change on disk.
fn sibling_sources(uri: &Url) -> Vec<std::sync::Arc<String>> {
    use std::collections::HashMap;
    use std::sync::{Arc, Mutex, OnceLock};
    use std::time::SystemTime;
    static CACHE: OnceLock<Mutex<HashMap<std::path::PathBuf, (SystemTime, Arc<String>)>>> = OnceLock::new();
    let Ok(path) = uri.to_file_path() else { return Vec::new() };
    let Some(dir) = path.parent() else { return Vec::new() };
    let Ok(entries) = std::fs::read_dir(dir) else { return Vec::new() };
    let mut cache = CACHE.get_or_init(|| Mutex::new(HashMap::new())).lock().unwrap();
    let mut out = Vec::new();
    for e in entries.flatten() {
        let p = e.path();
        if p == path || p.extension().and_then(|x| x.to_str()) != Some("vpy") {
            continue;
        }
        let Ok(mtime) = e.metadata().and_then(|m| m.modified()) else { continue };
        match cache.get(&p) {
            Some((t, text)) if *t == mtime => out.push(text.clone()),
            _ => {
                if let Ok(text) = std::fs::read_to_string(&p) {
                    let text = Arc::new(text);
                    cache.insert(p, (mtime, text.clone()));
                    out.push(text);
                }
            }
        }
    }
    out
}

/// Compute all diagnostics for a document.
pub fn compute_diagnostics(uri: &Url, text: &str, locale: &str) -> Vec<Diagnostic> {
    eprintln!("[LSP] compute_diagnostics called for URI: {}", uri);
    eprintln!("[LSP] Text length: {} lines", text.lines().count());
    let mut diags = Vec::new();

    match lex(text) {
        Ok(tokens) => {
            match parse_tokens(&tokens, uri.path()) {
                Ok(module) => {
                    eprintln!("[LSP] Analyzing variable usage...");
                    let analysis = analyze_variable_usage(&module);
                    // this module's globals as the others use them (`module.name`)
                    let stem = uri.to_file_path().ok()
                        .and_then(|p| p.file_stem().map(|s| s.to_string_lossy().into_owned()))
                        .unwrap_or_default();
                    let others = sibling_sources(uri);
                    let external = ExternalUse::scan(&stem, others.iter().map(|t| t.as_str()));
                    generate_usage_diagnostics(&analysis, &external, locale, &mut diags);
                    check_calls(&module, text, locale, &mut diags);
                }
                Err(e) => {
                    let msg = e.to_string();
                    let loc = parse_error_line_col(&msg, text)
                        .or_else(|| parse_lexer_error(&msg, text))
                        .unwrap_or(ErrorLocation { line: 0, col: 0, message: msg.clone() });
                    diags.push(error_diagnostic(
                        Range {
                            start: Position { line: loc.line, character: loc.col },
                            end: Position { line: loc.line, character: loc.col + 1 },
                        },
                        loc.message,
                    ));
                }
            }

            for (i, line_txt) in text.lines().enumerate() {
                validate_import_statement(uri, line_txt, i as u32, &mut diags);

                if line_txt.contains("POLYGON") && line_txt.contains(" 2") {
                    diags.push(Diagnostic {
                        range: whole_line(i as u32, line_txt),
                        severity: Some(DiagnosticSeverity::WARNING),
                        code: None,
                        code_description: None,
                        source: Some("vpy".into()),
                        message: tr(locale, "diagnostic.polygon.degenerate"),
                        related_information: None,
                        tags: None,
                        data: None,
                    });
                }

            }
        }
        Err(e) => {
            // Lexer error (e.g. indentation, unexpected character).
            let msg = e.to_string();
            let loc = parse_lexer_error(&msg, text)
                .unwrap_or(ErrorLocation { line: 0, col: 0, message: msg.clone() });
            diags.push(error_diagnostic(
                Range {
                    start: Position { line: loc.line, character: loc.col },
                    end: Position { line: loc.line, character: loc.col + 1 },
                },
                loc.message,
            ));
        }
    }

    eprintln!("[LSP] compute_diagnostics returning {} diagnostics", diags.len());
    for (i, diag) in diags.iter().enumerate() {
        eprintln!("[LSP] Diagnostic {}: line={}, message={}", i, diag.range.start.line, diag.message);
    }
    diags
}
