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
use super::ast_walk;
use crate::AssetInfo;
use std::collections::HashMap;
use std::sync::atomic::{AtomicUsize, Ordering};

/// Generate a unique label with the given prefix (copied from core/src/backend/m6809/utils.rs)
pub fn fresh_label(prefix: &str) -> String {
    static COUNTER: AtomicUsize = AtomicUsize::new(0);
    let id = COUNTER.fetch_add(1, Ordering::Relaxed);
    format!("{}_{}", prefix, id)
}

// ---------------------------------------------------------------------------
// "Does the program use X?" scans. All of them go through the exhaustive
// `ast_walk` visitor so a builtin is found wherever it appears (for/for-in/
// while/switch bodies, if conditions, call arguments, index expressions,
// compound assignments, returns, global initializers).
// ---------------------------------------------------------------------------

/// Check if module uses BEEP (needs BEEP_UPDATE_RUNTIME auto-injection)
pub fn has_beep_calls(module: &Module) -> bool {
    ast_walk::calls_any(module, &["BEEP"])
}

/// Check if any code path uses analog joystick reads (J1_X / J1_Y / J2_X / J2_Y / J2_ANALOG_X/Y).
/// When true, we auto-inject ONE Joy_Analog BIOS call per frame at the top of LOOP_BODY
/// and J1X_BUILTIN/J1Y_BUILTIN/etc. become cheap cached-RAM reads. Saves ~750 cycles per
/// duplicate call (Joy_Analog is heavy and already populates all 4 axes per BIOS call).
pub fn has_joystick_analog_calls(module: &Module) -> bool {
    ast_walk::calls_any(module, &["J1_X", "J1_Y", "J2_X", "J2_Y", "J2_ANALOG_X", "J2_ANALOG_Y"])
}

/// Check if module uses PLAY_NOTE (needs NOTE_UPDATE_RUNTIME + PLAY_NOTE_RUNTIME auto-injection)
pub fn has_note_calls(module: &Module) -> bool {
    ast_walk::calls_any(module, &["PLAY_NOTE"])
}

/// Check if module uses PRINT_TEXT or PRINT_NUMBER (needs TEXT_SCALE initialization)
pub fn has_print_calls(module: &Module) -> bool {
    ast_walk::calls_any(module, &["PRINT_TEXT", "PRINT_NUMBER"])
}

/// Check if module uses DRAW_VECTOR, DRAW_ANIM, or SHOW_LEVEL (needs DRAW_SCALE initialization)
pub fn has_draw_scale_calls(module: &Module) -> bool {
    ast_walk::calls_any(module, &["DRAW_VECTOR", "DRAW_VECTOR_EX", "DRAW_ANIM", "SHOW_LEVEL"])
}

/// Check if module uses DRAW_ANIM (needs DRAW_SCALE / DRAW_ANIM_SCALE initialization)
pub fn has_draw_anim_calls(module: &Module) -> bool {
    ast_walk::calls_any(module, &["DRAW_ANIM"])
}

/// String-literal first argument of every call to `builtin` (upper-case name).
fn first_string_args<'a>(module: &'a Module, builtin: &str) -> Vec<&'a str> {
    let mut out = Vec::new();
    ast_walk::for_each_call(module, |c| {
        if c.name.eq_ignore_ascii_case(builtin) {
            if let Some(Expr::StringLit(name)) = c.args.first() {
                out.push(name.as_str());
            }
        }
    });
    out
}

/// Collect every animation name passed to DRAW_ANIM("name", ...) in the module.
/// Used to emit per-anim state RAM zeroing at MAIN startup.
pub fn collect_draw_anim_names(module: &Module) -> std::collections::BTreeSet<String> {
    first_string_args(module, "DRAW_ANIM")
        .into_iter()
        .map(|name| name.to_uppercase().replace('-', "_").replace(' ', "_"))
        .collect()
}

/// Collect the raw recording names referenced by DRAW_RECORDING("name", ...)
/// calls (as typed in the source — NOT uppercased), for existence validation.
pub fn collect_draw_recording_names(module: &Module) -> std::collections::BTreeSet<String> {
    first_string_args(module, "DRAW_RECORDING")
        .into_iter()
        .map(str::to_string)
        .collect()
}

/// Check if module uses PLAY_MUSIC or PLAY_SFX builtins
/// Used to determine if AUDIO_UPDATE helper should be auto-injected
pub fn has_audio_calls(module: &Module) -> bool {
    ast_walk::calls_any(module, &["PLAY_MUSIC", "PLAY_SFX"])
}

