// ASM to Binary Converter - Convierte código M6809 assembly a binario
// Esto reemplaza la dependencia de lwasm con generación nativa

use std::collections::HashMap;
use std::path::PathBuf;
use std::fs;
use crate::backend::m6809_binary_emitter::BinaryEmitter;

// Global variable to store include directory (set before assembly)
static mut INCLUDE_DIR: Option<PathBuf> = None;

pub fn set_include_dir(dir: Option<PathBuf>) {
    unsafe {
        INCLUDE_DIR = dir;
    }
}

/// Convierte código M6809 assembly a formato binario
/// Retorna (bytes_binarios, linea_vpy -> offset_binario, symbol_table)
pub fn assemble_m6809(asm_source: &str, org: u16) -> Result<(Vec<u8>, HashMap<usize, usize>, HashMap<String, u16>), String> {
    let mut emitter = BinaryEmitter::new(org);
    let mut equates: HashMap<String, u16> = HashMap::new(); // Para directivas EQU
    
    // SIEMPRE cargar símbolos de Vectrex BIOS al inicio
    load_vectrex_symbols(&mut equates);
    
    // PRE-PASADA: Procesar TODO el archivo recolectando símbolos EQU e INCLUDE
    // Hacemos múltiples pasadas para resolver dependencias entre símbolos
    let lines: Vec<&str> = asm_source.lines().collect();
    let mut unresolved_equs: Vec<(String, String)> = Vec::new(); // (nombre, expresión)
    let mut max_iterations = 10;
    
    // Primera pasada: Procesar INCLUDE y cargar EQU simples (valores literales)
    for line in &lines {
        let trimmed = line.trim();
        
        // Saltar vacías y comentarios
        if trimmed.is_empty() || trimmed.starts_with(';') || trimmed.starts_with('*') {
            continue;
        }
        
        // Procesar directivas INCLUDE
        if let Some(include_path) = parse_include_directive(trimmed) {
            // Procesar archivo incluido y cargar sus símbolos
            if let Err(e) = process_include_file(&include_path, &mut equates) {
                eprintln!("Warning: {}", e);
            }
            continue;
        }
        
        // Procesar EQU
        if let Some((name, expr)) = parse_equ_directive_raw(trimmed) {
            // Intentar evaluar la expresión
            match evaluate_expression(&expr, &equates) {
                Ok(value) => {
                    equates.insert(name, value);
                }
                Err(_) => {
                    // No se puede resolver todavía, guardar para después
                    unresolved_equs.push((name, expr));
                }
            }
        }
    }
    
    // Pasadas adicionales para resolver EQU que dependen de otros símbolos
    while !unresolved_equs.is_empty() && max_iterations > 0 {
        max_iterations -= 1;
        let mut still_unresolved = Vec::new();
        let previous_count = unresolved_equs.len();
        let current_unresolved = std::mem::take(&mut unresolved_equs);
        
        for (name, expr) in current_unresolved {
            match evaluate_expression(&expr, &equates) {
                Ok(value) => {
                    equates.insert(name, value);
                }
                Err(_) => {
                    still_unresolved.push((name, expr));
                }
            }
        }
        
        // Si no se resolvió ninguno en esta iteración, romper el ciclo
        if still_unresolved.len() == previous_count {
            break;
        }
        
        unresolved_equs = still_unresolved;
    }
    
    // DEBUG: Check LEVEL_GP_BUFFER value after EQU resolution
    if let Some(&value) = equates.get("LEVEL_GP_BUFFER") {
        eprintln!("DEBUG: After EQU resolution, LEVEL_GP_BUFFER = 0x{:04X} ({})", value, value);
    }
    
    // Primera pasada: procesar etiquetas, EQU y generar código
    let mut current_line = 1;
    let mut last_global_label = String::from("_START");  // Track última etiqueta global para locales
    
    for line in asm_source.lines() {
        let trimmed = line.trim();
        
        // Saltar líneas vacías y comentarios
        if trimmed.is_empty() || trimmed.starts_with(';') || trimmed.starts_with('*') {
            current_line += 1;
            continue;
        }
        
        // Detectar línea de origen VPy desde comentarios especiales
        // Formato: ; VPy line 42
        if let Some(vpy_line) = parse_vpy_line_marker(trimmed) {
            emitter.set_source_line(vpy_line);
        }
        
        // Ignorar directivas EQU (ya procesadas en pre-pass)
        if trimmed.to_uppercase().contains(" EQU ") {
            current_line += 1;
            continue;
        }
        
        // Procesar directiva INCLUDE (ya procesado en PRE-PASS, ignorar aquí)
        if trimmed.to_uppercase().starts_with("INCLUDE") {
            current_line += 1;
            continue;
        }
        
        // Procesar etiquetas (terminan en :)
        if let Some(label) = parse_label(trimmed) {
            // Si es etiqueta local (empieza con .), prefijar con última global
            let full_label = if label.starts_with('.') {
                format!("{}{}", last_global_label, label)
            } else {
                last_global_label = label.to_string();
                label.to_string()
            };
            emitter.define_label(&full_label);
            
            // 🔍 TRACE: Definición de labels importantes y assets
            if full_label == "DSL_NEXT_PATH" || full_label == "DSL_LOOP" || full_label == "DSL_DONE" || full_label.contains("_MUSIC") || full_label.contains("_VECTORS") {
                eprintln!("🏷️  Line {}: Defined label '{}' at addr=${:04X} off={}", 
                    current_line, full_label, emitter.current_address, emitter.current_offset());
            }
            
            current_line += 1;
            continue;
        }
        
        // Procesar directivas ORG (cambio de dirección base)
        if trimmed.to_uppercase().starts_with("ORG") {
            // ORG ya se manejó al crear el emitter, ignorar
            current_line += 1;
            continue;
        }
        
        // 🔍 TRACE: Antes de procesar instrucción
        let trace_labels = ["DSL_LOOP", "DSL_NEXT_PATH", "DSL_DONE", "_PLAYER_VECTORS", "_TRIANGLE_VECTORS"];
        let should_trace = trace_labels.iter().any(|&l| last_global_label == l);
        if should_trace {
            eprintln!("🔍 Line {}: [{}] {} → addr=${:04X} off={}", 
                current_line, last_global_label, trimmed, emitter.current_address, emitter.current_offset());
        }
        
        // Procesar instrucciones y directivas de datos
        if let Err(e) = parse_and_emit_instruction(&mut emitter, trimmed, &equates, &last_global_label) {
            return Err(format!("Error en línea {}: {} (código: '{}')", current_line, e, trimmed));
        }
        
        // 🔍 TRACE: Después de procesar
        if should_trace {
            eprintln!("   ✓ After: addr=${:04X} off={} (delta={})", 
                emitter.current_address, emitter.current_offset(),
                emitter.current_offset() as i32 - (emitter.current_address as i32 - org as i32));
        }
        
        current_line += 1;
    }
    
    // Segunda pasada: resolver símbolos (incluyendo símbolos externos de BIOS)
    emitter.resolve_symbols_with_equates(&equates)?;
    
    // Obtener mapeo y symbols ANTES de finalizar (finalize consume emitter)
    let line_map = emitter.get_line_to_offset_map().clone();
    let symbol_table = emitter.get_symbol_table().clone();
    let binary = emitter.finalize();
    
    Ok((binary, line_map, symbol_table))
}

/// Extrae número de línea VPy desde comentario marcador
fn parse_vpy_line_marker(line: &str) -> Option<usize> {
    // Formato: ; VPy line 42
    if line.starts_with("; VPy line ") {
        let num_str = line.trim_start_matches("; VPy line ");
        num_str.parse::<usize>().ok()
    } else {
        None
    }
}

/// Parsea directiva EQU devolviendo la expresión sin evaluar (para pre-pass con dependencias)
fn parse_equ_directive_raw(line: &str) -> Option<(String, String)> {
    let upper = line.to_uppercase();
    if upper.contains(" EQU ") {
        let parts: Vec<&str> = line.splitn(2, |c: char| c.is_whitespace()).collect();
        if parts.len() >= 2 {
            let symbol = parts[0].trim().to_uppercase();
            let rest = parts[1..].join(" ");
            if let Some(value_part) = rest.split_whitespace().nth(1) {
                return Some((symbol, value_part.to_string()));
            }
        }
    }
    None
}

/// Parsea directiva EQU (formato: SYMBOL EQU $C800)
#[allow(dead_code)]
fn parse_equ_directive(line: &str) -> Option<(String, u16)> {
    let upper = line.to_uppercase();
    if upper.contains(" EQU ") {
        let parts: Vec<&str> = line.splitn(2, |c: char| c.is_whitespace()).collect();
        if parts.len() >= 2 {
            let symbol = parts[0].trim().to_uppercase();
            let rest = parts[1..].join(" ");
            if let Some(value_part) = rest.split_whitespace().nth(1) {
                if let Ok(value) = parse_address(value_part) {
                    return Some((symbol, value));
                }
            }
        }
    }
    None
}

/// Parsea directiva INCLUDE (formato: INCLUDE "file.I")
fn parse_include_directive(line: &str) -> Option<String> {
    let upper = line.to_uppercase();
    if upper.starts_with("INCLUDE") {
        // Extraer nombre de archivo entre comillas
        if let Some(start) = line.find('"') {
            if let Some(end) = line.rfind('"') {
                if end > start {
                    return Some(line[start+1..end].to_string());
                }
            }
        }
    }
    None
}

/// Resuelve path de INCLUDE buscando en directorios estándar
fn resolve_include_path(include_path: &str) -> Option<PathBuf> {
    // Priorizar el directorio especificado por --include-dir
    let base_dir = unsafe {
        INCLUDE_DIR.clone().or_else(|| std::env::current_dir().ok())
    }?;
    
    // Buscar workspace root (sube hasta encontrar Cargo.toml en root)
    let workspace_root = {
        let mut current = base_dir.clone();
        loop {
            if current.join("Cargo.toml").exists() && current.join("core").exists() {
                break Some(current);
            }
            match current.parent() {
                Some(p) => current = p.to_path_buf(),
                None => break None,
            }
        }
    };
    
    // Paths a intentar (en orden de prioridad)
    let mut search_paths = vec![
        // Desde el directorio base especificado
        base_dir.join(include_path),
        base_dir.join("include").join(include_path),
        base_dir.join("ide/frontend/public/include").join(include_path),
    ];
    
    // Agregar paths desde workspace root si se encontró
    if let Some(ws_root) = &workspace_root {
        search_paths.push(ws_root.join("include").join(include_path));
        search_paths.push(ws_root.join("ide/frontend/public/include").join(include_path));
    }
    
    // Paths adicionales (parent del base_dir)
    if let Some(parent) = base_dir.parent() {
        search_paths.push(parent.join(include_path));
        search_paths.push(parent.join("include").join(include_path));
        search_paths.push(parent.join("ide/frontend/public/include").join(include_path));
        
        // Dos niveles arriba (para casos como examples/jetpac/)
        if let Some(grandparent) = parent.parent() {
            search_paths.push(grandparent.join("include").join(include_path));
            search_paths.push(grandparent.join("ide/frontend/public/include").join(include_path));
        }
    }
    
    for path in search_paths {
        if path.exists() {
            return Some(path);
        }
    }
    
    None
}

/// Procesa archivo INCLUDE y extrae símbolos EQU
fn process_include_file(include_path: &str, equates: &mut HashMap<String, u16>) -> Result<(), String> {
    // Resolver path del archivo
    let resolved_path = resolve_include_path(include_path)
        .ok_or_else(|| format!("INCLUDE file not found: {}", include_path))?;
    
    // Leer contenido del archivo
    let content = fs::read_to_string(&resolved_path)
        .map_err(|e| format!("Error reading INCLUDE file {}: {}", include_path, e))?;
    
    // Parsear EQU del archivo incluido
    for line in content.lines() {
        let trimmed = line.trim();
        
        // Saltar vacías y comentarios
        if trimmed.is_empty() || trimmed.starts_with(';') || trimmed.starts_with('*') {
            continue;
        }
        
        // Procesar EQU
        if let Some((name, expr)) = parse_equ_directive_raw(trimmed) {
            // Intentar evaluar inmediatamente
            match evaluate_expression(&expr, equates) {
                Ok(value) => {
                    equates.insert(name, value);
                }
                Err(_) => {
                    // Si no se puede resolver, ignorar por ahora
                    // (será procesado en el pre-pass principal)
                }
            }
        }
    }
    
    Ok(())
}

