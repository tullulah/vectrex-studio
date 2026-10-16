Run the tests of the VPy compiler workspace (`buildtools/`, the only compiler).

Run `cargo test --all` in `buildtools/`. If $ARGUMENTS names a crate, run only that crate (for example `cargo test -p vpy_parser`); add `-- --nocapture` to see println! output.

Then report:
1. Totals: passed / failed / ignored
2. For each failure: the test name, the crate, and the reason
3. Which compiler phases (1-9: vpy_loader, vpy_parser, vpy_unifier, vpy_bank_allocator, vpy_codegen, vpy_assembler, vpy_linker, vpy_binary_writer, vpy_debug_gen) are fully green and which have failures, plus vpy_cli, vpy_disasm and vpy_lsp

If tests fail, read the relevant source files and offer to fix the root cause.
