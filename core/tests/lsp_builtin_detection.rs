use vectrex_lang::lsp::*;

#[test]
fn test_lsp_builtin_detection() {
    // Funciones unificadas (global + vectorlist)
    assert!(is_builtin_function("MOVE"));
    assert!(is_builtin_function("SET_INTENSITY"));
    assert!(is_builtin_function("DRAW_TO"));
    assert!(is_builtin_function("DRAW_LINE"));
    assert!(is_builtin_function("SET_ORIGIN"));
    assert!(is_builtin_function("PRINT_TEXT"));
    
    // Funciones específicas de dibujo directo
    assert!(is_builtin_function("RECT"));
    assert!(is_builtin_function("DRAW_POLYGON"));
    assert!(is_builtin_function("CIRCLE"));
    
    // Funciones específicas de vectorlist
    assert!(is_builtin_function("FRAME_BEGIN"));
    assert!(is_builtin_function("WAIT_RECAL"));
    
    // Compatibilidad hacia atrás (deprecated)
    assert!(is_builtin_function("INTENSITY"));      // deprecated: use SET_INTENSITY
    assert!(is_builtin_function("ORIGIN"));         // deprecated: use SET_ORIGIN
    assert!(is_builtin_function("MOVE_TO"));        // deprecated: use MOVE
    
    // Funciones no existentes no deben ser detectadas
    assert!(!is_builtin_function("NOT_A_FUNCTION"));
    assert!(!is_builtin_function("MY_CUSTOM_FUNC"));

    // Message dispatch system
    assert!(is_builtin_function("MSG_DEF"));
    assert!(is_builtin_function("PRINT_MSG"));

    // Camera / scroll
    assert!(is_builtin_function("SET_CAMERA_X"));
}

#[test]
fn test_lsp_builtin_arity() {
    use vectrex_lang::lsp::get_builtin_arity;
    
    // Funciones unificadas
    assert!(matches!(get_builtin_arity("MOVE"), Some(AritySpec::Exact(2))));
    assert!(matches!(get_builtin_arity("SET_INTENSITY"), Some(AritySpec::Exact(1))));
    assert!(matches!(get_builtin_arity("DRAW_TO"), Some(AritySpec::Exact(2))));
    assert!(matches!(get_builtin_arity("DRAW_LINE"), Some(AritySpec::Exact(5))));
    assert!(matches!(get_builtin_arity("SET_ORIGIN"), Some(AritySpec::Exact(0))));
    
    // Funciones específicas  
    assert!(matches!(get_builtin_arity("RECT"), Some(AritySpec::Exact(4))));
    assert!(matches!(get_builtin_arity("CIRCLE"), Some(AritySpec::Exact(1))));
    assert!(matches!(get_builtin_arity("FRAME_BEGIN"), Some(AritySpec::Exact(1))));
    
    // Compatibilidad hacia atrás
    assert!(matches!(get_builtin_arity("MOVE_TO"), Some(AritySpec::Exact(2))));        // deprecated: use MOVE
    assert!(matches!(get_builtin_arity("INTENSITY"), Some(AritySpec::Exact(1))));      // deprecated: use SET_INTENSITY
    assert!(matches!(get_builtin_arity("ORIGIN"), Some(AritySpec::Exact(0))));         // deprecated: use SET_ORIGIN
    
    // Funciones inexistentes
    assert!(get_builtin_arity("NOT_A_FUNCTION").is_none());

    // Message dispatch system
    assert!(matches!(get_builtin_arity("MSG_DEF"), Some(AritySpec::Exact(4))));
    assert!(matches!(get_builtin_arity("PRINT_MSG"), Some(AritySpec::Exact(1))));

    // Camera / scroll
    assert!(matches!(get_builtin_arity("SET_CAMERA_X"), Some(AritySpec::Exact(1))));
}