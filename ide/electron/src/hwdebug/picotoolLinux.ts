/*
 * picotool on Linux, where Ubuntu has no picotool package.
 *
 * The pico-sdk fetches picotool's source during a uvm2 build (`_deps/picotool-src`) but
 * builds it with PICOTOOL_NO_LIBUSB: that copy only processes ELFs and cannot talk to the
 * cartridge. So, when there is no picotool with USB, the IDE builds one from that source
 * (cmake + a host C++ compiler + libusb-1.0-0-dev, all dependencies of the .deb) into
 * ~/VectrexStudio/tools and keeps it for every later upload.
 *
 * No electron import: it runs in plain node too (tested in a container).
 */
import { spawn, spawnSync } from 'child_process';
import { chmodSync, copyFileSync, existsSync, mkdirSync, readdirSync } from 'fs';
import { homedir } from 'os';
import { dirname, join } from 'path';

/** The IDE's own picotool: ~/VectrexStudio/tools/picotool. */
export const keptPicotool = (): string => join(homedir(), 'VectrexStudio', 'tools', 'picotool');

export function onPath(name: string): boolean {
  return (process.env.PATH || '').split(':').some((d) => d && existsSync(join(d, name)));
}

/** A picotool that runs and was built with USB. */
export function picotoolHasUsb(p: string): boolean {
  const r = spawnSync(p, ['version'], { encoding: 'utf8', timeout: 5000 });
  return !r.error && r.status === 0 && !/without USB support/i.test(`${r.stdout}${r.stderr}`);
}

/** Folders named `name` under `dir`, a few levels down. */
function findDirs(dir: string, name: string, depth = 5): string[] {
  const out: string[] = [];
  let entries: import('fs').Dirent[];
  try { entries = readdirSync(dir, { withFileTypes: true }); } catch { return out; }
  for (const e of entries) {
    if (!e.isDirectory() || e.name.startsWith('.') || e.name === 'cargo-target' || e.name === 'node_modules') continue;
    const p = join(dir, e.name);
    if (e.name === name) out.push(p);
    else if (depth > 0) out.push(...findDirs(p, name, depth - 1));
  }
  return out;
}

/** The pico-sdk the IDE downloaded (~/VectrexStudio/pico-sdk/<version>), newest first. */
function picoSdkDirs(): string[] {
  const root = process.env.VECTREX_STUDIO_PICO_SDK_DIR || join(homedir(), 'VectrexStudio', 'pico-sdk');
  try {
    return readdirSync(root).filter((v) => !v.startsWith('.')).sort().reverse().map((v) => join(root, v))
      .filter((d) => existsSync(join(d, 'pico_sdk_init.cmake')));
  } catch { return []; }
}

function run(cmd: string, args: string[], say: (t: string) => void): Promise<number> {
  return new Promise((resolve) => {
    const child = spawn(cmd, args, { stdio: ['ignore', 'pipe', 'pipe'] });
    let tail = '';
    const take = (d: Buffer) => { tail = (tail + d.toString()).slice(-4000); };
    child.stdout?.on('data', take);
    child.stderr?.on('data', take);
    child.on('error', (e) => { say(`${cmd}: ${e.message}`); resolve(-1); });
    child.on('close', (code) => {
      if (code !== 0) for (const l of tail.trim().split('\n').slice(-8)) say(l);
      resolve(code ?? -1);
    });
  });
}

/**
 * A picotool with USB for this Linux machine, building it once if needed. `gameDir` is the
 * folder of the game being uploaded (its uvm2 build has picotool's source). Returns the
 * path, or null with the reason said.
 */
export async function ensureLinuxPicotool(gameDir: string, say: (t: string) => void): Promise<string | null> {
  if (onPath('picotool') && picotoolHasUsb('picotool')) return 'picotool';
  const kept = keptPicotool();
  if (existsSync(kept) && picotoolHasUsb(kept)) return kept;

  const roots = [gameDir, dirname(gameDir), dirname(dirname(gameDir))];
  const src = roots.flatMap((r) => findDirs(r, 'picotool-src')).find((d) => existsSync(join(d, 'CMakeLists.txt')));
  const sdk = picoSdkDirs()[0];
  if (!src || !sdk) {
    say(`picotool: no picotool with USB, and ${!src ? "no picotool source from a uvm2 build" : 'no pico-sdk'} to build one from`);
    return null;
  }
  const buildDir = join(dirname(kept), 'picotool-build');
  say('picotool: none with USB on this machine (Ubuntu has no package): building it once into ~/VectrexStudio/tools (about a minute)…');
  mkdirSync(buildDir, { recursive: true });
  if (await run('cmake', ['-S', src, '-B', buildDir, '-DCMAKE_BUILD_TYPE=Release', `-DPICO_SDK_PATH=${sdk}`], say) !== 0) {
    say('picotool: configure failed (libusb-1.0-0-dev, cmake and a C++ compiler are needed)');
    return null;
  }
  if (await run('cmake', ['--build', buildDir, '-j4', '--target', 'picotool'], say) !== 0) {
    say('picotool: build failed');
    return null;
  }
  const built = join(buildDir, 'picotool');
  if (!existsSync(built) || !picotoolHasUsb(built)) {
    say('picotool: built, but without USB support (is libusb-1.0-0-dev installed?)');
    return null;
  }
  copyFileSync(built, kept);
  chmodSync(kept, 0o755);
  say(`picotool: ready (${kept})`);
  return kept;
}
