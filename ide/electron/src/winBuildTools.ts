// Windows: the build tools a Mac or a Linux machine already has.
//
// A C project builds with `make` (its Makefile and the SDK's uvm2.mk, whose recipes are POSIX
// shell: mkdir -p, rm -rf, grep, sed, test), and a uvm2 image goes through CMake and the
// pico-sdk, which needs picotool, plus cargo for the SDK's Rust drawing layer. None of that
// ships with Windows, so the first C or uvm2 build downloads it, like the Arm toolchain:
//
//   make + busybox   xPack Windows Build Tools: GNU make, and busybox-w32 as its sh (the
//                    recipes' grep, sed, head... are busybox applets)
//   CMake, Ninja     Kitware's and ninja-build's own zips. Ninja is the generator: the
//                    "Unix Makefiles" one refuses a PATH with sh.exe on it, and Visual Studio's
//                    may not exist
//   picotool         Raspberry Pi's prebuilt one (pico-sdk-tools), found by the pico-sdk
//                    through PICOTOOL_FETCH_FROM_GIT_PATH; otherwise it builds picotool from
//                    source and needs a PC C++ compiler
//   Rust             rustup with the x86_64-pc-windows-gnu host. The SDK's Rust has
//                    proc-macro dependencies, which are compiled and linked FOR THE PC; the
//                    msvc host links with Visual Studio's link.exe, the gnu host brings its
//                    own linker. The channel is the SDK's rust-toolchain.toml.
//
// Each archive is pinned by version and SHA-256 and lives in
// ~/VectrexStudio/toolchains/windows/<name>-<version>.

import { promises as fs } from 'fs';
import { basename, delimiter, join } from 'path';
import * as os from 'os';
import { spawn } from 'child_process';
import { armToolchainRootDir, compareTagsDesc, downloadFile, installTarball, isValidSdkTag, toolPath, UVM2_RUST_TARGET } from './sdkManager.js';

type WinTool = {
  name: string; version: string; url: string; sha256: string;
  /** Leading folders of the zip to drop. */
  strip: number;
  /** A file that must be there once extracted. */
  mustContain: string;
  /** The folder (inside the install) that goes on PATH, or null. */
  bin: string | null;
};

const WIN_TOOLS: WinTool[] = [
  {
    name: 'make', version: '4.4.1-3',
    url: 'https://github.com/xpack-dev-tools/windows-build-tools-xpack/releases/download/v4.4.1-3/xpack-windows-build-tools-4.4.1-3-win32-x64.zip',
    sha256: '113d4dfdbbc56dc9b865c9f75d38cd0da82f0d7094187e6f7a803fe6eef1d218',
    strip: 1, mustContain: join('bin', 'make.exe'), bin: 'bin',
  },
  {
    name: 'cmake', version: '4.2.8',
    url: 'https://github.com/Kitware/CMake/releases/download/v4.2.8/cmake-4.2.8-windows-x86_64.zip',
    sha256: 'd33720a4e03114ae7c964c184e88f68a640be419f973bf4fb685f0900d1864ee',
    strip: 1, mustContain: join('bin', 'cmake.exe'), bin: 'bin',
  },
  {
    name: 'ninja', version: '1.13.2',
    url: 'https://github.com/ninja-build/ninja/releases/download/v1.13.2/ninja-win.zip',
    sha256: '07fc8261b42b20e71d1720b39068c2e14ffcee6396b76fb7a795fb460b78dc65',
    strip: 0, mustContain: 'ninja.exe', bin: '',
  },
  {
    // picotool/picotool.exe + picotoolConfig.cmake: PICOTOOL_FETCH_FROM_GIT_PATH is the
    // folder that holds picotool/.
    name: 'picotool', version: '2.2.0-a4',
    url: 'https://github.com/raspberrypi/pico-sdk-tools/releases/download/v2.2.0-4/picotool-2.2.0-a4-x64-win.zip',
    sha256: '42cd263ed17dd3987d0830fa239424b3958ec0407afd6985bfbf83a5fc5a55f2',
    strip: 0, mustContain: join('picotool', 'picotool.exe'), bin: 'picotool',
  },
];

const RUSTUP_VERSION = '1.29.1';
const RUSTUP_INIT = {
  url: `https://static.rust-lang.org/rustup/archive/${RUSTUP_VERSION}/x86_64-pc-windows-msvc/rustup-init.exe`,
  sha256: '6f4bef66261261fcb43131be8720bab817d403a09edec7455c371974b90bdb7e',
};
const RUST_HOST = 'x86_64-pc-windows-gnu';
/** The first SDK whose Rust build tools link on Windows without MinGW. */
const MIN_WINDOWS_SDK = 'v1.4.4';

