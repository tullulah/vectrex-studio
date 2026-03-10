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
        
        Commands::Asm { input, rom_size, bank_size, output } => {
            println!("{}", "=== GENERATE UNIFIED ASM ===".bright_cyan().bold());
            cmd_asm(&input, rom_size, bank_size, output)?;
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
        
        Commands::Build { input, output, rom_size, bank_size, debug, verbose } => {
            println!("{}", "=== FULL BUILD PIPELINE ===".bright_green().bold());
            cmd_build(&input, output, rom_size, bank_size, debug, verbose)?;
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

fn cmd_asm(input: &PathBuf, rom_size: usize, bank_size: usize, output: Option<PathBuf>) -> Result<()> {
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
    
    // Discover assets (vectors, music, sfx, levels)
    let assets = discover_assets(&source_path);
    
    // Generate unified ASM using real M6809 backend
    let generated = vpy_codegen::generate_from_module(&module, &bank_config, title, &assets)
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

fn cmd_build(input: &PathBuf, output: Option<PathBuf>, rom_size: usize, bank_size: usize, _debug: bool, verbose: bool) -> Result<()> {
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
                Ok(_symbol_table) => {
                    println!("  {} Phase 6.7 SUCCESS: Multi-bank binary written to {}",
                        "✓".green(), output_path_mb.display());
                    println!("     Total size: {} KB ({} banks × {} KB)",
                        rom_size / 1024,
                        rom_size / bank_size,
                        bank_size / 1024);
                    
                    // Phase 9: Generate PDB debug symbols for multibank
                    {
                        println!("\n{}", "Phase 9: Generating debug symbols (multibank)...".bright_cyan());
                        
                        // Load VECTREX.I for BIOS symbols
                        let vectrex_i_path = include_dir.join("VECTREX.I");
                        let _vectrex_i_content = if vectrex_i_path.exists() {
                            std::fs::read_to_string(&vectrex_i_path).ok()
                        } else {
                            None
                        };
                        
                        // TODO: PDB generation disabled - vpy_debug_gen incomplete
                        eprintln!("  ⚠ PDB generation skipped (buildtools implementation incomplete)");
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
            Ok(_symbol_table) => {
                println!("  {} Phase 6.7 SUCCESS: Multi-bank binary written to {}",
                    "✓".green(), output_path_mb.display());
                println!("     Total size: {} KB ({} banks × {} KB)",
                    rom_size / 1024,
                    rom_size / bank_size,
                    bank_size / 1024);
                
                // Phase 9: Generate PDB debug symbols for multibank (single-file path)
                {
                    println!("\n{}", "Phase 9: Generating debug symbols (multibank)...".bright_cyan());
                    
                    let include_dir = resolve_include_dir();
                    
                    // Load VECTREX.I for BIOS symbols
                    let vectrex_i_path = include_dir.join("VECTREX.I");
                    let _vectrex_i_content = if vectrex_i_path.exists() {
                        std::fs::read_to_string(&vectrex_i_path).ok()
                    } else {
                        None
                    };
                    
                    // TODO: PDB generation disabled - vpy_debug_gen incomplete
                    eprintln!("  ⚠ PDB generation skipped (buildtools implementation incomplete)");
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
    
    // Phase 9: Generate PDB debug symbols (if requested or always for now)
    {
        println!("\n{}", "Phase 9: Generating debug symbols...".bright_cyan());
        
        // Load VECTREX.I for BIOS symbols
        let _vectrex_i_content = if include_dir.join("VECTREX.I").exists() {
            std::fs::read_to_string(include_dir.join("VECTREX.I")).ok()
        } else {
            None
        };
        
        // TODO: PDB generation disabled - vpy_debug_gen incomplete
        eprintln!("  ⚠ PDB generation skipped (buildtools implementation incomplete)");
    }
    
    println!("\n{}", format!("✓ Build SUCCESS: {} bytes written to {}", 
        rom.rom_data.len(),
        output_path.display()).green().bold());
    
    Ok(())
}
