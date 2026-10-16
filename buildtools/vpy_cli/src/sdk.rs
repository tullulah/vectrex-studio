//! uvmc2-sdk resolution.
//!
//! The SDK (`uvm2-sdk/`, `vpy-c/`, `pitrex-sim/`, `rp2350-sdk/`, `tools/`, `vectrex-draw/`, ...)
//! is NOT bundled with vpy_cli or the IDE. Each project pins a release in its .vpyproj:
//!
//! ```toml
//! [sdk]
//! version = "v1.3.1"
//! ```
//!
//! and Vectrex Studio downloads that release into `<sdk_home>/<version>/`, where `sdk_home`
//! is `$VECTREX_STUDIO_SDK_DIR` or `~/VectrexStudio/sdk`. An installed release contains the
//! marker file `.vectrex-studio-sdk.json`. vpy_cli never downloads anything; it only finds.
//!
//! Resolution order for a given SDK subdirectory (e.g. `uvm2-sdk`):
//!   1. the subdir-specific env var (`UVM2_SDK_DIR`, `VPY_C_DIR`) — points straight at the subdir
//!   2. `UVMC2_SDK` — the SDK root; the subdir is `<root>/<subdir>`
//!   3. the project's `[sdk] version` → `<sdk_home>/<version>/<subdir>`, only if
//!      `<sdk_home>/<version>/.vectrex-studio-sdk.json` exists (a plain .vpy has no project,
//!      so only 1 and 2 apply)
//!
//! Each candidate must also contain the subdir's sentinel file (`uvm2_bus.c`, `vpy.c`), else
//! the next one is tried. The resolver is a pure function of [`SdkInputs`] so tests need no
//! process-global env mutation.

use std::fmt::Write as _;
use std::path::{Path, PathBuf};

/// Marker file written by the IDE into every installed SDK release.
pub const SDK_MARKER: &str = ".vectrex-studio-sdk.json";

/// What the input being built says about the SDK.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ProjectSdk {
    /// Input is a plain .vpy, not a .vpyproj.
    NoProject,
    /// .vpyproj with no `[sdk] version`.
    Unpinned { vpyproj: PathBuf },
    /// .vpyproj pins this version (not yet validated).
    Pinned { vpyproj: PathBuf, version: String },
    /// .vpyproj whose `[sdk]` section could not be read.
    Unreadable { vpyproj: PathBuf, error: String },
}

/// Everything the resolver depends on, captured up front (env + project).
#[derive(Debug, Clone)]
pub struct SdkInputs {
    pub env_uvmc2_sdk: Option<PathBuf>,
    pub env_uvm2_sdk_dir: Option<PathBuf>,
    pub env_vpy_c_dir: Option<PathBuf>,
    /// `$VECTREX_STUDIO_SDK_DIR` or `~/VectrexStudio/sdk` (None if no home dir is known).
    pub sdk_home: Option<PathBuf>,
    pub project: ProjectSdk,
}

/// One SDK subdirectory: its name under the root, its override env var, and a file that
/// proves the directory is the real thing.
#[derive(Debug, Clone, Copy)]
pub struct SdkPart {
    pub subdir: &'static str,
    pub env_var: &'static str,
    pub sentinel: &'static str,
    pub label: &'static str,
}

pub const UVM2_SDK: SdkPart = SdkPart {
    subdir: "uvm2-sdk",
    env_var: "UVM2_SDK_DIR",
    sentinel: "uvm2_bus.c",
    label: "UVM2 SDK (uvm2-sdk)",
};

pub const VPY_C: SdkPart = SdkPart {
    subdir: "vpy-c",
    env_var: "VPY_C_DIR",
    sentinel: "vpy.c",
    label: "libvpy C runtime (vpy-c)",
};

