//! Builtin metadata used by the language server: call arity, builtin
//! classification, localized messages and hover documentation.
//!
//! The arity table here is intentionally richer than
//! `vpy_parser::builtins::builtin_arity` (it models variadic builtins such as
//! `PRINT_TEXT` / `DRAW_POLYGON` and the real 5-argument `DRAW_LINE`), so it is
//! kept local. Builtin *classification* is the union of this list and
//! `vpy_parser::builtins::is_known_builtin`, so anything the parser treats as a
//! builtin is also highlighted as one.

/// Python keywords, VPy declarations and assignment-looking words that must
/// never be treated as a function name by the line-based arity checker.
pub fn is_python_keyword_or_builtin(word: &str) -> bool {
    let lower = word.to_ascii_lowercase();
    matches!(lower.as_str(),
        // Python keywords
        "and" | "as" | "assert" | "break" | "class" | "continue" | "def" | "del" | "elif" | "else" | "except" | "finally" |
        "for" | "from" | "global" | "if" | "import" | "in" | "is" | "lambda" | "nonlocal" | "not" | "or" | "pass" |
        "raise" | "return" | "try" | "while" | "with" | "yield" | "true" | "false" | "none" |
        // VPy variable declarations and control structures
        "var" | "let" | "const" |
        // Assignment patterns (contains =)
        _ if word.contains('=')
    )
}

/// True if `name` (case-insensitive) is a builtin function. Used for semantic
/// highlighting and to keep builtins out of the variable usage analysis.
pub fn is_builtin_function(name: &str) -> bool {
    let upper = name.to_ascii_uppercase();

    // The compiler's builtins (catalog.rs), and anything the parser classifies as one
    if crate::catalog::lookup(&upper).is_some() || vpy_parser::builtins::is_known_builtin(&upper) {
        return true;
    }

    // Unified functions (global + vectorlist)
    if matches!(upper.as_str(),
        "MOVE"|"SET_INTENSITY"|"DRAW_TO"|"DRAW_LINE"|"SET_ORIGIN"|"PRINT_TEXT"|"PRINT_NUMBER"|
        "SET_TEXT_SIZE"|"BEEP"|"RAND"|"RAND_RANGE"|"STOP_MUSIC"|"PLAY_SFX"|"AUDIO_UPDATE"|
        "UPDATE_BUTTONS"|"WAIT_RECAL"|"ABS"|"MIN"|"MAX"|"CLAMP"
    ) {
        return true;
    }

    // Direct drawing functions (global only)
    if upper.starts_with("DRAW_") || matches!(upper.as_str(),
        "RECT"|"POLYGON"|"CIRCLE"|"ARC"|"SPIRAL"|"DRAW_VECTORLIST"
    ) {
        return true;
    }

    // Asset system functions
    if matches!(upper.as_str(), "DRAW_VECTOR"|"DRAW_VECTOR_EX"|"PLAY_MUSIC") {
        return true;
    }

    // Vectorlist-specific functions
    if matches!(upper.as_str(),
        "FRAME_BEGIN"|"VECTOR_PHASE_BEGIN"|"WAIT_RECAL"|"PLAY_MUSIC1"|
        "DBG_STATIC_VL"|"DRAW_VL"
    ) {
        return true;
    }

    // Backward compatibility (deprecated)
    if matches!(upper.as_str(),
        "INTENSITY"|"ORIGIN"|"MOVE_TO"|
        "VECTREX_MOVE_TO"|"VECTREX_DRAW_TO"|"VECTREX_DRAW_LINE"|"VECTREX_SET_ORIGIN"|"VECTREX_SET_INTENSITY"|
        "VECTREX_FRAME_BEGIN"|"VECTREX_VECTOR_PHASE_BEGIN"|"VECTREX_WAIT_RECAL"|"VECTREX_PLAY_MUSIC1"|
        "VECTREX_DBG_STATIC_VL"|"VECTREX_DRAW_VL"|"VECTREX_DRAW_VECTORLIST"
    ) {
        return true;
    }

    // Trigonometry (precomputed tables)
    if matches!(upper.as_str(),
        "SIN"|"COS"|"TAN"|"MATH_SIN"|"MATH_COS"|"MATH_TAN"|"MATH.SIN"|"MATH.COS"|"MATH.TAN"
    ) {
        return true;
    }

    // Level system
    if matches!(upper.as_str(), "LOAD_LEVEL"|"SHOW_LEVEL"|"UPDATE_LEVEL") {
        return true;
    }

    // Message dispatch system
    if matches!(upper.as_str(), "MSG_DEF"|"PRINT_MSG") {
        return true;
    }

    // Camera / scroll
    if matches!(upper.as_str(), "SET_CAMERA_X") {
        return true;
    }

    false
}

