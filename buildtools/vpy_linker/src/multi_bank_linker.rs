/// Multi-Bank Linker - Generate 512KB multi-bank ROM from sectioned ASM
///
/// Sequential Bank Model (2025-01-02):
/// - Banks #0 to #(N-2): Code fills sequentially (address $0000 per bank)
/// - Bank #(N-1): Reserved for runtime helpers (address $0000)
///
/// Each bank is assembled with ORG $0000, then concatenated to form final ROM.
/// No "fixed bank" concept - all banks have same addressing model.

use std::collections::{HashMap, HashSet};
use std::fs;
use std::path::Path;

/// Generate cross-bank trampolines for user functions split across switchable banks.
///
/// When functions are split across switchable banks (0..helpers_bank-1), calls from
/// bank N to a function in bank M (N≠M) must go through a trampoline in the helpers
/// bank (always visible at $4000-$7FFF). The trampoline saves the current bank, switches
/// to the target bank, calls the function, then restores the original bank.
///
/// This function:
/// 1. Builds a label→bank map for all switchable banks
/// 2. Scans each bank's code for `JSR LABEL` crossing banks
/// 3. Replaces those JSRs with `JSR TRAMP_LABEL`
/// 4. Returns the trampoline ASM to be appended to the helpers bank
fn generate_cross_bank_trampolines(
    sections: &mut HashMap<u8, BankSection>,
    helpers_bank: u8,
) -> String {
    // Step 1: Build label→bank map for switchable banks only (not helpers bank)
    let mut label_to_bank: HashMap<String, u8> = HashMap::new();
    for (bank_id, section) in sections.iter() {
        if *bank_id == helpers_bank { continue; }
        for line in section.asm_code.lines() {
            let trimmed = line.trim();
            // Skip EQU definitions and empty/comment lines
            if trimmed.is_empty() || trimmed.starts_with(';') || trimmed.contains(" EQU ") {
                continue;
            }
            // Match "LABEL_NAME:" pattern (label definitions, not JSR targets)
            if let Some(colon_pos) = trimmed.find(':') {
                let label = trimmed[..colon_pos].trim();
                // Must be a non-empty identifier without spaces or dots (skip local labels)
                if !label.is_empty()
                    && !label.contains(' ')
                    && !label.starts_with('.')
                    && label.chars().next().map(|c| c.is_alphabetic() || c == '_').unwrap_or(false)
                {
                    label_to_bank.entry(label.to_string()).or_insert(*bank_id);
                }
            }
        }
    }

    if label_to_bank.is_empty() {
        return String::new();
    }

    // Step 2: Scan each switchable bank for cross-bank JSR calls and patch them
    let mut trampolines = String::new();
    let mut generated_trampolines: HashSet<String> = HashSet::new();

    let bank_ids: Vec<u8> = sections.keys().cloned().collect();

    for bank_id in bank_ids {
        if bank_id == helpers_bank { continue; }

        let new_code = {
            let section = sections.get(&bank_id).unwrap();
            let mut new_code = String::new();

            for line in section.asm_code.lines() {
                let trimmed = line.trim();

                // Match "JSR LABEL" (not JSR $xxxx, not JSR ,X, etc.)
                if let Some(after_jsr) = trimmed.strip_prefix("JSR ") {
                    let target = after_jsr.trim().split(|c: char| c.is_whitespace() || c == ';').next().unwrap_or("");

                    // Only intercept named labels (not $ addresses, not empty)
                    if !target.is_empty() && !target.starts_with('$') && !target.starts_with(',') {
                        if let Some(&target_bank) = label_to_bank.get(target) {
                            if target_bank != bank_id {
                                let tramp_name = format!("TRAMP_{}", target);
                                let indent = &line[..line.len() - line.trim_start().len()];
                                new_code.push_str(&format!(
                                    "{}JSR {}  ; cross-bank trampoline (bank #{} -> bank #{})\n",
                                    indent, tramp_name, bank_id, target_bank
                                ));

                                // Generate the trampoline stub once
                                if generated_trampolines.insert(tramp_name.clone()) {
                                    eprintln!(
                                        "[LINKER] Cross-bank call: bank#{} -> bank#{} ({}), trampoline generated",
                                        bank_id, target_bank, target
                                    );
                                    trampolines.push_str(&format!("{}:\n", tramp_name));
                                    trampolines.push_str("    LDA CURRENT_ROM_BANK  ; save caller's bank\n");
                                    trampolines.push_str("    PSHS A\n");
                                    trampolines.push_str(&format!("    LDA #${:02X}  ; switch to bank #{}\n", target_bank, target_bank));
                                    trampolines.push_str("    STA CURRENT_ROM_BANK\n");
                                    trampolines.push_str("    STA $DF00\n");
                                    trampolines.push_str(&format!("    JSR {}\n", target));
                                    trampolines.push_str("    PULS A\n");
                                    trampolines.push_str("    STA CURRENT_ROM_BANK  ; restore caller's bank\n");
                                    trampolines.push_str("    STA $DF00\n");
                                    trampolines.push_str("    RTS\n");
                                }
                                continue;
                            }
                        }
                    }
                }

                new_code.push_str(line);
                new_code.push('\n');
            }
            new_code
        };

        sections.get_mut(&bank_id).unwrap().asm_code = new_code;
    }

    trampolines
}

/// Relocate ARRAY_XXX_DATA const-array ROM blocks from bank 0 to helpers bank.
///
/// In multibank mode, functions may run in any switchable bank (0-2). Const arrays
/// have their ROM data in bank 0 ($0000-based). When a function runs in bank 1 or 2,
/// the $0XXX address points to the wrong bank's memory.
///
/// Moving ARRAY_XXX_DATA blocks to helpers bank (fixed at $4000-$7FFF) makes them
/// accessible from any bank. MAIN's initialization code sets VAR_XXX = #ARRAY_XXX_DATA
/// which will now resolve to $4XXX (always valid).
fn relocate_array_data_to_helpers(sections: &mut HashMap<u8, BankSection>, helpers_bank: u8) {
    let bank0_code = match sections.get(&0) {
        Some(b) => b.asm_code.clone(),
        None => return,
    };

    let mut new_bank0_code = String::new();
    let mut array_data = String::new();
    let mut in_array_block = false;
    let mut pending = String::new();  // accumulate current line being decided

    for line in bank0_code.lines() {
        let trimmed = line.trim();

        if !in_array_block {
            // Detect ARRAY_XXX_DATA: label (start of a const/mutable array ROM block)
            if trimmed.starts_with("ARRAY_") && trimmed.ends_with("DATA:") {
                in_array_block = true;
                pending.push_str(line);
                pending.push('\n');
            } else {
                new_bank0_code.push_str(line);
                new_bank0_code.push('\n');
            }
        } else {
            // Inside array block: collect FCB/FDB data lines
            if trimmed.starts_with("FCB ")
                || trimmed.starts_with("FDB ")
                || trimmed.starts_with(';')
                || trimmed.is_empty()
            {
                pending.push_str(line);
                pending.push('\n');
            } else {
                // Non-data line: flush current block to array_data
                array_data.push_str(&pending);
                pending.clear();
                // If this line itself starts a new array block, start it immediately
                // (rather than sending it to new_bank0_code where it would be missed)
                if trimmed.starts_with("ARRAY_") && trimmed.ends_with("DATA:") {
                    in_array_block = true;
                    pending.push_str(line);
                    pending.push('\n');
                } else {
                    in_array_block = false;
                    new_bank0_code.push_str(line);
                    new_bank0_code.push('\n');
                }
            }
        }
    }
    // Flush any remaining array block
    array_data.push_str(&pending);

    if array_data.is_empty() {
        return;
    }

    eprintln!("[LINKER] Relocating const array data ({} chars) from bank 0 to helpers bank #{}", array_data.len(), helpers_bank);

    // Update bank 0 (strip array data)
    if let Some(b0) = sections.get_mut(&0) {
        b0.asm_code = new_bank0_code;
    }

    // Append array data to helpers bank (always visible at $4000+)
    if let Some(helpers) = sections.get_mut(&helpers_bank) {
        helpers.asm_code.push_str("\n; === CONST ARRAY DATA (relocated to fixed bank - accessible from any bank) ===\n");
        helpers.asm_code.push_str(&array_data);
    }
}

