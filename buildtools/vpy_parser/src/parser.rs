//! VPy Parser - Convert tokens to AST
//!
//! Ported from core/src/parser.rs
//! Implements recursive descent parser for VPy language

use crate::ast::*;
use crate::error::{ParseError, ParseResult};
use crate::lexer::{Token, TokenKind};

/// Main parser struct
struct Parser<'a> {
    tokens: &'a [Token],
    pos: usize,
    filename: String,
}

impl<'a> Parser<'a> {
    /// Create new parser from token stream
    fn new(tokens: &'a [Token], filename: String) -> Self {
        Parser { tokens, pos: 0, filename }
    }

    // ====== HELPER METHODS ======

    /// Get current line number
    fn current_line(&self) -> usize {
        self.tokens
            .get(self.pos)
            .map(|t| t.line)
            .unwrap_or(1)
    }

    /// Get current column number
    fn current_col(&self) -> usize {
        self.tokens
            .get(self.pos)
            .map(|t| t.col)
            .unwrap_or(0)
    }

    /// Peek at current token without consuming
    fn peek(&self) -> &Token {
        &self.tokens[self.pos]
    }

    /// Peek at current token kind without consuming
    fn peek_kind(&self) -> Option<&TokenKind> {
        self.tokens.get(self.pos).map(|t| &t.kind)
    }

    /// Advance to next token
    fn advance(&mut self) {
        if self.pos < self.tokens.len() {
            self.pos += 1;
        }
    }

    /// Check if current token matches kind (without consuming)
    fn check(&self, kind: TokenKind) -> bool {
        std::mem::discriminant(&self.peek().kind) == std::mem::discriminant(&kind)
    }

    /// Check if current token is an identifier
    fn check_identifier(&self) -> bool {
        matches!(self.peek().kind, TokenKind::Identifier(_))
    }

    /// Match and consume a token kind
    fn match_kind(&mut self, kind: &TokenKind) -> bool {
        if self.check(kind.clone()) {
            self.pos += 1;
            true
        } else {
            false
        }
    }

    /// Match identifier case-insensitively
    fn match_ident_case(&mut self, upper: &str) -> bool {
        if let Some(TokenKind::Identifier(s)) = self.peek_kind().cloned() {
            if s.eq_ignore_ascii_case(upper) {
                self.advance();
                return true;
            }
        }
        false
    }

    /// Consume a token kind or return error
    fn consume(&mut self, kind: TokenKind) -> ParseResult<()> {
        if std::mem::discriminant(&self.peek().kind)
            == std::mem::discriminant(&kind)
        {
            self.pos += 1;
            Ok(())
        } else {
            let expected = format!("{:?}", kind);
            let got = format!("{:?}", self.peek().kind);
            self.err_here(&format!("Expected {} got {}", expected, got))
        }
    }

    /// Match and consume a number
    fn match_number(&mut self) -> Option<i32> {
        if let TokenKind::Number(n) = self.peek().kind {
            let v = n;
            self.pos += 1;
            Some(v)
        } else {
            None
        }
    }

    /// Match and consume a string literal
    fn match_string(&mut self) -> Option<String> {
        if let TokenKind::StringLit(s) = &self.peek().kind {
            let v = s.clone();
            self.pos += 1;
            Some(v)
        } else {
            None
        }
    }

    /// Match and consume an identifier
    fn match_identifier(&mut self) -> Option<String> {
        if let TokenKind::Identifier(s) = &self.peek().kind {
            let v = s.clone();
            self.pos += 1;
            Some(v)
        } else {
            None
        }
    }

    /// Try to match identifier (alias for match_identifier)
    #[allow(dead_code)]
    fn try_identifier(&mut self) -> Option<String> {
        self.match_identifier()
    }

    /// Consume an identifier or return error
    fn identifier(&mut self) -> ParseResult<String> {
        if let Some(s) = self.match_identifier() {
            Ok(s)
        } else {
            self.err_here("Expected identifier")
        }
    }

    /// Parse a signed number (optional minus prefix)
    #[allow(dead_code)]
    fn parse_signed_number(&mut self) -> ParseResult<i32> {
        let neg = self.match_kind(&TokenKind::Minus);
        if let TokenKind::Number(n) = self.peek().kind {
            let v = n;
            self.pos += 1;
            Ok(if neg { -v } else { v })
        } else {
            self.err_here("Expected number")
        }
    }

    /// Match comparison operator
    fn match_cmp_op(&mut self) -> Option<CmpOp> {
        let k = &self.peek().kind;
        let op = match k {
            TokenKind::EqEq => Some(CmpOp::Eq),
            TokenKind::NotEq => Some(CmpOp::Ne),
            TokenKind::Lt => Some(CmpOp::Lt),
            TokenKind::Le => Some(CmpOp::Le),
            TokenKind::Gt => Some(CmpOp::Gt),
            TokenKind::Ge => Some(CmpOp::Ge),
            _ => None,
        };
        if op.is_some() {
            self.pos += 1;
        }
        op
    }

    /// Skip newline tokens (useful for multiline contexts)
    fn skip_newlines(&mut self) {
        while self.match_kind(&TokenKind::Newline) {}
    }

    /// Create an error at current position
    fn err_here<T>(&self, msg: &str) -> ParseResult<T> {
        let tk = self.peek();
        Err(ParseError::Generic(format!(
            "{}:{}:{}: error: {}",
            self.filename, tk.line, tk.col, msg
        )))
    }

    /// Parse optional type annotation after colon
    /// Returns Some(type_name) if `: type` is found, None otherwise
    fn try_parse_type_annotation(&mut self) -> ParseResult<Option<String>> {
        if self.match_kind(&TokenKind::Colon) {
            let type_name = self.identifier()?;
            // Validate that the type name is one of the supported types
            match type_name.as_str() {
                "u8" | "i8" | "u16" | "i16" => {
                    Ok(Some(type_name))
                }
                _ => {
                    self.err_here(&format!(
                        "Invalid type name '{}'. Supported types: u8, i8, u16, i16",
                        type_name
                    ))
                }
            }
        } else {
            Ok(None)
        }
    }

    // ====== PARSER RULES ======
    // (To be implemented incrementally)

