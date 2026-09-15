/* sdk_rp2350.c — RP2350 hardware backend for the libvpy SDK contract.
 *
 * libvpy (vpy.c) is written against a tiny "PiTrex SDK" contract: it draws every
 * segment through v_directDraw32, writes sound through v_writePSG, reads input
 * through v_readButtons / v_readJoystick1Analog, and paces frames with
 * v_WaitRecal. The WASM sim satisfies that contract in pitrex-sim/sdk_host.c
 * (against the JS emulator); the PiTrex hardware satisfies it with the real
 * PiTrex SDK. This file is the third backend: it maps the SAME contract onto the
 * RP2350 cartridge BIOS, which owns all Vectrex hardware and exposes services as
 * ARM `svc #N` traps (see docs/RP2350_BIOS.md, BIOS_VERSION 0x0006).
 *
 * So a C game built with main.c + vpy.c + this file + rp2350_start.s links to a
 * RAM-loaded RP2350 game .bin (SYS_LAUNCH loads it at 0x20040000 and jumps to
 * game_main). No game-code or libvpy change — same contract, new backend.
 */
#include <stdint.h>

/* ── BIOS syscall traps (Thumb `svc #imm`; args r0-r3, return in r0, AAPCS).
 * The `svc` immediate must be a compile-time literal, so one wrapper per number.
 * Exception entry/return stacks r0-r3, and the SVCall handler writes only the
 * return value back into the stacked r0 — so r1-r3 are preserved across the
 * trap and r0 is in+out. */
static inline void sys_reset0ref(void)       { __asm__ volatile("svc #0"  ::: "r0","r1","r2","r3","memory"); }
static inline void sys_wait_recal(void)      { __asm__ volatile("svc #1"  ::: "r0","r1","r2","r3","memory"); }
static inline void sys_set_intensity(int b)  { register int r0 __asm__("r0")=b; __asm__ volatile("svc #2" : "+r"(r0) :: "memory"); }
static inline void sys_move(int x,int y)     { register int r0 __asm__("r0")=x; register int r1 __asm__("r1")=y; __asm__ volatile("svc #3" : "+r"(r0) : "r"(r1) : "memory"); }
static inline void sys_draw_delta(int dx,int dy){ register int r0 __asm__("r0")=dx; register int r1 __asm__("r1")=dy; __asm__ volatile("svc #4" : "+r"(r0) : "r"(r1) : "memory"); }
static inline void sys_psg_write(int reg,int val){ register int r0 __asm__("r0")=reg; register int r1 __asm__("r1")=val; __asm__ volatile("svc #5" : "+r"(r0) : "r"(r1) : "memory"); }
static inline int  sys_read_buttons(void)    { register int r0 __asm__("r0"); __asm__ volatile("svc #7"  : "=r"(r0) :: "memory"); return r0; }
static inline int  sys_read_axes(void)       { register int r0 __asm__("r0"); __asm__ volatile("svc #13" : "=r"(r0) :: "memory"); return r0; }
static inline void sys_play_music(const void *p){ register const void *r0 __asm__("r0")=p; __asm__ volatile("svc #21" : "+r"(r0) :: "memory"); }
static inline void sys_stop_music(void)      { __asm__ volatile("svc #22" ::: "r0","r1","r2","r3","memory"); }
/* SYS_RASTER_TEXT = 26. It used to be 23 — which the BIOS defines as SYS_PLAY_SFX
 * and dispatches to music::play_sfx(r0). Single-core, r2 (a string pointer) landed
 * in the SFX player as a track pointer: on the UVM2 that walked off into 0xffffffa4
 * and locked the core up inside the SVC handler. Dual-core cart games never saw it
 * because BEAM_RASTER records into the shared buffer instead of trapping, which is
 * why it stayed hidden. 26 is the first free number after SET_TEXT_METRICS (25). */
static inline void sys_raster_text(int x,int y,const unsigned char*s,int n){ register int r0 __asm__("r0")=x; register int r1 __asm__("r1")=y; register const unsigned char* r2 __asm__("r2")=s; register int r3 __asm__("r3")=n; __asm__ volatile("svc #26" :: "r"(r0),"r"(r1),"r"(r2),"r"(r3) : "memory"); }
/* SYS_DRAW_GAPPED = 27, the first free number after RASTER_TEXT (26). r0=dx, r1=dy,
 * r2 = (start,end) pairs as 0..255 fractions of the run, r3 = how many pairs. */
static inline void sys_draw_gapped(int dx,int dy,const unsigned char*g,int n){ register int r0 __asm__("r0")=dx; register int r1 __asm__("r1")=dy; register const unsigned char* r2 __asm__("r2")=g; register int r3 __asm__("r3")=n; __asm__ volatile("svc #27" :: "r"(r0),"r"(r1),"r"(r2),"r"(r3) : "memory"); }

/* ── Input snapshot owned by the SDK layer (libvpy reads these as externs). ── */
uint8_t currentButtonState = 0;
int8_t  currentJoy1X = 0;
int8_t  currentJoy1Y = 0;

/* libvpy scales VPy logical units (±127 screen) by VPY_SCALE for PiTrex
 * deflection units; the BIOS draw model wants raw i8 (±127) screen coords, so we
 * divide the scaled coords back down. The multiply was exact, so this is lossless. */
#define VPY_SCALE 127
/* caller units -> device units, rounded to nearest and symmetric about zero */
#define VS_RND(v) ((int)(((v) < 0 ? (v) - VPY_SCALE/2 : (v) + VPY_SCALE/2) / VPY_SCALE))

/* ── Lifecycle (BIOS already did clocks/pins/VIA init; nothing to do here). ── */
void vectrexinit(int mode) { (void)mode; }
void v_init(void)          {}
void v_setRefresh(int hz)  { (void)hz; }   /* BIOS paces ~50 Hz in SYS_WAIT_RECAL */

/* ── Beam-position tracking. SYS_WAIT_RECAL zero-refs the beam each frame, so we
 * reset our tracked origin to centre there and issue each segment's positioning
 * as a delta from the previous endpoint (segment chaining — no redundant
 * re-zero between connected strokes). ── */
static int s_beam_x = 0, s_beam_y = 0;

/* ═══════════════════════════════════════════════════════════════════════════
 * DUAL-CORE MODE (opt-in via -DVPY_DUAL_CORE; the game's VPy2 header also sets
 * the dual-core flag so the BIOS launches it on core 1). Compute-heavy games
 * (AAE's 6502 interpreter) overlap their compute with the beam draw: the game
 * runs on CORE 1 and RECORDS its draw commands into a shared RAM ring buffer
 * with NO `svc` — so core 1 makes ZERO flash fetches during a frame. CORE 0
 * materialises the sealed buffer (flash-timed, E-synced bus writes) in parallel.
 * The svc-free requirement is load-bearing: an `svc` fetches the exception
 * vector+handler from flash, which would stall core 0's cycle-timed beam ramps
 * (stretched vectors / broken E-sync). Fixed shared addresses — MUST match the
 * firmware (hardware/debug_cart/firmware/src/dc.rs). VPy games don't define
 * VPY_DUAL_CORE and keep the unchanged single-core svc path below. ══════════ */
/* Most gaps one run may carry. The dual-core queue packs them 4 per command and the
 * UVM2 primitive caps at 16; 8 is what both transports accept, and a run needing more
 * than eight dark stretches is beyond what one ramp should be asked to draw. */
#define DC_GAPS_MAX 8
#ifdef VPY_DUAL_CORE
struct dc_cmd  { unsigned char op; signed char a; signed char b; unsigned char _pad; };
struct dc_ctrl {
    volatile unsigned char  state[2];  /* 0=FREE (game may write), 1=SEALED (core 0 draws) */
    unsigned char           _p0[2];
    volatile unsigned short count[2];  /* # commands in each buffer */
    volatile unsigned int   axes;      /* SYS_READ_AXES snapshot, published by core 0 */
    volatile unsigned int   buttons;   /* SYS_READ_BUTTONS snapshot (P1 bits 0-3) */
};
/* MUST match the firmware dc.rs. 4096 cmds (was 1024): DK's title/intro emit
 * >1024 beam ops; the overflow was dropped, and vk_render draws text/logo LAST,
 * so the title/letters vanished. Buffers moved down into the game-stack gap. */
#define DC_CTRL   ((struct dc_ctrl *)0x20076F00u)
#define DC_BUF0   ((struct dc_cmd  *)0x20077000u)
#define DC_BUF1   ((struct dc_cmd  *)0x2007B000u)
#define DC_CMDS_MAX 4096
#define DC_FREE 0
#define DC_SEALED 1
#define DC_OP_ZERO 0
#define DC_OP_INTENSITY 1
#define DC_OP_MOVE 2
#define DC_OP_DRAW 3
#define DC_OP_RASTER 4   /* header cmd: a=x, b=y, _pad=len; then ceil(len/4) cmds
                          * of raw string bytes. core 0 draws it with the BIOS
                          * shift-register raster font (one sweep per pixel row). */
