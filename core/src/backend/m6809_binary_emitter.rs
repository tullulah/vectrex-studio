// M6809 Binary Code Emitter - Generación directa de código máquina
// Elimina dependencia de lwasm proporcionando emisión binaria integrada con mapeo preciso

use std::collections::HashMap;

/// Representa una referencia a símbolo que necesita resolverse en la segunda pasada
#[derive(Debug, Clone)]
struct SymbolRef {
    offset: usize,      // Posición en el binario donde va la dirección
    symbol: String,     // Nombre del símbolo referenciado
    is_relative: bool,  // true para branches relativos, false para absolute
    ref_size: u8,       // 1 para offset de 8 bits, 2 para dirección de 16 bits
    addend: i16,        // Add/sub offset applied to the resolved symbol address
}

/// Emisor de código binario M6809 con tracking de direcciones y símbolos
pub struct BinaryEmitter {
    code: Vec<u8>,                          // Bytes de código generados
    pub current_address: u16,               // Dirección actual en memoria (ORG) - PUBLIC para debug
    symbols: HashMap<String, u16>,          // Tabla de símbolos: label -> dirección
    symbol_refs: Vec<SymbolRef>,            // Referencias pendientes de resolver
    line_to_offset: HashMap<usize, usize>,  // Línea VPy -> offset en binario
    offset_to_line: HashMap<usize, usize>,  // Offset en binario -> línea VPy
    current_line: usize,                    // Línea actual del código fuente VPy
}

impl BinaryEmitter {
    /// Crea nuevo emisor con dirección base especificada
    pub fn new(org: u16) -> Self {
        BinaryEmitter {
            code: Vec::new(),
            current_address: org,
            symbols: HashMap::new(),
            symbol_refs: Vec::new(),
            line_to_offset: HashMap::new(),
            offset_to_line: HashMap::new(),
            current_line: 0,
        }
    }

    /// Establece la línea actual del código fuente (para debug mapping)
    pub fn set_source_line(&mut self, line: usize) {
        self.current_line = line;
    }

    /// Obtiene el offset actual en el buffer de código
    pub fn current_offset(&self) -> usize {
        self.code.len()
    }

    /// Registra mapeo bidireccional línea ↔ offset
    fn record_line_mapping(&mut self) {
        let offset = self.current_offset();
        self.line_to_offset.insert(self.current_line, offset);
        self.offset_to_line.insert(offset, self.current_line);
    }

    /// Emite un byte y avanza la dirección actual
    pub fn emit(&mut self, byte: u8) {
        self.code.push(byte);
        self.current_address = self.current_address.wrapping_add(1);
    }

    /// Emite un word de 16 bits (big-endian, formato 6809)
    pub fn emit_word(&mut self, word: u16) {
        // DEBUG: Log suspicious values
        if word == 0xC982 || word == 0xC8A2 || (word & 0xFF00 == 0xC800) {
            eprintln!("DEBUG emit_word: word=0x{:04X} at offset=0x{:04X}", word, self.code.len());
        }
        self.emit((word >> 8) as u8);  // High byte primero
        self.emit(word as u8);          // Low byte segundo
    }

    /// Define una etiqueta en la posición actual
    pub fn define_label(&mut self, label: &str) {
        if label == "START" || label == "MAIN" || label == "LOOP_BODY" {
            eprintln!("🏷️  Defining label '{}' at current_address=0x{:04X} (offset=0x{:04X})", 
                label, self.current_address, self.code.len());
        }
        self.symbols.insert(label.to_string(), self.current_address);
    }

    /// Registra referencia a símbolo para resolver en segunda pasada
    pub fn add_symbol_ref(&mut self, symbol: &str, is_relative: bool, ref_size: u8) {
        self.add_symbol_ref_with_addend(symbol, is_relative, ref_size, 0);
    }

    /// Registra referencia a símbolo con addend (e.g. LABEL+1)
    pub fn add_symbol_ref_with_addend(&mut self, symbol: &str, is_relative: bool, ref_size: u8, addend: i16) {
        // CRITICAL FIX: Reject single-character symbols that are register names
        if symbol.len() == 1 {
            let c = symbol.chars().next().unwrap().to_ascii_uppercase();
            if ['A', 'B', 'X', 'Y', 'U', 'S', 'D'].contains(&c) {
                // This is likely a parsing error - register names should not be treated as symbols
                eprintln!("❌ BUG: Attempted to add register name '{}' as symbol at offset={} - REJECTED", symbol, self.current_offset());
                return; // Don't add invalid symbol refs
            }
        }
        
        self.symbol_refs.push(SymbolRef {
            offset: self.current_offset(),
            symbol: symbol.to_string(),
            is_relative,
            ref_size,
            addend,
        });
    }

    /// Emite un opcode de direccionamiento extendido y deja un placeholder para una
    /// dirección de 16 bits que se resolverá en segunda pasada.
    ///
    /// Esto evita el patrón incorrecto de: add_symbol_ref(); <instr>_extended(0x0000)
    /// donde el SymbolRef quedaba apuntando al opcode en vez del operando.
    pub fn emit_extended_symbol_ref(&mut self, opcode: u8, symbol: &str, addend: i16) {
        let start_offset = self.current_offset();
        if symbol.len() == 1 {
            eprintln!("⚠️ emit_extended_symbol_ref: symbol='{}' opcode=0x{:02X} addend={} offset={}", 
                symbol, opcode, addend, start_offset);
        }
        self.record_line_mapping();
        self.emit(opcode);
        self.add_symbol_ref_with_addend(symbol, false, 2, addend);
        self.emit_word(0x0000);
    }

