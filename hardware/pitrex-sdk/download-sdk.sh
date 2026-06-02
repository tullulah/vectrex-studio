#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# download-pitrex-sdk.sh
# Descarga el PiTrex SDK (fuente: gtoal/pitrex en GitHub) y lo instala en:
#   ide/electron/resources/pitrex-sdk/
#
# USO:
#   cd /ruta/a/vectrex-pseudo-python
#   bash hardware/pitrex-sdk/download-sdk.sh
#
# REQUISITOS:
#   curl (o wget)
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

REPO="https://raw.githubusercontent.com/gtoal/pitrex/master"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUT="$REPO_ROOT/ide/electron/resources/pitrex-sdk"

# ── colores ──────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; RESET='\033[0m'
ok()  { echo -e "${GREEN}✓${RESET} $*"; }
msg() { echo -e "${CYAN}$*${RESET}"; }
warn(){ echo -e "${YELLOW}⚠ $*${RESET}"; }

# ── helper: download ──────────────────────────────────────────────────────────
dl() {
    local url="$1" dst="$2"
    mkdir -p "$(dirname "$dst")"
    if command -v curl &>/dev/null; then
        curl -fsSL "$url" -o "$dst"
    elif command -v wget &>/dev/null; then
        wget -q "$url" -O "$dst"
    else
        echo "ERROR: ni curl ni wget disponibles"
        exit 1
    fi
}

msg "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
msg "  PiTrex SDK Downloader (fuente: gtoal/pitrex)"
msg "  Destino: $OUT"
msg "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ─────────────────────────────────────────────────────────────────────────────
# 1. Precompiled .a libraries (ya están en el repo)
# ─────────────────────────────────────────────────────────────────────────────
msg "\n[1/5] Descargando librerías .a precompiladas..."
LIBS="libarm.a libbcm2835.a libbob.a libconsole.a libdebug.a libff12c.a libhal.a libi2c.a libutils.a"
for lib in $LIBS; do
    dl "$REPO/pitrex/baremetal/$lib" "$OUT/lib/$lib"
    ok "lib/$lib"
done

# ─────────────────────────────────────────────────────────────────────────────
# 2. Fuentes de entrada (baremetalEntry.S, bareMetalMain.c, stubs, etc.)
#    Se compilarán on-the-fly durante el build por cmd_build_pitrex
# ─────────────────────────────────────────────────────────────────────────────
msg "\n[2/5] Descargando fuentes baremetal (pitrex/baremetal/)..."
BAREMETAL_SRCS="baremetalEntry.S bareMetalMain.c cstubs.c \
    rpi-armtimer.c rpi-aux.c rpi-gpio.c rpi-interrupts.c rpi-systimer.c"
for f in $BAREMETAL_SRCS; do
    dl "$REPO/pitrex/baremetal/$f" "$OUT/src/$f"
    ok "src/$f"
done

msg "\n[3/5] Descargando fuentes pitrex/pitrex/ y pitrex/vectrex/..."
# pitrex/pitrex/ — BCM y GPIO
PITREX_SRCS="bcm2835.c pitrexio-gpio.c"
for f in $PITREX_SRCS; do
    dl "$REPO/pitrex/pitrex/$f" "$OUT/src/$f"
    ok "src/$f"
done
# pitrex/vectrex/ — interfaz Vectrex
VECTREX_SRCS="vectrexInterface.c osWrapper.c baremetalUtil.c"
for f in $VECTREX_SRCS; do
    dl "$REPO/pitrex/vectrex/$f" "$OUT/src/$f"
    ok "src/$f"
done

# ─────────────────────────────────────────────────────────────────────────────
# 3. Headers
# ─────────────────────────────────────────────────────────────────────────────
msg "\n[4/5] Descargando headers..."
# La estructura esperada de includes es la misma que el repo gtoal/pitrex:
#   -I sdk/include        → accede a pitrex/ y vectrex/ subdir
#   -I sdk/include/lib2835 → accede a bcm2835_vc.h, ff.h, etc.
#   -I sdk/src            → headers relativos en el mismo directorio que el fuente

# pitrex/pitrex/ headers → include/pitrex/
mkdir -p "$OUT/include/pitrex"
for h in bcm2835.h pitrexio-gpio.h via6522.h; do
    dl "$REPO/pitrex/pitrex/$h" "$OUT/include/pitrex/$h" 2>/dev/null || warn "  (no encontrado: pitrex/$h)"
done

# pitrex/vectrex/ headers → include/vectrex/
mkdir -p "$OUT/include/vectrex"
for h in vectrexInterface.h baremetalUtil.h osWrapper.h ini.h; do
    dl "$REPO/pitrex/vectrex/$h" "$OUT/include/vectrex/$h" 2>/dev/null || warn "  (no encontrado: vectrex/$h)"