/// Carga símbolos predefinidos de Vectrex (VECTREX.I + BIOS functions)
fn load_vectrex_symbols(equates: &mut HashMap<String, u16>) {
    // === SÍMBOLOS DE HARDWARE (VIA) ===
    equates.insert("VEC_DEFAULT_STK".to_string(), 0xCBEA);
    equates.insert("VIA_PORT_B".to_string(), 0xD000);
    equates.insert("VIA_PORT_A".to_string(), 0xD001);
    equates.insert("VIA_DDR_B".to_string(), 0xD002);
    equates.insert("VIA_DDR_A".to_string(), 0xD003);
    equates.insert("VIA_T1_CNT_LO".to_string(), 0xD004);
    equates.insert("VIA_T1_CNT_HI".to_string(), 0xD005);
    equates.insert("VIA_T1_LCH_LO".to_string(), 0xD006);
    equates.insert("VIA_T1_LCH_HI".to_string(), 0xD007);
    equates.insert("VIA_T2_LO".to_string(), 0xD008);
    equates.insert("VIA_T2_HI".to_string(), 0xD009);
    equates.insert("VIA_SHIFT_REG".to_string(), 0xD00A);
    equates.insert("VIA_AUX_CNTL".to_string(), 0xD00B);
    equates.insert("VIA_CNTL".to_string(), 0xD00C);
    equates.insert("VIA_INT_FLAGS".to_string(), 0xD00D);
    equates.insert("VIA_INT_ENABLE".to_string(), 0xD00E);
    equates.insert("VIA_PORT_A_NH".to_string(), 0xD00F);
    
    // === FUNCIONES DE BIOS (ROM 0xE000-0xFFFF) ===
    // Funciones principales de vectores/líneas
    equates.insert("WAIT_RECAL".to_string(), 0xF192);
    equates.insert("Wait_Recal".to_string(), 0xF192); // Mixed case variant
    equates.insert("MOVETO_D".to_string(), 0xF312);
    equates.insert("Moveto_d".to_string(), 0xF312); // Mixed case variant
    equates.insert("MOVETO_IX_FF".to_string(), 0xF34C);
    equates.insert("MOVETO_IX".to_string(), 0xF34F);
    equates.insert("MOVETO_D_7F".to_string(), 0xF35F);
    equates.insert("ZERO_REF".to_string(), 0xF35B);
    equates.insert("Zero_Ref".to_string(), 0xF35B); // Mixed case variant
    equates.insert("DRAW_LINEC".to_string(), 0xF3DF);
    equates.insert("DRAW_LINE_D".to_string(), 0xF3DD);
    equates.insert("Draw_Line_d".to_string(), 0xF3DD); // Mixed case variant
    equates.insert("DRAW_VLC".to_string(), 0xF408);
    equates.insert("DRAW_VL_MODE".to_string(), 0xF40C);
    equates.insert("DRAW_VL_A".to_string(), 0xF40E);
    equates.insert("DRAW_VL_B".to_string(), 0xF410);
    equates.insert("DRAW_VL".to_string(), 0xF413);
    
    // Funciones de texto
    equates.insert("PRINT_STR_D".to_string(), 0xF373);
    equates.insert("PRINT_STR".to_string(), 0xF37A);
    equates.insert("PRINT_LIST".to_string(), 0xF385);
    equates.insert("PRINT_SHIPS".to_string(), 0xF391);
    equates.insert("PRINT_SHIP".to_string(), 0xF393);
    
    // Funciones de audio
    equates.insert("DO_SOUND".to_string(), 0xF289);
    equates.insert("INIT_MUSIC".to_string(), 0xF533);
    equates.insert("INIT_MUSIC_CHK".to_string(), 0xF533);
    
    // Inicialización
    equates.insert("INIT_VIA".to_string(), 0xF14C);
    equates.insert("INIT_OS".to_string(), 0xF18B);
    equates.insert("INIT_OS_RAM".to_string(), 0xF164);
    equates.insert("DP_TO_C8".to_string(), 0xF1AA);
    equates.insert("INTENSITY_A".to_string(), 0xF2AB);
    equates.insert("Intensity_a".to_string(), 0xF2AB); // Mixed case variant
    equates.insert("INTENSITY_5F".to_string(), 0xF2A9);
    
    // Joystick y controles
    equates.insert("JOY_DIGITAL".to_string(), 0xF1F5);
    equates.insert("JOY_ANALOG".to_string(), 0xF1F8);
    equates.insert("READ_BTNS".to_string(), 0xF1BA);
    
    // Random y utilidades
    equates.insert("RANDOM".to_string(), 0xF517);
    equates.insert("RANDOM_3".to_string(), 0xF511);
    
    // Explosiones y efectos
    equates.insert("EXPLOSION".to_string(), 0xF976);
    equates.insert("EXPLOSION_SND".to_string(), 0xF92E);
    
    // Variantes de nombres comunes (lowercase/mixed case)
    equates.insert("VIA_T1_CNT_LO".to_string(), 0xD004);
    
    // Variables del sistema Vectrex
    equates.insert("VEC_SND_SHADOW".to_string(), 0xC800);
    equates.insert("VEC_MUSIC_WORK".to_string(), 0xC856);
    
    // Music data placeholder
    equates.insert("MUSIC1".to_string(), 0x0000);
}

/// Extrae etiqueta si la línea la define
fn parse_label(line: &str) -> Option<&str> {
    // ✅ FIX: Remove inline comments BEFORE checking for labels
    // Comments can contain ':' which would be incorrectly detected as labels
    let code = if let Some(idx) = line.find(';') {
        &line[..idx]
    } else {
        line
    }.trim();
    
    if code.contains(':') && !code.starts_with(';') {
        let parts: Vec<&str> = code.splitn(2, ':').collect();
        if parts.len() > 0 {
            let label = parts[0].trim();
            if !label.is_empty() {
                return Some(label);
            }
        }
    }
    None
}

/// Parsea y emite una instrucción M6809
fn parse_and_emit_instruction(emitter: &mut BinaryEmitter, line: &str, equates: &HashMap<String, u16>, last_global_label: &str) -> Result<(), String> {
    // Remover comentarios inline
    let code = if let Some(idx) = line.find(';') {
        &line[..idx]
    } else {
        line
    }.trim();
    
    if code.is_empty() {
        return Ok(());
    }
    
    // Separar mnemónico de operandos
    let parts: Vec<&str> = code.splitn(2, char::is_whitespace).collect();
    let mnemonic = parts[0].to_uppercase();
    let operand = if parts.len() > 1 { parts[1].trim() } else { "" };
    
    // DEBUG: Ver TODAS las instrucciones indexadas
    if operand.contains(',') && operand.len() <= 6 && !operand.contains("++") {
        eprintln!("🔎 parse_and_emit: {} '{}' (full line: '{}')", mnemonic, operand, code);
    }
    
    // Despachar según mnemónico
    match mnemonic.as_str() {
        // === DIRECTIVAS DE DATOS ===
        "FCC" => emit_fcc(emitter, operand),
        "FCB" | "DB" => emit_fcb(emitter, operand),  // DB es alias común (Frogger usa DB)
        "FDB" | "FDW" | "DW" => emit_fdb(emitter, operand, equates),  // DW es alias común (Frogger usa DW)
        "RMB" => emit_rmb(emitter, operand),
        "ZMB" => emit_zmb(emitter, operand),
        // === LOAD/STORE ===
        "LDA" => emit_lda(emitter, operand, equates),
        "LDB" => emit_ldb(emitter, operand, equates),
        "LDD" => emit_ldd(emitter, operand, equates),
        "STA" => emit_sta(emitter, operand, equates),
        "STB" => emit_stb(emitter, operand, equates),
        "STD" => emit_std(emitter, operand, equates),
        
        // === CONTROL FLOW ===
        "JSR" => emit_jsr(emitter, operand, last_global_label),
        "BSR" => emit_bsr(emitter, operand, last_global_label),
        "RTS" => { emitter.rts(); Ok(()) },
        "NOP" => { emitter.nop(); Ok(()) },
        "BRA" => emit_bra(emitter, operand, last_global_label),
        "BEQ" => emit_beq(emitter, operand, last_global_label),
        "BNE" => emit_bne(emitter, operand, last_global_label),
        "BCC" => emit_bcc(emitter, operand, last_global_label),
        "BCS" => emit_bcs(emitter, operand, last_global_label),
        "BHS" => emit_bcc(emitter, operand, last_global_label), // Alias de BCC (Branch if Higher or Same)
        "BLO" => emit_bcs(emitter, operand, last_global_label), // Alias de BCS (Branch if LOwer)
        "BLE" => emit_ble(emitter, operand, last_global_label),
        "BGT" => emit_bgt(emitter, operand, last_global_label),
        "BLT" => emit_blt(emitter, operand, last_global_label),
        "BGE" => emit_bge(emitter, operand, last_global_label),
        "BPL" => emit_bpl(emitter, operand, last_global_label),
        "BMI" => emit_bmi(emitter, operand, last_global_label),
        "BVC" => emit_bvc(emitter, operand, last_global_label),
        "BVS" => emit_bvs(emitter, operand, last_global_label),
        "BHI" => emit_bhi(emitter, operand, last_global_label),
        "BLS" => emit_bls(emitter, operand, last_global_label),
        
        // === LONG BRANCHES (16-bit offset) ===
        "LBRA" => emit_lbra(emitter, operand, last_global_label),
        "LBEQ" => emit_lbeq(emitter, operand, last_global_label),
        "LBNE" => emit_lbne(emitter, operand, last_global_label),
        "LBCS" => emit_lbcs(emitter, operand, last_global_label),
        "LBCC" => emit_lbcc(emitter, operand, last_global_label),
        "LBHS" => emit_lbcc(emitter, operand, last_global_label), // LBHS = LBCC (branch if higher or same)
        "LBLO" => emit_lbcs(emitter, operand, last_global_label), // LBLO = LBCS (branch if lower)
        "LBHI" => emit_lbhi(emitter, operand, last_global_label),
        "LBLS" => emit_lbls(emitter, operand, last_global_label),
        "LBLT" => emit_lblt(emitter, operand, last_global_label),
        "LBGE" => emit_lbge(emitter, operand, last_global_label),
        "LBGT" => emit_lbgt(emitter, operand, last_global_label),
        "LBLE" => emit_lble(emitter, operand, last_global_label),
        "LBMI" => emit_lbmi(emitter, operand, last_global_label),
        "LBPL" => emit_lbpl(emitter, operand, last_global_label),
        
        // === ARITHMETIC ===
        "ADDA" => emit_adda(emitter, operand, equates),
        "ADDB" => emit_addb(emitter, operand, equates),
        "ADDD" => emit_addd(emitter, operand, equates),
        "SUBA" => emit_suba(emitter, operand, equates),
        "SUBB" => emit_subb(emitter, operand, equates),
        "SUBD" => emit_subd(emitter, operand, equates),
        "SBCA" => emit_sbca(emitter, operand, equates),
        "SBCB" => emit_sbcb(emitter, operand, equates),
        
        // === LOGIC ===
        "ANDA" => emit_anda(emitter, operand, equates),
        "ANDB" => emit_andb(emitter, operand, equates),
        "BITA" => emit_bita(emitter, operand, equates),
        "BITB" => emit_bitb(emitter, operand, equates),
        "ORB" => emit_orb(emitter, operand, equates),
        "ORA" => emit_ora(emitter, operand, equates),
        "EORA" => emit_eora(emitter, operand, equates),
        
        // === REGISTER OPS ===
        "CLRA" => { emitter.clra(); Ok(()) },
        "CLRB" => { emitter.clrb(); Ok(()) },
        "CLR" => emit_clr(emitter, operand, equates),
        "INCA" => { emitter.inca(); Ok(()) },
        "INCB" => { emitter.incb(); Ok(()) },
        "INC" => emit_inc(emitter, operand, equates),
        "DECA" => { emitter.deca(); Ok(()) },
        "DECB" => { emitter.decb(); Ok(()) },
        "DEC" => emit_dec(emitter, operand, equates),
        "ASLA" | "LSLA" => { emitter.asla(); Ok(()) },  // LSLA es alias de ASLA
        "ASLB" | "LSLB" => { emitter.aslb(); Ok(()) },  // LSLB es alias de ASLB
        "ROLA" => { emitter.rola(); Ok(()) },
        "ROLB" => { emitter.rolb(); Ok(()) },
        "LSRA" => { emitter.lsra(); Ok(()) },
        "LSRB" => { emitter.lsrb(); Ok(()) },
        "ASRA" => { emitter.asra(); Ok(()) },
        "ASRB" => { emitter.asrb(); Ok(()) },
        "CLRA" => { emitter.clra(); Ok(()) },
        "RORA" => { emitter.rora(); Ok(()) },
        "RORB" => { emitter.rorb(); Ok(()) },
        "ABX" => { emitter.abx(); Ok(()) },
        "MUL" => { emitter.mul(); Ok(()) },
        "TSTA" => { emitter.tsta(); Ok(()) },
        "TSTB" => { emitter.tstb(); Ok(()) },
        "TST" => emit_tst(emitter, operand, equates),
        "NEGA" => { emitter.nega(); Ok(()) },
        "NEGB" => { emitter.negb(); Ok(()) },
        "COMA" => { emitter.coma(); Ok(()) },
        "COMB" => { emitter.comb(); Ok(()) },
        "SEX" => { emitter.sex(); Ok(()) },
        "EXCH" => { emitter.exch(); Ok(()) },
        
        // === TRANSFER/COMPARE ===
        "TFR" => emit_tfr(emitter, operand),
        "CMPA" => emit_cmpa(emitter, operand, equates),
        "CMPB" => emit_cmpb(emitter, operand, equates),
        "CMPD" => emit_cmpd(emitter, operand, equates),
        "CMPX" => emit_cmpx(emitter, operand, equates),
        "CMPY" => emit_cmpy(emitter, operand, equates),
        "CMPU" => emit_cmpu(emitter, operand, equates),
        "CMPS" => emit_cmps(emitter, operand, equates),
        
        // === 16-BIT LOAD/STORE ===
        "JMP" => emit_jmp(emitter, operand),
        "LDX" => emit_ldx(emitter, operand, equates),
        "LDY" => emit_ldy(emitter, operand, equates),
        "LDU" => emit_ldu(emitter, operand, equates),
        "STX" => emit_stx(emitter, operand, equates),
        "STY" => emit_sty(emitter, operand, equates),
        "STU" => emit_stu(emitter, operand, equates),
        "LEAX" | "LEAY" | "LEAS" | "LEAU" => emit_lea(emitter, &mnemonic, operand),
        
        // === STACK OPS ===
        "PSHS" => emit_pshs(emitter, operand),
        "PSHU" => emit_pshu(emitter, operand),
        "PULS" => emit_puls(emitter, operand),
        "PULU" => emit_pulu(emitter, operand),
        
        _ => Err(format!("Instrucción no soportada: {}", mnemonic))
    }
}

// === HELPERS DE EMISIÓN POR INSTRUCCIÓN ===