    /// Emite uno o más bytes de opcode (e.g. [0x10, 0x8E]) seguidos de un
    /// operando inmediato de 16 bits (word) que referencia a un símbolo a
    /// resolver en segunda pasada.
    pub fn emit_immediate16_symbol_ref(&mut self, opcode: &[u8], symbol: &str, addend: i16) {
        // DEBUG: Log single-char symbols BEFORE emitting anything
        let start_offset = self.current_offset();
        if symbol.len() == 1 {
            eprintln!("⚠️ emit_immediate16_symbol_ref: symbol='{}' opcode={:02X?} addend={} offset={}", 
                symbol, opcode, addend, start_offset);
        }
        self.record_line_mapping();
        for &b in opcode {
            self.emit(b);
        }
        self.add_symbol_ref_with_addend(symbol, false, 2, addend);
        self.emit_word(0x0000);
    }

    // ========== INSTRUCCIONES DE CARGA/ALMACENAMIENTO ==========

    /// LDA #immediate (opcode 0x86)
    pub fn lda_immediate(&mut self, value: u8) {
        self.record_line_mapping();
        self.emit(0x86);
        self.emit(value);
    }

    /// LDA direct (opcode 0x96) - dirección de 8 bits
    pub fn lda_direct(&mut self, addr: u8) {
        self.record_line_mapping();
        self.emit(0x96);
        self.emit(addr);
    }

    /// LDA extended (opcode 0xB6) - dirección de 16 bits
    pub fn lda_extended(&mut self, addr: u16) {
        self.record_line_mapping();
        self.emit(0xB6);
        self.emit_word(addr);
    }

    /// LDA extended con símbolo (resolver después)
    pub fn lda_extended_sym(&mut self, symbol: &str) {
        self.record_line_mapping();
        self.emit(0xB6);
        self.add_symbol_ref(symbol, false, 2);
        self.emit_word(0x0000); // Placeholder
    }

    /// LDA indexed (opcode 0xA6) - modos indexados con postbyte
    pub fn lda_indexed(&mut self, postbyte: u8) {
        self.record_line_mapping();
        self.emit(0xA6);
        self.emit(postbyte);
    }

    /// LDB #immediate (opcode 0xC6)
    pub fn ldb_immediate(&mut self, value: u8) {
        self.record_line_mapping();
        self.emit(0xC6);
        self.emit(value);
    }

    /// LDB direct (opcode 0xD6)
    pub fn ldb_direct(&mut self, addr: u8) {
        self.record_line_mapping();
        self.emit(0xD6);
        self.emit(addr);
    }

    /// LDB extended (opcode 0xF6)
    pub fn ldb_extended(&mut self, addr: u16) {
        self.record_line_mapping();
        self.emit(0xF6);
        self.emit_word(addr);
    }

    /// LDB indexed (opcode 0xE6 + postbyte)
    pub fn ldb_indexed(&mut self, postbyte: u8) {
        self.record_line_mapping();
        self.emit(0xE6);
        self.emit(postbyte);
    }

    /// LDD #immediate (opcode 0xCC)
    pub fn ldd_immediate(&mut self, value: u16) {
        self.record_line_mapping();
        self.emit(0xCC);
        self.emit_word(value);
    }

    /// LDD extended (opcode 0xFC)
    pub fn ldd_extended(&mut self, addr: u16) {
        self.record_line_mapping();
        self.emit(0xFC);
        self.emit_word(addr);
    }

    /// LDD indexed (opcode 0xEC + postbyte)
    pub fn ldd_indexed(&mut self, postbyte: u8) {
        self.record_line_mapping();
        self.emit(0xEC);
        self.emit(postbyte);
    }

    /// STA direct (opcode 0x97)
    pub fn sta_direct(&mut self, addr: u8) {
        self.record_line_mapping();
        self.emit(0x97);
        self.emit(addr);
    }

    /// STA extended (opcode 0xB7)
    pub fn sta_extended(&mut self, addr: u16) {
        self.record_line_mapping();
        self.emit(0xB7);
        self.emit_word(addr);
    }

    /// STA indexed (opcode 0xA7) - modos indexados con postbyte
    pub fn sta_indexed(&mut self, postbyte: u8) {
        self.record_line_mapping();
        self.emit(0xA7);
        self.emit(postbyte);
    }

    /// STB direct (opcode 0xD7)
    pub fn stb_direct(&mut self, addr: u8) {
        self.record_line_mapping();
        self.emit(0xD7);
        self.emit(addr);
    }

    /// STB extended (opcode 0xF7)
    pub fn stb_extended(&mut self, addr: u16) {
        self.record_line_mapping();
        self.emit(0xF7);
        self.emit_word(addr);
    }

    /// STB indexed (opcode 0xE7) - modos indexados con postbyte
    pub fn stb_indexed(&mut self, postbyte: u8) {
        self.record_line_mapping();
        self.emit(0xE7);
        self.emit(postbyte);
    }

    /// STD extended (opcode 0xFD)
    pub fn std_extended(&mut self, addr: u16) {
        self.record_line_mapping();
        self.emit(0xFD);
        self.emit_word(addr);
    }

    /// STD indexed (opcode 0xED) - Store D register with indexed addressing
    pub fn std_indexed(&mut self, postbyte: u8) {
        self.record_line_mapping();
        self.emit(0xED);
        self.emit(postbyte);
    }

    // ========== INSTRUCCIONES DE CONTROL DE FLUJO ==========

