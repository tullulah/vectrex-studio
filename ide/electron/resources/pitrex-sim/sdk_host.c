/*
 * PiTrex SDK host implementation for the IDE simulator.
 *
 * Implements the contract in include/vectrex/vectrexInterface.h and the FatFs
 * surface in include/baremetal/ff.h ONCE, for any pitrex program. Each call
 * bridges to a JS hook on `Module.pitrex` that the harness / IDE panel provides
 * (draw to a canvas, read host input, present a frame). There is deliberately
 * ZERO game-specific code here: the simulator is agnostic to what it runs.
 *
 * Frame model: the game loops calling v_WaitRecal() once per frame. We present
 * the accumulated vectors and emscripten_sleep(0) — Asyncify suspends the WASM
 * and resumes it on the host's next animation frame. (Same model the existing
 * PitrexCore asm interpreter uses: run until v_WaitRecal.)
 */
#include <stdint.h>
#include <stdio.h>
#include <emscripten.h>

#include "vectrex/vectrexInterface.h"
#include "baremetal/ff.h"

/* ---- Contract globals ---- */
uint8_t currentButtonState = 0;
int8_t  currentJoy1X = 0;
int8_t  currentJoy1Y = 0;

/* ---- JS bridges: the host supplies Module.pitrex.* (all optional) ---- */
EM_JS(void, js_draw_line, (int x0, int y0, int x1, int y1, int b), {
    if (Module.pitrex && Module.pitrex.drawLine) Module.pitrex.drawLine(x0, y0, x1, y1, b);
});
EM_JS(void, js_present, (void), {
    if (Module.pitrex && Module.pitrex.present) Module.pitrex.present();
});
EM_JS(int, js_read_buttons, (void), {
    return (Module.pitrex && Module.pitrex.readButtons) ? (Module.pitrex.readButtons() | 0) : 0;
});
EM_JS(int, js_joy_x, (void), {
    return (Module.pitrex && Module.pitrex.joyX) ? (Module.pitrex.joyX() | 0) : 0;
});
EM_JS(int, js_joy_y, (void), {
    return (Module.pitrex && Module.pitrex.joyY) ? (Module.pitrex.joyY() | 0) : 0;
});
EM_JS(int, js_millis, (void), {
    return (Module.pitrex && Module.pitrex.millis) ? (Module.pitrex.millis() | 0)
                                                   : (Date.now() | 0);
});
EM_JS(void, js_sound_ay, (int reg, int val), {
    if (Module.pitrex && Module.pitrex.soundAY) Module.pitrex.soundAY(reg, val);
});

/* ---- vectrexInterface ---- */
static int s_refresh_hz = 50;   /* Vectrex frame rate; the game may change it */

void vectrexinit(int mode) { (void)mode; }
void v_init(void) {}
void v_setRefresh(int hz) { if (hz > 0) s_refresh_hz = hz; }

/* Pace the game loop to the declared refresh: return how many ms v_WaitRecal
 * should sleep so frames advance at ~hz, instead of running flat-out. Keeps a
 * running target on the JS side and re-syncs if it falls behind. */
EM_JS(int, js_frame_delay, (int hz), {
    var now = (typeof performance !== 'undefined') ? performance.now() : Date.now();
    var period = 1000 / (hz > 0 ? hz : 50);
    if (Module._simNextFrame === undefined || Module._simNextFrame < now - 4 * period)
        Module._simNextFrame = now;
    Module._simNextFrame += period;
    var d = Module._simNextFrame - now;
    return (d < 0) ? 0 : (d | 0);
});

void v_directDraw32(int32_t x0, int32_t y0, int32_t x1, int32_t y1, uint8_t b) {
    js_draw_line((int)x0, (int)y0, (int)x1, (int)y1, (int)b);
}

void v_WaitRecal(void) {
    js_present();
    emscripten_sleep(js_frame_delay(s_refresh_hz)); /* pace to the game's refresh */
}

uint8_t v_readButtons(void) {
    currentButtonState = (uint8_t)js_read_buttons();
    return currentButtonState;
}
void v_readJoystick1Analog(void) {
    currentJoy1X = (int8_t)js_joy_x();
    currentJoy1Y = (int8_t)js_joy_y();
}
uint32_t v_millis(void) { return (uint32_t)js_millis(); }

void v_setSoundAY(uint8_t reg, uint8_t val) { js_sound_ay((int)reg, (int)val); }
void v_writePSG(uint8_t reg, uint8_t val)   { js_sound_ay((int)reg, (int)val); }

/* Digitised-sample playback → the JS side (PitrexSimView) mixes via Web Audio. */
EM_JS(void, js_play_sample, (int idx, int voice, int loop), {
    if (Module.pitrex && Module.pitrex.playSample) Module.pitrex.playSample(idx, voice, loop);
});
EM_JS(void, js_stop_sample, (int voice), {
    if (Module.pitrex && Module.pitrex.stopSample) Module.pitrex.stopSample(voice);
});
EM_JS(int, js_sample_playing, (int voice), {
    return (Module.pitrex && Module.pitrex.samplePlaying) ? (Module.pitrex.samplePlaying(voice) | 0) : 0;
});
void v_playSample(int idx, int voice, int loop) { js_play_sample(idx, voice, loop); }
void v_stopSample(int voice)                    { js_stop_sample(voice); }
int  v_samplePlaying(int voice)                 { return js_sample_playing(voice); }

/* ---- FatFs over stdio (emscripten MEMFS) ---- */
FRESULT f_open(FIL* fp, const char* path, BYTE mode) {
    const char* m = (mode & FA_WRITE) ? "wb" : "rb";
    FILE* h = fopen(path, m);
    if (!h) return FR_NO_FILE;
    fp->fp = h;
    return FR_OK;
}
FRESULT f_close(FIL* fp) {
    if (fp && fp->fp) { fclose((FILE*)fp->fp); fp->fp = 0; }
    return FR_OK;
}
FRESULT f_read(FIL* fp, void* buff, UINT btr, UINT* br) {
    size_t n = fread(buff, 1, btr, (FILE*)fp->fp);
    if (br) *br = (UINT)n;
    return FR_OK;
}
FRESULT f_write(FIL* fp, const void* buff, UINT btw, UINT* bw) {
    size_t n = fwrite(buff, 1, btw, (FILE*)fp->fp);
    if (bw) *bw = (UINT)n;
    return FR_OK;
}
FRESULT f_lseek(FIL* fp, FSIZE_t ofs) {
    return (fseek((FILE*)fp->fp, (long)ofs, SEEK_SET) == 0) ? FR_OK : FR_DISK_ERR;
}
FSIZE_t f_tell(FIL* fp) { return (FSIZE_t)ftell((FILE*)fp->fp); }
FSIZE_t f_size(FIL* fp) {
    FILE* h = (FILE*)fp->fp;
    long cur = ftell(h);
    fseek(h, 0, SEEK_END);
    long end = ftell(h);
    fseek(h, cur, SEEK_SET);
    return (FSIZE_t)end;
}
int f_eof(FIL* fp) { return feof((FILE*)fp->fp) ? 1 : 0; }
