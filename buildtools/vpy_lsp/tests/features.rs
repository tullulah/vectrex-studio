//! Tests for the language server's pure request handlers.

use tower_lsp::lsp_types::*;
use vpy_lsp::compute_diagnostics;
use vpy_lsp::diagnostics::{parse_error_line_col, parse_lexer_error, ErrorLocation};
use vpy_lsp::features::{
    code_actions, completion_items, definition_at, hover_at, rename_edits, semantic_tokens,
    signature_help_at,
};

const VALID_PROGRAM: &str = r#"META TITLE = "LSP TEST"

const SPEED = 2
player_x = 0

def main():
    SET_INTENSITY(127)

def loop():
    WAIT_RECAL()
    player_x = player_x + SPEED
    for i in range(0, 4):
        DRAW_LINE(player_x, 0, i, i, 127)
    PRINT_TEXT(-50, 60, "HELLO")
    draw_ship(player_x)

def draw_ship(x):
    DRAW_LINE(x, 0, x + 10, 10, 100)
"#;

fn uri() -> Url {
    Url::parse("file:///tmp/vpy_lsp_test/src/main.vpy").unwrap()
}

fn errors(diags: &[Diagnostic]) -> Vec<&Diagnostic> {
    diags.iter().filter(|d| d.severity == Some(DiagnosticSeverity::ERROR)).collect()
}

#[test]
fn valid_program_has_no_errors() {
    let diags = compute_diagnostics(&uri(), VALID_PROGRAM, "en");
    assert!(errors(&diags).is_empty(), "unexpected errors: {:#?}", diags);
}

#[test]
fn syntax_error_reports_correct_line_and_column() {
    // Line 6 (0-based 5) is missing its trailing colon.
    let src = "def main():\n    SET_INTENSITY(127)\n\ndef loop():\n    WAIT_RECAL()\n    if x > 0\n        y = 1\n";
    let diags = compute_diagnostics(&uri(), src, "en");
    let errs = errors(&diags);
    assert_eq!(errs.len(), 1, "{:#?}", diags);
    assert_eq!(errs[0].range.start.line, 5);
    assert_eq!(errs[0].range.start.character, 12, "error should sit at end of `    if x > 0`");
    assert!(errs[0].message.contains("Colon"), "{}", errs[0].message);
    assert_eq!(errs[0].source.as_deref(), Some("vpy"));
}

#[test]
fn lexer_error_reports_line_and_column() {
    let src = "def main():\n    x = 1 ! 2\n";
    let diags = compute_diagnostics(&uri(), src, "en");
    let errs = errors(&diags);
    assert_eq!(errs.len(), 1, "{:#?}", diags);
    assert_eq!(errs[0].range.start.line, 1);
    assert_eq!(errs[0].range.start.character, 10, "column of '!' including indentation");
}

#[test]
fn indentation_error_reports_line() {
    let src = "def main():\n   x = 1\n";
    let diags = compute_diagnostics(&uri(), src, "en");
    let errs = errors(&diags);
    assert_eq!(errs.len(), 1, "{:#?}", diags);
    assert_eq!(errs[0].range.start.line, 1);
    assert_eq!(errs[0].message, "Indentation must be multiples of 4");
}

#[test]
fn builtin_arity_and_unknown_function_are_reported() {
    let src = "def main():\n    DRAW_LINE(1, 2)\n    not_defined(3)\n";
    let diags = compute_diagnostics(&uri(), src, "en");
    let errs = errors(&diags);
    assert!(errs.iter().any(|d| d.range.start.line == 1
        && d.message == "Function `DRAW_LINE` expects 5 arguments, but 2 were provided."), "{:#?}", diags);
    assert!(errs.iter().any(|d| d.range.start.line == 2
        && d.message == "Unknown function 'not_defined'"), "{:#?}", diags);

    let es = compute_diagnostics(&uri(), src, "es");
    assert!(es.iter().any(|d| d.message.starts_with("La función `DRAW_LINE` espera 5")));
}

