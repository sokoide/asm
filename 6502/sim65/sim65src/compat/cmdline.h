/* Minimal cmdline.h compat shim for the vendored sim65 build (repo-local).
   Replaces the cc65 common/ library: argument passing into PVArgs only. */
#ifndef COMPAT_CMDLINE_H
#define COMPAT_CMDLINE_H

extern unsigned        ArgCount;  /* total argument count */
extern const char**    ArgVec;    /* argument vector */

#endif
