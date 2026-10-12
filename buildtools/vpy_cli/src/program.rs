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
    /// Source file of every function: m6809 label (`MAIN`, `LOOP`,
    /// `PHYSICS_CLAMP_X`) → the `.vpy` it is defined in. The unified module has
    /// lost this; the PDB needs it to point imported code at the right file.
    pub function_files: HashMap<String, PathBuf>,
}

impl Program {
    /// Function label → file NAME (`physics.vpy`), the form the PDB and the IDE use.
    pub fn function_file_names(&self) -> HashMap<String, String> {
        self.function_files
            .iter()
            .map(|(label, path)| {
                let name = path.file_name().and_then(|n| n.to_str()).unwrap_or("main.vpy").to_string();
                (label.clone(), name)
            })
            .collect()
    }
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
    // `import x` with no x.vpy: a library of poses and clips, assets/clips/**/x.vclip, as a
    // module of constants (vclipres.rs)
    if let Some(info) = &project {
        let clips = info.root_dir.join("assets").join("clips");
        let mut wanted: Vec<String> = modules
            .values()
            .flat_map(|m| m.imports.iter().filter_map(|i| i.module_path.last().cloned()))
            .filter(|n| !modules.contains_key(n))
            .collect();
        wanted.sort();
        wanted.dedup();
        for name in wanted {
            let Some(path) = vpy_codegen::vclipres::find_file(&clips, &name, "vclip") else { continue };
            let lib = vpy_codegen::vclipres::load_vclip_file(&path)
                .map_err(|e| anyhow!("{}: {e}", path.display()))?;
            let src = vpy_codegen::vclipres::vpy_module(&lib, &format!("{name}.vclip"));
            let tokens = vpy_parser::lex(&src).map_err(|e| anyhow!("{}: generated module: {e}", path.display()))?;
            let module = vpy_parser::parser::parse(tokens, path.to_str().unwrap_or("clip"))
                .map_err(|e| anyhow!("{}: generated module: {e}", path.display()))?;
            modules.insert(name.clone(), module);
            paths.insert(name, path);
        }
    }
    let module_count = modules.len();

    // Unified name of every function (same rule as the unifier: entry symbols
    // keep their name, imported ones become MODULE_symbol) → its file.
    let mut function_files = HashMap::new();
    for (name, module) in &modules {
        for item in &module.items {
            if let vpy_parser::Item::Function(f) = item {
                let unified = if name == &entry_module {
                    vpy_parser::symbols::entry_symbol(&f.name)
                } else {
                    vpy_parser::symbols::mangle(name, &f.name)
                };
                function_files.insert(vpy_parser::symbols::m6809_label(&unified), paths[name].clone());
            }
        }
    }

    // The file of every function, global and const, by unified name: codegen
    // errors ("line N: …") then say which file (vpy_codegen::origins).
    let mut item_files = HashMap::new();
    for (name, module) in &modules {
        for item in &module.items {
            let def = match item {
                vpy_parser::Item::Function(f) => &f.name,
                vpy_parser::Item::GlobalLet { name, .. } | vpy_parser::Item::Const { name, .. } => name,
                _ => continue,
            };
            let unified = if name == &entry_module {
                vpy_parser::symbols::entry_symbol(def)
            } else {
                vpy_parser::symbols::mangle(name, def)
            };
            item_files.insert(unified, (paths[name].display().to_string(), def.clone()));
        }
    }
    vpy_codegen::origins::set_items(item_files);

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

    Ok(Program { unified, entry_path, entry_module, project, module_count, function_files })
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
    fn every_function_knows_its_source_file() {
        let tmp = temp_project();
        let prog = load_program(&tmp.path().join("p.vpyproj")).expect("load");
        let files = prog.function_file_names();
        assert_eq!(files.get("MAIN").map(String::as_str), Some("main.vpy"));
        assert_eq!(files.get("LOOP").map(String::as_str), Some("main.vpy"));
        assert_eq!(files.get("PHYSICS_CLAMP_X").map(String::as_str), Some("physics.vpy"));
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
