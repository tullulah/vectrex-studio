// vpy_loader: Parse .vpyproj and discover source files
//
// Phase 1 of the compilation pipeline.
// Reads project metadata and file structure.

use serde::{Deserialize, Serialize};
use std::path::{Path, PathBuf};
use thiserror::Error;

#[derive(Debug, Clone, Error)]
pub enum LoadError {
    #[error("IO error: {0}")]
    Io(String),
    #[error("TOML parse error: {0}")]
    TomlError(String),
    #[error("Invalid project: {0}")]
    InvalidProject(String),
    #[error("File not found: {0}")]
    FileNotFound(String),
}

/// Project metadata from .vpyproj file
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct ProjectMetadata {
    pub title: Option<String>,
    pub author: Option<String>,
    pub version: Option<String>,
    pub music: Option<bool>,
    pub entry: Option<String>, // Entry point file path (e.g., "src/main.vpy")

    // Multibank configuration
    #[serde(default)]
    pub rom_total_size: Option<usize>,
    #[serde(default)]
    pub rom_bank_size: Option<usize>,
}

impl ProjectMetadata {
    /// Check if this project is configured for multibank
    pub fn is_multibank(&self) -> bool {
        self.rom_total_size.is_some() && self.rom_bank_size.is_some()
    }

    /// Get number of banks in this project
    pub fn num_banks(&self) -> usize {
        match (self.rom_total_size, self.rom_bank_size) {
            (Some(total), Some(bank_size)) => total / bank_size,
            _ => 1,
        }
    }
}

/// `[sdk]` section of a .vpyproj: which uvmc2-sdk release this project is built against.
///
/// ```toml
/// [sdk]
/// version = "v1.3.1"
/// ```
///
/// The SDK is NOT bundled with the compiler or the IDE: Vectrex Studio downloads the pinned
/// version into `~/VectrexStudio/sdk/<version>/` (root overridable with
/// `VECTREX_STUDIO_SDK_DIR`). The loader only reports what the project pins; it does not
/// validate or resolve it (see [`is_valid_sdk_version`] and vpy_cli's SDK resolver).
#[derive(Debug, Clone, Serialize, Deserialize, Default, PartialEq, Eq)]
pub struct SdkConfig {
    pub version: Option<String>,
}

/// True if `v` is a well-formed SDK release tag: `^v\d+(\.\d+){0,3}$` (e.g. `v1`, `v1.3.1`).
///
/// The version becomes a path component (`<sdk_root>/<version>`), so anything else
/// (separators, `..`, empty, pre-release suffixes) is rejected before touching the filesystem.
pub fn is_valid_sdk_version(v: &str) -> bool {
    let Some(rest) = v.strip_prefix('v') else { return false };
    let parts: Vec<&str> = rest.split('.').collect();
    !parts.is_empty()
        && parts.len() <= 4
        && parts.iter().all(|p| !p.is_empty() && p.bytes().all(|b| b.is_ascii_digit()))
}

/// Read only the `[sdk]` section of a .vpyproj (no entry-point / source discovery).
///
/// Returns `Ok(None)` when the project has no `[sdk]` table.
pub fn read_sdk_config(vpyproj_path: &Path) -> Result<Option<SdkConfig>, LoadError> {
    let content = std::fs::read_to_string(vpyproj_path)
        .map_err(|e| LoadError::Io(e.to_string()))?;
    parse_sdk_config(&content)
}

/// Parse the `[sdk]` section out of .vpyproj TOML text.
pub fn parse_sdk_config(content: &str) -> Result<Option<SdkConfig>, LoadError> {
    let table: toml::Table = toml::from_str(content)
        .map_err(|e| LoadError::TomlError(e.to_string()))?;
    sdk_from_table(&table)
}

fn sdk_from_table(table: &toml::Table) -> Result<Option<SdkConfig>, LoadError> {
    match table.get("sdk") {
        None => Ok(None),
        Some(v) => v.clone().try_into::<SdkConfig>()
            .map(Some)
            .map_err(|e| LoadError::InvalidProject(format!("invalid [sdk] section: {}", e))),
    }
}

/// Discovered source file
#[derive(Debug, Clone, Eq, PartialEq)]
pub struct SourceFile {
    pub path: PathBuf,
    pub is_entry: bool, // Is this the main entry point?
}

