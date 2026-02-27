#!/usr/bin/env python3
"""Disassemble key Vectrex BIOS routines for Print_Str_d analysis"""

data = open('/Users/daniel/projects/vectrex-pseudo-python/ide/frontend/src/assets/bios.bin', 'rb').read()
BASE = 0xE000

DP_LABELS = {
    0x00: "VIA_port_b", 0x01: "VIA_port_a", 0x02: "VIA_DDR_b", 0x03: "VIA_DDR_a",
    0x04: "VIA_t1_cnt_lo", 0x05: "VIA_t1_cnt_hi", 0x06: "VIA_t1_lch_lo",
    0x08: "VIA_t2_lo", 0x09: "VIA_t2_hi", 0x0A: "VIA_shift_reg", 0x0B: "VIA_aux_cntl",
    0x0C: "VIA_cntl(PCR)", 0x0D: "VIA_int_flags", 0x0E: "VIA_int_enable", 0x0F: "VIA_port_a_nohs",
}

LABELS = {
    0xF192: "Wait_Recal", 0xF1AA: "DP_to_D0", 0xF1AF: "DP_to_C8",
    0xF2E6: "Check0Ref", 0xF2FC: "Moveto_d_7F", 0xF312: "Moveto_d",
    0xF34A: "Reset0Ref_D0", 0xF354: "Reset0Ref", 0xF36B: "Reset0Int",
    0xF373: "Print_Str_hwyx", 0xF378: "Print_Str_yx", 0xF37A: "Print_Str_d",
    0xF495: "Print_Str", 0xF575: "Delay_1",
}

REGS = {0:'D',1:'X',2:'Y',3:'U',4:'S',5:'PC',8:'A',9:'B',0xA:'CC',0xB:'DP'}

def b(addr):
    return data[addr - BASE]

def w(addr):
    return (data[addr-BASE] << 8) | data[addr-BASE+1]

