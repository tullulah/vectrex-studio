/* Correr una imagen .um2 en Uvm2System SIN NAVEGADOR, para poder iterar sin pedirle a
 * nadie que pulse Shift+F5 y me pegue la consola.
 *
 *   node --experimental-strip-types tools/correr_uvm2.mjs <imagen.um2> [frames] [elf]
 *
 * Imprime lo mismo que el informe del panel —vectores por frame, escrituras a la VIA, y
 * donde gira si no dibuja— y ademas resuelve el PC contra el ELF si se le pasa. Todo el
 * ciclo de hoy (cambiar el emulador, probar, leer el PC, repetir) cabe aqui en segundos.
 */
import { readFileSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { Uvm2System } from "../src/emulator/systems/Uvm2System.ts";

const [img, nFrames = "180", elf] = process.argv.slice(2);
if (!img) { console.error("uso: correr_uvm2.mjs <imagen.um2> [frames] [elf]"); process.exit(2); }

const sys = new Uvm2System();
sys.init(new Uint8Array(readFileSync(img)));

let total = 0, conVectores = 0;
for (let f = 0; f < Number(nFrames); f++) {
  const segs = sys.runFrame();
  total += segs.length;
  if (segs.length) conVectores++;
}
console.log(`  ${nFrames} frames: ${total} segmentos, ${conVectores} frames con dibujo`);

/* DONDE ESTA EL NUCLEO 1. Saber que arranco no basta: si core 0 sigue esperandole, lo que
 * hace falta es donde se quedo EL. */
const c1 = (sys /** @type {any} */).cpu1;
if (c1) {
  const pc1 = c1.getReg(15) >>> 0;
  let quien = "";
  if (elf) { try {
    quien = execFileSync("arm-none-eabi-addr2line", ["-f", "-e", elf, "0x" + pc1.toString(16)])
              .toString().trim().split("\n").join("  ");
  } catch {} }
  console.log(`  nucleo 1 en 0x${pc1.toString(16)}  ${quien}`);
} else {
  console.log("  nucleo 1: NO arrancado (o ya termino)");
}

/* El PC donde gira, resuelto aqui mismo. Sin esto el numero es un jeroglifico y hay que
 * copiarlo a mano a addr2line, que es justo el paso que convierte una iteracion de
 * segundos en una de minutos. */
const perfil = (sys /** @type {any} */).perfil;
if (perfil && total === 0) {
  const top = [...perfil.entries()].sort((a, b) => b[1] - a[1]).slice(0, 3);
  const muestras = [...perfil.values()].reduce((a, b) => a + b, 0);
  console.log("  no dibuja. Donde gira:");
  for (const [pc, n] of top) {
    let quien = "";
    if (elf) {
      try {
        quien = execFileSync("arm-none-eabi-addr2line", ["-f", "-e", elf, "0x" + pc.toString(16)])
                  .toString().trim().split("\n").join("  ");
      } catch { /* sin toolchain: el numero solo */ }
    }
    console.log(`    0x${pc.toString(16)}  ${(100 * n / muestras).toFixed(1)}%  ${quien}`);
  }
}
