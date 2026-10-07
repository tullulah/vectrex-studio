// The language API as the MCP tools see it: `api_reference` (full) and the compact `api`
// block of `ide_get_context`. Generated from real sources, never hand-maintained:
//
//   VPy  `vpy_cli builtins --json` — the compiler compiles a call to every builtin
//        candidate for each target (so availability per target is measured) and attaches
//        the doc line of docs/MANUAL.md section 9 (buildtools/vpy_cli/src/builtins_catalog.rs;
//        its tests fail when a builtin has no doc line).
//   C    the headers of the project's PINNED SDK: <sdk>/vpy-c/include/vpy.h (+ vpy3d.h and
//        the other vpy*.h modules on request), parsed here: prototypes, the comment on the
//        line or above each one, the "---- section ----" banners, and the VPY_SHORT_NAMES
//        aliases. So the reference is exactly what that SDK version declares.
//
// The "how to" block is a set of recipes; a recipe is only shown when every function it
// uses exists in the reference for this language and target, so it cannot advertise a
// call the compiler or SDK does not have (and picks up a new one, e.g. a rotation call,
// as soon as it exists).
//
// Pure Node (no electron import): the test harness loads it directly.

import { promises as fs } from 'fs';
import * as path from 'path';
import { spawn } from 'child_process';

export type Lang = 'vpy' | 'c';

export interface ApiEntry {
  /** VPy: builtin name. C: the function or macro name (vpy_draw_line, J1_BUTTON_1). */
  name: string;
  signature: string;
  doc: string;
  category: string;
  /** VPy: targets whose backend accepts it. */
  targets?: string[];
  alternatives?: string[];
  aliasOf?: string;
  /** C: the VPY_SHORT_NAMES alias (DRAW_LINE for vpy_draw_line). */
  short?: string;
  /** C: header it is declared in. */
  header?: string;
  kind?: 'function' | 'macro' | 'constant';
}

export interface ApiReference {
  language: Lang;
  /** Where it was generated from (compiler path / SDK version + headers). */
  source: string;
  entries: ApiEntry[];
  notes: string[];
  /** C: header → section banners with their text. */
  sections?: Array<{ header: string; title: string; text: string }>;
  /** C: other vpy*.h modules of the SDK (not parsed unless asked for). */
  modules?: Array<{ header: string; summary: string }>;
}

// ── shared helpers ──────────────────────────────────────────────────────────

function run(cmd: string, args: string[], timeoutMs = 120000): Promise<{ code: number; stdout: string; stderr: string }> {
  return new Promise((resolve) => {
    const child = spawn(cmd, args, { stdio: ['ignore', 'pipe', 'pipe'] });
    let stdout = '', stderr = '';
    const t = setTimeout(() => child.kill(), timeoutMs);
    child.stdout.on('data', (d) => { stdout += d; });
    child.stderr.on('data', (d) => { stderr += d; });
    child.on('error', (e) => { clearTimeout(t); resolve({ code: -1, stdout, stderr: String(e) }); });
    child.on('close', (code) => { clearTimeout(t); resolve({ code: code ?? -1, stdout, stderr }); });
  });
}

const DANGLING = /\s+(a|an|the|to|by|of|at|in|on|into|for|with|without|and|or|is|from|as|that|when|while|than|about|around|over|per|via|its|their)$/i;

/** Index of the first clause boundary (". ", ";", ":", ", ") outside () and []. */
function clauseEnd(s: string): number {
  let depth = 0;
  for (let i = 0; i < s.length; i++) {
    const c = s[i];
    if (c === '(' || c === '[') depth++;
    else if ((c === ')' || c === ']') && depth > 0) depth--;
    else if (depth === 0) {
      const atSpace = i + 1 === s.length || s[i + 1] === ' ';
      // "a: 0..127 = full circle" names a parameter: not a clause boundary.
      if (c === ':' && atSpace && !s.slice(0, i).includes(' ')) continue;
      if (c === ';' || ((c === ':' || c === ',' || c === '.') && atSpace && !(c === '.' && /\d/.test(s[i - 1] || '')))) return i;
    }
  }
  return s.length;
}

const wordsOutside = (s: string) => s.replace(/\([^()]*\)|\[[^\[\]]*\]/g, '').split(' ').filter(Boolean).length;