/// Simple label extractor - extracts labels from ASM without full assembly
/// Returns map of label_name -> offset_in_bytes (approximation)
#[allow(dead_code)]
fn extract_labels_from_asm(asm: &str) -> HashMap<String, u16> {
    let mut labels = HashMap::new();
    let mut current_offset = 0u16;
    
    for line in asm.lines() {
        let trimmed = line.trim();
        
        // Skip empty lines and comments
        if trimmed.is_empty() || trimmed.starts_with(';') || trimmed.starts_with('*') {
            continue;
        }
        
        // Skip INCLUDE and EQU directives
        if trimmed.to_uppercase().starts_with("INCLUDE") || trimmed.to_uppercase().contains(" EQU ") {
            continue;
        }
        
        // Parse label (line ends with :)
        if let Some(label_pos) = trimmed.find(':') {
            let label = trimmed[..label_pos].trim().to_string();
            if !label.is_empty() && !label.starts_with(' ') {
                labels.insert(label, current_offset);
            }
        }
        
        // Estimate instruction size (very rough approximation)
        // Most 6809 instructions are 2-4 bytes, data directives vary
        if !trimmed.is_empty() && !trimmed.ends_with(':') {
            // FCB, FDB, FCC directives
            if trimmed.to_uppercase().starts_with("FCB ") {
                current_offset += 1;
            } else if trimmed.to_uppercase().starts_with("FDB ") {
                current_offset += 2;
            } else if trimmed.to_uppercase().starts_with("FCC ") {
                // FCC "string" - count characters
                if let Some(start) = trimmed.find('"') {
                    if let Some(end) = trimmed.rfind('"') {
                        if end > start {
                            let count = end - start - 1;
                            current_offset += count as u16 + 1; // +1 for terminator
                        }
                    }
                }
            } else if !trimmed.starts_with("ORG ") && !trimmed.starts_with("INCLUDE ") {
                // Regular instruction (rough estimate)
                current_offset += 2;
            }
        }
    }
    
    labels
}

/// Represents a single bank section in the ASM
#[derive(Debug, Clone)]
pub struct BankSection {
    pub bank_id: u8,
    pub org: u16,
    pub asm_code: String,
    pub size_estimate: usize,
}

/// Multi-bank linker configuration
#[derive(Debug, Clone)]
pub struct MultiBankLinker {
    pub rom_bank_size: u32,      // 16KB per bank
    pub rom_bank_count: u8,       // 32 banks total
    pub use_native_assembler: bool, // Use vecasm vs lwasm
    pub include_dir: Option<std::path::PathBuf>, // For VECTREX.I loading
}

impl MultiBankLinker {
    pub fn new(rom_bank_size: u32, rom_bank_count: u8, use_native_assembler: bool, include_dir: Option<std::path::PathBuf>) -> Self {
        MultiBankLinker {
            rom_bank_size,
            rom_bank_count,
            use_native_assembler,
            include_dir,
        }
    }
    
