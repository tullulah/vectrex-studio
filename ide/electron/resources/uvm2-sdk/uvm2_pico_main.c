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
#include "uvm2_psram.h"
#ifdef UVM2_PIO_STREAM
#include "uvm2_bus_stream.h"
#endif
#include "uvm2_led.h"

int uvm2_game_main(void);          /* the game's own main(), renamed at compile time */
void uvm2_runtime_init(void);      /* uvm2_svc.c */
void uvm2_romzip_cargar(void);     /* uvm2_romzip.c: lee roms/<juego>.zip de la SD */
#ifdef UVM2_DUAL_CORE
void uvm2_core1_start(void);       /* uvm2_core1.c */
#endif

/* EL PANICO, SIN printf DE POR MEDIO.
 *
 * El panic del SDK imprime el motivo, y aqui imprimir es peor que inutil: no hay consola
 * y la propia vsnprintf se sale de la pila (medido: BFAR = 0x20082000, el techo justo de
 * la SRAM), asi que el fallo que se ve es el del MENSAJERO y el motivo se pierde.
 *
 * Definiendo PICO_PANIC_FUNCTION=uvm2_panic_stash, `panic` pasa a ser un reenvio que llama
 * aqui con el mensaje en r0. Guardamos el puntero y paramos. El texto se resuelve despues
 * en el ELF, que es donde vive.
 *
 *   0x20080230  marca 0x9A91C000
 *   0x20080234  puntero al formato (a .rodata del payload)
 */
void __attribute__((noreturn)) uvm2_panic_stash(const char *fmt, ...);
void uvm2_panic_stash(const char *fmt, ...)
{
    volatile unsigned *g = (volatile unsigned *)0x20080230u;
    g[0] = 0x9A91C000u;
    g[1] = (unsigned)fmt;
    for (;;) { }
}

#ifdef UVM2_PSRAM_IMAGE
/* NUESTRO reset de arranque, en vez del del SDK (que es __weak).
 *
 * EL PROBLEMA: el chip select de la PSRAM del UVM2 no es un pin del bus QSPI, es un GPIO
 * DEL BANCO 0 (uvm2_psram.c: configure_cs1_pad escribe en pads_bank0/io_bank0). El
 * runtime_init_early_resets del SDK resetea IO_BANK0 y PADS_BANK0, con lo que borra esa
 * configuracion y el chip —del que estamos ejecutando— deja de contestar.
 *
 * Desactivar el paso entero (PICO_RUNTIME_SKIP_INIT_EARLY_RESETS) arranca, pero deja los
 * perifericos como los dejo el CARGADOR en vez de en un estado conocido, y se nota:
 * mandos que no responden y temblor. Asi que hacemos lo mismo que el SDK con dos bits
 * menos.
 *
 * Mascaras copiadas del propio SDK (0xEFEF3B7F asertar / 0x03F3FFF6 liberar) quitando los
 * bits 6 (IO_BANK0) y 9 (PADS_BANK0), leidos de resets.h y no de memoria. */
void runtime_init_early_resets(void)
{
    volatile unsigned *set   = (volatile unsigned *)(0x40020000u + 0x2000u);
    volatile unsigned *clr   = (volatile unsigned *)(0x40020000u + 0x3000u);
    volatile unsigned *hecho = (volatile unsigned *)(0x40020000u + 0x0008u);
    const unsigned banco0 = (1u << 6) | (1u << 9);      /* IO_BANK0 | PADS_BANK0 */
    const unsigned asertar = 0xEFEF3B7Fu & ~banco0;
    const unsigned liberar = 0x03F3FFF6u & ~banco0;

    *set = asertar;
    *clr = liberar;
    while ((*hecho & liberar) != liberar) { }
}
#endif

int uvm2_psram_listo = -1;   /* 1 = la PSRAM contesto, 0 = no, -1 = ni se intento */

int main(void)
{
#ifndef UVM2_STEP_OWNS_INIT
    uvm2_runtime_init();
    /* Con el bus ya tomado: 256 periodos de E, unos 170 us. Deja en
     * uvm2_ciclos_por_e_q8 la relacion reloj/E, que es lo que decide si la calibracion
     * de fase del stream por PIO vale en esta placa. */
    uvm2_medir_e();
#ifdef UVM2_PIO_STREAM
    /* Despues de medir E y con el bus ya tomado: la SM sincroniza contra ~E, asi que no
     * tiene sentido arrancarla antes de que el reloj este ahi. */
    uvm2_stream_start();
#endif
#  ifdef UVM2_CMDS_IN_PSRAM
    /* LA PSRAM, ANTES DE QUE NADIE EMITA UN COMANDO, y despues de uvm2_runtime_init.
     *
     * Ese orden no es cosmetico: el chip select de la PSRAM del UVM2 es un GPIO del banco
     * 0, y runtime_init_early_resets resetea IO_BANK0 y PADS_BANK0. Configurarla antes es
     * configurarla para que la borren — la averia que costo el cargador de dos etapas.
     *
     * Y va AQUI y no en uvm2_bus_init() porque en el camino del pico-sdk esa funcion NO
     * SE LLAMA: main() invoca los tres pasos por separado. Ponerla alli compilaba, no
     * enlazaba nada y dejaba la PSRAM sin inicializar; el sintoma fue una lista de
     * comandos que se leia entera a cero, o sea pantalla negra con el contador de frames
     * subiendo. Se vio comparando commands con bus_cycles: 1 ciclo por comando en vez de
     * ~7, porque un comando a cero no lleva retardo. */
    /* PRIMERO LOS PINES DEL BUS QSPI, que no son nuestros todavia.
     *
     * El lanzador de Ralf no salta al modulo: reinicia por la bootrom con RAM_IMAGE. Y la
     * bootrom, sabiendo que no va a ejecutar desde flash, deja los seis pines del QSPI en
     * FUNCSEL = NULL. El QMI acepta las transferencias, BUSY se comporta, CS se mueve — y
     * no conduce ni un pin. Dos semanas de "el chip esta muerto" fueron esto. */
    uvm2_qmi_levantar();
    uvm2_psram_listo = uvm2_psram_init();
#  endif
    /* El romset, ANTES del juego: su main() llama a aae_load_roms() de lo primero. En el
     * cartucho propio esto lo hace el firmware; aqui el UVM2 no lo hace y hay que leerlo
     * nosotros. Si falla, el juego pinta su cartel de "sin romset" y no se cuelga. */
    uvm2_romzip_cargar();
#  ifdef UVM2_DUAL_CORE
    /* After the runtime init, never before: core 1 takes the bus from here on,
     * and it must not start until the VIA has been programmed and the 6809 is
     * halted. */
    uvm2_core1_start();
#  endif
#endif
    /* UVM2_STEP_OWNS_INIT: a diagnostic image that brings the machine up itself,
     * one stage at a time. Calling runtime_init here would do every stage before
     * it ever got a say. */
    return uvm2_game_main();
}