/**
 * The "purpose" of a doc line for the compact view: its first clause, at most `maxWords`
 * words (bracketed text not counted; dropped when the clause is still too long), never
 * ending on a dangling preposition. api_reference keeps the whole doc.
 */
export function shortDoc(doc: string, maxWords = 9, maxParenWords = 4): string {
  let s = (doc || '').replace(/\s+/g, ' ').trim();
  // Long asides ("(ARM only; on m6809 it ...)") are detail for api_reference.
  s = s.replace(/\s*\(([^()]*)\)/g, (m, inner: string) => (inner.includes(';') || inner.split(' ').length > maxParenWords ? '' : m));
  s = s.slice(0, clauseEnd(s)).trim();
  if (wordsOutside(s) > maxWords) {
    s = s.replace(/\s*\([^()]*\)|\s*\[[^\[\]]*\]/g, '');
    const words = s.split(' ');
    if (words.length > maxWords) s = words.slice(0, maxWords).join(' ');
  }
  if ((s.match(/[([]/g) || []).length > (s.match(/[)\]]/g) || []).length) s = s.slice(0, Math.max(s.lastIndexOf('('), s.lastIndexOf('['))).trim();
  s = s.replace(/[,.:;]$/, '');
  while (DANGLING.test(s)) s = s.replace(DANGLING, '');
  return s;
}

// ── VPy: the compiler's own catalog ────────────────────────────────────────

const vpyCache = new Map<string, ApiReference>();

/** `vpy_cli builtins --json`, cached per compiler build (path + mtime + size). */
export async function vpyReference(cli: string): Promise<ApiReference> {
  const st = await fs.stat(cli);
  const key = `${cli}|${st.mtimeMs}|${st.size}`;
  const hit = vpyCache.get(key);
  if (hit) return hit;
  const r = await run(cli, ['builtins', '--json']);
  const line = r.stdout.trim().split('\n').reverse().find((l) => l.startsWith('{'));
  if (!line) {
    if (/unrecognized subcommand|unexpected argument/i.test(r.stderr)) {
      throw new Error(`the bundled compiler (${cli}) has no "builtins" subcommand: rebuild it (run-ide.sh)`);
    }
    throw new Error(`vpy_cli builtins failed (exit ${r.code}): ${(r.stderr || r.stdout).trim().slice(-500)}`);
  }
  const j = JSON.parse(line);
  const entries: ApiEntry[] = (j.builtins || []).map((b: any) => ({
    name: b.name,
    signature: b.signature || `${b.name}(...)`,
    doc: b.doc || (b.aliasOf ? `Same as ${b.aliasOf}` : ''),
    category: b.category || (b.aliasOf ? 'Aliases' : 'Other'),
    targets: b.targets || [],
    ...(b.alternatives?.length ? { alternatives: b.alternatives } : {}),
    ...(b.aliasOf ? { aliasOf: b.aliasOf } : {}),
  }));
  const ref: ApiReference = {
    language: 'vpy',
    source: `vpy_cli ${j.compiler} builtins (each builtin compiled per target; docs: docs/MANUAL.md)`,
    entries,
    notes: j.notes || [],
  };
  vpyCache.set(key, ref);
  return ref;
}

// ── C: the pinned SDK's headers ─────────────────────────────────────────────