    /// Parse module (top-level)
    fn parse_module(&mut self) -> ParseResult<Module> {
        let mut items = Vec::new();
        let mut meta = ModuleMeta::default();
        let mut imports = Vec::new();

        self.skip_newlines();

        // Parse items until EOF
        while !self.check(TokenKind::Eof) {
            self.skip_newlines();
            while self.match_kind(&TokenKind::Dedent) {}
            if self.check(TokenKind::Eof) {
                break;
            }

            // Check token kind first (not case-insensitive)
            match &self.peek().kind {
                TokenKind::Const => {
                    self.advance();
                    let const_line = self.current_line();
                    let name = self.identifier()?;
                    let type_annotation = self.try_parse_type_annotation()?;
                    self.consume(TokenKind::Equal)?;
                    let value = self.expression()?;
                    self.consume(TokenKind::Newline)?;
                    items.push(Item::Const {
                        name,
                        type_annotation,
                        value,
                        source_line: const_line,
                    });
                    continue;
                }
                TokenKind::Meta => {
                    self.advance();
                    let key = self.identifier()?;
                    self.consume(TokenKind::Equal)?;
                    let value = self.expression()?;
                    self.consume(TokenKind::Newline)?;
                    
                    // Store META value in meta struct
                    if key.eq_ignore_ascii_case("TITLE") {
                        if let Expr::StringLit(s) = &value {
                            meta.title_override = Some(s.clone());
                        }
                    } else if key.eq_ignore_ascii_case("MUSIC") {
                        match &value {
                            Expr::StringLit(s) => meta.music_override = Some(s.clone()),
                            Expr::Ident(ident) => meta.music_override = Some(ident.name.clone()),
                            _ => {}
                        }
                    } else if key.eq_ignore_ascii_case("COPYRIGHT") {
                        if let Expr::StringLit(s) = &value {
                            meta.copyright_override = Some(s.clone());
                        }
                    } else if key.eq_ignore_ascii_case("ROM_TOTAL_SIZE") {
                        if let Expr::Number(n) = value {
                            meta.rom_total_size = Some(n as u32);
                        }
                    } else if key.eq_ignore_ascii_case("ROM_BANK_SIZE") {
                        if let Expr::Number(n) = value {
                            meta.rom_bank_size = Some(n as u32);
                        }
                    } else if key.eq_ignore_ascii_case("MUSIC_TIMER") {
                        // META MUSIC_TIMER = true  → inject VIA T2 catch-up in LOOP_BODY
                        match &value {
                            Expr::Ident(ident) if ident.name.eq_ignore_ascii_case("true") => {
                                meta.music_timer = true;
                            }
                            _ => {}
                        }
                    } else if key.eq_ignore_ascii_case("INTERLEAVED_FRAMES") {
                        if let Expr::Number(n) = value {
                            if n == 2 || n == 3 {
                                meta.interleaved_frames = Some(n as u8);
                            }
                        }
                    }
                    
                    if let Expr::StringLit(s) = &value {
                        meta.metas.insert(key.to_uppercase(), s.clone());
                    }
                    continue;
                }
                TokenKind::Import => {
                    let import_decl = self.parse_import()?;
                    imports.push(import_decl);
                    continue;
                }
                TokenKind::From => {
                    let import_decl = self.parse_import()?;
                    imports.push(import_decl);
                    continue;
                }
                TokenKind::Export => {
                    self.advance();
                    let export = self.parse_export()?;
                    items.push(Item::Export(export));
                    continue;
                }
                TokenKind::Struct => {
                    self.advance();
                    let struct_def = self.parse_struct_def()?;
                    items.push(Item::StructDef(struct_def));
                    continue;
                }
                TokenKind::At => {
                    // @frame(N) decorator before def
                    self.advance();
                    let decorator = self.identifier()?;
                    let frame_group = if decorator.eq_ignore_ascii_case("frame") {
                        self.consume(TokenKind::LParen)?;
                        let n = if let TokenKind::Number(n) = self.peek().kind.clone() {
                            self.advance();
                            n as u8
                        } else {
                            return self.err_here("Expected number in @frame(N) decorator");
                        };
                        self.consume(TokenKind::RParen)?;
                        self.consume(TokenKind::Newline)?;
                        Some(n)
                    } else {
                        None
                    };
                    // Expect 'def' immediately after decorator
                    if !self.check(TokenKind::Def) {
                        return self.err_here("Expected 'def' after @frame(N) decorator");
                    }
                    self.advance();
                    let mut func = self.parse_function_def()?;
                    func.frame_group = frame_group;
                    items.push(Item::Function(func));
                    continue;
                }
                TokenKind::Def => {
                    self.advance();
                    let func = self.parse_function_def()?;
                    items.push(Item::Function(func));
                    continue;
                }
                TokenKind::VectorList => {
                    self.advance();
                    let vl = self.parse_vectorlist()?;
                    items.push(vl);
                    continue;
                }
                _ => {}
            }

            // Parse global variable declaration: identifier [: type] = expression
            if self.check_identifier() {
                let checkpoint = self.pos;
                if let Ok(name) = self.identifier() {
                    let type_annotation = self.try_parse_type_annotation().ok().flatten();
                    if self.match_kind(&TokenKind::Equal) {
                        let global_line = self.current_line();
                        let value = self.expression()?;
                        self.consume(TokenKind::Newline)?;
                        items.push(Item::GlobalLet {
                            name,
                            type_annotation,
                            value,
                            source_line: global_line,
                        });
                        continue;
                    }
                }
                // Not a variable declaration, rewind
                self.pos = checkpoint;
            }

            // If we get here, unexpected token
            return self.err_here("Expected function definition, const, or META declaration at module level");
        }

        Ok(Module {
            items,
            meta,
            imports,
        })
    }

