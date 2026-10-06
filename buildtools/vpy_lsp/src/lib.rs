//! VPy language server.
//!
//! Diagnostics come from `vpy_parser` (the compiler's own lexer and parser),
//! plus line-level checks for imports and builtin arity and an AST-based
//! variable usage analysis. Also provides completion, hover, go to
//! definition, rename, signature help, semantic tokens and quick fixes.
//!
//! The `vpy_lsp` binary serves this over stdio for the Electron IDE.

pub mod analysis;
pub mod builtins;
pub mod diagnostics;
pub mod features;

use std::collections::HashMap;
use std::sync::{Arc, Mutex};

use tower_lsp::jsonrpc::Result as LspResult;
use tower_lsp::lsp_types::*;
use tower_lsp::{Client, LanguageServer, LspService, Server};

pub use diagnostics::compute_diagnostics;
pub use features::SymbolDef;

/// Version reported in `serverInfo`.
pub const SERVER_VERSION: &str = "0.1.0";

/// Run the language server on stdin/stdout until the client exits.
pub async fn run_stdio_server() {
    let (stdin, stdout) = (tokio::io::stdin(), tokio::io::stdout());
    let (service, socket) = LspService::build(Backend::new).finish();
    Server::new(stdin, stdout, socket).serve(service).await;
}

/// Server capabilities advertised in the `initialize` response.
pub fn server_capabilities() -> ServerCapabilities {
    ServerCapabilities {
        text_document_sync: Some(TextDocumentSyncCapability::Options(TextDocumentSyncOptions {
            open_close: Some(true),
            change: Some(TextDocumentSyncKind::FULL),
            will_save: None,
            will_save_wait_until: None,
            save: Some(TextDocumentSyncSaveOptions::SaveOptions(SaveOptions {
                include_text: Some(false),
            })),
        })),
        completion_provider: Some(CompletionOptions {
            resolve_provider: None,
            trigger_characters: None,
            work_done_progress_options: Default::default(),
            all_commit_characters: None,
            completion_item: None,
        }),
        semantic_tokens_provider: Some(SemanticTokensServerCapabilities::SemanticTokensOptions(
            SemanticTokensOptions {
                work_done_progress_options: Default::default(),
                legend: features::semantic_tokens_legend(),
                range: None,
                full: Some(SemanticTokensFullOptions::Bool(true)),
            },
        )),
        hover_provider: Some(HoverProviderCapability::Simple(true)),
        definition_provider: Some(OneOf::Left(true)),
        rename_provider: Some(OneOf::Left(true)),
        signature_help_provider: Some(SignatureHelpOptions {
            trigger_characters: Some(vec!["(".to_string(), ",".to_string()]),
            retrigger_characters: None,
            work_done_progress_options: Default::default(),
        }),
        ..Default::default()
    }
}

/// LSP backend state: open documents, client locale and the user function
/// definitions discovered by semantic tokenization (shared across documents
/// for cross-file completion, definition and rename).
pub struct Backend {
    client: Client,
    docs: Arc<Mutex<HashMap<Url, String>>>,
    locale: Arc<Mutex<String>>,
    symbols: Arc<Mutex<Vec<SymbolDef>>>,
}

impl Backend {
    pub fn new(client: Client) -> Self {
        Backend {
            client,
            docs: Arc::new(Mutex::new(HashMap::new())),
            locale: Arc::new(Mutex::new("en".to_string())),
            symbols: Arc::new(Mutex::new(Vec::new())),
        }
    }

    fn doc_text(&self, uri: &Url) -> Option<String> {
        self.docs.lock().unwrap().get(uri).cloned()
    }

    fn locale(&self) -> String {
        self.locale.lock().unwrap().clone()
    }

    fn symbols(&self) -> Vec<SymbolDef> {
        self.symbols.lock().unwrap().clone()
    }

    async fn publish(&self, origin: &str, uri: Url, text: &str) {
        eprintln!("[LSP] {}: Computing diagnostics for {}", origin, uri);
        let diags = compute_diagnostics(&uri, text, &self.locale());
        eprintln!("[LSP] {}: Publishing {} diagnostics", origin, diags.len());
        self.client.publish_diagnostics(uri, diags, None).await;
    }
}

#[tower_lsp::async_trait]
impl LanguageServer for Backend {
    async fn initialize(&self, params: InitializeParams) -> LspResult<InitializeResult> {
        if let Some(loc) = params.locale {
            *self.locale.lock().unwrap() = loc;
        }
        Ok(InitializeResult {
            capabilities: server_capabilities(),
            server_info: Some(ServerInfo {
                name: "vpy-lsp".into(),
                version: Some(SERVER_VERSION.into()),
            }),
        })
    }