/// MAIN startup: copy a mutable global array's initial values from ROM
/// (`ARRAY_<NAME>_DATA`) to its RAM block (`VAR_<NAME>_DATA`).
///
/// The array name itself evaluates to `#VAR_<NAME>_DATA` (see
/// `context::global_array_base_label`), so no pointer variable is written here —
/// an unused array therefore needs no extra RAM symbol.
/// The copy is sized in BYTES (elements × element size): 8-bit arrays occupy
/// N bytes in ROM and RAM, so a word-per-element copy would overrun both.
fn emit_mutable_array_init(name: &str, element_count: usize, counter: usize, asm: &mut String) {
    let rom_label = format!("ARRAY_{}_DATA", name.to_uppercase());
    let ram_label = format!("VAR_{}_DATA", name.to_uppercase());
    let element_bytes = context::get_var_size(name).bytes;
    let total_bytes = element_count * element_bytes;
    asm.push_str(&format!(
        "    ; Copy array '{}' from ROM to RAM ({} elements x {} bytes)\n",
        name, element_count, element_bytes
    ));
    if total_bytes == 0 {
        return;
    }
    asm.push_str(&format!("    LDX #{}       ; Source: ROM array data\n", rom_label));
    asm.push_str(&format!("    LDU #{}       ; Dest: RAM array space\n", ram_label));
    if element_bytes == 2 {
        asm.push_str(&format!("    LDD #{}        ; Number of 16-bit elements\n", element_count));
        asm.push_str(&format!(".COPY_LOOP_{}:\n", counter));
        asm.push_str("    LDY ,X++        ; Load word from ROM, increment source\n");
        asm.push_str("    STY ,U++        ; Store word to RAM, increment dest\n");
        asm.push_str("    SUBD #1         ; Decrement counter\n");
    } else {
        asm.push_str(&format!("    LDY #{}        ; Number of bytes\n", total_bytes));
        asm.push_str(&format!(".COPY_LOOP_{}:\n", counter));
        asm.push_str("    LDA ,X+         ; Load byte from ROM, increment source\n");
        asm.push_str("    STA ,U+         ; Store byte to RAM, increment dest\n");
        asm.push_str("    LEAY -1,Y       ; Decrement counter (sets Z)\n");
    }
    asm.push_str(&format!("    LBNE .COPY_LOOP_{} ; Loop until done (LBNE for long branch)\n", counter));
}

