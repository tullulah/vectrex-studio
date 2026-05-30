/*
JSVecX : JavaScript port of the VecX emulator by raz0red.
         Copyright (C) 2010-2019 raz0red

The original C version was written by Valavan Manohararajah
(http://valavan.net/vectrex.html).
*/

/*
  Emulation of the AY-3-8910 / YM2149 sound chip.

  Based on various code snippets by Ville Hallik, Michael Cuddy,
  Tatsuyuki Satoh, Fabrice Frances, Nicola Salmoria.
*/

// Global music function call tracing
var MUSIC_CALL_LOG = [];
var MUSIC_CALL_LOG_ENABLED = false;
var MUSIC_CALL_LOG_LIMIT = 10000;

// Known music function addresses (from jetpac compilation)
var MUSIC_FUNCTION_ADDRS = {
  0x008B: 'PLAY_MUSIC_RUNTIME',
  0x0093: 'UPDATE_MUSIC_PSG',
  0x013B: 'STOP_MUSIC_RUNTIME'
};

// Opcode execution trace buffer (circular, last 100 opcodes)
var OPCODE_TRACE_BUFFER = [];
// Default to a larger buffer so we can capture the jump into garbage/ram.
// Can be overridden at runtime via window.OPCODE_TRACE_MAX.
// Bumped 2000 → 50000 to capture enough history to see bank-switch transitions
// (the crash class we're chasing — a runtime that switches bank then returns
// to caller without restoring — leaves no obvious local marker; we need the
// instruction whose STA $DF00 / STA CURRENT_ROM_BANK flipped to the wrong bank).
var OPCODE_TRACE_MAX = 50000;
// Per-instruction trace is OFF by default — it adds significant overhead
// (Array.shift on a 50000-entry buffer is O(N) per instruction). When chasing
// a crash, enable at runtime in the DevTools console:
//     window.OPCODE_TRACE_ENABLED = true
// and reproduce. The crash-dump path (PC/regs/stack snapshot/bank) still
// fires unconditionally, so most diagnostics work without the per-instruction
// trace anyway.
var OPCODE_TRACE_ENABLED = false;
var ERROR_HALT = false;
var CURRENT_ROM_NAME = null;
var CURRENT_ROM_PATH = null;
var TRACE_DUMPED = false;
var TRACE_DUMP_IN_PROGRESS = false;

// Full trace (stream-to-disk) mode
// IMPORTANT: this runs on the emulation thread. Avoid per-instruction string formatting.
// We stream binary records in large chunks.
// Record format (18 bytes):
//  pc:u16, b0:u8,b1:u8,b2:u8,b3:u8, a:u8,b:u8, x:u16,y:u16,u:u16,s:u16, dp:u8, cc:u8
var FULL_TRACE_BUF = null; // Uint8Array
var FULL_TRACE_BUF_OFF = 0;
var FULL_TRACE_DROPPED = false;
var FULL_TRACE_FILE_PATH = null;
var FULL_TRACE_FLUSH_IN_PROGRESS = false;
var FULL_TRACE_TOTAL_BYTES = 0;

function isFullTraceEnabled() {
    try {
        if (typeof window !== 'undefined' && window.OPCODE_TRACE_FULL != null) {
            return !!window.OPCODE_TRACE_FULL;
        }
    } catch (e) {}
    return false;
}

function getFullTraceMaxTotalBytes() {
    // Hard safety cap to avoid infinite disk usage.
    try {
        if (typeof window !== 'undefined' && window.OPCODE_TRACE_FULL_MAX_TOTAL_BYTES != null) {
            var n = Number(window.OPCODE_TRACE_FULL_MAX_TOTAL_BYTES);
            if (Number.isFinite(n)) {
                n = Math.floor(n);
                if (n < 1024 * 1024) n = 1024 * 1024;
                if (n > 5 * 1024 * 1024 * 1024) n = 5 * 1024 * 1024 * 1024;
                return n;
            }
        }
    } catch (e) {}
    return 1024 * 1024 * 1024; // 1GB default max
}

function getFullTraceChunkSize() {
    // Buffer size in memory before flushing. Larger = fewer IPC calls.
    try {
        if (typeof window !== 'undefined' && window.OPCODE_TRACE_FULL_CHUNK_BYTES != null) {
            var n = Number(window.OPCODE_TRACE_FULL_CHUNK_BYTES);
            if (Number.isFinite(n)) {
                n = Math.floor(n);
                if (n < 256 * 1024) n = 256 * 1024;
                if (n > 16 * 1024 * 1024) n = 16 * 1024 * 1024;
                return n;
            }
        }
    } catch (e) {}
    return 4 * 1024 * 1024; // 4MB
}

function setFullTraceFilePathFromRom() {
    FULL_TRACE_FILE_PATH = null;
    if (CURRENT_ROM_PATH && typeof CURRENT_ROM_PATH === 'string') {
        FULL_TRACE_FILE_PATH = CURRENT_ROM_PATH.replace(/\.(bin|BIN)$/, '.tracebin');
    }
}

function clearFullTrace() {
    FULL_TRACE_BUF = null;
    FULL_TRACE_BUF_OFF = 0;
    FULL_TRACE_DROPPED = false;
    FULL_TRACE_TOTAL_BYTES = 0;
    setFullTraceFilePathFromRom();
}

function ensureFullTraceBuf() {
    if (!FULL_TRACE_BUF) {
        FULL_TRACE_BUF = new Uint8Array(getFullTraceChunkSize());
        FULL_TRACE_BUF_OFF = 0;
    }
}

function enqueueFullTraceRecord(pc, b0, b1, b2, b3, a, b, x, y, u, s, dp, cc) {
    if (!isFullTraceEnabled()) return;
    if (FULL_TRACE_DROPPED) return;
    if (!FULL_TRACE_FILE_PATH) setFullTraceFilePathFromRom();
    if (!FULL_TRACE_FILE_PATH) return;

    var maxTotal = getFullTraceMaxTotalBytes();
    if (FULL_TRACE_TOTAL_BYTES + 18 > maxTotal) {
        FULL_TRACE_DROPPED = true;
        return;
    }

    ensureFullTraceBuf();
    if (FULL_TRACE_BUF.length - FULL_TRACE_BUF_OFF < 18) {
        // Buffer full; request flush (best effort) and drop if can't keep up.
        // We do not flush synchronously here to avoid stalling the emulation thread.
        try { if (typeof window !== 'undefined' && window.__flushFullTraceNow) window.__flushFullTraceNow(); } catch (e) {}
        // Allocate a new buffer; old one will be flushed on next tick.
        FULL_TRACE_BUF = new Uint8Array(getFullTraceChunkSize());
        FULL_TRACE_BUF_OFF = 0;
    }

    var o = FULL_TRACE_BUF_OFF;
    FULL_TRACE_BUF[o+0] = (pc >> 8) & 0xff;
    FULL_TRACE_BUF[o+1] = pc & 0xff;
    FULL_TRACE_BUF[o+2] = b0 & 0xff;
    FULL_TRACE_BUF[o+3] = b1 & 0xff;
    FULL_TRACE_BUF[o+4] = b2 & 0xff;
    FULL_TRACE_BUF[o+5] = b3 & 0xff;
    FULL_TRACE_BUF[o+6] = a & 0xff;
    FULL_TRACE_BUF[o+7] = b & 0xff;
    FULL_TRACE_BUF[o+8] = (x >> 8) & 0xff;
    FULL_TRACE_BUF[o+9] = x & 0xff;
    FULL_TRACE_BUF[o+10] = (y >> 8) & 0xff;
    FULL_TRACE_BUF[o+11] = y & 0xff;
    FULL_TRACE_BUF[o+12] = (u >> 8) & 0xff;
    FULL_TRACE_BUF[o+13] = u & 0xff;
    FULL_TRACE_BUF[o+14] = (s >> 8) & 0xff;
    FULL_TRACE_BUF[o+15] = s & 0xff;
    FULL_TRACE_BUF[o+16] = dp & 0xff;
    FULL_TRACE_BUF[o+17] = cc & 0xff;

    FULL_TRACE_BUF_OFF += 18;
    FULL_TRACE_TOTAL_BYTES += 18;
}

async function flushFullTraceQueue() {
    if (!isFullTraceEnabled()) return;
    if (FULL_TRACE_FLUSH_IN_PROGRESS) return;
    if (!FULL_TRACE_FILE_PATH) setFullTraceFilePathFromRom();
    if (!FULL_TRACE_FILE_PATH) return;
    if (!FULL_TRACE_BUF || FULL_TRACE_BUF_OFF === 0) return;

    try {
        if (typeof window === 'undefined') return;
        const w = window;
        if (!w.files || typeof w.files.appendFileBin !== 'function') return;

        FULL_TRACE_FLUSH_IN_PROGRESS = true;

        // Flush current buffer as binary chunk
        var chunk = FULL_TRACE_BUF.subarray(0, FULL_TRACE_BUF_OFF);
        FULL_TRACE_BUF_OFF = 0;
        await w.files.appendFileBin({ path: FULL_TRACE_FILE_PATH, data: chunk });
    } catch (e) {
        // If append fails, stop growing memory indefinitely
        FULL_TRACE_DROPPED = true;
    } finally {
        FULL_TRACE_FLUSH_IN_PROGRESS = false;
    }
}

function getOpcodeTraceMax() {
    try {
        if (typeof window !== 'undefined' && window.OPCODE_TRACE_MAX != null) {
            var n = Number(window.OPCODE_TRACE_MAX);
            if (Number.isFinite(n)) {
                n = Math.floor(n);
                if (n < 10) n = 10;
                if (n > 100000) n = 100000;  // Allow up to 100k instructions in circular buffer
                return n;
            }
        }
    } catch (e) {}
    return OPCODE_TRACE_MAX;
}

function addOpcodeTrace(pc, opcode, regs, bytes) {
    // Honor runtime toggle via window.OPCODE_TRACE_ENABLED so a paused session
    // can enable tracing without rebuilding. Default OFF for perf.
    if (typeof window !== 'undefined' && typeof window.OPCODE_TRACE_ENABLED !== 'undefined') {
        if (!window.OPCODE_TRACE_ENABLED) return;
    } else if (!OPCODE_TRACE_ENABLED) {
        return;
    }

    const bank = (this && this.vecx && typeof this.vecx.currentBank === 'number')
        ? this.vecx.currentBank
        : 0;

    OPCODE_TRACE_BUFFER.push({
        pc: pc,
        opcode: opcode,
        bytes: bytes || [],
        a: regs.a,
        b: regs.b,
        x: regs.x,
        y: regs.y,
        u: regs.u,
        s: regs.s,
        dp: regs.dp,
        cc: regs.cc,
        bank: bank
    });
    
    // Keep only last N
    var maxEntries = getOpcodeTraceMax();
    while (OPCODE_TRACE_BUFFER.length > maxEntries) {
        OPCODE_TRACE_BUFFER.shift();
    }
}

function clearOpcodeTrace() {
    OPCODE_TRACE_BUFFER = [];
    TRACE_DUMPED = false;
    TRACE_DUMP_IN_PROGRESS = false;
    ERROR_HALT = false;
    clearFullTrace();
}

function dumpStackSnapshot(cpu) {
    try {
        const start = cpu.reg_s.value & 0xffff;
        const lines = [];
        const bytesPerLine = 16;
        const totalBytes = 64; // Dump 64 bytes from stack (grows downward, so show upward addresses)
        let out = "=== STACK SNAPSHOT (from S=" + start.toString(16).toUpperCase().padStart(4, '0') + ") ===\n";
        for (let offset = 0; offset < totalBytes; offset += bytesPerLine) {
            const addr = (start + offset) & 0xffff;
            let line = addr.toString(16).toUpperCase().padStart(4, '0') + ": ";
            for (let i = 0; i < bytesPerLine; i++) {
                const b = cpu.vecx.read8((addr + i) & 0xffff) & 0xff;
                line += b.toString(16).toUpperCase().padStart(2, '0') + " ";
            }
            lines.push(line.trimEnd());
        }

        out += lines.join("\n") + "\n";

        // Interpret as big-endian words for quick return-address hints
        out += "\n=== STACK WORDS (big-endian) ===\n";
        let words = [];
        for (let offset = 0; offset < totalBytes; offset += 2) {
            const addr = (start + offset) & 0xffff;
            const hi = cpu.vecx.read8(addr) & 0xff;
            const lo = cpu.vecx.read8((addr + 1) & 0xffff) & 0xff;
            words.push(hi.toString(16).toUpperCase().padStart(2, '0') + lo.toString(16).toUpperCase().padStart(2, '0'));
        }
        out += words.map((w, idx) => "".concat((start + idx * 2).toString(16).toUpperCase().padStart(4, '0'), " ", w)).join("\n") + "\n";

        return out;
    } catch (e) {
        return "(stack snapshot unavailable: " + e + ")\n";
    }
}

