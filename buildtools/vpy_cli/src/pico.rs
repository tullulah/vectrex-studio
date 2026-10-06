//! pico-sdk and Arm toolchain resolution for the uvm2 target.
//!
//! The Raspberry Pi pico-sdk is pinned per uvmc2-sdk release, not "latest": the startup
//! contract the multicart loader validates (IMAGE_DEF block, no_flash binary type, the weak
//! isr_svcall the SDK overrides) can move between pico-sdk releases. An SDK release may name
//! its pico-sdk in a `PICO_SDK_VERSION` file at its root; every release so far uses
//! [`DEFAULT_PICO_SDK_VERSION`].
//!
//! Vectrex Studio downloads it into `<pico_home>/<version>/` (`$VECTREX_STUDIO_PICO_SDK_DIR`
//! or `~/VectrexStudio/pico-sdk`), with the same `.vectrex-studio-sdk.json` marker as the SDK.
//! vpy_cli never downloads; resolution order:
//!   1. `UVM2_PICO_SDK`, then `PICO_SDK_PATH` (the pico-sdk's own convention)
//!   2. `<pico_home>/<version>/`, only if its marker exists
//!
//! The Arm GNU Toolchain is too big and too platform-specific to download: it is found, not
//! fetched — `UVM2_ARM_TOOLCHAIN`, then the standard install locations. It must be the Arm
//! build: Homebrew's arm-none-eabi-gcc ships no nosys.specs and the pico-sdk link needs it.

use std::fmt::Write as _;
use std::path::{Path, PathBuf};

use crate::sdk::SDK_MARKER;

pub const DEFAULT_PICO_SDK_VERSION: &str = "2.2.0";

/// A file every pico-sdk checkout has, and the one the uvm2 build passes to CMake.
pub const PICO_TOOLCHAIN_FILE: &str = "cmake/preload/toolchains/pico_arm_cortex_m33_gcc.cmake";

fn is_valid_pico_version(v: &str) -> bool {
    let parts: Vec<&str> = v.split('.').collect();
    parts.len() == 3 && parts.iter().all(|p| !p.is_empty() && p.chars().all(|c| c.is_ascii_digit()))
}

/// The pico-sdk version an SDK release asks for (`<sdk_root>/PICO_SDK_VERSION`, else the default).
pub fn pico_sdk_version_for(sdk_root: &Path) -> String {
    std::fs::read_to_string(sdk_root.join("PICO_SDK_VERSION"))
        .ok()
        .map(|s| s.trim().to_string())
        .filter(|v| is_valid_pico_version(v))
        .unwrap_or_else(|| DEFAULT_PICO_SDK_VERSION.to_string())
}

pub fn default_pico_home() -> Option<PathBuf> {
    if let Some(d) = std::env::var_os("VECTREX_STUDIO_PICO_SDK_DIR") {
        return Some(PathBuf::from(d));
    }
    std::env::var_os("HOME")
        .or_else(|| std::env::var_os("USERPROFILE"))
        .map(|h| PathBuf::from(h).join("VectrexStudio").join("pico-sdk"))
}

/// Find the pico-sdk. `env` is (`UVM2_PICO_SDK`, `PICO_SDK_PATH`) as captured by the caller.
pub fn resolve_pico_sdk(
    env_uvm2_pico_sdk: Option<PathBuf>,
    env_pico_sdk_path: Option<PathBuf>,
    pico_home: Option<&Path>,
    version: &str,
) -> Result<PathBuf, String> {
    let mut looked = String::new();
    for (name, dir) in [("$UVM2_PICO_SDK", env_uvm2_pico_sdk), ("$PICO_SDK_PATH", env_pico_sdk_path)] {
        if let Some(dir) = dir {
            if dir.join(PICO_TOOLCHAIN_FILE).is_file() {
                return Ok(dir);
            }
            let _ = writeln!(looked, "    - {} (from {}: no {})", dir.display(), name, PICO_TOOLCHAIN_FILE);
        }
    }
    if is_valid_pico_version(version) {
        if let Some(home) = pico_home {
            let dir = home.join(version);
            if !dir.join(SDK_MARKER).is_file() {
                let _ = writeln!(looked, "    - {} (not installed: no {})", dir.display(), SDK_MARKER);
            } else if !dir.join(PICO_TOOLCHAIN_FILE).is_file() {
                let _ = writeln!(looked, "    - {} (installed, but has no {})", dir.display(), PICO_TOOLCHAIN_FILE);
            } else {
                return Ok(dir);
            }
        }
    }
    Err(format!(
        "pico-sdk {version} not found.\n  Looked in:\n{looked}  \
         Building the project for uvm2 in Vectrex Studio downloads it{}, or set UVM2_PICO_SDK=<pico-sdk checkout>.",
        pico_home.map(|h| format!(" (into {})", h.display())).unwrap_or_default()
    ))
}

