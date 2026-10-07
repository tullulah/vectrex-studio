//! VPy Parser: Phase 2 of buildtools compiler pipeline
//!
//! Converts token stream from lexer into AST (Abstract Syntax Tree)
//!
//! # Module Structure
//!
//! - `ast.rs`: AST type definitions (Module, Item, Stmt, Expr, etc.)
//! - `error.rs`: Error types (ParseError, ParseResult)
//! - `lexer.rs`: Tokenizer (lexical analysis)
//! - `builtins.rs`: Builtin function metadata
//! - `symbols.rs`: Cross-module symbol naming (`MODULE_symbol`), shared by every phase
//!
//! # Public API
//!
//! Main entry points:
//! - `lex(source) -> Result<Vec<Token>>` - Tokenize source code
//! - `parse_with_filename(filename) -> Result<Module>` - Full parse (lex + parse)

pub mod ast;
pub mod builtins;
pub mod error;
pub mod lexer;
pub mod parser;
pub mod symbols;

pub use ast::{
    AssignTarget, BinOp, CallInfo, CmpOp, Expr, ExportDecl, FieldDef, Function, IdentInfo,
    ImportDecl, ImportedSymbol, ImportSymbols, Item, LogicOp, MethodCallInfo, Module, ModuleMeta,
    Stmt, StructDef, VlEntry,
};
pub use error::{ParseError, ParseResult};
pub use lexer::{lex, Token, TokenKind};

/// Parse a source filename into an AST Module
///
/// # Arguments
/// * `filename` - Path to .vpy file
///
/// # Returns
/// * `ParseResult<Module>` - Parsed AST or error with file:line:col information
///
/// # TODO
/// This is a placeholder. Implementation to be ported from core/src/parser.rs
pub fn parse_file(_filename: &str) -> ParseResult<Module> {
    // TODO: Implement actual file reading and parsing
    Err(ParseError::Generic(
        "File-based parser not yet implemented - placeholder only".to_string(),
    ))
}

/// Parse tokens into an AST Module
///
/// # Arguments
/// * `tokens` - Token stream from lexer
/// * `filename` - Source filename (for error reporting)
///
/// # Returns
/// * `ParseResult<Module>` - Parsed AST or error with file:line:col information
pub fn parse_tokens(tokens: &[Token], filename: &str) -> ParseResult<Module> {
    parser::parse_module(tokens, filename)
}

#[cfg(test)]
mod tests {
    use super::*;

    // Helper to lex and parse in one go
    #[allow(dead_code)]
    fn parse_code(code: &str) -> ParseResult<Module> {
        let tokens = lex(code)?;
        parse_tokens(&tokens, "test.vpy")
    }

    // Test 1: Parse simple number
    #[test]
    fn test_parse_number() {
        let code = "x = 42";
        let tokens = lex(code).unwrap();
        let result = parse_tokens(&tokens, "test.vpy");
        assert!(result.is_ok(), "Failed to parse number");
    }

    // Test 2: Parse identifier
    #[test]
    fn test_parse_identifier() {
        let code = "value = my_var";
        let tokens = lex(code).unwrap();
        let result = parse_tokens(&tokens, "test.vpy");
        assert!(result.is_ok(), "Failed to parse identifier");
    }

    // Test 3: Parse string literal
    #[test]
    fn test_parse_string() {
        let code = "msg = \"hello world\"";
        let tokens = lex(code).unwrap();
        let result = parse_tokens(&tokens, "test.vpy");
        assert!(result.is_ok(), "Failed to parse string");
    }

    // Test 4: Parse binary operation
    #[test]
    fn test_parse_binary_op() {
        let code = "result = 10 + 20";
        let tokens = lex(code).unwrap();
        let result = parse_tokens(&tokens, "test.vpy");
        assert!(result.is_ok(), "Failed to parse binary operation");
    }

