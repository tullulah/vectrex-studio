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

# UVM2_DEPS lets a project name generated headers the build needs first.
uvm2: $(UVM2_DEPS) $(UVM2_SDK_OBJS) $(UVM2_BUILD)/svc_bridge.o | $(UVM2_BUILD)
	$(UVM2_LINKER) $(UVM2_CFLAGS_CLEAN) \
	    $(if $(UVM2_LDFLAGS_EXTRA),$(UVM2_LDFLAGS_EXTRA),-nostdlib) \
	    -Wl,--gc-sections -Wl,-T,$(UVM2_SDK)/uvm2_game.ld \
	    $(UVM2_SDK)/uvm2_start.s $(UVM2_SDK)/uvm2_svc_entry.s \
	    $(UVM2_SRCS) $(UVM2_CXXSRCS) \
	    $(UVM2_SDK_OBJS) $(UVM2_BUILD)/svc_bridge.o \
	    $(UVM2_LDLIBS) -lgcc -o $(UVM2_BUILD)/$(UVM2_NAME).elf
	$(UVM2_OBJCOPY) -O binary $(UVM2_BUILD)/$(UVM2_NAME).elf $(UVM2_BUILD)/$(UVM2_NAME).bin
	$(VPY_CLI) package-um2 $(UVM2_BUILD)/$(UVM2_NAME).bin --out $(UVM2_BUILD)/$(UVM2_NAME).um2
	@echo "=== Build OK (uvm2 SD game): $(UVM2_BUILD)/$(UVM2_NAME).um2 ==="

$(UVM2_BUILD):
	mkdir -p $(UVM2_BUILD)

uvm2-clean:
	rm -rf $(UVM2_BUILD)

.PHONY: uvm2 uvm2-clean
