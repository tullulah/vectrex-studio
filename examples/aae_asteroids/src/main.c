/* AAE Asteroids on the RP2350 cartridge — entry point (WORK IN PROGRESS).
 *
 * Approach (validated): AAE is compiled as a C game against the RP2350 SDK shim
 * (ide/electron/resources/rp2350-sdk/sdk_rp2350.c). AAE already draws through
 * `v_directDraw32`, which the shim provides (mapping to the BIOS svc draw path
 * with our per-path re-zero + MAX_CONSECUTIVE_DRAWS cap), so NO video
 * re-targeting is needed. Input goes through v_readButtons / v_readJoystick1Analog.
 *
 * Execution model (from AAE, mapped):
 *   - driver[] (aaemain.c) holds Asteroids' config: CPU_6502Z @ 1.512 MHz, NMI.
 *   - run_cpus_to_cycles() (cpu_control.c) runs the 6502 for a frame + fires the
 *     interrupt; the game's write to the DVG-GO register (0x3000) triggers
 *     dvg_generate_vector_list() (asteroid.c) → v_directDraw32 per segment.
 *   - run_asteroids() (asteroid.c) is per-frame housekeeping (watchdog, sound gate).
 *
 * TODO (the remaining build grind — see docs/AAE_RP2350_PORT.md):
 *   1. Provide/trim the AAE globals `run_cpus_to_cycles` needs: gamenum,
 *      driver[ASTEROID] entry, num_cpus, cyclecount[], running_cpu, tickcount[].
 *      Either include a trimmed aaemain.c (Asteroids driver row only) or set them
 *      up here directly.
 *   2. Replace load_roms(): copy the embedded asteroid_roms.h arrays into 6502
 *      memory at the addresses in AAE gameroms.h, then call init_asteroid().
 *   3. Coordinate scale: AAE emits large coords (e.g. x-17000); pick VPY_SCALE
 *      (or pre-scale in v_directDraw32) so the image fits the Vectrex ±127 field.
 *   4. Link RAM (rp2350_game_ram.ld, 'VPy2' header) and confirm it fits 252 KB.
 */

/* AAE externs (declared in its headers, resolved via -I<AAE>). */
extern int  init_asteroid(void);
extern void run_asteroids(void);
extern void run_cpus_to_cycles(void);   /* cpu_control.c */
extern int  gamenum;                    /* set to ASTEROID before init */

/* RP2350 SDK shim (sdk_rp2350.c). */
extern void v_init(void);
extern void v_WaitRecal(void);
extern unsigned char v_readButtons(void);
extern void v_readJoystick1Analog(void);

/* libvpy game entry: the BIOS jumps here after loading us at 0x20040000. */
void game_main(void)
{
    v_init();

    /* TODO(1,2): set up the Asteroids machine (driver row, cyclecount, ROMs)
     * then init_asteroid(). Placeholder call so the structure is visible. */
    init_asteroid();

    for (;;) {
        v_WaitRecal();            /* frame pace + zero-ref (shim) */
        v_readButtons();
        v_readJoystick1Analog();
        run_cpus_to_cycles();     /* run the 6502 a frame; DVG-GO draws vectors */
        run_asteroids();          /* per-frame housekeeping */
    }
}
