/*****************************************************************************/
/*                                                                           */
/*                                debugger.h                                 */
/*                                                                           */
/*           Interactive step debugger for the vendored sim65 (sim65i)       */
/*                                                                           */
/*                                                                           */
/*  This software is provided 'as-is', without any expressed or implied      */
/*  warranty.  In no event will the authors be held liable for any damages   */
/*  arising from the use of this software.                                   */
/*                                                                           */
/*  Permission is granted to anyone to use this software for any purpose,    */
/*  including commercial applications, and to alter and redistribute it      */
/*  freely, subject to the following restrictions:                           */
/*                                                                           */
/*  1. The origin of this software must not be misrepresented; you must not  */
/*     claim that you wrote the original software. If you use this software  */
/*     in a product, an acknowledgment of the product documentation would be */
/*     appreciated but is not required.                                      */
/*  2. Altered source versions must be plainly marked as such, and must not  */
/*     be misrepresented as being the original software.                     */
/*  3. This notice may not be removed or altered from any source             */
/*     distribution.                                                         */
/*                                                                           */
/*****************************************************************************/



#ifndef DEBUGGER_H
#define DEBUGGER_H



#include <stdint.h>



/*****************************************************************************/
/*                                   Data                                    */
/*****************************************************************************/



/* Nonzero while the interactive debugger owns the run loop. Read by
** error.c (SimExit) and paravirt.c (PVRead) to divert to the debugger.
*/
extern int DebuggerActive;

/* Exit code passed by the guest program via PVExit, or -1 while running. */
extern int DbgExitCode;



/*****************************************************************************/
/*                                   Code                                    */
/*****************************************************************************/



void DebuggerRun (unsigned long long MaxCycles, uint8_t SPAddr);
/* Run the interactive step debugger until quit, EOF or program exit. */

int DbgConsoleRead (unsigned char* Buf, unsigned Count);
/* Serve a guest stdin read (PVRead on fd 0) from the console line reader
** shared with the debugger REPL. Returns the number of bytes served; a
** short read (up to the end of one line) is valid.
*/



/* End of debugger.h */

#endif
