/* aae_machine.c — Eliminator (Sega G80, Z80). Cloned from the Tac/Scan port; only
 * gamenum, the driver row, the ROM loader and getport differ. SegaG80.c selects
 * this game's port handlers / security / speech by gamenum=ELIM2. */
#include <stdint.h>
#include <string.h>
#include "globals.h"
#include "cpu_control.h"
#include "eliminator_roms.h"

extern int  init_segag80(void);
extern void run_segag80(void);
extern void end_segag80(void);

unsigned char   *GI[5];
CONTEXTM6502    *c6502[MAX_ACPU];
CONTEXTMZ80      cMZ80[MAX_ACPU];
int              gamenum = ELIM2;
int              WATCHDOG, total_length, testsw, paused;
colors           vec_colors[1024];
aae_settings     config;

struct AAEDriver driver[ELIM2 + 1] =
{
    [ELIM2] =
    { "elim2", "Eliminator", 0,
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

int getport(int port)
{
    int b = currentButtonState, jx = currentJoy1X;
    switch (port) {
    case 0: return (b & 0x04) ? (0xe0 & ~0x20) : 0xe0;      /* $F8 Coin1 (btn3), active low */
    case 4: { int v=0;                                       /* $FC buttons, active high */
        if (b & 0x08) v |= 0x01;   /* btn4 -> Start1 */
        if (b & 0x01) v |= 0x04;   /* btn1 -> Fire   */
        if (b & 0x02) v |= 0x08;   /* btn2 -> aux    */
        return v; }
    case 6:                                                  /* $FC spinner delta */
        if (jx >  20) return (jx >  80) ?  5 :  3;
        if (jx < -20) return (jx < -80) ? -5 : -3;
        return 0;
    case 1: case 2: case 3: return 0xf0;
    default: return 0xff;
    }
}

static unsigned char gi0_mem[0x10000];
static unsigned char gi1_mem[0x400];

void aae_load_roms(void)
{
    GI[CPU0] = gi0_mem;
    GI[1]    = gi1_mem;
    memcpy(GI[CPU0] + 0x0000, eliminator_prog, 28672);
    memcpy(GI[1]    + 0x0000, eliminator_xyt, sizeof(eliminator_xyt));
}
