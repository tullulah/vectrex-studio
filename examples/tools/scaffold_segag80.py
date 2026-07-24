import os, sys, zipfile, io
REPO="/Users/daniel/projects/vectrex-pseudo-python"
EX=f"{REPO}/examples"
TAC=f"{EX}/aae_tacscan"
ROMS="/Users/daniel/projects/vectrex-arcade-private/arcade/roms"

def romlist(g):
    # ROM NUMBER tokens in load order (zips name files inconsistently: "1586.rom"
    # vs "1586.prom-u1" — match by the token before the first ".").
    if g=='startrek': return ['1873']+[str(1847+i) for i in range(1,24)]
    if g=='spacfury': return ['969c']+[f'{959+i}c' for i in range(1,10)]
    if g=='zektor':   return ['1611']+[str(1585+i) for i in range(1,22)]
    if g=='elim2':    return ['969']+[str(1332+i) for i in range(1,14)]

GAMES={
 'startrek':{'dir':'aae_startrek','enum':'STARTREK','desc':'Star Trek','rotate':0},
 'spacfury':{'dir':'aae_spacefury','enum':'SPACFURY','desc':'Space Fury','rotate':0},
 'zektor':  {'dir':'aae_zektor','enum':'ZEKTOR','desc':'Zektor','rotate':0},
 'elim2':   {'dir':'aae_eliminator','enum':'ELIM2','desc':'Eliminator','rotate':0},
}

def emit_arr(fh,name,data):
    fh.write(f"static const unsigned char {name}[{len(data)}] = {{\n")
    for i in range(0,len(data),16):
        fh.write("  "+",".join(str(b) for b in data[i:i+16])+",\n")
    fh.write("};\n\n")

def gen_roms(g, dst):
    zf=zipfile.ZipFile(f"{ROMS}/{g}.zip")
    # index zip entries by their token (basename before first ".")
    tok={os.path.basename(n).split(".")[0]: n for n in zf.namelist()}
    prog=b""
    for t in romlist(g):
        if t not in tok: raise SystemExit(f"MISSING rom token {t} in {g}.zip; have {sorted(tok)[:8]}...")
        prog+=zf.read(tok[t])
    # xyt PROM (region 1)
    xytname=next((n for n in tok.values() if 'xyt' in n.lower()), None)
    xyt=zf.read(xytname) if xytname else open(f"{TAC}/roms/s-c.xyt-u39","rb").read()
    hdr=f"{dst}/src/{GAMES[g]['dir'].replace('aae_','')}_roms.h"
    up=GAMES[g]['dir'].replace('aae_','').upper()
    with open(hdr,"w") as fh:
        fh.write(f"/* {GAMES[g]['desc']} ROMs — auto-generated from {g}.zip (region 0 concat + xyt). */\n")
        fh.write(f"#ifndef {up}_ROMS_H\n#define {up}_ROMS_H\n\n")
        emit_arr(fh,f"{up.lower()}_prog",prog)
        emit_arr(fh,f"{up.lower()}_xyt",xyt)
        fh.write("#endif\n")
    return len(prog),len(xyt),up.lower()

