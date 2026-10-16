//! The C side of the uvm2 builtins (vpy3d_bridge.c, vpy_jukebox.c) must take its
//! arguments the way the codegen passes them: the first four in r0-r3 -- the function's
//! parameters --, the rest in `vpyx_args[0..]` (read directly or through `A(k)`).
//! XF_POINT once declared three parameters and read y and z from vpyx_args[0..1]: y came
//! out as z, and z as whatever the last call left there.

fn body_of<'a>(src: &'a str, c_fn: &str) -> Option<(&'a str, &'a str)> {
    let pat = format!("{c_fn}(");
    let mut from = 0;
    while let Some(i) = src[from..].find(&pat).map(|i| i + from) {
        from = i + pat.len();
        // a definition: a type before it on the line, and `{` after the closing paren
        let line_start = src[..i].rfind('\n').map_or(0, |n| n + 1);
        let before = src[line_start..i].trim();
        if before.is_empty() || before.ends_with('=') || before.contains("return") {
            continue;
        }
        let close = from + src[from..].find(')')?;
        let rest = src[close + 1..].trim_start();
        if !rest.starts_with('{') {
            continue;
        }
        let open = close + 1 + src[close + 1..].find('{')?;
        let mut depth = 0;
        for (k, ch) in src[open..].char_indices() {
            match ch {
                '{' => depth += 1,
                '}' => {
                    depth -= 1;
                    if depth == 0 {
                        return Some((&src[from..close], &src[open..open + k]));
                    }
                }
                _ => {}
            }
        }
    }
    None
}

#[test]
fn every_builtin_takes_its_arguments_where_the_codegen_puts_them() {
    let bridge = include_str!("../src/c/vpy3d_bridge.c");
    let juke = include_str!("../src/c/vpy_jukebox.c");
    let mut checked = 0;
    for (name, c_fn, n) in vpy_codegen::arm::three_d::c_calls() {
        if c_fn.is_empty() {
            continue; // MESH(): no call, the slot itself
        }
        let Some((params, body)) = body_of(bridge, c_fn).or_else(|| body_of(juke, c_fn)) else {
            // straight into the SDK: it must take no more than r0-r3 carry
            assert!(n <= 4, "{name}: {n} arguments straight into {c_fn}, which reads the 5th on from the stack: wrap it");
            continue;
        };
        let params = params.split(',').filter(|p| !p.trim().is_empty() && p.trim() != "void").count();
        assert_eq!(params, n.min(4), "{name}: {c_fn} has {params} parameters, the codegen passes {} in registers", n.min(4));
        for k in 0..12 {
            let used = body.contains(&format!("vpyx_args[{k}]")) || body.contains(&format!("A({k})"));
            if used {
                assert!(k + 4 < n, "{name}: {c_fn} reads extra argument {k}, but only {} are passed", n.saturating_sub(4));
            }
        }
        checked += 1;
    }
    assert!(checked > 40, "only {checked} C functions found: the parser above is broken");
}
