use anyhow::{bail, Result};
use crate::ast::*;
use crate::lexer::{Token, TokenKind};

// Check if a name is a known builtin function (NOT a struct)
// This prevents builtins like MUSIC_UPDATE() from being parsed as StructInit
fn is_known_builtin(name: &str) -> bool {
    matches!(name,
        // Core builtins (0 args that look like structs)
        "WAIT_RECAL" | "SET_ORIGIN" | "MUSIC_UPDATE" | "STOP_MUSIC" |
        "SFX_UPDATE" |
        "SFX_UPDATE" |
        "PLAY_MUSIC1" | "DBG_STATIC_VL" | "VECTOR_PHASE_BEGIN" |
        // Joystick input builtins (0 args, uppercase - MUST be recognized)
        "J1_X" | "J1_Y" | "J1_X_DIGITAL" | "J1_Y_DIGITAL" |
        "J1_X_ANALOG" | "J1_Y_ANALOG" | "UPDATE_BUTTONS" | "J1_BUTTON_1" | "J1_BUTTON_2" |
        "J1_BUTTON_3" | "J1_BUTTON_4" |
        // Level system builtins (0 args)
        "SHOW_LEVEL" | "UPDATE_LEVEL" | "GET_LEVEL_BOUNDS" |
        // Multi-arg builtins (unlikely to be confused but include for completeness)
        "MOVE" | "PRINT_TEXT" | "DRAW_TO" | "DRAW_LINE" | "DEBUG_PRINT" |
        "DEBUG_PRINT_LABELED" | "DEBUG_PRINT_STR" | "DRAW_VECTOR" |
        "PLAY_MUSIC" | "PLAY_SFX" | "DRAW_VECTOR_LIST" | "DRAW_VL" |
        "FRAME_BEGIN" | "ABS" | "LEN" | "ASM" | "SET_INTENSITY" |
        "SET_TEXT_SIZE" | "PRINT_NUMBER" | "BEEP" | "RAND" | "RAND_RANGE"
    )
}

// Convert TokenKind to user-friendly display name
fn token_display_name(kind: &TokenKind) -> String {
    match kind {
        TokenKind::LParen => "'('".to_string(),
        TokenKind::RParen => "')'".to_string(),
        TokenKind::LBracket => "'['".to_string(),
        TokenKind::RBracket => "']'".to_string(),
        TokenKind::Colon => "':'".to_string(),
        TokenKind::Comma => "','".to_string(),
        TokenKind::Dot => "'.'".to_string(),
        TokenKind::Equal => "'='".to_string(),
        TokenKind::Plus => "'+'".to_string(),
        TokenKind::Minus => "'-'".to_string(),
        TokenKind::Star => "'*'".to_string(),
        TokenKind::Slash => "'/'".to_string(),
        TokenKind::SlashSlash => "'//'".to_string(),
        TokenKind::Percent => "'%'".to_string(),
        TokenKind::Lt => "'<'".to_string(),
        TokenKind::Gt => "'>'".to_string(),
        TokenKind::Le => "'<='".to_string(),
        TokenKind::Ge => "'>='".to_string(),
        TokenKind::EqEq => "'=='".to_string(),
        TokenKind::NotEq => "'!='".to_string(),
        TokenKind::And => "'and'".to_string(),
        TokenKind::Or => "'or'".to_string(),
        TokenKind::Not => "'not'".to_string(),
        TokenKind::Amp => "'&'".to_string(),
        TokenKind::Pipe => "'|'".to_string(),
        TokenKind::Caret => "'^'".to_string(),
        TokenKind::Tilde => "'~'".to_string(),
        TokenKind::At => "'@'".to_string(),
        TokenKind::ShiftLeft => "'<<'".to_string(),
        TokenKind::ShiftRight => "'>>'".to_string(),
        TokenKind::Newline => "newline".to_string(),
        TokenKind::Indent => "indentation".to_string(),
        TokenKind::Dedent => "dedentation".to_string(),
        TokenKind::Eof => "end of file".to_string(),
        TokenKind::Def => "'def'".to_string(),
        TokenKind::If => "'if'".to_string(),
        TokenKind::Elif => "'elif'".to_string(),
        TokenKind::Else => "'else'".to_string(),
        TokenKind::While => "'while'".to_string(),
        TokenKind::For => "'for'".to_string(),
        TokenKind::In => "'in'".to_string(),
        TokenKind::Range => "'range'".to_string(),
        TokenKind::Break => "'break'".to_string(),
        TokenKind::Continue => "'continue'".to_string(),
        TokenKind::Pass => "'pass'".to_string(),
        TokenKind::Return => "'return'".to_string(),
        TokenKind::Const => "'const'".to_string(),
        TokenKind::VectorList => "'vectorlist'".to_string(),
        TokenKind::Switch => "'switch'".to_string(),
        TokenKind::Case => "'case'".to_string(),
        TokenKind::Default => "'default'".to_string(),
        TokenKind::Meta => "'META'".to_string(),
        TokenKind::True => "'true'".to_string(),
        TokenKind::False => "'false'".to_string(),
        TokenKind::PlusEqual => "'+='".to_string(),
        TokenKind::MinusEqual => "'-='".to_string(),
        TokenKind::StarEqual => "'*='".to_string(),
        TokenKind::SlashEqual => "'/='".to_string(),
        TokenKind::SlashSlashEqual => "'//='".to_string(),
        TokenKind::PercentEqual => "'%='".to_string(),
        TokenKind::From => "'from'".to_string(),
        TokenKind::Import => "'import'".to_string(),
        TokenKind::As => "'as'".to_string(),
        TokenKind::Export => "'export'".to_string(),
        TokenKind::Struct => "'struct'".to_string(),
        TokenKind::Self_ => "'self'".to_string(),
        TokenKind::Identifier(_) => "identifier".to_string(),
        TokenKind::Number(_) => "number".to_string(),
        TokenKind::StringLit(_) => "string".to_string(),
    }
}

// Public entrypoint (filename-aware only)
pub fn parse_with_filename(tokens: &[Token], filename: &str) -> Result<Module> {
    let mut p = Parser { tokens, pos: 0, filename: filename.to_string() };
    p.parse_module()
}