def gen_machine(g,dst,proglen,short):
    e=GAMES[g]['enum']; desc=GAMES[g]['desc']
    s=f'''/* aae_machine.c — {desc} (Sega G80, Z80). Cloned from the Tac/Scan port; only
 * gamenum, the driver row, the ROM loader and getport differ. SegaG80.c selects
 * this game's port handlers / security / speech by gamenum={e}. */
#include <stdint.h>
#include <string.h>
#include "globals.h"
#include "cpu_control.h"
#include "{short}_roms.h"

extern int  init_segag80(void);
extern void run_segag80(void);
extern void end_segag80(void);

unsigned char   *GI[5];
CONTEXTM6502    *c6502[MAX_ACPU];
CONTEXTMZ80      cMZ80[MAX_ACPU];
int              gamenum = {e};
int              WATCHDOG, total_length, testsw, paused;
colors           vec_colors[1024];
aae_settings     config;

struct AAEDriver driver[{e} + 1] =
{{
    [{e}] =
    {{ "{g}", "{desc}", 0,
      &init_segag80, 0, &run_segag80, &end_segag80,
      0, 0, 0, 0,
      {{CPU_MZ80, CPU_NONE, CPU_NONE, CPU_NONE}},
      {{3000000, 0, 0, 0}},
      {{1, 0, 0, 0}},
      {{1, 0, 0, 0}},
      {{INT_TYPE_INT, 0, 0, 0}},
      {{0, 0, 0, 0}},
      40, VEC_COLOR, 0,
      {{0, 1024, 0, 1024}}
    }}
}};

/* Input — first-pass Sega G80 mapping (tune per game once it draws). Player
 * inputs are in the HIGH nibble of $F8-$FB (sega_fix_dips masks the low nibble);
 * $FC button-mode is returned raw (low nibble). btn3=Coin, btn4=Start,
 * btn1=Fire, btn2=aux, stick X = steer/spinner. */
extern unsigned char currentButtonState;
extern signed char   currentJoy1X, currentJoy1Y;

int getport(int port)
{{
    int b = currentButtonState, jx = currentJoy1X;
    switch (port) {{
    case 0: return (b & 0x04) ? (0xe0 & ~0x20) : 0xe0;      /* $F8 Coin1 (btn3), active low */
    case 4: {{ int v=0;                                       /* $FC buttons, active high */
        if (b & 0x08) v |= 0x01;   /* btn4 -> Start1 */
        if (b & 0x01) v |= 0x04;   /* btn1 -> Fire   */
        if (b & 0x02) v |= 0x08;   /* btn2 -> aux    */
        return v; }}
    case 6:                                                  /* $FC spinner delta */
        if (jx >  20) return (jx >  80) ?  5 :  3;
        if (jx < -20) return (jx < -80) ? -5 : -3;
        return 0;
    case 1: case 2: case 3: return 0xf0;
    default: return 0xff;
    }}
}}

static unsigned char gi0_mem[0x10000];
static unsigned char gi1_mem[0x400];

void aae_load_roms(void)
{{
    GI[CPU0] = gi0_mem;
    GI[1]    = gi1_mem;
    memcpy(GI[CPU0] + 0x0000, {short}_prog, {proglen});
    memcpy(GI[1]    + 0x0000, {short}_xyt, sizeof({short}_xyt));
}}
'''
    open(f"{dst}/src/aae_machine.c","w").write(s)

def gen_main(dst):
    s='''/* Sega G80 (Z80) AAE game on RP2350 — entry point. See aae_tacscan/src/main.c. */
extern int  init_segag80(void);
extern void run_segag80(void);
extern void run_cpus_to_cycles(void);
extern void init_cpu_config(void);
extern void aae_load_roms(void);
extern void v_init(void);
extern void v_WaitRecal(void);
extern unsigned char v_readButtons(void);
extern void v_readJoystick1Analog(void);
int main(void){
    v_init();
    aae_load_roms();
    init_cpu_config();
    init_segag80();
    for(;;){
        v_WaitRecal();
        v_readButtons();
        v_readJoystick1Analog();
        run_cpus_to_cycles();
        run_segag80();
    }
    return 0;
}
'''
    open(f"{dst}/src/main.c","w").write(s)

def gen_makefile(g,dst):
    d=GAMES[g]['dir']; rp=d+'_rp2350'
    tac=open(f"{TAC}/Makefile").read()
    # replace target name + artifact + elf/bin names
    m=tac.replace('aae_tacscan_rp2350',rp).replace('aae_tacscan.elf',f'{d}.elf').replace('aae_tacscan_sd.bin',f'{d}_sd.bin').replace('aae_tacscan',d)
    m=m.replace('.PHONY: '+rp+' sim clean', '.PHONY: '+rp+' sim clean')
    open(f"{dst}/Makefile","w").write(m)

def gen_cvproj(g,dst):
    d=GAMES[g]['dir']
    c=open(f"{TAC}/aae_tacscan.cvproj").read().replace('aae_tacscan',d).replace('Tac/Scan',GAMES[g]['desc'])
    open(f"{dst}/{d}.cvproj","w").write(c)

def scaffold(g):
    d=GAMES[g]['dir']; dst=f"{EX}/{d}"
    os.makedirs(f"{dst}/src",exist_ok=True); os.makedirs(f"{dst}/include",exist_ok=True)
    for f in os.listdir(f"{TAC}/include"):
        open(f"{dst}/include/{f}","wb").write(open(f"{TAC}/include/{f}","rb").read())
    for f in ['libc_stub.c','aae_stubs.c','samples.c','aae_compat.h']:
        open(f"{dst}/src/{f}","wb").write(open(f"{TAC}/src/{f}","rb").read())
    open(f"{dst}/.gitignore","w").write(open(f"{TAC}/.gitignore").read())
    proglen,xytlen,short=gen_roms(g,dst)
    gen_machine(g,dst,proglen,short)
    gen_main(dst)
    gen_makefile(g,dst)
    gen_cvproj(g,dst)
    print(f"  {d}: prog={proglen} xyt={xytlen} enum={GAMES[g]['enum']}")

for g in GAMES:
    print(f"scaffolding {g}...")
    scaffold(g)
print("done")