    /// Split ASM file into bank sections based on ORG directives
    ///
    /// Input ASM format:
    /// ```asm
    /// ; Common header
    /// 
    /// ; ================================================
    /// ; BANK #31 - 2 function(s)
    /// ; ================================================
    ///     ORG $4000  ; Fixed bank
    /// 
    /// LOOP_BODY:
    ///     ; ... code ...
    /// 
    /// ; ================================================
    /// ; BANK #0 - 13 function(s)
    /// ; ================================================
    ///     ORG $0000  ; Banked window
    /// 
    /// INIT_GAME:
    ///     ; ... code ...
    /// ```
    ///
    /// Returns: HashMap<bank_id, BankSection>
    pub fn split_asm_by_bank(&self, asm_content: &str) -> Result<HashMap<u8, BankSection>, String> {
        // **FIRST PASS**: Collect all definitions (EQU) before processing banks
        // This is necessary because definitions may appear AFTER bank code in the ASM
        let mut definitions = String::new();
        let mut in_defs = false;
        for line in asm_content.lines() {
            // Detect RAM variable definitions section (multiple possible markers)
            if line.contains("=== RAM VARIABLE DEFINITIONS") 
               || line.contains("=== RAM Variables") {
                in_defs = true;
                definitions.push_str(line);
                definitions.push('\n');
                continue;
            }
            if in_defs {
                definitions.push_str(line);
                definitions.push('\n');
                // Stop at empty line or non-EQU line
                if line.trim().is_empty() || (!line.contains("EQU") && !line.starts_with(';')) {
                    in_defs = false;
                }
            }
        }
        
        // Helper: detect start of shared data (arrays/consts) inside a bank block
        let extract_shared_tail = |code: &str| -> Option<String> {
            let markers = [
                "; Array literal for variable",
                "; Const array literal",
                "; Inline array",
                "; CONST ARRAY",
                "; === CONST ARRAY",
            ];

            markers
                .iter()
                .filter_map(|m| code.find(m))
                .min()
                .map(|idx| code[idx..].to_string())
        };
        
        // Helper: extract wrappers section from code
        let extract_wrappers = |code: &str| -> (String, String) {
            let marker = "; ===== CROSS-BANK CALL WRAPPERS =====";
            if let Some(idx) = code.find(marker) {
                let before = code[..idx].to_string();
                let after = code[idx..].to_string();
                (before, after)
            } else {
                (code.to_string(), String::new())
            }
        };

        let mut sections: HashMap<u8, BankSection> = HashMap::new();
        let mut current_bank_id: Option<u8> = None;
        let mut current_org: Option<u16> = None;
        let mut current_code = String::new();
        let mut header = String::new();
        let mut include_directives = String::new(); // INCLUDE directives - needed by ALL banks
        // NOTE: definitions already collected in FIRST PASS above
        let mut runtime_helpers = String::new(); // Runtime helper functions - needed by ALL banks
        let mut shared_tail = String::new(); // Data tail (arrays/consts) from last bank
        let mut data_bank_id: Option<u8> = None; // Bank that originally contained shared_tail
        let mut in_bank_section = false;
        let mut in_definitions = false;
        let mut definitions_ended = false;  // Track when EQU section ends
        let mut post_bank_code = String::new(); // Code AFTER all bank sections (wrappers, etc.)
        let mut header_seen = false; // Track if we've already extracted the header
        let mut skip_until_code_section = false; // Flag to skip header lines until we hit CODE SECTION
        
        for line in asm_content.lines() {
            // Detect Vectrex header: FCC "g GCE 1982" is the marker
            if !header_seen && line.contains("FCC \"g GCE 1982\"") && !in_bank_section {
                // This is the header start - collect it and flag to skip until INCLUDE or other directives
                header.clear();  // Clear any accumulated content from before
                header.push_str(line);
                header.push('\n');
                header_seen = true;
                skip_until_code_section = true;
                continue;
            }
            
            // Collect rest of header lines (FCB $80, FDB, etc. until we hit CODE SECTION or next major directive)
            if header_seen && skip_until_code_section {
                if line.contains("; CODE SECTION") || line.contains("INCLUDE \"") {
                    skip_until_code_section = false;
                    // Process this line normally (it's not part of header)
                } else if line.trim().is_empty() {
                    // Empty line - could be end of header
                    continue;
                } else if line.trim().starts_with(";") && !line.contains("HEADER") && !line.contains("DEFINE") {
                    // Comment line - skip it, it's not part of header
                    continue;
                } else if !line.contains("ORG ") && !line.contains("FCB") && !line.contains("FDB") && !line.contains("FCC ") && !line.trim().starts_with(";") {
                    // Non-header line found, stop collecting
                    skip_until_code_section = false;
                } else {
                    // Part of header (FCB, FDB, FCC directives)
                    header.push_str(line);
                    header.push('\n');
                    continue;
                }
            }
            
            // Collect INCLUDE directives (before bank sections)
            if !in_bank_section {
                let trimmed = line.trim();
                if trimmed.to_uppercase().starts_with("INCLUDE") {
                    include_directives.push_str(line);
                    include_directives.push('\n');
                    continue;
                }
            }
            
            // CRITICAL FIX (2026-01-20): DON'T skip definitions - they need to be in each bank!
            // Each bank assembles independently, so it needs its own copy of RAM variable definitions
            // OLD CODE: collected definitions in FIRST PASS, then skipped them here, then re-prepended in full_code
            // PROBLEM: Re-prepending didn't work because definitions got stripped again in assemble_bank
            // NEW CODE: Keep definitions in current_code so they persist through all processing steps
            
            // Detect start of definitions section
            if line.contains("=== RAM VARIABLE DEFINITIONS") 
               || line.contains("=== RAM Variables") {
                in_definitions = true;
                // ADD to current_code instead of skip
                current_code.push_str(line);
                current_code.push('\n');
                continue;
            }
            
            // Process EQU definitions - ADD them to current_code
            if in_definitions {
                current_code.push_str(line);
                current_code.push('\n');
                // Stop at empty line or non-EQU line
                if line.trim().is_empty() || (!line.contains("EQU") && !line.starts_with(';')) {
                    in_definitions = false;
                    definitions_ended = true;
                }
                continue;
            }
            

            // Detect bank header: "; BANK #N - M function(s)"
            if line.starts_with("; BANK #") {
                // If we're coming from a bank section, save it first
                // NOTE: Don't add runtime_helpers here - they'll be added later at the end
                if in_bank_section {
                    if let (Some(bank_id), Some(org)) = (current_bank_id, current_org) {
                        // For Bank #0: prepend header (FCC/FCB directives), then INCLUDE, then definitions
                        // For other banks: prepend INCLUDE + definitions only
                        let full_code = if bank_id == 0 {
                            format!("{}\n{}\n{}\n{}", header, include_directives, definitions, current_code)
                        } else {
                            format!("{}\n{}\n{}", include_directives, definitions, current_code)
                        };
                        sections.insert(bank_id, BankSection {
                            bank_id,
                            org,
                            asm_code: full_code,
                            size_estimate: current_code.len(),
                        });
                    }
                }
                
                // Parse new bank ID
                let parts: Vec<&str> = line.split_whitespace().collect();
                if parts.len() >= 3 {
                    let bank_str = parts[2].trim_matches(|c| c == '#' || c == ' ' || c == '-');
                    if let Ok(bank_id) = bank_str.parse::<u8>() {
                        // If we already have this bank ID (e.g., started accumulating for bank #0),
                        // DON'T clear current_code - continue accumulating
                        if current_bank_id != Some(bank_id) {
                            current_bank_id = Some(bank_id);
                            current_code.clear();
                        }
                        in_bank_section = true;
                        post_bank_code.clear();  // Reset post-bank code when entering new bank
                        continue;
                    }
                }
            }
            
            // Detect ORG directive
            if line.trim().starts_with("ORG ") && in_bank_section {
                let parts: Vec<&str> = line.split_whitespace().collect();
                if parts.len() >= 2 {
                    let org_str = parts[1].trim_start_matches('$');
                    if let Ok(org) = u16::from_str_radix(org_str, 16) {
                        current_org = Some(org);
                        current_code.push_str(line);
                        current_code.push('\n');
                        continue;
                    }
                }
            }
            
            // Detect end of bank sections: wrappers section or other post-bank code
            // This allows us to exit in_bank_section when we encounter these markers
            // CRITICAL FIX (2026-01-17): Do NOT exit in_bank_section for visual separator lines
            // like "; ================================================" which appear around BANK markers.
            // Only exit for actual wrapper section markers like "; ===== CROSS-BANK CALL WRAPPERS ====="
            let is_visual_separator = line.starts_with("; =====") && line.chars().all(|c| c == ';' || c == ' ' || c == '=');
            if in_bank_section && line.starts_with("; ===== ") && !is_visual_separator {
                // Save current bank before exiting in_bank_section
                // But DO NOT clear current_bank_id/org - let EOF handler save it properly
                in_bank_section = false;
                
                // Now accumulate this line and remaining lines in post_bank_code
                post_bank_code.push_str(line);
                post_bank_code.push('\n');
                continue;
            }
            
            // Accumulate code
            if in_bank_section {
                current_code.push_str(line);
                current_code.push('\n');
            } else if definitions_ended {
                // Sequential Model: After definitions, BEFORE first bank - this is HEADER (START/MAIN)
                // AFTER all banks - this is runtime helpers (wrappers, etc.)
                // We distinguish by checking if we've seen at least one bank section
                if sections.is_empty() {
                    // No banks seen yet - this could be header BUT in multibank mode,
                    // the header (including START) should be INSIDE Bank #0 code, NOT extracted.
                    // Start accumulating for bank #0 NOW (before seeing "BANK #0" marker)
                    if !in_bank_section {
                        in_bank_section = true;
                        current_bank_id = Some(0);
                        current_org = Some(0x0000);
                    }
                    current_code.push_str(line);
                    current_code.push('\n');
                } else {
                    // Banks already processed - this is runtime helpers
                    post_bank_code.push_str(line);
                    post_bank_code.push('\n');
                }
            } else {
                // Before definitions - this is REAL header (includes, FCC, FCB directives)
                // Extract this to header variable
                header.push_str(line);
                header.push('\n');
            }
        }
        
        // ===== FINALIZE RUNTIME HELPERS =====
        // Merge post_bank_code (wrappers and other helpers after banks)
        // BUT EXCLUDE ASSETS - assets must stay in their original bank, NOT in helpers bank
        let asset_markers = [
            "; EMBEDDED ASSETS",
            "; Generated from",
            "_VECTORS:",
            "_MUSIC:",
            "_SFX:",
            "_LEVEL:",
            "_PATH0:",
            "_PATH1:",
        ];
        let post_bank_code_without_assets = {
            let cut_pos = asset_markers.iter()
                .filter_map(|m| post_bank_code.find(m))
                .min()
                .unwrap_or(post_bank_code.len());
            post_bank_code[..cut_pos].to_string()
        };
        runtime_helpers.push_str(&post_bank_code_without_assets);
        
        // Also extract wrappers from current_code if they're there (in case marker detection didn't split them)
        let (bank_code_only, extracted_wrappers) = extract_wrappers(&current_code);
        if !extracted_wrappers.is_empty() {
            // Filter assets from extracted_wrappers too
            let wrappers_cut_pos = asset_markers.iter()
                .filter_map(|m| extracted_wrappers.find(m))
                .min()
                .unwrap_or(extracted_wrappers.len());
            let wrappers_without_assets = &extracted_wrappers[..wrappers_cut_pos];
            runtime_helpers.push_str(wrappers_without_assets);
        }
        
        // ===== SAVE LAST BANK WITH RUNTIME HELPERS =====
        if let (Some(bank_id), Some(org)) = (current_bank_id, current_org) {
            // Capture shared tail (arrays/consts) from bank_code_only
            if let Some(tail) = extract_shared_tail(&bank_code_only) {
                shared_tail = tail;
                data_bank_id = Some(bank_id);
            }
            
            // CRITICAL: Extract ORG directive from bank_code_only if present, and place it at the TOP
            let (org_line, code_without_org) = if bank_code_only.trim_start().starts_with("ORG ") {
                let first_newline = bank_code_only.find('\n').unwrap_or(bank_code_only.len());
                let org_part = bank_code_only[..first_newline].to_string();
                let code_part = if first_newline < bank_code_only.len() {
                    bank_code_only[first_newline+1..].to_string()
                } else {
                    String::new()
                };
                (format!("{}\n", org_part), code_part)
            } else {
                (String::new(), bank_code_only.clone())
            };
            
            // CRITICAL FIX (2026-01-17): Remove ALL ORG directives from all content sections
            // The code may have multiple ORG directives (from extracted sections), but we only want ONE at the top
            
            // Reconstruct with ORG at the very beginning (before INCLUDE/definitions)
            // This ensures PC starts at correct address for this bank
            // Bank #31 (fixed window) uses $4000, all others use $0000
            // CRITICAL: For Bank #31, CUSTOM_RESET must come IMMEDIATELY after ORG, before helpers
            
            // Extract CUSTOM_RESET if present in helpers bank (must be first instruction)
            let helpers_bank = (self.rom_bank_count - 1) as u8;
            let (custom_reset_code, remaining_code) = if bank_id == helpers_bank {
                // Look for CUSTOM_RESET: label in code_without_org
                if let Some(pos) = code_without_org.find("CUSTOM_RESET:") {
                    // Find the end of CUSTOM_RESET function (next label or empty line group)
                    let rest = &code_without_org[pos..];
                    let mut end_pos = rest.find("\n\n").unwrap_or(rest.len());
                    // Make sure we include the final instruction line
                    if end_pos < rest.len() {
                        if let Some(final_line_end) = rest[end_pos+2..].find('\n') {
                            end_pos = end_pos + 2 + final_line_end;
                        }
                    }
                    let custom_reset = rest[..=end_pos].to_string();
                    let remaining = format!("{}{}", &code_without_org[..pos], &rest[end_pos+1..]);
                    (custom_reset, remaining)
                } else {
                    ("".to_string(), code_without_org.clone())
                }
            } else {
                ("".to_string(), code_without_org.clone())
            };
            
            // CRITICAL FIX (2026-01-17): Remove ALL ORG directives from content sections
            // Multiple ORG directives cause assembler scope conflicts - we only want ONE at the top
            let clean_runtime_helpers = runtime_helpers
                .lines()
                .filter(|line| !line.trim().starts_with("ORG "))
                .collect::<Vec<_>>()
                .join("\n");
            
            let clean_remaining_code = remaining_code
                .lines()
                .filter(|line| !line.trim().starts_with("ORG "))
                .collect::<Vec<_>>()
                .join("\n");
                
            let clean_code_without_org = code_without_org
                .lines()
                .filter(|line| !line.trim().starts_with("ORG "))
                .collect::<Vec<_>>()
                .join("\n");
            
            let full_code = if org_line.is_empty() {  // CRITICAL FIX (2026-01-17): Bank #0 also needs ORG directive
                let org_directive = if bank_id == helpers_bank {
                    "    ORG $4000  ; Fixed bank window (runtime helpers + interrupt vectors)\n".to_string()
                } else {
                    "    ORG $0000\n".to_string()
                };
                // For helpers bank: ORG → CUSTOM_RESET → includes/defs → helpers → remaining code
                if bank_id == helpers_bank {
                    format!("{}{}\n{}\n{}\n{}\n{}", org_directive, custom_reset_code, include_directives, definitions, clean_runtime_helpers, clean_remaining_code)
                } else {
                    format!("{}{}\n{}\n{}", org_directive, include_directives, definitions, clean_code_without_org)
                }
            } else {
                if bank_id == helpers_bank {
                    format!("{}{}\n{}\n{}\n{}\n{}", org_line, custom_reset_code, include_directives, definitions, clean_runtime_helpers, clean_remaining_code)
                } else {
                    format!("{}{}\n{}\n{}", org_line, include_directives, definitions, clean_code_without_org)
                }
            };
            let size = full_code.len();
            sections.insert(bank_id, BankSection {
                bank_id,
                org,
                asm_code: full_code,
                size_estimate: size,
            });
        }
        
        // ===== ADD RUNTIME HELPERS TO HELPERS BANK ONLY =====
        // Runtime helpers (wrappers, math functions, etc.) belong in helpers bank (fixed ROM)
        // They should NOT be duplicated in user banks
        // Helpers bank is always visible and accessible from any bank via wrappers
        let helpers_bank = (self.rom_bank_count - 1) as u8;
        if !runtime_helpers.is_empty() {
            if let Some(bank_helpers) = sections.get_mut(&helpers_bank) {
                // Add helpers to helpers bank if not already present
                if !bank_helpers.asm_code.contains("; ===== CROSS-BANK CALL WRAPPERS =====") {
                    // Insert runtime_helpers AFTER definitions, BEFORE bank code
                    // Find where the bank code starts (look for first ORG directive)
                    let lines: Vec<&str> = bank_helpers.asm_code.lines().collect();
                    let mut new_code = String::new();
                    let mut org_found = false;
                    
                    for line in lines {
                        if !org_found && line.trim().starts_with("ORG ") {
                            // Insert runtime_helpers BEFORE ORG
                            new_code.push_str(&runtime_helpers);
                            new_code.push('\n');
                            org_found = true;
                        }
                        new_code.push_str(line);
                        new_code.push('\n');
                    }
                    
                    bank_helpers.asm_code = new_code;
                    bank_helpers.size_estimate = bank_helpers.asm_code.len();
                }
            }
        }
        // Sequential Model (2025-01-12): Header belongs to FIRST bank (Bank #0)
        // The header contains Vectrex magic bytes, START, MAIN, strings, constants
        // All must be in Bank #0 (the boot bank in sequential model)
        // Insert header at the BEGINNING of first bank's code (before ORG directive)
        if !header.is_empty() {
            let first_bank = 0u8;  // Bank #0 is the first/primary bank
            if let Some(bank0) = sections.get_mut(&first_bank) {
                // Bank #0's asm_code has: [INCLUDE] + [definitions] + [runtime_helpers] + [bank code with ORG]
                // We need to insert header BEFORE the ORG line
                let lines: Vec<&str> = bank0.asm_code.lines().collect();
                let mut new_code = String::new();
                let mut org_found = false;
                
                for line in lines {
                    if !org_found && line.trim().starts_with("ORG") {
                        // Insert header BEFORE ORG directive
                        new_code.push_str(&header);
                        new_code.push('\n');
                        org_found = true;
                    }
                    new_code.push_str(line);
                    new_code.push('\n');
                }
                
                bank0.asm_code = new_code;
                bank0.size_estimate += header.len();
            } else {
                // No first bank section found - create one with header
                let full_code = format!("{}\n{}\n{}\n{}\n        ORG $0000\n", 
                    include_directives,
                    definitions,
                    runtime_helpers,
                    header
                );
                let size = full_code.len();
                sections.insert(first_bank, BankSection {
                    bank_id: first_bank,
                    org: 0x0000,
                    asm_code: full_code,
                    size_estimate: size,
                });
            }
        }

        // Propagate shared tail (arrays/consts) to all banks EXCEPT helpers bank (fixed bank)
        // Helpers bank should have its own copy of assets at its own offset
        // Assets should NOT be duplicated across banks - each bank gets its data once
        if !shared_tail.is_empty() {
            let fixed_bank_id = helpers_bank;  // Helpers bank (last)
            for (bank_id, section) in sections.iter_mut() {
                // Skip the bank that already contains the shared tail (data_bank_id)
                // AND skip bank #31 (fixed bank, should keep its assets)
                if Some(*bank_id) != data_bank_id && *bank_id != fixed_bank_id {
                    section.asm_code.push_str("\n");
                    section.asm_code.push_str(&shared_tail);
                    section.size_estimate = section.asm_code.len();
                }
            }
        }
        
        // Assets are in both bank_0 and helpers bank at the same offsets due to global codegen
        // We ensure helpers bank versions are preferred by skipping asset symbols from other banks during extraction
        // (This is handled in the symbol extraction loop above)

        // Add interrupt vectors to last bank (fixed bank)
        // NOTE: Vectors are added in generate_multibank_rom after binary assembly, not here
        // This ensures they're placed at the correct ROM offset without ORG conflicts

        Ok(sections)
    }
    
