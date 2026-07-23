#ifndef _AAE_STDLIB_H
#define _AAE_STDLIB_H
#include <stddef.h>
void *malloc(size_t n);
void  free(void *p);
void *calloc(size_t n, size_t s);
int   rand(void);
void  srand(unsigned s);
int   abs(int v);
long  labs(long v);
void  exit(int code);
#endif