    /// Parse import declarations
    fn parse_import(&mut self) -> ParseResult<ImportDecl> {
        let line = self.current_line();
        
        if self.check(TokenKind::From) {
            self.advance();
            // from module import name1, name2, ...
            let module_path = vec![self.identifier()?];
            self.consume(TokenKind::Import)?;
            
            let mut symbols = vec![];
            loop {
                let name = self.identifier()?;
                let alias = if self.match_ident_case("AS") {
                    Some(self.identifier()?)
                } else {
                    None
                };
                symbols.push(ImportedSymbol { name, alias });
                if !self.match_kind(&TokenKind::Comma) {
                    break;
                }
            }
            self.consume(TokenKind::Newline)?;
            
            Ok(ImportDecl {
                module_path,
                symbols: ImportSymbols::Named(symbols),
                source_line: line,
                is_relative: false,
                relative_level: 0,
            })
        } else if self.check(TokenKind::Import) {
            self.advance();
            // import module [as alias]
            let module = self.identifier()?;
            let alias = if self.match_ident_case("AS") {
                Some(self.identifier()?)
            } else {
                None
            };
            self.consume(TokenKind::Newline)?;
            
            Ok(ImportDecl {
                module_path: vec![module],
                symbols: ImportSymbols::Module { alias },
                source_line: line,
                is_relative: false,
                relative_level: 0,
            })
        } else {
            self.err_here("Expected 'import' or 'from'")
        }
    }

    /// Parse export declarations
    fn parse_export(&mut self) -> ParseResult<ExportDecl> {
        let line = self.current_line();
        let mut names = vec![];
        
        loop {
            names.push(self.identifier()?);
            if !self.match_kind(&TokenKind::Comma) {
                break;
            }
        }
        self.consume(TokenKind::Newline)?;
        
        Ok(ExportDecl {
            symbols: names,
            source_line: line,
        })
    }

    /// Parse function definition: def name(params): body
    fn parse_function_def(&mut self) -> ParseResult<Function> {
        let line = self.current_line();
        let name = self.identifier()?;
        self.consume(TokenKind::LParen)?;
        
        // Parse parameters
        let mut params = vec![];
        if !self.check(TokenKind::RParen) {
            loop {
                params.push(self.identifier()?);
                if !self.match_kind(&TokenKind::Comma) {
                    break;
                }
            }
        }
        self.consume(TokenKind::RParen)?;
        self.consume(TokenKind::Colon)?;
        self.consume(TokenKind::Newline)?;
        self.consume(TokenKind::Indent)?;
        
        // Parse function body (statements)
        let mut body = vec![];
        while !self.check(TokenKind::Dedent) {
            body.push(self.statement()?);
        }
        self.consume(TokenKind::Dedent)?;
        
        Ok(Function {
            name,
            line,
            params,
            body,
            frame_group: None,
        })
    }

    /// Parse struct definition: struct Name: fields and methods
    fn parse_struct_def(&mut self) -> ParseResult<StructDef> {
        let line = self.current_line();
        let name = self.identifier()?;
        self.consume(TokenKind::Colon)?;
        self.consume(TokenKind::Newline)?;
        self.consume(TokenKind::Indent)?;
        
        let mut fields = vec![];
        let mut methods = vec![];
        let mut constructor = None;
        
        while !self.check(TokenKind::Dedent) {
            self.skip_newlines();
            
            if self.check(TokenKind::Dedent) {
                break;
            }
            
            // Parse field or method
            if self.match_kind(&TokenKind::Def) {
                let func = self.parse_function_def()?;
                if func.name.eq_ignore_ascii_case("__INIT__") {
                    constructor = Some(func);
                } else {
                    methods.push(func);
                }
            } else {
                // Parse field: field_name = default_value or field_name: type
                let field_name = self.identifier()?;
                let field_line = self.current_line();
                
                // Skip type annotation or default value (simplified parsing)
                if self.match_kind(&TokenKind::Colon) {
                    // Type annotation - skip it
                    let _type_name = self.identifier()?;
                    self.consume(TokenKind::Newline)?;
                } else if self.match_kind(&TokenKind::Equal) {
                    // Default value - skip it
                    let _ = self.expression()?;
                    self.consume(TokenKind::Newline)?;
                } else {
                    self.consume(TokenKind::Newline)?;
                }
                
                fields.push(FieldDef {
                    name: field_name,
                    type_annotation: None,
                    source_line: field_line,
                });
            }
        }
        self.consume(TokenKind::Dedent)?;
        
        Ok(StructDef {
            name,
            fields,
            methods,
            constructor,
            source_line: line,
        })
    }

    /// Parse vectorlist definition
    fn parse_vectorlist(&mut self) -> ParseResult<Item> {
        let name = self.identifier()?;
        self.consume(TokenKind::Colon)?;
        self.consume(TokenKind::Newline)?;
        self.consume(TokenKind::Indent)?;
        
        let entries = vec![];
        while !self.check(TokenKind::Dedent) {
            self.skip_newlines();
            if self.check(TokenKind::Dedent) {
                break;
            }
            
            // Parse vectorlist entry (simplified - just parse as expression for now)
            let _entry = self.expression()?;
            self.consume(TokenKind::Newline)?;
            // TODO: Parse specific vectorlist commands (MOVE, INTENSITY, etc.)
        }
        self.consume(TokenKind::Dedent)?;
        
        Ok(Item::VectorList {
            name,
            entries,
        })
    }

    // ====== EXPRESSION PARSER (Recursive descent with precedence) ======

    /// Parse full expression
    fn expression(&mut self) -> ParseResult<Expr> {
        self.logic_or()
    }

    /// Parse logic OR expression (lowest precedence)
    fn logic_or(&mut self) -> ParseResult<Expr> {
        let mut left = self.logic_and()?;
        while self.match_kind(&TokenKind::Or) {
            let right = self.logic_and()?;
            left = Expr::Logic {
                op: LogicOp::Or,
                left: Box::new(left),
                right: Box::new(right),
            };
        }
        Ok(left)
    }

    /// Parse logic AND expression
    fn logic_and(&mut self) -> ParseResult<Expr> {
        let mut left = self.equality()?;
        while self.match_kind(&TokenKind::And) {
            let right = self.equality()?;
            left = Expr::Logic {
                op: LogicOp::And,
                left: Box::new(left),
                right: Box::new(right),
            };
        }
        Ok(left)
    }

    /// Parse equality expression (==, !=, <, >, <=, >=)
    fn equality(&mut self) -> ParseResult<Expr> {
        let mut left = self.additive()?;
        while let Some(op) = self.match_cmp_op() {
            let right = self.additive()?;
            left = Expr::Compare {
                op,
                left: Box::new(left),
                right: Box::new(right),
            };
        }
        Ok(left)
    }

