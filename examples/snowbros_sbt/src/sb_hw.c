/* sb_hw.c — Snow Bros machine: 68000 (Musashi) + memory map + Pandora sprite RAM.
 *
 * Map (from the board):
 *   000000-03ffff  program ROM (sn6 even / sn5 odd bytes, big-endian)
 *   100000-103fff  work RAM
 *   200000         watchdog (writes ignored)
 *   300001         sound latch — Z80 not emulated yet; reads echo the last
 *                  command so the boot handshake passes
 *   400000         flipscreen (ignored)
 *   500000/2/4     DSW1 / DSW2 / SYSTEM, active-low; DSW1/DSW2 bit15 is
 *                  ACTIVE_HIGH and must read LOW or the game stops
 *   600000-6001ff  palette RAM (xBGR555, stored for the renderer)
 *   700000-701fff  Pandora sprite RAM, one byte in the low lane of each word
 *   800000/900000/a00000  IRQ 4/3/2 acknowledge
 *
 * IRQs: scanline timer fires IRQ2 at line 240, IRQ3 at 128, IRQ4 at 32.
 * We autovector and auto-clear at service (the ack writes become no-ops).
 */
#include <stdint.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include "musashi/m68k.h"
#include "sb_rom.h"

void sb_audio_cmd(unsigned char cmd);   /* sb_audio.c */

/* LA RAM DE SPRITES, EN LA SRAM INTERNA. Son 4 KB que se recorren ENTEROS cada
 * frame (512 entradas de 8 bytes en sb_render) y que ademas escribe el 68000 por
 * wr8, asi que los toca el frame por los dos lados. En la PSRAM eso va por la
 * cache XIP, que es de donde salio el 1,19x de Musashi.
 *
 * `.sram_rapida` es NOLOAD —no viaja en la imagen ni se pone a cero— y no hace
 * falta: sb_hw_init las memsetea explicitamente unas lineas mas abajo.
 *
 * SOLO EN EL CARTUCHO PROPIO. En el host la seccion no existe y el enlazador de
 * macOS ni siquiera acepta un nombre de seccion con esta forma; en la .um2 la
 * imagen ya esta entera en SRAM. */
#ifdef VPY_DUAL_CORE
#define SB_EN_SRAM __attribute__((section(".sram_rapida")))
#else
#define SB_EN_SRAM
#endif

unsigned char sb_ram[0x4000];
unsigned char sb_spriteram[0x1000] SB_EN_SRAM;
unsigned char sb_palette[0x200];

/* 0 until the 68000 first writes the Pandora sprite list. Before that the sprite
 * RAM is uninitialised power-on garbage (the arcade shows it as two random
 * sprites during the RAM/ROM self-test; on the vector console it came out as
 * bright random lines). sb_render skips drawing while this is 0. */
int sb_spr_live;

/* inputs, ACTIVE-LOW bit fields (1 = released). gmain.c clears bits. */
unsigned char sb_p1 = 0x7f;      /* up,down,left,right,b1,b2,b3 ; bit7 must stay 0 */
unsigned char sb_p2 = 0x7f;
unsigned char sb_system = 0xff;  /* start1,start2,coin1,coin2,-,tilt,coin3,- */

static unsigned char sb_dsw1 = 0xfe;  /* Europe, no flip, no service, demo snd, 1C_1C */
static unsigned char sb_dsw2 = 0xff;  /* normal, 100k, 3 lives, continues; bit6 = invuln dip */
static unsigned char soundcmd = 3;  /* Z80 ready/region code the boot demands */

int your_int_ack_handler_function(int level)
{
#ifdef SB_TRACE_IRQ
    { extern int printf(const char *, ...); printf("    irq%d taken\n", level); }
#endif
    m68k_set_virq(level, 0);
    return M68K_INT_ACK_AUTOVECTOR;
}

