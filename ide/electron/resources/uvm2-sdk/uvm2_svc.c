/*
 * uvm2_svc.c — the UVM2 side of the VPy syscall ABI.
 *
 * `svc #N` is the contract every VPy/C/SBT program already speaks: the same
 * table is implemented by our own cartridge firmware (Rust) and by the IDE
 * emulator (Rp2350System.ts).  This is the third implementation, and the only
 * one that drives a real Vectrex through halt mode.  Because the ABI is shared,
 * the generated image for UVM2 is byte-identical to the RP2350 one apart from
 * the handler that lands here — no forked codegen, no duplicated builtins.
 *
 * Drawing syscalls only RECORD into the command stream; SYS_WAIT_RECAL is what
 * replays it, polls input and paces the frame.
 */

#include "uvm2_bus.h"
#include "uvm2_draw.h"
#include "uvm2_input.h"
#include "uvm2_led.h"
#include "uvm2_text.h"
#include "uvm2_audio.h"

enum {
    SYS_RESET0REF     = 0,
    SYS_WAIT_RECAL    = 1,
    SYS_SET_INTENSITY = 2,
    SYS_MOVE          = 3,
    SYS_DRAW_DELTA    = 4,
    SYS_PSG_WRITE     = 5,
    SYS_PSG_SILENCE   = 6,
    SYS_READ_BUTTONS  = 7,
    SYS_BUS_WRITE     = 8,
    SYS_BUS_READ      = 11,
    SYS_PSG_READ      = 12,
    SYS_READ_AXES     = 13,
    SYS_READ_BTN_RAW  = 14,
    SYS_MOVE_ABS      = 15,
    SYS_PRINT_TEXT    = 16,
    SYS_PLAY_MUSIC    = 21,
    SYS_STOP_MUSIC    = 22,
    SYS_PLAY_SFX      = 23,
    SYS_RASTER_TEXT   = 26,   /* (r0:x, r1:y, r2:str, r3:len) — see sdk_rp2350.c */
};

/* Input is sampled once per frame in SYS_WAIT_RECAL and cached here: the read
 * sequences disturb Port B, so they may only run between frames. */
static uint8_t  s_buttons;
static uint32_t s_axes;
/* Leftover Vectrex time not yet handed to the sequencer, in bus cycles. */
static uint32_t s_audio_acc;

/* Bring-up sequence, narrated on the status LED because there is no other
 * output channel until the beam itself works.  Each stage latches its colour,
 * so a board that stops early leaves the diagnosis visible on the cartridge:
 *   blue  → the image booted but never saw a Vectrex clock yet
 *   red   → no clock at all: console off, or the cart is not seated
 *   amber → clock found, bus taken, VIA being primed
 *   green → frames are going out
 */
void uvm2_runtime_init(void)
{
    /* First, before anything with state: .bss is still whatever was in SRAM. */
    uvm2_cpu_init();

    /* Then the pads, so CLK can be read, and only then the LED — it needs a
     * calibrated cycle counter, and the Vectrex clock is what calibrates it. */
    uvm2_bus_pads();
    uvm2_led_init();
    uvm2_led_status(UVM2_STATUS_BOOT);

    /* Is the 6809 even clocking?  Everything below blocks on CLK edges, so
     * without this check a switched-off console is indistinguishable from a bug
     * in our own code: black screen, frozen cart, no clue which. */
    if (uvm2_clock_calibrate() == 0) {
        uvm2_led_status(UVM2_STATUS_NO_CLOCK);
        for (;;) { }
    }

    uvm2_led_status(UVM2_STATUS_HALTING);
    uvm2_bus_halt();
    uvm2_draw_init();
    /* Short vectors: double the velocity and halve the ramp while the DAC has
     * headroom, so a 4-unit glyph stroke stops paying a full-range 128-cycle ramp.
     * MEASURED on hardware 2026-08-04 before enabling this: dkong spent 140911 bus
     * cycles a frame against a 30000 budget (469%) — ~10.6 Hz refresh, which is the
     * flicker — and 128 of the ~169 cycles per vector were the fixed ramp.
     * The trade is real: distance is preserved (velocity x time) but the beam is lit
     * for less of it, so short vectors come out dimmer. Same bargain as the cart's
     * MIN_T1 floor. Turn it back off with uvm2_draw_set_fixup(0) if that costs more
     * than the refresh rate buys. */
    uvm2_draw_set_fixup(1);
    /* Analog stick. It was implemented all along (read_axis_analog is the BIOS
     * SAR) but s_analog defaulted to 0 and nobody turned it on, so every game got
     * a -1/0/1 verdict. Asteroids and the rest are analog games on real hardware
     * and the cart reads them that way. */
    uvm2_input_set_analog(1);
    uvm2_frame_begin();
    uvm2_led_status(UVM2_STATUS_RUNNING);
}