/// Evalúa una expresión aritmética: SYMBOL+10, LABEL-2, etc.
fn evaluate_expression(expr: &str, equates: &HashMap<String, u16>) -> Result<u16, String> {
    let expr = expr.trim();
    
    // Detectar operadores + o -
    if let Some(pos) = expr.rfind('+') {
        let left = expr[..pos].trim();
        let right = expr[pos+1..].trim();
        
        // DEBUG: Log splits for diagnosis
        if expr.contains("C880") || expr.contains("C982") {
            eprintln!("DEBUG evaluate_expression: expr='{}' left='{}' right='{}'", expr, left, right);
        }
        
        let offset = evaluate_expression(right, equates)?; // Recursivo para right
        
        if expr.contains("C880") || expr.contains("C982") {
            eprintln!("DEBUG: offset parsed = 0x{:04X} ({})", offset, offset);
        }
        
        return match evaluate_expression(left, equates) {
            Ok(base) => {
                let result = base.wrapping_add(offset);
                if expr.contains("C880") || expr.contains("C982") {
                    eprintln!("DEBUG: base=0x{:04X} + offset=0x{:04X} = 0x{:04X}", base, offset, result);
                }
                Ok(result)
            },
            Err(e) if e.starts_with("SYMBOL:") => {
                // Preservar addend cuando el símbolo base aún no está resuelto (pass 2)
                if offset > i16::MAX as u16 {
                    return Err(format!("Addend fuera de rango (>{}): {}", i16::MAX, offset));
                }
                let sym = e.trim_start_matches("SYMBOL:");
                Err(format!("SYMBOL:{}+{}", sym, offset))
            }
            Err(e) => Err(e),
        };
    }
    
    if let Some(pos) = expr.rfind('-') {
        // Cuidado con números negativos como -127
        if pos > 0 {
            let left = expr[..pos].trim();
            let right = expr[pos+1..].trim();
            let offset = evaluate_expression(right, equates)?; // Recursivo para right
            return match evaluate_expression(left, equates) {
                Ok(base) => Ok(base.wrapping_sub(offset)),
                Err(e) if e.starts_with("SYMBOL:") => {
                    if offset > i16::MAX as u16 {
                        return Err(format!("Addend fuera de rango (>{}): {}", i16::MAX, offset));
                    }
                    let sym = e.trim_start_matches("SYMBOL:");
                    Err(format!("SYMBOL:{}-{}", sym, offset))
                }
                Err(e) => Err(e),
            };
        }
    }
    
    // No es una expresión, es un valor directo (símbolo o número)
    resolve_symbol_value(expr, equates)
}

/// Resuelve un símbolo a su valor numérico (con evaluación recursiva de expresiones)
fn resolve_symbol_value(symbol: &str, equates: &HashMap<String, u16>) -> Result<u16, String> {
    let upper = symbol.to_uppercase();
    
    // Primero verificar si está en equates (puede ser una expresión o valor directo)
    if let Some(&value) = equates.get(&upper) {
        // El valor en equates ya está resuelto (fue procesado en pre-pass)
        return Ok(value);
    }
    
    // Si no está en equates, intentar como literal numérico
    if symbol.starts_with('$') {
        parse_hex(&symbol[1..])
    } else if symbol.starts_with("0X") || symbol.starts_with("0x") {
        u16::from_str_radix(&symbol[2..], 16)
            .map_err(|_| format!("Valor hex inválido: {}", symbol))
    } else if symbol.chars().all(|c| c.is_digit(10)) {
        symbol.parse::<u16>()
            .map_err(|_| format!("Valor decimal inválido: {}", symbol))
    } else {
        // Es un símbolo no resuelto - podría ser una label que se resolverá en pass 2
        Err(format!("SYMBOL:{}", symbol))
    }
}

/// Parsea un número (decimal o hex)
#[allow(dead_code)]
fn parse_number(s: &str) -> Result<u16, String> {
    let s = s.trim();
    if s.starts_with('$') {
        parse_hex(&s[1..])
    } else if s.starts_with("0X") || s.starts_with("0x") {
        u16::from_str_radix(&s[2..], 16)
            .map_err(|_| format!("Número hex inválido: {}", s))
    } else {
        s.parse::<u16>()
            .map_err(|_| format!("Número decimal inválido: {}", s))
    }
}

/// Resuelve un operando como dirección, consultando primero el HashMap de equates
fn resolve_address(operand: &str, equates: &HashMap<String, u16>) -> Result<u16, String> {
    // Intentar evaluar como expresión primero
    evaluate_expression(operand, equates)
}

/// Extrae (symbol, addend) de un error "SYMBOL:...".
/// Soporta "SYMBOL:LABEL", "SYMBOL:LABEL+1", "SYMBOL:LABEL-2".
fn parse_symbol_and_addend(sym_err: &str) -> Result<(String, i16), String> {
    if !sym_err.starts_with("SYMBOL:") {
        return Err(format!("Error interno: se esperaba SYMBOL:, got: {}", sym_err));
    }

    let rest = sym_err.trim_start_matches("SYMBOL:").trim();

    if let Some(pos) = rest.rfind('+') {
        let sym = rest[..pos].trim();
        let n = rest[pos + 1..].trim();
        let off = parse_number(n)?;
        if off > i16::MAX as u16 {
            return Err(format!("Addend fuera de rango (>{}): {}", i16::MAX, off));
        }
        return Ok((sym.to_string(), off as i16));
    }

    if let Some(pos) = rest.rfind('-') {
        if pos > 0 {
            let sym = rest[..pos].trim();
            let n = rest[pos + 1..].trim();
            let off = parse_number(n)?;
            if off > i16::MAX as u16 {
                return Err(format!("Addend fuera de rango (>{}): {}", i16::MAX, off));
            }
            return Ok((sym.to_string(), -(off as i16)));
        }
    }

    Ok((rest.to_string(), 0))
}

/// Helper: Expande labels locales (empiezan con .) con el prefijo del último label global
/// También verifica si es un label válido (alfanumérico, guión bajo, punto)
fn expand_local_label(operand: &str, last_global: &str) -> String {
    if operand.starts_with('.') {
        format!("{}{}", last_global, operand)
    } else {
        operand.to_string()
    }
}

/// Helper: Verifica si un operando es un label (alfanumérico, guión bajo, o punto para locales)
fn is_label(operand: &str) -> bool {
    operand.chars().all(|c| c.is_alphanumeric() || c == '_' || c == '.')
}

fn emit_lda(emitter: &mut BinaryEmitter, operand: &str, equates: &HashMap<String, u16>) -> Result<(), String> {
    if operand.starts_with('#') {
        let val = parse_immediate(&operand[1..])?;
        emitter.lda_immediate(val);
    } else if operand.contains(',') {
        // Modo indexado: LDA ,X  LDA 5,Y  etc.
        let (postbyte, offset) = parse_indexed_mode(operand)?;
        emitter.lda_indexed(postbyte);
        if let Some(off) = offset {
            emitter.emit(off as u8);
        }
    } else if operand.starts_with('$') {
        let addr = parse_hex(&operand[1..])?;
        if addr <= 0xFF {
            emitter.lda_direct(addr as u8);
        } else {
            emitter.lda_extended(addr);
        }
    } else if operand.starts_with('<') {
        // Direct page forzado (lwasm compatibility)
        let addr = resolve_address(&operand[1..], equates)?;
        emitter.lda_direct((addr & 0xFF) as u8);
    } else if operand.starts_with('>') {
        // Extended mode forzado (lwasm compatibility)
        let addr = resolve_address(&operand[1..], equates)?;
        emitter.lda_extended(addr);
    } else if operand.chars().all(|c| c.is_alphanumeric() || c == '_') {
        // Símbolo - intentar resolver, sino usar referencia
        let upper = operand.to_uppercase();
        if let Some(&addr) = equates.get(&upper) {
            if addr <= 0xFF {
                emitter.lda_direct(addr as u8);
            } else {
                emitter.lda_extended(addr);
            }
        } else {
            emitter.lda_extended_sym(operand);
        }
    } else {
        let addr = resolve_address(operand, equates)?;
        if addr <= 0xFF {
            emitter.lda_direct(addr as u8);
        } else {
            emitter.lda_extended(addr);
        }
    }
    Ok(())
}

fn emit_ldb(emitter: &mut BinaryEmitter, operand: &str, equates: &HashMap<String, u16>) -> Result<(), String> {
    if operand.starts_with('#') {
        let val = parse_immediate(&operand[1..])?;
        emitter.ldb_immediate(val);
    } else if operand.contains(',') {
        // Modo indexado
        let (postbyte, offset) = parse_indexed_mode(operand)?;
        emitter.ldb_indexed(postbyte);
        if let Some(off) = offset {
            emitter.emit(off as u8);
        }
    } else if operand.starts_with('<') {
        // Direct page forzado (lwasm compatibility)
        let addr = resolve_address(&operand[1..], equates)?;
        emitter.ldb_direct((addr & 0xFF) as u8);
    } else if operand.starts_with('>') {
        // Extended mode forzado (lwasm compatibility)
        let addr = resolve_address(&operand[1..], equates)?;
        emitter.ldb_extended(addr);
    } else if operand.starts_with('$') {
        let addr = parse_hex(&operand[1..])?;
        if addr <= 0xFF {
            emitter.ldb_direct(addr as u8);
        } else {
            emitter.ldb_extended(addr);
        }
    } else {
        // Intentar evaluar como expresión (puede incluir símbolos y aritmética)
        match evaluate_expression(operand, equates) {
            Ok(addr) => {
                if addr <= 0xFF {
                    emitter.ldb_direct(addr as u8);
                } else {
                    emitter.ldb_extended(addr);
                }
            }
            Err(msg) => {
                // Si el error es "SYMBOL:xxx", agregar referencia para resolver en pass 2
                if msg.starts_with("SYMBOL:") {
                    let (symbol, addend) = parse_symbol_and_addend(&msg)?;
                    emitter.emit_extended_symbol_ref(0xF6, &symbol, addend); // LDB extended
                } else {
                    return Err(msg);
                }
            }
        }
    }
    Ok(())
}

fn emit_ldd(emitter: &mut BinaryEmitter, operand: &str, equates: &HashMap<String, u16>) -> Result<(), String> {
    if operand.starts_with('#') {
        let val = parse_immediate_16_with_symbols(&operand[1..], equates)?;
        emitter.ldd_immediate(val);
    } else if operand.starts_with('>') {
        // Force extended addressing (lwasm compatibility)
        let operand_without_prefix = &operand[1..];
        match resolve_address(operand_without_prefix, equates) {
            Ok(addr) => {
                emitter.ldd_extended(addr);
            },
            Err(e) if e.starts_with("SYMBOL:") => {
                let (symbol, addend) = parse_symbol_and_addend(&e)?;
                emitter.emit_extended_symbol_ref(0xFC, &symbol, addend); // LDD extended
            },
            Err(e) => return Err(e),
        }
    } else if operand.contains(',') {
        // Indexed mode - parse postbyte
        let (postbyte, offset) = parse_indexed_mode(operand)?;
        emitter.ldd_indexed(postbyte);
        if let Some(off) = offset {
            emitter.emit(off as u8);
        }
    } else {
        match resolve_address(operand, equates) {
            Ok(addr) => {
                emitter.ldd_extended(addr);
            },
            Err(e) if e.starts_with("SYMBOL:") => {
                let (symbol, addend) = parse_symbol_and_addend(&e)?;
                emitter.emit_extended_symbol_ref(0xFC, &symbol, addend); // LDD extended
            },
            Err(e) => return Err(e),
        }
    }
    Ok(())
}

fn emit_sta(emitter: &mut BinaryEmitter, operand: &str, equates: &HashMap<String, u16>) -> Result<(), String> {
    // Check if it's indexed addressing (contains comma: ,X  ,X+  5,Y  etc.)
    if operand.contains(',') {
        let (postbyte, offset) = parse_indexed_mode(operand)?;
        emitter.sta_indexed(postbyte);
        if let Some(off) = offset {
            emitter.emit(off as u8);
        }
        return Ok(());
    }
    
    // Handle < (force direct page) and > (force extended) operators
    if operand.starts_with('<') {
        let addr = resolve_address(&operand[1..], equates)?;
        emitter.sta_direct((addr & 0xFF) as u8);
        return Ok(());
    } else if operand.starts_with('>') {
        let addr = resolve_address(&operand[1..], equates)?;
        emitter.sta_extended(addr);
        return Ok(());
    }
    
    match resolve_address(operand, equates) {
        Ok(addr) => {
            if addr <= 0xFF {
                emitter.sta_direct(addr as u8);
            } else {
                emitter.sta_extended(addr);
            }
        },
        Err(e) if e.starts_with("SYMBOL:") => {
            let (symbol, addend) = parse_symbol_and_addend(&e)?;
            emitter.emit_extended_symbol_ref(0xB7, &symbol, addend); // STA extended
        },
        Err(e) => return Err(e),
    }
    Ok(())
}

fn emit_stb(emitter: &mut BinaryEmitter, operand: &str, equates: &HashMap<String, u16>) -> Result<(), String> {
    // Check if it's indexed addressing (contains comma: ,X  ,X+  5,Y  etc.)
    if operand.contains(',') {
        let (postbyte, offset) = parse_indexed_mode(operand)?;
        emitter.stb_indexed(postbyte);
        if let Some(off) = offset {
            emitter.emit(off as u8);
        }
        return Ok(());
    }
    
    // Handle < (force direct page) and > (force extended) operators
    if operand.starts_with('<') {
        let addr = resolve_address(&operand[1..], equates)?;
        emitter.stb_direct((addr & 0xFF) as u8);
        return Ok(());
    } else if operand.starts_with('>') {
        let addr = resolve_address(&operand[1..], equates)?;
        emitter.stb_extended(addr);
        return Ok(());
    }
    
    match resolve_address(operand, equates) {
        Ok(addr) => {
            if addr <= 0xFF {
                emitter.stb_direct(addr as u8);
            } else {
                emitter.stb_extended(addr);
            }
        },
        Err(e) if e.starts_with("SYMBOL:") => {
            let (symbol, addend) = parse_symbol_and_addend(&e)?;
            emitter.emit_extended_symbol_ref(0xF7, &symbol, addend); // STB extended
        },
        Err(e) => return Err(e),
    }
    Ok(())
}

