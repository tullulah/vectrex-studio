# Shared build rules for the C individual_tests (vpy.h runtime).
# A test Makefile sets NAME then `include ../common.mk`.
# Targets: $(NAME)_pitrex (hardware kernel), $(NAME)_wasm (IDE simulator).

PITREX_SDK      ?= $(HOME)/projects/pitrex-baremetal
VPY_C_SDK       ?= $(HOME)/projects/vectrex-pseudo-python/ide/electron/resources/vpy-c
PITREX_SIM_SDK  ?= $(HOME)/projects/vectrex-pseudo-python/ide/electron/resources/pitrex-sim

# ---- compiled assets (.vmus/.vsfx audio + .vec vectors -> C headers) ----
# Each asset under assets/ is compiled to gen/<stem>.h by vpy_cli, reusing the
# same notes->PSG / path-geometry compiler as the ARM/PiTrex backend. main.c
# includes them and passes the arrays to PLAY_MUSIC / PLAY_SFX / DRAW_VECTOR.
VPY_CLI     ?= $(HOME)/projects/vectrex-pseudo-python/buildtools/target/debug/vpy_cli
GEN_DIR     := gen
AUDIO_SRCS  := $(wildcard assets/music/*.vmus assets/sfx/*.vsfx assets/*.vmus assets/*.vsfx)
VEC_SRCS    := $(wildcard assets/vectors/*.vec assets/*.vec)
# .vplay levels compile to gen/<stem>.h too (byte image + sprite table). They
# `#include` the per-sprite .vec headers, so VEC_SRCS must be listed FIRST so
# their gen/<name>.h exist by the time the level header is compiled.
LEVEL_SRCS  := $(wildcard assets/playground/*.vplay assets/*.vplay)
# .vanim animations compile to gen/<stem>.h (PI anim descriptor + sprite table).
# They `#include` their frame .vec headers, so VEC_SRCS must precede them.
ANIM_SRCS   := $(wildcard assets/animations/*.vanim assets/*.vanim)
ASSET_SRCS  := $(AUDIO_SRCS) $(VEC_SRCS) $(ANIM_SRCS) $(LEVEL_SRCS)

# `gen_audio` retained as an alias for older test Makefiles.
gen_audio: gen_assets
gen_assets: | $(GEN_DIR)
	@for f in $(ASSET_SRCS); do \
	  name=$$(basename $$f); stem=$${name%.*}; \
	  echo "  [asset] $$f -> $(GEN_DIR)/$$stem.h"; \
	  $(VPY_CLI) compile-asset $$f --format c --out $(GEN_DIR)/$$stem.h >/dev/null; \
	done

$(GEN_DIR):
	mkdir -p $(GEN_DIR)

# ---- real PiTrex hardware ----
ARM_CC          = /opt/arm-toolchain/bin/arm-none-eabi-gcc
ARM_OBJCOPY     = /opt/arm-toolchain/bin/arm-none-eabi-objcopy
PITREX_LIB_DIR := $(PITREX_SDK)/pitrex/lib7
ARM_CFLAGS = -Ofast -ffreestanding -nostartfiles -fuse-ld=bfd \
             -mhard-float -mfloat-abi=hard -mfpu=neon-fp-armv8 -march=armv8-a -mtune=cortex-a53 \
             -DRASPPI=3 -DUSE_PL011_UART=1 \
             -I$(PITREX_SDK)/pitrex -I$(PITREX_SDK)/pitrex/vectrex/uspi/include -I$(VPY_C_SDK)/include -Isrc -I$(GEN_DIR)
ARM_LIBS = -L$(PITREX_LIB_DIR) -lvectrexInterface -luspi -lm -lc \
           $(PITREX_LIB_DIR)/linkerHeapDefBoot.ld -lbaremetal

$(NAME)_pitrex: gen_assets | build_pitrex
	$(ARM_CC) $(ARM_CFLAGS) src/main.c $(VPY_C_SDK)/vpy.c $(ARM_LIBS) -o build_pitrex/$(NAME).elf
	$(ARM_OBJCOPY) build_pitrex/$(NAME).elf -O binary kernel7l.img
	@echo "=== Build OK: kernel7l.img ==="

build_pitrex:
	mkdir -p build_pitrex

# ---- RP2350 cartridge (SD-launched game via the cart BIOS) ----
# main.c + vpy.c + the RP2350 SDK backend (sdk_rp2350.c: maps the libvpy SDK
# contract onto BIOS `svc` traps) + the header/entry stub, linked RAM-resident
# at 0x20040000 (rp2350_game_ram.ld). Produces <name>_sd.bin — the launcher
# reads it off the SD card and jumps to game_main. Same main.c/vpy.c as PiTrex
# and WASM; only the SDK backend differs.
RP2350_SDK     ?= $(HOME)/projects/vectrex-pseudo-python/ide/electron/resources/rp2350-sdk
RP2350_CC      ?= arm-none-eabi-gcc
RP2350_OBJCOPY ?= arm-none-eabi-objcopy
RP2350_CFLAGS   = -mthumb -mcpu=cortex-m33 -mfloat-abi=soft \
                  -ffreestanding -Os -ffunction-sections -fdata-sections \
                  -I$(VPY_C_SDK)/include -I$(PITREX_SIM_SDK)/include -Isrc -I$(GEN_DIR)
RP2350_LDFLAGS  = -nostdlib -Wl,--gc-sections -Wl,-T,$(RP2350_SDK)/rp2350_game_ram.ld

$(NAME)_rp2350: gen_assets | build_rp2350
	$(RP2350_CC) $(RP2350_CFLAGS) $(RP2350_LDFLAGS) \
	    $(RP2350_SDK)/rp2350_start.s src/main.c $(VPY_C_SDK)/vpy.c $(RP2350_SDK)/sdk_rp2350.c \
	    -lgcc -o build_rp2350/$(NAME).elf
	$(RP2350_OBJCOPY) -O binary build_rp2350/$(NAME).elf build_rp2350/$(NAME)_sd.bin
	@echo "=== Build OK (rp2350 SD game): build_rp2350/$(NAME)_sd.bin ==="

build_rp2350:
	mkdir -p build_rp2350

# ---- IDE simulator (WASM) ----
EMCC ?= emcc
WASM_LDFLAGS = -sASYNCIFY -sASYNCIFY_STACK_SIZE=65536 \
               -sINITIAL_MEMORY=33554432 -sALLOW_MEMORY_GROWTH=1 \
               -sINVOKE_RUN=0 -sEXIT_RUNTIME=0 \
               -sMODULARIZE=1 -sEXPORT_NAME=createSimModule -sEXPORTED_RUNTIME_METHODS=callMain,FS

$(NAME)_wasm: gen_assets | build_wasm
	$(EMCC) -I$(PITREX_SIM_SDK)/include -I$(VPY_C_SDK)/include -Isrc -I$(GEN_DIR) -O2 \
	        src/main.c $(VPY_C_SDK)/vpy.c $(PITREX_SIM_SDK)/sdk_host.c $(WASM_LDFLAGS) \
	        -o build_wasm/$(NAME).js
	@echo "=== Sim build OK: build_wasm/$(NAME).js ==="

build_wasm:
	mkdir -p build_wasm

clean:
	rm -rf build_pitrex build_wasm build_rp2350 gen kernel7l.img
.PHONY: clean gen_audio gen_assets $(NAME)_pitrex $(NAME)_wasm $(NAME)_rp2350
