// SDK manager — the uvmc2-sdk is no longer bundled with the IDE.
//
// Each project pins an SDK version in its project file (`[sdk] version = "vX.Y.Z"`, in
// both .vpyproj and .cvproj). The IDE downloads that tag from GitHub on demand into a
// versioned folder, ~/VectrexStudio/sdk/<tag>/, and hands its paths to every consumer
// (vpy_cli, the WASM simulator build, external C makefiles) through the environment.
//
// The SDK locates its own parts relative to itself (uvm2.mk, uvm2_pico.cmake), so a
// plain extracted tarball of a tag is a complete install: no git, no build step.

import { promises as fs, createWriteStream } from 'fs';
import { basename, delimiter, dirname, join } from 'path';
import * as os from 'os';
import { spawn } from 'child_process';

export const SDK_REPO = 'tullulah/uvmc2-sdk';

/** Marker written last: a folder without it is an interrupted install, never used. */
const COMPLETE_MARKER = '.vectrex-studio-sdk.json';

/** Tags look like v1.3.1. Anything else is refused — the tag becomes a folder name. */
const TAG_RE = /^v\d+(\.\d+){0,3}$/;

export function isValidSdkTag(tag: unknown): tag is string {
  return typeof tag === 'string' && TAG_RE.test(tag);
}

export function sdkRootDir(): string {
  return process.env.VECTREX_STUDIO_SDK_DIR || join(os.homedir(), 'VectrexStudio', 'sdk');
}

export function sdkDirFor(tag: string): string {
  return join(sdkRootDir(), tag);
}

/** Newest first. v1.10 > v1.9, and v1.2 < v1.2.1. */
export function compareTagsDesc(a: string, b: string): number {
  const pa = a.replace(/^v/, '').split('.').map(Number);
  const pb = b.replace(/^v/, '').split('.').map(Number);
  for (let i = 0; i < Math.max(pa.length, pb.length); i++) {
    const d = (pb[i] ?? -1) - (pa[i] ?? -1);
    if (d !== 0) return d;
  }
  return 0;
}

// ─── Installed versions ────────────────────────────────────────────────────

export async function isSdkInstalled(tag: string): Promise<boolean> {
  if (!isValidSdkTag(tag)) return false;
  try {
    await fs.access(join(sdkDirFor(tag), COMPLETE_MARKER));
    return true;
  } catch {
    return false;
  }
}

export async function listInstalledSdks(): Promise<string[]> {
  let entries: string[] = [];
  try {
    entries = await fs.readdir(sdkRootDir());
  } catch {
    return [];
  }
  const out: string[] = [];
  for (const e of entries) {
    if (isValidSdkTag(e) && await isSdkInstalled(e)) out.push(e);
  }
  return out.sort(compareTagsDesc);
}

// ─── Remote tags ───────────────────────────────────────────────────────────

let remoteCache: { at: number; tags: string[] } | null = null;
const REMOTE_TTL_MS = 10 * 60 * 1000;

/** Tags published on GitHub, newest first, or null when GitHub can't be reached. */
export async function listRemoteSdkTags(force = false): Promise<string[] | null> {
  if (!force && remoteCache && Date.now() - remoteCache.at < REMOTE_TTL_MS) return remoteCache.tags;
  try {
    const res = await fetch(`https://api.github.com/repos/${SDK_REPO}/tags?per_page=100`, {
      headers: { Accept: 'application/vnd.github+json', 'User-Agent': 'VectrexStudio' },
      signal: AbortSignal.timeout(10_000),
    });
    if (!res.ok) return remoteCache?.tags ?? null;
    const body = (await res.json()) as Array<{ name: string }>;
    const tags = body.map(t => t.name).filter(isValidSdkTag).sort(compareTagsDesc);
    remoteCache = { at: Date.now(), tags };
    return tags;
  } catch {
    return remoteCache?.tags ?? null;
  }
}

/** The newest tag on GitHub; offline, the newest one installed. */
export async function latestSdkTag(): Promise<string | null> {
  const remote = await listRemoteSdkTags();
  if (remote && remote.length) return remote[0];
  const installed = await listInstalledSdks();
  return installed[0] ?? null;
}