static unsigned int rd8(unsigned int a)
{
    a &= 0xffffff;
#ifdef SB_WATCH
    /* SB_TRACE_RD_LO/HI: when the reading instruction (PPC) is in that range,
     * log the address read — used to find where the collision bitmap lives. */
    { extern int sb_frame_counter;
      static unsigned tlo=0xffffffff, thi;
      if (tlo==0xffffffff){ const char*e=getenv("SB_TRACE_RD_LO"); tlo=e?strtoul(e,0,16):0;
                            const char*h=getenv("SB_TRACE_RD_HI"); thi=h?strtoul(h,0,16):0; }
      if (tlo && sb_frame_counter>=400){
        unsigned ppc=m68k_get_reg(NULL,M68K_REG_PPC);
        if (ppc>=tlo && ppc<=thi){
          enum{NR=48}; static struct{unsigned pc,ad,n;}r[NR]; static int nr;
          int seen=0; for(int i=0;i<nr;i++) if(r[i].pc==ppc&&r[i].ad==a){r[i].n++;seen=1;break;}
          if(!seen&&nr<NR){r[nr].pc=ppc;r[nr].ad=a;r[nr].n=1;nr++;
            printf("RD PC %06x -> %06x\n",ppc,a);}
        }
      }
    }
#endif
    if (a < 0x40000) return sb_prog[a];
    if (a >= 0x100000 && a <= 0x103fff) return sb_ram[a & 0x3fff];
    if (a == 0x300001) return 3;                           /* Z80 always "ready" */
    if (a >= 0x500000 && a <= 0x500005) {
        switch (a) {
        case 0x500000: return sb_p1 & 0x7f;   /* bit15 low! */
        case 0x500001: return sb_dsw1;
        case 0x500002: return sb_p2 & 0x7f;
        case 0x500003: return sb_dsw2;
        case 0x500004: return sb_system;
        case 0x500005: return 0xff;
        }
    }
    if (a >= 0x600000 && a <= 0x6001ff) return sb_palette[a & 0x1ff];
    if (a >= 0x700000 && a <= 0x701fff) return sb_spriteram[(a & 0x1fff) >> 1];
    return 0xff;
}

/* SB_WATCH_WR=<hex 68000 addr>: log the PPC (writing instruction) and the
 * top-of-stack return each time the game writes that byte — used to find the
 * routine that sets the player's Y (0x1012ca) = the gravity/landing/collision
 * code, the doorway to the level collision table. */
#ifdef SB_WATCH
static unsigned sb_watch_addr = 0xffffffff;
static void sb_watch_hit(unsigned a68)
{
    if (sb_watch_addr == 0xffffffff) {
        const char *e = getenv("SB_WATCH_WR");
        sb_watch_addr = e ? (unsigned)strtoul(e, 0, 16) : 0;
    }
    static unsigned lo, hi;
    if (!lo) { const char *e = getenv("SB_WATCH_HI");
               lo = sb_watch_addr; hi = e ? (unsigned)strtoul(e,0,16) : sb_watch_addr; }
    if (a68 < lo || a68 > hi) return;
    /* skip the boot RAM-clear and self-test: only track once gameplay runs */
    { extern int sb_frame_counter; if (sb_frame_counter < 400) return; }
    unsigned ppc = m68k_get_reg(NULL, M68K_REG_PPC);
    /* unique (addr,pc) pairs with a count */
    enum { NW = 64 };
    static struct { unsigned addr, pc, n; } w[NW];
    static int nw;
    for (int i = 0; i < nw; i++)
        if (w[i].addr == a68 && w[i].pc == ppc) { w[i].n++; return; }
    if (nw < NW) {
        w[nw].addr = a68; w[nw].pc = ppc; w[nw].n = 1; nw++;
        printf("WATCH addr %06x  PC %06x  A0=%06x A2=%06x A3=%06x D3=%04x D4=%04x\n",
               a68, ppc,
               m68k_get_reg(NULL,M68K_REG_A0), m68k_get_reg(NULL,M68K_REG_A2),
               m68k_get_reg(NULL,M68K_REG_A3),
               m68k_get_reg(NULL,M68K_REG_D3)&0xffff, m68k_get_reg(NULL,M68K_REG_D4)&0xffff);
    }
}
#endif

