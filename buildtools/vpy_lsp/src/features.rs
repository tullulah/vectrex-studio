//! Request handlers as pure functions over document text, so they can be
//! unit-tested without an LSP client: semantic tokens, completion, hover,
//! definition lookup, rename, signature help and code actions.

use std::collections::HashMap;

use tower_lsp::lsp_types::*;
use vpy_parser::{lex, TokenKind};

use crate::analysis::extract_var_name_from_diagnostic;
use crate::builtins::{builtin_doc, is_builtin_function, tr};
use crate::diagnostics::resolve_module_path;

/// A user function definition discovered while computing semantic tokens.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SymbolDef {
    pub name: String,
    pub uri: Url,
    pub range: Range,
}

/// Semantic token legend advertised in `initialize`. Indices below must match.
pub fn semantic_tokens_legend() -> SemanticTokensLegend {
    SemanticTokensLegend {
        token_types: vec![
            SemanticTokenType::KEYWORD,
            SemanticTokenType::FUNCTION,
            SemanticTokenType::VARIABLE,
            SemanticTokenType::PARAMETER,
            SemanticTokenType::NUMBER,
            SemanticTokenType::STRING,
            SemanticTokenType::OPERATOR,
            SemanticTokenType::ENUM_MEMBER,
        ],
        token_modifiers: vec![
            SemanticTokenModifier::READONLY,
            SemanticTokenModifier::DECLARATION,
            SemanticTokenModifier::DEFAULT_LIBRARY,
        ],
    }
}

const TT_KEYWORD: u32 = 0;
const TT_FUNCTION: u32 = 1;
const TT_VARIABLE: u32 = 2;
const TT_NUMBER: u32 = 4;
const TT_STRING: u32 = 5;
const TT_OPERATOR: u32 = 6;
const TT_ENUM_MEMBER: u32 = 7;
const MOD_READONLY: u32 = 1 << 0;
const MOD_DECL: u32 = 1 << 1;
const MOD_DEFAULT_LIB: u32 = 1 << 2;

fn keyword_len(kind: &TokenKind) -> Option<u32> {
    Some(match kind {
        TokenKind::Def => 3,
        TokenKind::If => 2,
        TokenKind::Elif => 4,
        TokenKind::Else => 4,
        TokenKind::For => 3,
        TokenKind::In => 2,
        TokenKind::Range => 5,
        TokenKind::Return => 6,
        TokenKind::While => 5,
        TokenKind::Break => 5,
        TokenKind::Continue => 8,
        TokenKind::Const => 5,
        TokenKind::VectorList => 10,
        TokenKind::Switch => 6,
        TokenKind::Case => 4,
        TokenKind::Default => 7,
        TokenKind::Meta => 4,
        TokenKind::And => 3,
        TokenKind::Or => 2,
        TokenKind::Not => 3,
        TokenKind::True => 4,
        TokenKind::False => 5,
        _ => return None,
    })
}

