use clap::{Parser, Subcommand};
use colored::*;
use std::path::{Path, PathBuf};
use anyhow::{Result, Context};

// Use centralized asset discovery from vpy_codegen (ensures consistent sorting)
fn discover_assets(source_path: &Path) -> Vec<vpy_codegen::AssetInfo> {
    vpy_codegen::m6809::assets::discover_assets(source_path)
}

/// Resolve the directory that contains VECTREX.I.
/// Priority:
///   1. Same directory as the binary (packaged app — VECTREX.I bundled next to vpy_cli)
///   2. Walk up 3 levels from binary dir: target/ → buildtools/ → workspace/ide/frontend/public/include
///   3. Walk up 2 levels (fallback for shallower layouts)
fn resolve_include_dir() -> PathBuf {
    let cli_exe = std::env::current_exe().unwrap_or_default();
    let cli_dir = match cli_exe.parent() {
        Some(d) => d,
        None => return PathBuf::from("."),
    };
    // Case 1: packaged app – VECTREX.I sits next to the binary
    if cli_dir.join("VECTREX.I").exists() {
        return cli_dir.to_path_buf();
    }
    // Case 2: dev layout – buildtools/target/(debug|release)/vpy_cli
    if let Some(ws) = cli_dir.parent().and_then(|p| p.parent()).and_then(|p| p.parent()) {
        let candidate = ws.join("ide/frontend/public/include");
        if candidate.join("VECTREX.I").exists() {
            return candidate;
        }
    }
    // Case 3: fallback – 2 levels up
    if let Some(ws) = cli_dir.parent().and_then(|p| p.parent()) {
        return ws.join("ide/frontend/public/include");
    }
    cli_dir.to_path_buf()
}

#[derive(Parser)]
#[command(name = "vpy_cli")]
#[command(about = "VPy Compiler - Modular Pipeline", long_about = None)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Parse VPy file and show AST
    Parse {
        /// Input VPy file
        input: PathBuf,
        
        /// Output format (json, pretty, debug)
        #[arg(short, long, default_value = "pretty")]
        format: String,
    },
    
    /// Unify multi-module project
    Unify {
        /// Entry point VPy file
        input: PathBuf,
        
        /// Output format
        #[arg(short, long, default_value = "pretty")]
        format: String,
    },
    
    /// Generate IR (intermediate representation)
    Codegen {
        /// Entry point VPy file
        input: PathBuf,
        
        /// Output format
        #[arg(short, long, default_value = "pretty")]
        format: String,
    },
    
    /// Precompile a .vrec JSON recording into a standalone binary .vrb
    /// (polyline-chained; the same format hardware/emulator play from SD).
    VrecCompile {
        /// Input .vrec (JSON) file
        input: PathBuf,
        /// Output .vrb (binary) file
        output: PathBuf,
        /// Douglas-Peucker simplification epsilon (0 = off; ~6 suits small previews)
        #[arg(long, default_value = "6")]
        simplify: i32,
    },

    /// Compile a single `.vmus`/`.vsfx`/`.vec`/`.vplay` asset into its byte
    /// stream, emitting a C header (`--format c`) or a raw `.bin` (`--format
    /// bin`). Reuses the exact PSG (`.vmus`/`.vsfx`) / geometry (`.vec`) / level
    /// (`.vplay`) compiler that drives the ARM/PiTrex asm backend, so the C
    /// (vpy.h) runtime plays, draws and lays out byte-for-byte the same output
    /// as hardware. `.vplay` additionally emits a sprite pointer table.
    CompileAsset {
        /// Input asset file (.vmus, .vsfx, .vec or .vplay)
        input: PathBuf,

        /// Output format: `c` (C header) or `bin` (raw bytes)
        #[arg(long, default_value = "c")]
        format: String,

        /// Output file (.h for `c`, .bin for `bin`)
        #[arg(short, long)]
        out: PathBuf,

        /// Override the C symbol/base name (default: input file stem, uppercased)
        #[arg(long)]
        name: Option<String>,
    },

    /// Generate unified assembly (single ASM with bank markers)
    Asm {
        /// Entry point VPy file or .vpyproj
        input: PathBuf,

        /// ROM total size (e.g. 524288 for 512KB)
        #[arg(long, default_value = "32768")]
        rom_size: usize,

        /// ROM bank size (e.g. 16384 for 16KB)
        #[arg(long, default_value = "32768")]
        bank_size: usize,

        /// Output ASM file (optional)
        #[arg(short, long)]
        output: Option<PathBuf>,

        /// Compilation target (m6809 or rp2350)
        #[arg(long, default_value = "m6809")]
        target: String,
    },
    
    /// Allocate functions to banks
    Allocate {
        /// Entry point VPy file
        input: PathBuf,
        
        /// Show allocation graph
        #[arg(short, long)]
        graph: bool,
    },
    
    /// Assemble to object files
    Assemble {
        /// Entry point VPy file
        input: PathBuf,
        
        /// Output directory for .vo files
        #[arg(short, long)]
        output: Option<PathBuf>,
    },
    
    /// Link object files to ROM
    Link {
        /// Entry point VPy file
        input: PathBuf,
        
        /// Output ROM file
        #[arg(short, long)]
        output: Option<PathBuf>,
    },
    
    /// Full build pipeline (parse → unify → codegen → allocate → assemble → link)
    Build {
        /// Entry point VPy file or .vpyproj
        input: PathBuf,

        /// Output ROM file
        #[arg(short, long)]
        output: Option<PathBuf>,

        /// ROM total size (e.g. 524288 for 512KB multibank)
        #[arg(long, default_value = "32768")]
        rom_size: usize,

        /// ROM bank size (e.g. 16384 for 16KB banks)
        #[arg(long, default_value = "32768")]
        bank_size: usize,

        /// Generate debug symbols (.pdb)
        #[arg(long)]
        debug: bool,

        /// Show intermediate outputs
        #[arg(short, long)]
        verbose: bool,

        /// Compilation target (m6809 or rp2350)
        #[arg(long, default_value = "m6809")]
        target: String,

        /// (rp2350) Link the game to run from internal SRAM (0x20040000) so the
        /// SD-card launcher can load it. Default is XIP-from-flash (0x10200000).
        #[arg(long)]
        ram: bool,
    },
}

fn main() -> Result<()> {
    let cli = Cli::parse();
    
    match cli.command {
        Commands::Parse { input, format } => {
            println!("{}", "=== Phase 1: PARSE ===".bright_cyan().bold());
            cmd_parse(&input, &format)?;
        }
        
        Commands::Unify { input, format } => {
            println!("{}", "=== Phase 2: UNIFY ===".bright_cyan().bold());
            cmd_unify(&input, &format)?;
        }
        
        Commands::Codegen { input, format } => {
            println!("{}", "=== Phase 3: CODEGEN ===".bright_cyan().bold());
            cmd_codegen(&input, &format)?;
        }
        
        Commands::Asm { input, rom_size, bank_size, output, target } => {
            println!("{}", "=== GENERATE UNIFIED ASM ===".bright_cyan().bold());
            cmd_asm(&input, rom_size, bank_size, output, target)?;
        }

        Commands::CompileAsset { input, format, out, name } => {
            cmd_compile_asset(&input, &format, &out, name)?;
        }

        Commands::VrecCompile { input, output, simplify } => {
            let json = std::fs::read_to_string(&input)
                .map_err(|e| anyhow::anyhow!("read {}: {e}", input.display()))?;
            let bin = vpy_codegen::vrec_chain::compile_vrec_json_to_binary(&json, simplify)
                .map_err(|e| anyhow::anyhow!("{e}"))?;
            std::fs::write(&output, &bin)
                .map_err(|e| anyhow::anyhow!("write {}: {e}", output.display()))?;
            println!("✓ {} → {} ({} bytes)", input.display(), output.display(), bin.len());
        }
        
        Commands::Allocate { input, graph } => {
            println!("{}", "=== Phase 4: ALLOCATE ===".bright_cyan().bold());
            cmd_allocate(&input, graph)?;
        }
        
        Commands::Assemble { input, output } => {
            println!("{}", "=== Phase 5: ASSEMBLE ===".bright_cyan().bold());
            cmd_assemble(&input, output)?;
        }
        
        Commands::Link { input, output } => {
            println!("{}", "=== Phase 6: LINK ===".bright_cyan().bold());
            cmd_link(&input, output)?;
        }
        
        Commands::Build { input, output, rom_size, bank_size, debug, verbose, target, ram } => {
            println!("{}", "=== FULL BUILD PIPELINE ===".bright_green().bold());
            cmd_build(&input, output, rom_size, bank_size, debug, verbose, target, ram)?;
        }
    }
    
    Ok(())
}

fn cmd_parse(input: &PathBuf, format: &str) -> Result<()> {
    // Check if input is .vpyproj - load project and use entry point
    let source_path = if input.extension().and_then(|s| s.to_str()) == Some("vpyproj") {
        println!("{}", "Detected .vpyproj - loading project...".bright_cyan());
        let project_info = vpy_loader::load_project(input)
            .context("Failed to load project")?;
        
        println!("  Entry point: {}", project_info.entry_point.display().to_string().bright_yellow());
        println!("  Source files: {}", project_info.source_files.len());
        
        project_info.entry_point
    } else {
        input.clone()
    };
    
    let source = std::fs::read_to_string(&source_path)
        .context("Failed to read input file")?;
    
    // Lex first
    let tokens = vpy_parser::lex(&source)
        .map_err(|e| anyhow::anyhow!("Lex error: {}", e))?;
    
    // Parse tokens
    let module = vpy_parser::parser::parse(tokens, source_path.to_str().unwrap_or("unknown"))
        .map_err(|e| anyhow::anyhow!("Parse error: {}", e))?;
    
    match format {
        "json" => {
            // Module doesn't implement Serialize yet
            println!("{{");
            println!("  \"imports\": {:?},", module.imports);
            println!("  \"meta\": {{...}},");
            println!("  \"items\": {} items", module.items.len());
            println!("}}");
        }
        "debug" => {
            println!("{:#?}", module);
        }
        "pretty" | _ => {
            println!("\nImports: {}", module.imports.len());
            for import in &module.imports {
                let path = import.module_path.join(".");
                println!("  - import {} ({:?})", path.green(), import.symbols);
            }
            
            println!("\nMeta Fields: {}", module.meta.metas.len());
            for (key, value) in &module.meta.metas {
                println!("  {} = {}", key.cyan(), value.white());
            }
            if let Some(title) = &module.meta.title_override {
                println!("  TITLE = {}", title.bright_white());
            }
            
            // Count items by type
            let mut consts = 0;
            let mut globals = 0;
            let mut functions = 0;
            let mut structs = 0;
            
            for item in &module.items {
                match item {
                    vpy_parser::Item::Const { .. } => consts += 1,
                    vpy_parser::Item::GlobalLet { .. } => globals += 1,
                    vpy_parser::Item::Function(_) => functions += 1,
                    vpy_parser::Item::StructDef(_) => structs += 1,
                    _ => {}
                }
            }
            
            println!("\nItems:");
            println!("  - Constants: {}", consts);
            println!("  - Globals: {}", globals);
            println!("  - Functions: {}", functions);
            println!("  - Structs: {}", structs);
            
            println!("\nFunction Details:");
            for item in &module.items {
                if let vpy_parser::Item::Function(func) = item {
                    println!("  - {}({} params) → {} stmts", 
                        func.name.bright_yellow(),
                        func.params.len(),
                        func.body.len()
                    );
                }
            }
        }
    }
    
    println!("\n{}", "✓ Parse SUCCESS".green().bold());
    Ok(())
}

fn cmd_unify(input: &PathBuf, _format: &str) -> Result<()> {
    // Check if input is .vpyproj - load all sources
    let source_files = if input.extension().and_then(|s| s.to_str()) == Some("vpyproj") {
        println!("{}", "Detected .vpyproj - loading project...".bright_cyan());
        let project_info = vpy_loader::load_project(input)
            .context("Failed to load project")?;
        
        println!("  Entry point: {}", project_info.entry_point.display().to_string().bright_yellow());
        println!("  Source files: {}", project_info.source_files.len());
        
        project_info.source_files
    } else {
        // Single file - treat as standalone module
        vec![vpy_loader::SourceFile {
            path: input.clone(),
            is_entry: true,
        }]
    };
    
    // Parse all source files
    let mut parsed_modules = Vec::new();
    for source_file in &source_files {
        let source = std::fs::read_to_string(&source_file.path)
            .with_context(|| format!("Failed to read {}", source_file.path.display()))?;
        
        let tokens = vpy_parser::lex(&source)
            .map_err(|e| anyhow::anyhow!("Lex error in {}: {}", source_file.path.display(), e))?;
        
        let module = vpy_parser::parser::parse(tokens, source_file.path.to_str().unwrap_or("unknown"))
            .map_err(|e| anyhow::anyhow!("Parse error in {}: {}", source_file.path.display(), e))?;
        
        parsed_modules.push((source_file.path.clone(), module));
    }
    
    println!("\n{}", "Parsed Modules:".bright_white().bold());
    for (path, module) in &parsed_modules {
        let filename = path.file_name().unwrap().to_str().unwrap();
        println!("  {} {}", "✓".green(), filename.bright_yellow());
        println!("    Imports: {}", module.imports.len());
        println!("    Items: {}", module.items.len());
    }
    
    // Analyze imports and dependencies
    println!("\n{}", "Import Graph:".bright_white().bold());
    for (path, module) in &parsed_modules {
        let filename = path.file_stem().unwrap().to_str().unwrap();
        if !module.imports.is_empty() {
            for import in &module.imports {
                let import_path = import.module_path.join(".");
                println!("  {} → {}", filename.cyan(), import_path.yellow());
            }
        }
    }
    
    // Show symbol exports (functions and globals)
    println!("\n{}", "Exported Symbols:".bright_white().bold());
    for (path, module) in &parsed_modules {
        let filename = path.file_stem().unwrap().to_str().unwrap();
        let mut exports = Vec::new();
        
        for item in &module.items {
            match item {
                vpy_parser::Item::Function(func) => {
                    exports.push(format!("{}()", func.name));
                }
                vpy_parser::Item::GlobalLet { name, .. } => {
                    exports.push(name.clone());
                }
                vpy_parser::Item::Const { name, .. } => {
                    exports.push(format!("const {}", name));
                }
                _ => {}
            }
        }
        
        if !exports.is_empty() {
            println!("  {} exports:", filename.cyan());
            for export in exports {
                println!("    - {}", export.bright_white());
            }
        }
    }
    
    // Phase 3: Unify modules with vpy_unifier
    println!("\n{}", "=== Calling vpy_unifier ===".bright_cyan());
    
    // Convert to HashMap with module_name → Module
    let mut modules_map = std::collections::HashMap::new();
    for (path, module) in parsed_modules {
        let module_name = path.file_stem().unwrap().to_str().unwrap().to_string();
        modules_map.insert(module_name, module);
    }
    
    // Find entry module name (from entry point path)
    let entry_module_name = if input.extension().and_then(|s| s.to_str()) == Some("vpyproj") {
        let project_info = vpy_loader::load_project(input)
            .context("Failed to load project")?;
        project_info.entry_point.file_stem().unwrap().to_str().unwrap().to_string()
    } else {
        input.file_stem().unwrap().to_str().unwrap().to_string()
    };
    
    println!("  Entry module: {}", entry_module_name.bright_yellow());
    println!("  Total modules: {}", modules_map.len());
    
    // Unify!
    match vpy_unifier::unify_modules(modules_map, &entry_module_name) {
        Ok(unified) => {
            println!("\n{}", "=== Unified Module ===".bright_green().bold());
            println!("  Total items: {}", unified.items.len());
            
            // Show ALL items with their names to verify prefixing
            println!("\n{}", "Items after unification:".bright_white());
            for item in &unified.items {
                match item {
                    vpy_parser::Item::Function(func) => {
                        println!("    {} {}", "FUNCTION:".yellow(), func.name.bright_yellow().bold());
                    }
                    vpy_parser::Item::GlobalLet { name, .. } => {
                        println!("    {} {}", "VARIABLE:".cyan(), name.bright_cyan().bold());
                    }
                    vpy_parser::Item::Const { name, .. } => {
                        println!("    {} {}", "CONSTANT:".magenta(), name.bright_magenta().bold());
                    }
                    _ => {}
                }
            }
            
            let func_count = unified.items.iter().filter(|i| matches!(i, vpy_parser::Item::Function(_))).count();
            let var_count = unified.items.iter().filter(|i| matches!(i, vpy_parser::Item::GlobalLet { .. })).count();
            
            println!("\n{}", format!("✓ Unify SUCCESS: {} functions, {} variables", func_count, var_count).green().bold());
        }
        Err(e) => {
            println!("\n{}", format!("✗ Unify FAILED: {}", e).red().bold());
            return Err(e.into());
        }
    }
    
    Ok(())
}