pub fn generate_functions(module: &Module, assets: &[AssetInfo]) -> Result<String, String> {
    let mut asm = String::new();

    // Build frame_groups map and populate context for conditional JSR wrapping
    if let Some(n) = module.meta.interleaved_frames {
        let groups: HashMap<String, u8> = module.items.iter()
            .filter_map(|item| {
                if let vpy_parser::Item::Function(f) = item {
                    f.frame_group.map(|g| (f.name.to_uppercase(), g))
                } else {
                    None
                }
            })
            .collect();
        context::set_frame_groups(groups, n);
    }

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
    // Vectrex RAM is NOT zero at power-on (emulator fills it with a pattern too).
    // DRAW_VEC_INTENSITY is the SET_INTENSITY override read by DRAW_VECTOR AND
    // DRAW_RECORDING; if left uninitialized, its garbage value overrides the
    // recorded/vector intensity (e.g. $8E blanks the beam → nothing draws).
    asm.push_str("    CLR DRAW_VEC_INTENSITY ; 0 = use recorded/vector intensity (no override)\n");
    if crate::m6809::level::needs_level_runtime(module) {
        asm.push_str("    ; Init camera ONCE at boot (RAM not zero-init); LOAD_LEVEL must NOT reset it.\n");
        asm.push_str("    LDD #0\n");
        asm.push_str("    STD >CAMERA_X\n");
        asm.push_str("    STD >CAMERA_Y\n");
    }
    if has_print_calls(module) {
        asm.push_str("    LDA #$F8\n");
        asm.push_str("    STA TEXT_SCALE_H      ; Default height = -8 (normal size)\n");
        asm.push_str("    LDA #$48\n");
        asm.push_str("    STA TEXT_SCALE_W      ; Default width = 72 (normal size)\n");
    }
    if has_draw_scale_calls(module) {
        asm.push_str("    LDA #$7F\n");
        asm.push_str("    STA DRAW_SCALE        ; Default T1 scale = $7F (127 = full BIOS scale)\n");
    }
    if has_draw_anim_calls(module) {
        asm.push_str("    LDA #$7F\n");
        asm.push_str("    STA DRAW_ANIM_SCALE   ; Default anim scale = $7F (127 = full BIOS scale)\n");
        asm.push_str("    CLR DRAW_ANIM_SPEED_MUL ; Default speed=0 (use vanim timing)\n");
        // Zero per-animation state RAM (frame_idx, ticks_left). Without this, the
        // first DRAW_ANIM call sees garbage and computes a frame_ptr way out of bounds,
        // making DSWM draw random vectors. ticks_left=0 forces DAR_INIT path.
        for anim_name in collect_draw_anim_names(module) {
            asm.push_str(&format!("    CLR ANIM_{}_STATE     ; frame_idx = 0\n", anim_name));
            asm.push_str(&format!("    CLR ANIM_{}_STATE+1   ; ticks_left = 0 (forces DAR_INIT)\n", anim_name));
        }
    }
    if has_note_calls(module) {
        // Pre-initialize channel_id bytes so each channel slot knows which channel it owns
        asm.push_str("    ; Initialize NOTE_STATE channel IDs (pre-clear active flags)\n");
        asm.push_str("    LDA #0\n");
        asm.push_str("    STA NOTE_STATE        ; channel A: id=0, active=0 (initial)\n");
        asm.push_str("    CLR NOTE_STATE+1      ; active=0\n");
        asm.push_str("    LDA #1\n");
        asm.push_str("    STA NOTE_STATE+10     ; channel B: id=1\n");
        asm.push_str("    CLR NOTE_STATE+11     ; active=0\n");
        asm.push_str("    LDA #2\n");
        asm.push_str("    STA NOTE_STATE+20     ; channel C: id=2\n");
        asm.push_str("    CLR NOTE_STATE+21     ; active=0\n");
    }
    let mut array_copy_counter = 0;
    for item in &module.items {
        if let vpy_parser::Item::GlobalLet { name, value, .. } = item {
            if let vpy_parser::Expr::List(elements) = value {
                emit_mutable_array_init(name, elements.len(), array_copy_counter, &mut asm);
                array_copy_counter += 1;
            } else {
                // Non-array initialization: any valid initializer (Number, Ident
                // pointing to a const, etc.), stored with the global's width.
                emit_global_init(name, value, &mut asm, assets);
            }
        }
    }

    // CRITICAL: Initialize joystick mux ONCE before any J1_X/J1_Y calls
    // (copied from core/src/backend/m6809/mod.rs lines 834-849)
    joystick::emit_joystick_init(&mut asm);

    // Prime button state at startup: call BIOS Read_Btns ($F1BA) to initialize
    // $C80E (Vec_Prev_Btns) from the current hardware state. This ensures that
    // on the very first game frame, $C811 (edge-detected buttons) is clean.
    // Note: $C80E was already cleared (CLR $C80E) in START code.
    asm.push_str("    ; Prime BIOS button state at startup\n");
    asm.push_str("    JSR $F1BA    ; Read_Btns: reads PSG reg14 -> $C80F, $C811, $C80E\n");

    // Call main() if exists
    if let Some(main) = main_fn {
        asm.push_str("    ; Call main() for initialization\n");
        generate_function_body(main, &mut asm, assets)?;
    }

    // Force-clear Vec_Buttons ($C811) right before entering the game loop.
    // main() may call LOAD_LEVEL/PLAY_MUSIC which could disturb the button state,
    // and Wait_Recal in LOOP_BODY may re-arm transitions. Belt-and-suspenders.
    asm.push_str("    CLR >$C811  ; Force-clear Vec_Buttons before first loop() frame\n");

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
        // BIOS Read_Btns ($F1BA): reads PSG reg 14, inverts to active-HIGH,
        // stores current state in $C80F, computes rising-edge in $C811, updates $C80E.
        // More reliable on real hardware than direct PSG reads.
        asm.push_str("    JSR $F1BA    ; Read_Btns: PSG reg14 -> $C80F (active-HIGH), edge -> $C811\n");
        // Auto-inject Joy_Analog ONCE per frame if any code uses analog joystick reads.
        // Without this, every J1_X()/J1_Y() call would do its own ~750-cycle BIOS poll;
        // here we poll once (populating all 4 axes at $C81B-$C81E) and the per-call
        // builtins become cheap cached-RAM reads (~10 cycles).
        if has_joystick_analog_calls(module) {
            asm.push_str("    JSR $F1AA    ; DP_to_D0 (Joy_Analog requires DP=$D0)\n");
            asm.push_str("    JSR $F1F5    ; Joy_Analog: poll all 4 axes once → $C81B-$C81E\n");
            asm.push_str("    JSR Reset0Ref ; Restore beam state after Joy_Analog\n");
            asm.push_str("    JSR $F1AF    ; DP_to_C8 (restore DP for RAM access)\n");
        }
        // Auto-inject BEEP_UPDATE before user code so beep timer counts down every frame
        if has_beep_calls(module) {
            asm.push_str("    JSR BEEP_UPDATE_RUNTIME  ; Auto-injected: tick beep countdown timer\n");
        }
        // Auto-inject NOTE_UPDATE_RUNTIME before user code so note timers/arpeggio run every frame
        if has_note_calls(module) {
            asm.push_str("    JSR NOTE_UPDATE_RUNTIME  ; Auto-injected: tick note timers + arpeggio\n");
        }
        // Auto-inject FRAME_PARITY toggle for interleaved rendering
        if let Some(n) = module.meta.interleaved_frames {
            let skip_label = fresh_label("PARITY_OK");
            asm.push_str("    ; META INTERLEAVED_FRAMES: advance frame group counter\n");
            asm.push_str("    LDB >FRAME_PARITY\n");
            asm.push_str("    INCB\n");
            asm.push_str(&format!("    CMPB #{}\n", n));
            asm.push_str(&format!("    BLO {}\n", skip_label));
            asm.push_str("    CLRB\n");
            asm.push_str(&format!("{}:\n", skip_label));
            asm.push_str("    STB >FRAME_PARITY\n");
        }
        generate_function_body(loop_fn, &mut asm, assets)?;

        // Auto-inject AUDIO_UPDATE at END if module uses PLAY_MUSIC/PLAY_SFX
        if has_audio_calls(module) {
            asm.push_str("    JSR AUDIO_UPDATE  ; Auto-injected: update music + SFX\n");
        }

        asm.push_str("    RTS\n\n");
    } else {
        // Empty loop if not defined
        asm.push_str("LOOP_BODY:\n");
        asm.push_str("    JSR Wait_Recal   ; Synchronize with screen refresh (mandatory)\n");
        asm.push_str("    JSR $F1BA    ; Read_Btns: PSG reg14 -> $C80F (active-HIGH), edge -> $C811\n");
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
        asm.push_str(&format!("{}:\n", vpy_parser::symbols::m6809_label(&func.name)));
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

/// The code of one function; its errors carry the function's source file.
fn generate_function_body(func: &Function, asm: &mut String, assets: &[AssetInfo]) -> Result<(), String> {
    crate::origins::enter(&func.name);
    let result = generate_function_body_in(func, asm, assets).map_err(|e| crate::origins::locate(&e));
    crate::origins::leave();
    result
}

fn generate_function_body_in(func: &Function, asm: &mut String, assets: &[AssetInfo]) -> Result<(), String> {
    // Parameters and locals resolve to this function's frame slots (see `frames`);
    // the caller has already stored the arguments in the parameter slots.
    let label = vpy_parser::symbols::m6809_label(&func.name);
    context::set_current_function(&label);
    if let Some(frame) = context::frame_of(&label) {
        if frame.size > 0 {
            asm.push_str(&format!(
                "    ; frame of {}(): {} bytes at frame pool +{}\n",
                func.name, frame.size, frame.offset
            ));
        }
    }
    let loop_labels: Vec<(String, String)> = Vec::new();
    // Generate code for each statement
    let result = func.body.iter().try_for_each(|stmt| generate_statement(stmt, asm, assets, &loop_labels));
    context::set_current_function("");
    result
}

/// MAIN startup: store a scalar global's initial value with the global's width.
fn emit_global_init(name: &str, value: &Expr, asm: &mut String, assets: &[AssetInfo]) {
    expressions::emit_simple_expr(value, asm, assets);
    if context::get_var_size(name).bytes == 1 {
        asm.push_str(&format!("    STB VAR_{}\n", name.to_uppercase()));
    } else {
        asm.push_str(&format!("    STD VAR_{}\n", name.to_uppercase()));
    }
}

/// If a statement's primary expression is a direct call to a builtin/native
/// runtime function, return its name (for the `; NATIVE_CALL` debug annotation).
fn primary_builtin_call(stmt: &Stmt) -> Option<&str> {
    let expr = match stmt {
        Stmt::Expr(e, _) => e,
        Stmt::Assign { value, .. } => value,
        Stmt::Let { value, .. } => value,
        Stmt::CompoundAssign { value, .. } => value,
        Stmt::Return(Some(e), _) => e,
        _ => return None,
    };
    if let Expr::Call(call) = expr {
        if crate::m6809::builtins::is_builtin(&call.name) {
            return Some(&call.name);
        }
    }
    None
}

/// Error text for indexing / iterating a name that is not an array.
pub(crate) fn not_an_array_message(name: &str) -> String {
    format!(
        "`{name}` is not an array. On m6809 you can index a global array \
         (`xs = [..]`, `const XS = [..]`) or a function parameter that receives one"
    )
}

fn not_an_array_error(name: &str, line: usize) -> String {
    format!("line {line}: {}", not_an_array_message(name))
}

/// A global array name is a fixed base address, not a variable: `arr = ...` /
/// `arr += ...` cannot be compiled. Assign elements with `arr[i] = v`.
fn reject_array_rebind(name: &str) -> Result<(), String> {
    if context::global_array_base_label(name).is_some() {
        return Err(format!(
            "cannot assign to global array '{}' as a whole on m6809; assign its elements instead (e.g. {}[i] = value)",
            name, name
        ));
    }
    Ok(())
}

fn generate_statement(stmt: &Stmt, asm: &mut String, assets: &[AssetInfo], loop_labels: &[(String, String)]) -> Result<(), String> {
    // Debug annotations (Phase 9 PDB): map this statement's first emitted instruction
    // back to its VPy source line, and flag native/builtin calls for step-into.
    let src_line = stmt.source_line();
    if src_line > 0 {
        asm.push_str(&format!("; VPy_LINE:{}\n", src_line));
        if let Some(name) = primary_builtin_call(stmt) {
            asm.push_str(&format!("; NATIVE_CALL: {} at line {}\n", name.to_ascii_uppercase(), src_line));
        }
    }
    match stmt {
        Stmt::Assign { target, value, .. } => {
            match target {
                vpy_parser::AssignTarget::Ident { name, .. } => {
                    reject_array_rebind(name)?;
                    // Simple variable assignment: var = value
                    // 1. Evaluate expression
                    expressions::emit_simple_expr(value, asm, assets);

                    // 2. Store to variable with correct width dispatch
                    let var_label = expressions::resolve_var_label(name);
                    let size = context::get_var_size(name);
                    if size.bytes == 1 {
                        // 8-bit store: B already holds low byte from emit_simple_expr
                        asm.push_str(&format!("    STB {}\n", var_label));
                    } else {
                        // 16-bit store: D already holds value from emit_simple_expr
                        asm.push_str(&format!("    STD {}\n", var_label));
                    }
                }
                
                vpy_parser::AssignTarget::Index { target: array_expr, index, source_line, .. } => {
                    // Array element assignment: arr[index] = value.
                    // `arr` is a global array (base = its data label) or a parameter
                    // holding the base address of the array the caller passed.
                    let array_id = match &**array_expr {
                        vpy_parser::Expr::Ident(id) => id,
                        _ => {
                            return Err(format!(
                                "line {}: only a named array can be assigned through an index on m6809 (e.g. xs[i] = v)",
                                source_line
                            ))
                        }
                    };
                    let Some((base, elem)) = context::resolve_array(&array_id.name) else {
                        return Err(not_an_array_error(&array_id.name, *source_line));
                    };

                    // 1. D = index * element size
                    expressions::emit_simple_expr(index, asm, assets);
                    if elem.bytes == 2 {
                        asm.push_str("    ASLB            ; Multiply index by 2 (16-bit elements)\n");
                        asm.push_str("    ROLA\n");
                    }

                    // 2. X = base + offset
                    match &base {
                        context::ArrayBase::Label(label) => {
                            asm.push_str(&format!("    LDX #{}  ; Array data address\n", label));
                            asm.push_str("    LEAX D,X        ; X = base + offset\n");
                        }
                        context::ArrayBase::Pointer(slot) => {
                            asm.push_str(&format!("    ADDD >{}  ; + array base address (parameter)\n", slot));
                            asm.push_str("    TFR D,X         ; X = base + offset\n");
                        }
                    }
                    asm.push_str("    PSHS X          ; Save computed address (stack-safe across function calls)\n");

                    // 3. Evaluate value to assign
                    expressions::emit_simple_expr(value, asm, assets);

                    // 4. Store with the element width
                    asm.push_str("    PULS X          ; Restore computed address\n");
                    if elem.bytes == 1 {
                        asm.push_str("    STB ,X          ; Store 8-bit value\n");
                    } else {
                        asm.push_str("    STD ,X          ; Store 16-bit value\n");
                    }
                }
                
                _ => {
                    return Err(format!("Assignment target {:?} not yet supported", target));
                }
            }
        }
        
        Stmt::CompoundAssign { target, op, value, source_line } => {
            // `t op= v` is `t = t op v`: the binop code keeps both operands intact
            // whatever `v` is, and the store uses the target's width.
            match target {
                vpy_parser::AssignTarget::Ident { name, source_line: l, col } => {
                    reject_array_rebind(name)?;
                    let current = Expr::Ident(vpy_parser::IdentInfo { name: name.clone(), source_line: *l, col: *col });
                    let combined = Expr::Binary { op: *op, left: Box::new(current), right: Box::new(value.clone()) };
                    expressions::emit_simple_expr(&combined, asm, assets);
                    let var_label = expressions::resolve_var_label(name);
                    if context::get_var_size(name).bytes == 1 {
                        asm.push_str(&format!("    STB {}\n", var_label));
                    } else {
                        asm.push_str(&format!("    STD {}\n", var_label));
                    }
                }
                // `xs[i] op= v`: the index is evaluated twice, so it must have no
                // side effects (no call); `g[r][c] += 1` and `ties[i + 1].hp -= 1`
                // lower to such an index.
                vpy_parser::AssignTarget::Index { target: arr, index, .. } if has_no_calls(index) => {
                    let element = Expr::Index { target: arr.clone(), index: index.clone() };
                    let combined = Expr::Binary { op: *op, left: Box::new(element), right: Box::new(value.clone()) };
                    let assign = Stmt::Assign { target: target.clone(), value: combined, source_line: *source_line };
                    generate_statement(&assign, asm, assets, loop_labels)?;
                }
                _ => {
                    return Err(format!(
                        "line {}: compound assignment to an element whose index calls a function \
                         (`xs[f(i)] += v`) is not supported on m6809; put the index in a variable first",
                        source_line
                    ))
                }
            }
        }
        
        Stmt::Let { name, value, .. } => {
            // Local variable assignment: let var = value
            // 1. Evaluate expression
            expressions::emit_simple_expr(value, asm, assets);

            // 2. Store to variable with correct width dispatch
            let var_label = expressions::resolve_var_label(name);
            if context::get_var_size(name).bytes == 1 {
                // 8-bit store: B already holds low byte from emit_simple_expr
                asm.push_str(&format!("    STB {}\n", var_label));
            } else {
                // 16-bit store: D already holds value from emit_simple_expr
                asm.push_str(&format!("    STD {}\n", var_label));
            }
        }

        Stmt::Expr(expr, ..) => {
            // If this is a call to a @frame(N)-decorated function, guard with FRAME_PARITY check
            if let Expr::Call(call_info) = expr {
                let name_upper = call_info.name.to_uppercase();
                if let Some(group) = context::get_frame_group(&name_upper) {
                    if context::get_interleaved_n() > 0 {
                        let skip = fresh_label("FRAME_SKIP");
                        asm.push_str(&format!("    ; @frame({}) guard for {}\n", group, call_info.name));
                        asm.push_str("    LDB >FRAME_PARITY\n");
                        asm.push_str(&format!("    CMPB #{}\n", group));
                        asm.push_str(&format!("    BNE {}\n", skip));
                        expressions::emit_simple_expr(expr, asm, assets);
                        asm.push_str(&format!("{}:\n", skip));
                        return Ok(());
                    }
                }
            }
            expressions::emit_simple_expr(expr, asm, assets);
        }

        Stmt::If { cond, body, elifs, else_body, .. } => {
            // Copied from core/src/backend/m6809/statements.rs
            let end = fresh_label("IF_END");
            let mut next = fresh_label("IF_NEXT");
            let simple_if = elifs.is_empty() && else_body.is_none();
            // Peephole: emit direct compare-and-branch for `if x == LIT` / `if x != LIT`
            // patterns (saves ~15 cycles vs the boolean-materialise+LBEQ path).
            // Falls back to the generic path for non-Compare conds and for ordered
            // comparisons (signed/unsigned tricky with mixed i16/u16 globals).
            expressions::emit_branch_if_false(cond, &next, asm, assets);
            for s in body { generate_statement(s, asm, assets, loop_labels)?; }
            asm.push_str(&format!("    LBRA {}\n", end));
            for (i, (c, b)) in elifs.iter().enumerate() {
                asm.push_str(&format!("{}:\n", next));
                let new_next = if i == elifs.len() - 1 && else_body.is_none() { end.clone() } else { fresh_label("IF_NEXT") };
                expressions::emit_branch_if_false(c, &new_next, asm, assets);
                for s in b { generate_statement(s, asm, assets, loop_labels)?; }
                asm.push_str(&format!("    LBRA {}\n", end));
                next = new_next;
            }
            if let Some(eb) = else_body {
                asm.push_str(&format!("{}:\n", next));
                for s in eb { generate_statement(s, asm, assets, loop_labels)?; }
            } else if !elifs.is_empty() || simple_if {
                if next != end {
                    asm.push_str(&format!("{}:\n", next));
                }
            }
            asm.push_str(&format!("{}:\n", end));
        }

        Stmt::While { cond, body, .. } => {
            let ls = fresh_label("WH");
            let le = fresh_label("WH_END");
            let mut inner_labels = loop_labels.to_vec();
            inner_labels.push((le.clone(), ls.clone())); // break→end, continue→top
            asm.push_str(&format!("{}: ; while start\n", ls));
            // Same peephole as Stmt::If — direct compare-and-branch when applicable.
            expressions::emit_branch_if_false(cond, &le, asm, assets);
            for s in body { generate_statement(s, asm, assets, &inner_labels)?; }
            asm.push_str(&format!("    LBRA {}\n{}: ; while end\n", ls, le));
        }

        Stmt::Break { .. } => {
            if let Some((break_lbl, _)) = loop_labels.last() {
                asm.push_str(&format!("    LBRA {}  ; break\n", break_lbl));
            } else {
                return Err("break outside of loop".to_string());
            }
        }

        Stmt::Continue { .. } => {
            if let Some((_, continue_lbl)) = loop_labels.last() {
                asm.push_str(&format!("    LBRA {}  ; continue\n", continue_lbl));
            } else {
                return Err("continue outside of loop".to_string());
            }
        }

        Stmt::ForIn { var, iterable, body, source_line, .. } => {
            // `for v in xs` iterates a global array: its length is the compile-time
            // ARRAY_<NAME>_LEN and each element is read with the array's own
            // element size and sign (u8/i8 = 1 byte, untyped/i16/u16 = 2 bytes).
            let array_id = match iterable {
                Expr::Ident(id) => id,
                _ => {
                    return Err(format!(
                        "line {}: `for {} in ...` needs the name of a global array on m6809 (its length must be known at compile time)",
                        source_line, var
                    ))
                }
            };
            let (base_label_value, elem) = match context::resolve_array(&array_id.name) {
                Some((context::ArrayBase::Label(label), elem)) => (label, elem),
                Some((context::ArrayBase::Pointer(_), _)) => {
                    return Err(format!(
                        "line {}: `for {} in {}`: '{}' is a parameter, so its length is not known at compile time on m6809. \
                         Pass the length as another argument and use `for i in range(0, n)`.",
                        source_line, var, array_id.name, array_id.name
                    ))
                }
                None => return Err(not_an_array_error(&array_id.name, *source_line)),
            };

            let ls = fresh_label("FI");
            let li = fresh_label("FI_INC");  // continue target
            let le = fresh_label("FI_END");
            let mut inner_labels = loop_labels.to_vec();
            inner_labels.push((le.clone(), li.clone()));

            let var_label  = expressions::resolve_var_label(var);
            let var_size   = context::get_var_size(var);
            // The counter is a local of the function (frame slot); the array base
            // and length are link-time constants, used as immediates.
            let ctr_label  = expressions::resolve_var_label(&super::frames::for_in_counter_name(*source_line));
            let len_value  = format!("ARRAY_{}_LEN", array_id.name.to_uppercase());

            // Init counter = 0
            asm.push_str("    LDD #0\n");
            asm.push_str(&format!("    STD >{}\n", ctr_label));

            asm.push_str(&format!("{}: ; forin start\n", ls));
            // Condition: ctr < len
            asm.push_str(&format!("    LDD >{}\n", ctr_label));
            asm.push_str(&format!("    CMPD #{}  ; array {} length\n", len_value, array_id.name));
            asm.push_str(&format!("    LBGE {}\n", le));

            // Load element: var = base[ctr * element size]
            asm.push_str(&format!("    LDD >{}\n", ctr_label));
            if elem.bytes == 2 {
                asm.push_str("    ASLB\n");
                asm.push_str("    ROLA                ; D = ctr * 2 (16-bit elements)\n");
            }
            // Same addressing as `xs[i]` (emit_index): LDX #base is the form the
            // multibank linker relocates when a const array moves to the helpers bank.
            asm.push_str(&format!("    LDX #{}  ; array {} base address\n", base_label_value, array_id.name));
            asm.push_str("    LEAX D,X            ; X = base + offset\n");
            if elem.bytes == 1 {
                if elem.signed {
                    asm.push_str("    LDB ,X              ; B = arr[ctr] (8-bit element)\n");
                    asm.push_str("    SEX                 ; i8: sign-extend\n");
                } else {
                    asm.push_str("    CLRA                ; u8: zero-extend\n");
                    asm.push_str("    LDB ,X              ; B = arr[ctr] (8-bit element)\n");
                }
            } else {
                asm.push_str("    LDD ,X              ; D = arr[ctr]\n");
            }
            if var_size.bytes == 1 {
                asm.push_str(&format!("    STB >{}\n", var_label));
            } else {
                asm.push_str(&format!("    STD >{}\n", var_label));
            }

            for s in body { generate_statement(s, asm, assets, &inner_labels)?; }

            // Continue target: increment counter
            asm.push_str(&format!("{}: ; forin inc\n", li));
            asm.push_str(&format!("    LDD >{}\n", ctr_label));
            asm.push_str("    ADDD #1\n");
            asm.push_str(&format!("    STD >{}\n", ctr_label));
            asm.push_str(&format!("    LBRA {}\n", ls));
            asm.push_str(&format!("{}: ; forin end\n", le));
        }

        Stmt::For { var, start, end, step, body, .. } => {
            let ls = fresh_label("FR");
            let li = fresh_label("FR_INC");
            let le = fresh_label("FR_END");
            let mut inner_labels = loop_labels.to_vec();
            inner_labels.push((le.clone(), li.clone()));

            // The loop variable is loaded/stored with its own width (a global may be 8-bit).
            let var_label = expressions::resolve_var_label(var);
            let store = if context::get_var_size(var).bytes == 1 { "STB" } else { "STD" };
            let var_expr = Expr::Ident(vpy_parser::IdentInfo { name: var.clone(), source_line: 0, col: 0 });

            // Init loop variable = start
            expressions::emit_simple_expr(start, asm, assets);
            asm.push_str(&format!("    {} >{}\n", store, var_label));

            asm.push_str(&format!("{}: ; for start\n", ls));

            // Condition: var < end
            expressions::emit_simple_expr(end, asm, assets);
            asm.push_str("    STD >TMPVAL         ; for limit\n");
            expressions::emit_simple_expr(&var_expr, asm, assets);
            asm.push_str("    CMPD >TMPVAL\n");
            asm.push_str(&format!("    LBGE {}\n", le));

            for s in body { generate_statement(s, asm, assets, &inner_labels)?; }

            asm.push_str(&format!("{}: ; for inc\n", li));
            if let Some(step_expr) = step {
                expressions::emit_simple_expr(step_expr, asm, assets);
                asm.push_str("    STD >TMPVAL\n");
                expressions::emit_simple_expr(&var_expr, asm, assets);
                asm.push_str("    ADDD >TMPVAL\n");
            } else {
                expressions::emit_simple_expr(&var_expr, asm, assets);
                asm.push_str("    ADDD #1\n");
            }
            asm.push_str(&format!("    {} >{}\n", store, var_label));
            asm.push_str(&format!("    LBRA {}\n", ls));
            asm.push_str(&format!("{}: ; for end\n", le));
        }

        Stmt::Switch { expr, cases, default, .. } => {
            let le = fresh_label("SW_END");

            // Evaluate switch expression once, store to TMPVAL
            expressions::emit_simple_expr(expr, asm, assets);
            asm.push_str("    STD >TMPVAL         ; switch value\n");

            for (ci, (case_val, case_body)) in cases.iter().enumerate() {
                let no_match = fresh_label("SW_NXT");
                // A case body ends with LBRA end, so TMPVAL only has to survive the
                // case VALUES. A constant compares directly; any other case value may
                // use TMPVAL itself, so the switch value waits on the stack meanwhile.
                if let Some(k) = expressions::try_extract_int_literal(case_val) {
                    asm.push_str("    LDD >TMPVAL\n");
                    asm.push_str(&format!("    CMPD #{}            ; case value\n", k));
                } else {
                    asm.push_str("    LDD >TMPVAL\n");
                    asm.push_str("    PSHS D              ; switch value\n");
                    expressions::emit_simple_expr(case_val, asm, assets);
                    asm.push_str("    STD >TMPPTR         ; case value\n");
                    asm.push_str("    PULS D\n");
                    asm.push_str("    STD >TMPVAL\n");
                    asm.push_str("    CMPD >TMPPTR\n");
                }
                asm.push_str(&format!("    LBNE {}\n", no_match));
                for s in case_body { generate_statement(s, asm, assets, loop_labels)?; }
                asm.push_str(&format!("    LBRA {}\n", le));
                asm.push_str(&format!("{}: ; case {}\n", no_match, ci));
            }

            if let Some(default_body) = default {
                for s in default_body { generate_statement(s, asm, assets, loop_labels)?; }
            }

            asm.push_str(&format!("{}: ; switch end\n", le));
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
    bank0_asm.push_str("    CLR VPY_MOVE_X        ; MOVE offset defaults to 0\n");
    bank0_asm.push_str("    CLR VPY_MOVE_Y        ; MOVE offset defaults to 0\n");
    bank0_asm.push_str("    CLR DRAW_VEC_INTENSITY ; 0 = use recorded/vector intensity (no override)\n");
    if crate::m6809::level::needs_level_runtime(module) {
        bank0_asm.push_str("    ; Init camera ONCE at boot (RAM not zero-init). LOAD_LEVEL must NOT\n");
        bank0_asm.push_str("    ; reset it (matches pitrex): the game sets it via SET_CAMERA_Y before\n");
        bank0_asm.push_str("    ; LOAD_LEVEL/SPAWN, and GET_LEVEL_FLOOR_Y / the spawn Y-filter read it.\n");
        bank0_asm.push_str("    LDD #0\n");
        bank0_asm.push_str("    STD >CAMERA_X\n");
        bank0_asm.push_str("    STD >CAMERA_Y\n");
    }
    if has_print_calls(module) {
        bank0_asm.push_str("    LDA #$F8\n");
        bank0_asm.push_str("    STA TEXT_SCALE_H      ; Default height = -8 (normal size)\n");
        bank0_asm.push_str("    LDA #$48\n");
        bank0_asm.push_str("    STA TEXT_SCALE_W      ; Default width = 72 (normal size)\n");
    }
    if has_draw_scale_calls(module) {
        bank0_asm.push_str("    LDA #$7F\n");
        bank0_asm.push_str("    STA DRAW_SCALE        ; Default T1 scale = $7F (127 = full BIOS scale)\n");
    }
    if has_draw_anim_calls(module) {
        bank0_asm.push_str("    LDA #$7F\n");
        bank0_asm.push_str("    STA DRAW_ANIM_SCALE   ; Default anim scale = $7F (127 = full BIOS scale)\n");
        bank0_asm.push_str("    CLR DRAW_ANIM_SPEED_MUL ; Default speed=0 (use vanim timing)\n");
        // Zero per-animation state RAM (frame_idx, ticks_left) — see single-bank branch above.
        for anim_name in collect_draw_anim_names(module) {
            bank0_asm.push_str(&format!("    CLR ANIM_{}_STATE     ; frame_idx = 0\n", anim_name));
            bank0_asm.push_str(&format!("    CLR ANIM_{}_STATE+1   ; ticks_left = 0 (forces DAR_INIT)\n", anim_name));
        }
    }
    if has_note_calls(module) {
        bank0_asm.push_str("    ; Initialize NOTE_STATE channel IDs (pre-clear active flags)\n");
        bank0_asm.push_str("    LDA #0\n");
        bank0_asm.push_str("    STA NOTE_STATE        ; channel A: id=0\n");
        bank0_asm.push_str("    CLR NOTE_STATE+1      ; active=0\n");
        bank0_asm.push_str("    LDA #1\n");
        bank0_asm.push_str("    STA NOTE_STATE+10     ; channel B: id=1\n");
        bank0_asm.push_str("    CLR NOTE_STATE+11     ; active=0\n");
        bank0_asm.push_str("    LDA #2\n");
        bank0_asm.push_str("    STA NOTE_STATE+20     ; channel C: id=2\n");
        bank0_asm.push_str("    CLR NOTE_STATE+21     ; active=0\n");
    }
    let mut array_copy_counter = 0;
    for item in &module.items {
        if let vpy_parser::Item::GlobalLet { name, value, .. } = item {
            if let vpy_parser::Expr::List(elements) = value {
                emit_mutable_array_init(name, elements.len(), array_copy_counter, &mut bank0_asm);
                array_copy_counter += 1;
            } else {
                // Non-array: emit value (handles Number, Ident→const, expressions)
                emit_global_init(name, value, &mut bank0_asm, assets);
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
        bank0_asm.push_str("    JSR $F1BA    ; Read_Btns: PSG reg14 -> $C80F (active-HIGH), edge -> $C811\n");
        // Auto-inject Joy_Analog ONCE per frame (same rationale as single-bank path).
        if has_joystick_analog_calls(module) {
            bank0_asm.push_str("    JSR $F1AA    ; DP_to_D0 (Joy_Analog requires DP=$D0)\n");
            bank0_asm.push_str("    JSR $F1F5    ; Joy_Analog: poll all 4 axes once → $C81B-$C81E\n");
            bank0_asm.push_str("    JSR Reset0Ref ; Restore beam state after Joy_Analog\n");
            bank0_asm.push_str("    JSR $F1AF    ; DP_to_C8 (restore DP for RAM access)\n");
        }
        if has_beep_calls(module) {
            bank0_asm.push_str("    JSR BEEP_UPDATE_RUNTIME  ; Auto-injected: tick beep countdown timer\n");
        }
        if has_note_calls(module) {
            bank0_asm.push_str("    JSR NOTE_UPDATE_RUNTIME  ; Auto-injected: tick note timers + arpeggio\n");
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
        bank0_asm.push_str("    JSR $F1BA    ; Read_Btns: PSG reg14 -> $C80F (active-HIGH), edge -> $C811\n");
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
        asm.push_str(&format!("{}:\n", vpy_parser::symbols::m6809_label(&func.name)));
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

/// Does `e` contain no call (so evaluating it twice is the same as once)?
fn has_no_calls(e: &Expr) -> bool {
    let mut calls = false;
    super::ast_walk::walk_expr(e, &mut super::ast_walk::ExprFn(|x: &Expr| {
        calls |= matches!(x, Expr::Call(_) | Expr::MethodCall(_));
    }));
    !calls
}
