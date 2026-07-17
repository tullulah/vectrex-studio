/**
 * PitrexAsmParser.ts — Parse the ARM32 .s file emitted by the VPy pitrex backend.
 *
 * The .s file uses GNU ARM32 assembly (not Thumb). Key features:
 *   - .equ NAME, VALUE   → equates (variable addresses in Pi Zero RAM)
 *   - LABEL: .space N    → BSS variables (assigned sequential addresses)
 *   - LABEL: .hword N    → rodata arrays (assigned sequential addresses + data stored)
 *   - label:             → code label (maps to instruction index)
 *   - .asciz "text"      → string literal (follows a label; stored in strings map)
 *   - Inline string trick: b label_after / label: .asciz / label_after: — branch skips data
 *
 * The parser resolves all symbol references so the interpreter can use pure
 * numeric addresses and instruction indices.
 */

// ---------------------------------------------------------------------------
// Public types
// ---------------------------------------------------------------------------

export interface AsmInstruction {
  /** If a label was defined on this line. */
  label?: string;
  /** Base mnemonic, lowercase (e.g. 'mov', 'ldr', 'bl'). */
  op: string;
  /** Condition suffix if any (e.g. 'eq', 'lt', 'gt'). */
  cond?: string;
  /** Raw operand strings, split by comma-outside-brackets. */
  operands: string[];
  lineNum: number;
}

export interface ParsedAsm {
  /** .equ NAME, VALUE → NAME → numeric value. */
  equs: Map<string, number>;
  /** All symbols (equs + bss + rodata + extern + string) → { kind, value }. */
  symbols: Map<string, { kind: 'equ' | 'bss' | 'rodata' | 'extern' | 'string'; value: number }>;
  /** Code label → instruction index. */
  labels: Map<string, number>;
  /** Numeric local labels: [{number, instrIdx}] in order. Used for 1f/1b resolution. */
  numericLabels: Array<{ n: number; idx: number }>;
  /** String label → text content. */
  strings: Map<string, string>;
  /** The instruction list. */
  instructions: AsmInstruction[];
  /** Initial memory contents (rodata and mutable-array data): addr → word32. */
  initMemory: Map<number, number>;
}

// ---------------------------------------------------------------------------
// ARM condition suffixes (ordered longest-first to avoid partial matches)
// ---------------------------------------------------------------------------

const ARM_CONDITIONS = ['eq','ne','cs','hs','cc','lo','mi','pl','vs','vc','hi','ls','ge','lt','gt','le','al'];

/**
 * Known base mnemonics that can carry a condition suffix.
 * Listed as a Set for O(1) lookup.
 */
const BASE_MNEMONICS = new Set([
  'mov','mvn','ldr','ldrh','ldrsh','ldrb','str','strh','strb',
  'add','sub','mul','rsb','neg','and','orr','eor','bic',
  'cmp','cmn','tst','teq',
  'asr','lsl','lsr','ror',
  'push','pop','b','bl','bx','blx',
  'it','ite','itt','ittee','itete',
  'nop','wfi','wfe',
  'uxth','uxtb','sxtb','sxth',
  'clz','udiv','sdiv',
  // gcc integer-codegen additions (libvpy vpy.s): 32-bit immediate builders,
  // long multiplies, multiply-subtract, bitfield-extract, double load/store.
  'movw','movt','smull','umull','mls','ubfx','ldrd','strd',
]);

/** Parse mnemonic into { op, cond }. */
function parseMnemonic(raw: string): { op: string; cond?: string } {
  const lo = raw.toLowerCase();

  // Direct full-mnemonic conditional branches: beq, bne, blt, bge, bgt, ble, blo, bhi, bhs, bcs, bcc, bmi, bpl, bvs, bvc, bls, bal
  if (lo.startsWith('b') && lo.length >= 3) {
    const suffix = lo.slice(1);
    if (ARM_CONDITIONS.includes(suffix)) {
      return { op: 'b', cond: suffix };
    }
  }

  // Try stripping a known condition suffix from the end
  for (const cond of ARM_CONDITIONS) {
    if (lo.endsWith(cond) && lo.length > cond.length) {
      const base = lo.slice(0, lo.length - cond.length);
      if (BASE_MNEMONICS.has(base)) {
        return { op: base, cond };
      }
    }
  }

  return { op: lo };
}