export function winToolsRootDir(): string {
  return join(armToolchainRootDir(), 'windows');
}

/** `env`'s PATH with `dirs` in front. Windows spells the key `Path`: reuse the one there is,
 *  or the child gets two and which one wins is undefined. */
export function prependPath(env: NodeJS.ProcessEnv, dirs: string[]): void {
  const key = Object.keys(env).find((k) => k.toUpperCase() === 'PATH') ?? 'PATH';
  const rest = env[key] ? [env[key] as string] : [];
  env[key] = [...dirs, ...rest].join(delimiter);
}

const inFlight = new Map<string, Promise<string>>();

function ensureTool(t: WinTool, log: (line: string) => void): Promise<string> {
  const id = `${t.name}-${t.version}`;
  const running = inFlight.get(id);
  if (running) return running;
  const p = (async () => {
    const dir = join(winToolsRootDir(), id);
    try { await fs.access(join(dir, t.mustContain)); return dir; } catch { /* not yet */ }
    log(`[tools] ${t.name} ${t.version}: downloading (once)...\n`);
    const out = await installTarball({
      what: `${t.name} ${t.version}`, url: t.url, root: winToolsRootDir(), name: id,
      mustContain: t.mustContain, marker: { name: t.name, version: t.version, url: t.url },
      progressTag: id, ext: 'zip', sha256: t.sha256, strip: t.strip,
    });
    log(`[tools] ${t.name} ${t.version} installed: ${out}\n`);
    return out;
  })().finally(() => inFlight.delete(id));
  inFlight.set(id, p);
  return p;
}

function run(cmd: string, args: string[], env: NodeJS.ProcessEnv, onLine: (l: string) => void): Promise<{ code: number | null; out: string; missing: boolean }> {
  return new Promise((resolve) => {
    let out = '';
    let child: ReturnType<typeof spawn>;
    try {
      child = spawn(cmd, args, { stdio: ['ignore', 'pipe', 'pipe'], env });
    } catch {
      resolve({ code: null, out: '', missing: true });
      return;
    }
    const take = (c: Buffer) => {
      const s = c.toString();
      out += s;
      for (const l of s.split(/\r?\n|\r/)) if (l.trim()) onLine(l.trim());
    };
    child.stdout?.on('data', take);
    child.stderr?.on('data', take);
    child.on('error', (e: NodeJS.ErrnoException) => resolve({ code: null, out, missing: e.code === 'ENOENT' }));
    child.on('close', (code) => resolve({ code, out, missing: false }));
  });
}

/** The Rust channel an SDK pins (its rust-toolchain.toml), or null. */
async function sdkRustChannel(sdkDir: string): Promise<string | null> {
  try {
    const text = await fs.readFile(join(sdkDir, 'rust-toolchain.toml'), 'utf-8');
    return /^\s*channel\s*=\s*"([^"]+)"/m.exec(text)?.[1] ?? null;
  } catch {
    return null;
  }
}

/**
 * Rust for a uvm2 build on Windows: rustup (installed for this user if missing), and the SDK's
 * channel on the gnu host with the Cortex-M33 target. Returns what the build's environment
 * needs: RUSTUP_TOOLCHAIN (it outranks rust-toolchain.toml, whose channel alone would mean the
 * default host) and ~/.cargo/bin, which a fresh install has not put on this process's PATH.
 */
