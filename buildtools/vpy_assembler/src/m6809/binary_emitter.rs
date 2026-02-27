// M6809 Binary Code Emitter - Direct machine code generation
// Eliminates dependency on lwasm by providing integrated binary emission with precise mapping

use std::collections::HashMap;
use super::asm_to_binary::{UnresolvedRef, RefType};

/// Represents a symbol reference that needs to be resolved in the second pass
#[derive(Debug, Clone)]
struct SymbolRef {
    offset: usize,      // Position in binary where the address goes
    symbol: String,     // Name of the referenced symbol
    is_relative: bool,  // true for relative branches, false for absolute
    ref_size: u8,       // 1 for 8-bit offset, 2 for 16-bit address
    addend: i16,        // Add/sub offset applied to the resolved symbol address
}

/// M6809 binary code emitter with address and symbol tracking
pub struct BinaryEmitter {
    code: Vec<u8>,                          // Generated code bytes
    pub current_address: u16,               // Current memory address (ORG) - PUBLIC for debug
    symbols: HashMap<String, u16>,          // Symbol table: label -> address
    symbol_refs: Vec<SymbolRef>,            // Pending references to resolve
    line_to_offset: HashMap<usize, usize>,  // VPy line -> binary offset
    offset_to_line: HashMap<usize, usize>,  // Binary offset -> VPy line
    current_line: usize,                    // Current VPy source line
    object_mode: bool,                      // Object mode: allow unresolved symbols
    unresolved_refs: Vec<UnresolvedRef>,    // Unresolved symbols (for object mode)
    use_long_branches: bool,                // Multi-bank mode: use long branches (LBEQ/LBNE/LBRA) instead of short
}

impl BinaryEmitter {
    /// Creates a new emitter with the specified base address
    pub fn new(org: u16) -> Self {
        BinaryEmitter {
            code: Vec::new(),
            current_address: org,
            symbols: HashMap::new(),
            symbol_refs: Vec::new(),
            line_to_offset: HashMap::new(),
            offset_to_line: HashMap::new(),
            current_line: 0,
            object_mode: false,
            unresolved_refs: Vec::new(),
            use_long_branches: false,
        }
    }
    
    /// Set object mode (allows unresolved symbols)
    pub fn set_object_mode(&mut self, enabled: bool) {
        self.object_mode = enabled;
    }
    
    /// Set long branch mode (use LBEQ/LBNE/LBRA instead of BEQ/BNE/BRA)
    /// Required for multi-bank ROMs where branches may exceed 8-bit range
    pub fn set_long_branches(&mut self, enabled: bool) {
        self.use_long_branches = enabled;
    }
    
    /// Get list of unresolved symbols (for object mode)
    pub fn take_unresolved_refs(&mut self) -> Vec<UnresolvedRef> {
        std::mem::take(&mut self.unresolved_refs)
    }

    /// Sets the current source line (for debug mapping)
    pub fn set_source_line(&mut self, line: usize) {
        self.current_line = line;
    }

    /// Gets the current offset in the code buffer
    pub fn current_offset(&self) -> usize {
        self.code.len()
    }

    /// Records bidirectional line ↔ offset mapping
    fn record_line_mapping(&mut self) {
        let offset = self.current_offset();
        self.line_to_offset.insert(self.current_line, offset);
        self.offset_to_line.insert(offset, self.current_line);
    }

    /// Emits a byte and advances the current address
    pub fn emit(&mut self, byte: u8) { 
        self.code.push(byte);
        self.current_address = self.current_address.wrapping_add(1);
    }

    /// Emits a 16-bit word (big-endian, 6809 format)
    pub fn emit_word(&mut self, word: u16) {
        self.emit((word >> 8) as u8);  // High byte first
        self.emit(word as u8);          // Low byte second
    }

    /// Defines a label at the current position
    pub fn define_label(&mut self, label: &str) {
        // Use current_address for the label, which already accounts for ORG
        // This works correctly for all ORG values including $4000 for Bank 31
        let label_address = self.current_address;
        
        // Store both original and uppercase variants for case-insensitive lookup
        self.symbols.insert(label.to_string(), label_address);
        self.symbols.insert(label.to_uppercase(), label_address);
    }

    /// Records a symbol reference to resolve in the second pass
    pub fn add_symbol_ref(&mut self, symbol: &str, is_relative: bool, ref_size: u8) {
        self.add_symbol_ref_with_addend(symbol, is_relative, ref_size, 0);
    }

    /// Records a symbol reference with addend (e.g. LABEL+1)
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

