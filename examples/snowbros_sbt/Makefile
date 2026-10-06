# snowbros_sbt — Snow Bros on the Vectrex: emulated 68000 (Musashi) + Pandora
# sprite list drawn as vectors.
#
#   make host   -> native harness (build/host_sb)
#                  AUTOCOIN=120 DUMPFRAME=400 ./build/host_sb 2> frame.txt
#   make sim    -> IDE emulator panel (F5), build_wasm/game.js
#   make rp2350 -> our own cartridge, .bin to the SD card
#                  build_rp2350/snowbros_sbt_sd.bin
#   make uvm2   -> Ralf's multicart, PSRAM payload
#                  build_uvm2/snowbros_sbt.bin
#
# The .cvproj next door declares all four. It matters: the IDE rebuilds from
# there, and what is not written down does not exist.
#
# Milestone: wireframe renderer. The traced .vec shapes in assets/vectors/
# replace the placeholder silhouette boxes tile-family by tile-family; those
# boxes are OFF by default since 2026-09-16 (TILE_BOXES=1 brings them back).

AAE_SRC   = $(HOME)/projects/vectrex-arcade-private/aae-games/aae-src
MUSASHI   = $(AAE_SRC)/musashi

SRC = src/gmain.c src/sb_hw.c src/sb_render.c src/sb_audio.c \
      $(MUSASHI)/m68kcpu.c $(MUSASHI)/m68kops.c $(MUSASHI)/softfloat/softfloat.c

GEN = src/sb_rom.h src/sb_tiles.h src/sb_sprites.h src/sb_font.h src/sb_shapes.h \
      src/sb_snddata.h

#   CHEATS=1  invulnerability (the board's own DSW2 dip) — for reaching high
#             floors to grow the sprite catalogue, TNZS-style
CHEATFLAG = $(if $(filter 1,$(CHEATS)),-DSB_CHEATS_DEFAULT=1,)

# ---- render knobs: THE SAME ONES IN ALL FOUR TARGETS -----------------------
# RENDER_DEFS goes into HOST_CFLAGS, WASM_CFLAGS *and* UVM2_CFLAGS (which is
# also where the cartridge recipe takes its -D from). That is not tidiness: a
# knob that reaches the host but not the console means the two draw different
# screens, and every picture and every measurement taken from one of them is of
# a game nobody is playing. dkong lost an hour to exactly this.
#
# TILE_BOXES: the placeholder silhouette boxes for tiles with no traced .vec —
# see the long note in sb_render.c. 0 (default, 2026-09-16) leaves those tiles
# blank; 1 brings the scaffolding back:
#
#     make sim TILE_BOXES=1
#
# The unmatched-tile WORKLIST is untouched either way: it is counted in
# flush_object before anything is drawn, so `make host SB_LOG_UNMATCHED=1` still
# reports what needs tracing next with the boxes off.
TILE_BOXES  ?= 0
RENDER_DEFS  = -DSB_TILE_BOXES=$(TILE_BOXES)

HOST_CC     ?= cc
HOST_CFLAGS  = -std=gnu11 -O2 -w $(CHEATFLAG) $(RENDER_DEFS) -Isrc -I$(AAE_SRC)

build build_wasm:
	@mkdir -p $@

host: $(GEN) | build
	$(HOST_CC) $(HOST_CFLAGS) $(SRC) src/host_vec.c -lm -o build/host_sb
	@echo "=== host: build/host_sb ==="

