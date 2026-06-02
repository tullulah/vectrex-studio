# Dockerfile para compilar el PiTrex SDK (gtoal/pitrex) y extraer
# los archivos necesarios para poder compilar juegos VPy para PiTrex.
#
# USAR:
#   docker build -t pitrex-sdk-builder hardware/pitrex-sdk/
#   docker run --rm -v $(pwd)/ide/electron/resources/pitrex-sdk:/output pitrex-sdk-builder
#
# Produce en ide/electron/resources/pitrex-sdk/:
#   obj/          ← .o files (entry, baremetal, vectrex)
#   lib/          ← .a files (libarm, libbcm2835, etc.)
#   linker/       ← linker scripts
#   include/      ← headers necesarios para compilar user code

FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y \
    gcc-arm-none-eabi \
    binutils-arm-none-eabi \
    git \
    make \
    ca-certificates \
    --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

# Clonar el repo
WORKDIR /src
RUN git clone --depth=1 https://github.com/gtoal/pitrex.git

WORKDIR /src/pitrex

# ── Compilar pitrex/pitrex/ (bcm2835.o, pitrexio-gpio.o) ──────────────────
RUN cd pitrex/pitrex && make -f Makefile.baremetal all

# ── Compilar pitrex/vectrex/ (vectrexInterface.o, osWrapper.o, baremetalUtil.o) ──
RUN cd pitrex/vectrex && make -f Makefile.baremetal all

# ── Compilar piTrexBoot/ (loaderEntry.o, bootStrapMain.o) ─────────────────
# Nota: el Makefile principal de piTrexBoot compila los stubs baremetal también
RUN cd piTrexBoot && make all || true

# ── Compilar los stubs baremetal directamente ──────────────────────────────
# Estos son los .c/.S que cada juego necesita como entry point
RUN mkdir -p /build/baremetal && \
    CFLAGS="-Ofast -I/src/pitrex/pitrex -I/src/pitrex/pitrex/baremetal/lib2835 \
      -mfloat-abi=hard -nostartfiles -mfpu=vfp -march=armv6zk -mtune=arm1176jzf-s \
      -DRPI0 -DFREESTANDING -DPITREX_DEBUG -DMHZ1000 -DLOADER_START=0x8000" && \
    arm-none-eabi-gcc $CFLAGS \
      -c /src/pitrex/pitrex/baremetal/baremetalEntry.S \
      -o /build/baremetal/baremetalEntry_standalone.o && \
    arm-none-eabi-gcc $CFLAGS \
      -c /src/pitrex/pitrex/baremetal/bareMetalMain.c \
      -o /build/baremetal/bareMetalMain.o && \
    arm-none-eabi-gcc $CFLAGS \
      -c /src/pitrex/pitrex/baremetal/cstubs.c \
      -o /build/baremetal/cstubs.o && \
    arm-none-eabi-gcc $CFLAGS \
      -c /src/pitrex/pitrex/baremetal/rpi-armtimer.c \
      -o /build/baremetal/rpi-armtimer.o && \
    arm-none-eabi-gcc $CFLAGS \
      -c /src/pitrex/pitrex/baremetal/rpi-aux.c \
      -o /build/baremetal/rpi-aux.o && \
    arm-none-eabi-gcc $CFLAGS \
      -c /src/pitrex/pitrex/baremetal/rpi-gpio.c \
      -o /build/baremetal/rpi-gpio.o && \
    arm-none-eabi-gcc $CFLAGS \
      -c /src/pitrex/pitrex/baremetal/rpi-interrupts.c \
      -o /build/baremetal/rpi-interrupts.o && \
    arm-none-eabi-gcc $CFLAGS \
      -c /src/pitrex/pitrex/baremetal/rpi-systimer.c \
      -o /build/baremetal/rpi-systimer.o

# ── Compilar también con LOADER_START=0x4000000 (modo loader) ─────────────
RUN CFLAGS="-Ofast -I/src/pitrex/pitrex -I/src/pitrex/pitrex/baremetal/lib2835 \
      -mfloat-abi=hard -nostartfiles -mfpu=vfp -march=armv6zk -mtune=arm1176jzf-s \
      -DRPI0 -DFREESTANDING -DPITREX_DEBUG -DMHZ1000 -DLOADER_START=0x4000000" && \
    arm-none-eabi-gcc $CFLAGS \
      -c /src/pitrex/pitrex/baremetal/baremetalEntry.S \
      -o /build/baremetal/baremetalEntry_loader.o

# ── Crear linker script standalone (0x8000) ───────────────────────────────
RUN cat > /build/pitrex_standalone.ld << 'EOF'
/* PiTrex standalone linker script — game is kernel.img, loaded at 0x8000 */
ENTRY(_start)
SECTIONS {
    . = 0x8000;
    .text   : { *(.text*) }
    .rodata : { *(.rodata*) }
    .data   : { *(.data*) }
    .bss    : { *(.bss*) *(COMMON) }
    heap_low  = 0x2000000;
    heap_top  = 0x3f00000;
}
EOF