    /// JSR extended (opcode 0xBD)
    pub fn jsr_extended(&mut self, addr: u16) {
        self.record_line_mapping();
        self.emit(0xBD);
        self.emit_word(addr);
    }

    /// JSR extended con símbolo (resolver después)
    pub fn jsr_extended_sym(&mut self, symbol: &str) {
        self.record_line_mapping();
        self.emit(0xBD);
        self.add_symbol_ref(symbol, false, 2);
        self.emit_word(0x0000); // Placeholder
    }

    /// RTS (opcode 0x39)
    pub fn rts(&mut self) {
        self.record_line_mapping();
        self.emit(0x39);
    }

    /// BSR - Branch to Subroutine (opcode 0x8D + offset relativo de 8 bits)
    pub fn bsr_offset(&mut self, offset: i8) {
        self.record_line_mapping();
        self.emit(0x8D);
        self.emit(offset as u8);
    }

    /// BSR con etiqueta (resolver después)
    pub fn bsr_label(&mut self, label: &str) {
        self.record_line_mapping();
        self.emit(0x8D);
        self.add_symbol_ref(label, true, 1);
        self.emit(0x00); // Placeholder
    }

    /// NOP - No Operation (opcode 0x12)
    pub fn nop(&mut self) {
        self.record_line_mapping();
        self.emit(0x12);
    }

    /// BRA - branch siempre (opcode 0x20)
    pub fn bra_offset(&mut self, offset: i8) {
        self.record_line_mapping();
        self.emit(0x20);
        self.emit(offset as u8);
    }

    /// BRA con etiqueta (resolver después)
    pub fn bra_label(&mut self, label: &str) {
        self.record_line_mapping();
        self.emit(0x20);
        self.add_symbol_ref(label, true, 1);
        self.emit(0x00); // Placeholder
    }

    /// BEQ - branch si igual/cero (opcode 0x27)
    pub fn beq_offset(&mut self, offset: i8) {
        self.record_line_mapping();
        self.emit(0x27);
        self.emit(offset as u8);
    }

    /// BEQ con etiqueta
    pub fn beq_label(&mut self, label: &str) {
        self.record_line_mapping();
        self.emit(0x27);
        self.add_symbol_ref(label, true, 1);
        self.emit(0x00);
    }

    /// LBEQ - long branch si igual/cero (opcode 0x10 0x27, offset 16-bit)
    pub fn lbeq_label(&mut self, label: &str) {
        self.record_line_mapping();
        self.emit(0x10);
        self.emit(0x27);
        self.add_symbol_ref(label, true, 2); // 2 bytes para offset de 16 bits
        self.emit(0x00);
        self.emit(0x00);
    }

    /// BNE - branch si no igual/no cero (opcode 0x26)
    pub fn bne_offset(&mut self, offset: i8) {
        self.record_line_mapping();
        self.emit(0x26);
        self.emit(offset as u8);
    }

    /// BNE con etiqueta
    pub fn bne_label(&mut self, label: &str) {
        self.record_line_mapping();
        self.emit(0x26);
        self.add_symbol_ref(label, true, 1);
        self.emit(0x00);
    }

    /// LBNE - long branch si no igual (opcode 0x10 0x26, offset 16-bit)
    pub fn lbne_label(&mut self, label: &str) {
        self.record_line_mapping();
        self.emit(0x10);
        self.emit(0x26);
        self.add_symbol_ref(label, true, 2);
        self.emit(0x00);
        self.emit(0x00);
    }

    /// BCC - branch si carry clear (opcode 0x24)
    pub fn bcc_offset(&mut self, offset: i8) {
        self.record_line_mapping();
        self.emit(0x24);
        self.emit(offset as u8);
    }

    /// BCS - branch si carry set (opcode 0x25)
    pub fn bcs_offset(&mut self, offset: i8) {
        self.record_line_mapping();
        self.emit(0x25);
        self.emit(offset as u8);
    }

    // ========== INSTRUCCIONES ARITMÉTICAS Y LÓGICAS ==========

    /// ADDA #immediate (opcode 0x8B)
    pub fn adda_immediate(&mut self, value: u8) {
        self.record_line_mapping();
        self.emit(0x8B);
        self.emit(value);
    }

    /// ADDA extended (opcode 0xBB)
    pub fn adda_extended(&mut self, addr: u16) {
        self.record_line_mapping();
        self.emit(0xBB);
        self.emit_word(addr);
    }

    /// ADDB #immediate (opcode 0xCB)
    pub fn addb_immediate(&mut self, value: u8) {
        self.record_line_mapping();
        self.emit(0xCB);
        self.emit(value);
    }

    /// ADDD #immediate (opcode 0xC3) - 16-bit add to D register
    pub fn addd_immediate(&mut self, value: u16) {
        self.record_line_mapping();
        self.emit(0xC3);
        self.emit_word(value);
    }

    /// ADDD extended (opcode 0xF3) - 16-bit add to D register
    pub fn addd_extended(&mut self, addr: u16) {
        self.record_line_mapping();
        self.emit(0xF3);
        self.emit_word(addr);
    }

    /// SUBD #immediate (opcode 0x83) - 16-bit subtract from D register
    pub fn subd_immediate(&mut self, value: u16) {
        self.record_line_mapping();
        self.emit(0x83);
        self.emit_word(value);
    }

    /// SUBD extended (opcode 0xB3) - 16-bit subtract from D register
    pub fn subd_extended(&mut self, addr: u16) {
        self.record_line_mapping();
        self.emit(0xB3);
        self.emit_word(addr);
    }

