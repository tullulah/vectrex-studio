# uvm2.mk — drop-in `uvm2` build rule for any C/C++ game that already builds
# for the RP2350 cartridge.
#
# The two targets are the same program: the game speaks the `svc` syscall ABI
# through sdk_rp2350.c either way. What differs is who ANSWERS it — on our
# cartridge the firmware does, on the UVM2 there is no firmware, so uvm2-sdk
# answers from inside the image and drives the VIA over a halt-mode bus. So a
# uvm2 build is the rp2350 build with a different start file, linker script and
# SDK, wrapped in a `.um2` header.
#
# Usage — four lines next to the existing rp2350 rule:
#
#     UVM2_NAME   = dkong                  # → build_uvm2/dkong.um2
#     UVM2_SRCS   = $(GAME_SRCS)           # the game's own sources
#     UVM2_CFLAGS = $(ARM_CFLAGS)          # its compile flags, reused as-is
#     include $(UVM2_SDK)/uvm2.mk
#
# Optional:
#     UVM2_LDLIBS  = -lm                   # extra link libraries
#     UVM2_CXXSRCS = port/foo.cpp          # C++ sources, compiled with g++
#     UVM2_DEPS    = src/generated.h        # prerequisites (generated headers)
#     UVM2_CC      = $(ARM_CC)              # match the project's toolchain
#     UVM2_LDFLAGS_EXTRA = --specs=nosys.specs
#     UVM2_SDK     = .../uvm2-sdk          # if not already set
#
# A game that needs libvpy just lists $(VPY_C_SDK)/vpy.c in UVM2_SRCS.

UVM2_SDK ?= $(HOME)/projects/vectrex-pseudo-python/ide/electron/resources/uvm2-sdk
VPY_ROOT ?= $(HOME)/projects/vectrex-pseudo-python
RP2350_SDK ?= $(VPY_ROOT)/ide/electron/resources/rp2350-sdk
VPY_CLI  ?= $(VPY_ROOT)/buildtools/target/debug/vpy_cli

# A project that builds rp2350 with a specific toolchain should pass the same
# one here (UVM2_CC = $(ARM_CC)); the default only fits a plain freestanding
# build with no libc.
UVM2_CC      ?= arm-none-eabi-gcc
UVM2_CXX     ?= arm-none-eabi-g++
UVM2_OBJCOPY ?= arm-none-eabi-objcopy
UVM2_BUILD   ?= build_uvm2

# `,` as a variable: a literal comma cannot appear inside a filter-out list.
, := ,

# The UVM2 is single-core: core 1 is free, but the draw path is not split yet,
# and a game built for the cartridge's dual-core mode would record its draws to
# a buffer nobody drains. Drop the flag rather than let it fail at runtime.
UVM2_CFLAGS_CLEAN = $(filter-out -DVPY_DUAL_CORE -Wa$(,)--defsym$(,)DUAL_CORE_FLAG=0x44430001,\
                      $(UVM2_CFLAGS)) -I$(UVM2_SDK)

UVM2_SDK_SRCS = uvm2_bus.c uvm2_draw.c uvm2_input.c uvm2_led.c uvm2_text.c \
                uvm2_audio.c uvm2_svc.c
UVM2_SDK_OBJS = $(addprefix $(UVM2_BUILD)/sdk_,$(UVM2_SDK_SRCS:.c=.o))

$(UVM2_BUILD)/sdk_%.o: $(UVM2_SDK)/%.c | $(UVM2_BUILD)
	$(UVM2_CC) $(UVM2_CFLAGS_CLEAN) -c $< -o $@

$(UVM2_BUILD)/svc_bridge.o: $(RP2350_SDK)/sdk_rp2350.c | $(UVM2_BUILD)
	$(UVM2_CC) $(UVM2_CFLAGS_CLEAN) -c $< -o $@

# The linker is driven by g++ only when the game has C++ in it; a pure C game
# must not pull the C++ driver in.
UVM2_LINKER = $(if $(UVM2_CXXSRCS),$(UVM2_CXX),$(UVM2_CC))