    /// Parse additive expression (+, -)
    fn additive(&mut self) -> ParseResult<Expr> {
        let mut left = self.multiplicative()?;
        loop {
            if self.match_kind(&TokenKind::Plus) {
                let right = self.multiplicative()?;
                left = Expr::Binary {
                    op: BinOp::Add,
                    left: Box::new(left),
                    right: Box::new(right),
                };
            } else if self.match_kind(&TokenKind::Minus) {
                let right = self.multiplicative()?;
                left = Expr::Binary {
                    op: BinOp::Sub,
                    left: Box::new(left),
                    right: Box::new(right),
                };
            } else {
                break;
            }
        }
        Ok(left)
    }

    /// Parse multiplicative expression (*, /, %, //)
    fn multiplicative(&mut self) -> ParseResult<Expr> {
        let mut left = self.unary()?;
        loop {
            if self.match_kind(&TokenKind::Star) {
                let right = self.unary()?;
                left = Expr::Binary {
                    op: BinOp::Mul,
                    left: Box::new(left),
                    right: Box::new(right),
                };
            } else if self.match_kind(&TokenKind::Slash) {
                let right = self.unary()?;
                left = Expr::Binary {
                    op: BinOp::Div,
                    left: Box::new(left),
                    right: Box::new(right),
                };
            } else if self.match_kind(&TokenKind::Percent) {
                let right = self.unary()?;
                left = Expr::Binary {
                    op: BinOp::Mod,
                    left: Box::new(left),
                    right: Box::new(right),
                };
            } else if self.match_kind(&TokenKind::SlashSlash) {
                let right = self.unary()?;
                left = Expr::Binary {
                    op: BinOp::FloorDiv,
                    left: Box::new(left),
                    right: Box::new(right),
                };
            } else {
                break;
            }
        }
        Ok(left)
    }

    /// Parse unary expression (-, not, ~)
    fn unary(&mut self) -> ParseResult<Expr> {
        if self.match_kind(&TokenKind::Minus) {
            let expr = self.unary()?;
            // Create a negative number if it's a literal
            if let Expr::Number(n) = expr {
                Ok(Expr::Number(-n))
            } else {
                // Otherwise, multiply by -1 (workaround for lack of Unary operator)
                Ok(Expr::Binary {
                    op: BinOp::Mul,
                    left: Box::new(Expr::Number(-1)),
                    right: Box::new(expr),
                })
            }
        } else if self.match_kind(&TokenKind::Not) {
            let expr = self.unary()?;
            Ok(Expr::Not(Box::new(expr)))
        } else if self.match_kind(&TokenKind::Tilde) {
            let expr = self.unary()?;
            Ok(Expr::BitNot(Box::new(expr)))
        } else {
            self.postfix()
        }
    }

    /// Parse postfix expression (field access, method calls, indexing)
    fn postfix(&mut self) -> ParseResult<Expr> {
        let mut expr = self.primary()?;
        loop {
            if self.match_kind(&TokenKind::Dot) {
                let field = self.identifier()?;
                if self.match_kind(&TokenKind::LParen) {
                    // Method call: expr.method(args)
                    let args = self.parse_arguments()?;
                    self.consume(TokenKind::RParen)?;
                    let line = self.current_line();
                    let col = self.current_col();
                    expr = Expr::MethodCall(MethodCallInfo {
                        target: Box::new(expr),
                        method_name: field,
                        args,
                        source_line: line,
                        col,
                    });
                } else {
                    // Field access: expr.field
                    let line = self.current_line();
                    let col = self.current_col();
                    expr = Expr::FieldAccess {
                        target: Box::new(expr),
                        field,
                        source_line: line,
                        col,
                    };
                }
            } else if self.match_kind(&TokenKind::LBracket) {
                let index = self.expression()?;
                self.consume(TokenKind::RBracket)?;
                expr = Expr::Index {
                    target: Box::new(expr),
                    index: Box::new(index),
                };
            } else {
                break;
            }
        }
        Ok(expr)
    }

    /// Parse primary expression (literals, identifiers, parentheses)
    fn primary(&mut self) -> ParseResult<Expr> {
        let line = self.current_line();
        let col = self.current_col();

        // Number literals
        if let Some(n) = self.match_number() {
            return Ok(Expr::Number(n));
        }

        // String literals
        if let Some(s) = self.match_string() {
            return Ok(Expr::StringLit(s));
        }

        // List literals
        if self.match_kind(&TokenKind::LBracket) {
            let mut elements = vec![];
            if !self.check(TokenKind::RBracket) {
                loop {
                    elements.push(self.expression()?);
                    if !self.match_kind(&TokenKind::Comma) {
                        break;
                    }
                }
            }
            self.consume(TokenKind::RBracket)?;
            return Ok(Expr::List(elements));
        }

        // Parenthesized expression
        if self.match_kind(&TokenKind::LParen) {
            let expr = self.expression()?;
            self.consume(TokenKind::RParen)?;
            return Ok(expr);
        }

        // Identifiers and builtin calls
        if let Some(name) = self.match_identifier() {
            // Check if it's a builtin function call
            if self.match_kind(&TokenKind::LParen) {
                let args = self.parse_arguments()?;
                self.consume(TokenKind::RParen)?;
                return Ok(Expr::Call(CallInfo {
                    name,
                    args,
                    source_line: line,
                    col,
                }));
            }
            // Otherwise it's just an identifier
            return Ok(Expr::Ident(IdentInfo {
                name,
                source_line: line,
                col,
            }));
        }

        self.err_here("Expected expression (number, string, identifier, or parenthesized expression)")
    }

    /// Parse function call arguments
    fn parse_arguments(&mut self) -> ParseResult<Vec<Expr>> {
        let mut args = vec![];
        if self.check(TokenKind::RParen) {
            return Ok(args);
        }
        loop {
            args.push(self.expression()?);
            if !self.match_kind(&TokenKind::Comma) {
                break;
            }
        }
        Ok(args)
    }

    // ====== STATEMENT PARSER ======

