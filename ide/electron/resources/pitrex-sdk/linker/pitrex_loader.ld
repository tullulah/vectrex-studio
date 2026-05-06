/* PiTrex loader mode — cargado por piTrexBoot en 0x4000000
   Copiar a piZero1/<nombre>.img */
ENTRY(_start)
SECTIONS {
    . = 0x4000000;
    .text   : { *(.text .text*) }
    .rodata : { *(.rodata .rodata*) }
    .data   : { *(.data .data*) }
    .bss    : {
        __bss_start = .;
        *(.bss .bss*) *(COMMON)
        __bss_end = .;
    }
    /DISCARD/ : { *(.ARM.exidx*) *(.ARM.extab*) }
}
heap_low  = 0x5000000;
heap_top  = 0xfffffff;