/// Candidate Arm toolchain folders (`.../arm-none-eabi`) in the standard install locations,
/// newest version first within each location.
pub fn standard_toolchain_candidates() -> Vec<PathBuf> {
    let mut out = Vec::new();
    for (base, prefix) in [
        ("/Applications/ArmGNUToolchain", ""),   // macOS installer
        ("/opt", "arm-gnu-toolchain"),            // Linux tarball convention
        ("/usr/local", "arm-gnu-toolchain"),
    ] {
        let Ok(rd) = std::fs::read_dir(base) else { continue };
        let mut found: Vec<PathBuf> = rd
            .flatten()
            .filter(|e| e.file_name().to_string_lossy().starts_with(prefix))
            .map(|e| {
                let p = e.path();
                if p.join("arm-none-eabi").is_dir() { p.join("arm-none-eabi") } else { p }
            })
            .collect();
        found.sort_by(|a, b| version_key(b).cmp(&version_key(a)));
        out.extend(found);
    }
    out
}

/// Numeric runs of a path's text, so 15.2.rel1 sorts above 14.3.rel1 and 13.10 above 13.9.
fn version_key(p: &Path) -> Vec<u64> {
    p.to_string_lossy()
        .split(|c: char| !c.is_ascii_digit())
        .filter(|s| !s.is_empty())
        .filter_map(|s| s.parse().ok())
        .collect()
}

fn gcc_name() -> &'static str {
    if cfg!(windows) { "arm-none-eabi-gcc.exe" } else { "arm-none-eabi-gcc" }
}

/// Usable = has the compiler and the newlib nosys.specs the pico-sdk link needs.
fn toolchain_problem(dir: &Path) -> Option<String> {
    if !dir.join("bin").join(gcc_name()).is_file() {
        return Some(format!("no bin/{}", gcc_name()));
    }
    if !contains_file(dir, "nosys.specs", 6) {
        return Some("no nosys.specs (the Homebrew build? the pico-sdk link needs the Arm one)".into());
    }
    None
}

fn contains_file(dir: &Path, name: &str, depth: u32) -> bool {
    let Ok(rd) = std::fs::read_dir(dir) else { return false };
    for e in rd.flatten() {
        let p = e.path();
        if e.file_name() == name {
            return true;
        }
        if depth > 0 && p.is_dir() && contains_file(&p, name, depth - 1) {
            return true;
        }
    }
    false
}

