/* PiTrex standalone — game cargado por Pi Zero bootloader en 0x8000
   Copiar resultado a SD como kernel.img */
ENTRY(_start)
SECTIONS {
    . = 0x8000;
    .text   : { *(.text .text*) }
    .rodata : { *(.rodata .rodata*) }
    .data   : { *(.data .data*) }
    .bss    : {
        __bss_start = .;
        __bss_start__ = .;
        *(.bss .bss*) *(COMMON)
        __bss_end = .;
        __bss_end__ = .;
    }
    _end = .;
    /DISCARD/ : { *(.ARM.exidx*) *(.ARM.extab*) }
}
heap_low  = 0x2000000;
heap_top  = 0x3f00000;
