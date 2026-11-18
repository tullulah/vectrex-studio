/* vpy_save.c — the VPy builtins SAVE_SET, SAVE_GET, SAVE_WRITE and SAVE_READ: a few numbers
 * kept on the SD card across power-offs (high score tables, unlocked levels, settings).
 *
 * The program fills a table of VPYS_N integers with SAVE_SET(i, v) and SAVE_WRITE("NAME")
 * puts it on the card as `config/NAME.SAV`; SAVE_READ("NAME") brings it back at start-up and
 * SAVE_GET(i) reads it. TEXT, ONE NUMBER A LINE, up to the highest slot ever set — so the file
 * can be read and edited from a PC, as Kuroishi's high score table is (config/KUROISHI.HI).
 *
 * Written with the SDK's FAT writer, the calibration's and Kuroishi's: overwrite the first
 * sector in place when the file is there, create it (and its folder) when it is not. That
 * writer takes at most 512 bytes, which is the cap on what a table may hold as text.
 *
 * Shipped inside vpy_cli and compiled into the image when a program calls these builtins.
 * Where there is no card, or on the debug cartridge (its BIOS exposes no write path), nothing
 * is kept: SAVE_READ returns 0, SAVE_WRITE returns 0, and the table still works for the session.
 */
#include <stdint.h>

#define VPYS_N 64
static int32_t s_save[VPYS_N];
static int s_top;                  /* one past the highest slot set: what gets written */

void vpys_set(int i, int v)
{
    if ((unsigned)i >= VPYS_N) return;
    s_save[i] = v;
    if (i + 1 > s_top) s_top = i + 1;
}

int vpys_get(int i)
{
    return (unsigned)i < VPYS_N ? s_save[i] : 0;
}

#if defined(UVM2_PICO_RUNTIME)
#include "uvm2_sd.h"

/* config/NAME.SAV, the name as given (up to 8 characters: the card's reader wants 8.3). */
static void path_of(char *p, const char *name)
{
    const char *a = "config/";
    int k = 0;
    while (*a) p[k++] = *a++;
    for (int j = 0; name && name[j] && j < 8; j++) p[k++] = name[j];
    p[k++] = '.'; p[k++] = 'S'; p[k++] = 'A'; p[k++] = 'V';
    p[k] = 0;
}

static int put_int(char *o, int32_t v)
{
    char t[12];
    int n = 0, k = 0;
    uint32_t u = v < 0 ? (uint32_t)(-(int64_t)v) : (uint32_t)v;
    do { t[n++] = (char)('0' + u % 10u); u /= 10u; } while (u);
    if (v < 0) o[k++] = '-';
    while (n) o[k++] = t[--n];
    return k;
}

int vpys_write(const char *name)
{
    char path[24], buf[512];
    int n = 0;
    for (int i = 0; i < s_top; i++) {
        if (n + 13 > (int)sizeof buf) return 0;       /* would not fit the writer's sector */
        n += put_int(buf + n, s_save[i]);
        buf[n++] = '\n';
    }
    path_of(path, name);
    if (uvm2_sd_overwrite(path, (const unsigned char *)buf, (uint32_t)n)) return 1;
    if (uvm2_sd_error != UVM2_SD_MISSING && uvm2_sd_error != UVM2_SD_TOO_BIG) return 0;
    return uvm2_sd_create(path, (const unsigned char *)buf, (uint32_t)n);
}

/* The numbers back into the table, in order; how many were read (0: no card, no file). */
int vpys_read(const char *name)
{
    char path[24];
    unsigned char buf[512];
    path_of(path, name);
    uint32_t got = uvm2_sd_read_from(path, buf, sizeof buf, 0);
    int count = 0, neg = 0, in = 0;
    int32_t v = 0;
    for (uint32_t i = 0; i <= got && count < VPYS_N; i++) {
        const int c = i < got ? buf[i] : '\n';
        if (c == '-' && !in) { neg = 1; in = 1; v = 0; }
        else if (c >= '0' && c <= '9') { v = v * 10 + (c - '0'); in = 1; }
        else if (in) {                                   /* the end of a number */
            vpys_set(count++, neg ? -v : v);
            v = 0; neg = 0; in = 0;
        }
    }
    return count;
}
#else
int vpys_write(const char *name) { (void)name; return 0; }
int vpys_read(const char *name) { (void)name; return 0; }
#endif
