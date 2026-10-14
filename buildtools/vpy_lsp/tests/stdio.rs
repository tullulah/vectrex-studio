//! End-to-end test: spawn the `vpy_lsp` binary and talk JSON-RPC over stdio
//! the way the Electron IDE does.

use std::io::{BufRead, BufReader, Read, Write};
use std::process::{Child, ChildStdin, Command, Stdio};
use std::sync::mpsc::{channel, Receiver};
use std::thread;
use std::time::Duration;

use serde_json::{json, Value};

struct Server {
    child: Child,
    stdin: Option<ChildStdin>,
    rx: Receiver<Value>,
}

impl Server {
    fn spawn() -> Server {
        let mut child = Command::new(env!("CARGO_BIN_EXE_vpy_lsp"))
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::null())
            .spawn()
            .expect("spawn vpy_lsp");
        let stdin = child.stdin.take().unwrap();
        let stdout = child.stdout.take().unwrap();
        let (tx, rx) = channel();
        thread::spawn(move || {
            let mut reader = BufReader::new(stdout);
            loop {
                let mut content_length = None;
                loop {
                    let mut header = String::new();
                    if reader.read_line(&mut header).unwrap_or(0) == 0 {
                        return;
                    }
                    let header = header.trim_end();
                    if header.is_empty() {
                        break;
                    }
                    if let Some(v) = header.strip_prefix("Content-Length: ") {
                        content_length = v.parse::<usize>().ok();
                    }
                }
                let mut body = vec![0u8; content_length.expect("Content-Length header")];
                if reader.read_exact(&mut body).is_err() {
                    return;
                }
                if tx.send(serde_json::from_slice(&body).expect("JSON body")).is_err() {
                    return;
                }
            }
        });
        Server { child, stdin: Some(stdin), rx }
    }

    fn send(&mut self, msg: Value) {
        let body = msg.to_string();
        let stdin = self.stdin.as_mut().expect("stdin still open");
        write!(stdin, "Content-Length: {}\r\n\r\n{}", body.len(), body).unwrap();
        stdin.flush().unwrap();
    }

    /// Wait for the first message matching `pred`, skipping the others.
    fn wait_for(&self, what: &str, pred: impl Fn(&Value) -> bool) -> Value {
        loop {
            let msg = self
                .rx
                .recv_timeout(Duration::from_secs(10))
                .unwrap_or_else(|_| panic!("timed out waiting for {}", what));
            if pred(&msg) {
                return msg;
            }
        }
    }
}

impl Drop for Server {
    fn drop(&mut self) {
        let _ = self.child.kill();
        let _ = self.child.wait();
    }
}

#[test]
fn stdio_session_publishes_diagnostics_and_answers_requests() {
    let mut server = Server::spawn();
    let uri = "file:///tmp/vpy_lsp_stdio/src/main.vpy";

    server.send(json!({"jsonrpc": "2.0", "id": 1, "method": "initialize",
        "params": {"processId": null, "rootUri": null, "capabilities": {}, "locale": "en"}}));
    let init = server.wait_for("initialize response", |m| m["id"] == 1);
    let caps = &init["result"]["capabilities"];
    assert_eq!(init["result"]["serverInfo"]["name"], "vpy-lsp");
    assert_eq!(caps["textDocumentSync"]["change"], 1);
    assert_eq!(caps["hoverProvider"], true);
    assert_eq!(caps["definitionProvider"], true);
    assert_eq!(caps["renameProvider"], true);
    assert_eq!(caps["signatureHelpProvider"]["triggerCharacters"], json!(["(", ","]));
    assert_eq!(caps["semanticTokensProvider"]["legend"]["tokenTypes"][0], "keyword");
    assert!(caps["completionProvider"].is_object());

    server.send(json!({"jsonrpc": "2.0", "method": "initialized", "params": {}}));
    let log = server.wait_for("init log", |m| m["method"] == "window/logMessage");
    assert_eq!(log["params"]["message"], "VPy LSP initialized");

    let text = "def main():\n    SET_INTENSITY(127)\n\ndef loop():\n    WAIT_RECAL()\n    if x > 0\n        DRAW_LINE(0, 0, 10, 10, 127)\n";
    server.send(json!({"jsonrpc": "2.0", "method": "textDocument/didOpen", "params": {
        "textDocument": {"uri": uri, "languageId": "vpy", "version": 1, "text": text}}}));
    let diags = server.wait_for("publishDiagnostics", |m| m["method"] == "textDocument/publishDiagnostics");
    assert_eq!(diags["params"]["uri"], uri);
    let list = diags["params"]["diagnostics"].as_array().unwrap();
    assert_eq!(list.len(), 1, "{:#}", diags);
    assert_eq!(list[0]["severity"], 1);
    assert_eq!(list[0]["range"]["start"]["line"], 5);
    assert_eq!(list[0]["source"], "vpy");

    // Fixing the error clears the diagnostics.
    let fixed = text.replace("if x > 0\n", "if 1 > 0:\n");
    server.send(json!({"jsonrpc": "2.0", "method": "textDocument/didChange", "params": {
        "textDocument": {"uri": uri, "version": 2}, "contentChanges": [{"text": fixed}]}}));
    let diags = server.wait_for("publishDiagnostics", |m| m["method"] == "textDocument/publishDiagnostics");
    assert_eq!(diags["params"]["diagnostics"], json!([]));

    server.send(json!({"jsonrpc": "2.0", "id": 2, "method": "textDocument/hover", "params": {
        "textDocument": {"uri": uri}, "position": {"line": 6, "character": 12}}}));
    let hover = server.wait_for("hover response", |m| m["id"] == 2);
    let hover_text = hover["result"]["contents"]["value"].as_str().unwrap_or_default();
    assert!(hover_text.starts_with("`DRAW_LINE(x0, y0, x1, y1, intensity)`"), "{hover_text}");

    server.send(json!({"jsonrpc": "2.0", "id": 3, "method": "textDocument/completion", "params": {
        "textDocument": {"uri": uri}, "position": {"line": 4, "character": 4}}}));
    let completion = server.wait_for("completion response", |m| m["id"] == 3);
    let labels: Vec<&str> = completion["result"].as_array().unwrap().iter()
        .map(|i| i["label"].as_str().unwrap()).collect();
    assert!(labels.contains(&"DRAW_LINE") && labels.contains(&"WAIT_RECAL"), "{:?}", labels);

    server.send(json!({"jsonrpc": "2.0", "id": 4, "method": "shutdown"}));
    let shutdown = server.wait_for("shutdown response", |m| m["id"] == 4);
    assert!(shutdown.get("error").is_none(), "{:#}", shutdown);
    assert!(shutdown["result"].is_null());
    server.send(json!({"jsonrpc": "2.0", "method": "exit"}));
    // tower-lsp notices the exit on its next read; closing the pipe (as a
    // client does) lets the serve loop return.
    drop(server.stdin.take());
    for _ in 0..50 {
        if let Some(status) = server.child.try_wait().unwrap() {
            assert!(status.success(), "vpy_lsp exited with {}", status);
            return;
        }
        thread::sleep(Duration::from_millis(100));
    }
    panic!("vpy_lsp did not exit after shutdown/exit");
}