// ---------------------------------------------------------------------------
// Operand splitting
// ---------------------------------------------------------------------------

/** Split operand string by commas, but respect {...} and [...] brackets. */
function splitOperands(s: string): string[] {
  const parts: string[] = [];
  let depth = 0;
  let start = 0;
  for (let i = 0; i < s.length; i++) {
    const c = s[i];
    if (c === '{' || c === '[') depth++;
    else if (c === '}' || c === ']') depth--;
    else if (c === ',' && depth === 0) {
      parts.push(s.slice(start, i).trim());
      start = i + 1;
    }
  }
  const last = s.slice(start).trim();
  if (last) parts.push(last);
  return parts;
}

// ---------------------------------------------------------------------------
// Numeric literal parser
// ---------------------------------------------------------------------------

function parseNumber(s: string): number | null {
  s = s.trim();
  if (s.startsWith('0x') || s.startsWith('0X')) {
    const v = parseInt(s.slice(2), 16);
    return isNaN(v) ? null : v;
  }
  if (s.startsWith('-0x') || s.startsWith('-0X')) {
    const v = parseInt(s.slice(3), 16);
    return isNaN(v) ? null : -v;
  }
  if (/^-?\d+$/.test(s)) {
    return parseInt(s, 10);
  }
  return null;
}

/**
 * Decode the escape sequences inside a `.ascii`/`.asciz` string literal.
 * Handles gcc's octal (`\NNN`, e.g. the s_sin table in libvpy's vpy.s), plus
 * `\xNN`, `\n`, `\r`, `\t`, and `\\`. Octal is matched first because gcc always
 * zero-pads octal escapes to 3 digits, so a following literal digit is never
 * consumed. Literal printable characters pass through untouched.
 */
function decodeAsmString(raw: string): string {
  return raw
    .replace(/\\([0-7]{1,3})/g, (_m, o) => String.fromCharCode(parseInt(o, 8) & 0xFF))
    .replace(/\\x([0-9a-fA-F]{2})/g, (_m, h) => String.fromCharCode(parseInt(h, 16)))
    .replace(/\\n/g, '\n')
    .replace(/\\r/g, '\r')
    .replace(/\\t/g, '\t')
    .replace(/\\\\/g, '\\');
}

// ---------------------------------------------------------------------------
// Directives to skip
// ---------------------------------------------------------------------------

const SKIP_DIRECTIVES = new Set([
  '.ltorg', '.align', '.global', '.globl', '.type', '.extern',
  '.arch', '.fpu', '.syntax', '.thumb_func', '.thumb', '.arm',
  '.text', '.size', '.weak', '.set', '.section',
]);

// ---------------------------------------------------------------------------
// Main parser
// ---------------------------------------------------------------------------

// Fake address base for different symbol kinds
const EXTERN_BASE  = 0x00210000;  // Extern symbols (currentJoy1X etc.)
const STRING_BASE  = 0xF0000000;  // Inline string labels
const BSS_BASE     = 0x00200000;  // BSS labels (PITREX_CUR_X etc.)
const RODATA_BASE  = 0x00208000;  // Read-only data arrays
const TEXT_DATA_BASE = 0x00400000; // Text-section data labels (assets emitted as .byte/.word)