#define DC_OP_PSG 6      /* a=register, b=value. THE DUAL-CORE GAME HAS NO OTHER WAY TO
                          * MAKE A SOUND. v_writePSG used to svc unconditionally, and the
                          * firmware's own note says it plainly: "the dual-core game never
                          * svc's" (dc.rs). So the write went nowhere and the cartridge was
                          * silent — not a broken note, no path at all. It cannot be done
                          * directly either: core 0 owns the bus while it draws, and two
                          * writers on the VIA with no arbitration is the fault that shipped
                          * once already. It travels in the queue like everything else. */
/* LAS DOS OPS EN CUARTOS DE UNIDAD, para que la BIOS reciba EXACTAMENTE lo que en la .um2
 * recibe uvm2_draw.c: v_directDraw32 en la UVM2 es intensity + move_abs_q4 + delta_q4, sin
 * redondear a i8 ni fusionar tramos (esa es la rama UVM2_SUBUNIDAD de abajo). Con el anillo
 * en i8 la lista de la BIOS salia distinta de la de la .um2 (632 rampas contra 617, y mas
 * pinzas de cero por la cadencia VPY_MAX_CONSECUTIVE_DRAWS) — y el objetivo es que salga
 * IGUAL, que se mide en el emulador (VIADUMP de las dos). 12 bits con signo por eje: a =
 * x[7:0], b = y[7:0], _pad = x[11:8] | y[11:8] << 4. VS_Q4(±16129) = ±2032, cabe. */
#define DC_OP_MOVE_ABS_Q4 7
#define DC_OP_DELTA_Q4    8
#define DC_OP_DRAW_GAPPED 5 /* ONE STRAIGHT LINE WITH GAPS, IN A SINGLE RAMP. Header:
                          * a=dx, b=dy, _pad = gap count; then ceil(n*2/4) commands holding
                          * the (start,end) pairs as 0..255 fractions of the run.
                          *
                          * Why it exists: splitting a line into pieces costs one operation
                          * per piece — two DACs, the T1 count, open and close the ramp,
                          * about 40 us — and the beam's velocity is set by the DACs, so as
                          * long as they are left alone the beam keeps travelling THE SAME
                          * LINE. All that changes along the way is BLANK. Measured on
                          * Donkey Kong's 25m: 26 collinear runs merging 55 operations,
                          * ~2.2 ms out of an 18.5 ms frame.
                          *
                          * Same shape as RASTER on purpose: header plus data in the
                          * following commands, a pattern already proven in this queue. */
static int s_dc_w = 0;   /* current write buffer (0/1) */
static int s_dc_n = 0;   /* commands recorded into it so far */
static inline void dc_push(unsigned char op, signed char a, signed char b) {
    if (s_dc_n < DC_CMDS_MAX) {
        struct dc_cmd *buf = s_dc_w ? DC_BUF1 : DC_BUF0;
        buf[s_dc_n].op = op; buf[s_dc_n].a = a; buf[s_dc_n].b = b;
        s_dc_n++;
    }
}
/* Record a raster-text run: a header cmd (x,y,len) followed by the string bytes
 * packed 4 per cmd. core0_materialize replays it via the shift-register font. */
/* The gapped line, pushed to the command queue. `gaps` are (start,end) pairs as
 * 0..255 fractions of the run; n is capped at DC_GAPS_MAX (hoisted above both transports,
 * since flush_frame builds the array before it knows which one it is talking to). */
static inline void dc_push_q4(unsigned char op, int x, int y) {
    if (s_dc_n < DC_CMDS_MAX) {
        struct dc_cmd *buf = s_dc_w ? DC_BUF1 : DC_BUF0;
        buf[s_dc_n].op = op;
        buf[s_dc_n].a = (signed char)(x & 0xFF);
        buf[s_dc_n].b = (signed char)(y & 0xFF);
        buf[s_dc_n]._pad = (unsigned char)(((x >> 8) & 0x0F) | (((y >> 8) & 0x0F) << 4));
        s_dc_n++;
    }
}
static void dc_push_gapped(signed char dx, signed char dy, const unsigned char *gaps, int n) {
    if (n < 0) n = 0;
    if (n > DC_GAPS_MAX) n = DC_GAPS_MAX;
    int ndata = (n * 2 + 3) / 4;
    if (s_dc_n + 1 + ndata > DC_CMDS_MAX) return;
    struct dc_cmd *buf = s_dc_w ? DC_BUF1 : DC_BUF0;
    buf[s_dc_n].op = DC_OP_DRAW_GAPPED; buf[s_dc_n].a = dx; buf[s_dc_n].b = dy;
    buf[s_dc_n]._pad = (unsigned char)n; s_dc_n++;
    for (int i = 0; i < n * 2; i += 4) {
        unsigned char *q = (unsigned char *)&buf[s_dc_n];
        for (int k = 0; k < 4; k++) q[k] = (i + k < n * 2) ? gaps[i + k] : 0;
        s_dc_n++;
    }
}

static void dc_push_raster(signed char x, signed char y, const unsigned char *s, int len) {
    if (len < 0) len = 0;
    if (len > 255) len = 255;
    int ndata = (len + 3) / 4;
    if (s_dc_n + 1 + ndata > DC_CMDS_MAX) return;   /* no room this frame */
    struct dc_cmd *buf = s_dc_w ? DC_BUF1 : DC_BUF0;
    buf[s_dc_n].op = DC_OP_RASTER; buf[s_dc_n].a = x; buf[s_dc_n].b = y;
    buf[s_dc_n]._pad = (unsigned char)len; s_dc_n++;
    for (int i = 0; i < len; i += 4) {
        unsigned char *p = (unsigned char *)&buf[s_dc_n];
        p[0] = s[i];
        p[1] = (i + 1 < len) ? s[i + 1] : 0;
        p[2] = (i + 2 < len) ? s[i + 2] : 0;
        p[3] = (i + 3 < len) ? s[i + 3] : 0;
        s_dc_n++;
    }
}
#define BEAM_ZERO()       dc_push(DC_OP_ZERO, 0, 0)
#define BEAM_INTENSITY(b) dc_push(DC_OP_INTENSITY, (signed char)(b), 0)
#define BEAM_MOVE(x,y)    dc_push(DC_OP_MOVE, (signed char)(x), (signed char)(y))
#define BEAM_DRAW(x,y)    dc_push(DC_OP_DRAW, (signed char)(x), (signed char)(y))
#define BEAM_DELTA_ES_I8  1   /* el comando lleva el delta en un byte con signo */
#define BEAM_RASTER(x,y,s,n) dc_push_raster((signed char)(x),(signed char)(y),(s),(n))
#define BEAM_DRAW_GAPPED(x,y,h,n) dc_push_gapped((signed char)(x),(signed char)(y),(h),(n))
/* Overridable so the gapped ramp can be MEASURED: -DHAS_GAPPED_RAMP=0 falls back to one
 * stroke per piece, everything else identical, which is the only way to get a two-build
 * comparison with a single variable in it. */
#ifndef HAS_GAPPED_RAMP
#define HAS_GAPPED_RAMP 1
#endif
#else
#define BEAM_ZERO()       sys_reset0ref()
#define BEAM_INTENSITY(b) sys_set_intensity(b)
#define BEAM_MOVE(x,y)    sys_move((x),(y))
#define BEAM_DRAW(x,y)    sys_draw_delta((x),(y))
/* EN EL UVM2 EL DELTA NO ES UN BYTE. `uvm2_draw_delta` recibe enteros y trocea el sola
 * por el limite de VERDAD (127*255/DRAW_SCALE, ~202 unidades). Partir aqui a 127 es
 * trocear para un formato de comando que no es el nuestro — y era el 100% del troceo:
 * medido en dkong, un trazo de 179 unidades salia en dos de 89. */
#define BEAM_DELTA_ES_I8  0
#define BEAM_RASTER(x,y,s,n) sys_raster_text((x),(y),(s),(n)) /* SYS #26 */
/* THE SVC PATH HAS IT ONLY ON THE UVM2, and the asymmetry is not an oversight.
 *
 * The gapped ramp needs someone on the other side of the call to toggle BLANK inside the
 * ramp. On the UVM2 that is uvm2_draw_delta_patterned(), in the same image. On the games
 * cart the other side is the firmware's SVC handler, which has no such syscall — cart
 * games take the dual-core path, where the command travels through the queue as
 * DC_OP_DRAW_GAPPED instead. Turning this on for a single-core CART build would trap into
 * a handler that does not know the number, so it is gated on the UVM2 runtime, not on the
 * board being an RP2350. */
#ifdef UVM2_PICO_RUNTIME
#define BEAM_DRAW_GAPPED(x,y,h,n) sys_draw_gapped((x),(y),(h),(n))
#ifndef HAS_GAPPED_RAMP
#define HAS_GAPPED_RAMP 1
#endif
#else
#define HAS_GAPPED_RAMP 0
#endif
#endif

/* Draw a raster-font string at device coords (x,y) (i8, ±127). Dual-core records
 * it into the shared list (core 0 replays via the BIOS shift-register font);
 * single-core traps to the BIOS raster primitive. `s` = bytes 0x20..0x6F. */
void v_rasterText(int x, int y, const unsigned char *s, int n) { BEAM_RASTER(x, y, s, n); }

