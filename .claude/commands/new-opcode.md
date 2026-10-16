Add a new MC6809 opcode (or addressing mode) to the VPy assembler (`buildtools/vpy_assembler`).

Usage: /new-opcode [OPCODE_NAME]

1. Check whether $ARGUMENTS is already handled: search the dispatch in `buildtools/vpy_assembler/src/m6809/asm_to_binary.rs` and the emitters in `binary_emitter.rs`. Note which addressing modes are missing.
2. Get the opcode bytes, cycle counts and valid addressing modes from the 6809 instruction table in `docs/vec_prog_docs/other/TOOLS/6809/TEXT/6809.TXT` (it also covers indexed and push/pull post-bytes and page-2/page-3 prefixes `$10`/`$11`).
3. Add the mnemonic to the dispatch in `asm_to_binary.rs`.
4. Implement the encoding in `binary_emitter.rs` for each valid mode: inherent, immediate, direct, extended, indexed (relative for branches).
5. Add tests in a `#[cfg(test)]` module in `vpy_assembler` that call `vpy_assembler::assemble_m6809(source, 0x0000, false, false)` and check the bytes, one per addressing mode, plus an invalid-operand case. Tests run from the crate directory, so the assembler finds `VECTREX.I` through its `../../ide/frontend/public/include/VECTREX.I` fallback.
6. Run `cd buildtools && cargo test -p vpy_assembler` (the workspace denies warnings).