fn cmd_codegen(input: &PathBuf, _format: &str) -> Result<()> {
    // Load project or single file
    let source_files = if input.extension().and_then(|s| s.to_str()) == Some("vpyproj") {
        println!("{}", "Detected .vpyproj - loading project...".bright_cyan());
        let project_info = vpy_loader::load_project(input)
            .context("Failed to load project")?;
        
        println!("  Entry point: {}", project_info.entry_point.display().to_string().bright_yellow());
        println!("  Source files: {}", project_info.source_files.len());
        
        project_info.source_files
    } else {
        vec![vpy_loader::SourceFile {
            path: input.clone(),
            is_entry: true,
        }]
    };
    
    // Parse all modules
    let mut parsed_modules = Vec::new();
    for source_file in &source_files {
        let source = std::fs::read_to_string(&source_file.path)
            .with_context(|| format!("Failed to read {}", source_file.path.display()))?;
        
        let tokens = vpy_parser::lex(&source)
            .map_err(|e| anyhow::anyhow!("Lex error in {}: {}", source_file.path.display(), e))?;
        
        let module = vpy_parser::parser::parse(tokens, source_file.path.to_str().unwrap_or("unknown"))
            .map_err(|e| anyhow::anyhow!("Parse error in {}: {}", source_file.path.display(), e))?;
        
        parsed_modules.push((source_file.path.clone(), module));
    }
    
    println!("\n{}", "Code Generation Plan:".bright_white().bold());
    
    // Count functions and estimate code size
    let mut total_functions = 0;
    let mut total_globals = 0;
    let mut total_statements = 0;
    
    for (path, module) in &parsed_modules {
        let filename = path.file_stem().unwrap().to_str().unwrap();
        
        let mut func_count = 0;
        let mut stmt_count = 0;
        let mut global_count = 0;
        
        for item in &module.items {
            match item {
                vpy_parser::Item::Function(func) => {
                    func_count += 1;
                    stmt_count += func.body.len();
                }
                vpy_parser::Item::GlobalLet { .. } | vpy_parser::Item::Const { .. } => {
                    global_count += 1;
                }
                _ => {}
            }
        }
        
        total_functions += func_count;
        total_globals += global_count;
        total_statements += stmt_count;
        
        println!("  {} {}", "Module:".cyan(), filename.bright_yellow());
        println!("    Functions: {}", func_count);
        println!("    Globals: {}", global_count);
        println!("    Statements: {}", stmt_count);
    }
    
    // Estimate assembly size (rough: ~10 bytes per statement)
    let estimated_size = total_statements * 10;
    println!("\n{}", "Code Size Estimate:".bright_white().bold());
    println!("  Total functions: {}", total_functions);
    println!("  Total globals: {}", total_globals);
    println!("  Total statements: {}", total_statements);
    println!("  Estimated ASM size: {} bytes (~{} KB)", estimated_size, estimated_size / 1024);
    
    // Determine if multibank is needed
    let needs_multibank = estimated_size > 32768; // 32KB single bank limit
    if needs_multibank {
        println!("\n{}", "⚠ Multibank Required".yellow().bold());
        println!("  Estimated size exceeds 32KB");
        println!("  Will need bank allocation (Phase 4)");
    } else {
        println!("\n{}", "✓ Single Bank Sufficient".green().bold());
        println!("  Code fits in 32KB cartridge");
    }
    
    // Show function list with entry points
    println!("\n{}", "Functions to Generate:".bright_white().bold());
    for (path, module) in &parsed_modules {
        let filename = path.file_stem().unwrap().to_str().unwrap();
        
        for item in &module.items {
            if let vpy_parser::Item::Function(func) = item {
                let is_entry = func.name == "main" || func.name == "loop";
                let marker = if is_entry { "→" } else { " " };
                let color_name = if is_entry { 
                    func.name.bright_green() 
                } else { 
                    func.name.white() 
                };
                
                println!("  {} {}.{}({} params, {} stmts)", 
                    marker,
                    filename.cyan(),
                    color_name,
                    func.params.len(),
                    func.body.len()
                );
            }
        }
    }
    
    // Show RAM allocation plan
    println!("\n{}", "RAM Allocation Plan:".bright_white().bold());
    let ram_start = 0xC800;
    let mut ram_offset = 0;
    
    for (path, module) in &parsed_modules {
        let filename = path.file_stem().unwrap().to_str().unwrap();
        
        for item in &module.items {
            match item {
                vpy_parser::Item::GlobalLet { name, .. } => {
                    println!("  ${:04X} VAR_{} (from {})", 
                        ram_start + ram_offset,
                        name.to_uppercase().yellow(),
                        filename.cyan()
                    );
                    ram_offset += 2; // 16-bit variables
                }
                vpy_parser::Item::Const { name, .. } => {
                    // Const arrays don't allocate RAM (ROM only)
                    println!("  ROM    CONST_{} (from {})", 
                        name.to_uppercase().bright_blue(),
                        filename.cyan()
                    );
                }
                _ => {}
            }
        }
    }
    
    println!("\n  Total RAM used: {} bytes", ram_offset);
    
    println!("\n{}", "Note: Full ASM generation not yet implemented".yellow());
    println!("{}", "This command currently shows code generation planning and size estimates".yellow());
    
    println!("\n{}", "✓ Codegen SUCCESS (planning only)".green().bold());
    
    Ok(())
}

fn cmd_asm(input: &PathBuf, rom_size: usize, bank_size: usize, output: Option<PathBuf>, target: String) -> Result<()> {
    // Parse project or single file
    let source_path = if input.extension().and_then(|s| s.to_str()) == Some("vpyproj") {
        println!("{}", "Detected .vpyproj - loading project...".bright_cyan());
        let project_info = vpy_loader::load_project(input)
            .context("Failed to load project")?;
        
        println!("  Entry point: {}", project_info.entry_point.display().to_string().bright_yellow());
        println!("  Source files: {}", project_info.source_files.len());
        
        project_info.entry_point
    } else {
        input.clone()
    };
    
    let source = std::fs::read_to_string(&source_path)
        .context("Failed to read input file")?;
    
    // Parse to extract function names (placeholder)
    let tokens = vpy_parser::lex(&source)
        .map_err(|e| anyhow::anyhow!("Lex error: {}", e))?;
    
    let module = vpy_parser::parser::parse(tokens, source_path.to_str().unwrap_or("unknown"))
        .map_err(|e| anyhow::anyhow!("Parse error: {}", e))?;
    
    // Extract function names
    let mut functions = Vec::new();
    for item in &module.items {
        if let vpy_parser::Item::Function(func) = item {
            functions.push(func.name.clone());
        }
    }
    
    // Extract title from META (default to filename if not specified)
    let title = module.meta.title_override
        .as_deref()
        .unwrap_or_else(|| source_path.file_stem()
            .and_then(|s| s.to_str())
            .unwrap_or("VPY GAME"));
    
    println!("\n{}", "Bank Configuration:".bright_white().bold());
    let bank_config = vpy_codegen::BankConfig::new(rom_size, bank_size);
    println!("  ROM Total: {} bytes", rom_size);
    println!("  Bank Size: {} bytes", bank_size);
    println!("  Bank Count: {}", bank_config.rom_bank_count);
    println!("  Helpers Bank: {} {}", 
        bank_config.helpers_bank.to_string().bright_yellow(),
        "(DYNAMIC - not hardcoded 31)".bright_green()
    );
    println!("  Title: {}", title.bright_cyan());
    
    if bank_config.rom_bank_count == 1 {
        println!("  {}", "Single-bank mode".cyan());
    } else {
        println!("  {}", format!("Multi-bank mode ({} banks)", bank_config.rom_bank_count).cyan());
    }
    
    println!("\n{}", "Generating unified ASM...".bright_white());

    let build_target = match target.as_str() {
        "rp2350"  => vpy_codegen::Target::Rp2350,
        "pitrex"  => vpy_codegen::Target::PiTrex,
        "uvm2"    => vpy_codegen::Target::Uvm2,
        _ => vpy_codegen::Target::M6809,
    };
    println!("  Target: {}", target.bright_yellow());

    // Discover assets (vectors, music, sfx, levels)
    let assets = discover_assets(&source_path);

    // Generate unified ASM using selected backend
    let generated = vpy_codegen::generate_from_module_with_target(&module, &bank_config, title, &assets, &build_target)
        .context("Failed to generate ASM")?;
    
    println!("  ASM size: {} bytes", generated.asm_source.len());
    println!("  Symbols: {}", generated.symbols.len());
    println!("  External refs: {}", generated.external_refs.len());
    
    // Write to output file if specified
    if let Some(output_path) = output {
        std::fs::write(&output_path, &generated.asm_source)
            .context("Failed to write ASM file")?;
        println!("\n{}", format!("✓ ASM written to {}", output_path.display()).green().bold());
    } else {
        // Print to stdout
        println!("\n{}", "Generated ASM:".bright_white().bold());
        println!("{}", "=".repeat(80).bright_black());
        println!("{}", generated.asm_source);
        println!("{}", "=".repeat(80).bright_black());
    }
    
    println!("\n{}", "Symbol Table:".bright_white().bold());
    for (name, info) in generated.symbols.iter().take(10) {
        println!("  {} → Bank {} @ ${:04X} ({})", 
            name.yellow(),
            info.bank_id,
            info.offset,
            info.metadata.bright_black()
        );
    }
    if generated.symbols.len() > 10 {
        println!("  ... and {} more symbols", generated.symbols.len() - 10);
    }
    
    println!("\n{}", "✓ ASM generation SUCCESS".green().bold());
    
    Ok(())
}

/// Compile a `.vmus`/`.vsfx`/`.vec` asset into a C header or raw `.bin`.
///
/// The byte stream comes from the SAME compiler used by the ARM/PiTrex asm
/// backend (`vpy_codegen::pitrex::assets`): notes→PSG for `.vmus`/`.vsfx`, and
/// the path/segment geometry for `.vec`. The C runtime therefore plays/draws
/// byte-for-byte identical output to real hardware.
fn cmd_compile_asset(input: &Path, format: &str, out: &Path, name: Option<String>) -> Result<()> {
    println!("{}", "=== COMPILE ASSET ===".bright_cyan().bold());

    let ext = input.extension().and_then(|s| s.to_str()).unwrap_or("").to_lowercase();
    let stem = input.file_stem().and_then(|s| s.to_str()).unwrap_or("asset");
    let base = name.clone().unwrap_or_else(|| stem.to_string());
    let sym = base.to_uppercase().replace(['-', ' ', '.'], "_");

    // Level (.vplay) has a bespoke output: a byte image PLUS a companion sprite
    // pointer table (objects reference sprites by index, not absolute address).
    // Handle it here and return; the .vmus/.vsfx/.vec path below stays untouched.
    if ext == "vplay" {
        return cmd_compile_level(input, format, out, &sym);
    }

    // Animation (.vanim) → PI anim descriptor + companion sprite pointer table
    // (like the level path), consumed by libvpy vpy_draw_anim.
    if ext == "vanim" {
        return cmd_compile_anim(input, format, out, &sym);
    }

    // Compile to bytes + choose the C array suffix based on asset kind.
    let (bytes, suffix) = match ext.as_str() {
        "vmus" => (
            vpy_codegen::pitrex::assets::compile_vmus_file_to_bytes(input)
                .map_err(|e| anyhow::anyhow!("compile {}: {e}", input.display()))?,
            "music",
        ),
        "vsfx" => (
            vpy_codegen::pitrex::assets::compile_vsfx_file_to_bytes(input)
                .map_err(|e| anyhow::anyhow!("compile {}: {e}", input.display()))?,
            "sfx",
        ),
        "vec" => (
            vpy_codegen::pitrex::assets::compile_vec_file_to_bytes(input)
                .map_err(|e| anyhow::anyhow!("compile {}: {e}", input.display()))?,
            "vec",
        ),
        other => {
            return Err(anyhow::anyhow!(
                "unsupported asset extension '.{other}' (expected .vmus, .vsfx, .vec or .vplay)"
            ));
        }
    };

    let kind = if suffix == "vec" { "path" } else { "PSG" };
    println!("  {} → {} {} bytes", input.display(), bytes.len(), kind);

    match format {
        "bin" => {
            std::fs::write(out, &bytes)
                .with_context(|| format!("write {}", out.display()))?;
        }
        "c" | _ => {
            let var = format!("{}_{}", sym, suffix);
            let guard = format!("VPY_ASSET_{}_{}_H", sym, suffix.to_uppercase());
            let mut h = String::new();
            let desc = if suffix == "vec" {
                "vector path stream (little-endian)"
            } else {
                "PSG event stream (little-endian)"
            };
            h.push_str(&format!("/* Auto-generated by `vpy_cli compile-asset` from {}.\n", input.display()));
            h.push_str(&format!(" * {desc} — do not edit by hand. */\n"));
            h.push_str(&format!("#ifndef {guard}\n#define {guard}\n\n"));
            h.push_str(&format!("static const unsigned char {var}[] = {{\n"));
            for chunk in bytes.chunks(12) {
                let row: Vec<String> = chunk.iter().map(|b| format!("0x{:02X}", b)).collect();
                h.push_str(&format!("    {},\n", row.join(", ")));
            }
            h.push_str("};\n\n");
            h.push_str(&format!("#endif /* {guard} */\n"));
            std::fs::write(out, h)
                .with_context(|| format!("write {}", out.display()))?;
            println!("  {} C symbol: {}", "✓".green(), var.bright_yellow());
        }
    }

    println!("{}", format!("✓ Wrote {}", out.display()).green().bold());
    Ok(())
}

