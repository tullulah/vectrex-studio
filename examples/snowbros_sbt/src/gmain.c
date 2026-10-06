/* gmain.c — Snow Bros SBT front-end: emulated 68000 + Pandora-to-vector renderer.
 * One machine frame per v_WaitRecal. Same skeleton as the TNZS port.
 *
 * Input map (Vectrex pad 1):
 *   stick     -> P1 joystick        button 1 -> shoot   button 2 -> jump
 *   button 3  -> coin               button 4 -> start 1P
 */
#include <stdint.h>
#include <stdio.h>
#ifdef __EMSCRIPTEN__
#include <emscripten.h>
#endif
#include <stdlib.h>
void vectrexinit(int);
void v_init(void);
void v_WaitRecal(void);
void v_setRefresh(int);
uint8_t v_readButtons(void);
void v_readJoystick1Analog(void);
extern int8_t currentJoy1X, currentJoy1Y;

void sb_hw_init(void);
void sb_hw_frame(void);
void sb_hw_avanzar(void);   /* un frame de maquina, o los que deba el reloj: ver sb_hw.c */
void sb_render(void);

/* Telemetria por RTT, solo en los cartuchos (src/sb_rtt.c lee un periferico del
 * RP2350). Sin ella los tres cortes desaparecen del todo, no quedan como llamadas
 * vacias — un instrumento apagado tiene que costar cero. */
#ifndef SB_FPSRTT
#define SB_FPSRTT 0
#endif
#if SB_FPSRTT
void sb_marca(int fase);
#else
#define sb_marca(fase) ((void)0)
#endif
extern unsigned char sb_p1, sb_system;

int main(void)
{
    vectrexinit(1);
    v_init();
    v_setRefresh(60);

    /* UVM2: turn the drawing 90 degrees. Snow Bros is a HORIZONTAL game and the
     * Vectrex screen is vertical, so drawn upright it shrinks with big bands top
     * and bottom (see the compose_levels geometry note). Rotated, laid-on-its-
     * side, the level fills the screen with only the uniform 0.857 scale. Same
     * mechanism Major Havoc uses; the rotation lives in the SDK's draw layer, so
     * host/sim/rp2350 are untouched — this block only exists in the UVM2 build. */
#ifdef UVM2_PICO_RUNTIME
    {
        extern void uvm2_config_juego(const char *, unsigned);
        extern int  uvm2_config_cargar(void);
        extern int  uvm2_config_asistente(void);
        extern void uvm2_draw_girar(int);
        /* which settings this game exposes in the calibration assistant */
        uvm2_config_juego("SNOWBT", 4u /*GIRO*/ | 2u /*MENU*/ | 1u /*HZ*/);
        uvm2_draw_girar(1);      /* rotated by default (horizontal game) */
        uvm2_config_cargar();    /* a saved CFG overrides it if the player chose otherwise */
        /* brief window to open the assistant with button 4 (calibration + rotate) */
        for (int f = 0; f < 75; f++) {
            v_WaitRecal();
            if (v_readButtons() & 0x08) { uvm2_config_asistente(); break; }
        }
    }
#endif

    sb_hw_init();

    /* SPRLOAD=<sprites_NN.bin>: render a captured Pandora RAM dump instead of
     * running the 68000 — for pixel-vs-vector orientation checks. */
    const char *sl = getenv("SPRLOAD");
    if (sl) {
        extern unsigned char sb_spriteram[0x1000];
        extern int sb_spr_live;
        FILE *f = fopen(sl, "rb");
        if (f) { fread(sb_spriteram, 1, 0x1000, f); fclose(f); }
        sb_spr_live = 1;   /* loaded a dump directly, not via the 68000 — mark live */
        for (;;) { v_WaitRecal(); sb_render(); }
    }

    for (;;) {
        v_WaitRecal();
        v_readJoystick1Analog();
        uint8_t bt = v_readButtons();

        /* active-low: start released, clear pressed bits */
        unsigned char p1 = 0x7f, sys = 0xff;
        if (currentJoy1Y >  40) p1 &= ~0x01;   /* up    */
        if (currentJoy1Y < -40) p1 &= ~0x02;   /* down  */
        if (currentJoy1X < -40) p1 &= ~0x04;   /* left  */
        if (currentJoy1X >  40) p1 &= ~0x08;   /* right */
        if (bt & 0x01) p1 &= ~0x10;            /* B1 = shoot   */
        if (bt & 0x02) p1 &= ~0x20;            /* B2 = jump    */

        /* B3 = coin 1, EDGE-TRIGGERED into a fixed 4-frame pulse, then LOCKED
         * OUT for ~half a second. The board's coin protection reads a held coin
         * line as a jammed mech and dies with COIN ERROR (measured in MAME:
         * 4-frame pulse fine, long hold fatal). A clean pad edge was enough, but
         * a REAL button bounces — each bounce is a fresh edge, and back-to-back
         * edges re-arm the pulse and keep the line effectively held. The lockout
         * swallows the bounce train (and any human multi-press) so one press is
         * always exactly one 4-frame coin, on hardware as in the sim. */
        {
            static int coin_prev, coin_pulse, coin_lock;
            int down = (bt & 0x04) != 0;
            if (coin_lock > 0) coin_lock--;
            else if (down && !coin_prev) { coin_pulse = 4; coin_lock = 30; }
            coin_prev = down;
            if (coin_pulse > 0) { coin_pulse--; sys &= ~0x04; }
        }
        if (bt & 0x08) sys &= ~0x01;           /* B4 = start 1 */
        sb_p1 = p1;
        sb_system = sys;

        /* SB_FPSRTT: los tres cortes del frame (ver src/sb_rtt.c). Apagado, el
         * macro los borra y esto vuelve a ser dos llamadas. */
        sb_marca(0);
        sb_hw_avanzar();
        sb_marca(1);
        sb_render();
        sb_marca(2);

#ifdef __EMSCRIPTEN__
        /* first sighting of an unknown frame -> save the sprite RAM STRAIGHT
         * INTO THE PROJECT via the sim SDK's v_simSaveData (lands in
         * dumps/sim_<session>/sprites_NNNNN.bin — no console round-trip, no
         * replaying runs to re-capture). tools/autotrace.py --catalog picks
         * them up. Cap = 2000 files/session = 8MB, roomy but bounded. */
        {
            extern int sb_capture_request;
            extern int sb_frame_counter;
            extern unsigned char sb_spriteram[0x1000];
            void v_simSaveData(const char *, const void *, unsigned);
            static int emitted;
            if (sb_capture_request && emitted < 2000) {
                sb_capture_request = 0;
                emitted++;
                char name[32];
                snprintf(name, sizeof name, "sprites_%05d.bin", sb_frame_counter);
                v_simSaveData(name, sb_spriteram, 0x1000);
            }
        }
#endif
    }
    return 0;
}
