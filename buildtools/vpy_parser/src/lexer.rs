//! VPy Lexer - Tokenize VPy source code
//!
//! Ported from core/src/lexer.rs
//! Converts raw text into a token stream with proper indentation handling (Python-style)

use crate::error::{ParseError, ParseResult};

/// Token types for the VPy language
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum TokenKind {
    // Keywords
    Def,
    If,
    Elif,
    Else,
    For,
    While,
    In,
    Range,
    Break,
    Continue,
    Pass,
    Return,
    Const,
    VectorList,
    Switch,
    Case,
    Default,
    Meta,
    And,
    Or,
    Not,
    True,
    False,
    From,
    Import,
    As,
    Export,
    Struct,
    Self_,
    At,

    // Literals
    Identifier(String),
    Number(i32),
    StringLit(String),

    // Punctuation
    LParen,
    RParen,
    LBracket,
    RBracket,
    Colon,
    Comma,
    Dot,

    // Operators
    Plus,
    Minus,
    Star,
    Slash,
    SlashSlash,
    Percent,
    Amp,
    Pipe,
    Caret,
    Tilde,
    ShiftLeft,
    ShiftRight,

    // Comparison
    Equal,
    EqEq,
    NotEq,
    Lt,
    Le,
    Gt,
    Ge,

    // Compound assignment
    PlusEqual,
    MinusEqual,
    StarEqual,
    SlashEqual,
    SlashSlashEqual,
    PercentEqual,

    // Structural
    Newline,
    Indent,
    Dedent,
    Eof,
}

/// A token with location information
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Token {
    pub kind: TokenKind,
    pub line: usize,
    pub col: usize,
}

/// Lex VPy source code into a token stream
///
/// Handles:
/// - Indentation-based block structure (INDENT/DEDENT tokens)
/// - Comments (# and ; starters)
/// - String literals with escape sequences
/// - All operators and keywords
///
/// # Arguments
/// * `input` - VPy source code as string
///
/// # Returns
/// * `ParseResult<Vec<Token>>` - Token stream or error with line/col
pub fn lex(input: &str) -> ParseResult<Vec<Token>> {
    let mut tokens = Vec::new();
    let mut indent_stack: Vec<usize> = vec![0];

    for (line_idx, raw_line) in input.lines().enumerate() {
        let line_no = line_idx + 1;
        let trimmed = raw_line.trim();

        // Skip blank lines and comments
        if trimmed.is_empty() || trimmed.starts_with('#') || trimmed.starts_with(';') {
            continue;
        }

        // Check indentation
        let indent = raw_line.chars().take_while(|c| *c == ' ').count();
        if indent % 4 != 0 {
            return Err(ParseError::Generic(format!(
                "Indentation must be multiples of 4 (line {})",
                line_no
            )));
        }

        // Generate INDENT tokens
        let current = *indent_stack.last().unwrap();
        if indent > current {
            indent_stack.push(indent);
            tokens.push(Token {
                kind: TokenKind::Indent,
                line: line_no,
                col: 1,
            });
        }

        // Generate DEDENT tokens
        while indent < *indent_stack.last().unwrap() {
            indent_stack.pop();
            tokens.push(Token {
                kind: TokenKind::Dedent,
                line: line_no,
                col: 1,
            });
        }

        // Tokenize the line content
        lex_line(trimmed, line_no, &mut tokens)?;

        // Add newline marker
        tokens.push(Token {
            kind: TokenKind::Newline,
            line: line_no,
            col: raw_line.len(),
        });
    }

    // Emit final DEDENT tokens
    while indent_stack.len() > 1 {
        indent_stack.pop();
        tokens.push(Token {
            kind: TokenKind::Dedent,
            line: 0,
            col: 0,
        });
    }

    // EOF marker
    tokens.push(Token {
        kind: TokenKind::Eof,
        line: 0,
        col: 0,
    });

    Ok(tokens)
}