/* Draw ONE horizontal row of RAW bytes (each byte = 8 pixels, bit7 = leftmost) at
 * device coords (x,y) via the shift-register raster sweep — the general primitive
 * behind the ZX-Spectrum screen render (one sweep per non-blank pixel row). Same
 * DC encoding as v_rasterText; core 0 now materialises OP_RASTER as raw rows. */
void v_rasterRow(int x, int y, const unsigned char *s, int n) { BEAM_RASTER(x, y, s, n); }

/* Set the beam Z-axis intensity for the following draws (records OP_INTENSITY in
 * dual-core; the core-0 materialiser calls set_brightness before replaying). The
 * raster row sweep relies on this being set BEFORE the rows (not inline). */
void v_setIntensity(int b) { BEAM_INTENSITY((signed char)b); }

/* Bound integrator drift: chaining segments with only relative moves (no re-zero)
 * lets the integrators drift, so after N consecutive segments we force a fresh
 * zero-ref. This is the runtime analogue of PiTrex's MAX_CONSECUTIVE_DRAWS (=65)
 * and of the VPy compiler's fusion cap: 32 was HW-validated to draw cleanly
 * without a re-zero, above which shapes visibly wobble. Per-game overridable
 * (-DVPY_MAX_CONSECUTIVE_DRAWS=N): games whose runtime MERGES segments emit fewer
 * but LONGER vectors that drift more per vector, so they want a lower cap (more
 * frequent re-zeros) to keep glyphs/shapes landing where they belong. */
/* KNOB EN TIEMPO DE EJECUCION en el UVM2. Esta cadencia es lo unico que ACOTA la deriva
 * del integrador: cada N dibujos con un salto de por medio, el haz vuelve al origen y el
 * error acumulado se borra. Bajarla endereza el dibujo y cuesta operaciones; subirla lo
 * contrario. En esa placa no se puede leer ni escribir por SWD —parar el nucleo es una
 * violacion de fase— asi que probar un valor costaba un flasheo; ahora se barre desde el
 * menu de servicio viendo el dibujo. */
/* ── UNA PERILLA QUE NO LLEGABA. Estaba asi:
 *
 *     volatile int uvm2_max_draws = 6;
 *     #define VPY_MAX_CONSECUTIVE_DRAWS uvm2_max_draws
 *
 * sin `#undef`, o sea que el `-DVPY_MAX_CONSECUTIVE_DRAWS=N` del Makefile del juego se
 * REDEFINIA aqui y el numero que corria en consola era el 6 de esta linea, pasara lo que
 * pasara en el build. Medido en asterock el 2026-09-03: 76 re-ceros por frame, que es
 * 498 vectores / 6 — el juego pedia 32 y corria 6. El sintoma en pantalla son trazos
 * DESPLAZADOS y solapados, porque cada re-cero vuelve al centro y la reaproximacion
 * redondea ([[la-deriva-esta-en-los-saltos]]: -47/-89 unidades por salto).
 *
 * Ahora el valor del juego SIEMBRA la variable y el `#undef` es explicito, asi que
 * seguir barriendola desde el menu de servicio sigue funcionando pero el punto de
 * partida es el que compilo el juego.
 *
 * EL DEFECTO SALE DE LA CAPTURA, no de una prueba a ojo: el VecFever dibuja ESTE juego
 * con 12-16 pulsos de cero por frame (vecfever-asterock-bus.csv, histograma sobre 816
 * frames), y 498 vectores / 32 = 15,6. El 32 que ya estaba documentado como validado en
 * hardware es el que reproduce su cadencia. ── */
/* El orden importa: hay que preguntar si el JUEGO lo definio ANTES de poner cualquier
 * defecto, o los dos casos se vuelven indistinguibles. Y los defectos se dejan donde
 * estaban a proposito — 6 en el UVM2 y 4 en el cartucho propio son lo que estaba
 * corriendo, y subirlos les cambiaria el dibujo a dkong y a los demas puertos sin una
 * sola medida suya ([[tune-on-one-game-is-overfitting]]). Lo que se arregla aqui es que
 * el juego PUEDA decidir, no lo que decide por el. */
#ifdef UVM2_PICO_RUNTIME
#  ifdef VPY_MAX_CONSECUTIVE_DRAWS
/* KNOB EN TIEMPO DE EJECUCION, sembrado con el valor QUE COMPILO EL JUEGO. */
volatile int uvm2_max_draws = VPY_MAX_CONSECUTIVE_DRAWS;
#    undef VPY_MAX_CONSECUTIVE_DRAWS
#  else
volatile int uvm2_max_draws = 6;      /* lo que corria de facto en esta placa */
#  endif
#  define VPY_MAX_CONSECUTIVE_DRAWS uvm2_max_draws
#endif
#ifdef UVM2_CUENTA_ENTRADA
unsigned uvm2_cuenta_entrada;   /* DIAGNOSTICO, ver uvm2_frame_end */
#endif
#ifndef VPY_MAX_CONSECUTIVE_DRAWS
#define VPY_MAX_CONSECUTIVE_DRAWS 4   /* el cartucho propio, sin tocar */
#endif

/* ── 1 -> 4 EL 2026-08-11, y la clave es que el 1 estaba compensando OTRA COSA ──
 * El 1 se puso el 5-ago porque con 32 todo se tambaleaba. Y era cierto, pero la causa
 * no era el presupuesto: era que **subirlo encendia automaticamente el reordenado por
 * vecino mas cercano** (ver la nota de VPY_NO_REORDER, ahora opt-in). El reordenado
 * ordena por proximidad sobre objetos QUE SE MUEVEN, asi que el orden de dibujo cambia
 * entre frames y con el que valor tenia antes cada sample-and-hold — cuyo residuo depende
 * del valor anterior. Eso baila. Un error determinista no puede temblar.
 *
 * Desacoplados los dos, el presupuesto se puede subir y NO tiembla.
 *
 * MEDIDO EN HARDWARE con Donkey Kong, con la escena FIJADA (esperando a que el contador
 * de segmentos se estabilizara) y los dos binarios en los mismos tres cuadros:
 *
 *     pantalla    presup. 1   presup. 4    mejora
 *     475 seg       17543       15789      -10,0%   (18 -> 20 fps)
 *     424 seg       17688       13606      -23,1%
 *     373 seg       16085       14894       -7,4%
 *
 * NO ES UN NUMERO, ES UN RANGO: el ahorro es proporcional a cuantos re-ceros evita cada
 * pantalla, y eso depende de cuantas cadenas cortas tenga el dibujo.
 *
 * POR QUE 4 Y NO MAS: con 8 no mejora, y con 16 **el HUD tiembla cuando hay muchos
 * vectores** — eso ya no es el reordenado, es deriva sistematica que crece con la LONGITUD
 * de la cadena. 4 esta por debajo de ese limite con margen.
 *
 * OJO: esto se midio en UN JUEGO. El mecanismo generaliza (menos re-ceros = movimientos
 * mas cortos, porque dejan de salir del centro), pero el limite de deriva depende del
 * contenido. Un juego que se vea temblar o desplazado con esto quiere un valor menor, y
 * se le pone en su Makefile: -DVPY_MAX_CONSECUTIVE_DRAWS=N. */

/* DEFAULT 1 SINCE 2026-08-05 — measured, replacing a 32 that was making every game
 * wobble. The position error is FIXED PER MOVEMENT (the deflection lag at the end of
 * each blanked move), not proportional to distance, so it accumulates by COUNT: two or
 * three moves are already visible. That is why nothing between 1 and 32 works —
 * 2/4/8 were each tried on hardware and each still wobbled — and why the two
 * distance-based policies (re-zero before a long move; re-zero on a path budget) both
 * failed outright: a line of text only ever makes SHORT hops, so neither ever fired,
 * and the text piled up anyway.
 *
 * Cost, measured on Asteroids, same geometry either side:
 *     gameplay     ~205 vectors   44.2 -> 44.2 fps    NOTHING (the frame is paced,
 *                                                      not beam-bound, at this load)
 *     high scores  ~509 vectors   26.9 -> 23.1 fps    14%, and ~5-9% once the reorder
 *                                                      below is dropped
 * So it is free where you actually play and only bites on text-heavy screens. The
 * firmware's own `print_text` has always re-zeroed per glyph and has always rendered
 * cleanly; this is the SDK doing the same thing.
 *
 * WITH A PER-STROKE RE-ZERO THE NEAREST-NEIGHBOUR REORDER CANNOT HELP: every move now
 * starts from the origin, so there is no inter-stroke travel left to shorten, and its
 * O(n^2) search (145 strokes ~ 21k distance tests per frame, on the game's core) is
 * pure waste.
 *
 * ── EL REORDENADO ES OPT-IN (2026-08-11), Y ANTES SE ENCENDIA SOLO ─────────────
 * Aqui habia esto:
 *
 *     #if VPY_MAX_CONSECUTIVE_DRAWS <= 1 && !defined(VPY_NO_REORDER)
 *     #define VPY_NO_REORDER 1
 *     #endif
 *
 * o sea que SUBIR EL PRESUPUESTO ENCENDIA EL REORDENADO automaticamente. La intencion
 * era buena —"disabled automatically rather than left as a flag someone has to
 * remember"— pero encadenaba las dos cosas en el sentido peligroso: quien sube el
 * presupuesto para ahorrar zeros se lleva de propina un reordenado que no pidio.
 *
 * MEDIDO EN HARDWARE con Donkey Kong, pareado y con el binario de control verificado
 * byte a byte: con el reordenado el dibujo TIEMBLA mucho; sin el, nada. Y en velocidad
 * los dos son indistinguibles, asi que no se pierde nada.
 *
 * MECANISMO, y por eso no es un caso particular de un juego: un error determinista NO
 * PUEDE TEMBLAR — con escena estatica sale igual en cada frame, quedaria torcido, no
 * bailando. Para temblar, algo tiene que CAMBIAR entre frames. Y el reordenado ordena por
 * proximidad sobre objetos QUE SE MUEVEN, asi que el orden de dibujo varia frame a frame,
 * y con el que valor tenia antes cada sample-and-hold — cuyo residuo depende del valor
 * anterior. Eso vale para cualquier juego con movimiento.
 *
 * Por eso no lo arreglaba ningun knob de temporizacion (Y_MUX_ECYC, T1_EXTRA_Q8): reducen
 * el TAMANO del residuo, pero lo que baila es que el residuo cambie de SITIO.
 *
 * LA SALIDA BUENA, sin hacer: un reordenado ESTABLE, que fije el orden mientras la
 * topologia de la escena no cambie en vez de recalcularlo con las posiciones nuevas cada
 * frame. Daria los ~53 movimientos por frame que ahorra SIN el baile.
 *
 * Quien lo quiera, que lo pida: -DVPY_REORDER=1 */