/// Compile a `.vplay` level into a C header (or raw `.bin`).
///
/// Reuses `vpy_codegen::levelres::compile_vplay_file_to_c_bytes`, which emits
/// the SAME object/header byte layout the ARM/PiTrex backend uses — only the
/// two link-resolved pointers differ (layer pointers become byte offsets and
/// each object's `vector_ptr` becomes a SPRITE INDEX). Because a C array can't
/// hold absolute addresses, the sprite binding is expressed as a companion
/// pointer table: the header emits `#include "<sprite>.h"` for every referenced
/// `.vec` and a `{SYM}_level_sprites[]` array of `{SPRITE}_vec` pointers, in the
/// exact index order the byte image references. The game passes both the level
/// image and this table to `vpy_load_level(level, sprites)`.
fn cmd_compile_level(input: &Path, format: &str, out: &Path, sym: &str) -> Result<()> {
    let (bytes, sprite_names) = vpy_codegen::levelres::compile_vplay_file_to_c_bytes(input)
        .map_err(|e| anyhow::anyhow!("compile {}: {e}", input.display()))?;

    // Enemy runtime image + sprite table (position-independent, for
    // vpy_spawn_enemies). `enemy_sprite_syms` are assembly symbols like
    // `_ENEMY_VEC`; `enemy_blobs` are any anim/SM byte blobs the table references.
    let (enemy_bytes, enemy_sprite_syms, enemy_blobs) =
        vpy_codegen::levelres::compile_enemies_to_c_bytes(input)
            .map_err(|e| anyhow::anyhow!("compile enemies {}: {e}", input.display()))?;

    println!("  {} → {} level bytes, {} sprite(s), {} enemy bytes, {} enemy sprite(s)",
        input.display(), bytes.len(), sprite_names.len(),
        enemy_bytes.len(), enemy_sprite_syms.len());

    match format {
        "bin" => {
            // Raw byte image only; the sprite table is a C construct and cannot
            // be represented in a flat .bin — callers that need sprites should
            // use `--format c`.
            std::fs::write(out, &bytes)
                .with_context(|| format!("write {}", out.display()))?;
        }
        "c" | _ => {
            let level_var        = format!("{}_level", sym);
            let sprites_var      = format!("{}_level_sprites", sym);
            let enemies_var      = format!("{}_enemies", sym);
            let enemy_sprites_var = format!("{}_enemy_sprites", sym);
            let guard = format!("VPY_ASSET_{}_LEVEL_H", sym);

            // Map an enemy-sprite assembly symbol to its C .vec array name and
            // the sibling header stem to `#include`. `_ENEMY_VEC` -> array
            // `ENEMY_vec`, header `enemy.h` (matching the .vec arm of
            // cmd_compile_asset). Non-`_VEC` symbols are anim/SM blobs emitted
            // inline in this header (no include, C name = symbol without the
            // leading underscore).
            let vec_array = |asm_sym: &str| -> String {
                let base = asm_sym.trim_start_matches('_').trim_end_matches("_VEC");
                format!("{}_vec", base)
            };
            let vec_header_stem = |asm_sym: &str| -> String {
                asm_sym.trim_start_matches('_').trim_end_matches("_VEC").to_lowercase()
            };

            // Union of sprite headers to include: level object sprites +
            // enemy `.vec` sprites (deduplicated by stem, level order first).
            let mut includes: Vec<String> = sprite_names.clone();
            for s in &enemy_sprite_syms {
                if s.ends_with("_VEC") {
                    let stem = vec_header_stem(s);
                    if !includes.iter().any(|n| n.to_lowercase() == stem) {
                        includes.push(stem);
                    }
                }
            }

            let mut h = String::new();
            h.push_str(&format!("/* Auto-generated by `vpy_cli compile-asset` from {}.\n", input.display()));
            h.push_str(" * VPy level byte image + sprite table AND enemy image + enemy sprite\n");
            h.push_str(" * table (all little-endian, position-independent) — do not edit by hand.\n");
            h.push_str(" * Object/enemy sprite fields are INDICES into the companion pointer\n");
            h.push_str(&format!(" * tables. Pass ({level_var}, {sprites_var}) to vpy_load_level()\n"));
            h.push_str(&format!(" * and ({enemies_var}, {enemy_sprites_var}) to vpy_spawn_enemies(). */\n"));
            h.push_str(&format!("#ifndef {guard}\n#define {guard}\n\n"));

            // Pull in each referenced sprite's compiled .vec header. Each is
            // generated as gen/<name>.h and exposes `{NAME}_vec` (see the .vec
            // arm of cmd_compile_asset).
            for name in &includes {
                h.push_str(&format!("#include \"{}.h\"\n", name));
            }
            if !includes.is_empty() { h.push('\n'); }

            let emit_bytes = |h: &mut String, var: &str, data: &[u8]| {
                h.push_str(&format!("static const unsigned char {var}[] = {{\n"));
                for chunk in data.chunks(12) {
                    let row: Vec<String> = chunk.iter().map(|b| format!("0x{:02X}", b)).collect();
                    h.push_str(&format!("    {},\n", row.join(", ")));
                }
                h.push_str("};\n\n");
            };

            // Any anim/SM blobs the enemy sprite table references, emitted before
            // the table so their addresses are in scope.
            for (blob_sym, blob) in &enemy_blobs {
                let cname = blob_sym.trim_start_matches('_');
                emit_bytes(&mut h, cname, blob);
            }

            emit_bytes(&mut h, &level_var, &bytes);

            // Level sprite pointer table (index-ordered). C forbids a zero-length
            // array, so emit a single NULL entry when the level has no sprites.
            h.push_str(&format!("static const unsigned char *const {sprites_var}[] = {{\n"));
            if sprite_names.is_empty() {
                h.push_str("    0,  /* no sprites referenced */\n");
            } else {
                for name in &sprite_names {
                    let sprite_sym = name.to_uppercase().replace(['-', ' ', '.'], "_");
                    h.push_str(&format!("    {}_vec,\n", sprite_sym));
                }
            }
            h.push_str("};\n\n");

            // Enemy image + enemy sprite pointer table (index-ordered). Enemy
            // sprite entries resolve to a `.vec` array or an inline anim/SM blob.
            emit_bytes(&mut h, &enemies_var, &enemy_bytes);
            h.push_str(&format!("static const unsigned char *const {enemy_sprites_var}[] = {{\n"));
            if enemy_sprite_syms.is_empty() {
                h.push_str("    0,  /* no enemy sprites referenced */\n");
            } else {
                for s in &enemy_sprite_syms {
                    if s.ends_with("_VEC") {
                        h.push_str(&format!("    {},\n", vec_array(s)));
                    } else {
                        h.push_str(&format!("    {},\n", s.trim_start_matches('_')));
                    }
                }
            }
            h.push_str("};\n\n");

            h.push_str(&format!("#endif /* {guard} */\n"));
            std::fs::write(out, h)
                .with_context(|| format!("write {}", out.display()))?;
            println!("  {} C symbols: {} + {} + {} + {}", "✓".green(),
                level_var.bright_yellow(), sprites_var.bright_yellow(),
                enemies_var.bright_yellow(), enemy_sprites_var.bright_yellow());
        }
    }

    println!("{}", format!("✓ Wrote {}", out.display()).green().bold());
    Ok(())
}

/// Compile a `.vanim` animation into a C header (or raw `.bin`).
///
/// Emits the position-independent anim descriptor (`{SYM}_anim`) that libvpy's
/// `vpy_draw_anim` ticks, plus the companion sprite pointer table
/// (`{SYM}_anim_sprites`) whose entries point at the compiled frame `.vec`
/// arrays. Frame/base sprite fields in the descriptor are INDICES into that
/// table (a C array can't hold absolute addresses), so the generated header
/// `#include`s each referenced `.vec`'s `gen/<name>.h` and lists `{NAME}_vec`
/// in index order. The game passes both arrays to
/// `DRAW_ANIM(WORLD_anim, WORLD_anim_sprites, x, y, mirror)`.
fn cmd_compile_anim(input: &Path, format: &str, out: &Path, sym: &str) -> Result<()> {
    let resource = vpy_codegen::animres::VanimResource::load(input)
        .map_err(|e| anyhow::anyhow!("load {}: {e}", input.display()))?;
    let (bytes, sprite_names) = resource
        .compile_to_c_bytes()
        .map_err(|e| anyhow::anyhow!("compile {}: {e}", input.display()))?;

    println!("  {} → {} anim bytes, {} frame sprite(s)",
        input.display(), bytes.len(), sprite_names.len());

    match format {
        "bin" => {
            std::fs::write(out, &bytes)
                .with_context(|| format!("write {}", out.display()))?;
        }
        "c" | _ => {
            let anim_var    = format!("{}_anim", sym);
            let sprites_var = format!("{}_anim_sprites", sym);
            let guard = format!("VPY_ASSET_{}_ANIM_H", sym);
            let mut h = String::new();
            h.push_str(&format!("/* Auto-generated by `vpy_cli compile-asset` from {}.\n", input.display()));
            h.push_str(" * Position-independent animation descriptor (little-endian) + frame\n");
            h.push_str(" * sprite pointer table — do not edit by hand. Frame sprite fields are\n");
            h.push_str(&format!(" * INDICES into {sprites_var}[]; pass both to DRAW_ANIM(). */\n"));
            h.push_str(&format!("#ifndef {guard}\n#define {guard}\n\n"));

            for name in &sprite_names {
                h.push_str(&format!("#include \"{}.h\"\n", name));
            }
            if !sprite_names.is_empty() { h.push('\n'); }

            h.push_str(&format!("static const unsigned char {anim_var}[] = {{\n"));
            for chunk in bytes.chunks(12) {
                let row: Vec<String> = chunk.iter().map(|b| format!("0x{:02X}", b)).collect();
                h.push_str(&format!("    {},\n", row.join(", ")));
            }
            h.push_str("};\n\n");

            h.push_str(&format!("static const unsigned char *const {sprites_var}[] = {{\n"));
            if sprite_names.is_empty() {
                h.push_str("    0,  /* no frame sprites referenced */\n");
            } else {
                for name in &sprite_names {
                    let sprite_sym = name.to_uppercase().replace(['-', ' ', '.'], "_");
                    h.push_str(&format!("    {}_vec,\n", sprite_sym));
                }
            }
            h.push_str("};\n\n");

            h.push_str(&format!("#endif /* {guard} */\n"));
            std::fs::write(out, h)
                .with_context(|| format!("write {}", out.display()))?;
            println!("  {} C symbols: {} + {}", "✓".green(),
                anim_var.bright_yellow(), sprites_var.bright_yellow());
        }
    }

    println!("{}", format!("✓ Wrote {}", out.display()).green().bold());
    Ok(())
}

fn cmd_allocate(_input: &PathBuf, _graph: bool) -> Result<()> {
    println!("{}", "TODO: Implement bank allocator integration".yellow());
    Ok(())
}

fn cmd_assemble(_input: &PathBuf, _output: Option<PathBuf>) -> Result<()> {
    println!("{}", "TODO: Implement assembler integration".yellow());
    Ok(())
}

fn cmd_link(_input: &PathBuf, _output: Option<PathBuf>) -> Result<()> {
    println!("{}", "TODO: Implement linker integration".yellow());
    Ok(())
}

/// Locate the best arm-none-eabi-gcc available.
/// Prefers arm-gcc-bin@10 (Homebrew osx-cross, has newlib) over the system one.
fn find_arm_gcc() -> String {
    let candidates = [
        "/opt/arm-toolchain/bin/arm-none-eabi-gcc",   // official ARM GNU 10.3-2021.10
        "/opt/homebrew/Cellar/arm-gcc-bin@10/10.3-2021.10_1/bin/arm-none-eabi-gcc",
        "/usr/local/Cellar/arm-gcc-bin@10/10.3-2021.10_1/bin/arm-none-eabi-gcc",
        "arm-none-eabi-gcc",
    ];
    for c in &candidates {
        if std::path::Path::new(c).exists() || !c.starts_with('/') {
            return c.to_string();
        }
    }
    "arm-none-eabi-gcc".to_string()
}

fn find_arm_as() -> String {
    let gcc = find_arm_gcc();
    // Replace gcc with as in the same directory
    let as_path = std::path::Path::new(&gcc)
        .parent()
        .map(|d| d.join("arm-none-eabi-as"))
        .filter(|p| p.exists())
        .map(|p| p.to_string_lossy().to_string());
    as_path.unwrap_or_else(|| "arm-none-eabi-as".to_string())
}

fn find_arm_objcopy() -> String {
    let gcc = find_arm_gcc();
    let oc_path = std::path::Path::new(&gcc)
        .parent()
        .map(|d| d.join("arm-none-eabi-objcopy"))
        .filter(|p| p.exists())
        .map(|p| p.to_string_lossy().to_string());
    oc_path.unwrap_or_else(|| "arm-none-eabi-objcopy".to_string())
}

fn find_arm_ar() -> String {
    let gcc = find_arm_gcc();
    let ar_path = std::path::Path::new(&gcc)
        .parent()
        .map(|d| d.join("arm-none-eabi-ar"))
        .filter(|p| p.exists())
        .map(|p| p.to_string_lossy().to_string());
    ar_path.unwrap_or_else(|| "arm-none-eabi-ar".to_string())
}

/// Locate the libvpy C runtime source directory (`vpy.c` + `include/vpy.h`).
///
/// This is the shared C reimplementation of the VPy builtins on the PiTrex SDK
/// contract; the pitrex backend can call into it (`bl vpy_<name>`) instead of
/// emitting the builtin body inline. Search order:
///   1. `VPY_C_DIR` env var
///   2. bundled next to the executable: `<exe_dir>/vpy-c` (IDE packaging)
///   3. the repo tree relative to this crate: `ide/electron/resources/vpy-c`
fn find_vpy_c_dir() -> Option<std::path::PathBuf> {
    let ok = |p: &std::path::Path| p.join("vpy.c").exists();

    if let Ok(dir) = std::env::var("VPY_C_DIR") {
        let p = std::path::PathBuf::from(dir);
        if ok(&p) { return Some(p); }
    }
    if let Ok(exe) = std::env::current_exe() {
        if let Some(d) = exe.parent() {
            let p = d.join("vpy-c");
            if ok(&p) { return Some(p); }
        }
    }
    // CARGO_MANIFEST_DIR = <repo>/buildtools/vpy_cli → repo root is two levels up.
    let manifest = std::path::PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    let p = manifest.join("../../ide/electron/resources/vpy-c");
    if ok(&p) { return p.canonicalize().ok(); }
    None
}