function dumpOpcodeTrace(errorMsg, extra) {
    // Always print, even if already dumped (helps with debugging)
    // if (TRACE_DUMPED || TRACE_DUMP_IN_PROGRESS) return;
    TRACE_DUMP_IN_PROGRESS = true;
    if (OPCODE_TRACE_BUFFER.length === 0) {
        TRACE_DUMPED = true;
        TRACE_DUMP_IN_PROGRESS = false;
        console.log("=== NO TRACE AVAILABLE (buffer empty) ===");
        return "(no trace)";
    }
    
    var maxEntries = getOpcodeTraceMax();
    let output = "=== OPCODE EXECUTION TRACE (Last " + OPCODE_TRACE_BUFFER.length + " instructions, max " + maxEntries + ") ===\n";
    output += "Error: " + errorMsg + "\n\n";
    output += "PC     BANK BYTES           A  B  X    Y    U    S    DP CC\n";
    output += "====== ==== =============== == == ==== ==== ==== ==== == ==\n";
    
    for (let i = 0; i < OPCODE_TRACE_BUFFER.length; i++) {
        const t = OPCODE_TRACE_BUFFER[i];
        output += t.pc.toString(16).toUpperCase().padStart(4, '0') + "   ";
        output += (t.bank ?? 0).toString(16).toUpperCase().padStart(4, '0') + " ";
        const bytesStr = (t.bytes && t.bytes.length)
            ? t.bytes.map(b => b.toString(16).toUpperCase().padStart(2, '0')).join(' ')
            : t.opcode.toString(16).toUpperCase().padStart(2, '0');
        output += bytesStr.padEnd(15, ' ') + " ";
        output += t.a.toString(16).toUpperCase().padStart(2, '0') + " ";
        output += t.b.toString(16).toUpperCase().padStart(2, '0') + " ";
        output += t.x.toString(16).toUpperCase().padStart(4, '0') + " ";
        output += t.y.toString(16).toUpperCase().padStart(4, '0') + " ";
        output += t.u.toString(16).toUpperCase().padStart(4, '0') + " ";
        output += t.s.toString(16).toUpperCase().padStart(4, '0') + " ";
        output += t.dp.toString(16).toUpperCase().padStart(2, '0') + " ";
        output += t.cc.toString(16).toUpperCase().padStart(2, '0');
        
        if (i === OPCODE_TRACE_BUFFER.length - 1) {
            output += " <-- ERROR HERE";
        }
        output += "\n";
    }

    if (extra) {
        output += "\n" + extra + "\n";
    }
    
    // Save to disk (Electron) if possible, otherwise fallback to browser download.
    // Loud logging at every step so we know exactly why a save might not happen —
    // this dance is critical when the in-console trace gets truncated and we need
    // the file on disk to grep for bank transitions.
    try {
        if (typeof window !== 'undefined') {
            const w = window;
            const romPath = (typeof CURRENT_ROM_PATH !== 'undefined' && CURRENT_ROM_PATH)
                || (w.CURRENT_ROM_PATH || null);
            const romName = (typeof CURRENT_ROM_NAME !== 'undefined' && CURRENT_ROM_NAME)
                || (w.CURRENT_ROM_NAME || null);
            console.log('[trace-save] CURRENT_ROM_PATH=' + romPath + ' CURRENT_ROM_NAME=' + romName + ' hasFilesAPI=' + (!!(w.files && typeof w.files.saveFile === 'function')));
            const stackPath = (romPath && typeof romPath === 'string')
                ? romPath.replace(/\.(bin|BIN)$/, '.stack')
                : null;

            if (stackPath && w.files && typeof w.files.saveFile === 'function') {
                console.log('[trace-save] writing ' + output.length + ' bytes to ' + stackPath);
                w.files.saveFile({ path: stackPath, content: output })
                    .then((r) => console.log("📝 Stack trace saved to: " + stackPath + " (response: " + JSON.stringify(r) + ")"))
                    .catch((e) => console.warn("Failed to save .stack via Electron files API:", e));
            } else if (romName) {
                const fileName = romName.replace(/\.(bin|BIN)$/, '.stack');
                console.log('[trace-save] no files API or path — falling back to browser download as ' + fileName);
                const blob = new Blob([output], { type: 'text/plain' });
                const url = URL.createObjectURL(blob);
                const a = document.createElement('a');
                a.href = url;
                a.download = fileName;
                a.click();
                URL.revokeObjectURL(url);
                console.log("📝 Stack trace downloaded: " + fileName);
            } else {
                console.warn('[trace-save] cannot save: CURRENT_ROM_PATH and CURRENT_ROM_NAME both null. EmulatorPanel must set window.CURRENT_ROM_PATH after compile/load.');
            }
        }
    } catch (e) {
        console.warn("Failed to persist .stack:", e);
    }

    TRACE_DUMPED = true;
    TRACE_DUMP_IN_PROGRESS = false;
    
    return output;
}

// Expose to window for debugging panel
if (typeof window !== 'undefined') {
    window.MUSIC_CALL_LOG = MUSIC_CALL_LOG;
    window.MUSIC_CALL_LOG_ENABLED = MUSIC_CALL_LOG_ENABLED;
    window.MUSIC_CALL_LOG_LIMIT = MUSIC_CALL_LOG_LIMIT;
    window.MUSIC_FUNCTION_ADDRS = MUSIC_FUNCTION_ADDRS;
    window.OPCODE_TRACE_BUFFER = OPCODE_TRACE_BUFFER;
    window.clearOpcodeTrace = clearOpcodeTrace;
    window.dumpOpcodeTrace = dumpOpcodeTrace;
    window.CURRENT_ROM_NAME = null;
    window.CURRENT_ROM_PATH = null;
    window.OPCODE_TRACE_FULL = window.OPCODE_TRACE_FULL ?? false;
    window.OPCODE_TRACE_FULL_CHUNK_BYTES = window.OPCODE_TRACE_FULL_CHUNK_BYTES ?? (4 * 1024 * 1024);
    window.OPCODE_TRACE_FULL_MAX_TOTAL_BYTES = window.OPCODE_TRACE_FULL_MAX_TOTAL_BYTES ?? (1024 * 1024 * 1024);
    window.STACK_SAVE_PROMPT = window.STACK_SAVE_PROMPT ?? false;
}

// Background flusher for full trace streaming
if (typeof window !== 'undefined') {
    try {
        if (!window.__fullTraceFlushTimer) {
            window.__fullTraceFlushTimer = setInterval(() => {
                flushFullTraceQueue();
            }, 250);
        }
        window.__flushFullTraceNow = () => flushFullTraceQueue();
    } catch (e) {}
}

