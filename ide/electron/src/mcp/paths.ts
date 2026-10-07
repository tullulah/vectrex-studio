// Filesystem helpers for MCP tools: URI <-> path conversion, project-root
// containment, project-file discovery and a bounded project tree walk.
// Pure Node (no Electron) so it can be exercised outside the app.

import * as fs from 'fs/promises';
import * as path from 'path';

export const PROJECT_FILE_EXTS = ['.vpyproj', '.cvproj'];

/** file:// URI in the same raw form the editor uses (no percent-encoding). */
export function pathToFileUri(p: string): string {
  const norm = p.replace(/\\/g, '/');
  return /^[A-Za-z]:\//.test(norm) ? `file:///${norm}` : `file://${norm}`;
}

/** Local path of a file:// URI (raw or percent-encoded). Throws for other schemes. */
export function fileUriToPath(uri: string): string {
  if (!/^file:\/\//i.test(uri)) throw new Error(`Not a file:// URI: ${uri}`);
  let p = uri.replace(/^file:\/\//i, '');
  if (/%[0-9A-Fa-f]{2}/.test(p)) {
    try { p = decodeURIComponent(p); } catch { /* keep raw */ }
  }
  if (/^\/[A-Za-z]:\//.test(p)) p = p.slice(1); // file:///C:/x -> C:/x
  if (process.platform === 'win32') p = p.replace(/\//g, '\\');
  return path.normalize(p);
}

function isInside(root: string, target: string): boolean {
  const rel = path.relative(root, target);
  return rel === '' || (!rel.startsWith('..') && !path.isAbsolute(rel));
}

/** realpath of the deepest existing ancestor of `p`, with the missing tail re-appended. */
async function realpathLoose(p: string): Promise<string> {
  let cur = path.resolve(p);
  const tail: string[] = [];
  for (;;) {
    try {
      const real = await fs.realpath(cur);
      return tail.length ? path.join(real, ...tail.reverse()) : real;
    } catch {
      const parent = path.dirname(cur);
      if (parent === cur) return path.resolve(p);
      tail.push(path.basename(cur));
      cur = parent;
    }
  }
}

/**
 * Resolve `p` (relative to `root`, or absolute) and require that it stays inside
 * `root`, following symlinks of the existing part of the path. Returns the absolute
 * (non-realpath) path. Throws otherwise.
 */
export async function resolveInsideRoot(root: string, p: string): Promise<string> {
  if (typeof p !== 'string' || !p.trim()) throw new Error('Path is required');
  if (p.includes('\0')) throw new Error('Invalid path');
  const abs = path.resolve(root, p);
  const realRoot = await realpathLoose(root);
  const realAbs = await realpathLoose(abs);
  if (!isInside(path.resolve(root), abs) || !isInside(realRoot, realAbs)) {
    throw new Error(`Path "${p}" is outside the project root (${root})`);
  }
  return abs;
}

/** Same check for an already-absolute path. */
export async function assertInsideRoot(root: string, absPath: string): Promise<void> {
  await resolveInsideRoot(root, absPath);
}

/**
 * Given a .vpyproj/.cvproj path or a directory, return the project file.
 * A directory must contain exactly one project file, or one named after the directory.
 */
export async function findProjectFile(target: string): Promise<string> {
  const abs = path.resolve(target);
  let st;
  try { st = await fs.stat(abs); } catch { throw new Error(`Path not found: ${abs}`); }
  if (st.isFile()) {
    if (!PROJECT_FILE_EXTS.includes(path.extname(abs).toLowerCase())) {
      throw new Error(`Not a project file (expected .vpyproj or .cvproj): ${abs}`);
    }
    return abs;
  }
  if (!st.isDirectory()) throw new Error(`Not a file or directory: ${abs}`);
  const entries = await fs.readdir(abs);
  const candidates = entries.filter((e) => PROJECT_FILE_EXTS.includes(path.extname(e).toLowerCase())).sort();
  if (candidates.length === 0) throw new Error(`No .vpyproj or .cvproj file in ${abs}`);
  if (candidates.length === 1) return path.join(abs, candidates[0]);
  const base = path.basename(abs).toLowerCase();
  const named = candidates.filter((c) => path.basename(c, path.extname(c)).toLowerCase() === base);
  if (named.length === 1) return path.join(abs, named[0]);
  // Prefer a VPy project over a C manifest when both sit in the folder.
  const vpy = candidates.filter((c) => c.toLowerCase().endsWith('.vpyproj'));
  if (vpy.length === 1) return path.join(abs, vpy[0]);
  throw new Error(`Several project files in ${abs}: ${candidates.join(', ')} — pass one explicitly`);
}

export interface TreeEntry { path: string; type: 'file' | 'dir'; size?: number }

const SKIP_DIRS = new Set(['build', 'node_modules', '.git', 'target', '__pycache__', '.DS_Store', '.vscode', '.idea']);

/** Breadth-first listing of `root`, bounded by depth and entry count. Paths are relative, '/'-separated. */
export async function walkProjectTree(root: string, opts: { maxDepth?: number; maxEntries?: number } = {}): Promise<{ entries: TreeEntry[]; truncated: boolean }> {
  const maxDepth = Math.max(1, Math.min(opts.maxDepth ?? 6, 12));
  const maxEntries = Math.max(1, Math.min(opts.maxEntries ?? 2000, 10000));
  const entries: TreeEntry[] = [];
  let truncated = false;
  let queue: Array<{ dir: string; rel: string }> = [{ dir: root, rel: '' }];
  for (let depth = 0; depth < maxDepth && queue.length && !truncated; depth++) {
    const next: typeof queue = [];
    for (const { dir, rel } of queue) {
      let items: import('fs').Dirent[];
      try { items = await fs.readdir(dir, { withFileTypes: true }); } catch { continue; }
      items.sort((a, b) => a.name.localeCompare(b.name));
      for (const it of items) {
        if (SKIP_DIRS.has(it.name)) continue;
        if (entries.length >= maxEntries) { truncated = true; break; }
        const relPath = rel ? `${rel}/${it.name}` : it.name;
        const full = path.join(dir, it.name);
        if (it.isDirectory()) {
          entries.push({ path: relPath + '/', type: 'dir' });
          next.push({ dir: full, rel: relPath });
        } else if (it.isFile()) {
          let size: number | undefined;
          try { size = (await fs.stat(full)).size; } catch { /* ignore */ }
          entries.push({ path: relPath, type: 'file', size });
        }
      }
      if (truncated) break;
    }
    queue = next;
    if (depth === maxDepth - 1 && queue.length) truncated = true;
  }
  entries.sort((a, b) => a.path.localeCompare(b.path));
  return { entries, truncated };
}
