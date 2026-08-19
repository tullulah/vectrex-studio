/* memmap_psram.ld — EXPERIMENTO: enlazar la imagen del UVM2 en la PSRAM EXTERNA.
 *
 * Copia literal de memmap_no_flash.ld del pico-sdk (rp2350) con UNA sola linea
 * cambiada: la region RAM pasa de 0x20000000/256k a 0x11000000/8192k. Todo lo demas
 * —IMAGE_DEF, tabla de vectores, orden de secciones, los scratch banks— se conserva,
 * que es el motivo de copiar en vez de escribir uno nuevo.
 *
 * LA PREGUNTA QUE RESPONDE: el cargador del multicart de Ralf lee la direccion de la
 * cabecera .um2 y copia ahi. ¿Honra una direccion en la PSRAM? Nuestra sonda midio esa
 * PSRAM MUDA, pero la midio desde DENTRO de un juego ya cargado: si su firmware la
 * inicializa solo cuando la necesita, esa medida no lo habria visto. La unica forma de
 * saberlo es pedirle que cargue ahi.
 *
 * Los scratch banks se quedan en la SRAM interna a proposito: son del RP2350, no del
 * chip externo.
 */
/* Based on GCC ARM embedded samples.
   Defines the following symbols for use by code:
    __exidx_start
    __exidx_end
    __etext
    __data_start__
    __preinit_array_start
    __preinit_array_end
    __init_array_start
    __init_array_end
    __fini_array_start
    __fini_array_end
    __data_end__
    __bss_start__
    __bss_end__
    __end__
    end
    __HeapLimit
    __StackLimit
    __StackTop
    __stack (== StackTop)
*/

MEMORY
{
    RAM(rwx) : ORIGIN =  0x11000000, LENGTH = 8192k
    /* LOS DATOS ESCRIBIBLES NO VAN EN LA PSRAM.
     *
     * Con .data y .bss ahi, el crt0 arranca poniendo a cero decenas de KB de PSRAM POR LA
     * CACHE mientras busca sus propias instrucciones en ese mismo chip. Medido: tras ese
     * borrado la PSRAM deja de contestar a las lecturas (devuelve un patron periodico
     * 00/CC8C/8888), runtime_run_initializers se come un cero de su tabla, hace `blx 0` y
     * salta a la direccion cero — HardFault con INVSTATE. Ese era el "PC 11000199 y luego
     * negro" de toda la tarde.
     *
     * DONDE EMPIEZA ESTA REGION IMPORTA. El cargador sigue residente en la parte baja de
     * la SRAM y lleva el payload EMPOTRADO dentro: con 280 KB de juego, su imagen llega
     * hasta ~0x20049000. Si .data cayera en 0x20040000, el cargador se estaria pisando a si
     * mismo mientras copia — leyendo de un array que acaba de machacar.
     *
     * 0x20060000 deja 384 KB para el cargador y 128 KB aqui, y por arriba se para en
     * 0x20080000, donde empiezan los scratch y la pila. */
    SRAM(rwx) : ORIGIN = 0x20060000, LENGTH = 128k
    /* .bss VUELVE A PSRAM, y .data se queda en SRAM. Ojo con el porque, que cambio.
     *
     * Anoche mande .bss a SRAM creyendo que el borrado del crt0 —decenas de KB escritos en
     * el chip del que se ejecuta— era lo que dejaba muda la PSRAM. Despues resulto que la
     * causa era OTRA: el chip select es un GPIO del banco 0 y runtime_init_early_resets lo
     * borraba. Corregido eso, el .bss en PSRAM no tiene por que molestar; ayudaba solo
     * porque reducia el trafico y asi tardaba mas en notarse.
     *
     * Y no es opcional: el .bss de aztarac son ~830 KB. En los 520 KB de SRAM del RP2350 no
     * cabe de ninguna manera ("region SRAM overflowed by 576712 bytes"), asi que para los
     * juegos que motivaron todo esto la unica opcion es la PSRAM.
     *
     * .data SI se queda en SRAM, y esa razon no ha cambiado: los mutex del SDK se toman con
     * ldaexb/strexb y los accesos exclusivos NO funcionan sobre memoria XIP.
     *
     * OJO CON QUE SE MUEVE AQUI Y QUE NO.
     *
     * .bss SI: el crt0 lo pone a cero el mismo, no lo copia de ningun sitio.
     * .data NO: el crt0 de una imagen `no_flash` NO TIENE bucle de copia — va del CPUID
     * al borrado del .bss y de ahi a platform_entry, porque da por hecho que quien cargo
     * la imagen ya dejo los datos en su direccion final. Ponerla en SRAM la deja sin
     * nadie que la traiga: la tabla de inicializadores vive dentro de .data, se leyo
     * memoria sin estrenar, y `blx` salto a una direccion inventada (CFSR=0x100,
     * IBUSERR). Comprobado: 0x20040000 contenia 31F1080A FE3BB809 ... o sea ruido.
     * Y ese dia llego: .data VUELVE a SRAM, y la copia la hace el CARGADOR con las
     * direcciones que empotrar.py saca del ELF.
     *
     * Hace falta porque los mutex del SDK viven en .data y se toman con accesos
     * EXCLUSIVOS (ldaexb/strexb). Los monitores exclusivos no funcionan sobre memoria
     * mapeada por XIP: el strexb falla siempre y el bucle no sale nunca. Medido: asteroids
     * girando para siempre en 0x11000292, dentro de mutex_try_enter_block_until, sin fallo
     * ni excepcion — IPSR=0, simplemente atascado. */
    SCRATCH_X(rwx) : ORIGIN = 0x20080000, LENGTH = 4k
    SCRATCH_Y(rwx) : ORIGIN = 0x20081000, LENGTH = 4k
}

