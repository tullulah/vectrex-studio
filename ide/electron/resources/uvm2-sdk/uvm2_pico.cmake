# uvm2_pico.cmake — build a UVM2 SD game through the PICO SDK.
#
# WHY THIS REPLACES uvm2_start.s + uvm2_game.ld (2026-08-04)
# ----------------------------------------------------------
# Our hand-rolled startup produced images the UVM2 refused to launch — not one of
# our ~45 games booted, while Ralf's did from the same card. Proven on hardware:
# the RP2350 (unlike the RP2040) requires an **IMAGE_DEF** metadata block, the
# bootrom validates it, and the UVM2 firmware defers to that validation. Without
# the block our first instruction never executed (a breadcrumb in WATCHDOG_SCRATCH4
# stayed 0); with a block bolted on, the same image walked its whole startup.
#
# So the boot contract belongs to the chip, not to us. crt0.S emits the block from
# `embedded_start_block.inc.S`, and gets the rest of the RP2350 entry right too —
# notably the RCP init that a NOT-through-the-bootrom image needs.
#
# WHAT WE STILL OWN: everything Vectrex-side (uvm2_bus/draw/input/led/text/audio)
# and the `svc` ABI. `isr_svcall` is WEAK in crt0.S, so uvm2_svc_handler simply
# overrides it — no SDK patching.
#
# Usage from a game's Makefile:
#   cmake -S $(UVM2_SDK)/pico -B build_uvm2 \
#         -DUVM2_NAME=dkong -DUVM2_GAME_SRCS="a.c;b.c" -DUVM2_GAME_INCS="inc"
#   cmake --build build_uvm2
#
# Board: olimex_rp2350_xxl, the same one Ralf builds against. The UVM2's GPIO map
# matches his pin-for-pin (D0=0, A0=8, PB6=22, /IRQ=23, A14=24, A15=25, R/W=26,
# /HALT=27, /NMI=29, CLK=31), so this is the board definition that fits the wiring.

if(NOT DEFINED UVM2_NAME)
    message(FATAL_ERROR "set -DUVM2_NAME=<game>")
endif()

set(PICO_BOARD olimex_rp2350_xxl CACHE STRING "Board type")
include(pico_sdk_import.cmake)
project(${UVM2_NAME} C CXX ASM)
# EL PANICO, LEGIBLE. Antes de pico_sdk_init() para que llegue tambien a panic.c, que se
# compila dentro de la libreria del SDK: pasarlo como define del juego NO basta — lo probe
# y el simbolo ni aparecia en el ELF.
#
# Con esto `panic` deja de imprimir y llama a uvm2_panic_stash, que guarda el puntero al
# mensaje en 0x20080234 y para. Imprimir aqui es peor que inutil: no hay consola y vsnprintf
# se sale de la pila (medido: BFAR = 0x20082000, el techo justo), asi que lo unico que se
# ve es el fallo del mensajero y el motivo se pierde.
if(DEFINED ENV{UVM2_PANIC_STASH} AND NOT "$ENV{UVM2_PANIC_STASH}" STREQUAL "0")
    message(STATUS "UVM2_PANIC_STASH: panic guarda el motivo en 0x20080230 en vez de imprimirlo")
    add_compile_definitions(PICO_PANIC_FUNCTION=uvm2_panic_stash)
endif()

# EL HEAP, QUE POR DEFECTO SON 2 KB DE NADA.
#
# El pico-sdk reserva PICO_HEAP_SIZE = 2048 en una seccion `.heap` (crt0.S), y una imagen
# del UVM2 no reserva memoria dinamica: ni el juego ni este SDK llaman a malloc. Con la
# RAM al borde eso son 2 KB tirados — dkong se pasaba por 900 bytes solo por ellos.
#
# NO SE PONE A CERO PARA TODOS. Son 44 puertos y no puedo probar que ninguno reserve; un
# malloc que devuelve NULL falla en silencio y lejos de aqui. Asi que es OPT-IN, y quien
# lo encienda tiene una comprobacion que lo demuestra para SU imagen:
#
#     arm-none-eabi-nm imagen.elf | grep -E ' (malloc|_sbrk|_malloc_r)$'
#
# si eso no imprime nada, no hay quien pueda reservar y el heap sobra de verdad.
if(DEFINED ENV{UVM2_HEAP})
    message(STATUS "UVM2_HEAP: heap de $ENV{UVM2_HEAP} bytes (el pico-sdk pone 2048)")
    add_compile_definitions(PICO_HEAP_SIZE=$ENV{UVM2_HEAP})