    /// Emits an extended addressing opcode and leaves a placeholder for a
    /// 16-bit address to be resolved in the second pass.
    ///
    /// This avoids the incorrect pattern of: add_symbol_ref(); <instr>_extended(0x0000)
    /// where the SymbolRef ended up pointing at the opcode instead of the operand.
    pub fn emit_extended_symbol_ref(&mut self, opcode: u8, symbol: &str, addend: i16) {
        self.record_line_mapping();
        self.emit(opcode);
        self.add_symbol_ref_with_addend(symbol, false, 2, addend);
        self.emit_word(0x0000);
    }

    /// Emits one or more opcode bytes (e.g. [0x10, 0x8E]) followed by a
    /// 16-bit immediate word operand referencing a symbol to be resolved
    /// in the second pass.
    pub fn emit_immediate16_symbol_ref(&mut self, opcode: &[u8], symbol: &str, addend: i16) {
        self.record_line_mapping();
        for &b in opcode {
            self.emit(b);
        }
        self.add_symbol_ref_with_addend(symbol, false, 2, addend);
        self.emit_word(0x0000);
    }

    // ========== LOAD/STORE INSTRUCTIONS ==========

    /// LDA #immediate (opcode 0x86)
    pub fn lda_immediate(&mut self, value: u8) {
        self.record_line_mapping();
        self.emit(0x86);
        self.emit(value);
    }

    /// LDA direct (opcode 0x96) - 8-bit address
    pub fn lda_direct(&mut self, addr: u8) {
        self.record_line_mapping();
        self.emit(0x96);
        self.emit(addr);
    }

    /// LDA extended (opcode 0xB6) - 16-bit address
    pub fn lda_extended(&mut self, addr: u16) {
        self.record_line_mapping();
        self.emit(0xB6);
        self.emit_word(addr);
    }

    /// LDA extended with symbol (resolve later)
    pub fn lda_extended_sym(&mut self, symbol: &str) {
        self.record_line_mapping();
        self.emit(0xB6);
        self.add_symbol_ref(symbol, false, 2);
        self.emit_word(0x0000); // Placeholder
    }

    /// LDA indexed (opcode 0xA6) - indexed modes with postbyte
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

    /// STA indexed (opcode 0xA7) - indexed modes with postbyte
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

    /// STB indexed (opcode 0xE7) - indexed modes with postbyte
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

    // ========== CONTROL FLOW INSTRUCTIONS ==========

    /// JSR extended (opcode 0xBD)
    pub fn jsr_extended(&mut self, addr: u16) {
        self.record_line_mapping();
        self.emit(0xBD);
        self.emit_word(addr);
    }

    /// JSR extended with symbol (resolve later)
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

    /// BSR - Branch to Subroutine (opcode 0x8D + 8-bit relative offset)
    pub fn bsr_offset(&mut self, offset: i8) {
        self.record_line_mapping();
        self.emit(0x8D);
        self.emit(offset as u8);
    }

    /// BSR with label (resolve later)
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

    /// BRA - branch always (opcode 0x20)
    pub fn bra_offset(&mut self, offset: i8) {
        self.record_line_mapping();
        self.emit(0x20);
        self.emit(offset as u8);
    }

    /// BRA with label (auto-selects short/long based on configuration)
    pub fn bra_label(&mut self, label: &str) {
        if self.use_long_branches {
            self.lbra_label(label);
        } else {
            self.record_line_mapping();
            self.emit(0x20);
            self.add_symbol_ref(label, true, 1);
            self.emit(0x00); // Placeholder
        }
    }

    /// LBRA - long branch siempre (opcode 0x16, offset 16-bit)
    /// NOTE: LBRA tiene opcode especial 0x16 (no 0x10 0x20 como otros long branches)
    pub fn lbra_label(&mut self, label: &str) {
        self.record_line_mapping();
        self.emit(0x16);  // LBRA special opcode (not 0x10 0x20)
        self.add_symbol_ref(label, true, 2); // 2 bytes para offset de 16 bits
        self.emit(0x00);
        self.emit(0x00);
    }

    /// BEQ - branch if equal/zero (opcode 0x27)
    pub fn beq_offset(&mut self, offset: i8) {
        self.record_line_mapping();
        self.emit(0x27);
        self.emit(offset as u8);
    }

    /// BEQ with label (auto-selects short/long based on configuration)
    pub fn beq_label(&mut self, label: &str) {
        if self.use_long_branches {
            self.lbeq_label(label);
        } else {
            self.record_line_mapping();
            self.emit(0x27);
            self.add_symbol_ref(label, true, 1);
            self.emit(0x00);
        }
    }