static void wr8(unsigned int a, unsigned int d)
{
    a &= 0xffffff;
    if (a >= 0x100000 && a <= 0x103fff) {
#if defined(SB_WATCH) || defined(SB_LEVELCAP)
        /* SB_FORCE_LEVEL=N: the game zeroes the level word inside a RAM-clear
         * loop at start-of-play (0x1ba4). Intercept just that byte write so play
         * begins on level N — every other write is real, the game logic is
         * untouched and it loads/draws level N's scenery. Lets compose_levels
         * capture each floor's static background without playing to it. */
        { static int fl=-2; if(fl==-2){const char*e=getenv("SB_FORCE_LEVEL"); fl=e?atoi(e):-1;}
          if (fl>=0 && a==0x101573 && m68k_get_reg(NULL,M68K_REG_PPC)==0x1ba4) d=fl&0xff; }
#endif
        sb_ram[a & 0x3fff] = d;
#ifdef SB_WATCH
        sb_watch_hit(a);
#endif
        return;
    }
    if (a == 0x300001) {
        /* SB_TRACE_SND=1: log every sound-latch command with its frame — the raw
         * material for mapping arcade command bytes to PSG music/SFX assets. */
        { static int t = -1; if (t < 0) t = getenv("SB_TRACE_SND") ? 1 : 0;
          if (t) { extern int sb_frame_counter;
                   printf("SND f%d cmd %02x\n", sb_frame_counter, d); } }
        /* The board's sound latch IS our sound trigger: the game's own code
         * decides what plays, and sb_audio.c maps the command to the PSG stream
         * ripped from the sound ROM. Only the WRITE matters — the read side
         * still answers the boot handshake below. */
        sb_audio_cmd((unsigned char)d);
        soundcmd = d; return; }
    if (a >= 0x600000 && a <= 0x6001ff) { sb_palette[a & 0x1ff] = d; return; }
    if (a >= 0x700000 && a <= 0x701fff) {
        if (a & 1) sb_spriteram[(a & 0x1fff) >> 1] = d;    /* low lane only */
        sb_spr_live = 1;   /* the game now drives the sprite list; safe to draw */
#ifdef SB_TRACE_SPR
        /* SB_TRACE_SPR: log unique PCs that write sprite Y (byte 5 of each 8-byte
         * Pandora entry) after gameplay starts — that routine builds the display
         * list and is where any vertical scroll offset is applied. */
        { extern int sb_frame_counter;
          int idx = (a & 0x1fff) >> 1;
          if ((idx & 7) == 5 && sb_frame_counter > 400) {
              unsigned ppc = m68k_get_reg(NULL, M68K_REG_PPC);
              enum { NP = 48 };
              static struct { unsigned pc, n; } p[NP]; static int np;
              int seen = 0;
              for (int i = 0; i < np; i++) if (p[i].pc == ppc) { p[i].n++; seen = 1; break; }
              if (!seen && np < NP) {
                  p[np].pc = ppc; p[np].n = 1; np++;
                  printf("SPRY PC %06x  d=%02x idx=%03x A0=%06x A1=%06x A2=%06x D0=%04x D1=%04x\n",
                         ppc, d & 0xff, idx,
                         m68k_get_reg(NULL,M68K_REG_A0), m68k_get_reg(NULL,M68K_REG_A1),
                         m68k_get_reg(NULL,M68K_REG_A2),
                         m68k_get_reg(NULL,M68K_REG_D0)&0xffff, m68k_get_reg(NULL,M68K_REG_D1)&0xffff);
              }
          }
        }
#endif
        return;
    }
    if (a >= 0x800000 && a <= 0x800001) {
#ifdef SB_TRACE_IRQ
        { extern int printf(const char *, ...); static int n; if (n < 12) { n++; printf("    irq4 ack (handler ran)\n"); } }
#endif
        m68k_set_virq(4, 0); return; }
    if (a >= 0x900000 && a <= 0x900001) {
#ifdef SB_TRACE_IRQ
        { extern int printf(const char *, ...); static int n; if (n < 6) { n++; printf("    irq3 ack\n"); } }
#endif
        m68k_set_virq(3, 0); return; }
    if (a >= 0xa00000 && a <= 0xa00001) {
#ifdef SB_TRACE_IRQ
        { extern int printf(const char *, ...); static int n; if (n < 6) { n++; printf("    irq2 ack\n"); } }
#endif
        m68k_set_virq(2, 0); return; }
    if (a == 0x200000 || a == 0x200001 || a == 0x400000 || a == 0x400001) return;
#ifdef SB_TRACE_MAP
    { extern int printf(const char *, ...); static int n; if (n < 20) { n++;
        printf("    UNMAPPED write %06x = %02x (pc %06x)\n", a, d,
               m68k_get_reg(NULL, M68K_REG_PC)); } }
#endif
}