fn cmd_build_pitrex(input: &PathBuf, output: Option<PathBuf>, verbose: bool) -> Result<()> {
    use std::process::Command;

    let arm_gcc = find_arm_gcc();
    println!("{}", "Target: PiTrex (ARM32 / ARMv6 / Pi Zero)".bright_yellow().bold());

    // Phase 1: Load project or single file
    let (source_path, project_dir) = if input.extension().and_then(|s| s.to_str()) == Some("vpyproj") {
        let project_info = vpy_loader::load_project(input)
            .context("Failed to load project")?;
        let dir = input.parent().unwrap_or_else(|| std::path::Path::new(".")).to_path_buf();
        (project_info.entry_point, dir)
    } else {
        let dir = {
            let parent = input.parent().unwrap_or_else(|| std::path::Path::new("."));
            if parent.file_name().and_then(|n| n.to_str()) == Some("src") {
                parent.parent().unwrap_or(parent).to_path_buf()
            } else {
                find_project_root_from(parent)
            }
        };
        (input.clone(), dir)
    };

    // Phase 2: Parse
    println!("\n{}", "Phase 1: Parse".bright_cyan().bold());
    let source = std::fs::read_to_string(&source_path)
        .context("Failed to read source file")?;
    let tokens = vpy_parser::lex(&source)
        .map_err(|e| anyhow::anyhow!("Lex error: {}", e))?;
    let module = vpy_parser::parser::parse(tokens, source_path.to_str().unwrap_or("unknown"))
        .map_err(|e| anyhow::anyhow!("Parse error: {}", e))?;
    println!("  {} Parsed {} items", "✓".green(), module.items.len());

    // Phase 3: Unify
    println!("\n{}", "Phase 2: Unify".bright_cyan().bold());
    let mut modules_map = std::collections::HashMap::new();
    let module_name = source_path.file_stem()
        .and_then(|s| s.to_str())
        .unwrap_or("main")
        .to_string();
    modules_map.insert(module_name.clone(), module);
    let unified = vpy_unifier::unify_modules(modules_map, &module_name)
        .map_err(|e| anyhow::anyhow!("Unification error: {}", e))?;
    println!("  {} Unified {} items", "✓".green(), unified.items.len());

    // Phase 4: PiTrex ARM32 codegen
    println!("\n{}", "Phase 3: PiTrex ARM32 Codegen".bright_cyan().bold());
    let title = unified.meta.title_override.as_deref().unwrap_or("VPY GAME");
    let bank_config = vpy_codegen::BankConfig::pitrex();
    let assets = discover_assets(&source_path);

    let generated = vpy_codegen::generate_from_module_with_target(
        &unified, &bank_config, title, &assets, &vpy_codegen::Target::PiTrex,
    ).context("PiTrex codegen failed")?;
    println!("  {} Generated {} bytes of ARM32 assembly", "✓".green(), generated.asm_source.len());

    // Determine output paths
    let build_dir = project_dir.join("build");
    std::fs::create_dir_all(&build_dir)?;

    let project_name: String = output.as_ref()
        .and_then(|p| p.file_stem())
        .and_then(|s| s.to_str())
        .map(|s| s.to_string())
        .or_else(|| vpyproj_project_name(input))
        .unwrap_or_else(|| {
            project_dir.file_name()
                .and_then(|n| n.to_str())
                .unwrap_or("output")
                .to_string()
        });

    let s_path   = build_dir.join(format!("{}.s",   project_name));
    let asm_path = build_dir.join(format!("{}.asm", project_name));
    let o_path   = build_dir.join(format!("{}.o",   project_name));
    let elf_path = build_dir.join(format!("{}.elf", project_name));
    let img_path = output.unwrap_or_else(|| build_dir.join(format!("{}.img", project_name)));

    std::fs::write(&s_path, &generated.asm_source)
        .with_context(|| format!("Failed to write {}", s_path.display()))?;
    std::fs::copy(&s_path, &asm_path)
        .with_context(|| format!("Failed to write {}", asm_path.display()))?;
    println!("  {} ARM32 ASM written: {}", "✓".green(), s_path.display());

    // Find PiTrex SDK — search order:
    //   1. PITREX_SDK env var
    //   2. Bundled alongside this binary: <exe_dir>/pitrex-sdk  (IDE packaging)
    //   3. ~/pitrex-baremetal
    //   4. /opt/pitrex-baremetal
    let exe_dir = std::env::current_exe().ok()
        .and_then(|p| p.parent().map(|d| d.to_path_buf()));
    let sdk_path = std::env::var("PITREX_SDK").ok()
        .map(std::path::PathBuf::from)
        .or_else(|| {
            let home = std::env::var("HOME").ok()?;
            let p = std::path::PathBuf::from(&home).join("projects/pitrex-baremetal");
            if p.exists() { Some(p) } else { None }
        })
        .or_else(|| {
            let home = std::env::var("HOME").ok()?;
            let p = std::path::PathBuf::from(&home).join("pitrex-baremetal");
            if p.exists() { Some(p) } else { None }
        })
        .or_else(|| {
            let p = exe_dir.as_ref()?.join("pitrex-sdk");
            if p.join("lib").exists() { Some(p) } else { None }
        })
        .or_else(|| {
            let p = std::path::Path::new("/opt/pitrex-baremetal");
            if p.exists() { Some(p.to_path_buf()) } else { None }
        })
        .ok_or_else(|| anyhow::anyhow!(
            "PiTrex SDK not found.\n\
             Options:\n\
             - Bundle it: copy SDK libs to ide/electron/resources/pitrex-sdk/lib/\n\
             - Set env var: export PITREX_SDK=/path/to/pitrex-baremetal\n\
             - Install to: ~/pitrex-baremetal or /opt/pitrex-baremetal"
        ))?;
    if verbose {
        println!("  PiTrex SDK: {}", sdk_path.display());
    }

    // ── Detect SDK layout ────────────────────────────────────────────────────
    // Malban/gtoal SDK (github.com/malban/pitrex-baremetal) has:
    //   pitrex/lib7/  (Pi Zero 2 W, ARMv8/Cortex-A53)  ← try first
    //   pitrex/lib/   (Pi Zero 1,   ARMv6/ARM1176)
    // Bundled VPy SDK has:
    //   lib/ obj/standalone/ linker/pitrex_standalone.ld
    let malban_lib7 = sdk_path.join("pitrex/lib7");
    let malban_lib1 = sdk_path.join("pitrex/lib");

    if malban_lib7.exists() || malban_lib1.exists() {
        // ── Malban SDK layout ─────────────────────────────────────────────
        let (lib_dir, as_arch, gcc_arch_flags, rasppi) = if malban_lib7.exists() {
            (malban_lib7.clone(),
             vec!["-march=armv8-a", "-mfpu=neon-fp-armv8", "-mfloat-abi=hard"],
             vec!["-fuse-ld=bfd", "-Ofast", "-mhard-float", "-mfloat-abi=hard",
                  "-mfpu=neon-fp-armv8", "-march=armv8-a", "-mtune=cortex-a53",
                  "-ffreestanding", "-nostartfiles", "-DPITREX_DEBUG",
                  "-DRASPPI=3", "-DUSE_PL011_UART=1"],
             "Pi Zero 2 W (ARMv8/Cortex-A53)")
        } else {
            (malban_lib1.clone(),
             vec!["-march=armv6zk", "-mfpu=vfp", "-mfloat-abi=hard"],
             vec!["-fuse-ld=bfd", "-Ofast", "-mfloat-abi=hard", "-mfpu=vfp",
                  "-march=armv6zk", "-mtune=arm1176jzf-s",
                  "-ffreestanding", "-nostartfiles", "-DPITREX_DEBUG",
                  "-DRASPPI=1", "-DUSE_PL011_UART=1"],
             "Pi Zero 1 (ARMv6/ARM1176)")
        };
        let heap_ld = lib_dir.join("linkerHeapDefBoot.ld");
        if verbose {
            println!("  SDK layout: malban  ({rasppi})");
            println!("  Lib dir: {}", lib_dir.display());
        }

        // Phase 4: Assemble
        println!("\n{}", "Phase 4: ARM32 Assemble".bright_cyan().bold());
        let arm_as = find_arm_as();
        let mut as_args: Vec<String> = as_arch.iter().map(|s| s.to_string()).collect();
        as_args.push(s_path.to_str().unwrap().into());
        as_args.push("-o".into());
        as_args.push(o_path.to_str().unwrap().into());

        let as_out = Command::new(&arm_as).args(&as_args).output()
            .map_err(|e| anyhow::anyhow!("arm-none-eabi-as not found: {}\nInstall: https://developer.arm.com/downloads/-/gnu-rm", e))?;
        if !as_out.status.success() {
            return Err(anyhow::anyhow!("arm-none-eabi-as failed:\n{}", String::from_utf8_lossy(&as_out.stderr)));
        }
        println!("  {} Assembled: {}", "✓".green(), o_path.display());

        // Compile Bézier supplement (provides v_drawBezierCubic / v_drawBezierQuad)
        // The C source is embedded so the binary is self-contained.
        const BEZIER_C_SRC: &str = include_str!("pitrex_bezier.c");
        let bezier_c_path = build_dir.join(format!("{}_bezier.c", project_name));
        let bezier_o_path = build_dir.join(format!("{}_bezier.o", project_name));
        std::fs::write(&bezier_c_path, BEZIER_C_SRC)?;

        let sdk_inc      = sdk_path.join("pitrex");
        let sdk_inc_uspi = sdk_path.join("pitrex/vectrex/uspi/include");
        let mut cc_args: Vec<String> = gcc_arch_flags.iter().map(|s| s.to_string()).collect();
        cc_args.push(format!("-I{}", sdk_inc.display()));
        cc_args.push(format!("-I{}", sdk_inc_uspi.display()));
        cc_args.push("-c".into());
        cc_args.push(bezier_c_path.to_str().unwrap().into());
        cc_args.push("-o".into());
        cc_args.push(bezier_o_path.to_str().unwrap().into());

        let cc_out = Command::new(&arm_gcc).args(&cc_args).output()
            .map_err(|e| anyhow::anyhow!("arm-none-eabi-gcc not found: {}", e))?;
        if !cc_out.status.success() {
            return Err(anyhow::anyhow!("Bézier compile failed:\n{}", String::from_utf8_lossy(&cc_out.stderr)));
        }
        println!("  {} Compiled Bézier supplement: {}", "✓".green(), bezier_o_path.display());

        // ── libvpy C runtime (vpy.c) ──────────────────────────────────────
        // The VPy builtins reimplemented in C on the PiTrex SDK contract. The
        // pitrex codegen can call these directly (`bl vpy_<name>`) instead of
        // emitting the builtin body inline (see pitrex/libvpy.rs). Compiled
        // with the SAME arch flags as the program and -ffunction-sections /
        // -fdata-sections, then archived into libvpy.a so it's tree-shaken:
        // a member (function/data section) is pulled into the image ONLY if a
        // vpy_* symbol is actually referenced. A program using no bridged
        // builtin references no vpy_* symbol → nothing from libvpy is linked.
        let libvpy_a_path = build_dir.join("libvpy.a");
        if let Some(vpy_c_dir) = find_vpy_c_dir() {
            let vpy_c   = vpy_c_dir.join("vpy.c");
            let vpy_inc = vpy_c_dir.join("include");
            let vpy_o   = build_dir.join(format!("{}_vpy.o", project_name));
            // Sibling of the program .s. This single compile of vpy.c to
            // assembly feeds BOTH the JS sim (the IDE reads this file and hands
            // it to PitrexCore so bridged builtins like `bl vpy_draw_circle`
            // resolve) AND the hardware object (assembled below into libvpy.a).
            // Always emitted when the vpy-c runtime is present — simpler than
            // gating on builtin usage; the sim just parses the extra functions.
            let libvpy_s = build_dir.join(format!("{}_libvpy.s", project_name));

            // Step 1: compile vpy.c -> .s with the SAME arch flags as the
            // program object. -ffunction-sections/-fdata-sections keep each
            // function/data section separate so the archive stays tree-shakeable.
            let mut vs_args: Vec<String> = gcc_arch_flags.iter().map(|s| s.to_string()).collect();
            vs_args.push("-S".into());
            vs_args.push("-ffunction-sections".into());
            vs_args.push("-fdata-sections".into());
            vs_args.push(format!("-I{}", vpy_inc.display()));
            vs_args.push(format!("-I{}", sdk_inc.display()));
            vs_args.push(format!("-I{}", sdk_inc_uspi.display()));
            vs_args.push(vpy_c.to_str().unwrap().into());
            vs_args.push("-o".into());
            vs_args.push(libvpy_s.to_str().unwrap().into());

            let vs_out = Command::new(&arm_gcc).args(&vs_args).output()
                .map_err(|e| anyhow::anyhow!("arm-none-eabi-gcc not found: {}", e))?;
            if !vs_out.status.success() {
                return Err(anyhow::anyhow!("libvpy (vpy.c) -S compile failed:\n{}", String::from_utf8_lossy(&vs_out.stderr)));
            }
            println!("  {} Emitted libvpy ARM asm: {}", "✓".green(), libvpy_s.display());

            // Step 2: assemble the emitted .s into the object for the archive,
            // so the sim .s and the hardware .o come from one identical compile.
            let mut vc_args: Vec<String> = gcc_arch_flags.iter().map(|s| s.to_string()).collect();
            vc_args.push("-c".into());
            vc_args.push(libvpy_s.to_str().unwrap().into());
            vc_args.push("-o".into());
            vc_args.push(vpy_o.to_str().unwrap().into());

            let vc_out = Command::new(&arm_gcc).args(&vc_args).output()
                .map_err(|e| anyhow::anyhow!("arm-none-eabi-gcc not found: {}", e))?;
            if !vc_out.status.success() {
                return Err(anyhow::anyhow!("libvpy (vpy.c) assemble failed:\n{}", String::from_utf8_lossy(&vc_out.stderr)));
            }

            // Archive so the linker pulls only referenced members (tree-shaking).
            let _ = std::fs::remove_file(&libvpy_a_path);
            let ar = find_arm_ar();
            let ar_out = Command::new(&ar)
                .args(["crs", libvpy_a_path.to_str().unwrap(), vpy_o.to_str().unwrap()])
                .output()
                .map_err(|e| anyhow::anyhow!("arm-none-eabi-ar not found: {}", e))?;
            if !ar_out.status.success() {
                return Err(anyhow::anyhow!("libvpy archive failed:\n{}", String::from_utf8_lossy(&ar_out.stderr)));
            }
            println!("  {} Compiled libvpy C runtime: {}", "✓".green(), libvpy_a_path.display());
        } else if verbose {
            println!("  {} libvpy C runtime (vpy-c) not found — inline builtins only", "→".yellow());
        }

        // Phase 5+6: Link directly against precompiled .a (no need to compile SDK sources)
        println!("\n{}", "Phase 5+6: ARM32 Link".bright_cyan().bold());
        let mut link_args: Vec<String> = gcc_arch_flags.iter().map(|s| s.to_string()).collect();
        link_args.push(format!("-L{}", lib_dir.display()));
        link_args.push("-Wl,--allow-multiple-definition".into());
        // Drop unreferenced sections so archived libvpy members that aren't
        // called are pruned from the image (per-function/-data tree-shaking).
        link_args.push("-Wl,--gc-sections".into());
        link_args.push("-o".into());
        link_args.push(elf_path.to_str().unwrap().into());
        link_args.push(o_path.to_str().unwrap().into());
        // Bézier supplement must precede -lvectrexInterface so its symbols win
        link_args.push(bezier_o_path.to_str().unwrap().into());
        // libvpy archive: placed before the SDK libs so its vpy_* refs resolve,
        // and after the program object so the program's refs pull members in.
        if libvpy_a_path.exists() {
            link_args.push(libvpy_a_path.to_str().unwrap().into());
        }
        link_args.extend(["-lvectrexInterface", "-luspi", "-lm", "-lc"].iter().map(|s| s.to_string()));
        link_args.push(heap_ld.to_str().unwrap().into());
        link_args.push("-lbaremetal".into());

        let ld_out = Command::new(&arm_gcc).args(&link_args).output()
            .map_err(|e| anyhow::anyhow!("arm-none-eabi-gcc not found: {}", e))?;
        if !ld_out.status.success() {
            return Err(anyhow::anyhow!("Link failed:\n{}", String::from_utf8_lossy(&ld_out.stderr)));
        }
        println!("  {} Linked: {}", "✓".green(), elf_path.display());

    } else {
        // ── Bundled VPy SDK layout (linker/ obj/standalone/ lib/) ────────
        // Phase 4: Assemble (ARMv6 — Pi Zero 1 mode for bundled SDK)
        println!("\n{}", "Phase 4: ARM32 Assemble".bright_cyan().bold());
        let arm_as = find_arm_as();
        let as_out = Command::new(&arm_as)
            .args(["-march=armv6", "-mfpu=vfp", "-mfloat-abi=hard",
                   s_path.to_str().unwrap(), "-o", o_path.to_str().unwrap()])
            .output()
            .map_err(|e| anyhow::anyhow!("arm-none-eabi-as not found: {}\nInstall: https://developer.arm.com/downloads/-/gnu-rm", e))?;
        if !as_out.status.success() {
            return Err(anyhow::anyhow!("arm-none-eabi-as failed:\n{}", String::from_utf8_lossy(&as_out.stderr)));
        }
        println!("  {} Assembled: {}", "✓".green(), o_path.display());

        let ld_script_path = sdk_path.join("linker/pitrex_standalone.ld");
        if !ld_script_path.exists() {
            return Err(anyhow::anyhow!(
                "Linker script not found: {}\n\
                 Set PITREX_SDK to a pitrex-baremetal checkout, e.g.:\n\
                   export PITREX_SDK=~/pitrex-baremetal",
                ld_script_path.display()
            ));
        }

        let sdk_lib_dir = sdk_path.join("lib");
        let sdk_precompiled_dir = sdk_path.join("obj/standalone");
        let sdk_obj_names = ["baremetalEntry.o","bareMetalMain.o","cstubs.o",
            "rpi-armtimer.o","rpi-aux.o","rpi-gpio.o","rpi-interrupts.o",
            "rpi-systimer.o","bcm2835.o","pitrexio-gpio.o","vectrexInterface.o",
            "osWrapper.o","baremetalUtil.o"];

        let use_precompiled = sdk_precompiled_dir.exists()
            && sdk_obj_names.iter().all(|n| sdk_precompiled_dir.join(n).exists());

        if !use_precompiled {
            return Err(anyhow::anyhow!(
                "Bundled SDK precompiled objects not found at: {}\n\
                 Point PITREX_SDK to a full pitrex-baremetal checkout instead.",
                sdk_precompiled_dir.display()
            ));
        }

        println!("\n{}", "Phase 5: Using precompiled SDK objects".bright_cyan().bold());
        println!("  {} {} precompiled objects", "✓".green(), sdk_obj_names.len());

        println!("\n{}", "Phase 6: ARM32 Link".bright_cyan().bold());
        let mut link_args = vec![
            "-O2", "-mfloat-abi=hard", "-nostartfiles", "-mfpu=vfp",
            "-march=armv6zk", "-mtune=arm1176jzf-s",
            "-DRPI0", "-DFREESTANDING", "-DPITREX_DEBUG", "-DMHZ1000",
        ].iter().map(|s| s.to_string()).collect::<Vec<_>>();
        link_args.push(format!("-L{}", sdk_lib_dir.display()));
        link_args.push("-Wl,--allow-multiple-definition".into());
        link_args.push("-o".into());
        link_args.push(elf_path.to_str().unwrap().into());
        for n in &sdk_obj_names { link_args.push(sdk_precompiled_dir.join(n).to_string_lossy().into_owned()); }
        link_args.push(o_path.to_str().unwrap().into());
        link_args.extend(["-lm", "-lff12c", "-ldebug", "-lhal", "-lutils",
                           "-lconsole", "-lbob", "-li2c", "-lbcm2835", "-larm"]
            .iter().map(|s| s.to_string()));
        link_args.push("-T".into());
        link_args.push(ld_script_path.to_str().unwrap().into());

        let ld_out = Command::new(&arm_gcc).args(&link_args).output()
            .map_err(|e| anyhow::anyhow!("arm-none-eabi-gcc not found: {}", e))?;
        if !ld_out.status.success() {
            return Err(anyhow::anyhow!("Link failed:\n{}", String::from_utf8_lossy(&ld_out.stderr)));
        }
        println!("  {} Linked: {}", "✓".green(), elf_path.display());
    }

    // Phase 7: Extract binary
    println!("\n{}", "Phase 7: Extract .img".bright_cyan().bold());
    let objcopy = find_arm_objcopy();
    let oc_out = Command::new(&objcopy)
        .args(["-O", "binary", elf_path.to_str().unwrap(), img_path.to_str().unwrap()])
        .output()
        .map_err(|e| anyhow::anyhow!("arm-none-eabi-objcopy not found: {}", e))?;
    if !oc_out.status.success() {
        return Err(anyhow::anyhow!("objcopy failed:\n{}", String::from_utf8_lossy(&oc_out.stderr)));
    }

    let img_size = std::fs::metadata(&img_path).map(|m| m.len()).unwrap_or(0);
    println!("  {} Image written: {} ({} bytes)", "✓".green(), img_path.display(), img_size);
    println!("\n{}", format!(
        "✓ BUILD SUCCESS (pitrex): {} bytes → {}\n  Copy to SD card as kernel7l.img",
        img_size, img_path.display()
    ).bright_green().bold());

    Ok(())
}