# ---- IDE simulator (WASM) — this is what F5 runs ---------------------------
PITREX_SIM_SDK ?= $(HOME)/projects/vectrex-pseudo-python/ide/electron/resources/uvmc2-sdk/pitrex-sim
VPY_C_SDK      ?= $(HOME)/projects/vectrex-pseudo-python/ide/electron/resources/uvmc2-sdk/vpy-c
EMCC           ?= emcc
EMSDK          ?= $(HOME)/emsdk
EMSDK_EMCC     := $(EMSDK)/upstream/emscripten
EMSDK_PY       := $(firstword $(wildcard $(EMSDK)/python/*/bin))
EMCC_PATH      := $(if $(EMSDK_PY),$(EMSDK_PY):,)$(EMSDK_EMCC):$(PATH)

WASM_CFLAGS  = -std=gnu11 -O1 -w $(CHEATFLAG) $(RENDER_DEFS) -Isrc -I$(AAE_SRC) \
               -I$(PITREX_SIM_SDK)/include -I$(VPY_C_SDK)/include
WASM_LDFLAGS = -sASYNCIFY -sASYNCIFY_IGNORE_INDIRECT -sASYNCIFY_STACK_SIZE=1048576 \
               -sINITIAL_MEMORY=134217728 -sALLOW_MEMORY_GROWTH=1 \
               -sINVOKE_RUN=0 -sEXIT_RUNTIME=0 \
               -sMODULARIZE=1 -sEXPORT_NAME=createSimModule -sEXPORTED_RUNTIME_METHODS=callMain,FS

sim: $(GEN) | build_wasm
	PATH="$(EMCC_PATH)" $(EMCC) $(WASM_CFLAGS) $(SRC) src/sb_sim.c $(PITREX_SIM_SDK)/sdk_host.c $(WASM_LDFLAGS) -o build_wasm/game.js
	@echo "=== sim build OK: build_wasm/game.js ==="

# ---- sound ripper: the Z80+YM3812 music, out of the ROM --------------------
# Runs the real sound program (sbros-4.29) under mz80, feeds it each latch
# command and logs the YM3812 register writes — the raw material the PSG
# .vmus/.vsfx conversion works from. See the header of tools/snd_rip.c.
#   make snd_rip && ./build/snd_rip build/sbros4.bin build/snd
build/sbros4.bin: rom/snowbros.zip | build
	python3 -c "import zipfile; open('build/sbros4.bin','wb').write(zipfile.ZipFile('rom/snowbros.zip').read('sbros-4.29'))"

snd_rip: tools/snd_rip.c tools/mz80/mz80.c build/sbros4.bin | build
	$(HOST_CC) -std=gnu11 -O2 -w -DNO_PI -Itools/mz80 tools/snd_rip.c tools/mz80/mz80.c -o build/snd_rip
	@mkdir -p build/snd
	@echo "=== snd_rip: build/snd_rip ==="

# snd_ref: the SAME logs played back through the REAL chip (MAME's ymfm
# YM3812). Two jobs: a reference to listen to, and the measurements that drive
# the SFX conversion — an FM zap's pitch cannot be computed from fnum (the
# operator MULT scales it, feedback and inharmonic modulation dominate it), so
# it is measured off the rendered audio. See tools/snd_ref.cpp.
#   make snd_ref && ./build/snd_ref build/snd/cmd_1f.log shot.wav
YMFM ?= $(HOME)/projects/mame/3rdparty/ymfm/src
YMFM_SRCS = $(YMFM)/ymfm_opl.cpp $(YMFM)/ymfm_misc.cpp $(YMFM)/ymfm_pcm.cpp \
            $(YMFM)/ymfm_adpcm.cpp $(YMFM)/ymfm_ssg.cpp

snd_ref: tools/snd_ref.cpp | build
	c++ -std=c++17 -O2 -w -I$(YMFM) tools/snd_ref.cpp $(YMFM_SRCS) -o build/snd_ref
	@echo "=== snd_ref: build/snd_ref ==="

src/sb_rom.h src/sb_tiles.h: tools/roms_to_c.py tools/extract_sprites.py
	python3 tools/roms_to_c.py

src/sb_sprites.h: tools/vec_to_sprites.py $(wildcard assets/vectors/*.vec)
	python3 tools/vec_to_sprites.py

src/sb_shapes.h: tools/vec_to_shapes.py $(wildcard assets/vectors/level_*.vec)
	python3 tools/vec_to_shapes.py

src/sb_font.h: tools/make_font.py
	python3 tools/make_font.py

# The PSG streams of the arcade's own music/SFX. Two stages, both offline: the
# ripper runs the sound ROM (build/snd/*.log), the converter reduces YM3812 to
# PSG. build/snd is kept out of the deps on purpose — re-ripping is cheap but it
# needs the romset, and a checkout with sb_snddata.h already present must build.
src/sb_snddata.h: tools/snd_conv.py tools/snd_rip.c tools/snd_ref.cpp | build
	$(MAKE) snd_rip snd_ref
	./build/snd_rip build/sbros4.bin build/snd
	python3 tools/snd_conv.py

.PHONY: host sim snd_rip snd_ref

# ---- the two cartridges (UVM2 + RP2350) ------------------------------------
# Same program, bare metal, twice. The game speaks the same `svc` ABI through
# sdk_rp2350.c either way; what changes is who ANSWERS it:
#
#   make uvm2     Ralf's multicart. No firmware — uvm2-sdk answers from inside
#                 the image, linked through the pico-sdk (so: full newlib, full
#                 crt0). 1.5MB with the 68000 ROM and the Musashi tables, which
#                 does not fit the 496K GAME_RAM, so it links into external
#                 PSRAM and the artifact is a flat .bin, NOT a .um2 module (the
#                 multicart menu cannot load one of those; our loader can).
#   make rp2350   our own cartridge. The BIOS answers, and with VPY_DUAL_CORE it
#                 does so through its function table: core 0 materialises the
#                 beam by PIO+DMA while the game runs on core 1. The artifact is
#                 build_rp2350/snowbros_sbt_sd.bin, copied to the SD card.
#
# Both recipes live in uvm2.mk — ONE rule shared by every project, not a
# forty-third private copy. What this file owes it is the toolchain, the machine
# flags and the sources; the rest is the same for all of us.
export UVM2_LOAD_PSRAM ?= 1
UVM2_NAME   = snowbros_sbt

# libc_stub.c is in the list but never reaches the .um2: uvm2.mk drops it by name
# (UVM2_SRCS_DROP), because that path already has a real crt0 and the two would
# collide. See the file — it is three functions, and it says why.
UVM2_SRCS   = src/gmain.c src/sb_hw.c src/sb_audio.c $(RENDER_OBJ) src/libc_stub.c src/sb_rtt.c \
              $(MUSASHI_OBJ) $(MUSASHI)/softfloat/softfloat.c

# ---- LAS TABLAS DEL DIBUJO EN LA SRAM INTERNA -----------------------------
#
# MEDIDO en consola: `lista` son 11,7 ms para 730 segmentos = 2.400 ciclos de M33
# por segmento, que es muchisimo para calcular una recta y meterla en un anillo.
# El sospechoso no es el codigo (sb_render.c son 2.704 bytes) sino las TABLAS que
# recorre, todas en PSRAM y por tanto por la cache XIP:
#
#     sb_spriteram    4.096 B   entera cada frame (va aparte, en sb_hw.c)
#     sb_tile_blank   4.096 B   una lectura por entrada de sprite
#     sb_tile_toprow 32.768 B   por cada tile, en snowy_top() y object_dark()
#
# Las dos ultimas viven en sb_tiles.h, que lo GENERA tools/roms_to_c.py: no se
# pueden anotar a mano sin que el generador se las lleve por delante la proxima
# vez. Con -fdata-sections cada una cae en su propia `.rodata.<nombre>`, asi que
# se renombran DESDE FUERA, por nombre exacto, sin tocar el fichero generado.
#
# NO SE MUEVE sb_vec_pts (43.100 B): solo se lee para objetos que tienen .vec, no
# para todos, y no cabe — quedan 44 KB y estas tres ya se llevan 41.
RENDER_SRAM ?= 1
ifeq ($(RENDER_SRAM),1)
RENDER_OBJ = build_rp2350/sb_render_sram.o
else
RENDER_OBJ = src/sb_render.c
endif

# ---- MUSASHI EN LA SRAM INTERNA -------------------------------------------
#
# MEDIDO EN CONSOLA el 2026-09-16 por RTT: emular el 68000 son 25,8 ms de un frame
# de 33,4 — el 77%. La lista son 6,8 (20%) y esperar al haz 0,8 (3%). Este puerto
# no esta limitado por el haz ni de lejos, asi que ninguna perilla de rampa, de
# blanking ni de re-cero le gana nada: lo que hay que acelerar es el interprete.
#
# Son 139.130 ciclos de 68000 en 25,8 ms a 150 MHz = 27,8 ciclos de M33 por ciclo
# de 68000, que es mucho para Musashi. Y el juego se enlaza en la PSRAM (ver
# rp2350_game_ram.ld) y ejecuta a traves de la cache XIP — el peor patron posible
# para un interprete: una tabla de despacho de 107 KB que salta a un manejador
# distinto en cada instruccion.
#
# `rp2350_start.s` YA copia `.sram_text` a la SRAM interna antes de main(), y el
# script de enlazado reserva 220 KB para ello. Asi que no hace falta tocar ni el
# SDK ni la receta compartida: basta con que el codigo de Musashi ESTE en esa
# seccion. Como son fuentes de terceros y no se pueden anotar funcion a funcion
# (m68kops.c son miles), se compilan aparte SIN -ffunction-sections —para que todo
# caiga en un solo `.text`— y se renombra la seccion.
#
#     m68kops.c  107.226 B      de 225.280 disponibles. Cabe con holgura.
#     m68kcpu.c    9.950 B
#
# softfloat.c NO entra: es la FPU del 68020+, este juego no la toca, y son bytes
# de SRAM a cambio de nada.
#
# MUSASHI_SRAM=0 vuelve a compilarlos como dos fuentes mas, en PSRAM. Es el
# control del experimento y tiene que seguir existiendo: la cache XIP ya se acuso
# en falso una vez en este proyecto, y la unica forma de saberlo es tener los dos
# binarios y el mismo `emul=` en la misma escena.
MUSASHI_SRAM ?= 1
ifeq ($(MUSASHI_SRAM),1)
MUSASHI_OBJ = build_rp2350/m68k_sram.o
else
MUSASHI_OBJ = $(MUSASHI)/m68kcpu.c $(MUSASHI)/m68kops.c
endif
# UNA SOLA ASIGNACION de UVM2_DEPS en todo el fichero, y por eso se construye con
# $(filter): los .o que hagan falta salen de las dos perillas de arriba, y un
# segundo `UVM2_DEPS =` mas abajo ganaria en silencio.
UVM2_DEPS   = $(GEN) $(filter %.o,$(MUSASHI_OBJ) $(RENDER_OBJ))

# FPSRTT=1 — los fotogramas por segundo por RTT. SOLO EN LOS CARTUCHOS, y por eso va
# aqui y no en RENDER_DEFS: sb_rtt.c lee TIMELR, un periferico del RP2350, y en el host
# o en el WASM eso es una direccion cualquiera.
#
#   make rp2350 FPSRTT=1            (copiar el .bin a la SD y arrancarlo)
#   probe-rs attach --chip RP235x build_rp2350/snowbros_sbt.elf
#
# POR DEFECTO 0, y no por ahorrar: la linea de telemetria sale por el anillo dos veces
# por segundo, o sea que la build de medida NO es la build que se juega. Un instrumento
# encendido de serie acaba midiendose a si mismo.
FPSRTT      ?= 0

# CATCHUP=1 — el tiempo de maquina lo marca el reloj y no el refresco, con tope
# (ver sb_hw.c). ENCENDIDO DE SERIE EN LOS CARTUCHOS, porque sin el el juego corre
# a fps/57,5 de su velocidad: al 83% en una escena media y al 51% en la peor, que
# es literalmente el sintoma con el que empezo esto ("el juego se ve lento").
#
# Y APAGADO EN EL HOST Y EN EL SIM, que es por lo que vive aqui y no en RENDER_DEFS:
# atarlo a un reloj de pared los haria no deterministas, y el host es donde se
# comparan volcados byte a byte y donde se cosechan los dumps de sprites.
#
#   make rp2350 CATCHUP=0     el control
CATCHUP     ?= 1
UVM2_CFLAGS_EXTRA = -DSB_FPSRTT=$(FPSRTT) -DSB_CATCHUP=$(CATCHUP)

# EL TOOLCHAIN, POR SU NOMBRE. uvm2.mk cae por defecto en el `arm-none-eabi-gcc`
# que haya en el PATH, y el de Homebrew VIENE SIN NEWLIB: se muere en `#include
# <stdint.h>` antes de llegar a una sola linea nuestra, con un error que parece
# de nuestras fuentes y no lo es. El bueno es el mismo que uvm2_pico.cmake ya usa
# para la .um2 (UVM2_ARM_TOOLCHAIN), asi que los dos cartuchos compilan con el
# mismo compilador — que es lo unico que hace comparables sus dos imagenes.
ARM_BIN     ?= $(firstword $(wildcard /Applications/ArmGNUToolchain/*/arm-none-eabi/bin) $(dir $(shell which arm-none-eabi-gcc)))
UVM2_CC      = $(ARM_BIN)/arm-none-eabi-gcc
UVM2_CXX     = $(ARM_BIN)/arm-none-eabi-g++
UVM2_OBJCOPY = $(ARM_BIN)/arm-none-eabi-objcopy