/// Asset file (vector, music, recording, or audio sample)
#[derive(Debug, Clone, Eq, PartialEq)]
pub enum AssetFile {
    Vector(PathBuf),
    Music(PathBuf),
    /// .vrec — multi-frame vector recording (game-preview / attract playback)
    Recording(PathBuf),
    /// .vsmp — 4-bit PCM audio sample (voice/vector-movie audio track, PSG volume DAC)
    Sample(PathBuf),
}

/// Complete project information
#[derive(Debug, Clone)]
pub struct ProjectInfo {
    pub metadata: ProjectMetadata,
    pub root_dir: PathBuf,
    pub source_files: Vec<SourceFile>,
    pub asset_files: Vec<AssetFile>,
    pub entry_point: PathBuf, // Path to main.vpy
    /// `[sdk]` section, if the project pins an SDK version.
    pub sdk: Option<SdkConfig>,
}

impl ProjectInfo {
    pub fn is_multibank(&self) -> bool {
        self.metadata.is_multibank()
    }

    pub fn num_banks(&self) -> usize {
        self.metadata.num_banks()
    }
}

/// Expand glob pattern and return matching files
fn expand_glob_pattern(pattern: &str, root_dir: &Path) -> Result<Vec<PathBuf>, LoadError> {
    let full_pattern = root_dir.join(pattern).to_string_lossy().to_string();
    let mut files = Vec::new();
    
    match glob::glob(&full_pattern) {
        Ok(paths) => {
            for entry in paths {
                match entry {
                    Ok(path) => files.push(path),
                    Err(e) => return Err(LoadError::Io(format!("Glob error: {}", e))),
                }
            }
        }
        Err(e) => return Err(LoadError::Io(format!("Glob pattern error: {}", e))),
    }
    
    // Sort for deterministic ordering across platforms/filesystems
    files.sort();
    Ok(files)
}