async function windowsRust(sdkDir: string | null, base: NodeJS.ProcessEnv, log: (line: string) => void): Promise<NodeJS.ProcessEnv> {
  const cargoHome = process.env.CARGO_HOME || join(os.homedir(), '.cargo');
  const cargoBin = join(cargoHome, 'bin');
  const env: NodeJS.ProcessEnv = { ...base };
  prependPath(env, [cargoBin]);

  let have = await run('rustup', ['--version'], env, () => {});
  if (have.missing) {
    log(`[Rust] No rustup: installing it (rustup ${RUSTUP_VERSION}, host ${RUST_HOST}) into ${cargoHome}, a one-time download of a few minutes...\n`);
    const exe = join(winToolsRootDir(), `rustup-init-${RUSTUP_VERSION}.exe`);
    await fs.mkdir(winToolsRootDir(), { recursive: true });
    await downloadFile(RUSTUP_INIT.url, exe, `rustup-init ${RUSTUP_VERSION}`, RUSTUP_INIT.sha256);
    const inst = await run(exe, ['-y', '--profile', 'minimal', '--default-host', RUST_HOST, '--default-toolchain', 'none'],
      env, (l) => log(`[Rust] ${l}\n`));
    if (inst.code !== 0) {
      log('[Rust] The rustup installer failed (above). Install Rust from https://rustup.rs and build again.\n');
      return {};
    }
    have = await run('rustup', ['--version'], env, () => {});
  }
  if (have.missing) {
    log(`[Rust] rustup is installed but not found in ${cargoBin}: install Rust from https://rustup.rs and build again.\n`);
    return {};
  }

  const channel = (sdkDir && await sdkRustChannel(sdkDir)) || 'stable';
  const toolchain = `${channel}-${RUST_HOST}`;
  const list = await run('rustup', ['target', 'list', '--installed', '--toolchain', toolchain], env, () => {});
  if (list.code !== 0 || !list.out.split(/\s+/).includes(UVM2_RUST_TARGET)) {
    log(`[Rust] Installing Rust ${toolchain} with the ${UVM2_RUST_TARGET} target (one time)...\n`);
    const t = await run('rustup', ['toolchain', 'install', toolchain, '--profile', 'minimal', '--target', UVM2_RUST_TARGET],
      env, (l) => log(`[Rust] ${l}\n`));
    if (t.code !== 0) log(`[Rust] rustup toolchain install ${toolchain} failed (above).\n`);
  }
  // dlltool: the windows-sys crate (a dependency of the SDK's proc macros) links through it,
  // and rustc looks for it on PATH only, while the gnu toolchain keeps its own in the sysroot's
  // self-contained folder. At the END of PATH: that folder also has an ld.exe and a gcc.
  const sysroot = await run('rustup', ['run', toolchain, 'rustc', '--print', 'sysroot'], env, () => {});
  const key = Object.keys(env).find((k) => k.toUpperCase() === 'PATH') ?? 'PATH';
  if (sysroot.code === 0 && sysroot.out.trim()) {
    const selfContained = join(sysroot.out.trim(), 'lib', 'rustlib', RUST_HOST, 'bin', 'self-contained');
    env[key] = [env[key], selfContained].filter(Boolean).join(delimiter);
  }
  return { RUSTUP_TOOLCHAIN: toolchain, [key]: env[key] };
}

/**
 * The environment a C (make) or uvm2 (CMake + cargo) build needs on Windows, with every
 * missing tool downloaded first. `base` is the build's environment so far; the result is
 * `base` plus PATH, the generator and picotool. `uvm2` adds Rust.
 */
export async function windowsBuildEnv(o: {
  base: NodeJS.ProcessEnv; sdkDir: string | null; uvm2: boolean; log: (line: string) => void;
}): Promise<NodeJS.ProcessEnv> {
  const env: NodeJS.ProcessEnv = { ...o.base };
  const dirs: Record<string, string> = {};
  for (const t of WIN_TOOLS) {
    if (!o.uvm2 && t.name !== 'make') continue;
    try {
      dirs[t.name] = await ensureTool(t, o.log);
    } catch (e: any) {
      o.log(`[tools] Could not install ${t.name} ${t.version}: ${e?.message || e}\n`);
    }
  }
  const pathDirs = WIN_TOOLS
    .filter((t) => dirs[t.name] && t.bin !== null && t.name !== 'picotool')
    .map((t) => join(dirs[t.name], t.bin as string));
  // The Arm compiler on PATH too: a project's own rp2350 rule may call arm-none-eabi-gcc bare.
  if (env.UVM2_ARM_TOOLCHAIN) pathDirs.push(join(env.UVM2_ARM_TOOLCHAIN, 'bin'));
  prependPath(env, pathDirs);
  if (o.uvm2) {
    // Older SDKs' Rust build tools need MinGW's dlltool (windows-sys 0.61): said up front.
    const tag = o.sdkDir ? basename(o.sdkDir) : '';
    if (isValidSdkTag(tag) && compareTagsDesc(tag, MIN_WINDOWS_SDK) > 0) {
      o.log(`[tools] SDK ${tag}: uvm2 builds on Windows need SDK ${MIN_WINDOWS_SDK} or later (the Rust build fails on "dlltool"). Pick a newer SDK in Project Settings.\n`);
    }
    if (!env.CMAKE_GENERATOR) env.CMAKE_GENERATOR = 'Ninja';
    if (dirs.picotool && !env.PICOTOOL_FETCH_FROM_GIT_PATH) env.PICOTOOL_FETCH_FROM_GIT_PATH = toolPath(dirs.picotool);
    Object.assign(env, await windowsRust(o.sdkDir, env, o.log));
  }
  return env;
}
