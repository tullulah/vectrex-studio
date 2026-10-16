// The IDE's C and uvm2 builds on a clean Windows, through the IDE's own code (dist/, built by
// `npm run build`): the SDK, the pico-sdk and the Arm toolchain downloaded as a build does,
// the Windows tools from winBuildTools.ts, and new projects from the IDE's templates.
//
//   node scripts/win-build-smoke.js <sdk-tag | sdk-folder> <vpy_cli.exe> <work-dir>
//
// An SDK folder (a checkout of a branch) is used as it is, instead of downloading a tag.
// Builds a C project (make uvm2, make rp2350 and make sim, with a .vec asset compiled by vpy_cli) and a
// VPy project for uvm2. PATH is cut down to Windows' own folders first, and Rust goes into
// <work-dir>, so nothing the CI machine has installed is used. Exits non-zero on a failure.

const { spawn } = require('child_process');
const { existsSync, promises: fs } = require('fs');
const path = require('path');

const dist = path.join(__dirname, '..', 'dist');
const sdk = require(path.join(dist, 'sdkManager.js'));
const { windowsBuildEnv, windowsPicotool, windowsSimEnv } = require(path.join(dist, 'winBuildTools.js'));
const serial = require(path.join(dist, 'hwdebug', 'serialLink.js'));
const { createProjectFromTemplate } = require(path.join(dist, 'projectTemplates.js'));

const [tag, vpyCliArg, workArg] = process.argv.slice(2);
if (!tag || !vpyCliArg || !workArg) {
  console.error('usage: node scripts/win-build-smoke.js <sdk-tag> <vpy_cli.exe> <work-dir>');
  process.exit(2);
}
const work = path.resolve(workArg);
const vpyCli = path.resolve(vpyCliArg);
const log = (l) => process.stdout.write(l.endsWith('\n') ? l : l + '\n');

function run(cmd, args, cwd, env) {
  log(`$ ${cmd} ${args.join(' ')}   (in ${cwd})`);
  return new Promise((resolve) => {
    const child = spawn(cmd, args, { cwd, env, stdio: 'inherit' });
    child.on('error', (e) => { log(`spawn ${cmd}: ${e.message}`); resolve(-1); });
    child.on('close', (code) => resolve(code ?? -1));
  });
}