    /// SUBD indexed (opcode 0xA3) - 16-bit subtract from D register with indexed addressing
    pub fn subd_indexed(&mut self, postbyte: u8) {
        self.record_line_mapping();
        self.emit(0xA3);
        self.emit(postbyte);
    }

    /// SUBA #immediate (opcode 0x80)
    pub fn suba_immediate(&mut self, value: u8) {
        self.record_line_mapping();
        self.emit(0x80);
        self.emit(value);
    }

    /// SUBB #immediate (opcode 0xC0)
    pub fn subb_immediate(&mut self, value: u8) {
        self.record_line_mapping();
        self.emit(0xC0);
        self.emit(value);
    }

    /// SBCA #immediate (opcode 0x82) - Subtract with Carry from A
    pub fn sbca_immediate(&mut self, value: u8) {
        self.record_line_mapping();
        self.emit(0x82);
        self.emit(value);
    }

    /// SBCB #immediate (opcode 0xC2) - Subtract with Carry from B
    pub fn sbcb_immediate(&mut self, value: u8) {
        self.record_line_mapping();
        self.emit(0xC2);
        self.emit(value);
    }

    /// ANDA #immediate (opcode 0x84)
    pub fn anda_immediate(&mut self, value: u8) {
        self.record_line_mapping();
        self.emit(0x84);
        self.emit(value);
    }

    /// ANDB #immediate (opcode 0xC4)
    pub fn andb_immediate(&mut self, value: u8) {
        self.record_line_mapping();
        self.emit(0xC4);
        self.emit(value);
    }

    /// BITA #immediate (opcode 0x85)
    pub fn bita_immediate(&mut self, value: u8) {
        self.record_line_mapping();
        self.emit(0x85);
        self.emit(value);
    }

    /// BITA extended (opcode 0xB5)
    pub fn bita_extended(&mut self, addr: u16) {
        self.record_line_mapping();
        self.emit(0xB5);
        self.emit_word(addr);
    }

    /// BITB #immediate (opcode 0xC5)
    pub fn bitb_immediate(&mut self, value: u8) {
        self.record_line_mapping();
        self.emit(0xC5);
        self.emit(value);
    }

    /// BITB extended (opcode 0xF5)
    pub fn bitb_extended(&mut self, addr: u16) {
        self.record_line_mapping();
        self.emit(0xF5);
        self.emit_word(addr);
    }

    /// ORB #immediate (opcode 0xCA)
    pub fn orb_immediate(&mut self, value: u8) {
        self.record_line_mapping();
        self.emit(0xCA);
        self.emit(value);
    }

    /// ORA #immediate (opcode 0x8A)
    pub fn ora_immediate(&mut self, value: u8) {
        self.record_line_mapping();
        self.emit(0xAA);  // ORAA #immediate (was 0x8A = ORCC, WRONG!)
        self.emit(value);
    }

    /// EORA #immediate (opcode 0x88)
    pub fn eora_immediate(&mut self, value: u8) {
        self.record_line_mapping();
        self.emit(0x88);
        self.emit(value);
    }

    /// CLRA (opcode 0x4F)
    pub fn clra(&mut self) {
        self.record_line_mapping();
        self.emit(0x4F);
    }

    /// CLRB (opcode 0x5F)
    pub fn clrb(&mut self) {
        self.record_line_mapping();
        self.emit(0x5F);
    }

    /// CLR extended (opcode 0x7F) - Clear memory location
    pub fn clr_extended(&mut self, addr: u16) {
        self.record_line_mapping();
        self.emit(0x7F);
        self.emit_word(addr);
    }
    
    /// CLR indexed (opcode 0x6F) - Clear memory location (indexed mode)
    pub fn clr_indexed(&mut self, postbyte: u8) {
        self.record_line_mapping();
        self.emit(0x6F);
        self.emit(postbyte);
    }
    
    /// INC extended (opcode 0x7C) - Increment memory location (extended mode)
    pub fn inc_extended(&mut self, addr: u16) {
        self.record_line_mapping();
        self.emit(0x7C);
        self.emit_word(addr);
    }
    
    /// INC indexed (opcode 0x6C) - Increment memory location (indexed mode)
    pub fn inc_indexed(&mut self, postbyte: u8) {
        self.record_line_mapping();
        self.emit(0x6C);
        self.emit(postbyte);
    }
    
    /// DEC direct (opcode 0x0A) - Decrement memory location (direct page mode)
    pub fn dec_direct(&mut self, addr: u8) {
        self.record_line_mapping();
        self.emit(0x0A);
        self.emit(addr);
    }
    
    /// DEC extended (opcode 0x7A) - Decrement memory location (extended mode)
    pub fn dec_extended(&mut self, addr: u16) {
        self.record_line_mapping();
        self.emit(0x7A);
        self.emit_word(addr);
    }
    
    /// DEC indexed (opcode 0x6A) - Decrement memory location (indexed mode)
    pub fn dec_indexed(&mut self, postbyte: u8) {
        self.record_line_mapping();
        self.emit(0x6A);
        self.emit(postbyte);
    }

    /// INCA (opcode 0x4C)
    pub fn inca(&mut self) {
        self.record_line_mapping();
        self.emit(0x4C);
    }

    /// INCB (opcode 0x5C)
    pub fn incb(&mut self) {
        self.record_line_mapping();
        self.emit(0x5C);
    }

    /// DECA (opcode 0x4A)
    pub fn deca(&mut self) {
        self.record_line_mapping();
        self.emit(0x4A);
    }