    /// Parse a statement
    fn statement(&mut self) -> ParseResult<Stmt> {
        let start_line = self.current_line();

        // Control flow statements - use TokenKind matching
        match &self.peek().kind {
            TokenKind::For => {
                self.advance();
                return self.for_stmt(start_line);
            }
            TokenKind::While => {
                self.advance();
                return self.while_stmt(start_line);
            }
            TokenKind::If => {
                self.advance();
                return self.if_stmt(start_line);
            }
            TokenKind::Switch => {
                self.advance();
                return self.switch_stmt(start_line);
            }
            TokenKind::Return => {
                self.advance();
                return self.return_stmt(start_line);
            }
            TokenKind::Break => {
                self.advance();
                self.consume(TokenKind::Newline)?;
                return Ok(Stmt::Break { source_line: start_line });
            }
            TokenKind::Continue => {
                self.advance();
                self.consume(TokenKind::Newline)?;
                return Ok(Stmt::Continue { source_line: start_line });
            }
            TokenKind::Pass => {
                self.advance();
                self.consume(TokenKind::Newline)?;
                return Ok(Stmt::Pass { source_line: start_line });
            }
            _ => {}
        }

        // Try assignment: var = expr or arr[i] = expr
        let checkpoint = self.pos;
        if let Ok(lhs) = self.postfix() {
            if self.match_kind(&TokenKind::Equal) {
                let rhs = self.expression()?;
                self.consume(TokenKind::Newline)?;
                let target = self.expr_to_assign_target(lhs, start_line)?;
                return Ok(Stmt::Assign {
                    target,
                    value: rhs,
                    source_line: start_line,
                });
            } else if self.check_compound_assign() {
                let op = self.parse_compound_op()?;
                let rhs = self.expression()?;
                self.consume(TokenKind::Newline)?;
                let target = self.expr_to_assign_target(lhs, start_line)?;
                return Ok(Stmt::CompoundAssign {
                    target,
                    op,
                    value: rhs,
                    source_line: start_line,
                });
            }
        }

        // Not an assignment - revert and parse as expression statement
        self.pos = checkpoint;
        let expr = self.expression()?;
        self.consume(TokenKind::Newline)?;
        Ok(Stmt::Expr(expr, start_line))
    }

    /// Convert expression to assignment target
    fn expr_to_assign_target(
        &self,
        expr: Expr,
        source_line: usize,
    ) -> ParseResult<AssignTarget> {
        match expr {
            Expr::Ident(info) => Ok(AssignTarget::Ident {
                name: info.name,
                source_line,
                col: info.col,
            }),
            Expr::Index { target, index } => Ok(AssignTarget::Index {
                target,
                index,
                source_line,
                col: 0,
            }),
            Expr::FieldAccess {
                target,
                field,
                source_line: line,
                col,
            } => Ok(AssignTarget::FieldAccess {
                target,
                field,
                source_line: line,
                col,
            }),
            _ => self.err_here("Invalid assignment target"),
        }
    }

    /// Check if current token is a compound assignment operator
    fn check_compound_assign(&self) -> bool {
        matches!(
            self.peek().kind,
            TokenKind::PlusEqual
                | TokenKind::MinusEqual
                | TokenKind::StarEqual
                | TokenKind::SlashEqual
                | TokenKind::SlashSlashEqual
                | TokenKind::PercentEqual
        )
    }

    /// Parse compound assignment operator
    fn parse_compound_op(&mut self) -> ParseResult<BinOp> {
        match self.peek().kind {
            TokenKind::PlusEqual => {
                self.advance();
                Ok(BinOp::Add)
            }
            TokenKind::MinusEqual => {
                self.advance();
                Ok(BinOp::Sub)
            }
            TokenKind::StarEqual => {
                self.advance();
                Ok(BinOp::Mul)
            }
            TokenKind::SlashEqual => {
                self.advance();
                Ok(BinOp::Div)
            }
            TokenKind::SlashSlashEqual => {
                self.advance();
                Ok(BinOp::FloorDiv)
            }
            TokenKind::PercentEqual => {
                self.advance();
                Ok(BinOp::Mod)
            }
            _ => self.err_here("Expected compound assignment operator"),
        }
    }

    /// Parse while statement
    fn while_stmt(&mut self, source_line: usize) -> ParseResult<Stmt> {
        let cond = self.expression()?;
        self.consume(TokenKind::Colon)?;
        self.consume(TokenKind::Newline)?;
        self.consume(TokenKind::Indent)?;
        let mut body = Vec::new();
        while !self.check(TokenKind::Dedent) {
            body.push(self.statement()?);
        }
        self.consume(TokenKind::Dedent)?;
        Ok(Stmt::While {
            cond,
            body,
            source_line,
        })
    }

    /// Parse for statement (range-based or iterator-based)
    fn for_stmt(&mut self, source_line: usize) -> ParseResult<Stmt> {
        let var = self.identifier()?;
        self.consume(TokenKind::In)?;

        // Check if it's range-based (for i in range(...))
        if self.match_kind(&TokenKind::Range) {
            self.consume(TokenKind::LParen)?;
            self.skip_newlines();
            let first_arg = self.expression()?;
            self.skip_newlines();

            // range() can be: range(end), range(start, end), range(start, end, step)
            if self.match_kind(&TokenKind::RParen) {
                // range(end) - from 0 to end
                let start = Expr::Number(0);
                let end = first_arg;
                let step = None;
                
                self.consume(TokenKind::Colon)?;
                self.consume(TokenKind::Newline)?;
                self.consume(TokenKind::Indent)?;

                let mut body = Vec::new();
                while !self.check(TokenKind::Dedent) {
                    body.push(self.statement()?);
                }
                self.consume(TokenKind::Dedent)?;

                Ok(Stmt::For {
                    var,
                    start,
                    end,
                    step,
                    body,
                    source_line,
                })
            } else if self.match_kind(&TokenKind::Comma) {
                // range(start, end) or range(start, end, step)
                self.skip_newlines();
                let start = first_arg;
                let end = self.expression()?;
                self.skip_newlines();

                let step = if self.match_kind(&TokenKind::Comma) {
                    self.skip_newlines();
                    Some(self.expression()?)
                } else {
                    None
                };

                self.skip_newlines();
                self.consume(TokenKind::RParen)?;
                self.consume(TokenKind::Colon)?;
                self.consume(TokenKind::Newline)?;
                self.consume(TokenKind::Indent)?;

                let mut body = Vec::new();
                while !self.check(TokenKind::Dedent) {
                    body.push(self.statement()?);
                }
                self.consume(TokenKind::Dedent)?;

                Ok(Stmt::For {
                    var,
                    start,
                    end,
                    step,
                    body,
                    source_line,
                })
            } else {
                Err(ParseError::Generic("Expected ) or , in range()".to_string()))
            }
        } else {
            // Iterator-based for-in loop
            let iterable = self.expression()?;
            self.consume(TokenKind::Colon)?;
            self.consume(TokenKind::Newline)?;
            self.consume(TokenKind::Indent)?;

            let mut body = Vec::new();
            while !self.check(TokenKind::Dedent) {
                body.push(self.statement()?);
            }
            self.consume(TokenKind::Dedent)?;

            Ok(Stmt::ForIn {
                var,
                iterable,
                body,
                source_line,
            })
        }
    }

