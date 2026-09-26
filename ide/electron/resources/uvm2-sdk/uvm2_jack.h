/*
 * uvm2_jack.h — the UVMC2's audio jack: a PT8211 16-bit stereo DAC.
 *
 * REAL AUDIO, off the Vectrex entirely. The console's own sound is a PSG with
 * three square channels and one envelope; this is sixteen bits at 32 kHz out of
 * a socket on the cartridge, and nothing about it touches the bus — different
 * PIO block, different DMA channel, different pins.
 *
 * IT IS THE UVMC2's AND ONLY THE UVMC2's. On the debug cartridge GPIO43-47 are
 * not connected (hardware/debug_cart/COMPONENTS.md), so a game that has to run
 * on both asks uvm2_jack_init() and takes 0 for an answer.
 *
 * It lived in one game (uvmc2-games/quarter) before it lived here, which is why
 * it is a driver and not a sound engine: it takes mono samples at
 * UVM2_JACK_RATE and gets them out. What they are is the game's business.
 */
#ifndef UVM2_JACK_H
#define UVM2_JACK_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* THE ONE SAMPLE RATE. A game's own synth must agree with it, so it takes this
 * and does not write 32000 down a second time. */
#define UVM2_JACK_RATE 32000

int  uvm2_jack_init(void);                      /* 1 = running, 0 = no jack here */
int  uvm2_jack_space(void);                     /* samples to write now to stay ahead */
void uvm2_jack_write(const int16_t *s, int n);  /* mono, UVM2_JACK_RATE */
int  uvm2_jack_ok(void);
int  uvm2_jack_set(int on);                     /* start/stop PIO2 + DMA entirely */

/* ── WHAT IT DECIDED, so a game can say it out loud ────────────────────────
 *
 * Every one of these is a runtime negotiation — which state machine was free,
 * which DMA channel, what the clock turned out to be — and every one of them
 * can go wrong in a way that sounds exactly like the others: noise. A silent
 * driver leaves the only diagnosis available as flashing a card and listening,
 * which cannot tell "wrong pins" from "wrong clock" from "wrong format".
 *
 * uvm2_jack_pinctrl is the SM's own register AFTER the SDK has folded in the
 * GPIO base, so it says which pins are really being driven: with the base at
 * 16, OUT_BASE (bits 4:0) should read 27 for GPIO43 and SIDESET_BASE (bits
 * 14:10) should read 28 for GPIO44. */
int      uvm2_jack_sm(void);       /* the PIO2 state machine, -1 if none */
int      uvm2_jack_dma(void);      /* the DMA channel, -1 if none */
uint32_t uvm2_jack_clk(void);      /* the system clock it believed, in Hz */
uint32_t uvm2_jack_div_q8(void);   /* the PIO divider it set, Q8 */
uint32_t uvm2_jack_pinctrl(void);  /* the SM's PINCTRL as programmed */
uint32_t uvm2_jack_base(void);     /* PIO2's GPIO window base */

#ifdef __cplusplus
}
#endif

#endif /* UVM2_JACK_H */
