/* aae_machine.c - the Asteroids "machine": the AAE global state that normally
 * lives in aaemain.c, trimmed to the single game we run.
 *
 * Why not include aaemain.c: its driver[] table lists every AAE game, so it
 * drags in every game's init and run entry points (link errors) plus main().
 * Instead this file defines a ONE-ROW driver[] holding only the "Asteroids
 * (Revision 2)" entry (values copied verbatim from aaemain.c) and the handful
 * of globals the Asteroids execution path (cpu_control.c / cpuintrf.c /
 * asteroid.c) reads.
 *
 * gamenum is 0 because Asteroids is the only row. The per-frame runner reads
 * driver[gamenum].{cpu_type,cpu_freq,fps,cpu_divisions,cpu_intpass_per_frame,
 * cpu_int_type,int_cpu}; those are the fields that must be exact. The pointer
 * fields our path never dereferences (rom, game_dips, game_keys, game_samples,
 * artwork) are left NULL: ROMs are loaded from the embedded arrays (see the ROM
 * loader step), not via driver[].rom.
 */
#include <stdint.h>        /* osd_cpu.h (via globals.h) uses int8_t etc. */
#include <string.h>        /* memcpy for the ROM loader */
#include "globals.h"       /* struct AAEDriver, colors, aae_settings, GI, MAX_ACPU, CONTEXT* */
#include "cpu_control.h"   /* CPU_6502Z, CPU_NONE, INT_TYPE_NMI */
#include "asteroid_roms.h" /* embedded ROM byte arrays (rom_np3/ef2/h2/j2/...) */

/* Note on gamenum: it is 0 (index into our one-row driver[]), NOT the AAE
 * ASTEROID enum (~92). asteroid.c compares `gamenum==ASTEROID` only in the
 * high-score save path (save_hi / check_hi), which is stubbed on the cart, so
 * gamenum=0 is functionally correct for gameplay while keeping driver[gamenum]
 * in bounds. */

/* Asteroids entry points (defined in asteroid.c). */
extern int  init_asteroid(void);
extern void run_asteroids(void);
extern void end_asteroids(void);

/* ---- machine globals (subset of aaemain.c's, referenced by our path) ---- */
unsigned char   *GI[5];                 /* 6502 game image / memory pointers */
CONTEXTM6502    *c6502[MAX_ACPU];       /* 6502 CPU contexts (malloc'd in init) */
CONTEXTMZ80      cMZ80[MAX_ACPU];       /* Z80 contexts (unused; referenced by dispatch) */
int              gamenum = 0;           /* only Asteroids in driver[] */
int              WATCHDOG;
int              total_length;          /* AVG vector-list length accumulator */
int              testsw;                /* test switch */
int              paused;
colors           vec_colors[1024];      /* per-vector colour table */
aae_settings     config;                /* global config (zeroed) */

/* ---- the one game: Asteroids (Revision 2), copied from aaemain.c ---- */
struct AAEDriver driver[] =
{
    { "asteroid", "Asteroids (Revision 2)", 0,
      &init_asteroid, 0, &run_asteroids, &end_asteroids,
      0, 0,                             /* game_dips, game_keys */
      0, 0,                             /* game_samples, artwork */
      {CPU_6502Z, CPU_NONE, CPU_NONE, CPU_NONE},
      {1512000, 0, 0, 0},               /* cpu_freq */
      {4, 0, 0, 0},                     /* cpu_divisions */
      {1, 0, 0, 0},                     /* cpu_intpass_per_frame */
      {INT_TYPE_NMI, 0, 0, 0},          /* cpu_int_type */
      {0, 0, 0, 0},                     /* int_cpu (no custom int handlers) */
      60, VEC_BW_16, 0,                 /* fps, vid_type, rotation */
      {0, 1024, 0, 812}                 /* gamerect */
    }
};

/* ---- input: the 6502 reads Asteroids' control ports through getport(port),
 * one bit per switch (all active-high; see asteroid_keys in AAE gamekeys.h):
 *   port 0: Fire 0x10, Hyperspace 0x08
 *   port 1: RotateLeft 0x80, RotateRight 0x40, Thrust 0x20, P1-Start 0x08, Coin 0x01
 * We map the Vectrex controller onto them via the SDK shim's input snapshot
 * (currentButtonState / currentJoy1X/Y), refreshed each frame by
 * v_readButtons + v_readJoystick1Analog in the main loop. Same globals in the
 * rp2350 cart shim and the WASM host shim, so this works on HW and in the sim.
 *   stick left/right -> rotate    stick up -> thrust
 *   button 1 -> Fire   button 2 -> Thrust   button 3 -> Hyperspace
 *   button 4 -> insert Coin + P1 Start (press to begin a game)
 */
extern unsigned char currentButtonState;   /* P1 buttons in bits 0-3 (btn N = bit N-1) */
extern signed char   currentJoy1X;         /* -127..127                                */
extern signed char   currentJoy1Y;         /* -127..127, + = up                        */

int getport(int port)
{
    int b = currentButtonState;
    int jx = currentJoy1X, jy = currentJoy1Y;
    const int DZ = 40;                       /* analog dead-zone */
    int r = 0;
    if (port == 0) {
        if (b & 0x01) r |= 0x10;             /* button 1 -> Fire       */
        if (b & 0x04) r |= 0x08;             /* button 3 -> Hyperspace */
    } else {                                 /* port 1 */
        if (jx < -DZ)               r |= 0x80;        /* stick left  -> Rotate Left  */
        if (jx >  DZ)               r |= 0x40;        /* stick right -> Rotate Right */
        if (jy >  DZ || (b & 0x02)) r |= 0x20;        /* stick up / button 2 -> Thrust */
        if (b & 0x08)               r |= 0x08 | 0x01; /* button 4 -> P1 Start + Coin  */
    }
    return r;
}

/* ---- ROM loader: build the 6502 64 KB memory image and copy the embedded
 * Asteroids ROMs to their load addresses (from gameroms.h ROM_START(asteroid)).
 * Must run BEFORE init_asteroid(): init6502Z() points the CPU's m6502Base at
 * GI[CPU0], and init_asteroid writes GI[CPU0] directly. GI[CPU0] is a static
 * 64 KB buffer (zeroed as .bss) rather than malloc'd, to keep it off the arena.
 * The 034602 DVG PROM is intentionally NOT loaded: it is not in the AAE ROM
 * table (AAE emulates the vector generator in software). ---- */
static unsigned char gi0_mem[0x10000];   /* 6502 address space, zero-init */

void aae_load_asteroid_roms(void)
{
    GI[CPU0] = gi0_mem;
    memcpy(GI[CPU0] + 0x5000, rom_np3, 2048);  /* 035127.02 vector ROM   */
    memcpy(GI[CPU0] + 0x6800, rom_ef2, 2048);  /* 035145.02 program      */
    memcpy(GI[CPU0] + 0x7000, rom_h2,  2048);  /* 035144.02 program      */
    memcpy(GI[CPU0] + 0x7800, rom_j2,  2048);  /* 035143.02 program      */
    memcpy(GI[CPU0] + 0xf800, rom_j2,  2048);  /* ROM_RELOAD -> reset/NMI vectors */
}