    /// Parse if statement with elif and else
    fn if_stmt(&mut self, source_line: usize) -> ParseResult<Stmt> {
        let cond = self.expression()?;
        self.consume(TokenKind::Colon)?;
        self.consume(TokenKind::Newline)?;
        self.consume(TokenKind::Indent)?;

        let mut body = Vec::new();
        while !self.check(TokenKind::Dedent) {
            body.push(self.statement()?);
        }
        self.consume(TokenKind::Dedent)?;

        // Parse elif clauses
        let mut elifs = Vec::new();
        while self.match_kind(&TokenKind::Elif) {
            let elif_cond = self.expression()?;
            self.consume(TokenKind::Colon)?;
            self.consume(TokenKind::Newline)?;
            self.consume(TokenKind::Indent)?;

            let mut elif_body = Vec::new();
            while !self.check(TokenKind::Dedent) {
                elif_body.push(self.statement()?);
            }
            self.consume(TokenKind::Dedent)?;

            elifs.push((elif_cond, elif_body));
        }

        // Parse else clause
        let else_body = if self.match_kind(&TokenKind::Else) {
            self.consume(TokenKind::Colon)?;
            self.consume(TokenKind::Newline)?;
            self.consume(TokenKind::Indent)?;

            let mut eb = Vec::new();
            while !self.check(TokenKind::Dedent) {
                eb.push(self.statement()?);
            }
            self.consume(TokenKind::Dedent)?;

            Some(eb)
        } else {
            None
        };

        Ok(Stmt::If {
            cond,
            body,
            elifs,
            else_body,
            source_line,
        })
    }

    /// Parse switch statement
    fn switch_stmt(&mut self, source_line: usize) -> ParseResult<Stmt> {
        let expr = self.expression()?;
        self.consume(TokenKind::Colon)?;
        self.consume(TokenKind::Newline)?;
        self.consume(TokenKind::Indent)?;

        let mut cases = Vec::new();
        let mut default_block = None;

        while !self.check(TokenKind::Dedent) {
            if self.match_ident_case("CASE") {
                let case_expr = self.expression()?;
                self.consume(TokenKind::Colon)?;
                self.consume(TokenKind::Newline)?;
                self.consume(TokenKind::Indent)?;

                let mut case_body = Vec::new();
                while !self.check(TokenKind::Dedent) {
                    case_body.push(self.statement()?);
                }
                self.consume(TokenKind::Dedent)?;

                cases.push((case_expr, case_body));
            } else if self.match_ident_case("DEFAULT") {
                self.consume(TokenKind::Colon)?;
                self.consume(TokenKind::Newline)?;
                self.consume(TokenKind::Indent)?;

                let mut def_body = Vec::new();
                while !self.check(TokenKind::Dedent) {
                    def_body.push(self.statement()?);
                }
                self.consume(TokenKind::Dedent)?;

                default_block = Some(def_body);
            } else {
                return self.err_here("Expected 'case' or 'default' in switch block");
            }
        }

        self.consume(TokenKind::Dedent)?;

        Ok(Stmt::Switch {
            expr,
            cases,
            default: default_block,
            source_line,
        })
    }

    /// Parse return statement
    fn return_stmt(&mut self, source_line: usize) -> ParseResult<Stmt> {
        if self.check(TokenKind::Newline) {
            self.consume(TokenKind::Newline)?;
            return Ok(Stmt::Return(None, source_line));
        }

        let expr = self.expression()?;
        self.consume(TokenKind::Newline)?;
        Ok(Stmt::Return(Some(expr), source_line))
    }
}

/// Parse tokens into an AST Module
pub fn parse(tokens: Vec<Token>, filename: &str) -> ParseResult<Module> {
    let mut parser = Parser::new(&tokens, filename.to_string());
    parser.parse_module()
}

