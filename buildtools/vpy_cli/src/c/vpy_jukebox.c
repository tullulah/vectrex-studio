/* vpy_jukebox.c — the VPy builtins MUSIC_TRACK, SFX_PCM, LISTENER… on the uvm2 target.
 *
 * Recorded music and effects out of the UVMC2's audio jack, off the SD card: a track is
 * <dir>/<ID>.PCM (4-bit IMA ADPCM, "RJMU" header), read into the cartridge's PSRAM a slice a
 * frame while it already plays, into one of two slots so the next one loads while this one
 * plays on and the two cross-fade. The effects are one pack, <dir>/SFX.PCM ("RJSX": groups
 * of clips, one of a group at random), loaded whole into PSRAM and mixed over the music on
 * five voices (0 an engine or hum, 1 yours, 2 the world, 3 voices -- they duck the music --,
 * 4 things passing), each placed in the world against a listener.
 *
 * Shipped inside vpy_cli and compiled into the image when a program uses these builtins.
 * vpy_cli injects vpyj_frame() at the start of every frame. Where there is no jack or no
 * PSRAM (or the card lacks the files) every call is a no-op: SFX_PCM returns 0 and
 * JUKEBOX_LIVE() 0, and the program keeps its PSG sounds.
 *
 * From the Return of the Jedi C game's jukebox.c (its decoder and idea: kuroishi's
 * stream.c).
 */
#include <stdint.h>
#include <stddef.h>

int  jukebox_sfx(int group, int voice, int gain, int loop);

/* A builtin's arguments past the fourth (vpy3d_bridge.c defines it when the program has 3D) */
__attribute__((weak)) int32_t vpyx_args[12];

/* vpyx_call: every builtin's call from VPy code goes through here, its C function in r12
   and its arguments in r0-r3 (and vpyx_args[]) -- SP aligned to 8 bytes as the AAPCS asks,
   whatever the expression being evaluated had pushed, then put back. (Weak: both
   vpy3d_bridge.c and vpy_jukebox.c carry it, either may be in the image alone.) */
__attribute__((naked, weak)) void vpyx_call(void)
{
    __asm volatile(
        "push {r4, lr}\n"
        "mov r4, sp\n"
        "bic lr, r4, #7\n"
        "mov sp, lr\n"
        "blx r12\n"
        "mov sp, r4\n"
        "pop {r4, pc}\n");
}

static char s_dir[17] = "";        /* the card folder (JUKEBOX_DIR) */

void jukebox_play(const char *id);
int  jukebox_live(void);
const char *jukebox_report(void);
int  jukebox_boot_progress(void);
void jukebox_update(int mode);
void jukebox_listener(int32_t x, int32_t y, int32_t z, int32_t fx, int32_t fz);
int  jukebox_sfx_at(int group, int voice, int gain, int loop, int32_t x, int32_t y, int32_t z);
void jukebox_voice_at(int voice, int32_t x, int32_t y, int32_t z);
void jukebox_sfx_stop(int voice);
int  jukebox_sfx_busy(int voice);
enum { JB_SCREEN = 0, JB_PLAY = 1, JB_BOOT = 2 };

#define OUT_RATE 32000u          /* the jack's (UVM2_JACK_RATE) */
#define HDR      32u
#define HEAD     (24u * 1024u)   /* ~2 s of a track in before it may start */
#define FADE     12800u          /* samples of cross-fade: 0.4 s */

static const int16_t STEP[89] = {
    7,8,9,10,11,12,13,14,16,17,19,21,23,25,28,31,34,37,41,45,50,55,60,66,73,80,
    88,97,107,118,130,143,157,173,190,209,230,253,279,307,337,371,408,449,494,
    544,598,658,724,796,876,963,1060,1166,1282,1411,1552,1707,1878,2066,2272,
    2499,2749,3024,3327,3660,4026,4428,4871,5358,5894,6484,7132,7845,8630,9493,
    10442,11487,12635,13899,15289,16818,18500,20350,22385,24623,27086,29794,32767 };
static const int8_t DELTA[8] = { -1,-1,-1,-1,2,4,6,8 };

