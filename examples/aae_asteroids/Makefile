# AAE Asteroids → RP2350 cartridge (C game on libvpy). WORK IN PROGRESS.
# See docs/AAE_RP2350_PORT.md. `asteroid.c` already compiles for thumbv8m; the
# remaining work is the rest of the file set + ROM loader + machine setup + link.
#
# AAE source lives OUTSIDE this repo (see [[pitrex-aae-source-location]]).
AAE_SRC     ?= $(HOME)/projects/pitrex-baremetal/aae
RP2350_SDK  ?= $(HOME)/projects/vectrex-pseudo-python/ide/electron/resources/rp2350-sdk

# The IDE's simulator build injects PITREX_SIM_SDK + VPY_C_SDK (paths into the
# app resources). Honour those names so the IDE and a manual `make` agree on the
# shim; fall back to the in-repo dev locations when building by hand.
PITREX_SIM_SDK ?= $(HOME)/projects/vectrex-pseudo-python/ide/electron/resources/pitrex-sim
VPY_C_SDK      ?= $(HOME)/projects/vectrex-pseudo-python/ide/electron/resources/vpy-c
VPY_C_INC   ?= $(VPY_C_SDK)/include
PITREX_INC  ?= $(PITREX_SIM_SDK)/include

# Named RP2350_CC (not CC) so a `CC=cc` in the environment can't override it and
# drag in the host clang, which rejects -mcpu=cortex-m33.
RP2350_CC   ?= arm-none-eabi-gcc
OBJCOPY     ?= arm-none-eabi-objcopy

# -std=gnu11: AAE is K&R C (`int (*f)()` = unspecified args). GCC 15 defaults to
#   C23 where `()` means `(void)`, which turns AAE's handler tables into errors.
# CCNT0(): PiTrex ARM cycle-counter profiling macro, absent here -> no-op.
# -Iinclude FIRST so our libc shims (stdlib/string/stdio) win over anything else.
CFLAGS  = -mthumb -mcpu=cortex-m33 -mfloat-abi=soft -ffreestanding -Os -std=gnu11 \
          -ffunction-sections -fdata-sections -DVPY_RP2350 -D'CCNT0(x)=do{}while(0)' \
          -Iinclude -Isrc -I$(AAE_SRC) -I$(VPY_C_INC) -I$(PITREX_INC)
LDFLAGS = -nostdlib -Wl,--gc-sections -Wl,-T,$(RP2350_SDK)/rp2350_game_ram.ld

# Minimal Asteroids file set (STARTING POINT — refine as the build links):
#   6502 CPU + interface + frame control + the Asteroids driver/DVG + utils.
# Sound (pokey), high-score EEPROM (earom), file/zip loaders are stubbed or
# replaced (embedded ROMs); logging is a no-op via the libc shim.
AAE_SRCS = \
  $(AAE_SRC)/asteroid.c \
  $(AAE_SRC)/m6502/m6502.c \
  $(AAE_SRC)/m6502/m6502zp.c \
  $(AAE_SRC)/cpuintrf.c \
  $(AAE_SRC)/cpu_control.c \
  $(AAE_SRC)/rand.c \
  $(AAE_SRC)/acommon.c

LOCAL_SRCS = src/main.c src/libc_stub.c src/aae_stubs.c src/aae_machine.c

aae_asteroids_rp2350: | build_rp2350
	$(RP2350_CC) $(CFLAGS) $(LDFLAGS) \
	    $(RP2350_SDK)/rp2350_start.s $(LOCAL_SRCS) $(AAE_SRCS) $(RP2350_SDK)/sdk_rp2350.c \
	    -lgcc -o build_rp2350/aae_asteroids.elf
	$(OBJCOPY) -O binary build_rp2350/aae_asteroids.elf build_rp2350/aae_asteroids_sd.bin
	@echo "=== Build (rp2350 SD game): build_rp2350/aae_asteroids_sd.bin ==="

build_rp2350:
	mkdir -p build_rp2350

# ---- IDE simulator (WASM) --------------------------------------------------
# Runs the SAME AAE file set + aae_machine/aae_stubs against the pitrex-sim host
# shim (sdk_host.c), compiled with emscripten, and loaded in the IDE emulator
# panel. Emscripten provides a real libc, so unlike the rp2350 build this does
# NOT use -Iinclude (our freestanding shims) and does NOT compile libc_stub.c —
# the real headers/functions win. -std=gnu11 + the CCNT0 no-op are still needed.
# The [simulate] section in aae_asteroids.cvproj points the IDE at build_wasm/game.js.
EMCC        ?= emcc
# emcc needs Python >= 3.10. The IDE puts emcc on PATH but NOT emsdk's bundled
# python, so the system python (may be 3.9) is picked and emcc aborts with
# "emscripten requires python 3.10 or above". Prepend emsdk's own python for the
# sim build so it works both from a shell and from the IDE's minimal PATH.
EMSDK        ?= $(HOME)/emsdk
EMSDK_PY     := $(firstword $(wildcard $(EMSDK)/python/*/bin))
EMCC_PATH    := $(if $(EMSDK_PY),$(EMSDK_PY):,)$(PATH)
WASM_SRCS    = src/main.c src/aae_stubs.c src/aae_machine.c
WASM_CFLAGS  = -std=gnu11 -O2 -D'CCNT0(x)=do{}while(0)' \
               -Isrc -I$(AAE_SRC) -I$(VPY_C_INC) -I$(PITREX_INC)
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
.PHONY: aae_asteroids_rp2350 sim clean