def disasm_range(start, end):
    addr = start
    while addr < end:
        if addr in LABELS:
            print(f"\n{LABELS[addr]}:")
        
        op = b(addr)
        
        # Page 2 prefix
        if op == 0x10:
            op2 = b(addr+1)
            if op2 == 0x83:
                val = w(addr+2)
                print(f"  {addr:04X}  CMPD #{val:04X}")
                addr += 4; continue
            elif op2 == 0x8E:
                val = w(addr+2)
                print(f"  {addr:04X}  LDY  #{val:04X}")
                addr += 4; continue
            elif op2 == 0xCE:
                val = w(addr+2)
                print(f"  {addr:04X}  LDS  #{val:04X}")
                addr += 4; continue
            elif op2 in (0x27, 0x26, 0x24, 0x25):
                names = {0x27:'LBEQ',0x26:'LBNE',0x24:'LBCC',0x25:'LBCS'}
                rel = w(addr+2)
                if rel >= 0x8000: rel -= 0x10000
                tgt = addr + 4 + rel
                lbl = LABELS.get(tgt, f"{tgt:04X}")
                print(f"  {addr:04X}  {names[op2]} {lbl}")
                addr += 4; continue
            else:
                print(f"  {addr:04X}  ??? 10 {op2:02X}")
                addr += 2; continue
        
        # 1-byte inherent
        inherent = {
            0x39:'RTS', 0x3D:'MUL', 0x3F:'SWI', 0x3B:'RTI',
            0x40:'NEGA', 0x43:'COMA', 0x44:'LSRA', 0x47:'ASRA', 0x48:'LSLA',
            0x49:'ROLA', 0x4A:'DECA', 0x4C:'INCA', 0x4D:'TSTA', 0x4F:'CLRA',
            0x50:'NEGB', 0x53:'COMB', 0x54:'LSRB', 0x57:'ASRB', 0x58:'LSLB',
            0x59:'ROLB', 0x5A:'DECB', 0x5C:'INCB', 0x5D:'TSTB', 0x5F:'CLRB',
        }
        if op in inherent:
            print(f"  {addr:04X}  {inherent[op]}")
            addr += 1; continue
        
        # TFR / EXG
        if op in (0x1E, 0x1F):
            pb = b(addr+1)
            r1 = REGS.get((pb>>4)&0xF, '?')
            r2 = REGS.get(pb&0xF, '?')
            name = 'TFR' if op == 0x1F else 'EXG'
            print(f"  {addr:04X}  {name}  {r1},{r2}")
            addr += 2; continue
        
        # PSHS/PULS
        if op in (0x34, 0x35):
            pb = b(addr+1)
            name = 'PSHS' if op == 0x34 else 'PULS'
            rl = []
            for bit, r in [(0x01,'CC'),(0x02,'A'),(0x04,'B'),(0x08,'DP'),
                           (0x10,'X'),(0x20,'Y'),(0x40,'U'),(0x80,'PC')]:
                if pb & bit: rl.append(r)
            print(f"  {addr:04X}  {name} {','.join(rl)}")
            addr += 2; continue
        
        # Branches (8-bit relative)
        branches = {
            0x20:'BRA',0x21:'BRN',0x22:'BHI',0x23:'BLS',0x24:'BCC',0x25:'BCS',
            0x26:'BNE',0x27:'BEQ',0x28:'BVC',0x29:'BVS',0x2A:'BPL',0x2B:'BMI',
            0x2C:'BGE',0x2D:'BLT',0x2E:'BGT',0x2F:'BLE',0x8D:'BSR',
        }
        if op in branches:
            rel = b(addr+1)
            if rel >= 0x80: rel -= 0x100
            tgt = addr + 2 + rel
            lbl = LABELS.get(tgt, f"{tgt:04X}")
            print(f"  {addr:04X}  {branches[op]}  {lbl}")
            addr += 2; continue
        
        # Direct page
        dp_ops = {
            0x00:'NEG',0x03:'COM',0x04:'LSR',0x06:'ROR',0x07:'ASR',0x08:'LSL',
            0x09:'ROL',0x0A:'DEC',0x0C:'INC',0x0D:'TST',0x0E:'JMP',0x0F:'CLR',
            0x90:'SUBA',0x91:'CMPA',0x93:'SUBD',0x94:'ANDA',0x95:'BITA',
            0x96:'LDA',0x97:'STA',0x98:'EORA',0x99:'ADCA',0x9A:'ORA',0x9B:'ADDA',
            0x9C:'CMPX',0x9D:'JSR',0x9E:'LDX',0x9F:'STX',
            0xD0:'SUBB',0xD1:'CMPB',0xD3:'ADDD',0xD4:'ANDB',0xD5:'BITB',
            0xD6:'LDB',0xD7:'STB',0xD8:'EORB',0xD9:'ADCB',0xDA:'ORB',0xDB:'ADDB',
            0xDC:'LDD',0xDD:'STD',0xDE:'LDU',0xDF:'STU',
        }
        if op in dp_ops:
            off = b(addr+1)
            dp_name = DP_LABELS.get(off, f"<{off:02X}>")
            print(f"  {addr:04X}  {dp_ops[op]:4s} <{dp_name}>  ; DP+${off:02X}")
            addr += 2; continue
        
        # Immediate 8-bit
        imm8 = {
            0x80:'SUBA',0x81:'CMPA',0x82:'SBCA',0x84:'ANDA',0x85:'BITA',
            0x86:'LDA',0x88:'EORA',0x89:'ADCA',0x8A:'ORA',0x8B:'ADDA',
            0xC0:'SUBB',0xC1:'CMPB',0xC4:'ANDB',0xC5:'BITB',0xC6:'LDB',
            0xC8:'EORB',0xC9:'ADCB',0xCA:'ORB',0xCB:'ADDB',
        }
        if op in imm8:
            val = b(addr+1)
            print(f"  {addr:04X}  {imm8[op]:4s} #${val:02X}")
            addr += 2; continue
        
        # Immediate 16-bit
        imm16 = {0x83:'SUBD',0x8C:'CMPX',0x8E:'LDX',0xC3:'ADDD',0xCC:'LDD',0xCE:'LDU'}
        if op in imm16:
            val = w(addr+1)
            lbl = LABELS.get(val, f"${val:04X}")
            print(f"  {addr:04X}  {imm16[op]:4s} #{lbl}")
            addr += 3; continue
        
        # Extended
        ext = {
            0xB0:'SUBA',0xB1:'CMPA',0xB3:'SUBD',0xB4:'ANDA',0xB5:'BITA',
            0xB6:'LDA',0xB7:'STA',0xB9:'ADCA',0xBA:'ORA',0xBB:'ADDA',
            0xBC:'CMPX',0xBD:'JSR',0xBE:'LDX',0xBF:'STX',
            0xF0:'SUBB',0xF1:'CMPB',0xF3:'ADDD',0xF6:'LDB',0xF7:'STB',
            0xFC:'LDD',0xFD:'STD',0xFE:'LDU',0xFF:'STU',
            0x7E:'JMP',0x7F:'CLR',
        }
        if op in ext:
            val = w(addr+1)
            lbl = LABELS.get(val, f"${val:04X}")
            print(f"  {addr:04X}  {ext[op]:4s} {lbl}")
            addr += 3; continue
        
        # Indexed  
        idx_ops = {
            0xA0:'SUBA',0xA1:'CMPA',0xA3:'SUBD',0xA4:'ANDA',0xA5:'BITA',
            0xA6:'LDA',0xA7:'STA',0xA9:'ADCA',0xAA:'ORA',0xAB:'ADDA',
            0xAC:'CMPX',0xAD:'JSR',0xAE:'LDX',0xAF:'STX',
            0xE0:'SUBB',0xE1:'CMPB',0xE3:'ADDD',0xE6:'LDB',0xE7:'STB',
            0xEC:'LDD',0xED:'STD',0xEE:'LDU',0xEF:'STU',
            0x30:'LEAX',0x31:'LEAY',0x32:'LEAS',0x33:'LEAU',
        }
        if op in idx_ops:
            pb = b(addr+1)
            ireg = {0:'X',1:'Y',2:'U',3:'S'}
            r = ireg.get((pb>>5)&3, '?')
            if pb & 0x80 == 0:
                # 5-bit offset
                off5 = pb & 0x1F
                if off5 >= 16: off5 -= 32
                operand = f"{off5},{r}"
                sz = 2
            else:
                mode = pb & 0x0F
                if mode == 0x04: operand = f",{r}"; sz = 2
                elif mode == 0x00: operand = f",{r}+"; sz = 2
                elif mode == 0x01: operand = f",{r}++"; sz = 2
                elif mode == 0x02: operand = f",-{r}"; sz = 2
                elif mode == 0x03: operand = f",--{r}"; sz = 2
                elif mode == 0x08:
                    off8 = b(addr+2)
                    if off8 >= 0x80: off8 -= 0x100
                    operand = f"{off8},{r}"
                    sz = 3
                elif mode == 0x09:
                    off16 = w(addr+2)
                    if off16 >= 0x8000: off16 -= 0x10000
                    operand = f"{off16},{r}"
                    sz = 4
                elif mode == 0x0C:
                    off8 = b(addr+2)
                    if off8 >= 0x80: off8 -= 0x100
                    operand = f"{off8},PC"
                    sz = 3
                elif mode == 0x0D:
                    off16 = w(addr+2)
                    if off16 >= 0x8000: off16 -= 0x10000
                    operand = f"{off16},PC"
                    sz = 4
                else:
                    operand = f"[pb=${pb:02X}]"
                    sz = 2
            print(f"  {addr:04X}  {idx_ops[op]:4s} {operand}")
            addr += sz; continue
        
        print(f"  {addr:04X}  ???  ${op:02X}")
        addr += 1


print("=" * 70)
print("BIOS DISASSEMBLY: Beam positioning and text routines")
print("DP=$D0 for all BIOS routines (VIA registers at $D000-$D00F)")
print("=" * 70)

print("\n\n=== Print_Str_d ($F37A) and related entry points ===")
disasm_range(0xF373, 0xF395)

print("\n\n=== Moveto_d_7F ($F2FC) / Moveto_d ($F312) ===")
disasm_range(0xF2FC, 0xF345)

print("\n\n=== Check0Ref ($F2E6) ===")
disasm_range(0xF2E6, 0xF2FC)

print("\n\n=== Reset0Ref_D0 ($F34A) / Reset0Ref ($F354) / Reset0Int ($F36B) ===")
disasm_range(0xF34A, 0xF373)

print("\n\n=== Print_Str ($F495) - character drawing loop ===")
disasm_range(0xF495, 0xF4D0)

print("\n\n=== Delay_1 ($F575) ===")
disasm_range(0xF575, 0xF57A)