enum { SL_IDLE, SL_LOAD, SL_DONE, SL_DEAD };
typedef struct {
    char     id[16];
    int      state;
    uint32_t len;                /* bytes of the file in the slot so far */
    uint32_t cap;
    /* the decoder */
    uint32_t samples, pos, step, frac, loop;
    int32_t  pred, loop_pred;
    int      idx, loop_idx, head;
    int      partial;            /* its load was dropped half way: plays out, never reused */
    int16_t  held;
} slot_t;
static slot_t s_slot[2];
static int s_cur = -1, s_old = -1;   /* playing, fading out */
static uint32_t s_fade;              /* samples into the cross-fade */
static char s_want[16];
/* The jack's rate. (Resampling to a MEASURED rate was tried and was wrong: what it measured
   was a ring lapping itself, see uvm2_jack.c's AHEAD. s_seen_hz is still shown on the title.) */
static uint32_t s_out_hz = OUT_RATE;
static uint32_t s_seen_hz;
static uint32_t s_src_hz[2];

static int same(const char *a, const char *b)
{
    while (*a && *a == *b) a++, b++;
    return *a == *b;
}
static void copy_id(char *d, const char *s) { int k = 0; while (s[k] && k < 15) d[k] = s[k], k++; d[k] = 0; }

/* ── WHERE A SLOT'S BYTES ARE: the PSRAM on the cartridge, the host's buffer elsewhere ── */
#if defined(UVM2_PICO_RUNTIME)
/* THROUGH THE UNCACHED ALIAS: writing through the cached window corrupts what is written
 * (uvm2_draw.c measured it). Slot A below the romset (4 MB in), slot B above it. */
#ifndef JB_PSRAM
#define JB_PSRAM ((uintptr_t)0x15000000u)  /* (a desktop test of this loader puts it in its own memory) */
#endif
static const uint32_t BASE[2] = { 0x000000u, 0x500000u };   /* from JB_PSRAM */
static uint8_t pu8(int s, uint32_t o) { return *(const volatile uint8_t *)(JB_PSRAM + BASE[s] + o); }
#else
static const unsigned char *s_mem[2];
static uint8_t pu8(int s, uint32_t o) { return s_mem[s] && o < s_slot[s].len ? s_mem[s][o] : 0; }
#endif
static uint32_t pu32(int s, uint32_t o)
{
    return (uint32_t)pu8(s, o) | (uint32_t)pu8(s, o + 1) << 8 | (uint32_t)pu8(s, o + 2) << 16 | (uint32_t)pu8(s, o + 3) << 24;
}

/* the header read, the decoder set to the start */
static int slot_head(int s)
{
    slot_t *t = &s_slot[s];
    if (t->head) return 1;
    if (t->len < HDR) return 0;
    if (pu8(s, 0) != 'R' || pu8(s, 1) != 'J' || pu8(s, 2) != 'M' || pu8(s, 3) != 'U' || pu8(s, 19) != 1) {
        t->state = SL_DEAD;
        return 0;
    }
    t->samples = pu32(s, 4);
    uint32_t hz = pu32(s, 8);
    if (!hz || hz > 96000u) hz = 22050u;
    s_src_hz[s] = hz;
    t->step = (uint32_t)(((uint64_t)hz << 16) / s_out_hz);
    t->loop = pu32(s, 12);
    t->loop_pred = (int16_t)(pu8(s, 16) | pu8(s, 17) << 8);
    t->loop_idx = pu8(s, 18);
    t->pos = 0; t->pred = 0; t->idx = 0; t->frac = 0; t->held = 0;
    t->head = 1;
    return 1;
}

static int16_t slot_src(int s)
{
    slot_t *t = &s_slot[s];
    uint32_t avail = (t->len - HDR) * 2u;
    if (avail > t->samples) avail = t->samples;
    if (t->pos >= avail) {
        if (t->pos < t->samples && !t->partial) return t->held;   /* the card has not caught up: hold */
        if (t->partial || t->loop >= avail) { t->pos = 0; t->pred = 0; t->idx = 0; }   /* round again */
        else { t->pos = t->loop; t->pred = t->loop_pred; t->idx = t->loop_idx; }
    }
    const uint8_t by = pu8(s, HDR + (t->pos >> 1));
    const int code = (t->pos & 1u) ? (by >> 4) : (by & 15);
    t->pos++;
    const int32_t st = STEP[t->idx];
    int32_t diff = st >> 3;
    if (code & 4) diff += st;
    if (code & 2) diff += st >> 1;
    if (code & 1) diff += st >> 2;
    t->pred += (code & 8) ? -diff : diff;
    if (t->pred > 32767) t->pred = 32767;
    if (t->pred < -32768) t->pred = -32768;
    t->idx += DELTA[code & 7];
    if (t->idx < 0) t->idx = 0;
    if (t->idx > 88) t->idx = 88;
    return (int16_t)t->pred;
}