fn cmd_build_rp2350(input: &PathBuf, output: Option<PathBuf>, verbose: bool, ram: bool) -> Result<()> {
    use std::process::Command;

    println!("{}", "Target: RP2350 (ARM Thumb2)".bright_yellow().bold());
    if ram {
        println!("  {} RAM-linked (SD launcher) — entry at 0x20040000", "→".cyan());
    }

    // Phase 1: Load project or single file
    let (source_path, project_dir) = if input.extension().and_then(|s| s.to_str()) == Some("vpyproj") {
        let project_info = vpy_loader::load_project(input)
            .context("Failed to load project")?;
        let dir = input.parent().unwrap_or_else(|| std::path::Path::new(".")).to_path_buf();
        (project_info.entry_point, dir)
    } else {
        let dir = {
            let parent = input.parent().unwrap_or_else(|| std::path::Path::new("."));
            if parent.file_name().and_then(|n| n.to_str()) == Some("src") {
                parent.parent().unwrap_or(parent).to_path_buf()
            } else {
                find_project_root_from(parent)
            }
        };
        (input.clone(), dir)
    };

    // Phase 2: Parse
    println!("\n{}", "Phase 1: Parse".bright_cyan().bold());
    let source = std::fs::read_to_string(&source_path)
        .context("Failed to read source file")?;
    let tokens = vpy_parser::lex(&source)
        .map_err(|e| anyhow::anyhow!("Lex error: {}", e))?;
    let module = vpy_parser::parser::parse(tokens, source_path.to_str().unwrap_or("unknown"))
        .map_err(|e| anyhow::anyhow!("Parse error: {}", e))?;
    println!("  {} Parsed {} items", "✓".green(), module.items.len());

    // Phase 3: Unify (single file — wrap in identity unifier)
    println!("\n{}", "Phase 2: Unify".bright_cyan().bold());
    let mut modules_map = std::collections::HashMap::new();
    let module_name = source_path.file_stem()
        .and_then(|s| s.to_str())
        .unwrap_or("main")
        .to_string();
    modules_map.insert(module_name.clone(), module);
    let unified = vpy_unifier::unify_modules(modules_map, &module_name)
        .map_err(|e| anyhow::anyhow!("Unification error: {}", e))?;
    println!("  {} Unified {} items", "✓".green(), unified.items.len());

    // Phase 4: ARM codegen — always single-bank for RP2350
    println!("\n{}", "Phase 3: ARM Codegen".bright_cyan().bold());
    let title = unified.meta.title_override.as_deref().unwrap_or("VPY GAME");
    let bank_config = vpy_codegen::BankConfig::single_bank();
    let assets = discover_assets(&source_path);

    let generated = vpy_codegen::generate_from_module_with_target(
        &unified, &bank_config, title, &assets, &vpy_codegen::Target::Rp2350,
    ).context("ARM codegen failed")?;
    println!("  {} Generated {} bytes of ARM assembly", "✓".green(), generated.asm_source.len());

    // Determine output paths
    let build_dir = project_dir.join("build");
    std::fs::create_dir_all(&build_dir)?;

    // Derive project name (priority: --output stem > vpyproj name > directory name).
    // This avoids spaces when the directory is "3d test" but the project is "3d_test".
    let project_name: String = output.as_ref()
        .and_then(|p| p.file_stem())
        .and_then(|s| s.to_str())
        .map(|s| s.to_string())
        .or_else(|| vpyproj_project_name(input))
        .unwrap_or_else(|| {
            project_dir.file_name()
                .and_then(|n| n.to_str())
                .unwrap_or("output")
                .to_string()
        });

    let s_path   = build_dir.join(format!("{}.s",   project_name));
    let asm_path = build_dir.join(format!("{}.asm", project_name)); // alias for IDE STATUS check
    let o_path   = build_dir.join(format!("{}.o",   project_name));
    let elf_path = build_dir.join(format!("{}.elf", project_name));
    let bin_path = output.unwrap_or_else(|| build_dir.join(format!("{}.bin", project_name)));

    // Write .s file and .asm alias (IDE STATUS check expects .asm)
    std::fs::write(&s_path, &generated.asm_source)
        .with_context(|| format!("Failed to write {}", s_path.display()))?;
    std::fs::copy(&s_path, &asm_path)
        .with_context(|| format!("Failed to write {}", asm_path.display()))?;
    println!("  {} ARM ASM written: {}", "✓".green(), s_path.display());

    // Linker script. For --ram builds (SD launcher targets) always use the
    // bundled RAM script — an in-tree rp2350_game.ld links for XIP flash and
    // would put the entry pointer at 0x10200xxx, wrong for a RAM-loaded game.
    // Otherwise prefer an in-tree copy, then the bundled flash script.
    let ld_path = if ram {
        write_bundled_rp2350_ram_ld(&build_dir)?
    } else {
        match find_rp2350_ld(&project_dir) {
            Some(p) => p,
            None => write_bundled_rp2350_ld(&build_dir)?,
        }
    };
    if verbose {
        println!("  Linker script: {}", ld_path.display());
    }

    // Phase 5: Assemble with arm-none-eabi-as
    println!("\n{}", "Phase 4: ARM Assemble".bright_cyan().bold());
    let as_result = Command::new("arm-none-eabi-as")
        .args([
            "-mthumb",
            "-mcpu=cortex-m33",
            "-mfpu=fpv5-sp-d16",
            s_path.to_str().unwrap(),
            "-o",
            o_path.to_str().unwrap(),
        ])
        .output();

    match as_result {
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => {
            return Err(anyhow::anyhow!(
                "arm-none-eabi-as not found on PATH.\n\
                 Install the ARM GNU toolchain: https://developer.arm.com/downloads/-/arm-gnu-toolchain-downloads\n\
                 On macOS: brew install --cask gcc-arm-embedded\n\
                 On Ubuntu: sudo apt install gcc-arm-none-eabi"
            ));
        }
        Err(e) => return Err(anyhow::anyhow!("Failed to invoke arm-none-eabi-as: {}", e)),
        Ok(out) => {
            if !out.status.success() {
                let stderr = String::from_utf8_lossy(&out.stderr);
                return Err(anyhow::anyhow!("arm-none-eabi-as failed:\n{}", stderr));
            }
            println!("  {} Assembled: {}", "✓".green(), o_path.display());
        }
    }

    // Phase 6: Link with arm-none-eabi-ld
    println!("\n{}", "Phase 5: ARM Link".bright_cyan().bold());
    let ld_result = Command::new("arm-none-eabi-ld")
        .args([
            // --gc-sections drops unreachable per-symbol sections (each vec/level/
            // enemy blob is in its own `.rodata._NAME_*`). Without it, the shared
            // libvpy PI enemy image (`_NAME_ENEMIES_C` / `_NAME_ENEMY_SPRITES` ->
            // `_*_VEC`) — emitted for every level but NOT referenced by the arm
            // enemy path — was force-kept, both bloating the 252 KB GAME_RAM RAM
            // build past its limit and (before `_VEC` was emitted) failing the
            // link on `undefined reference to _*_VEC`. Roots: ENTRY(game_main) +
            // the linker script's KEEP(*(.game_rom)).
            "--gc-sections",
            "-T",
            ld_path.to_str().unwrap(),
            o_path.to_str().unwrap(),
            "-o",
            elf_path.to_str().unwrap(),
        ])
        .output();

    match ld_result {
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => {
            return Err(anyhow::anyhow!(
                "arm-none-eabi-ld not found on PATH.\n\
                 Install the ARM GNU toolchain (same package as arm-none-eabi-as)."
            ));
        }
        Err(e) => return Err(anyhow::anyhow!("Failed to invoke arm-none-eabi-ld: {}", e)),
        Ok(out) => {
            if !out.status.success() {
                let stderr = String::from_utf8_lossy(&out.stderr);
                return Err(anyhow::anyhow!("arm-none-eabi-ld failed:\n{}", stderr));
            }
            println!("  {} Linked: {}", "✓".green(), elf_path.display());
        }
    }

    // Phase 7: Extract binary with arm-none-eabi-objcopy
    println!("\n{}", "Phase 6: Extract Binary".bright_cyan().bold());
    let objcopy_result = Command::new("arm-none-eabi-objcopy")
        .args([
            "-O",
            "binary",
            elf_path.to_str().unwrap(),
            bin_path.to_str().unwrap(),
        ])
        .output();

    match objcopy_result {
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => {
            return Err(anyhow::anyhow!(
                "arm-none-eabi-objcopy not found on PATH.\n\
                 Install the ARM GNU toolchain (same package as arm-none-eabi-as)."
            ));
        }
        Err(e) => return Err(anyhow::anyhow!("Failed to invoke arm-none-eabi-objcopy: {}", e)),
        Ok(out) => {
            if !out.status.success() {
                let stderr = String::from_utf8_lossy(&out.stderr);
                return Err(anyhow::anyhow!("arm-none-eabi-objcopy failed:\n{}", stderr));
            }
        }
    }

    let bin_size = std::fs::metadata(&bin_path).map(|m| m.len()).unwrap_or(0);
    println!("  {} Binary written: {} ({} bytes)", "✓".green(), bin_path.display(), bin_size);
    println!("\n{}", format!("✓ BUILD SUCCESS (rp2350): {} bytes written to {}",
        bin_size,
        bin_path.display()).bright_green().bold());

    Ok(())
}

/// Build for the UVM2 (Ultimate Vectrex Multicart 2) — Cortex-M33 / Pico SDK toolchain.
fn cmd_build_uvm2(input: &PathBuf, output: Option<PathBuf>, verbose: bool) -> Result<()> {
    use std::process::Command;

    println!("{}", "Target: UVM2 (Ultimate Vectrex Multicart 2 / Cortex-M33)".bright_yellow().bold());

    let (source_path, project_dir) = if input.extension().and_then(|s| s.to_str()) == Some("vpyproj") {
        let project_info = vpy_loader::load_project(input).context("Failed to load project")?;
        let dir = input.parent().unwrap_or_else(|| std::path::Path::new(".")).to_path_buf();
        (project_info.entry_point, dir)
    } else {
        let dir = {
            let parent = input.parent().unwrap_or_else(|| std::path::Path::new("."));
            if parent.file_name().and_then(|n| n.to_str()) == Some("src") {
                parent.parent().unwrap_or(parent).to_path_buf()
            } else {
                find_project_root_from(parent)
            }
        };
        (input.clone(), dir)
    };

    println!("\n{}", "Phase 1: Parse".bright_cyan().bold());
    let source = std::fs::read_to_string(&source_path).context("Failed to read source file")?;
    let tokens = vpy_parser::lex(&source).map_err(|e| anyhow::anyhow!("Lex error: {}", e))?;
    let module = vpy_parser::parser::parse(tokens, source_path.to_str().unwrap_or("unknown"))
        .map_err(|e| anyhow::anyhow!("Parse error: {}", e))?;
    println!("  {} Parsed {} items", "✓".green(), module.items.len());

    println!("\n{}", "Phase 2: Unify".bright_cyan().bold());
    let mut modules_map = std::collections::HashMap::new();
    let module_name = source_path.file_stem().and_then(|s| s.to_str()).unwrap_or("main").to_string();
    modules_map.insert(module_name.clone(), module);
    let unified = vpy_unifier::unify_modules(modules_map, &module_name)
        .map_err(|e| anyhow::anyhow!("Unification error: {}", e))?;
    println!("  {} Unified {} items", "✓".green(), unified.items.len());

    println!("\n{}", "Phase 3: UVM2 ARM Thumb2 Codegen".bright_cyan().bold());
    let title = project_dir.file_name().and_then(|n| n.to_str()).unwrap_or("UVM2 Game");
    let bank_config = vpy_codegen::BankConfig::single_bank();
    let assets = discover_assets(&source_path);
    let generated = vpy_codegen::generate_from_module_with_target(
        &unified, &bank_config, title, &assets, &vpy_codegen::Target::Uvm2,
    ).context("UVM2 codegen failed")?;
    println!("  {} Generated {} bytes of ARM assembly", "✓".green(), generated.asm_source.len());

    let build_dir = project_dir.join("build");
    std::fs::create_dir_all(&build_dir)?;

    let project_name: String = output.as_ref()
        .and_then(|p| p.file_stem()).and_then(|s| s.to_str()).map(|s| s.to_string())
        .or_else(|| vpyproj_project_name(input))
        .unwrap_or_else(|| project_dir.file_name().and_then(|n| n.to_str()).unwrap_or("output").to_string());

    let s_path   = build_dir.join(format!("{}.s",   project_name));
    let asm_path = build_dir.join(format!("{}.asm", project_name));
    let o_path   = build_dir.join(format!("{}.o",   project_name));
    let elf_path = build_dir.join(format!("{}.elf", project_name));
    let bin_path = output.unwrap_or_else(|| build_dir.join(format!("{}.bin", project_name)));

    std::fs::write(&s_path, &generated.asm_source)
        .with_context(|| format!("Failed to write {}", s_path.display()))?;
    std::fs::copy(&s_path, &asm_path)
        .with_context(|| format!("Failed to write {}", asm_path.display()))?;
    println!("  {} ARM ASM written: {}", "✓".green(), s_path.display());

    // Linker script — prefer a uvm2-specific one, fall back to the bundled rp2350 script
    let ld_path = match find_uvm2_ld(&project_dir).or_else(|| find_rp2350_ld(&project_dir)) {
        Some(p) => p,
        None => write_bundled_rp2350_ld(&build_dir)?,
    };
    if verbose { println!("  Linker script: {}", ld_path.display()); }

    println!("\n{}", "Phase 4: ARM Assemble".bright_cyan().bold());
    let as_out = Command::new("arm-none-eabi-as")
        .args(["-mthumb", "-mcpu=cortex-m33", "-mfpu=fpv5-sp-d16",
               s_path.to_str().unwrap(), "-o", o_path.to_str().unwrap()])
        .output();
    match as_out {
        Err(e) if e.kind() == std::io::ErrorKind::NotFound =>
            return Err(anyhow::anyhow!("arm-none-eabi-as not found. Install gcc-arm-embedded.")),
        Err(e) => return Err(anyhow::anyhow!("Failed to invoke arm-none-eabi-as: {}", e)),
        Ok(out) => {
            if !out.status.success() {
                return Err(anyhow::anyhow!("arm-none-eabi-as failed:\n{}",
                    String::from_utf8_lossy(&out.stderr)));
            }
            println!("  {} Assembled: {}", "✓".green(), o_path.display());
        }
    }

    println!("\n{}", "Phase 5: ARM Link".bright_cyan().bold());
    let ld_out = Command::new("arm-none-eabi-ld")
        .args(["-T", ld_path.to_str().unwrap(),
               o_path.to_str().unwrap(), "-o", elf_path.to_str().unwrap()])
        .output();
    match ld_out {
        Err(e) if e.kind() == std::io::ErrorKind::NotFound =>
            return Err(anyhow::anyhow!("arm-none-eabi-ld not found.")),
        Err(e) => return Err(anyhow::anyhow!("Failed to invoke arm-none-eabi-ld: {}", e)),
        Ok(out) => {
            if !out.status.success() {
                return Err(anyhow::anyhow!("arm-none-eabi-ld failed:\n{}",
                    String::from_utf8_lossy(&out.stderr)));
            }
            println!("  {} Linked: {}", "✓".green(), elf_path.display());
        }
    }

    println!("\n{}", "Phase 6: Extract Binary".bright_cyan().bold());
    let oc_out = Command::new("arm-none-eabi-objcopy")
        .args(["-O", "binary", elf_path.to_str().unwrap(), bin_path.to_str().unwrap()])
        .output();
    match oc_out {
        Err(e) if e.kind() == std::io::ErrorKind::NotFound =>
            return Err(anyhow::anyhow!("arm-none-eabi-objcopy not found.")),
        Err(e) => return Err(anyhow::anyhow!("Failed to invoke arm-none-eabi-objcopy: {}", e)),
        Ok(out) => {
            if !out.status.success() {
                return Err(anyhow::anyhow!("arm-none-eabi-objcopy failed:\n{}",
                    String::from_utf8_lossy(&out.stderr)));
            }
        }
    }

    let bin_size = std::fs::metadata(&bin_path).map(|m| m.len()).unwrap_or(0);
    println!("  {} Binary: {} ({} bytes)", "✓".green(), bin_path.display(), bin_size);

    // Phase 7: Wrap with UM2 header for SD card (UVM2 game format)
    println!("\n{}", "Phase 7: UM2 Package".bright_cyan().bold());
    let um2_path = build_dir.join(format!("{}.um2", project_name));
    let bin_data = std::fs::read(&bin_path)
        .with_context(|| format!("Failed to read binary for UM2 packaging: {}", bin_path.display()))?;
    let um2_data = build_um2(&bin_data, 0x20000000u32);
    std::fs::write(&um2_path, &um2_data)
        .with_context(|| format!("Failed to write UM2: {}", um2_path.display()))?;
    println!("  {} UM2: {} ({} bytes) — header(20) + ARM binary",
        "✓".green(), um2_path.display(), um2_data.len());

    println!("\n{}", format!("✓ BUILD SUCCESS (uvm2): {} bytes  →  {}",
        um2_data.len(), um2_path.display()).bright_green().bold());

    Ok(())
}