#if !defined(VPY_REORDER) && !defined(VPY_NO_REORDER)
#define VPY_NO_REORDER 1
#endif
static int s_draws_since_zero = 0;


/* Cache the last intensity so we skip the redundant SET_INTENSITY syscall+bus
 * write when consecutive segments share a brightness — measured 42–100% of them
 * do (starcas 100%, tacscan 92%, bzone/redbaron ~45%). Reset each frame in case
 * the BIOS touches intensity between frames. Cuts per-frame beam work → less
 * flicker on the vector-heavy AAE arcade ports. */
static int s_last_intensity = -1;

static int clamp127(int v) { return v > 127 ? 127 : (v < -127 ? -127 : v); }

/* Blanked move to (x,y), split into ≤127 steps so a long move doesn't wrap the
 * i8 DAC (the integrators accumulate). Capped at 8 steps like the BIOS dv_move_to. */
static void beam_move_to(int x, int y)
{
    int dx = x - s_beam_x, dy = y - s_beam_y, steps = 0;
    while ((dx > 127 || dx < -127 || dy > 127 || dy < -127) && steps < 8) {
        int sx = clamp127(dx), sy = clamp127(dy);
        BEAM_MOVE(sx, sy);
        dx -= sx; dy -= sy; steps++;
    }
    /* Skip the reposition when the beam is already there — connected segments in
     * a path share endpoints, so this elides one MOVE(0,0) syscall per segment
     * (matches the native backend's stroke chaining; big win vs a move per seg). */
    if (dx || dy) BEAM_MOVE(dx, dy);
    s_beam_x = x; s_beam_y = y;
}

/* LIT draw to (x,y), split into N PROPORTIONAL ≤127 i8 chunks. A DP-simplified
 * long vector (Speed Freak's road rail collapses to one segment >127 units) would
 * be truncated by the i8 BEAM_DRAW / dc_cmd delta and vanish. But the split must
 * keep the SLOPE: clamping dx and dy independently draws chunks of different angles
 * → the line kinks/goes random (the bent right rail). Divide the whole vector into
 * n = ceil(max(|dx|,|dy|)/127) equal sub-segments so every chunk is collinear. */
static void beam_draw_to(int x, int y)
{
    int sx0 = s_beam_x, sy0 = s_beam_y;
    int dx = x - sx0, dy = y - sy0;
    int adx = dx < 0 ? -dx : dx, ady = dy < 0 ? -dy : dy;
#if BEAM_DELTA_ES_I8
    int n = ((adx > ady ? adx : ady) + 126) / 127;   /* ceil(max/127) */
#else
    int n = 1;   /* el backend acepta el delta entero y trocea por el limite real */
#endif
    if (n < 1) n = 1;
    for (int i = 1; i <= n; i++) {
        int tx = sx0 + (int)((long)dx * i / n);
        int ty = sy0 + (int)((long)dy * i / n);
        BEAM_DRAW(tx - s_beam_x, ty - s_beam_y);
        s_beam_x = tx; s_beam_y = ty;
    }
}

/* ── Contiguous collinear-run merge — the runtime analogue of the VPy codegen's
 * vec-simplify. The AAE 3D ports (Battlezone/Red Baron) subdivide straight edges
 * into many ≤2-unit segments — ~70% of the scene — and each pays a full beam
 * setup (Y S&H charge + ramp) → flicker. Accumulate a run of contiguous,
 * same-brightness, near-collinear segments and draw it as ONE vector. MERGE_TOL
 * is the max perpendicular deviation (device units, ±127 space) a segment may add
 * before it's treated as a corner; 0 disables the merge. Applies to every game
 * that draws via v_directDraw32 (VPy games already simplify, so few merges fire). */
#ifndef MERGE_TOL
#define MERGE_TOL 1
#endif
/* Intensity-gated merge: some games mix BRIGHT long straight lines (which want an
 * aggressive tolerance so a slightly-curved run collapses to a couple of vectors —
 * e.g. Speed Freak's perspective road rails) with DIM small glyphs (text, which a
 * high tolerance would visibly deform). A vector whose brightness ≥ MERGE_INT_HI
 * uses MERGE_TOL_HI instead of MERGE_TOL. Defaults leave every game unchanged:
 * MERGE_TOL_HI = MERGE_TOL, MERGE_INT_HI = 128 (never triggers). */
#ifndef MERGE_TOL_HI
#define MERGE_TOL_HI MERGE_TOL
#endif
#ifndef MERGE_INT_HI
#define MERGE_INT_HI 128
#endif
/* Longest merged vector, in device units. The merge is bounded anyway by the i8
 * DRAW delta (±127), but a game whose art is drawn as deliberately SHORT collinear
 * chunks may have chosen that length because one long analog ramp visibly drifts or
 * bows on its hardware — merging the chunks back would undo the workaround. Lower
 * this to keep the benefit (fewer beam setups) without recreating the long ramp.
 * Default 127 = the i8 limit, i.e. unchanged for every existing game. */
#ifndef MERGE_MAX
#define MERGE_MAX 127
#endif
static int s_run = 0, s_run_x0, s_run_y0, s_run_x1, s_run_y1, s_run_b;

/* Douglas-Peucker chain simplification — the runtime twin of the compile-time
 * simplify_polyline in vpy_codegen/src/vecres.rs. A curved multi-segment path
 * (Speed Freak's road) fits the greedy collinear merge badly: it snaps at every
 * bend yet fuses near-collinear glyph strokes (text deforms). DP instead keeps the
 * vertices of maximum perpendicular deviation and drops the ones lying on the
 * retained chord — a smooth run collapses to a few long vectors while true corners
 * (glyph vertices, road bends) survive. Per-game (-DSIMPLIFY_EPS=N, a ±127-space
 * epsilon); 0 = off (default; other games unchanged). Integer math: compare
 * perp²·len2 = cross² against eps²·len2, so no sqrt. */
#ifndef SIMPLIFY_EPS
#define SIMPLIFY_EPS 0
#endif
/* Only Douglas-Peucker chains of at least this many points. Long polylines (a road)
 * simplify; short shapes (text glyphs — a few strokes) pass through INTACT, so DP
 * shrinks the road without eating letters. Per-game (-DSIMPLIFY_MIN_CHAIN=N). */
#ifndef SIMPLIFY_MIN_CHAIN
#define SIMPLIFY_MIN_CHAIN 1
#endif
#if SIMPLIFY_EPS > 0
#define CHAIN_MAX 96
static int s_chx[CHAIN_MAX], s_chy[CHAIN_MAX], s_chn = 0, s_chb = -1;
static void dp_rec(int first, int last, long long eps2, unsigned char *keep)
{
    if (last <= first + 1) return;
    long ax = s_chx[first], ay = s_chy[first];
    long bx = s_chx[last],  by = s_chy[last];
    long dx = bx - ax, dy = by - ay;
    long long len2 = (long long)dx * dx + (long long)dy * dy;
    long long best = -1; int split = first;
    for (int i = first + 1; i < last; i++) {
        long px = s_chx[i], py = s_chy[i];
        long long m;
        if (len2 > 0) {                    /* perp² · len2 == cross²          */
            long long cross = (long long)dx * (ay - py) - (long long)(ax - px) * dy;
            m = cross * cross;
        } else {                           /* degenerate chord: point dist²   */
            long long ex = px - ax, ey = py - ay;
            m = ex * ex + ey * ey;
        }
        if (m > best) { best = m; split = i; }
    }
    long long thresh = (len2 > 0) ? eps2 * len2 : eps2;
    if (best > thresh) {
        keep[split] = 1;
        dp_rec(first, split, eps2, keep);
        dp_rec(split, last,  eps2, keep);
    }
}
#endif