# -mcpu/-mthumb NO SON DECORACION, y su ausencia no se lee como tal. La .um2 se
# enlaza por cmake, que extrae de aqui solo los -I/-D/-include y pone la maquina
# por su cuenta; la receta rp2350 usa ESTOS FLAGS TAL CUAL. Sin ellos gcc compila
# para el ARM por defecto (v4T, modo ARM) y el enlazado falla dentro de libgcc
# —"conflicting CPU architectures v8-M.mainline vs v4T"— hablando de ficheros que
# no son nuestros. Anadirlos no cambia la .um2: ese camino no los mira.
#
# -ffreestanding ES IMPRESCINDIBLE: sdk_rp2350.c implementa memset como un bucle
# de bytes y el paso loop-idiom de gcc (activo desde -O2, y -Os lo lleva) lo
# reescribe COMO UNA LLAMADA A memset — recursion infinita a la primera. A dkong
# le costo una pantalla negra en hardware.
UVM2_CFLAGS = -Os -w $(CHEATFLAG) $(RENDER_DEFS) $(UVM2_CFLAGS_EXTRA) -Isrc -I$(AAE_SRC) \
              -ffunction-sections -fdata-sections \
              -mcpu=cortex-m33 -mthumb -ffreestanding -fno-common
UVM2_LDFLAGS_EXTRA = -Wl,--gc-sections
# UVM2_DEPS SE ASIGNA ARRIBA, con MUSASHI_SRAM, y NO se repite aqui. Estaba, y una
# segunda asignacion con `=` gana: el .o de Musashi no se habria construido antes
# del enlazado y el fallo habria sido "no such file", que no habla de esto. Es la
# misma trampa que tiene anotada el Makefile de dkong con GAME_CFLAGS.