/// Build a .um2 file for the Ultimate Vectrex Multicart 2.
///
/// Header format (20 bytes, all fields little-endian):
///   [0..4]   Magic:       "2CMU"  (0x554D4332)
///   [4..8]   Version:     1
///   [8..12]  GameCount:   1
///   [12..16] LoadAddr:    load address in SRAM (e.g. 0x20000000)
///   [16..20] BinarySize:  length of the ARM binary in bytes
///   [20..]   Binary data  (ARM Thumb2, Cortex-M33)
#[allow(dead_code)]
fn build_um2(bin: &[u8], load_addr: u32) -> Vec<u8> {
    let mut out = Vec::with_capacity(20 + bin.len());
    // Magic "2CMU"
    out.extend_from_slice(b"2CMU");
    // Version = 1
    out.extend_from_slice(&1u32.to_le_bytes());
    // GameCount = 1
    out.extend_from_slice(&1u32.to_le_bytes());
    // LoadAddr
    out.extend_from_slice(&load_addr.to_le_bytes());
    // BinarySize
    out.extend_from_slice(&(bin.len() as u32).to_le_bytes());
    // ARM binary payload
    out.extend_from_slice(bin);
    out
}

/// Build a UF2 binary from raw `data` loaded at `base_addr`.
/// UF2 spec: https://github.com/microsoft/uf2
/// Each 512-byte block carries 256 bytes of payload.
/// Family ID 0xE48BFF59 = rp2350-arm-s (RP2350 Cortex-M33)
#[allow(dead_code)]
fn build_uf2(data: &[u8], base_addr: u32) -> Vec<u8> {
    const MAGIC0:      u32 = 0x0A324655; // "UF2\n"
    const MAGIC1:      u32 = 0x9E5D5157;
    const MAGIC_END:   u32 = 0x0AB16F30;
    const FLAG_FAMILY: u32 = 0x00002000;
    const FAMILY_ID:   u32 = 0xE48BFF59; // rp2350-arm-s
    const PAYLOAD:     usize = 256;
    const BLOCK_SIZE:  usize = 512;

    let total_blocks = (data.len() + PAYLOAD - 1) / PAYLOAD;
    let mut out = Vec::with_capacity(total_blocks * BLOCK_SIZE);

    for (i, chunk) in data.chunks(PAYLOAD).enumerate() {
        let addr = base_addr + (i * PAYLOAD) as u32;
        let mut block = [0u8; BLOCK_SIZE];
        let w = |buf: &mut [u8], off: usize, v: u32| {
            buf[off..off + 4].copy_from_slice(&v.to_le_bytes());
        };
        w(&mut block,   0, MAGIC0);
        w(&mut block,   4, MAGIC1);
        w(&mut block,   8, FLAG_FAMILY);
        w(&mut block,  12, addr);
        w(&mut block,  16, PAYLOAD as u32);
        w(&mut block,  20, i as u32);
        w(&mut block,  24, total_blocks as u32);
        w(&mut block,  28, FAMILY_ID);
        block[32..32 + chunk.len()].copy_from_slice(chunk);
        w(&mut block, 508, MAGIC_END);
        out.extend_from_slice(&block);
    }
    out
}

fn find_project_root_from(start: &Path) -> PathBuf {
    let mut current = start;
    loop {
        if let Ok(entries) = std::fs::read_dir(current) {
            let has_vpyproj = entries
                .flatten()
                .any(|e| e.path().extension().and_then(|s| s.to_str()) == Some("vpyproj"));
            if has_vpyproj { return current.to_path_buf(); }
        }
        match current.parent() {
            Some(p) => current = p,
            None => return start.to_path_buf(),
        }
    }
}

/// Find linker script by walking up from project dir and binary location looking for
/// hardware/debug_cart/firmware/rp2350_game.ld
fn find_rp2350_ld(project_dir: &Path) -> Option<PathBuf> {
    // Helper: walk up from a starting path
    fn walk_up(start: &Path) -> Option<PathBuf> {
        let mut current = start;
        loop {
            let candidate = current.join("hardware/debug_cart/firmware/rp2350_game.ld");
            if candidate.exists() {
                return Some(candidate);
            }
            match current.parent() {
                Some(p) => current = p,
                None => return None,
            }
        }
    }

    // 1. Walk up from the project directory
    if let Some(found) = walk_up(project_dir) {
        return Some(found);
    }

    // 2. Walk up from the CLI binary location (covers running from buildtools/target/debug/)
    if let Ok(exe) = std::env::current_exe() {
        if let Some(exe_dir) = exe.parent() {
            if let Some(found) = walk_up(exe_dir) {
                return Some(found);
            }
        }
    }

    // 3. Walk up from the current working directory
    if let Ok(cwd) = std::env::current_dir() {
        if let Some(found) = walk_up(&cwd) {
            return Some(found);
        }
    }

    None
}

/// The rp2350 game linker script is bundled into the compiler binary so builds
/// don't depend on the (now private) hardware/ directory. Writes it into the
/// build dir and returns the path for the linker to consume.
fn write_bundled_rp2350_ld(build_dir: &Path) -> anyhow::Result<PathBuf> {
    const BUNDLED_LD: &str = include_str!("../resources/rp2350_game.ld");
    let path = build_dir.join("rp2350_game.ld");
    std::fs::write(&path, BUNDLED_LD)
        .with_context(|| format!("Failed to write bundled linker script {}", path.display()))?;
    Ok(path)
}

/// RAM-linked variant: game runs from internal SRAM at 0x20040000, loaded off
/// the SD card by the cart launcher (see rp2350_game_ram.ld header).
fn write_bundled_rp2350_ram_ld(build_dir: &Path) -> anyhow::Result<PathBuf> {
    const BUNDLED_LD: &str = include_str!("../resources/rp2350_game_ram.ld");
    let path = build_dir.join("rp2350_game_ram.ld");
    std::fs::write(&path, BUNDLED_LD)
        .with_context(|| format!("Failed to write bundled linker script {}", path.display()))?;
    Ok(path)
}

/// Find the UVM2 linker script — looks for hardware/uvm2/uvm2_game.ld first,
/// then falls back to the rp2350_game.ld (same Pico SDK memory map).
#[allow(dead_code)]
fn find_uvm2_ld(project_dir: &Path) -> Option<PathBuf> {
    fn walk_up(start: &Path) -> Option<PathBuf> {
        let mut current = start;
        loop {
            let candidate = current.join("hardware/uvm2/uvm2_game.ld");
            if candidate.exists() { return Some(candidate); }
            match current.parent() {
                Some(p) => current = p,
                None => return None,
            }
        }
    }
    walk_up(project_dir)
        .or_else(|| { std::env::current_exe().ok().and_then(|e| e.parent().and_then(|d| walk_up(d))) })
        .or_else(|| { std::env::current_dir().ok().and_then(|d| walk_up(&d)) })
}

/// Extract project name from a .vpyproj file without pulling in the full toml crate.
/// Tries [build] output stem first, then [project] name, returns None on any failure.
fn vpyproj_project_name(vpyproj: &Path) -> Option<String> {
    let content = std::fs::read_to_string(vpyproj).ok()?;
    // Look for:  output = "build/3d_test.bin"  →  "3d_test"
    for line in content.lines() {
        let t = line.trim();
        if t.starts_with("output") {
            if let Some(val) = t.splitn(2, '=').nth(1) {
                let val = val.trim().trim_matches('"');
                let stem = std::path::Path::new(val)
                    .file_stem()
                    .and_then(|s| s.to_str())
                    .map(|s| s.to_string());
                if stem.is_some() { return stem; }
            }
        }
    }
    // Fallback: [project] name = "3d_test"
    for line in content.lines() {
        let t = line.trim();
        if t.starts_with("name") {
            if let Some(val) = t.splitn(2, '=').nth(1) {
                let val = val.trim().trim_matches('"').to_string();
                if !val.is_empty() { return Some(val); }
            }
        }
    }
    None
}

