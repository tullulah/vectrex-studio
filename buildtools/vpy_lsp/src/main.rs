//! `vpy_lsp` binary: VPy language server over stdio.

#[tokio::main]
async fn main() {
    eprintln!("[vpy_lsp] launching full LSP server");
    vpy_lsp::run_stdio_server().await;
}