fn emit_std(emitter: &mut BinaryEmitter, operand: &str, equates: &HashMap<String, u16>) -> Result<(), String> {
    if operand.contains(',') {
        // Indexed mode: 1,S  5,X  A,X  etc.
        let (postbyte, offset) = parse_indexed_mode(operand)?;
        emitter.std_indexed(postbyte);
        if let Some(off) = offset {
            emitter.emit(off as u8);
        }
        Ok(())
    } else if operand.starts_with('>') {
        // Extended mode forzado (lwasm compatibility)
        let operand_without_prefix = &operand[1..];
        match resolve_address(operand_without_prefix, equates) {
            Ok(addr) => {
                emitter.std_extended(addr);
            },
            Err(e) if e.starts_with("SYMBOL:") => {
                let (symbol, addend) = parse_symbol_and_addend(&e)?;
                emitter.emit_extended_symbol_ref(0xFD, &symbol, addend); // STD extended
            },
            Err(e) => return Err(e),
        }
        Ok(())
    } else {
        match resolve_address(operand, equates) {
            Ok(addr) => {
                emitter.std_extended(addr);
            },
            Err(e) if e.starts_with("SYMBOL:") => {
                let (symbol, addend) = parse_symbol_and_addend(&e)?;
                emitter.emit_extended_symbol_ref(0xFD, &symbol, addend); // STD extended
            },
            Err(e) => return Err(e),
        }
        Ok(())
    }
}

fn emit_jsr(emitter: &mut BinaryEmitter, operand: &str, last_global: &str) -> Result<(), String> {
    if operand.starts_with('$') {
        let addr = parse_hex(&operand[1..])?;
        emitter.jsr_extended(addr);
    } else if is_label(operand) {
        let full_label = expand_local_label(operand, last_global);
        emitter.jsr_extended_sym(&full_label);
    } else {
        let addr = parse_address(operand)?;
        emitter.jsr_extended(addr);
    }
    Ok(())
}

fn emit_bsr(emitter: &mut BinaryEmitter, operand: &str, last_global: &str) -> Result<(), String> {
    if is_label(operand) {
        let full_label = expand_local_label(operand, last_global);
        emitter.bsr_label(&full_label);
    } else {
        let offset = parse_signed(operand)?;
        emitter.bsr_offset(offset);
    }
    Ok(())
}

fn emit_bra(emitter: &mut BinaryEmitter, operand: &str, last_global: &str) -> Result<(), String> {
    if is_label(operand) {
        let full_label = expand_local_label(operand, last_global);
        emitter.bra_label(&full_label);
    } else {
        let offset = parse_signed(operand)?;
        emitter.bra_offset(offset);
    }
    Ok(())
}

fn emit_beq(emitter: &mut BinaryEmitter, operand: &str, last_global: &str) -> Result<(), String> {
    if is_label(operand) {
        let full_label = expand_local_label(operand, last_global);
        emitter.beq_label(&full_label);
    } else {
        let offset = parse_signed(operand)?;
        emitter.beq_offset(offset);
    }
    Ok(())
}

fn emit_bne(emitter: &mut BinaryEmitter, operand: &str, last_global: &str) -> Result<(), String> {
    if is_label(operand) {
        let full_label = expand_local_label(operand, last_global);
        emitter.bne_label(&full_label);
    } else {
        let offset = parse_signed(operand)?;
        emitter.bne_offset(offset);
    }
    Ok(())
}

fn emit_bcc(emitter: &mut BinaryEmitter, operand: &str, last_global: &str) -> Result<(), String> {
    if is_label(operand) {
        let full_label = expand_local_label(operand, last_global);
        emitter.emit(0x24); // BCC opcode
        emitter.add_symbol_ref(&full_label, true, 1); // Relative, 1-byte offset
        emitter.emit(0x00); // Placeholder
        Ok(())
    } else {
        let offset = parse_signed(operand)?;
        emitter.bcc_offset(offset);
        Ok(())
    }
}

fn emit_bcs(emitter: &mut BinaryEmitter, operand: &str, last_global: &str) -> Result<(), String> {
    if is_label(operand) {
        let full_label = expand_local_label(operand, last_global);
        emitter.emit(0x25); // BCS opcode
        emitter.add_symbol_ref(&full_label, true, 1); // Relative, 1-byte offset
        emitter.emit(0x00); // Placeholder
        Ok(())
    } else {
        let offset = parse_signed(operand)?;
        emitter.bcs_offset(offset);
        Ok(())
    }
}

fn emit_ble(emitter: &mut BinaryEmitter, operand: &str, last_global: &str) -> Result<(), String> {
    if is_label(operand) {
        let full_label = expand_local_label(operand, last_global);
        emitter.emit(0x2F); // BLE opcode
        emitter.add_symbol_ref(&full_label, true, 1); // Relative, 1-byte offset
        emitter.emit(0x00); // Placeholder
        Ok(())
    } else {
        let offset = parse_signed(operand)?;
        emitter.emit(0x2F);
        emitter.emit(offset as u8);
        Ok(())
    }
}

fn emit_bgt(emitter: &mut BinaryEmitter, operand: &str, last_global: &str) -> Result<(), String> {
    if is_label(operand) {
        let full_label = expand_local_label(operand, last_global);
        emitter.emit(0x2E);
        emitter.add_symbol_ref(&full_label, true, 1);
        emitter.emit(0x00);
        Ok(())
    } else {
        let offset = parse_signed(operand)?;
        emitter.emit(0x2E);
        emitter.emit(offset as u8);
        Ok(())
    }
}

fn emit_blt(emitter: &mut BinaryEmitter, operand: &str, last_global: &str) -> Result<(), String> {
    if is_label(operand) {
        let full_label = expand_local_label(operand, last_global);
        emitter.emit(0x2D);
        emitter.add_symbol_ref(&full_label, true, 1);
        emitter.emit(0x00);
        Ok(())
    } else {
        let offset = parse_signed(operand)?;
        emitter.emit(0x2D);
        emitter.emit(offset as u8);
        Ok(())
    }
}

fn emit_bge(emitter: &mut BinaryEmitter, operand: &str, last_global: &str) -> Result<(), String> {
    if is_label(operand) {
        let full_label = expand_local_label(operand, last_global);
        emitter.emit(0x2C);
        emitter.add_symbol_ref(&full_label, true, 1);
        emitter.emit(0x00);
        Ok(())
    } else {
        let offset = parse_signed(operand)?;
        emitter.emit(0x2C);
        emitter.emit(offset as u8);
        Ok(())
    }
}

fn emit_bpl(emitter: &mut BinaryEmitter, operand: &str, last_global: &str) -> Result<(), String> {
    if is_label(operand) {
        let full_label = expand_local_label(operand, last_global);
        emitter.emit(0x2A);
        emitter.add_symbol_ref(&full_label, true, 1);
        emitter.emit(0x00);
        Ok(())
    } else {
        let offset = parse_signed(operand)?;
        emitter.emit(0x2A);
        emitter.emit(offset as u8);
        Ok(())
    }
}

fn emit_bmi(emitter: &mut BinaryEmitter, operand: &str, last_global: &str) -> Result<(), String> {
    if is_label(operand) {
        let full_label = expand_local_label(operand, last_global);
        emitter.emit(0x2B);
        emitter.add_symbol_ref(&full_label, true, 1);
        emitter.emit(0x00);
        Ok(())
    } else {
        let offset = parse_signed(operand)?;
        emitter.emit(0x2B);
        emitter.emit(offset as u8);
        Ok(())
    }
}

fn emit_bvc(emitter: &mut BinaryEmitter, operand: &str, last_global: &str) -> Result<(), String> {
    if is_label(operand) {
        let full_label = expand_local_label(operand, last_global);
        emitter.emit(0x28);
        emitter.add_symbol_ref(&full_label, true, 1);
        emitter.emit(0x00);
        Ok(())
    } else {
        let offset = parse_signed(operand)?;
        emitter.emit(0x28);
        emitter.emit(offset as u8);
        Ok(())
    }
}

fn emit_bvs(emitter: &mut BinaryEmitter, operand: &str, last_global: &str) -> Result<(), String> {
    if is_label(operand) {
        let full_label = expand_local_label(operand, last_global);
        emitter.emit(0x29);
        emitter.add_symbol_ref(&full_label, true, 1);
        emitter.emit(0x00);
        Ok(())
    } else {
        let offset = parse_signed(operand)?;
        emitter.emit(0x29);
        emitter.emit(offset as u8);
        Ok(())
    }
}

fn emit_bhi(emitter: &mut BinaryEmitter, operand: &str, last_global: &str) -> Result<(), String> {
    if is_label(operand) {
        let full_label = expand_local_label(operand, last_global);
        emitter.emit(0x22);
        emitter.add_symbol_ref(&full_label, true, 1);
        emitter.emit(0x00);
        Ok(())
    } else {
        let offset = parse_signed(operand)?;
        emitter.emit(0x22);
        emitter.emit(offset as u8);
        Ok(())
    }
}

fn emit_bls(emitter: &mut BinaryEmitter, operand: &str, last_global: &str) -> Result<(), String> {
    if is_label(operand) {
        let full_label = expand_local_label(operand, last_global);
        emitter.emit(0x23);
        emitter.add_symbol_ref(&full_label, true, 1);
        emitter.emit(0x00);
        Ok(())
    } else {
        let offset = parse_signed(operand)?;
        emitter.emit(0x23);
        emitter.emit(offset as u8);
        Ok(())
    }
}

// === LONG BRANCHES (16-bit offset) ===
// MC6809 long branches use 2-byte opcode prefix (0x10) + condition byte + 16-bit offset

fn emit_lbra(emitter: &mut BinaryEmitter, operand: &str, last_global: &str) -> Result<(), String> {
    if is_label(operand) {
        emitter.emit(0x16); // LBRA opcode
        let full_label = expand_local_label(operand, last_global);
        emitter.add_symbol_ref(&full_label, true, 2); // Relative, 2-byte offset
        emitter.emit_word(0x0000); // Placeholder
        Ok(())
    } else {
        let offset = parse_signed(operand)?;
        emitter.emit(0x16);
        emitter.emit_word(offset as u16);
        Ok(())
    }
}

fn emit_lbeq(emitter: &mut BinaryEmitter, operand: &str, last_global: &str) -> Result<(), String> {
    if is_label(operand) {
        emitter.emit(0x10); // Long branch prefix
        emitter.emit(0x27); // BEQ condition
        let full_label = expand_local_label(operand, last_global);
        emitter.add_symbol_ref(&full_label, true, 2); // Relative, 2-byte offset
        emitter.emit_word(0x0000); // Placeholder
        Ok(())
    } else {
        let offset = parse_signed(operand)?;
        emitter.emit(0x10);
        emitter.emit(0x27);
        emitter.emit_word(offset as u16);
        Ok(())
    }
}

fn emit_lbne(emitter: &mut BinaryEmitter, operand: &str, last_global: &str) -> Result<(), String> {
    if is_label(operand) {
        emitter.emit(0x10);
        emitter.emit(0x26); // BNE condition
        let full_label = expand_local_label(operand, last_global);
        emitter.add_symbol_ref(&full_label, true, 2);
        emitter.emit_word(0x0000);
        Ok(())
    } else {
        let offset = parse_signed(operand)?;
        emitter.emit(0x10);
        emitter.emit(0x26);
        emitter.emit_word(offset as u16);
        Ok(())
    }
}

fn emit_lbcs(emitter: &mut BinaryEmitter, operand: &str, last_global: &str) -> Result<(), String> {
    if is_label(operand) {
        emitter.emit(0x10);
        emitter.emit(0x25); // BCS condition
        let full_label = expand_local_label(operand, last_global);
        emitter.add_symbol_ref(&full_label, true, 2);
        emitter.emit_word(0x0000);
        Ok(())
    } else {
        let offset = parse_signed(operand)?;
        emitter.emit(0x10);
        emitter.emit(0x25);
        emitter.emit_word(offset as u16);
        Ok(())
    }
}

fn emit_lbcc(emitter: &mut BinaryEmitter, operand: &str, last_global: &str) -> Result<(), String> {
    if is_label(operand) {
        emitter.emit(0x10);
        emitter.emit(0x24); // BCC condition
        let full_label = expand_local_label(operand, last_global);
        emitter.add_symbol_ref(&full_label, true, 2);
        emitter.emit_word(0x0000);
        Ok(())
    } else {
        let offset = parse_signed(operand)?;
        emitter.emit(0x10);
        emitter.emit(0x24);
        emitter.emit_word(offset as u16);
        Ok(())
    }
}

fn emit_lblt(emitter: &mut BinaryEmitter, operand: &str, last_global: &str) -> Result<(), String> {
    if is_label(operand) {
        emitter.emit(0x10);
        emitter.emit(0x2D); // BLT condition
        let full_label = expand_local_label(operand, last_global);
        emitter.add_symbol_ref(&full_label, true, 2);
        emitter.emit_word(0x0000);
        Ok(())
    } else {
        let offset = parse_signed(operand)?;
        emitter.emit(0x10);
        emitter.emit(0x2D);
        emitter.emit_word(offset as u16);
        Ok(())
    }
}

fn emit_lbge(emitter: &mut BinaryEmitter, operand: &str, last_global: &str) -> Result<(), String> {
    if is_label(operand) {
        emitter.emit(0x10);
        emitter.emit(0x2C); // BGE condition
        let full_label = expand_local_label(operand, last_global);
        emitter.add_symbol_ref(&full_label, true, 2);
        emitter.emit_word(0x0000);
        Ok(())
    } else {
        let offset = parse_signed(operand)?;
        emitter.emit(0x10);
        emitter.emit(0x2C);
        emitter.emit_word(offset as u16);
        Ok(())
    }
}