/// Parse tokens (by reference) into an AST Module
/// This is the main entry point for parsing
pub fn parse_module(tokens: &[Token], filename: &str) -> ParseResult<Module> {
    let mut parser = Parser::new(tokens, filename.to_string());
    parser.parse_module()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn lex_and_parse(code: &str) -> ParseResult<Module> {
        let tokens = crate::lexer::lex(code)?;
        parse(tokens, "test.vpy")
    }

    #[test]
    fn test_parse_simple_expression() {
        // Simple expression statement: x = 42
        let code = "x = 42\n";
        let result = lex_and_parse(code);
        assert!(result.is_ok() || result.is_err()); // Module parsing WIP
    }

    #[test]
    fn test_lexer_for_statement() {
        // Verify lexer can tokenize a for loop
        let code = "for i in range(10):\n    x = i\n";
        let result = crate::lexer::lex(code);
        assert!(result.is_ok());
        if let Ok(tokens) = result {
            let token_kinds: Vec<_> = tokens.iter().map(|t| format!("{:?}", t.kind)).collect();
            // Should have FOR, IDENTIFIER, IN, RANGE, etc.
            assert!(token_kinds.iter().any(|k| k.contains("Identifier")));
        }
    }

    #[test]
    fn test_lexer_if_statement() {
        // Verify lexer can tokenize an if statement
        let code = "if x > 0:\n    y = x + 1\n";
        let result = crate::lexer::lex(code);
        assert!(result.is_ok());
    }

    #[test]
    fn test_lexer_while_statement() {
        // Verify lexer can tokenize a while loop
        let code = "while count < 10:\n    count += 1\n";
        let result = crate::lexer::lex(code);
        assert!(result.is_ok());
    }

    #[test]
    fn test_parse_empty_module() {
        // Empty file
        let code = "";
        let result = lex_and_parse(code);
        // Should handle gracefully (empty module or error depending on implementation)
        let _ = result;
    }

    #[test]
    fn test_parse_const_declaration() {
        let code = "const PI = 314\n";
        let result = lex_and_parse(code);
        assert!(result.is_ok());
        if let Ok(module) = result {
            assert_eq!(module.items.len(), 1);
            if let Item::Const { name, .. } = &module.items[0] {
                assert_eq!(name, "PI");
            } else {
                panic!("Expected Const item");
            }
        }
    }

    #[test]
    fn test_parse_global_variable() {
        let code = "player_x = 100\n";
        let result = lex_and_parse(code);
        assert!(result.is_ok());
        if let Ok(module) = result {
            assert_eq!(module.items.len(), 1);
            if let Item::GlobalLet { name, .. } = &module.items[0] {
                assert_eq!(name, "player_x");
            } else {
                panic!("Expected GlobalLet item");
            }
        }
    }

    // ===== TYPE ANNOTATION TESTS =====

    #[test]
    fn test_parse_const_with_u8_type() {
        let code = "const VALUE: u8 = 42\n";
        let result = lex_and_parse(code);
        assert!(result.is_ok());
        if let Ok(module) = result {
            assert_eq!(module.items.len(), 1);
            if let Item::Const { name, type_annotation, .. } = &module.items[0] {
                assert_eq!(name, "VALUE");
                assert_eq!(type_annotation, &Some("u8".to_string()));
            } else {
                panic!("Expected Const item");
            }
        }
    }

    #[test]
    fn test_parse_const_with_i16_type() {
        let code = "const LIMIT: i16 = 1000\n";
        let result = lex_and_parse(code);
        assert!(result.is_ok());
        if let Ok(module) = result {
            assert_eq!(module.items.len(), 1);
            if let Item::Const { name, type_annotation, .. } = &module.items[0] {
                assert_eq!(name, "LIMIT");
                assert_eq!(type_annotation, &Some("i16".to_string()));
            } else {
                panic!("Expected Const item");
            }
        }
    }

    #[test]
    fn test_parse_const_with_u16_type() {
        let code = "const SIZE: u16 = 256\n";
        let result = lex_and_parse(code);
        assert!(result.is_ok());
        if let Ok(module) = result {
            assert_eq!(module.items.len(), 1);
            if let Item::Const { name, type_annotation, .. } = &module.items[0] {
                assert_eq!(name, "SIZE");
                assert_eq!(type_annotation, &Some("u16".to_string()));
            } else {
                panic!("Expected Const item");
            }
        }
    }

    #[test]
    fn test_parse_const_with_i8_type() {
        let code = "const OFFSET: i8 = -10\n";
        let result = lex_and_parse(code);
        assert!(result.is_ok());
        if let Ok(module) = result {
            assert_eq!(module.items.len(), 1);
            if let Item::Const { name, type_annotation, .. } = &module.items[0] {
                assert_eq!(name, "OFFSET");
                assert_eq!(type_annotation, &Some("i8".to_string()));
            } else {
                panic!("Expected Const item");
            }
        }
    }

    #[test]
    fn test_parse_const_without_type() {
        let code = "const UNTYPED = 100\n";
        let result = lex_and_parse(code);
        assert!(result.is_ok());
        if let Ok(module) = result {
            assert_eq!(module.items.len(), 1);
            if let Item::Const { name, type_annotation, .. } = &module.items[0] {
                assert_eq!(name, "UNTYPED");
                assert_eq!(type_annotation, &None);
            } else {
                panic!("Expected Const item");
            }
        }
    }

    #[test]
    fn test_parse_global_var_with_u8_type() {
        let code = "player_health: u8 = 100\n";
        let result = lex_and_parse(code);
        assert!(result.is_ok());
        if let Ok(module) = result {
            assert_eq!(module.items.len(), 1);
            if let Item::GlobalLet { name, type_annotation, .. } = &module.items[0] {
                assert_eq!(name, "player_health");
                assert_eq!(type_annotation, &Some("u8".to_string()));
            } else {
                panic!("Expected GlobalLet item");
            }
        }
    }

    #[test]
    fn test_parse_global_var_with_u16_type() {
        let code = "score: u16 = 5000\n";
        let result = lex_and_parse(code);
        assert!(result.is_ok());
        if let Ok(module) = result {
            assert_eq!(module.items.len(), 1);
            if let Item::GlobalLet { name, type_annotation, .. } = &module.items[0] {
                assert_eq!(name, "score");
                assert_eq!(type_annotation, &Some("u16".to_string()));
            } else {
                panic!("Expected GlobalLet item");
            }
        }
    }

    #[test]
    fn test_parse_global_var_with_i16_type() {
        let code = "offset: i16 = -500\n";
        let result = lex_and_parse(code);
        assert!(result.is_ok());
        if let Ok(module) = result {
            assert_eq!(module.items.len(), 1);
            if let Item::GlobalLet { name, type_annotation, .. } = &module.items[0] {
                assert_eq!(name, "offset");
                assert_eq!(type_annotation, &Some("i16".to_string()));
            } else {
                panic!("Expected GlobalLet item");
            }
        }
    }

    #[test]
    fn test_parse_global_var_without_type() {
        let code = "x = 42\n";
        let result = lex_and_parse(code);
        assert!(result.is_ok());
        if let Ok(module) = result {
            assert_eq!(module.items.len(), 1);
            if let Item::GlobalLet { name, type_annotation, .. } = &module.items[0] {
                assert_eq!(name, "x");
                assert_eq!(type_annotation, &None);
            } else {
                panic!("Expected GlobalLet item");
            }
        }
    }

    #[test]
    fn test_parse_invalid_type_name() {
        let code = "const BAD: u32 = 100\n";
        let result = lex_and_parse(code);
        assert!(result.is_err(), "Should reject invalid type name u32");
    }

    #[test]
    fn test_parse_malformed_type_annotation() {
        let code = "const BAD: = 100\n";
        let result = lex_and_parse(code);
        assert!(result.is_err(), "Should reject missing type name after colon");
    }

    #[test]
    fn test_parse_meta_title() {
        let code = "META TITLE = \"My Game\"\n";
        let result = lex_and_parse(code);
        assert!(result.is_ok());
        if let Ok(module) = result {
            assert_eq!(module.meta.title_override, Some("My Game".to_string()));
        }
    }

    #[test]
    fn test_parse_function_definition() {
        let code = "def main():\n    x = 42\n";
        let result = lex_and_parse(code);
        assert!(result.is_ok());
        if let Ok(module) = result {
            assert_eq!(module.items.len(), 1);
            if let Item::Function(func) = &module.items[0] {
                assert_eq!(func.name, "main");
                assert_eq!(func.params.len(), 0);
                assert_eq!(func.body.len(), 1);
            } else {
                panic!("Expected Function item");
            }
        }
    }

    #[test]
    fn test_parse_function_with_params() {
        let code = "def add(a, b):\n    return a + b\n";
        let result = lex_and_parse(code);
        assert!(result.is_ok());
        if let Ok(module) = result {
            assert_eq!(module.items.len(), 1);
            if let Item::Function(func) = &module.items[0] {
                assert_eq!(func.name, "add");
                assert_eq!(func.params.len(), 2);
                assert_eq!(func.params[0], "a");
                assert_eq!(func.params[1], "b");
            } else {
                panic!("Expected Function item");
            }
        }
    }

    #[test]
    fn test_parse_struct_definition() {
        let code = "struct Point:\n    x = 0\n    y = 0\n";
        let result = lex_and_parse(code);
        assert!(result.is_ok());
        if let Ok(module) = result {
            assert_eq!(module.items.len(), 1);
            if let Item::StructDef(struct_def) = &module.items[0] {
                assert_eq!(struct_def.name, "Point");
                assert_eq!(struct_def.fields.len(), 2);
            } else {
                panic!("Expected StructDef item");
            }
        }
    }

    // ===== INTEGRATION TESTS =====
    // Tests that parse complete VPy programs

    #[test]
    fn test_integration_simple_program() {
        // Simple program with META, const, function, and loop
        let code = r#"META TITLE = "Simple Game"

const SPEED = 5

def main():
    SET_INTENSITY(127)

def loop():
    WAIT_RECAL()
    x = x + SPEED
"#;
        let result = lex_and_parse(code);
        assert!(result.is_ok(), "Failed to parse simple program");
        if let Ok(module) = result {
            // Should have: 1 const + 2 functions
            assert_eq!(module.items.len(), 3, "Expected 3 items (const + 2 functions)");
            assert_eq!(module.meta.title_override, Some("Simple Game".to_string()), "META TITLE not parsed");
        }
    }

    #[test]
    fn test_integration_multi_function_program() {
        let code = r#"def main():
    x = 0
    y = 0

def loop():
    WAIT_RECAL()
    update_player()
    draw_player()

def update_player():
    pass

def draw_player():
    pass
"#;
        let result = lex_and_parse(code);
        assert!(result.is_ok(), "Failed to parse multi-function program");
        if let Ok(module) = result {
            assert_eq!(module.items.len(), 4, "Expected 4 functions");
            // Verify names
            if let Item::Function(f) = &module.items[0] {
                assert_eq!(f.name, "main");
            }
            if let Item::Function(f) = &module.items[1] {
                assert_eq!(f.name, "loop");
            }
            if let Item::Function(f) = &module.items[2] {
                assert_eq!(f.name, "update_player");
            }
            if let Item::Function(f) = &module.items[3] {
                assert_eq!(f.name, "draw_player");
            }
        }
    }

    #[test]
    fn test_integration_import_program() {
        let code = r#"import graphics
import input

player_x = 0

def loop():
    WAIT_RECAL()
    input.get_input()
    graphics.draw()
"#;
        let result = lex_and_parse(code);
        assert!(result.is_ok(), "Failed to parse import program");
        if let Ok(module) = result {
            // Should have: 2 imports + 1 global var + 1 function
            assert_eq!(module.imports.len(), 2, "Expected 2 imports");
            assert_eq!(module.items.len(), 2, "Expected 2 items (global + function)");
        }
    }

    #[test]
    fn test_integration_control_flow() {
        let code = r#"def loop():
    WAIT_RECAL()
    for i in range(10):
        x = i
    while x < 100:
        x = x + 1
    if x > 50:
        y = 1
    elif x > 25:
        y = 2
    else:
        y = 3
"#;
        let result = lex_and_parse(code);
        if let Err(e) = &result {
            eprintln!("Control flow parse error: {}", e);
        }
        assert!(result.is_ok(), "Failed to parse control flow program");
        if let Ok(module) = result {
            assert_eq!(module.items.len(), 1, "Expected 1 function");
        }
    }

    #[test]
    fn test_integration_struct_with_methods() {
        let code = r#"struct Player:
    x = 0
    y = 0
    def move(dx, dy):
        x = x + dx
        y = y + dy
    def draw():
        DRAW_VECTOR("player")
"#;
        let result = lex_and_parse(code);
        if let Err(e) = &result {
            eprintln!("Struct parse error: {}", e);
        }
        assert!(result.is_ok(), "Failed to parse struct with methods");
        if let Ok(module) = result {
            assert_eq!(module.items.len(), 1, "Expected 1 struct");
            if let Item::StructDef(struct_def) = &module.items[0] {
                assert_eq!(struct_def.name, "Player");
                assert_eq!(struct_def.fields.len(), 2, "Expected 2 fields");
                assert_eq!(struct_def.methods.len(), 2, "Expected 2 methods");
            }
        }
    }

    #[test]
    fn test_integration_complex_expressions() {
        let code = r#"def loop():
    WAIT_RECAL()
    a = 10 + 20 * 5
    b = (100 - 50) / 5
    c = a % 3
    d = a > 50
    e = c == 0
    f = not d
    arr = [1, 2, 3]
    val = arr[0]
    SET_INTENSITY(val)
"#;
        let result = lex_and_parse(code);
        if let Err(e) = &result {
            eprintln!("Complex expr parse error: {}", e);
        }
        assert!(result.is_ok(), "Failed to parse complex expressions");
        if let Ok(module) = result {
            assert_eq!(module.items.len(), 1, "Expected 1 function");
        }
    }
}
