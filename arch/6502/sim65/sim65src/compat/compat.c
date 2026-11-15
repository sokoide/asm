/* Compat implementations for the vendored sim65 build (repo-local). */
#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include "cmdline.h"
#include "print.h"
#include "xmalloc.h"

unsigned        ArgCount = 0;
const char**    ArgVec   = 0;
unsigned char   ArgStart = 0;

int Verbosity = 0;

void Print (FILE* F, unsigned Level, const char* Format, ...)
{
    if (Level <= (unsigned) Verbosity) {
        va_list Ap;
        va_start (Ap, Format);
        vfprintf (F, Format, Ap);
        va_end (Ap);
    }
}

void xfree (void* Block)
{
    free (Block);
}

void* xmalloc (size_t Size)
{
    void* P = malloc (Size);
    if (P == 0) {
        fprintf (stderr, "sim65i: out of memory\n");
        exit (EXIT_FAILURE);
    }
    return P;
}