/// Localized string lookup. Unknown keys are returned verbatim.
pub fn tr(locale: &str, key: &str) -> String {
    let l = if locale.starts_with("es") { "es" } else { "en" };
    let val = match (l, key) {
        ("en", "init.ready") => "VPy LSP initialized",
        ("es", "init.ready") => "VPy LSP inicializado",
        ("en", "diagnostic.polygon.degenerate") => "POLYGON count 2 produces a degenerate list (use >=3 or a thin RECT).",
        ("es", "diagnostic.polygon.degenerate") => "POLYGON count 2 genera lista degenerada (usa >=3 o un RECT delgado).",
        ("en", "diagnostic.arity.too_few") => "Function `{}` expects {} arguments, but {} were provided.",
        ("es", "diagnostic.arity.too_few") => "La función `{}` espera {} argumentos, pero se proporcionaron {}.",
        ("en", "diagnostic.arity.too_many") => "Function `{}` expects {} arguments, but {} were provided.",
        ("es", "diagnostic.arity.too_many") => "La función `{}` espera {} argumentos, pero se proporcionaron {}.",
        ("en", "diagnostic.arity.variable") => "Function `{}` expects at least {} arguments, but {} were provided.",
        ("es", "diagnostic.arity.variable") => "La función `{}` espera al menos {} argumentos, pero se proporcionaron {}.",
        ("en", "hover.user_function.line") => "Function `{}` defined at line {}",
        ("es", "hover.user_function.line") => "Función `{}` definida en línea {}",
        // Unified functions (global + vectorlist)
        ("en", "doc.MOVE") => "MOVE(x, y)  - moves the beam to position (x,y) without drawing.",
        ("es", "doc.MOVE") => "MOVE(x, y)  - mueve el haz a la posición (x,y) sin dibujar.",
        ("en", "doc.SET_INTENSITY") => "SET_INTENSITY(val)  - sets beam intensity.",
        ("es", "doc.SET_INTENSITY") => "SET_INTENSITY(val)  - fija la intensidad del haz.",
        ("en", "doc.DRAW_TO") => "DRAW_TO(x, y)  - draws line to position.",
        ("es", "doc.DRAW_TO") => "DRAW_TO(x, y)  - dibuja línea a posición.",
        ("en", "doc.DRAW_LINE") => "DRAW_LINE(x1, y1, x2, y2, intensity)  - draws line segment.",
        ("es", "doc.DRAW_LINE") => "DRAW_LINE(x1, y1, x2, y2, intensidad)  - dibuja segmento.",
        ("en", "doc.SET_ORIGIN") => "SET_ORIGIN()  - resets origin (0,0).",
        ("es", "doc.SET_ORIGIN") => "SET_ORIGIN()  - restablece origen (0,0).",
        ("en", "doc.PRINT_TEXT") => "PRINT_TEXT(x, y, \"text\")  - shows vector text.",
        ("es", "doc.PRINT_TEXT") => "PRINT_TEXT(x, y, \"texto\")  - muestra texto vectorial.",

        // Direct drawing functions
        ("en", "doc.RECT") => "RECT(x1, y1, x2, y2)  - draws a rectangle.",
        ("es", "doc.RECT") => "RECT(x1, y1, x2, y2)  - dibuja un rectángulo.",
        ("en", "doc.POLYGON") => "POLYGON(n, x1, y1, ...)  - draws a polygon with n vertices.",
        ("es", "doc.POLYGON") => "POLYGON(n, x1, y1, ...)  - dibuja un polígono de n vértices.",
        ("en", "doc.CIRCLE") => "CIRCLE(cx, cy, r) or CIRCLE(cx, cy, r, segs)  - draws a circle.",
        ("es", "doc.CIRCLE") => "CIRCLE(cx, cy, r) o CIRCLE(cx, cy, r, segs)  - dibuja un círculo.",
        ("en", "doc.ARC") => "ARC(cx, cy, r, startDeg, sweepDeg) or ARC(..., segs)  - draws an arc.",
        ("es", "doc.ARC") => "ARC(cx, cy, r, angIni, angFin) o ARC(..., segs)  - dibuja un arco.",
        ("en", "doc.SPIRAL") => "SPIRAL(cx, cy, r_start, r_end, turns) or SPIRAL(..., segs)  - draws a spiral.",
        ("es", "doc.SPIRAL") => "SPIRAL(cx, cy, r_ini, r_fin, vueltas) o SPIRAL(..., segs)  - dibuja una espiral.",
        ("en", "doc.DRAW_VECTORLIST") => "DRAW_VECTORLIST addr,len  - draws a raw vector list (advanced).",
        ("es", "doc.DRAW_VECTORLIST") => "DRAW_VECTORLIST dir,long  - dibuja una vector list cruda (avanzado).",
        ("en", "doc.DRAW_VECTOR_ROT") => "DRAW_VECTOR_ROT(\"name\", x, y, angle [, mirror [, intensity]])  - draws a .vec sprite at (x,y) rotated about its centre; angle 0..127 = one full turn counter-clockwise (32 = 90 degrees), as SIN/COS.",
        ("es", "doc.DRAW_VECTOR_ROT") => "DRAW_VECTOR_ROT(\"nombre\", x, y, ángulo [, espejo [, intensidad]])  - dibuja un sprite .vec en (x,y) girado sobre su centro; ángulo 0..127 = una vuelta completa en sentido antihorario (32 = 90 grados), como SIN/COS.",

        // Vectorlist-specific functions
        ("en", "doc.FRAME_BEGIN") => "FRAME_BEGIN intensity  - begins new frame.",
        ("es", "doc.FRAME_BEGIN") => "FRAME_BEGIN intensidad  - iniciar nuevo frame.",
        ("en", "doc.VECTOR_PHASE_BEGIN") => "VECTOR_PHASE_BEGIN  - begins vector phase.",
        ("es", "doc.VECTOR_PHASE_BEGIN") => "VECTOR_PHASE_BEGIN  - iniciar fase vectorial.",
        ("en", "doc.WAIT_RECAL") => "WAIT_RECAL  - waits for recalibration.",
        ("es", "doc.WAIT_RECAL") => "WAIT_RECAL  - esperar recalibración.",
        ("en", "doc.PLAY_MUSIC1") => "PLAY_MUSIC1  - plays music track 1.",
        ("es", "doc.PLAY_MUSIC1") => "PLAY_MUSIC1  - reproducir música pista 1.",
        ("en", "doc.DBG_STATIC_VL") => "DBG_STATIC_VL  - debug static vectorlist.",
        ("es", "doc.DBG_STATIC_VL") => "DBG_STATIC_VL  - debug vectorlist estática.",
        ("en", "doc.DRAW_VL") => "DRAW_VL addr,len  - draws raw vectorlist.",
        ("es", "doc.DRAW_VL") => "DRAW_VL dir,long  - dibuja vectorlist cruda.",

        // Backward compatibility (deprecated)
        ("en", "doc.INTENSITY") => "INTENSITY val  - DEPRECATED: use SET_INTENSITY instead.",
        ("es", "doc.INTENSITY") => "INTENSITY val  - OBSOLETO: usar SET_INTENSITY en su lugar.",
        ("en", "doc.ORIGIN") => "ORIGIN  - DEPRECATED: use SET_ORIGIN instead.",
        ("es", "doc.ORIGIN") => "ORIGIN  - OBSOLETO: usar SET_ORIGIN en su lugar.",
        ("en", "doc.MOVE_TO") => "MOVE_TO x,y  - DEPRECATED: use MOVE instead.",
        ("es", "doc.MOVE_TO") => "MOVE_TO x,y  - OBSOLETO: usar MOVE en su lugar.",

        // Message dispatch system
        ("en", "doc.MSG_DEF") => "MSG_DEF(id, x, y, text)  - data declaration for message dispatch table. Registers a message with a numeric id (1-based), x/y screen coordinates, and text string. Emits no runtime code — used by PRINT_MSG.",
        ("es", "doc.MSG_DEF") => "MSG_DEF(id, x, y, texto)  - declaración de dato para tabla de despacho de mensajes. Registra un mensaje con id numérico (base 1), coordenadas x/y y texto. No emite código en tiempo de ejecución — usado por PRINT_MSG.",
        ("en", "doc.PRINT_MSG") => "PRINT_MSG(id_expr)  - prints the message registered with MSG_DEF for the given id. Dispatches via a ROM lookup table, replacing large if/elif chains.",
        ("es", "doc.PRINT_MSG") => "PRINT_MSG(id_expr)  - imprime el mensaje registrado con MSG_DEF para el id dado. Despacha mediante tabla ROM, reemplazando cadenas largas de if/elif.",

        // Camera / scroll
        ("en", "doc.SET_CAMERA_X") => "SET_CAMERA_X(offset)  - sets the horizontal scroll camera offset (16-bit value).",
        ("es", "doc.SET_CAMERA_X") => "SET_CAMERA_X(offset)  - fija el desplazamiento horizontal de cámara (valor de 16 bits).",

        _ => key,
    };
    val.to_string()
}