static int16_t slot_take(int s)
{
    slot_t *t = &s_slot[s];
    t->frac += t->step;
    while (t->frac >= (1u << 16)) { t->frac -= 1u << 16; t->held = slot_src(s); }
    return t->held;
}

/* ── EFFECTS: ROTJ/SFX.PCM (tools/sfx.py), whole in PSRAM, four voices over the music ── */
#define NVOICE 5                  /* 0 hum/engine, 1 yours, 2 the world, 3 voices (duck the music), 4 pass-bys */
typedef struct { uint32_t base, n, pos, step, frac; int32_t pred; int idx, gain, loop; int16_t held, gl, gr; } voice_t;
static voice_t s_v[NVOICE];
static int s_sfx;                 /* 0 not asked, 1 loading, 2 ready, 3 none */
static uint32_t s_sfx_len, s_seed = 12345u;
#if defined(UVM2_PICO_RUNTIME)
#define SFX_BASE (JB_PSRAM + 0x300000u)     /* 2 MB from slot A's end to slot B's start. The romset (4 MB in) lies inside:
                                     the loader only uses it at boot, before any of this is read */
#define SFX_CAP  0x200000u
static uint8_t sx8(uint32_t o) { return *(const volatile uint8_t *)(SFX_BASE + o); }
#else
static unsigned char *s_sfx_mem;
static uint8_t sx8(uint32_t o) { return s_sfx_mem && o < s_sfx_len ? s_sfx_mem[o] : 0; }
#endif
static uint32_t sx16(uint32_t o) { return (uint32_t)sx8(o) | (uint32_t)sx8(o + 1) << 8; }
static uint32_t sx32(uint32_t o) { return sx16(o) | sx16(o + 2) << 16; }

int jukebox_sfx(int group, int voice, int gain, int loop)
{
    if (s_sfx != 2 || voice < 0 || voice >= NVOICE) return 0;
    uint32_t ng = sx16(4);
    if ((uint32_t)group >= ng) return 0;
    uint32_t first = sx16(8 + 4u * (uint32_t)group), cnt = sx16(10 + 4u * (uint32_t)group);
    if (!cnt) return 0;
    s_seed = s_seed * 1103515245u + 12345u;
    uint32_t c = 8u + 4u * ng + 12u * (first + (s_seed >> 16) % cnt);
    voice_t *v = &s_v[voice];
    v->n = 0;                                       /* silent while it is set up */
    v->base = sx32(c); v->step = (sx32(c + 8) << 16) / OUT_RATE;
    v->pos = 0; v->frac = 0; v->pred = 0; v->idx = 0; v->held = 0;
    v->gain = gain > 0 ? gain : 256; v->loop = loop; v->gl = v->gr = 256;
    v->n = sx32(c + 4);
    return 1;
}

/* ── WHERE A SOUND IS: the listener (the camera), and each voice's level in each ear ──
   Full volume up to NEAR, nothing from FAR, panned by how far to the right of the camera's
   heading it lies -- the way vpyimpact places its hits, here for recorded sounds. */