# EL CARTUCHO ENLAZA CONTRA NEWLIB, no con -nostdlib como los 41 puertos AAE.
#
# Musashi atrapa los errores de bus con setjmp/longjmp (m68kcpu.h:631), y eso no
# se rellena con un stub: `setjmp` va declarado __returns_twice, el compilador
# genera m68k_execute contando con ello, y una implementacion escrita a mano que
# no guarde exactamente los registros que toca rompe LEJOS de la causa. Ademas
# hacen falta sscanf, strchr, atoi y compania para los caminos de depuracion, que
# siguen compilados aunque getenv() los deje apagados. dkong y speedfrk ya se
# enlazan asi (--specs=nosys.specs); son ~30 KB sobre una imagen de 610 KB que
# vive en 8 MB de PSRAM.
#
# `end` ES EL PRINCIPIO DEL MONTON, y lo pide _sbrk de libnosys. dkong le pone
# 0x20080000, que es el TOPE de la SRAM interna: alli el monton crece hacia la
# nada y solo es inofensivo porque nadie llama a malloc. Aqui SI hay malloc en la
# imagen (lo arrastra el stdio de newlib), asi que se deriva del enlazado en vez
# de escribirlo a ojo: _bss_end, el final de lo nuestro, con los MB de PSRAM
# libres por delante.
RP2350_LDFLAGS = -nostartfiles --specs=nosys.specs \
                 -Wl,--gc-sections -Wl,-T,$(RP2350_SDK)/rp2350_game_ram.ld \
                 -Wa,--defsym,DUAL_CORE_FLAG=0x44430001 \
                 -Wl,--defsym,end=_bss_end