/* Emit one absolute segment: re-zero if the drift budget is spent, set brightness
 * (cached), blank-move to the start, lit-draw to the end (BIOS convention). */
static void beam_seg(int ax0, int ay0, int ax1, int ay1, int b)
{
    /* Bound integrator drift by re-zeroing — but ONLY at a chain boundary (where a
     * blanked move to the next start is needed anyway), never MID contiguous run.
     * A mid-run re-zero sends the beam to centre and re-approaches over a long
     * blanked move whose settle error DISPLACES the segment — worst on runs far
     * from centre (Speed Freak's right road rail, always the one that "walks off").
     * So a contiguous run draws unbroken; drift only resets between runs. */
    int need_move = (ax0 != s_beam_x || ay0 != s_beam_y);
    int rezero = need_move && s_draws_since_zero >= VPY_MAX_CONSECUTIVE_DRAWS;
    if (rezero) {
        BEAM_ZERO();
        s_beam_x = 0; s_beam_y = 0;
        s_draws_since_zero = 0;
        /* LA INTENSIDAD CACHEADA MUERE CON EL CERO. zero_beam() del firmware escribe
         * PORT_A=0 y borra el registro de desplazamiento, asi que tras un re-cero el
         * haz ya NO tiene la intensidad que `s_last_intensity` dice que tiene. Sin
         * invalidar la cache, el `if (b != s_last_intensity)` de abajo se salta la
         * escritura y TODO lo que se dibuja despues del primer re-cero del frame sale
         * a la intensidad que deje el cero.
         *
         * MEDIDO en el emulador ARM con el .bin real, dkong 25m y SnowBros titulo: de
         * 453 y 251 segmentos, SOLO LOS 6 PRIMEROS —justo hasta el primer re-cero, que
         * llega a los VPY_MAX_CONSECUTIVE_DRAWS trazos— salian con la intensidad del
         * juego. Y encaja con la consola: lo unico que se ve brillante es aquello cuya
         * intensidad CAMBIA respecto al trazo anterior (que fuerza la escritura); todo
         * lo que comparte intensidad con su vecino sale apagado. */
        s_last_intensity = -1;
        /* The approach from the origin is itself travel, and it is billed to the new
         * budget — otherwise a shape far from centre re-zeroes and immediately spends
         * its whole allowance getting back out there, which is the "walks off" failure
         * the comment above describes. */
    }
    /* INTENSIDAD 0 = SALTO EN BLANCO, no un trazo a oscuras. El haz tiene que
     * recorrer el tramo de todas formas —los integradores corren igual—, asi que
     * apagarlo con BEAM_INTENSITY y dibujarlo cuesta una escritura de bus de mas y
     * no pinta nada. Un MOVE hace lo mismo y ademas no toca la intensidad cacheada,
     * asi que el tramo encendido de al lado no tiene que volver a ponerla. */
    if (b == 0) { beam_move_to(ax0, ay0); beam_move_to(ax1, ay1); return; }
    if (b != s_last_intensity) { BEAM_INTENSITY(b); s_last_intensity = b; }
    beam_move_to(ax0, ay0);
    beam_draw_to(ax1, ay1);   /* splits >127 i8 chunks (DP long vectors) */
    s_draws_since_zero++;
}

#if HAS_GAPPED_RAMP
/* The gapped twin of beam_seg: ONE ramp for a whole collinear run, with BLANK toggled
 * along the way. Same bookkeeping — the run is a draw like any other, so it re-zeroes on
 * the same budget and leaves the beam at its end.
 *
 * `gaps` are (start,end) pairs in 0..255 fractions of the run, already merged and
 * clamped by the caller. The run is guaranteed to fit the command's i8 delta because
 * flush_frame() caps it at +-127; the guard below is there so a future caller that
 * forgets cannot emit a wrapped delta, which would draw a line to somewhere else.
 */
static void beam_seg_gapped(int ax0, int ay0, int ax1, int ay1, int b,
                            const unsigned char *gaps, int ngaps)
{
    int dx = ax1 - ax0, dy = ay1 - ay0;
    if (dx > 127 || dx < -127 || dy > 127 || dy < -127 || ngaps <= 0) {
        beam_seg(ax0, ay0, ax1, ay1, b);   /* cannot be one command: draw it plain */
        return;
    }
    int need_move = (ax0 != s_beam_x || ay0 != s_beam_y);
    if (need_move && s_draws_since_zero >= VPY_MAX_CONSECUTIVE_DRAWS) {
        BEAM_ZERO();
        s_beam_x = 0; s_beam_y = 0;
        s_draws_since_zero = 0;
        s_last_intensity = -1;   /* ver la nota de beam_seg */
    }
    if (b != s_last_intensity) { BEAM_INTENSITY(b); s_last_intensity = b; }
    beam_move_to(ax0, ay0);
    BEAM_DRAW_GAPPED(dx, dy, gaps, ngaps);
    s_beam_x = ax1; s_beam_y = ay1;
    s_draws_since_zero++;
}
#endif

/* ── Frame-level stroke reorder (nearest-neighbour) ─────────────────────────
 * On this HW the beam's per-vector time is ∝ travel, so drawing shapes in the
 * order the game emits them makes the beam criss-cross the screen BLANKED — for
 * a busy screen (Donkey Kong) ~80% of the frame's beam-time was wasted on those
 * repositioning moves, collapsing the refresh rate → heavy flicker. So instead
 * of emitting each segment immediately, emit_seg() RECORDS it into a stroke (a
 * maximal run of connected, same-brightness segments); at v_WaitRecal the frame
 * is flushed with the strokes ordered greedily nearest-first, each in whichever
 * direction starts closest to the beam. Same picture (phosphor persistence hides
 * draw order), a fraction of the blanked travel — applies to EVERY game.
 * Per-game escape: -DVPY_NO_REORDER falls back to immediate emission. */
#ifndef VPY_NO_REORDER
#ifndef VPY_REORDER_MAX_PTS
#define VPY_REORDER_MAX_PTS    4096
#endif
#ifndef VPY_REORDER_MAX_STROKE
#define VPY_REORDER_MAX_STROKE 1024
#endif
static short  rr_y[VPY_REORDER_MAX_PTS], rr_x[VPY_REORDER_MAX_PTS];
/* rr_dark[k] = el segmento que ACABA en el punto k va apagado. Antes la intensidad
 * era por TRAZO, asi que un tramo a oscuras partia el trazo en dos y el reordenador
 * los repartia por el frame: cada trozo se re-aproximaba con un salto en blanco desde
 * donde estuviera el haz. Con esto una recta con gaps —los peldanos de dos escaleras
 * y el aire entre ellas— se recorre UNA vez de punta a punta. */
static unsigned char rr_dark[VPY_REORDER_MAX_PTS];
static int    rr_off[VPY_REORDER_MAX_STROKE], rr_len[VPY_REORDER_MAX_STROKE], rr_b[VPY_REORDER_MAX_STROKE];
static int    rr_npts = 0, rr_nst = 0;
/* Last frame's stroke count, kept after the reset so it can be read live. */
volatile int  vpy_strokes_last = 0;

/* record a segment; extend the open stroke iff it connects and shares brightness */
static void emit_seg(int ax0, int ay0, int ax1, int ay1, int b)
{
    /* un tramo apagado se une SIEMPRE (no trae intensidad propia que respetar), y un
     * tramo encendido se une si el trazo aun no tiene intensidad o coincide con la suya */
    if (rr_nst > 0 && rr_npts > 0 && rr_npts < VPY_REORDER_MAX_PTS &&
        rr_y[rr_npts-1] == ay0 && rr_x[rr_npts-1] == ax0 &&
        (b == 0 || rr_b[rr_nst-1] == 0 || rr_b[rr_nst-1] == b)) {
        rr_y[rr_npts] = ay1; rr_x[rr_npts] = ax1; rr_dark[rr_npts] = (b == 0);
        rr_npts++;
        rr_len[rr_nst-1]++;
        if (b) rr_b[rr_nst-1] = b;
        return;
    }
    if (rr_nst < VPY_REORDER_MAX_STROKE && rr_npts + 2 <= VPY_REORDER_MAX_PTS) {
        rr_off[rr_nst] = rr_npts; rr_len[rr_nst] = 2; rr_b[rr_nst] = b;
        rr_nst++;
        rr_y[rr_npts] = ay0; rr_x[rr_npts] = ax0; rr_dark[rr_npts] = 0; rr_npts++;
        rr_y[rr_npts] = ay1; rr_x[rr_npts] = ax1; rr_dark[rr_npts] = (b == 0); rr_npts++;
        return;
    }
    beam_seg(ax0, ay0, ax1, ay1, b);   /* buffer full → emit directly (no reorder) */
}

static long rr_d2(int ay, int ax, int by, int bx){ long dy = ay-by, dx = ax-bx; return dy*dy + dx*dx; }

/* reorder + emit the frame's recorded strokes, then reset. Beam starts at the
 * device origin (0,0) — v_WaitRecal re-zeros it right after. O(strokes^2). */
