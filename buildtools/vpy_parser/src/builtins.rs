/// Check if a name is a known builtin function
///
/// This prevents builtins like MUSIC_UPDATE() from being parsed as StructInit.
/// Builtins with no args that start with uppercase would otherwise be confused
/// with struct initialization calls.
pub fn is_known_builtin(name: &str) -> bool {
    matches!(
        name,
        // Core builtins (0 args)
        "WAIT_RECAL"
            | "SET_ORIGIN"
            | "MUSIC_UPDATE"
            | "STOP_MUSIC"
            | "SFX_UPDATE"
            | "PLAY_MUSIC1"
            | "DBG_STATIC_VL"
            | "VECTOR_PHASE_BEGIN"
            // Joystick input builtins
            | "J1_X"
            | "J1_Y"
            | "J1_X_DIGITAL"
            | "J1_Y_DIGITAL"
            | "J1_X_ANALOG"
            | "J1_Y_ANALOG"
            | "UPDATE_BUTTONS"
            | "J1_BUTTON_1"
            | "J1_BUTTON_2"
            | "J1_BUTTON_3"
            | "J1_BUTTON_4"
            // Level system builtins
            | "SHOW_LEVEL"
            | "UPDATE_LEVEL"
            | "GET_LEVEL_BOUNDS"
            | "SET_CAMERA_X"
            // Multi-arg builtins
            | "MOVE"
            | "PRINT_TEXT"
            | "PRINT_NUMBER"
            | "DRAW_TO"
            | "DRAW_LINE"
            | "DEBUG_PRINT"
            | "DEBUG_PRINT_LABELED"
            | "DEBUG_PRINT_STR"
            | "DRAW_VECTOR"
            | "PLAY_MUSIC"
            | "PLAY_SFX"
            | "DRAW_VECTOR_LIST"
            | "DRAW_VL"
            | "FRAME_BEGIN"
            | "ABS"
            | "LEN"
            | "ASM"
            | "SET_INTENSITY"
            | "DRAW_VECTOR_EX"
            | "DRAW_RECT"
            | "DRAW_FILLED_RECT"
            | "DRAW_CIRCLE"
            | "DRAW_CIRCLE_SEG"
            | "DRAW_POLYGON"
            | "DRAW_ARC"
            | "DRAW_ELLIPSE"
    )
}

/// Get the expected arity (number of arguments) for a builtin function
pub fn builtin_arity(name: &str) -> Option<usize> {
    match name {
        // 0-argument builtins
        "WAIT_RECAL" | "SET_ORIGIN" | "MUSIC_UPDATE" | "STOP_MUSIC" | "SFX_UPDATE"
        | "PLAY_MUSIC1" | "DBG_STATIC_VL" | "VECTOR_PHASE_BEGIN" | "J1_X" | "J1_Y"
        | "J1_X_DIGITAL" | "J1_Y_DIGITAL" | "J1_X_ANALOG" | "J1_Y_ANALOG" | "UPDATE_BUTTONS"
        | "J1_BUTTON_1" | "J1_BUTTON_2" | "J1_BUTTON_3" | "J1_BUTTON_4" | "SHOW_LEVEL"
        | "UPDATE_LEVEL" | "GET_LEVEL_BOUNDS" => Some(0),

        // 1-argument builtins
        "DRAW_VECTOR" | "PLAY_MUSIC" | "PLAY_SFX" | "ABS" | "LEN" | "ASM" | "SET_CAMERA_X" => Some(1),

        // 2-argument builtins
        "MOVE" | "DRAW_TO" => Some(2),

        // 3-argument builtins
        "DRAW_LINE" | "PRINT_TEXT" | "PRINT_NUMBER" => Some(3),

        // Variable-argument or context-dependent
        "DEBUG_PRINT" | "DEBUG_PRINT_LABELED" | "DEBUG_PRINT_STR" => None,
        "DRAW_VECTOR_LIST" | "DRAW_VL" => None,
        "FRAME_BEGIN" => None,
        "SET_INTENSITY" => Some(1),
        "DRAW_VECTOR_EX" => Some(4),

        _ => None,
    }
}