endif()

pico_sdk_init()

add_executable(${UVM2_NAME}
    ${UVM2_GAME_SRCS}
    ${UVM2_SDK_DIR}/uvm2_bus.c
    ${UVM2_SDK_DIR}/uvm2_sd.c
    ${UVM2_SDK_DIR}/uvm2_romzip.c
    ${UVM2_SDK_DIR}/uvm2_draw.c
    ${UVM2_SDK_DIR}/uvm2_input.c
    ${UVM2_SDK_DIR}/uvm2_led.c
    ${UVM2_SDK_DIR}/uvm2_text.c
    ${UVM2_SDK_DIR}/uvm2_audio.c
    ${UVM2_SDK_DIR}/uvm2_svc.c
    ${UVM2_SDK_DIR}/uvm2_core1.c
    ${UVM2_SDK_DIR}/uvm2_psram.c
    ${UVM2_SDK_DIR}/uvm2_svc_entry.s
    ${UVM2_SDK_DIR}/uvm2_pico_main.c
    ${UVM2_SDK_DIR}/uvm2_pico_svc.S
)

# A RAM image: the UVM2 firmware copies it to 0x20000000 and launches it. This is
# also what makes crt0 emit the VECTOR_TABLE item the launch path looks for.
pico_set_binary_type(${UVM2_NAME} no_flash)

# EXPERIMENTO: enlazar en la PSRAM EXTERNA (0x11000000) en vez de en la SRAM interna.
#
# Se enciende con la variable de entorno UVM2_LOAD_PSRAM=1. La imagen resultante hay que
# empaquetarla con `vpy_cli package-um2 --load-addr 0x11000000`, porque la cabecera .um2
# es lo que le dice al cargador del multicart donde copiar.
#
# LA PREGUNTA: ¿honra su cargador una direccion fuera de la SRAM? Medimos esa PSRAM muda,
# pero DESDE DENTRO de un juego ya cargado — si su firmware la inicializa solo cuando la
# necesita, esa medida no lo habria visto. Pedirle que cargue ahi es la unica prueba.
if(DEFINED ENV{UVM2_LOAD_PSRAM} AND NOT "$ENV{UVM2_LOAD_PSRAM}" STREQUAL "0")
    message(STATUS "UVM2_LOAD_PSRAM: enlazando en la PSRAM externa (0x11000000)")
    pico_set_linker_script(${UVM2_NAME} ${CMAKE_CURRENT_LIST_DIR}/memmap_psram.ld)
    target_compile_definitions(${UVM2_NAME} PRIVATE UVM2_PSRAM_IMAGE=1)
endif()

# The game keeps its own `main`; rename it so uvm2_pico_main.c can wrap it with
# the runtime init. Scoped to the GAME sources only — as a global flag it also
# renames the `main` in CMake's compiler-probe program and configuration fails.
set_source_files_properties(${UVM2_GAME_SRCS} PROPERTIES
    COMPILE_DEFINITIONS "main=uvm2_game_main")

# Tells uvm2-sdk that crt0 owns .bss and the vector table now.
target_compile_definitions(${UVM2_NAME} PRIVATE UVM2_PICO_RUNTIME=1)

# Los defines del juego van como OPCIONES, no como definiciones. CMake se come
# los que llevan parentesis: -D'CCNT0(x)=do{}while(0)' entra en la lista, no da
# ningun aviso, y no aparece en flags.make — el juego compila con CCNT0 sin
# declarar y falla en aae-src/cpuintrf.c. Como opcion cruda llega intacto, y
# ademas cada define es un unico elemento de argv, asi que las llaves y los
# parentesis no pasan por ningun shell.
# SOLO PARA C. El target lleva ficheros en ensamblador (uvm2_svc_entry.s), y el
# ensamblador se atraganta: con `-include cabecera.h` se pone a leer C y suelta
# "bad instruction: typedef signed char __int8_t". Lo mismo con un define que lleve
# parentesis.
foreach(def ${UVM2_GAME_DEFS})
    target_compile_options(${UVM2_NAME} PRIVATE "$<$<COMPILE_LANGUAGE:C>:-D${def}>")
