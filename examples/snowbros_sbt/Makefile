# snowbros_sbt — Snow Bros on the Vectrex: emulated 68000 (Musashi) + Pandora
# sprite list drawn as vectors.
#
#   make host  -> native harness (build/host_sb)
#                 AUTOCOIN=120 DUMPFRAME=400 ./build/host_sb 2> frame.txt
#   make sim   -> IDE emulator panel (F5), build_wasm/game.js
#
# Milestone: wireframe renderer (per-tile silhouette boxes). The traced .vec
# shapes in assets/vectors/ replace the boxes tile-family by tile-family.

AAE_SRC   = $(HOME)/projects/vectrex-arcade-private/aae-games/aae-src
MUSASHI   = $(AAE_SRC)/musashi

SRC = src/gmain.c src/sb_hw.c src/sb_render.c \
      $(MUSASHI)/m68kcpu.c $(MUSASHI)/m68kops.c $(MUSASHI)/softfloat/softfloat.c

GEN = src/sb_rom.h src/sb_tiles.h src/sb_sprites.h src/sb_font.h

#   CHEATS=1  invulnerability (the board's own DSW2 dip) — for reaching high
#             floors to grow the sprite catalogue, TNZS-style
CHEATFLAG = $(if $(filter 1,$(CHEATS)),-DSB_CHEATS_DEFAULT=1,)

HOST_CC     ?= cc
HOST_CFLAGS  = -std=gnu11 -O2 -w $(CHEATFLAG) -Isrc -I$(AAE_SRC)

build build_wasm:
	@mkdir -p $@

host: $(GEN) | build
	$(HOST_CC) $(HOST_CFLAGS) $(SRC) src/host_vec.c -lm -o build/host_sb
	@echo "=== host: build/host_sb ==="

# ---- IDE simulator (WASM) — this is what F5 runs ---------------------------
PITREX_SIM_SDK ?= $(HOME)/projects/vectrex-pseudo-python/ide/electron/resources/pitrex-sim
VPY_C_SDK      ?= $(HOME)/projects/vectrex-pseudo-python/ide/electron/resources/vpy-c
EMCC           ?= emcc
EMSDK          ?= $(HOME)/emsdk
EMSDK_EMCC     := $(EMSDK)/upstream/emscripten
EMSDK_PY       := $(firstword $(wildcard $(EMSDK)/python/*/bin))
EMCC_PATH      := $(if $(EMSDK_PY),$(EMSDK_PY):,)$(EMSDK_EMCC):$(PATH)

WASM_CFLAGS  = -std=gnu11 -O1 -w $(CHEATFLAG) -Isrc -I$(AAE_SRC) \
               -I$(PITREX_SIM_SDK)/include -I$(VPY_C_SDK)/include
WASM_LDFLAGS = -sASYNCIFY -sASYNCIFY_IGNORE_INDIRECT -sASYNCIFY_STACK_SIZE=1048576 \
               -sINITIAL_MEMORY=134217728 -sALLOW_MEMORY_GROWTH=1 \
               -sINVOKE_RUN=0 -sEXIT_RUNTIME=0 \
               -sMODULARIZE=1 -sEXPORT_NAME=createSimModule -sEXPORTED_RUNTIME_METHODS=callMain,FS

sim: $(GEN) | build_wasm
	PATH="$(EMCC_PATH)" $(EMCC) $(WASM_CFLAGS) $(SRC) src/sb_sim.c $(PITREX_SIM_SDK)/sdk_host.c $(WASM_LDFLAGS) -o build_wasm/game.js
	@echo "=== sim build OK: build_wasm/game.js ==="

src/sb_rom.h src/sb_tiles.h: tools/roms_to_c.py tools/extract_sprites.py
	python3 tools/roms_to_c.py

src/sb_sprites.h: tools/vec_to_sprites.py $(wildcard assets/vectors/*.vec)
	python3 tools/vec_to_sprites.py

src/sb_font.h: tools/make_font.py
	python3 tools/make_font.py

.PHONY: host sim

# ---- UVM2 cartridge (Ralf's multicart) -------------------------------------
# Same program, bare-metal: uvm2-sdk answers the svc ABI from inside the image.
# Freestanding build — src/uvm2_shim + sb_libc_stub.c neutralise the host-only
# debug paths (getenv -> NULL turns them all off).
# 1.5MB image (68000 ROM + Musashi tables): only fits linked into external
# PSRAM. The artifact is a flat .bin for our PSRAM loader, NOT a .um2 module.
export UVM2_LOAD_PSRAM ?= 1
UVM2_NAME   = snowbros_sbt
UVM2_SRCS   = src/gmain.c src/sb_hw.c src/sb_render.c \
              $(MUSASHI)/m68kcpu.c $(MUSASHI)/m68kops.c $(MUSASHI)/softfloat/softfloat.c
UVM2_CFLAGS = -Os -w $(CHEATFLAG) -Isrc -I$(AAE_SRC) \
              -ffunction-sections -fdata-sections
UVM2_LDFLAGS_EXTRA = -Wl,--gc-sections
UVM2_DEPS   = $(GEN)
include $(HOME)/projects/vectrex-pseudo-python/ide/electron/resources/uvm2-sdk/uvm2.mk