    async fn initialized(&self, _: InitializedParams) {
        let msg = builtins::tr(&self.locale(), "init.ready");
        self.client.log_message(MessageType::INFO, msg).await;
    }

    async fn shutdown(&self) -> LspResult<()> {
        Ok(())
    }

    async fn did_open(&self, params: DidOpenTextDocumentParams) {
        let uri = params.text_document.uri;
        let text = params.text_document.text;
        self.docs.lock().unwrap().insert(uri.clone(), text.clone());
        self.publish("did_open", uri, &text).await;
    }

    async fn did_change(&self, params: DidChangeTextDocumentParams) {
        let uri = params.text_document.uri;
        if let Some(change) = params.content_changes.into_iter().last() {
            self.docs.lock().unwrap().insert(uri.clone(), change.text.clone());
            self.publish("did_change", uri, &change.text).await;
        }
    }

    async fn did_save(&self, params: DidSaveTextDocumentParams) {
        let uri = params.text_document.uri;
        eprintln!("[LSP] did_save: Triggered for {}", uri);
        if let Some(text) = self.doc_text(&uri) {
            self.publish("did_save", uri, &text).await;
        }
    }

    async fn completion(&self, params: CompletionParams) -> LspResult<Option<CompletionResponse>> {
        let uri = params.text_document_position.text_document.uri;
        let pos = params.text_document_position.position;
        let text = self.doc_text(&uri).unwrap_or_default();
        let items = features::completion_items(&text, pos, &uri, &self.symbols());
        Ok(Some(CompletionResponse::Array(items)))
    }

    async fn semantic_tokens_full(&self, params: SemanticTokensParams) -> LspResult<Option<SemanticTokensResult>> {
        let uri = params.text_document.uri;
        let Some(text) = self.doc_text(&uri) else { return Ok(None) };
        let (data, defs) = features::semantic_tokens(&uri, &text);
        {
            let mut symbols = self.symbols.lock().unwrap();
            symbols.retain(|d| d.uri != uri);
            symbols.extend(defs);
        }
        Ok(Some(SemanticTokensResult::Tokens(SemanticTokens { result_id: None, data })))
    }

    async fn hover(&self, params: HoverParams) -> LspResult<Option<Hover>> {
        let pos = params.text_document_position_params.position;
        let uri = params.text_document_position_params.text_document.uri;
        eprintln!("[vpy_lsp][hover] request pos= {:?} uri= {}", pos, uri);
        let Some(text) = self.doc_text(&uri) else { return Ok(None) };
        Ok(features::hover_at(&text, pos, &uri, &self.locale(), &self.symbols()))
    }

    async fn goto_definition(&self, params: GotoDefinitionParams) -> LspResult<Option<GotoDefinitionResponse>> {
        let pos = params.text_document_position_params.position;
        let uri = params.text_document_position_params.text_document.uri;
        let Some(text) = self.doc_text(&uri) else { return Ok(None) };
        Ok(features::definition_at(&text, pos, &uri, &self.symbols()).map(GotoDefinitionResponse::Scalar))
    }

    async fn code_action(&self, params: CodeActionParams) -> LspResult<Option<CodeActionResponse>> {
        let uri = params.text_document.uri;
        eprintln!("[vpy_lsp][code_action] request for uri= {}", uri);
        if params.context.diagnostics.is_empty() {
            return Ok(None);
        }
        let Some(text) = self.doc_text(&uri) else { return Ok(None) };
        let actions = features::code_actions(&text, &uri, &params.context.diagnostics);
        Ok(if actions.is_empty() { None } else { Some(actions) })
    }

    async fn rename(&self, params: RenameParams) -> LspResult<Option<WorkspaceEdit>> {
        let pos = params.text_document_position.position;
        let uri = params.text_document_position.text_document.uri;
        let all_docs: Vec<(Url, String)> = {
            let docs = self.docs.lock().unwrap();
            docs.iter().map(|(u, t)| (u.clone(), t.clone())).collect()
        };
        let Some(text) = all_docs.iter().find(|(u, _)| *u == uri).map(|(_, t)| t.clone()) else {
            return Ok(None);
        };
        Ok(features::rename_edits(&text, pos, &params.new_name, &all_docs, &self.symbols()))
    }

    async fn signature_help(&self, params: SignatureHelpParams) -> LspResult<Option<SignatureHelp>> {
        let pos = params.text_document_position_params.position;
        let uri = params.text_document_position_params.text_document.uri;
        let Some(text) = self.doc_text(&uri) else { return Ok(None) };
        Ok(features::signature_help_at(&text, pos))
    }
}