include $(HOME)/projects/vectrex-pseudo-python/ide/electron/resources/uvmc2-sdk/uvm2-sdk/uvm2.mk

# El nombre corto, que es el que escribe todo el mundo y el que busca el IDE en
# [targets.rp2350]. uvm2.mk declara `rp2350-cart` y `snowbros_sbt_rp2350`.
rp2350: rp2350-cart
.PHONY: rp2350

# ---- el .o de Musashi con su codigo en `.sram_text` ------------------------
# Va DESPUES del include porque usa UVM2_CFLAGS_CLEAN, que lo construye uvm2.mk.
#
# SIN -ffunction-sections a proposito: con el, cada funcion cae en su propia
# `.text.<nombre>` y habria que renombrarlas de una en una (miles). Sin el, todo
# el modulo cae en un unico `.text` y una sola llamada a objcopy lo mueve.
# Se pierde el --gc-sections dentro de estos dos ficheros, que da igual: de
# Musashi se usa casi todo y lo que sobra son unos pocos KB de una SRAM que
# tiene 100 KB libres despues de esto.
#
# `ld -r` los junta antes de renombrar para que sea UNA seccion y no dos.
# MUSASHI_OPT: el resto del juego se compila -Os porque la imagen tiene que caber,
# pero Musashi ya no comparte sitio con nadie — vive en su propia seccion y en la
# SRAM interna, donde sobran 107 KB. Un interprete a -Os paga caro: son saltos
# indirectos y bucles calientes, justo lo que -Os deja sin desenrollar y sin
# alinear.
#
# `-Os` se FILTRA ademas de anadir `-O2`: gcc coge la ultima, asi que anadir sin
# quitar funcionaria, pero deja dos niveles de optimizacion en la misma linea y el
# siguiente que la lea no sabe cual manda. Una perilla que no se lee es una perilla
# que acaba desconectada.
#
#   make rp2350 MUSASHI_OPT=-Os     el control
MUSASHI_OPT   ?= -O2
MUSASHI_CFLAGS = $(filter-out -ffunction-sections -Os,$(UVM2_CFLAGS_CLEAN)) \
                 $(MUSASHI_OPT) -DVPY_DUAL_CORE

