//! Function Code Generation
//!
//! Generates M6809 assembly for VPy functions
//!
//! Two modes:
//! - Single-bank: All functions in one bank (generate_functions)
//! - Multi-bank: Functions distributed across banks (generate_functions_by_bank)

use vpy_parser::{Module, Function, Stmt, Expr};
use super::expressions;
use super::context;
use super::joystick;
use crate::AssetInfo;
use std::collections::HashMap;
use std::sync::atomic::{AtomicUsize, Ordering};

/// Generate a unique label with the given prefix (copied from core/src/backend/m6809/utils.rs)
pub fn fresh_label(prefix: &str) -> String {
    static COUNTER: AtomicUsize = AtomicUsize::new(0);
    let id = COUNTER.fetch_add(1, Ordering::Relaxed);
    format!("{}_{}", prefix, id)
}

/// Check if module uses BEEP (needs BEEP_UPDATE_RUNTIME auto-injection)
pub fn has_beep_calls(module: &Module) -> bool {
    fn check_expr(expr: &Expr) -> bool {
        matches!(expr, Expr::Call(c) if c.name == "BEEP")
    }
    fn check_stmt(stmt: &Stmt) -> bool {
        match stmt {
            Stmt::Expr(expr, _) => check_expr(expr),
            Stmt::If { cond, body, elifs, else_body, .. } => {
                check_expr(cond) ||
                body.iter().any(check_stmt) ||
                elifs.iter().any(|(e, b)| check_expr(e) || b.iter().any(check_stmt)) ||
                else_body.as_ref().map_or(false, |body| body.iter().any(check_stmt))
            },
            Stmt::While { cond, body, .. } => check_expr(cond) || body.iter().any(check_stmt),
            Stmt::For { body, .. } => body.iter().any(check_stmt),
            _ => false,
        }
    }
    module.items.iter().any(|item| {
        if let vpy_parser::Item::Function(func) = item {
            func.body.iter().any(check_stmt)
        } else {
            false
        }
    })
}

/// Check if module uses PRINT_TEXT or PRINT_NUMBER (needs TEXT_SCALE initialization)
pub fn has_print_calls(module: &Module) -> bool {
    fn check_expr(expr: &Expr) -> bool {
        matches!(expr, Expr::Call(c) if c.name == "PRINT_TEXT" || c.name == "PRINT_NUMBER")
    }
    fn check_stmt(stmt: &Stmt) -> bool {
        match stmt {
            Stmt::Expr(expr, _) => check_expr(expr),
            Stmt::If { cond, body, elifs, else_body, .. } => {
                check_expr(cond) ||
                body.iter().any(check_stmt) ||
                elifs.iter().any(|(e, b)| check_expr(e) || b.iter().any(check_stmt)) ||
                else_body.as_ref().map_or(false, |body| body.iter().any(check_stmt))
            },
            Stmt::While { cond, body, .. } => check_expr(cond) || body.iter().any(check_stmt),
            Stmt::For { body, .. } => body.iter().any(check_stmt),
            _ => false,
        }
    }
    module.items.iter().any(|item| {
        if let vpy_parser::Item::Function(func) = item {
            func.body.iter().any(check_stmt)
        } else {
            false
        }
    })
}

/// Check if module uses PLAY_MUSIC or PLAY_SFX (needs AUDIO_UPDATE auto-injection)
/// Check if module uses PLAY_MUSIC or PLAY_SFX builtins
/// Used to determine if AUDIO_UPDATE helper should be auto-injected
pub fn has_audio_calls(module: &Module) -> bool {
    fn check_expr(expr: &Expr) -> bool {
        match expr {
            Expr::Call(call_info) => {
                call_info.name == "PLAY_MUSIC" || call_info.name == "PLAY_SFX"
            },
            _ => false,
        }
    }
    
    fn check_stmt(stmt: &Stmt) -> bool {
        match stmt {
            Stmt::Expr(expr, _) => check_expr(expr),
            Stmt::If { cond, body, elifs, else_body, .. } => {
                check_expr(cond) ||
                body.iter().any(check_stmt) ||
                elifs.iter().any(|(e, b)| check_expr(e) || b.iter().any(check_stmt)) ||
                else_body.as_ref().map_or(false, |body| body.iter().any(check_stmt))
            },
            Stmt::While { cond, body, .. } => check_expr(cond) || body.iter().any(check_stmt),
            Stmt::For { body, .. } => body.iter().any(check_stmt),
            _ => false,
        }
    }
    
    module.items.iter().any(|item| {
        if let vpy_parser::Item::Function(func) = item {
            func.body.iter().any(check_stmt)
        } else {
            false
        }
    })
}

