/* AAE Tac/Scan on the RP2350 cartridge — entry point (WORK IN PROGRESS).
 *
 * Same AAE-as-a-C-game approach as aae_asteroids, but Tac/Scan is a Sega G80
 * vector game: a Z80 CPU (mz80 core) + Sega's own vector generator (SegaG80.c),
 * not a 6502 + Atari AVG. See docs/AAE_RP2350_PORT.md and [[aae-rp2350-feasibility]].
 *
 * Execution model (from AAE, mapped):
 *   - driver[TACSCAN] (aae_machine.c) holds Tac/Scan's config: CPU_MZ80 @ 3 MHz,
 *     INT_TYPE_INT, 40 fps, VEC_COLOR.
 *   - run_cpus_to_cycles() (cpu_control.c) runs the Z80 for a frame + fires the
 *     40 Hz IRQ; the game writes the vector RAM ($E000-$EFFF) which
 *     BWVectorGenerator()/sega_generate_vector_list() walks → v_directDraw32.
 *   - run_segag80() (SegaG80.c) is per-frame housekeeping (vector gen + sound gate).
 *
 * IMPORTANT: unlike Asteroids (gamenum=0), SegaG80.c switches on gamenum==TACSCAN
 * to pick the Z80 port handlers + security, so aae_machine.c sets gamenum=TACSCAN
 * (the AAE enum) and sizes driver[] to cover that index.
 */

/* AAE externs. */
extern int  init_segag80(void);
extern void run_segag80(void);
extern void run_cpus_to_cycles(void);   /* cpu_control.c */
extern void init_cpu_config(void);      /* cpu_control.c: derive num_cpus + cyclecount */

/* Our machine setup (aae_machine.c). Builds GI[0] (Z80 memory) + GI[1] (xyt
 * PROM / sin table) and copies the embedded ROMs in — must run before init. */
extern void aae_load_tacscan_roms(void);

/* RP2350 SDK shim (sdk_rp2350.c). */
extern void v_init(void);
extern void v_WaitRecal(void);
extern unsigned char v_readButtons(void);
extern void v_readJoystick1Analog(void);

int main(void)
{
    v_init();

    aae_load_tacscan_roms();   /* build GI[0]/GI[1] + copy ROMs (must precede init) */
    init_cpu_config();         /* num_cpus + cyclecount from driver[gamenum]        */
    init_segag80();            /* init Z80 context, port handlers, vector RAM        */

    for (;;) {
        v_WaitRecal();            /* frame pace + zero-ref (shim) */
        v_readButtons();
        v_readJoystick1Analog();
        run_cpus_to_cycles();     /* run the Z80 a frame; fires the 40 Hz IRQ */
        run_segag80();            /* vector generation + per-frame housekeeping */
    }
    return 0;
}