/// Load a .vpyproj project
pub fn load_project(vpyproj_path: &Path) -> Result<ProjectInfo, LoadError> {
    // Read and parse .vpyproj
    let content = std::fs::read_to_string(vpyproj_path)
        .map_err(|e| LoadError::Io(e.to_string()))?;

    // Parse as TOML table (root level)
    let table: toml::Table = toml::from_str(&content)
        .map_err(|e| LoadError::TomlError(e.to_string()))?;
    
    // Try to get metadata from [package] section, [project] section, or use root level
    let metadata = if let Some(project_val) = table.get("project") {
        // Try to deserialize from the project table directly from Value
        project_val.clone().try_into::<ProjectMetadata>()
            .unwrap_or_default()
    } else if let Some(package_val) = table.get("package") {
        // Try to deserialize from the package table
        package_val.clone().try_into::<ProjectMetadata>()
            .unwrap_or_default()
    } else {
        // Fallback: try to parse entire content as metadata
        toml::from_str::<ProjectMetadata>(&content)
            .unwrap_or_default()
    };

    // Lenient here (like the metadata above): a malformed [sdk] must not break targets
    // that need no SDK (m6809). The SDK resolver re-reads it with `read_sdk_config` and
    // reports the error where it matters.
    let sdk = sdk_from_table(&table).unwrap_or(None);

    let root_dir = vpyproj_path
        .parent()
        .ok_or_else(|| LoadError::InvalidProject("No parent directory".into()))?
        .to_path_buf();

    // Determine entry point from metadata or default to src/main.vpy
    let entry_point = if let Some(entry_path) = &metadata.entry {
        root_dir.join(entry_path)
    } else {
        root_dir.join("src/main.vpy")
    };

    // Verify entry point exists
    if !entry_point.exists() {
        return Err(LoadError::FileNotFound(
            format!("Entry point not found: {}", entry_point.display()),
        ));
    }

    // Read source files from [sources] section in TOML
    let mut source_files = Vec::new();
    
    if let Some(sources_val) = table.get("sources") {
        if let Some(vpy_array) = sources_val.get("vpy").and_then(|v| v.as_array()) {
            // Extract file paths from [sources] vpy array
            for item in vpy_array {
                if let Some(path_str) = item.as_str() {
                    // Check if this is a glob pattern
                    if path_str.contains('*') || path_str.contains('?') {
                        // Expand glob pattern
                        match expand_glob_pattern(path_str, &root_dir) {
                            Ok(files) => {
                                for file_path in files {
                                    if file_path.extension().map_or(false, |ext| ext == "vpy") {
                                        source_files.push(SourceFile {
                                            path: file_path,
                                            is_entry: false,
                                        });
                                    }
                                }
                            }
                            Err(_) => {
                                // Glob expansion failed, try as direct path
                                let full_path = root_dir.join(path_str);
                                if full_path.exists() && full_path.extension().map_or(false, |ext| ext == "vpy") {
                                    source_files.push(SourceFile {
                                        path: full_path,
                                        is_entry: false,
                                    });
                                }
                            }
                        }
                    } else {
                        // Direct path (no glob)
                        let full_path = root_dir.join(path_str);
                        if full_path.exists() && full_path.extension().map_or(false, |ext| ext == "vpy") {
                            source_files.push(SourceFile {
                                path: full_path,
                                is_entry: false,
                            });
                        }
                    }
                }
            }
        }
    }

    // If no sources found from TOML, fallback to discovering from entry point directory
    if source_files.is_empty() {
        if let Some(parent) = entry_point.parent() {
            if parent.exists() && parent.is_dir() {
                discover_vpy_files(parent, &mut source_files)?;
            } else {
                // Single file project - just add the entry point
                source_files.push(SourceFile {
                    path: entry_point.clone(),
                    is_entry: true,
                });
            }
        }
    }

    if source_files.is_empty() {
        return Err(LoadError::InvalidProject(
            "No .vpy files found in [sources] or in entry point directory".into(),
        ));
    }

    // Mark entry point
    for file in &mut source_files {
        file.is_entry = file.path == entry_point;
    }

    // Discover asset files from [resources] section
    let mut asset_files = Vec::new();
    
    if let Some(resources_val) = table.get("resources") {
        // Read vector assets
        if let Some(vectors_array) = resources_val.get("vectors").and_then(|v| v.as_array()) {
            for item in vectors_array {
                if let Some(path_str) = item.as_str() {
                    // Handle glob patterns
                    if path_str.contains('*') || path_str.contains('?') {
                        match expand_glob_pattern(path_str, &root_dir) {
                            Ok(files) => {
                                for file_path in files {
                                    if file_path.extension().map_or(false, |ext| ext == "vec") {
                                        asset_files.push(AssetFile::Vector(file_path));
                                    }
                                }
                            }
                            Err(_) => {}
                        }
                    } else {
                        let full_path = root_dir.join(path_str);
                        if full_path.exists() && full_path.extension().map_or(false, |ext| ext == "vec") {
                            asset_files.push(AssetFile::Vector(full_path));
                        }
                    }
                }
            }
        }
        // Read recording assets (.vrec — multi-frame segment captures)
        if let Some(rec_array) = resources_val.get("recordings").and_then(|v| v.as_array()) {
            for item in rec_array {
                if let Some(path_str) = item.as_str() {
                    // Handle glob patterns
                    if path_str.contains('*') || path_str.contains('?') {
                        match expand_glob_pattern(path_str, &root_dir) {
                            Ok(files) => {
                                for file_path in files {
                                    if file_path.extension().map_or(false, |ext| ext == "vrec") {
                                        asset_files.push(AssetFile::Recording(file_path));
                                    }
                                }
                            }
                            Err(_) => {}
                        }
                    } else {
                        let full_path = root_dir.join(path_str);
                        if full_path.exists() && full_path.extension().map_or(false, |ext| ext == "vrec") {
                            asset_files.push(AssetFile::Recording(full_path));
                        }
                    }
                }
            }
        }
        // Read audio-sample assets (.vsmp — 4-bit PCM voice/vector-movie audio)
        if let Some(smp_array) = resources_val.get("samples").and_then(|v| v.as_array()) {
            for item in smp_array {
                if let Some(path_str) = item.as_str() {
                    // Handle glob patterns
                    if path_str.contains('*') || path_str.contains('?') {
                        match expand_glob_pattern(path_str, &root_dir) {
                            Ok(files) => {
                                for file_path in files {
                                    if file_path.extension().map_or(false, |ext| ext == "vsmp") {
                                        asset_files.push(AssetFile::Sample(file_path));
                                    }
                                }
                            }
                            Err(_) => {}
                        }
                    } else {
                        let full_path = root_dir.join(path_str);
                        if full_path.exists() && full_path.extension().map_or(false, |ext| ext == "vsmp") {
                            asset_files.push(AssetFile::Sample(full_path));
                        }
                    }
                }
            }
        }
        // Read music assets
        if let Some(music_array) = resources_val.get("music").and_then(|v| v.as_array()) {
            for item in music_array {
                if let Some(path_str) = item.as_str() {
                    // Handle glob patterns
                    if path_str.contains('*') || path_str.contains('?') {
                        match expand_glob_pattern(path_str, &root_dir) {
                            Ok(files) => {
                                for file_path in files {
                                    if file_path.extension().map_or(false, |ext| ext == "vmus" || ext == "mus") {
                                        asset_files.push(AssetFile::Music(file_path));
                                    }
                                }
                            }
                            Err(_) => {}
                        }
                    } else {
                        let full_path = root_dir.join(path_str);
                        if full_path.exists() && full_path.extension().map_or(false, |ext| ext == "vmus" || ext == "mus") {
                            asset_files.push(AssetFile::Music(full_path));
                        }
                    }
                }
            }
        }
    }
    
    // Fallback: discover assets in standard directories if not in TOML
    if asset_files.is_empty() {
        let assets_dir = root_dir.join("assets");
        if assets_dir.exists() {
            discover_vector_assets(&assets_dir.join("vectors"), &mut asset_files)?;
            discover_music_assets(&assets_dir.join("music"), &mut asset_files)?;
            discover_recording_assets(&assets_dir.join("recordings"), &mut asset_files)?;
            discover_sample_assets(&assets_dir.join("samples"), &mut asset_files)?;
        }
    }

    Ok(ProjectInfo {
        metadata,
        root_dir,
        source_files,
        asset_files,
        entry_point,
        sdk,
    })
}

