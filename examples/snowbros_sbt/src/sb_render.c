/* sb_render.c — draw the Pandora sprite list as vectors.
 *
 * Chain walk mirrors the chip (byte3 bit2 = relative position, bits 0/1 the
 * 9th bits of dx/dy). Entries are grouped into OBJECTS (an absolute entry plus
 * the relatives that follow, split when a step leaves the object's bbox or its
 * 16px grid — same rule the extraction tools settled on). Each object is
 * identified by its LOWEST tile code (frames are consecutive-tile runs):
 *   hit  -> draw the traced .vec strokes centred on the object's bbox,
 *           mirrored when the object is drawn flipped;
 *   miss -> per-tile silhouette boxes (sb_tiles.h), so everything stays
 *           visible while the vec catalogue grows.
 * SB_LOG_UNMATCHED (host): count unmatched base tiles, dump a toplist at the
 * end — that list is the next tracing worklist.
 */
#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include "sb_tiles.h"
#include "sb_sprites.h"
#include "sb_font.h"
#include "sb_shapes.h"

void v_directDraw32(int32_t, int32_t, int32_t, int32_t, uint8_t);

/* SB_FPSRTT=1 — telemetria de fotogramas por RTT, solo para los cartuchos (lee un
 * periferico del RP2350). Ver src/sb_rtt.c: `make rp2350 FPSRTT=1`.
 *
 * El contador de segmentos va en un MACRO y no tocando los sitios que dibujan: un
 * macro con nombre de funcion no se re-expande dentro de si mismo, asi que esto se
 * expande a la llamada de verdad mas un incremento. Once puntos de dibujo repartidos
 * por el fichero, y ninguno hay que recordarlo. */
#ifndef SB_FPSRTT
#define SB_FPSRTT 0
#endif
#if SB_FPSRTT
static unsigned sb_segs;
#define v_directDraw32(a, b, c, d, e) (sb_segs++, v_directDraw32((a), (b), (c), (d), (e)))
#endif

extern unsigned char sb_spriteram[0x1000];
extern unsigned char sb_palette[0x200];
extern unsigned char sb_ram[0x4000];   /* 68000 work RAM (0x100000..) */

#define SB_W 256
#define SB_H 224
#define SB_S 90
#define DX(px) (((int32_t)(px) - SB_W/2) * SB_S)
#define DY(py) (((SB_H/2) - (int32_t)(py)) * SB_S)
#define BRIGHT 95
#define BG_TILES 24   /* objects with more tiles than this are backdrop */
#define BG_BRIGHT 25  /* draw backdrop faint; 0 culls it entirely */

/* SB_TILE_BOXES — the per-tile SILHOUETTE BOXES, the placeholder for every tile
 * whose object found no traced .vec. 1 draws them, 0 leaves those tiles blank.
 *
 * They are scaffolding: they keep the screen readable while the vec catalogue
 * grows, and they are the reason a half-traced level looks like a grid of
 * rectangles. `make <target> TILE_BOXES=1` puts them back — one variable, and
 * it reaches all four targets (see the Makefile; a knob that arrives at the host
 * but not at the cartridge means measuring two games that draw differently).
 *
 * WHAT THIS DOES *NOT* TURN OFF, because neither is a placeholder:
 *   - the stroke font (draw_glyph): text is text, traced or not.
 *   - the authored PLATFORMS (draw_level_platforms): the per-level geometry from
 *     sb_shapes.h IS the level — it is drawn regardless of this box knob.
 */
#ifndef SB_TILE_BOXES
#define SB_TILE_BOXES 1
#endif

static void rect(int x0, int y0, int x1, int y1, uint8_t b)
{
    v_directDraw32(DX(x0), DY(y0), DX(x1), DY(y0), b);
    v_directDraw32(DX(x1), DY(y0), DX(x1), DY(y1), b);
    v_directDraw32(DX(x1), DY(y1), DX(x0), DY(y1), b);
    v_directDraw32(DX(x0), DY(y1), DX(x0), DY(y0), b);
}

static int sext9(int v) { v &= 0x1ff; return v >= 0x100 ? v - 0x200 : v; }

/* --- text path: the game writes text as raw ASCII tile codes ------------- */
/* 0x04-0x0d bold HUD digits; 0x10-0x1f and 0x5e solid fills (skip);
 * 0x20-0x5a ASCII; 0x5b/0x5c/0x5d composite 1P/2P/HI. */