ENTRY(_entry_point)

SECTIONS
{
    /* Note unlike RP2040, we start the image with a vector table even for
       NO_FLASH builds. On Arm, the bootrom expects a VT at the start of the
       image by default; on RISC-V, the default is to enter the image at its
       lowest address, so an IMAGE_DEF item is required to specify the
       nondefault entry point. */

    .text : {
        __logical_binary_start = .;
        /* Vectors require 512-byte alignment on v8-M when >48 IRQs are used,
           so we would waste RAM if the vector table were not at the
           start. */
        KEEP (*(.vectors))
        KEEP (*(.binary_info_header))
        __binary_info_header_end = .;
        KEEP (*(.embedded_block))
        __embedded_block_end = .;
        __reset_start = .;
        KEEP (*(.reset))
        __reset_end = .;
        /* Los tres ficheros del camino caliente se EXCLUYEN aqui y se recogen abajo, en
         * .data, que vive en SRAM. Si no se excluyen, esta regla generica se los queda. */
        *(EXCLUDE_FILE(*uvm2_bus.c.obj *uvm2_draw.c.obj *uvm2_svc.c.obj *uvm2_svc_entry.s.obj) .text*)
        . = ALIGN(4);
        *(.init)
        *(.fini)
        /* Pull all c'tors into .text */
        *crtbegin.o(.ctors)
        *crtbegin?.o(.ctors)
        *(EXCLUDE_FILE(*crtend?.o *crtend.o) .ctors)
        *(SORT(.ctors.*))
        *(.ctors)
        /* Followed by destructors */
        *crtbegin.o(.dtors)
        *crtbegin?.o(.dtors)
        *(EXCLUDE_FILE(*crtend?.o *crtend.o) .dtors)
        *(SORT(.dtors.*))
        *(.dtors)

        *(.eh_frame*)
    } > RAM

    .rodata : {
        . = ALIGN(4);
        *(.rodata*)
        *(.srodata*)
        . = ALIGN(4);
        *(SORT_BY_ALIGNMENT(SORT_BY_NAME(.flashdata*)))
        . = ALIGN(4);
    } > RAM

    .ARM.extab :
    {
        *(.ARM.extab* .gnu.linkonce.armextab.*)
    } > RAM

    __exidx_start = .;
    .ARM.exidx :
    {
        *(.ARM.exidx* .gnu.linkonce.armexidx.*)
    } > RAM
    __exidx_end = .;

    /* Machine inspectable binary information */
    . = ALIGN(4);
    __binary_info_start = .;
    .binary_info :
    {
        KEEP(*(.binary_info.keep.*))
        *(.binary_info.*)
    } > RAM
    __binary_info_end = .;
    . = ALIGN(4);

    .data : {
        __data_start__ = .;
        /* EL CAMINO CALIENTE DEL BUS, EN SRAM.
         *
         * Vive aqui —no en .text, que esta en PSRAM— porque el ejecutor escribe UNA vez por
         * periodo de E, y un fallo de cache en mitad de esa ventana hace que la escritura
         * caiga en el periodo siguiente: el trazo sale con la rampa equivocada. Eso se ve
         * como temblor y algun vector suelto muy brillante, y NO aparece en los contadores
         * — medido con asteroids desde PSRAM: bus_cycles 11745 de 30000, dropped 0,
         * overrun 13 de 3677 frames. Sobra tiempo; lo que falla es CUANDO cae cada
         * escritura, no cuantas hay.
         *
         * Al estar dentro de .data, viaja en la imagen (AT> RAM) y lo copia el cargador. */
        *(.time_critical*)
        /* Y los tres ficheros enteros. Marcar solo uvm2_exec quito el vector brillante pero
         * el temblor seguia: entre trazo y trazo tambien corren la capa de dibujo y el
         * manejador de svc que cierra el frame, y desde PSRAM cada fallo de cache mueve el
         * momento en que caen las escrituras. */
        *uvm2_bus.c.obj(.text*)
        *uvm2_draw.c.obj(.text*)
        *uvm2_svc.c.obj(.text*)
        /* El manejador de svc esta en ENSAMBLADOR, no en el .c del mismo nombre. */
        *uvm2_svc_entry.s.obj(.text*)
        . = ALIGN(4);
        *(vtable)
        *(.data*)
        *(.sdata*)

        . = ALIGN(4);
        *(.after_data.*)
        . = ALIGN(4);
        /* preinit data */
        PROVIDE_HIDDEN (__mutex_array_start = .);
        KEEP(*(SORT(.mutex_array.*)))
        KEEP(*(.mutex_array))
        PROVIDE_HIDDEN (__mutex_array_end = .);

        . = ALIGN(4);
        /* preinit data */
        PROVIDE_HIDDEN (__preinit_array_start = .);
        KEEP(*(SORT(.preinit_array.*)))
        KEEP(*(.preinit_array))
        PROVIDE_HIDDEN (__preinit_array_end = .);

        . = ALIGN(4);
        /* init data */
        PROVIDE_HIDDEN (__init_array_start = .);
        KEEP(*(SORT(.init_array.*)))
        KEEP(*(.init_array))
        PROVIDE_HIDDEN (__init_array_end = .);

        . = ALIGN(4);
        /* finit data */
        PROVIDE_HIDDEN (__fini_array_start = .);
        *(SORT(.fini_array.*))
        *(.fini_array)
        PROVIDE_HIDDEN (__fini_array_end = .);

        *(.jcr)
        . = ALIGN(4);
   } > SRAM AT> RAM

    .tdata : {
        . = ALIGN(4);
		*(.tdata .tdata.* .gnu.linkonce.td.*)
        /* All data end */
        __tdata_end = .;
    } > SRAM AT> RAM
    PROVIDE(__data_end__ = .);

    .uninitialized_data (NOLOAD): {
        . = ALIGN(4);
        *(.uninitialized_data*)
    } > RAM
    /* __etext is (for backwards compatibility) the name of the .data init source pointer (...) */
    __etext = LOADADDR(.data);

    .tbss (NOLOAD) : {
        . = ALIGN(4);
        __bss_start__ = .;
        __tls_base = .;
        *(.tbss .tbss.* .gnu.linkonce.tb.*)
        *(.tcommon)

        __tls_end = .;
    } > RAM

    .bss (NOLOAD) : {
        . = ALIGN(4);
        __tbss_end = .;

        *(SORT_BY_ALIGNMENT(SORT_BY_NAME(.bss*)))
        *(COMMON)
        PROVIDE(__global_pointer$ = . + 2K);
        *(.sbss*)
        . = ALIGN(4);
        __bss_end__ = .;
    } > RAM

    .heap (NOLOAD):
    {
        __end__ = .;
        end = __end__;
        KEEP(*(.heap*))
    } > RAM
    /* historically on GCC sbrk was growing past __HeapLimit to __StackLimit, however
       to be more compatible, we now set __HeapLimit explicitly to where the end of the heap is */
    /* El monton y la pila viven en SRAM desde que .data/.bss se mudaron; calcular estos
     * limites sobre RAM (la PSRAM) dejaba __StackLimit en 0x11800000, o sea apuntando a
     * otro chip. No provoca fallo por si solo —_entry_point pone MSPLIM a 0— pero es un
     * numero mentiroso esperando a que alguien lo use. */
    __HeapLimit = ORIGIN(SRAM) + LENGTH(SRAM);

    /* Start and end symbols must be word-aligned */
    .scratch_x : {
        __scratch_x_start__ = .;
        *(.scratch_x.*)
        . = ALIGN(4);
        __scratch_x_end__ = .;
    } > SCRATCH_X
    __scratch_x_source__ = LOADADDR(.scratch_x);

    .scratch_y : {
        __scratch_y_start__ = .;
        *(.scratch_y.*)
        . = ALIGN(4);
        __scratch_y_end__ = .;
    } > SCRATCH_Y
    __scratch_y_source__ = LOADADDR(.scratch_y);

    /* .stack*_dummy section doesn't contains any symbols. It is only
     * used for linker to calculate size of stack sections, and assign
     * values to stack symbols later
     *
     * stack1 section may be empty/missing if platform_launch_core1 is not used */

    /* by default we put core 0 stack at the end of scratch Y, so that if core 1
     * stack is not used then all of SCRATCH_X is free.
     */
    .stack1_dummy (NOLOAD):
    {
        *(.stack1*)
    } > SCRATCH_X
    .stack_dummy (NOLOAD):
    {
        KEEP(*(.stack*))
    } > SCRATCH_Y

    /* stack limit is poorly named, but historically is maximum heap ptr */
    __StackLimit = __StackBottom;
    __StackOneTop = ORIGIN(SCRATCH_X) + LENGTH(SCRATCH_X);
    __StackTop = ORIGIN(SCRATCH_Y) + LENGTH(SCRATCH_Y);
    __StackOneBottom = __StackOneTop - SIZEOF(.stack1_dummy);
    __StackBottom = __StackTop - SIZEOF(.stack_dummy);
    PROVIDE(__stack = __StackTop);

    /* picolibc and LLVM */
    PROVIDE (__heap_start = __end__);
    PROVIDE (__heap_end = __HeapLimit);
    PROVIDE( __tls_align = MAX(ALIGNOF(.tdata), ALIGNOF(.tbss)) );
    PROVIDE( __tls_size_align = (__tls_size + __tls_align - 1) & ~(__tls_align - 1));
    PROVIDE( __arm32_tls_tcb_offset = MAX(8, __tls_align) );

    /* llvm-libc */
    PROVIDE (_end = __end__);
    PROVIDE (__llvm_libc_heap_limit = __HeapLimit);

    /* Check if data + heap + stack exceeds RAM limit */
    ASSERT(__StackLimit >= __HeapLimit, "region RAM overflowed")

    ASSERT( __binary_info_header_end - __logical_binary_start <= 1024, "Binary info must be in first 1024 bytes of the binary")
    ASSERT( __embedded_block_end - __logical_binary_start <= 4096, "Embedded block must be in first 4096 bytes of the binary")

    /* todo assert on extra code */
}