/// Compute delta-encoded semantic tokens for a document plus the user
/// function definitions found in it (`def <name>`). If the document doesn't
/// lex, no tokens and no definitions are returned.
pub fn semantic_tokens(uri: &Url, text: &str) -> (Vec<SemanticToken>, Vec<SymbolDef>) {
    let lines: Vec<&str> = text.lines().collect();
    let mut data = Vec::new();
    let mut defs = Vec::new();

    let tokens = match lex(text) {
        Ok(t) => t,
        Err(_) => return (data, defs),
    };

    let mut raw: Vec<(u32, u32, u32, u32, u32)> = Vec::new();
    for (idx, tk) in tokens.iter().enumerate() {
        if tk.line == 0 {
            continue;
        }
        let line0 = (tk.line - 1) as u32;
        let line_str = lines.get(line0 as usize).copied().unwrap_or("");
        let indent = line_str.chars().take_while(|c| *c == ' ').count() as u32;
        let base_col = indent + tk.col as u32;

        match &tk.kind {
            k if keyword_len(k).is_some() => {
                raw.push((line0, base_col, keyword_len(k).unwrap(), TT_KEYWORD, 0));
            }
            TokenKind::Identifier(name) => {
                // Is this the name right after `def` (skipping layout tokens)?
                let mut is_after_def = false;
                let mut j = idx;
                while j > 0 {
                    j -= 1;
                    match tokens[j].kind {
                        TokenKind::Newline | TokenKind::Indent | TokenKind::Dedent => continue,
                        TokenKind::Def => is_after_def = true,
                        _ => {}
                    }
                    break;
                }
                let len = name.len() as u32;
                if is_after_def {
                    raw.push((line0, base_col, len, TT_FUNCTION, MOD_DECL));
                    defs.push(SymbolDef {
                        name: name.clone(),
                        uri: uri.clone(),
                        range: Range {
                            start: Position { line: line0, character: base_col },
                            end: Position { line: line0, character: base_col + len },
                        },
                    });
                } else if is_builtin_function(name) {
                    raw.push((line0, base_col, len, TT_FUNCTION, MOD_DEFAULT_LIB));
                } else if name.to_ascii_uppercase().starts_with("I_") {
                    raw.push((line0, base_col, len, TT_ENUM_MEMBER, MOD_READONLY));
                } else {
                    raw.push((line0, base_col, len, TT_VARIABLE, 0));
                }
            }
            TokenKind::Number(_) => {
                let slice = line_str.get(base_col as usize..).unwrap_or("");
                let len = slice
                    .chars()
                    .take_while(|ch| ch.is_ascii_hexdigit() || matches!(ch, 'x' | 'X' | 'b' | 'B'))
                    .count()
                    .max(1);
                raw.push((line0, base_col, len as u32, TT_NUMBER, 0));
            }
            TokenKind::StringLit(s) => {
                raw.push((line0, base_col, (s.len() + 2) as u32, TT_STRING, 0));
            }
            TokenKind::Plus | TokenKind::Minus | TokenKind::Star | TokenKind::Slash
            | TokenKind::Percent | TokenKind::Amp | TokenKind::Pipe | TokenKind::Caret
            | TokenKind::Tilde | TokenKind::Dot | TokenKind::Colon | TokenKind::Comma
            | TokenKind::Equal | TokenKind::Lt | TokenKind::Gt => {
                raw.push((line0, base_col, 1, TT_OPERATOR, 0));
            }
            TokenKind::ShiftLeft | TokenKind::ShiftRight | TokenKind::EqEq
            | TokenKind::NotEq | TokenKind::Le | TokenKind::Ge => {
                raw.push((line0, base_col, 2, TT_OPERATOR, 0));
            }
            _ => {}
        }
    }

    raw.sort_by(|a, b| a.0.cmp(&b.0).then(a.1.cmp(&b.1)));
    let (mut last_line, mut last_col, mut first) = (0, 0, true);
    for (line, col, length, token_type, mods) in raw {
        let delta_line = if first { line } else { line - last_line };
        let delta_start = if first || delta_line != 0 { col } else { col - last_col };
        data.push(SemanticToken {
            delta_line,
            delta_start,
            length,
            token_type,
            token_modifiers_bitset: mods,
        });
        last_line = line;
        last_col = col;
        first = false;
    }

    (data, defs)
}

/// The identifier (`[A-Za-z0-9_]+`) under or immediately before `pos`.
pub fn word_at(text: &str, pos: Position) -> Option<String> {
    let line = text.lines().nth(pos.line as usize).unwrap_or("");
    let chars: Vec<char> = line.chars().collect();
    let cursor = pos.character as usize;
    if cursor > chars.len() {
        return None;
    }
    let is_word = |c: char| c.is_alphanumeric() || c == '_';
    let mut start = cursor;
    let mut end = cursor;
    while start > 0 && is_word(chars[start - 1]) {
        start -= 1;
    }
    while end < chars.len() && is_word(chars[end]) {
        end += 1;
    }
    if start >= end {
        return None;
    }
    Some(chars[start..end].iter().collect())
}

/// Parse `from <module> import a, b as c` into (module, [(original, alias)]).
fn parse_from_import(line: &str) -> Option<(&str, Vec<(&str, Option<&str>)>)> {
    let after_from = line.trim().strip_prefix("from ")?;
    let parts: Vec<&str> = after_from.splitn(2, " import ").collect();
    if parts.len() != 2 {
        return None;
    }
    let names = parts[1]
        .trim()
        .split(',')
        .map(|item| {
            let item = item.trim();
            match item.split_once(" as ") {
                Some((orig, alias)) => (orig.trim(), Some(alias.trim())),
                None => (item, None),
            }
        })
        .collect();
    Some((parts[0].trim(), names))
}