static int text_code(int tile)
{
    if (tile >= 0x04 && tile <= 0x0d) return '0' + tile - 0x04;
    if (tile >= 0x20 && tile <= 0x5d) return tile;
    return 0;
}

static int is_textish(int tile)
{   /* anything the text path fully owns, including skipped fills */
    return tile < 0x100 &&
           (text_code(tile) || (tile >= 0x10 && tile <= 0x1f) || tile == 0x5e);
}

static void draw_glyph(int code, int sx, int sy)
{
    if (code < 0x21 || code > 0x5d) return;   /* space & fills: nothing */
    int first = sb_font_idx[code - 0x20].first;
    int count = sb_font_idx[code - 0x20].count;
    for (int i = 1; i < count; i++) {
        if (sb_font_pts[first + i][2]) continue;      /* pen-up: new stroke */
        int ax = sx + sb_font_pts[first + i - 1][0];
        int ay = sy + sb_font_pts[first + i - 1][1];
        int bx = sx + sb_font_pts[first + i][0];
        int by = sy + sb_font_pts[first + i][1];
        v_directDraw32(DX(ax), DY(ay), DX(bx), DY(by), BRIGHT);
    }
}

/* current object being collected */
#define OBJ_MAX 512
static struct { int x, y, tile, flip, pal; } obj[OBJ_MAX];
static int nobj;
static int obx0, oby0, obx1, oby1;   /* bbox of collected tiles */

/* the game parks unused sprites by pointing their colours at black — if the
 * whole object resolves to near-black in the live CRAM, the arcade shows
 * nothing and so do we (top-row colours as proxy) */
static int object_dark(void)
{
    int lit = 0;
    for (int i = 0; i < nobj && !lit; i++) {
        const unsigned char *row = sb_tile_toprow[obj[i].tile];
        for (int k = 0; k < 16; k++) {
            int c = (k & 1) ? (row[k >> 1] & 0x0f) : (row[k >> 1] >> 4);
            if (!c) continue;
            int off = ((obj[i].pal * 16 + c) & 0xff) * 2;
            int w = (sb_palette[off] << 8) | sb_palette[off + 1];
            if ((w & 0x1f) + ((w >> 5) & 0x1f) + ((w >> 10) & 0x1f) >= 12) { lit = 1; break; }
        }
    }
    return !lit;
}

int sb_capture_request;   /* set on a new unmatched sighting; host saves RAM */

/* unmatched-frame tracking: count + shape of the last sighting per base,
 * merged into a worklist file on exit (SB_MISSING_FILE, host only) */
static struct { unsigned count; unsigned char w, h, ntiles; } unmatched[4096];
static int log_unmatched = -1;

/* Authored per-level platform geometry (sb_shapes.h), drawn in arcade space via
 * DX/DY so it lands under the sprites. This REPLACES flush_platforms/snowy_top:
 * the pixel heuristic missed the left-hand structures and had no diagonals; the
 * .vec has every platform exactly where it was traced. Level word at 0x101572. */
static void draw_stream(const int16_t *d, int dy)
{
    int have = 0, ppx = 0, ppy = 0;
    for (int i = 0; d[i] != SB_END; ) {
        if (d[i] == SB_PEN) { have = 0; i++; continue; }
        int py = d[i] + dy, px = d[i + 1]; i += 2;
        if (have) v_directDraw32(DX(ppx), DY(ppy), DX(px), DY(py), BRIGHT);
        ppx = px; ppy = py; have = 1;
    }
}

/* Snow Bros stacks a world's floors as one continuous vertical strip and SCROLLS
 * UP between them. Measured from a MAME capture by cross-correlating the backdrop
 * frame to frame: it slides 2px/frame for a FULL SCREEN (224px) over ~112 frames
 * when the floor advances — the outgoing floor leaves completely out the bottom
 * as the incoming one arrives from the top, no overlap. The per-level .vec is a
 * fixed screen, so we animate that same slide ourselves: on the frame the level
 * word (0x101572) steps up by one, slide the OUTGOING floor down and bring the
 * INCOMING floor down from a full screen above. SB_SCROLL_PX/FRAMES are the
 * measured defaults; override at runtime on the host (env) to tune vs hardware. */
#ifndef SB_SCROLL_PX
#define SB_SCROLL_PX 224
#endif
#ifndef SB_SCROLL_FRAMES
#define SB_SCROLL_FRAMES 112
#endif