/// Hover documentation for a builtin, given its upper-cased name.
pub fn builtin_doc(locale: &str, upper: &str) -> Option<String> {
    // The compiler's own: every form, the doc line of docs/MANUAL.md, the targets
    if let Some(b) = crate::catalog::lookup(upper) {
        let mut doc = b.signatures.iter().map(|s| format!("`{s}`")).collect::<Vec<_>>().join("  \n");
        if let Some(d) = &b.doc {
            doc.push_str(&format!("\n\n{d}"));
        }
        doc.push_str(&format!("\n\nTargets: {}", b.targets.join(", ")));
        return Some(doc);
    }
    let key = match upper {
        // Unified functions (global + vectorlist)
        "MOVE" => "doc.MOVE",
        "SET_INTENSITY" => "doc.SET_INTENSITY",
        "DRAW_TO" => "doc.DRAW_TO",
        "DRAW_LINE" => "doc.DRAW_LINE",
        "SET_ORIGIN" => "doc.SET_ORIGIN",
        "PRINT_TEXT" => "doc.PRINT_TEXT",

        // Direct drawing functions
        "RECT" => "doc.RECT",
        "POLYGON" => "doc.POLYGON",
        "CIRCLE" => "doc.CIRCLE",
        "ARC" => "doc.ARC",
        "SPIRAL" => "doc.SPIRAL",
        "DRAW_VECTORLIST" | "VECTREX_DRAW_VECTORLIST" => "doc.DRAW_VECTORLIST",
        "DRAW_VECTOR_ROT" => "doc.DRAW_VECTOR_ROT",

        // Vectorlist-specific functions
        "FRAME_BEGIN" | "VECTREX_FRAME_BEGIN" => "doc.FRAME_BEGIN",
        "VECTOR_PHASE_BEGIN" | "VECTREX_VECTOR_PHASE_BEGIN" => "doc.VECTOR_PHASE_BEGIN",
        "WAIT_RECAL" | "VECTREX_WAIT_RECAL" => "doc.WAIT_RECAL",
        "PLAY_MUSIC1" | "VECTREX_PLAY_MUSIC1" => "doc.PLAY_MUSIC1",
        "DBG_STATIC_VL" | "VECTREX_DBG_STATIC_VL" => "doc.DBG_STATIC_VL",
        "DRAW_VL" | "VECTREX_DRAW_VL" => "doc.DRAW_VL",

        // Backward compatibility (deprecated)
        "INTENSITY" => "doc.INTENSITY",
        "ORIGIN" => "doc.ORIGIN",
        "MOVE_TO" | "VECTREX_MOVE_TO" => "doc.MOVE_TO",
        "VECTREX_DRAW_TO" => "doc.DRAW_TO",
        "VECTREX_DRAW_LINE" => "doc.DRAW_LINE",
        "VECTREX_SET_ORIGIN" => "doc.SET_ORIGIN",
        "VECTREX_SET_INTENSITY" => "doc.SET_INTENSITY",

        // Message dispatch system
        "MSG_DEF" => "doc.MSG_DEF",
        "PRINT_MSG" => "doc.PRINT_MSG",

        // Camera / scroll
        "SET_CAMERA_X" => "doc.SET_CAMERA_X",

        _ => return None,
    };
    Some(tr(locale, key))
}
