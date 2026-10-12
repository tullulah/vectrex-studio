//! Where the variables go on uvm2: the scalars (and each array's pointer) in the window
//! after the runtime area, [0x2007F460, 0x20080000); the arrays' data in the first 12 KB of
//! the reserved .vpyram, [0x2007C000, 0x2007F000). The allocator used to run straight on past
//! 0x20080000, over the cores' stacks, without a word (the Return of the Jedi port's
//! variables reached 0x200818C0). Running out of either is now a compile error.

use vpy_codegen::{BankConfig, Target};

fn generate(src: &str, target: &Target) -> Result<String, String> {
    let tokens = vpy_parser::lex(src).expect("lex");
    let m = vpy_parser::parse_tokens(&tokens, "main.vpy").expect("parse");
    let mut modules = std::collections::HashMap::new();
    modules.insert("main".to_string(), m);
    let module = vpy_unifier::unify_modules(modules, "main").expect("unify");
    vpy_codegen::generate_from_module_with_target(&module, &BankConfig::single_bank(), "T", &[], target)
        .map(|g| g.asm_source)
        .map_err(|e| format!("{e:?}"))
}

fn addr(asm: &str, name: &str) -> u32 {
    let line = asm.lines().find(|l| l.starts_with(&format!(".equ {name},"))).unwrap_or_else(|| panic!("no {name}"));
    let hex = line.split("0x").nth(1).unwrap().split_whitespace().next().unwrap();
    u32::from_str_radix(hex, 16).unwrap()
}

#[test]
fn uvm2_arrays_go_below_the_window_and_running_out_is_an_error() {
    let src = "big: i32 = [0] * 2000\nn = 0\ndef main():\n    pass\ndef loop():\n    big[1] = n\n";
    let asm = generate(src, &Target::Uvm2).unwrap();
    let data = addr(&asm, "ARRAY_BIG_DATA");
    assert!((0x2007_C000..0x2007_F000).contains(&data), "array data at {data:08X}");
    assert!((0x2007_F460..0x2008_0000).contains(&addr(&asm, "VAR_BIG")), "its pointer in the window");
    assert!((0x2007_F460..0x2008_0000).contains(&addr(&asm, "VAR_N")), "a scalar in the window");

    // 16 KB of arrays: more than the 12 KB reserved for them
    let err = generate("a: i32 = [0] * 2500\nb: i32 = [0] * 1500\ndef main():\n    pass\ndef loop():\n    pass\n", &Target::Uvm2).unwrap_err();
    assert!(err.contains("arrays do not fit"), "{err}");
    // and scalars past the window
    let mut many = String::new();
    for i in 0..800 {
        many.push_str(&format!("v{i} = 0\n"));
    }
    many.push_str("def main():\n    pass\ndef loop():\n    pass\n");
    let err = generate(&many, &Target::Uvm2).unwrap_err();
    assert!(err.contains("variables do not fit"), "{err}");
}
