# Shared build rules for the C individual_tests (vpy.h runtime).
# A test Makefile sets NAME then `include ../common.mk`.
# Targets: $(NAME)_pitrex (hardware kernel), $(NAME)_wasm (IDE simulator).

PITREX_SDK      ?= $(HOME)/projects/pitrex-baremetal
VPY_C_SDK       ?= $(HOME)/projects/vectrex-pseudo-python/ide/electron/resources/vpy-c
PITREX_SIM_SDK  ?= $(HOME)/projects/vectrex-pseudo-python/ide/electron/resources/pitrex-sim

# ---- real PiTrex hardware ----
ARM_CC          = /opt/arm-toolchain/bin/arm-none-eabi-gcc
ARM_OBJCOPY     = /opt/arm-toolchain/bin/arm-none-eabi-objcopy
PITREX_LIB_DIR := $(PITREX_SDK)/pitrex/lib7
ARM_CFLAGS = -Ofast -ffreestanding -nostartfiles -fuse-ld=bfd \
             -mhard-float -mfloat-abi=hard -mfpu=neon-fp-armv8 -march=armv8-a -mtune=cortex-a53 \
             -DRASPPI=3 -DUSE_PL011_UART=1 \
             -I$(PITREX_SDK)/pitrex -I$(PITREX_SDK)/pitrex/vectrex/uspi/include -I$(VPY_C_SDK)/include -Isrc
ARM_LIBS = -L$(PITREX_LIB_DIR) -lvectrexInterface -luspi -lm -lc \
           $(PITREX_LIB_DIR)/linkerHeapDefBoot.ld -lbaremetal

$(NAME)_pitrex: | build_pitrex
	$(ARM_CC) $(ARM_CFLAGS) src/main.c $(VPY_C_SDK)/vpy.c $(ARM_LIBS) -o build_pitrex/$(NAME).elf
	$(ARM_OBJCOPY) build_pitrex/$(NAME).elf -O binary kernel7l.img
	@echo "=== Build OK: kernel7l.img ==="

build_pitrex:
	mkdir -p build_pitrex

# ---- IDE simulator (WASM) ----
EMCC ?= emcc
WASM_LDFLAGS = -sASYNCIFY -sASYNCIFY_STACK_SIZE=65536 \
               -sINITIAL_MEMORY=33554432 -sALLOW_MEMORY_GROWTH=1 \
               -sINVOKE_RUN=0 -sEXIT_RUNTIME=0 \
               -sMODULARIZE=1 -sEXPORT_NAME=createSimModule -sEXPORTED_RUNTIME_METHODS=callMain,FS

$(NAME)_wasm: | build_wasm
	$(EMCC) -I$(PITREX_SIM_SDK)/include -I$(VPY_C_SDK)/include -Isrc -O2 \
	        src/main.c $(VPY_C_SDK)/vpy.c $(PITREX_SIM_SDK)/sdk_host.c $(WASM_LDFLAGS) \
	        -o build_wasm/$(NAME).js
	@echo "=== Sim build OK: build_wasm/$(NAME).js ==="

build_wasm:
	mkdir -p build_wasm

clean:
	rm -rf build_pitrex build_wasm kernel7l.img
.PHONY: clean $(NAME)_pitrex $(NAME)_wasm
