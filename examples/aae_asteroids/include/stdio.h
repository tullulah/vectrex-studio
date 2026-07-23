#ifndef _AAE_STDIO_H
#define _AAE_STDIO_H
typedef void FILE;            /* logging is a no-op on the cart */
extern FILE *stderr, *stdout;
int printf(const char *fmt, ...);
int sprintf(char *buf, const char *fmt, ...);
int fprintf(FILE *f, const char *fmt, ...);
#endif