    /// DECB (opcode 0x5A)
    pub fn decb(&mut self) {
        self.record_line_mapping();
        self.emit(0x5A);
    }

    /// NEGA (opcode 0x40) - Negate A (two's complement)
    pub fn nega(&mut self) {
        self.record_line_mapping();
        self.emit(0x40);
    }

    /// NEGB (opcode 0x50) - Negate B (two's complement)
    pub fn negb(&mut self) {
        self.record_line_mapping();
        self.emit(0x50);
    }

    /// COMA (opcode 0x43) - Complement A (one's complement)
    pub fn coma(&mut self) {
        self.record_line_mapping();
        self.emit(0x43);
    }

    /// COMB (opcode 0x53) - Complement B (one's complement)
    pub fn comb(&mut self) {
        self.record_line_mapping();
        self.emit(0x53);
    }

    /// ASLA (opcode 0x48) - Arithmetic Shift Left A
    pub fn asla(&mut self) {
        self.record_line_mapping();
        self.emit(0x48);
    }

    /// ASLB (opcode 0x58) - Arithmetic Shift Left B
    pub fn aslb(&mut self) {
        self.record_line_mapping();
        self.emit(0x58);
    }

    /// ROLA (opcode 0x49) - Rotate Left A
    pub fn rola(&mut self) {
        self.record_line_mapping();
        self.emit(0x49);
    }

    /// ROLB (opcode 0x59) - Rotate Left B
    pub fn rolb(&mut self) {
        self.record_line_mapping();
        self.emit(0x59);
    }

    /// LSRA (opcode 0x44) - Logical Shift Right A
    pub fn lsra(&mut self) {
        self.record_line_mapping();
        self.emit(0x44);
    }

    /// LSRB (opcode 0x54) - Logical Shift Right B
    pub fn lsrb(&mut self) {
        self.record_line_mapping();
        self.emit(0x54);
    }

    /// ASRA (opcode 0x47) - Arithmetic Shift Right A
    pub fn asra(&mut self) {
        self.record_line_mapping();
        self.emit(0x47);
    }

    /// ASRB (opcode 0x57) - Arithmetic Shift Right B
    pub fn asrb(&mut self) {
        self.record_line_mapping();
        self.emit(0x57);
    }

    /// RORA (opcode 0x46) - Rotate Right A
    pub fn rora(&mut self) {
        self.record_line_mapping();
        self.emit(0x46);
    }

    /// RORB (opcode 0x56) - Rotate Right B
    pub fn rorb(&mut self) {
        self.record_line_mapping();
        self.emit(0x56);
    }

    /// ABX (opcode 0x3A) - Add B to X
    pub fn abx(&mut self) {
        self.record_line_mapping();
        self.emit(0x3A);
    }

    /// MUL (opcode 0x3D) - Multiply A by B unsigned, result in D (A=hi, B=lo)
    pub fn mul(&mut self) {
        self.record_line_mapping();
        self.emit(0x3D);
    }

    /// SEX (opcode 0x1D) - Sign EXtend B into A
    /// Extends the sign bit of register B into register A
    /// If B is negative (bit 7 = 1), sets A to 0xFF
    /// If B is positive (bit 7 = 0), sets A to 0x00
    pub fn sex(&mut self) {
        self.record_line_mapping();
        self.emit(0x1D);
    }

    /// EXCH (opcode 0x1E) - Exchange A and B registers
    pub fn exch(&mut self) {
        self.record_line_mapping();
        self.emit(0x1E);
    }

    /// TSTA (opcode 0x4D) - Test A (actualiza flags sin modificar A)
    pub fn tsta(&mut self) {
        self.record_line_mapping();
        self.emit(0x4D);
    }

    /// TSTB (opcode 0x5D) - Test B (actualiza flags sin modificar B)
    pub fn tstb(&mut self) {
        self.record_line_mapping();
        self.emit(0x5D);
    }

    /// TST extended (opcode 0x7D) - Test memory location
    pub fn tst_extended(&mut self, addr: u16) {
        self.record_line_mapping();
        self.emit(0x7D);
        self.emit_word(addr);
    }

    /// TST extended con símbolo
    pub fn tst_extended_sym(&mut self, symbol: &str) {
        self.record_line_mapping();
        self.emit(0x7D);
        self.add_symbol_ref(symbol, false, 2);
        self.emit_word(0x0000); // Placeholder
    }

    // ========== INSTRUCCIONES DE TRANSFERENCIA/COMPARACIÓN ==========

    /// TFR (opcode 0x1F) - requiere postbyte con src/dst
    pub fn tfr(&mut self, src: u8, dst: u8) {
        self.record_line_mapping();
        self.emit(0x1F);
        self.emit((src << 4) | dst);
    }

    /// CMPA #immediate (opcode 0x81)
    pub fn cmpa_immediate(&mut self, value: u8) {
        self.record_line_mapping();
        self.emit(0x81);
        self.emit(value);
    }

    /// CMPB #immediate (opcode 0xC1)
    pub fn cmpb_immediate(&mut self, value: u8) {
        self.record_line_mapping();
        self.emit(0xC1);
        self.emit(value);
    }

    /// CMPD #immediate (opcode 0x1083) - Compare D register with 16-bit value
    pub fn cmpd_immediate(&mut self, value: u16) {
        self.record_line_mapping();
        self.emit(0x10);
        self.emit(0x83);
        self.emit_word(value);
    }

    /// CMPD extended (opcode 0x10B3) - Compare D register with memory
    pub fn cmpd_extended(&mut self, addr: u16) {
        self.record_line_mapping();
        self.emit(0x10);
        self.emit(0xB3);
        self.emit_word(addr);
    }