#define NEAR 3000
#define FAR  40000
static int32_t s_lis[3], s_rx = 1024, s_rz;
void jukebox_listener(int32_t x, int32_t y, int32_t z, int32_t fx, int32_t fz)
{
    s_lis[0] = x; s_lis[1] = y; s_lis[2] = z;
    int32_t rx = fz, rz = -fx;                     /* the heading turned a quarter right, on the floor */
    int32_t a = rx < 0 ? -rx : rx, b = rz < 0 ? -rz : rz, m = a > b ? a + b / 2 : b + a / 2;
    if (m) { s_rx = (int32_t)((int64_t)rx * 1024 / m); s_rz = (int32_t)((int64_t)rz * 1024 / m); }
}
static uint32_t isq(uint64_t n) { uint64_t r = 0, b = (uint64_t)1 << 62; while (b > n) b >>= 2; while (b) { if (n >= r + b) { n -= r + b; r = (r >> 1) + b; } else r >>= 1; b >>= 2; } return (uint32_t)r; }
void jukebox_voice_at(int voice, int32_t x, int32_t y, int32_t z)
{
    if (voice < 0 || voice >= NVOICE) return;
    int64_t dx = x - s_lis[0], dy = y - s_lis[1], dz = z - s_lis[2];
    uint32_t d = isq((uint64_t)(dx * dx + dy * dy + dz * dz)), h = isq((uint64_t)(dx * dx + dz * dz));
    int32_t g = d <= NEAR ? 256 : d >= FAR ? 0 : (int32_t)(256 - (int64_t)(d - NEAR) * 256 / (FAR - NEAR));
    int32_t pan = h > 200 ? (int32_t)((dx * s_rx + dz * s_rz) / (int64_t)h) / 4 : 0;   /* -256 left .. +256 right */
    if (pan > 256) pan = 256;
    if (pan < -256) pan = -256;
    int32_t l = 256 - pan, r = 256 + pan;          /* the near ear full, the far one fading */
    s_v[voice].gl = (int16_t)((l > 256 ? 256 : l) * g >> 8);
    s_v[voice].gr = (int16_t)((r > 256 ? 256 : r) * g >> 8);
}
int jukebox_sfx_at(int group, int voice, int gain, int loop, int32_t x, int32_t y, int32_t z)
{
    if (!jukebox_sfx(group, voice, gain, loop)) return 0;
    jukebox_voice_at(voice, x, y, z);
    return 1;
}
void jukebox_sfx_stop(int voice) { if (voice >= 0 && voice < NVOICE) s_v[voice].n = 0; }
int  jukebox_sfx_busy(int voice) { return voice >= 0 && voice < NVOICE && s_v[voice].n; }

static int16_t voice_take(voice_t *v)
{
    v->frac += v->step;
    while (v->frac >= (1u << 16)) {
        v->frac -= 1u << 16;
        if (v->pos >= v->n) {
            if (!v->loop) { v->n = 0; return 0; }
            v->pos = 0; v->pred = 0; v->idx = 0;
        }
        const uint8_t by = sx8(v->base + (v->pos >> 1));
        const int code = (v->pos & 1u) ? (by >> 4) : (by & 15);
        v->pos++;
        const int32_t st = STEP[v->idx];
        int32_t diff = st >> 3;
        if (code & 4) diff += st;
        if (code & 2) diff += st >> 1;
        if (code & 1) diff += st >> 2;
        v->pred += (code & 8) ? -diff : diff;
        if (v->pred > 32767) v->pred = 32767;
        if (v->pred < -32768) v->pred = -32768;
        v->idx += DELTA[code & 7];
        if (v->idx < 0) v->idx = 0;
        if (v->idx > 88) v->idx = 88;
        v->held = (int16_t)v->pred;
    }
    return v->held;
}

static int playable(int s)
{
    return s >= 0 && s_slot[s].state != SL_DEAD && s_slot[s].state != SL_IDLE && slot_head(s) &&
           (s_slot[s].state == SL_DONE || s_slot[s].len >= HEAD);
}

