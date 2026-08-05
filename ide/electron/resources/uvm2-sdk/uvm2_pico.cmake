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
pico_sdk_init()

add_executable(${UVM2_NAME}
    ${UVM2_GAME_SRCS}
    ${UVM2_SDK_DIR}/uvm2_bus.c
    ${UVM2_SDK_DIR}/uvm2_draw.c
    ${UVM2_SDK_DIR}/uvm2_input.c
    ${UVM2_SDK_DIR}/uvm2_led.c
    ${UVM2_SDK_DIR}/uvm2_text.c
    ${UVM2_SDK_DIR}/uvm2_audio.c
    ${UVM2_SDK_DIR}/uvm2_svc.c
    ${UVM2_SDK_DIR}/uvm2_core1.c
    ${UVM2_SDK_DIR}/uvm2_svc_entry.s
    ${UVM2_SDK_DIR}/uvm2_pico_main.c
    ${UVM2_SDK_DIR}/uvm2_pico_svc.S
)

# A RAM image: the UVM2 firmware copies it to 0x20000000 and launches it. This is
# also what makes crt0 emit the VECTOR_TABLE item the launch path looks for.
pico_set_binary_type(${UVM2_NAME} no_flash)

# The game keeps its own `main`; rename it so uvm2_pico_main.c can wrap it with
# the runtime init. Scoped to the GAME sources only — as a global flag it also
# renames the `main` in CMake's compiler-probe program and configuration fails.
set_source_files_properties(${UVM2_GAME_SRCS} PROPERTIES
    COMPILE_DEFINITIONS "main=uvm2_game_main")

# Tells uvm2-sdk that crt0 owns .bss and the vector table now.
target_compile_definitions(${UVM2_NAME} PRIVATE UVM2_PICO_RUNTIME=1 ${UVM2_GAME_DEFS})

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

target_include_directories(${UVM2_NAME} PRIVATE ${UVM2_SDK_DIR})
target_link_libraries(${UVM2_NAME} pico_stdlib pico_multicore hardware_dma hardware_pio ${UVM2_GAME_LIBS})

# Keep the SVC handler alive. Nothing in C calls uvm2_svc_handler — it is reached
# only through the vector table — so --gc-sections drops its section, and the
# .thumb_set alias to it disappears with it, silently leaving crt0's weak
# `bkpt #0` stub installed. Naming it as a link root is what makes the override
# actually happen; without this every libvpy builtin faults on its first svc.
target_link_options(${UVM2_NAME} PRIVATE -Wl,--undefined=uvm2_svc_handler)

# No USB/UART stdio: the cart has neither, and enabling it drags TinyUSB into a
# 50 Hz draw loop.
pico_enable_stdio_uart(${UVM2_NAME} 0)
pico_enable_stdio_usb(${UVM2_NAME} 0)

# pico_add_extra_outputs derives the .bin/.uf2 names from the executable, and
# refuses one with no extension. The SDK normally sets this globally; set it on
# the target so we do not depend on where in the include order that happens.
set_target_properties(${UVM2_NAME} PROPERTIES SUFFIX ".elf")

pico_add_extra_outputs(${UVM2_NAME})

# Wrap the flat image in the .um2 header the multicart reads.
find_program(VPY_CLI vpy_cli PATHS ${VPY_CLI_DIR} NO_DEFAULT_PATH)
if(VPY_CLI)
    add_custom_command(TARGET ${UVM2_NAME} POST_BUILD
        COMMAND ${VPY_CLI} package-um2 $<TARGET_FILE_DIR:${UVM2_NAME}>/${UVM2_NAME}.bin
                --out $<TARGET_FILE_DIR:${UVM2_NAME}>/${UVM2_NAME}.um2
        COMMENT "packaging ${UVM2_NAME}.um2")
else()
    message(WARNING "vpy_cli not found — .bin will not be wrapped into .um2")
endif()
