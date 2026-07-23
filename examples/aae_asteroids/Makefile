# AAE Asteroids → RP2350 cartridge (C game on libvpy). WORK IN PROGRESS.
# See docs/AAE_RP2350_PORT.md. `asteroid.c` already compiles for thumbv8m; the
# remaining work is the rest of the file set + ROM loader + machine setup + link.
#
# AAE source lives OUTSIDE this repo (see [[pitrex-aae-source-location]]).
AAE_SRC     ?= $(HOME)/projects/pitrex-baremetal/aae
RP2350_SDK  ?= $(HOME)/projects/vectrex-pseudo-python/ide/electron/resources/rp2350-sdk
VPY_C_INC   ?= $(HOME)/projects/vectrex-pseudo-python/ide/electron/resources/vpy-c/include
PITREX_INC  ?= $(HOME)/projects/vectrex-pseudo-python/ide/electron/resources/pitrex-sim/include

CC          ?= arm-none-eabi-gcc
OBJCOPY     ?= arm-none-eabi-objcopy

# -Iinclude FIRST so our libc shims (stdlib/string/stdio) win over anything else.
CFLAGS  = -mthumb -mcpu=cortex-m33 -mfloat-abi=soft -ffreestanding -Os \
          -ffunction-sections -fdata-sections -DVPY_RP2350 \
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

LOCAL_SRCS = src/main.c src/libc_stub.c

aae_asteroids_rp2350: | build_rp2350
	$(CC) $(CFLAGS) $(LDFLAGS) \
	    $(RP2350_SDK)/rp2350_start.s $(LOCAL_SRCS) $(AAE_SRCS) $(RP2350_SDK)/sdk_rp2350.c \
	    -lgcc -o build_rp2350/aae_asteroids.elf
	$(OBJCOPY) -O binary build_rp2350/aae_asteroids.elf build_rp2350/aae_asteroids_sd.bin
	@echo "=== Build (rp2350 SD game): build_rp2350/aae_asteroids_sd.bin ==="

build_rp2350:
	mkdir -p build_rp2350

clean:
	rm -rf build_rp2350
.PHONY: aae_asteroids_rp2350 clean