/* the mix in stereo: the music in the middle, every voice where it is */
static void render_lr(int16_t *outl, int16_t *outr, int n)
{
    for (int i = 0; i < n; i++) {
        int32_t v = 0;
        int cur = playable(s_cur), old = s_old >= 0 && s_old != s_cur && playable(s_old);
        /* the new one comes up as the old one goes down; until the new one has its head
           start the old plays on at full (g stays 0) */
        uint32_t g = s_fade >= FADE ? 256u : s_fade * 256u / FADE;
        if (cur) v += (int32_t)slot_take(s_cur) * (int32_t)g >> 8;
        if (old) v += (int32_t)slot_take(s_old) * (int32_t)(256u - g) >> 8;
        if (s_fade < FADE && (cur || s_cur < 0)) s_fade++;
        if (s_fade >= FADE) s_old = -1;
        v = s_v[3].n ? v / 2 : v * 3 / 4;          /* headroom under the effects; down under a voice */
        int32_t l = v, r = v;
        for (int k = 0; k < NVOICE; k++)
            if (s_v[k].n) {
                int32_t x = (int32_t)voice_take(&s_v[k]) * s_v[k].gain >> 8;
                l += x * s_v[k].gl >> 9; r += x * s_v[k].gr >> 9;
            }
        outl[i] = (int16_t)(l > 32767 ? 32767 : l < -32768 ? -32768 : l);
        if (outr) outr[i] = (int16_t)(r > 32767 ? 32767 : r < -32768 ? -32768 : r);
        else outl[i] = (int16_t)(((l > 32767 ? 32767 : l < -32768 ? -32768 : l) + (r > 32767 ? 32767 : r < -32768 ? -32768 : r)) / 2);
    }
}
void jukebox_render(int16_t *out, int n) { render_lr(out, 0, n); }   /* mono, for the tests */

/* the slot a new track goes into: never the one playing; one already holding it is reused */
static int slot_for(const char *id)
{
    for (int s = 0; s < 2; s++)
        if (s != s_cur && s_slot[s].state != SL_DEAD && s_slot[s].state != SL_IDLE && !s_slot[s].partial && same(s_slot[s].id, id)) return s;
    return s_cur == 0 ? 1 : 0;
}

static void start_in(int s, const char *id, int reuse)
{
    slot_t *t = &s_slot[s];
    if (!reuse) { copy_id(t->id, id); t->state = SL_LOAD; t->len = 0; t->partial = 0; }
    t->head = 0;                                    /* from the top again */
    s_old = s_cur; s_cur = s; s_fade = 0;
    copy_id(s_want, id);
}

#if defined(UVM2_PICO_RUNTIME)
#include "uvm2_sd.h"
#include "uvm2_jack.h"
#include "uvm2_psram.h"
#include "pico/time.h"

extern int uvm2_psram_ready;
static int s_tried, s_jack, s_ram, s_loading = -1;
static uvm2_sd_file s_file, s_sfile;
static uint32_t s_kbs;
#define SLICE 2048u

static void bring_up(void)
{
    s_tried = 1;
    s_jack = uvm2_jack_init();
    if (uvm2_psram_ready != 1) { uvm2_qmi_bring_up(); uvm2_psram_ready = uvm2_psram_init(); }
    s_ram = uvm2_psram_ready == 1;
    if (s_ram) uvm2_psram_enable_xip();
    s_slot[0].cap = 0x300000u; s_slot[1].cap = 0x300000u;
}

void jukebox_play(const char *id)
{
    if (!s_tried) bring_up();
    if (!s_jack || !s_ram) return;
    if (!id || !*id) { s_old = s_cur; s_cur = -1; s_fade = 0; s_want[0] = 0; return; }
    if (s_cur >= 0 && same(s_slot[s_cur].id, id) && s_slot[s_cur].state != SL_DEAD) return;
    for (int k = 0; k < 2; k++) if (s_slot[k].state == SL_DEAD && same(s_slot[k].id, id)) return;   /* not on the card */
    int s = slot_for(id);
    int reuse = s_slot[s].state != SL_IDLE && s_slot[s].state != SL_DEAD && !s_slot[s].partial && same(s_slot[s].id, id);
    if (!reuse) {                                   /* open it: the one loading before is dropped */
        char path[40];
        int k = 0;
        for (int j = 0; s_dir[j] && k < 16; j++) path[k++] = s_dir[j];
        if (k) path[k++] = '/';
        for (int j = 0; id[j] && k < 34; j++) path[k++] = id[j];
        path[k++] = '.'; path[k++] = 'P'; path[k++] = 'C'; path[k++] = 'M'; path[k] = 0;
        if (s_loading >= 0 && s_loading != s) {     /* dropped half way: it may play out its fade */
            s_slot[s_loading].partial = 1;
            s_slot[s_loading].state = s_slot[s_loading].len >= HEAD ? SL_DONE : SL_IDLE;
        }
        s_file.ok = 0;
        if (!uvm2_sd_open(path, &s_file)) { copy_id(s_slot[s].id, id); s_slot[s].state = SL_DEAD; return; }
        s_loading = s;
    }
    start_in(s, id, reuse);
}