static void flush_frame(void)
{
    int by = 0, bx = 0;
    for (int done = 0; done < rr_nst; done++) {
        int best = -1, rev = 0; long bestd = 0;
        for (int s = 0; s < rr_nst; s++) {
            if (rr_len[s] < 0) continue;                 /* already emitted */
            int a = rr_off[s], z = rr_off[s] + rr_len[s] - 1;
            long d0 = rr_d2(by, bx, rr_y[a], rr_x[a]);
            long d1 = rr_d2(by, bx, rr_y[z], rr_x[z]);
            if (best < 0 || d0 < bestd) { bestd = d0; best = s; rev = 0; }
            if (d1 < bestd)             { bestd = d1; best = s; rev = 1; }
        }
        int a = rr_off[best], n = rr_len[best], b = rr_b[best];
        rr_len[best] = -1;
        /* ONE RAMP PER COLLINEAR RUN, not per segment.
         *
         * Splitting a line into pieces costs one operation per piece: two DACs, the T1
         * count, open and close the ramp. With DRAW_SCALE=160 and MIN_T1=31 that is ~21
         * us of MINIMUM ramp even for a two-unit piece, plus ~16-27 us of bus writes.
         * And it is not needed: the beam's velocity is set by the DACs, so while they
         * are left alone the beam keeps travelling THE SAME LINE.
         *
         * So look for runs of collinear, same-direction segments. All lit means ONE
         * stroke — that works on both boards and needs nothing new; a mix of lit and
         * dark goes through the gapped ramp, which toggles BLANK along the way.
         * Measured on the 25m: 26 runs merging 55 operations, ~2.2 ms of an 18.5 ms
         * frame.
         *
         * The +-127 cap is the command's i8 delta: a longer run is split, which is what
         * beam_draw_to did anyway. */
        #define PY(k) (rev ? rr_y[a+n-1-(k)] : rr_y[a+(k)])
        #define PX(k) (rev ? rr_x[a+n-1-(k)] : rr_x[a+(k)])
        /* la marca es del SEGMENTO: el k une los puntos k y k+1 */
        #define OSC(k) (rev ? rr_dark[a+n-1-(k)] : rr_dark[a+(k)+1])
        for (int k = 0; k < n-1; ) {
            long ux = PX(k+1)-PX(k), uy = PY(k+1)-PY(k);
            int j = k + 1;
            while (j < n-1) {
                long vx = PX(j+1)-PX(j), vy = PY(j+1)-PY(j);
                if (ux*vy != vx*uy || ux*vx + uy*vy <= 0) break;   /* gira o retrocede */
                int tx = PX(j+1)-PX(k), ty = PY(j+1)-PY(k);
                if (tx > 127 || tx < -127 || ty > 127 || ty < -127) break;
                j++;
            }
            int nsegs = j - k, dark = 0;
            for (int m = k; m < j; m++) if (OSC(m)) dark++;
            if (nsegs == 1 || (dark && dark != nsegs && !HAS_GAPPED_RAMP)) {
                for (int m = k; m < j; m++)
                    beam_seg(PX(m), PY(m), PX(m+1), PY(m+1), OSC(m) ? 0 : b);
            } else if (dark == 0) {
                beam_seg(PX(k), PY(k), PX(j), PY(j), b);
            } else if (dark == nsegs) {
                beam_seg(PX(k), PY(k), PX(j), PY(j), 0);
            }
#if HAS_GAPPED_RAMP
            else {
                /* los gaps en fracciones 0..255: la rampa avanza con el eje dominante,
                 * asi que la fraccion se mide en ese eje. */
                int TX = PX(j)-PX(k), TY = PY(j)-PY(k);
                long aX = TX < 0 ? -TX : TX, aY = TY < 0 ? -TY : TY;
                long total = aX > aY ? aX : aY; if (!total) total = 1;
                unsigned char h[DC_GAPS_MAX*2]; int nh = 0; long acc = 0;
                for (int m = k; m < j; m++) {
                    int sx = PX(m+1)-PX(m), sy = PY(m+1)-PY(m);
                    long bx2 = sx < 0 ? -sx : sx, by2 = sy < 0 ? -sy : sy;
                    long len = bx2 > by2 ? bx2 : by2;
                    if (OSC(m)) {
                        int ini = (int)(acc * 255 / total);
                        int fin = (int)((acc + len) * 255 / total);
                        if (nh && h[nh*2-1] >= ini) h[nh*2-1] = (unsigned char)fin;
                        else if (nh < DC_GAPS_MAX) {
                            h[nh*2] = (unsigned char)ini; h[nh*2+1] = (unsigned char)fin; nh++;
                        }
                    }
                    acc += len;
                }
                beam_seg_gapped(PX(k), PY(k), PX(j), PY(j), b, h, nh);
            }
#endif
            k = j;
        }
        by = PY(n-1); bx = PX(n-1);
        #undef PY
        #undef PX
        #undef OSC
    }
    vpy_strokes_last = rr_nst;
    rr_npts = 0; rr_nst = 0;
}
#else
#define emit_seg    beam_seg    /* reorder disabled: emit immediately */
#define flush_frame()           ((void)0)
#endif

#if SIMPLIFY_EPS > 0
/* Douglas-Peucker the buffered contiguous chain, emit the kept vertices as
 * connected segments. */
static void flush_chain(void)
{
    if (s_chn < 2) { s_chn = 0; return; }
    unsigned char keep[CHAIN_MAX];
    for (int i = 0; i < s_chn; i++) keep[i] = 0;
    keep[0] = keep[s_chn - 1] = 1;
    if (s_chn >= SIMPLIFY_MIN_CHAIN)
        dp_rec(0, s_chn - 1, (long long)SIMPLIFY_EPS * SIMPLIFY_EPS, keep);
    else
        for (int i = 1; i < s_chn - 1; i++) keep[i] = 1;   /* short shape: keep all */
    int px = s_chx[0], py = s_chy[0];
    for (int i = 1; i < s_chn; i++)
        if (keep[i]) { emit_seg(px, py, s_chx[i], s_chy[i], s_chb); px = s_chx[i]; py = s_chy[i]; }
    s_chn = 0;
}
#endif

/* Draw + clear the pending merged run. MUST be called before anything that
 * re-zeros the beam (WAIT_RECAL, new stroke) or the run draws from a stale origin. */
static void flush_run(void)
{
    if (s_run) { emit_seg(s_run_x0, s_run_y0, s_run_x1, s_run_y1, s_run_b); s_run = 0; }
#if SIMPLIFY_EPS > 0
    flush_chain();
#endif
}

/* EL RECORTE DE TRAZOS CORTOS SE RETIRO EL 2026-09-09, Y NO VUELVE.
 *
 * Fue `CULL_MIN_AX`: tiraba los trazos iluminados con menos de N unidades de dispositivo
 * EN LOS DOS EJES. Se escribio para pseudo-3D (Speed Freak), donde el detalle lejano se
 * agolpa en el punto de fuga y se vuelve a dibujar a tamaño completo cuando la camara se
 * acerca. En un juego de escenario no hay punto de fuga: lo que tira es el dibujo.
 *
 * MEDIDO en Donkey Kong, un frame del 25m sacado del arnes de host (639 trazos):
 *     N=1     7 tirados  ( 1%)
 *     N=2   116 tirados  (18%)   <- lo que llevaba dkong
 *     N=3   191 tirados  (30%)
 * Y 639 - 116 = 523 contra los 520 que se leyeron POR SWD del cartucho dibujando esa
 * pantalla: cuadraba a tres trazos. Era exactamente la geometria que faltaba en la foto.
 *
 * NO SE DEJA APAGADO POR DEFECTO, SE QUITA. Un knob a cero es un knob que alguien vuelve a
 * encender, y este ya sobrevivio a que lo dieran por retirado. Ademas era invisible desde
 * el arnes de host —el recorte vive AQUI, y el host no pasa por esta capa—, asi que medir
 * su efecto exigia leer el cartucho por SWD. Si algun dia hace falta recortar detalle
 * lejano, que lo haga el JUEGO que sabe donde esta su punto de fuga, no el SDK de todos. */
#ifdef CULL_MIN_AX
#error "CULL_MIN_AX se retiro el 2026-09-09: tiraba el 18% del dibujo de dkong. Ver la nota de arriba."
#endif

/* TEXT opts OUT of the sub-visible cull AND of the collinear merge: glyph strokes
 * ARE small (1-2 units), so culling them mangles the letters, and merging fuses
 * strokes of adjacent letters that happen to abut into one long bright bar. The
 * game brackets its text with v_textBegin()/v_textEnd(); segments drawn in between
 * are kept at full detail and emitted one-for-one, so only NON-text vectors are
 * culled/merged. Before this, a game with vector text had to disable the merge
 * game-wide (jetpac_sbt built -DMERGE_TOL=0), which left its long straight line-art
 * — platforms, floor — drawn as a chain of separate short dashes. No-op for games
 * that never call it (s_in_text stays 0) or that build with both off. */
