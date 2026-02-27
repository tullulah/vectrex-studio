// Helpers - Runtime helper functions (MUL, DIV, etc.)

/// Emit 16-bit signed multiply helper routine
/// Input: MUL_A (i16), MUL_B (i16)
/// Output: RESULT = MUL_A * MUL_B (low 16 bits)
/// MUL_A and MUL_B are overwritten with their absolute values internally.
/// Uses: TMPPTR2+1 (sign flag)
pub fn emit_mul_helper(out: &mut String) {
    out.push_str(concat!(
        "MUL16:\n",
        // ── MUL_A sign ─────────────────────────────────────────────
        "    LDD MUL_A\n",
        "    BPL MUL16_APOS\n",
        "    COMA\n",
        "    COMB\n",
        "    ADDD #1\n",
        "    STD MUL_A\n",            // MUL_A = |a|
        "    LDA #1\n",
        "    STA TMPPTR2+1\n",        // sign_flag = 1
        "    BRA MUL16_BCHECK\n",
        "MUL16_APOS:\n",
        "    LDA #0\n",
        "    STA TMPPTR2+1\n",        // sign_flag = 0
        // ── MUL_B sign ─────────────────────────────────────────────
        "MUL16_BCHECK:\n",
        "    LDD MUL_B\n",
        "    BPL MUL16_BPOS\n",
        "    COMA\n",
        "    COMB\n",
        "    ADDD #1\n",
        "    STD MUL_B\n",            // MUL_B = |b|
        "    LDA TMPPTR2+1\n",
        "    EORA #1\n",
        "    STA TMPPTR2+1\n",        // toggle sign flag
        // ── Unsigned binary multiply: |a| * |b| ────────────────────
        "MUL16_BPOS:\n",
        "    LDD MUL_A\n",
        "    STD MUL_RES\n",
        "    LDD #0\n",
        "    STD MUL_TMP\n",
        "    LDD MUL_B\n",
        "    STD MUL_CNT\n",
        "MUL16_LOOP:\n",
        "    LDD MUL_CNT\n",
        "    BEQ MUL16_DONE\n",
        "    LDD MUL_CNT\n",
        "    ANDB #1\n",              // check LSB of low byte (was ANDA — bug fix)
        "    BEQ MUL16_SKIP\n",
        "    LDD MUL_RES\n",
        "    ADDD MUL_TMP\n",
        "    STD MUL_TMP\n",
        "MUL16_SKIP:\n",
        "    LDD MUL_RES\n",
        "    ASLB\n",
        "    ROLA\n",
        "    STD MUL_RES\n",
        "    LDD MUL_CNT\n",
        "    LSRA\n",
        "    RORB\n",
        "    STD MUL_CNT\n",
        "    BRA MUL16_LOOP\n",
        // ── Apply sign ─────────────────────────────────────────────
        "MUL16_DONE:\n",
        "    LDD MUL_TMP\n",
        "    LDA TMPPTR2+1\n",
        "    BEQ MUL16_STORE\n",
        "    COMA\n",
        "    COMB\n",
        "    ADDD #1\n",              // negate result
        "MUL16_STORE:\n",
        "    STD RESULT\n",
        "    RTS\n\n",
    ));
}

/// Emit 16-bit signed division helper routine
/// Input: DIV_A (dividend i16), DIV_B (divisor i16)
/// Output: RESULT = signed quotient
/// DIV_A and DIV_B are preserved (needed by Mod caller)
/// Uses: DIV_Q (quotient acc), DIV_R (|dividend| working), TMPPTR (|divisor|), TMPPTR2+1 (sign flag)
pub fn emit_div_helper(out: &mut String) {
    out.push_str(concat!(
        "DIV16:\n",
        "    LDD #0\n",
        "    STD DIV_Q\n",
        // ── Dividend sign ──────────────────────────────────────────
        "    LDD DIV_A\n",
        "    BPL DIV16_DPOS\n",       // if >= 0, skip negation
        "    COMA\n",
        "    COMB\n",
        "    ADDD #1\n",              // D = |dividend|
        "    STD DIV_R\n",            // DIV_R = |dividend|
        "    LDA #1\n",
        "    STA TMPPTR2+1\n",        // sign_flag = 1
        "    BRA DIV16_RCHECK\n",
        "DIV16_DPOS:\n",
        "    STD DIV_R\n",            // DIV_R = dividend (positive)
        "    LDA #0\n",
        "    STA TMPPTR2+1\n",        // sign_flag = 0
        // ── Divisor sign ───────────────────────────────────────────
        "DIV16_RCHECK:\n",
        "    LDD DIV_B\n",
        "    BEQ DIV16_DONE\n",       // divisor == 0 → return 0
        "    BPL DIV16_RPOS\n",       // if >= 0, skip negation
        "    COMA\n",
        "    COMB\n",
        "    ADDD #1\n",              // D = |divisor|
        "    STD TMPPTR\n",           // TMPPTR = |divisor|
        "    LDA TMPPTR2+1\n",
        "    EORA #1\n",
        "    STA TMPPTR2+1\n",        // toggle sign flag
        "    BRA DIV16_LOOP\n",
        "DIV16_RPOS:\n",
        "    STD TMPPTR\n",           // TMPPTR = |divisor| (already positive)
        // ── Unsigned subtraction loop ───────────────────────────────
        "DIV16_LOOP:\n",
        "    LDD DIV_R\n",
        "    SUBD TMPPTR\n",
        "    BLO DIV16_DONE\n",
        "    STD DIV_R\n",
        "    LDD DIV_Q\n",
        "    ADDD #1\n",
        "    STD DIV_Q\n",
        "    BRA DIV16_LOOP\n",
        // ── Apply sign to quotient ──────────────────────────────────
        "DIV16_DONE:\n",
        "    LDD DIV_Q\n",
        "    LDA TMPPTR2+1\n",
        "    BEQ DIV16_STORE\n",
        "    COMA\n",
        "    COMB\n",
        "    ADDD #1\n",              // negate for negative result
        "DIV16_STORE:\n",
        "    STD RESULT\n",
        "    RTS\n\n",
    ));
}