/* ---- IDLE SKIP: no emular la espera ---------------------------------------
 *
 * MEDIDO (perfil del PC en el host, 20 ventanas de gameplay): entre el 39% y el
 * 73% del tiempo del 68000 —mediana 60%— se va en TRES bucles de cuatro bytes:
 *
 *     andi  #$7bff, SR     ; baja la mascara -> deja pasar la IRQ que toca
 *     tst.w (A0)           ; la bandera que pone el manejador
 *     beq   *-4            ; girar
 *
 * El 68000 no esta trabajando ahi: espera una interrupcion cuyo instante NOSOTROS
 * decidimos, porque sb_hw_frame() las dispara en las fronteras de sus slices. Asi
 * que emular ese giro es tiempo tirado, y es mas de la mitad del frame.
 *
 * POR QUE NO SE PARCHEA LA ROM CON `STOP`. Era el plan —`STOP #imm` ocupa
 * exactamente los mismos 4 bytes que `tst.w`+`beq`, y es la instruccion que el
 * 68000 tiene para esto— pero el inmediato de STOP es el SR entero, y el SR en
 * ese punto es ESTADO DE EJECUCION: los tres sitios dejan 0x2300, 0x2200 y
 * 0x2000, y el tercero no se deduce de la cadena. Un parche estatico tendria que
 * adivinar una mascara; si se pasa de alta el STOP no despierta nunca y si se
 * queda corta despierta con la interrupcion equivocada. Ademas obliga a una ROM
 * escribible y arriesga la suma de comprobacion del arranque.
 *
 * LO QUE SE HACE, que es exacto por construccion: cuando el bucle lee su bandera
 * y sale CERO, se corta el timeslice (m68k_end_timeslice). El bucle habria girado
 * hasta la interrupcion, y el slice termina justo donde esa interrupcion se
 * dispara — el mundo emulado ve exactamente lo mismo, sin los ciclos de en medio.
 * Es el mismo recurso que MAME llama idle skip.
 *
 * LOS SITIOS SE BUSCAN, NO SE ESCRIBEN. La firma de 8 bytes (`andi #imm,SR` +
 * `tst.w (An)` + `beq.s *-4`) se localiza recorriendo la ROM al arrancar: 9
 * ocurrencias en esta. Cablear 0x3c6/0x442/0x46a habria funcionado en esta ROM y
 * en ninguna otra region, y habria fallado en silencio.
 */
#ifndef SB_IDLE_SKIP
#define SB_IDLE_SKIP 1
#endif

#define SB_IDLE_MAX 16
static unsigned sb_idle_pc[SB_IDLE_MAX];   /* direccion del `tst.w`, ordenada */
static int      sb_idle_n;
static unsigned sb_idle_lo, sb_idle_hi;    /* el rango, para descartar de un golpe */
static unsigned sb_idle_armado;            /* el `tst.w` que se acaba de buscar */
unsigned        sb_idle_cortes;            /* cuantas veces se ha saltado (diagnostico) */

static void sb_idle_buscar(void)
{
    sb_idle_n = 0;
    for (unsigned a = 0; a + 8 <= 0x40000 && sb_idle_n < SB_IDLE_MAX; a += 2) {
        unsigned andi = (sb_prog[a] << 8) | sb_prog[a + 1];
        unsigned tst  = (sb_prog[a + 4] << 8) | sb_prog[a + 5];
        unsigned beq  = (sb_prog[a + 6] << 8) | sb_prog[a + 7];
        if (andi != 0x027c) continue;              /* andi #imm, SR            */
        if ((tst & 0xfff8) != 0x4a50) continue;    /* tst.w (An)               */
        if (beq != 0x67fc) continue;               /* beq.s *-4  (a si mismo)  */
        sb_idle_pc[sb_idle_n++] = a + 4;
    }
    sb_idle_lo = sb_idle_n ? sb_idle_pc[0] : 1;
    sb_idle_hi = sb_idle_n ? sb_idle_pc[sb_idle_n - 1] : 0;
}