    /// Assemble a single bank section to binary
    ///
    /// Creates temporary ASM file with:
    /// - Common header (from pseudo-bank 255)
    /// - Bank-specific ORG and code
    /// - External symbols from fixed bank (if not fixed bank itself)
    /// - Assembles with vecasm or lwasm
    ///
    /// Returns: Binary data (padded to bank size)
    pub fn assemble_bank(
        &self,
        bank_section: &BankSection,
        temp_dir: &Path,
        helper_symbols: &HashMap<String, u16>,
    ) -> Result<Vec<u8>, String> {
        // Bank ASM already contains everything
        let mut full_asm = bank_section.asm_code.clone();
        
        // CRITICAL FIX (2026-01-14): Bank #31 must use ORG $4000, not $0000
        // The fixed bank window is at 0x4000-0x7FFF in the CPU address space
        // split_asm_by_bank extracts Bank #31 with ORG $0000 from the backend,
        // but assemble_bank must override it to $4000 for correct symbol resolution
        let helper_bank_id = (self.rom_bank_count - 1) as u8;
        if bank_section.bank_id as u8 == helper_bank_id {
            // Replace ORG $0000 with ORG $4000 for Bank #31
            full_asm = full_asm.replace(
                "ORG $0000  ; Fixed bank (no VPy functions, only runtime)",
                "ORG $4000  ; Fixed bank window (runtime helpers + interrupt vectors)"
            );
        }
        
        // Prepend external symbol definitions from helper bank and shared data
        // This is needed for all banks to reference symbols from helpers and arrays/consts
        if !helper_symbols.is_empty() {
            // Collect locally-defined labels so we don't shadow them with injected EQUs
            let local_labels: HashSet<String> = full_asm.lines()
                .filter_map(|line| {
                    let t = line.trim();
                    if t.is_empty() || t.starts_with(';') || t.contains(" EQU ") { return None; }
                    if let Some(pos) = t.find(':') {
                        let label = t[..pos].trim();
                        if !label.is_empty() && !label.contains(' ') && !label.starts_with('.') {
                            return Some(label.to_string());
                        }
                    }
                    None
                })
                .collect();

            let mut external_symbols = String::from("; External symbols (helpers, BIOS, and shared data)\n");
            for (symbol, address) in helper_symbols {
                if local_labels.contains(symbol) { continue; }
                external_symbols.push_str(&format!("{} EQU ${:04X}\n", symbol, address));
            }
            external_symbols.push_str("\n");
            
            // Insert after INCLUDE directive if present, otherwise prepend to ASM
            let lines: Vec<&str> = full_asm.lines().collect();
            let mut new_asm = String::new();
            let mut include_found = false;
            
            for line in lines {
                new_asm.push_str(line);
                new_asm.push('\n');
                
                if !include_found && line.trim().to_uppercase().starts_with("INCLUDE") {
                    new_asm.push_str(&external_symbols);
                    include_found = true;
                }
            }
            
            // If no INCLUDE directive found, prepend symbols before ORG
            if !include_found {
                let mut final_asm = external_symbols;
                final_asm.push_str(&new_asm);
                new_asm = final_asm;
            }
            
            full_asm = new_asm;
        }
        
        // Ensure each bank ASM has an explicit ORG before writing/assembling
        let full_asm_owned = if !full_asm.contains("ORG ") {
            let org_prefix = if bank_section.bank_id as u8 == helper_bank_id { "ORG $4000\n" } else { "ORG $0000\n" };
            let mut with_org = String::new();
            with_org.push_str(org_prefix);
            with_org.push_str(&full_asm);
            with_org
        } else {
            full_asm.to_string()
        };

        let full_asm = &full_asm_owned;
        
        // CRITICAL: For multi-bank, convert all short branches to long branches in helpers
        // This is needed because DIV16, MUL16, etc. have branches that exceed ±127 bytes
        // in banks beyond #0. The assembler cannot emit long branches based on final
        // offsets (they're not known yet), so we convert at codegen time.
        let full_asm_longbranch = convert_short_to_long_branches(full_asm);
        
        // DEBUG: Write ASM snapshots to temp files for inspection
        // - bank_XX_full.asm : full content (includes headers/external symbols)
        // - bank_XX.asm      : trimmed view (only bank code; headers removed)
        {
            use std::fs::File;
            use std::io::Write;

            // Full snapshot (unchanged)
            let temp_full_path = temp_dir.join(format!("bank_{:02}_full.asm", bank_section.bank_id));
            if let Ok(mut file) = File::create(&temp_full_path) {
                let _ = file.write_all(full_asm_longbranch.as_bytes());
            }

            // Trimmed snapshot for readability (drop repeated headers/INCLUDE/externals for banks 0-30)
            let _trimmed_asm = if bank_section.bank_id as u8 == helper_bank_id {
                full_asm_longbranch.clone()
            } else {
                // Keep first ORG; then keep from CODE SECTION onwards, skipping INCLUDE/external EQU block for readability
                let mut org_line: Option<String> = None;
                let mut trimmed_body = Vec::new();
                let mut in_code = false;

                for line in full_asm_longbranch.lines() {
                    let trimmed = line.trim_start();
                    let upper = trimmed.to_uppercase();

                    if org_line.is_none() && upper.starts_with("ORG ") {
                        org_line = Some(line.to_string());
                        continue;
                    }

                    if !in_code {
                        if upper.contains("; CODE SECTION") {
                            in_code = true;
                            trimmed_body.push(line.to_string());
                        }
                        continue;
                    }

                    // Skip boilerplate/definitions for readability even after body starts
                    if trimmed.is_empty() {
                        continue;
                    }
                    if upper.starts_with("INCLUDE") {
                        continue;
                    }
                    if upper.starts_with("; EXTERNAL SYMBOLS") {
                        continue;
                    }
                    // CRITICAL FIX (2026-01-20): DON'T skip EQU lines - each bank needs them!
                    // Each bank assembles independently, so RAM variable definitions must be present
                    // Original code had: if second == "EQU" { continue; } which broke multibank builds
                    // Solution: Keep EQU lines in each bank's ASM

                    trimmed_body.push(line.to_string());
                }

                let mut out = String::new();
                if let Some(org) = org_line.clone() {
                    out.push_str(&org);
                    out.push('\n');
                }

                if trimmed_body.is_empty() {
                    // Fallback: no CODE SECTION marker (common in small banks). Do a light filter:
                    let mut fallback = Vec::new();
                    let mut saw_body = false;
                    for line in full_asm_longbranch.lines() {
                        let trimmed = line.trim_start();
                        let upper = trimmed.to_uppercase();

                        if upper.starts_with("ORG ") {
                            continue; // already emitted
                        }
                        if trimmed.is_empty() {
                            continue;
                        }
                        if upper.starts_with("INCLUDE") {
                            continue;
                        }
                        if upper.starts_with("; EXTERNAL SYMBOLS") {
                            continue;
                        }
                        // CRITICAL FIX (2026-01-20): DON'T skip EQU lines - each bank needs them!
                        // Each bank assembles independently, so RAM variable definitions must be present
                        // Original code had: if second == "EQU" { continue; } which broke multibank builds
                        // Solution: Keep EQU lines in each bank's ASM
                        saw_body = true;
                        fallback.push(line.to_string());
                    }

                    if saw_body {
                        out.push_str(&fallback.join("\n"));
                        out.push('\n');
                    } else {
                        out.push_str(&full_asm_longbranch);
                    }
                } else {
                    out.push_str(&trimmed_body.join("\n"));
                    out.push('\n');
                }
                out
            };

            let temp_trimmed_path = temp_dir.join(format!("bank_{:02}.asm", bank_section.bank_id));
            // CRITICAL FIX (2026-01-20): Use full_asm_longbranch directly - it already has definitions!
            // DON'T write trimmed (which filters out EQU lines)
            if let Err(e) = fs::write(&temp_trimmed_path, &full_asm_longbranch) {
                eprintln!("     [WARN] Failed to write bank ASM: {}", e);
            }
        }
        
        // CRITICAL: Assemble with correct ORG per bank
        // Bank #0-30: ORG $0000 (switchable window - physical ROM offset bank_id * 16KB)
        // Bank #31: ORG $4000 (fixed window - physical ROM offset 0x7C000, but CPU sees 0x4000)
        // Symbol addresses are relative to the ORG in their bank
        let helper_bank_id = (self.rom_bank_count - 1) as u8;
        let bank_org = if bank_section.bank_id as u8 == helper_bank_id {
            0x4000u16  // Fixed bank window
        } else {
            0x0000u16  // Switchable bank window
        };
        
        // DEBUG: Check for multiple ORG directives (should only be ONE)
        let org_count = full_asm_longbranch.matches("ORG $").count();
        
        let _ = org_count; // suppress unused variable warning
        
        let (binary, _line_map, _symbol_table, _unresolved) = vpy_assembler::m6809::asm_to_binary::assemble_m6809(
            &full_asm_longbranch,
            bank_org,  // Use correct ORG based on bank type
            false,   // Not object mode
            false    // Don't auto-convert (we already did it above)
        ).map_err(|e| format!("Failed to assemble bank {}: {}", bank_section.bank_id, e))?;

        
        // Get binary data (already Vec<u8>, no .0 field)
        let mut binary_data = binary;
        
        // Pad to bank size (16KB)
        let bank_size = self.rom_bank_size as usize;
        if binary_data.len() > bank_size {
            return Err(format!("Bank {} overflow: {} bytes (max: {} bytes)", 
                bank_section.bank_id, binary_data.len(), bank_size));
        }
        
        // Pad with 0xFF (standard for unused ROM)
        binary_data.resize(bank_size, 0xFF);
        
        Ok(binary_data)
    }
    