endforeach()

# Opciones CRUDAS del juego (no defines): `-include algo.h`, avisos que hay que callar...
# Los puertos AAE necesitan `-include src/aae_compat.h`, que no cabe como define.
foreach(opt ${UVM2_GAME_OPTS})
    target_compile_options(${UVM2_NAME} PRIVATE "$<$<COMPILE_LANGUAGE:C>:${opt}>")
endforeach()

# DESACTUALIZADO EN UN PUNTO: lo de "nunca escribimos el consumidor de core 1"
# ya no es cierto — uvm2_core1.c existe (reproduccion, entrada, cola del PSG y
# ritmo de 50 Hz) y uvm2_pico_main.c lo arranca. Lo que faltaba era el
# interruptor: se enciende con UVM2_DUAL_CORE en UVM2_GAME_DEFS (make uvm2
# UVM2_DUAL_CORE=1, o la variable de entorno del mismo nombre para vpy_cli).
# El rechazo de abajo sigue siendo correcto y necesario: VPY_DUAL_CORE es OTRA
# cosa y aqui no la drena nadie.
#
# NOT because the UVM2 is single-core — it carries the same RP2350 we do, and
# Ralf's own games use both halves of it (core 0 fills commandBuffer[2][8K],
# core 1 replays it and reads the controls, handshaken through two volatile
# frame counters). What is single-core is OUR UVM2 runtime: we never wrote the
# core-1 consumer for it.
#
# So the flag has to be refused, because -DVPY_DUAL_CORE does not mean "use two
# cores". It means "record draws into a buffer that THE CARTRIDGE FIRMWARE's
# core 1 drains", and on the UVM2 there is no firmware — the image is the whole
# program, and nobody drains it. A game built with it would draw nothing at all.
# Failing here beats failing on the screen.
#
# Worth doing eventually: a second core would not make the drawing faster (the
# replay is paced by the Vectrex's own 1.5 MHz clock and cannot outrun it), but
# it would overlap the game logic with the replay instead of running them back
# to back, which is exactly what Ralf's split buys.
if("VPY_DUAL_CORE" IN_LIST UVM2_GAME_DEFS)
    message(FATAL_ERROR "VPY_DUAL_CORE in UVM2_GAME_DEFS: that flag targets the cartridge firmware's core 1, which does not exist here")
endif()

# The game's include dirs go on the GAME SOURCES, not on the target. A port that
# ships freestanding libc shims (asteroids_sbt's include_rp2350/) would otherwise
# shadow the real <stdio.h> for the pico-sdk's own sources, which then lose puts()
# and fail to build. Scoped this way each side gets the headers it expects.
set_source_files_properties(${UVM2_GAME_SRCS} PROPERTIES
    INCLUDE_DIRECTORIES "${UVM2_GAME_INCS}")

# Cabeceras preincluidas (`-include foo.h`). Los ports aae las usan para su
# aae_compat.h, y sin ellas el juego no compila: salen decenas de simbolos
# "undeclared" que parecen un problema de fuentes y no lo son. Van sobre las
# fuentes del JUEGO, como las inclusiones, para no metersela al pico-sdk.
if(UVM2_GAME_PREINC)
    set(UVM2_PREINC_OPTS "")
    foreach(hdr ${UVM2_GAME_PREINC})
        list(APPEND UVM2_PREINC_OPTS "-include" "${hdr}")
    endforeach()
    set_source_files_properties(${UVM2_GAME_SRCS} PROPERTIES
        COMPILE_OPTIONS "${UVM2_PREINC_OPTS}")
endif()