// ─── Install ───────────────────────────────────────────────────────────────

export type SdkProgress = { tag: string; phase: 'download' | 'extract' | 'done'; received: number; total: number | null };

const inFlight = new Map<string, Promise<string>>();

/** Make sure `tag` is installed; download and extract it if not. Returns its folder. */
export function ensureSdk(tag: string, onProgress?: (p: SdkProgress) => void): Promise<string> {
  if (!isValidSdkTag(tag)) return Promise.reject(new Error(`Invalid SDK version "${tag}"`));
  const running = inFlight.get(tag);
  if (running) return running;
  const p = installSdk(tag, onProgress).finally(() => inFlight.delete(tag));
  inFlight.set(tag, p);
  return p;
}

function installSdk(tag: string, onProgress?: (p: SdkProgress) => void): Promise<string> {
  return installTarball({
    what: `SDK ${tag}`,
    url: `https://codeload.github.com/${SDK_REPO}/tar.gz/refs/tags/${tag}`,
    root: sdkRootDir(),
    name: tag,
    mustContain: join('uvm2-sdk', 'uvm2_bus.c'),
    marker: { tag, repo: SDK_REPO },
    progressTag: tag,
    onProgress,
  });
}

/**
 * Download a GitHub tag tarball and install it as <root>/<name>, atomically: it is
 * extracted next to the destination, checked, marked complete, then renamed into place.
 * Already installed (marker present) → returns at once.
 */
async function installTarball(o: {
  what: string; url: string; root: string; name: string; mustContain: string;
  marker: Record<string, string>; progressTag: string; onProgress?: (p: SdkProgress) => void;
}): Promise<string> {
  const dest = join(o.root, o.name);
  try {
    await fs.access(join(dest, COMPLETE_MARKER));
    return dest;
  } catch { /* not installed */ }

  await fs.mkdir(o.root, { recursive: true });
  const stamp = `${process.pid}-${Date.now()}`;
  const tarball = join(o.root, `.download-${o.name}-${stamp}.tar.gz`);
  const staging = join(o.root, `.extract-${o.name}-${stamp}`);
  const tag = o.progressTag;

  try {
    // 1. Download the tag's source tarball (public repo: no token needed).
    const res = await fetch(o.url, { headers: { 'User-Agent': 'VectrexStudio' } });
    if (!res.ok || !res.body) {
      throw new Error(res.status === 404
        ? `${o.what} does not exist (${o.url})`
        : `Download failed for ${o.what}: HTTP ${res.status}`);
    }
    const total = Number(res.headers.get('content-length')) || null;
    let received = 0;
    const out = createWriteStream(tarball);
    const reader = res.body.getReader();
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      received += value.length;
      if (!out.write(value)) await new Promise<void>(r => out.once('drain', () => r()));
      o.onProgress?.({ tag, phase: 'download', received, total });
    }
    await new Promise<void>((resolve, reject) => out.end((err?: Error | null) => (err ? reject(err) : resolve())));

    // 2. Extract next to the final folder, so the rename below is atomic.
    o.onProgress?.({ tag, phase: 'extract', received, total });
    await fs.mkdir(staging, { recursive: true });
    await runTar(['-xzf', tarball, '-C', staging, '--strip-components=1']);

    // 3. Refuse a tarball that isn't what we expected.
    try {
      await fs.access(join(staging, o.mustContain));
    } catch {
      throw new Error(`${o.what} downloaded but its layout is not recognised (no ${o.mustContain})`);
    }
    await fs.writeFile(join(staging, COMPLETE_MARKER), JSON.stringify({
      ...o.marker, installedAt: new Date().toISOString(),
    }, null, 2) + '\n');

    // 4. Publish. A leftover folder without the marker is a broken earlier attempt.
    await fs.rm(dest, { recursive: true, force: true });
    await fs.rename(staging, dest);
    o.onProgress?.({ tag, phase: 'done', received, total });
    return dest;
  } finally {
    await fs.rm(tarball, { force: true }).catch(() => {});
    await fs.rm(staging, { recursive: true, force: true }).catch(() => {});
  }
}