static void draw_level_platforms(void)
{
    /* Only while a level is actually being played. The player object (fixed
     * struct at 0x1015b2, X word at +6 = 0x1015b8) is zero on the static title
     * and high-score screens and non-zero once a floor is running (attract DEMO
     * included, which is correct — it plays a real level). Without this, the
     * level word (still 0) would paint level-0 platforms over the SNOW BROS
     * logo. It is a whole-game invariant, not a per-level pixel heuristic. */
    if (!((sb_ram[0x15b8] << 8) | sb_ram[0x15b9])) return;
    int level = (sb_ram[0x1572] << 8) | sb_ram[0x1573];
    if (level < 0 || level >= SB_NLEVELS) return;

    static int scroll_px = -1, scroll_frames;
    if (scroll_px < 0) {
        const char *a = getenv("SB_SCROLL_PX"), *b = getenv("SB_SCROLL_FRAMES");
        scroll_px = a ? atoi(a) : SB_SCROLL_PX;
        scroll_frames = b ? atoi(b) : SB_SCROLL_FRAMES;
    }

    /* transition tracking: animate only a normal +1 floor step; any other jump
     * (game over -> 0, forced level, boot garbage) snaps with no slide */
    static int prev = -1, t, from;
    if (prev < 0) prev = level;
    if (level != prev) {
        if (level == prev + 1 && scroll_frames > 0) { t = scroll_frames; from = prev; }
        else t = 0;
        prev = level;
    }

    if (t > 0) {
        int off = scroll_px * (scroll_frames - t) / scroll_frames;  /* 0..scroll_px */
        if (from >= 0 && from < SB_NLEVELS) draw_stream(sb_levels[from], off);       /* out the bottom */
        draw_stream(sb_levels[level], off - scroll_px);                              /* in from the top */
        t--;
    } else {
        draw_stream(sb_levels[level], 0);
    }
}

static int sig_find(int tile)
{
    int lo = 0, hi = SB_NSIGS - 1;
    while (lo <= hi) {
        int mid = (lo + hi) / 2;
        if (sb_vec_sigs[mid].tile == tile) return mid;
        if (sb_vec_sigs[mid].tile < tile) lo = mid + 1; else hi = mid - 1;
    }
    return -1;
}

static void draw_shape(int s, int cx, int cy, int mirror)
{
    int p0 = sb_vec_shapes[s].poly0, np = sb_vec_shapes[s].npolys;
    for (int p = p0; p < p0 + np; p++) {
        int first = sb_vec_polys[p].first, n = sb_vec_polys[p].npts;
        for (int i = 0; i < n - 1; i++) {
            int ax = sb_vec_pts[first + i][0],     ay = sb_vec_pts[first + i][1];
            int bx = sb_vec_pts[first + i + 1][0], by = sb_vec_pts[first + i + 1][1];
            if (mirror) { ax = -ax; bx = -bx; }
            /* vec y is up, screen y is down */
            v_directDraw32(DX(cx + ax), DY(cy - ay), DX(cx + bx), DY(cy - by), BRIGHT);
        }
    }
}

