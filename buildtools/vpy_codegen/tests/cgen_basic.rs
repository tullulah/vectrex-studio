//! The C backend (uvm2, `[uvm2] backend = "c"`): the program as C on libvpy, with the
//! ARM backend's semantics. These pin the constructs whose C spelling decides them.

fn gen(src: &str) -> String {
    let tokens = vpy_parser::lex(src).expect("lex");
    let m = vpy_parser::parse_tokens(&tokens, "main.vpy").expect("parse");
    let mut modules = std::collections::HashMap::new();
    modules.insert("main".to_string(), m);
    let module = vpy_unifier::unify_modules(modules, "main").expect("unify");
    vpy_codegen::cgen::generate_c(&module, &[]).expect("C").c_source
}

#[test]
fn program_shape_and_semantics() {
    let c = gen("const BIG = 110000\nxs: u8 = [1, 2, 3]\nws: i32 = [0] * 4\nn = 0\n\
                 def add(a, b):\n    return a + b\n\
                 def main():\n    n = BIG\n\
                 def loop():\n    for i in range(0, 3):\n        n += xs[i]\n    ws[1] = add(n, 2) or 5\n    if n > 3 and n < 9:\n        n = n / 2\n");
    // 32-bit constants fold (the ARM targets' ints, not m6809's 16 bits)
    assert!(c.contains("110000"), "{c}");
    // typed arrays keep their element type; zero arrays need no initialiser
    assert!(c.contains("static uint8_t G_XS[3] = { 1, 2, 3 };"), "{c}");
    assert!(c.contains("static int32_t G_WS[4];"), "{c}");
    // a for re-tests var < end, steps by its literal
    assert!(c.contains("for (l_i = 0; l_i < 3; l_i += 1)"), "{c}");
    // `or` gives 1 when the left side is true, else the right side
    assert!(c.contains("? 1 :"), "{c}");
    // libvpy runs the frame
    assert!(c.contains("vpy_run(vpy_setup, vpy_loop)"), "{c}");
    assert!(c.contains("#pragma GCC optimize (\"Os\", \"wrapv\""), "{c}");
}

#[test]
fn function_values_and_indirect_calls() {
    let c = gen("f = 0\ndef twice(x):\n    return x * 2\ndef main():\n    f = twice\ndef loop():\n    f(3)\n");
    assert!(c.contains("(int32_t)(intptr_t)F_TWICE"), "{c}");
    assert!(c.contains("((int32_t (*)(int32_t))(intptr_t)(G_F))(3)"), "{c}");
}

/// A struct array lowered to field arrays comes back as one C array of structs (one base,
/// fixed offsets), unless a field array is used as a whole.
#[test]
fn struct_fields_become_c_structs() {
    let c = gen("struct Tie:\n    on: u8\n    x: i32\n    z: i32\ntie = Tie[4]\ndef main():\n    pass\n\
                 def loop():\n    tie[1].x = 5\n    tie[2].z += tie[1].x\n");
    assert!(c.contains("static struct { uint8_t f_on; int32_t f_x; int32_t f_z; } G_TIE[4];"), "{c}");
    assert!(c.contains("G_TIE[1].f_x = 5;"), "{c}");
}