pub fn generate_functions(module: &Module, assets: &[AssetInfo]) -> Result<String, String> {
    let mut asm = String::new();
    
    // Find main() and loop()
    let mut main_fn = None;
    let mut loop_fn = None;
    let mut other_fns = Vec::new();
    
    for item in &module.items {
        if let vpy_parser::Item::Function(func) = item {
            // IMPORTANT: After unifier, function names are uppercase
            match func.name.to_uppercase().as_str() {
                "MAIN" => main_fn = Some(func),
                "LOOP" => loop_fn = Some(func),
                _ => other_fns.push(func),
            }
        }
    }
    
    // Generate MAIN entry point
    asm.push_str(";***************************************************************************\n");
    asm.push_str("; MAIN PROGRAM\n");
    asm.push_str(";***************************************************************************\n\n");
    
    asm.push_str("MAIN:\n");
    
    // Initialize global variables with their initial values
    asm.push_str("    ; Initialize global variables\n");
    asm.push_str("    CLR VPY_MOVE_X        ; MOVE offset defaults to 0\n");
    asm.push_str("    CLR VPY_MOVE_Y        ; MOVE offset defaults to 0\n");
    if has_print_calls(module) {
        asm.push_str("    LDA #$F8\n");
        asm.push_str("    STA TEXT_SCALE_H      ; Default height = -8 (normal size)\n");
        asm.push_str("    LDA #$48\n");
        asm.push_str("    STA TEXT_SCALE_W      ; Default width = 72 (normal size)\n");
    }
    let mut array_copy_counter = 0;
    for item in &module.items {
        if let vpy_parser::Item::GlobalLet { name, value, .. } = item {
            if let vpy_parser::Expr::List(elements) = value {
                // CRITICAL FIX (2026-01-19): Mutable arrays need RAM space
                // 1. Copy initial values from ROM (ARRAY_{NAME}_DATA) to RAM (VAR_{NAME}_DATA)
                // 2. Set VAR_{NAME} pointer to RAM location (not ROM)
                let rom_label = format!("ARRAY_{}_DATA", name.to_uppercase());
                let ram_label = format!("VAR_{}_DATA", name.to_uppercase());
                let array_len = elements.len();

                asm.push_str(&format!("    ; Copy array '{}' from ROM to RAM ({} elements)\n", name, array_len));
                asm.push_str(&format!("    LDX #{}       ; Source: ROM array data\n", rom_label));
                asm.push_str(&format!("    LDU #{}       ; Dest: RAM array space\n", ram_label));
                asm.push_str(&format!("    LDD #{}        ; Number of elements\n", array_len));
                asm.push_str(&format!(".COPY_LOOP_{}:\n", array_copy_counter));
                asm.push_str("    LDY ,X++        ; Load word from ROM, increment source\n");
                asm.push_str("    STY ,U++        ; Store word to RAM, increment dest\n");
                asm.push_str("    SUBD #1         ; Decrement counter\n");
                asm.push_str(&format!("    LBNE .COPY_LOOP_{} ; Loop until done (LBNE for long branch)\n", array_copy_counter));

                // Set VAR_{NAME} pointer to RAM array (not ROM)
                asm.push_str(&format!("    LDX #{}    ; Array now in RAM\n", ram_label));
                asm.push_str(&format!("    STX VAR_{}\n", name.to_uppercase()));

                array_copy_counter += 1;
            } else {
                // Non-array initialization: use emit_simple_expr so we handle any
                // valid initializer (Number, Ident pointing to a const, etc.)
                expressions::emit_simple_expr(value, &mut asm, assets);
                asm.push_str(&format!("    STD VAR_{}\n", name.to_uppercase()));
            }
        }
    }

    // CRITICAL: Initialize joystick mux ONCE before any J1_X/J1_Y calls
    // (copied from core/src/backend/m6809/mod.rs lines 834-849)
    joystick::emit_joystick_init(&mut asm);
    
    // Call main() if exists
    if let Some(main) = main_fn {
        asm.push_str("    ; Call main() for initialization\n");
        generate_function_body(main, &mut asm, assets)?;
    }
    
    // Infinite loop calling loop()
    asm.push_str("\n.MAIN_LOOP:\n");
    asm.push_str("    JSR LOOP_BODY\n");
    asm.push_str("    LBRA .MAIN_LOOP   ; Use long branch for multibank support\n\n");
    
    // Generate LOOP_BODY
    if let Some(loop_fn) = loop_fn {
        asm.push_str("LOOP_BODY:\n");
        // Inject WAIT_RECAL at the start of every loop
        asm.push_str("    JSR Wait_Recal   ; Synchronize with screen refresh (mandatory)\n");
        // NOTE: Reset0Ref is NOT called here. Each drawing primitive (DRAW_LINE,
        // DRAW_CIRCLE, etc.) calls Reset0Ref internally before positioning the beam.
        // Calling it here breaks PRINT_TEXT because it consumes the VIA scale factor
        // that Wait_Recal sets up ($80), leaving it at a wrong value for Print_Str_d.
        // CRITICAL (2026-01-19): Button reading with proper DP handling
        // This sequence MUST happen before any user code to ensure DP=$C8 for normal RAM access
        asm.push_str("    JSR $F1AA  ; DP_to_D0: set direct page to $D0 for PSG access\n");
        asm.push_str("    JSR $F1BA  ; Read_Btns: read PSG register 14, update $C80F (Vec_Btn_State)\n");
        asm.push_str("    JSR $F1AF  ; DP_to_C8: restore direct page to $C8 for normal RAM access\n");
        // Auto-inject BEEP_UPDATE before user code so beep timer counts down every frame
        if has_beep_calls(module) {
            asm.push_str("    JSR BEEP_UPDATE_RUNTIME  ; Auto-injected: tick beep countdown timer\n");
        }
        generate_function_body(loop_fn, &mut asm, assets)?;

        // Auto-inject AUDIO_UPDATE at END if module uses PLAY_MUSIC/PLAY_SFX
        if has_audio_calls(module) {
            if module.meta.music_timer {
                // META MUSIC_TIMER = true: use VIA T2 to call AUDIO_UPDATE an extra time
                // when user code took longer than one frame, keeping music in sync.
                // T2 bit 5 of VIA_int_flags ($D00D) is set when the timer fires;
                // Wait_Recal clears it on the next call — we must NOT clear it here.
                // Extended addressing (>) required: DP=$C8 but VIA is at $D00D.
                asm.push_str("    ; META MUSIC_TIMER: catch up if game frame was slow\n");
                asm.push_str("    LDA >$D00D              ; VIA_int_flags (extended addr, DP=$C8)\n");
                asm.push_str("    BITA #$20               ; Bit 5 = T2 elapsed (>1 frame of user code)\n");
                asm.push_str("    BEQ MUSIC_CATCHUP_SKIP  ; On time — skip extra tick\n");
                asm.push_str("    JSR AUDIO_UPDATE        ; Catch-up tick: game was slow\n");
                asm.push_str("MUSIC_CATCHUP_SKIP:\n");
            }
            asm.push_str("    JSR AUDIO_UPDATE  ; Auto-injected: update music + SFX\n");
        }

        asm.push_str("    RTS\n\n");
    } else {
        // Empty loop if not defined
        asm.push_str("LOOP_BODY:\n");
        asm.push_str("    JSR Wait_Recal   ; Synchronize with screen refresh (mandatory)\n");
        // NOTE: Reset0Ref NOT called here - drawing primitives handle it internally
        // CRITICAL: Button reading with proper DP handling (even if no user code)
        asm.push_str("    JSR $F1AA  ; DP_to_D0: set direct page to $D0 for PSG access\n");
        asm.push_str("    JSR $F1BA  ; Read_Btns: read PSG register 14, update $C80F (Vec_Btn_State)\n");
        asm.push_str("    JSR $F1AF  ; DP_to_C8: restore direct page to $C8 for normal RAM access\n");
        asm.push_str("    RTS\n\n");
    }
    
    // Generate other user functions (excluding MAIN and LOOP which are handled above)
    for func in other_fns {
        // Double-check: skip MAIN and LOOP (should already be filtered but be safe)
        let name_upper = func.name.to_uppercase();
        if name_upper == "MAIN" || name_upper == "LOOP" {
            continue;  // Already handled above
        }
        
        // IMPORTANT: Function name already comes uppercase from unifier
        asm.push_str(&format!("; Function: {}\n", func.name));
        asm.push_str(&format!("{}:\n", func.name));
        generate_function_body(func, &mut asm, assets)?;
        
        // Only add RTS if function doesn't end with explicit return
        let has_explicit_return = func.body.last()
            .map(|stmt| matches!(stmt, Stmt::Return(..)))
            .unwrap_or(false);
        if !has_explicit_return {
            asm.push_str("    RTS\n");
        }
        asm.push_str("\n");
    }
    
    Ok(asm)
}