# ─── El enlazado va por el pico-sdk, NO por uvm2_start.s ────────────────────
#
# Esta regla enlazaba a mano con uvm2_start.s + uvm2_game.ld. Ese camino produce
# imagenes que arrancan pero DIBUJAN UN SEGMENTO FANTASMA ILUMINADO desde el
# origen, uno por frame.
#
# MEDIDO en consola 2026-08-11, mismo juego (dkong) y mismo uvm2-sdk:
#   por aqui (uvm2_start.s):        fantasma
#   por uvm2_pico.cmake (pico-sdk): limpio
# Y no esta en el dibujo: la lista de comandos leida POR SWD del cartucho
# mientras dibujaba tenia exactamente los comandos que encienden el haz que debe
# tener. Un trazo que empieza en el origen —frame sin ningun movimiento— mostraba
# el fantasma igual, y el mismo binario lo hacia en dos consolas distintas.
# Lo que cambia es el arranque: uvm2_cpu_init() no toca los relojes, y bajo el
# pico-sdk el crt0 hace el runtime_init completo (ademas del IMAGE_DEF y del
# init del RCP que una imagen que NO pasa por el bootrom necesita).
#
# uvm2_pico.cmake existe desde el 2026-08-04 y esta migracion quedo pendiente;
# mientras tanto todos los juegos siguieron saliendo por el camino muerto. Se
# hace AQUI, una vez, y la heredan todos los que ya incluyen este fichero.
#
# El cmake quiere las inclusiones, los defines y las librerias por separado, asi
# que se extraen de los mismos UVM2_CFLAGS/UVM2_LDLIBS que el juego ya define.
empty :=
space := $(empty) $(empty)
semi  := ;
list   = $(subst $(space),$(semi),$(strip $1))

UVM2_PICO_SDK ?= $(HOME)/projects/vectrex-arcade-private/hardware/uvm2/RP2350_CrazyStones/pico-sdk
# Homebrew's arm-none-eabi-gcc has no nosys.specs — this toolchain does.
UVM2_ARM_TOOLCHAIN ?= /Applications/ArmGNUToolchain/15.2.rel1/arm-none-eabi
UVM2_CMAKE_BUILD   ?= $(UVM2_BUILD)/pico

# `-include foo.h` son DOS palabras, asi que un $(filter) simple se queda con el
# flag y tira la cabecera. Se pegan antes de filtrar. Sin esto, aae_speedfrk y
# los demas aae —que preincluyen su aae_compat.h— fallan con medio fichero de
# simbolos "undeclared", que no parece un problema de flags sino de fuentes.
UVM2_CFLAGS_GLUED = $(subst -include ,-include=,$(UVM2_CFLAGS_CLEAN))

# Y las comillas simples de defines como -D'CCNT0(x)=do{}while(0)' son cosa del
# shell: al pasar por cmake sobreviven literales y el define sale con comillas
# dentro. Fuera.
quote := '
# Fuentes que sobran EN ESTE CAMINO, no en el juego. libc_stub.c existe en los 41
# ports aae porque el enlazado viejo iba con -nostdlib y habia que rellenar exit,
# fclose y compania a mano. El pico-sdk trae newlib, asi que los stubs chocan con
# el de verdad: "multiple definition of 'exit'". Se quitan aqui, que es donde se
# sabe por que camino vamos; el juego sigue teniendolos para su build rp2350.
UVM2_SRCS_DROP ?= libc_stub.c
UVM2_SRCS_KEPT  = $(foreach s,$(UVM2_SRCS) $(UVM2_CXXSRCS),\
                    $(if $(filter $(UVM2_SRCS_DROP),$(notdir $(s))),,$(s)))
UVM2_GAME_SRCS   = $(abspath $(UVM2_SRCS_KEPT) $(RP2350_SDK)/sdk_rp2350.c)
UVM2_GAME_INCS   = $(abspath $(patsubst -I%,%,$(filter -I%,$(UVM2_CFLAGS_GLUED))))
UVM2_GAME_DEFS   = $(subst $(quote),,$(patsubst -D%,%,$(filter -D%,$(UVM2_CFLAGS_GLUED))))
UVM2_GAME_PREINC = $(abspath $(patsubst -include=%,%,$(filter -include=%,$(UVM2_CFLAGS_GLUED))))
UVM2_GAME_LIBS   = $(patsubst -l%,%,$(filter -l%,$(UVM2_LDLIBS)))