    /// Generate multi-bank ROM from sectioned ASM
    ///
    /// Process:
    /// 1. Split ASM by bank sections
    /// 2. Extract symbols from fixed bank (Bank #31)
    /// 3. Assemble each bank separately (with external symbols if needed)
    /// 4. Concatenate in order (0, 1, ..., 31)
    /// 5. Write to output ROM file
    ///
    /// Output: 512KB ROM file with 32 banks
    /// Returns: Symbol table (name → address) on success for PDB generation
    pub fn generate_multibank_rom(
        &self,
        asm_path: &Path,
        output_rom_path: &Path,
    ) -> Result<HashMap<String, u16>, String> {
        // Read ASM
        let asm_content = fs::read_to_string(asm_path)
            .map_err(|e| format!("Failed to read ASM from {:?}: {}", asm_path, e))?;
        
        // Split by bank
        let mut sections = self.split_asm_by_bank(&asm_content)?;

        // Generate cross-bank trampolines for user functions split across switchable banks.
        // Must happen BEFORE multi-pass assembly so the patched JSRs and trampoline labels
        // are present when symbols are collected.
        let helper_bank_id_for_tramp = (self.rom_bank_count - 1) as u8;
        let trampolines = generate_cross_bank_trampolines(&mut sections, helper_bank_id_for_tramp);
        if !trampolines.is_empty() {
            if let Some(helpers) = sections.get_mut(&helper_bank_id_for_tramp) {
                helpers.asm_code.push_str("\n; === CROSS-BANK USER FUNCTION TRAMPOLINES ===\n");
                helpers.asm_code.push_str(&trampolines);
            }
        }

        // Relocate const array ROM data from bank 0 to helpers bank so it's always accessible.
        // Functions split to banks 1-2 need array data at fixed addresses ($4000+).
        if sections.len() > 2 {
            relocate_array_data_to_helpers(&mut sections, helper_bank_id_for_tramp);
        }

        // **PASS 1**: Iteratively extract global symbol table from all banks
        // This allows cross-bank references (e.g., CUSTOM_RESET referencing START)
        // We do this iteratively because some symbols may depend on others being defined first.
        let mut all_symbols = HashMap::new();
        let helper_bank_id = (self.rom_bank_count - 1) as u8;
        let max_iterations = 5;
        
        // Load BIOS symbols from shared function (same as single-bank)
        // This ensures multibank and single-bank use identical BIOS addresses
        use vpy_assembler::m6809::asm_to_binary::{load_vectrex_symbols, set_include_dir};
        
        // Set include_dir BEFORE loading symbols to ensure VECTREX.I is found
        if let Some(ref dir) = self.include_dir {
            set_include_dir(Some(dir.clone()));
        }
        
        let mut bios_equates = std::collections::HashMap::new();
        load_vectrex_symbols(&mut bios_equates);
        
        // Insert BIOS symbols into all_symbols
        for (name, addr) in bios_equates.iter() {
            all_symbols.insert(name.clone(), *addr);
        }
        
        // Also define a placeholder for START - will be overwritten if found in actual code
        if !all_symbols.contains_key("START") {
            all_symbols.insert("START".to_string(), 0x0022u16);  // Placeholder from single-bank .bin
        }
        
        for iteration in 0..max_iterations {
            let prev_count = all_symbols.len();
            
            // CRITICAL FIX (2026-01-20): Process Banks #0-#30 FIRST, then Bank #31 LAST
            // Reason: Bank #31 contains ASSET_ADDR_TABLE which references assets in Banks #1-#30
            // We need those asset symbols defined BEFORE we can assemble Bank #31
            let banks_first_order: Vec<u8> = {
                let mut order = Vec::new();
                // First: Banks #0-#30 (code + assets - these define the asset symbols)
                for id in 0..self.rom_bank_count {
                    if id != helper_bank_id {
                        order.push(id);
                    }
                }
                // Last: Bank #31 (helpers + lookup tables - these REFERENCE asset symbols)
                order.push(helper_bank_id);
                order
            };
            
            for bank_id in banks_first_order {
                if let Some(section) = sections.get(&bank_id) {
                    let mut bank_asm = convert_short_to_long_branches(&section.asm_code);
                    
                    // Inject previously found symbols into this bank's ASM
                    if !all_symbols.is_empty() {
                        // Collect labels locally defined in this bank's code (to avoid overriding them with EQUs)
                        let local_labels: HashSet<String> = bank_asm.lines()
                            .filter_map(|line| {
                                let t = line.trim();
                                if t.is_empty() || t.starts_with(';') || t.contains(" EQU ") { return None; }
                                if let Some(pos) = t.find(':') {
                                    let label = t[..pos].trim();
                                    if !label.is_empty() && !label.contains(' ') && !label.starts_with('.') {
                                        return Some(label.to_string());
                                    }
                                }
                                None
                            })
                            .collect();

                        let mut external_symbols = String::from("; External symbols (cross-bank references and BIOS)\n");
                        for (symbol, address) in &all_symbols {
                            // Skip symbols defined locally in this bank — injecting an EQU would shadow the real label
                            if local_labels.contains(symbol) { continue; }
                            external_symbols.push_str(&format!("{} EQU ${:04X}\n", symbol, address));
                        }
                        external_symbols.push_str("\n");
                        
                        // Insert after INCLUDE directive or at start if no INCLUDE
                        let lines: Vec<&str> = bank_asm.lines().collect();
                        let mut new_asm = String::new();
                        let mut include_found = false;
                        
                        for line in lines {
                            if !include_found && line.trim().to_uppercase().starts_with("INCLUDE") {
                                new_asm.push_str(line);
                                new_asm.push('\n');
                                new_asm.push_str(&external_symbols);
                                include_found = true;
                            } else {
                                new_asm.push_str(line);
                                new_asm.push('\n');
                            }
                        }
                        
                        if !include_found {
                            // No INCLUDE found, prepend at start
                            bank_asm = format!("{}\n{}", external_symbols, new_asm);
                        } else {
                            bank_asm = new_asm;
                        }
                    }
                    
                    // Try to assemble with available symbols.
                    // Use object_mode=true so banks can contribute their defined labels
                    // even when some external symbols are still unresolved (deadlock prevention).
                    match vpy_assembler::m6809::asm_to_binary::assemble_m6809(&bank_asm, 0x0000, true, false) {
                        Ok((_, _, symbol_table, _)) => {
                            
                            // Calculate runtime address for each symbol based on bank
                            // CRITICAL FIX (2026-01-18): Symbol addresses from assembler already include ORG
                            // For Bank #31 (ORG $4000), addresses are already absolute ($4000+offset)
                            // For other banks (ORG $0000), addresses are already relative ($0000+offset)
                            // So we DON'T add bank_base - the addresses are already correct!
                            
                            for (label, addr) in symbol_table {
                                let runtime_addr = addr;  // Use address as-is (ORG already included)

                                // Symbol merge rules:
                                // - New symbol (not yet seen): always add
                                // - Helpers bank with non-zero addr: update (helpers knows its own symbols; ORG=$4000 so real symbols are ≥$4000)
                                // - Helpers bank with addr=$0000: SKIP — this is an object_mode unresolved placeholder, not a real definition
                                // - Other banks: first-come-first-served (don't override already-resolved symbols)
                                if !all_symbols.contains_key(&label) {
                                    all_symbols.insert(label, runtime_addr);
                                } else if bank_id as u8 == helper_bank_id && runtime_addr != 0 {
                                    all_symbols.insert(label, runtime_addr);
                                }
                            }
                        }
                        Err(e) => {
                            // Bank failed to assemble - this is expected for cross-bank references
                            // Continue with other banks to collect their symbols
                            // We'll retry this bank in the next iteration with more symbols available
                            if iteration < max_iterations - 1 {
                                // Extract the symbol name from error "Undefined symbol: SYMBOLNAME"
                                let missing_symbol = if e.contains(": ") {
                                    e.split(": ").last().unwrap_or("unknown")
                                } else {
                                    "unknown"
                                };
                                let _ = missing_symbol; // suppress unused variable
                                // Continue - don't fail yet, more iterations may resolve this
                            } else {
                                // Final iteration - this is a real error
                                eprintln!("       ❌ FATAL: Bank #{} assembly failed in final PASS 1 iteration", bank_id);
                                eprintln!("          Error: {}", e);
                                eprintln!("          This usually indicates:");
                                eprintln!("            - Cross-bank symbol references still unresolved");
                                eprintln!("            - Missing external symbol definitions");
                                eprintln!("            - Syntax errors in generated ASM");
                                eprintln!("\n          Multibank build cannot proceed - symbol table incomplete.");
                                return Err(format!("Bank #{} assembly failed in PASS 1: {}", bank_id, e));
                            }
                        }
                    }
                }
            }
            
            let new_count = all_symbols.len();
            
            // If no new symbols found, we've converged
            if new_count == prev_count {
                break;
            }
        }
        
        // CRITICAL: START symbol MUST exist - it's the entry point
        if !all_symbols.contains_key("START") {
            eprintln!("       ❌ FATAL: Symbol START not found in symbol table");
            eprintln!("          START is the program entry point - multibank build cannot proceed.");
            return Err("Symbol START not found - cannot generate multibank ROM".to_string());
        }

        // **PASS 2**: Assemble helper bank with all symbols available
        let helper_section = sections.get(&helper_bank_id)
            .ok_or_else(|| format!("Helper bank #{} not found in ASM sections", helper_bank_id))?;

        // Inject all extracted symbols into helper bank ASM
        let mut helper_asm_with_symbols = String::new();
        for (symbol, address) in &all_symbols {
            helper_asm_with_symbols.push_str(&format!("{} EQU ${:04X}\n", symbol, address));
        }
        helper_asm_with_symbols.push_str("\n");
        helper_asm_with_symbols.push_str(&helper_section.asm_code);

        let helper_full_asm_longbranch = convert_short_to_long_branches(&helper_asm_with_symbols);
        // CRITICAL FIX (2026-01-14): Helper bank uses fixed window at 0x4000, not 0x0000
        let helpers_bank = (self.rom_bank_count - 1) as u8;
        let helper_org = if helper_bank_id == helpers_bank {
            0x4000u16
        } else {
            0x0000u16
        };
        let (mut helper_binary, _helper_line_map, _helper_symbol_table, _helper_unresolved) = vpy_assembler::m6809::asm_to_binary::assemble_m6809(
            &helper_full_asm_longbranch,
            helper_org,
            false,
            false,
        ).map_err(|e| format!("Failed to assemble helper bank {}: {}", helper_bank_id, e))?;

        // Pad helper bank to full size
        let bank_size = self.rom_bank_size as usize;
        if helper_binary.len() > bank_size {
            return Err(format!("Helper bank {} overflow: {} bytes (max: {} bytes)", helper_bank_id, helper_binary.len(), bank_size));
        }
        helper_binary.resize(bank_size, 0xFF);

        // Use the global symbol table extracted from all banks
        
        // Create temp directory for bank assemblies
        let temp_dir = output_rom_path.parent()
            .ok_or("Invalid output path")?
            .join("multibank_temp");
        fs::create_dir_all(&temp_dir)
            .map_err(|e| format!("Failed to create temp dir: {}", e))?;

        // DEBUG: Emit a flattened ASM view (one file, all banks) for inspection.
        // This is a source-of-truth snapshot showing exactly what each bank assembles.
        let flattened_path = temp_dir.join("multibank_flat.asm");
        let mut flattened = String::new();
        flattened.push_str("; AUTO-GENERATED FLATTENED MULTIBANK ASM\n");
        flattened.push_str(&format!("; Banks: {} | Bank size: {} bytes | Total: {} bytes\n\n", self.rom_bank_count, self.rom_bank_size, self.rom_bank_size as usize * self.rom_bank_count as usize));
        
        // STRUCTURE (2026-01-14): ORG $0000 FIRST, then DEFINE SECTION
        // Establishes program counter before including symbols
        flattened.push_str("ORG $0000\n\n");
        flattened.push_str(";***************************************************************************\n");
        flattened.push_str("; DEFINE SECTION\n");
        flattened.push_str(";***************************************************************************\n");
        flattened.push_str("    INCLUDE \"VECTREX.I\"\n\n");

        // Remove duplicated INCLUDE + RAM EQU + RUNTIME blocks in flattened view
        // DEFINE SECTION is emitted ONCE at the top (global)
        // Each bank emits only its code (no INCLUDE, no global EQU, no RUNTIME)
        let strip_for_flatten = |bank_id: u8, code: &str| -> String {
            // ALL banks strip INCLUDE (emitted globally at top)
            // ALL banks strip RUNTIME SECTION (except Bank #31 which needs it)
            // Bank #0 additionally strips RAM EQU (to be emitted after header)
            let mut out = String::new();
            let mut in_equ_section = false;
            let mut in_runtime_section = false;
            for line in code.lines() {
                let trimmed = line.trim_start();
                let upper = trimmed.to_uppercase();
                
                // Skip INCLUDE directives (all banks, emitted globally)
                if upper.starts_with("INCLUDE") {
                    continue;
                }
                
                // Skip external symbol declarations header
                if upper.starts_with("; EXTERNAL SYMBOLS") {
                    continue;
                }
                
                // Mark start of RUNTIME SECTION (skip for all banks except #31)
                if upper.contains("RUNTIME SECTION") {
                    in_runtime_section = true;
                    if bank_id != 31 {
                        continue; // Skip for non-Bank#31
                    }
                }
                
                // Skip entire RUNTIME SECTION for non-Bank#31
                if in_runtime_section && bank_id != 31 {
                    // Keep skipping until DATA SECTION or end of file
                    if upper.contains("DATA SECTION") {
                        in_runtime_section = false;
                    }
                    continue;
                }
                
                // Mark start of EQU section (skip for Bank #0 during multibank)
                if upper.contains("=== RAM VARIABLE DEFINITIONS") {
                    in_equ_section = true;
                    continue;
                }
                
                // Skip blank/comment lines in EQU section
                if in_equ_section && (trimmed.is_empty() || trimmed.starts_with(";")) {
                    continue;
                }
                
                // Detect end of EQU section
                if in_equ_section && !trimmed.starts_with("EQU ") && !trimmed.starts_with("RESULT") && 
                   !trimmed.contains(" EQU ") && !trimmed.is_empty() {
                    in_equ_section = false;
                }
                
                // Skip lines that are part of the EQU section
                if in_equ_section {
                    continue;
                }
                
                out.push_str(line);
                out.push('\n');
            }
            out
        };

        for bank_id in 0..self.rom_bank_count {
            let phys_offset = bank_id as u32 * self.rom_bank_size;
            flattened.push_str(&format!("; ===== BANK #{:02} (physical offset ${:05X}) =====\n", bank_id, phys_offset));
            if let Some(section) = sections.get(&bank_id) {
                // STRUCTURE (2026-01-14):
                // Global ORG $0000 emitted at top (before DEFINE SECTION)
                // Each bank: strip INCLUDE + RAM EQU, emit only code
                //
                // For Bank #0 in flat file:
                //   - Strips INCLUDE (emitted globally)
                //   - Strips RAM EQU (but re-inserted after header for readability)
                //   - Keeps: header + START + code
                
                let code = strip_for_flatten(bank_id as u8, &section.asm_code);
                
                // Check if this bank's code already has an ORG directive
                let has_org = code.contains("ORG ");
                
                // For Bank #31 (fixed bank), ensure it has ORG $4000
                // For Bank #0 (and others): ORG $0000 already emitted globally, no repeat needed
                if bank_id == 31 && !has_org {
                    flattened.push_str("ORG $4000  ; Fixed bank window\n");
                }
                // Bank #0 and #1-#30 don't need local ORG (global $0000 applies)
                
                // For Bank #0 in flat file: reinstate RAM definitions after header for readability
                if bank_id == 0 {
                    // Find where START: appears and insert definitions before it
                    if let Some(start_pos) = code.find("START:") {
                        let before_start = &code[..start_pos];
                        let after_start = &code[start_pos..];
                        
                        flattened.push_str(before_start);
                        // Extract and re-insert definitions section before START
                        // Look for === RAM VARIABLE DEFINITIONS in the original section code
                        if let Some(def_start) = section.asm_code.find("=== RAM VARIABLE DEFINITIONS") {
                            if let Some(const_start) = section.asm_code.find(";**** CONST DECLARATIONS") {
                                let extracted_defs = &section.asm_code[def_start..const_start];
                                if !extracted_defs.trim().is_empty() {
                                    flattened.push_str("\n;***************************************************************************\n");
                                    flattened.push_str("; CODE SECTION\n");
                                    flattened.push_str(";***************************************************************************\n\n");
                                    flattened.push_str(extracted_defs);
                                    flattened.push_str("\n;**** CONST DECLARATIONS (NUMBER-ONLY) ****\n\n");
                                }
                            }
                        }
                        flattened.push_str(after_start);
                    } else {
                        flattened.push_str(&code);
                    }
                } else {
                    flattened.push_str(&code);
                }
            } else {
                flattened.push_str("; [empty bank]\n");
            }
            flattened.push_str("\n\n");
        }

        // Add RESET vector at the end of Bank #31 (for complete flat file inspection)
        // In multibank mode, vectors are in Bank #31 fixed window at $4000-$7FFF
        // RESET vector is at $FFFE, which maps to Bank #31 ($4000 + $3FFE = $7FFE)
        flattened.push_str("\n");
        flattened.push_str(";***************************************************************************\n");
        flattened.push_str("; INTERRUPT VECTORS (Bank #31 Fixed Window)\n");
        flattened.push_str(";***************************************************************************\n");
        flattened.push_str("ORG $FFFE\n");
        flattened.push_str("FDB CUSTOM_RESET\n");

        fs::write(&flattened_path, flattened)
            .map_err(|e| format!("Failed to write flattened ASM to {:?}: {}", flattened_path, e))?;

        // Emit per-bank ASM snapshots (bank_00.asm .. bank_31.asm) with explicit ORG for inspection
        for bank_id in 0..self.rom_bank_count {
            let bank_path = temp_dir.join(format!("bank_{:02}.asm", bank_id));
            if let Some(section) = sections.get(&bank_id) {
                let has_org = section.asm_code.contains("ORG ");
                let mut bank_code = String::new();
                if bank_id == 31 && !has_org {
                    bank_code.push_str("ORG $4000  ; Fixed bank window\n");
                } else if !has_org {
                    bank_code.push_str("ORG $0000  ; Switchable bank window\n");
                }
                bank_code.push_str(&section.asm_code);
                fs::write(&bank_path, bank_code)
                    .map_err(|e| format!("Failed to write bank_{:02}.asm: {}", bank_id, e))?;
            } else {
                // Create an explicit empty placeholder to keep numbering consistent
                let placeholder = format!("; [empty bank {:02}]\n", bank_id);
                fs::write(&bank_path, placeholder)
                    .map_err(|e| format!("Failed to write empty bank_{:02}.asm: {}", bank_id, e))?;
            }
        }
        
        // Assemble each bank in order. The helper bank (#31) was already assembled above.
        let mut rom_data = Vec::new();
        for bank_id in 0..self.rom_bank_count {
            if bank_id as u8 == helper_bank_id {
                rom_data.extend_from_slice(&helper_binary);
                continue;
            }

            if let Some(section) = sections.get(&bank_id) {
                // CRITICAL FIX (2026-01-20): Filter external symbols for this bank
                // Include:
                // 1. Bank #31 code range ($4000-$7FFF fixed window) - always visible
                // 2. BIOS range ($E000-$FFFF) - always visible
                // 3. RAM variables ($C800-$CFFF) - always visible
                // 4. Asset symbols (_VECTORS, _PATH, _MUSIC) from ANY bank - cross-bank references
                let external_symbols: HashMap<String, u16> = all_symbols.iter()
                    .filter(|(name, addr)| {
                        let a = **addr;
                        let is_fixed_or_bios = (a >= 0x4000 && a < 0x8000) || (a >= 0xE000) || (a >= 0xC800 && a < 0xD000);
                        let is_asset = name.contains("_VECTORS") || name.contains("_PATH") || name.contains("_MUSIC");
                        is_fixed_or_bios || is_asset
                    })
                    .map(|(k, v)| (k.clone(), *v))
                    .collect();
                
                
                let binary = self.assemble_bank(section, &temp_dir, &external_symbols)?;
                rom_data.extend_from_slice(&binary);
            } else {
                // Empty bank - fill with 0xFF
                rom_data.resize(rom_data.len() + self.rom_bank_size as usize, 0xFF);
            }
        }
        
        // Verify total size
        let expected_size = self.rom_bank_size as usize * self.rom_bank_count as usize;
        if rom_data.len() != expected_size {
            return Err(format!("ROM size mismatch: {} bytes (expected {} bytes)", 
                rom_data.len(), expected_size));
        }
        
        // Vectrex BIOS owns all interrupt vectors ($FFF0–$FFFF), including RESET at $FFFE.
        // Multibank cartridges MUST NOT override BIOS vectors within the cart image.
        // Boot flow: BIOS reset → detects cartridge → jumps to $0000 in current window.
        // Our Bank #0 boot stub is responsible for switching to the fixed bank via $DF00 and
        // then jumping to the entry at $4000+START. Therefore, we intentionally do NOT patch
        // any vector bytes in the generated ROM.
        
        // Patch RESET vector to point to CUSTOM_RESET in fixed bank (#31)
        // Vector lives at the last two bytes of the fixed bank window ($3FFE-$3FFF)
        let reset_vector_offset = (self.rom_bank_count as usize - 1) * self.rom_bank_size as usize
            + (self.rom_bank_size as usize - 2);
        if reset_vector_offset + 1 >= rom_data.len() {
            return Err(format!("RESET vector offset out of bounds (offset={}, len={})", reset_vector_offset, rom_data.len()));
        }
        // CUSTOM_RESET is placed at the start of the fixed bank and assembled with ORG $0000 → runtime address $4000
        let reset_handler_addr: u16 = 0x4000;
        // 6809 uses big-endian for 16-bit addresses: high byte first, then low byte
        rom_data[reset_vector_offset] = (reset_handler_addr >> 8) as u8;       // High byte ($40)
        rom_data[reset_vector_offset + 1] = (reset_handler_addr & 0x00FF) as u8; // Low byte ($00)

        // Patch header: copy header bytes from single-bank .bin if available, otherwise generate default header
        // Derive .bin path next to the .rom
        let _bin_path = output_rom_path.with_extension("bin");
        let final_rom = rom_data;

        // Multibank ROM: Bank #0 already contains assembled header from backend codegen
        // The backend emits a complete Vectrex header (FCC, FCB, FDB, title, etc.)
        // which is assembled into Bank #0 by the linker's split_asm_by_bank process.
        // DO NOT overwrite it - it's already correct and complete.

        // Write ROM
        fs::write(output_rom_path, final_rom)
            .map_err(|e| format!("Failed to write ROM: {}", e))?;
        
        // Return symbol table for PDB generation
        Ok(all_symbols)
    }
}