target_include_directories(${UVM2_NAME} PRIVATE ${UVM2_SDK_DIR})
# hardware_flash: NO es para escribir en la flash — de ahi no se toca nada. Es
# para flash_devinfo_set_cs_size() y flash_do_cmd(), que son la unica forma de
# pedirle al BOOTROM la secuencia de salida de XIP hacia CS1, o sea hacia la
# PSRAM. Ver el bloque de uvm2_psram_probe_bootrom(). pico_stdlib no lo arrastra.
target_link_libraries(${UVM2_NAME} pico_stdlib pico_multicore hardware_dma hardware_pio hardware_flash ${UVM2_GAME_LIBS})

# ── La capa de dibujo COMPARTIDA por los dos cartuchos ───────────────────────
#
# UNA sola implementacion del modelo de haz: la misma caja Rust que enlaza el firmware
# del cartucho propio, aqui como staticlib dentro de la imagen. Antes vivia en el
# repositorio privado y esto llevaba una guarda `EXISTS` para que el arbol publico
# siguiera compilando sin ella — pero esa guarda dejaba VIVA una segunda capa de dibujo,
# que es justo lo que se estaba quitando. Con la caja aqui, el arbol compila solo y no
# hay segunda implementacion que mantener.
#
# CMake la CONSTRUYE, no la busca hecha: un .a que hay que acordarse de recompilar a mano
# se queda viejo en silencio, y un binario viejo ya nos costo una tarde entera.
set(VECTREX_DRAW_DIR "${CMAKE_CURRENT_LIST_DIR}/../vectrex-draw")
set(VECTREX_DRAW_TARGET thumbv8m.main-none-eabi)   # coma flotante SOFTWARE: esta imagen
                                                   # se compila -mfloat-abi=softfp y el
                                                   # enlazador compara Tag_ABI_VFP_args
                                                   # aunque no cruce ningun flotante
if(DEFINED ENV{UVM2_PIO_STREAM} AND NOT "$ENV{UVM2_PIO_STREAM}" STREQUAL "0")
    # No hay segunda .a: el ABI del stream sale del MISMO envoltorio que la capa de dibujo,
    # porque una staticlib exige manejador de panico y dos no caben en un enlace. Ver
    # vectrex-draw/cabi/src/lib.rs.
    set(VECTREX_CABI_FEATURES --features bus)
    target_compile_definitions(${UVM2_NAME} PRIVATE UVM2_PIO_STREAM=1)
endif()

set(VECTREX_DRAW_LIB
    "${VECTREX_DRAW_DIR}/cabi/target/${VECTREX_DRAW_TARGET}/release/libvectrex_draw_cabi.a")

find_program(CARGO_EXE cargo)
if(NOT CARGO_EXE)
    message(FATAL_ERROR
        "No encuentro `cargo`. La capa de dibujo compartida es Rust: "
        "instala rustup y `rustup target add ${VECTREX_DRAW_TARGET}`.")
endif()

add_custom_target(vectrex_draw_lib ALL
    COMMAND ${CARGO_EXE} build --release --target ${VECTREX_DRAW_TARGET}
            --manifest-path "${VECTREX_DRAW_DIR}/cabi/Cargo.toml"
            ${VECTREX_CABI_FEATURES}
    BYPRODUCTS ${VECTREX_DRAW_LIB}
    COMMENT "capa de dibujo compartida (vectrex-draw)")
add_dependencies(${UVM2_NAME} vectrex_draw_lib)
target_link_libraries(${UVM2_NAME} ${VECTREX_DRAW_LIB})
target_compile_definitions(${UVM2_NAME} PRIVATE UVM2_VECTREX_DRAW=1)

# ── EL STREAM DE BUS POR PIO+DMA, COMPARTIDO ─────────────────────────────────
#
# Misma caja que usa el firmware del cartucho propio (vectrex-bus), enlazada aqui como
# staticlib. No es un puerto ni una transcripcion: es EL MISMO conductor y EL MISMO
# programa de PIO ya ensamblado, con el ancho del `out` parcheado al instalar (25 pines
# alli, 27 aqui). Lo unico propio de esta placa es como se arma la palabra de bus, que ya
# vivia en uvm2_bus.h porque aqui la direccion esta partida.
#
# Detras de perilla porque hay que compararlo contra el camino SIO con la misma escena,
# que es como se midio el 1,21x en el otro cartucho:
#
#     make uvm2 UVM2_PIO_STREAM=1