/** Strip comments, keeping string literals intact enough for declarations. */
function stripComments(s: string): string {
  return s.replace(/\/\*[\s\S]*?\*\//g, ' ').replace(/\/\/.*$/gm, ' ');
}

function cleanComment(raw: string): string {
  return raw
    .replace(/^\/\*+/, '').replace(/\*+\/$/, '')
    .split('\n').map((l) => l.replace(/^\s*\*\s?/, '').trim()).join(' ')
    .replace(/\s+/g, ' ').trim();
}

/** Remove `#ifdef __cplusplus ... #endif` blocks (extern "C" wrappers). */
function dropCplusplus(lines: string[]): string[] {
  const out: string[] = [];
  let skip = 0;
  for (const l of lines) {
    const t = l.trim();
    if (skip) {
      if (/^#\s*if/.test(t)) skip++;
      else if (/^#\s*endif/.test(t)) skip--;
      continue;
    }
    if (/^#\s*ifdef\s+__cplusplus\b/.test(t)) { skip = 1; continue; }
    out.push(l);
  }
  return out;
}

export interface ParsedHeader {
  header: string;
  summary: string;
  entries: ApiEntry[];
  sections: Array<{ header: string; title: string; text: string }>;
}

/**
 * Parse one libvpy header: function prototypes (with the comment on their line, or the
 * comment block right above them, which also covers the declarations that follow it without
 * a blank line), `---- section ----` banners as categories, VPY_* constants, and the
 * VPY_SHORT_NAMES aliases (`#define DRAW_LINE vpy_draw_line`, `#define J1_BUTTON_1() vpy_j1_button(1)`).
 */
export function parseCHeader(text: string, header: string): ParsedHeader {
  const lines = dropCplusplus(text.split(/\r?\n/));
  const entries: ApiEntry[] = [];
  const sections: ParsedHeader['sections'] = [];
  const shortOf = new Map<string, string>();
  const macros: ApiEntry[] = [];
  let summary = '';
  let category = 'general';
  let pendingComment = '';    // comment block that ended on the previous line
  let shortDepth = 0;         // inside #ifdef VPY_SHORT_NAMES (nesting depth)
  let braceDepth = 0;         // inside a struct/union body
  let stmt = '';
  let stmtTrailing = '';

  for (let i = 0; i < lines.length; i++) {
    let line = lines[i];
    const t = line.trim();

    // Comment blocks (possibly multi-line) that start the line.
    if (t.startsWith('/*') && !stmt) {
      let raw = line;
      while (!raw.includes('*/') && i + 1 < lines.length) raw += '\n' + lines[++i];
      const after = raw.slice(raw.indexOf('*/') + 2).trim();
      const body = raw.slice(raw.indexOf('/*'), raw.indexOf('*/') + 2);
      const text = cleanComment(body);
      if (!summary && entries.length === 0 && sections.length === 0) {
        summary = text.replace(/^[\w.]+\s+[—-]\s+/, '');
      }
      const banner = /^-{3,}\s*(.+?)\s*-{3,}\s*(.*)$/.exec(text);
      if (banner) {
        category = banner[1].trim();
        sections.push({ header, title: category, text: banner[2].trim() });
        pendingComment = '';
      } else {
        pendingComment = text;
      }
      if (!after) continue;
      line = after;
    }

    if (!t) { pendingComment = ''; continue; }

    if (/^#/.test(t)) {
      if (/^#\s*ifdef\s+VPY_SHORT_NAMES\b/.test(t)) { shortDepth = 1; continue; }
      if (shortDepth) {
        if (/^#\s*if/.test(t)) shortDepth++;
        else if (/^#\s*endif/.test(t)) { shortDepth--; continue; }
        const fn = /^#\s*define\s+([A-Za-z_]\w*)\(([^)]*)\)\s+(.+?)\s*(?:\/\*.*)?$/.exec(t);
        const obj = /^#\s*define\s+([A-Za-z_]\w*)\s+([A-Za-z_]\w*)\s*(?:\/\*.*)?$/.exec(t);
        if (fn) {
          const target = /^\(?\s*([A-Za-z_]\w*)\s*\(/.exec(fn[3]);
          macros.push({
            name: fn[1], signature: `${fn[1]}(${fn[2]})`, doc: pendingComment ? shortDoc(pendingComment, 14) : `${fn[3]}`,
            category: 'short names (VPY_SHORT_NAMES)', header, kind: 'macro',
            ...(target && target[1] !== 'void' ? { aliasOf: target[1] } : {}),
          });
          if (!pendingComment) macros[macros.length - 1].doc = `= ${fn[3]}`;
        } else if (obj) {
          shortOf.set(obj[2], obj[1]);
        }
        continue;
      }
      const c = /^#\s*define\s+(VPY\w*)\s+(\S+)\s*(?:\/\*\s*(.*?)\s*\*\/)?\s*$/.exec(t);
      if (c && !/_H$/.test(c[1])) {
        entries.push({ name: c[1], signature: `#define ${c[1]} ${c[2]}`, doc: c[3] || '', category, header, kind: 'constant' });
      }
      pendingComment = '';
      continue;
    }

    // Struct / typedef bodies are not API calls.
    const code = stripComments(line);
    if (braceDepth || /\{/.test(code)) {
      braceDepth += (code.match(/\{/g) || []).length - (code.match(/\}/g) || []).length;
      pendingComment = '';
      continue;
    }

    // Accumulate one statement up to ';'.
    const trailing = /\/\*\s*(.*?)\s*\*\/\s*$/.exec(line);
    stmt += ' ' + code;
    if (trailing) stmtTrailing = trailing[1];
    if (!code.includes(';')) continue;
    const s = stmt.replace(/\s+/g, ' ').trim();
    const own = stmtTrailing;
    stmt = ''; stmtTrailing = '';
    // A comment block documents the declaration right below it (not the ones after).
    const above = pendingComment;
    pendingComment = '';
    if (/^(typedef|extern|struct|enum|union)\b/.test(s)) continue;
    const m = /^(.*?)\b([A-Za-z_]\w*)\s*\(([^()]*(?:\([^()]*\)[^()]*)*)\)\s*;$/.exec(s);
    if (!m) continue;
    const ret = m[1].trim();
    if (!ret) continue;
    entries.push({
      name: m[2], signature: `${ret} ${m[2]}(${m[3].trim()})`.replace(/\s+\*/g, ' *').replace(/\* /g, '*'),
      doc: own || above, category, header, kind: 'function',
    });
  }
  for (const e of entries) if (e.kind === 'function' && shortOf.has(e.name)) e.short = shortOf.get(e.name);
  return { header, summary: shortDoc(summary, 16), entries: [...entries, ...macros], sections };
}

const cCache = new Map<string, ApiReference>();

/** The headers of a libvpy SDK install: <sdkDir>/vpy-c/include. */
export function cIncludeDir(sdkDir: string): string {
  return path.join(sdkDir, 'vpy-c', 'include');
}

/**
 * Reference for the SDK at `sdkDir` (version `version`): vpy.h + vpy3d.h by default, or the
 * given `headers` (e.g. ['vpyphys.h']). Cached per (version, header files' mtimes).
 */
export async function cReference(sdkDir: string, version: string, headers: string[] = ['vpy.h', 'vpy3d.h']): Promise<ApiReference> {
  const inc = cIncludeDir(sdkDir);
  let all: string[];
  try { all = (await fs.readdir(inc)).filter((f) => /^vpy\w*\.h$/.test(f)).sort(); } catch {
    throw new Error(`SDK ${version} has no ${inc} (is it installed?)`);
  }
  const want = headers.filter((h) => all.includes(h));
  if (!want.length) throw new Error(`SDK ${version} has none of ${headers.join(', ')} (it has: ${all.join(', ')})`);
  const stamps = await Promise.all(all.map(async (h) => `${h}:${(await fs.stat(path.join(inc, h))).mtimeMs}`));
  const key = `${sdkDir}|${version}|${want.join(',')}|${stamps.join(',')}`;
  const hit = cCache.get(key);
  if (hit) return hit;
  const entries: ApiEntry[] = [];
  const sections: ApiReference['sections'] = [];
  const modules: ApiReference['modules'] = [];
  for (const h of all) {
    const text = await fs.readFile(path.join(inc, h), 'utf-8');
    const p = parseCHeader(text, h);
    if (want.includes(h)) { entries.push(...p.entries); sections.push(...p.sections); }
    else modules.push({ header: h, summary: p.summary });
  }
  const ref: ApiReference = {
    language: 'c',
    source: `uvmc2-sdk ${version}: ${want.map((h) => 'vpy-c/include/' + h).join(', ')}`,
    entries, notes: [], sections, modules,
  };
  cCache.set(key, ref);
  return ref;
}

// ── views: compact (ide_get_context) and full (api_reference) ──────────────

/** Categories that are not something a game calls (filtered from the compact view). */
const VPY_COMPACT_SKIP = /injected|not working|sd launcher|aliases/i;
const C_COMPACT_SKIP = /stroke buffer|lifecycle|short names|pool sizes/i;

function paramsOf(signature: string): string {
  const m = /\(([\s\S]*)\)\s*$/.exec(signature);
  return m ? m[1] : '';
}

/** C prototype → `DRAW_LINE(x0, y0, x1, y1, b) -> int` (short name, parameter names only). */
export function cCall(e: ApiEntry): string {
  if (e.kind === 'macro') return e.signature;
  const ret = e.signature.slice(0, e.signature.indexOf(e.name)).trim();
  const params = paramsOf(e.signature).split(',').map((p) => p.trim()).filter((p) => p && p !== 'void')
    .map((p) => {
      if (/\(\s*\*\s*(\w+)\s*\)/.test(p)) return /\(\s*\*\s*(\w+)\s*\)/.exec(p)![1];
      const m = /([A-Za-z_]\w*)\s*(\[[^\]]*\])?$/.exec(p);
      return m ? m[1] : p;
    });
  return `${e.short || e.name}(${params.join(', ')})${ret && ret !== 'void' ? ' -> ' + ret.replace(/\s+\*/g, '*') : ''}`;
}

function collapseNumbered(lines: Array<{ name: string; text: string }>): string[] {
  // J1_BUTTON_1() … J1_BUTTON_4(): one line when the members differ only by a trailing digit.
  const out: string[] = [];
  for (let i = 0; i < lines.length; i++) {
    const m = /^(.*?)(\d)$/.exec(lines[i].name);
    if (m) {
      let j = i;
      while (j + 1 < lines.length && new RegExp(`^${m[1].replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\d$`).test(lines[j + 1].name)) j++;
      if (j > i) {
        out.push(lines[i].text.replace(lines[i].name, `${lines[i].name}..${lines[j].name.slice(m[1].length)}`));
        i = j;
        continue;
      }
    }
    out.push(lines[i].text);
  }
  return out;
}

/** "A() — p" + "B() — p" → "A() / B() — p" (accessor families: GET_SCROLL_LIMIT_*, GET_ENEMY_X/Y...). */
function mergeSamePurpose(lines: string[]): string[] {
  const order: string[] = [];
  const by = new Map<string, string[]>();
  for (const l of lines) {
    const i = l.lastIndexOf(' — ');
    const key = i > 0 ? l.slice(i) : '\u0000' + l;
    if (!by.has(key)) { by.set(key, []); order.push(key); }
    by.get(key)!.push(i > 0 ? l.slice(0, i) : l);
  }
  return order.map((k) => joinFamily(by.get(k)!) + (k.startsWith('\u0000') ? '' : k));
}

/** ["GET_X_LEFT()", "GET_X_RIGHT()"] → "GET_X_LEFT/RIGHT()" when the arguments match; else "a / b". */
function joinFamily(sigs: string[]): string {
  if (sigs.length < 2) return sigs.join('');
  const parts = sigs.map((x) => /^([A-Za-z_]\w*?)_([A-Za-z0-9]+)(\(.*\))$/.exec(x));
  if (parts.every((p) => p && p[1] === parts[0]![1] && p[3] === parts[0]![3])) {
    return `${parts[0]![1]}_${parts.map((p) => p![2]).join('/')}${parts[0]![3]}`;
  }
  return sigs.join(' / ');
}

export interface CompactApi {
  /** (language and target are the context's project.kind and buildTarget) */
  source: string;
  /** category → one line per call: "SIGNATURE — purpose". */
  functions: Record<string, string[]>;
  howTo: string[];
  modules?: string;
  more: string;
}

function has(ref: ApiReference, name: string, target?: string): boolean {
  const e = ref.entries.find((x) => x.name.toUpperCase() === name.toUpperCase());
  if (!e) return false;
  return !target || !e.targets || e.targets.includes(target);
}

/** C display name: the VPY_SHORT_NAMES alias when there is one. */
function cName(ref: ApiReference, name: string): string {
  const e = ref.entries.find((x) => x.name === name);
  return e?.short || name;
}

// Recipes. `uses` must all exist (on the target) for a recipe to be shown; `{fn}` in the
// text is replaced by the C display name of fn. The first matching recipe of each need wins,
// unless `also` is set (then every matching one is shown).
interface Recipe { need: string; uses: string[]; text: string | ((ref: ApiReference) => string); also?: boolean }

const VPY_RECIPES: Recipe[] = [
  { need: 'rotate a sprite', also: true, uses: ['DRAW_VECTOR_ROT'], text: (r) => {
    const e = r.entries.find((x) => x.name.toUpperCase() === 'DRAW_VECTOR_ROT')!;
    // The practical form: the sprite name filled in, optional arguments left to the function list.
    return `${e.signature.replace(/\[.*\]/, '').replace('"name"', '"ship"')} — ${shortDoc(e.doc, 20, 20)}`;
  } },
  { need: 'rotate a sprite', also: true, uses: ['DRAW_VECTOR_3D'], text: 'DRAW_VECTOR_3D("ship", 0, 0, angle, x, y): az = turn in the screen plane, 0..127 per turn' },
  { need: 'rotate a sprite', uses: ['SIN', 'COS', 'DRAW_LINE'], text: 'rx = (x*cos(a) - y*sin(a)) / 127, ry = (x*sin(a) + y*cos(a)) / 127 (a = 0..127 per turn)' },
  { need: 'many objects', uses: ['DRAW_VECTOR'], text: 'global arrays xs = [0, 0, 0] ...; for i in range(0, len(xs)): DRAW_VECTOR("rock", xs[i], ys[i])' },
  { need: 'music and sound effects', uses: ['PLAY_MUSIC', 'PLAY_SFX'], text: 'PLAY_MUSIC("theme") once in main(); PLAY_SFX("laser") on the event; updates are automatic' },
  { need: 'joystick and buttons', uses: ['J1_X', 'J1_BUTTON_1'], text: 'J1_X() / J1_Y() -127..127; J1_BUTTON_1() is 1 while held: compare with last frame for a press' },
  { need: 'text and score', uses: ['PRINT_TEXT', 'PRINT_NUMBER'], text: 'PRINT_TEXT(-120, 110, "SCORE"); PRINT_NUMBER(-40, 110, score) each frame' },
  { need: 'random numbers', uses: ['RAND_RANGE'], text: 'rand_range(lo, hi), rand()' },
  { need: 'collisions', uses: ['ABS'], text: 'box test: if abs(ax - bx) < 10 and abs(ay - by) < 10:' },
  { need: 'levels', uses: ['LOAD_LEVEL', 'SHOW_LEVEL', 'LEVEL_COLLISION_Y'], text: 'LOAD_LEVEL("level1") in main(), SHOW_LEVEL() in loop(), y = LEVEL_COLLISION_Y(x, y, half_h)' },
];

const C_RECIPES: Recipe[] = [
  { need: 'rotate a sprite', uses: ['vpy_draw_vector_rot'], text: (r) => {
    const e = r.entries.find((x) => x.name === 'vpy_draw_vector_rot')!;
    return `${cCall(e).replace(/\(data,/, '(SHIP_vec,')} — ${shortDoc(e.doc, 20, 20) || 'draws a compiled .vec rotated'}`;
  } },
  { need: 'rotate a sprite', uses: ['vpy_sin', 'vpy_cos', 'vpy_draw_line'], text: 'no sprite rotation call in this SDK: rotate the points yourself, rx = (x*{vpy_cos}(a) - y*{vpy_sin}(a)) / 127 (a = 0..127 per turn), then {vpy_draw_line}; real 3D: a .vmesh with vpy3d.h' },
  { need: 'many objects', uses: ['vpy_draw_vector'], text: 'static struct { int x, y, alive; } rocks[8]; for (...) if (rocks[i].alive) {vpy_draw_vector}(ROCK_vec, rocks[i].x, rocks[i].y);' },
  { need: 'music and sound effects', uses: ['vpy_play_music', 'vpy_play_sfx'], text: '#include "theme.h" (from assets/music/theme.vmus) then {vpy_play_music}(THEME_music) in setup(), {vpy_play_sfx}(LASER_sfx) on the event; vpy_run updates both' },
  { need: 'joystick and buttons', uses: ['vpy_j1_x', 'vpy_j1_button'], text: '{vpy_j1_x}() / {vpy_j1_y}() = -127..127; vpy_j1_button(n) / J1_BUTTON_1() = 1 while held: keep last frame\'s value to act once per press' },
  { need: 'text and score', uses: ['vpy_print_text', 'vpy_print_number'], text: '{vpy_print_text}(-120, 110, "SCORE"); {vpy_print_number}(-40, 110, score); every frame' },
  { need: 'random numbers', uses: ['vpy_rand_range'], text: 'vpy_rand_range(lo, hi), vpy_rand(); vpy_seed(n) once' },
  { need: 'collisions', uses: ['vpy_abs'], text: 'box test: vpy_abs(ax - bx) < 10 && vpy_abs(ay - by) < 10 (no sprite-vs-sprite call)' },
  { need: 'levels', uses: ['vpy_load_level', 'vpy_show_level', 'vpy_level_collision_y'], text: '#include "level1.h"; {vpy_load_level}(LEVEL1_level, LEVEL1_level_sprites) in setup(), {vpy_show_level}() in loop(); {vpy_level_collision_y}(x, y, half_h)' },
];

export function howTo(ref: ApiReference, target?: string): string[] {
  const recipes = ref.language === 'c' ? C_RECIPES : VPY_RECIPES;
  const out: string[] = [];
  const matched = new Set<string>();
  for (const r of recipes) {
    // `also` recipes all show; a plain one is the fallback when none before it matched.
    if (matched.has(r.need) && !r.also) continue;
    if (!r.uses.every((u) => has(ref, u, ref.language === 'vpy' ? target : undefined))) continue;
    let text = typeof r.text === 'function' ? r.text(ref) : r.text;
    if (ref.language === 'c') text = text.replace(/\{(\w+)\}/g, (_, n) => cName(ref, n));
    out.push(`${r.need}: ${text}`);
    matched.add(r.need);
  }
  return out;
}

/** The compact view for ide_get_context: what a game calls, one short line each. */
export function compactApi(ref: ApiReference, target?: string): CompactApi {
  const functions: Record<string, Array<{ name: string; text: string }>> = {};
  if (ref.language === 'vpy') {
    for (const e of ref.entries) {
      if (e.aliasOf || VPY_COMPACT_SKIP.test(e.category) || /^Short names? of|debug/i.test(e.doc)) continue;
      if (target && e.targets && !e.targets.includes(target)) continue;
      (functions[e.category] ||= []).push({ name: e.name, text: `${e.signature} — ${shortDoc(e.doc)}` });
    }
  } else {
    for (const e of ref.entries) {
      if (e.kind !== 'function' || e.header !== 'vpy.h' || C_COMPACT_SKIP.test(e.category)) continue;
      if (/^vpy_(font_|peek_|draw_line_dev|draw_stats|pending|get_priority|init$|frame_begin)/.test(e.name)) continue;
      const cat = e.category.replace(/\s*\(.*$/, '');
      (functions[cat] ||= []).push({ name: e.short || e.name, text: `${cCall(e)} — ${shortDoc(e.doc)}`.replace(/ — $/, '') });
    }
  }
  const out: Record<string, string[]> = {};
  for (const [k, v] of Object.entries(functions)) out[k] = mergeSamePurpose(collapseNumbered(v));
  const total = ref.entries.filter((e) => e.kind !== 'constant').length;
  const compact: CompactApi = {
    source: ref.language === 'vpy' ? ref.source.replace(/ \(.*$/, '') : ref.source.replace(/vpy-c\/include\//g, ''),
    functions: out,
    howTo: howTo(ref, target),
    more: `api_reference {topic?, query?}: all ${total} entries${ref.language === 'vpy' ? ' + targets' : ', vpy3d.h, modules'}`,
  };
  if (ref.language === 'c') {
    const n3d = ref.entries.filter((e) => e.header === 'vpy3d.h' && e.kind === 'function').length;
    const mods = (ref.modules || []).map((m) => m.header.replace(/\.h$/, ''));
    compact.modules = `${n3d ? `vpy3d.h (${n3d} functions: meshes, camera, perspective; topic "vpy3d"); ` : ''}also ${mods.join(', ')} (topic = header name)`;
  }
  return compact;
}

/** Topics api_reference accepts: the categories, plus "howto" (and the headers for C). */
export function topicsOf(ref: ApiReference): string[] {
  const cats = [...new Set(ref.entries.map((e) => e.category))];
  const headers = ref.language === 'c' ? [...new Set(ref.entries.map((e) => e.header!)), ...(ref.modules || []).map((m) => m.header)] : [];
  return [...cats, ...headers.map((h) => h.replace(/\.h$/, '')), 'howto'];
}

/** Filter for api_reference: topic = category (prefix, case-insensitive) or header; query = substring/regex on name+doc. */
export function filterEntries(ref: ApiReference, opts: { topic?: string; query?: string; target?: string }): ApiEntry[] {
  let list = ref.entries;
  if (opts.topic) {
    const t = opts.topic.toLowerCase().replace(/\.h$/, '');
    list = list.filter((e) => e.category.toLowerCase().includes(t) || (e.header && e.header.replace(/\.h$/, '').toLowerCase() === t));
  }
  if (opts.query) {
    let re: RegExp;
    try { re = new RegExp(opts.query, 'i'); } catch { re = new RegExp(opts.query.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'i'); }
    list = list.filter((e) => re.test(e.name) || re.test(e.short || '') || re.test(e.signature) || re.test(e.doc) || re.test(e.category));
  }
  return list;
}