// Small constant folder used for vectorlist numeric arguments.
fn const_eval(e: &Expr) -> Option<i32> {
    use crate::ast::BinOp;
    match e {
        Expr::Number(n) => Some(*n),
        Expr::Binary { op, left, right } => {
            let l = const_eval(left)?; let r = const_eval(right)?;
            let v = match op {
                BinOp::Add => l.wrapping_add(r),
                BinOp::Sub => l.wrapping_sub(r),
                BinOp::Mul => l.wrapping_mul(r),
                BinOp::Div => if r!=0 { l.wrapping_div(r) } else { return None },
                BinOp::FloorDiv => if r!=0 { l.wrapping_div(r) } else { return None }, // División entera (igual que Div en enteros)
                BinOp::Mod => if r!=0 { l.wrapping_rem(r) } else { return None },
                BinOp::Shl => l.wrapping_shl((r & 0xF) as u32),
                BinOp::Shr => ((l as u32) >> (r & 0xF)) as i32,
                BinOp::BitAnd => l & r,
                BinOp::BitOr => l | r,
                BinOp::BitXor => l ^ r,
            };
            // Truncate to 16-bit SIGNED range, preserving negative sign
            let truncated = ((v & 0xFFFF) as i16) as i32;
            Some(truncated)
        }
        Expr::Not(inner) => const_eval(inner).map(|v| if (v & 0xFFFF)==0 {1} else {0}),
        Expr::BitNot(inner) => const_eval(inner).map(|v| ((!v) & 0xFFFF) as i16 as i32),
        _ => None,
    }
}

struct Parser<'a> { tokens: &'a [Token], pos: usize, filename: String }

impl<'a> Parser<'a> {
    /// Get the current line number from the current token
    fn current_line(&self) -> usize {
        self.tokens.get(self.pos)
            .map(|t| t.line)
            .unwrap_or(1)
    }
    
    fn parse_module(&mut self) -> Result<Module> {
        let mut items = Vec::new();
        let mut meta = ModuleMeta::default();
        let mut imports = Vec::new();
    while !self.check(TokenKind::Eof) {
            // skip structural noise
            while self.match_kind(&TokenKind::Newline) {}
            while self.match_kind(&TokenKind::Dedent) {}
            if self.check(TokenKind::Eof) { break; }
            if self.match_kind(&TokenKind::Const) || self.match_ident_case("CONST") {
                let const_line = self.current_line();
                let name = self.identifier()?;
                // Check for optional type annotation: type
                let type_annotation = if self.match_kind(&TokenKind::Colon) {
                    Some(self.identifier()?)
                } else {
                    None
                };
                self.consume(TokenKind::Equal)?;
                let value = self.expression()?;
                self.consume(TokenKind::Newline)?;
                if name.eq_ignore_ascii_case("TITLE") { if let Expr::StringLit(s)=&value { meta.title_override = Some(s.clone()); } }
                items.push(Item::Const { name, type_annotation, value, source_line: const_line });
                continue;
            }
            // Global variable declaration: identifier [: type] = expression (Python-style, no keyword)
            if self.check_identifier() {
                let checkpoint = self.pos;
                if let Ok(name) = self.identifier() {
                    // Check for optional type annotation: type
                    let type_annotation = if self.match_kind(&TokenKind::Colon) {
                        Some(self.identifier()?)
                    } else {
                        None
                    };
                    if self.match_kind(&TokenKind::Equal) {
                        let global_line = self.current_line();
                        let value = self.expression()?;
                        self.consume(TokenKind::Newline)?;
                        items.push(Item::GlobalLet { name, type_annotation, value, source_line: global_line });
                        continue;
                    }
                }
                // Not a variable declaration, rewind
                self.pos = checkpoint;
            }
            if self.match_kind(&TokenKind::Meta) || self.match_ident_case("META") {
                let key = self.identifier()?;
                self.consume(TokenKind::Equal)?;
                let value = self.expression()?;
                self.consume(TokenKind::Newline)?;
                if let Expr::StringLit(s)=&value { meta.metas.insert(key.to_uppercase(), s.clone()); }
                if key.eq_ignore_ascii_case("TITLE") { if let Expr::StringLit(s)=&value { meta.title_override = Some(s.clone()); } }
                else if key.eq_ignore_ascii_case("MUSIC") {
                    match &value {
                        Expr::StringLit(s) => meta.music_override = Some(s.clone()),
                        Expr::Ident(id) => meta.music_override = Some(id.name.clone()),
                        _ => {}
                    }
                }
                else if key.eq_ignore_ascii_case("COPYRIGHT") { if let Expr::StringLit(s)=&value { meta.copyright_override = Some(s.clone()); } }
                else if key.eq_ignore_ascii_case("MUSIC_TIMER") {
                    if let Expr::Ident(id) = &value {
                        meta.music_timer = !id.name.eq_ignore_ascii_case("false");
                    }
                }
                else if key.eq_ignore_ascii_case("INTERLEAVED_FRAMES") {
                    if let Expr::Number(n) = value {
                        if n == 2 || n == 3 {
                            meta.interleaved_frames = Some(n as u8);
                        }
                    }
                }
                continue;
            }
            if self.match_kind(&TokenKind::VectorList) || self.match_ident_case("VECTORLIST") {
                // if keyword matched as identifier the token already consumed. If actual keyword token kind consumed above.
                let vl = self.parse_vectorlist()?; items.push(vl); continue;
            }
            
            // Import statements: from X import Y, import X
            if self.check(TokenKind::From) || self.check(TokenKind::Import) {
                let import_decl = self.parse_import()?;
                imports.push(import_decl);
                continue;
            }
            
            // Export statement: export symbol1, symbol2
            if self.check(TokenKind::Export) {
                let export = self.parse_export()?;
                items.push(export);
                continue;
            }
            
            // Struct definition: struct Name:
            if self.check(TokenKind::Struct) {
                let struct_def = self.parse_struct()?;
                items.push(Item::StructDef(struct_def));
                continue;
            }
            
            // @frame(N) decorator before def
            let pending_frame_group = if self.check(TokenKind::At) {
                self.advance();
                let decorator = self.identifier()?;
                if decorator.eq_ignore_ascii_case("frame") {
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
                }
            } else {
                None
            };
            if self.check(TokenKind::Def) {
                let mut func = self.parse_function_def()?;
                func.frame_group = pending_frame_group;
                items.push(Item::Function(func));
                continue;
            }
            
            // Permitir expression statements en top-level (llamadas a funciones, etc.)
            if !self.check(TokenKind::Eof) && !self.check(TokenKind::Newline) {
                let expr = self.expression()?;
                self.consume(TokenKind::Newline)?;
                items.push(Item::ExprStatement(expr));
                continue;
            }
            
            return self.err_here(&format!("Unexpected token {:?} at top-level", self.peek().kind));
        }
        Ok(Module { items, meta, imports })
    }