// ─── pico-sdk (uvm2 builds) ────────────────────────────────────────────────
//
// The Raspberry Pi pico-sdk is too big to ship inside the SDK, and it is pinned, not
// "latest": the startup contract the multicart loader validates (IMAGE_DEF block,
// no_flash binary type, the weak isr_svcall the SDK overrides) can move between
// releases. An SDK may name its pico-sdk in a PICO_SDK_VERSION file at its root;
// every SDK tag so far uses 2.2.0. Installed without submodules (TinyUSB, lwIP,
// BTstack, mbedTLS), which no uvm2 image enables — same as the starter kit's setup.sh.

export const DEFAULT_PICO_SDK_VERSION = '2.2.0';
const PICO_SDK_REPO = 'raspberrypi/pico-sdk';
const PICO_VERSION_RE = /^\d+\.\d+\.\d+$/;

export function picoSdkRootDir(): string {
  return process.env.VECTREX_STUDIO_PICO_SDK_DIR || join(os.homedir(), 'VectrexStudio', 'pico-sdk');
}

/** The pico-sdk version an installed SDK asks for. */
export async function picoSdkVersionFor(sdkDir: string): Promise<string> {
  try {
    const v = (await fs.readFile(join(sdkDir, 'PICO_SDK_VERSION'), 'utf-8')).trim();
    if (PICO_VERSION_RE.test(v)) return v;
  } catch { /* file absent: every SDK tag so far */ }
  return DEFAULT_PICO_SDK_VERSION;
}

const picoInFlight = new Map<string, Promise<string>>();

/** Make sure pico-sdk `version` is installed; download it if not. Returns its folder. */
export function ensurePicoSdk(version: string, onProgress?: (p: SdkProgress) => void): Promise<string> {
  if (!PICO_VERSION_RE.test(version)) return Promise.reject(new Error(`Invalid pico-sdk version "${version}"`));
  const running = picoInFlight.get(version);
  if (running) return running;
  const p = installTarball({
    what: `pico-sdk ${version}`,
    url: `https://codeload.github.com/${PICO_SDK_REPO}/tar.gz/refs/tags/${version}`,
    root: picoSdkRootDir(),
    name: version,
    mustContain: 'pico_sdk_init.cmake',
    marker: { version, repo: PICO_SDK_REPO },
    progressTag: `pico-sdk-${version}`,
    onProgress,
  }).finally(() => picoInFlight.delete(version));
  picoInFlight.set(version, p);
  return p;
}

/** bsdtar ships with macOS and Windows 10+, GNU tar with Linux; both take these flags. */
function runTar(args: string[]): Promise<void> {
  return new Promise((resolve, reject) => {
    const child = spawn('tar', args, { stdio: ['ignore', 'ignore', 'pipe'] });
    let err = '';
    child.stderr.on('data', (c: Buffer) => { err += c.toString(); });
    child.on('error', reject);
    child.on('close', code => (code === 0 ? resolve() : reject(new Error(`tar exited ${code}: ${err.trim()}`))));
  });
}

// ─── Environment for consumers ─────────────────────────────────────────────

/** Every variable an SDK consumer reads: vpy_cli, the simulator build, makefiles. */
export function sdkEnv(dir: string, picoSdkDir?: string): Record<string, string> {
  return {
    ...(picoSdkDir ? { UVM2_PICO_SDK: picoSdkDir, PICO_SDK_PATH: picoSdkDir } : {}),
    UVMC2_SDK: dir,
    UVM2_SDK_DIR: join(dir, 'uvm2-sdk'),   // vpy_cli
    VPY_C_DIR: join(dir, 'vpy-c'),         // vpy_cli
    VPY_C_SDK: join(dir, 'vpy-c'),         // makefiles, simulator build
    PITREX_SIM_SDK: join(dir, 'pitrex-sim'),
    RP2350_SDK: join(dir, 'rp2350-sdk'),
  };
}