fn generate_function_body(func: &Function, asm: &mut String, assets: &[AssetInfo]) -> Result<(), String> {
    // Generate code for each statement
    for stmt in &func.body {
        generate_statement(stmt, asm, assets)?;
    }
    Ok(())
}

fn generate_statement(stmt: &Stmt, asm: &mut String, assets: &[AssetInfo]) -> Result<(), String> {
    match stmt {
        Stmt::Assign { target, value, .. } => {
            match target {
                vpy_parser::AssignTarget::Ident { name, .. } => {
                    // Simple variable assignment: var = value
                    // 1. Evaluate expression
                    expressions::emit_simple_expr(value, asm, assets);

                    // 2. Store to variable with correct width dispatch
                    let size = context::get_var_size(name);
                    if size.bytes == 1 {
                        // 8-bit store: take low byte from RESULT and store with STB
                        asm.push_str("    LDB RESULT+1    ; Load low byte\n");
                        asm.push_str(&format!("    STB VAR_{}\n", name.to_uppercase()));
                    } else {
                        // 16-bit store: standard STD
                        asm.push_str("    LDD RESULT\n");
                        asm.push_str(&format!("    STD VAR_{}\n", name.to_uppercase()));
                    }
                }
                
                vpy_parser::AssignTarget::Index { target: array_expr, index, .. } => {
                    // Array indexed assignment: arr[index] = value
                    // Only support simple variable arrays (not complex expressions)
                    let array_name = if let vpy_parser::Expr::Ident(id) = &**array_expr {
                        &id.name
                    } else {
                        return Err("Complex array expressions not yet supported in assignment".to_string());
                    };

                    // Get element size for stride calculation
                    let element_size = context::get_var_size(array_name).bytes;

                    // 1. Evaluate index first
                    expressions::emit_simple_expr(index, asm, assets);
                    asm.push_str("    LDD RESULT\n");

                    // Stride multiply: only if element_size == 2
                    if element_size == 2 {
                        asm.push_str("    ASLB            ; Multiply index by 2 (16-bit elements)\n");
                        asm.push_str("    ROLA\n");
                    }
                    // For 8-bit elements, stride is 1, no multiply needed

                    asm.push_str("    STD TMPPTR      ; Save offset temporarily\n");

                    // 2. Load array base address (RAM for mutable, ROM for const)
                    // Use context to determine which label to use
                    let name_upper = array_name.to_uppercase();
                    let label = if context::is_mutable_array(array_name) {
                        format!("VAR_{}_DATA", name_upper)  // RAM
                    } else {
                        format!("ARRAY_{}_DATA", name_upper)  // ROM
                    };
                    asm.push_str(&format!("    LDD #{}  ; Array data address\n", label));

                    // 3. Add offset to base pointer
                    asm.push_str("    TFR D,X         ; X = array base pointer\n");
                    asm.push_str("    LDD TMPPTR      ; D = offset\n");
                    asm.push_str("    LEAX D,X        ; X = base + offset\n");
                    asm.push_str("    STX TMPPTR2     ; Save computed address\n");

                    // 4. Evaluate value to assign
                    expressions::emit_simple_expr(value, asm, assets);

                    // 5. Store value at computed address with correct width dispatch
                    asm.push_str("    LDX TMPPTR2     ; Load computed address\n");
                    if element_size == 1 {
                        // 8-bit store: take low byte and use STB
                        asm.push_str("    LDB RESULT+1    ; Load low byte\n");
                        asm.push_str("    STB ,X          ; Store 8-bit value\n");
                    } else {
                        // 16-bit store: standard STD
                        asm.push_str("    LDD RESULT      ; Load value\n");
                        asm.push_str("    STD ,X          ; Store 16-bit value\n");
                    }
                }
                
                _ => {
                    return Err(format!("Assignment target {:?} not yet supported", target));
                }
            }
        }
        
        Stmt::CompoundAssign { target, op, value, .. } => {
            // CRITICAL FIX (2026-02-22): Stack balance - use TMPVAL instead of PSHS/PULS
            // Load current value, save to TMPVAL, evaluate right side, perform op
            match target {
                vpy_parser::AssignTarget::Ident { name, .. } => {
                    // IMPORTANT: Convert name to uppercase for consistency with variable allocation
                    asm.push_str(&format!("    LDD >VAR_{}\n", name.to_uppercase()));
                    asm.push_str("    STD TMPVAL          ; Save left operand\n");

                    // Evaluate right side
                    expressions::emit_simple_expr(value, asm, assets);
                    asm.push_str("    LDD RESULT\n");

                    // Perform operation
                    match op {
                        vpy_parser::BinOp::Add => asm.push_str("    ADDD TMPVAL         ; D = D + TMPVAL\n"),
                        vpy_parser::BinOp::Sub => {
                            asm.push_str("    STD TMPPTR          ; Save right operand\n");
                            asm.push_str("    LDD TMPVAL          ; Get left operand\n");
                            asm.push_str("    SUBD TMPPTR         ; D = left - right\n");
                        }
                        _ => return Err(format!("Aug-assign {:?} not yet supported", op)),
                    }

                    // Store back (uppercase for consistency)
                    asm.push_str(&format!("    STD VAR_{}\n", name.to_uppercase()));
                }
                _ => return Err("Complex assignment targets not yet supported".to_string()),
            }
        }
        
        Stmt::Let { name, value, .. } => {
            // Local variable assignment: let var = value
            // 1. Evaluate expression
            expressions::emit_simple_expr(value, asm, assets);

            // 2. Store to variable with correct width dispatch
            let size = context::get_var_size(name);
            if size.bytes == 1 {
                // 8-bit store: take low byte from RESULT and store with STB
                asm.push_str("    LDB RESULT+1    ; Load low byte\n");
                asm.push_str(&format!("    STB VAR_{}\n", name.to_uppercase()));
            } else {
                // 16-bit store: standard STD
                asm.push_str("    LDD RESULT\n");
                asm.push_str(&format!("    STD VAR_{}\n", name.to_uppercase()));
            }
        }

        Stmt::Expr(expr, ..) => {
            expressions::emit_simple_expr(expr, asm, assets);
        }

        Stmt::If { cond, body, elifs, else_body, .. } => {
            // Copied from core/src/backend/m6809/statements.rs
            let end = fresh_label("IF_END");
            let mut next = fresh_label("IF_NEXT");
            let simple_if = elifs.is_empty() && else_body.is_none();
            expressions::emit_simple_expr(cond, asm, assets);
            // NOTE: emit_simple_expr must return with balanced stack. The LDD below loads
            // the condition result from RESULT. Before branching, ensure any temporary values
            // left on the stack by complex expressions (like array indexing) are cleaned.
            asm.push_str(&format!("    LDD RESULT\n    LBEQ {}\n", next));
            for s in body { generate_statement(s, asm, assets)?; }
            asm.push_str(&format!("    LBRA {}\n", end));
            for (i, (c, b)) in elifs.iter().enumerate() {
                asm.push_str(&format!("{}:\n", next));
                let new_next = if i == elifs.len() - 1 && else_body.is_none() { end.clone() } else { fresh_label("IF_NEXT") };
                expressions::emit_simple_expr(c, asm, assets);
                // Stack balance check: emit_simple_expr must return with balanced stack before branch
                asm.push_str(&format!("    LDD RESULT\n    LBEQ {}\n", new_next));
                for s in b { generate_statement(s, asm, assets)?; }
                asm.push_str(&format!("    LBRA {}\n", end));
                next = new_next;
            }
            if let Some(eb) = else_body {
                asm.push_str(&format!("{}:\n", next));
                for s in eb { generate_statement(s, asm, assets)?; }
            } else if !elifs.is_empty() || simple_if {
                if next != end {
                    asm.push_str(&format!("{}:\n", next));
                }
            }
            asm.push_str(&format!("{}:\n", end));
        }
        
        Stmt::While { cond, body, .. } => {
            // Copied from core/src/backend/m6809/statements.rs
            let ls = fresh_label("WH");
            let le = fresh_label("WH_END");
            asm.push_str(&format!("{}: ; while start\n", ls));
            expressions::emit_simple_expr(cond, asm, assets);
            // Stack balance check: emit_simple_expr must return with balanced stack before branch
            asm.push_str(&format!("    LDD RESULT\n    LBEQ {}\n", le));
            for s in body { generate_statement(s, asm, assets)?; }
            asm.push_str(&format!("    LBRA {}\n{}: ; while end\n", ls, le));
        }
        
        Stmt::Return(expr, ..) => {
            if let Some(e) = expr {
                expressions::emit_simple_expr(e, asm, assets);
            }
            asm.push_str("    RTS\n");
        }
        
        _ => {
            asm.push_str(&format!("    ; TODO: Statement {:?}\n", stmt));
        }
    }
    
    Ok(())
}