#[test]
fn unresolved_import_is_reported() {
    let src = "from does_not_exist import thing\n\ndef main():\n    thing()\n";
    let diags = compute_diagnostics(&uri(), src, "en");
    assert!(diags.iter().any(|d| d.range.start.line == 0
        && d.range.start.character == 5
        && d.message.contains("Cannot resolve module 'does_not_exist'")), "{:#?}", diags);
}

#[test]
fn usage_analysis_and_quick_fixes() {
    let src = "unused = 5\nspeed = 3\n\ndef main():\n    x = speed\n    DEBUG_PRINT(x)\n";
    let diags = compute_diagnostics(&uri(), src, "en");
    let unused = diags.iter().find(|d| d.code == Some(NumberOrString::String("unused-variable".into())))
        .expect("unused-variable warning");
    assert_eq!(unused.range.start.line, 0);
    assert!(unused.message.contains("'unused'"));
    let hint = diags.iter().find(|d| d.code == Some(NumberOrString::String("suggest-const".into())))
        .expect("suggest-const hint");
    assert_eq!(hint.range.start.line, 1);

    let actions = code_actions(src, &uri(), &[unused.clone(), hint.clone()]);
    let titles: Vec<String> = actions.iter().map(|a| match a {
        CodeActionOrCommand::CodeAction(a) => a.title.clone(),
        CodeActionOrCommand::Command(c) => c.title.clone(),
    }).collect();
    assert!(titles.contains(&"Remove unused variable 'unused'".to_string()), "{:?}", titles);
    assert!(titles.contains(&"Convert 'speed' to const".to_string()), "{:?}", titles);
}

#[test]
fn completion_offers_builtins_and_user_functions() {
    let (_, defs) = semantic_tokens(&uri(), VALID_PROGRAM);
    let items = completion_items(VALID_PROGRAM, Position { line: 10, character: 4 }, &uri(), &defs);
    let draw_line = items.iter().find(|i| i.label == "DRAW_LINE").expect("DRAW_LINE offered");
    assert_eq!(draw_line.kind, Some(CompletionItemKind::KEYWORD));
    let wait = items.iter().find(|i| i.label == "WAIT_RECAL").expect("WAIT_RECAL offered");
    assert_eq!(wait.kind, Some(CompletionItemKind::METHOD));
    let ship = items.iter().find(|i| i.label == "draw_ship").expect("user function offered");
    assert_eq!(ship.insert_text.as_deref(), Some("draw_ship($0)"));
    assert_eq!(ship.detail.as_deref(), Some("Function (current file)"));
}

#[test]
fn completion_after_colon_offers_types_only() {
    let src = "x: \n";
    let items = completion_items(src, Position { line: 0, character: 2 }, &uri(), &[]);
    let labels: Vec<&str> = items.iter().map(|i| i.label.as_str()).collect();
    assert_eq!(labels, vec!["u8", "i8", "u16", "i16", "u32", "i32"]);
}

#[test]
fn hover_on_builtin_shows_docs() {
    // Cursor in the middle of `DRAW_LINE` on line 12 (0-based).
    let hover = hover_at(VALID_PROGRAM, Position { line: 12, character: 12 }, &uri(), "en", &[])
        .expect("hover for DRAW_LINE");
    match hover.contents {
        HoverContents::Markup(m) => {
            assert_eq!(m.kind, MarkupKind::Markdown);
            assert_eq!(m.value, "DRAW_LINE(x1, y1, x2, y2, intensity)  - draws line segment.");
        }
        other => panic!("unexpected hover contents {:?}", other),
    }
    let es = hover_at(VALID_PROGRAM, Position { line: 12, character: 12 }, &uri(), "es-ES", &[]).unwrap();
    assert!(matches!(es.contents, HoverContents::Markup(ref m) if m.value.contains("dibuja segmento")));
}

