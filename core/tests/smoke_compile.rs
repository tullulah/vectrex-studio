use vectrex_lang::{lex, parse_with_filename, target::Target};

#[test]
fn smoke_minimal_compile() {
    let src = r#"META TITLE = "SMOKE"

def main():
    SET_INTENSITY(127)

def loop():
    WAIT_RECAL()
    x = 1
    y = x + 2
    y = y + 3
"#;
    let tokens = lex(src).expect("lex ok");
    assert!(tokens.len() > 0, "tokens generated");
    let module = parse_with_filename(&tokens, "smoke.vpy").expect("parse ok");
    assert!(module.items.len() >= 2, "expect at least 2 functions");
    // Emit 6809 asm
    let opts = vectrex_lang::codegen::CodegenOptions {
        title: "SMOKE".to_string(),
        auto_loop: true,
        diag_freeze: false,
        force_extended_jsr: false,
        _bank_size: 0,
        per_frame_silence: false,
        debug_init_draw: false,
        blink_intensity: false,
        exclude_ram_org: false,
        fast_wait: false, 
        source_path: None,
        assets: vec![],
        const_values: std::collections::BTreeMap::new(),
        const_arrays: std::collections::BTreeMap::new(),
        const_string_arrays: std::collections::BTreeSet::new(),
        mutable_arrays: std::collections::BTreeSet::new(),
        structs: std::collections::HashMap::new(),
        type_context: std::collections::HashMap::new(),
        output_name: None,
        buffer_requirements: None,
        frame_groups: std::collections::HashMap::new(),
        interleaved_frames: None,
    };
    let asm = vectrex_lang::codegen::emit_asm(&module, Target::Vectrex, &opts);
    // The main loop is generated with label "MAIN:" when auto_loop is enabled
    assert!(asm.contains("main:") || asm.contains("MAIN:"), "asm should contain main loop label");
    assert!(asm.to_ascii_uppercase().contains("VECTREX_VECTOR_PHASE_BEGIN") == false, "no unused wrappers emitted by default");
}
