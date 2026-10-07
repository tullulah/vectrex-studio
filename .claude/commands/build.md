Build the VPy compiler workspace (`buildtools/`, the only compiler; there is no `core/` crate).

Run `cargo build --all` in the `buildtools/` directory. Report compilation errors clearly, grouped by crate. The workspace denies warnings, so unused imports, unused variables and dead code are errors too. For each error, name the compiler phase it belongs to and the source files to look at.

Crates:
- Phase 1: vpy_loader (`.vpyproj` → ProjectInfo)
- Phase 2: vpy_parser (AST)
- Phase 3: vpy_unifier (modules, imports, `MODULE_symbol` names)
- Phase 4: vpy_bank_allocator
- Phase 5: vpy_codegen (m6809 / arm / pitrex / uvm2 backends, asset compilers)
- Phase 6: vpy_assembler (MC6809)
- Phase 7: vpy_linker (the only source of final addresses)
- Phase 8: vpy_binary_writer
- Phase 9: vpy_debug_gen
- vpy_cli (the `vpy_cli` binary), vpy_disasm, and vpy_lsp (the language server)

The IDE uses the copies in `ide/electron/resources/`. `./run-ide.sh` rebuilds `vpy_cli` and `vpy_lsp` and copies them there, so mention it when the change should reach the IDE.
