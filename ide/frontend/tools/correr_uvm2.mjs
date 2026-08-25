/* Correr una imagen .um2 en Uvm2System SIN NAVEGADOR, para poder iterar sin pedirle a
 * nadie que pulse Shift+F5 y me pegue la consola.
 *
 *   node --experimental-strip-types tools/correr_uvm2.mjs <imagen.um2> [frames] [elf]
 *
 * Imprime lo mismo que el informe del panel —vectores por frame, escrituras a la VIA, y
 * donde gira si no dibuja— y ademas resuelve el PC contra el ELF si se le pasa. Todo el
 * ciclo de hoy (cambiar el emulador, probar, leer el PC, repetir) cabe aqui en segundos.
 */
import { readFileSync, readdirSync, statSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { execFileSync } from "node:child_process";
import { Uvm2System } from "../src/emulator/systems/Uvm2System.ts";

const [img, nFrames = "180", elf] = process.argv.slice(2);
if (!img) { console.error("uso: correr_uvm2.mjs <imagen.um2> [frames] [elf]"); process.exit(2); }

const sys = new Uvm2System();

/* EL ELF Y LA SD, igual que hara el IDE. Sin ELF no hay simbolos que atrapar y el juego
 * pinta su X de "falta el romset"; con ellos, el emulador atiende uvm2_sd_leer desde
 * ~/VectrexStudio/sd, que es la MISMA carpeta que usa el simulador. */
if (elf) sys.setElf(new Uint8Array(readFileSync(elf)));
{
  const raiz = join(homedir(), "VectrexStudio", "sd");
  const files = {};
  const anda = (dir, rel) => {
    let ent = []; try { ent = readdirSync(dir, { withFileTypes: true }); } catch { return; }
    for (const e of ent) {
      if (e.name.startsWith(".")) continue;
      const p = join(dir, e.name), r = rel ? `${rel}/${e.name}` : e.name;
      if (e.isDirectory()) anda(p, r);
      else try { if (statSync(p).size <= 2 << 20) files[r.toLowerCase()] = new Uint8Array(readFileSync(p)); } catch {}
    }
  };
  anda(raiz, "");
  sys.setSdFiles(files);
}

sys.init(new Uint8Array(readFileSync(img)));

let total = 0, conVectores = 0;
/* Avance cada 500 frames: un juego que arranca despacio y uno colgado se distinguen por
 * si los contadores SE MUEVEN, no por el total al final. */
const t0 = Date.now();
for (let f = 0; f < Number(nFrames); f++) {
  const segs = sys.runFrame();
  total += segs.length;
  if (segs.length) conVectores++;
  if ((f + 1) % 500 === 0) {
    const q = (sys /** @type {any} */);
    console.log(`    frame ${f + 1}: ${total} segmentos, bus=${q.busCycle}, ` +
                `${((Date.now() - t0) / 1000).toFixed(0)}s`);
  }
}
console.log(`  ${nFrames} frames: ${total} segmentos, ${conVectores} frames con dibujo`);
/* Los contadores internos: sin ellos "no dibuja" no distingue "no escribe a la VIA" de
 * "escribe y el haz no se mueve", que se arreglan en sitios opuestos. */
const q = (sys /** @type {any} */);
console.log(`  escrituras a la VIA: ${q.viaWrites ?? '?'}   ciclos de bus: ${q.busCycle}` +
            `   palabras del stream: ${q.pioPalabras ?? '?'}`);

/* LOS CONTADORES DEL PROPIO JUEGO, leidos de su memoria por el simbolo del ELF. Dicen si
 * el juego CREE que dibuja: si el emite 600 vectores y en pantalla salen 2, el problema
 * esta en el camino; si el emite 2, esta en el juego. Son dos sitios opuestos. */
if (elf) {
  try {
    const nm = execFileSync("arm-none-eabi-nm", [elf]).toString();
    const l = nm.split("\n").find(x => x.endsWith(" uvm2_stats"));
    if (l) {
      const base = parseInt(l.split(" ")[0], 16);
      const q = (sys /** @type {any} */);
      const rd = (i) => q.read32(base + i * 4) >>> 0;
      console.log(`  el juego dice: comandos=${rd(0)} bus=${rd(1)} vectores=${rd(9)} ` +
                  `saltos=${rd(10)} descartados=${rd(6)} recals=${rd(7)}`);
      /* Y POR QUE dibuja poco: si falta el romset, el juego pinta una X y nada mas. Esa
       * es una respuesta completamente distinta de "el camino de dibujo esta roto". */
      for (const sim of ["dk_rom_error", "uvm2_romzip_error", "uvm2_romzip_bytes"]) {
        const ln = nm.split("\n").find(x => x.endsWith(" " + sim));
        if (ln) console.log(`    ${sim} = ${q.read32(parseInt(ln.split(" ")[0], 16)) >>> 0}`);
      }
    }
  } catch (e) { console.log("  (sin contadores:", String(e).slice(0, 60), ")"); }
}

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