/// Find the Arm GNU Toolchain: `UVM2_ARM_TOOLCHAIN`, then `candidates` in order.
pub fn resolve_arm_toolchain(env: Option<PathBuf>, candidates: &[PathBuf]) -> Result<PathBuf, String> {
    let mut looked = String::new();
    if let Some(dir) = env {
        match toolchain_problem(&dir) {
            None => return Ok(dir),
            Some(why) => { let _ = writeln!(looked, "    - {} (from $UVM2_ARM_TOOLCHAIN: {})", dir.display(), why); }
        }
    }
    for dir in candidates {
        match toolchain_problem(dir) {
            None => return Ok(dir.clone()),
            Some(why) => { let _ = writeln!(looked, "    - {} ({})", dir.display(), why); }
        }
    }
    if looked.is_empty() {
        looked.push_str("    - /Applications/ArmGNUToolchain/*, /opt/arm-gnu-toolchain*, /usr/local/arm-gnu-toolchain* (none present)\n");
    }
    Err(format!(
        "Arm GNU Toolchain not found.\n  Looked in:\n{looked}  \
         Install it from developer.arm.com (arm-gnu-toolchain, bare-metal AArch32 arm-none-eabi),\n  \
         or point the build at yours: UVM2_ARM_TOOLCHAIN=/path/to/arm-none-eabi"
    ))
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use tempfile::TempDir;

    fn pico_install(home: &Path, version: &str, marker: bool) -> PathBuf {
        let dir = home.join(version);
        let tc = dir.join(PICO_TOOLCHAIN_FILE);
        fs::create_dir_all(tc.parent().unwrap()).unwrap();
        fs::write(&tc, "").unwrap();
        if marker {
            fs::write(dir.join(SDK_MARKER), "{}").unwrap();
        }
        dir
    }

    fn toolchain(root: &Path, name: &str, nosys: bool) -> PathBuf {
        let dir = root.join(name).join("arm-none-eabi");
        fs::create_dir_all(dir.join("bin")).unwrap();
        fs::write(dir.join("bin").join(gcc_name()), "").unwrap();
        if nosys {
            fs::create_dir_all(dir.join("arm-none-eabi/lib")).unwrap();
            fs::write(dir.join("arm-none-eabi/lib/nosys.specs"), "").unwrap();
        }
        dir
    }

    #[test]
    fn version_file_overrides_default() {
        let t = TempDir::new().unwrap();
        assert_eq!(pico_sdk_version_for(t.path()), DEFAULT_PICO_SDK_VERSION);
        fs::write(t.path().join("PICO_SDK_VERSION"), "2.3.1\n").unwrap();
        assert_eq!(pico_sdk_version_for(t.path()), "2.3.1");
        fs::write(t.path().join("PICO_SDK_VERSION"), "../evil").unwrap();
        assert_eq!(pico_sdk_version_for(t.path()), DEFAULT_PICO_SDK_VERSION);
    }

    #[test]
    fn installed_version_resolves_and_needs_marker() {
        let t = TempDir::new().unwrap();
        let dir = pico_install(t.path(), "2.2.0", true);
        assert_eq!(resolve_pico_sdk(None, None, Some(t.path()), "2.2.0").unwrap(), dir);
        pico_install(t.path(), "2.1.0", false);
        let err = resolve_pico_sdk(None, None, Some(t.path()), "2.1.0").unwrap_err();
        assert!(err.contains("not installed") && err.contains("2.1.0"), "{err}");
    }

    #[test]
    fn env_beats_home_and_broken_env_falls_through() {
        let t = TempDir::new().unwrap();
        let home_dir = pico_install(&t.path().join("home"), "2.2.0", true);
        let env_dir = pico_install(&t.path().join("env"), "x", false);
        assert_eq!(resolve_pico_sdk(Some(env_dir.clone()), None, Some(&t.path().join("home")), "2.2.0").unwrap(), env_dir);
        assert_eq!(resolve_pico_sdk(None, Some(env_dir.clone()), Some(&t.path().join("home")), "2.2.0").unwrap(), env_dir);
        let broken = t.path().join("nothing");
        assert_eq!(resolve_pico_sdk(Some(broken), None, Some(&t.path().join("home")), "2.2.0").unwrap(), home_dir);
    }

    #[test]
    fn invalid_version_never_becomes_a_path() {
        let t = TempDir::new().unwrap();
        pico_install(t.path(), "2.2.0", true);
        assert!(resolve_pico_sdk(None, None, Some(t.path()), "../2.2.0").is_err());
    }

    #[test]
    fn toolchain_env_then_candidates_and_nosys_required() {
        let t = TempDir::new().unwrap();
        let homebrew = toolchain(t.path(), "brew", false);
        let arm = toolchain(t.path(), "15.2.rel1", true);
        assert_eq!(resolve_arm_toolchain(None, &[homebrew.clone(), arm.clone()]).unwrap(), arm);
        assert_eq!(resolve_arm_toolchain(Some(arm.clone()), &[]).unwrap(), arm);
        let err = resolve_arm_toolchain(Some(homebrew), &[]).unwrap_err();
        assert!(err.contains("nosys.specs") && err.contains("UVM2_ARM_TOOLCHAIN"), "{err}");
    }

    #[test]
    fn newest_toolchain_sorts_first() {
        let mut v = vec![PathBuf::from("/A/13.9.rel1"), PathBuf::from("/A/15.2.rel1"), PathBuf::from("/A/13.10.rel1")];
        v.sort_by(|a, b| version_key(b).cmp(&version_key(a)));
        assert_eq!(v[0], PathBuf::from("/A/15.2.rel1"));
        assert_eq!(v[1], PathBuf::from("/A/13.10.rel1"));
    }
}