fn emit_lbgt(emitter: &mut BinaryEmitter, operand: &str, last_global: &str) -> Result<(), String> {
    if is_label(operand) {
        emitter.emit(0x10);
        emitter.emit(0x2E); // BGT condition
        let full_label = expand_local_label(operand, last_global);
        emitter.add_symbol_ref(&full_label, true, 2);
        emitter.emit_word(0x0000);
        Ok(())
    } else {
        let offset = parse_signed(operand)?;
        emitter.emit(0x10);
        emitter.emit(0x2E);
        emitter.emit_word(offset as u16);
        Ok(())
    }
}

fn emit_lble(emitter: &mut BinaryEmitter, operand: &str, last_global: &str) -> Result<(), String> {
    if is_label(operand) {
        emitter.emit(0x10);
        emitter.emit(0x2F); // BLE condition
        let full_label = expand_local_label(operand, last_global);
        emitter.add_symbol_ref(&full_label, true, 2);
        emitter.emit_word(0x0000);
        Ok(())
    } else {
        let offset = parse_signed(operand)?;
        emitter.emit(0x10);
        emitter.emit(0x2F);
        emitter.emit_word(offset as u16);
        Ok(())
    }
}

fn emit_lbmi(emitter: &mut BinaryEmitter, operand: &str, last_global: &str) -> Result<(), String> {
    if is_label(operand) {
        emitter.emit(0x10);
        emitter.emit(0x2B); // BMI condition
        let full_label = expand_local_label(operand, last_global);
        emitter.add_symbol_ref(&full_label, true, 2);
        emitter.emit_word(0x0000);
        Ok(())
    } else {
        let offset = parse_signed(operand)?;
        emitter.emit(0x10);
        emitter.emit(0x2B);
        emitter.emit_word(offset as u16);
        Ok(())
    }
}

fn emit_lbpl(emitter: &mut BinaryEmitter, operand: &str, last_global: &str) -> Result<(), String> {
    if is_label(operand) {
        emitter.emit(0x10);
        emitter.emit(0x2A); // BPL condition
        let full_label = expand_local_label(operand, last_global);
        emitter.add_symbol_ref(&full_label, true, 2);
        emitter.emit_word(0x0000);
        Ok(())
    } else {
        let offset = parse_signed(operand)?;
        emitter.emit(0x10);
        emitter.emit(0x2A);
        emitter.emit_word(offset as u16);
        Ok(())
    }
}

fn emit_lbhi(emitter: &mut BinaryEmitter, operand: &str, last_global: &str) -> Result<(), String> {
    if is_label(operand) {
        emitter.emit(0x10);
        emitter.emit(0x22); // BHI condition
        let full_label = expand_local_label(operand, last_global);
        emitter.add_symbol_ref(&full_label, true, 2);
        emitter.emit_word(0x0000);
        Ok(())
    } else {
        let offset = parse_signed(operand)?;
        emitter.emit(0x10);
        emitter.emit(0x22);
        emitter.emit_word(offset as u16);
        Ok(())
    }
}

fn emit_lbls(emitter: &mut BinaryEmitter, operand: &str, last_global: &str) -> Result<(), String> {
    if is_label(operand) {
        emitter.emit(0x10);
        emitter.emit(0x23); // BLS condition
        let full_label = expand_local_label(operand, last_global);
        emitter.add_symbol_ref(&full_label, true, 2);
        emitter.emit_word(0x0000);
        Ok(())
    } else {
        let offset = parse_signed(operand)?;
        emitter.emit(0x10);
        emitter.emit(0x23);
        emitter.emit_word(offset as u16);
        Ok(())
    }
}

fn emit_adda(emitter: &mut BinaryEmitter, operand: &str, equates: &HashMap<String, u16>) -> Result<(), String> {
    if operand.starts_with('#') {
        let val = parse_immediate(&operand[1..])?;
        emitter.adda_immediate(val);
        Ok(())
    } else if operand.contains(',') {
        // Modo indexado: ADDA ,X  ADDA 5,Y  etc.
        let (postbyte, offset) = parse_indexed_mode(operand)?;
        emitter.emit(0xAB);  // ADDA indexed opcode
        emitter.emit(postbyte);
        if let Some(off) = offset {
            emitter.emit(off as u8);
        }
        if let Some(off) = offset {
            emitter.emit(off as u8);
        }
        Ok(())
    } else {
        match evaluate_expression(operand, equates) {
            Ok(addr) => {
                emitter.adda_extended(addr);
                Ok(())
            }
            Err(msg) => {
                if msg.starts_with("SYMBOL:") {
                    let (symbol, addend) = parse_symbol_and_addend(&msg)?;
                    emitter.emit_extended_symbol_ref(0xBB, &symbol, addend); // ADDA extended
                    Ok(())
                } else {
                    Err(msg)
                }
            }
        }
    }
}

fn emit_addb(emitter: &mut BinaryEmitter, operand: &str, equates: &HashMap<String, u16>) -> Result<(), String> {
    if operand.starts_with('#') {
        let val = parse_immediate(&operand[1..])?;
        emitter.addb_immediate(val);
        Ok(())
    } else if operand.contains(',') {
        // INDEXED MODE (e.g., ",X", "B,X", "5,Y")
        emitter.emit(0xEB); // ADDB indexed opcode
        let (postbyte, offset) = parse_indexed_mode(operand)?;
        emitter.emit(postbyte);
        if let Some(off) = offset {
            emitter.emit(off as u8);
        }
        Ok(())
    } else {
        match evaluate_expression(operand, equates) {
            Ok(addr) => {
                emitter.emit(0xFB); // ADDB extended opcode
                emitter.emit_word(addr);
                Ok(())
            }
            Err(msg) => {
                if msg.starts_with("SYMBOL:") {
                    let (symbol, addend) = parse_symbol_and_addend(&msg)?;
                    emitter.emit_extended_symbol_ref(0xFB, &symbol, addend); // ADDB extended
                    Ok(())
                } else {
                    Err(msg)
                }
            }
        }
    }
}

fn emit_suba(emitter: &mut BinaryEmitter, operand: &str, equates: &HashMap<String, u16>) -> Result<(), String> {
    if operand.starts_with('#') {
        let val = parse_immediate(&operand[1..])?;
        emitter.suba_immediate(val);
        Ok(())
    } else if operand.contains(',') {
        // INDEXED MODE
        emitter.emit(0xA0); // SUBA indexed opcode
        let (postbyte, offset) = parse_indexed_mode(operand)?;
        emitter.emit(postbyte);
        if let Some(off) = offset {
            emitter.emit(off as u8);
        }
        Ok(())
    } else {
        // Extended mode
        match evaluate_expression(operand, equates) {
            Ok(addr) => {
                emitter.emit(0xB0); // SUBA extended opcode
                emitter.emit_word(addr);
                Ok(())
            }
            Err(msg) => {
                if msg.starts_with("SYMBOL:") {
                    let (symbol, addend) = parse_symbol_and_addend(&msg)?;
                    emitter.emit_extended_symbol_ref(0xB0, &symbol, addend); // SUBA extended
                    Ok(())
                } else {
                    Err(msg)
                }
            }
        }
    }
}

fn emit_sbca(emitter: &mut BinaryEmitter, operand: &str, equates: &HashMap<String, u16>) -> Result<(), String> {
    if operand.starts_with('#') {
        let val = parse_immediate(&operand[1..])?;
        emitter.sbca_immediate(val);
        Ok(())
    } else if operand.contains(',') {
        // INDEXED MODE
        emitter.emit(0xA2); // SBCA indexed opcode
        let (postbyte, offset) = parse_indexed_mode(operand)?;
        emitter.emit(postbyte);
        if let Some(off) = offset {
            emitter.emit(off as u8);
        }
        Ok(())
    } else {
        // Extended mode
        match evaluate_expression(operand, equates) {
            Ok(addr) => {
                emitter.emit(0xB2); // SBCA extended opcode
                emitter.emit_word(addr);
                Ok(())
            }
            Err(msg) => {
                if msg.starts_with("SYMBOL:") {
                    let (symbol, addend) = parse_symbol_and_addend(&msg)?;
                    emitter.emit_extended_symbol_ref(0xB2, &symbol, addend); // SBCA extended
                    Ok(())
                } else {
                    Err(msg)
                }
            }
        }
    }
}

fn emit_sbcb(emitter: &mut BinaryEmitter, operand: &str, equates: &HashMap<String, u16>) -> Result<(), String> {
    if operand.starts_with('#') {
        let val = parse_immediate(&operand[1..])?;
        emitter.sbcb_immediate(val);
        Ok(())
    } else if operand.contains(',') {
        // INDEXED MODE
        emitter.emit(0xE2); // SBCB indexed opcode
        let (postbyte, offset) = parse_indexed_mode(operand)?;
        emitter.emit(postbyte);
        if let Some(off) = offset {
            emitter.emit(off as u8);
        }
        Ok(())
    } else {
        // Extended mode
        match evaluate_expression(operand, equates) {
            Ok(addr) => {
                emitter.emit(0xF2); // SBCB extended opcode
                emitter.emit_word(addr);
                Ok(())
            }
            Err(msg) => {
                if msg.starts_with("SYMBOL:") {
                    let (symbol, addend) = parse_symbol_and_addend(&msg)?;
                    emitter.emit_extended_symbol_ref(0xF2, &symbol, addend); // SBCB extended
                    Ok(())
                } else {
                    Err(msg)
                }
            }
        }
    }
}

fn emit_subb(emitter: &mut BinaryEmitter, operand: &str, equates: &HashMap<String, u16>) -> Result<(), String> {
    if operand.starts_with('#') {
        let val = parse_immediate(&operand[1..])?;
        emitter.subb_immediate(val);
        Ok(())
    } else if operand.contains(',') {
        // INDEXED MODE (e.g., ",X", "B,X", "5,Y")
        emitter.emit(0xE0); // SUBB indexed opcode
        let (postbyte, offset) = parse_indexed_mode(operand)?;
        emitter.emit(postbyte);
        if let Some(off) = offset {
            emitter.emit(off as u8);
        }
        Ok(())
    } else {
        match evaluate_expression(operand, equates) {
            Ok(addr) => {
                emitter.emit(0xF0); // SUBB extended opcode
                emitter.emit_word(addr);
                Ok(())
            }
            Err(msg) => {
                if msg.starts_with("SYMBOL:") {
                    let (symbol, addend) = parse_symbol_and_addend(&msg)?;
                    emitter.emit_extended_symbol_ref(0xF0, &symbol, addend); // SUBB extended
                    Ok(())
                } else {
                    Err(msg)
                }
            }
        }
    }
}

fn emit_addd(emitter: &mut BinaryEmitter, operand: &str, equates: &HashMap<String, u16>) -> Result<(), String> {
    if operand.starts_with('#') {
        let val = parse_immediate_16_with_symbols(&operand[1..], equates)?;
        emitter.addd_immediate(val);
        Ok(())
    } else if operand.contains(',') {
        // INDEXED MODE
        emitter.emit(0xE3); // ADDD indexed opcode
        let (postbyte, offset) = parse_indexed_mode(operand)?;
        emitter.emit(postbyte);
        if let Some(off) = offset {
            emitter.emit(off as u8);
        }
        Ok(())
    } else {
        // Extended mode (symbol or address)
        match evaluate_expression(operand, equates) {
            Ok(addr) => {
                emitter.addd_extended(addr);
                Ok(())
            }
            Err(msg) => {
                if msg.starts_with("SYMBOL:") {
                    let (symbol, addend) = parse_symbol_and_addend(&msg)?;
                    emitter.emit_extended_symbol_ref(0xF3, &symbol, addend); // ADDD extended
                    Ok(())
                } else {
                    Err(msg)
                }
            }
        }
    }
}

fn emit_subd(emitter: &mut BinaryEmitter, operand: &str, equates: &HashMap<String, u16>) -> Result<(), String> {
    if operand.starts_with('#') {
        let val = parse_immediate_16_with_symbols(&operand[1..], equates)?;
        emitter.subd_immediate(val);
        Ok(())
    } else if operand.contains(',') {
        // Indexed mode: 3,S  5,X  A,X  etc.
        let (postbyte, offset) = parse_indexed_mode(operand)?;
        emitter.subd_indexed(postbyte);
        if let Some(off) = offset {
            emitter.emit(off as u8);
        }
        Ok(())
    } else {
        // Extended mode (symbol or address)
        match evaluate_expression(operand, equates) {
            Ok(addr) => {
                emitter.subd_extended(addr);
                Ok(())
            }
            Err(msg) => {
                if msg.starts_with("SYMBOL:") {
                    let (symbol, addend) = parse_symbol_and_addend(&msg)?;
                    emitter.emit_extended_symbol_ref(0xB3, &symbol, addend); // SUBD extended
                    Ok(())
                } else {
                    Err(msg)
                }
            }
        }
    }
}

fn emit_anda(emitter: &mut BinaryEmitter, operand: &str, equates: &HashMap<String, u16>) -> Result<(), String> {
    if operand.starts_with('#') {
        let val = parse_immediate(&operand[1..])?;
        emitter.anda_immediate(val);
        Ok(())
    } else if operand.contains(',') {
        // INDEXED MODE
        emitter.emit(0xA4); // ANDA indexed opcode
        let (postbyte, offset) = parse_indexed_mode(operand)?;
        emitter.emit(postbyte);
        if let Some(off) = offset {
            emitter.emit(off as u8);
        }
        Ok(())
    } else {
        match evaluate_expression(operand, equates) {
            Ok(addr) => {
                emitter.emit(0xB4); // ANDA extended opcode
                emitter.emit_word(addr);
                Ok(())
            }
            Err(msg) => {
                if msg.starts_with("SYMBOL:") {
                    let symbol = &msg[7..];
                    emitter.add_symbol_ref(symbol, false, 2);
                    emitter.emit(0xB4);
                    emitter.emit_word(0);
                    Ok(())
                } else {
                    Err(msg)
                }
            }
        }
    }
}

