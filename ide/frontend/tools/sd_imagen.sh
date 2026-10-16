#!/bin/sh
# sd_imagen.sh — una tarjeta SD para el emulador de la BIOS del cartucho propio.
#
# La BIOS lee la SD POR BLOQUES (sd.rs, FAT de verdad), asi que el emulador no le sirve
# una carpeta como al .um2 sino una IMAGEN FAT: esto la arma con hdiutil (macOS) a partir
# de una carpeta, como superfloppy FAT16 (sector 0 = VBR, que es lo que sd.rs::list_root
# reconoce por el 0xEB).
#
#   tools/sd_imagen.sh <carpeta> <salida.img> [MB]
#
# La carpeta lleva lo mismo que la tarjeta real: <JUEGO>.BIN en la raiz, roms/<juego>.zip
# y config/uvm2.cfg (512 bytes o mas).
set -e
DIR="$1"; OUT="$2"; MB="${3:-16}"
[ -d "$DIR" ] && [ -n "$OUT" ] || { echo "uso: $0 <carpeta> <salida.img> [MB]"; exit 2; }
TMP=$(mktemp -d)
# SIN FICHEROS ._*: hdiutil copia los atributos extendidos de macOS como AppleDouble
# (`._DKONG.BIN`, atributo oculto) y el directorio raiz de la tarjeta se llena de entradas
# que sd.rs::list_root toma por juegos — el primer .BIN de la lista era `_DKON~6.BIN`, 4 KB
# de basura, y el boton 4 lanzaba eso. Se limpian los atributos de la copia de origen.
hdiutil create -size "${MB}m" -fs "MS-DOS FAT16" -layout NONE -volname VSD \
    -srcfolder "$DIR" -format UDRW -o "$TMP/sd.dmg" >/dev/null
# Aun con los atributos limpios hdiutil deja los ._*: se montan y se borran de verdad.
MNT=$(hdiutil attach -nobrowse -readwrite "$TMP/sd.dmg" | awk '/\/Volumes\//{print $NF}')
find "$MNT" -name '._*' -delete
rm -rf "$MNT/.fseventsd" "$MNT/.Trashes" 2>/dev/null || true
hdiutil detach "$MNT" >/dev/null
mv "$TMP/sd.dmg" "$OUT"
rm -rf "$TMP"
echo "=> $OUT ($(wc -c <"$OUT" | tr -d ' ') bytes)"
