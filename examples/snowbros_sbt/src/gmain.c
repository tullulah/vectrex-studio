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
void sb_render(void);
extern unsigned char sb_p1, sb_system;

int main(void)
{
    vectrexinit(1);
    v_init();
    v_setRefresh(60);
    sb_hw_init();

    /* SPRLOAD=<sprites_NN.bin>: render a captured Pandora RAM dump instead of
     * running the 68000 — for pixel-vs-vector orientation checks. */
    const char *sl = getenv("SPRLOAD");
    if (sl) {
        extern unsigned char sb_spriteram[0x1000];
        FILE *f = fopen(sl, "rb");
        if (f) { fread(sb_spriteram, 1, 0x1000, f); fclose(f); }
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
        if (bt & 0x04) sys &= ~0x04;           /* B3 = coin 1  */
        if (bt & 0x08) sys &= ~0x01;           /* B4 = start 1 */
        sb_p1 = p1;
        sb_system = sys;

        sb_hw_frame();
        sb_render();

#ifdef __EMSCRIPTEN__
        /* first sighting of an unknown frame -> spit the sprite RAM to the
         * console as hex; tools/import_sbfarm.py turns the saved IDE log into
         * dumps/ for the catalogue. Capped per session to keep the log sane. */
        {
            extern int sb_capture_request;
            extern unsigned char sb_spriteram[0x1000];
            static int emitted;
            if (sb_capture_request && emitted < 300) {
                sb_capture_request = 0;
                emitted++;
                static char hex[0x2000 + 1];
                for (int i = 0; i < 0x1000; i++) {
                    hex[i * 2]     = "0123456789abcdef"[sb_spriteram[i] >> 4];
                    hex[i * 2 + 1] = "0123456789abcdef"[sb_spriteram[i] & 15];
                }
                hex[0x2000] = 0;
                EM_ASM({ console.log('SBFARM ' + UTF8ToString($0)); }, hex);
            }
        }
#endif
    }
    return 0;
}