fn emit_andb(emitter: &mut BinaryEmitter, operand: &str, equates: &HashMap<String, u16>) -> Result<(), String> {
    if operand.starts_with('#') {
        let val = parse_immediate(&operand[1..])?;
        emitter.andb_immediate(val);
        Ok(())
    } else if operand.contains(',') {
        // INDEXED MODE
        emitter.emit(0xE4); // ANDB indexed opcode
        let (postbyte, offset) = parse_indexed_mode(operand)?;
        emitter.emit(postbyte);
        if let Some(off) = offset {
            emitter.emit(off as u8);
        }
        Ok(())
    } else {
        match evaluate_expression(operand, equates) {
            Ok(addr) => {
                emitter.emit(0xF4); // ANDB extended opcode
                emitter.emit_word(addr);
                Ok(())
            }
            Err(msg) => {
                if msg.starts_with("SYMBOL:") {
                    let symbol = &msg[7..];
                    emitter.add_symbol_ref(symbol, false, 2);
                    emitter.emit(0xF4);
                    emitter.emit_word(0);
                    Ok(())
                } else {
                    Err(msg)
                }
            }
        }
    }
}

fn emit_bita(emitter: &mut BinaryEmitter, operand: &str, equates: &HashMap<String, u16>) -> Result<(), String> {
    if operand.starts_with('#') {
        let val = parse_immediate(&operand[1..])?;
        emitter.bita_immediate(val);
        Ok(())
    } else if operand.contains(',') {
        // INDEXED MODE
        emitter.emit(0xA5); // BITA indexed opcode
        let (postbyte, offset) = parse_indexed_mode(operand)?;
        emitter.emit(postbyte);
        if let Some(off) = offset {
            emitter.emit(off as u8);
        }
        Ok(())
    } else {
        match evaluate_expression(operand, equates) {
            Ok(addr) => {
                emitter.bita_extended(addr);
                Ok(())
            }
            Err(msg) => {
                if msg.starts_with("SYMBOL:") {
                    let symbol = &msg[7..];
                    emitter.add_symbol_ref(symbol, false, 2);
                    emitter.emit(0xB5); // BITA extended
                    emitter.emit_word(0);
                    Ok(())
                } else {
                    Err(msg)
                }
            }
        }
    }
}

fn emit_bitb(emitter: &mut BinaryEmitter, operand: &str, equates: &HashMap<String, u16>) -> Result<(), String> {
    if operand.starts_with('#') {
        let val = parse_immediate(&operand[1..])?;
        emitter.bitb_immediate(val);
        Ok(())
    } else if operand.contains(',') {
        // INDEXED MODE
        emitter.emit(0xE5); // BITB indexed opcode
        let (postbyte, offset) = parse_indexed_mode(operand)?;
        emitter.emit(postbyte);
        if let Some(off) = offset {
            emitter.emit(off as u8);
        }
        Ok(())
    } else {
        match evaluate_expression(operand, equates) {
            Ok(addr) => {
                emitter.bitb_extended(addr);
                Ok(())
            }
            Err(msg) => {
                if msg.starts_with("SYMBOL:") {
                    let symbol = &msg[7..];
                    emitter.add_symbol_ref(symbol, false, 2);
                    emitter.emit(0xF5); // BITB extended
                    emitter.emit_word(0);
                    Ok(())
                } else {
                    Err(msg)
                }
            }
        }
    }
}

fn emit_orb(emitter: &mut BinaryEmitter, operand: &str, equates: &HashMap<String, u16>) -> Result<(), String> {
    if operand.starts_with('#') {
        let val = parse_immediate(&operand[1..])?;
        emitter.orb_immediate(val);
        Ok(())
    } else if operand.contains(',') {
        // INDEXED MODE
        emitter.emit(0xEA); // ORB indexed opcode
        let (postbyte, offset) = parse_indexed_mode(operand)?;
        emitter.emit(postbyte);
        if let Some(off) = offset {
            emitter.emit(off as u8);
        }
        Ok(())
    } else {
        // Extended mode
        match evaluate_expression(operand, equates) {
            Ok(addr) => {
                emitter.emit(0xFA); // ORB extended opcode
                emitter.emit_word(addr);
                Ok(())
            }
            Err(msg) => {
                if msg.starts_with("SYMBOL:") {
                    let symbol = &msg[7..];
                    emitter.add_symbol_ref(symbol, false, 2);
                    emitter.emit(0xFA);
                    emitter.emit_word(0);
                    Ok(())
                } else {
                    Err(msg)
                }
            }
        }
    }
}

fn emit_ora(emitter: &mut BinaryEmitter, operand: &str, equates: &HashMap<String, u16>) -> Result<(), String> {
    if operand.starts_with('#') {
        let val = parse_immediate(&operand[1..])?;
        emitter.ora_immediate(val);
        Ok(())
    } else if operand.contains(',') {
        // INDEXED MODE
        emitter.emit(0xAA); // ORA indexed opcode
        let (postbyte, offset) = parse_indexed_mode(operand)?;
        emitter.emit(postbyte);
        if let Some(off) = offset {
            emitter.emit(off as u8);
        }
        Ok(())
    } else {
        match evaluate_expression(operand, equates) {
            Ok(addr) => {
                emitter.emit(0xBA); // ORA extended opcode
                emitter.emit_word(addr);
                Ok(())
            }
            Err(msg) => {
                if msg.starts_with("SYMBOL:") {
                    let symbol = &msg[7..];
                    emitter.add_symbol_ref(symbol, false, 2);
                    emitter.emit(0xBA);
                    emitter.emit_word(0);
                    Ok(())
                } else {
                    Err(msg)
                }
            }
        }
    }
}

fn emit_eora(emitter: &mut BinaryEmitter, operand: &str, equates: &HashMap<String, u16>) -> Result<(), String> {
    if operand.starts_with('#') {
        let val = parse_immediate(&operand[1..])?;
        emitter.eora_immediate(val);
        Ok(())
    } else if operand.contains(',') {
        // INDEXED MODE
        emitter.emit(0xA8); // EORA indexed opcode
        let (postbyte, offset) = parse_indexed_mode(operand)?;
        emitter.emit(postbyte);
        if let Some(off) = offset {
            emitter.emit(off as u8);
        }
        Ok(())
    } else {
        match evaluate_expression(operand, equates) {
            Ok(addr) => {
                emitter.emit(0xB8); // EORA extended opcode
                emitter.emit_word(addr);
                Ok(())
            }
            Err(msg) => {
                if msg.starts_with("SYMBOL:") {
                    let symbol = &msg[7..];
                    emitter.add_symbol_ref(symbol, false, 2);
                    emitter.emit(0xB8);
                    emitter.emit_word(0);
                    Ok(())
                } else {
                    Err(msg)
                }
            }
        }
    }
}

fn emit_tfr(emitter: &mut BinaryEmitter, operand: &str) -> Result<(), String> {
    use crate::backend::m6809_binary_emitter::tfr_regs;
    
    let parts: Vec<&str> = operand.split(',').map(|s| s.trim()).collect();
    if parts.len() != 2 {
        return Err(format!("TFR requiere 2 registros separados por coma: {}", operand));
    }
    
    let src = match parts[0].to_uppercase().as_str() {
        "D" => tfr_regs::D,
        "X" => tfr_regs::X,
        "Y" => tfr_regs::Y,
        "U" => tfr_regs::U,
        "S" => tfr_regs::S,
        "PC" => tfr_regs::PC,
        "A" => tfr_regs::A,
        "B" => tfr_regs::B,
        "CC" => tfr_regs::CC,
        "DP" => tfr_regs::DP,
        _ => return Err(format!("Registro fuente TFR inválido: {}", parts[0]))
    };
    
    let dst = match parts[1].to_uppercase().as_str() {
        "D" => tfr_regs::D,
        "X" => tfr_regs::X,
        "Y" => tfr_regs::Y,
        "U" => tfr_regs::U,
        "S" => tfr_regs::S,
        "PC" => tfr_regs::PC,
        "A" => tfr_regs::A,
        "B" => tfr_regs::B,
        "CC" => tfr_regs::CC,
        "DP" => tfr_regs::DP,
        _ => return Err(format!("Registro destino TFR inválido: {}", parts[1]))
    };
    
    emitter.tfr(src, dst);
    Ok(())
}

fn emit_cmpa(emitter: &mut BinaryEmitter, operand: &str, equates: &HashMap<String, u16>) -> Result<(), String> {
    if operand.starts_with('#') {
        let val = parse_immediate(&operand[1..])?;
        emitter.cmpa_immediate(val);
    } else if operand.contains(',') {
        // INDEXED MODE (e.g., ",X", "B,X", "5,Y")
        emitter.emit(0xA1); // CMPA indexed opcode
        let (postbyte, offset) = parse_indexed_mode(operand)?;
        emitter.emit(postbyte);
        if let Some(off) = offset {
            emitter.emit(off as u8);
        }
    } else {
        // DIRECT or EXTENDED
        match evaluate_expression(operand, equates) {
            Ok(addr) => {
                if addr <= 0xFF {
                    // DIRECT mode
                    emitter.emit(0x91); // CMPA direct opcode
                    emitter.emit(addr as u8);
                } else {
                    // Extended addressing
                    emitter.emit(0xB1); // CMPA extended opcode
                    emitter.emit_word(addr);
                }
            }
            Err(e) if e.starts_with("SYMBOL:") => {
                let sym = e.strip_prefix("SYMBOL:").unwrap();
                emitter.emit(0xB1); // CMPA extended (assume)
                emitter.add_symbol_ref(sym, false, 2);
                emitter.emit_word(0); // Placeholder
            }
            Err(e) => return Err(e),
        }
    }
    Ok(())
}

fn emit_cmpb(emitter: &mut BinaryEmitter, operand: &str, equates: &HashMap<String, u16>) -> Result<(), String> {
    if operand.starts_with('#') {
        let val = parse_immediate(&operand[1..])?;
        emitter.cmpb_immediate(val);
    } else if operand.contains(',') {
        // INDEXED MODE (e.g., ",X", "B,X", "5,Y")
        emitter.emit(0xE1); // CMPB indexed opcode
        let (postbyte, offset) = parse_indexed_mode(operand)?;
        emitter.emit(postbyte);
        if let Some(off) = offset {
            emitter.emit(off as u8);
        }
    } else {
        // DIRECT or EXTENDED (assume DIRECT for now)
        match evaluate_expression(operand, equates) {
            Ok(addr) => {
                if addr <= 0xFF {
                    // DIRECT mode
                    emitter.emit(0xD1); // CMPB direct opcode
                    emitter.emit(addr as u8);
                } else {
                    // Extended addressing
                    emitter.emit(0xF1); // CMPB extended opcode
                    emitter.emit_word(addr);
                }
            }
            Err(e) if e.starts_with("SYMBOL:") => {
                let sym = e.strip_prefix("SYMBOL:").unwrap();
                emitter.emit(0xF1); // CMPB extended (assume)
                emitter.add_symbol_ref(sym, false, 2);
                emitter.emit_word(0); // Placeholder
            }
            Err(e) => return Err(e),
        }
    }
    Ok(())
}

fn emit_cmpd(emitter: &mut BinaryEmitter, operand: &str, equates: &HashMap<String, u16>) -> Result<(), String> {
    if operand.starts_with('#') {
        let val = parse_immediate_16_with_symbols(&operand[1..], equates)?;
        emitter.cmpd_immediate(val);
        Ok(())
    } else if operand.contains(',') {
        // Modo indexado: CMPD ,X  CMPD 5,Y  etc.
        let (postbyte, offset) = parse_indexed_mode(operand)?;
        emitter.emit(0x10);  // CMPD prefix
        emitter.emit(0xA3);  // CMPD indexed opcode
        emitter.emit(postbyte);
        if let Some(off) = offset {
            emitter.emit(off as u8);
        }
        if let Some(off) = offset {
            emitter.emit(off as u8);
        }
        Ok(())
    } else {
        match evaluate_expression(operand, equates) {
            Ok(addr) => {
                emitter.cmpd_extended(addr);
                Ok(())
            }
            Err(e) if e.starts_with("SYMBOL:") => {
                emitter.cmpd_extended(0);
                emitter.add_symbol_ref(operand, false, 2);
                Ok(())
            }
            Err(e) => Err(e),
        }
    }
}

fn emit_cmpx(emitter: &mut BinaryEmitter, operand: &str, equates: &HashMap<String, u16>) -> Result<(), String> {
    if operand.starts_with('#') {
        let val = parse_immediate_16_with_symbols(&operand[1..], equates)?;
        emitter.cmpx_immediate(val);
        Ok(())
    } else {
        Err(format!("CMPX solo soporta modo inmediato (#valor)"))
    }
}

fn emit_cmpy(emitter: &mut BinaryEmitter, operand: &str, equates: &HashMap<String, u16>) -> Result<(), String> {
    if operand.starts_with('#') {
        let val = parse_immediate_16_with_symbols(&operand[1..], equates)?;
        emitter.cmpy_immediate(val);
        Ok(())
    } else {
        Err(format!("CMPY solo soporta modo inmediato (#valor)"))
    }
}

fn emit_cmpu(emitter: &mut BinaryEmitter, operand: &str, equates: &HashMap<String, u16>) -> Result<(), String> {
    if operand.starts_with('#') {
        let val = parse_immediate_16_with_symbols(&operand[1..], equates)?;
        emitter.cmpu_immediate(val);
        Ok(())
    } else {
        Err(format!("CMPU solo soporta modo inmediato (#valor)"))
    }
}

fn emit_cmps(emitter: &mut BinaryEmitter, operand: &str, equates: &HashMap<String, u16>) -> Result<(), String> {
    if operand.starts_with('#') {
        let val = parse_immediate_16_with_symbols(&operand[1..], equates)?;
        emitter.cmps_immediate(val);
        Ok(())
    } else {
        Err(format!("CMPS solo soporta modo inmediato (#valor)"))
    }
}