static int s_in_text = 0;
#ifdef VPY_MIDE_REDONDEO
volatile unsigned vpy_red_n, vpy_red_err_c, vpy_red_subunidad, vpy_red_cero;
/* SONDAS PROPIAS de la comparacion con el VecFever. Separadas de vpy_red_* a proposito:
 * aquellas son CONTADORES que el SDK incrementa en cada vector, asi que una sonda que se
 * apoye en ellas lee el contador, no lo que escribio. Me costo media sesion de medidas
 * falsas. `sonda_lista` distingue "sin escribir" de "escribio un cero". */
#ifdef VPY_MIDE_REDONDEO
volatile int sonda_a, sonda_b, sonda_c, sonda_d, sonda_e, sonda_f;
volatile unsigned sonda_lista;
#endif
#endif
void v_textBegin(void) { s_in_text = 1; }
void v_textEnd(void)   { s_in_text = 0; }

#ifdef UVM2_SUBUNIDAD
/* CAMINO DE SUB-UNIDADES: DEL JUEGO AL SDK SIN PASAR POR LA REJILLA ENTERA.
 *
 * `VS_RND` divide las coordenadas del juego por 127 y REDONDEA A ENTERO. Medido en mhavoc
 * sobre 81.552 vectores: 0,22 unidades de error por eje, el 3,6% de los vectores
 * enteramente sub-unidad y el 0,26% desapareciendo porque sus dos extremos caen en el mismo
 * punto. Con la geometria del VecFever de entrada, ese redondeo hacia PERDER las entradas 1
 * a 4 de su tabla de records y el resto salia en diagonal; en 1/16 sale la lista completa.
 *
 * POR QUE SE SALTA beam_seg Y LA FUSION. `BEAM_MOVE`/`BEAM_DRAW` castean el delta a
 * `signed char`, o sea +-127 — que en 1/16 son +-7,9 unidades. Llevar ese camino entero a
 * sub-unidades obliga a cambiar la codificacion de comandos del doble nucleo, que es otra
 * cosa y mas grande. Aqui se va directo a la API del SDK, que ya toma 1/16.
 *
 * LO QUE SE PIERDE, y no es gratis: la fusion de colineales, la simplificacion
 * Douglas-Peucker y el culling trabajan en enteros y se quedan fuera. Para mhavoc eso es
 * SIMPLIFY_EPS=2: sin ella salen mas vectores y el frame cuesta mas. Es un intercambio
 * medible; si duele, lo que hay que hacer es llevar esas tres a 1/16 tambien. */
void uvm2_draw_move_abs_q4(int x_q4, int y_q4);
void uvm2_draw_delta_q4(int dx_q4, int dy_q4);
void uvm2_draw_intensity(int z);

#define VS_Q4(v) ((int)(((v) < 0 ? (long)(v) * 16 - VPY_SCALE / 2 \
                                 : (long)(v) * 16 + VPY_SCALE / 2) / VPY_SCALE))

void v_directDraw32(int32_t x0, int32_t y0, int32_t x1, int32_t y1, uint8_t b)
{
    if (b == 0) return;                       /* z=0 es un salto en blanco, no un trazo */
#ifdef UVM2_CUENTA_ENTRADA
    uvm2_cuenta_entrada++;   /* DIAGNOSTICO: cuantas llamadas de dibujo ENTRAN al SDK */
#endif
#ifdef VPY_DUAL_CORE
    /* El cartucho propio: las mismas tres llamadas, pero grabadas en el anillo para que las
     * haga la BIOS (dc.rs), que las pasa a uvm2_draw.c tal cual. */
    BEAM_INTENSITY((signed char)b);
    dc_push_q4(DC_OP_MOVE_ABS_Q4, VS_Q4(x0), VS_Q4(y0));
    dc_push_q4(DC_OP_DELTA_Q4, VS_Q4(x1) - VS_Q4(x0), VS_Q4(y1) - VS_Q4(y0));
#else
    uvm2_draw_intensity((int)b);
    uvm2_draw_move_abs_q4(VS_Q4(x0), VS_Q4(y0));
    uvm2_draw_delta_q4(VS_Q4(x1) - VS_Q4(x0), VS_Q4(y1) - VS_Q4(y0));
#endif
}
#else
void v_directDraw32(int32_t x0, int32_t y0, int32_t x1, int32_t y1, uint8_t b)
{
#ifdef UVM2_CUENTA_ENTRADA
    if (b) uvm2_cuenta_entrada++;   /* DIAGNOSTICO: llamadas de dibujo que ENTRAN */
#endif
    /* ROUND, DO NOT TRUNCATE. C division truncates TOWARDS ZERO, so this snapped the two
     * halves of the screen in opposite directions and carried a whole unit of error
     * instead of half. On a long vector nobody sees it; on a vector CUT INTO PIECES — an
     * occluded girder — each piece rounds its own ends and the pieces stop sharing a
     * slope. Measured on a 25m girder: pieces at -0.0641, -0.0562, -0.0549 and -0.0556
     * where the line is -0.056, which is the staircase you can see. */
    int ax0 = VS_RND(x0), ay0 = VS_RND(y0);
    int ax1 = VS_RND(x1), ay1 = VS_RND(y1);
#ifdef VPY_MIDE_REDONDEO
    /* CUANTA PRECISION SE TIRA AQUI. El juego entrega coordenadas finas (del orden de
     * +-16000) y VS_RND las redondea a las +-127 enteras del DAC, o sea 1/127 de lo que
     * traia. La pregunta es si eso importa: se cuenta el error en centesimas de unidad y
     * cuantos vectores quedan por debajo de UNA unidad, que son los que no se pueden ni
     * expresar. Solo con -DVPY_MIDE_REDONDEO; fuera de eso no cuesta nada. */
    {
        extern volatile unsigned vpy_red_n, vpy_red_err_c, vpy_red_subunidad, vpy_red_cero;
        #define VPY_ABS(v) ((v) < 0 ? -(v) : (v))
        long ex = (long)x0 - (long)ax0 * VPY_SCALE, ey = (long)y0 - (long)ay0 * VPY_SCALE;
        vpy_red_n++;
        vpy_red_err_c += (unsigned)((VPY_ABS(ex) + VPY_ABS(ey)) * 100 / VPY_SCALE);
        long dxf = (long)x1 - (long)x0, dyf = (long)y1 - (long)y0;
        if (VPY_ABS(dxf) < VPY_SCALE && VPY_ABS(dyf) < VPY_SCALE) vpy_red_subunidad++;
        if (ax0 == ax1 && ay0 == ay1) vpy_red_cero++;   /* el vector desaparece al redondear */
    }
#endif
#if SIMPLIFY_EPS > 0
    /* Buffer a contiguous, same-brightness chain; Douglas-Peucker it on flush. */
    if (s_chn > 0 && (int)b == s_chb &&
        ax0 == s_chx[s_chn - 1] && ay0 == s_chy[s_chn - 1] && s_chn < CHAIN_MAX - 1) {
        s_chx[s_chn] = ax1; s_chy[s_chn] = ay1; s_chn++;
    } else {
        flush_chain();
        s_chx[0] = ax0; s_chy[0] = ay0; s_chx[1] = ax1; s_chy[1] = ay1; s_chn = 2; s_chb = (int)b;
    }
    return;
#endif
#if MERGE_TOL > 0 || MERGE_TOL_HI > 0
    int tol = s_in_text ? 0 : (((int)b >= MERGE_INT_HI) ? MERGE_TOL_HI : MERGE_TOL);
    if (tol > 0 && s_run && (int)b == s_run_b && ax0 == s_run_x1 && ay0 == s_run_y1) {
        int rdx = s_run_x1 - s_run_x0, rdy = s_run_y1 - s_run_y0;  /* run so far     */
        int ndx = ax1 - ax0,          ndy = ay1 - ay0;            /* new segment    */
        int ex  = ax1 - s_run_x0,     ey  = ay1 - s_run_y0;       /* merged delta   */
        long cross = (long)rdx * ndy - (long)rdy * ndx;           /* |run||new|sinθ  */
        long dot   = (long)rdx * ndx + (long)rdy * ndy;           /* same direction? */
        long run2  = (long)rdx * rdx + (long)rdy * rdy;
        /* Extend the run iff: same general direction, perpendicular deviation
         * (|cross|/|run|) ≤ tol, and the merged delta still fits an i8 DRAW (and
         * MERGE_MAX, if the game asked for a shorter ceiling than the i8 limit). */
        if (dot >= 0 && cross * cross <= run2 * (long)(tol * tol)
            && ex <= MERGE_MAX && ex >= -MERGE_MAX && ey <= MERGE_MAX && ey >= -MERGE_MAX) {
            s_run_x1 = ax1; s_run_y1 = ay1;
            return;
        }
    }
    flush_run();
    s_run = 1; s_run_x0 = ax0; s_run_y0 = ay0; s_run_x1 = ax1; s_run_y1 = ay1; s_run_b = (int)b;
#else
    emit_seg(ax0, ay0, ax1, ay1, (int)b);
#endif
}
#endif /* UVM2_SUBUNIDAD */

/* ── Frame pace + input. vpy_frame_begin() calls v_WaitRecal then the two input
 * refreshers, so v_WaitRecal only paces + re-zeros our tracked beam. ── */
