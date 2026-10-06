//! Document diagnostics: lexer/parser errors from `vpy_parser` (the same
//! front end the compiler uses), import resolution, builtin arity checks,
//! unknown-function checks and variable usage hints.

use std::collections::HashSet;
use std::path::{Path, PathBuf};

use tower_lsp::lsp_types::{Diagnostic, DiagnosticSeverity, Position, Range, Url};
use vpy_parser::{lex, parse_tokens, Item};

use crate::analysis::{analyze_variable_usage, generate_usage_diagnostics};
use crate::builtins::{get_builtin_arity, is_python_keyword_or_builtin, tr, AritySpec};

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

/// Line-based check of call arity for builtins and of unknown function names.
/// VPy uses Python-style calls `FUNCTION(arg1, ...)`; a known builtin used
/// without parentheses is reported as an error.
fn validate_function_arity(
    original_line: &str,
    line_num: u32,
    locale: &str,
    diags: &mut Vec<Diagnostic>,
    defined_functions: &HashSet<String>,
) {
    let trimmed = original_line.trim();
    if trimmed.is_empty() || trimmed.starts_with('#') || trimmed.starts_with("//") {
        return;
    }
    // Control structures ending with ':'.
    if trimmed.ends_with(':') {
        return;
    }

    let parts: Vec<&str> = trimmed.split_whitespace().collect();
    if let Some(first_word) = parts.first() {
        if is_python_keyword_or_builtin(first_word) {
            return;
        }
    }

    // Ignore parentheses inside trailing comments.
    let comment_pos = trimmed.find('#').unwrap_or(trimmed.len());
    let code_part = trimmed[..comment_pos].trim();

    if let Some(paren_pos) = code_part.find('(') {
        let func_name = code_part[..paren_pos].trim();
        let remaining = &code_part[paren_pos + 1..];

        if is_python_keyword_or_builtin(func_name) {
            return;
        }

        if let Some(close_paren) = remaining.find(')') {
            let args_part = &remaining[..close_paren];

            if let Some(arity_spec) = get_builtin_arity(func_name) {
                let arg_count = if args_part.trim().is_empty() {
                    0
                } else {
                    args_part.split(',').map(|s| s.trim()).filter(|s| !s.is_empty()).count()
                };

                let message_key = match arity_spec {
                    AritySpec::Exact(expected) if arg_count == expected => None,
                    AritySpec::Exact(expected) if arg_count < expected => Some("diagnostic.arity.too_few"),
                    AritySpec::Exact(_) => Some("diagnostic.arity.too_many"),
                    AritySpec::Variable(min_args) if arg_count >= min_args => None,
                    AritySpec::Variable(_) => Some("diagnostic.arity.variable"),
                };

                if let Some(message_key) = message_key {
                    let expected_str = match arity_spec {
                        AritySpec::Exact(n) => n.to_string(),
                        AritySpec::Variable(n) => format!("at least {}", n),
                    };
                    let message = tr(locale, message_key)
                        .replacen("{}", func_name, 1)
                        .replacen("{}", &expected_str, 1)
                        .replacen("{}", &arg_count.to_string(), 1);
                    diags.push(error_diagnostic(whole_line(line_num, original_line), message));
                }
            } else if !func_name.is_empty() && !defined_functions.contains(func_name) {
                diags.push(error_diagnostic(
                    whole_line(line_num, original_line),
                    format!("Unknown function '{}'", func_name),
                ));
            }
        }
    } else if let Some(func_name) = parts.first() {
        if get_builtin_arity(func_name).is_some() {
            diags.push(error_diagnostic(
                whole_line(line_num, original_line),
                format!("Function '{}' must be called with parentheses: {}(...)", func_name, func_name),
            ));
        }
    }
}

/// Compute all diagnostics for a document.
pub fn compute_diagnostics(uri: &Url, text: &str, locale: &str) -> Vec<Diagnostic> {
    eprintln!("[LSP] compute_diagnostics called for URI: {}", uri);
    eprintln!("[LSP] Text length: {} lines", text.lines().count());
    let mut diags = Vec::new();

    match lex(text) {
        Ok(tokens) => {
            // Collect `def name(` matches from raw text first so user calls are
            // not flagged as unknown when the parse fails.
            let mut defined_functions = HashSet::new();
            for line in text.lines() {
                let t = line.trim_start();
                if let Some(rest) = t.strip_prefix("def ") {
                    if let Some(paren) = rest.find('(') {
                        let name = rest[..paren].trim();
                        if !name.is_empty() {
                            defined_functions.insert(name.to_string());
                        }
                    }
                }
            }

            match parse_tokens(&tokens, uri.path()) {
                Ok(module) => {
                    for item in &module.items {
                        if let Item::Function(func) = item {
                            defined_functions.insert(func.name.clone());
                        }
                    }
                    eprintln!("[LSP] Analyzing variable usage...");
                    let analysis = analyze_variable_usage(&module);
                    generate_usage_diagnostics(&analysis, locale, &mut diags);
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

                validate_function_arity(line_txt, i as u32, locale, &mut diags, &defined_functions);
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