    // --- vectorlist ---
    fn parse_vectorlist(&mut self) -> Result<Item> {
        let name = self.identifier()?;
        self.consume(TokenKind::Colon)?;
        self.consume(TokenKind::Newline)?;
        self.consume(TokenKind::Indent)?;
        let mut entries: Vec<VlEntry> = Vec::new();
        loop {
            while self.match_kind(&TokenKind::Newline) {}
            if self.check(TokenKind::Dedent) { self.match_kind(&TokenKind::Dedent); break; }
            if self.check(TokenKind::Eof) { break; }
            let cmd = match self.peek().kind.clone() { TokenKind::Identifier(s) => s, _ => break };
            let upper = cmd.to_ascii_uppercase();
            // consume identifier
            self.match_identifier();
            match upper.as_str() {
                "INTENSITY" => {
                    // Unificado: INTENSITY(value) funciona igual que las funciones globales
                    self.consume(TokenKind::LParen)?;
                    let expr = self.expression()?;
                    let v = if let Some(v) = const_eval(&expr) { v } else { return self.err_here("Expected number for INTENSITY"); };
                    self.consume(TokenKind::RParen)?;
                    entries.push(VlEntry::Intensity(v));
                }
                "SET_INTENSITY" => {
                    // Unificado: SET_INTENSITY(value) funciona igual que INTENSITY
                    self.consume(TokenKind::LParen)?;
                    let expr = self.expression()?;
                    let v = if let Some(v) = const_eval(&expr) { v } else { return self.err_here("Expected number for SET_INTENSITY"); };
                    self.consume(TokenKind::RParen)?;
                    entries.push(VlEntry::Intensity(v));
                }
                "ORIGIN" => entries.push(VlEntry::Origin),
                "SET_ORIGIN" => {
                    // Unificado: SET_ORIGIN funciona igual que ORIGIN
                    entries.push(VlEntry::Origin)
                }
                "MOVE" => { 
                    // Unificado: MOVE(x, y) funciona igual que las funciones globales
                    self.consume(TokenKind::LParen)?;
                    let x_expr = self.expression()?;
                    let x = if let Some(v) = const_eval(&x_expr) { v } else { return self.err_here("Expected number for x in MOVE"); };
                    self.consume(TokenKind::Comma)?;
                    let y_expr = self.expression()?;
                    let y = if let Some(v) = const_eval(&y_expr) { v } else { return self.err_here("Expected number for y in MOVE"); };
                    self.consume(TokenKind::RParen)?;
                    entries.push(VlEntry::Move(x, y));
                }
                "RECT" => {
                    // Unificado: RECT(x1, y1, x2, y2) funciona igual que las funciones globales
                    self.consume(TokenKind::LParen)?;
                    let x1_expr = self.expression()?;
                    let x1 = if let Some(v) = const_eval(&x1_expr) { v } else { return self.err_here("Expected number for x1 in RECT"); };
                    self.consume(TokenKind::Comma)?;
                    let y1_expr = self.expression()?;
                    let y1 = if let Some(v) = const_eval(&y1_expr) { v } else { return self.err_here("Expected number for y1 in RECT"); };
                    self.consume(TokenKind::Comma)?;
                    let x2_expr = self.expression()?;
                    let x2 = if let Some(v) = const_eval(&x2_expr) { v } else { return self.err_here("Expected number for x2 in RECT"); };
                    self.consume(TokenKind::Comma)?;
                    let y2_expr = self.expression()?;
                    let y2 = if let Some(v) = const_eval(&y2_expr) { v } else { return self.err_here("Expected number for y2 in RECT"); };
                    self.consume(TokenKind::RParen)?;
                    entries.push(VlEntry::Rect(x1, y1, x2, y2));
                }
                "POLYGON" => {
                    // Count can be an expression, vertices must be literal signed ints (no binary ops across coords).
                    let cnt_expr = self.expression()?;
                    let n = if let Some(nn) = const_eval(&cnt_expr) { nn } else { return self.err_here("POLYGON expects count"); };
                    if !(2..=256).contains(&n) { return self.err_here("POLYGON count out of range"); }
                    let mut verts = Vec::new();
                    for _ in 0..n { let x = self.parse_signed_number()?; let y = self.parse_signed_number()?; verts.push((x,y)); }
                    entries.push(VlEntry::Polygon(verts));
                }
                "CIRCLE" => {
                    // Unificado: CIRCLE(cx, cy, r) o CIRCLE(cx, cy, r, segs)
                    self.consume(TokenKind::LParen)?;
                    let cx_expr = self.expression()?;
                    let cx = if let Some(v) = const_eval(&cx_expr) { v } else { return self.err_here("Expected number for cx in CIRCLE"); };
                    self.consume(TokenKind::Comma)?;
                    let cy_expr = self.expression()?;
                    let cy = if let Some(v) = const_eval(&cy_expr) { v } else { return self.err_here("Expected number for cy in CIRCLE"); };
                    self.consume(TokenKind::Comma)?;
                    let r_expr = self.expression()?;
                    let r = if let Some(v) = const_eval(&r_expr) { v } else { return self.err_here("Expected number for r in CIRCLE"); };
                    
                    // Parámetro opcional segs
                    let segs = if self.match_kind(&TokenKind::Comma) {
                        let segs_expr = self.expression()?;
                        if let Some(v) = const_eval(&segs_expr) { v } else { return self.err_here("Expected number for segs in CIRCLE"); }
                    } else { 16 };
                    
                    self.consume(TokenKind::RParen)?;
                    let segs = segs.clamp(3, 64);
                    entries.push(VlEntry::Circle { cx, cy, r, segs });
                }
                "ARC" => {
                    // Unificado: ARC(cx, cy, r, startDeg, sweepDeg) o ARC(cx, cy, r, startDeg, sweepDeg, segs)
                    self.consume(TokenKind::LParen)?;
                    let cx_expr = self.expression()?;
                    let cx = if let Some(v) = const_eval(&cx_expr) { v } else { return self.err_here("Expected number for cx in ARC"); };
                    self.consume(TokenKind::Comma)?;
                    let cy_expr = self.expression()?;
                    let cy = if let Some(v) = const_eval(&cy_expr) { v } else { return self.err_here("Expected number for cy in ARC"); };
                    self.consume(TokenKind::Comma)?;
                    let r_expr = self.expression()?;
                    let r = if let Some(v) = const_eval(&r_expr) { v } else { return self.err_here("Expected number for r in ARC"); };
                    self.consume(TokenKind::Comma)?;
                    let start_expr = self.expression()?;
                    let start = if let Some(v) = const_eval(&start_expr) { v } else { return self.err_here("Expected number for startDeg in ARC"); };
                    self.consume(TokenKind::Comma)?;
                    let sweep_expr = self.expression()?;
                    let sweep = if let Some(v) = const_eval(&sweep_expr) { v } else { return self.err_here("Expected number for sweepDeg in ARC"); };
                    
                    // Parámetro opcional segs
                    let segs = if self.match_kind(&TokenKind::Comma) {
                        let segs_expr = self.expression()?;
                        if let Some(v) = const_eval(&segs_expr) { v } else { return self.err_here("Expected number for segs in ARC"); }
                    } else { 16 };
                    
                    self.consume(TokenKind::RParen)?;
                    let segs = segs.clamp(2, 128);
                    entries.push(VlEntry::Arc { cx, cy, r, start_deg: start, sweep_deg: sweep, segs });
                }
                "SPIRAL" => {
                    // Unificado: SPIRAL(cx, cy, r_start, r_end, turns) o SPIRAL(cx, cy, r_start, r_end, turns, segs)
                    self.consume(TokenKind::LParen)?;
                    let cx_expr = self.expression()?;
                    let cx = if let Some(v) = const_eval(&cx_expr) { v } else { return self.err_here("Expected number for cx in SPIRAL"); };
                    self.consume(TokenKind::Comma)?;
                    let cy_expr = self.expression()?;
                    let cy = if let Some(v) = const_eval(&cy_expr) { v } else { return self.err_here("Expected number for cy in SPIRAL"); };
                    self.consume(TokenKind::Comma)?;
                    let rs_expr = self.expression()?;
                    let rs = if let Some(v) = const_eval(&rs_expr) { v } else { return self.err_here("Expected number for r_start in SPIRAL"); };
                    self.consume(TokenKind::Comma)?;
                    let re_expr = self.expression()?;
                    let re = if let Some(v) = const_eval(&re_expr) { v } else { return self.err_here("Expected number for r_end in SPIRAL"); };
                    self.consume(TokenKind::Comma)?;
                    let turns_expr = self.expression()?;
                    let turns = if let Some(v) = const_eval(&turns_expr) { v } else { return self.err_here("Expected number for turns in SPIRAL"); };
                    
                    // Parámetro opcional segs
                    let segs = if self.match_kind(&TokenKind::Comma) {
                        let segs_expr = self.expression()?;
                        if let Some(v) = const_eval(&segs_expr) { v } else { return self.err_here("Expected number for segs in SPIRAL"); }
                    } else { 64 };
                    
                    self.consume(TokenKind::RParen)?;
                    let segs = segs.clamp(4, 256);
                    entries.push(VlEntry::Spiral { cx, cy, r_start: rs, r_end: re, turns, segs });
                }
                _ => return self.err_here(&format!("Unknown vectorlist command {}", cmd)),
            }
            if self.check(TokenKind::Newline) { self.match_kind(&TokenKind::Newline); }
        }
        Ok(Item::VectorList { name, entries })
    }