/// Tokenize a single logical line (content without leading whitespace)
fn lex_line(line: &str, line_no: usize, out: &mut Vec<Token>) -> ParseResult<()> {
    let chars: Vec<char> = line.chars().collect();
    let mut idx = 0;

    while idx < chars.len() {
        let c = chars[idx];

        match c {
            // Whitespace (skip - already processed indentation)
            ' ' => {
                idx += 1;
            }

            // Punctuation
            '(' => {
                out.push(token(TokenKind::LParen, line_no, idx));
                idx += 1;
            }
            ')' => {
                out.push(token(TokenKind::RParen, line_no, idx));
                idx += 1;
            }
            '[' => {
                out.push(token(TokenKind::LBracket, line_no, idx));
                idx += 1;
            }
            ']' => {
                out.push(token(TokenKind::RBracket, line_no, idx));
                idx += 1;
            }
            ':' => {
                out.push(token(TokenKind::Colon, line_no, idx));
                idx += 1;
            }
            ',' => {
                out.push(token(TokenKind::Comma, line_no, idx));
                idx += 1;
            }
            '.' => {
                out.push(token(TokenKind::Dot, line_no, idx));
                idx += 1;
            }

            // Operators with compound variants
            '+' => {
                if idx + 1 < chars.len() && chars[idx + 1] == '=' {
                    out.push(token(TokenKind::PlusEqual, line_no, idx));
                    idx += 2;
                } else {
                    out.push(token(TokenKind::Plus, line_no, idx));
                    idx += 1;
                }
            }
            '-' => {
                if idx + 1 < chars.len() && chars[idx + 1] == '=' {
                    out.push(token(TokenKind::MinusEqual, line_no, idx));
                    idx += 2;
                } else {
                    out.push(token(TokenKind::Minus, line_no, idx));
                    idx += 1;
                }
            }
            '*' => {
                if idx + 1 < chars.len() && chars[idx + 1] == '=' {
                    out.push(token(TokenKind::StarEqual, line_no, idx));
                    idx += 2;
                } else {
                    out.push(token(TokenKind::Star, line_no, idx));
                    idx += 1;
                }
            }
            '%' => {
                if idx + 1 < chars.len() && chars[idx + 1] == '=' {
                    out.push(token(TokenKind::PercentEqual, line_no, idx));
                    idx += 2;
                } else {
                    out.push(token(TokenKind::Percent, line_no, idx));
                    idx += 1;
                }
            }
            '/' => {
                if idx + 1 < chars.len() && chars[idx + 1] == '=' {
                    out.push(token(TokenKind::SlashEqual, line_no, idx));
                    idx += 2;
                } else if idx + 2 < chars.len()
                    && chars[idx + 1] == '/'
                    && chars[idx + 2] == '='
                {
                    out.push(token(TokenKind::SlashSlashEqual, line_no, idx));
                    idx += 3;
                } else if idx + 1 < chars.len() && chars[idx + 1] == '/' {
                    out.push(token(TokenKind::SlashSlash, line_no, idx));
                    idx += 2;
                } else {
                    out.push(token(TokenKind::Slash, line_no, idx));
                    idx += 1;
                }
            }

            // Bitwise operators
            '&' => {
                out.push(token(TokenKind::Amp, line_no, idx));
                idx += 1;
            }
            '|' => {
                out.push(token(TokenKind::Pipe, line_no, idx));
                idx += 1;
            }
            '^' => {
                out.push(token(TokenKind::Caret, line_no, idx));
                idx += 1;
            }
            '~' => {
                out.push(token(TokenKind::Tilde, line_no, idx));
                idx += 1;
            }
            '@' => {
                out.push(token(TokenKind::At, line_no, idx));
                idx += 1;
            }

            // Assignment and comparison
            '=' => {
                if idx + 1 < chars.len() && chars[idx + 1] == '=' {
                    out.push(token(TokenKind::EqEq, line_no, idx));
                    idx += 2;
                } else {
                    out.push(token(TokenKind::Equal, line_no, idx));
                    idx += 1;
                }
            }
            '!' => {
                if idx + 1 < chars.len() && chars[idx + 1] == '=' {
                    out.push(token(TokenKind::NotEq, line_no, idx));
                    idx += 2;
                } else {
                    return Err(ParseError::Generic(format!(
                        "Unexpected '!' at line {}:{} (did you mean != ?)",
                        line_no, idx + 1
                    )));
                }
            }
            '<' => {
                if idx + 1 < chars.len() && chars[idx + 1] == '<' {
                    out.push(token(TokenKind::ShiftLeft, line_no, idx));
                    idx += 2;
                } else if idx + 1 < chars.len() && chars[idx + 1] == '=' {
                    out.push(token(TokenKind::Le, line_no, idx));
                    idx += 2;
                } else {
                    out.push(token(TokenKind::Lt, line_no, idx));
                    idx += 1;
                }
            }
            '>' => {
                if idx + 1 < chars.len() && chars[idx + 1] == '>' {
                    out.push(token(TokenKind::ShiftRight, line_no, idx));
                    idx += 2;
                } else if idx + 1 < chars.len() && chars[idx + 1] == '=' {
                    out.push(token(TokenKind::Ge, line_no, idx));
                    idx += 2;
                } else {
                    out.push(token(TokenKind::Gt, line_no, idx));
                    idx += 1;
                }
            }

            // Comments (stop processing line)
            '#' | ';' => {
                break;
            }

            // Numbers (decimal, hex, binary)
            '0'..='9' => {
                let start = idx;

                // Hexadecimal
                if chars[idx] == '0' && idx + 1 < chars.len()
                    && (chars[idx + 1] == 'x' || chars[idx + 1] == 'X')
                {
                    idx += 2;
                    let hex_start = idx;
                    while idx < chars.len() && chars[idx].is_ascii_hexdigit() {
                        idx += 1;
                    }
                    let num = i32::from_str_radix(&line[hex_start..idx], 16).unwrap_or(0);
                    out.push(token(TokenKind::Number(num), line_no, start));
                }
                // Binary
                else if chars[idx] == '0' && idx + 1 < chars.len()
                    && (chars[idx + 1] == 'b' || chars[idx + 1] == 'B')
                {
                    idx += 2;
                    let bin_start = idx;
                    while idx < chars.len() && (chars[idx] == '0' || chars[idx] == '1') {
                        idx += 1;
                    }
                    let num = i32::from_str_radix(&line[bin_start..idx], 2).unwrap_or(0);
                    out.push(token(TokenKind::Number(num), line_no, start));
                }
                // Decimal
                else {
                    while idx < chars.len() && chars[idx].is_ascii_digit() {
                        idx += 1;
                    }
                    let num: i32 = line[start..idx].parse().unwrap();
                    out.push(token(TokenKind::Number(num), line_no, start));
                }
            }

            // String literals
            '"' => {
                let start_col = idx;
                idx += 1;
                let mut buf: Vec<u8> = Vec::new();

                while idx < chars.len() {
                    let c2 = chars[idx];
                    if c2 == '"' {
                        break;
                    }

                    if c2 == '\\' {
                        idx += 1;
                        if idx >= chars.len() {
                            return Err(ParseError::Generic(format!(
                                "Unterminated escape in string line {}:{}",
                                line_no, start_col + 1
                            )));
                        }

                        match chars[idx] {
                            'n' => buf.push(0x0A),
                            'r' => buf.push(0x0D),
                            't' => buf.push(0x09),
                            '"' => buf.push(b'"'),
                            '\\' => buf.push(b'\\'),
                            'x' => {
                                if idx + 2 >= chars.len() {
                                    return Err(ParseError::Generic(format!(
                                        "Incomplete hex escape line {}:{}",
                                        line_no, start_col + 1
                                    )));
                                }

                                let h1 = chars.get(idx + 1).copied().unwrap_or(' ');
                                let h2 = chars.get(idx + 2).copied().unwrap_or(' ');

                                if !(h1.is_ascii_hexdigit() && h2.is_ascii_hexdigit()) {
                                    return Err(ParseError::Generic(format!(
                                        "Invalid hex escape line {}:{}",
                                        line_no, start_col + 1
                                    )));
                                }

                                let hex_str = format!("{}{}", h1, h2);
                                let val = u8::from_str_radix(&hex_str, 16).unwrap();
                                buf.push(val);
                                idx += 2;
                            }
                            other => {
                                return Err(ParseError::Generic(format!(
                                    "Unknown escape \\{} at line {}:{}",
                                    other, line_no, start_col + 1
                                )));
                            }
                        }
                    } else {
                        buf.push(c2 as u8);
                    }
                    idx += 1;
                }

                if idx >= chars.len() || chars[idx] != '"' {
                    return Err(ParseError::Generic(format!(
                        "Unterminated string literal at line {}:{}",
                        line_no, start_col + 1
                    )));
                }

                let s = String::from_utf8_lossy(&buf).to_string();
                out.push(token(TokenKind::StringLit(s), line_no, start_col));
                idx += 1; // skip closing quote
            }

            // Identifiers and keywords
            'a'..='z' | 'A'..='Z' | '_' => {
                let start = idx;
                while idx < chars.len()
                    && (chars[idx].is_alphanumeric() || chars[idx] == '_')
                {
                    idx += 1;
                }

                let ident = &line[start..idx];
                let ident_lower = ident.to_lowercase();
                let kind = match ident_lower.as_str() {
                    "def" => TokenKind::Def,
                    "if" => TokenKind::If,
                    "elif" => TokenKind::Elif,
                    "else" => TokenKind::Else,
                    "for" => TokenKind::For,
                    "while" => TokenKind::While,
                    "break" => TokenKind::Break,
                    "continue" => TokenKind::Continue,
                    "pass" => TokenKind::Pass,
                    "const" => TokenKind::Const,
                    "vectorlist" => TokenKind::VectorList,
                    "switch" => TokenKind::Switch,
                    "case" => TokenKind::Case,
                    "default" => TokenKind::Default,
                    "meta" => TokenKind::Meta,
                    "in" => TokenKind::In,
                    "range" => TokenKind::Range,
                    "return" => TokenKind::Return,
                    "and" => TokenKind::And,
                    "or" => TokenKind::Or,
                    "not" => TokenKind::Not,
                    "true" => TokenKind::True,
                    "false" => TokenKind::False,
                    "from" => TokenKind::From,
                    "import" => TokenKind::Import,
                    "as" => TokenKind::As,
                    "export" => TokenKind::Export,
                    "struct" => TokenKind::Struct,
                    "self" => TokenKind::Self_,
                    _ => TokenKind::Identifier(ident.to_string()),
                };

                out.push(token(kind, line_no, start));
            }

            // Unexpected character
            _ => {
                return Err(ParseError::Generic(format!(
                    "Unexpected character '{}' at line {}:{}",
                    c, line_no, idx + 1
                )));
            }
        }
    }

    Ok(())
}