    /// LBEQ - long branch if equal/zero (opcode 0x10 0x27, 16-bit offset)
    pub fn lbeq_label(&mut self, label: &str) {
        self.record_line_mapping();
        self.emit(0x10);
        self.emit(0x27);
        self.add_symbol_ref(label, true, 2); // 2 bytes for 16-bit offset
        self.emit(0x00);
        self.emit(0x00);
    }

    /// BNE - branch if not equal/not zero (opcode 0x26)
    pub fn bne_offset(&mut self, offset: i8) {
        self.record_line_mapping();
        self.emit(0x26);
        self.emit(offset as u8);
    }

    /// BNE with label (auto-selects short/long based on configuration)
    pub fn bne_label(&mut self, label: &str) {
        if self.use_long_branches {
            self.lbne_label(label);
        } else {
            self.record_line_mapping();
            self.emit(0x26);
            self.add_symbol_ref(label, true, 1);
            self.emit(0x00);
        }
    }

    /// LBNE - long branch if not equal (opcode 0x10 0x26, 16-bit offset)
    pub fn lbne_label(&mut self, label: &str) {
        self.record_line_mapping();
        self.emit(0x10);
        self.emit(0x26);
        self.add_symbol_ref(label, true, 2);
        self.emit(0x00);
        self.emit(0x00);
    }

    /// BCC - branch if carry clear (opcode 0x24)
    pub fn bcc_offset(&mut self, offset: i8) {
        self.record_line_mapping();
        self.emit(0x24);
        self.emit(offset as u8);
    }

    /// BCS - branch if carry set (opcode 0x25)
    pub fn bcs_offset(&mut self, offset: i8) {
        self.record_line_mapping();
        self.emit(0x25);
        self.emit(offset as u8);
    }

    // ========== ARITHMETIC AND LOGIC INSTRUCTIONS ==========

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

    /// ADCA #immediate (opcode 0x89)
    pub fn adca_immediate(&mut self, value: u8) {
        self.record_line_mapping();
        self.emit(0x89);
        self.emit(value);
    }

    /// ADCA direct (opcode 0x99)
    pub fn adca_direct(&mut self, addr: u8) {
        self.record_line_mapping();
        self.emit(0x99);
        self.emit(addr);
    }

    /// ADCA indexed (opcode 0xA9)
    pub fn adca_indexed(&mut self, postbyte: u8) {
        self.record_line_mapping();
        self.emit(0xA9);
        self.emit(postbyte);
    }