$(MUSASHI_OBJ): $(MUSASHI)/m68kcpu.c $(MUSASHI)/m68kops.c $(GEN) | $(RP2350_BUILD)
	$(UVM2_CC) $(MUSASHI_CFLAGS) -c $(MUSASHI)/m68kcpu.c -o $(RP2350_BUILD)/m68kcpu.o
	$(UVM2_CC) $(MUSASHI_CFLAGS) -c $(MUSASHI)/m68kops.c -o $(RP2350_BUILD)/m68kops.o
	$(ARM_BIN)/arm-none-eabi-ld -r $(RP2350_BUILD)/m68kcpu.o $(RP2350_BUILD)/m68kops.o \
	    -o $(RP2350_BUILD)/m68k_junto.o
	$(UVM2_OBJCOPY) --rename-section .text=.sram_text.musashi \
	    $(RP2350_BUILD)/m68k_junto.o $@
	@# SIN LISTA DE FLAGS, Y NO ES ESTILO. `--rename-section vieja=nueva,flags`
	@# SUSTITUYE las banderas de la seccion por exactamente las que se listen, y
	@# omitir `contents` la convierte en NOBITS: el codigo SE TIRA y la seccion
	@# queda a ceros. Aqui iba `,alloc,load,readonly,code` —que parecia completo— y
	@# el cartucho arrancaba, copiaba 117 KB de ceros a la SRAM y moria con
	@# UNDEFINSTR (CFSR=0x00010000) dentro de `.sram_text`.
	@#
	@# Lo peor es que NO SE VE: `objdump -h` sigue imprimiendo "CONTENTS, ALLOC,
	@# LOAD, READONLY, CODE" en la cabecera del .o renombrado. Solo `objdump -s`
	@# —los bytes— lo delata. Y el enlazado final sigue aplicando las reubicaciones,
	@# asi que los pools de literales aparecen con sus valores correctos entre los
	@# ceros y la seccion parece medio buena.
	@#
	@# LA COMPROBACION VA EN LA RECETA, no en un comentario: si la seccion vuelve a
	@# salir vacia, la build falla aqui y no en la consola.
	@$(ARM_BIN)/arm-none-eabi-objdump -s -j .sram_text.musashi $@ | \
	    awk 'NR>3 && $$2 !~ /^0+$$/ { ok=1 } END { exit !ok }' || \
	    { echo "*** $@: .sram_text.musashi esta a CEROS — objcopy ha tirado el codigo"; exit 1; }