done

# pitrex/baremetal/lib2835/ headers → include/lib2835/
# (críticos: bcm2835_vc.h, bcm2835.h, ff.h, ffconf.h, diskio.h, integer.h)
mkdir -p "$OUT/include/lib2835"
for h in bcm2835.h bcm2835_vc.h bcm2835_aux.h bcm2835_gpio.h bcm2835_i2c.h bcm2835_spi.h \
          ff.h ffconf.h diskio.h integer.h debug.h console.h bob.h i2c.h; do
    dl "$REPO/pitrex/baremetal/lib2835/$h" "$OUT/include/lib2835/$h" 2>/dev/null || warn "  (no encontrado: lib2835/$h)"
done

# pitrex/baremetal/ headers propios (rpi-*.h, vectors.h) → include/
BAREMETAL_H="rpi-armtimer.h rpi-aux.h rpi-base.h rpi-gpio.h rpi-interrupts.h rpi-systimer.h vectors.h"
for h in $BAREMETAL_H; do
    dl "$REPO/pitrex/baremetal/$h" "$OUT/include/$h" 2>/dev/null || warn "  (no encontrado: $h)"
done

# También copiar rpi-*.h a include/baremetal/ para satisfacer <baremetal/rpi-aux.h> etc.
mkdir -p "$OUT/include/baremetal"
for h in $BAREMETAL_H; do
    cp "$OUT/include/$h" "$OUT/include/baremetal/$h" 2>/dev/null || true
done

# vectrexInterface.c incluye .i files como "vectorFont.i", "rasterFont.i", "commands.i"
for f in vectorFont.i rasterFont.i commands.i; do
    dl "$REPO/pitrex/vectrex/$f" "$OUT/src/$f" 2>/dev/null || warn "  (no encontrado: $f)"
done
ok "headers OK"

# ─────────────────────────────────────────────────────────────────────────────
# 4. Linker scripts
# ─────────────────────────────────────────────────────────────────────────────
msg "\n[5/5] Creando linker scripts..."
mkdir -p "$OUT/linker"

cat > "$OUT/linker/pitrex_standalone.ld" << 'EOF'
/* PiTrex standalone — game cargado por Pi Zero bootloader en 0x8000
   Copiar resultado a SD como kernel.img */
ENTRY(_start)
SECTIONS {
    . = 0x8000;
    .text   : { *(.text .text*) }
    .rodata : { *(.rodata .rodata*) }
    .data   : { *(.data .data*) }
    .bss    : {
        __bss_start = .;
        *(.bss .bss*) *(COMMON)
        __bss_end = .;
    }
    /DISCARD/ : { *(.ARM.exidx*) *(.ARM.extab*) }
}
heap_low  = 0x2000000;
heap_top  = 0x3f00000;
EOF
ok "linker/pitrex_standalone.ld"

cat > "$OUT/linker/pitrex_loader.ld" << 'EOF'
/* PiTrex loader mode — cargado por piTrexBoot en 0x4000000
   Copiar a piZero1/<nombre>.img */
ENTRY(_start)
SECTIONS {
    . = 0x4000000;
    .text   : { *(.text .text*) }
    .rodata : { *(.rodata .rodata*) }
    .data   : { *(.data .data*) }
    .bss    : {
        __bss_start = .;
        *(.bss .bss*) *(COMMON)
        __bss_end = .;
    }
    /DISCARD/ : { *(.ARM.exidx*) *(.ARM.extab*) }
}
heap_low  = 0x5000000;
heap_top  = 0xfffffff;
EOF
ok "linker/pitrex_loader.ld"

# ─────────────────────────────────────────────────────────────────────────────
# VERSION
# ─────────────────────────────────────────────────────────────────────────────
date '+downloaded: %Y-%m-%d %H:%M' > "$OUT/VERSION"
echo "source: https://github.com/gtoal/pitrex" >> "$OUT/VERSION"

# ─────────────────────────────────────────────────────────────────────────────
# Resumen
# ─────────────────────────────────────────────────────────────────────────────
echo ""
msg "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ok "PiTrex SDK instalado en $OUT"
echo ""
echo "  Contenido:"
echo "    src/      — fuentes C/S (se compilan al buildear)"
echo "    lib/      — librerías .a precompiladas"
echo "    include/  — headers"
echo "    linker/   — linker scripts (standalone + loader)"
echo ""
echo "  Siguiente paso:"
echo "    cd buildtools && cargo build --release -p vpy_cli"
echo "    cp target/release/vpy_cli ../ide/electron/resources/vpy_cli"
msg "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