/// Convert all short branches to long branches in assembly code
/// This is required for multi-bank compilation because helper functions
/// (DIV16, MUL16, etc.) contain branches that may exceed ±127 bytes when
/// split across banks.
/// 
/// Conversions:
/// - BRA label → LBRA label  (0x20 → 0x16)
/// - BEQ label → LBEQ label  (0x27 → 0x10 0x27)
/// - BNE label → LBNE label  (0x26 → 0x10 0x26)
/// - BCS label → LBCS label  (0x25 → 0x10 0x25)
/// - BCC label → LBCC label  (0x24 → 0x10 0x24)
/// - And many other conditional branches...
fn convert_short_to_long_branches(asm: &str) -> String {
    let mut result = String::new();
    
    for line in asm.lines() {
        // Don't touch comments or labels
        if line.trim().starts_with(';') || line.trim().starts_with('*') {
            result.push_str(line);
            result.push('\n');
            continue;
        }
        
        let trimmed = line.trim();
        
        // Check for short branch instructions
        let converted = if trimmed.starts_with("BRA ") {
            let operand = trimmed.strip_prefix("BRA ").unwrap_or("");
            let indent = line.len() - line.trim_start().len();
            format!("{}LBRA {}", " ".repeat(indent), operand)
        } else if trimmed.starts_with("BEQ ") {
            let operand = trimmed.strip_prefix("BEQ ").unwrap_or("");
            let indent = line.len() - line.trim_start().len();
            format!("{}LBEQ {}", " ".repeat(indent), operand)
        } else if trimmed.starts_with("BNE ") {
            let operand = trimmed.strip_prefix("BNE ").unwrap_or("");
            let indent = line.len() - line.trim_start().len();
            format!("{}LBNE {}", " ".repeat(indent), operand)
        } else if trimmed.starts_with("BCS ") {
            let operand = trimmed.strip_prefix("BCS ").unwrap_or("");
            let indent = line.len() - line.trim_start().len();
            format!("{}LBCS {}", " ".repeat(indent), operand)
        } else if trimmed.starts_with("BCC ") {
            let operand = trimmed.strip_prefix("BCC ").unwrap_or("");
            let indent = line.len() - line.trim_start().len();
            format!("{}LBCC {}", " ".repeat(indent), operand)
        } else if trimmed.starts_with("BLO ") {
            let operand = trimmed.strip_prefix("BLO ").unwrap_or("");
            let indent = line.len() - line.trim_start().len();
            format!("{}LBLO {}", " ".repeat(indent), operand)
        } else if trimmed.starts_with("BHS ") {
            let operand = trimmed.strip_prefix("BHS ").unwrap_or("");
            let indent = line.len() - line.trim_start().len();
            format!("{}LBHS {}", " ".repeat(indent), operand)
        } else if trimmed.starts_with("BLT ") {
            let operand = trimmed.strip_prefix("BLT ").unwrap_or("");
            let indent = line.len() - line.trim_start().len();
            format!("{}LBLT {}", " ".repeat(indent), operand)
        } else if trimmed.starts_with("BGE ") {
            let operand = trimmed.strip_prefix("BGE ").unwrap_or("");
            let indent = line.len() - line.trim_start().len();
            format!("{}LBGE {}", " ".repeat(indent), operand)
        } else if trimmed.starts_with("BLE ") {
            let operand = trimmed.strip_prefix("BLE ").unwrap_or("");
            let indent = line.len() - line.trim_start().len();
            format!("{}LBLE {}", " ".repeat(indent), operand)
        } else if trimmed.starts_with("BGT ") {
            let operand = trimmed.strip_prefix("BGT ").unwrap_or("");
            let indent = line.len() - line.trim_start().len();
            format!("{}LBGT {}", " ".repeat(indent), operand)
        } else if trimmed.starts_with("BVS ") {
            let operand = trimmed.strip_prefix("BVS ").unwrap_or("");
            let indent = line.len() - line.trim_start().len();
            format!("{}LBVS {}", " ".repeat(indent), operand)
        } else if trimmed.starts_with("BVC ") {
            let operand = trimmed.strip_prefix("BVC ").unwrap_or("");
            let indent = line.len() - line.trim_start().len();
            format!("{}LBVC {}", " ".repeat(indent), operand)
        } else if trimmed.starts_with("BMI ") {
            let operand = trimmed.strip_prefix("BMI ").unwrap_or("");
            let indent = line.len() - line.trim_start().len();
            format!("{}LBMI {}", " ".repeat(indent), operand)
        } else if trimmed.starts_with("BPL ") {
            let operand = trimmed.strip_prefix("BPL ").unwrap_or("");
            let indent = line.len() - line.trim_start().len();
            format!("{}LBPL {}", " ".repeat(indent), operand)
        } else {
            // No branch instruction - keep as is
            line.to_string()
        };
        
        result.push_str(&converted);
        result.push('\n');
    }
    
    result
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_split_asm_by_bank() {
        let asm = r#"
; Header
    ORG $0000

; ================================================
; BANK #31 - 2 function(s)
; ================================================
    ORG $4000  ; Fixed bank

LOOP_BODY:
    RTS

; ================================================
; BANK #0 - 13 function(s)
; ================================================
    ORG $0000  ; Banked window

INIT_GAME:
    RTS
"#;
        
        let linker = MultiBankLinker::new(16384, 32, true, None);
        let sections = linker.split_asm_by_bank(asm).unwrap();
        
        assert_eq!(sections.len(), 2); // 2 banks (header is embedded in bank #0)
        let last_bank = linker.rom_bank_count - 1;
        assert!(sections.contains_key(&last_bank));
        assert!(sections.contains_key(&0));
        
        let bank31 = sections.get(&last_bank).unwrap();
        assert_eq!(bank31.org, 0x4000);
        assert!(bank31.asm_code.contains("LOOP_BODY"));
        
        let bank0 = sections.get(&0).unwrap();
        assert_eq!(bank0.org, 0x0000);
        assert!(bank0.asm_code.contains("INIT_GAME"));
    }
}