    /// CMPX #immediate (opcode 0x8C) - Compare X register with 16-bit value
    pub fn cmpx_immediate(&mut self, value: u16) {
        self.record_line_mapping();
        self.emit(0x8C);
        self.emit_word(value);
    }

    /// CMPY #immediate (opcode 0x108C) - Compare Y register with 16-bit value
    pub fn cmpy_immediate(&mut self, value: u16) {
        self.record_line_mapping();
        self.emit(0x10);
        self.emit(0x8C);
        self.emit_word(value);
    }

    /// CMPU #immediate (opcode 0x1183) - Compare U register with 16-bit value
    pub fn cmpu_immediate(&mut self, value: u16) {
        self.record_line_mapping();
        self.emit(0x11);
        self.emit(0x83);
        self.emit_word(value);
    }

    /// CMPS #immediate (opcode 0x118C) - Compare S register with 16-bit value
    pub fn cmps_immediate(&mut self, value: u16) {
        self.record_line_mapping();
        self.emit(0x11);
        self.emit(0x8C);
        self.emit_word(value);
    }

    // ========== INSTRUCCIONES 16-BIT ADICIONALES ==========

    /// JMP extended (opcode 0x7E)
    pub fn jmp_extended(&mut self, addr: u16) {
        self.record_line_mapping();
        self.emit(0x7E);
        self.emit_word(addr);
    }

    /// JMP extended con símbolo
    pub fn jmp_extended_sym(&mut self, symbol: &str) {
        self.record_line_mapping();
        self.emit(0x7E);
        self.add_symbol_ref(symbol, false, 2);
        self.emit_word(0x0000);
    }

    /// LDX #immediate (opcode 0x8E)
    pub fn ldx_immediate(&mut self, value: u16) {
        self.record_line_mapping();
        self.emit(0x8E);
        self.emit_word(value);
    }

    /// LDX #immediate con símbolo (opcode 0x8E + symbol ref)
    pub fn ldx_immediate_sym(&mut self, symbol: &str) {
        self.record_line_mapping();
        self.emit(0x8E);
        self.add_symbol_ref(symbol, false, 2);
        self.emit_word(0); // Placeholder for symbol resolution
    }

    /// LDX extended (opcode 0xBE)
    pub fn ldx_extended(&mut self, addr: u16) {
        self.record_line_mapping();
        self.emit(0xBE);
        self.emit_word(addr);
    }

    /// LDX extended con símbolo
    pub fn ldx_extended_sym(&mut self, symbol: &str) {
        self.record_line_mapping();
        self.emit(0xBE);
        self.add_symbol_ref(symbol, false, 2);
        self.emit_word(0x0000);
    }

    /// LDX indexed (opcode 0xAE + postbyte)
    pub fn ldx_indexed(&mut self, postbyte: u8) {
        self.record_line_mapping();
        self.emit(0xAE);
        self.emit(postbyte);
    }

    /// LDY #immediate (opcode 0x108E)
    pub fn ldy_immediate(&mut self, value: u16) {
        self.record_line_mapping();
        self.emit(0x10);
        self.emit(0x8E);
        self.emit_word(value);
    }

    /// LDY #immediate with symbol reference
    pub fn ldy_immediate_sym(&mut self, symbol: &str) {
        self.record_line_mapping();
        self.emit(0x10);
        self.emit(0x8E);
        self.add_symbol_ref(symbol, false, 2);
        self.emit_word(0x0000);
    }

    /// LDY extended (opcode 0x10BE)
    pub fn ldy_extended(&mut self, addr: u16) {
        self.record_line_mapping();
        self.emit(0x10);
        self.emit(0xBE);
        self.emit_word(addr);
    }

    /// LDY indexed (opcode 0x10AE + postbyte)
    pub fn ldy_indexed(&mut self, postbyte: u8) {
        self.record_line_mapping();
        self.emit(0x10);
        self.emit(0xAE);
        self.emit(postbyte);
    }

    /// STX extended (opcode 0xBF)
    pub fn stx_extended(&mut self, addr: u16) {
        self.record_line_mapping();
        self.emit(0xBF);
        self.emit_word(addr);
    }

    /// STX indexed (opcode 0xAF + postbyte)
    pub fn stx_indexed(&mut self, postbyte: u8) {
        self.record_line_mapping();
        self.emit(0xAF);
        self.emit(postbyte);
    }

    /// STY extended (opcode 0x10BF)
    pub fn sty_extended(&mut self, addr: u16) {
        self.record_line_mapping();
        self.emit(0x10);
        self.emit(0xBF);
        self.emit_word(addr);
    }

    /// STY indexed (opcode 0x10AF + postbyte)
    pub fn sty_indexed(&mut self, postbyte: u8) {
        self.record_line_mapping();
        self.emit(0x10);
        self.emit(0xAF);
        self.emit(postbyte);
    }

    /// LDU #immediate (opcode 0xCE)
    pub fn ldu_immediate(&mut self, value: u16) {
        self.record_line_mapping();
        self.emit(0xCE);
        self.emit_word(value);
    }

    /// LDU #immediate con símbolo (opcode 0xCE + symbol ref)
    pub fn ldu_immediate_sym(&mut self, symbol: &str) {
        self.record_line_mapping();
        self.emit(0xCE);
        self.add_symbol_ref(symbol, false, 2);
        self.emit_word(0); // Placeholder for symbol resolution
    }

