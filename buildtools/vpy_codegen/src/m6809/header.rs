//! Vectrex Cartridge Header Generation
//!
//! Format:
//! - Copyright string: "g GCE 2025"
//! - Music pointer: $0000 (none)
//! - Box dimensions: height, width, rel_y, rel_x
//! - Game title (from META TITLE)

use vpy_parser::ModuleMeta;

pub fn generate_header(title: &str, _meta: &ModuleMeta) -> Result<String, String> {
    let mut asm = String::new();
    
    asm.push_str(";***************************************************************************\n");
    asm.push_str("; CARTRIDGE HEADER\n");
    asm.push_str(";***************************************************************************\n");
    
    // Copyright string (required by BIOS)
    asm.push_str("    FCC \"g GCE 2025\"\n");
    asm.push_str("    FCB $80                 ; String terminator\n");
    
    // Music pointer (BIOS music symbols defined in VECTREX.I: music1-musicd)
    let music_ptr = if let Some(ref music_name) = _meta.music_override {
        music_name.as_str()
    } else {
        "music1"
    };
    asm.push_str(&format!("    FDB {}              ; Music pointer\n", music_ptr));
    
    // Box dimensions (standard size)
    asm.push_str("    FCB $F8,$50,$20,$BB     ; Height, Width, Rel Y, Rel X\n");
    
    // Game title
    let title_str = if title.is_empty() {
        "VPY GAME"
    } else {
        title
    };
    asm.push_str(&format!("    FCC \"{}\"\n", title_str));
    asm.push_str("    FCB $80                 ; String terminator\n");
    asm.push_str("    FCB 0                   ; End of header\n\n");
    
    Ok(asm)
}