# ---- sb_render.c con sus dos tablas calientes en `.sram_text` --------------
# CON -fdata-sections (al reves que Musashi): aqui NO se quiere mover el modulo
# entero —sb_vec_pts son 43 KB que no caben— sino DOS tablas concretas, y para
# eso cada una tiene que estar en su propia seccion. El resto se queda en PSRAM y
# --gc-sections sigue pudiendo tirar lo que no se use.
#
# Nombres DISTINTOS para cada una: renombrar dos secciones al mismo nombre en un
# solo objeto no es lo mismo que fusionarlas, y objcopy no promete el resultado.
$(RENDER_OBJ): src/sb_render.c $(GEN) | $(RP2350_BUILD)
	$(UVM2_CC) $(UVM2_CFLAGS_CLEAN) -DVPY_DUAL_CORE -c $< -o $(RP2350_BUILD)/sb_render_tmp.o
	$(UVM2_OBJCOPY) \
	    --rename-section .rodata.sb_tile_toprow=.sram_text.toprow \
	    --rename-section .rodata.sb_tile_blank=.sram_text.tileblank \
	    $(RP2350_BUILD)/sb_render_tmp.o $@
	@# EL MISMO GUARDIA QUE MUSASHI, y por la misma razon: una lista de flags en
	@# --rename-section convierte la seccion en NOBITS y la deja a ceros SIN
	@# avisar. Aqui no habria pantalla negra: saldrian tiles en blanco.
	@for s in .sram_text.toprow .sram_text.tileblank; do \
	    $(ARM_BIN)/arm-none-eabi-objdump -s -j $$s $@ | \
	      awk 'NR>3 && $$2 !~ /^0+$$/ { ok=1 } END { exit !ok }' || \
	      { echo "*** $@: $$s esta a CEROS"; exit 1; }; \
	done
	@echo "=== dibujo -> .sram_text: $$($(ARM_BIN)/arm-none-eabi-size -A $@ | awk '/sram_text/{s+=$$2} END{print s}') bytes ==="
	@echo "=== Musashi -> .sram_text: $$($(ARM_BIN)/arm-none-eabi-size -A $@ | awk '/sram_text/{print $$2}') bytes ==="

# ---- level-background capture harness --------------------------------------
# host_levelcap: like the host but with SB_FORCE_LEVEL wired in (see sb_hw.c),
# so tools/compose_levels.py can force each floor and grab its static scenery.
host-levelcap: $(GEN) | build
	$(HOST_CC) $(HOST_CFLAGS) -DSB_LEVELCAP $(SRC) src/host_vec.c -lm -o build/host_levelcap
	@echo "=== host-levelcap: build/host_levelcap ==="
.PHONY: host-levelcap