unsigned int m68k_read_memory_8(unsigned int a)  { return rd8(a); }

unsigned int m68k_read_memory_16(unsigned int a)
{
    unsigned v = (rd8(a) << 8) | rd8(a + 1);
#if SB_IDLE_SKIP
    /* DOS PASOS, y hacen falta los dos. El primero ve pasar la BUSQUEDA DEL
     * OPCODE del `tst.w` (Musashi va con M68K_SEPARATE_READS apagado, asi que los
     * opcodes salen por aqui); el segundo es la lectura del DATO que viene justo
     * detras. Solo si ese dato es cero el bucle va a girar: si la bandera ya
     * estaba puesta, el bucle sale solo y aqui no se toca nada. Cortar en el
     * primer paso habria recortado tambien la iteracion que SI avanza. */
    /* EL FILTRO VA POR EL OPCODE, NO POR LA DIRECCION, y la diferencia se midio:
     * comprobando el rango de direcciones en CADA lectura de 16 bits, la escena sin
     * espera (vec=0) pasaba de 17,6 a 20,8 ms — un 18% de peaje en el sitio donde
     * el idle skip no ahorra nada. El valor ya esta en la mano, asi que se mira
     * primero: `tst.w (An)` es un unico `== 0x4a50` sobre el opcode enmascarado, y
     * solo entonces se paga la busqueda en la tabla. */
    if ((v & 0xfff8) == 0x4a50) {
        sb_idle_armado = 0;
        if (a >= sb_idle_lo && a <= sb_idle_hi)
            for (int i = 0; i < sb_idle_n; i++)
                if (sb_idle_pc[i] == a) { sb_idle_armado = a; break; }
    } else if (sb_idle_armado) {
        sb_idle_armado = 0;
        if (!v) { sb_idle_cortes++; m68k_end_timeslice(); }
    }
#endif
    return v;
}
unsigned int m68k_read_memory_32(unsigned int a)
{ return (m68k_read_memory_16(a) << 16) | m68k_read_memory_16(a + 2); }

void m68k_write_memory_8(unsigned int a, unsigned int d)  { wr8(a, d & 0xff); }
void m68k_write_memory_16(unsigned int a, unsigned int d)
{ wr8(a, (d >> 8) & 0xff); wr8(a + 1, d & 0xff); }
void m68k_write_memory_32(unsigned int a, unsigned int d)
{ m68k_write_memory_16(a, d >> 16); m68k_write_memory_16(a + 2, d & 0xffff); }

/* disassembler hooks some Musashi builds want */
unsigned int m68k_read_disassembler_8(unsigned int a)  { return rd8(a); }
unsigned int m68k_read_disassembler_16(unsigned int a) { return m68k_read_memory_16(a); }
unsigned int m68k_read_disassembler_32(unsigned int a) { return m68k_read_memory_32(a); }

#ifndef SB_CHEATS_DEFAULT
#define SB_CHEATS_DEFAULT 0
#endif

/* Machine timing, DERIVED from the board rather than written down. Every term is
 * checked against MAME's driver (src/mame/kaneko/snowbros.cpp, snowbros_base):
 *
 *     M68000(config, m_maincpu, XTAL(16'000'000)/2);  // 8 Mhz - confirmed
 *     m_screen->set_refresh_hz(57.5);                 // ~57.5 - confirmed
 *     m_screen->set_size(32*8, 262);
 *     if (scanline == 240) irq2; == 128 irq3; == 32 irq4;
 *
 * THE REFRESH WAS 60 AND IT IS 57.5. The old line said "8MHz, 60Hz, 262 lines ->
 * ~509 cycles/line": the clock was right, the refresh was not, and the 68000 got
 * 133.358 cycles per machine frame instead of 139.130 — 4,3% short. It only shows
 * if the game's frame work does not fit in the budget, so it is not what makes the
 * port look slow (that is one machine frame per DRAWN frame, and we draw at 30-35
 * instead of 57,5), but it is 4,3% of emulation the board does and we did not.
 *
 * Centesimas de Hz porque 57,5 no es entero y un #define que redondee a 57 o 58 se
 * come un 1% sin decirlo. */
