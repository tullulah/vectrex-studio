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
import { join } from 'path';
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

async function installSdk(tag: string, onProgress?: (p: SdkProgress) => void): Promise<string> {
  const dest = sdkDirFor(tag);
  if (await isSdkInstalled(tag)) return dest;

  const root = sdkRootDir();
  await fs.mkdir(root, { recursive: true });
  const stamp = `${process.pid}-${Date.now()}`;
  const tarball = join(root, `.download-${tag}-${stamp}.tar.gz`);
  const staging = join(root, `.extract-${tag}-${stamp}`);

  try {
    // 1. Download the tag's source tarball (public repo: no token needed).
    const url = `https://codeload.github.com/${SDK_REPO}/tar.gz/refs/tags/${tag}`;
    const res = await fetch(url, { headers: { 'User-Agent': 'VectrexStudio' } });
    if (!res.ok || !res.body) {
      throw new Error(res.status === 404
        ? `SDK version ${tag} does not exist in ${SDK_REPO}`
        : `Download failed for SDK ${tag}: HTTP ${res.status}`);
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
      onProgress?.({ tag, phase: 'download', received, total });
    }
    await new Promise<void>((resolve, reject) => out.end((err?: Error | null) => (err ? reject(err) : resolve())));

    // 2. Extract next to the final folder, so the rename below is atomic.
    onProgress?.({ tag, phase: 'extract', received, total });
    await fs.mkdir(staging, { recursive: true });
    await runTar(['-xzf', tarball, '-C', staging, '--strip-components=1']);

    // 3. Refuse a tarball that isn't an SDK.
    try {
      await fs.access(join(staging, 'uvm2-sdk', 'uvm2_bus.c'));
    } catch {
      throw new Error(`SDK ${tag} downloaded but its layout is not recognised (no uvm2-sdk/uvm2_bus.c)`);
    }
    await fs.writeFile(join(staging, COMPLETE_MARKER), JSON.stringify({
      tag, repo: SDK_REPO, installedAt: new Date().toISOString(),
    }, null, 2) + '\n');

    // 4. Publish. A leftover folder without the marker is a broken earlier attempt.
    await fs.rm(dest, { recursive: true, force: true });
    await fs.rename(staging, dest);
    onProgress?.({ tag, phase: 'done', received, total });
    return dest;
  } finally {
    await fs.rm(tarball, { force: true }).catch(() => {});
    await fs.rm(staging, { recursive: true, force: true }).catch(() => {});
  }
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
export function sdkEnv(dir: string): Record<string, string> {
  return {
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

/** Version + installed folder for a project, downloading the SDK if needed. */
export async function resolveProjectSdk(
  projectFile: string,
  log: (line: string) => void,
  onProgress?: (p: SdkProgress) => void,
): Promise<{ version: string; dir: string } | { error: string }> {
  const v = await projectSdkVersion(projectFile);
  if ('error' in v) return v;
  if (v.pinned) log(`[SDK] ${projectFile} had no [sdk] version — pinned to ${v.version}\n`);
  if (!(await isSdkInstalled(v.version))) log(`[SDK] Downloading SDK ${v.version} into ${sdkDirFor(v.version)}...\n`);
  try {
    const dir = await ensureSdk(v.version, onProgress);
    return { version: v.version, dir };
  } catch (e: any) {
    return { error: e?.message || String(e) };
  }
}