fn cmd_build(input: &PathBuf, output: Option<PathBuf>, rom_size: usize, bank_size: usize, _debug: bool, verbose: bool, target: String, ram: bool) -> Result<()> {
    // PiTrex target: separate path — no banks, ARM32 toolchain invocation
    if target == "pitrex" {
        return cmd_build_pitrex(input, output, verbose);
    }
    // RP2350 target: separate path — no banks, ARM toolchain invocation
    if target == "rp2350" {
        return cmd_build_rp2350(input, output, verbose, ram);
    }
    // UVM2 target: Ultimate Vectrex Multicart 2 — same Pico SDK toolchain as rp2350
    if target == "uvm2" {
        return cmd_build_uvm2(input, output, verbose);
    }

    // Check if this is a multi-module project
    let is_multimodule = input.extension().and_then(|s| s.to_str()) == Some("vpyproj");
    
    if is_multimodule {
        // Multi-module projects: Use buildtools pipeline
        if verbose {
            println!("{}", "Compiling .vpyproj project with buildtools...".bright_cyan());
        }
        
        // Phase 1: Load project
        println!("\n{}", "Phase 1: Load Project".bright_cyan().bold());
        let project_info = vpy_loader::load_project(input)
            .context("Failed to load project")?;
        
        println!("  Entry: {}", project_info.entry_point.display().to_string().yellow());
        println!("  Files: {}", project_info.source_files.len());
        println!("  Assets: {}", project_info.asset_files.len());
        
        // Phase 2: Parse all modules
        println!("\n{}", "Phase 2: Parse Modules".bright_cyan().bold());
        let mut modules = std::collections::HashMap::new();
        for source_file in &project_info.source_files {
            if verbose {
                println!("  Parsing {}...", source_file.path.display());
            }
            
            let source = std::fs::read_to_string(&source_file.path)
                .with_context(|| format!("Failed to read {}", source_file.path.display()))?;
            
            let tokens = vpy_parser::lex(&source)
                .map_err(|e| anyhow::anyhow!("Lex error in {}: {}", source_file.path.display(), e))?;
            
            let module = vpy_parser::parser::parse(tokens, source_file.path.to_str().unwrap_or("unknown"))
                .map_err(|e| anyhow::anyhow!("Parse error in {}: {}", source_file.path.display(), e))?;
            
            // Module name from file stem
            let module_name = source_file.path.file_stem()
                .and_then(|s| s.to_str())
                .unwrap_or("unknown")
                .to_string();
            
            modules.insert(module_name, module);
        }
        println!("  {} Parsed {} modules", "✓".green(), modules.len());
        
        // Phase 3: Unify modules
        println!("\n{}", "Phase 3: Unify Modules".bright_cyan().bold());
        let entry_module_name = project_info.entry_point
            .file_stem()
            .and_then(|s| s.to_str())
            .unwrap_or("main");
        
        let unified = vpy_unifier::unify_modules(modules, entry_module_name)
            .map_err(|e| anyhow::anyhow!("Unification error: {}", e))?;
        
        println!("  {} Unified {} items", "✓".green(), unified.items.len());

        // META TARGET override: redirect to pitrex/rp2350 build path
        if let Some(meta_target) = &unified.meta.target {
            if meta_target == "pitrex" {
                return cmd_build_pitrex(input, output, verbose);
            }
            if meta_target == "rp2350" {
                return cmd_build_rp2350(input, output, verbose, ram);
            }
        }

        // **CRITICAL**: Override rom_size and bank_size from META if specified
        let rom_size = unified.meta.rom_total_size.map(|s| s as usize).unwrap_or(rom_size);
        let bank_size = unified.meta.rom_bank_size.map(|s| s as usize).unwrap_or(bank_size);
        
        if verbose && (unified.meta.rom_total_size.is_some() || unified.meta.rom_bank_size.is_some()) {
            println!("  {} Using ROM size from META: {} bytes", "✓".cyan(), rom_size);
            println!("  {} Using Bank size from META: {} bytes", "✓".cyan(), bank_size);
        }
        
        // Phase 4: Code generation
        println!("\n{}", "Phase 4: Code Generation".bright_cyan().bold());
        let title = unified.meta.title_override.as_deref()
            .or(project_info.metadata.title.as_deref())
            .unwrap_or("VPY GAME");
        
        let bank_config = vpy_codegen::BankConfig::new(rom_size, bank_size);
        
        // Discover assets
        let assets = discover_assets(&input);
        
        let generated = vpy_codegen::generate_from_module(&unified, &bank_config, title, &assets)
            .map_err(|e| anyhow::anyhow!("Codegen error: {}", e))?;
        
        println!("  {} Generated {} bytes ASM", "✓".green(), generated.asm_source.len());
        
        // Determine output paths
        // CRITICAL FIX (2026-01-20): Detect project root directory properly
        // If input is src/main.vpy, we need to go up to find the .vpyproj or src/ parent
        let project_dir = {
            let input_parent = input.parent().unwrap_or_else(|| std::path::Path::new("."));
            
            // Check if parent is "src" directory - if so, go up one more level
            if input_parent.file_name().and_then(|n| n.to_str()) == Some("src") {
                input_parent.parent().unwrap_or(input_parent).to_path_buf()
            } else {
                // Otherwise, search for .vpyproj in current or parent directories
                let mut current = input_parent;
                loop {
                    // Check if there's a .vpyproj file here
                    if let Ok(entries) = std::fs::read_dir(current) {
                        let has_vpyproj = entries
                            .flatten()
                            .any(|entry| entry.path().extension().and_then(|s| s.to_str()) == Some("vpyproj"));
                        
                        if has_vpyproj {
                            break current.to_path_buf();
                        }
                    }
                    
                    // Go up one level
                    match current.parent() {
                        Some(parent) => current = parent,
                        None => break input_parent.to_path_buf(), // Reached root, use original parent
                    }
                }
            }
        };
        
        let build_dir = project_dir.join("build");
        std::fs::create_dir_all(&build_dir)?;
        
        // CRITICAL FIX (2026-01-20): Use project directory name, not input file name
        // This ensures test_incremental/src/main.vpy generates test_incremental.asm
        let project_name = project_dir
            .file_name()
            .and_then(|n| n.to_str())
            .unwrap_or_else(|| input.file_stem().and_then(|s| s.to_str()).unwrap_or("output"));
        
        // CRITICAL FIX (2026-01-18): When --output is specified, place ASM in same directory
        // This fixes IDE integration where it expects both .asm and .bin in the same location
        let (asm_path, _bin_path) = if let Some(ref output_bin) = output {
            // User specified --output path -> use same directory for ASM
            let output_dir = output_bin.parent().unwrap_or_else(|| std::path::Path::new("."));
            std::fs::create_dir_all(output_dir)?;
            
            let asm_file = if let Some(stem) = output_bin.file_stem().and_then(|s| s.to_str()) {
                format!("{}.asm", stem)
            } else {
                format!("{}.asm", project_name)
            };
            
            (output_dir.join(asm_file), output_bin.clone())
        } else {
            // No --output specified -> use default build/ directory
            (build_dir.join(format!("{}.asm", project_name)), build_dir.join(format!("{}.bin", project_name)))
        };
        
        // Write ASM file
        std::fs::write(&asm_path, &generated.asm_source)
            .with_context(|| format!("Failed to write ASM to {}", asm_path.display()))?;
        
        println!("  {} ASM written: {}", "✓".green(), asm_path.display());
        
        // Set up workspace paths for include directory (needed for VECTREX.I)
        let include_dir = resolve_include_dir();
        
        // **CRITICAL: Detect multibank BEFORE assembling**
        // If multibank is detected, skip unified assembler and use multi_bank_linker directly
        // Require at least 3 banks (2 code + 1 helpers); 2-bank configs use single-bank path.
        let num_banks_cli = rom_size / bank_size.max(1);
        let is_multibank = rom_size > 32768 && num_banks_cli > 2;

        if is_multibank {
            println!("\n{}", format!("Multibank detected: {} KB ROM ({} banks × {} KB)",
                rom_size / 1024,
                rom_size / bank_size,
                bank_size / 1024).bright_yellow().bold());
            
            println!("\n{}", "Phase 6.7: Multi-bank binary generation...".bright_cyan().bold());
            
            let output_path_mb = output.clone().unwrap_or_else(|| build_dir.join(format!("{}.bin", project_name)));
            
            let linker = vpy_linker::MultiBankLinker::new(
                bank_size as u32,
                (rom_size / bank_size) as u8,
                true, // use native assembler
                Some(include_dir.clone()) // include dir for VECTREX.I
            );
            
            match linker.generate_multibank_rom(&asm_path, &output_path_mb) {
                Ok(symbol_table) => {
                    println!("  {} Phase 6.7 SUCCESS: Multi-bank binary written to {}",
                        "✓".green(), output_path_mb.display());
                    println!("     Total size: {} KB ({} banks × {} KB)",
                        rom_size / 1024,
                        rom_size / bank_size,
                        bank_size / 1024);
                    
                    // Phase 9: Generate PDB debug symbols for multibank
                    {
                        println!("\n{}", "Phase 9: Generating debug symbols (multibank)...".bright_cyan());
                        // Use bank_00_full.asm which contains all EQU definitions for the project
                        let flat_asm_path = output_path_mb.parent()
                            .unwrap_or_else(|| std::path::Path::new("."))
                            .join("multibank_temp")
                            .join("bank_00_full.asm");
                        let pdb_path = output_path_mb.with_extension("pdb");
                        let func_lines: Vec<(String, usize)> = unified.items.iter().filter_map(|it| {
                            if let vpy_parser::Item::Function(f) = it {
                                Some((f.name.to_uppercase(), f.line))
                            } else { None }
                        }).collect();
                        let bank_asms = collect_bank_asms(flat_asm_path.parent()
                            .unwrap_or_else(|| std::path::Path::new(".")));
                        // Use the entry .vpy file name (not project name) so the IDE opens the
                        // correct source tab when a breakpoint hits.
                        let src_name = format!("{}.vpy", entry_module_name);
                        match std::fs::read_to_string(&flat_asm_path) {
                            Ok(flat_asm) => {
                                match generate_pdb(&flat_asm, &src_name, &pdb_path, &symbol_table, &func_lines, &bank_asms) {
                                    Ok(()) => println!("  {} PDB written: {}", "✓".green(), pdb_path.display()),
                                    Err(e) => eprintln!("  ⚠ PDB write failed: {}", e),
                                }
                            }
                            Err(_) => eprintln!("  ⚠ PDB skipped: bank_00_full.asm not found"),
                        }
                    }
                    
                    println!("\n{}", format!("✓ BUILD SUCCESS (multibank): {} KB written to {}", 
                        rom_size / 1024,
                        output_path_mb.display()).bright_green().bold());
                    
                    return Ok(());
                }
                Err(e) => {
                    // FATAL ERROR: Multibank build explicitly requested via META but failed
                    // DO NOT fallback to single-bank - user expects multibank ROM
                    eprintln!("\n{}", format!("❌ BUILD FAILED (multibank): {}", e).bright_red().bold());
                    eprintln!("\n  Multibank ROM generation failed.");
                    eprintln!("  Project has META ROM_TOTAL_SIZE={} - multibank is REQUIRED.", rom_size);
                    eprintln!("  Cannot fallback to single-bank (code exceeds 32KB limit).");
                    eprintln!("\n  Common causes:");
                    eprintln!("    - Cross-bank symbol references not resolved (PASS 1 failure)");
                    eprintln!("    - Asset distribution issues (symbols missing from banks)");
                    eprintln!("    - Syntax errors in generated bank ASM");
                    return Err(anyhow::anyhow!("Multibank build failed: {}", e));
                }
            }
        }
        
        // Phase 5: Parse ASM into bank sections (single-bank path OR multibank fallback)
        println!("\n{}", "Phase 5: Parse Bank Sections".bright_cyan().bold());
        
        let sections = vpy_assembler::parse_unified_asm(&generated.asm_source)
            .context("Failed to parse unified ASM")?;
        
        if verbose {
            println!("  Found {} bank section(s)", sections.len());
            for section in &sections {
                println!("    Bank {}: {} lines at ORG ${:04X}", 
                    section.bank_id, section.asm_lines.len(), section.org_address);
            }
        }
        
        // Phase 6: Assemble banks
        println!("\n{}", "Phase 6: Assemble Banks".bright_cyan().bold());
        
        // Set include directory for VECTREX.I (absolute path from CLI binary location)
        vpy_assembler::set_include_dir(Some(include_dir.clone()));
        
        let binaries = vpy_assembler::assemble_banks(sections)
            .context("Failed to assemble banks")?;
        
        if verbose {
            for binary in &binaries {
                println!("    Bank {}: {} bytes", binary.bank_id, binary.bytes.len());
            }
        }
        println!("  {} Assembled {} bank(s)", "✓".green(), binaries.len());

        // Phase 7: Link ROM
        println!("\n{}", "Phase 7: Link ROM".bright_cyan().bold());

        let code_bytes: usize = binaries.iter().map(|b| b.bytes.len()).sum();
        let rom = vpy_linker::link_unified_asm(&generated, binaries)
            .context("Failed to link ROM")?;
        let padded_bytes = rom.rom_data.len();

        println!("  {} ROM size: {} bytes", "✓".green(), padded_bytes);
        println!("  {} Code:     {} bytes ({} bytes free)", "✓".green(), code_bytes, padded_bytes - code_bytes);
        println!("  {} Symbols: {}", "✓".green(), rom.symbols.len());

        // Phase 8: Write binary
        println!("\n{}", "Phase 8: Write Binary".bright_cyan().bold());

        let output_path = output.unwrap_or_else(|| build_dir.join(format!("{}.bin", project_name)));

        std::fs::write(&output_path, &rom.rom_data)
            .context("Failed to write binary")?;

        println!("  {} Binary written: {}", "✓".green(), output_path.display());

        println!("\n{}", format!("✓ BUILD SUCCESS: {} bytes ({} free)", padded_bytes, padded_bytes - code_bytes).bright_green().bold());
        
        return Ok(());
    }
    
    // Single-file project: use buildtools pipeline (unchanged)
    let source_path = input.clone();
    
    let source = std::fs::read_to_string(&source_path)
        .context("Failed to read input file")?;
    
    let tokens = vpy_parser::lex(&source)
        .map_err(|e| anyhow::anyhow!("Lex error: {}", e))?;
    
    let module = vpy_parser::parser::parse(tokens, source_path.to_str().unwrap_or("unknown"))
        .map_err(|e| anyhow::anyhow!("Parse error: {}", e))?;
    
    // Extract function names
    let mut functions = Vec::new();
    for item in &module.items {
        if let vpy_parser::Item::Function(func) = item {
            functions.push(func.name.clone());
        }
    }
    
    // Override rom_size and bank_size from META if specified
    let rom_size = module.meta.rom_total_size.map(|s| s as usize).unwrap_or(rom_size);
    let bank_size = module.meta.rom_bank_size.map(|s| s as usize).unwrap_or(bank_size);
    
    if verbose && (module.meta.rom_total_size.is_some() || module.meta.rom_bank_size.is_some()) {
        println!("  Using ROM size from META: {} bytes", rom_size);
        println!("  Using Bank size from META: {} bytes", bank_size);
    }
    
    // Extract title from META (default to filename if not specified)
    let title = module.meta.title_override
        .as_deref()
        .unwrap_or("VPY GAME");
    
    // Phase 1: Generate unified ASM
    if verbose {
        println!("\n{}", "Phase 1: Generating unified ASM...".bright_cyan());
        println!("  Title: {}", title);
    }
    
    let bank_config = vpy_codegen::BankConfig::new(rom_size, bank_size);
    
    // Discover assets
    let assets = discover_assets(&source_path);
    
    let generated = vpy_codegen::generate_from_module(&module, &bank_config, title, &assets)
        .context("Failed to generate ASM")?;
    
    if verbose {
        println!("  ASM size: {} bytes", generated.asm_source.len());
        println!("  Symbols: {}", generated.symbols.len());
    }
    
    // Phase 2: Parse unified ASM into bank sections
    if verbose {
        println!("\n{}", "Phase 2: Parsing bank sections...".bright_cyan());
    }
    
    let sections = vpy_assembler::parse_unified_asm(&generated.asm_source)
        .context("Failed to parse unified ASM")?;
    
    if verbose {
        println!("  Found {} bank section(s)", sections.len());
        for section in &sections {
            println!("    Bank {}: {} lines at ORG ${:04X}", 
                section.bank_id, section.asm_lines.len(), section.org_address);
        }
    }
    
    // SAVE ASM FILE NOW (before assembling, so we can debug failures)
    // CRITICAL FIX (2026-01-20): Detect project root directory properly
    let project_dir = {
        let input_parent = source_path.parent().unwrap_or_else(|| std::path::Path::new("."));
        
        // Check if parent is "src" directory - if so, go up one more level
        if input_parent.file_name().and_then(|n| n.to_str()) == Some("src") {
            input_parent.parent().unwrap_or(input_parent).to_path_buf()
        } else {
            // Otherwise, search for .vpyproj in current or parent directories
            let mut current = input_parent;
            loop {
                // Check if there's a .vpyproj file here
                if let Ok(entries) = std::fs::read_dir(current) {
                    let has_vpyproj = entries
                        .flatten()
                        .any(|entry| entry.path().extension().and_then(|s| s.to_str()) == Some("vpyproj"));
                    
                    if has_vpyproj {
                        break current.to_path_buf();
                    }
                }
                
                // Go up one level
                match current.parent() {
                    Some(parent) => current = parent,
                    None => break input_parent.to_path_buf(), // Reached root, use original parent
                }
            }
        }
    };
    
    let build_dir = project_dir.join("build");
    std::fs::create_dir_all(&build_dir)?;
    
    // Use project directory name, not input file name
    let project_name = project_dir
        .file_name()
        .and_then(|n| n.to_str())
        .unwrap_or_else(|| source_path.file_stem().and_then(|s| s.to_str()).unwrap_or("output"));
    
    let asm_path = if let Some(ref output_bin) = output {
        output_bin.with_extension("asm")
    } else {
        build_dir.join(format!("{}.asm", project_name))
    };
    
    // Write ASM file
    std::fs::write(&asm_path, &generated.asm_source)
        .with_context(|| format!("Failed to write ASM to {}", asm_path.display()))?;
    
    if verbose {
        println!("  ASM written: {}", asm_path.display());
    }
    
    // **CRITICAL: Detect multibank BEFORE assembling**
    // If multibank is detected, skip unified assembler and use multi_bank_linker directly
    // Require at least 3 banks (2 code + 1 helpers); 2-bank configs use single-bank path.
    let num_banks_fn = rom_size / bank_size.max(1);
    let is_multibank = rom_size > 32768 && num_banks_fn > 2;

    if is_multibank {
        println!("\n{}", format!("Multibank detected: {} KB ROM ({} banks × {} KB)",
            rom_size / 1024,
            rom_size / bank_size,
            bank_size / 1024).bright_yellow().bold());
        
        println!("\n{}", "Phase 6.7: Multi-bank binary generation...".bright_cyan().bold());
        
        let output_path_mb = output.clone().unwrap_or_else(|| {
            source_path.with_extension("bin")
        });
        
        let include_dir = resolve_include_dir();

        let linker = vpy_linker::MultiBankLinker::new(
            bank_size as u32,
            (rom_size / bank_size) as u8,
            true, // use native assembler
            Some(include_dir.clone()) // include dir for VECTREX.I
        );
        
        match linker.generate_multibank_rom(&asm_path, &output_path_mb) {
            Ok(symbol_table) => {
                println!("  {} Phase 6.7 SUCCESS: Multi-bank binary written to {}",
                    "✓".green(), output_path_mb.display());
                println!("     Total size: {} KB ({} banks × {} KB)",
                    rom_size / 1024,
                    rom_size / bank_size,
                    bank_size / 1024);
                
                // Phase 9: Generate PDB debug symbols for multibank (single-file path)
                {
                    println!("\n{}", "Phase 9: Generating debug symbols (multibank)...".bright_cyan());
                    let flat_asm_path = output_path_mb.parent()
                        .unwrap_or_else(|| std::path::Path::new("."))
                        .join("multibank_temp")
                        .join("bank_00_full.asm");
                    let pdb_path = output_path_mb.with_extension("pdb");
                    let func_lines: Vec<(String, usize)> = module.items.iter().filter_map(|it| {
                        if let vpy_parser::Item::Function(f) = it {
                            Some((f.name.to_uppercase(), f.line))
                        } else { None }
                    }).collect();
                    let bank_asms = collect_bank_asms(flat_asm_path.parent()
                        .unwrap_or_else(|| std::path::Path::new(".")));
                    // Use the entry .vpy file name (not project name) so the IDE opens the
                    // correct source tab when a breakpoint hits.
                    let src_name = source_path.file_name().and_then(|n| n.to_str()).unwrap_or("main.vpy");
                    match std::fs::read_to_string(&flat_asm_path) {
                        Ok(flat_asm) => {
                            match generate_pdb(&flat_asm, src_name, &pdb_path, &symbol_table, &func_lines, &bank_asms) {
                                Ok(()) => println!("  {} PDB written: {}", "✓".green(), pdb_path.display()),
                                Err(e) => eprintln!("  ⚠ PDB write failed: {}", e),
                            }
                        }
                        Err(_) => eprintln!("  ⚠ PDB skipped: bank_00_full.asm not found"),
                    }
                }
                
                println!("\n{}", format!("✓ Build SUCCESS (multibank): {} KB written to {}", 
                    rom_size / 1024,
                    output_path_mb.display()).bright_green().bold());
                
                return Ok(());
            }
            Err(e) => {
                // FATAL ERROR: Multibank build explicitly requested via META but failed
                // DO NOT fallback to single-bank - user expects multibank ROM
                eprintln!("\n{}", format!("❌ Link FAILED (multibank): {}", e).bright_red().bold());
                eprintln!("\n  Multibank ROM generation failed during link command.");
                eprintln!("  Cannot fallback to single-bank (multibank explicitly requested).");
                eprintln!("\n  Common causes:");
                eprintln!("    - Cross-bank symbol references not resolved");
                eprintln!("    - Missing .vo object files");
                eprintln!("    - Incompatible object file versions");
                return Err(anyhow::anyhow!("Multibank link failed: {}", e));
            }
        }
    }
    
    // Phase 3: Assemble each bank (single-bank path OR multibank fallback)
    if verbose {
        println!("\n{}", "Phase 3: Assembling banks...".bright_cyan());
    }
    
    // Set include directory for VECTREX.I
    let include_dir = resolve_include_dir();
    vpy_assembler::set_include_dir(Some(include_dir.clone()));
    
    let binaries = vpy_assembler::assemble_banks(sections)
        .context("Failed to assemble banks")?;
    
    if verbose {
        for binary in &binaries {
            println!("    Bank {}: {} bytes", binary.bank_id, binary.bytes.len());
        }
    }
    
    // Phase 4: Link banks into ROM
    if verbose {
        println!("\n{}", "Phase 4: Linking ROM...".bright_cyan());
    }

    let code_bytes: usize = binaries.iter().map(|b| b.bytes.len()).sum();
    let rom = vpy_linker::link_unified_asm(&generated, binaries)
        .context("Failed to link ROM")?;
    let padded_bytes = rom.rom_data.len();

    if verbose {
        println!("  ROM size: {} bytes", padded_bytes);
        println!("  Code:     {} bytes ({} bytes free)", code_bytes, padded_bytes - code_bytes);
        println!("  Symbols: {}", rom.symbols.len());
    }
    
    // Phase 5: Write binary
    let output_path = output.unwrap_or_else(|| {
        source_path.with_extension("bin")
    });
    
    if verbose {
        println!("\n{}", "Phase 5: Writing outputs...".bright_cyan());
    }
    
    // Write binary file
    std::fs::write(&output_path, &rom.rom_data)
        .context("Failed to write binary")?;
    
    if verbose {
        println!("  BIN written: {}", output_path.display());
    }
    
    // Phase 9: Generate PDB debug symbols
    {
        println!("\n{}", "Phase 9: Generating debug symbols...".bright_cyan());
        let pdb_path = output_path.with_extension("pdb");
        // Real symbol addresses from the linker (single-bank: offset == bank-relative PC).
        let sb_syms: std::collections::BTreeMap<String, u16> = rom.symbols.iter()
            .map(|(name, loc)| (name.clone(), loc.offset))
            .collect();
        // Function name → VPy definition line, for vpyLineMap breakpoint resolution.
        let sb_funcs: Vec<(String, usize)> = module.items.iter().filter_map(|it| {
            if let vpy_parser::Item::Function(f) = it {
                Some((f.name.to_uppercase(), f.line))
            } else { None }
        }).collect();
        match generate_pdb(&generated.asm_source, source_path.file_name().and_then(|n| n.to_str()).unwrap_or("main.vpy"), &pdb_path, &sb_syms, &sb_funcs, &[]) {
            Ok(()) => println!("  {} PDB written: {}", "✓".green(), pdb_path.display()),
            Err(e) => eprintln!("  ⚠ PDB write failed: {}", e),
        }
    }
    
    println!("\n{}", format!("✓ Build SUCCESS: {} bytes written to {}", 
        rom.rom_data.len(),
        output_path.display()).green().bold());
    
    Ok(())
}

