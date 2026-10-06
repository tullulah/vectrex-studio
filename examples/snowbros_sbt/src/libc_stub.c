/* libc_stub.c — the handful of libc symbols the RP2350 cartridge build needs and
 * newlib cannot give it.
 *
 * ONLY FOR THE CARTRIDGE (`make rp2350`). uvm2.mk drops this file from the .um2
 * build by name (UVM2_SRCS_DROP): that path links through the pico-sdk, which
 * brings a full crt0, and these definitions would collide with the real ones.
 *
 * WHY IT IS SO SHORT. The cartridge links --specs=nosys.specs, i.e. against real
 * newlib, so setjmp/longjmp (Musashi traps bus errors with them), sscanf, strchr
 * and friends are the genuine articles. What newlib does NOT have is the end of
 * a program that never ends:
 *
 *   exit()  Musashi's m68kfpu.c calls exit(1) on an unimplemented FPU op. Pulling
 *           newlib's exit drags __libc_fini_array in, which references `_fini` —
 *           a symbol only a hosted crt0 provides, so the link dies with
 *           "undefined reference to _fini" from inside libc, a message that says
 *           nothing about the game. There is nowhere to exit TO on a cartridge:
 *           spin, and leave the last frame on the screen.
 */

void exit(int code)   { (void)code; for (;;) { } }
void _exit(int code)  { (void)code; for (;;) { } }
void abort(void)      { for (;;) { } }