fn emit_clr(emitter: &mut BinaryEmitter, operand: &str, equates: &HashMap<String, u16>) -> Result<(), String> {
    // Check if it's indexed addressing (contains comma: ,-S  ,X+  5,Y  etc.)
    if operand.contains(',') {
        let (postbyte, offset) = parse_indexed_mode(operand)?;
        emitter.clr_indexed(postbyte);
        if let Some(off) = offset {
            emitter.emit(off as u8);
        }
        return Ok(());
    }
    
    // Handle < (force direct page) and > (force extended) operators
    if operand.starts_with('<') {
        let addr = resolve_address(&operand[1..], equates)?;
        emitter.emit(0x0F); // CLR direct page opcode
        emitter.emit((addr & 0xFF) as u8);
        return Ok(());
    } else if operand.starts_with('>') {
        let addr = resolve_address(&operand[1..], equates)?;
        emitter.clr_extended(addr);
        return Ok(());
    }
    
    // CLR para memoria (extended mode - opcode 0x7F)
    match evaluate_expression(operand, equates) {
        Ok(addr) => {
            emitter.clr_extended(addr);
            Ok(())
        }
        Err(e) if e.starts_with("SYMBOL:") => {
            emitter.clr_extended(0);
            emitter.add_symbol_ref(operand, false, 2);
            Ok(())
        }
        Err(e) => Err(e),
    }
}

fn emit_inc(emitter: &mut BinaryEmitter, operand: &str, equates: &HashMap<String, u16>) -> Result<(), String> {
    // Check if it's indexed addressing
    if operand.contains(',') {
        let (postbyte, offset) = parse_indexed_mode(operand)?;
        emitter.inc_indexed(postbyte);
        if let Some(off) = offset {
            emitter.emit(off as u8);
        }
        return Ok(());
    }
    
    // INC para memoria (extended mode - opcode 0x7C)
    match evaluate_expression(operand, equates) {
        Ok(addr) => {
            emitter.inc_extended(addr);
            Ok(())
        }
        Err(e) if e.starts_with("SYMBOL:") => {
            emitter.inc_extended(0);
            emitter.add_symbol_ref(operand, false, 2);
            Ok(())
        }
        Err(e) => Err(e),
    }
}

fn emit_dec(emitter: &mut BinaryEmitter, operand: &str, equates: &HashMap<String, u16>) -> Result<(), String> {
    // Check if it's indexed addressing
    if operand.contains(',') {
        let (postbyte, offset) = parse_indexed_mode(operand)?;
        emitter.dec_indexed(postbyte);
        if let Some(off) = offset {
            emitter.emit(off as u8);
        }
        return Ok(());
    }
    
    // Handle < (force direct page) and > (force extended) operators
    if operand.starts_with('<') {
        let addr = resolve_address(&operand[1..], equates)?;
        emitter.dec_direct((addr & 0xFF) as u8);
        return Ok(());
    } else if operand.starts_with('>') {
        let addr = resolve_address(&operand[1..], equates)?;
        emitter.dec_extended(addr);
        return Ok(());
    }
    
    // DEC para memoria (auto-select mode based on address)
    match evaluate_expression(operand, equates) {
        Ok(addr) => {
            if addr <= 0xFF {
                emitter.dec_direct(addr as u8);
            } else {
                emitter.dec_extended(addr);
            }
            Ok(())
        }
        Err(e) if e.starts_with("SYMBOL:") => {
            emitter.dec_extended(0);
            emitter.add_symbol_ref(operand, false, 2);
            Ok(())
        }
        Err(e) => Err(e),
    }
}

fn emit_tst(emitter: &mut BinaryEmitter, operand: &str, equates: &HashMap<String, u16>) -> Result<(), String> {
    // TST para memoria (extended mode - opcode 0x7D)
    if operand.chars().all(|c| c.is_alphanumeric() || c == '_') {
        // Es un símbolo
        emitter.tst_extended_sym(operand);
        Ok(())
    } else {
        // Es una dirección numérica
        match evaluate_expression(operand, equates) {
            Ok(addr) => {
                emitter.tst_extended(addr);
                Ok(())
            }
            Err(e) => Err(e),
        }
    }
}

// === HELPERS DE PARSING ===

/// Parsea modo indexado y retorna (postbyte, tiene_offset_extra)
/// Ejemplos: ,X+ → (0x80, false), ,X++ → (0x81, false), 4,X → (offset en postbyte, true si >-16..+15)
fn parse_indexed_mode(operand: &str) -> Result<(u8, Option<i8>), String> {
    let trimmed = operand.trim();
    
    // Helper para obtener bits de registro
    let get_reg_bits = |reg: &str| -> Result<u8, String> {
        match reg.to_uppercase().as_str() {
            "X" => Ok(0x00),
            "Y" => Ok(0x20),
            "U" => Ok(0x40),
            "S" => Ok(0x60),
            _ => Err(format!("Registro no reconocido: {}", reg))
        }
    };
    
    // Modos con acumulador: A,X  B,X  D,X  A,Y  B,Y  D,Y  A,U  B,U  D,U  A,S  B,S  D,S
    // Postbytes: A=0x86, B=0x85, D=0x8B (más bits de registro)
    for index_reg in &["X", "Y", "U", "S"] {
        for acc_reg in &["A", "B", "D"] {
            if trimmed == format!("{},{}", acc_reg, index_reg) {
                let reg_bits = get_reg_bits(index_reg)?;
                let acc_bits = match acc_reg.as_ref() {
                    "A" => 0x86,
                    "B" => 0x85,
                    "D" => 0x8B,
                    _ => unreachable!()
                };
                return Ok((acc_bits | reg_bits, None));
            }
        }
    }
    
    // Modos auto-increment/decrement: ,REG+ ,REG++ ,-REG --REG
    // También soporta sin coma: REG+ REG++ (sintaxis alternativa)
    // Soporta X, Y, U, S
    for reg in &["X", "Y", "U", "S"] {
        // ,REG+ o REG+ → post-increment by 1
        if trimmed == format!(",{}+", reg) || trimmed == format!("{}+", reg) {
            let reg_bits = get_reg_bits(reg)?;
            return Ok((0x80 | reg_bits, None));
        }
        // ,REG++ o REG++ → post-increment by 2
        if trimmed == format!(",{}++", reg) || trimmed == format!("{}++", reg) {
            let reg_bits = get_reg_bits(reg)?;
            return Ok((0x81 | reg_bits, None));
        }
        // ,-REG → pre-decrement by 1
        if trimmed == format!(",-{}", reg) {
            let reg_bits = get_reg_bits(reg)?;
            return Ok((0x82 | reg_bits, None));
        }
        // --REG → pre-decrement by 2
        if trimmed == format!("--{}", reg) || trimmed == format!(",--{}", reg) {
            let reg_bits = get_reg_bits(reg)?;
            return Ok((0x83 | reg_bits, None));
        }
    }
    
    // offset,REG → constant offset o sin offset
    if let Some(comma_pos) = trimmed.find(',') {
        let offset_str = trimmed[..comma_pos].trim();
        let reg_str = trimmed[comma_pos+1..].trim();
        let reg_bits = get_reg_bits(reg_str)?;
        
        eprintln!("🐛 parse_indexed_mode: offset_str='{}' reg_str='{}' reg_bits=0x{:02X}", offset_str, reg_str, reg_bits);
        
        if offset_str.is_empty() {
            // ,REG → zero offset (indirect)
            eprintln!("🐛   → zero offset: 0x{:02X}", 0x84 | reg_bits);
            return Ok((0x84 | reg_bits, None));
        } else {
            // offset,REG
            let offset = parse_signed(offset_str)?;
            eprintln!("🐛   → parsed offset: {}", offset);
            if offset >= -16 && offset <= 15 {
                // 5-bit offset en postbyte
                let postbyte = ((offset as u8) & 0x1F) | reg_bits;
                eprintln!("🐛   → 5-bit postbyte: 0x{:02X}", postbyte);
                return Ok((postbyte, None));
            } else {
                // 8-bit offset
                eprintln!("🐛   → 8-bit postbyte: 0x{:02X} offset={}", 0x88 | reg_bits, offset);
                return Ok((0x88 | reg_bits, Some(offset)));
            }
        }
    }
    
    Err(format!("Modo indexado no reconocido: {}", operand))
}

fn parse_immediate(s: &str) -> Result<u8, String> {
    let trimmed = s.trim();
    
    // Check for character literal: 'X' (ASCII value of X)
    if trimmed.starts_with('\'') && trimmed.ends_with('\'') && trimmed.len() == 3 {
        let ch = trimmed.chars().nth(1).unwrap();
        return Ok(ch as u8);
    }
    
    if trimmed.starts_with('$') {
        u8::from_str_radix(&trimmed[1..], 16)
            .map_err(|_| format!("Valor inmediato hex inválido: {}", s))
    } else if trimmed.starts_with("0x") {
        u8::from_str_radix(&trimmed[2..], 16)
            .map_err(|_| format!("Valor inmediato hex inválido: {}", s))
    } else if trimmed.starts_with('-') {
        // Número negativo - parsear como i8 y convertir a u8 (representación en complemento a 2)
        trimmed.parse::<i8>()
            .map(|v| v as u8)
            .map_err(|_| format!("Valor inmediato decimal inválido: {}", s))
    } else {
        trimmed.parse::<u8>()
            .map_err(|_| format!("Valor inmediato decimal inválido: {}", s))
    }
}

fn parse_immediate_16(s: &str) -> Result<u16, String> {
    let trimmed = s.trim();
    if trimmed.starts_with('$') {
        u16::from_str_radix(&trimmed[1..], 16)
            .map_err(|_| format!("Valor inmediato 16-bit hex inválido: {}", s))
    } else if trimmed.starts_with("0x") {
        u16::from_str_radix(&trimmed[2..], 16)
            .map_err(|_| format!("Valor inmediato 16-bit hex inválido: {}", s))
    } else if trimmed.starts_with('-') {
        // Número negativo - parsear como i16 y convertir a u16 (representación en complemento a 2)
        trimmed.parse::<i16>()
            .map(|v| v as u16)
            .map_err(|_| format!("Valor inmediato 16-bit decimal inválido: {}", s))
    } else {
        trimmed.parse::<u16>()
            .map_err(|_| format!("Valor inmediato 16-bit decimal inválido: {}", s))
    }
}

fn parse_immediate_16_with_symbols(s: &str, equates: &HashMap<String, u16>) -> Result<u16, String> {
    let trimmed = s.trim();
    
    // Try standard numeric parsing first
    if trimmed.starts_with('$') {
        return u16::from_str_radix(&trimmed[1..], 16)
            .map_err(|_| format!("Valor inmediato 16-bit hex inválido: {}", s));
    } else if trimmed.starts_with("0x") {
        return u16::from_str_radix(&trimmed[2..], 16)
            .map_err(|_| format!("Valor inmediato 16-bit hex inválido: {}", s));
    } else if trimmed.starts_with('-') {
        return trimmed.parse::<i16>()
            .map(|v| v as u16)
            .map_err(|_| format!("Valor inmediato 16-bit decimal inválido: {}", s));
    } else if let Ok(num) = trimmed.parse::<u16>() {
        return Ok(num);
    }
    
    // If not a number, try to resolve as symbol
    let symbol_name = trimmed.to_uppercase();
    if let Some(&value) = equates.get(&symbol_name) {
        Ok(value)
    } else {
        Err(format!("Símbolo no resuelto: {}", trimmed))
    }
}

fn parse_address(s: &str) -> Result<u16, String> {
    let trimmed = s.trim().trim_start_matches('<'); // Ignorar < de direct page
    if trimmed.starts_with('$') {
        parse_hex(&trimmed[1..])
    } else if trimmed.starts_with("0x") {
        u16::from_str_radix(&trimmed[2..], 16)
            .map_err(|_| format!("Dirección hex inválida: {}", s))
    } else {
        trimmed.parse::<u16>()
            .map_err(|_| format!("Dirección decimal inválida: {}", s))
    }
}

fn parse_hex(s: &str) -> Result<u16, String> {
    u16::from_str_radix(s, 16)
        .map_err(|_| format!("Valor hexadecimal inválido: ${}", s))
}

fn parse_signed(s: &str) -> Result<i8, String> {
    s.trim().parse::<i8>()
        .map_err(|_| format!("Offset con signo inválido: {}", s))
}

// === DIRECTIVAS DE DATOS ===

fn emit_fcc(emitter: &mut BinaryEmitter, operand: &str) -> Result<(), String> {
    // FCC "string" - Form Constant Characters
    let trimmed = operand.trim();
    if let Some(start) = trimmed.find('"') {
        if let Some(end) = trimmed.rfind('"') {
            if end > start {
                let text = &trimmed[start+1..end];
                emitter.emit_string(text);
                return Ok(());
            }
        }
    }
    Err(format!("FCC requiere string entre comillas: {}", operand))
}

fn emit_fcb(emitter: &mut BinaryEmitter, operand: &str) -> Result<(), String> {
    // FCB $80,$FF,10 - Form Constant Byte(s)
    let parts: Vec<&str> = operand.split(',').map(|s| s.trim()).collect();
    for part in parts {
        let value = parse_immediate(part)?;
        emitter.emit_bytes(&[value]);
    }
    Ok(())
}

fn emit_fdb(emitter: &mut BinaryEmitter, operand: &str, equates: &HashMap<String, u16>) -> Result<(), String> {
    // FDB $C800,label - Form Constant Word(s)
    let parts: Vec<&str> = operand.split(',').map(|s| s.trim()).collect();
    for part in parts {
        // Skip single-character "symbols" that are likely register names or parsing errors
        if part.len() == 1 {
            let c = part.chars().next().unwrap().to_ascii_uppercase();
            if ['A', 'B', 'X', 'Y', 'U', 'S'].contains(&c) {
                return Err(format!("FDB: Símbolo de un carácter '{}' no permitido (probablemente error de parsing)", part));
            }
        }
        
        // Intentar resolver como símbolo primero
        let upper = part.to_uppercase();
        if let Some(&value) = equates.get(&upper) {
            emitter.emit_data_word(value);
        } else if part.chars().all(|c| c.is_alphanumeric() || c == '_') && !part.chars().all(|c| c.is_ascii_digit()) {
            // Es un símbolo (no es puramente numérico) - usar referencia (normalizado a uppercase para consistencia)
            emitter.add_symbol_ref(&upper, false, 2);
            emitter.emit_data_word(0x0000); // Placeholder que DEBE resolverse en PASS 2
        } else {
            // Es un valor numérico
            let value = parse_immediate_16(part)?;
            emitter.emit_data_word(value);
        }
    }
    Ok(())
}