/// Generate a minimal .pdb JSON file by parsing the generated ASM source.
///
/// Extracts:
///   - variables: lines matching `VAR_FOO  EQU $BASE+$OFF  ; ... (N bytes)`
///   - functions: lines matching `FUNC_NAME:` at start of line (not VAR_/EQU/FCB/FDB)
///   - labels: all other `LABEL:` definitions
///   - line map: `; VPy_LINE:N` annotations
/// Collects per-bank full ASM files from a multibank_temp directory: returns
/// (bank_id, file content, relative path) sorted by bank id, for `bank_NN_full.asm`.
fn collect_bank_asms(temp_dir: &std::path::Path) -> Vec<(u8, String, String)> {
    let mut out: Vec<(u8, String, String)> = Vec::new();
    if let Ok(entries) = std::fs::read_dir(temp_dir) {
        for e in entries.flatten() {
            let fname = e.file_name().to_string_lossy().to_string();
            if let Some(rest) = fname.strip_prefix("bank_") {
                if let Some(num) = rest.strip_suffix("_full.asm") {
                    if let Ok(bank_id) = num.parse::<u8>() {
                        if let Ok(content) = std::fs::read_to_string(e.path()) {
                            out.push((bank_id, content, format!("multibank_temp/{}", fname)));
                        }
                    }
                }
            }
        }
    }
    out.sort_by_key(|(b, _, _)| *b);
    out
}

fn generate_pdb(
    asm_source: &str,
    source_name: &str,
    output_pdb_path: &std::path::Path,
    // label name (UPPERCASE) -> bank-relative address (PC). From the linker (Phase 7).
    symbol_table: &std::collections::BTreeMap<String, u16>,
    // (UPPERCASE function name, VPy def line). From the parsed module.
    func_lines: &[(String, usize)],
    // Per-bank full ASM: (bank_id, file content, relative path). Each is assembled
    // standalone to build a bank-aware line/address map (asmBankAddr) and the
    // bank->file table (asmBankFiles) so the IDE opens the active bank's ASM on pause.
    bank_asms: &[(u8, String, String)],
) -> std::io::Result<()> {
    use std::collections::HashMap;

    // ── Output maps (IDE PdbData schema; see ide/frontend/src/state/debugStore.ts) ──
    let mut variables: serde_json::Map<String, serde_json::Value> = serde_json::Map::new();
    let mut functions: serde_json::Map<String, serde_json::Value> = serde_json::Map::new(); // VPy fn -> {startLine,endLine,address,type}
    let mut symbols: serde_json::Map<String, serde_json::Value> = serde_json::Map::new();   // label -> "0xADDR"
    let mut labels: serde_json::Map<String, serde_json::Value> = serde_json::Map::new();    // non-VAR equate -> int
    let mut line_map: serde_json::Map<String, serde_json::Value> = serde_json::Map::new();  // "vpyLine" -> "0xADDR" (VPy breakpoints)
    let mut vpy_line_map: serde_json::Map<String, serde_json::Value> = serde_json::Map::new(); // "decAddr" -> {file,line,column} (PC→VPy)
    let mut asm_line_map: serde_json::Map<String, serde_json::Value> = serde_json::Map::new(); // "0xADDR" -> {file,address,line} (PC→ASM)
    let mut native_calls: serde_json::Map<String, serde_json::Value> = serde_json::Map::new(); // "vpyLine" -> "NAME"
    let mut asm_functions: serde_json::Map<String, serde_json::Value> = serde_json::Map::new(); // label -> {name,file,startLine,endLine,type}
    let mut bios_symbols: serde_json::Map<String, serde_json::Value> = serde_json::Map::new();  // BIOS name -> "0xADDR"
    let mut asm_address_map: serde_json::Map<String, serde_json::Value> = serde_json::Map::new();
    let mut asm_bank_addr: serde_json::Map<String, serde_json::Value> = serde_json::Map::new();
    let mut asm_bank_files: serde_json::Map<String, serde_json::Value> = serde_json::Map::new();
    let mut asm_file_field = serde_json::Value::Null;

    // EQU address parser: `NAME  EQU $BASE+$OFF` or `NAME  EQU $ADDR`
    let parse_equ_address = |line: &str| -> Option<u32> {
        let code = line.split(';').next()?.trim();
        let mut it = code.split_whitespace();
        let _name = it.next()?;
        let kw = it.next()?.to_uppercase();
        if kw != "EQU" { return None; }
        let rhs = it.next()?;
        if let Some((base, off)) = rhs.split_once('+') {
            let b = u32::from_str_radix(base.trim_start_matches('$'), 16).ok()?;
            let o = u32::from_str_radix(off.trim_start_matches('$'), 16).ok()?;
            Some(b.wrapping_add(o))
        } else {
            u32::from_str_radix(rhs.trim_start_matches('$'), 16).ok()
        }
    };
    let parse_comment_size = |line: &str| -> usize {
        let comment = line.split(';').nth(1).unwrap_or("");
        if let Some(bp) = comment.rfind(" bytes)") {
            let before = &comment[..bp];
            if let Some(pp) = before.rfind('(') {
                if let Ok(n) = before[pp+1..].trim().parse::<usize>() { return n; }
            }
        }
        2
    };

    // ── Variables + equate labels (from the unified ASM text) ──
    for line in asm_source.lines() {
        let trimmed = line.trim();
        let code = trimmed.split(';').next().unwrap_or("").trim();
        if !code.to_uppercase().contains(" EQU ") { continue; }
        let Some(name) = code.split_whitespace().next() else { continue };
        let Some(addr) = parse_equ_address(trimmed) else { continue };
        if name.starts_with("VAR_") {
            let size = parse_comment_size(trimmed);
            let clean = name.strip_prefix("VAR_").unwrap_or(name).to_lowercase();
            let var_type = if line.contains("system") || line.contains("System") { "system" }
                else if line.contains("array") || name.contains("_DATA") { "array" }
                else { "unknown" };
            variables.insert(clean.clone(), serde_json::json!({
                "name": clean, "address": format!("0x{:04X}", addr),
                "size": size, "type": var_type, "declLine": null
            }));
        } else if !name.starts_with('_') {
            labels.insert(name.to_string(), serde_json::Value::Number(addr.into()));
        }
    }

    // ── Symbols: every linker-resolved label -> "0xADDR" ──
    for (name, addr) in symbol_table {
        symbols.insert(name.clone(), serde_json::Value::String(format!("0x{:04X}", addr)));
    }

    // ── BIOS symbols from VECTREX.I (NAME EQU/SET $XXXX) ──
    {
        let inc = resolve_include_dir();
        if let Ok(content) = std::fs::read_to_string(inc.join("VECTREX.I")) {
            for l in content.lines() {
                let code = l.split(';').next().unwrap_or("").split('*').next().unwrap_or("");
                let mut it = code.split_whitespace();
                if let (Some(name), Some(kw), Some(val)) = (it.next(), it.next(), it.next()) {
                    let kw = kw.to_ascii_uppercase();
                    if kw == "EQU" || kw == "SET" {
                        let v = val.trim();
                        let parsed = if let Some(h) = v.strip_prefix('$') {
                            u32::from_str_radix(h, 16).ok()
                        } else if let Some(h) = v.strip_prefix("0x").or_else(|| v.strip_prefix("0X")) {
                            u32::from_str_radix(h, 16).ok()
                        } else { v.parse::<u32>().ok() };
                        if let Some(a) = parsed {
                            bios_symbols.insert(name.to_string(), serde_json::Value::String(format!("0x{:04X}", a)));
                        }
                    }
                }
            }
        }
    }

    // ── VPy functions: name -> {startLine,endLine,address,type} ──
    {
        let mut sorted: Vec<(usize, &str)> = func_lines.iter().map(|(n, l)| (*l, n.as_str())).collect();
        sorted.sort();
        for (i, (def_line, uname)) in sorted.iter().enumerate() {
            // VPy `loop()` compiles to the label `LOOP_BODY`, not `LOOP`; fall back to `<NAME>_BODY`.
            let addr = symbol_table.get(*uname)
                .or_else(|| symbol_table.get(&format!("{}_BODY", uname)))
                .copied().unwrap_or(0);
            let end_line = if i + 1 < sorted.len() { sorted[i + 1].0.saturating_sub(1) } else { def_line + 1 };
            functions.insert(uname.to_string(), serde_json::json!({
                "address": format!("0x{:04X}", addr),
                "startLine": def_line, "endLine": end_line, "type": "vpy"
            }));
        }
    }

    // ── Seed the re-assembler so each unit resolves operands (linker labels + EQUs) ──
    let mut seed_equates: HashMap<String, u16> = HashMap::new();
    for (name, addr) in symbol_table { seed_equates.insert(name.clone(), *addr); }
    for line in asm_source.lines() {
        let t = line.trim();
        if t.to_uppercase().contains(" EQU ") {
            if let Some(name) = t.split_whitespace().next() {
                if let Some(addr) = parse_equ_address(t) { seed_equates.insert(name.to_string(), addr as u16); }
            }
        }
    }

    // Units to assemble: single-bank = one (asm_source); multibank = each bank file.
    let asm_name = source_name.replace(".vpy", ".asm");
    let units: Vec<(&str, u16, Option<u8>, String)> = if bank_asms.is_empty() {
        asm_file_field = serde_json::Value::String(asm_name.clone());
        vec![(asm_source, 0x0000u16, None, asm_name.clone())]
    } else {
        bank_asms.iter().map(|(b, c, rel)| {
            let org = if c.contains("ORG $4000") { 0x4000u16 } else { 0x0000u16 };
            (c.as_str(), org, Some(*b), rel.clone())
        }).collect()
    };

    for (text, org, bank_opt, file_rel) in &units {
        let line_to_addr = match vpy_assembler::m6809::asm_to_binary::assemble_m6809_seeded(text, *org, true, false, &seed_equates) {
            Ok((_bin, map, _syms, _unresolved)) => map,
            Err(e) => { eprintln!("  ⚠ PDB asm map skipped for {}: {}", file_rel, e); continue; }
        };

        // asmAddressMap (single) / asmBankAddr (multi) + asmLineMap (PC→ASM)
        for (asm_line, addr) in &line_to_addr {
            let a = *addr as u16;
            let key = format!("0x{:04X}", a);
            match bank_opt {
                Some(b) => { asm_bank_addr.insert(format!("{}:{:04X}", b, a), serde_json::Value::Number((*asm_line as u64).into())); }
                None => {
                    asm_address_map.insert(asm_line.to_string(), serde_json::Value::String(format!("{:04X}", a)));
                    // asmLineMap (PC→ASM) is single-bank only: bank-relative addresses
                    // collide across banks, so multibank uses asmBankAddr/asmBankFiles instead.
                    asm_line_map.entry(key.clone()).or_insert_with(|| {
                        let mut o = serde_json::Map::new();
                        o.insert("file".into(), serde_json::Value::String(file_rel.clone()));
                        o.insert("address".into(), serde_json::Value::String(key.clone()));
                        o.insert("line".into(), serde_json::Value::Number((*asm_line as u64).into()));
                        serde_json::Value::Object(o)
                    });
                }
            }
        }
        if let Some(b) = bank_opt { asm_bank_files.insert(b.to_string(), serde_json::Value::String(file_rel.clone())); }

        // Per-statement VPy↔ASM + native-call scan. Runs for every unit/bank: the
        // VPy_LINE annotations survive into each bank's full ASM, so multibank gets
        // statement-granularity breakpoints too. Banks are scanned in ascending order
        // and first-writer wins, so a bank-relative address that collides across banks
        // keeps the lower bank's (user code lives in the low banks).
        // The physical line counter must match the assembler (1-based, every line).
        {
            let mut pending_vpy: Option<u32> = None;
            let mut phys = 0usize;
            let mut label_lines: Vec<(String, usize)> = Vec::new();
            for raw in text.lines() {
                phys += 1;
                let t = raw.trim();
                if let Some(rest) = t.strip_prefix("; VPy_LINE:") {
                    if let Ok(n) = rest.trim().parse::<u32>() { pending_vpy = Some(n); }
                    continue;
                }
                if let Some(rest) = t.strip_prefix("; NATIVE_CALL:") {
                    if let Some((name, ln)) = rest.trim().split_once(" at line ") {
                        if let Ok(n) = ln.trim().parse::<u32>() {
                            native_calls.entry(n.to_string())
                                .or_insert_with(|| serde_json::Value::String(name.trim().to_string()));
                        }
                    }
                    continue;
                }
                // Track label defs for asmFunctions.
                let code = t.split(';').next().unwrap_or("").trim();
                if let Some(lbl) = code.strip_suffix(':') {
                    let lbl = lbl.trim();
                    if !lbl.is_empty() && !lbl.contains(' ') && !lbl.starts_with('.') {
                        label_lines.push((lbl.to_string(), phys));
                    }
                }
                // First addressed line after a VPy_LINE marker binds that VPy line.
                if let Some(n) = pending_vpy {
                    if let Some(addr) = line_to_addr.get(&phys) {
                        let a = *addr as u16;
                        let hex = format!("0x{:04X}", a);
                        line_map.entry(n.to_string()).or_insert_with(|| serde_json::Value::String(hex.clone()));
                        vpy_line_map.entry(a.to_string()) // decimal-addr key (IDE PC→VPy lookup)
                            .or_insert_with(|| serde_json::json!({ "file": source_name, "line": n, "column": 0 }));
                        pending_vpy = None;
                    }
                }
            }
            // asmFunctions: single-bank only (multibank PC→ASM uses asmBankAddr).
            if bank_opt.is_none() {
                for (i, (name, start)) in label_lines.iter().enumerate() {
                    let end = if i + 1 < label_lines.len() { label_lines[i + 1].1.saturating_sub(1) } else { *start };
                    let ty = if bios_symbols.contains_key(name) { "bios" }
                        else if func_lines.iter().any(|(u, _)| u == &name.to_uppercase()) { "vpy" }
                        else { "native" };
                    asm_functions.entry(name.clone()).or_insert_with(|| serde_json::json!({
                        "name": name, "file": file_rel, "startLine": start, "endLine": end, "type": ty
                    }));
                }
            }
        }
    }

    // Multibank: point pdb.asm at bank 0's file as a default.
    if !bank_asms.is_empty() {
        if let Some(b0) = asm_bank_files.get("0") { asm_file_field = b0.clone(); }
    }

    let entry = symbol_table.get("START").or_else(|| symbol_table.get("MAIN")).copied().unwrap_or(0);

    let pdb = serde_json::json!({
        "version": "2.0",
        "source": source_name,
        "asm": asm_file_field,
        "binary": source_name.replace(".vpy", ".bin"),
        "entry_point": format!("0x{:04X}", entry),
        "symbols": symbols,
        "variables": variables,
        "functions": functions,
        "labels": labels,
        "lineMap": line_map,
        "vpyLineMap": vpy_line_map,
        "asmLineMap": asm_line_map,
        "asmAddressMap": asm_address_map,
        "asmBankAddr": asm_bank_addr,
        "asmBankFiles": asm_bank_files,
        "asmFunctions": asm_functions,
        "nativeCalls": native_calls,
        "bios_symbols": bios_symbols
    });

    let json_str = serde_json::to_string_pretty(&pdb)
        .map_err(|e| std::io::Error::new(std::io::ErrorKind::Other, e))?;
    std::fs::write(output_pdb_path, json_str)
}