/// Create a Token with location information
fn token(kind: TokenKind, line: usize, col: usize) -> Token {
    Token { kind, line, col }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_simple_number() {
        let result = lex("42");
        assert!(result.is_ok());
        let tokens = result.unwrap();
        assert!(matches!(tokens[0].kind, TokenKind::Number(42)));
    }

    #[test]
    fn test_simple_identifier() {
        let result = lex("player_x");
        assert!(result.is_ok());
        let tokens = result.unwrap();
        assert!(
            matches!(tokens[0].kind, TokenKind::Identifier(ref s) if s == "player_x")
        );
    }

    #[test]
    fn test_keyword() {
        let result = lex("def");
        assert!(result.is_ok());
        let tokens = result.unwrap();
        assert!(matches!(tokens[0].kind, TokenKind::Def));
    }

    #[test]
    fn test_operators() {
        let result = lex("+ - * /");
        assert!(result.is_ok());
        let tokens = result.unwrap();
        assert!(matches!(tokens[0].kind, TokenKind::Plus));
        assert!(matches!(tokens[1].kind, TokenKind::Minus));
        assert!(matches!(tokens[2].kind, TokenKind::Star));
        assert!(matches!(tokens[3].kind, TokenKind::Slash));
    }

    #[test]
    fn test_string_literal() {
        let result = lex(r#""hello world""#);
        assert!(result.is_ok());
        let tokens = result.unwrap();
        assert!(
            matches!(tokens[0].kind, TokenKind::StringLit(ref s) if s == "hello world")
        );
    }

    #[test]
    fn test_hex_number() {
        let result = lex("0xFF");
        assert!(result.is_ok());
        let tokens = result.unwrap();
        assert!(matches!(tokens[0].kind, TokenKind::Number(255)));
    }

    #[test]
    fn test_binary_number() {
        let result = lex("0b1010");
        assert!(result.is_ok());
        let tokens = result.unwrap();
        assert!(matches!(tokens[0].kind, TokenKind::Number(10)));
    }

    #[test]
    fn test_indentation() {
        let input = "def main():\n    SET_INTENSITY(127)";
        let result = lex(input);
        assert!(result.is_ok());
        let tokens = result.unwrap();
        // Should have INDENT token
        assert!(tokens.iter().any(|t| matches!(t.kind, TokenKind::Indent)));
    }

    #[test]
    fn test_invalid_indent() {
        let input = "def main():\n  x = 1"; // 2 spaces (not multiple of 4)
        let result = lex(input);
        assert!(result.is_err());
    }
}