int jukebox_live(void)
{
    return s_jack && s_ram && s_cur >= 0 && s_slot[s_cur].state != SL_DEAD;
}

/* "JACK 1 RAM 1 SD 2 A2 812K B0 0K 1340KBS": the jack and the PSRAM came up, the card's last
   step (1 mount, 2 open, 3 data) and FatFs result, each slot's state and KB in, the card's
   measured speed. On the title, because this board has no probe: the screen is the instrument. */
static char *put_num(char *q, uint32_t v)
{
    char t[10]; int n = 0;
    do t[n++] = (char)('0' + v % 10), v /= 10; while (v && n < 10);
    while (n) *q++ = t[--n];
    return q;
}
static char *put_str(char *q, const char *a) { while (*a) *q++ = *a++; return q; }
const char *jukebox_report(void)
{
    static char b[96];
    char *q = b;
    q = put_str(q, "JACK "); q = put_num(q, (uint32_t)s_jack);
    q = put_str(q, " RAM "); q = put_num(q, (uint32_t)s_ram);
    q = put_str(q, " SD "); q = put_num(q, uvm2_sd_diag.step); *q++ = '/'; q = put_num(q, uvm2_sd_diag.fresult);
    for (int s = 0; s < 2; s++) {
        *q++ = ' '; *q++ = s ? 'B' : 'A'; q = put_num(q, (uint32_t)s_slot[s].state);
        *q++ = ' '; q = put_num(q, s_slot[s].len / 1024u); *q++ = 'K';
    }
    *q++ = ' '; q = put_num(q, s_kbs); q = put_str(q, "KBS");
    q = put_str(q, " OUT "); q = put_num(q, s_seen_hz);
    q = put_str(q, " CLK "); q = put_num(q, uvm2_jack_clk() / 1000000u);
    *q = 0;
    return b;
}

int jukebox_boot_progress(void)
{
    if (!s_tried) return 0;
    if (!s_jack || !s_ram) return 256;              /* no jack or no PSRAM: nothing to load */
    if (s_sfx == 0) return 0;
    if (s_sfx == 1) return s_sfile.len ? (int)((uint64_t)s_sfx_len * 220u / s_sfile.len) : 0;
    if (s_cur < 0 || s_slot[s_cur].state == SL_DEAD || playable(s_cur)) return 256;
    return 220 + (int)(s_slot[s_cur].len * 36u / HEAD);   /* then the first track's head */
}