    // Test 5: Parse unary operation
    #[test]
    fn test_parse_unary_op() {
        let code = "value = -42";
        let tokens = lex(code).unwrap();
        let result = parse_tokens(&tokens, "test.vpy");
        assert!(result.is_ok(), "Failed to parse unary operation");
    }

    // Test 6: Parse function call
    #[test]
    fn test_parse_function_call() {
        let code = "def loop():\n    SET_INTENSITY(127)";
        let tokens = lex(code).unwrap();
        let result = parse_tokens(&tokens, "test.vpy");
        assert!(result.is_ok(), "Failed to parse function call");
    }

    // Test 7: Parse array indexing
    #[test]
    fn test_parse_array_indexing() {
        let code = "value = arr[0]";
        let tokens = lex(code).unwrap();
        let result = parse_tokens(&tokens, "test.vpy");
        assert!(result.is_ok(), "Failed to parse array indexing");
    }

    // Test 8: Parse if statement
    #[test]
    fn test_parse_if_statement() {
        let code = "def loop():\n    if x > 0:\n        y = 1";
        let tokens = lex(code).unwrap();
        let result = parse_tokens(&tokens, "test.vpy");
        assert!(result.is_ok(), "Failed to parse if statement");
    }

    // Test 9: Parse while loop
    #[test]
    fn test_parse_while_loop() {
        let code = "def loop():\n    while x < 100:\n        x = x + 1";
        let tokens = lex(code).unwrap();
        let result = parse_tokens(&tokens, "test.vpy");
        assert!(result.is_ok(), "Failed to parse while loop");
    }

    // Test 10: Parse function definition
    #[test]
    fn test_parse_function_def() {
        let code = "def main():\n    SET_INTENSITY(127)";
        let tokens = lex(code).unwrap();
        let result = parse_tokens(&tokens, "test.vpy");
        assert!(result.is_ok(), "Failed to parse function definition");
        if let Ok(module) = result {
            assert_eq!(module.items.len(), 1, "Expected 1 function");
        }
    }

    // Test 11: Parse variable declaration (let)
    #[test]
    fn test_parse_variable_declaration() {
        let code = "player_x = 0";
        let tokens = lex(code).unwrap();
        let result = parse_tokens(&tokens, "test.vpy");
        assert!(result.is_ok(), "Failed to parse variable declaration");
    }

    // Test 12: Parse const array
    #[test]
    fn test_parse_const_array() {
        let code = "const my_array = [1, 2, 3]";
        let tokens = lex(code).unwrap();
        let result = parse_tokens(&tokens, "test.vpy");
        assert!(result.is_ok(), "Failed to parse const array");
    }

    // Test 13: Parse import statement
    #[test]
    fn test_parse_import() {
        let code = "import graphics";
        let tokens = lex(code).unwrap();
        let result = parse_tokens(&tokens, "test.vpy");
        assert!(result.is_ok(), "Failed to parse import statement");
    }

    // Test 14: Integration - Complete program
    #[test]
    fn test_parse_complete_program() {
        let code = r#"
def main():
    SET_INTENSITY(127)

def loop():
    WAIT_RECAL()
    DRAW_LINE(0, 0, 50, 50, 127)
    x = J1_X()
    if x > 0:
        y = 1
"#;
        let tokens = lex(code).unwrap();
        let result = parse_tokens(&tokens, "test.vpy");
        assert!(result.is_ok(), "Failed to parse complete program");
        if let Ok(module) = result {
            assert!(module.items.len() >= 2, "Expected at least 2 functions");
        }
    }

    // Test 15: Integration - Multimodule project (imports)
    #[test]
    fn test_parse_multimodule() {
        let code = r#"
import input
import graphics

player_x = 0

def main():
    SET_INTENSITY(127)

def loop():
    WAIT_RECAL()
    input.get_input()
    graphics.draw_player()
"#;
        let tokens = lex(code).unwrap();
        let result = parse_tokens(&tokens, "test.vpy");
        assert!(result.is_ok(), "Failed to parse multimodule project");
    }
}
