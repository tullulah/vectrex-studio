Show the current status of the 9 VPy compiler phases (`buildtools/`, the only compiler).

Read `buildtools/README.md` and `docs/COMPILER_STATUS.md` (the Known issues section), then run `cargo test --all` in `buildtools/` to get live test counts per crate.

Output a table like:

| Phase | Crate              | Status | Tests (passed/total) |
|-------|--------------------|--------|----------------------|
| 1     | vpy_loader         | ...    | ...                  |
| 2     | vpy_parser         | ...    | ...                  |
| ...   | ...                | ...    | ...                  |

Include the support crates as extra rows: vpy_cli, vpy_disasm, vpy_lsp. Base the status on the test run, not on the README's claims. Highlight crates with failing tests and the open items listed under Known issues. If the README disagrees with what the tests or the code show, point it out.