    /// ADCA extended (opcode 0xB9)
    pub fn adca_extended(&mut self, addr: u16) {
        self.record_line_mapping();
        self.emit(0xB9);
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

    /// TST extended with symbol
    pub fn tst_extended_sym(&mut self, symbol: &str) {
        self.record_line_mapping();
        self.emit(0x7D);
        self.add_symbol_ref(symbol, false, 2);
        self.emit_word(0x0000); // Placeholder
    }

    // ========== TRANSFER/COMPARISON INSTRUCTIONS ==========

    /// TFR (opcode 0x1F) - requires postbyte with src/dst
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

    /// CMPX extended (opcode 0xBC) - Compare X register with memory
    pub fn cmpx_extended(&mut self, addr: u16) {
        self.record_line_mapping();
        self.emit(0xBC);
        self.emit_word(addr);
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

    // ========== ADDITIONAL 16-BIT INSTRUCTIONS ==========

    /// JMP extended (opcode 0x7E)
    pub fn jmp_extended(&mut self, addr: u16) {
        self.record_line_mapping();
        self.emit(0x7E);
        self.emit_word(addr);
    }

    /// JMP extended with symbol
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

    /// LDX #immediate with symbol (opcode 0x8E + symbol ref)
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

    /// LDX extended with symbol
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

    /// LDU #immediate with symbol (opcode 0xCE + symbol ref)
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

    /// LDU extended with symbol
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

    /// LDS #immediate (opcode 0x10CE) - Load Stack Pointer
    pub fn lds_immediate(&mut self, value: u16) {
        self.record_line_mapping();
        self.emit(0x10);
        self.emit(0xCE);
        self.emit_word(value);
    }

    /// LDS #immediate with symbol (opcode 0x10CE + symbol ref)
    pub fn lds_immediate_sym(&mut self, symbol: &str) {
        self.record_line_mapping();
        self.emit(0x10);
        self.emit(0xCE);
        self.add_symbol_ref(symbol, false, 2);
        self.emit_word(0); // Placeholder for symbol resolution
    }

    /// LDS direct (opcode 0x10DE)
    pub fn lds_direct(&mut self, addr: u8) {
        self.record_line_mapping();
        self.emit(0x10);
        self.emit(0xDE);
        self.emit(addr);
    }

    /// LDS indexed (opcode 0x10EE + postbyte)
    pub fn lds_indexed(&mut self, postbyte: u8) {
        self.record_line_mapping();
        self.emit(0x10);
        self.emit(0xEE);
        self.emit(postbyte);
    }

    /// LDS extended (opcode 0x10FE)
    pub fn lds_extended(&mut self, addr: u16) {
        self.record_line_mapping();
        self.emit(0x10);
        self.emit(0xFE);
        self.emit_word(addr);
    }

    /// LDS extended with symbol
    pub fn lds_extended_sym(&mut self, symbol: &str) {
        self.record_line_mapping();
        self.emit(0x10);
        self.emit(0xFE);
        self.add_symbol_ref(symbol, false, 2);
        self.emit_word(0x0000);
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

    // ========== DATA DIRECTIVES ==========

    /// Emits raw bytes (for FCC, FCB, etc.)
    pub fn emit_bytes(&mut self, bytes: &[u8]) {
        self.record_line_mapping();
        for &byte in bytes {
            self.emit(byte);
        }
    }

    /// Emits ASCII string (for FCC)
    pub fn emit_string(&mut self, s: &str) {
        self.record_line_mapping();
        for byte in s.bytes() {
            self.emit(byte);
        }
    }

    /// Emits a 16-bit word (for FDB/FDW)
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

    // ========== SYMBOL RESOLUTION (SECOND PASS) ==========

    /// Resolves all symbol references after the first pass
    /// Searches first in symbols (local labels), then in equates (external/BIOS symbols)
    pub fn resolve_symbols_with_equates(&mut self, equates: &std::collections::HashMap<String, u16>) -> Result<(), String> {
        for sym_ref in &self.symbol_refs {
            // Search first in local symbols (case-sensitive)
            let target_addr_opt = if let Some(&addr) = self.symbols.get(&sym_ref.symbol) {
                Some(addr)
            } else {
                // Search in equates with uppercase (BIOS/INCLUDE symbols are uppercase)
                let upper_symbol = sym_ref.symbol.to_uppercase();
                equates.get(&upper_symbol).copied()
            };

            // If the symbol was not found
            let target_addr = match target_addr_opt {
                Some(addr) => addr,
                None => {
                    let upper_symbol = sym_ref.symbol.to_uppercase();

                    // In object mode: add to unresolved_refs and use placeholder
                    if self.object_mode {
                        let ref_type = if sym_ref.is_relative {
                            if sym_ref.ref_size == 1 {
                                RefType::Relative8
                            } else {
                                RefType::Relative16
                            }
                        } else {
                            RefType::Absolute16
                        };
                        
                        self.unresolved_refs.push(UnresolvedRef {
                            symbol: upper_symbol.clone(),
                            offset: sym_ref.offset,
                            ref_type,
                        });
                        
                        // Use placeholder 0x0000 (already emitted during first pass)
                        continue;
                    }

                    // In normal mode: error
                    eprintln!("❌ UNRESOLVED SYMBOL: '{}' (uppercase: '{}') at offset={}, is_relative={}, ref_size={}",
                        sym_ref.symbol, upper_symbol, sym_ref.offset, sym_ref.is_relative, sym_ref.ref_size);

                    // If a single character, likely a parsing error
                    if sym_ref.symbol.len() == 1 {
                        eprintln!("   ⚠️  POSSIBLE BUG: Single-character symbol '{}' - likely misparse offset", sym_ref.symbol);
                    }

                    return Err(format!("Undefined symbol: {} (searched as {})", sym_ref.symbol, upper_symbol));
                }
            };

            let effective_target = target_addr.wrapping_add(sym_ref.addend as u16);

            if sym_ref.is_relative {
                // Relative branch: calculate offset from the next instruction
                // Correct formula: next_addr = branch_instruction_addr + opcode_size + ref_size (offset bytes)
                let org = self.current_address.wrapping_sub(self.code.len() as u16);

                // Detect whether it is a long branch (opcode 1 or 2 bytes) or short branch (opcode 1 byte)
                // LBRA: opcode 0x16 (1 byte!) + 2 bytes offset = 3 bytes total
                // LBEQ, LBNE, LBCC, etc.: opcode 0x10 0x2x (2 bytes) + 2 bytes offset = 4 bytes total
                // Short branches: BEQ, BNE, etc.: opcode 0x2x (1 byte) + 1 byte offset = 2 bytes total
                let opcode_size = if sym_ref.ref_size == 2 {
                    // Check if this is LBRA (opcode 0x16) or standard long branch (opcode 0x10 0x2x)
                    // sym_ref.offset points to the offset field, so we check the byte before it
                    let prev_byte = if sym_ref.offset > 0 { self.code[sym_ref.offset - 1] } else { 0 };
                    let is_lbra = prev_byte == 0x16;
                    if is_lbra {
                        1 // LBRA has 1-byte opcode (0x16)
                    } else {
                        2 // Other long branches have 2-byte opcode (0x10 0x2x)
                    }
                } else { 
                    1 // Short branches have 1-byte opcode
                };
                
                // CRITICAL: sym_ref.offset points to the OFFSET FIELD, not the start of the opcode
                // Therefore we need to subtract opcode_size to get the real branch start
                let branch_instruction_addr = org.wrapping_add(sym_ref.offset as u16).wrapping_sub(opcode_size);
                let next_addr = branch_instruction_addr + opcode_size + sym_ref.ref_size as u16;
                let offset_i32 = effective_target as i32 - next_addr as i32;
                
                if sym_ref.ref_size == 1 {
                    // Short branch (8-bit offset)
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
                // Absolute 16-bit address
                if sym_ref.ref_size == 2 {
                    self.code[sym_ref.offset] = (effective_target >> 8) as u8;
                    self.code[sym_ref.offset + 1] = effective_target as u8;
                } else {
                    // 8-bit address (direct page)
                    self.code[sym_ref.offset] = effective_target as u8;
                }
            }
        }
        Ok(())
    }

    /// Legacy version that only uses internal symbols (deprecated)
    #[allow(dead_code)]
    pub fn resolve_symbols(&mut self) -> Result<(), String> {
        use std::collections::HashMap;
        let empty_equates = HashMap::new();
        self.resolve_symbols_with_equates(&empty_equates)
    }

    // ========== FINAL OUTPUT ==========

    /// Gets the generated binary code
    pub fn finalize(self) -> Vec<u8> {
        self.code
    }

    /// Gets the line -> offset mapping
    pub fn get_line_to_offset_map(&self) -> &HashMap<usize, usize> {
        &self.line_to_offset
    }

    /// Gets the offset -> line mapping
    #[allow(dead_code)]
    pub fn get_offset_to_line_map(&self) -> &HashMap<usize, usize> {
        &self.offset_to_line
    }

    /// Gets the base address (ORG)
    #[allow(dead_code)]
    pub fn get_org(&self) -> u16 {
        self.current_address.wrapping_sub(self.code.len() as u16)
    }
    
    /// Changes the base address (ORG) and pads with fill bytes if necessary.
    /// Used when the ASM has multiple ORG directives (e.g., code + vectors).
    pub fn set_org(&mut self, new_org: u16) {
        let current_org = self.get_org();
        let current_offset = self.code.len();

        // Calculate how many bytes we need to add to reach the new ORG.
        // new_org must be >= current_address to make sense.
        if new_org < self.current_address {
            eprintln!("⚠️  Warning: ORG ${:04X} is before current address ${:04X} - padding backward",
                new_org, self.current_address);
            // In this case, calculate the expected offset.
            // If initial ORG was $FFF0 and current is $0020, and new_org is $FFF0
            // we want to keep the offset but change current_address.
            self.current_address = new_org;
            return;
        }

        // Calculate how many padding bytes we need
        let target_offset = if current_org == 0 {
            // Normal ORG (sequential): new_org is the direct offset
            new_org as usize
        } else {
            // High-base ORG (e.g., $FFF0): calculate relative offset
            // If current_org = $FFF0 and new_org = $FFF0, offset does not change
            // If current_org = $FFF0 and new_org = $0020, we want offset = $0030 (0x0020 + 0x0010)
            let offset_from_base = (new_org.wrapping_sub(current_org)) as usize;
            current_offset + offset_from_base
        };

        // Fill with 0xFF up to the target offset
        if target_offset > current_offset {
            self.code.resize(target_offset, 0xFF);
        }

        // Update current address
        self.current_address = new_org;
    }

    /// Gets the symbol table (labels -> real addresses)
    pub fn get_symbol_table(&self) -> &HashMap<String, u16> {
        &self.symbols
    }
}

// TFR register code constants
#[allow(dead_code)]
pub mod tfr_regs {
    pub const D: u8 = 0;  // A:B concatenated
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