export function parseAsm(src: string): ParsedAsm {
  const lines = src.split('\n');

  const equs    = new Map<string, number>();
  const symbols = new Map<string, { kind: 'equ' | 'bss' | 'rodata' | 'extern' | 'string'; value: number }>();
  const labels  = new Map<string, number>();
  const numericLabels: Array<{ n: number; idx: number }> = [];
  const strings = new Map<string, string>();
  const instructions: AsmInstruction[] = [];
  const initMemory = new Map<number, number>();

  // Section state
  type Section = 'none' | 'bss' | 'rodata' | 'text';
  let section: Section = 'none';

  // BSS address allocation
  let bssNext = BSS_BASE;
  // Rodata address allocation
  let rodataNext = RODATA_BASE;
  // Extern address counter
  let externNext = EXTERN_BASE;
  // String address counter
  let stringNext = STRING_BASE;

  // Track the last label seen (for .asciz association)
  let lastTextLabel: string | null = null;
  // Track the last rodata label (for .hword data)
  let lastRodataLabel: string | null = null;
  let lastRodataAddr = 0;

  // Text-section data (.byte/.word/.short/.hword under labels — used for the
  // vector asset tables emitted by pitrex/assets.rs).
  let textDataNext = TEXT_DATA_BASE;
  let textDataActive = false;
  // Forward references inside `.word SYMBOL` data — patched after the main
  // pass once every label has been seen.
  const pendingTextRefs: Array<{ addr: number; symbol: string }> = [];

  const writeMemByte = (addr: number, val: number): void => {
    const aligned = addr & ~3;
    const shift   = (addr & 3) * 8;
    const prev    = initMemory.get(aligned) ?? 0;
    initMemory.set(aligned, ((prev & ~(0xFF << shift)) | (((val & 0xFF) << shift) >>> 0)) | 0);
  };
  const writeMemHalf = (addr: number, val: number): void => {
    if ((addr & 1) !== 0) {
      writeMemByte(addr,     val & 0xFF);
      writeMemByte(addr + 1, (val >>> 8) & 0xFF);
      return;
    }
    const aligned = addr & ~3;
    const shift   = (addr & 2) * 8;
    const prev    = initMemory.get(aligned) ?? 0;
    initMemory.set(aligned, ((prev & ~(0xFFFF << shift)) | (((val & 0xFFFF) << shift) >>> 0)) | 0);
  };
  const writeMemWord = (addr: number, val: number): void => {
    if ((addr & 3) === 0) {
      initMemory.set(addr, val | 0);
      return;
    }
    for (let i = 0; i < 4; i++) writeMemByte(addr + i, (val >>> (i * 8)) & 0xFF);
  };

  for (let lineIdx = 0; lineIdx < lines.length; lineIdx++) {
    let line = lines[lineIdx];

    // Strip inline comment (@ starts a comment in ARM asm, // also used)
    const commentAt = line.indexOf('@');
    if (commentAt >= 0) line = line.slice(0, commentAt);
    const commentSlash = line.indexOf('//');
    if (commentSlash >= 0) line = line.slice(0, commentSlash);
    line = line.trim();

    if (!line) continue;

    // ── Section switches ────────────────────────────────────────────────
    if (line.startsWith('.section')) {
      textDataActive = false;
      if (line.includes('.bss'))    { section = 'bss';    continue; }
      if (line.includes('.rodata')) { section = 'rodata'; continue; }
      if (line.includes('.text'))   { section = 'text';   continue; }
      continue;
    }
    // Bare section directives (without .section prefix, e.g. just ".bss" or ".text")
    if (line === '.bss')  { section = 'bss';    textDataActive = false; continue; }
    if (line === '.text') { section = 'text';   textDataActive = false; continue; }
    // gcc emits initialized statics (s_intensity, s_psg_mixer, …) in a bare
    // `.data` section as `LABEL: .word/.byte`. Route it through the rodata path
    // so those bytes land in initMemory and their addresses resolve. (The VPy
    // pitrex backend never emits `.data`, so this only affects libvpy's vpy.s.)
    if (line === '.data') { section = 'rodata'; textDataActive = false; continue; }

    // ── Global .equ (can appear in bss or anywhere) ─────────────────────
    if (line.startsWith('.equ ') || line.startsWith('.equ\t')) {
      // .equ NAME, VALUE  or  .equ NAME, VALUE  @ comment
      const rest = line.slice(4).trim();
      const comma = rest.indexOf(',');
      if (comma >= 0) {
        const name = rest.slice(0, comma).trim();
        const valStr = rest.slice(comma + 1).trim();
        const v = parseNumber(valStr);
        if (name && v !== null) {
          equs.set(name, v);
          symbols.set(name, { kind: 'equ', value: v });
        }
      }
      continue;
    }

    // ── .extern declarations ────────────────────────────────────────────
    if (line.startsWith('.extern ') || line.startsWith('.extern\t')) {
      const name = line.slice(7).trim();
      if (name && !symbols.has(name)) {
        symbols.set(name, { kind: 'extern', value: externNext });
        externNext += 4;
      }
      continue;
    }

    // ── .set NAME, VALUE ────────────────────────────────────────────────
    // gcc names its section anchors this way: `.set .LANCHOR2, . + 0` binds
    // the anchor to the current location counter (`.`). movw/movt then load
    // :lower16:/:upper16: of the anchor to address the following data (e.g.
    // vpy_draw_circle addresses the s_sin table via .LANCHOR2). We align the
    // counter to 4 first — matching the alignment the very next data label
    // applies — so the anchor and the label resolve to the same address.
    // (Handled before SKIP_DIRECTIVES, which lists `.set`.)
    if (line.startsWith('.set ') || line.startsWith('.set\t')) {
      const rest  = line.slice(4).trim();
      const comma = rest.indexOf(',');
      if (comma >= 0) {
        const name   = rest.slice(0, comma).trim();
        const valStr = rest.slice(comma + 1).trim();
        let v: number | null = null;
        if (valStr.startsWith('.')) {
          // Location-counter-relative: "." / ". + N" / ". - N".
          let addr = section === 'bss' ? bssNext : rodataNext;
          addr = (addr + 3) & ~3;
          if (section === 'bss') bssNext = addr; else rodataNext = addr;
          const m = valStr.match(/^\.\s*([+-])\s*(\d+)/);
          v = m ? (m[1] === '-' ? addr - parseInt(m[2], 10) : addr + parseInt(m[2], 10)) : addr;
        } else {
          v = parseNumber(valStr);
        }
        if (name && v !== null) {
          equs.set(name, v);
          symbols.set(name, { kind: 'equ', value: v });
        }
      }
      continue;
    }

    // ── Skip directives with no useful data ────────────────────────────
    {
      const tok = line.split(/[\s\t]/)[0];
      if (SKIP_DIRECTIVES.has(tok)) continue;
    }

    // ── BSS section ─────────────────────────────────────────────────────
    if (section === 'bss') {
      // VPy form: "LABEL: .space N" (label + reservation on one line).
      const spaceMatch = line.match(/^(\w[\w.]*)\s*:\s*\.space\s+(\d+)/);
      if (spaceMatch) {
        const name = spaceMatch[1];
        const sz   = parseInt(spaceMatch[2], 10);
        bssNext = (bssNext + 3) & ~3; // align to 4
        symbols.set(name, { kind: 'bss', value: bssNext });
        bssNext += sz;
        continue;
      }
      // gcc form: bare "LABEL:" on its own line, reservation on the next.
      const bareLabel = line.match(/^(\w[\w.]*)\s*:\s*$/);
      if (bareLabel) {
        bssNext = (bssNext + 3) & ~3;
        symbols.set(bareLabel[1], { kind: 'bss', value: bssNext });
        continue;
      }
      // gcc form: bare ".space N" (reservation / padding) advances the counter.
      const bareSpace = line.match(/^\.space\s+(\d+)/);
      if (bareSpace) {
        bssNext += parseInt(bareSpace[1], 10);
        continue;
      }
      continue;
    }

    // ── Rodata section ──────────────────────────────────────────────────
    if (section === 'rodata') {
      // LABEL:
      const labelMatch = line.match(/^([\w.]+)\s*:/);
      if (labelMatch) {
        const name = labelMatch[1];
        rodataNext = (rodataNext + 3) & ~3;
        symbols.set(name, { kind: 'rodata', value: rodataNext });
        lastRodataLabel = name;
        lastRodataAddr = rodataNext;
        // No data emitted yet — .hword lines follow
        // (remainder of line after colon may have .align or nothing)
        continue;
      }

      // .hword N [, N, ...]   (one or more values on this line)
      if (line.startsWith('.hword') || line.startsWith('.short')) {
        const rest = line.replace(/^\.hword\s*|^\.short\s*/, '');
        const vals = rest.split(',').map(s => s.trim()).filter(Boolean);
        for (const vs of vals) {
          const v = parseNumber(vs);
          if (v !== null) {
            // Store as 16-bit value in a 32-bit slot (little-endian packing)
            const aligned = rodataNext & ~3;
            const shift   = (rodataNext & 2) * 8;
            const prev    = initMemory.get(aligned) ?? 0;
            initMemory.set(aligned, (prev & ~(0xFFFF << shift)) | (((v & 0xFFFF) << shift) >>> 0));
            rodataNext += 2;
          }
        }
        continue;
      }

      // .word N or .word SYMBOL  (4-byte pointer table entries for string arrays)
      if (line.startsWith('.word')) {
        rodataNext = (rodataNext + 3) & ~3; // ensure 4-byte alignment
        const rest = line.replace(/^\.word\s*/, '');
        const tokens = rest.split(',').map(t => t.trim()).filter(Boolean);
        for (const tok of tokens) {
          const num = parseNumber(tok);
          if (num !== null) writeMemWord(rodataNext, num);
          else              pendingTextRefs.push({ addr: rodataNext, symbol: tok });
          rodataNext += 4;
        }
        continue;
      }

      // .byte N [, N, ...] — store one or more bytes
      // Needed for tables emitted in rodata (e.g. _PITREX_SIN_TABLE, the 3D
      // vertex table). Without this they end up as zeros and any sin/cos or
      // rotation lookup silently returns 0.
      if (line.startsWith('.byte')) {
        const rest = line.replace(/^\.byte\s*/, '');
        const vals = rest.split(',').map(s => s.trim()).filter(Boolean);
        for (const vs of vals) {
          const v = parseNumber(vs);
          if (v !== null) {
            writeMemByte(rodataNext, v & 0xFF);
            rodataNext++;
          }
        }
        continue;
      }

      // .asciz "..." — null-terminated string bytes stored in initMemory
      const ascizMatch = line.match(/^\.asciz\s+"((?:[^"\\]|\\.)*)"/);
      if (ascizMatch) {
        const decoded = decodeAsmString(ascizMatch[1]);
        for (let i = 0; i < decoded.length; i++) {
          writeMemByte(rodataNext, decoded.charCodeAt(i) & 0xFF);
          rodataNext++;
        }
        writeMemByte(rodataNext, 0); // null terminator
        rodataNext++;
        continue;
      }

      // .ascii "..." — like .asciz but NO trailing null. gcc emits the libvpy
      // const tables (s_sin, glyph strokes) as one or more concatenated .ascii
      // lines; each appends its decoded bytes at the running rodata address.
      const asciiMatch = line.match(/^\.ascii\s+"((?:[^"\\]|\\.)*)"/);
      if (asciiMatch) {
        const decoded = decodeAsmString(asciiMatch[1]);
        for (let i = 0; i < decoded.length; i++) {
          writeMemByte(rodataNext, decoded.charCodeAt(i) & 0xFF);
          rodataNext++;
        }
        continue;
      }

      // .space N — zero-filled reservation / struct padding (advance counter).
      const rodataSpace = line.match(/^\.space\s+(\d+)/);
      if (rodataSpace) {
        rodataNext += parseInt(rodataSpace[1], 10);
        continue;
      }

      // .align or other rodata directives
      if (line.startsWith('.align')) {
        const n = parseInt(line.split(/\s+/)[1] ?? '2', 10);
        const align = 1 << n;
        rodataNext = (rodataNext + align - 1) & ~(align - 1);
      }
      // .balign N — align to N-byte boundary (N is the literal byte count, not log2)
      if (line.startsWith('.balign')) {
        const align = parseInt(line.split(/\s+/)[1] ?? '4', 10);
        if (align > 0) {
          rodataNext = (rodataNext + align - 1) & ~(align - 1);
        }
      }
      continue;
    }

    // ── Text section ────────────────────────────────────────────────────
    if (section === 'text') {
      // .asciz "..." — string data, no instruction
      const ascizMatch = line.match(/^\.asciz\s+"((?:[^"\\]|\\.)*)"/);
      if (ascizMatch) {
        if (lastTextLabel) {
          // Decode escape sequences in the string
          const decoded = decodeAsmString(ascizMatch[1]);
          strings.set(lastTextLabel, decoded);
          // Assign fake string address if not already in symbols.
          // Advance stringNext by actual string length + null terminator,
          // aligned to 4 bytes — otherwise consecutive strings overlap and
          // reads past the null run into the next string ("POLY" + "FILL" + …
          // would render as one concatenated blob).
          if (!symbols.has(lastTextLabel)) {
            symbols.set(lastTextLabel, { kind: 'string', value: stringNext });
            stringNext += decoded.length + 1;
            stringNext = (stringNext + 3) & ~3;
          }
        }
        continue;
      }

      // ── Label detection ──────────────────────────────────────────────
      // Lines can be "LABEL:" or "LABEL: instruction..."
      // Local numeric labels: "1:" or "2:"
      // Local ARM labels start with ".L" (".Larc_skip0:") — must check
      // BEFORE the dot-prefix directive skip below, otherwise these
      // branch targets disappear and conditional skips fall through.
      const labelMatch = line.match(/^([\w.]+)\s*:(.*)/);
      if (labelMatch) {
        const labelName = labelMatch[1];
        const rest      = labelMatch[2].trim();

        // Record label at CURRENT instruction index (even if we emit an instruction on the same line)
        if (/^\d+$/.test(labelName)) {
          // Numeric local label
          const n = parseInt(labelName, 10);
          numericLabels.push({ n, idx: instructions.length });
          labels.set(`__num_${n}_${numericLabels.length - 1}`, instructions.length);
        } else {
          labels.set(labelName, instructions.length);
        }
        lastTextLabel = labelName;

        if (rest) {
          // There is an instruction on the same line as the label
          line = rest;
          // Fall through to instruction parsing below
        } else {
          // Reset text-data tracking — if data directives follow this label,
          // they belong to a fresh data block addressed by `lastTextLabel`.
          textDataActive = false;
          continue;
        }
      }

      // ── Text-section data directives (.byte / .word / .short / .hword) ──
      // Asset tables emitted by pitrex/assets.rs live in the text section
      // and use these directives. Bind them to the most recent label and
      // store the bytes in initMemory so the runtime ldr/ldrb can read them.
      const dataMatch = line.match(/^\.(byte|word|short|hword)\s*(.*)$/);
      if (dataMatch) {
        const kind = dataMatch[1];
        const rest = dataMatch[2].trim();

        if (!textDataActive && lastTextLabel) {
          textDataNext = (textDataNext + 3) & ~3;
          // Override any prior code-label entry: this label addresses data,
          // not an instruction index. Branches to it shouldn't happen anyway.
          symbols.set(lastTextLabel, { kind: 'rodata', value: textDataNext });
          textDataActive = true;
        }

        const tokens = rest.split(',').map(t => t.trim()).filter(Boolean);
        for (const tok of tokens) {
          const num = parseNumber(tok);
          if (kind === 'word') {
            if (num !== null) writeMemWord(textDataNext, num);
            else              pendingTextRefs.push({ addr: textDataNext, symbol: tok });
            textDataNext += 4;
          } else if (kind === 'short' || kind === 'hword') {
            writeMemHalf(textDataNext, (num ?? 0) & 0xFFFF);
            textDataNext += 2;
          } else {
            writeMemByte(textDataNext, (num ?? 0) & 0xFF);
            textDataNext += 1;
          }
        }
        continue;
      }

      // .balign N inside text-data — keep textDataNext aligned to N bytes so
      // subsequent .word loads from the runtime hit the right offsets.
      if (line.startsWith('.balign')) {
        const align = parseInt(line.split(/\s+/)[1] ?? '4', 10);
        if (align > 0) {
          textDataNext = (textDataNext + align - 1) & ~(align - 1);
        }
        continue;
      }

      // Skip remaining directives in text section (after label handling,
      // so that `.Lfoo:` style local labels above are still registered).
      if (line.startsWith('.')) continue;

      // ── Instruction parsing ──────────────────────────────────────────
      // Split mnemonic from operands
      const spaceIdx = line.search(/[\s\t]/);
      let mnemonic: string;
      let opStr: string;
      if (spaceIdx < 0) {
        mnemonic = line;
        opStr    = '';
      } else {
        mnemonic = line.slice(0, spaceIdx);
        opStr    = line.slice(spaceIdx + 1).trim();
      }

      if (!mnemonic) continue;

      const { op, cond } = parseMnemonic(mnemonic);
      const operands = opStr ? splitOperands(opStr) : [];

      const instr: AsmInstruction = {
        op,
        cond,
        operands,
        lineNum: lineIdx + 1,
      };

      instructions.push(instr);
      textDataActive = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Post-process: resolve forward `.word SYMBOL` references inside text-data
  // blocks (e.g. the asset pointer tables). Symbols defined later in the file
  // are guaranteed to be known by now.
  // ---------------------------------------------------------------------------
  // Resolve a single operand of a data expression to a byte value:
  // a literal number, or a symbol/equ address. (Code labels are instruction
  // indices, not byte addresses, so they are intentionally NOT consulted here.)
  const resolveDataOperand = (name: string): number | null => {
    const n = parseNumber(name);
    if (n !== null) return n;
    const s = symbols.get(name);
    if (s) return s.value;
    const e = equs.get(name);
    if (e !== undefined) return e;
    return null;
  };
  for (const ref of pendingTextRefs) {
    // Support label arithmetic in `.word` data — crucially the offset tables
    // emitted by compile_vrec use `.word FRAME_LABEL - BASE_LABEL` to encode a
    // byte offset. Also handles `SYM + N` / `SYM - N`. Falls back to a plain
    // symbol lookup. Without this the whole table resolves to 0, which makes
    // DRAW_RECORDING read segment_count from the base (= frame_count) → garbage.
    const expr = ref.symbol.trim();
    const m = expr.match(/^(\S+)\s*([+-])\s*(\S+)$/);
    let val: number | null;
    if (m) {
      const a = resolveDataOperand(m[1]);
      const b = resolveDataOperand(m[3]);
      val = (a !== null && b !== null) ? (m[2] === '-' ? a - b : a + b) : null;
    } else {
      val = resolveDataOperand(expr);
    }
    if (val !== null) writeMemWord(ref.addr, val >>> 0);
  }

  return { equs, symbols, labels, numericLabels, strings, instructions, initMemory };
}

// ---------------------------------------------------------------------------
// Resolve a symbol reference for ldr =SYMBOL
// ---------------------------------------------------------------------------

export function resolveSymbol(name: string, parsed: ParsedAsm): number | null {
  // 1. Try as a plain number
  const num = parseNumber(name);
  if (num !== null) return num;

  // 2. Look up in symbols map (covers equs, bss, rodata, extern, string)
  const sym = parsed.symbols.get(name);
  if (sym) return sym.value;

  // 3. Try equs directly (redundant with symbols but kept for safety)
  const eq = parsed.equs.get(name);
  if (eq !== undefined) return eq;

  return null;
}