#define SB_CPU_HZ      8000000u   /* XTAL(16'000'000)/2 */
#define SB_REFRESH_CHZ 5750u      /* 57,50 Hz */
#define SB_LINES       262u
#define CYC_FRAME      ((SB_CPU_HZ * 100u) / SB_REFRESH_CHZ)   /* 139.130 */
#define CYC_LINE       ((int)(CYC_FRAME / SB_LINES))           /* 531 */
/* ---- CATCH-UP: el mundo a 57,5 Hz aunque dibujemos a 47 -------------------
 *
 * EL PROBLEMA QUE CIERRA. gmain llamaba a sb_hw_frame() UNA vez por frame
 * dibujado, asi que el mundo avanzaba a la velocidad del refresco: a 47,8 fps el
 * juego corria al 83% de su velocidad real, y a 29,6 en la escena peor, al 51%.
 * No es el framerate lo que se ve mal — es que Snow Bros va lento.
 *
 * Ahora el tiempo de maquina lo marca el RELOJ, no el dibujo: se acumula el
 * tiempo transcurrido y se ejecutan los frames de maquina que se deban.
 *
 * EL TOPE NO ES PRUDENCIA, ES LO QUE EVITA LA BARRENA. Sin el, una escena que no
 * da abasto genera deuda; la deuda pide mas frames de maquina; esos frames
 * retrasan mas el dibujo; y la deuda crece sola hasta que el juego se para. Por
 * eso la deuda se RECORTA antes de pagarla: lo que no se puede pagar se tira, que
 * es exactamente lo que hace una recreativa real cuando se le acumula el trabajo.
 *
 * EL TOPE ES 2, Y SALE DE LA MEDIDA. En consola (RTT, 2026-09-17) la escena peor
 * dibuja a 29,6 fps; 2 frames de maquina por frame dibujado son 59,2 Hz, por
 * encima de los 57,5 que hacen falta. O sea que 2 basta EN TODAS las escenas
 * medidas, y un tope mayor solo serviria para meter 18,7 ms mas de emulacion
 * dentro de un mismo frame — un tiron visible a cambio de nada.
 */
#ifndef SB_CATCHUP
#define SB_CATCHUP 0          /* el host y el sim NO: ver la nota de abajo */
#endif
#ifndef SB_CATCHUP_MAX
#define SB_CATCHUP_MAX 2
#endif
/* Microsegundos de un frame de maquina, de las MISMAS constantes que CYC_LINE.
 * 100.000.000 / 5750 = 17.391 us = 57,50 Hz. */
#define SB_US_FRAME (100000000u / SB_REFRESH_CHZ)

unsigned sb_maq_frames;       /* frames de maquina ejecutados (diagnostico) */
void sb_hw_frame(void);       /* definida mas abajo */

void sb_hw_avanzar(void)
{
#if SB_CATCHUP
    static unsigned t_prev, deuda;
    unsigned ahora = *(volatile unsigned *)0x400B000Cu;   /* TIMELR, us */
    if (!t_prev) { t_prev = ahora; sb_hw_frame(); sb_maq_frames++; return; }
    deuda += ahora - t_prev;
    t_prev = ahora;
    if (deuda > SB_CATCHUP_MAX * SB_US_FRAME) deuda = SB_CATCHUP_MAX * SB_US_FRAME;
    while (deuda >= SB_US_FRAME) { deuda -= SB_US_FRAME; sb_hw_frame(); sb_maq_frames++; }
#else
    /* EL HOST Y EL SIM VAN A UN FRAME POR FRAME, A PROPOSITO. Atar el numero de
     * frames de maquina a un reloj de pared haria el host NO DETERMINISTA, y el
     * host es donde se comparan volcados byte a byte (asi se comprobo que el idle
     * skip no cambiaba el juego) y donde se cosechan los dumps de sprites. Dos
     * ejecuciones que no dan el mismo frame no sirven para eso. */
    sb_hw_frame();
    sb_maq_frames++;
#endif
}