    // --- functions / statements ---
    fn function(&mut self) -> Result<Item> {
        let func = self.parse_function_def()?;
        Ok(Item::Function(func))
    }

    // Helper method to parse function definition (used by both top-level and struct methods)
    fn parse_function_def(&mut self) -> Result<Function> {
        let func_line = self.peek().line;  // Capture function definition line
        self.consume(TokenKind::Def)?;
        let name = self.identifier()?;
        self.consume(TokenKind::LParen)?;
        let mut params = Vec::new();
        self.skip_newlines(); // Allow newlines after opening paren
        if !self.check(TokenKind::RParen) {
            loop { 
                params.push(self.identifier()?); 
                self.skip_newlines(); // Allow newlines after parameter
                if self.match_kind(&TokenKind::Comma) { 
                    self.skip_newlines(); // Allow newlines after comma
                    continue; 
                } 
                break; 
            }
        }
        self.skip_newlines(); // Allow newlines before closing paren
        self.consume(TokenKind::RParen)?; self.consume(TokenKind::Colon)?; self.consume(TokenKind::Newline)?; self.consume(TokenKind::Indent)?;
        let mut body = Vec::new();
        while !self.match_kind(&TokenKind::Dedent) { body.push(self.statement()?); }
        Ok(Function { name, line: func_line, params, body, frame_group: None })
    }

    // Parse struct definition: struct Name:
    fn parse_struct(&mut self) -> Result<StructDef> {
        let source_line = self.peek().line;
        self.consume(TokenKind::Struct)?;
        let name = self.identifier()?;
        self.consume(TokenKind::Colon)?;
        self.consume(TokenKind::Newline)?;
        self.consume(TokenKind::Indent)?;
        
        let mut fields = Vec::new();
        let mut methods = Vec::new();
        let mut constructor = None;
        
        while !self.check(TokenKind::Dedent) {
            self.skip_newlines(); // Skip any extra newlines
            if self.check(TokenKind::Dedent) { break; }
            
            // Check if it's a method definition (def keyword)
            if self.check(TokenKind::Def) {
                let method = self.parse_function_def()?;
                
                // Check if it's a constructor
                if method.name == "__init__" {
                    if constructor.is_some() {
                        return self.err_here(&format!("Struct {} already has a constructor", name));
                    }
                    constructor = Some(method);
                } else {
                    methods.push(method);
                }
            } else {
                // Parse field: name: type
                let field_line = self.peek().line;
                let field_name = self.identifier()?;
                self.consume(TokenKind::Colon)?;
                let type_annotation = Some(self.identifier()?);
                self.consume(TokenKind::Newline)?;
                
                fields.push(FieldDef {
                    name: field_name,
                    type_annotation,
                    source_line: field_line,
                });
            }
        }
        
        self.consume(TokenKind::Dedent)?;
        
        if fields.is_empty() {
            return self.err_here(&format!("Struct {} must have at least one field", name));
        }
        
        Ok(StructDef { name, fields, methods, constructor, source_line })
    }

