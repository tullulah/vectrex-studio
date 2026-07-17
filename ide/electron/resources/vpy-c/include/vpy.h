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

/* Optional VPy-style uppercase aliases so migrated .vpy reads naturally. */
#ifdef VPY_SHORT_NAMES
#define SET_INTENSITY   vpy_set_intensity
#define MOVE            vpy_move
#define DRAW_LINE       vpy_draw_line
#define DRAW_CIRCLE     vpy_draw_circle
#define DRAW_RECT       vpy_draw_rect
#define DRAW_FILLED_RECT vpy_draw_filled_rect
#define DRAW_POLYGON    vpy_draw_polygon
#define SET_TEXT_SIZE   vpy_set_text_size
#define PRINT_TEXT      vpy_print_text
#define PRINT_NUMBER    vpy_print_number
#define J1_X            vpy_j1_x
#define J1_Y            vpy_j1_y
#endif

#ifdef __cplusplus
}
#endif

#endif /* VPY_H */