void sb_hw_init(void)
{
    /* DSW2 bit6 = the board's own Invulnerability dip (active low).
     * make CHEATS=1, or SB_INVULN=1 at runtime on the host. */
    if (SB_CHEATS_DEFAULT || getenv("SB_INVULN"))
        sb_dsw2 &= ~0x40;
    memset(sb_ram, 0, sizeof sb_ram);
    memset(sb_spriteram, 0, sizeof sb_spriteram);
    memset(sb_palette, 0, sizeof sb_palette);
    sb_spr_live = 0;
    sb_idle_buscar();
    m68k_init();
    m68k_set_cpu_type(M68K_CPU_TYPE_68000);
    m68k_pulse_reset();
#ifdef SB_TRACE_SPR
    { const char *e = getenv("SB_DASM");
      if (e) { unsigned a = strtoul(e, 0, 16), end = a + 0x140;
               char buf[128];
               while (a < end) { int n = m68k_disassemble(buf, a, M68K_CPU_TYPE_68000);
                                 printf("%06x: %s\n", a, buf); a += n; } } }
#endif
}

static void slice(int cycles)
{
    static int hist_on = -1;
    static unsigned hist[0x8000];  /* PC/8 buckets over the 256KB ROM */
    static long samples = 0;
    if (hist_on < 0) hist_on = getenv("PCHIST") ? 1 : 0;
    if (!hist_on) { m68k_execute(cycles); return; }
    while (cycles > 0) {
        unsigned cortes = sb_idle_cortes;
        m68k_execute(64);
        cycles -= 64;
        /* El perfil trocea el slice en 64 ciclos, asi que un corte se "cura" en la
         * vuelta siguiente y el idle skip no se notaria. Con esto PCHIST mide lo
         * mismo que corre de verdad. */
        if (sb_idle_cortes != cortes) break;
        unsigned pc = m68k_get_reg(NULL, M68K_REG_PC);
        if (pc < 0x40000) hist[pc >> 3]++;
        if (++samples == 400000) {
            printf("  -- top PCs --\n");
            for (int pass = 0; pass < 10; pass++) {
                unsigned best = 0, bi = 0;
                for (unsigned i = 0; i < 0x8000; i++)
                    if (hist[i] > best) { best = hist[i]; bi = i; }
                if (!best) break;
                printf("    %06x  %u\n", bi << 3, best);
                hist[bi] = 0;
            }
            samples = 0;
        }
    }
}

void sb_hw_frame(void)
{
    /* SB_POKE=off:val[,off:val...] — force work-RAM bytes every frame */
    static int npokes = -1;
    static struct { int off, val; } pokes[32];
    if (npokes < 0) {
        npokes = 0;
        const char *e = getenv("SB_POKE");
        while (e && *e && npokes < 32) {
            unsigned o, v;
            if (sscanf(e, "%x:%x", &o, &v) == 2 && o < 0x4000) {
                pokes[npokes].off = o; pokes[npokes].val = v; npokes++;
            }
            e = strchr(e, ',');
            if (e) e++;
        }
    }
    static int trace = -1, fr = 0;
    if (fr > 280)
        for (int i = 0; i < npokes; i++) sb_ram[pokes[i].off] = pokes[i].val;
    if (trace < 0) trace = getenv("PCTRACE") ? 1 : 0;
    slice(32 * CYC_LINE);
    m68k_set_irq(4);
    slice((128 - 32) * CYC_LINE);
    m68k_set_irq(3);
    slice((240 - 128) * CYC_LINE);
    m68k_set_irq(2);
    slice((262 - 240) * CYC_LINE);
    ++fr;
    if (trace && fr >= 250 && fr < 256) {
        printf("  f%d pc=%06x sr=%04x  shadow27c=%02x%02x shadowc7c=%02x%02x\n",
               fr, m68k_get_reg(NULL, M68K_REG_PC), m68k_get_reg(NULL, M68K_REG_SR),
               sb_ram[0x27c], sb_ram[0x27d], sb_ram[0xc7c], sb_ram[0xc7d]);
    }
}