#[test]
fn hover_and_definition_of_user_function() {
    let (_, defs) = semantic_tokens(&uri(), VALID_PROGRAM);
    let def = defs.iter().find(|d| d.name == "draw_ship").expect("draw_ship def");
    assert_eq!(def.range.start, Position { line: 16, character: 4 });

    // Call site `    draw_ship(player_x)` is line 14.
    let call = Position { line: 14, character: 6 };
    let hover = hover_at(VALID_PROGRAM, call, &uri(), "en", &defs).expect("hover");
    assert!(matches!(hover.contents, HoverContents::Markup(ref m) if m.value == "Function `draw_ship` defined at line 17"));

    let loc = definition_at(VALID_PROGRAM, call, &uri(), &defs).expect("definition");
    assert_eq!(loc.range, def.range);
}

#[test]
fn rename_updates_every_whole_word_occurrence() {
    let (_, defs) = semantic_tokens(&uri(), VALID_PROGRAM);
    let docs = vec![(uri(), VALID_PROGRAM.to_string())];
    let edit = rename_edits(VALID_PROGRAM, Position { line: 14, character: 6 }, "draw_player", &docs, &defs)
        .expect("rename edit");
    let edits = &edit.changes.unwrap()[&uri()];
    assert_eq!(edits.len(), 2);
    assert!(edits.iter().all(|e| e.new_text == "draw_player"));
}

#[test]
fn signature_help_tracks_active_parameter() {
    let src = "MOVE(10, ";
    let help = signature_help_at(src, Position { line: 0, character: 9 }).expect("signature");
    assert_eq!(help.signatures[0].label, "MOVE(x, y)");
    assert_eq!(help.active_parameter, Some(1));
}

#[test]
fn semantic_tokens_classify_keywords_builtins_and_defs() {
    let src = "def main():\n    SET_INTENSITY(127)\n";
    let (data, defs) = semantic_tokens(&uri(), src);
    // def(keyword) main(function decl) : ( ) SET_INTENSITY(builtin) 127(number)
    let types: Vec<(u32, u32, u32, u32)> = data.iter()
        .map(|t| (t.delta_line, t.delta_start, t.length, t.token_type)).collect();
    assert_eq!(types[0], (0, 0, 3, 0));  // def
    assert_eq!(types[1], (0, 4, 4, 1));  // main
    assert_eq!(data[1].token_modifiers_bitset, 1 << 1);
    let builtin = data.iter().find(|t| t.length == 13).expect("SET_INTENSITY token");
    assert_eq!((builtin.delta_line, builtin.delta_start, builtin.token_type), (1, 4, 1));
    assert_eq!(builtin.token_modifiers_bitset, 1 << 2);
    assert!(data.iter().any(|t| t.token_type == 4 && t.length == 3));
    assert_eq!(defs.len(), 1);
    assert_eq!(defs[0].name, "main");
}

#[test]
fn parser_error_location_handles_windows_paths() {
    let text = "a\n    b = (\n";
    let loc = parse_error_line_col("C:\\games\\src\\main.vpy:2:4: error: Expected RParen got Newline", text)
        .unwrap();
    assert_eq!(loc, ErrorLocation { line: 1, col: 8, message: "Expected RParen got Newline".into() });
    let loc = parse_error_line_col("/C:/games/main.vpy:1:0: error: boom", text).unwrap();
    assert_eq!((loc.line, loc.col), (0, 0));
}

#[test]
fn lexer_error_location_formats() {
    let text = "a\n    b\n";
    let loc = parse_lexer_error("Indentation must be multiples of 4 (line 2)", text).unwrap();
    assert_eq!(loc, ErrorLocation { line: 1, col: 0, message: "Indentation must be multiples of 4".into() });
    let loc = parse_lexer_error("Unexpected character '$' at line 2:1", text).unwrap();
    assert_eq!((loc.line, loc.col), (1, 4));
    assert!(parse_lexer_error("no position here", text).is_none());
}