    /// LDU indexed (opcode 0xEE)
    pub fn ldu_indexed(&mut self, postbyte: u8) {
        self.record_line_mapping();
        self.emit(0xEE);
        self.emit(postbyte);
    }

    /// LDU extended (opcode 0xFE)
    pub fn ldu_extended(&mut self, addr: u16) {
        self.record_line_mapping();
        self.emit(0xFE);
        self.emit_word(addr);
    }

    /// LDU extended con símbolo
    pub fn ldu_extended_sym(&mut self, symbol: &str) {
        self.record_line_mapping();
        self.emit(0xFE);
        self.add_symbol_ref(symbol, false, 2);
        self.emit_word(0x0000);
    }

    /// STU extended (opcode 0xFF)
    pub fn stu_extended(&mut self, addr: u16) {
        self.record_line_mapping();
        self.emit(0xFF);
        self.emit_word(addr);
    }

    /// LEAX indexed (opcode 0x30 + postbyte)
    pub fn leax_indexed(&mut self, postbyte: u8) {
        self.record_line_mapping();
        self.emit(0x30);
        self.emit(postbyte);
    }

    /// LEAY indexed (opcode 0x31 + postbyte)
    pub fn leay_indexed(&mut self, postbyte: u8) {
        self.record_line_mapping();
        self.emit(0x31);
        self.emit(postbyte);
    }

    /// LEAS indexed (opcode 0x32 + postbyte)
    pub fn leas_indexed(&mut self, postbyte: u8) {
        self.record_line_mapping();
        self.emit(0x32);
        self.emit(postbyte);
    }

    /// LEAU indexed (opcode 0x33 + postbyte)
    pub fn leau_indexed(&mut self, postbyte: u8) {
        self.record_line_mapping();
        self.emit(0x33);
        self.emit(postbyte);
    }

    // ========== INSTRUCCIONES DE STACK ==========

    /// PSHS (opcode 0x34 + postbyte con registros a apilar)
    pub fn pshs(&mut self, postbyte: u8) {
        self.record_line_mapping();
        self.emit(0x34);
        self.emit(postbyte);
    }

    /// PSHU (opcode 0x36 + postbyte)
    pub fn pshu(&mut self, postbyte: u8) {
        self.record_line_mapping();
        self.emit(0x36);
        self.emit(postbyte);
    }

    /// PULS (opcode 0x35 + postbyte)
    pub fn puls(&mut self, postbyte: u8) {
        self.record_line_mapping();
        self.emit(0x35);
        self.emit(postbyte);
    }

    /// PULU (opcode 0x37 + postbyte)
    pub fn pulu(&mut self, postbyte: u8) {
        self.record_line_mapping();
        self.emit(0x37);
        self.emit(postbyte);
    }

    // ========== DIRECTIVAS DE DATOS ==========

    /// Emite bytes directos (para FCC, FCB, etc.)
    pub fn emit_bytes(&mut self, bytes: &[u8]) {
        self.record_line_mapping();
        for &byte in bytes {
            self.emit(byte);
        }
    }

    /// Emite string ASCII (para FCC)
    pub fn emit_string(&mut self, s: &str) {
        self.record_line_mapping();
        for byte in s.bytes() {
            self.emit(byte);
        }
    }

    /// Emite word de 16 bits (para FDB/FDW)
    pub fn emit_data_word(&mut self, word: u16) {
        self.record_line_mapping();
        self.emit_word(word);
    }

    /// Reserva bytes (para RMB) - emite zeros
    pub fn reserve_bytes(&mut self, count: usize) {
        self.record_line_mapping();
        for _ in 0..count {
            self.emit(0x00);
        }
    }

    // ========== RESOLUCIÓN DE SÍMBOLOS (SEGUNDA PASADA) ==========

