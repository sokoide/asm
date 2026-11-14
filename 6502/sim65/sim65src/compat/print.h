/* Minimal print.h compat shim for the vendored sim65 build (repo-local). */
#ifndef COMPAT_PRINT_H
#define COMPAT_PRINT_H

#include <stdio.h>

extern int Verbosity;

void Print (FILE* F, unsigned Level, const char* Format, ...);

#endif
