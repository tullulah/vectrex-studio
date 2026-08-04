/* uvm2_pico_main.c — the seam between the pico-sdk runtime and a UVM2 game.
 *
 * With uvm2_start.s we owned the entry: it built the vector table, cleared .bss,
 * ran the C++ constructors, called uvm2_runtime_init() and then main(). The
 * pico-sdk crt0 now does all of that EXCEPT the last two — it hands us a fully
 * initialised C environment and calls main().
 *
 * So main() here is ours: bring the Vectrex side up, then run the game. The game
 * keeps its own `main` and is compiled with -Dmain=uvm2_game_main, which is a
 * rename rather than an edit — none of the ~45 game sources change.
 *
 * Why the runtime init cannot simply live inside each game: it must run before
 * ANY C touches the bus or the LED, and it is where a switched-off console is
 * detected (uvm2_clock_calibrate). Keeping it here means one place gets it right.
 */
#include "uvm2_bus.h"
#include "uvm2_led.h"

int uvm2_game_main(void);          /* the game's own main(), renamed at compile time */
void uvm2_runtime_init(void);      /* uvm2_svc.c */

int main(void)
{
#ifndef UVM2_STEP_OWNS_INIT
    uvm2_runtime_init();
#endif
    /* UVM2_STEP_OWNS_INIT: a diagnostic image that brings the machine up itself,
     * one stage at a time. Calling runtime_init here would do every stage before
     * it ever got a say. */
    return uvm2_game_main();
}
