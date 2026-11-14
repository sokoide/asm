/* Minimal xmalloc.h compat shim for the vendored sim65 build (repo-local). */
#ifndef COMPAT_XMALLOC_H
#define COMPAT_XMALLOC_H

void* xmalloc (size_t Size);
void  xfree (void* Block);

#endif
