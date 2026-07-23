/* aae_stubs.c — no-op stubs for AAE subsystems Asteroids never exercises.
 *
 * Asteroids runs a single CPU_6502Z (see the driver row in aae_machine.c), so
 * the Z80 (mz80*) and 68000 (musashi m68k_*) cores are referenced by AAE's
 * generic cpu_control/cpuintrf dispatch but never actually entered. Sound
 * (Pokey) and logging are likewise not wired on the cart. These definitions
 * exist only to satisfy the link; the linker matches by name, so plain
 * signatures are fine (no AAE headers included -> no declaration conflicts).
 */

/* ---- Z80 core (unused by Asteroids) ---- */
unsigned mz80exec(unsigned n)            { (void)n; return 0; }
unsigned mz80GetElapsedTicks(unsigned n) { (void)n; return 0; }
void     mz80GetContext(void *p)         { (void)p; }
void     mz80SetContext(void *p)         { (void)p; }
void     mz80reset(void)                 { }
unsigned mz80int(unsigned v)             { (void)v; return 0; }
unsigned mz80nmi(void)                   { return 0; }

/* ---- 68000 core / musashi (unused by Asteroids) ---- */
void m68k_pulse_reset(void)              { }
int  m68k_execute(int n)                 { (void)n; return 0; }
int  m68k_cycles_run(void)               { return 0; }
void m68k_end_timeslice(void)            { }
void m68k_set_irq(unsigned int level)    { (void)level; }

/* ---- sound (Pokey) — not wired on the cart yet ---- */
void pokey_sh_update(void)               { }

/* ---- logging — no-op on the cart ---- */
int log_it(char *fmt, ...)               { (void)fmt; return 0; }

/* ---- high-score EEROM save (loaders.c) — no persistent storage on the cart ---- */
int save_hi_aae(int start, int size, int image) { (void)start; (void)size; (void)image; return 0; }
