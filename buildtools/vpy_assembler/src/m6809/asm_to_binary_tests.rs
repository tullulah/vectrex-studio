//! Unit tests for the private helpers of `asm_to_binary.rs`.
//!
//! These used to live in `parser.rs`, `expression.rs` and `symbols.rs`, which were
//! never declared with `mod` and therefore never compiled: they tested stale copies
//! of these helpers. They now exercise the live implementations.

use super::*;

// --- directive / label parsing (was m6809/parser.rs) ---

#[test]
fn test_parse_vpy_line_marker_valid_and_other_comment() {
    assert_eq!(parse_vpy_line_marker("; VPy line 42"), Some(42));
    assert_eq!(parse_vpy_line_marker("; Other comment"), None);
    assert_eq!(parse_vpy_line_marker("; VPy line abc"), None);
}

#[test]
fn test_parse_label_global_local_and_instruction() {
    assert_eq!(parse_label("MAIN:"), Some("MAIN"));
    assert_eq!(parse_label(".local:"), Some(".local"));
    assert_eq!(parse_label("    LDA #10"), None);
}

#[test]
fn test_parse_label_colon_inside_comment_is_not_label() {
    assert_eq!(parse_label("    LDA #10 ; note: not a label"), None);
    assert_eq!(parse_label("LOOP: ; comment: here"), Some("LOOP"));
}

#[test]
fn test_parse_equ_directive_raw_returns_uppercase_name_and_expr() {
    assert_eq!(
        parse_equ_directive_raw("tmp_val EQU $C880+2"),
        Some(("TMP_VAL".to_string(), "$C880+2".to_string()))
    );
    assert_eq!(parse_equ_directive_raw("    LDA #1"), None);
}

#[test]
fn test_parse_include_directive_quoted_path() {
    assert_eq!(parse_include_directive("INCLUDE \"VECTREX.I\""), Some("VECTREX.I".to_string()));
    assert_eq!(parse_include_directive("INCLUDE VECTREX.I"), None);
    assert_eq!(parse_include_directive("    LDA #1"), None);
}

#[test]
fn test_expand_local_label_prefixes_only_dotted() {
    assert_eq!(expand_local_label(".local", "MAIN"), "MAIN.local");
    assert_eq!(expand_local_label("GLOBAL", "MAIN"), "GLOBAL");
}

#[test]
fn test_is_label_symbols_vs_numbers_and_modes() {
    assert!(is_label("SYMBOL"));
    assert!(is_label("_under_score"));
    assert!(is_label(".local"));
    assert!(is_label("MAIN.local"));
    assert!(!is_label("#10"));
    assert!(!is_label("$D000"));
    assert!(!is_label("123"));
    assert!(!is_label(""));
}

// --- expression evaluation (was m6809/expression.rs) ---

#[test]
fn test_parse_number_hex_decimal_and_invalid() {
    assert_eq!(parse_number("$FF"), Ok(255));
    assert_eq!(parse_number("0x10"), Ok(16));
    assert_eq!(parse_number("100"), Ok(100));
    assert!(parse_number("invalid").is_err());
}

#[test]
fn test_evaluate_expression_literal_and_equate() {
    let mut equates = HashMap::new();
    equates.insert("BASE".to_string(), 0x1000);
    assert_eq!(evaluate_expression("$FF", &equates), Ok(255));
    assert_eq!(evaluate_expression("BASE", &equates), Ok(0x1000));
    // Equate lookup is case-insensitive (keys are stored uppercase).
    assert_eq!(evaluate_expression("base", &equates), Ok(0x1000));
}

#[test]
fn test_evaluate_expression_arithmetic_and_precedence() {
    let equates = HashMap::new();
    assert_eq!(evaluate_expression("10+20", &equates), Ok(30));
    assert_eq!(evaluate_expression("100-50", &equates), Ok(50));
    assert_eq!(evaluate_expression("5*4", &equates), Ok(20));
    assert_eq!(evaluate_expression("100/5", &equates), Ok(20));
    assert_eq!(evaluate_expression("2+3*4", &equates), Ok(14));
    assert_eq!(evaluate_expression("(2+3)*4", &equates), Ok(20));
    assert_eq!(evaluate_expression("10-2-3", &equates), Ok(5));
}

#[test]
fn test_evaluate_expression_division_by_zero_is_error() {
    assert!(evaluate_expression("10/0", &HashMap::new()).is_err());
}

#[test]
fn test_evaluate_expression_unresolved_symbol_keeps_addend() {
    let equates = HashMap::new();
    assert_eq!(evaluate_expression("LABEL", &equates), Err("SYMBOL:LABEL".to_string()));
    assert_eq!(evaluate_expression("LABEL+3", &equates), Err("SYMBOL:LABEL+3".to_string()));
    assert_eq!(evaluate_expression("LABEL-2", &equates), Err("SYMBOL:LABEL-2".to_string()));
}

#[test]
fn test_parse_symbol_and_addend_from_symbol_error() {
    assert_eq!(parse_symbol_and_addend("SYMBOL:SYM"), Ok(("SYM".to_string(), 0)));
    assert_eq!(parse_symbol_and_addend("SYMBOL:SYM+10"), Ok(("SYM".to_string(), 10)));
    assert_eq!(parse_symbol_and_addend("SYMBOL:SYM-5"), Ok(("SYM".to_string(), -5)));
    assert_eq!(parse_symbol_and_addend("SYMBOL:>SYM"), Ok(("SYM".to_string(), 0)));
    assert!(parse_symbol_and_addend("SYM+1").is_err());
}

