# AAE Tac/Scan → RP2350 cartridge (C game on libvpy). WORK IN PROGRESS.
# Sega G80 vector game: Z80 (mz80 core) + Sega's own vector generator. See the
# aae_asteroids Makefile for the shared rationale; [[aae-rp2350-feasibility]].
#
# AAE source lives OUTSIDE this repo (see [[pitrex-aae-source-location]]).
AAE_SRC     ?= $(HOME)/projects/pitrex-baremetal/aae
RP2350_SDK  ?= $(HOME)/projects/vectrex-pseudo-python/ide/electron/resources/rp2350-sdk

PITREX_SIM_SDK ?= $(HOME)/projects/vectrex-pseudo-python/ide/electron/resources/pitrex-sim
VPY_C_SDK      ?= $(HOME)/projects/vectrex-pseudo-python/ide/electron/resources/vpy-c
VPY_C_INC   ?= $(VPY_C_SDK)/include
PITREX_INC  ?= $(PITREX_SIM_SDK)/include

RP2350_CC   ?= arm-none-eabi-gcc
OBJCOPY     ?= arm-none-eabi-objcopy

# -std=gnu11: AAE is K&R C. -O3: Z80 interpreter is CPU-bound. -DVPY_DUAL_CORE +
# --defsym DUAL_CORE_FLAG: run the Z80 compute on core 1, draw on core 0 (like
# asteroids; see sdk_rp2350.c + firmware dc.rs).
CFLAGS  = -mthumb -mcpu=cortex-m33 -mfloat-abi=soft -ffreestanding -O3 -std=gnu11 \
          -ffunction-sections -fdata-sections -DVPY_RP2350 -DVPY_DUAL_CORE -D'CCNT0(x)=do{}while(0)' \
          -Wa,--defsym,DUAL_CORE_FLAG=0x44430001 \
          -include src/aae_compat.h -Iinclude -Isrc -I$(AAE_SRC) -I$(VPY_C_INC) -I$(PITREX_INC)
LDFLAGS = -nostdlib -Wl,--gc-sections -Wl,-T,$(RP2350_SDK)/rp2350_game_ram.ld

# Tac/Scan file set (STARTING POINT — refine as the build links):
#   Z80 CPU (mz80) + interface + frame control + the Sega G80 driver + utils.
# Sound (SegaG80snd: AY8910 + speech samples) is stubbed in aae_stubs.c.
AAE_SRCS = \
  $(AAE_SRC)/SegaG80.c \
  $(AAE_SRC)/SegaG80snd.c \
  $(AAE_SRC)/mz80/mz80.c \
  $(AAE_SRC)/cpuintrf.c \
  $(AAE_SRC)/cpu_control.c \
  $(AAE_SRC)/rand.c \
  $(AAE_SRC)/acommon.c

LOCAL_SRCS = src/main.c src/libc_stub.c src/aae_stubs.c src/aae_machine.c src/samples.c

aae_spacefury_rp2350: | build_rp2350
	$(RP2350_CC) $(CFLAGS) $(LDFLAGS) \
	    $(RP2350_SDK)/rp2350_start.s $(LOCAL_SRCS) $(AAE_SRCS) $(RP2350_SDK)/sdk_rp2350.c \
	    -lgcc -o build_rp2350/aae_spacefury.elf
	$(OBJCOPY) -O binary build_rp2350/aae_spacefury.elf build_rp2350/aae_spacefury_sd.bin
	@echo "=== Build (rp2350 SD game): build_rp2350/aae_spacefury_sd.bin ==="

build_rp2350:
	mkdir -p build_rp2350

# ---- IDE simulator (WASM) --------------------------------------------------
EMCC        ?= emcc
EMSDK        ?= $(HOME)/emsdk
EMSDK_PY     := $(firstword $(wildcard $(EMSDK)/python/*/bin))
EMCC_PATH    := $(if $(EMSDK_PY),$(EMSDK_PY):,)$(PATH)
WASM_SRCS    = src/main.c src/aae_stubs.c src/aae_machine.c src/samples.c
WASM_CFLAGS  = -std=gnu11 -O2 -D'CCNT0(x)=do{}while(0)' \
               -include src/aae_compat.h -Isrc -I$(AAE_SRC) -I$(VPY_C_INC) -I$(PITREX_INC)
WASM_LDFLAGS = -sASYNCIFY -sASYNCIFY_STACK_SIZE=65536 \
               -sINITIAL_MEMORY=33554432 -sALLOW_MEMORY_GROWTH=1 \
               -sINVOKE_RUN=0 -sEXIT_RUNTIME=0 \
               -sMODULARIZE=1 -sEXPORT_NAME=createSimModule -sEXPORTED_RUNTIME_METHODS=callMain,FS

sim: | build_wasm
	PATH="$(EMCC_PATH)" $(EMCC) $(WASM_CFLAGS) $(WASM_SRCS) $(AAE_SRCS) $(PITREX_SIM_SDK)/sdk_host.c \
	        $(WASM_LDFLAGS) -o build_wasm/game.js
	@echo "=== Sim build OK: build_wasm/game.js ==="

build_wasm:
	mkdir -p build_wasm

clean:
	rm -rf build_rp2350 build_wasm
.PHONY: aae_spacefury_rp2350 sim clean