static void flush_object(void)
{
    if (!nobj) return;
    /* base tile + majority flip decide identity and orientation */
    int base = 0xffff, flips = 0, vis = 0;
    for (int i = 0; i < nobj; i++) {
        if (obj[i].tile < base) base = obj[i].tile;
        flips += obj[i].flip & 1;   /* X mirror only */
        int sx = obj[i].x, sy = obj[i].y;
        if (sx > -16 && sx < SB_W && sy > -16 && sy < SB_H) vis = 1;
    }
    if (!vis || object_dark()) { nobj = 0; return; }

    int s = sig_find(base);
    /* several signatures can share a base (frame VARIANTS with different
     * boxes); pick the one whose bbox matches — edge-clipped fragments match
     * nothing and stay as boxes */
    if (s >= 0) {
        while (s > 0 && sb_vec_sigs[s - 1].tile == base) s--;
        int hit = -1, bw = obx1 - obx0 + 16, bh = oby1 - oby0 + 16;
        for (int k = s; k < SB_NSIGS && sb_vec_sigs[k].tile == base; k++)
            if (sb_vec_sigs[k].w == bw && sb_vec_sigs[k].h == bh) { hit = k; break; }
        s = hit;
    }
    if (s >= 0) {
        int cx = (obx0 + obx1 + 16) / 2, cy = (oby0 + oby1 + 16) / 2;
        /* the vec is traced as the reference capture looked; mirror only when
         * the runtime orientation DIFFERS from that reference */
        int runflip = flips * 2 > nobj;
        int mirror = runflip != sb_vec_sigs[s].refflip;
#ifdef SB_TRACE_FACING
        { extern int printf(const char *, ...); extern int sb_frame_counter;
          printf("FACE f=%d base=%03x cx=%d mirror=%d\n", sb_frame_counter, base, cx, mirror); }
#endif
        draw_shape(sb_vec_sigs[s].shape, cx, cy, mirror);
        nobj = 0;
        return;
    }

    /* pure text objects always render via the stroke font at full bright —
     * a long instruction line must not be dimmed as backdrop */
    int textish = 0;
    for (int i = 0; i < nobj; i++) textish += is_textish(obj[i].tile);
    if (textish == nobj) {
        for (int i = 0; i < nobj; i++)
            draw_glyph(text_code(obj[i].tile), obj[i].x, obj[i].y);
        nobj = 0;
        return;
    }

    /* scenery = level-bank tiles in BULK; small level-bank objects can be
     * later-floor ENEMIES (their gfx live past 0x600) and must stay visible */
    int scenery = nobj > BG_TILES;
    if (!scenery && nobj >= 10) {
        scenery = 1;
        for (int i = 0; i < nobj; i++)
            if (obj[i].tile < 0x600 || obj[i].tile > 0xcff) { scenery = 0; break; }
    }
    int bright = scenery ? BG_BRIGHT : BRIGHT;

    /* worklist: skip scenery and HUD-region singles (own path). Level-bank
     * bases (0x600-0xcff) are only skipped when the object is scenery-SHAPED
     * (>= 10 tiles, same threshold the draw rule uses): floor-11+ enemies keep
     * their gfx in those banks and arrive as small objects — excluding the
     * whole range made them uncapturable and the worklist blind to them. */
    if (log_unmatched > 0 && !scenery && nobj <= BG_TILES
        && base >= 0x100 && (base < 0x600 || base > 0xcff || nobj < 10)) {
        /* first sighting of this base -> ask the host to dump the sprite RAM
         * NOW, so transient frames can't slip between farm samples */
        if (!unmatched[base].count) sb_capture_request = 1;
        unmatched[base].count++;
        unmatched[base].w = (obx1 - obx0 + 16) / 16;
        unmatched[base].h = (oby1 - oby0 + 16) / 16;
        unmatched[base].ntiles = nobj;
    }

    for (int i = 0; i < nobj; i++) {
        int t = obj[i].tile;
        if (is_textish(t)) { draw_glyph(text_code(t), obj[i].x, obj[i].y); continue; }
        /* platforms no longer come from snow-cap detection here — they are drawn
         * from the authored per-level geometry (draw_level_platforms), so these
         * scenery tiles just fall through to the faint backdrop boxes below. */
        if (!SB_TILE_BOXES) continue;   /* untraced tile: draw nothing at all */
        if (!bright) continue;
        const unsigned char *b = sb_tile_box[t];
        int bx0 = b[0], by0 = b[1], bx1 = b[2] + 1, by1 = b[3] + 1;
        if (obj[i].flip & 1) { int q = bx0; bx0 = 16 - bx1; bx1 = 16 - q; }
        if (obj[i].flip & 2) { int q = by0; by0 = 16 - by1; by1 = 16 - q; }
        rect(obj[i].x + bx0, obj[i].y + by0, obj[i].x + bx1, obj[i].y + by1, bright);
    }
    nobj = 0;
}

int sb_frame_counter;