/// Recursively discover .vpy files
fn discover_vpy_files(dir: &Path, files: &mut Vec<SourceFile>) -> Result<(), LoadError> {
    let entries = std::fs::read_dir(dir)
        .map_err(|e| LoadError::Io(e.to_string()))?;

    // Collect and sort entries for deterministic ordering across platforms/filesystems
    let mut sorted_entries: Vec<_> = entries
        .filter_map(|e| e.ok())
        .collect();
    sorted_entries.sort_by_key(|e| e.path());

    for entry in sorted_entries {
        let path = entry.path();

        if path.is_dir() {
            discover_vpy_files(&path, files)?;
        } else if path.extension().map_or(false, |ext| ext == "vpy") {
            files.push(SourceFile {
                path,
                is_entry: false,
            });
        }
    }

    Ok(())
}

/// Discover .vec files in vectors directory
fn discover_vector_assets(dir: &Path, assets: &mut Vec<AssetFile>) -> Result<(), LoadError> {
    if !dir.exists() {
        return Ok(());
    }

    let entries = std::fs::read_dir(dir)
        .map_err(|e| LoadError::Io(e.to_string()))?;

    // Collect and sort for deterministic ordering across platforms/filesystems
    let mut paths: Vec<_> = entries
        .filter_map(|e| e.ok().map(|e| e.path()))
        .filter(|p| p.extension().map_or(false, |ext| ext == "vec"))
        .collect();
    paths.sort();

    for path in paths {
        assets.push(AssetFile::Vector(path));
    }

    Ok(())
}

/// Discover .vmus files in music directory
fn discover_music_assets(dir: &Path, assets: &mut Vec<AssetFile>) -> Result<(), LoadError> {
    if !dir.exists() {
        return Ok(());
    }

    let entries = std::fs::read_dir(dir)
        .map_err(|e| LoadError::Io(e.to_string()))?;

    // Collect and sort for deterministic ordering across platforms/filesystems
    let mut paths: Vec<_> = entries
        .filter_map(|e| e.ok().map(|e| e.path()))
        .filter(|p| p.extension().map_or(false, |ext| ext == "vmus"))
        .collect();
    paths.sort();

    for path in paths {
        assets.push(AssetFile::Music(path));
    }

    Ok(())
}