    fn statement(&mut self) -> Result<Stmt> {
        let start_source_line = self.peek().line; // Capturar línea del statement
        
        if self.match_kind(&TokenKind::For) { return self.for_stmt(start_source_line); }
        if self.match_kind(&TokenKind::While) { return self.while_stmt(start_source_line); }
        if self.match_kind(&TokenKind::If) { return self.if_stmt(start_source_line); }
        if self.match_kind(&TokenKind::Switch) { return self.switch_stmt(start_source_line); }
        if self.match_kind(&TokenKind::Return) { return self.return_stmt(start_source_line); }
        if self.match_kind(&TokenKind::Break) { self.consume(TokenKind::Newline)?; return Ok(Stmt::Break { source_line: start_source_line }); }
        if self.match_kind(&TokenKind::Continue) { self.consume(TokenKind::Newline)?; return Ok(Stmt::Continue { source_line: start_source_line }); }
        if self.match_kind(&TokenKind::Pass) { self.consume(TokenKind::Newline)?; return Ok(Stmt::Pass { source_line: start_source_line }); }
        
        // Try to parse assignment (x = value or arr[i] = value)
        let checkpoint = self.pos;
        if let Ok(lhs_expr) = self.postfix() {
            // Check if followed by assignment operator
            if self.match_kind(&TokenKind::Equal) {
                let rhs = self.expression()?;
                self.consume(TokenKind::Newline)?;
                let target = self.expr_to_assign_target(lhs_expr, start_source_line)?;
                return Ok(Stmt::Assign { target, value: rhs, source_line: start_source_line });
            } else if self.check(TokenKind::PlusEqual) || self.check(TokenKind::MinusEqual) || 
                      self.check(TokenKind::StarEqual) || self.check(TokenKind::SlashEqual) || 
                      self.check(TokenKind::SlashSlashEqual) || self.check(TokenKind::PercentEqual) {
                let op = match self.peek().kind {
                    TokenKind::PlusEqual => { self.advance(); crate::ast::BinOp::Add }
                    TokenKind::MinusEqual => { self.advance(); crate::ast::BinOp::Sub }
                    TokenKind::StarEqual => { self.advance(); crate::ast::BinOp::Mul }
                    TokenKind::SlashEqual => { self.advance(); crate::ast::BinOp::Div }
                    TokenKind::SlashSlashEqual => { self.advance(); crate::ast::BinOp::FloorDiv }
                    TokenKind::PercentEqual => { self.advance(); crate::ast::BinOp::Mod }
                    _ => unreachable!()
                };
                let rhs = self.expression()?;
                self.consume(TokenKind::Newline)?;
                let target = self.expr_to_assign_target(lhs_expr, start_source_line)?;
                return Ok(Stmt::CompoundAssign { target, op, value: rhs, source_line: start_source_line });
            }
        }
        
        // Not an assignment, revert and parse as expression statement
        self.pos = checkpoint;
        let expr = self.expression()?; self.consume(TokenKind::Newline)?; Ok(Stmt::Expr(expr, start_source_line))
    }

    fn switch_stmt(&mut self, source_line: usize) -> Result<Stmt> {
        let expr = self.expression()?; self.consume(TokenKind::Colon)?; self.consume(TokenKind::Newline)?; self.consume(TokenKind::Indent)?;
        let mut cases = Vec::new(); let mut default_block=None;
        while !self.match_kind(&TokenKind::Dedent) {
            if self.match_kind(&TokenKind::Case) { let cv=self.expression()?; self.consume(TokenKind::Colon)?; self.consume(TokenKind::Newline)?; self.consume(TokenKind::Indent)?; let mut body=Vec::new(); while !self.match_kind(&TokenKind::Dedent) { body.push(self.statement()?); } cases.push((cv,body)); }
            else if self.match_kind(&TokenKind::Default) { self.consume(TokenKind::Colon)?; self.consume(TokenKind::Newline)?; self.consume(TokenKind::Indent)?; let mut body=Vec::new(); while !self.match_kind(&TokenKind::Dedent) { body.push(self.statement()?); } default_block=Some(body); }
            else { bail!("Expected 'case' or 'default' in switch block"); }
        }
        Ok(Stmt::Switch { expr, cases, default: default_block, source_line })
    }

    fn while_stmt(&mut self, source_line: usize) -> Result<Stmt> { let cond=self.expression()?; self.consume(TokenKind::Colon)?; self.consume(TokenKind::Newline)?; self.consume(TokenKind::Indent)?; let mut body=Vec::new(); while !self.match_kind(&TokenKind::Dedent){ body.push(self.statement()?);} Ok(Stmt::While { cond, body, source_line }) }
    fn return_stmt(&mut self, source_line: usize) -> Result<Stmt> { if self.check(TokenKind::Newline) { self.consume(TokenKind::Newline)?; return Ok(Stmt::Return(None, source_line)); } let expr=self.expression()?; self.consume(TokenKind::Newline)?; Ok(Stmt::Return(Some(expr), source_line)) }
    fn for_stmt(&mut self, source_line: usize) -> Result<Stmt> { 
        let var=self.identifier()?; 
        self.consume(TokenKind::In)?; 
        
        // Check if it's "for x in range(...)" or "for x in array"
        if self.check(TokenKind::Range) {
            // Traditional range-based for loop
            self.consume(TokenKind::Range)?; 
            self.consume(TokenKind::LParen)?; 
            self.skip_newlines(); // Allow newlines after opening paren
            let start=self.expression()?; 
            self.skip_newlines(); // Allow newlines after start
            self.consume(TokenKind::Comma)?; 
            self.skip_newlines(); // Allow newlines after comma
            let end=self.expression()?; 
            self.skip_newlines(); // Allow newlines after end
            let step= if self.match_kind(&TokenKind::Comma){
                self.skip_newlines(); // Allow newlines after second comma
                Some(self.expression()?)
            } else {None}; 
            self.skip_newlines(); // Allow newlines before closing paren
            self.consume(TokenKind::RParen)?; 
            self.consume(TokenKind::Colon)?; 
            self.consume(TokenKind::Newline)?; 
            self.consume(TokenKind::Indent)?; 
            let mut body=Vec::new(); 
            while !self.match_kind(&TokenKind::Dedent){ 
                body.push(self.statement()?);
            } 
            Ok(Stmt::For { var, start, end, step, body, source_line }) 
        } else {
            // Iterator-based for-in loop: for x in array
            let iterable = self.expression()?;
            self.consume(TokenKind::Colon)?; 
            self.consume(TokenKind::Newline)?; 
            self.consume(TokenKind::Indent)?; 
            let mut body=Vec::new(); 
            while !self.match_kind(&TokenKind::Dedent){ 
                body.push(self.statement()?);
            } 
            Ok(Stmt::ForIn { var, iterable, body, source_line })
        }
    }
    fn if_stmt(&mut self, source_line: usize) -> Result<Stmt> { let cond=self.expression()?; self.consume(TokenKind::Colon)?; self.consume(TokenKind::Newline)?; self.consume(TokenKind::Indent)?; let mut body=Vec::new(); while !self.match_kind(&TokenKind::Dedent){ body.push(self.statement()?);} let mut elifs=Vec::new(); while self.match_kind(&TokenKind::Elif){ let ec=self.expression()?; self.consume(TokenKind::Colon)?; self.consume(TokenKind::Newline)?; self.consume(TokenKind::Indent)?; let mut ebody=Vec::new(); while !self.match_kind(&TokenKind::Dedent){ ebody.push(self.statement()?);} elifs.push((ec,ebody)); } let else_body= if self.match_kind(&TokenKind::Else){ self.consume(TokenKind::Colon)?; self.consume(TokenKind::Newline)?; self.consume(TokenKind::Indent)?; let mut eb=Vec::new(); while !self.match_kind(&TokenKind::Dedent){ eb.push(self.statement()?);} Some(eb)} else {None}; Ok(Stmt::If { cond, body, elifs, else_body, source_line }) }