const TYPE_KEYWORDS: [(&str, &str); 6] = [
    ("u8", "Unsigned 8-bit integer (0-255)"),
    ("i8", "Signed 8-bit integer (-128 to 127)"),
    ("u16", "Unsigned 16-bit integer (0-65535)"),
    ("i16", "Signed 16-bit integer (-32768 to 32767)"),
    ("u32", "Unsigned 32-bit integer (ARM targets only)"),
    ("i32", "Signed 32-bit integer (ARM targets only)"),
];

/// Unified functions (global + vectorlist) and VPy keywords offered by completion.
const UNIFIED_ITEMS: &[&str] = &[
    "MOVE", "SET_INTENSITY", "DRAW_TO", "DRAW_LINE", "SET_ORIGIN", "PRINT_TEXT", "PRINT_NUMBER",
    // Direct drawing functions
    "DRAW_POLYGON", "DRAW_CIRCLE", "DRAW_CIRCLE_SEG", "DRAW_ARC", "DRAW_SPIRAL",
    "RECT", "POLYGON", "CIRCLE", "ARC", "SPIRAL", "DRAW_VECTORLIST", "DRAW_VECTOR_ROT",
    // Message dispatch system
    "MSG_DEF", "PRINT_MSG",
    // Camera / scroll
    "SET_CAMERA_X",
    // Declarations and structures
    "VECTORLIST", "CONST", "VAR", "META", "TITLE", "MUSIC", "COPYRIGHT",
    // Control keywords
    "def", "for", "while", "if", "switch",
    // Import keywords
    "from", "import", "export", "as",
];

/// Vectorlist-only functions offered by completion.
const VECTORLIST_ONLY: [&str; 6] = [
    "FRAME_BEGIN", "VECTOR_PHASE_BEGIN", "WAIT_RECAL", "PLAY_MUSIC1", "DBG_STATIC_VL", "DRAW_VL",
];

/// Completion items at `pos`. After a `:` only the integer type names are
/// offered; otherwise builtins, keywords, known user functions and names
/// brought in by `from X import ...`.
pub fn completion_items(text: &str, pos: Position, uri: &Url, symbols: &[SymbolDef]) -> Vec<CompletionItem> {
    let mut items = Vec::new();

    // Type annotation context (after ':').
    let line = text.lines().nth(pos.line as usize).unwrap_or("");
    let col = pos.character as usize;
    if col > 0 && col <= line.len() {
        let before_cursor = line.get(..col).unwrap_or(line);
        if before_cursor.trim_end().ends_with(':') || line.chars().nth(col - 1) == Some(':') {
            for (type_name, detail) in TYPE_KEYWORDS {
                items.push(CompletionItem {
                    label: type_name.to_string(),
                    kind: Some(CompletionItemKind::KEYWORD),
                    insert_text: Some(type_name.to_string()),
                    detail: Some(detail.to_string()),
                    ..Default::default()
                });
            }
            return items;
        }
    }

    for name in UNIFIED_ITEMS {
        items.push(CompletionItem {
            label: name.to_string(),
            kind: Some(CompletionItemKind::KEYWORD),
            insert_text: None,
            detail: Some("Unified function (global/vectorlist)".to_string()),
            ..Default::default()
        });
    }

    for name in VECTORLIST_ONLY {
        items.push(CompletionItem {
            label: name.to_string(),
            kind: Some(CompletionItemKind::METHOD),
            insert_text: None,
            detail: Some("Vectorlist-only function".to_string()),
            ..Default::default()
        });
    }

    // User functions from every document seen so far.
    for def in symbols {
        items.push(CompletionItem {
            label: def.name.clone(),
            kind: Some(CompletionItemKind::FUNCTION),
            insert_text: Some(format!("{}($0)", def.name)),
            insert_text_format: Some(InsertTextFormat::SNIPPET),
            detail: if &def.uri == uri {
                Some("Function (current file)".to_string())
            } else {
                Some(format!("Function ({})", def.uri.path().rsplit('/').next().unwrap_or("")))
            },
            ..Default::default()
        });
    }

    // Names brought in by `from X import ...` (alias wins over original).
    for line in text.lines() {
        if let Some((module_name, names)) = parse_from_import(line) {
            for (original, alias) in names {
                let label = alias.unwrap_or(original);
                if !items.iter().any(|i| i.label == label) {
                    items.push(CompletionItem {
                        label: label.to_string(),
                        kind: Some(CompletionItemKind::FUNCTION),
                        insert_text: Some(format!("{}($0)", label)),
                        insert_text_format: Some(InsertTextFormat::SNIPPET),
                        detail: Some(format!("Imported from {}", module_name)),
                        ..Default::default()
                    });
                }
            }
        }
    }

    items
}

