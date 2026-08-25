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
const caja = { x0: 1e9, x1: -1e9, y0: 1e9, y1: -1e9 };
for (let f = 0; f < Number(nFrames); f++) {
  const segs = sys.runFrame();
  total += segs.length;
  if (segs.length) conVectores++;
  /* LA CAJA DE TODOS LOS FRAMES, no la del ultimo: un eje que se mueve DE VEZ EN CUANDO se
   * lee como "clavado" si solo miras una instantanea. */
  for (const g of segs) {
    caja.x0 = Math.min(caja.x0, g.x0, g.x1); caja.x1 = Math.max(caja.x1, g.x0, g.x1);
    caja.y0 = Math.min(caja.y0, g.y0, g.y1); caja.y1 = Math.max(caja.y1, g.y0, g.y1);
  }
  /* MIRAR LOS SEGMENTOS, no solo contarlos. 42 por frame puede ser un dibujo o la misma
   * raya 42 veces, y eso no se distingue con un total. */
  if (f === Number(nFrames) - 1 && segs.length) {
    const caja = segs.reduce((a, s) => ({
      x0: Math.min(a.x0, s.x0, s.x1), x1: Math.max(a.x1, s.x0, s.x1),
      y0: Math.min(a.y0, s.y0, s.y1), y1: Math.max(a.y1, s.y0, s.y1),
    }), { x0: 1e9, x1: -1e9, y0: 1e9, y1: -1e9 });
    const unicos = new Set(segs.map(s => `${s.x0},${s.y0},${s.x1},${s.y1}`)).size;
    console.log(`  ultimo frame: ${segs.length} segmentos, ${unicos} distintos, ` +
                `caja x[${caja.x0.toFixed(0)}..${caja.x1.toFixed(0)}] ` +
                `y[${caja.y0.toFixed(0)}..${caja.y1.toFixed(0)}]`);
    const h = (sys /** @type {any} */).viaHist;
    const nom = ["ORB","ORA","DDRB","DDRA","T1CL","T1CH","T1LL","T1LH","T2CL","T2CH","SR","ACR","PCR","IFR","IER","ORAnh"];
    const qq = (sys /** @type {any} */);
    console.log(`  entradas: TXF0 directo=${qq.txfDirectas} por DMA=${qq.dmaPalabras}`);
    console.log(`  palabras: escritura=${qq.pioEsc} park=${qq.pioPark_n} silencio=${qq.pioSil}`);
    const oh = [...(sys /** @type {any} */).orbHist].map((n, v) => [v, n]).filter(x => x[1])
                 .sort((a, b) => b[1] - a[1]).slice(0, 6);
    console.log("  valores escritos a ORB: " + oh.map(([v, n]) => `0x${v.toString(16)}=${n}`).join("  "));
    const ah = [...(sys /** @type {any} */).oraHist].map((n, v) => [v, n]).filter(x => x[1]);
    console.log(`  ORA: ${ah.length} valores distintos, ` +
                `cambios del S&H de Y: ${(sys /** @type {any} */).cambiosYsh}`);
    console.log("  escrituras por registro: " +
      [...h].map((n, i) => n ? `${nom[i]}=${n}` : "").filter(Boolean).join("  "));
    for (const s of segs.slice(0, 5))
      console.log(`    (${s.x0.toFixed(0)},${s.y0.toFixed(0)}) -> (${s.x1.toFixed(0)},${s.y1.toFixed(0)}) z=${s.z ?? s.intensity ?? '?'}`);
  }
  if ((f + 1) % 500 === 0) {
    const q = (sys /** @type {any} */);
    console.log(`    frame ${f + 1}: ${total} segmentos, bus=${q.busCycle}, ` +
                `${((Date.now() - t0) / 1000).toFixed(0)}s`);
  }
}
console.log(`  ${nFrames} frames: ${total} segmentos, ${conVectores} frames con dibujo`);
console.log(`  caja de TODOS los frames: x[${caja.x0.toFixed(0)}..${caja.x1.toFixed(0)}] ` +
            `y[${caja.y0.toFixed(0)}..${caja.y1.toFixed(0)}]`);
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