void sb_render(void)
{
    sb_frame_counter++;
    if (log_unmatched < 0) {
        /* on by default on the host — SB_LOG_UNMATCHED=0 disables */
        const char *e = getenv("SB_LOG_UNMATCHED");
        log_unmatched = e ? atoi(e) : 1;
    }
    int x = 0, y = 0;
    nobj = 0;
    for (int offs = 0; offs < 0x1000; offs += 8) {
        int dx = sb_spriteram[offs + 4];
        int dy = sb_spriteram[offs + 5];
        int b3 = sb_spriteram[offs + 3];
        int at = sb_spriteram[offs + 7];
        if (b3 & 1) dx |= 0x100;
        if (b3 & 2) dy |= 0x100;
        if (b3 & 4) {
            x += sext9(dx);
            y += sext9(dy);
            if (nobj && (((x - obj[0].x) % 16) || ((y - obj[0].y) % 16)
                         || x < obx0 - 16 || x > obx1 + 16
                         || y < oby0 - 16 || y > oby1 + 16))
                flush_object();
        } else {
            flush_object();
            x = sext9(dx);
            y = sext9(dy);
        }

        int tile = (((at & 0x3f) << 8) | sb_spriteram[offs + 6]) & 0xfff;
        if (sb_tile_blank[tile]) continue;
        if (!nobj) { obx0 = obx1 = x; oby0 = oby1 = y; }
        else {
            if (x < obx0) obx0 = x; if (x > obx1) obx1 = x;
            if (y < oby0) oby0 = y; if (y > oby1) oby1 = y;
        }
        if (nobj < OBJ_MAX) {
            /* the chip wraps the FINAL position to 9 bits signed — a chain
             * can accumulate past 512 and land back on the left of the screen */
            obj[nobj].x = sext9(x); obj[nobj].y = sext9(y); obj[nobj].tile = tile;
            obj[nobj].flip = ((at >> 7) & 1) | ((at >> 5) & 2);  /* bit7 X, bit6 Y */
            obj[nobj].pal = b3 >> 4;
            nobj++;
        }
    }
    flush_object();
    draw_level_platforms();
#if SB_FPSRTT
    /* AL FINAL, con el frame ya emitido: lo que cuenta es lo que se ha dibujado.
     * Quien emite la linea es sb_marca(2), desde gmain — aqui solo se deja el dato. */
    { extern unsigned sb_vec_last; sb_vec_last = sb_segs; sb_segs = 0; }
#endif
}

/* host: dump the unmatched-tile toplist (call at exit) */
static const char *tile_region(int t)
{
    if (t < 0x100)               return "font/HUD text (text path, don't trace)";
    if (t <= 0x13b)              return "ball/effects";
    if (t >= 0x304 && t <= 0x33f) return "enemy 1 (pink)";
    if (t >= 0x340 && t <= 0x3c2) return "player pose";
    if (t >= 0x480 && t <= 0x52f) return "enemy 2";
    if (t >= 0x530 && t <= 0x5be) return "enemy 3";
    if (t >= 0xd28 && t <= 0xe51) return "boss";
    return "?";
}

void sb_unmatched_report(void)
{
    if (log_unmatched <= 0) return;
    printf("-- unmatched base tiles (trace these next) --\n");
    unsigned shown[4096];
    for (int i = 0; i < 4096; i++) shown[i] = unmatched[i].count;
    for (int pass = 0; pass < 20; pass++) {
        unsigned best = 0; int bi = -1;
        for (int i = 0; i < 4096; i++)
            if (shown[i] > best) { best = shown[i]; bi = i; }
        if (bi < 0 || !best) break;
        printf("  tile %04x  seen %u frames  %dx%d %d tiles  %s\n", bi, best,
               unmatched[bi].w * 16, unmatched[bi].h * 16, unmatched[bi].ntiles,
               tile_region(bi));
        shown[bi] = 0;
    }

    /* merge into the persistent worklist: "base count WxH ntiles region" */
    const char *path = getenv("SB_MISSING_FILE");
    if (!path) path = "missing_frames.txt";
    unsigned prev[4096] = {0};
    FILE *f = fopen(path, "r");
    if (f) {
        unsigned b, c; int w, h, n;
        char rest[128];
        while (fscanf(f, "%x %u %dx%d %d %127[^\n]", &b, &c, &w, &h, &n, rest) >= 5)
            if (b < 4096) prev[b] = c;
        fclose(f);
    }
    f = fopen(path, "w");
    if (!f) return;
    fprintf(f, "# unmatched sprite frames — cumulative; regenerate vecs with\n");
    fprintf(f, "# tools/autotrace.py --catalog after capturing them in dumps/\n");
    int total = 0;
    for (int i = 0; i < 4096; i++) {
        unsigned c = unmatched[i].count + prev[i];
        if (!c) continue;
        int w = unmatched[i].count ? unmatched[i].w * 16 : 0;
        int h = unmatched[i].count ? unmatched[i].h * 16 : 0;
        int n = unmatched[i].count ? unmatched[i].ntiles : 0;
        fprintf(f, "%04x %u %dx%d %d %s\n", i, c, w, h, n, tile_region(i));
        total++;
    }
    fclose(f);
    printf("-- %d unmatched bases merged into %s --\n", total, path);
}