    // --- expressions ---
    fn expression(&mut self) -> Result<Expr> { self.logic_or() }
    fn logic_or(&mut self) -> Result<Expr> { let mut node=self.logic_and()?; while self.match_kind(&TokenKind::Or){ let rhs=self.logic_and()?; node=Expr::Logic { op:LogicOp::Or, left:Box::new(node), right:Box::new(rhs)}; } Ok(node) }
    fn logic_and(&mut self) -> Result<Expr> { let mut node=self.bit_or()?; while self.match_kind(&TokenKind::And){ let rhs=self.bit_or()?; node=Expr::Logic { op:LogicOp::And, left:Box::new(node), right:Box::new(rhs)};} Ok(node) }
    fn bit_or(&mut self) -> Result<Expr> { let mut node=self.bit_xor()?; while self.match_kind(&TokenKind::Pipe){ let rhs=self.bit_xor()?; node=Expr::Binary { op:BinOp::BitOr, left:Box::new(node), right:Box::new(rhs)};} Ok(node) }
    fn bit_xor(&mut self) -> Result<Expr> { let mut node=self.bit_and()?; while self.match_kind(&TokenKind::Caret){ let rhs=self.bit_and()?; node=Expr::Binary { op:BinOp::BitXor, left:Box::new(node), right:Box::new(rhs)};} Ok(node) }
    fn bit_and(&mut self) -> Result<Expr> { let mut node=self.shift()?; while self.match_kind(&TokenKind::Amp){ let rhs=self.shift()?; node=Expr::Binary { op:BinOp::BitAnd, left:Box::new(node), right:Box::new(rhs)};} Ok(node) }
    fn shift(&mut self) -> Result<Expr> { let mut node=self.comparison()?; while let Some(op)= if self.match_kind(&TokenKind::ShiftLeft){Some(BinOp::Shl)} else if self.match_kind(&TokenKind::ShiftRight){Some(BinOp::Shr)} else {None} { let rhs=self.comparison()?; node=Expr::Binary { op, left:Box::new(node), right:Box::new(rhs)}; } Ok(node) }
    fn comparison(&mut self) -> Result<Expr> { let first=self.term()?; if let Some(op0)=self.match_cmp_op(){ let mut operands=vec![first]; let mut ops=vec![op0]; operands.push(self.term()?); while let Some(nop)=self.match_cmp_op(){ ops.push(nop); operands.push(self.term()?);} if ops.len()==1 { let left=operands.remove(0); let right=operands.remove(0); return Ok(Expr::Compare { op:ops[0], left:Box::new(left), right:Box::new(right)});} let mut chain=None; for i in 0..ops.len(){ let cmp=Expr::Compare { op:ops[i], left:Box::new(operands[i].clone()), right:Box::new(operands[i+1].clone())}; chain=Some(if let Some(acc)=chain { Expr::Logic { op:LogicOp::And, left:Box::new(acc), right:Box::new(cmp)} } else { cmp }); } return Ok(chain.unwrap()); } Ok(first) }
    fn term(&mut self) -> Result<Expr> { let mut node=self.factor()?; while let Some(op)= if self.match_kind(&TokenKind::Plus){Some(BinOp::Add)} else if self.match_kind(&TokenKind::Minus){Some(BinOp::Sub)} else {None} { let rhs=self.factor()?; node=Expr::Binary { op, left:Box::new(node), right:Box::new(rhs)};} Ok(node) }
    fn factor(&mut self) -> Result<Expr> { let mut node=self.unary()?; while let Some(op)= if self.match_kind(&TokenKind::Star){Some(BinOp::Mul)} else if self.match_kind(&TokenKind::Slash){Some(BinOp::Div)} else if self.match_kind(&TokenKind::SlashSlash){Some(BinOp::FloorDiv)} else if self.match_kind(&TokenKind::Percent){Some(BinOp::Mod)} else {None} { let rhs=self.unary()?; node=Expr::Binary { op, left:Box::new(node), right:Box::new(rhs)};} Ok(node) }
    fn unary(&mut self) -> Result<Expr> {
        if self.match_kind(&TokenKind::Not) {
            let inner = self.unary()?;
            return Ok(Expr::Not(Box::new(inner)));
        } else if self.match_kind(&TokenKind::Minus) {
            let rhs = self.unary()?;
            return Ok(Expr::Binary { op: BinOp::Sub, left: Box::new(Expr::Number(0)), right: Box::new(rhs) });
        } else if self.match_kind(&TokenKind::Plus) {
            return self.unary();
        } else if self.match_kind(&TokenKind::Tilde) {
            let inner = self.unary()?;
            return Ok(Expr::BitNot(Box::new(inner)));
        }
        self.postfix()
    }

