/* Native host harness: link the SAME AAE sources + aae_machine against a fake
 * SDK to check the game logic (does the Z80 run, does it draw) off-emulator. */
#include <stdio.h>
#include <stdint.h>

/* --- fake SDK (what sdk_rp2350.c/sdk_host.c provide) --- */
unsigned char currentButtonState = 0;
signed char   currentJoy1X = 0, currentJoy1Y = 0;
long draw_calls = 0;
void v_init(void){}
void v_WaitRecal(void){}
unsigned char v_readButtons(void){ return 0; }
void v_readJoystick1Analog(void){}
void v_directDraw32(int y0,int x0,int y1,int x1,int z){ (void)y0;(void)x0;(void)y1;(void)x1;(void)z; draw_calls++; }
/* misc SDK bits SegaG80/vectrexInterface may want */
void v_setBrightness(int b){(void)b;}
void v_zeroBeam(void){}

/* cpuintrf memory-handler error reporting (gc-dropped on the cart, kept here) */
int errorlog = 0, have_error = 0;
int mrh_error(int a){ (void)a; return 0xff; }
int mwh_error(int a,int d){ (void)a; (void)d; return 0; }

/* AAE globals normally in aaemain.c (gc-dropped on the cart). Provide storage
 * big enough for whatever struct the AAE code overlays on _Machine. */
char Machine[8192];
unsigned char *RAM = 0, *ROM = 0;

/* --- AAE entry points --- */
extern int  init_segag80(void);
extern void run_segag80(void);
extern void run_cpus_to_cycles(void);
extern void init_cpu_config(void);
extern void aae_load_tacscan_roms(void);
extern int gamenum;
extern unsigned char *GI[5];

int main(void){
    aae_load_tacscan_roms();
    init_cpu_config();
    init_segag80();
    printf("gamenum=%d GI0=%p GI1=%p\n", gamenum, (void*)GI[0], (void*)GI[1]);
    for (int f=0; f<120; f++){
        long before = draw_calls;
        run_cpus_to_cycles();
        run_segag80();
        if (f<5 || f==30 || f==60 || f==119)
            printf("frame %3d: draw_calls +%ld (total %ld)\n", f, draw_calls-before, draw_calls);
    }
    printf("TOTAL draw_calls over 120 frames: %ld\n", draw_calls);
    return 0;
}

/* pokey sound (dead code on Tac/Scan) */
void Update_pokey_sound(void){}
char chip[8192];
