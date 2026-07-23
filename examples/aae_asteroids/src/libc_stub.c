/* libc_stub.c — freestanding libc shims for the RP2350 (-nostdlib) AAE build.
 * AAE is written against a hosted libc; the cart has none, so provide the small
 * subset AAE actually uses. malloc is a bump allocator over a static arena
 * (AAE allocates a few fixed buffers at init and never frees). printf/logging
 * are no-ops on the cart. rand() is the same LCG style AAE expects. */
#include <stddef.h>

/* ---- mem/str ---- */
void *memcpy(void *d, const void *s, size_t n) {
    unsigned char *dst = d; const unsigned char *src = s;
    while (n--) *dst++ = *src++;
    return d;
}
void *memset(void *d, int c, size_t n) {
    unsigned char *dst = d;
    while (n--) *dst++ = (unsigned char)c;
    return d;
}
void *memmove(void *d, const void *s, size_t n) {
    unsigned char *dst = d; const unsigned char *src = s;
    if (dst < src) while (n--) *dst++ = *src++;
    else { dst += n; src += n; while (n--) *--dst = *--src; }
    return d;
}
int memcmp(const void *a, const void *b, size_t n) {
    const unsigned char *x = a, *y = b;
    while (n--) { if (*x != *y) return *x - *y; x++; y++; }
    return 0;
}
size_t strlen(const char *s) { size_t n = 0; while (s[n]) n++; return n; }
int strcmp(const char *a, const char *b) {
    while (*a && *a == *b) { a++; b++; }
    return (unsigned char)*a - (unsigned char)*b;
}
char *strcpy(char *d, const char *s) { char *r = d; while ((*d++ = *s++)) ; return r; }
char *strncpy(char *d, const char *s, size_t n) {
    char *r = d;
    while (n && (*d = *s)) { d++; s++; n--; }
    while (n--) *d++ = 0;
    return r;
}

/* ---- malloc: bump allocator over a static arena (no free) ---- */
#ifndef AAE_ARENA_BYTES
#define AAE_ARENA_BYTES (48 * 1024)   /* tune once real usage is known */
#endif
static unsigned char s_arena[AAE_ARENA_BYTES] __attribute__((aligned(8)));
static size_t s_arena_used = 0;
void *malloc(size_t n) {
    n = (n + 7u) & ~(size_t)7u;               /* 8-byte align */
    if (s_arena_used + n > sizeof s_arena) return (void *)0;  /* OOM */
    void *p = &s_arena[s_arena_used];
    s_arena_used += n;
    return p;
}
void  free(void *p) { (void)p; }              /* no-op */
void *calloc(size_t n, size_t s) {
    size_t total = n * s;
    void *p = malloc(total);
    if (p) memset(p, 0, total);
    return p;
}

/* ---- misc ---- */
static unsigned int s_rng = 0x12345678u;
int  rand(void) { s_rng = s_rng * 1103515245u + 12345u; return (int)((s_rng >> 16) & 0x7fff); }
void srand(unsigned s) { s_rng = s; }
int  abs(int v)  { return v < 0 ? -v : v; }
long labs(long v){ return v < 0 ? -v : v; }
void exit(int code) { (void)code; for (;;) ; }

/* ---- logging/printf are no-ops on the cart ---- */
void *stderr = 0, *stdout = 0;
int printf(const char *fmt, ...)              { (void)fmt; return 0; }
int sprintf(char *buf, const char *fmt, ...)  { (void)fmt; if (buf) buf[0] = 0; return 0; }
int fprintf(void *f, const char *fmt, ...)    { (void)f; (void)fmt; return 0; }