/// Hover: builtin documentation first, then "function defined at line N" for
/// user functions of the same document.
pub fn hover_at(text: &str, pos: Position, uri: &Url, locale: &str, symbols: &[SymbolDef]) -> Option<Hover> {
    let word = word_at(text, pos)?;
    let upper = word.to_ascii_uppercase();
    if let Some(doc) = builtin_doc(locale, &upper) {
        return Some(Hover {
            contents: HoverContents::Markup(MarkupContent { kind: MarkupKind::Markdown, value: doc }),
            range: None,
        });
    }
    let def = symbols.iter().find(|d| d.name == word && &d.uri == uri)?;
    let value = tr(locale, "hover.user_function.line")
        .replacen("{}", &def.name, 1)
        .replacen("{}", &(def.range.start.line + 1).to_string(), 1);
    Some(Hover {
        contents: HoverContents::Markup(MarkupContent { kind: MarkupKind::Markdown, value }),
        range: Some(def.range),
    })
}

/// Resolve a name imported via `from X import name [as alias]` to its
/// definition (or to the start of the module file if the definition is not
/// known yet).
fn resolve_import_target(text: &str, symbol_name: &str, current_uri: &Url, symbols: &[SymbolDef]) -> Option<Location> {
    for line in text.lines() {
        let Some((module_path, names)) = parse_from_import(line) else { continue };
        for (original, alias) in names {
            let matches = alias.map(|a| a == symbol_name).unwrap_or(original == symbol_name);
            if !matches {
                continue;
            }
            let target_uri = current_uri
                .to_file_path()
                .ok()
                .and_then(|p| p.parent().and_then(|dir| resolve_module_path(module_path, dir)))
                .and_then(|path| Url::from_file_path(path).ok());
            // An unresolvable module doesn't end the search: a later import
            // line may still provide the name.
            let Some(target_uri) = target_uri else { continue };
            if let Some(def) = symbols.iter().find(|d| d.name == original && d.uri == target_uri) {
                return Some(Location { uri: def.uri.clone(), range: def.range });
            }
            return Some(Location { uri: target_uri, range: Range::default() });
        }
    }
    None
}

/// Go to definition: same document first, then any document, then imports.
pub fn definition_at(text: &str, pos: Position, uri: &Url, symbols: &[SymbolDef]) -> Option<Location> {
    let word = word_at(text, pos)?;
    if let Some(def) = symbols.iter().find(|d| d.name == word && &d.uri == uri) {
        return Some(Location { uri: def.uri.clone(), range: def.range });
    }
    if let Some(def) = symbols.iter().find(|d| d.name == word) {
        return Some(Location { uri: def.uri.clone(), range: def.range });
    }
    resolve_import_target(text, &word, uri, symbols)
}

/// Rename a known user function across all open documents (whole-word match).
pub fn rename_edits(
    text: &str,
    pos: Position,
    new_name: &str,
    all_docs: &[(Url, String)],
    symbols: &[SymbolDef],
) -> Option<WorkspaceEdit> {
    let original = word_at(text, pos)?;
    if original.is_empty() || new_name.is_empty() {
        return None;
    }
    if !symbols.iter().any(|d| d.name == original) {
        return None;
    }

    let is_word_byte = |b: u8| b.is_ascii_alphanumeric() || b == b'_';
    let mut changes: HashMap<Url, Vec<TextEdit>> = HashMap::new();
    for (doc_uri, doc_text) in all_docs {
        let mut edits = Vec::new();
        for (line_idx, line_txt) in doc_text.lines().enumerate() {
            let bytes = line_txt.as_bytes();
            let mut search_idx = 0;
            while search_idx < bytes.len() {
                if bytes[search_idx..].starts_with(original.as_bytes()) {
                    let after_pos = search_idx + original.len();
                    let before_ok = search_idx == 0 || !is_word_byte(bytes[search_idx - 1]);
                    let after_ok = after_pos >= bytes.len() || !is_word_byte(bytes[after_pos]);
                    if before_ok && after_ok {
                        edits.push(TextEdit {
                            range: Range {
                                start: Position { line: line_idx as u32, character: search_idx as u32 },
                                end: Position { line: line_idx as u32, character: after_pos as u32 },
                            },
                            new_text: new_name.to_string(),
                        });
                    }
                    search_idx = after_pos;
                } else {
                    search_idx += 1;
                }
            }
        }
        if !edits.is_empty() {
            changes.insert(doc_uri.clone(), edits);
        }
    }

    if changes.is_empty() {
        return None;
    }
    Some(WorkspaceEdit { changes: Some(changes), document_changes: None, change_annotations: None })
}

