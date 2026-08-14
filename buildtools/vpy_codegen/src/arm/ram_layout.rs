//! RAM layout for RP2350 target.
//!
//! RP2350 SRAM: 512KB @ 0x20000000
//! We use a small fixed area at the top of SRAM for VPy runtime variables.
//! User variables follow immediately after.
//!
//! Layout:
//!   0x20000000  SRAM start (stack grows down from 0x20080000)
//!   0x2007F000  VPy runtime area (4KB reserved)
//!     +0x000  TMPVAL      (4 bytes) — 32-bit arithmetic temporary
//!     +0x004  TMPPTR      (4 bytes) — pointer temporary
//!     +0x008  TMPPTR2     (4 bytes) — second pointer temporary
//!     +0x00C  ARG0..ARG4  (5×4 = 20 bytes) — function call arguments
//!     +0x020  RESULT      (4 bytes) — function return value
//!     +0x024  BEEP_FRAMES (4 bytes) — non-blocking beep counter
//!     +0x028  USER_RAM_START — user variables allocated here upward

pub fn emit_ram_layout() -> String {
    let mut s = String::from("@ --- VPy runtime RAM (RP2350 SRAM) ---\n");
    let base: u32 = 0x2007_F000;

    let vars: &[(&str, u32, &str)] = &[
        ("TMPVAL",          0x000, "32-bit arithmetic temporary"),
        ("TMPPTR",          0x004, "pointer temporary"),
        ("TMPPTR2",         0x008, "second pointer temporary"),
        ("VAR_ARG0",        0x00C, "function argument 0"),
        ("VAR_ARG1",        0x010, "function argument 1"),
        ("VAR_ARG2",        0x014, "function argument 2"),
        ("VAR_ARG3",        0x018, "function argument 3"),
        ("VAR_ARG4",        0x01C, "function argument 4"),
        ("RESULT",          0x020, "function return value"),
        ("BEEP_FRAMES_LEFT",0x024, "non-blocking beep counter"),
        ("VIA_WRITE_ADDR",  0x028, "scratch for bus_write address"),
        ("VIA_WRITE_DATA",  0x02C, "scratch for bus_write data"),
        // 3D drawing engine scratch (used by dv3d_* functions)
        ("_dv3d_cos",       0x030, "3D cos offsets: cos_ax, cos_ay, cos_az (3 bytes)"),
        ("_dv3d_tmp",       0x034, "3D vertex raw coords: rx, ry, rz (3 bytes)"),
        ("_dv3d_sm",        0x038, "3D rotation intermediates: t0, y1, z1, x2 (4 bytes)"),
        ("_dv3d_cur",       0x03C, "3D current beam pos: cur_x, cur_y (2 bytes)"),
        ("_dv3d_fst",       0x03E, "3D first vertex of path: first_x, first_y (2 bytes)"),
        ("_dv3d_vbuf",      0x040, "3D rotated vertex cache: sx,sy pairs (254 bytes max)"),
        // Animation state (0x13E–0x13F): 2-byte gap between vbuf and RAND_SEED
        ("VPY_ANIM_STATE_BUF",  0x13E, "animation frame_idx(u8) at +0, ticks_left(u8) at +1"),
        // Runtime state variables (0x140–0x1BF)
        ("RAND_SEED",        0x140, "LCG random number seed"),
        ("BTN_STATE_J1",     0x144, "cached VIA Port B (J1 buttons, bits 4-7 active-low)"),
        ("BTN_STATE_J2",     0x148, "cached PSG reg 14 (J2 buttons, bits 0-3 active-low)"),
        ("CAMERA_X",         0x14C, "camera X offset (used by show_level)"),
        ("CAMERA_Y",         0x150, "camera Y offset"),
        ("TEXT_SIZE",        0x154, "text scale factor (1=normal, 2=double, ...)"),
        // 0x158 free — was TEXT_COLOR (removed: monochrome console, use SET_INTENSITY)
        ("LEVEL_DATA_PTR",   0x15C, "pointer to loaded level ROM data"),
        ("DBGVAL",           0x160, "debug_print last written value"),
        ("PRINT_BEAM_X",     0x164, "beam X shadow during print_text"),
        ("PRINT_BEAM_Y",     0x168, "beam Y shadow during print_text"),
        // PSG music sequencer (0x16C–0x17F)
        ("PSG_MUSIC_PTR",    0x16C, "pointer to current music event in ROM"),
        ("PSG_MUSIC_START",  0x170, "pointer to loop-start event"),
        ("PSG_IS_PLAYING",   0x174, "1 = music playing"),
        ("PSG_DELAY_FRAMES", 0x178, "frames remaining before next music event"),
        // PSG SFX player (0x17C–0x18B)
        ("PSG_SFX_PTR",      0x17C, "pointer to current SFX event in ROM"),
        ("PSG_SFX_ACTIVE",   0x180, "1 = SFX playing"),
        ("PSG_SFX_DELAY",    0x184, "frames remaining before next SFX event"),
        // Level engine (0x188–0x29B)
        ("LEVEL_GP_COUNT",      0x188, "number of active GP objects"),
        // LEVEL_GP_BUF: 32 objects × 8 bytes = 256 bytes (0x188+4..0x288)
        // Each slot: +0 world_x(i16), +2 world_y(i16), +4 vel_x(i8), +5 vel_y(i8), +6 alive(u8), +7 pad
        ("LEVEL_GP_BUF",        0x18C, "level GP mutable buffer (32 obj × 8 bytes = 256 bytes)"),
        // Scroll limits loaded from .vplay scrollLimits field (0x28C–0x29B)
        ("SCROLL_LIMIT_LEFT",   0x28C, "camera scroll limit: left world X"),
        ("SCROLL_LIMIT_RIGHT",  0x290, "camera scroll limit: right world X"),
        ("SCROLL_LIMIT_TOP",    0x294, "camera scroll limit: top world Y"),
        ("SCROLL_LIMIT_BOTTOM", 0x298, "camera scroll limit: bottom world Y"),
        // PSG NOTE engine (0x29C–0x2FF): 3 channels × 32 bytes = 96 bytes + 4-byte mixer shadow
        ("NOTE_STATE",          0x29C, "note engine state: 3 channels × 32 bytes each"),
        ("PSG_MIXER_SHADOW",    0x2FC, "shadow of AY R7 mixer register (0x3F = all disabled)"),
        // MOVE builtin position (used by DRAW_LINE to compute absolute coordinates)
        ("VPY_MOVE_X",          0x300, "last MOVE X position (added to DRAW_LINE x0/x1)"),
        ("VPY_MOVE_Y",          0x304, "last MOVE Y position (added to DRAW_LINE y0/y1)"),
        // Enemy system (0x308–0x40B): 1 count word + 8 slots × 32 bytes each
        // Each pool slot: +0 active(u32), +4 world_x(i32), +8 world_y(i32),
        //   +12 sprite_ptr(u32), +16 wp_base(u32),
        //   +20 wp_idx(u8)+wp_count(u8)+ai_type(u8)+is_anim(u8),
        //   +24 anim_frame_idx(u8)+anim_ticks_left(u8)+pad(6)
        ("ENEMY_COUNT_ARM",     0x308, "active enemy count"),
        ("ENEMY_POOL_ARM",      0x30C, "enemy pool: 8 slots × 32 bytes"),
        // Joystick axis cache (0x40C–0x41B): read once during WAIT_RECAL, used during game loop
        // Prevents bus_write($D000,...) during display which corrupts VIA PORT B / beam positioning
        ("J1_AXIS_X",           0x40C, "cached J1 X axis (-127..127), updated each WAIT_RECAL"),
        ("J1_AXIS_Y",           0x410, "cached J1 Y axis (-127..127), updated each WAIT_RECAL"),
        ("J2_AXIS_X",           0x414, "cached J2 X axis (-127..127), updated each WAIT_RECAL"),
        ("J2_AXIS_Y",           0x418, "cached J2 Y axis (-127..127), updated each WAIT_RECAL"),
        // Enemy state array (0x41C–0x43B): 8 slots × 4 bytes — GET/SET_ENEMY_STATE
        ("ENEMY_STATE_ARM",     0x41C, "enemy state per slot: 8 × i32"),
        // Per-player animation state (0x43C–0x43D): frame_idx(u8)+ticks_left(u8)
        ("VPY_PLAYER_ANIM_STATE", 0x43C, "player animation state: frame_idx(u8)+ticks_left(u8)"),
        // Brightness override (0x43E, in the free gap before wander scratch): 0=use
        // .vec per-path intensity, >0=override from SET_INTENSITY. Written only by the
        // SET_INTENSITY builtin, read by DRAW_VECTOR/DRAW_VECTOR_3D, reset once per frame.
        ("VPY_BRIGHTNESS_OVERRIDE", 0x43E, "SET_INTENSITY override: 0=.vec intensity, >0=override (1 byte)"),
        // Escala del PROXIMO vpy_draw_vector_ex, en treintaydosavos (32 = 1:1).
        // La pone show_level desde el byte +4 del objeto, y vpy_draw_vector_ex la
        // CONSUME (la deja a 0) para que no se herede a la llamada siguiente. Va por
        // aqui y no como sexto argumento porque los seis llamantes montan la pila de
        // tres formas distintas: un argumento mas habria leido basura en tres de ellos.
        ("VPY_DRAW_SCALE",      0x43F, "escala del proximo DRAW_VECTOR_EX (x32; 0/32 = 1:1, 1 byte)"),
        // Wander AI per-slot scratch (0x440–0x45F): 8 slots × 4 bytes
        // Each slot: +0..1 idle_timer/from_x/vy (i16), +2..3 target_x (i16)
        ("WANDER_SCRATCH_ARM",  0x440, "wander AI scratch: 8 slots x 4 bytes (scratch_a|target_x)"),
        // user RAM starts here (0x460)
        ("USER_RAM_START",      0x460, "user variables begin here"),
    ];

    for (name, offset, comment) in vars {
        s.push_str(&format!(
            ".equ {:<20} 0x{:08X}  @ {}\n",
            format!("{},", name),
            base + offset,
            comment
        ));
    }
    s.push('\n');
    s
}

/// Allocate a user variable and return its address.
/// Called by the functions module while processing GlobalLet items.
pub struct RamAllocator {
    next: u32,
}

impl RamAllocator {
    pub fn new() -> Self {
        Self { next: 0x2007_F460 } // USER_RAM_START (after wander scratch at 0x440–0x45F)
    }

    /// Allocate `bytes` bytes, return base address.
    pub fn alloc(&mut self, bytes: u32) -> u32 {
        // Align to 4 bytes
        let addr = (self.next + 3) & !3;
        self.next = addr + bytes;
        addr
    }
}