# Dual core. OJO A LOS NOMBRES, que es lo que lo tuvo apagado:
#
#   VPY_DUAL_CORE  = "graba los trazos en un buffer que drena el core 1 del
#                     FIRMWARE DEL CARTUCHO". En el UVM2 no hay firmware, la
#                     imagen es todo el programa, y nadie lo drenaria. Se filtra
#                     arriba y uvm2_pico.cmake lo rechaza con un error.
#   UVM2_DUAL_CORE = el nuestro, dentro de la imagen: uvm2_core1.c arranca el
#                     core 1 y ahi ocurren la reproduccion, la entrada, la cola
#                     del PSG y el ritmo de 50 Hz. Mismo mecanismo que el
#                     cartucho: doble buffer por frame&1 y dos contadores
#                     monotonos con dmb.
#
# Estaba escrito entero y NADIE lo definia. No hace el dibujo mas rapido —lo
# marca el reloj de 1,5 MHz de la Vectrex— sino que solapa la logica del juego
# con el barrido del haz, que es lo que hace Ralf con su reparto.
#
# POR DEFECTO DESDE 2026-08-12, validado en consola con dkong: dibuja, los mandos
# responden, y el frame queda al 98% del techo del haz (39,51 ms de barrido sobre
# 40,25 ms de frame). Se apaga con UVM2_DUAL_CORE=0.
#
# ABIERTO: la MUSICA no suena en dual core. Un sospechoso claro es el ritmo del
# secuenciador — el camino monocore avanza la pista por TIEMPO VECTREX
# transcurrido (varios ticks si el frame se pasa del presupuesto, y dkong gasta
# 59.000 ciclos sobre 30.000), mientras core 1 la avanza UNA vez por frame.
#
#   make uvm2 UVM2_DUAL_CORE=0
UVM2_DUAL_CORE ?= 1
ifeq ($(UVM2_DUAL_CORE),1)
UVM2_GAME_DEFS += UVM2_DUAL_CORE
endif

# UVM2_DEPS lets a project name generated headers the build needs first.
uvm2: $(UVM2_DEPS) | $(UVM2_BUILD)
	cmake -S $(UVM2_SDK)/pico -B $(UVM2_CMAKE_BUILD) \
	    -DCMAKE_BUILD_TYPE=Release \
	    -DCMAKE_TOOLCHAIN_FILE=$(UVM2_PICO_SDK)/cmake/preload/toolchains/pico_arm_cortex_m33_gcc.cmake \
	    -DPICO_SDK_PATH=$(UVM2_PICO_SDK) -DPICO_TOOLCHAIN_PATH=$(UVM2_ARM_TOOLCHAIN) \
	    -DUVM2_SDK_DIR=$(UVM2_SDK) -DVPY_CLI_DIR=$(dir $(VPY_CLI)) \
	    -DUVM2_NAME=$(UVM2_NAME) \
	    -DUVM2_GAME_SRCS="$(call list,$(UVM2_GAME_SRCS))" \
	    -DUVM2_GAME_INCS="$(call list,$(UVM2_GAME_INCS))" \
	    -DUVM2_GAME_DEFS="$(call list,$(UVM2_GAME_DEFS))" \
	    -DUVM2_GAME_PREINC="$(call list,$(UVM2_GAME_PREINC))" \
	    -DUVM2_GAME_LIBS="$(call list,$(UVM2_GAME_LIBS))" > $(UVM2_CMAKE_BUILD).log
	cmake --build $(UVM2_CMAKE_BUILD) -j8
	cp $(UVM2_CMAKE_BUILD)/$(UVM2_NAME).um2 $(UVM2_BUILD)/$(UVM2_NAME).um2
	@echo "=== Build OK (uvm2 SD game): $(UVM2_BUILD)/$(UVM2_NAME).um2 ==="

$(UVM2_BUILD):
	mkdir -p $(UVM2_BUILD)

uvm2-clean:
	rm -rf $(UVM2_BUILD)

.PHONY: uvm2 uvm2-clean