fn emit_rmb(emitter: &mut BinaryEmitter, operand: &str) -> Result<(), String> {
    // RMB 10 - Reserve Memory Bytes (no init)
    let count = operand.trim().parse::<usize>()
        .map_err(|_| format!("RMB requiere número entero: {}", operand))?;
    emitter.reserve_bytes(count);
    Ok(())
}

fn emit_zmb(emitter: &mut BinaryEmitter, operand: &str) -> Result<(), String> {
    // ZMB 10 - Zero Memory Bytes (init to zero)
    let count = operand.trim().parse::<usize>()
        .map_err(|_| format!("ZMB requiere número entero: {}", operand))?;
    emitter.reserve_bytes(count); // Ya emite zeros por defecto
    Ok(())
}

// === INSTRUCCIONES 16-BIT ===

fn emit_jmp(emitter: &mut BinaryEmitter, operand: &str) -> Result<(), String> {
    if operand.starts_with('$') {
        let addr = parse_hex(&operand[1..])?;
        emitter.jmp_extended(addr);
    } else if operand.chars().all(|c| c.is_alphanumeric() || c == '_') {
        emitter.jmp_extended_sym(operand);
    } else {
        let addr = parse_address(operand)?;
        emitter.jmp_extended(addr);
    }
    Ok(())
}

fn emit_ldx(emitter: &mut BinaryEmitter, operand: &str, equates: &HashMap<String, u16>) -> Result<(), String> {
    if operand.starts_with('#') {
        // Immediate mode
        let value_part = &operand[1..];
        let upper = value_part.to_uppercase();
        if let Some(&value) = equates.get(&upper) {
            emitter.ldx_immediate(value);
        } else {
            match evaluate_expression(value_part, equates) {
                Ok(value) => emitter.ldx_immediate(value),
                Err(e) if e.starts_with("SYMBOL:") => {
                    let (symbol, addend) = parse_symbol_and_addend(&e)?;
                    // DEBUG: Log when adding symbol ref
                    if symbol.len() == 1 {
                        eprintln!("⚠️ LDX emit_ldx: operand='{}' value_part='{}' symbol='{}' addend={} offset={}", 
                            operand, value_part, symbol, addend, emitter.current_offset());
                    }
                    emitter.emit_immediate16_symbol_ref(&[0x8E], &symbol, addend);
                }
                Err(_) => {
                    let value = parse_immediate_16(value_part)?;
                    emitter.ldx_immediate(value);
                }
            }
        }
    } else if operand.starts_with('>') {
        // Force extended addressing (lwasm compatibility) - LDX has no DP mode anyway
        let addr = resolve_address(&operand[1..], equates)?;
        emitter.ldx_extended(addr);
    } else if operand.contains(',') || operand.contains('+') || operand.contains('-') {
        // Indexed mode: ,Y  ,Y++  5,Y  etc.
        let (postbyte, offset) = parse_indexed_mode(operand)?;
        emitter.ldx_indexed(postbyte);
        if let Some(off) = offset {
            emitter.emit(off as u8);
        }
    } else if operand.chars().all(|c| c.is_alphanumeric() || c == '_') {
        // Symbol reference
        let upper = operand.to_uppercase();
        if let Some(&value) = equates.get(&upper) {
            emitter.ldx_extended(value);
        } else {
            emitter.ldx_extended_sym(operand);
        }
    } else {
        let addr = parse_address(operand)?;
        emitter.ldx_extended(addr);
    }
    Ok(())
}

fn emit_ldy(emitter: &mut BinaryEmitter, operand: &str, equates: &HashMap<String, u16>) -> Result<(), String> {
    if operand.starts_with('#') {
        let value_part = &operand[1..];
        let upper = value_part.to_uppercase();
        if let Some(&value) = equates.get(&upper) {
            emitter.ldy_immediate(value);
        } else {
            match evaluate_expression(value_part, equates) {
                Ok(value) => emitter.ldy_immediate(value),
                Err(e) if e.starts_with("SYMBOL:") => {
                    let (symbol, addend) = parse_symbol_and_addend(&e)?;
                    emitter.emit_immediate16_symbol_ref(&[0x10, 0x8E], &symbol, addend);
                }
                Err(_) => {
                    let value = parse_immediate_16(value_part)?;
                    emitter.ldy_immediate(value);
                }
            }
        }
    } else if operand.contains(',') {
        // Modo indexado
        let (postbyte, offset) = parse_indexed_mode(operand)?;
        emitter.ldy_indexed(postbyte);
        if let Some(off) = offset {
            emitter.emit(off as u8);
        }
    } else {
        let addr = parse_address(operand)?;
        emitter.ldy_extended(addr);
    }
    Ok(())
}

fn emit_stx(emitter: &mut BinaryEmitter, operand: &str, equates: &HashMap<String, u16>) -> Result<(), String> {
    // Check if it's indexed addressing (contains comma: ,X  5,Y  etc.)
    if operand.contains(',') {
        let (postbyte, offset) = parse_indexed_mode(operand)?;
        emitter.stx_indexed(postbyte);
        if let Some(off) = offset {
            emitter.emit(off as u8);
        }
    } else if operand.starts_with('>') {
        // Force extended addressing (lwasm compatibility) - STX has no DP mode
        let addr = resolve_address(&operand[1..], equates)?;
        emitter.stx_extended(addr);
    } else {
        // Extended addressing
        let upper = operand.to_uppercase();
        if let Some(&addr) = equates.get(&upper) {
            emitter.stx_extended(addr);
        } else {
            let addr = parse_address(operand)?;
            emitter.stx_extended(addr);
        }
    }
    Ok(())
}

fn emit_sty(emitter: &mut BinaryEmitter, operand: &str, equates: &HashMap<String, u16>) -> Result<(), String> {
    // Check if it's indexed addressing (contains comma: ,X  5,Y  etc.)
    if operand.contains(',') {
        let (postbyte, offset) = parse_indexed_mode(operand)?;
        emitter.sty_indexed(postbyte);
        if let Some(off) = offset {
            emitter.emit(off as u8);
        }
    } else {
        // Extended addressing
        let upper = operand.to_uppercase();
        if let Some(&addr) = equates.get(&upper) {
            emitter.sty_extended(addr);
        } else {
            let addr = parse_address(operand)?;
            emitter.sty_extended(addr);
        }
    }
    Ok(())
}

fn emit_ldu(emitter: &mut BinaryEmitter, operand: &str, equates: &HashMap<String, u16>) -> Result<(), String> {
    if operand.starts_with('#') {
        // Immediate mode
        let value_part = &operand[1..];

        // Try equates first (fast path)
        let upper = value_part.to_uppercase();
        if let Some(&value) = equates.get(&upper) {
            if upper.contains("LEVEL_GP_BUFFER") || value == 0xC982 {
                eprintln!("DEBUG emit_ldu: Found {} = 0x{:04X} in equates", upper, value);
            }
            emitter.ldu_immediate(value);
        } else {
            match evaluate_expression(value_part, equates) {
                Ok(value) => emitter.ldu_immediate(value),
                Err(e) if e.starts_with("SYMBOL:") => {
                    let (symbol, addend) = parse_symbol_and_addend(&e)?;
                    emitter.emit_immediate16_symbol_ref(&[0xCE], &symbol, addend);
                }
                Err(_) => {
                    let value = parse_immediate_16(value_part)?;
                    emitter.ldu_immediate(value);
                }
            }
        }
    } else if operand.contains(',') || operand.contains('+') || operand.contains('-') {
        // Indexed mode: ,X  X++  ,X++  5,X  A,X  etc.
        let (postbyte, offset) = parse_indexed_mode(operand)?;
        emitter.ldu_indexed(postbyte);
        if let Some(off) = offset {
            emitter.emit(off as u8);
        }
    } else if operand.chars().all(|c| c.is_alphanumeric() || c == '_') {
        // Symbol reference
        let upper = operand.to_uppercase();
        if let Some(&value) = equates.get(&upper) {
            emitter.ldu_extended(value);
        } else {
            emitter.ldu_extended_sym(operand);
        }
    } else {
        let addr = parse_address(operand)?;
        emitter.ldu_extended(addr);
    }
    Ok(())
}

fn emit_stu(emitter: &mut BinaryEmitter, operand: &str, equates: &HashMap<String, u16>) -> Result<(), String> {
    let upper = operand.to_uppercase();
    if let Some(&addr) = equates.get(&upper) {
        emitter.stu_extended(addr);
    } else {
        let addr = parse_address(operand)?;
        emitter.stu_extended(addr);
    }
    Ok(())
}

fn emit_lea(emitter: &mut BinaryEmitter, mnemonic: &str, operand: &str) -> Result<(), String> {
    // Parse indexed addressing mode with optional offset: 5,X  -2,Y  ,S  etc.
    let (postbyte, offset) = parse_indexed_mode(operand)?;
    
    match mnemonic {
        "LEAX" => {
            emitter.leax_indexed(postbyte);
            if let Some(off) = offset {
                emitter.emit(off as u8);
            }
        },
        "LEAY" => {
            emitter.leay_indexed(postbyte);
            if let Some(off) = offset {
                emitter.emit(off as u8);
            }
        },
        "LEAS" => {
            emitter.leas_indexed(postbyte);
            if let Some(off) = offset {
                emitter.emit(off as u8);
            }
        },
        "LEAU" => {
            emitter.leau_indexed(postbyte);
            if let Some(off) = offset {
                emitter.emit(off as u8);
            }
        },
        _ => unreachable!()
    }
    Ok(())
}

/// Parse indexed addressing mode and generate postbyte
/// Formats: ,X  ,Y  ,U  ,S  5,X  -2,Y  etc.
fn parse_indexed_postbyte(operand: &str, _emitter: &mut BinaryEmitter) -> Result<u8, String> {
    let operand = operand.trim();
    
    // Extract offset and register
    if let Some(comma_pos) = operand.find(',') {
        let offset_str = operand[..comma_pos].trim();
        let reg_str = operand[comma_pos+1..].trim().to_uppercase();
        
        // Determine register base
        let reg_bits = match reg_str.as_str() {
            "X" => 0x00,
            "Y" => 0x20,
            "U" => 0x40,
            "S" => 0x60,
            _ => return Err(format!("Registro indexado no válido: {}", reg_str))
        };
        
        // Parse offset
        if offset_str.is_empty() {
            // No offset: ,X → postbyte 0x84 (no offset mode)
            return Ok(reg_bits | 0x84);
        }
        
        // Parse numeric offset
        let offset = if offset_str.starts_with("$") {
            i16::from_str_radix(&offset_str[1..], 16)
                .map_err(|_| format!("Offset hexadecimal inválido: {}", offset_str))?
        } else {
            offset_str.parse::<i16>()
                .map_err(|_| format!("Offset inválido: {}", offset_str))?
        };
        
        // Determine offset size and generate postbyte
        if offset == 0 {
            // Zero offset: 0,X → postbyte 0x84
            Ok(reg_bits | 0x84)
        } else if offset >= -16 && offset <= 15 {
            // 5-bit offset (-16 to +15): encoded in postbyte
            let offset_5bit = (offset & 0x1F) as u8;
            Ok(reg_bits | offset_5bit)
        } else if offset >= -128 && offset <= 127 {
            // 8-bit offset: postbyte 0x88, then 1 byte offset
            // Note: Caller must emit the offset byte after the postbyte
            Ok(reg_bits | 0x88)
        } else {
            // 16-bit offset: postbyte 0x89, then 2 bytes offset (i16 always fits)
            // Note: Caller must emit the 2 offset bytes after the postbyte
            Ok(reg_bits | 0x89)
        }
    } else {
        Err(format!("Formato de direccionamiento indexado inválido: {}", operand))
    }
}

// === STACK OPS ===

fn emit_pshs(emitter: &mut BinaryEmitter, operand: &str) -> Result<(), String> {
    let postbyte = parse_push_pull_postbyte(operand)?;
    emitter.pshs(postbyte);
    Ok(())
}

fn emit_pshu(emitter: &mut BinaryEmitter, operand: &str) -> Result<(), String> {
    let postbyte = parse_push_pull_postbyte(operand)?;
    emitter.pshu(postbyte);
    Ok(())
}

fn emit_puls(emitter: &mut BinaryEmitter, operand: &str) -> Result<(), String> {
    let postbyte = parse_push_pull_postbyte(operand)?;
    emitter.puls(postbyte);
    Ok(())
}

fn emit_pulu(emitter: &mut BinaryEmitter, operand: &str) -> Result<(), String> {
    let postbyte = parse_push_pull_postbyte(operand)?;
    emitter.pulu(postbyte);
    Ok(())
}

fn parse_push_pull_postbyte(operand: &str) -> Result<u8, String> {
    // Parsea lista de registros: "D,X,Y" o "A,B,DP"
    let mut postbyte: u8 = 0;
    let parts: Vec<String> = operand.split(',').map(|s| s.trim().to_uppercase()).collect();
    
    for reg in parts {
        postbyte |= match reg.as_ref() {
            "CC" => 0x01,
            "A" => 0x02,
            "B" => 0x04,
            "DP" => 0x08,
            "X" => 0x10,
            "Y" => 0x20,
            "U" | "S" => 0x40,  // Depende de la instrucción (PSHS vs PSHU)
            "PC" => 0x80,
            "D" => 0x06,  // A+B
            _ => return Err(format!("Registro desconocido en PUSH/PULL: {}", reg))
        };
    }
    
    Ok(postbyte)
}
