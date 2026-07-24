/* aae_machine.c — Space Fury (Sega G80, Z80). Cloned from the Tac/Scan port; only
 * gamenum, the driver row, the ROM loader and getport differ. SegaG80.c selects
 * this game's port handlers / security / speech by gamenum=SPACFURY. */
#include <stdint.h>
#include <string.h>
#include "globals.h"
#include "cpu_control.h"
#include "spacefury_roms.h"

extern int  init_segag80(void);
extern void run_segag80(void);
extern void end_segag80(void);

unsigned char   *GI[5];
CONTEXTM6502    *c6502[MAX_ACPU];
CONTEXTMZ80      cMZ80[MAX_ACPU];
int              gamenum = SPACFURY;
int              WATCHDOG, total_length, testsw, paused;
colors           vec_colors[1024];
aae_settings     config;

struct AAEDriver driver[SPACFURY + 1] =
{
    [SPACFURY] =
    { "spacfury", "Space Fury", 0,
      &init_segag80, 0, &run_segag80, &end_segag80,
      0, 0, 0, 0,
      {CPU_MZ80, CPU_NONE, CPU_NONE, CPU_NONE},
      {3000000, 0, 0, 0},
      {1, 0, 0, 0},
      {1, 0, 0, 0},
      {INT_TYPE_INT, 0, 0, 0},
      {0, 0, 0, 0},
      40, VEC_COLOR, 0,
      {0, 1024, 0, 1024}
    }
};

/* Input — first-pass Sega G80 mapping (tune per game once it draws). Player
 * inputs are in the HIGH nibble of $F8-$FB (sega_fix_dips masks the low nibble);
 * $FC button-mode is returned raw (low nibble). btn3=Coin, btn4=Start,
 * btn1=Fire, btn2=aux, stick X = steer/spinner. */
extern unsigned char currentButtonState;
extern signed char   currentJoy1X, currentJoy1Y;

/* Space Fury reads input via sega_ports_r → getport(0..4) (NOT sega_ports_r2/r3).
 * Exact bits from spacfury_keys — all ACTIVE-LOW in the HIGH nibble (sega_fix_dips
 * masks the low nibble). Standard VPy mapping: btn3=Coin, btn4=Start, btn1=Fire,
 * btn2=Thrust, stick=rotate. */
int getport(int port)
{
    int b = currentButtonState, jx = currentJoy1X;
    const int DZ = 25;
    switch (port) {
    case 0:  /* $F8 coins (active low, default 0xe0): Coin1=0x80 */
        return (b & 0x04) ? (0xe0 & ~0x80) : 0xe0;   /* btn3 -> Coin 1 */
    case 1:  /* $F9 start (active low, default 0xf0): Start1=0x20 */
        return (b & 0x08) ? (0xf0 & ~0x20) : 0xf0;   /* btn4 -> Start 1 */
    case 2: { /* $FA rotate (active low): Left=0x20 Right=0x10 */
        int v = 0xf0;
        if (jx < -DZ) v &= ~0x20;   /* stick left  -> Rotate Left  */
        if (jx >  DZ) v &= ~0x10;   /* stick right -> Rotate Right */
        return v; }
    case 3: { /* $FB buttons (active low): Fire=0x10 Thrust=0x20 */
        int v = 0xf0;
        if (b & 0x01) v &= ~0x10;   /* btn1 -> Fire   */
        if (b & 0x02) v &= ~0x20;   /* btn2 -> Thrust */
        return v; }
    default: return (port >= 1 && port <= 3) ? 0xf0 : 0xff;
    }
}

static unsigned char gi0_mem[0x10000];
static unsigned char gi1_mem[0x400];

void aae_load_roms(void)
{
    GI[CPU0] = gi0_mem;
    GI[1]    = gi1_mem;
    memcpy(GI[CPU0] + 0x0000, spacefury_prog, 20480);
    memcpy(GI[1]    + 0x0000, spacefury_xyt, sizeof(spacefury_xyt));
}
