/* host_vec.c — native shim so gmain.c runs on the desktop (same idea as the
 * TNZS/DK harnesses): capture v_directDraw32 segments, count frames in
 * v_WaitRecal, and dump one frame's geometry to stderr for PNG rendering:
 *     DUMPFRAME=300 FRAMES=400 ./build/host_sb 2> frame.txt
 * AUTOCOIN=<frame> holds coin+start briefly so the harness reaches gameplay.
 */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

#define MAXSEG 40000
static struct { int x0, y0, x1, y1, z; } segs[MAXSEG];
static int nseg = 0, frame = 0, dumpframe = -2, maxframes = 600, autocoin = -2;

void v_directDraw32(int32_t x0, int32_t y0, int32_t x1, int32_t y1, uint8_t b)
{
    if (b > 0 && nseg < MAXSEG) {
        segs[nseg].x0 = x0; segs[nseg].y0 = y0;
        segs[nseg].x1 = x1; segs[nseg].y1 = y1; segs[nseg].z = b;
        nseg++;
    }
}

int8_t currentJoy1X = 0, currentJoy1Y = 0;
void vectrexinit(int x) { (void)x; }
void v_setRefresh(int hz) { (void)hz; }

/* AUTOPLAY=1: wander left/right, hop and shoot — enough motion to surface
 * walk/jump/throw poses and snowed enemies for the frame harvest */
void v_readJoystick1Analog(void)
{
    if (!getenv("AUTOPLAY")) return;
    /* long direction holds so a full snowball actually gets PUSHED (that is
     * what clears floors), with a hop mixed in to reach ledges */
    int ph = (frame / 300) % 2;
    currentJoy1X = ph ? -100 : 100;
    currentJoy1Y = 0;
}

void v_init(void)
{
    const char *e;
    if ((e = getenv("DUMPFRAME"))) dumpframe = atoi(e);
    if ((e = getenv("FRAMES")))    maxframes = atoi(e);
    if ((e = getenv("AUTOCOIN")))  autocoin  = atoi(e);
}

uint8_t v_readButtons(void)
{
    uint8_t b = 0;
    if (autocoin >= 0) {
        if (frame >= autocoin && frame < autocoin + 4)        b |= 0x04; /* coin  */
        if (frame >= autocoin + 30 && frame < autocoin + 34)  b |= 0x08; /* start */
    }
    if (getenv("AUTOPLAY") && autocoin >= 0 && frame > autocoin + 100) {
        if (frame % 12 < 5)  b |= 0x01;   /* near-continuous snow shots */
        if (frame % 110 < 5) b |= 0x02;   /* hop */
    }
    return b;
}

void v_WaitRecal(void)
{
    { extern void sb_sprdump_hook(int); sb_sprdump_hook(frame); }
    /* SPRFARM=<dir> SPREVERY=<n>: save the sprite RAM every n frames — the
     * frame-catalogue harvest (dumps feed tools/autotrace.py --catalog) */
    {
        static const char *farm; static int every = -1;
        if (every < 0) {
            farm = getenv("SPRFARM");
            const char *e = getenv("SPREVERY");
            every = farm ? (e ? atoi(e) : 30) : 0;
        }
        extern int sb_capture_request;
        if (every > 0 && (frame % every == 0 || sb_capture_request)) {
            sb_capture_request = 0;
            extern unsigned char sb_spriteram[0x1000];
            char path[512];
            snprintf(path, sizeof path, "%s/sprites_%05d.bin", farm, frame);
            FILE *f = fopen(path, "wb");
            if (f) { fwrite(sb_spriteram, 1, 0x1000, f); fclose(f); }
            /* RAMFARM=<dir>: work RAM alongside, for state archaeology */
            const char *rf = getenv("RAMFARM");
            if (rf) {
                extern unsigned char sb_ram[0x4000];
                snprintf(path, sizeof path, "%s/ram_%05d.bin", rf, frame);
                f = fopen(path, "wb");
                if (f) { fwrite(sb_ram, 1, 0x4000, f); fclose(f); }
            }
        }
    }
    if (frame == dumpframe) {
        for (int i = 0; i < nseg; i++)
            fprintf(stderr, "%d %d %d %d %d\n",
                    segs[i].x0, segs[i].y0, segs[i].x1, segs[i].y1, segs[i].z);
    }
    if (frame % 60 == 0)
        printf("frame %d: %d segs\n", frame, nseg);
    if (frame++ >= maxframes) {
        { extern void sb_unmatched_report(void); sb_unmatched_report(); }
        exit(0);
    }
    nseg = 0;
}

/* SPRDUMP=<frame>: print raw pandora entries that frame (debug)
 * SPRSAVE=<file> with SPRDUMP: also write the raw 4KB sprite RAM there */
void sb_sprdump_hook(int frame)
{
    static int want = -3;
    if (want == -3) { const char *e = getenv("SPRDUMP"); want = e ? atoi(e) : -2; }
    if (frame != want) return;
    { const char *sv = getenv("SPRSAVE");
      if (sv) { extern unsigned char sb_spriteram[0x1000];
                FILE *f = fopen(sv, "wb");
                if (f) { fwrite(sb_spriteram, 1, 0x1000, f); fclose(f); } } }
    extern unsigned char sb_spriteram[0x1000];
    for (int o = 0; o < 0x1000; o += 8) {
        int b3 = sb_spriteram[o+3], b6 = sb_spriteram[o+6], b7 = sb_spriteram[o+7];
        int tile = ((b7 & 0x3f) << 8) | b6;
        if (tile) fprintf(stderr, "entry %03x: tile %04x pal %x b3=%02x dx=%02x dy=%02x\n",
                          o/8, tile, b3>>4, b3, sb_spriteram[o+4], sb_spriteram[o+5]);
    }
}