    /// Resuelve todas las referencias a símbolos después de la primera pasada
    /// Busca primero en symbols (labels locales), luego en equates (símbolos externos/BIOS)
    pub fn resolve_symbols_with_equates(&mut self, equates: &std::collections::HashMap<String, u16>) -> Result<(), String> {
        for sym_ref in &self.symbol_refs {
            // Buscar primero en symbols locales (case-sensitive)
            let target_addr = if let Some(&addr) = self.symbols.get(&sym_ref.symbol) {
                addr
            } else {
                // Buscar en equates con uppercase (símbolos BIOS/INCLUDE son uppercase)
                let upper_symbol = sym_ref.symbol.to_uppercase();
                if equates.get(&upper_symbol).is_none() {
                    // Debug: mostrar DÓNDE se agregó esta referencia
                    eprintln!("❌ SÍMBOLO NO RESUELTO: '{}' (uppercase: '{}') at offset={}, is_relative={}, ref_size={}", 
                        sym_ref.symbol, upper_symbol, sym_ref.offset, sym_ref.is_relative, sym_ref.ref_size);
                    
                    // Si es un carácter solitario, probablemente es un error de parsing
                    if sym_ref.symbol.len() == 1 {
                        eprintln!("   ⚠️  POSIBLE BUG: Símbolo de 1 carácter '{}' - probablemente offset mal parseado", sym_ref.symbol);
                    }
                }
                *equates.get(&upper_symbol)
                    .ok_or_else(|| format!("Símbolo no definido: {} (buscado como {})", sym_ref.symbol, upper_symbol))?
            };

            let effective_target = target_addr.wrapping_add(sym_ref.addend as u16);

            if sym_ref.is_relative {
                // Branch relativo: calcular offset desde la siguiente instrucción
                // Fórmula correcta: next_addr = branch_instruction_addr + opcode_size + ref_size (offset bytes)
                let org = self.current_address - self.code.len() as u16;
                
                // Detectar si es long branch (opcode 2 bytes) o short branch (opcode 1 byte)
                // Long branches: LBEQ, LBNE, LBCC, LBCS, etc. (opcode = 0x10 0x2x)
                // Short branches: BEQ, BNE, BCC, BCS, etc. (opcode = 0x2x)
                let opcode_size = if sym_ref.ref_size == 2 { 2 } else { 1 };
                
                // CRÍTICO: sym_ref.offset apunta al OFFSET FIELD, no al inicio del opcode
                // Por eso necesitamos restar opcode_size para obtener el inicio real del branch
                let branch_instruction_addr = org + sym_ref.offset as u16 - opcode_size;
                let next_addr = branch_instruction_addr + opcode_size + sym_ref.ref_size as u16;
                let offset_i32 = effective_target as i32 - next_addr as i32;
                
                // 🔍 TRACE: Resolución de branches importantes (expandido para debug)
                if sym_ref.symbol.contains("ULR") || sym_ref.symbol == "DSL_NEXT_PATH" || sym_ref.symbol == "DSL_LOOP" || sym_ref.symbol == "DSL_DONE" {
                    eprintln!("🔗 Resolving {} at offset {}: branch_addr=${:04X}, opcode_size={}, ref_size={}, next=${:04X}, target=${:04X}, offset={}", 
                        sym_ref.symbol, sym_ref.offset, branch_instruction_addr, opcode_size, sym_ref.ref_size, next_addr, target_addr, offset_i32);
                }
                
                if sym_ref.ref_size == 1 {
                    // Branch corto (8-bit offset)
                    if offset_i32 < -128 || offset_i32 > 127 {
                        return Err(format!(
                            "❌ Branch offset OUT OF RANGE for '{}' at 0x{:04X}: offset={} (need LBEQ/LBNE/LBxx instead of BEQ/BNE/Bxx)\n   Tip: Distance from 0x{:04X} to 0x{:04X} = {} bytes (exceeds 8-bit range -128..127)",
                            sym_ref.symbol, branch_instruction_addr, offset_i32, next_addr, target_addr, offset_i32
                        ));
                    }
                    let offset = offset_i32 as i8;
                    self.code[sym_ref.offset] = offset as u8;
                } else {
                    // Long branch (16-bit offset)
                    let offset = offset_i32 as i16;
                    self.code[sym_ref.offset] = (offset >> 8) as u8;     // High byte
                    self.code[sym_ref.offset + 1] = (offset & 0xFF) as u8; // Low byte
                }
            } else {
                // Dirección absoluta de 16 bits
                if sym_ref.ref_size == 2 {
                    // 🔍 DEBUG: Log ALL symbol resolutions (temporary debug)
                    let should_log = sym_ref.symbol.starts_with('_') || sym_ref.symbol == "START" || sym_ref.symbol == "MAIN" || sym_ref.symbol == "LOOP_BODY";
                    if should_log {
                        if sym_ref.addend != 0 {
                            eprintln!("🔗 Symbol '{}' at bin_offset=0x{:04X} resolved to addr=0x{:04X} (addend {:+}) => 0x{:04X}", 
                                sym_ref.symbol, sym_ref.offset, target_addr, sym_ref.addend, effective_target);
                        } else {
                            eprintln!("🔗 Symbol '{}' at bin_offset=0x{:04X} resolved to addr=0x{:04X}", 
                                sym_ref.symbol, sym_ref.offset, target_addr);
                        }
                    }
                    self.code[sym_ref.offset] = (effective_target >> 8) as u8;
                    self.code[sym_ref.offset + 1] = effective_target as u8;
                } else {
                    // Dirección de 8 bits (direct page)
                    self.code[sym_ref.offset] = effective_target as u8;
                }
            }
        }
        Ok(())
    }

    /// Versión legacy que solo usa symbols internos (deprecated)
    #[allow(dead_code)]
    pub fn resolve_symbols(&mut self) -> Result<(), String> {
        use std::collections::HashMap;
        let empty_equates = HashMap::new();
        self.resolve_symbols_with_equates(&empty_equates)
    }

    // ========== SALIDA FINAL ==========

    /// Obtiene el código binario generado
    pub fn finalize(self) -> Vec<u8> {
        self.code
    }

    /// Obtiene el mapeo línea -> offset
    pub fn get_line_to_offset_map(&self) -> &HashMap<usize, usize> {
        &self.line_to_offset
    }

    /// Obtiene el mapeo offset -> línea
    #[allow(dead_code)]
    pub fn get_offset_to_line_map(&self) -> &HashMap<usize, usize> {
        &self.offset_to_line
    }

    /// Obtiene la dirección base (ORG)
    #[allow(dead_code)]
    pub fn get_org(&self) -> u16 {
        self.current_address - self.code.len() as u16
    }
    
    /// Obtiene la tabla de símbolos (labels -> addresses reales)
    pub fn get_symbol_table(&self) -> &HashMap<String, u16> {
        &self.symbols
    }
}

// Constantes para TFR - códigos de registros
#[allow(dead_code)]
pub mod tfr_regs {
    pub const D: u8 = 0;  // A:B concatenado
    pub const X: u8 = 1;
    pub const Y: u8 = 2;
    pub const U: u8 = 3;
    pub const S: u8 = 4;
    pub const PC: u8 = 5;
    pub const A: u8 = 8;
    pub const B: u8 = 9;
    pub const CC: u8 = 10;
    pub const DP: u8 = 11;
}