function e6809()
{
    this.vecx = null;
    this.FLAG_E = 0x80;
    this.FLAG_F = 0x40;
    this.FLAG_H = 0x20;
    this.FLAG_I = 0x10;
    this.FLAG_N = 0x08;
    this.FLAG_Z = 0x04;
    this.FLAG_V = 0x02;
    this.FLAG_C = 0x01;
    this.IRQ_NORMAL = 0;
    this.IRQ_SYNC = 1;
    this.IRQ_CWAI = 2;
    this.reg_x = new fptr(0);
    this.reg_y = new fptr(0);
    this.reg_u = new fptr(0);
    this.reg_s = new fptr(0);
    this.reg_pc = 0;
    this.reg_a = 0;
    this.reg_b = 0;
    this.reg_dp = 0;
    this.reg_cc = 0;
    this.irq_status = 0;
    this.rptr_xyus = [ this.reg_x, this.reg_y, this.reg_u, this.reg_s ];
    this.test_c = function( i0, i1, r, sub )
    {
        var flag = (i0 | i1) & ~r;
        flag |= (i0 & i1);
        flag = (flag >> 7) & 1;
        flag ^= sub;
        return flag;
    }
    this.test_z8 = function( r )
    {
        var flag = ~r;
        flag = (flag >> 4) & (flag & 0xf);
        flag = (flag >> 2) & (flag & 0x3);
        flag = (flag >> 1) & (flag & 0x1);
        return flag;
    }
    this.test_z16 = function( r )
    {
        var flag = ~r;
        flag = (flag >> 8) & (flag & 0xff);
        flag = (flag >> 4) & (flag & 0xf);
        flag = (flag >> 2) & (flag & 0x3);
        flag = (flag >> 1) & (flag & 0x1);
        return flag;
    }
    this.test_v = function( i0, i1, r )
    {
        var flag = ~(i0 ^ i1);
        flag &= (i0 ^ r);
        flag = (flag >> 7) & 1;
        return flag;
    }
    this.set_reg_d = function( value )
    {
        this.reg_a = (value >> 8);
        this.reg_b = value;
    }
    this.read16 = function( address )
    {
        var datahi = this.vecx.read8(address);
        var datalo = this.vecx.read8(address + 1);
        return (datahi << 8) | datalo;
    }
    this.write16 = function( address, data )
    {
        this.vecx.write8(address, data >> 8);
        this.vecx.write8(address + 1, data);
    }
    this.push8 = function( sp, data )
    {
        sp.value--;
        this.vecx.write8(sp.value, data);
    }
    this.push16 = function( sp, data )
    {
        sp.value--;
        this.vecx.write8(sp.value, data);
        sp.value--;
        this.vecx.write8(sp.value, data >> 8 );
    }
    this.pull16 = function( sp )
    {
        var datahi = this.vecx.read8(sp.value++);
        var datalo = this.vecx.read8(sp.value++);
        return (datahi << 8) | datalo;
    }
    this.pc_read16 = function()
    {
        var data = this.read16(this.reg_pc);
        this.reg_pc += 2;
        return data;
    }
    this.sign_extend = function( data )
    {
        return (~(data & 0x80) + 1) | (data & 0xff);
    }
    this.ea_indexed = function( cycles )
    {
        var ea = 0;
        var op = 0;
        var r = 0;
        op = this.vecx.read8(this.reg_pc++);
        r = (op >> 5) & 3;
        switch( op )
        {
            case 0x00: case 0x01: case 0x02: case 0x03:
            case 0x04: case 0x05: case 0x06: case 0x07:
            case 0x08: case 0x09: case 0x0a: case 0x0b:
            case 0x0c: case 0x0d: case 0x0e: case 0x0f:
            case 0x20: case 0x21: case 0x22: case 0x23:
            case 0x24: case 0x25: case 0x26: case 0x27:
            case 0x28: case 0x29: case 0x2a: case 0x2b:
            case 0x2c: case 0x2d: case 0x2e: case 0x2f:
            case 0x40: case 0x41: case 0x42: case 0x43:
            case 0x44: case 0x45: case 0x46: case 0x47:
            case 0x48: case 0x49: case 0x4a: case 0x4b:
            case 0x4c: case 0x4d: case 0x4e: case 0x4f:
            case 0x60: case 0x61: case 0x62: case 0x63:
            case 0x64: case 0x65: case 0x66: case 0x67:
            case 0x68: case 0x69: case 0x6a: case 0x6b:
            case 0x6c: case 0x6d: case 0x6e: case 0x6f:
                ea = this.rptr_xyus[r].value + (op & 0xf);
                cycles.value++;
                break;
            case 0x10: case 0x11: case 0x12: case 0x13:
            case 0x14: case 0x15: case 0x16: case 0x17:
            case 0x18: case 0x19: case 0x1a: case 0x1b:
            case 0x1c: case 0x1d: case 0x1e: case 0x1f:
            case 0x30: case 0x31: case 0x32: case 0x33:
            case 0x34: case 0x35: case 0x36: case 0x37:
            case 0x38: case 0x39: case 0x3a: case 0x3b:
            case 0x3c: case 0x3d: case 0x3e: case 0x3f:
            case 0x50: case 0x51: case 0x52: case 0x53:
            case 0x54: case 0x55: case 0x56: case 0x57:
            case 0x58: case 0x59: case 0x5a: case 0x5b:
            case 0x5c: case 0x5d: case 0x5e: case 0x5f:
            case 0x70: case 0x71: case 0x72: case 0x73:
            case 0x74: case 0x75: case 0x76: case 0x77:
            case 0x78: case 0x79: case 0x7a: case 0x7b:
            case 0x7c: case 0x7d: case 0x7e: case 0x7f:
                ea = this.rptr_xyus[r].value + (op & 0xf) - 0x10;
                cycles.value++;
                break;
            case 0x80: case 0x81:
            case 0xa0: case 0xa1:
            case 0xc0: case 0xc1:
            case 0xe0: case 0xe1:
                ea = this.rptr_xyus[r].value;
                this.rptr_xyus[r].value+=(1 + (op & 1));
                cycles.value+=(2 + (op & 1));
                break;
            case 0x90: case 0x91:
            case 0xb0: case 0xb1:
            case 0xd0: case 0xd1:
            case 0xf0: case 0xf1:
                ea = this.read16(this.rptr_xyus[r].value);
                this.rptr_xyus[r].value+=(1 + (op & 1));
                cycles.value+=(5 + (op & 1));
                break;
            case 0x82: case 0x83:
            case 0xa2: case 0xa3:
            case 0xc2: case 0xc3:
            case 0xe2: case 0xe3:
                this.rptr_xyus[r].value-=(1 + (op & 1));
                ea = this.rptr_xyus[r].value;
                cycles.value+=(2 + (op & 1));
                break;
            case 0x92: case 0x93:
            case 0xb2: case 0xb3:
            case 0xd2: case 0xd3:
            case 0xf2: case 0xf3:
                this.rptr_xyus[r].value-=(1 + (op & 1));
                ea = this.read16(this.rptr_xyus[r].value);
                cycles.value+=(5 + (op & 1));
                break;
            case 0x84: case 0xa4:
            case 0xc4: case 0xe4:
                ea = this.rptr_xyus[r].value;
                break;
            case 0x94: case 0xb4:
            case 0xd4: case 0xf4:
                ea = this.read16(this.rptr_xyus[r].value);
                cycles.value+=(3);
                break;
            case 0x85: case 0xa5:
            case 0xc5: case 0xe5:
                ea = this.rptr_xyus[r].value + this.sign_extend(this.reg_b);
                cycles.value+=(1);
                break;
            case 0x95: case 0xb5:
            case 0xd5: case 0xf5:
                ea = this.read16(this.rptr_xyus[r].value + this.sign_extend(this.reg_b));
                cycles.value+=(4);
                break;
            case 0x86: case 0xa6:
            case 0xc6: case 0xe6:
                ea = this.rptr_xyus[r].value + this.sign_extend(this.reg_a);
                cycles.value+=(1);
                break;
            case 0x96: case 0xb6:
            case 0xd6: case 0xf6:
                ea = this.read16(this.rptr_xyus[r].value + this.sign_extend(this.reg_a));
                cycles.value+=(4);
            break;
            case 0x88: case 0xa8:
            case 0xc8: case 0xe8:
                ea = this.rptr_xyus[r].value + this.sign_extend(this.vecx.read8(this.reg_pc++));
                cycles.value+=(1);
                break;
            case 0x98: case 0xb8:
            case 0xd8: case 0xf8:
                ea = this.read16(this.rptr_xyus[r].value + this.sign_extend(this.vecx.read8(this.reg_pc++)));
                cycles.value+=(4);
                break;
            case 0x89: case 0xa9:
            case 0xc9: case 0xe9:
                ea = this.rptr_xyus[r].value + this.pc_read16();
                cycles.value+=(4);
                break;
            case 0x99: case 0xb9:
            case 0xd9: case 0xf9:
                ea = this.read16(this.rptr_xyus[r].value + this.pc_read16());
                cycles.value+=(7);
                break;
            case 0x8b: case 0xab:
            case 0xcb: case 0xeb:
                ea = this.rptr_xyus[r].value +  ((this.reg_a<<8)|(this.reg_b&0xff)) ;
                cycles.value+=(4);
                break;
            case 0x9b: case 0xbb:
            case 0xdb: case 0xfb:
                ea = this.read16(this.rptr_xyus[r].value +  ((this.reg_a<<8)|(this.reg_b&0xff)) );
                cycles.value+=(7);
                break;
            case 0x8c: case 0xac:
            case 0xcc: case 0xec:
                r = this.sign_extend(this.vecx.read8(this.reg_pc++));
                ea = this.reg_pc + r;
                cycles.value+=(1);
                break;
            case 0x9c: case 0xbc:
            case 0xdc: case 0xfc:
                r = this.sign_extend(this.vecx.read8(this.reg_pc++));
                ea = this.read16(this.reg_pc + r);
                cycles.value+=(4);
                break;
            case 0x8d: case 0xad:
            case 0xcd: case 0xed:
                r = this.pc_read16();
                ea = this.reg_pc + r;
                cycles.value+=(5);
                break;
            case 0x9d: case 0xbd:
            case 0xdd: case 0xfd:
                r = this.pc_read16();
                ea = this.read16(this.reg_pc + r);
                cycles.value+=(8);
                break;
            case 0x9f:
                ea = this.read16(this.pc_read16());
                cycles.value+=(5);
                break;
            default:
                const postByteError = "Undefined post-byte: 0x" + pb.toString(16).toUpperCase().padStart(2, '0') + " at PC=0x" + this.reg_pc.toString(16).toUpperCase().padStart(4, '0');
                console.log("⚠️ UNDEFINED POST-BYTE ERROR:");
                console.log("  PC: 0x" + this.reg_pc.toString(16).toUpperCase().padStart(4, '0'));
                console.log("  Post-byte: 0x" + pb.toString(16).toUpperCase().padStart(2, '0') + " (" + pb + ")");
                console.log("  Registers:");
                console.log("    A: 0x" + this.reg_a.toString(16).toUpperCase().padStart(2, '0'));
                console.log("    B: 0x" + this.reg_b.toString(16).toUpperCase().padStart(2, '0'));
                console.log("    X: 0x" + this.reg_x.value.toString(16).toUpperCase().padStart(4, '0'));
                console.log("    Y: 0x" + this.reg_y.value.toString(16).toUpperCase().padStart(4, '0'));
                console.log("    U: 0x" + this.reg_u.value.toString(16).toUpperCase().padStart(4, '0'));
                console.log("    S: 0x" + this.reg_s.value.toString(16).toUpperCase().padStart(4, '0'));
                console.log("    DP: 0x" + (this.reg_dp & 0xFF).toString(16).toUpperCase().padStart(2, '0'));
                console.log("    CC: 0x" + this.reg_cc.toString(16).toUpperCase().padStart(2, '0'));
                
                // Dump trace to file
                const traceOutput = dumpOpcodeTrace(postByteError);
                console.log("\n" + traceOutput);

                // Stop emulator to avoid infinite error loops
                try {
                    if (this.vecx) {
                        if (typeof this.vecx.debugStop === 'function') this.vecx.debugStop();
                        else if (typeof this.vecx.stop === 'function') this.vecx.stop();
                    }
                } catch (e) {}

                utils.showError(postByteError);
                
                break;
        }
        return ea;
    }
    this.inst_neg = function( data )
    {
        var i0 = 0;
        var i1 = (~data) & 0xffff;
        var r = i0 + i1 + 1;
        this.reg_cc=((this.reg_cc&~this.FLAG_H)|(this.test_c(i0 << 4, i1 << 4, r << 4, 0)*this.FLAG_H)) ;
        this.reg_cc=((this.reg_cc&~this.FLAG_N)|( ((r>>7)&1) *this.FLAG_N)) ;
        this.reg_cc=((this.reg_cc&~this.FLAG_Z)|(this.test_z8(r)*this.FLAG_Z)) ;
        this.reg_cc=((this.reg_cc&~this.FLAG_V)|( ((((~(i0^i1))&(i0^r))>>7)&1) *this.FLAG_V)) ;
        this.reg_cc=((this.reg_cc&~this.FLAG_C)|(this.test_c(i0, i1, r, 1)*this.FLAG_C)) ;
        return r;
    }
    this.inst_com = function( data )
    {
        var r = (~data) & 0xffff;
        this.reg_cc=((this.reg_cc&~this.FLAG_N)|( ((r>>7)&1) *this.FLAG_N)) ;
        this.reg_cc=((this.reg_cc&~this.FLAG_Z)|(this.test_z8(r)*this.FLAG_Z)) ;
        this.reg_cc=((this.reg_cc&~this.FLAG_V)|(0*this.FLAG_V)) ;
        this.reg_cc=((this.reg_cc&~this.FLAG_C)|(1*this.FLAG_C)) ;
        return r;
    }
    this.inst_lsr = function( data )
    {
        var r = (data >> 1) & 0x7f;
        this.reg_cc=((this.reg_cc&~this.FLAG_N)|(0*this.FLAG_N)) ;
        this.reg_cc=((this.reg_cc&~this.FLAG_Z)|(this.test_z8(r)*this.FLAG_Z)) ;
        this.reg_cc=((this.reg_cc&~this.FLAG_C)|(data & 1*this.FLAG_C)) ;
        return r;
    }
    this.inst_ror = function( data )
    {
        var c =  ((this.reg_cc/this.FLAG_C>>0)&1) ;
        var r = ((data >> 1) & 0x7f) | (c << 7);
        this.reg_cc=((this.reg_cc&~this.FLAG_N)|( ((r>>7)&1) *this.FLAG_N)) ;
        this.reg_cc=((this.reg_cc&~this.FLAG_Z)|(this.test_z8(r)*this.FLAG_Z)) ;
        this.reg_cc=((this.reg_cc&~this.FLAG_C)|(data & 1*this.FLAG_C)) ;
        return r;
    }
    this.inst_asr = function( data )
    {
        var r = ((data >> 1) & 0x7f) | (data & 0x80);
        this.reg_cc=((this.reg_cc&~this.FLAG_N)|( ((r>>7)&1) *this.FLAG_N)) ;
        this.reg_cc=((this.reg_cc&~this.FLAG_Z)|(this.test_z8(r)*this.FLAG_Z)) ;
        this.reg_cc=((this.reg_cc&~this.FLAG_C)|(data & 1*this.FLAG_C)) ;
        return r;
    }
    this.inst_asl = function( data )
    {
        var i0 = data;
        var i1 = data;
        var r = i0 + i1;
        this.reg_cc=((this.reg_cc&~this.FLAG_H)|(this.test_c(i0 << 4, i1 << 4, r << 4, 0)*this.FLAG_H)) ;
        this.reg_cc=((this.reg_cc&~this.FLAG_N)|( ((r>>7)&1) *this.FLAG_N)) ;
        this.reg_cc=((this.reg_cc&~this.FLAG_Z)|(this.test_z8(r)*this.FLAG_Z)) ;
        this.reg_cc=((this.reg_cc&~this.FLAG_V)|( ((((~(i0^i1))&(i0^r))>>7)&1) *this.FLAG_V)) ;
        this.reg_cc=((this.reg_cc&~this.FLAG_C)|(this.test_c(i0, i1, r, 0)*this.FLAG_C)) ;
        return r;
    }
    this.inst_rol = function( data )
    {
        var i0 = data;
        var i1 = data;
        var c =  ((this.reg_cc/this.FLAG_C>>0)&1) ;
        var r = i0 + i1 + c;
        this.reg_cc=((this.reg_cc&~this.FLAG_N)|( ((r>>7)&1) *this.FLAG_N)) ;
        this.reg_cc=((this.reg_cc&~this.FLAG_Z)|(this.test_z8(r)*this.FLAG_Z)) ;
        this.reg_cc=((this.reg_cc&~this.FLAG_V)|( ((((~(i0^i1))&(i0^r))>>7)&1) *this.FLAG_V)) ;
        this.reg_cc=((this.reg_cc&~this.FLAG_C)|(this.test_c(i0, i1, r, 0)*this.FLAG_C)) ;
        return r;
    }
    this.inst_dec = function( data )
    {
        var i0 = data;
        var i1 = 0xff;
        var r = i0 + i1;
        this.reg_cc=((this.reg_cc&~this.FLAG_N)|( ((r>>7)&1) *this.FLAG_N)) ;
        this.reg_cc=((this.reg_cc&~this.FLAG_Z)|(this.test_z8(r)*this.FLAG_Z)) ;
        this.reg_cc=((this.reg_cc&~this.FLAG_V)|( ((((~(i0^i1))&(i0^r))>>7)&1) *this.FLAG_V)) ;
        return r;
    }
    this.inst_inc = function( data )
    {
        var i0 = data;
        var i1 = 1;
        var r = i0 + i1;
        this.reg_cc=((this.reg_cc&~this.FLAG_N)|( ((r>>7)&1) *this.FLAG_N)) ;
        this.reg_cc=((this.reg_cc&~this.FLAG_Z)|(this.test_z8(r)*this.FLAG_Z)) ;
        this.reg_cc=((this.reg_cc&~this.FLAG_V)|( ((((~(i0^i1))&(i0^r))>>7)&1) *this.FLAG_V)) ;
        return r;
    }
    this.inst_tst8 = function( data )
    {
        this.reg_cc=((this.reg_cc&~this.FLAG_N)|( ((data>>7)&1) *this.FLAG_N)) ;
        this.reg_cc=((this.reg_cc&~this.FLAG_Z)|(this.test_z8(data)*this.FLAG_Z)) ;
        this.reg_cc=((this.reg_cc&~this.FLAG_V)|(0*this.FLAG_V)) ;
    }
    this.inst_tst16 = function( data )
    {
        this.reg_cc=((this.reg_cc&~this.FLAG_N)|( ((data >> 8>>7)&1) *this.FLAG_N)) ;
        this.reg_cc=((this.reg_cc&~this.FLAG_Z)|(this.test_z16(data)*this.FLAG_Z)) ;
        this.reg_cc=((this.reg_cc&~this.FLAG_V)|(0*this.FLAG_V)) ;
    }
    this.inst_clr = function()
    {
        this.reg_cc=((this.reg_cc&~this.FLAG_N)|(0*this.FLAG_N)) ;
        this.reg_cc=((this.reg_cc&~this.FLAG_Z)|(1*this.FLAG_Z)) ;
        this.reg_cc=((this.reg_cc&~this.FLAG_V)|(0*this.FLAG_V)) ;
        this.reg_cc=((this.reg_cc&~this.FLAG_C)|(0*this.FLAG_C)) ;
    }
    this.inst_sub8 = function( data0, data1 )
    {
        var i0 = data0;
        var i1 = (~data1) & 0xffff;
        var r = i0 + i1 + 1;
        this.reg_cc=((this.reg_cc&~this.FLAG_H)|(this.test_c(i0 << 4, i1 << 4, r << 4, 0)*this.FLAG_H)) ;
        this.reg_cc=((this.reg_cc&~this.FLAG_N)|( ((r>>7)&1) *this.FLAG_N)) ;
        this.reg_cc=((this.reg_cc&~this.FLAG_Z)|(this.test_z8(r)*this.FLAG_Z)) ;
        this.reg_cc=((this.reg_cc&~this.FLAG_V)|( ((((~(i0^i1))&(i0^r))>>7)&1) *this.FLAG_V)) ;
        this.reg_cc=((this.reg_cc&~this.FLAG_C)|(this.test_c(i0, i1, r, 1)*this.FLAG_C)) ;
        return r;
    }
    this.inst_sbc = function( data0, data1 )
    {
        var i0 = data0;
        var i1 = (~data1) & 0xffff;
        var c = 1 -  ((this.reg_cc/this.FLAG_C>>0)&1) ;
        var r = i0 + i1 + c;
        this.reg_cc=((this.reg_cc&~this.FLAG_H)|(this.test_c(i0 << 4, i1 << 4, r << 4, 0)*this.FLAG_H)) ;
        this.reg_cc=((this.reg_cc&~this.FLAG_N)|( ((r>>7)&1) *this.FLAG_N)) ;
        this.reg_cc=((this.reg_cc&~this.FLAG_Z)|(this.test_z8(r)*this.FLAG_Z)) ;
        this.reg_cc=((this.reg_cc&~this.FLAG_V)|( ((((~(i0^i1))&(i0^r))>>7)&1) *this.FLAG_V)) ;
        this.reg_cc=((this.reg_cc&~this.FLAG_C)|(this.test_c(i0, i1, r, 1)*this.FLAG_C)) ;
        return r;
    }
    this.inst_and = function( data0, data1 )
    {
        var r = data0 & data1;
        this.inst_tst8(r);
        return r;
    }
    this.inst_eor = function ( data0, data1 )
    {
        var r = data0 ^ data1;
        this.inst_tst8(r);
        return r;
    }
    this.inst_adc = function ( data0, data1 )
    {
        var i0 = data0;
        var i1 = data1;
        var c =  ((this.reg_cc/this.FLAG_C>>0)&1) ;
        var r = i0 + i1 + c;
        this.reg_cc=((this.reg_cc&~this.FLAG_H)|(this.test_c(i0 << 4, i1 << 4, r << 4, 0)*this.FLAG_H)) ;
        this.reg_cc=((this.reg_cc&~this.FLAG_N)|( ((r>>7)&1) *this.FLAG_N)) ;
        this.reg_cc=((this.reg_cc&~this.FLAG_Z)|(this.test_z8(r)*this.FLAG_Z)) ;
        this.reg_cc=((this.reg_cc&~this.FLAG_V)|( ((((~(i0^i1))&(i0^r))>>7)&1) *this.FLAG_V)) ;
        this.reg_cc=((this.reg_cc&~this.FLAG_C)|(this.test_c(i0, i1, r, 0)*this.FLAG_C)) ;
        return r;
    }
    this.inst_or = function( data0, data1 )
    {
        var r = data0 | data1;
        this.inst_tst8(r);
        return r;
    }
    this.inst_add8 = function( data0, data1 )
    {
        var i0 = data0;
        var i1 = data1;
        var r = i0 + i1;
        this.reg_cc=((this.reg_cc&~this.FLAG_H)|(this.test_c(i0 << 4, i1 << 4, r << 4, 0)*this.FLAG_H)) ;
        this.reg_cc=((this.reg_cc&~this.FLAG_N)|( ((r>>7)&1) *this.FLAG_N)) ;
        this.reg_cc=((this.reg_cc&~this.FLAG_Z)|(this.test_z8(r)*this.FLAG_Z)) ;
        this.reg_cc=((this.reg_cc&~this.FLAG_V)|( ((((~(i0^i1))&(i0^r))>>7)&1) *this.FLAG_V)) ;
        this.reg_cc=((this.reg_cc&~this.FLAG_C)|(this.test_c(i0, i1, r, 0)*this.FLAG_C)) ;
        return r;
    }
    this.inst_add16 = function( data0, data1 )
    {
        var i0 = data0;
        var i1 = data1;
        var r = i0 + i1;
        this.reg_cc=((this.reg_cc&~this.FLAG_N)|( ((r >> 8>>7)&1) *this.FLAG_N)) ;
        this.reg_cc=((this.reg_cc&~this.FLAG_Z)|(this.test_z16(r)*this.FLAG_Z)) ;
        this.reg_cc=((this.reg_cc&~this.FLAG_V)|(this.test_v(i0 >> 8, i1 >> 8, r >> 8)*this.FLAG_V)) ;
        this.reg_cc=((this.reg_cc&~this.FLAG_C)|(this.test_c(i0 >> 8, i1 >> 8, r >> 8, 0)*this.FLAG_C)) ;
        return r;
    }
    this.inst_sub16 = function( data0, data1 )
    {
        var i0 = data0;
        var i1 = (~data1) & 0xffff;
        var r = i0 + i1 + 1;
        this.reg_cc=((this.reg_cc&~this.FLAG_N)|( ((r >> 8>>7)&1) *this.FLAG_N)) ;
        this.reg_cc=((this.reg_cc&~this.FLAG_Z)|(this.test_z16(r)*this.FLAG_Z)) ;
        this.reg_cc=((this.reg_cc&~this.FLAG_V)|(this.test_v(i0 >> 8, i1 >> 8, r >> 8)*this.FLAG_V)) ;
        this.reg_cc=((this.reg_cc&~this.FLAG_C)|(this.test_c(i0 >> 8, i1 >> 8, r >> 8, 1)*this.FLAG_C)) ;
        return r;
    }
    this.inst_bra8 = function ( test, op, cycles )
    {
        var offset = this.vecx.read8(this.reg_pc++);
        var mask = (test ^ (op & 1)) - 1;
        this.reg_pc += this.sign_extend(offset) & mask;
        cycles.value+=(3);
    }
    this.inst_bra16 = function( test, op, cycles )
    {
        var offset = this.pc_read16();
        var mask = (test ^ (op & 1)) - 1;
        this.reg_pc += offset & mask;
        cycles.value+=(5 - mask);
    }
    this.inst_psh = function ( op, sp, data, cycles )
    {
        if( op & 0x80 )
        {
            this.push16(sp, this.reg_pc);
            cycles.value+=(2);
        }
        if( op & 0x40 )
        {
            this.push16(sp, data);
            cycles.value+=(2);
        }
        if( op & 0x20 )
        {
            this.push16(sp, this.reg_y.value);
            cycles.value+=(2);
        }
        if( op & 0x10 )
        {
            this.push16(sp, this.reg_x.value);
            cycles.value+=(2);
        }
        if( op & 0x08 )
        {
            this.push8(sp, this.reg_dp);
            cycles.value+=(1);
        }
        if( op & 0x04 )
        {
            this.push8(sp, this.reg_b);
            cycles.value+=(1);
        }
        if( op & 0x02 )
        {
            this.push8(sp, this.reg_a);
            cycles.value+=(1);
        }
        if( op & 0x01 )
        {
            this.push8(sp, this.reg_cc);
            cycles.value+=(1);
        }
    }
    this.inst_pul = function( op, sp, osp, cycles )
    {
        if( op & 0x01 )
        {
            this.reg_cc =  (this.vecx.read8(sp.value++)) ;
            cycles.value+=(1);
        }
        if( op & 0x02 )
        {
            this.reg_a =  (this.vecx.read8(sp.value++)) ;
            cycles.value+=(1);
        }
        if( op & 0x04 )
        {
            this.reg_b =  (this.vecx.read8(sp.value++)) ;
            cycles.value+=(1);
        }
        if( op & 0x08 )
        {
            this.reg_dp =  (this.vecx.read8(sp.value++)) ;
            cycles.value+=(1);
        }
        if( op & 0x10 )
        {
            this.reg_x.value=(this.pull16(sp));
            cycles.value+=(2);
        }
        if( op & 0x20 )
        {
            this.reg_y.value=(this.pull16(sp));
            cycles.value+=(2);
        }
        if( op & 0x40 )
        {
            osp.value=(this.pull16(sp));
            cycles.value+=(2);
        }
        if( op & 0x80 )
        {
            this.reg_pc = this.pull16(sp);
            cycles.value+=(2);
        }
    }
    this.exgtfr_read = function( reg )
    {
        var data = 0;
        switch( reg )
        {
            case 0x0:
                data =  ((this.reg_a<<8)|(this.reg_b&0xff)) ;
                break;
            case 0x1:
                data = this.reg_x.value;
                break;
            case 0x2:
                data = this.reg_y.value;
                break;
            case 0x3:
                data = this.reg_u.value;
                break;
            case 0x4:
                data = this.reg_s.value;
                break;
            case 0x5:
                data = this.reg_pc;
                break;
            case 0x8:
                data = 0xff00 | this.reg_a;
                break;
            case 0x9:
                data = 0xff00 | this.reg_b;
                break;
            case 0xa:
                data = 0xff00 | this.reg_cc;
                break;
            case 0xb:
                data = 0xff00 | this.reg_dp;
                break;
            default:
                data = 0xffff;
                utils.showError("illegal exgtfr reg" + reg);
                break;
        }
        return data;
    }
    this.exgtfr_write = function( reg, data )
    {
        switch( reg )
        {
            case 0x0:
                this.set_reg_d(data);
                break;
            case 0x1:
                this.reg_x.value=(data);
                break;
            case 0x2:
                this.reg_y.value=(data);
                break;
            case 0x3:
                this.reg_u.value=(data);
                break;
            case 0x4:
                this.reg_s.value=(data);
                break;
            case 0x5:
                this.reg_pc = data;
                break;
            case 0x8:
                this.reg_a = data;
                break;
            case 0x9:
                this.reg_b = data;
                break;
            case 0xa:
                this.reg_cc = data;
                break;
            case 0xb:
                this.reg_dp = data;
                break;
            default:
                utils.showError("illegal exgtfr reg " + reg)
                break;
        }
    }
    this.inst_exg = function()
    {
        var op = this.vecx.read8(this.reg_pc++);
        var tmp = this.exgtfr_read(op & 0xf);
        this.exgtfr_write(op & 0xf, this.exgtfr_read(op >> 4));
        this.exgtfr_write(op >> 4, tmp);
    }
    this.inst_tfr = function()
    {
        var op = this.vecx.read8(this.reg_pc++);
        this.exgtfr_write(op & 0xf, this.exgtfr_read(op >> 4));
    }
    this.e6809_reset = function()
    {
        this.reg_x.value=(0);
        this.reg_y.value=(0);
        this.reg_u.value=(0);
        this.reg_s.value=(0);
        this.reg_a = 0;
        this.reg_b = 0;
        this.reg_dp = 0;
        this.reg_cc = this.FLAG_I | this.FLAG_F;
        this.irq_status = this.IRQ_NORMAL;
        this.reg_pc = this.read16(0xfffe);
        ERROR_HALT = false;
    }
    this.cycles = new fptr(0);
    this.e6809_sstep = function( irq_i, irq_f )
    {
        var op = 0;
        var cycles = this.cycles;
        if (ERROR_HALT) {
            cycles.value = 0;
            return cycles.value;
        }
        cycles.value=(0);
        var ea = 0;
        var i0 = 0;
        var i1 = 0;
        var r = 0;
        if( irq_f )
        {
            if(  ((this.reg_cc/this.FLAG_F>>0)&1)  == 0 )
            {
                if( this.irq_status != this.IRQ_CWAI )
                {
                    this.reg_cc=((this.reg_cc&~this.FLAG_E)|(0*this.FLAG_E)) ;
                    this.inst_psh(0x81, this.reg_s, this.reg_u.value, cycles);
                }
                this.reg_cc=((this.reg_cc&~this.FLAG_I)|(1*this.FLAG_I)) ;
                this.reg_cc=((this.reg_cc&~this.FLAG_F)|(1*this.FLAG_F)) ;
                this.reg_pc = this.read16(0xfff6);
                this.irq_status = this.IRQ_NORMAL;
                cycles.value+=(7);
            }
            else
            {
                if( this.irq_status == this.IRQ_SYNC )
                {
                    this.irq_status = this.IRQ_NORMAL;
                }
            }
        }
        if( irq_i )
        {
            if(  ((this.reg_cc/this.FLAG_I>>0)&1)  == 0 )
            {
                if( this.irq_status != this.IRQ_CWAI )
                {
                    this.reg_cc=((this.reg_cc&~this.FLAG_E)|(1*this.FLAG_E)) ;
                    this.inst_psh(0xff, this.reg_s, this.reg_u.value, cycles);
                }
                this.reg_cc=((this.reg_cc&~this.FLAG_I)|(1*this.FLAG_I)) ;
                this.reg_pc = this.read16(0xfff8);
                this.irq_status = this.IRQ_NORMAL;
                cycles.value+=(7);
            }
            else
            {
                if( this.irq_status == this.IRQ_SYNC )
                {
                    this.irq_status = this.IRQ_NORMAL;
                }
            }
        }
        if( this.irq_status != this.IRQ_NORMAL )
        {
            return cycles.value + 1;
        }
        op = this.vecx.read8(this.reg_pc++);
        var op_pc = (this.reg_pc - 1) & 0xffff;
        
        // Record opcode trace
        addOpcodeTrace(op_pc, op, {
            a: this.reg_a,
            b: this.reg_b,
            x: this.reg_x.value,
            y: this.reg_y.value,
            u: this.reg_u.value,
            s: this.reg_s.value,
            dp: this.reg_dp & 0xFF,
            cc: this.reg_cc
        }, [
            op & 0xff,
            this.vecx.read8((op_pc + 1) & 0xffff) & 0xff,
            this.vecx.read8((op_pc + 2) & 0xffff) & 0xff,
            this.vecx.read8((op_pc + 3) & 0xffff) & 0xff
        ]);

        // Full trace (binary streaming): one fixed-size record per instruction
        if (isFullTraceEnabled()) {
            var fb1 = this.vecx.read8((op_pc + 1) & 0xffff) & 0xff;
            var fb2 = this.vecx.read8((op_pc + 2) & 0xffff) & 0xff;
            var fb3 = this.vecx.read8((op_pc + 3) & 0xffff) & 0xff;
            enqueueFullTraceRecord(
                op_pc,
                op & 0xff, fb1, fb2, fb3,
                this.reg_a & 0xff,
                this.reg_b & 0xff,
                this.reg_x.value & 0xffff,
                this.reg_y.value & 0xffff,
                this.reg_u.value & 0xffff,
                this.reg_s.value & 0xffff,
                this.reg_dp & 0xff,
                this.reg_cc & 0xff
            );
        }
        
        switch( op )
        {
            case 0x00:
                ea =  ((this.reg_dp<<8)|this.vecx.read8(this.reg_pc++)) ;
                r = this.inst_neg(this.vecx.read8(ea));
                this.vecx.write8(ea, r);
                cycles.value+=(6);
                break;
            case 0x40:
                this.reg_a = this.inst_neg(this.reg_a);
                cycles.value+=(2);
                break;
            case 0x50:
                this.reg_b = this.inst_neg(this.reg_b);
                cycles.value+=(2);
                break;
            case 0x60:
                ea = this.ea_indexed(cycles);
                r = this.inst_neg(this.vecx.read8(ea));
                this.vecx.write8(ea, r);
                cycles.value+=(6);
                break;
            case 0x70:
                ea = this.pc_read16();
                r = this.inst_neg(this.vecx.read8(ea));
                this.vecx.write8(ea, r);
                cycles.value+=(7);
                break;
            case 0x03:
                ea =  ((this.reg_dp<<8)|this.vecx.read8(this.reg_pc++)) ;
                r = this.inst_com(this.vecx.read8(ea));
                this.vecx.write8(ea, r);
                cycles.value+=(6);
                break;
            case 0x43:
                this.reg_a = this.inst_com(this.reg_a);
                cycles.value+=(2);
                break;
            case 0x53:
                this.reg_b = this.inst_com(this.reg_b);
                cycles.value+=(2);
                break;
            case 0x63:
                ea = this.ea_indexed(cycles);
                r = this.inst_com(this.vecx.read8(ea));
                this.vecx.write8(ea, r);
                cycles.value+=(6);
                break;
            case 0x73:
                ea = this.pc_read16();
                r = this.inst_com(this.vecx.read8(ea));
                this.vecx.write8(ea, r);
                cycles.value+=(7);
                break;
            case 0x04:
                ea =  ((this.reg_dp<<8)|this.vecx.read8(this.reg_pc++)) ;
                r = this.inst_lsr(this.vecx.read8(ea));
                this.vecx.write8(ea, r);
                cycles.value+=(6);
                break;
            case 0x44:
                this.reg_a = this.inst_lsr(this.reg_a);
                cycles.value+=(2);
                break;
            case 0x54:
                this.reg_b = this.inst_lsr(this.reg_b);
                cycles.value+=(2);
                break;
            case 0x64:
                ea = this.ea_indexed(cycles);
                r = this.inst_lsr(this.vecx.read8(ea));
                this.vecx.write8(ea, r);
                cycles.value+=(6);
                break;
            case 0x74:
                ea = this.pc_read16();
                r = this.inst_lsr(this.vecx.read8(ea));
                this.vecx.write8(ea, r);
                cycles.value+=(7);
                break;
            case 0x06:
                ea =  ((this.reg_dp<<8)|this.vecx.read8(this.reg_pc++)) ;
                r = this.inst_ror(this.vecx.read8(ea));
                this.vecx.write8(ea, r);
                cycles.value+=(6);
                break;
            case 0x46:
                this.reg_a = this.inst_ror(this.reg_a);
                cycles.value+=(2);
                break;
            case 0x56:
                this.reg_b = this.inst_ror(this.reg_b);
                cycles.value+=(2);
                break;
            case 0x66:
                ea = this.ea_indexed(cycles);
                r = this.inst_ror(this.vecx.read8(ea));
                this.vecx.write8(ea, r);
                cycles.value+=(6);
                break;
            case 0x76:
                ea = this.pc_read16();
                r = this.inst_ror(this.vecx.read8(ea));
                this.vecx.write8(ea, r);
                cycles.value+=(7);
                break;
            case 0x07:
                ea =  ((this.reg_dp<<8)|this.vecx.read8(this.reg_pc++)) ;
                r = this.inst_asr(this.vecx.read8(ea));
                this.vecx.write8(ea, r);
                cycles.value+=(6);
                break;
            case 0x47:
                this.reg_a = this.inst_asr(this.reg_a);
                cycles.value+=(2);
                break;
            case 0x57:
                this.reg_b = this.inst_asr(this.reg_b);
                cycles.value+=(2);
                break;
            case 0x67:
                ea = this.ea_indexed(cycles);
                r = this.inst_asr(this.vecx.read8(ea));
                this.vecx.write8(ea, r);
                cycles.value+=(6);
                break;
            case 0x77:
                ea = this.pc_read16();
                r = this.inst_asr(this.vecx.read8(ea));
                this.vecx.write8(ea, r);
                cycles.value+=(7);
                break;
            case 0x08:
                ea =  ((this.reg_dp<<8)|this.vecx.read8(this.reg_pc++)) ;
                r = this.inst_asl(this.vecx.read8(ea));
                this.vecx.write8(ea, r);
                cycles.value+=(6);
                break;
            case 0x48:
                this.reg_a = this.inst_asl(this.reg_a);
                cycles.value+=(2);
                break;
            case 0x58:
                this.reg_b = this.inst_asl(this.reg_b);
                cycles.value+=(2);
                break;
            case 0x68:
                ea = this.ea_indexed(cycles);
                r = this.inst_asl(this.vecx.read8(ea));
                this.vecx.write8(ea, r);
                cycles.value+=(6);
                break;
            case 0x78:
                ea = this.pc_read16();
                r = this.inst_asl(this.vecx.read8(ea));
                this.vecx.write8(ea, r);
                cycles.value+=(7);
                break;
            case 0x09:
                ea =  ((this.reg_dp<<8)|this.vecx.read8(this.reg_pc++)) ;
                r = this.inst_rol(this.vecx.read8(ea));
                this.vecx.write8(ea, r);
                cycles.value+=(6);
                break;
            case 0x49:
                this.reg_a = this.inst_rol(this.reg_a);
                cycles.value+=(2);
                break;
            case 0x59:
                this.reg_b = this.inst_rol(this.reg_b);
                cycles.value+=(2);
                break;
            case 0x69:
                ea = this.ea_indexed(cycles);
                r = this.inst_rol(this.vecx.read8(ea));
                this.vecx.write8(ea, r);
                cycles.value+=(6);
                break;
            case 0x79:
                ea = this.pc_read16();
                r = this.inst_rol(this.vecx.read8(ea));
                this.vecx.write8(ea, r);
                cycles.value+=(7);
                break;
            case 0x0a:
                ea =  ((this.reg_dp<<8)|this.vecx.read8(this.reg_pc++)) ;
                r = this.inst_dec(this.vecx.read8(ea));
                this.vecx.write8(ea, r);
                cycles.value+=(6);
                break;
            case 0x4a:
                this.reg_a = this.inst_dec(this.reg_a);
                cycles.value+=(2);
                break;
            case 0x5a:
                this.reg_b = this.inst_dec(this.reg_b);
                cycles.value+=(2);
                break;
            case 0x6a:
                ea = this.ea_indexed(cycles);
                r = this.inst_dec(this.vecx.read8(ea));
                this.vecx.write8(ea, r);
                cycles.value+=(6);
                break;
            case 0x7a:
                ea = this.pc_read16();
                r = this.inst_dec(this.vecx.read8(ea));
                this.vecx.write8(ea, r);
                cycles.value+=(7);
                break;
            case 0x0c:
                ea =  ((this.reg_dp<<8)|this.vecx.read8(this.reg_pc++)) ;
                r = this.inst_inc(this.vecx.read8(ea));
                this.vecx.write8(ea, r);
                cycles.value+=(6);
                break;
            case 0x4c:
                this.reg_a = this.inst_inc(this.reg_a);
                cycles.value+=(2);
                break;
            case 0x5c:
                this.reg_b = this.inst_inc(this.reg_b);
                cycles.value+=(2);
                break;
            case 0x6c:
                ea = this.ea_indexed(cycles);
                r = this.inst_inc(this.vecx.read8(ea));
                this.vecx.write8(ea, r);
                cycles.value+=(6);
                break;
            case 0x7c:
                ea = this.pc_read16();
                r = this.inst_inc(this.vecx.read8(ea));
                this.vecx.write8(ea, r);
                cycles.value+=(7);
                break;
            case 0x0d:
                ea =  ((this.reg_dp<<8)|this.vecx.read8(this.reg_pc++)) ;
                this.inst_tst8(this.vecx.read8(ea));
                cycles.value+=(6);
                break;
            case 0x4d:
                this.inst_tst8(this.reg_a);
                cycles.value+=(2);
                break;
            case 0x5d:
                this.inst_tst8(this.reg_b);
                cycles.value+=(2);
                break;
            case 0x6d:
                ea = this.ea_indexed(cycles);
                this.inst_tst8(this.vecx.read8(ea));
                cycles.value+=(6);
                break;
            case 0x7d:
                ea = this.pc_read16();
                this.inst_tst8(this.vecx.read8(ea));
                cycles.value+=(7);
                break;
            case 0x0e:
                this.reg_pc =  ((this.reg_dp<<8)|this.vecx.read8(this.reg_pc++)) ;
                cycles.value+=(3);
                break;
            case 0x6e:
                this.reg_pc = this.ea_indexed(cycles);
                cycles.value+=(3);
                break;
            case 0x7e:
                this.reg_pc = this.pc_read16();
                cycles.value+=(4);
                break;
            case 0x0f:
                ea =  ((this.reg_dp<<8)|this.vecx.read8(this.reg_pc++)) ;
                this.inst_clr();
                this.vecx.write8(ea, 0);
                cycles.value+=(6);
                break;
            case 0x4f:
                this.inst_clr();
                this.reg_a = 0;
                cycles.value+=(2);
                break;
            case 0x5f:
                this.inst_clr();
                this.reg_b = 0;
                cycles.value+=(2);
                break;
            case 0x6f:
                ea = this.ea_indexed(cycles);
                this.inst_clr();
                this.vecx.write8(ea, 0);
                cycles.value+=(6);
                break;
            case 0x7f:
                ea = this.pc_read16();
                this.inst_clr();
                this.vecx.write8(ea, 0);
                cycles.value+=(7);
                break;
            case 0x80:
                this.reg_a = this.inst_sub8(this.reg_a, this.vecx.read8(this.reg_pc++));
                cycles.value+=(2);
                break;
            case 0x90:
                ea =  ((this.reg_dp<<8)|this.vecx.read8(this.reg_pc++)) ;
                this.reg_a = this.inst_sub8(this.reg_a, this.vecx.read8(ea));
                cycles.value+=(4);
                break;
            case 0xa0:
                ea = this.ea_indexed(cycles);
                this.reg_a = this.inst_sub8(this.reg_a, this.vecx.read8(ea));
                cycles.value+=(4);
                break;
            case 0xb0:
                ea = this.pc_read16();
                this.reg_a = this.inst_sub8(this.reg_a, this.vecx.read8(ea));
                cycles.value+=(5);
                break;
            case 0xc0:
                this.reg_b = this.inst_sub8(this.reg_b, this.vecx.read8(this.reg_pc++));
                cycles.value+=(2);
                break;
            case 0xd0:
                ea =  ((this.reg_dp<<8)|this.vecx.read8(this.reg_pc++)) ;
                this.reg_b = this.inst_sub8(this.reg_b, this.vecx.read8(ea));
                cycles.value+=(4);
                break;
            case 0xe0:
                ea = this.ea_indexed(cycles);
                this.reg_b = this.inst_sub8(this.reg_b, this.vecx.read8(ea));
                cycles.value+=(4);
                break;
            case 0xf0:
                ea = this.pc_read16();
                this.reg_b = this.inst_sub8(this.reg_b, this.vecx.read8(ea));
                cycles.value+=(5);
                break;
            case 0x81:
                this.inst_sub8(this.reg_a, this.vecx.read8(this.reg_pc++));
                cycles.value+=(2);
                break;
            case 0x91:
                ea =  ((this.reg_dp<<8)|this.vecx.read8(this.reg_pc++)) ;
                this.inst_sub8(this.reg_a, this.vecx.read8(ea));
                cycles.value+=(4);
                break;
            case 0xa1:
                ea = this.ea_indexed(cycles);
                this.inst_sub8(this.reg_a, this.vecx.read8(ea));
                cycles.value+=(4);
                break;
            case 0xb1:
                ea = this.pc_read16();
                this.inst_sub8(this.reg_a, this.vecx.read8(ea));
                cycles.value+=(5);
                break;
            case 0xc1:
                this.inst_sub8(this.reg_b, this.vecx.read8(this.reg_pc++));
                cycles.value+=(2);
                break;
            case 0xd1:
                ea =  ((this.reg_dp<<8)|this.vecx.read8(this.reg_pc++)) ;
                this.inst_sub8(this.reg_b, this.vecx.read8(ea));
                cycles.value+=(4);
                break;
            case 0xe1:
                ea = this.ea_indexed(cycles);
                this.inst_sub8(this.reg_b, this.vecx.read8(ea));
                cycles.value+=(4);
                break;
            case 0xf1:
                ea = this.pc_read16();
                this.inst_sub8(this.reg_b, this.vecx.read8(ea));
                cycles.value+=(5);
                break;
            case 0x82:
                this.reg_a = this.inst_sbc(this.reg_a, this.vecx.read8(this.reg_pc++));
                cycles.value+=(2);
                break;
            case 0x92:
                ea =  ((this.reg_dp<<8)|this.vecx.read8(this.reg_pc++)) ;
                this.reg_a = this.inst_sbc(this.reg_a, this.vecx.read8(ea));
                cycles.value+=(4);
                break;
            case 0xa2:
                ea = this.ea_indexed(cycles);
                this.reg_a = this.inst_sbc(this.reg_a, this.vecx.read8(ea));
                cycles.value+=(4);
                break;
            case 0xb2:
                ea = this.pc_read16();
                this.reg_a = this.inst_sbc(this.reg_a, this.vecx.read8(ea));
                cycles.value+=(5);
                break;
            case 0xc2:
                this.reg_b = this.inst_sbc(this.reg_b, this.vecx.read8(this.reg_pc++));
                cycles.value+=(2);
                break;
            case 0xd2:
                ea =  ((this.reg_dp<<8)|this.vecx.read8(this.reg_pc++)) ;
                this.reg_b = this.inst_sbc(this.reg_b, this.vecx.read8(ea));
                cycles.value+=(4);
                break;
            case 0xe2:
                ea = this.ea_indexed(cycles);
                this.reg_b = this.inst_sbc(this.reg_b, this.vecx.read8(ea));
                cycles.value+=(4);
                break;
            case 0xf2:
                ea = this.pc_read16();
                this.reg_b = this.inst_sbc(this.reg_b, this.vecx.read8(ea));
                cycles.value+=(5);
                break;
            case 0x84:
                this.reg_a = this.inst_and(this.reg_a, this.vecx.read8(this.reg_pc++));
                cycles.value+=(2);
                break;
            case 0x94:
                ea =  ((this.reg_dp<<8)|this.vecx.read8(this.reg_pc++)) ;
                this.reg_a = this.inst_and(this.reg_a, this.vecx.read8(ea));
                cycles.value+=(4);
                break;
            case 0xa4:
                ea = this.ea_indexed(cycles);
                this.reg_a = this.inst_and(this.reg_a, this.vecx.read8(ea));
                cycles.value+=(4);
                break;
            case 0xb4:
                ea = this.pc_read16();
                this.reg_a = this.inst_and(this.reg_a, this.vecx.read8(ea));
                cycles.value+=(5);
                break;
            case 0xc4:
                this.reg_b = this.inst_and(this.reg_b, this.vecx.read8(this.reg_pc++));
                cycles.value+=(2);
                break;
            case 0xd4:
                ea =  ((this.reg_dp<<8)|this.vecx.read8(this.reg_pc++)) ;
                this.reg_b = this.inst_and(this.reg_b, this.vecx.read8(ea));
                cycles.value+=(4);
                break;
            case 0xe4:
                ea = this.ea_indexed(cycles);
                this.reg_b = this.inst_and(this.reg_b, this.vecx.read8(ea));
                cycles.value+=(4);
                break;
            case 0xf4:
                ea = this.pc_read16();
                this.reg_b = this.inst_and(this.reg_b, this.vecx.read8(ea));
                cycles.value+=(5);
                break;
            case 0x85:
                this.inst_and(this.reg_a, this.vecx.read8(this.reg_pc++));
                cycles.value+=(2);
                break;
            case 0x95:
                ea =  ((this.reg_dp<<8)|this.vecx.read8(this.reg_pc++)) ;
                this.inst_and(this.reg_a, this.vecx.read8(ea));
                cycles.value+=(4);
                break;
            case 0xa5:
                ea = this.ea_indexed(cycles);
                this.inst_and(this.reg_a, this.vecx.read8(ea));
                cycles.value+=(4);
                break;
            case 0xb5:
                ea = this.pc_read16();
                this.inst_and(this.reg_a, this.vecx.read8(ea));
                cycles.value+=(5);
                break;
            case 0xc5:
                this.inst_and(this.reg_b, this.vecx.read8(this.reg_pc++));
                cycles.value+=(2);
                break;
            case 0xd5:
                ea =  ((this.reg_dp<<8)|this.vecx.read8(this.reg_pc++)) ;
                this.inst_and(this.reg_b, this.vecx.read8(ea));
                cycles.value+=(4);
                break;
            case 0xe5:
                ea = this.ea_indexed(cycles);
                this.inst_and(this.reg_b, this.vecx.read8(ea));
                cycles.value+=(4);
                break;
            case 0xf5:
                ea = this.pc_read16();
                this.inst_and(this.reg_b, this.vecx.read8(ea));
                cycles.value+=(5);
                break;
            case 0x86:
                this.reg_a = this.vecx.read8(this.reg_pc++);
                this.inst_tst8(this.reg_a);
                cycles.value+=(2);
                break;
            case 0x96:
                ea =  ((this.reg_dp<<8)|this.vecx.read8(this.reg_pc++)) ;
                this.reg_a = this.vecx.read8(ea);
                this.inst_tst8(this.reg_a);
                cycles.value+=(4);
                break;
            case 0xa6:
                ea = this.ea_indexed(cycles);
                this.reg_a = this.vecx.read8(ea);
                this.inst_tst8(this.reg_a);
                cycles.value+=(4);
                break;
            case 0xb6:
                ea = this.pc_read16();
                this.reg_a = this.vecx.read8(ea);
                this.inst_tst8(this.reg_a);
                cycles.value+=(5);
                break;
            case 0xc6:
                this.reg_b = this.vecx.read8(this.reg_pc++);
                this.inst_tst8(this.reg_b);
                cycles.value+=(2);
                break;
            case 0xd6:
                ea =  ((this.reg_dp<<8)|this.vecx.read8(this.reg_pc++)) ;
                this.reg_b = this.vecx.read8(ea);
                this.inst_tst8(this.reg_b);
                cycles.value+=(4);
                break;
            case 0xe6:
                ea = this.ea_indexed(cycles);
                this.reg_b = this.vecx.read8(ea);
                this.inst_tst8(this.reg_b);
                cycles.value+=(4);
                break;
            case 0xf6:
                ea = this.pc_read16();
                this.reg_b = this.vecx.read8(ea);
                this.inst_tst8(this.reg_b);
                cycles.value+=(5);
                break;
            case 0x97:
                ea =  ((this.reg_dp<<8)|this.vecx.read8(this.reg_pc++)) ;
                this.vecx.write8(ea, this.reg_a);
                this.inst_tst8(this.reg_a);
                cycles.value+=(4);
                break;
            case 0xa7:
                ea = this.ea_indexed(cycles);
                this.vecx.write8(ea, this.reg_a);
                this.inst_tst8(this.reg_a);
                cycles.value+=(4);
                break;
            case 0xb7:
                ea = this.pc_read16();
                this.vecx.write8(ea, this.reg_a);
                this.inst_tst8(this.reg_a);
                cycles.value+=(5);
                break;
            case 0xd7:
                ea =  ((this.reg_dp<<8)|this.vecx.read8(this.reg_pc++)) ;
                this.vecx.write8(ea, this.reg_b);
                this.inst_tst8(this.reg_b);
                cycles.value+=(4);
                break;
            case 0xe7:
                ea = this.ea_indexed(cycles);
                this.vecx.write8(ea, this.reg_b);
                this.inst_tst8(this.reg_b);
                cycles.value+=(4);
                break;
            case 0xf7:
                ea = this.pc_read16();
                this.vecx.write8(ea, this.reg_b);
                this.inst_tst8(this.reg_b);
                cycles.value+=(5);
                break;
            case 0x88:
                this.reg_a = this.inst_eor(this.reg_a, this.vecx.read8(this.reg_pc++));
                cycles.value+=(2);
                break;
            case 0x98:
                ea =  ((this.reg_dp<<8)|this.vecx.read8(this.reg_pc++)) ;
                this.reg_a = this.inst_eor(this.reg_a, this.vecx.read8(ea));
                cycles.value+=(4);
                break;
            case 0xa8:
                ea = this.ea_indexed(cycles);
                this.reg_a = this.inst_eor(this.reg_a, this.vecx.read8(ea));
                cycles.value+=(4);
                break;
            case 0xb8:
                ea = this.pc_read16();
                this.reg_a = this.inst_eor(this.reg_a, this.vecx.read8(ea));
                cycles.value+=(5);
                break;
            case 0xc8:
                this.reg_b = this.inst_eor(this.reg_b, this.vecx.read8(this.reg_pc++));
                cycles.value+=(2);
                break;
            case 0xd8:
                ea =  ((this.reg_dp<<8)|this.vecx.read8(this.reg_pc++)) ;
                this.reg_b = this.inst_eor(this.reg_b, this.vecx.read8(ea));
                cycles.value+=(4);
                break;
            case 0xe8:
                ea = this.ea_indexed(cycles);
                this.reg_b = this.inst_eor(this.reg_b, this.vecx.read8(ea));
                cycles.value+=(4);
                break;
            case 0xf8:
                ea = this.pc_read16();
                this.reg_b = this.inst_eor(this.reg_b, this.vecx.read8(ea));
                cycles.value+=(5);
                break;
            case 0x89:
                this.reg_a = this.inst_adc(this.reg_a, this.vecx.read8(this.reg_pc++));
                cycles.value+=(2);
                break;
            case 0x99:
                ea =  ((this.reg_dp<<8)|this.vecx.read8(this.reg_pc++)) ;
                this.reg_a = this.inst_adc(this.reg_a, this.vecx.read8(ea));
                cycles.value+=(4);
                break;
            case 0xa9:
                ea = this.ea_indexed(cycles);
                this.reg_a = this.inst_adc(this.reg_a, this.vecx.read8(ea));
                cycles.value+=(4);
                break;
            case 0xb9:
                ea = this.pc_read16();
                this.reg_a = this.inst_adc(this.reg_a, this.vecx.read8(ea));
                cycles.value+=(5);
                break;
            case 0xc9:
                this.reg_b = this.inst_adc(this.reg_b, this.vecx.read8(this.reg_pc++));
                cycles.value+=(2);
                break;
            case 0xd9:
                ea =  ((this.reg_dp<<8)|this.vecx.read8(this.reg_pc++)) ;
                this.reg_b = this.inst_adc(this.reg_b, this.vecx.read8(ea));
                cycles.value+=(4);
                break;
            case 0xe9:
                ea = this.ea_indexed(cycles);
                this.reg_b = this.inst_adc(this.reg_b, this.vecx.read8(ea));
                cycles.value+=(4);
                break;
            case 0xf9:
                ea = this.pc_read16();
                this.reg_b = this.inst_adc(this.reg_b, this.vecx.read8(ea));
                cycles.value+=(5);
                break;
            case 0x8a:
                this.reg_a = this.inst_or(this.reg_a, this.vecx.read8(this.reg_pc++));
                cycles.value+=(2);
                break;
            case 0x9a:
                ea =  ((this.reg_dp<<8)|this.vecx.read8(this.reg_pc++)) ;
                this.reg_a = this.inst_or(this.reg_a, this.vecx.read8(ea));
                cycles.value+=(4);
                break;
            case 0xaa:
                ea = this.ea_indexed(cycles);
                this.reg_a = this.inst_or(this.reg_a, this.vecx.read8(ea));
                cycles.value+=(4);
                break;
            case 0xba:
                ea = this.pc_read16();
                this.reg_a = this.inst_or(this.reg_a, this.vecx.read8(ea));
                cycles.value+=(5);
                break;
            case 0xca:
                this.reg_b = this.inst_or(this.reg_b, this.vecx.read8(this.reg_pc++));
                cycles.value+=(2);
                break;
            case 0xda:
                ea =  ((this.reg_dp<<8)|this.vecx.read8(this.reg_pc++)) ;
                this.reg_b = this.inst_or(this.reg_b, this.vecx.read8(ea));
                cycles.value+=(4);
                break;
            case 0xea:
                ea = this.ea_indexed(cycles);
                this.reg_b = this.inst_or(this.reg_b, this.vecx.read8(ea));
                cycles.value+=(4);
                break;
            case 0xfa:
                ea = this.pc_read16();
                this.reg_b = this.inst_or(this.reg_b, this.vecx.read8(ea));
                cycles.value+=(5);
                break;
            case 0x8b:
                this.reg_a = this.inst_add8(this.reg_a, this.vecx.read8(this.reg_pc++));
                cycles.value+=(2);
                break;
            case 0x9b:
                ea =  ((this.reg_dp<<8)|this.vecx.read8(this.reg_pc++)) ;
                this.reg_a = this.inst_add8(this.reg_a, this.vecx.read8(ea));
                cycles.value+=(4);
                break;
            case 0xab:
                ea = this.ea_indexed(cycles);
                this.reg_a = this.inst_add8(this.reg_a, this.vecx.read8(ea));
                cycles.value+=(4);
                break;
            case 0xbb:
                ea = this.pc_read16();
                this.reg_a = this.inst_add8(this.reg_a, this.vecx.read8(ea));
                cycles.value+=(5);
                break;
            case 0xcb:
                this.reg_b = this.inst_add8(this.reg_b, this.vecx.read8(this.reg_pc++));
                cycles.value+=(2);
                break;
            case 0xdb:
                ea =  ((this.reg_dp<<8)|this.vecx.read8(this.reg_pc++)) ;
                this.reg_b = this.inst_add8(this.reg_b, this.vecx.read8(ea));
                cycles.value+=(4);
                break;
            case 0xeb:
                ea = this.ea_indexed(cycles);
                this.reg_b = this.inst_add8(this.reg_b, this.vecx.read8(ea));
                cycles.value+=(4);
                break;
            case 0xfb:
                ea = this.pc_read16();
                this.reg_b = this.inst_add8(this.reg_b, this.vecx.read8(ea));
                cycles.value+=(5);
                break;
            case 0x83:
                this.set_reg_d(this.inst_sub16( ((this.reg_a<<8)|(this.reg_b&0xff)) , this.pc_read16()));
                cycles.value+=(4);
                break;
            case 0x93:
                ea =  ((this.reg_dp<<8)|this.vecx.read8(this.reg_pc++)) ;
                this.set_reg_d(this.inst_sub16( ((this.reg_a<<8)|(this.reg_b&0xff)) , this.read16(ea)));
                cycles.value+=(6);
                break;
            case 0xa3:
                ea = this.ea_indexed(cycles);
                this.set_reg_d(this.inst_sub16( ((this.reg_a<<8)|(this.reg_b&0xff)) , this.read16(ea)));
                cycles.value+=(6);
                break;
            case 0xb3:
                ea = this.pc_read16();
                this.set_reg_d(this.inst_sub16( ((this.reg_a<<8)|(this.reg_b&0xff)) , this.read16(ea)));
                cycles.value+=(7);
                break;
            case 0x8c:
                this.inst_sub16(this.reg_x.value, this.pc_read16());
                cycles.value+=(4);
                break;
            case 0x9c:
                ea =  ((this.reg_dp<<8)|this.vecx.read8(this.reg_pc++)) ;
                this.inst_sub16(this.reg_x.value, this.read16(ea));
                cycles.value+=(6);
                break;
            case 0xac:
                ea = this.ea_indexed(cycles);
                this.inst_sub16(this.reg_x.value, this.read16(ea));
                cycles.value+=(6);
                break;
            case 0xbc:
                ea = this.pc_read16();
                this.inst_sub16(this.reg_x.value, this.read16(ea));
                cycles.value+=(7);
                break;
            case 0x8e:
                this.reg_x.value=(this.pc_read16());
                this.inst_tst16(this.reg_x.value);
                cycles.value+=(3);
                break;
            case 0x9e:
                ea =  ((this.reg_dp<<8)|this.vecx.read8(this.reg_pc++)) ;
                this.reg_x.value=(this.read16(ea));
                this.inst_tst16(this.reg_x.value);
                cycles.value+=(5);
                break;
            case 0xae:
                ea = this.ea_indexed(cycles);
                this.reg_x.value=(this.read16(ea));
                this.inst_tst16(this.reg_x.value);
                cycles.value+=(5);
                break;
            case 0xbe:
                ea = this.pc_read16();
                this.reg_x.value=(this.read16(ea));
                this.inst_tst16(this.reg_x.value);
                cycles.value+=(6);
                break;
            case 0xce:
                this.reg_u.value=(this.pc_read16());
                this.inst_tst16(this.reg_u.value);
                cycles.value+=(3);
                break;
            case 0xde:
                ea =  ((this.reg_dp<<8)|this.vecx.read8(this.reg_pc++)) ;
                this.reg_u.value=(this.read16(ea));
                this.inst_tst16(this.reg_u.value);
                cycles.value+=(5);
                break;
            case 0xee:
                ea = this.ea_indexed(cycles);
                this.reg_u.value=(this.read16(ea));
                this.inst_tst16(this.reg_u.value);
                cycles.value+=(5);
                break;
            case 0xfe:
                ea = this.pc_read16();
                this.reg_u.value=(this.read16(ea));
                this.inst_tst16(this.reg_u.value);
                cycles.value+=(6);
                break;
            case 0x9f:
                ea =  ((this.reg_dp<<8)|this.vecx.read8(this.reg_pc++)) ;
                this.write16(ea, this.reg_x.value);
                this.inst_tst16(this.reg_x.value);
                cycles.value+=(5);
                break;
            case 0xaf:
                ea = this.ea_indexed(cycles);
                this.write16(ea, this.reg_x.value);
                this.inst_tst16(this.reg_x.value);
                cycles.value+=(5);
                break;
            case 0xbf:
                ea = this.pc_read16();
                this.write16(ea, this.reg_x.value);
                this.inst_tst16(this.reg_x.value);
                cycles.value+=(6);
                break;
            case 0xdf:
                ea =  ((this.reg_dp<<8)|this.vecx.read8(this.reg_pc++)) ;
                this.write16(ea, this.reg_u.value);
                this.inst_tst16(this.reg_u.value);
                cycles.value+=(5);
                break;
            case 0xef:
                ea = this.ea_indexed(cycles);
                this.write16(ea, this.reg_u.value);
                this.inst_tst16(this.reg_u.value);
                cycles.value+=(5);
                break;
            case 0xff:
                ea = this.pc_read16();
                this.write16(ea, this.reg_u.value);
                this.inst_tst16(this.reg_u.value);
                cycles.value+=(6);
                break;
            case 0xc3:
                this.set_reg_d(this.inst_add16( ((this.reg_a<<8)|(this.reg_b&0xff)) , this.pc_read16()));
                cycles.value+=(4);
                break;
            case 0xd3:
                ea =  ((this.reg_dp<<8)|this.vecx.read8(this.reg_pc++)) ;
                this.set_reg_d(this.inst_add16( ((this.reg_a<<8)|(this.reg_b&0xff)) , this.read16(ea)));
                cycles.value+=(6);
                break;
            case 0xe3:
                ea = this.ea_indexed(cycles);
                this.set_reg_d(this.inst_add16( ((this.reg_a<<8)|(this.reg_b&0xff)) , this.read16(ea)));
                cycles.value+=(6);
                break;
            case 0xf3:
                ea = this.pc_read16();
                this.set_reg_d(this.inst_add16( ((this.reg_a<<8)|(this.reg_b&0xff)) , this.read16(ea)));
                cycles.value+=(7);
                break;
            case 0xcc:
                this.set_reg_d(this.pc_read16());
                this.inst_tst16( ((this.reg_a<<8)|(this.reg_b&0xff)) );
                cycles.value+=(3);
                break;
            case 0xdc:
                ea =  ((this.reg_dp<<8)|this.vecx.read8(this.reg_pc++)) ;
                this.set_reg_d(this.read16(ea));
                this.inst_tst16( ((this.reg_a<<8)|(this.reg_b&0xff)) );
                cycles.value+=(5);
                break;
            case 0xec:
                ea = this.ea_indexed(cycles);
                this.set_reg_d(this.read16(ea));
                this.inst_tst16( ((this.reg_a<<8)|(this.reg_b&0xff)) );
                cycles.value+=(5);
                break;
            case 0xfc:
                ea = this.pc_read16();
                this.set_reg_d(this.read16(ea));
                this.inst_tst16( ((this.reg_a<<8)|(this.reg_b&0xff)) );
                cycles.value+=(6);
                break;
            case 0xdd:
                ea =  ((this.reg_dp<<8)|this.vecx.read8(this.reg_pc++)) ;
                this.write16(ea,  ((this.reg_a<<8)|(this.reg_b&0xff)) );
                this.inst_tst16( ((this.reg_a<<8)|(this.reg_b&0xff)) );
                cycles.value+=(5);
                break;
            case 0xed:
                ea = this.ea_indexed(cycles);
                this.write16(ea,  ((this.reg_a<<8)|(this.reg_b&0xff)) );
                this.inst_tst16( ((this.reg_a<<8)|(this.reg_b&0xff)) );
                cycles.value+=(5);
                break;
            case 0xfd:
                ea = this.pc_read16();
                this.write16(ea,  ((this.reg_a<<8)|(this.reg_b&0xff)) );
                this.inst_tst16( ((this.reg_a<<8)|(this.reg_b&0xff)) );
                cycles.value+=(6);
                break;
            case 0x12:
                cycles.value+=(2);
                break;
            case 0x3d:
                r = (this.reg_a & 0xff) * (this.reg_b & 0xff);
                this.set_reg_d(r);
                this.reg_cc=((this.reg_cc&~this.FLAG_Z)|(this.test_z16(r)*this.FLAG_Z)) ;
                this.reg_cc=((this.reg_cc&~this.FLAG_C)|((r >> 7) & 1*this.FLAG_C)) ;
                cycles.value+=(11);
                break;
            case 0x20:
            case 0x21:
                this.inst_bra8(0, op, cycles);
                break;
            case 0x22:
            case 0x23:
                this.inst_bra8( ((this.reg_cc/this.FLAG_C>>0)&1)  |  ((this.reg_cc/this.FLAG_Z>>0)&1) , op, cycles);
                break;
            case 0x24:
            case 0x25:
                this.inst_bra8( ((this.reg_cc/this.FLAG_C>>0)&1) , op, cycles);
                break;
            case 0x26:
            case 0x27:
                this.inst_bra8( ((this.reg_cc/this.FLAG_Z>>0)&1) , op, cycles);
                break;
            case 0x28:
            case 0x29:
                this.inst_bra8( ((this.reg_cc/this.FLAG_V>>0)&1) , op, cycles);
                break;
            case 0x2a:
            case 0x2b:
                this.inst_bra8( ((this.reg_cc/this.FLAG_N>>0)&1) , op, cycles);
                break;
            case 0x2c:
            case 0x2d:
                this.inst_bra8( ((this.reg_cc/this.FLAG_N>>0)&1)  ^  ((this.reg_cc/this.FLAG_V>>0)&1) , op, cycles);
                break;
            case 0x2e:
            case 0x2f:
                this.inst_bra8( ((this.reg_cc/this.FLAG_Z>>0)&1)  |
                               ( ((this.reg_cc/this.FLAG_N>>0)&1)  ^  ((this.reg_cc/this.FLAG_V>>0)&1) ), op, cycles);
                break;
            case 0x16:
                r = this.pc_read16();
                this.reg_pc += r;
                cycles.value+=(5);
                break;
            case 0x17:
                r = this.pc_read16();
                this.push16(this.reg_s, this.reg_pc);
                this.reg_pc += r;
                cycles.value+=(9);
                break;
            case 0x8d:
                r = this.vecx.read8(this.reg_pc++);
                this.push16(this.reg_s, this.reg_pc);
                this.reg_pc += this.sign_extend(r);
                cycles.value+=(7);
                break;
            case 0x9d:
                ea =  ((this.reg_dp<<8)|this.vecx.read8(this.reg_pc++)) ;
                this.push16(this.reg_s, this.reg_pc);
                this.reg_pc = ea;
                cycles.value+=(7);
                break;
            case 0xad:
                ea = this.ea_indexed(cycles);
                this.push16(this.reg_s, this.reg_pc);
                this.reg_pc = ea;
                cycles.value+=(7);
                break;
            case 0xbd:
                ea = this.pc_read16();
                
                // Log music function calls
                if (typeof window !== 'undefined' && window.MUSIC_CALL_LOG_ENABLED && 
                    window.MUSIC_CALL_LOG && window.MUSIC_CALL_LOG.length < window.MUSIC_CALL_LOG_LIMIT) {
                    var funcName = window.MUSIC_FUNCTION_ADDRS[ea];
                    if (funcName) {
                        window.MUSIC_CALL_LOG.push({
                            type: 'JSR',
                            from: this.reg_pc - 3, // PC antes del JSR
                            to: ea,
                            funcName: funcName,
                            frame: (typeof window.g_frameCount !== 'undefined') ? window.g_frameCount : 0,
                            timestamp: Date.now()
                        });
                    }
                }
                
                this.push16(this.reg_s, this.reg_pc);
                this.reg_pc = ea;
                cycles.value+=(8);
                break;
            case 0x30:
                this.reg_x.value=(this.ea_indexed(cycles));
                this.reg_cc=((this.reg_cc&~this.FLAG_Z)|(this.test_z16(this.reg_x.value)*this.FLAG_Z)) ;
                cycles.value+=(4);
                break;
            case 0x31:
                this.reg_y.value=(this.ea_indexed(cycles));
                this.reg_cc=((this.reg_cc&~this.FLAG_Z)|(this.test_z16(this.reg_y.value)*this.FLAG_Z)) ;
                cycles.value+=(4);
                break;
            case 0x32:
                this.reg_s.value=(this.ea_indexed(cycles));
                cycles.value+=(4);
                break;
            case 0x33:
                this.reg_u.value=(this.ea_indexed(cycles));
                cycles.value+=(4);
                break;
            case 0x34:
                this.inst_psh(this.vecx.read8(this.reg_pc++), this.reg_s, this.reg_u.value, cycles);
                cycles.value+=(5);
                break;
            case 0x35:
                this.inst_pul(this.vecx.read8(this.reg_pc++), this.reg_s, this.reg_u, cycles);
                cycles.value+=(5);
                break;
            case 0x36:
                this.inst_psh(this.vecx.read8(this.reg_pc++), this.reg_u, this.reg_s.value, cycles);
                cycles.value+=(5);
                break;
            case 0x37:
                this.inst_pul(this.vecx.read8(this.reg_pc++), this.reg_u, this.reg_s, cycles);
                cycles.value+=(5);
                break;
            case 0x39:
                this.reg_pc = this.pull16(this.reg_s);
                cycles.value+=(5);
                break;
            case 0x3a:
                this.reg_x.value+=(this.reg_b & 0xff);
                cycles.value+=(3);
                break;
            case 0x1b:
                // ABA - Add B to A
                this.reg_a = this.inst_add8(this.reg_a, (this.reg_b & 0xff));
                cycles.value+=(2);
                break;
            case 0x1a:
                this.reg_cc |= this.vecx.read8(this.reg_pc++);
                cycles.value+=(3);
                break;
            case 0x1c:
                this.reg_cc &= this.vecx.read8(this.reg_pc++);
                cycles.value+=(3);
                break;
            case 0x1d:
                this.set_reg_d(this.sign_extend(this.reg_b));
                this.reg_cc=((this.reg_cc&~this.FLAG_N)|( ((this.reg_a>>7)&1) *this.FLAG_N)) ;
                this.reg_cc=((this.reg_cc&~this.FLAG_Z)|(this.test_z16( ((this.reg_a<<8)|(this.reg_b&0xff)) )*this.FLAG_Z)) ;
                cycles.value+=(2);
                break;
            case 0x1e:
                this.inst_exg();
                cycles.value+=(8);
                break;
            case 0x1f:
                this.inst_tfr();
                cycles.value+=(6);
                break;
            case 0x3b:
                if(  ((this.reg_cc/this.FLAG_E>>0)&1)  )
                {
                    this.inst_pul(0xff, this.reg_s, this.reg_u, cycles);
                }
                else
                {
                    this.inst_pul(0x81, this.reg_s, this.reg_u, cycles);
                }
                cycles.value+=(3);
                break;
            case 0x3f:
                this.reg_cc=((this.reg_cc&~this.FLAG_E)|(1*this.FLAG_E)) ;
                this.inst_psh(0xff, this.reg_s, this.reg_u.value, cycles);
                this.reg_cc=((this.reg_cc&~this.FLAG_I)|(1*this.FLAG_I)) ;
                this.reg_cc=((this.reg_cc&~this.FLAG_F)|(1*this.FLAG_F)) ;
                this.reg_pc = this.read16(0xfffa);
                cycles.value+=(7);
                break;
            case 0x13:
                this.irq_status = this.IRQ_SYNC;
                cycles.value+=(2);
                break;
            case 0x19:
                i0 = this.reg_a;
                i1 = 0;
                if( (this.reg_a & 0x0f) > 0x09 ||  ((this.reg_cc/this.FLAG_H>>0)&1)  == 1 )
                {
                    i1 |= 0x06;
                }
                if( (this.reg_a & 0xf0) > 0x80 && (this.reg_a & 0x0f) > 0x09 )
                {
                    i1 |= 0x60;
                }
                if( (this.reg_a & 0xf0) > 0x90 ||  ((this.reg_cc/this.FLAG_C>>0)&1)  == 1 )
                {
                    i1 |= 0x60;
                }
                this.reg_a = i0 + i1;
                this.reg_cc=((this.reg_cc&~this.FLAG_N)|( ((this.reg_a>>7)&1) *this.FLAG_N)) ;
                this.reg_cc=((this.reg_cc&~this.FLAG_Z)|(this.test_z8(this.reg_a)*this.FLAG_Z)) ;
                this.reg_cc=((this.reg_cc&~this.FLAG_V)|(0*this.FLAG_V)) ;
                this.reg_cc=((this.reg_cc&~this.FLAG_C)|(this.test_c(i0, i1, this.reg_a, 0)*this.FLAG_C)) ;
                cycles.value+=(2);
                break;
            case 0x3c:
                var val = this.vecx.read8(this.reg_pc++);
                this.reg_cc=((this.reg_cc&~this.FLAG_E)|(1*this.FLAG_E)) ;
                this.inst_psh(0xff, this.reg_s, this.reg_u.value, cycles);
                this.irq_status = this.IRQ_CWAI;
                this.reg_cc &= val;
                cycles.value+=(4);
                break;
            case 0x10:
                op = this.vecx.read8(this.reg_pc++);
                switch( op )
                    {
                    case 0x20:
                    case 0x21:
                        this.inst_bra16(0, op, cycles);
                        break;
                    case 0x22:
                    case 0x23:
                        this.inst_bra16( ((this.reg_cc/this.FLAG_C>>0)&1)  |  ((this.reg_cc/this.FLAG_Z>>0)&1) , op, cycles);
                        break;
                    case 0x24:
                    case 0x25:
                        this.inst_bra16( ((this.reg_cc/this.FLAG_C>>0)&1) , op, cycles);
                        break;
                    case 0x26:
                    case 0x27:
                        this.inst_bra16( ((this.reg_cc/this.FLAG_Z>>0)&1) , op, cycles);
                        break;
                    case 0x28:
                    case 0x29:
                        this.inst_bra16( ((this.reg_cc/this.FLAG_V>>0)&1) , op, cycles);
                        break;
                    case 0x2a:
                    case 0x2b:
                        this.inst_bra16( ((this.reg_cc/this.FLAG_N>>0)&1) , op, cycles);
                        break;
                    case 0x2c:
                    case 0x2d:
                        this.inst_bra16( ((this.reg_cc/this.FLAG_N>>0)&1)  ^  ((this.reg_cc/this.FLAG_V>>0)&1) , op, cycles);
                        break;
                    case 0x2e:
                    case 0x2f:
                        this.inst_bra16( ((this.reg_cc/this.FLAG_Z>>0)&1)  |
                                        ( ((this.reg_cc/this.FLAG_N>>0)&1)  ^  ((this.reg_cc/this.FLAG_V>>0)&1) ), op, cycles);
                        break;
                    case 0x83:
                        this.inst_sub16( ((this.reg_a<<8)|(this.reg_b&0xff)) , this.pc_read16());
                        cycles.value+=(5);
                        break;
                    case 0x93:
                        ea =  ((this.reg_dp<<8)|this.vecx.read8(this.reg_pc++)) ;
                        this.inst_sub16( ((this.reg_a<<8)|(this.reg_b&0xff)) , this.read16(ea));
                        cycles.value+=(7);
                        break;
                    case 0xa3:
                        ea = this.ea_indexed(cycles);
                        this.inst_sub16( ((this.reg_a<<8)|(this.reg_b&0xff)) , this.read16(ea));
                        cycles.value+=(7);
                        break;
                    case 0xb3:
                        ea = this.pc_read16();
                        this.inst_sub16( ((this.reg_a<<8)|(this.reg_b&0xff)) , this.read16(ea));
                        cycles.value+=(8);
                        break;
                    case 0x8c:
                        this.inst_sub16(this.reg_y.value, this.pc_read16());
                        cycles.value+=(5);
                        break;
                    case 0x9c:
                        ea =  ((this.reg_dp<<8)|this.vecx.read8(this.reg_pc++)) ;
                        this.inst_sub16(this.reg_y.value, this.read16(ea));
                        cycles.value+=(7);
                        break;
                    case 0xac:
                        ea = this.ea_indexed(cycles);
                        this.inst_sub16(this.reg_y.value, this.read16(ea));
                        cycles.value+=(7);
                        break;
                    case 0xbc:
                        ea = this.pc_read16();
                        this.inst_sub16(this.reg_y.value, this.read16(ea));
                        cycles.value+=(8);
                        break;
                    case 0x8e:
                        this.reg_y.value=(this.pc_read16());
                        this.inst_tst16(this.reg_y.value);
                        cycles.value+=(4);
                        break;
                    case 0x9e:
                        ea =  ((this.reg_dp<<8)|this.vecx.read8(this.reg_pc++)) ;
                        this.reg_y.value=(this.read16(ea));
                        this.inst_tst16(this.reg_y.value);
                        cycles.value+=(6);
                        break;
                    case 0xae:
                        ea = this.ea_indexed(cycles);
                        this.reg_y.value=(this.read16(ea));
                        this.inst_tst16(this.reg_y.value);
                        cycles.value+=(6);
                        break;
                    case 0xbe:
                        ea = this.pc_read16();
                        this.reg_y.value=(this.read16(ea));
                        this.inst_tst16(this.reg_y.value);
                        cycles.value+=(7);
                        break;
                    case 0x9f:
                        ea =  ((this.reg_dp<<8)|this.vecx.read8(this.reg_pc++)) ;
                        this.write16(ea, this.reg_y.value);
                        this.inst_tst16(this.reg_y.value);
                        cycles.value+=(6);
                        break;
                    case 0xaf:
                        ea = this.ea_indexed(cycles);
                        this.write16(ea, this.reg_y.value);
                        this.inst_tst16(this.reg_y.value);
                        cycles.value+=(6);
                        break;
                    case 0xbf:
                        ea = this.pc_read16();
                        this.write16(ea, this.reg_y.value);
                        this.inst_tst16(this.reg_y.value);
                        cycles.value+=(7);
                        break;
                    case 0xce:
                        this.reg_s.value=(this.pc_read16());
                        this.inst_tst16(this.reg_s.value);
                        cycles.value+=(4);
                        break;
                    case 0xde:
                        ea =  ((this.reg_dp<<8)|this.vecx.read8(this.reg_pc++)) ;
                        this.reg_s.value=(this.read16(ea));
                        this.inst_tst16(this.reg_s.value);
                        cycles.value+=(6);
                        break;
                    case 0xee:
                        ea = this.ea_indexed(cycles);
                        this.reg_s.value=(this.read16(ea));
                        this.inst_tst16(this.reg_s.value);
                        cycles.value+=(6);
                        break;
                    case 0xfe:
                        ea = this.pc_read16();
                        this.reg_s.value=(this.read16(ea));
                        this.inst_tst16(this.reg_s.value);
                        cycles.value+=(7);
                        break;
                    case 0xdf:
                        ea =  ((this.reg_dp<<8)|this.vecx.read8(this.reg_pc++)) ;
                        this.write16(ea, this.reg_s.value);
                        this.inst_tst16(this.reg_s.value);
                        cycles.value+=(6);
                        break;
                    case 0xef:
                        ea = this.ea_indexed(cycles);
                        this.write16(ea, this.reg_s.value);
                        this.inst_tst16(this.reg_s.value);
                        cycles.value+=(6);
                        break;
                    case 0xff:
                        ea = this.pc_read16();
                        this.write16(ea, this.reg_s.value);
                        this.inst_tst16(this.reg_s.value);
                        cycles.value+=(7);
                        break;
                    case 0x3f:
                        this.reg_cc=((this.reg_cc&~this.FLAG_E)|(1*this.FLAG_E)) ;
                        this.inst_psh(0xff, this.reg_s, this.reg_u.value, cycles);
                        this.reg_pc = this.read16(0xfff4);
                        cycles.value+=(8);
                        break;
                    default:
                        ERROR_HALT = true;
                        utils.showError("unknown page-1 op code: " + op);
                        break;
                }
                break;
            case 0x11:
                op = this.vecx.read8(this.reg_pc++);
                switch( op )
                {
                    case 0x83:
                        this.inst_sub16(this.reg_u.value, this.pc_read16());
                        cycles.value+=(5);
                        break;
                    case 0x93:
                        ea =  ((this.reg_dp<<8)|this.vecx.read8(this.reg_pc++)) ;
                        this.inst_sub16(this.reg_u.value, this.read16(ea));
                        cycles.value+=(7);
                        break;
                    case 0xa3:
                        ea = this.ea_indexed(cycles);
                        this.inst_sub16(this.reg_u.value, this.read16(ea));
                        cycles.value+=(7);
                        break;
                    case 0xb3:
                        ea = this.pc_read16();
                        this.inst_sub16(this.reg_u.value, this.read16(ea));
                        cycles.value+=(8);
                        break;
                    case 0x8c:
                        this.inst_sub16(this.reg_s.value, this.pc_read16());
                        cycles.value+=(5);
                        break;
                    case 0x9c:
                        ea =  ((this.reg_dp<<8)|this.vecx.read8(this.reg_pc++)) ;
                        this.inst_sub16(this.reg_s.value, this.read16(ea));
                        cycles.value+=(7);
                        break;
                    case 0xac:
                        ea = this.ea_indexed(cycles);
                        this.inst_sub16(this.reg_s.value, this.read16(ea));
                        cycles.value+=(7);
                        break;
                    case 0xbc:
                        ea = this.pc_read16();
                        this.inst_sub16(this.reg_s.value, this.read16(ea));
                        cycles.value+=(8);
                        break;
                    case 0x3f:
                        this.reg_cc=((this.reg_cc&~this.FLAG_E)|(1*this.FLAG_E)) ;
                        this.inst_psh(0xff, this.reg_s, this.reg_u.value, cycles);
                        this.reg_pc = this.read16(0xfff2);
                        cycles.value+=(8);
                        break;
                    default:
                        ERROR_HALT = true;
                        utils.showError("unknown page-2 op code: " + op);
                        break;
                }
                break;
            default:
                ERROR_HALT = true;
                const errorMsg = "Unknown page-0 opcode: 0x" + op.toString(16).toUpperCase().padStart(2, '0') + " at PC=0x" + op_pc.toString(16).toUpperCase().padStart(4, '0');
                console.log("⚠️ UNKNOWN PAGE-0 OPCODE ERROR:");
                console.log("  PC: 0x" + op_pc.toString(16).toUpperCase().padStart(4, '0'));
                console.log("  Opcode: 0x" + op.toString(16).toUpperCase().padStart(2, '0') + " (" + op + ")");
                console.log("  Registers:");
                console.log("    A: 0x" + this.reg_a.toString(16).toUpperCase().padStart(2, '0'));
                console.log("    B: 0x" + this.reg_b.toString(16).toUpperCase().padStart(2, '0'));
                console.log("    X: 0x" + this.reg_x.value.toString(16).toUpperCase().padStart(4, '0'));
                console.log("    Y: 0x" + this.reg_y.value.toString(16).toUpperCase().padStart(4, '0'));
                console.log("    U: 0x" + this.reg_u.value.toString(16).toUpperCase().padStart(4, '0'));
                console.log("    S: 0x" + this.reg_s.value.toString(16).toUpperCase().padStart(4, '0'));
                console.log("    DP: 0x" + (this.reg_dp & 0xFF).toString(16).toUpperCase().padStart(2, '0'));
                console.log("    CC: 0x" + this.reg_cc.toString(16).toUpperCase().padStart(2, '0'));
                // Bank-switching corruption is a common cause of "code runs into data".
                // Show the active switchable bank ($0000-$3FFF). The property name in
                // public/jsvecx_deploy/vecx.js is `currentBank` (camelCase); the older
                // src/generated/jsvecx/vecx_full.js uses `current_bank`. We try both.
                var __bk = 'unknown';
                var __src = '';
                try {
                    var __v = (typeof window !== 'undefined') ? window.vecx : null;
                    if (__v) {
                        if (typeof __v.currentBank !== 'undefined') {
                            __bk = '0x' + (__v.currentBank & 0xFF).toString(16).toUpperCase().padStart(2, '0');
                            __src = 'window.vecx.currentBank';
                        } else if (typeof __v.current_bank !== 'undefined') {
                            __bk = '0x' + (__v.current_bank & 0xFF).toString(16).toUpperCase().padStart(2, '0');
                            __src = 'window.vecx.current_bank';
                        }
                    }
                } catch (e) { __src = 'error: ' + e.message; }
                console.log("    BANK: " + __bk + " [src=" + __src + "] (active switchable bank at $0000-$3FFF)");
                // Dump extended state. Include both naming conventions and the bank
                // register address so we can confirm bank-switch corruption hypotheses.
                try {
                    if (typeof window !== 'undefined' && window.vecx) {
                        var v = window.vecx;
                        var keys = ['currentBank','current_bank','isMultibank','bankRegister','via_pcr','via_acr','via_ifr','running','debugState'];
                        var info = keys.map(function(k){
                            var val = v[k];
                            if (typeof val === 'undefined') return k+'=undef';
                            if (typeof val === 'number') return k+'=0x'+val.toString(16);
                            return k+'='+val;
                        }).join(' ');
                        console.log("    VECX STATE: " + info);
                    }
                } catch (e) {}
                const stackSnapshot = dumpStackSnapshot(this);
                console.log(stackSnapshot);
                
                // Dump trace to file
                const traceOutput = dumpOpcodeTrace(errorMsg, stackSnapshot);
                console.log("\n=== LAST INSTRUCTIONS BEFORE CRASH ===");
                console.log(traceOutput);
                console.log("=== END TRACE ===");

                // Kick a final flush for full trace (best effort)
                try {
                    if (typeof window !== 'undefined' && window.__flushFullTraceNow) {
                        window.__flushFullTraceNow();
                    }
                } catch (e) {}

                // Stop emulator to avoid infinite error loops
                try {
                    // Force stop by setting running flag to false globally
                    if (typeof window !== 'undefined' && window.vecxInstance) {
                        window.vecxInstance.running = false;
                        if (typeof window.vecxInstance.debugStop === 'function') {
                            window.vecxInstance.debugStop();
                        }
                    }
                    if (this.vecx) {
                        this.vecx.running = false;
                        if (typeof this.vecx.debugStop === 'function') this.vecx.debugStop();
                        else if (typeof this.vecx.stop === 'function') this.vecx.stop();
                    }
                } catch (e) {
                    console.error("Failed to stop emulator:", e);
                }

                utils.showError(errorMsg);
                break;
        }
        return cycles.value;
    }
    this.init = function( vecx )
    {
        this.vecx = vecx;
    }
}