# Keep the SVC handler alive. Nothing in C calls uvm2_svc_handler — it is reached
# only through the vector table — so --gc-sections drops its section, and the
# .thumb_set alias to it disappears with it, silently leaving crt0's weak
# `bkpt #0` stub installed. Naming it as a link root is what makes the override
# actually happen; without this every libvpy builtin faults on its first svc.
target_link_options(${UVM2_NAME} PRIVATE -Wl,--undefined=uvm2_svc_handler)

# VPY_RAM. Los programas VPy guardan sus variables en direcciones ABSOLUTAS
# (0x2007C000..0x20080000, ver vpy_codegen arm/ram_layout.rs). uvm2_game.ld tenia
# una region para ellas; el script del pico-sdk no, su RAM llega a 0x20080000 y
# puede poner .bss justo encima — corrupcion silenciosa en un juego grande.
#
# El .S generado declara una seccion .vpyram vacia (NOBITS) y esto la fija ahi:
# si .bss llegara a solaparla, ld lo dice y el build FALLA, que es infinitamente
# mejor que descubrirlo en la pantalla. Para juegos en C la seccion no existe y
# la opcion no hace nada.
target_link_options(${UVM2_NAME} PRIVATE -Wl,--section-start=.vpyram=0x2007C000)

# No USB/UART stdio: the cart has neither, and enabling it drags TinyUSB into a
# 50 Hz draw loop.
pico_enable_stdio_uart(${UVM2_NAME} 0)
pico_enable_stdio_usb(${UVM2_NAME} 0)

# pico_add_extra_outputs derives the .bin/.uf2 names from the executable, and
# refuses one with no extension. The SDK normally sets this globally; set it on
# the target so we do not depend on where in the include order that happens.
set_target_properties(${UVM2_NAME} PROPERTIES SUFFIX ".elf")

# El .uf2 solo tiene sentido para una imagen que arranque la bootrom. Un payload
# enlazado en la PSRAM lo carga NUESTRO cargador, y ademas elf2uf2 lo rechaza: para un
# binario `no_flash` espera direcciones de SRAM y 0x11000000 no lo es ("entry point is
# not in mapped part of file"). Peor aun, al fallar BORRA el .elf, que es justo lo que
# necesitamos. Asi que ahi nos quedamos con el ELF y hacemos el .bin nosotros.
if(DEFINED ENV{UVM2_LOAD_PSRAM} AND NOT "$ENV{UVM2_LOAD_PSRAM}" STREQUAL "0")
    message(STATUS "UVM2_LOAD_PSRAM: solo .bin (lo carga nuestro cargador, no la bootrom)")
    pico_add_bin_output(${UVM2_NAME})
else()
    pico_add_extra_outputs(${UVM2_NAME})
endif()

# Wrap the flat image in the .um2 header the multicart reads.
# Un payload de PSRAM no es un modulo: no lo carga el multicart, lo carga nuestro
# cargador. Empaquetarlo como .um2 solo serviria para confundir en la tarjeta.
find_program(VPY_CLI vpy_cli PATHS ${VPY_CLI_DIR} NO_DEFAULT_PATH)
if(VPY_CLI AND NOT (DEFINED ENV{UVM2_LOAD_PSRAM} AND NOT "$ENV{UVM2_LOAD_PSRAM}" STREQUAL "0"))
    add_custom_command(TARGET ${UVM2_NAME} POST_BUILD
        COMMAND ${VPY_CLI} package-um2 $<TARGET_FILE_DIR:${UVM2_NAME}>/${UVM2_NAME}.bin
                --out $<TARGET_FILE_DIR:${UVM2_NAME}>/${UVM2_NAME}.um2
        COMMENT "packaging ${UVM2_NAME}.um2")
else()
    message(WARNING "vpy_cli not found — .bin will not be wrapped into .um2")
endif()