/* r0-r3 of the interrupted code sit at frame[0..3]; frame[6] is the stacked PC,
 * which points just past the `svc` instruction, so the immediate is at [-2].
 * A result must be written back to frame[0] — exception return reloads r0. */
void uvm2_svc_dispatch(uint32_t *frame)
{
    const uint8_t *pc  = (const uint8_t *)(uintptr_t)frame[6];
    uint32_t       num = pc[-2];
    uint32_t       r0  = frame[0];
    uint32_t       r1  = frame[1];

    switch (num) {
    case SYS_RESET0REF:
        uvm2_draw_reset();
        break;

    case SYS_WAIT_RECAL:
        uvm2_frame_end();
        /* Between frames, with the beam clamped at centre — the only window in
         * which input reads and PSG writes may drive Port B.  Audio is ticked
         * here rather than on a second core, so the .vmus tempo follows the
         * frame rate; a frame over budget stretches the music with it. */
#ifndef UVM2_NO_INPUT
        s_buttons = uvm2_read_buttons();
        s_axes    = uvm2_read_axes();
#endif
        /* Both of those drove Port A/B for the PSG and the analog mux, which the
         * draw path's cached DAC/S-H state does not know about. Drop the cache so
         * the next frame re-establishes Y, Z and the DAC instead of trusting a
         * hold the SAR just overwrote. */
        uvm2_draw_invalidate();

        /* Advance the sequencer by ELAPSED VECTREX TIME, not once per frame.
         * A frame heavy enough to blow the 50 Hz budget takes two frames' worth
         * of bus cycles, and ticking once would play the track at half speed —
         * which is exactly what a draw-heavy game did. Our own cartridge gets
         * this for free by sequencing on core 1; here we count the cycles. */
#ifndef UVM2_NO_AUDIO
        s_audio_acc += uvm2_frame_bus_cycles();
        while (s_audio_acc >= UVM2_CYCLES_PER_FRAME) {
            s_audio_acc -= UVM2_CYCLES_PER_FRAME;
            uvm2_audio_tick();
        }
#endif

        uvm2_frame_begin();
        /* First commands of the new frame: put the zero reference and the Y/Z
         * holds back where the analog read left them. Must come after
         * frame_begin so they are part of the new stream. */
        uvm2_draw_prime_holds();
        break;

#ifdef UVM2_NO_DRAW
    /* Bisection build: swallow every drawing syscall so the stream carries only
     * what frame_end/frame_begin put in it. Anything still visible on screen is
     * produced by the frame boundary, not by the game's geometry. */
    case SYS_SET_INTENSITY:
    case SYS_MOVE:
    case SYS_DRAW_DELTA:
    case SYS_MOVE_ABS:
        break;
#else
    case SYS_SET_INTENSITY:
        uvm2_draw_intensity((int)r0);
        break;

    case SYS_MOVE:
        uvm2_draw_move((int)(int32_t)r0, (int)(int32_t)r1);
        break;

    case SYS_DRAW_DELTA:
        uvm2_draw_delta((int)(int32_t)r0, (int)(int32_t)r1);
        break;

    case SYS_MOVE_ABS:
        uvm2_draw_move_abs((int)(int32_t)r0, (int)(int32_t)r1);
        break;

    /* r0=x, r1=y (both i8), r2=string, r3 = scale | (intensity << 8).
     * The VPy stub has already resolved TEXT_SIZE and the brightness override
     * into r3, so both defaults are applied before we ever see the call. */
    case SYS_PRINT_TEXT:
        uvm2_print_text((int)(int8_t)r0, (int)(int8_t)r1,
                        (const char *)(uintptr_t)frame[2],
                        (int)(frame[3] & 0xFFu), (int)((frame[3] >> 8) & 0xFFu));
        break;

    case SYS_PLAY_MUSIC:
        uvm2_play_music((const uint8_t *)(uintptr_t)r0);
        break;

    case SYS_STOP_MUSIC:
        uvm2_stop_music();
        break;

    case SYS_PLAY_SFX:
        uvm2_play_sfx((const uint8_t *)(uintptr_t)r0);
        break;

    /* Raster text. The cart BIOS draws this with the VIA shift register; here we
     * render it with the vector font, which is what this SDK has. Same call, same
     * arguments — the game cannot tell, and it beats dropping the text. */
    case SYS_RASTER_TEXT: {
        /* r2/r3 are not unpacked at the top of this function — only r0/r1 are —
         * so take the string straight out of the stacked exception frame. */
        const char *str = (const char *)(uintptr_t)frame[2];
        if (str) uvm2_print_text((int)(int8_t)r0, (int)(int8_t)r1, str, 1, 0x5F);
        break;
    }

#endif /* UVM2_NO_DRAW */

    case SYS_PSG_WRITE:
        uvm2_psg_write(r0, r1);
        break;

    case SYS_PSG_READ:
        frame[0] = uvm2_psg_read(r0);
        break;

    case SYS_PSG_SILENCE:
        uvm2_psg_write(8, 0);
        uvm2_psg_write(9, 0);
        uvm2_psg_write(10, 0);
        break;

    /* Two different shapes of the same byte, and they are not interchangeable.
     *   #7  wants "1 = pressed", J1 in bits 0-3 and J2 in bits 4-7.
     *   #14 wants the raw per-port bytes packed as (J1 << 8) | J2, still
     *       active-low, and the generated getters read J1 at bits 4-7 (the VIA
     *       Port B position) and J2 at bits 0-3.
     * Returning one where the other is expected leaves every button reading as
     * held down, which is exactly how this went wrong the first time. */
    case SYS_READ_BUTTONS:
        frame[0] = (uint32_t)(uint8_t)~s_buttons;
        break;

    case SYS_READ_BTN_RAW: {
        uint32_t j1 = (uint32_t)(((s_buttons & 0x0Fu) << 4) | 0x0Fu);
        uint32_t j2 = (uint32_t)(((s_buttons >> 4) & 0x0Fu) | 0xF0u);
        frame[0] = (j1 << 8) | j2;
        break;
    }

    case SYS_READ_AXES:
        frame[0] = s_axes;
        break;

    /* Raw bus access. The address is a full Vectrex address; only the VIA is
     * reachable while the 6809 is halted, and the register is its low nibble. */
    case SYS_BUS_WRITE:
        uvm2_via_write(r0 & 0x0Fu, r1);
        break;

    case SYS_BUS_READ:
        frame[0] = uvm2_via_read(r0 & 0x0Fu);
        break;

    /* Digitised samples and SD browsing are not implemented on UVM2.  They are
     * no-ops in the IDE emulator too, so a game that calls them behaves the
     * same in both places rather than hanging. */
    default:
        frame[0] = 0;
        break;
    }
}