void v_WaitRecal(void)
{
    flush_run();    /* push the frame's last pending merged run into the buffer  */
    flush_frame();  /* reorder the frame's strokes nearest-first, then emit them */
#ifdef VPY_DUAL_CORE
    /* Seal the frame we just recorded for core 0, then spin (in RAM, no svc/flash)
     * until the OTHER buffer is free so we never overwrite one core 0 is drawing.
     * Pipeline: core 0 draws buffer A while we record buffer B → frame = max(). */
    DC_CTRL->count[s_dc_w] = (unsigned short)s_dc_n;
    __asm__ volatile("dmb 0xf" ::: "memory");
    DC_CTRL->state[s_dc_w] = DC_SEALED;
    __asm__ volatile("sev" ::: "memory");           /* wake core 0 if it's waiting */
    int n = 1 - s_dc_w;
    while (DC_CTRL->state[n] != DC_FREE) { __asm__ volatile("" ::: "memory"); }
    __asm__ volatile("dmb 0xf" ::: "memory");
    s_dc_w = n; s_dc_n = 0;
#else
    sys_wait_recal();
#endif
    s_beam_x = 0; s_beam_y = 0;
    s_draws_since_zero = 0;   /* WAIT_RECAL zero-refs the beam → fresh drift budget */
    s_last_intensity = -1;    /* re-establish brightness on the first segment of the frame */
}

/* Start a new stroke/path with a fresh zero-ref, so integrator drift can't carry
 * across shape/path boundaries (mirrors the native ARM backend's per-path
 * re-zero). libvpy calls this at each path start on RP2350. The MAX_CONSECUTIVE
 * cap in v_directDraw32 still bounds a single very long path on top of this. */
/* ── EL RE-CERO POR OBJETO, POR PRESUPUESTO: PROBADO EN CONSOLA Y DESCARTADO ──
 *
 * Se probo hacer que el limite de objeto fuera una OPORTUNIDAD de pinzar el cero y no una
 * obligacion —pinzar solo tras VPY_MAX_CONSECUTIVE_DRAWS trazos— porque el VecFever dibuja
 * Major Havoc con 12,6 pinzas por frame y 27 trazos entre ellas, y dkong hacia 55 pinzas
 * con 8 trazos entre ellas: 5,5 veces mas. Barrido en el emulador (dkong 25m, frame
 * congelado, ~498 trazos):
 *
 *     por objeto  55 pinzas  8,0 entre pinzas  11625 ciclos (32%)  bus 37006
 *     16          23         22,7               4730 (13%)         35435
 *     24          19         27,7               3870 (11%)         35119   <- el de su cadencia
 *     32          15         35,6               2938 ( 8%)         35154
 *
 * **EN LA CONSOLA, CON 24, EL DIBUJO SE ROMPE ENTERO** (Daniel, 2026-09-10: *"dk24 rompe
 * todo"*). Y el emulador no lo veia venir: las cajas de los cinco barridos salian iguales
 * a dos unidades (202x214 .. 204x215) y el dibujo se veia limpio en los renders.
 *
 * POR QUE no se ve aqui: el re-cero por objeto esta tapando la DERIVA ANALOGICA de los
 * integradores, y eso no esta modelado. La nota de VK_NO_OBJECT en vk_render.c ya lo decia
 * —sin asentar el cero la Y deriva 7 veces mas que la X— y el ahorro de frame era del 5%,
 * no del 30% que estime al principio (los 211 ciclos por pinza incluyen la reaproximacion
 * desde el centro, y ese viaje no desaparece al quitar la pinza).
 *
 * Se retira en vez de dejarlo tras un #ifdef apagado: un knob a cero es un knob que alguien
 * vuelve a encender. Si se reintenta, el criterio es la CONSOLA y hay que empezar por
 * entender por que su cadencia le vale a el y a nosotros no — probablemente porque nuestra
 * reaproximacion redondea peor. Lo que NO sirve es el emulador.
 *
 * Start a new stroke/path with a fresh zero-ref, so integrator drift can't carry
 * across shape/path boundaries (mirrors the native ARM backend's per-path re-zero). */
void v_beamNewStroke(void)
{
    flush_run();   /* finish the pending run before this stroke's re-zero */
    BEAM_ZERO();
    s_beam_x = 0; s_beam_y = 0;
    s_draws_since_zero = 0;
    s_last_intensity = -1;   /* el cero se lleva la intensidad; ver la nota de beam_seg */
}

uint8_t v_readButtons(void)
{
    /* SYS_READ_BUTTONS returns P1 in bits 0-3 (P2 in 4-7); libvpy's J1_BUTTON_N
     * reads bit N-1 of currentButtonState, so this maps 1:1. In dual-core, core 0
     * owns the bus and publishes the snapshot (no svc / bus access from core 1). */
#ifdef VPY_DUAL_CORE
    currentButtonState = (uint8_t)DC_CTRL->buttons;
#else
    currentButtonState = (uint8_t)sys_read_buttons();
#endif
    return currentButtonState;
}

void v_readJoystick1Analog(void)
{
    /* SYS_READ_AXES: (J1X<<24)|(J1Y<<16)|(J2X<<8)|J2Y, each a raw i8. */
#ifdef VPY_DUAL_CORE
    unsigned int a = DC_CTRL->axes;
#else
    unsigned int a = (unsigned int)sys_read_axes();
#endif
    currentJoy1X = (int8_t)(a >> 24);
    currentJoy1Y = (int8_t)(a >> 16);
}

/* The OTHER two mux channels. SYS_READ_AXES already samples all four (the BIOS SARs
 * channels 0..3 = J1X, J1Y, J2X, J2Y in one go), so this costs nothing extra — it just
 * unpacks the half that v_readJoystick1Analog throws away. Useful for a second pad, and
 * for telling "this axis is dead" apart from "this axis is on a different channel than
 * we think" when a controller misbehaves. */
/* WEAK: several AAE ports already define these in their own aae_stubs.c (as
 * `signed char`), and a strong definition here collided with them — 9 games stopped
 * linking with "multiple definition of `currentJoy2X'" the moment this was added.
 * Weak means the SDK supplies them only when the game does not. */
__attribute__((weak)) int8_t currentJoy2X = 0;
__attribute__((weak)) int8_t currentJoy2Y = 0;
__attribute__((weak)) void v_readJoystick2Analog(void)
{
#ifdef VPY_DUAL_CORE
    unsigned int a = DC_CTRL->axes;
#else
    unsigned int a = (unsigned int)sys_read_axes();
#endif
    currentJoy2X = (int8_t)(a >> 8);
    currentJoy2Y = (int8_t)a;
}

void v_writePSG(uint8_t reg, uint8_t val)
{
#ifdef VPY_DUAL_CORE
    dc_push(DC_OP_PSG, (signed char)reg, (signed char)val);
#else
    sys_psg_write(reg, val);
#endif
}

/* Digitised-sample audio (AAE Sega-G80). No-op on RP2350 for now: HW needs a
 * software voice mixer feeding the PSG volume-DAC streamer (see the .vsmp path).
 * A game built for rp2350 still triggers these; they just stay silent. */
void v_playSample(int idx, int voice, int loop) { (void)idx; (void)voice; (void)loop; }
void v_stopSample(int voice)                    { (void)voice; }
int  v_samplePlaying(int voice)                 { (void)voice; return 0; }

/* ── Core-1 music. The BIOS runs the .vmus sequencer on core 1 (tempo decoupled
 * from core-0 draw load); core 0 just hands over the track and stops it. libvpy
 * calls these instead of its software sequencer when built for RP2350. ── */
void v_playMusic(const unsigned char *vmus) { sys_play_music(vmus); }
void v_stopMusic(void)                      { sys_stop_music(); }

/* ── Freestanding libc bits. GCC emits calls to memset/memcpy/memmove for
 * aggregate init and array ops, and there is no libc in this bare-metal link
 * (we pull in only libgcc for the AEABI integer-division helpers). ── */
#include <stddef.h>
/* Only when there is NO libc behind us. Under the UVM2 pico-sdk build there is,
 * and defining these again is actively dangerous rather than merely redundant:
 * GCC recognises `while (n--) *p++ = c` as a memset and rewrites it into a CALL
 * to memset — this function — so it recurses until the stack eats the image.
 * Seen on hardware 2026-08-04: dkong's stack walked from 0x20082000 down past
 * 0x20027700 (371 KB) overwriting its own code, then took a HardFault whose
 * handler faulted too and locked the core up. The freestanding cartridge build
 * still needs them; it links no libc at all. */
#ifndef UVM2_PICO_RUNTIME
void *memset(void *d, int c, size_t n)  { unsigned char *p = d; while (n--) *p++ = (unsigned char)c; return d; }
void *memcpy(void *d, const void *s, size_t n) { unsigned char *pd = d; const unsigned char *ps = s; while (n--) *pd++ = *ps++; return d; }
void *memmove(void *d, const void *s, size_t n) {
    unsigned char *pd = d; const unsigned char *ps = s;
    if (pd < ps) { while (n--) *pd++ = *ps++; }
    else { pd += n; ps += n; while (n--) *--pd = *--ps; }
    return d;
}
#endif