/// Discover .vrec files in recordings directory
fn discover_recording_assets(dir: &Path, assets: &mut Vec<AssetFile>) -> Result<(), LoadError> {
    if !dir.exists() {
        return Ok(());
    }

    let entries = std::fs::read_dir(dir)
        .map_err(|e| LoadError::Io(e.to_string()))?;

    // Collect and sort for deterministic ordering across platforms/filesystems
    let mut paths: Vec<_> = entries
        .filter_map(|e| e.ok().map(|e| e.path()))
        .filter(|p| p.extension().map_or(false, |ext| ext == "vrec"))
        .collect();
    paths.sort();

    for path in paths {
        assets.push(AssetFile::Recording(path));
    }

    Ok(())
}

/// Discover .vsmp files in samples directory
fn discover_sample_assets(dir: &Path, assets: &mut Vec<AssetFile>) -> Result<(), LoadError> {
    if !dir.exists() {
        return Ok(());
    }

    let entries = std::fs::read_dir(dir)
        .map_err(|e| LoadError::Io(e.to_string()))?;

    // Collect and sort for deterministic ordering across platforms/filesystems
    let mut paths: Vec<_> = entries
        .filter_map(|e| e.ok().map(|e| e.path()))
        .filter(|p| p.extension().map_or(false, |ext| ext == "vsmp"))
        .collect();
    paths.sort();

    for path in paths {
        assets.push(AssetFile::Sample(path));
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use tempfile::TempDir;

    /// Helper to create a test project structure
    fn create_test_project(
        multibank: bool,
    ) -> (TempDir, PathBuf) {
        let temp = TempDir::new().unwrap();
        let root = temp.path().to_path_buf();

        // Create src directory
        fs::create_dir(root.join("src")).unwrap();

        // Create main.vpy
        fs::write(
            root.join("src/main.vpy"),
            "def main():\n    pass\n\ndef loop():\n    pass\n",
        )
        .unwrap();

        // Create assets
        fs::create_dir_all(root.join("assets/vectors")).unwrap();
        fs::create_dir_all(root.join("assets/music")).unwrap();
        fs::create_dir_all(root.join("assets/recordings")).unwrap();
        fs::write(root.join("assets/vectors/player.vec"), "{}").unwrap();
        fs::write(root.join("assets/music/theme.vmus"), "{}").unwrap();
        fs::write(root.join("assets/recordings/preview.vrec"), "{}").unwrap();

        // Create .vpyproj
        let toml = if multibank {
            "title = \"Test Multibank\"\nrom_total_size = 524288\nrom_bank_size = 16384\n"
        } else {
            "title = \"Test Single\"\n"
        };

        fs::write(root.join("test.vpyproj"), toml).unwrap();

        (temp, root)
    }

    #[test]
    fn test_load_single_bank_project() {
        let (_temp, root) = create_test_project(false);
        let proj_path = root.join("test.vpyproj");

        let info = load_project(&proj_path).expect("Failed to load single-bank project");

        assert_eq!(info.metadata.title, Some("Test Single".into()));
        assert!(!info.is_multibank());
        assert_eq!(info.num_banks(), 1);
        assert_eq!(info.source_files.len(), 1);
        assert!(info.source_files[0].is_entry);
        assert_eq!(info.asset_files.len(), 3);
        assert!(info.asset_files.iter().any(|a| matches!(a, AssetFile::Recording(p) if p.ends_with("preview.vrec"))));
    }

    #[test]
    fn test_load_multibank_project() {
        let (_temp, root) = create_test_project(true);
        let proj_path = root.join("test.vpyproj");

        let info = load_project(&proj_path).expect("Failed to load multibank project");

        assert_eq!(info.metadata.title, Some("Test Multibank".into()));
        assert!(info.is_multibank());
        assert_eq!(info.num_banks(), 32);
        assert_eq!(info.source_files.len(), 1);
        assert_eq!(info.asset_files.len(), 3);
    }

    #[test]
    fn test_load_missing_main_vpy() {
        let temp = TempDir::new().unwrap();
        let root = temp.path();
        fs::create_dir(root.join("src")).unwrap();
        fs::write(
            root.join("test.vpyproj"),
            "title = \"Bad\"\n",
        )
        .unwrap();

        let result = load_project(&root.join("test.vpyproj"));
        // Since we're looking for main.vpy in src/, but src/ is empty,
        // the discover_vpy_files won't find anything
        // So the check for "No .vpy files found" will trigger first
        assert!(matches!(result, Err(LoadError::InvalidProject(_)) | Err(LoadError::FileNotFound(_))));
    }

    #[test]
    fn test_load_missing_vpyproj() {
        let temp = TempDir::new().unwrap();
        let missing = temp.path().join("nonexistent.vpyproj");

        let result = load_project(&missing);
        assert!(matches!(result, Err(LoadError::Io(_))));
    }

    #[test]
    fn test_discover_multiple_vpy_files() {
        let temp = TempDir::new().unwrap();
        let root = temp.path();

        fs::create_dir_all(root.join("src/modules")).unwrap();
        fs::write(root.join("src/main.vpy"), "def main(): pass\n").unwrap();
        fs::write(root.join("src/modules/input.vpy"), "def get_input(): pass\n").unwrap();
        fs::write(root.join("src/modules/graphics.vpy"), "def draw(): pass\n").unwrap();
        fs::create_dir_all(root.join("assets/vectors")).unwrap();
        fs::create_dir_all(root.join("assets/music")).unwrap();

        fs::write(
            root.join("test.vpyproj"),
            "[package]\ntitle = \"Multi-Module\"\n",
        )
        .unwrap();

        let info = load_project(&root.join("test.vpyproj")).unwrap();

        assert_eq!(info.source_files.len(), 3);
        let names: Vec<_> = info
            .source_files
            .iter()
            .map(|f| f.path.file_name().unwrap().to_str().unwrap())
            .collect();
        assert!(names.contains(&"main.vpy"));
        assert!(names.contains(&"input.vpy"));
        assert!(names.contains(&"graphics.vpy"));
    }

    #[test]
    fn test_sdk_version_parsed_from_vpyproj() {
        let (_temp, root) = create_test_project(false);
        let proj_path = root.join("test.vpyproj");
        fs::write(
            &proj_path,
            "[project]\nname = \"x\"\nversion = \"0.1.0\"\n\n[sdk]\nversion = \"v1.3.1\"\n",
        )
        .unwrap();

        let info = load_project(&proj_path).unwrap();
        assert_eq!(info.sdk, Some(SdkConfig { version: Some("v1.3.1".into()) }));
        // The project's own version must not leak into the SDK pin.
        assert_eq!(info.metadata.version, Some("0.1.0".into()));

        let direct = read_sdk_config(&proj_path).unwrap();
        assert_eq!(direct, info.sdk);
    }

    #[test]
    fn test_sdk_absent_is_none() {
        let (_temp, root) = create_test_project(false);
        let info = load_project(&root.join("test.vpyproj")).unwrap();
        assert_eq!(info.sdk, None);
        assert_eq!(read_sdk_config(&root.join("test.vpyproj")).unwrap(), None);
    }

    #[test]
    fn test_sdk_malformed_section() {
        // read_sdk_config reports it; load_project stays usable for SDK-less targets.
        assert!(parse_sdk_config("[sdk]\nversion = 1\n").is_err());
        let (_temp, root) = create_test_project(false);
        let proj_path = root.join("test.vpyproj");
        fs::write(&proj_path, "[sdk]\nversion = 1\n").unwrap();
        assert!(load_project(&proj_path).unwrap().sdk.is_none());
        assert!(read_sdk_config(&proj_path).is_err());
    }

    #[test]
    fn test_sdk_version_validation() {
        for ok in ["v1", "v1.3", "v1.3.1", "v10.0.0.2", "v0.0.0"] {
            assert!(is_valid_sdk_version(ok), "{ok} should be valid");
        }
        for bad in ["", "v", "1.3.1", "v1.", "v.1", "v1..2", "v1.2.3.4.5", "v1.3.1-rc1",
                    "v1/../..", "../v1", "v1.3.1 ", "V1.3.1", "v1.a"] {
            assert!(!is_valid_sdk_version(bad), "{bad:?} should be rejected");
        }
    }
}