// ─── `[sdk] version` in a project file ─────────────────────────────────────
//
// Read with a regex over the [sdk] table and written by editing only that line, so
// the rest of the file — comments and layout included — is left exactly as it was.

const TABLE_HEADER_RE = /^\s*\[\[?\s*([^\]]+?)\s*\]\]?\s*(#.*)?$/;
const VERSION_LINE_RE = /^(\s*version\s*=\s*)(["'])([^"']*)\2(.*)$/;

function findSdkTable(lines: string[]): { start: number; end: number } | null {
  let start = -1;
  for (let i = 0; i < lines.length; i++) {
    const m = TABLE_HEADER_RE.exec(lines[i]);
    if (!m) continue;
    if (start >= 0) return { start, end: i };
    if (m[1] === 'sdk') start = i;
  }
  return start >= 0 ? { start, end: lines.length } : null;
}

export function readSdkVersionFromText(text: string): string | null {
  const lines = text.split(/\r?\n/);
  const table = findSdkTable(lines);
  if (!table) return null;
  for (let i = table.start + 1; i < table.end; i++) {
    const m = VERSION_LINE_RE.exec(lines[i]);
    if (m) return m[3].trim() || null;
  }
  return null;
}

export function writeSdkVersionToText(text: string, tag: string): string {
  const eol = text.includes('\r\n') ? '\r\n' : '\n';
  const lines = text.split(/\r?\n/);
  const table = findSdkTable(lines);
  if (table) {
    for (let i = table.start + 1; i < table.end; i++) {
      const m = VERSION_LINE_RE.exec(lines[i]);
      if (m) {
        lines[i] = `${m[1]}${m[2]}${tag}${m[2]}${m[4]}`;
        return lines.join(eol);
      }
    }
    lines.splice(table.start + 1, 0, `version = "${tag}"`);
    return lines.join(eol);
  }
  let body = lines.join(eol);
  if (!body.endsWith(eol)) body += eol;
  return `${body}${eol}[sdk]${eol}version = "${tag}"${eol}`;
}

export async function readProjectSdkVersion(projectFile: string): Promise<string | null> {
  return readSdkVersionFromText(await fs.readFile(projectFile, 'utf-8'));
}

export async function writeProjectSdkVersion(projectFile: string, tag: string): Promise<void> {
  if (!isValidSdkTag(tag)) throw new Error(`Invalid SDK version "${tag}"`);
  const text = await fs.readFile(projectFile, 'utf-8');
  await fs.writeFile(projectFile, writeSdkVersionToText(text, tag), 'utf-8');
}

// ─── Resolution ────────────────────────────────────────────────────────────

export type ProjectSdk = { version: string; pinned: boolean };

/**
 * The SDK version a project uses. A project without one is pinned to the latest tag
 * (or, offline, the newest installed) and the file is updated, so its builds stay
 * reproducible from then on. `pinned` says this call wrote it.
 */
export async function projectSdkVersion(projectFile: string): Promise<ProjectSdk | { error: string }> {
  const current = await readProjectSdkVersion(projectFile);
  if (current) {
    if (!isValidSdkTag(current)) return { error: `Invalid [sdk] version "${current}" in ${projectFile}` };
    return { version: current, pinned: false };
  }
  const latest = await latestSdkTag();
  if (!latest) {
    return { error: `The project has no [sdk] version, GitHub (${SDK_REPO}) can't be reached and no SDK is installed in ${sdkRootDir()}` };
  }
  await writeProjectSdkVersion(projectFile, latest);
  return { version: latest, pinned: true };
}

/**
 * Version + installed folder for a project, downloading the SDK if needed. With
 * `pico: true` (uvm2 builds) also the pico-sdk that SDK asks for, downloaded if needed.
 */
export async function resolveProjectSdk(
  projectFile: string,
  log: (line: string) => void,
  onProgress?: (p: SdkProgress) => void,
  opts: { pico?: boolean } = {},
): Promise<{ version: string; dir: string; picoSdkDir?: string } | { error: string }> {
  const v = await projectSdkVersion(projectFile);
  if ('error' in v) return v;
  if (v.pinned) log(`[SDK] ${projectFile} had no [sdk] version — pinned to ${v.version}\n`);
  if (!(await isSdkInstalled(v.version))) log(`[SDK] Downloading SDK ${v.version} into ${sdkDirFor(v.version)}...\n`);
  try {
    const dir = await ensureSdk(v.version, onProgress);
    if (!opts.pico) return { version: v.version, dir };
    const picoVersion = await picoSdkVersionFor(dir);
    const picoDir = join(picoSdkRootDir(), picoVersion);
    try {
      await fs.access(join(picoDir, COMPLETE_MARKER));
    } catch {
      log(`[SDK] Downloading pico-sdk ${picoVersion} (needed by SDK ${v.version}) into ${picoDir}...\n`);
    }
    const picoSdkDir = await ensurePicoSdk(picoVersion, onProgress);
    return { version: v.version, dir, picoSdkDir };
  } catch (e: any) {
    return { error: e?.message || String(e) };
  }
}

// ─── Build folders made with another SDK ───────────────────────────────────
//
// A project that switches SDK version (or pico-sdk) keeps build folders made with the
// old one: CMake refuses its cache ("does not match the source ... used to generate
// cache") and make's .d files keep objects compiled against the old headers, which are
// still installed, so they never rebuild. Before a build, every top-level `build`, `build_*` or `build-*` folder
// of the project that references a DIFFERENT version under the IDE's SDK or pico-sdk
// folder is deleted; the build recreates it. Only those folders are touched, and only
// when they point inside the IDE-managed roots, so a project's own paths never count.

const STALE_SCAN_MAX_FILES = 5000;
const STALE_SCAN_MAX_BYTES = 2 * 1024 * 1024;

function escapeRe(s: string): string {
  return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

/** Versions under `root` that `text` references, other than `current`. */
function otherVersionsIn(text: string, root: string, current: string): string[] {
  const re = new RegExp(`${escapeRe(root)}[\\\\/]([^\\\\/\\s"';:]+)`, 'g');
  const out = new Set<string>();
  for (let m = re.exec(text); m; m = re.exec(text)) if (m[1] !== current) out.add(m[1]);
  return [...out];
}

/**
 * A CMake cache CMake would refuse: made in another folder (a project copied from another
 * machine or moved: "The current CMakeCache.txt directory ... is different"), or for a
 * source folder that no longer exists (an SDK since removed). The reason, or null.
 */
async function cacheMadeElsewhere(text: string, cacheDir: string): Promise<string | null> {
  const value = (key: string) => {
    const m = new RegExp(`^${key}:[A-Z]+=(.*)$`, 'm').exec(text);
    return m ? m[1].trim() : null;
  };
  const real = async (p: string) => { try { return await fs.realpath(p); } catch { return null; } };
  const madeIn = value('CMAKE_CACHEFILE_DIR');
  if (madeIn) {
    const [a, b] = [await real(madeIn), await real(cacheDir)];
    if (a === null || a !== b) return `was made in another folder (${madeIn})`;
  }
  const source = value('CMAKE_HOME_DIRECTORY');
  if (source && (await real(source)) === null) return `was made for a source folder that is gone (${source})`;
  return null;
}

async function findStaleReference(dir: string, roots: Array<{ root: string; current: string; what: string }>): Promise<string | null> {
  let seen = 0;
  const walk = async (d: string, depth: number): Promise<string | null> => {
    let entries: import('fs').Dirent[];
    try { entries = await fs.readdir(d, { withFileTypes: true }); } catch { return null; }
    // Caches first: one CMakeCache.txt settles a CMake folder without reading its objects.
    entries.sort((a, b) => Number(b.name === 'CMakeCache.txt') - Number(a.name === 'CMakeCache.txt'));
    for (const e of entries) {
      if (seen >= STALE_SCAN_MAX_FILES) return null;
      const p = join(d, e.name);
      if (e.isDirectory()) {
        if (depth < 8) { const hit = await walk(p, depth + 1); if (hit) return hit; }
        continue;
      }
      if (e.name !== 'CMakeCache.txt' && !e.name.endsWith('.d')) continue;
      seen++;
      try {
        const st = await fs.stat(p);
        if (st.size > STALE_SCAN_MAX_BYTES) continue;
        const text = await fs.readFile(p, 'utf8');
        if (e.name === 'CMakeCache.txt') {
          const moved = await cacheMadeElsewhere(text, d);
          if (moved) return `${p} ${moved}`;
        }
        for (const r of roots) {
          const other = otherVersionsIn(text, r.root, r.current);
          if (other.length) return `${p} was made with another ${r.what} version (${other[0]})`;
        }
      } catch { /* unreadable: not ours to judge */ }
    }
    return null;
  };
  return walk(dir, 0);
}

/**
 * Delete the project's top-level `build`, `build_*` or `build-*` folders made with another SDK / pico-sdk
 * version than the one this build uses, or holding a CMake cache made in another folder (a
 * project copied from another machine) or for a source folder that is gone. Returns the
 * folders deleted.
 */
export async function dropStaleSdkBuilds(
  projectDir: string,
  current: { dir: string; picoSdkDir?: string },
  log: (line: string) => void,
): Promise<string[]> {
  const roots = [{ root: sdkRootDir(), current: basename(current.dir), what: 'SDK' }];
  if (current.picoSdkDir) roots.push({ root: picoSdkRootDir(), current: basename(current.picoSdkDir), what: 'pico-sdk' });
  let entries: import('fs').Dirent[];
  try { entries = await fs.readdir(projectDir, { withFileTypes: true }); } catch { return []; }
  const dropped: string[] = [];
  for (const e of entries) {
    if (!e.isDirectory() || !/^build([_-].*)?$/i.test(e.name)) continue;
    const dir = join(projectDir, e.name);
    const why = await findStaleReference(dir, roots);
    if (!why) continue;
    try {
      await fs.rm(dir, { recursive: true, force: true });
      dropped.push(dir);
      log(`[SDK] ${e.name}/ is stale: ${why.slice(dir.length + 1)}. Deleted, the build recreates it\n`);
    } catch (err: any) {
      log(`[SDK] could not delete stale ${dir}: ${err?.message || err}\n`);
    }
  }
  return dropped;
}

// ─── Arm GNU Toolchain (uvm2 builds) ───────────────────────────────────────
//
// Found, never downloaded: it is large and platform-specific. Same search as vpy_cli's
// pico.rs, so what the panel says is what the build will find: $UVM2_ARM_TOOLCHAIN, then
// the standard install locations, newest first, then the arm-none-eabi-gcc on the PATH (a
// Linux distribution's package, /usr). The one found is passed to every build as
// $UVM2_ARM_TOOLCHAIN (the SDK's uvm2.mk only looks in the standard locations). It needs
// newlib's nosys.specs, which the pico-sdk link uses: Homebrew's arm-none-eabi-gcc has none.

export const ARM_TOOLCHAIN_DOWNLOAD_URL =
  'https://developer.arm.com/downloads/-/arm-gnu-toolchain-downloads';

export type ToolchainCandidate = { dir: string; source: string; problem: string | null };
export type ToolchainStatus = {
  found: { dir: string; version: string | null; source: string } | null;
  candidates: ToolchainCandidate[];
};

function versionKey(p: string): number[] {
  return (p.match(/\d+/g) || []).map(Number);
}

function compareVersionKeysDesc(a: string, b: string): number {
  const ka = versionKey(a), kb = versionKey(b);
  for (let i = 0; i < Math.max(ka.length, kb.length); i++) {
    const d = (kb[i] ?? -1) - (ka[i] ?? -1);
    if (d !== 0) return d;
  }
  return 0;
}

async function standardToolchainDirs(): Promise<string[]> {
  const out: string[] = [];
  for (const [base, prefix] of [
    ['/Applications/ArmGNUToolchain', ''],     // macOS installer
    ['/opt', 'arm-gnu-toolchain'],             // Linux tarball convention
    ['/usr/local', 'arm-gnu-toolchain'],
  ] as const) {
    let names: string[];
    try { names = await fs.readdir(base); } catch { continue; }
    const found: string[] = [];
    for (const n of names.filter(n => n.startsWith(prefix) && !n.startsWith('.'))) {
      const p = join(base, n);
      found.push(await isDir(join(p, 'arm-none-eabi')) ? join(p, 'arm-none-eabi') : p);
    }
    out.push(...found.sort(compareVersionKeysDesc));
  }
  return out;
}

async function isDir(p: string): Promise<boolean> {
  try { return (await fs.stat(p)).isDirectory(); } catch { return false; }
}

async function containsFile(dir: string, name: string, depth: number): Promise<boolean> {
  let entries: import('fs').Dirent[];
  try { entries = await fs.readdir(dir, { withFileTypes: true }); } catch { return false; }
  if (entries.some(e => e.name === name)) return true;
  if (depth <= 0) return false;
  for (const e of entries) {
    if (e.isDirectory() && await containsFile(join(dir, e.name), name, depth - 1)) return true;
  }
  return false;
}

const gccName = process.platform === 'win32' ? 'arm-none-eabi-gcc.exe' : 'arm-none-eabi-gcc';

/** The compiler's own answer for nosys.specs: a full path when it has one, else null. */
function gccNosysSpecs(gcc: string): Promise<string | null | undefined> {
  return new Promise(resolve => {
    const child = spawn(gcc, ['-print-file-name=nosys.specs'], { stdio: ['ignore', 'pipe', 'ignore'] });
    let out = '';
    child.stdout.on('data', (c: Buffer) => { out += c.toString(); });
    child.on('error', () => resolve(undefined));          // does not run here
    child.on('close', code => {
      const p = out.trim();
      resolve(code !== 0 ? undefined : (p.startsWith('/') || /^[A-Za-z]:[\\/]/.test(p)) ? p : null);
    });
  });
}

async function toolchainProblem(dir: string): Promise<string | null> {
  const gcc = join(dir, 'bin', gccName);
  try { await fs.access(gcc); } catch { return `no bin/${gccName}`; }
  const noNosys = 'no nosys.specs (the Homebrew build? the pico-sdk link needs newlib\'s)';
  const specs = await gccNosysSpecs(gcc);
  if (specs !== undefined) {
    if (specs === null) return noNosys;
    try { await fs.access(specs); return null; } catch { return noNosys; }
  }
  if (!(await containsFile(dir, 'nosys.specs', 6))) return noNosys;
  return null;
}

/** The toolchain folder of the arm-none-eabi-gcc on the PATH (its bin's parent), if any. */
async function pathToolchainDir(): Promise<string | null> {
  for (const d of (process.env.PATH || '').split(delimiter).filter(Boolean)) {
    try { await fs.access(join(d, gccName)); return dirname(d); } catch { /* next */ }
  }
  return null;
}

function gccVersion(dir: string): Promise<string | null> {
  return new Promise(resolve => {
    const child = spawn(join(dir, 'bin', gccName), ['-dumpversion'], { stdio: ['ignore', 'pipe', 'ignore'] });
    let out = '';
    child.stdout.on('data', (c: Buffer) => { out += c.toString(); });
    child.on('error', () => resolve(null));
    child.on('close', code => resolve(code === 0 ? out.trim() || null : null));
  });
}

export async function detectArmToolchain(): Promise<ToolchainStatus> {
  const candidates: ToolchainCandidate[] = [];
  const env = process.env.UVM2_ARM_TOOLCHAIN;
  const tried: Array<{ dir: string; source: string }> = [
    ...(env ? [{ dir: env, source: '$UVM2_ARM_TOOLCHAIN' }] : []),
    ...(await standardToolchainDirs()).map(dir => ({ dir, source: 'standard location' })),
  ];
  const onPath = await pathToolchainDir();
  if (onPath && !tried.some(t => t.dir === onPath)) tried.push({ dir: onPath, source: 'PATH' });
  for (const { dir, source } of tried) {
    const problem = await toolchainProblem(dir);
    candidates.push({ dir, source, problem });
    if (!problem) return { found: { dir, source, version: await gccVersion(dir) }, candidates };
  }
  return { found: null, candidates };
}

/**
 * `UVM2_ARM_TOOLCHAIN` for a build's environment: the toolchain the panel shows, so a
 * build finds the same one (a distro's /usr included, which uvm2.mk does not look for).
 * Empty when the variable is already set or no usable toolchain is installed.
 */
export async function armToolchainEnv(): Promise<Record<string, string>> {
  if (process.env.UVM2_ARM_TOOLCHAIN) return {};
  const { found } = await detectArmToolchain();
  return found ? { UVM2_ARM_TOOLCHAIN: found.dir } : {};
}

// ─── Rust for uvm2 builds ──────────────────────────────────────────────────
//
// The SDK's drawing layer is Rust, built for the Cortex-M33: a uvm2 build needs cargo and
// the thumbv8m.main-none-eabi target. The toolchain is per user (~/.rustup), so no package
// can set it up; with rustup installed (Linux: the .deb recommends the distribution's
// rustup), the first uvm2 build does it, said in the build output: `rustup default stable`
// when there is no toolchain yet, then `rustup target add`. Without rustup it only says
// what to install; the SDK's own CMake check reports the missing cargo.

export const UVM2_RUST_TARGET = 'thumbv8m.main-none-eabi';

function runTool(cmd: string, args: string[], onLine?: (line: string) => void): Promise<{ code: number | null; out: string; missing: boolean }> {
  return new Promise(resolve => {
    let out = '';
    let child: ReturnType<typeof spawn>;
    try {
      child = spawn(cmd, args, { stdio: ['ignore', 'pipe', 'pipe'] });
    } catch {
      resolve({ code: null, out: '', missing: true });
      return;
    }
    const take = (c: Buffer) => {
      const s = c.toString();
      out += s;
      if (onLine) for (const l of s.split(/\r?\n|\r/)) if (l.trim()) onLine(l.trim());
    };
    child.stdout?.on('data', take);
    child.stderr?.on('data', take);
    child.on('error', (e: NodeJS.ErrnoException) => resolve({ code: null, out, missing: e.code === 'ENOENT' }));
    child.on('close', code => resolve({ code, out, missing: false }));
  });
}

/** Make sure a uvm2 build will find cargo with the Cortex-M33 target; log what it does. */
export async function ensureUvm2Rust(log: (line: string) => void): Promise<void> {
  const list = await runTool('rustup', ['target', 'list', '--installed']);
  if (list.code === 0 && list.out.split(/\s+/).includes(UVM2_RUST_TARGET)) return;

  if (list.missing) {
    const cargo = await runTool('cargo', ['--version']);
    if (!cargo.missing) {
      log(`[Rust] cargo found but no rustup: make sure the ${UVM2_RUST_TARGET} target is installed for it.`);
    } else {
      log(process.platform === 'linux'
        ? `[Rust] uvm2 builds need Rust: sudo apt install rustup (or https://rustup.rs). The IDE then sets it up on the next build.`
        : `[Rust] uvm2 builds need Rust: install rustup (https://rustup.rs, or brew install rustup). The IDE then sets it up on the next build.`);
    }
    return;
  }

  if (list.code !== 0) {
    // rustup without a toolchain yet ("no default is configured")
    log('[Rust] No Rust toolchain yet: installing the stable one (a one-time download, a few minutes)…');
    const d = await runTool('rustup', ['default', 'stable'], l => log(`[Rust] ${l}`));
    if (d.code !== 0) { log('[Rust] rustup default stable failed; run it in a terminal to see why.'); return; }
  }
  log(`[Rust] Adding the ${UVM2_RUST_TARGET} target (one time)…`);
  const a = await runTool('rustup', ['target', 'add', UVM2_RUST_TARGET], l => log(`[Rust] ${l}`));
  if (a.code !== 0) log(`[Rust] rustup target add ${UVM2_RUST_TARGET} failed; run it in a terminal to see why.`);
}