    fn postfix(&mut self) -> Result<Expr> {
        let mut expr = self.primary()?;
        loop {
            // Handle field access: obj.field
            if self.match_kind(&TokenKind::Dot) {
                let field_line = self.peek().line;
                let field_col = self.peek().col;
                let field = self.identifier()?;
                expr = Expr::FieldAccess { 
                    target: Box::new(expr), 
                    field,
                    source_line: field_line,
                    col: field_col
                };
            }
            // Handle indexing: arr[index]
            else if self.match_kind(&TokenKind::LBracket) {
                let index = self.expression()?;
                self.consume(TokenKind::RBracket)?;
                expr = Expr::Index { target: Box::new(expr), index: Box::new(index) };
            }
            else {
                break;
            }
        }
        Ok(expr)
    }

    fn primary(&mut self) -> Result<Expr> {
        if let Some(n) = self.match_number() {
            return Ok(Expr::Number(n));
        } else if let Some(s) = self.match_string() {
            return Ok(Expr::StringLit(s));
        } else if self.match_kind(&TokenKind::Self_) {
            return Ok(Expr::Ident(IdentInfo { name: "self".to_string(), source_line: self.tokens[self.pos-1].line, col: self.tokens[self.pos-1].col }));
        } else if self.match_kind(&TokenKind::True) {
            return Ok(Expr::Number(1));
        } else if self.match_kind(&TokenKind::False) {
            return Ok(Expr::Number(0));
        } else if self.match_kind(&TokenKind::LBracket) {
            // Array literal: [1, 2, 3]
            let mut elements = Vec::new();
            self.skip_newlines();
            if !self.check(TokenKind::RBracket) {
                loop {
                    elements.push(self.expression()?);
                    self.skip_newlines();
                    if self.match_kind(&TokenKind::Comma) {
                        self.skip_newlines();
                        // Allow trailing comma
                        if self.check(TokenKind::RBracket) {
                            break;
                        }
                        continue;
                    }
                    break;
                }
            }
            self.skip_newlines();
            self.consume(TokenKind::RBracket)?;
            return Ok(Expr::List(elements));
        } else if let Some(first) = self.match_identifier() {
            let ident_token = self.tokens[self.pos-1].clone();
            
            // Check for function call or struct init
            if self.match_kind(&TokenKind::LParen) {
                let mut args = Vec::new();
                self.skip_newlines();
                if !self.check(TokenKind::RParen) {
                    loop {
                        args.push(self.expression()?);
                        self.skip_newlines();
                        if self.match_kind(&TokenKind::Comma) { 
                            self.skip_newlines();
                            continue; 
                        }
                        break;
                    }
                }
                self.skip_newlines();
                self.consume(TokenKind::RParen)?;
                
                // If no args and starts with uppercase, treat as struct init
                // UNLESS it's a known builtin function
                // (This is a heuristic; proper validation happens in semantic analysis)
                if args.is_empty() && first.chars().next().map_or(false, |c| c.is_uppercase()) 
                    && !is_known_builtin(&first) {
                    return Ok(Expr::StructInit {
                        struct_name: first,
                        source_line: ident_token.line,
                        col: ident_token.col,
                    });
                }
                
                // Otherwise, it's a function call
                return Ok(Expr::Call(crate::ast::CallInfo { 
                    name: first, 
                    source_line: ident_token.line, 
                    col: ident_token.col, 
                    args 
                }));
            }
            
            // Not a call, create identifier
            let mut expr = Expr::Ident(crate::ast::IdentInfo { 
                name: first, 
                source_line: ident_token.line, 
                col: ident_token.col 
            });
            
            // Handle field access: obj.field or method calls obj.method()
            while self.match_kind(&TokenKind::Dot) {
                let field_token = self.peek().clone();
                if let Some(field_name) = self.match_identifier() {
                    // Check if this is followed by a call (method call)
                    if self.check(TokenKind::LParen) {
                        // Method call: obj.method(args)
                        self.consume(TokenKind::LParen)?;
                        let mut args = Vec::new();
                        self.skip_newlines();
                        if !self.check(TokenKind::RParen) {
                            loop {
                                args.push(self.expression()?);
                                self.skip_newlines();
                                if self.match_kind(&TokenKind::Comma) { 
                                    self.skip_newlines();
                                    continue; 
                                }
                                break;
                            }
                        }
                        self.skip_newlines();
                        self.consume(TokenKind::RParen)?;
                        return Ok(Expr::MethodCall(crate::ast::MethodCallInfo { 
                            target: Box::new(expr),
                            method_name: field_name,
                            args,
                            source_line: field_token.line, 
                            col: field_token.col,
                        }));
                    } else {
                        // Field access
                        expr = Expr::FieldAccess {
                            target: Box::new(expr),
                            field: field_name,
                            source_line: field_token.line,
                            col: field_token.col,
                        };
                    }
                } else {
                    return self.err_here("Expected identifier after '.'");
                }
            }
            
            return Ok(expr);
        } else if self.match_kind(&TokenKind::LParen) {
            self.skip_newlines(); // Allow newlines after opening paren
            let e = self.expression()?;
            self.skip_newlines(); // Allow newlines before closing paren
            self.consume(TokenKind::RParen)?;
            return Ok(e);
        }
        self.err_here(&format!("Unexpected token {:?}", self.peek().kind))
    }

    // --- helpers ---
    fn expr_to_assign_target(&self, expr: Expr, line: usize) -> Result<crate::ast::AssignTarget> {
        match expr {
            Expr::Ident(info) => Ok(crate::ast::AssignTarget::Ident { 
                name: info.name, 
                source_line: info.source_line, 
                col: info.col 
            }),
            Expr::Index { target, index } => Ok(crate::ast::AssignTarget::Index { 
                target, 
                index, 
                source_line: line, 
                col: 0 
            }),
            Expr::FieldAccess { target, field, source_line, col } => Ok(crate::ast::AssignTarget::FieldAccess {
                target,
                field,
                source_line,
                col,
            }),
            _ => self.err_here(&format!("Invalid assignment target at line {}", line))
        }
    }
    
