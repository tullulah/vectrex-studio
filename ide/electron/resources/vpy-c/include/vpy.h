/*
 * vpy.h — the VPy builtin runtime, in C.
 *
 * Reimplements the procedural VPy builtins (draw / input / math / text) ON TOP
 * of the minimal PiTrex SDK contract (vectrexInterface.h: v_directDraw32,
 * v_WaitRecal, v_readButtons, v_readJoystick1Analog, v_millis, v_setSoundAY).
 * Because it uses ONLY that contract, the same C code runs identically on real
 * PiTrex hardware and in the Vectrex Studio emulator panel (WASM + host shim).
 *
 * Coordinates use the same logical VPy space as the .vpy language (roughly
 * -127..127, +Y up); vpy scales by x127 to PiTrex units, exactly like the VPy
 * pitrex codegen. Brightness is 0..127.
 */
#ifndef VPY_H
#define VPY_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ---- lifecycle ---- */
void vpy_init(void);                 /* vectrexinit + v_init + v_setRefresh(60) */
void vpy_frame_begin(void);          /* v_WaitRecal + refresh input snapshot   */
void vpy_run(void (*setup)(void), void (*loop)(void)); /* init; setup(); loop forever */

/* ---- drawing (VPy space, brightness 0..127) ---- */
void vpy_set_intensity(int b);
void vpy_move(int x, int y);
void vpy_draw_line(int x0, int y0, int x1, int y1, int b);
void vpy_draw_circle(int cx, int cy, int r, int b);
void vpy_draw_rect(int x, int y, int w, int h, int b);           /* x,y = lower-left */
void vpy_draw_filled_rect(int x, int y, int w, int h, int b);
void vpy_draw_polygon(const int *xy, int n, int b);              /* n vertices, xy[2n] */
void vpy_draw_ellipse(int cx, int cy, int rx, int ry, int b);    /* 16-segment ellipse */

/* ---- compiled vector sprites (.vec) --------------------------------------
 * `data` is a vector path stream compiled from a .vec by
 *   `vpy_cli compile-asset <file>.vec --format c --out <name>.h`
 * (same path/segment geometry compiler as the ARM/PiTrex backend). The sprite
 * is drawn at VPy position (x,y) using the asset's own per-path intensity.
 * Bezier segments are tessellated into lines (the host contract only exposes
 * v_directDraw32). draw_vector_ex adds horizontal mirror + an optional
 * intensity override (pass intensity<=0 to keep each path's own intensity). */
void vpy_draw_vector(const unsigned char *data, int x, int y);
void vpy_draw_vector_ex(const unsigned char *data, int x, int y, int mirror, int intensity);

/* ---- text ---- */
void vpy_set_text_size(int s);       /* glyph scale (VPy units per grid unit ~ s) */
void vpy_print_text(int x, int y, const char *s);
void vpy_print_number(int x, int y, long n);

/* ---- input ---- */
int vpy_j1_x(void);                  /* -127..127 */
int vpy_j1_y(void);                  /* -127..127 (+ = up) */
int vpy_j1_button(int n);            /* n = 1..4 -> 0/1 */

/* ---- math ---- */
int vpy_abs(int v);
int vpy_min(int a, int b);
int vpy_max(int a, int b);
int vpy_clamp(int v, int lo, int hi);
int vpy_sin(int a);                  /* a: 0..127 = full circle; returns -127..127 */
int vpy_cos(int a);
int vpy_sqrt(int v);
int vpy_atan2(int y, int x);         /* returns 0..127 (full circle) */
int vpy_rand(void);
int vpy_rand_range(int lo, int hi);
void vpy_seed(unsigned s);

/* ---- sound (basic tone on PSG channel A) ---- */
void vpy_beep(int on);
void vpy_tone(int period, int volume); /* period 12-bit, volume 0..15; 0 vol = off */

/* ---- compiled music / SFX playback ---------------------------------------
 * `data` is a PSG event stream compiled from a .vmus/.vsfx by
 *   `vpy_cli compile-asset <file> --format c --out <name>.h`
 * (same notes->PSG compiler as the ARM/PiTrex backend). A simple 50 Hz
 * sequencer walks the stream, writing PSG registers via v_setSoundAY each frame.
 * vpy_run() drives vpy_music_update()/vpy_sfx_update() automatically. */
void vpy_play_music(const unsigned char *data);  /* start/replace music playback */
void vpy_music_update(void);                      /* advance one frame (auto-called) */
void vpy_stop_music(void);                         /* mute channels + stop */
void vpy_play_sfx(const unsigned char *data);     /* trigger a one-shot SFX (channel C) */
void vpy_sfx_update(void);                         /* advance one frame (auto-called) */

/* Optional VPy-style uppercase aliases so migrated .vpy reads naturally. */
#ifdef VPY_SHORT_NAMES
#define SET_INTENSITY   vpy_set_intensity
#define MOVE            vpy_move
#define DRAW_LINE       vpy_draw_line
#define DRAW_CIRCLE     vpy_draw_circle
#define DRAW_RECT       vpy_draw_rect
#define DRAW_FILLED_RECT vpy_draw_filled_rect
#define DRAW_POLYGON    vpy_draw_polygon
#define DRAW_ELLIPSE    vpy_draw_ellipse
#define DRAW_VECTOR     vpy_draw_vector
#define DRAW_VECTOR_EX  vpy_draw_vector_ex
#define SET_TEXT_SIZE   vpy_set_text_size
#define PRINT_TEXT      vpy_print_text
#define PRINT_NUMBER    vpy_print_number
#define J1_X            vpy_j1_x
#define J1_Y            vpy_j1_y
#define PLAY_MUSIC      vpy_play_music
#define STOP_MUSIC      vpy_stop_music
#define PLAY_SFX        vpy_play_sfx
#endif

#ifdef __cplusplus
}
#endif

#endif /* VPY_H */