void jukebox_update(int mode)
{
    if (!s_tried) bring_up();
    if (!s_jack) return;
    if (s_sfx == 0 && s_ram) {
        char path[40];
        int k = 0;
        for (int j = 0; s_dir[j] && k < 16; j++) path[k++] = s_dir[j];
        if (k) path[k++] = '/';
        for (const char *a = "SFX.PCM"; *a; a++) path[k++] = *a;
        path[k] = 0;
        s_sfx = uvm2_sd_open(path, &s_sfile) ? 1 : 3;
    }
    /* HOW LONG THE CARD MAY HAVE THIS FRAME. Reading it stops the game (it is the same core),
       so under play it gets little; the effects come in whole behind the loading screen, where
       the frame has nothing else to do (JB_BOOT), and are never read again. */
    static unsigned char tmp[SLICE];
    const uint32_t budget = mode == JB_BOOT ? 15000u : mode == JB_PLAY ? 1700u : 6000u;
    if (s_sfx == 1) {                               /* the effects: all of them, into PSRAM */
        const uint32_t t0 = time_us_32();
        do {
            uint32_t want = s_sfx_len + SLICE <= SFX_CAP ? SLICE : SFX_CAP - s_sfx_len;
            uint32_t got = want ? uvm2_sd_next(&s_sfile, tmp, want) : 0;
            volatile uint8_t *p = (volatile uint8_t *)(SFX_BASE + s_sfx_len);
            for (uint32_t i = 0; i < got; i++) p[i] = tmp[i];
            s_sfx_len += got;
            if (!got) { s_sfx = s_sfx_len > 8u && sx8(0) == 'R' && sx8(1) == 'J' && sx8(2) == 'S' && sx8(3) == 'X' ? 2 : 3; break; }
        } while (time_us_32() - t0 < budget);
    }
    else if (s_loading >= 0) {                    /* the track, in slices, within the budget */
        slot_t *t = &s_slot[s_loading];
        const uint32_t t0 = time_us_32();
        const uint32_t slice = mode == JB_PLAY ? SLICE / 4u : SLICE;
        /* ONE SLICE ALWAYS, THEN AS MANY MORE AS FIT. Asking first whether even the first
           fits, with no measurement yet and the slowest rate assumed, answered no forever:
           nothing was read, so nothing was measured, so nothing ever loaded. */
        for (int first = 1;; first = 0) {
            uint32_t spent = time_us_32() - t0;
            uint32_t kbs = s_kbs ? s_kbs : 200u;
            if (!first && (spent >= budget || budget - spent < slice * 1000u / kbs)) break;
            uint32_t want = slice;
            if (t->len + want > t->cap) want = t->cap - t->len;
            uint32_t a = time_us_32();
            uint32_t got = want ? uvm2_sd_next(&s_file, tmp, want) : 0;
            uint32_t us = time_us_32() - a;
            if (us) { uint32_t k = got * 1000u / us; s_kbs = s_kbs ? (s_kbs * 3u + k) / 4u : k; }
            volatile uint8_t *p = (volatile uint8_t *)(JB_PSRAM + BASE[s_loading] + t->len);
            for (uint32_t i = 0; i < got; i++) p[i] = tmp[i];
            t->len += got;
            if (!got) { t->state = t->len >= HDR ? SL_DONE : SL_DEAD; s_loading = -1; break; }
        }
    }
    int n = uvm2_jack_space();
    static uint32_t m_t0, m_n;                      /* what the jack took, over ~2 s: shown, not used */
    if (!m_t0) m_t0 = time_us_32();
    m_n += (uint32_t)(n > 0 ? n : 0);
    uint32_t el = time_us_32() - m_t0;
    if (el > 2000000u) { s_seen_hz = (uint32_t)((uint64_t)m_n * 1000000u / el); m_t0 = time_us_32(); m_n = 0; }
    while (n > 0) {
        int16_t bl[96], br[96];
        const int k = n > 96 ? 96 : n;
        render_lr(bl, br, k);
        uvm2_jack_write_lr(bl, br, k);              /* stereo: the DAC has two channels */
        n -= k;
    }
}

#else
/* Not on the cartridge runtime: silence (the program keeps its PSG sounds). */
void jukebox_play(const char *id) { (void)id; }
int  jukebox_live(void) { return 0; }
const char *jukebox_report(void) { return ""; }
int  jukebox_boot_progress(void) { return 256; }
void jukebox_update(int mode) { (void)mode; }
#endif

/* ── the VPy builtins ──────────────────────────────────────────────────────────────── */
static int s_mode;                 /* JB_SCREEN, JB_PLAY or JB_BOOT (JUKEBOX_MODE) */

void vpyj_dir(const char *d)
{
    int k = 0;
    while (d && d[k] && k < 16) { s_dir[k] = d[k]; k++; }
    s_dir[k] = 0;
}
void vpyj_mode(int m) { s_mode = m < 0 ? 0 : m > 2 ? 2 : m; }
void vpyj_frame(void) { jukebox_update(s_mode); }
int  vpyj_sfx(int group, int voice, int gain, int loop) { return jukebox_sfx(group, voice, gain, loop); }
/* fz: argument 5, in vpyx_args[0] */
void vpyj_listener(int32_t x, int32_t y, int32_t z, int32_t fx)
{
    jukebox_listener(x, y, z, fx, vpyx_args[0]);
}
/* (x, y, z): arguments 5-7, which the codegen passes in vpyx_args[] */
int  vpyj_sfx_at(int group, int voice, int gain, int loop)
{
    return jukebox_sfx_at(group, voice, gain, loop, vpyx_args[0], vpyx_args[1], vpyx_args[2]);
}