    fn match_ident_case(&mut self, upper:&str) -> bool { if let Some(TokenKind::Identifier(s))=self.peek_kind().cloned(){ if s.eq_ignore_ascii_case(upper){ self.advance(); return true; } } false }
    fn match_cmp_op(&mut self) -> Option<CmpOp> {
        let k=&self.peek().kind; let op=match k { TokenKind::EqEq=>Some(CmpOp::Eq), TokenKind::NotEq=>Some(CmpOp::Ne), TokenKind::Lt=>Some(CmpOp::Lt), TokenKind::Le=>Some(CmpOp::Le), TokenKind::Gt=>Some(CmpOp::Gt), TokenKind::Ge=>Some(CmpOp::Ge), _=>None }; if op.is_some(){ self.pos+=1; } op }
    fn match_number(&mut self) -> Option<i32> { if let TokenKind::Number(n)=self.peek().kind { let v=n; self.pos+=1; Some(v) } else { None } }
    fn match_string(&mut self) -> Option<String> { if let TokenKind::StringLit(s)=&self.peek().kind { let v=s.clone(); self.pos+=1; Some(v) } else { None } }
    fn match_identifier(&mut self) -> Option<String> { if let TokenKind::Identifier(s)=&self.peek().kind { let v=s.clone(); self.pos+=1; Some(v) } else { None } }
    fn try_identifier(&mut self) -> Option<String> { self.match_identifier() }
    fn unread_identifier(&mut self, name:String) { self.pos-=1; if let TokenKind::Identifier(s)=&self.tokens[self.pos].kind { assert_eq!(&name,s); } }
    fn identifier(&mut self) -> Result<String> { if let Some(s)=self.match_identifier(){ Ok(s) } else { self.err_here("Expected identifier") } }
    fn parse_signed_number(&mut self) -> Result<i32> { let neg=self.match_kind(&TokenKind::Minus); if let TokenKind::Number(n)=self.peek().kind { let v=n; self.pos+=1; Ok(if neg { -v } else { v }) } else { self.err_here("Expected number") } }
    fn consume(&mut self, kind: TokenKind) -> Result<()> { 
        if std::mem::discriminant(&self.peek().kind)==std::mem::discriminant(&kind) { 
            self.pos+=1; 
            Ok(()) 
        } else { 
            let expected = token_display_name(&kind);
            let got = token_display_name(&self.peek().kind);
            self.err_here(&format!("Expected {} got {}", expected, got)) 
        } 
    }
    fn check(&self, kind: TokenKind) -> bool { std::mem::discriminant(&self.peek().kind)==std::mem::discriminant(&kind) }
    fn check_identifier(&self) -> bool { matches!(self.peek().kind, TokenKind::Identifier(_)) }
    fn match_kind(&mut self, kind:&TokenKind) -> bool { if self.check(kind.clone()) { self.pos+=1; true } else { false } }
    fn peek(&self) -> &Token { &self.tokens[self.pos] }
    fn peek_kind(&self) -> Option<&TokenKind> { self.tokens.get(self.pos).map(|t| &t.kind) }
    fn advance(&mut self) { if self.pos < self.tokens.len() { self.pos+=1; } }
    
    // Helper to skip newlines (useful in multiline contexts like function arguments)
    fn skip_newlines(&mut self) {
        while self.match_kind(&TokenKind::Newline) {}
    }
    fn err_here<T>(&self, msg:&str) -> Result<T> { let tk=self.peek(); bail!("{}:{}:{}: error: {}", self.filename, tk.line, tk.col, msg) }
    
    // --- Import parsing ---
    // Supports:
    //   from module.path import symbol1, symbol2 as alias
    //   from .relative import symbol
    //   from ..parent import symbol
    //   import module
    //   import module as alias
    fn parse_import(&mut self) -> Result<crate::ast::ImportDecl> {
        use crate::ast::{ImportDecl, ImportSymbols, ImportedSymbol};
        
        let source_line = self.peek().line;
        let mut is_relative = false;
        let mut relative_level = 0;
        let mut module_path = Vec::new();
        
        if self.match_kind(&TokenKind::From) {
            // from X import Y
            
            // Check for relative imports (. or ..)
            while self.check(TokenKind::Dot) {
                self.advance();
                is_relative = true;
                relative_level += 1;
            }
            
            // Parse module path (module.submodule.etc)
            if let Some(first) = self.try_identifier() {
                module_path.push(first);
                while self.match_kind(&TokenKind::Dot) {
                    let part = self.identifier()?;
                    module_path.push(part);
                }
            }
            
            // Consume 'import'
            self.consume(TokenKind::Import)?;
            
            // Check for 'import *'
            if self.match_kind(&TokenKind::Star) {
                self.consume(TokenKind::Newline)?;
                return Ok(ImportDecl {
                    module_path,
                    symbols: ImportSymbols::All,
                    source_line,
                    is_relative,
                    relative_level,
                });
            }
            
            // Parse named imports: symbol1, symbol2 as alias, ...
            let mut symbols = Vec::new();
            loop {
                let name = self.identifier()?;
                let alias = if self.match_kind(&TokenKind::As) {
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
                source_line,
                is_relative,
                relative_level,
            })
        } else if self.match_kind(&TokenKind::Import) {
            // import module as alias
            let first = self.identifier()?;
            module_path.push(first);
            while self.match_kind(&TokenKind::Dot) {
                let part = self.identifier()?;
                module_path.push(part);
            }
            
            let alias = if self.match_kind(&TokenKind::As) {
                Some(self.identifier()?)
            } else {
                None
            };
            
            self.consume(TokenKind::Newline)?;
            Ok(ImportDecl {
                module_path,
                symbols: ImportSymbols::Module { alias },
                source_line,
                is_relative: false,
                relative_level: 0,
            })
        } else {
            self.err_here("Expected 'from' or 'import'")
        }
    }
    
    // --- Export parsing ---
    // Supports: export symbol1, symbol2, ...
    fn parse_export(&mut self) -> Result<Item> {
        use crate::ast::ExportDecl;
        
        let source_line = self.peek().line;
        self.consume(TokenKind::Export)?;
        
        let mut symbols = Vec::new();
        loop {
            let name = self.identifier()?;
            symbols.push(name);
            if !self.match_kind(&TokenKind::Comma) {
                break;
            }
        }
        
        self.consume(TokenKind::Newline)?;
        Ok(Item::Export(ExportDecl { symbols, source_line }))
    }
}
