/* rp2350_game_sram.ld — el juego en la SRAM interna del cartucho de Vectrex Studio.
 *
 * Codigo, rodata y .data en 0x20040000 y el .bss en la PSRAM: el hueco de 220 KB entre el .bss
 * de la BIOS y la pila del juego (0x20077000). La BIOS ve por la cabecera que el punto de
 * entrada cae en ese rango, copia el .bin de la PSRAM a la SRAM y arranca alli (sd.rs,
 * GAME_SRAM_ADDR). Para lo que quepa: la PSRAM va por QSPI con una cache XIP de 16 KB y un
 * interprete con sus tablas no cabe en ella (aae_esb a 1 fps, 2026-09-16). */
MEMORY {
    GAME_RAM (rwx) : ORIGIN = 0x20040000, LENGTH = 220K
    /* El .bss (memoria emulada, tablas de despacho) sigue en la PSRAM: es lo que no cabe.
     * Empieza pasado el .bin crudo que el cargador deja en 0x11000000 (no hace falta, pero
     * asi el cero inicial no pisa nada que aun se este leyendo). */
    GAME_BSS (rw)  : ORIGIN = 0x11080000, LENGTH = 7168K
}

ENTRY(game_main)

SECTIONS {
    .game_rom 0x20040000 : {
        KEEP(*(.game_rom))
        *(.text)
        *(.text.*)
        *(.rodata)
        *(.rodata.*)

        /* C++ static constructors. A freestanding image has no C runtime to run
         * these, so rp2350_start.s walks the array before main(). Without it a
         * C++ game whose globals have constructors starts with them unbuilt —
         * it links and boots, then misbehaves far from the cause. KEEP, or
         * --gc-sections drops the array entirely. */
        . = ALIGN(4);
        __init_array_start = .;
        KEEP(*(SORT_BY_INIT_PRIORITY(.init_array.*)))
        KEEP(*(.init_array))
        __init_array_end = .;
        . = ALIGN(4);
    } > GAME_RAM

    .data : {
        *(.data)
        *(.data.*)
        . = ALIGN(4);
    } > GAME_RAM

    .bss : {
        _bss_start = .;
        *(.bss)
        *(.bss.*)
        *(COMMON)
        . = ALIGN(4);
        _bss_end = .;
    } > GAME_BSS

    /* Tabla de unwind VACIA, pero con sus simbolos.
     *
     * Las secciones se descartan (abajo) porque un programa freestanding no desenrolla
     * nada, pero el unwinder de libgcc referencia __exidx_start/__exidx_end igualmente si
     * algo lo arrastra. Los juegos que enlazan con -nostdlib nunca lo ven; dkong usa
     * --specs=nosys.specs y ahi si aparece: "undefined reference to __exidx_start" al
     * añadirle el cargador de ROM. Declararlos vacios es la solucion estandar: el
     * unwinder encuentra una tabla de cero entradas y no desenrolla, que es lo correcto.
     * PROVIDE para no pisar a nadie que los defina por su cuenta. */
    PROVIDE(__exidx_start = .);
    PROVIDE(__exidx_end   = .);

    /DISCARD/ : {
        *(.ARM.exidx*)
        *(.ARM.extab*)
    }
}