/// Where a resolved directory came from (for logging).
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum SdkSource {
    SubdirEnv(&'static str),
    RootEnv,
    Project { version: String },
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Resolved {
    pub dir: PathBuf,
    pub source: SdkSource,
}

impl Resolved {
    pub fn describe(&self) -> String {
        match &self.source {
            SdkSource::SubdirEnv(v) => format!("{} (from ${})", self.dir.display(), v),
            SdkSource::RootEnv => format!("{} (from $UVMC2_SDK)", self.dir.display()),
            SdkSource::Project { version } => {
                format!("{} (SDK {} pinned by the project)", self.dir.display(), version)
            }
        }
    }
}

impl SdkInputs {
    /// Capture the process environment and the `[sdk]` pin of `input` (if it is a .vpyproj).
    pub fn from_env(input: &Path) -> Self {
        let env_path = |k: &str| {
            std::env::var_os(k).filter(|v| !v.is_empty()).map(PathBuf::from)
        };
        let sdk_home = env_path("VECTREX_STUDIO_SDK_DIR").or_else(|| {
            env_path("HOME")
                .or_else(|| env_path("USERPROFILE"))
                .map(|h| h.join("VectrexStudio").join("sdk"))
        });
        let project = if input.extension().and_then(|s| s.to_str()) == Some("vpyproj") {
            let vpyproj = input.to_path_buf();
            match vpy_loader::read_sdk_config(input) {
                Ok(Some(vpy_loader::SdkConfig { version: Some(version) })) => {
                    ProjectSdk::Pinned { vpyproj, version }
                }
                Ok(_) => ProjectSdk::Unpinned { vpyproj },
                Err(e) => ProjectSdk::Unreadable { vpyproj, error: e.to_string() },
            }
        } else {
            ProjectSdk::NoProject
        };
        SdkInputs {
            env_uvmc2_sdk: env_path("UVMC2_SDK"),
            env_uvm2_sdk_dir: env_path("UVM2_SDK_DIR"),
            env_vpy_c_dir: env_path("VPY_C_DIR"),
            sdk_home,
            project,
        }
    }

    fn subdir_env(&self, part: &SdkPart) -> Option<&PathBuf> {
        match part.env_var {
            "UVM2_SDK_DIR" => self.env_uvm2_sdk_dir.as_ref(),
            "VPY_C_DIR" => self.env_vpy_c_dir.as_ref(),
            _ => None,
        }
    }
}

/// Resolve one SDK subdirectory. On failure the error is a ready-to-print, actionable
/// message (what the project pins, every place that was looked at, how to fix it).
pub fn resolve(inputs: &SdkInputs, part: &SdkPart) -> Result<Resolved, String> {
    let ok = |p: &Path| p.join(part.sentinel).is_file();
    // One line per rejected candidate, for the error message.
    let mut tried: Vec<String> = Vec::new();

    // 1. Subdir-specific env var.
    if let Some(p) = inputs.subdir_env(part) {
        if ok(p) {
            return Ok(Resolved { dir: p.clone(), source: SdkSource::SubdirEnv(part.env_var) });
        }
        tried.push(format!("${}={} (no {})", part.env_var, p.display(), part.sentinel));
    }

    // 2. SDK root env var.
    if let Some(root) = &inputs.env_uvmc2_sdk {
        let p = root.join(part.subdir);
        if ok(&p) {
            return Ok(Resolved { dir: p, source: SdkSource::RootEnv });
        }
        tried.push(format!("$UVMC2_SDK={} (no {}/{})", root.display(), part.subdir, part.sentinel));
    }

    // 3. Version pinned by the project.
    let home_desc = inputs
        .sdk_home
        .as_ref()
        .map(|h| h.display().to_string())
        .unwrap_or_else(|| "~/VectrexStudio/sdk (no home directory known)".into());
    let pin_line: String;
    let fix_line: String;
    match &inputs.project {
        ProjectSdk::NoProject => {
            pin_line = "The input is a plain .vpy file (no .vpyproj), so no SDK version is pinned \
                        and only environment variables are consulted."
                .into();
            fix_line = format!(
                "Build the .vpyproj instead, or set UVMC2_SDK=<sdk root> (or {}=<dir>).",
                part.env_var
            );
        }
        ProjectSdk::Unpinned { vpyproj } => {
            pin_line = format!("{} pins no SDK version (no [sdk] version).", vpyproj.display());
            fix_line = "Add `[sdk] version = \"vX.Y.Z\"` to the project (opening it in Vectrex \
                        Studio does this and downloads the SDK), or set UVMC2_SDK=<sdk root>."
                .into();
        }
        ProjectSdk::Unreadable { vpyproj, error } => {
            pin_line = format!("Could not read the [sdk] section of {}: {}", vpyproj.display(), error);
            fix_line = "Fix the [sdk] section (version = \"vX.Y.Z\"), or set UVMC2_SDK=<sdk root>."
                .into();
        }
        ProjectSdk::Pinned { vpyproj, version } => {
            pin_line = format!("{} pins SDK {}.", vpyproj.display(), version);
            if !vpy_loader::is_valid_sdk_version(version) {
                tried.push(format!(
                    "[sdk] version = {:?} is not a valid release tag (expected vX.Y.Z)",
                    version
                ));
                fix_line = "Set [sdk] version to a release tag like \"v1.3.1\", or set \
                            UVMC2_SDK=<sdk root>."
                    .into();
            } else {
                fix_line = format!(
                    "Open or build the project in Vectrex Studio to download SDK {} \
                     (into {}), or set UVMC2_SDK=<sdk root>.",
                    version, home_desc
                );
                if let Some(home) = &inputs.sdk_home {
                    let root = home.join(version);
                    let p = root.join(part.subdir);
                    if !root.join(SDK_MARKER).is_file() {
                        tried.push(format!("{} (not installed: no {})", root.display(), SDK_MARKER));
                    } else if !ok(&p) {
                        tried.push(format!(
                            "{} (installed, but has no {}/{})",
                            root.display(),
                            part.subdir,
                            part.sentinel
                        ));
                    } else {
                        return Ok(Resolved {
                            dir: p,
                            source: SdkSource::Project { version: version.clone() },
                        });
                    }
                } else {
                    tried.push("SDK home: unknown (set VECTREX_STUDIO_SDK_DIR or HOME)".into());
                }
            }
        }
    }

    let mut msg = format!("{} not found.\n  {}\n", part.label, pin_line);
    if tried.is_empty() {
        let _ = writeln!(msg, "  Looked in: nothing ({} and UVMC2_SDK are unset)", part.env_var);
    } else {
        let _ = writeln!(msg, "  Looked in:");
        for t in &tried {
            let _ = writeln!(msg, "    - {}", t);
        }
    }
    let _ = write!(msg, "  {}", fix_line);
    Err(msg)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use tempfile::TempDir;

    /// Create `<home>/<version>/` with (optionally) the marker and the given parts.
    fn install(home: &Path, version: &str, marker: bool, parts: &[&SdkPart]) -> PathBuf {
        let root = home.join(version);
        fs::create_dir_all(&root).unwrap();
        if marker {
            fs::write(root.join(SDK_MARKER), "{\"tag\":\"x\"}").unwrap();
        }
        for p in parts {
            fs::create_dir_all(root.join(p.subdir)).unwrap();
            fs::write(root.join(p.subdir).join(p.sentinel), "").unwrap();
        }
        root
    }

    fn inputs(home: &Path, project: ProjectSdk) -> SdkInputs {
        SdkInputs {
            env_uvmc2_sdk: None,
            env_uvm2_sdk_dir: None,
            env_vpy_c_dir: None,
            sdk_home: Some(home.to_path_buf()),
            project,
        }
    }

    fn pinned(v: &str) -> ProjectSdk {
        ProjectSdk::Pinned { vpyproj: PathBuf::from("game.vpyproj"), version: v.into() }
    }

    #[test]
    fn project_pin_resolves_to_installed_folder() {
        let t = TempDir::new().unwrap();
        let root = install(t.path(), "v1.3.1", true, &[&UVM2_SDK, &VPY_C]);
        let i = inputs(t.path(), pinned("v1.3.1"));
        let r = resolve(&i, &UVM2_SDK).unwrap();
        assert_eq!(r.dir, root.join("uvm2-sdk"));
        assert_eq!(r.source, SdkSource::Project { version: "v1.3.1".into() });
        assert_eq!(resolve(&i, &VPY_C).unwrap().dir, root.join("vpy-c"));
    }

    #[test]
    fn missing_marker_is_not_installed() {
        let t = TempDir::new().unwrap();
        install(t.path(), "v1.3.1", false, &[&UVM2_SDK]);
        let err = resolve(&inputs(t.path(), pinned("v1.3.1")), &UVM2_SDK).unwrap_err();
        assert!(err.contains("pins SDK v1.3.1"), "{err}");
        assert!(err.contains(SDK_MARKER), "{err}");
        assert!(err.contains("Vectrex Studio"), "{err}");
    }

    #[test]
    fn other_version_installed_does_not_match() {
        let t = TempDir::new().unwrap();
        install(t.path(), "v1.3.0", true, &[&UVM2_SDK]);
        assert!(resolve(&inputs(t.path(), pinned("v1.3.1")), &UVM2_SDK).is_err());
    }

    #[test]
    fn invalid_version_rejected_without_touching_paths() {
        let t = TempDir::new().unwrap();
        // A traversal that WOULD hit a valid install if used as a path component.
        install(t.path(), "v1.3.1", true, &[&UVM2_SDK]);
        fs::create_dir_all(t.path().join("x")).unwrap();
        let err = resolve(&inputs(&t.path().join("x"), pinned("../v1.3.1")), &UVM2_SDK).unwrap_err();
        assert!(err.contains("not a valid release tag"), "{err}");
        assert!(resolve(&inputs(t.path(), pinned("1.3.1")), &UVM2_SDK).is_err());
    }

    #[test]
    fn env_beats_project() {
        let t = TempDir::new().unwrap();
        install(t.path(), "v1.3.1", true, &[&UVM2_SDK, &VPY_C]);
        let env_root = install(&t.path().join("envsdk"), "root", false, &[&UVM2_SDK, &VPY_C]);
        let sub = install(&t.path().join("sub"), "only", false, &[&UVM2_SDK]);

        // UVMC2_SDK root beats the project pin.
        let mut i = inputs(t.path(), pinned("v1.3.1"));
        i.env_uvmc2_sdk = Some(env_root.clone());
        let r = resolve(&i, &UVM2_SDK).unwrap();
        assert_eq!(r.dir, env_root.join("uvm2-sdk"));
        assert_eq!(r.source, SdkSource::RootEnv);

        // The subdir-specific var beats both.
        i.env_uvm2_sdk_dir = Some(sub.join("uvm2-sdk"));
        let r = resolve(&i, &UVM2_SDK).unwrap();
        assert_eq!(r.dir, sub.join("uvm2-sdk"));
        assert_eq!(r.source, SdkSource::SubdirEnv("UVM2_SDK_DIR"));
        // ...but only for its own part: vpy-c still comes from UVMC2_SDK.
        assert_eq!(resolve(&i, &VPY_C).unwrap().source, SdkSource::RootEnv);
    }

    #[test]
    fn broken_env_falls_through_to_project() {
        let t = TempDir::new().unwrap();
        let root = install(t.path(), "v1.3.1", true, &[&UVM2_SDK]);
        let mut i = inputs(t.path(), pinned("v1.3.1"));
        i.env_uvmc2_sdk = Some(t.path().join("nope"));
        i.env_uvm2_sdk_dir = Some(t.path().join("nope2"));
        assert_eq!(resolve(&i, &UVM2_SDK).unwrap().dir, root.join("uvm2-sdk"));
    }

    #[test]
    fn plain_vpy_uses_env_only() {
        let t = TempDir::new().unwrap();
        install(t.path(), "v1.3.1", true, &[&UVM2_SDK]);
        let err = resolve(&inputs(t.path(), ProjectSdk::NoProject), &UVM2_SDK).unwrap_err();
        assert!(err.contains("plain .vpy"), "{err}");
        assert!(err.contains("UVMC2_SDK"), "{err}");

        let mut i = inputs(t.path(), ProjectSdk::NoProject);
        i.env_uvmc2_sdk = Some(t.path().join("v1.3.1"));
        assert_eq!(resolve(&i, &UVM2_SDK).unwrap().source, SdkSource::RootEnv);
    }

    #[test]
    fn unpinned_project_error_says_so() {
        let t = TempDir::new().unwrap();
        let p = ProjectSdk::Unpinned { vpyproj: PathBuf::from("game.vpyproj") };
        let err = resolve(&inputs(t.path(), p), &UVM2_SDK).unwrap_err();
        assert!(err.contains("pins no SDK version"), "{err}");
    }

    #[test]
    fn from_env_reads_project_pin() {
        // Only the project part of from_env is asserted (env vars are process-global).
        let t = TempDir::new().unwrap();
        let proj = t.path().join("game.vpyproj");
        fs::write(&proj, "[project]\nname = \"g\"\n\n[sdk]\nversion = \"v1.3.1\"\n").unwrap();
        assert_eq!(
            SdkInputs::from_env(&proj).project,
            ProjectSdk::Pinned { vpyproj: proj.clone(), version: "v1.3.1".into() }
        );
        assert_eq!(SdkInputs::from_env(&t.path().join("main.vpy")).project, ProjectSdk::NoProject);
    }
}