/// Signature help for the builtin whose `(` is the last one before the cursor.
pub fn signature_help_at(text: &str, pos: Position) -> Option<SignatureHelp> {
    let line = text.lines().nth(pos.line as usize).unwrap_or("");
    let cut = (pos.character as usize).min(line.len());
    let prefix = line.get(..cut).unwrap_or(line);
    let idx = prefix.rfind('(')?;
    let ident: String = prefix[..idx]
        .chars()
        .rev()
        .take_while(|c| c.is_alphanumeric() || *c == '_')
        .collect::<String>()
        .chars()
        .rev()
        .collect();
    if ident.is_empty() {
        return None;
    }
    let arg_str = &prefix[idx + 1..];
    let param_index = if arg_str.trim().is_empty() { 0 } else { arg_str.matches(',').count() };

    let sigs: [(&str, &[&str], &str); 8] = [
        ("MOVE", &["x", "y"], "Move beam to (x,y)"),
        ("RECT", &["x", "y", "w", "h"], "Draw rectangle"),
        ("POLYGON", &["n", "x1y1..."], "Draw polygon"),
        ("CIRCLE", &["r"], "Draw circle"),
        ("ARC", &["r", "startAngle", "endAngle"], "Draw arc"),
        ("SPIRAL", &["r", "turns"], "Draw spiral"),
        ("INTENSITY", &["val"], "Set beam intensity"),
        ("PRINT_TEXT", &["x", "y", "text"], "Print text"),
    ];
    let upper = ident.to_ascii_uppercase();
    let (name, params_list, doc) = sigs.into_iter().find(|(n, _, _)| *n == upper)?;
    let sig = SignatureInformation {
        label: format!("{}({})", name, params_list.join(", ")),
        documentation: Some(Documentation::String(doc.to_string())),
        parameters: Some(
            params_list
                .iter()
                .map(|p| ParameterInformation { label: ParameterLabel::Simple(p.to_string()), documentation: None })
                .collect(),
        ),
        active_parameter: None,
    };
    let max_index = params_list.len().saturating_sub(1);
    Some(SignatureHelp {
        signatures: vec![sig],
        active_signature: Some(0),
        active_parameter: Some(param_index.min(max_index) as u32),
    })
}

/// Quick fixes for the usage diagnostics ("suggest-const", "unused-variable").
pub fn code_actions(text: &str, uri: &Url, diagnostics: &[Diagnostic]) -> Vec<CodeActionOrCommand> {
    let mut actions = Vec::new();
    for diagnostic in diagnostics {
        let code = match &diagnostic.code {
            Some(NumberOrString::String(s)) => s.as_str(),
            _ => continue,
        };
        let Some(var_name) = extract_var_name_from_diagnostic(&diagnostic.message) else { continue };

        let (title, new_text) = match code {
            "suggest-const" => {
                let Some(line) = text.lines().nth(diagnostic.range.start.line as usize) else { continue };
                let new_text = if line.trim().starts_with(&var_name) {
                    line.replacen(&format!("{} =", var_name), &format!("const {} =", var_name), 1)
                } else {
                    format!("const {}", line.trim())
                };
                (format!("Convert '{}' to const", var_name), new_text)
            }
            "unused-variable" => (format!("Remove unused variable '{}'", var_name), String::new()),
            _ => continue,
        };

        actions.push(CodeActionOrCommand::CodeAction(CodeAction {
            title,
            kind: Some(CodeActionKind::QUICKFIX),
            diagnostics: Some(vec![diagnostic.clone()]),
            edit: Some(WorkspaceEdit {
                changes: Some(HashMap::from([(
                    uri.clone(),
                    vec![TextEdit { range: diagnostic.range, new_text }],
                )])),
                ..Default::default()
            }),
            ..Default::default()
        }));
    }
    actions
}
