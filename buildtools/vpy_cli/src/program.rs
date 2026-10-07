//! Phases 1-3 for EVERY target: load the project (or a lone `.vpy`), parse every
//! source module, unify them into one module.
//!
//! All build paths (m6809, rp2350, uvm2, pitrex, `asm`) go through
//! [`load_program`], so an imported module is compiled the same way whatever the
//! backend, and an import that does not resolve fails the same way everywhere.

use anyhow::{anyhow, Context, Result};
use std::collections::HashMap;
use std::path::{Path, PathBuf};

/// A parsed + unified program.
pub struct Program {
    /// The unified module (Phase 3 output) the backends consume.
    pub unified: vpy_parser::Module,
    /// Path of the entry `.vpy`.
    pub entry_path: PathBuf,
    /// Module name of the entry (file stem).
    pub entry_module: String,
    /// The loaded project, when the input was a `.vpyproj`.
    pub project: Option<vpy_loader::ProjectInfo>,
    /// Number of modules that were parsed.
    pub module_count: usize,
}

/// Module name of a source file: its file stem (`src/physics.vpy` → `physics`).
fn module_name(path: &Path) -> String {
    path.file_stem().and_then(|s| s.to_str()).unwrap_or("main").to_string()
}

fn parse_file(path: &Path) -> Result<vpy_parser::Module> {
    let source = std::fs::read_to_string(path)
        .with_context(|| format!("Failed to read {}", path.display()))?;
    let tokens = vpy_parser::lex(&source)
        .map_err(|e| anyhow!("Lex error in {}: {}", path.display(), e))?;
    vpy_parser::parser::parse(tokens, path.to_str().unwrap_or("unknown"))
        .map_err(|e| anyhow!("Parse error in {}: {}", path.display(), e))
}

/// Load `input` (a `.vpyproj` or a single `.vpy`), parse every module, unify.
///
/// A single `.vpy` is compiled alone: if it imports another module, unification
/// fails with `file:line: error: module `x` not found …` (never a silent success).
pub fn load_program(input: &Path) -> Result<Program> {
    let is_project = input.extension().and_then(|s| s.to_str()) == Some("vpyproj");
    let (sources, entry_path, project) = if is_project {
        let info = vpy_loader::load_project(input).context("Failed to load project")?;
        let mut sources: Vec<PathBuf> = info.source_files.iter().map(|s| s.path.clone()).collect();
        if !sources.iter().any(|p| p == &info.entry_point) {
            sources.push(info.entry_point.clone());
        }
        (sources, info.entry_point.clone(), Some(info))
    } else {
        (vec![input.to_path_buf()], input.to_path_buf(), None)
    };
    let entry_module = module_name(&entry_path);

    let mut modules = HashMap::new();
    let mut paths: HashMap<String, PathBuf> = HashMap::new();
    for path in &sources {
        let name = module_name(path);
        if let Some(prev) = paths.get(&name) {
            return Err(anyhow!(
                "two source files define module `{}`: {} and {} — module names are file names, rename one",
                name, prev.display(), path.display()
            ));
        }
        modules.insert(name.clone(), parse_file(path)?);
        paths.insert(name, path.clone());
    }
    let module_count = modules.len();

    let unified = vpy_unifier::unify_modules(modules, &entry_module).map_err(|e| match e {
        vpy_unifier::UnifierError::Unresolved(diags) => {
            let rendered: Vec<String> = diags
                .iter()
                .map(|d| {
                    let path = paths
                        .get(&d.module)
                        .map(|p| p.display().to_string())
                        .unwrap_or_else(|| format!("{}.vpy", d.module));
                    d.render(&path)
                })
                .collect();
            anyhow!("{}", rendered.join("\n"))
        }
        other => anyhow!("Unification error: {}", other),
    })?;

    Ok(Program { unified, entry_path, entry_module, project, module_count })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn write(dir: &Path, rel: &str, text: &str) {
        let p = dir.join(rel);
        std::fs::create_dir_all(p.parent().unwrap()).unwrap();
        std::fs::write(p, text).unwrap();
    }

    fn temp_project() -> tempfile::TempDir {
        let tmp = tempfile::tempdir().unwrap();
        let dir = tmp.path();
        write(dir, "p.vpyproj", "[project]\nname = \"p\"\nversion = \"0.1.0\"\nentry = \"src/main.vpy\"\n\n[sources]\nvpy = [\"src/**/*.vpy\"]\n");
        write(dir, "src/main.vpy", "import physics\n\ndef main():\n    SET_INTENSITY(127)\n\ndef loop():\n    x = physics.clamp_x(1)\n");
        write(dir, "src/physics.vpy", "def clamp_x(v):\n    return v\n");
        tmp
    }

    #[test]
    fn project_loads_every_module() {
        let tmp = temp_project();
        let prog = load_program(&tmp.path().join("p.vpyproj")).expect("load");
        assert_eq!(prog.module_count, 2);
        assert!(prog.unified.items.iter().any(|i| matches!(i, vpy_parser::Item::Function(f) if f.name == "PHYSICS_clamp_x")));
    }

    #[test]
    fn lone_file_with_import_is_an_error_with_path_and_line() {
        let tmp = temp_project();
        let main = tmp.path().join("src/main.vpy");
        let err = load_program(&main).err().expect("must fail").to_string();
        assert!(err.contains(&format!("{}:1: error: module `physics` not found", main.display())), "{err}");
        assert!(err.contains(".vpyproj"), "{err}");
    }
}