// --- BIOS symbol loading (was m6809/symbols.rs) ---

#[test]
fn test_parse_vectrex_symbols_stores_both_cases() {
    let content = r"
; Test VECTREX.I
Wait_Recal EQU $F192
VIA_port_b EQU $D000   ; comment
        ";
    let mut equates = HashMap::new();
    parse_vectrex_symbols(content, &mut equates);
    assert_eq!(equates.get("Wait_Recal"), Some(&0xF192));
    assert_eq!(equates.get("WAIT_RECAL"), Some(&0xF192));
    assert_eq!(equates.get("VIA_PORT_B"), Some(&0xD000));
}

#[test]
fn test_load_vectrex_symbols_from_repo_include() {
    // cargo runs unit tests from the crate dir, so the ../../ide fallback finds VECTREX.I.
    let mut equates = HashMap::new();
    load_vectrex_symbols(&mut equates);
    assert_eq!(equates.get("WAIT_RECAL"), Some(&0xF192));
}

// --- end-to-end through assemble_m6809 ---

#[test]
fn test_assembler_numeric_branch_offset_is_not_a_label() {
    // BRA with a decimal operand is a raw signed offset, not a symbol named "2".
    let (bytes, _, _, unresolved) =
        assemble_m6809("    BRA 2\n    NOP\n    NOP\n", 0x0000, false, false).expect("assembles");
    assert_eq!(&bytes[..2], &[0x20, 0x02]);
    assert!(unresolved.is_empty());
}

#[test]
fn test_assembler_jsr_decimal_address_is_not_a_label() {
    let (bytes, _, _, _) =
        assemble_m6809("    JSR 4096\n", 0x0000, false, false).expect("assembles");
    assert_eq!(&bytes[..3], &[0xBD, 0x10, 0x00]);
}

#[test]
fn test_assembler_local_label_branch_resolves() {
    let src = "MAIN:\n.loop:\n    NOP\n    BRA .loop\n";
    let (bytes, _, symbols, _) = assemble_m6809(src, 0x0000, false, false).expect("assembles");
    // NOP at 0, BRA at 1: offset = 0 - 3 = -3
    assert_eq!(&bytes[..3], &[0x12, 0x20, 0xFD]);
    assert!(symbols.contains_key("MAIN"));
}

// --- auto-increment indexed modes ---
// `,R++` post-increments by 2 (postbyte 1RR00001), `,R+` by 1 (1RR00000).
// The 16-bit instructions that pop a word off the hardware stack must use `,S++`.

fn bytes_of(src: &str) -> Vec<u8> {
    assemble_m6809(src, 0, false, false).expect("assemble").0
}

#[test]
fn post_increment_by_two_encodes_postbyte_x1() {
    // S register bits = 11 → 0x60.
    assert_eq!(bytes_of("    CMPD ,S++\n"), vec![0x10, 0xA3, 0xE1]);
    assert_eq!(bytes_of("    ADDD ,S++\n"), vec![0xE3, 0xE1]);
    assert_eq!(bytes_of("    SUBD ,S++\n"), vec![0xA3, 0xE1]);
    assert_eq!(bytes_of("    LDD ,S++\n"), vec![0xEC, 0xE1]);
    assert_eq!(bytes_of("    LDX ,S++\n"), vec![0xAE, 0xE1]);
    assert_eq!(bytes_of("    LDY ,X++\n"), vec![0x10, 0xAE, 0x81]);
    assert_eq!(bytes_of("    STY ,U++\n"), vec![0x10, 0xAF, 0xC1]);
}

#[test]
fn post_increment_by_one_encodes_postbyte_x0() {
    assert_eq!(bytes_of("    LDA ,X+\n"), vec![0xA6, 0x80]);
    assert_eq!(bytes_of("    STA ,U+\n"), vec![0xA7, 0xC0]);
    assert_eq!(bytes_of("    LDB ,S+\n"), vec![0xE6, 0xE0]);
}

#[test]
fn stack_offset_and_pre_decrement_modes() {
    assert_eq!(bytes_of("    ADDD ,S\n"), vec![0xE3, 0xE4]);
    assert_eq!(bytes_of("    LEAS 2,S\n"), vec![0x32, 0x62]);
    assert_eq!(bytes_of("    STD ,--S\n"), vec![0xED, 0xE3]);
}

// EORB was missing (the `^` operator's code could not be assembled), and
// `ORA #n` emitted ORA indexed ($AA) instead of the immediate form ($8A).
#[test]
fn eorb_and_ora_immediate_encode() {
    assert_eq!(bytes_of("    EORB #$0F\n"), vec![0xC8, 0x0F]);
    assert_eq!(bytes_of("    EORB ,X\n"), vec![0xE8, 0x84]);
    assert_eq!(bytes_of("    EORB $C880\n"), vec![0xF8, 0xC8, 0x80]);
    assert_eq!(bytes_of("    EORA #$0F\n"), vec![0x88, 0x0F]);
    assert_eq!(bytes_of("    ORA #$0F\n"), vec![0x8A, 0x0F]);
}
