/*
 * uvm2_draw.h — Vectrex analog beam control, recorded as a VIA command stream.
 *
 * This is the port of Ralf's VectrexHaltCommandWriter: the sequences that a
 * 6809 would write to the VIA to move, light and blank the beam, emitted into a
 * buffer instead of onto the bus.  uvm2_frame_end() hands the whole buffer to
 * uvm2_exec(), so the beam draws with no gaps and the CPU never blocks on a
 * clock edge while composing a frame.
 *
 * Coordinates are VPy/Vectrex units, roughly -127..127 with +Y up, and deltas
 * are what the SYS_MOVE / SYS_DRAW_DELTA syscalls carry.  Intensity is 0..127.
 */
#ifndef UVM2_DRAW_H
#define UVM2_DRAW_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Configure the VIA and prime the integrators.  Call once, after uvm2_bus_init. */
void uvm2_draw_init(void);

/* SYS_RESET0REF — beam back to centre, blanked (zero the integrators). */
void uvm2_draw_reset(void);
/* Drop the cached DAC/mux state — see the note in uvm2_draw.c. */
void uvm2_draw_invalidate(void);
/* Re-charge the zero-reference / Y / Z holds after an analog read. */
void uvm2_draw_prime_holds(void);

/* SYS_SET_INTENSITY — Z-axis DAC, 0..127. */
void uvm2_draw_intensity(int brightness);

/* SYS_MOVE / SYS_DRAW_DELTA — relative, blanked and lit respectively. */
void uvm2_draw_move(int dx, int dy);
void uvm2_draw_delta(int dx, int dy);

/* SYS_MOVE_ABS — absolute position, measured from centre. */
void uvm2_draw_move_abs(int x, int y);

/* Frame boundary.  uvm2_frame_end() blanks, re-centres, replays the stream and
 * then pads the frame out to exactly 30000 bus cycles (50 Hz), locked to the
 * Vectrex clock rather than to any RP2350 timer. */
void uvm2_frame_begin(void);
void uvm2_frame_end(void);

/* Frames completed since boot — the only clock a halted Vectrex gives us. */
uint32_t uvm2_frame_count(void);

/* Bus cycles the last frame actually consumed, padding included. Equals
 * UVM2_CYCLES_PER_FRAME for a frame that fit, and more for one that did not —
 * which is how audio keeps its tempo when drawing runs over. */
uint32_t uvm2_frame_bus_cycles(void);

/* ── Throughput levers (the point of the command-stream model) ──────────────
 * scale is the ramp duration in bus cycles for a full-range delta; it is the
 * dominant per-vector cost.  With scale = 128 a vector costs ~136 cycles, so a
 * 50 Hz frame fits ~220 of them.
 *
 * "fixup" is the lever Ralf left in his writer but commented out: while a delta
 * is small, double it and halve the scale.  A short vector then ramps for far
 * fewer cycles at the same length on screen.  Off by default so measurements
 * are directly comparable to his; turn it on to see the difference. */
void uvm2_draw_set_scale(uint32_t cycles);
void uvm2_draw_set_fixup(int enable);

#ifdef __cplusplus
}
#endif

#endif /* UVM2_DRAW_H */
