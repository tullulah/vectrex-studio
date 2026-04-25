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
      if (line.includes('.bss'))    { section = 'bss';    continue; }
      if (line.includes('.rodata')) { section = 'rodata'; continue; }
      if (line.includes('.text'))   { section = 'text';   continue; }
      continue;
    }

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

    // ── Skip directives with no useful data ────────────────────────────
    {
      const tok = line.split(/[\s\t]/)[0];
      if (SKIP_DIRECTIVES.has(tok)) continue;
    }

    // ── BSS section ─────────────────────────────────────────────────────
    if (section === 'bss') {
      // LABEL: .space N
      const spaceMatch = line.match(/^(\w[\w.]*)\s*:\s*\.space\s+(\d+)/);
      if (spaceMatch) {
        const name = spaceMatch[1];
        const sz   = parseInt(spaceMatch[2], 10);
        bssNext = (bssNext + 3) & ~3; // align to 4
        symbols.set(name, { kind: 'bss', value: bssNext });
        bssNext += sz;
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

      // .align or other rodata directives
      if (line.startsWith('.align')) {
        const n = parseInt(line.split(/\s+/)[1] ?? '2', 10);
        const align = 1 << n;
        rodataNext = (rodataNext + align - 1) & ~(align - 1);
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
          const raw = ascizMatch[1];
          const decoded = raw
            .replace(/\\x([0-9a-fA-F]{2})/g, (_m, h) => String.fromCharCode(parseInt(h, 16)))
            .replace(/\\n/g, '\n')
            .replace(/\\r/g, '\r')
            .replace(/\\t/g, '\t')
            .replace(/\\0/g, '\0')
            .replace(/\\\\/g, '\\');
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
          continue;
        }
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
    }
  }

  // ---------------------------------------------------------------------------
  // Post-process: resolve =SYMBOL in operands to numeric values, record which
  // are ldr-literal operands so the executor doesn't need to re-scan symbols.
  // We do this as a lightweight pass — the executor handles it at runtime.
  // ---------------------------------------------------------------------------

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