/// Generate functions distributed across banks (multibank support)
///
/// # Arguments
/// * `module` - Parsed VPy module
/// * `assets` - Asset info for DRAW_VECTOR etc
/// * `bank_assignments` - Map of function_name -> bank_id (from BankAllocator)
///
/// # Returns
/// HashMap<bank_id, asm_code_for_that_bank>
pub fn generate_functions_by_bank(
    module: &Module,
    assets: &[AssetInfo],
    bank_assignments: &HashMap<String, u8>,
) -> Result<HashMap<u8, String>, String> {
    let mut bank_asm: HashMap<u8, String> = HashMap::new();
    
    // Collect all functions
    let mut main_fn = None;
    let mut loop_fn = None;
    let mut other_fns = Vec::new();
    
    for item in &module.items {
        if let vpy_parser::Item::Function(func) = item {
            match func.name.to_uppercase().as_str() {
                "MAIN" => main_fn = Some(func),
                "LOOP" => loop_fn = Some(func),
                _ => other_fns.push(func),
            }
        }
    }
    
    // Bank 0 always gets MAIN, LOOP_BODY, and entry point
    let mut bank0_asm = String::new();
    
    bank0_asm.push_str(";***************************************************************************\n");
    bank0_asm.push_str("; MAIN PROGRAM (Bank #0)\n");
    bank0_asm.push_str(";***************************************************************************\n\n");
    
    bank0_asm.push_str("MAIN:\n");
    
    // Initialize global variables with their initial values
    bank0_asm.push_str("    ; Initialize global variables\n");
    let mut array_copy_counter = 0;
    for item in &module.items {
        if let vpy_parser::Item::GlobalLet { name, value, .. } = item {
            if let vpy_parser::Expr::List(elements) = value {
                let rom_label = format!("ARRAY_{}_DATA", name.to_uppercase());
                let ram_label = format!("VAR_{}_DATA", name.to_uppercase());
                let array_len = elements.len();
                
                bank0_asm.push_str(&format!("    ; Copy array '{}' from ROM to RAM ({} elements)\n", name, array_len));
                bank0_asm.push_str(&format!("    LDX #{}       ; Source: ROM array data\n", rom_label));
                bank0_asm.push_str(&format!("    LDU #{}       ; Dest: RAM array space\n", ram_label));
                bank0_asm.push_str(&format!("    LDD #{}        ; Number of elements\n", array_len));
                bank0_asm.push_str(&format!(".COPY_LOOP_{}:\n", array_copy_counter));
                bank0_asm.push_str("    LDY ,X++        ; Load word from ROM, increment source\n");
                bank0_asm.push_str("    STY ,U++        ; Store word to RAM, increment dest\n");
                bank0_asm.push_str("    SUBD #1         ; Decrement counter\n");
                bank0_asm.push_str(&format!("    LBNE .COPY_LOOP_{} ; Loop until done (LBNE for long branch)\n", array_copy_counter));
                bank0_asm.push_str(&format!("    LDX #{}    ; Array now in RAM\n", ram_label));
                bank0_asm.push_str(&format!("    STX VAR_{}\n", name.to_uppercase()));
                array_copy_counter += 1;
            } else if let vpy_parser::Expr::Number(n) = value {
                bank0_asm.push_str(&format!("    LDD #{}\n", n));
                bank0_asm.push_str(&format!("    STD VAR_{}\n", name.to_uppercase()));
            }
        }
    }
    
    joystick::emit_joystick_init(&mut bank0_asm);
    
    if let Some(main) = main_fn {
        bank0_asm.push_str("    ; Call main() for initialization\n");
        generate_function_body(main, &mut bank0_asm, assets)?;
    }
    
    bank0_asm.push_str("\n.MAIN_LOOP:\n");
    bank0_asm.push_str("    JSR LOOP_BODY\n");
    bank0_asm.push_str("    LBRA .MAIN_LOOP   ; Use long branch for multibank support\n\n");
    
    // Generate LOOP_BODY
    if let Some(loop_fn) = loop_fn {
        bank0_asm.push_str("LOOP_BODY:\n");
        bank0_asm.push_str("    JSR Wait_Recal   ; Synchronize with screen refresh (mandatory)\n");
        // NOTE: Reset0Ref NOT called here - drawing primitives handle it internally
        bank0_asm.push_str("    JSR $F1AA  ; DP_to_D0: set direct page to $D0 for PSG access\n");
        bank0_asm.push_str("    JSR $F1BA  ; Read_Btns: read PSG register 14, update $C80F (Vec_Btn_State)\n");
        bank0_asm.push_str("    JSR $F1AF  ; DP_to_C8: restore direct page to $C8 for normal RAM access\n");
        if has_beep_calls(module) {
            bank0_asm.push_str("    JSR BEEP_UPDATE_RUNTIME  ; Auto-injected: tick beep countdown timer\n");
        }
        generate_function_body(loop_fn, &mut bank0_asm, assets)?;

        if has_audio_calls(module) {
            bank0_asm.push_str("    JSR AUDIO_UPDATE  ; Auto-injected: update music + SFX (after all game logic)\n");
        }

        bank0_asm.push_str("    RTS\n\n");
    } else {
        bank0_asm.push_str("LOOP_BODY:\n");
        bank0_asm.push_str("    JSR Wait_Recal   ; Synchronize with screen refresh (mandatory)\n");
        // NOTE: Reset0Ref NOT called here - drawing primitives handle it internally
        bank0_asm.push_str("    JSR $F1AA  ; DP_to_D0: set direct page to $D0 for PSG access\n");
        bank0_asm.push_str("    JSR $F1BA  ; Read_Btns: read PSG register 14, update $C80F (Vec_Btn_State)\n");
        bank0_asm.push_str("    JSR $F1AF  ; DP_to_C8: restore direct page to $C8 for normal RAM access\n");
        bank0_asm.push_str("    RTS\n\n");
    }
    
    bank_asm.insert(0, bank0_asm);
    
    // Group other functions by assigned bank
    for func in other_fns {
        let name_upper = func.name.to_uppercase();
        if name_upper == "MAIN" || name_upper == "LOOP" {
            continue;
        }
        
        // Get assigned bank (default to 0 if not assigned)
        let bank_id = bank_assignments.get(&func.name)
            .or_else(|| bank_assignments.get(&name_upper))
            .copied()
            .unwrap_or(0);
        
        // Get or create ASM buffer for this bank
        let asm = bank_asm.entry(bank_id).or_insert_with(String::new);
        
        asm.push_str(&format!("; Function: {} (Bank #{})\n", func.name, bank_id));
        asm.push_str(&format!("{}:\n", func.name));
        generate_function_body(func, asm, assets)?;
        
        let has_explicit_return = func.body.last()
            .map(|stmt| matches!(stmt, Stmt::Return(..)))
            .unwrap_or(false);
        if !has_explicit_return {
            asm.push_str("    RTS\n");
        }
        asm.push_str("\n");
    }
    
    Ok(bank_asm)
}