# ── Linker script para modo loader (0x4000000) ────────────────────────────
RUN cat > /build/pitrex_loader.ld << 'EOF'
/* PiTrex loader linker script — game loaded by piTrexBoot at 0x4000000 */
ENTRY(_start)
SECTIONS {
    . = 0x4000000;
    .text   : { *(.text*) }
    .rodata : { *(.rodata*) }
    .data   : { *(.data*) }
    .bss    : { *(.bss*) *(COMMON) }
    heap_low  = 0x5000000;
    heap_top  = 0xfffffff;
}
EOF

# ── Colectar todo en /sdk ──────────────────────────────────────────────────
RUN mkdir -p /sdk/obj/standalone /sdk/obj/loader /sdk/lib /sdk/linker /sdk/include/pitrex /sdk/include/baremetal

# .o files standalone
RUN cp /build/baremetal/baremetalEntry_standalone.o /sdk/obj/standalone/baremetalEntry.o && \
    cp /build/baremetal/bareMetalMain.o              /sdk/obj/standalone/ && \
    cp /build/baremetal/cstubs.o                     /sdk/obj/standalone/ && \
    cp /build/baremetal/rpi-armtimer.o               /sdk/obj/standalone/ && \
    cp /build/baremetal/rpi-aux.o                    /sdk/obj/standalone/ && \
    cp /build/baremetal/rpi-gpio.o                   /sdk/obj/standalone/ && \
    cp /build/baremetal/rpi-interrupts.o             /sdk/obj/standalone/ && \
    cp /build/baremetal/rpi-systimer.o               /sdk/obj/standalone/

# .o files loader mode
RUN cp /build/baremetal/baremetalEntry_loader.o      /sdk/obj/loader/baremetalEntry.o && \
    cp /build/baremetal/bareMetalMain.o              /sdk/obj/loader/ && \
    cp /build/baremetal/cstubs.o                     /sdk/obj/loader/ && \
    cp /build/baremetal/rpi-armtimer.o               /sdk/obj/loader/ && \
    cp /build/baremetal/rpi-aux.o                    /sdk/obj/loader/ && \
    cp /build/baremetal/rpi-gpio.o                   /sdk/obj/loader/ && \
    cp /build/baremetal/rpi-interrupts.o             /sdk/obj/loader/ && \
    cp /build/baremetal/rpi-systimer.o               /sdk/obj/loader/

# .o from pitrex/pitrex/ and pitrex/vectrex/ (same for both modes)
RUN cp /src/pitrex/pitrex/pitrex/build.baremetal/bcm2835.o         /sdk/obj/standalone/ && \
    cp /src/pitrex/pitrex/pitrex/build.baremetal/pitrexio-gpio.o   /sdk/obj/standalone/ && \
    cp /src/pitrex/pitrex/vectrex/build.baremetal/vectrexInterface.o /sdk/obj/standalone/ && \
    cp /src/pitrex/pitrex/vectrex/build.baremetal/osWrapper.o      /sdk/obj/standalone/ && \
    cp /src/pitrex/pitrex/vectrex/build.baremetal/baremetalUtil.o  /sdk/obj/standalone/ && \
    cp /src/pitrex/pitrex/pitrex/build.baremetal/bcm2835.o         /sdk/obj/loader/ && \
    cp /src/pitrex/pitrex/pitrex/build.baremetal/pitrexio-gpio.o   /sdk/obj/loader/ && \
    cp /src/pitrex/pitrex/vectrex/build.baremetal/vectrexInterface.o /sdk/obj/loader/ && \
    cp /src/pitrex/pitrex/vectrex/build.baremetal/osWrapper.o      /sdk/obj/loader/ && \
    cp /src/pitrex/pitrex/vectrex/build.baremetal/baremetalUtil.o  /sdk/obj/loader/

# .a precompiled libs
RUN cp /src/pitrex/pitrex/baremetal/lib*.a /sdk/lib/

# linker scripts
RUN cp /build/pitrex_standalone.ld    /sdk/linker/ && \
    cp /build/pitrex_loader.ld        /sdk/linker/ && \
    cp /src/pitrex/pitrex/baremetal/linkerHeapDefBoot.ld /sdk/linker/

# headers
RUN cp /src/pitrex/pitrex/vectrex/vectrexInterface.h  /sdk/include/ && \
    cp /src/pitrex/pitrex/vectrex/baremetalUtil.h      /sdk/include/ && \
    cp /src/pitrex/pitrex/pitrex/*.h                   /sdk/include/pitrex/ 2>/dev/null || true && \
    cp /src/pitrex/pitrex/baremetal/*.h                /sdk/include/baremetal/ 2>/dev/null || true

# SDK version info
RUN git -C /src/pitrex log --oneline -1 > /sdk/VERSION

CMD ["sh", "-c", \
  "cp -r /sdk/. /output/ && \
   echo '✓ PiTrex SDK copiado a /output' && \
   echo '  obj/standalone/ — .o para kernel.img (standalone, carga en 0x8000)' && \
   echo '  obj/loader/     — .o para piZero1/*.img (loader, carga en 0x4000000)' && \
   echo '  lib/            — .a precompilados' && \
   echo '  linker/         — linker scripts' && \
   find /output -name '*.o' -o -name '*.a' | wc -l | xargs echo '  archivos copiados:'"]