async function main() {
  await fs.mkdir(work, { recursive: true });
  // A clean machine: Windows' own folders on PATH, Rust and the IDE's downloads in <work>.
  const sysRoot = process.env.SystemRoot || 'C:\\Windows';
  const base = {};
  for (const k of ['SystemRoot', 'SystemDrive', 'windir', 'ComSpec', 'PATHEXT', 'TEMP', 'TMP', 'USERPROFILE',
    'APPDATA', 'LOCALAPPDATA', 'ProgramData', 'ProgramFiles', 'NUMBER_OF_PROCESSORS', 'PROCESSOR_ARCHITECTURE', 'OS', 'USERNAME']) {
    if (process.env[k]) base[k] = process.env[k];
  }
  base.Path = [path.join(sysRoot, 'System32'), sysRoot, path.join(sysRoot, 'System32', 'WindowsPowerShell', 'v1.0')].join(';');
  base.CARGO_HOME = path.join(work, 'cargo');
  base.RUSTUP_HOME = path.join(work, 'rustup');
  process.env.CARGO_HOME = base.CARGO_HOME;   // winBuildTools reads ~/.cargo from here
  process.env.VECTREX_STUDIO_SDK_DIR = path.join(work, 'sdk');
  process.env.VECTREX_STUDIO_PICO_SDK_DIR = path.join(work, 'pico-sdk');
  process.env.VECTREX_STUDIO_TOOLCHAIN_DIR = path.join(work, 'toolchains');
  for (const k of ['VECTREX_STUDIO_SDK_DIR', 'VECTREX_STUDIO_PICO_SDK_DIR', 'VECTREX_STUDIO_TOOLCHAIN_DIR']) base[k] = process.env[k];

  log(`== SDK ${tag}`);
  const sdkFolder = existsSync(tag) ? path.resolve(tag) : null;
  const sdkDir = sdkFolder ?? await sdk.ensureSdk(tag);
  const pin = sdkFolder ? null : tag;
  const pico = await sdk.ensurePicoSdk(await sdk.picoSdkVersionFor(sdkDir));
  const arm = await sdk.armToolchainEnv(log);
  if (!arm.UVM2_ARM_TOOLCHAIN) throw new Error('no Arm toolchain');
  const env0 = { ...base, VPY_CLI: sdk.toolPath(vpyCli), ...sdk.sdkEnv(sdkDir, pico), ...arm };
  const env = await windowsBuildEnv({ base: env0, sdkDir, uvm2: true, log });

  const failures = [];
  const check = (what, ok) => { log(`${ok ? 'PASS' : 'FAIL'}: ${what}`); if (!ok) failures.push(what); };

  log('== C project');
  const c = await createProjectFromTemplate({ kind: 'c', name: 'smoke_c', parentDir: work, sdkVersion: pin });
  const cDir = c.projectDir;
  await fs.mkdir(path.join(cDir, 'assets', 'vectors'), { recursive: true });
  await fs.copyFile(path.join(__dirname, '..', '..', '..', 'examples', 'SnowBros', 'assets', 'vectors', 'enemy1.vec'),
    path.join(cDir, 'assets', 'vectors', 'enemy1.vec'));
  check('make uvm2', (await run('make', ['uvm2'], cDir, env)) === 0 && existsSync(path.join(cDir, 'build_uvm2', 'smoke_c.um2')));
  check('asset header from vpy_cli', existsSync(path.join(cDir, 'gen', 'enemy1.h')));
  check('make rp2350', (await run('make', ['rp2350'], cDir, env)) === 0 && existsSync(path.join(cDir, 'build_rp2350', 'smoke_c_sd.bin')));
  // The WASM simulator: make sim with emscripten, which the IDE installs (once)
  const simEnv = await windowsSimEnv({ base: { ...env0 }, log });
  check('make sim', (await run('make', ['sim'], cDir, simEnv)) === 0 && existsSync(path.join(cDir, 'build_wasm', 'smoke_c.js')));

  log('== VPy project (uvm2)');
  const v = await createProjectFromTemplate({ kind: 'vpy', name: 'smoke_vpy', parentDir: work, sdkVersion: pin });
  const vDir = v.projectDir;
  const out = path.join(vDir, 'build', 'smoke_vpy.bin');
  check('vpy_cli build --target uvm2',
    (await run(vpyCli, ['build', v.projectFile, '--output', out, '--target', 'uvm2'], vDir, env)) === 0
      && existsSync(path.join(vDir, 'build', 'smoke_vpy.um2')));

  // Upload to Cartridge, what can run without a cartridge: picotool, the COM port search and
  // the PowerShell that holds a port (asked for one that does not exist).
  log('== Upload to Cartridge (no cartridge)');
  const pt = await windowsPicotool(log);
  check('picotool', !!pt && (await run(pt, ['version'], work, env)) === 0);
  let ports = null;
  try { ports = await serial.monitorPorts(); } catch (e) { log(String(e)); }
  check(`COM port search (${JSON.stringify(ports)})`, Array.isArray(ports));
  let openErr = '';
  try { (await serial.Link.open('COM99')).close(); } catch (e) { openErr = String(e?.message ?? e); }
  log(`Link.open(COM99): ${openErr}`);
  check('a missing COM port is an error that names it', openErr.includes('COM99'));

  if (failures.length) {
    log(`\n${failures.length} failed: ${failures.join(', ')}`);
    process.exit(1);
  }
  log('\nall passed');
}

main().catch((e) => { console.error(e); process.exit(1); });
