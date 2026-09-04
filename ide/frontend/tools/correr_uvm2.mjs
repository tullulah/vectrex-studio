/* Correr una imagen .um2 en Uvm2System SIN NAVEGADOR, para poder iterar sin pedirle a
 * nadie que pulse Shift+F5 y me pegue la consola.
 *
 *   node tools/correr_uvm2.mjs <imagen.um2> [frames] [elf]
 *
 * Imprime lo mismo que el informe del panel —vectores por frame, escrituras a la VIA, y
 * donde gira si no dibuja— y ademas resuelve el PC contra el ELF si se le pasa. Todo el
 * ciclo de hoy (cambiar el emulador, probar, leer el PC, repetir) cabe aqui en segundos.
 */
if (process.env.VIADUMP) globalThis.__VIADUMP = 1;
import { readFileSync, readdirSync, statSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { execFileSync } from "node:child_process";
/* DEL BUNDLE, no del .ts: node --experimental-strip-types no reescribe los imports
 * "./x.js" que usa el fuente y falla con ERR_MODULE_NOT_FOUND. Rehacerlo cuando se
 * toque el emulador:
 *   ./node_modules/.bin/esbuild src/emulator/systems/Uvm2System.ts \
 *       --bundle --format=esm --platform=node --outfile=tools/.uvm2emu-built.mjs */
import { Uvm2System } from "./.uvm2emu-built.mjs";

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
/* PULSACIONES SIN MANOS. PULSA="40:1,120:2" = en el frame 40 el boton 1, en el 120 el 2;
 * cada una dura seis frames, que es mas que el antirrebote de cualquier menu. Sin esto el
 * emulador se queda en la pantalla de titulo y no se prueba NADA del juego. */
/* VARIOS BOTONES A LA VEZ: "100:12" = en el frame 100, los botones 1 Y 2 juntos. Hacia
 * falta porque las combinaciones son acciones de verdad — en asterock la MONEDA es 1+2 y
 * START es 3+4 — y con un solo boton no se llega al juego. */
const guion = (process.env.PULSA || "").split(",").filter(Boolean)
  .map(x => ({ f: Number(x.split(":")[0]),
               bs: (x.split(":")[1] || "1").split("").map(Number) }));
for (let f = 0; f < Number(nFrames); f++) {
  const pulsa = guion.find(g => f >= g.f && f < g.f + 6);
  if (guion.length) {
    let m = 0xF0;
    if (pulsa) for (const b of pulsa.bs) m &= ~(1 << (3 + b));
    sys.setJoyButtons(m);
  }
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
    const ah = [...(sys /** @type {any} */).oraHist].map((n, v) => [v, n]).filter(x => x[1])
                 .sort((a, b) => b[1] - a[1]);
    console.log("  ORA, todos los valores: " + ah.map(([v, n]) => `0x${v.toString(16)}=${n}`).join(" "));
    console.log(`  ORA: ${ah.length} valores distintos, ` +
                `cambios del S&H de Y: ${(sys /** @type {any} */).cambiosYsh}`);
    console.log("  escrituras por registro: " +
      [...h].map((n, i) => n ? `${nom[i]}=${n}` : "").filter(Boolean).join("  "));
    for (const s of segs.slice(0, 5))
      console.log(`    (${s.x0.toFixed(0)},${s.y0.toFixed(0)}) -> (${s.x1.toFixed(0)},${s.y1.toFixed(0)}) z=${s.z ?? s.intensity ?? '?'}`);
    /* Y EL DIBUJO, A UN SVG. Contar segmentos y mirar la caja no distingue una rejilla de
     * un garabato con la misma extension; esto se abre y se ve. */
    /* Y LOS SEGMENTOS EN CRUDO. Para medir la deriva hace falta el numero, no la imagen:
     * una rejilla torcida y una bien dibujada se distinguen a ojo solo cuando ya es tarde. */
    if (process.env.SEGS) writeFileSync(process.env.SEGS, JSON.stringify(segs));
    if (process.env.SVG) {
      const e = 800 / Math.max(caja.x1 - caja.x0, caja.y1 - caja.y0, 1);
      /* SIN GIRAR NINGUN EJE. Se comprobo rindiendo las cuatro orientaciones de la
       * pantalla de titulo de dkong y leyendo cual dice "DONKEY KONG": esta. */
      const px = (v, o) => ((v - o) * e).toFixed(1);
      /* EL BRILLO ES Z, Y PUNTO. Aqui hubo un modelo de "fosforo = intensidad x tiempo"
       * que atenuaba cada trazo por su velocidad (z * 130 / (long/ticks) / 4): TRES
       * numeros que no salen de ninguna medida, y el efecto era que los trazos rapidos
       * —los nuestros, que van a tasas altas— desaparecian mientras los puntos se
       * pintaban a brillo pleno. Me hizo leer "letras a puntos" en un dibujo cuyos
       * trazos estaban ahi. El frame de la CAPTURA del VecFever pintado con esa misma
       * regla sale igual de punteado (56% de sus segmentos son de longitud cero contra
       * nuestro 60%), asi que el punto por vertice es del idioma, no del puerto.
       *
       * Lo que el dwell SI dice, y es lo unico que se usa: si un segmento de longitud
       * cero estuvo iluminado (ticks>0) es un PUNTO de verdad y hay que pintarlo; si no,
       * no existe. */
      const luz = (s) => Math.max(0.15, (s.intensity ?? 127) / 127);
      writeFileSync(process.env.SVG,
        `<svg xmlns="http://www.w3.org/2000/svg" width="820" height="820" style="background:#000">` +
        segs.map(s => {
          const dot = Math.abs(s.x1 - s.x0) < 1 && Math.abs(s.y1 - s.y0) < 1;
          if (dot && s.ticks) {
            /* Radio FIJO: el punto es un punto. Escalarlo con el dwell era la otra
             * mitad de la invencion — hacia gordos justo los vertices y tapaba el trazo. */
            return `<circle cx="${px(s.x0, caja.x0)}" cy="${px(s.y0, caja.y0)}" ` +
                   `r="1.5" fill="#0f0" fill-opacity="${luz(s).toFixed(2)}"/>`;
          }
          if (dot) return "";
          return `<line x1="${px(s.x0, caja.x0)}" y1="${px(s.y0, caja.y0)}" ` +
                 `x2="${px(s.x1, caja.x0)}" y2="${px(s.y1, caja.y0)}" ` +
                 `stroke="#0f0" stroke-opacity="${luz(s).toFixed(2)}" stroke-width="1.5"/>`;
        }).join("") + `</svg>`);
      console.log(`  dibujo escrito en ${process.env.SVG}`);
    }
  }
  if ((f + 1) % 500 === 0) {
    const q = (sys /** @type {any} */);
    console.log(`    frame ${f + 1}: ${total} segmentos, bus=${q.busCycle}, ` +
                `${((Date.now() - t0) / 1000).toFixed(0)}s`);
  }
}
console.log(`  ${nFrames} frames: ${total} segmentos, ${conVectores} frames con dibujo`);
{
  const yh = [...(sys /** @type {any} */).yshHist].map((n, v) => [v, n]).filter(x => x[1])
               .sort((a, b) => b[1] - a[1]).slice(0, 8);
  console.log("  ORA en cada enganche de Y: " + yh.map(([v, n]) => `0x${v.toString(16)}=${n}`).join("  "));
}
console.log("  palabras del PIO:\n    " + (sys /** @type {any} */).trazaPio.join("\n    "));
console.log("  secuencia a la VIA: " + (sys /** @type {any} */).traza.join(" "));
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
      for (const sim of ["dk_rom_error", "uvm2_romzip_error", "uvm2_romzip_bytes", "mh_env_x0", "mh_env_x1", "mh_env_y0", "mh_env_y1", "figura", "densidad", "T1_EXTRA_Q8", "T1_LAG_ARRANQUE", "MIN_T1_ARRANQUE", "VCAP_SALTO", "RAMPA_FIJA", "VCAP_SLOW", "VCAP_DV", "T1_SALTO", "MIN_T1", "VCAP", "T1_TRANSPORT", "DRAW_SCALE", "T1_LAG",
                         /* La ENTRADA tal como la ve el juego. Sin esto, "el emulador no
                          * reacciona a los botones" no distingue "no llegan" de "llegan y
                          * el juego no los usa", que se arreglan en sitios opuestos. */
                         "currentButtonState", "currentJoy1X", "currentJoy1Y", "vfcap_frames", "vfcap_saltados", "vfcap_error", "vfcap_bytes", "vfcap_psram_ok", "vfcap_copiado", "vfcap_nframes", "dbg_mt", "DBG_MT_X", "DBG_H_X", "DEUDA_X", "DEUDA_Y", "vpy_red_n", "vpy_red_err_c", "vpy_red_subunidad", "vpy_red_cero", "sonda_lista", "sonda_a", "sonda_b", "sonda_c", "sonda_d", "sonda_e", "sonda_f", "uvm2_pacer_cycles", "uvm2_cero_cada"]) {
        const ln = nm.split("\n").find(x => x.endsWith(" " + sim));
        if (!ln) continue;
        const v = q.read32(parseInt(ln.split(" ")[0], 16));
        /* Las sondas llevan valores CON SIGNO. Imprimirlas sin signo daba 4294967063 por
         * -233, que se lee como basura y manda a buscar un fallo que no existe. */
        console.log(`    ${sim} = ${sim.startsWith("sonda_") && sim !== "sonda_lista" ? (v | 0) : (v >>> 0)}`);
      }
    }
  } catch (e) { console.log("  (sin contadores:", String(e).slice(0, 60), ")"); }
}

/* EL LISTADO DE COMANDOS TAL CUAL LO DEJO EL JUEGO. Es la fuente de todo lo demas: si un
 * vector no esta aqui, no puede llegar al PIO ni a la VIA. Tres bytes por comando:
 * retardo 12, registro 4, dato 8. */
if (elf) {
  try {
    const nm2 = execFileSync("arm-none-eabi-nm", [elf]).toString();
    const lc = nm2.split("\n").find(x => x.endsWith(" s_cmds"));
    if (lc) {
      const base = parseInt(lc.split(" ")[0], 16);
      const q2 = (sys /** @type {any} */);
      const nom = ["ORB","ORA","DDRB","DDRA","T1CL","T1CH","T1LL","T1LH","T2CL","T2CH","SR","ACR","PCR","IFR","IER","ORAnh"];
      const sim = (n) => { const l = nm2.split("\n").find(x => x.endsWith(" " + n)); return l ? parseInt(l.split(" ")[0], 16) : 0; };
      const pbuf = sim("s_buf"), pcnt = sim("s_count");
      const buf = pbuf ? q2.read32(pbuf) : 0, cnt = pcnt ? q2.read32(pcnt) : 0;
      /* LA CAPACIDAD SE LEE DEL ELF, no se supone: cada juego compila la suya y un buffer
       * de mas apunta a bss vacia, que se lee como una lista de ceros perfectamente creible. */
      const tam = execFileSync("arm-none-eabi-nm", ["-S", elf]).toString()
        .split("\n").find(x => x.endsWith(" s_cmds"));
      const CAP = parseInt(tam.split(/\s+/)[1], 16) / 2;
      const b0 = base + (buf & 1) * CAP;
      const cmd = (i) => { const a = b0 + i*3; const v = q2.read8(a) | (q2.read8(a+1) << 8) | (q2.read8(a+2) << 16);
                           return { reg: (v >> 8) & 0xF, dato: v & 0xFF, ret: v >>> 12 }; };
      console.log(`  lista: s_buf=${buf} s_count=${cnt}`);
      const fuera = [];
      for (let i = 0; i < Math.min(90, cnt); i++) { const c = cmd(i);
        fuera.push(`${i}:${nom[c.reg]}=0x${c.dato.toString(16)}${c.ret ? "+" + c.ret : ""}`); }
      console.log("  listado del juego: " + fuera.join(" "));
      /* LOS VECTORES, RECONSTRUIDOS DE LA LISTA. La fase la marca ORB: con los bits 0-2 a
       * cero el DAC entra en la Y, con el bit 0 puesto entra en la X. */
      /* LA Y ES EL ORA QUE VA ANTES DE ABRIR EL MUX, no el de despues: el valor tiene que
       * estar puesto en el DAC cuando el sample-and-hold lo muestrea. Leerlo al reves da
       * "vy=0 siempre", que es un sintoma perfectamente creible de un eje muerto. */
      let ultOra = 0, vy = 0, vx = 0, t1lo = 0, t1hi = 0;
      const trip = new Map();
      for (let i = 0; i < cnt; i++) { const c = cmd(i);
        if (c.reg === 0) { if ((c.dato & 0x07) === 0x00) vy = ultOra; }
        else if (c.reg === 1) { vx = c.dato; ultOra = c.dato; }
        else if (c.reg === 4) t1lo = c.dato;
        else if (c.reg === 5) { t1hi = c.dato;
          const sg = (v) => v > 127 ? v - 256 : v;
          const k = `vx=${sg(vx)} vy=${sg(vy)} t1=${t1lo | (t1hi << 8)}`;
          trip.set(k, (trip.get(k) || 0) + 1); } }
      const orden = [...trip.entries()].sort((a, b) => b[1] - a[1]);
      console.log(`  vectores distintos en la lista: ${orden.length}`);
      for (const [k, n] of orden.slice(0, 12)) console.log(`    ${k}  x${n}`);
    }
  } catch (e) { console.log("  (sin listado)", String(e).slice(0, 50)); }
}

/* DONDE ESTAN LOS DOS NUCLEOS. Esto imprimia SOLO el nucleo 1 — y su propio comentario
 * decia que lo que hace falta es donde se quedo el 0. Con mhavoc colgado en el primer
 * frame (recals=1 tras 1200 frames) la unica pregunta era esa, y no habia forma de
 * responderla sin parchear la herramienta. */
{
  const c0 = (sys /** @type {any} */).cpu;
  if (c0) {
    const pc0 = c0.getReg(15) >>> 0;
    let quien = "";
    if (elf) { try {
      quien = execFileSync("arm-none-eabi-addr2line", ["-f", "-e", elf, "0x" + pc0.toString(16)])
                .toString().trim().split("\n").join("  ");
    } catch {} }
    console.log(`  nucleo 0 en 0x${pc0.toString(16)}  ${quien}`);
  }
}
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

/* LA ARITMETICA, EJECUTADA POR LA CPU EMULADA.
 *
 * El listado de comandos sale con `t1 = DRAW_SCALE` y `vx = dx`: el modelo FIJO, que en el
 * codigo no existe. O el juego no llama a la rampa, o la rampa devuelve otra cosa AQUI. Se
 * corta por lo sano llamandola a mano en la CPU emulada con casos cuyo resultado se sabe
 * del host, y comparando. Si difieren, el fallo es de la CPU, no del dibujo.
 */
if (elf) {
  try {
    const q3 = /** @type {any} */ (sys);
    const nm3 = execFileSync("arm-none-eabi-nm", [elf]).toString().split("\n");
    const dir = (n) => { const l = nm3.find(x => x.endsWith(" " + n)); return l ? parseInt(l.split(" ")[0], 16) : 0; };
    const fn = dir("vx_ramp_params");
    const cpu = q3.cpu;
    const w32 = (a, v) => { for (let i = 0; i < 4; i++) q3.write8((a + i) >>> 0, (v >>> (i * 8)) & 0xFF); };
    const SCR = 0x20060000, PILA = 0x20061000;
    const salida = [];
    /* (0,50) VA PRIMERO Y ES EL QUE MAS DICE: un vector VERTICAL no puede mover la X, y
     * la CPU emulada devolvia vx=1 donde el host devuelve 0 (test `un_vertical_no_mueve_
     * la_x` en vectrex-draw). Son 0,39 unidades de desplazamiento por trazo SIEMPRE AL
     * MISMO LADO, y en la lista de asterock salian 351 trazos con `vx=1 vy=24`: es una
     * deriva horizontal entera fabricada por el emulador. */
    const casos = [[0, 50], [50, 0], [68, 0], [-46, 0], [6, 0]];
    console.log("  vx_ramp_params EN LA CPU EMULADA (host: 50->vx=125 t1=64, 68->vx=125 t1=87, -46->vx=-127 t1=58):");
    for (const [dx, dy] of casos) {
      cpu.setReg(0, dx >>> 0); cpu.setReg(1, dy >>> 0);
      cpu.setReg(2, SCR); cpu.setReg(3, SCR + 4);
      cpu.setReg(13, PILA);
      w32(PILA, SCR + 8);            // 5o argumento: *t1, por pila (AAPCS)
      w32(SCR, 0); w32(SCR + 4, 0); w32(SCR + 8, 0);
      cpu.setReg(14, 0xFFFFFFFE);
      cpu.setReg(15, fn & ~1);
      let n = 0;
      while ((cpu.getReg(15) >>> 0) !== 0xFFFFFFFE && n < 200000) { cpu.step(q3); n++; }
      const sg = (v) => (v | 0);
      const r = { dx, dy, vx: sg(q3.read32(SCR)), vy: sg(q3.read32(SCR + 4)), t1: q3.read32(SCR + 8) >>> 0 };
      salida.push(r);
      console.log(`    (${dx},${dy}) -> vx=${r.vx} vy=${r.vy} t1=${r.t1}   [${n} instrucciones]`);
    }
    /* VEREDICTO, no listado. Los dos sintomas de que la CPU se come una instruccion de la
     * rampa, escritos como invariantes y no como numeros esperados:
     *   - un t1 igual para TODA entrada es el modelo fijo, que en el codigo no existe;
     *   - un vector vertical tiene que mover la Y mas que la X.
     * Asi fallo `ssat`: sin implementar se saltaba en silencio y el dibujo seguia siendo
     * creible, solo que plano. */
    const t1s = new Set(salida.map(r => r.t1));
    const vert = salida.find(r => r.dx === 0 && r.dy !== 0);
    const malo = [];
    if (t1s.size === 1) malo.push(`t1 vale ${[...t1s][0]} para todas las entradas`);
    if (vert && Math.abs(vert.vy) <= Math.abs(vert.vx)) malo.push(`(0,${vert.dy}) no mueve la Y`);
    /* EL EJE QUE NO SE PIDE TIENE QUE QUEDARSE QUIETO. Este invariante faltaba y por eso
     * la sonda decia "la rampa: la CPU emulada la calcula bien" mientras devolvia vx=1
     * para dx=0 — un sesgo que falsea CUALQUIER medida de geometria hecha en el emulador. */
    if (vert && vert.vx !== 0) malo.push(`(0,${vert.dy}) mueve la X: vx=${vert.vx} (el host da 0)`);
    if (salida.every(r => r.vx === 0 && r.vy === 0)) malo.push("devuelve 0,0 para TODO: la sonda no esta ejecutando la funcion");
    console.log(malo.length ? "  RAMPA MAL EN LA CPU EMULADA: " + malo.join("; ")
                            : "  rampa: la CPU emulada la calcula bien");
  } catch (e) { console.log("  (sonda de rampa fallida)", e && e.stack ? e.stack.split("\n").slice(0, 5).join("\n      ") : String(e)); }
}

if (process.env.VIADUMP) {
  const v = (sys /** @type {any} */).viaFull;
  const N=['ORB','ORA','DDRB','DDRA','T1CL','T1CH','T1LL','T1LH','T2CL','T2CH','SR','ACR','PCR','IFR','IER','ORAnh'];
  let o='cycle\treg\tname\tdata\n';
  for (let i=0;i<v.length;i+=3) o+=`${v[i]}\t${v[i+1].toString(16)}\t${N[v[i+1]]}\t${v[i+2].toString(16).padStart(2,'0')}\n`;
  writeFileSync(process.env.VIADUMP, o);
  console.log(`  VIA volcado: ${v.length/3} escrituras -> ${process.env.VIADUMP}`);
}

function capacidadCmds(nmLines, elfPath) {
  /* La capacidad se lee del ELF (nm -S), no se supone: cada juego compila la suya y un
   * desplazamiento de mas apunta a bss vacia, que se lee como una lista de ceros
   * perfectamente creible. */
  try {
    const l = execFileSync("arm-none-eabi-nm", ["-S", elfPath]).toString()
      .split("\n").find(x => x.endsWith(" s_cmds"));
    return parseInt(l.split(/\s+/)[1], 16) / 2;
  } catch { return 0; }
}

if (process.env.CMDDUMP) {
  // Lee la lista de comandos EXACTA del SDK (s_cmds) de la RAM del emulador: 3 bytes/cmd,
  // packed24 = (delay<<12)|(reg<<8)|data. Es la vara buena (ciclos de E), sin el PIO.
  const S = (sys /** @type {any} */);
  const ram = S.sram; const BASE = 0x20000000;
  const rd32 = (a) => ram[a-BASE] | (ram[a-BASE+1]<<8) | (ram[a-BASE+2]<<16) | (ram[a-BASE+3]<<24);
  // Las direcciones SE RESUELVEN DEL ELF, no se cuecen: estuvieron fijas y el primer
  // rebuild las dejo apuntando a otra cosa — s_count leyo 16,8M y el volcado era basura.
  const nmc = execFileSync("arm-none-eabi-nm", [elf]).toString().split("\n");
  const dir = (n) => { const l = nmc.find(x => x.endsWith(" " + n)); return l ? parseInt(l.split(" ")[0], 16) : 0; };
  const S_CMDS = dir("s_cmds"), S_COUNT = dir("s_count");
  if (!S_CMDS || !S_COUNT) { console.log("  CMDDUMP: sin simbolos s_cmds/s_count en el ELF"); process.exit(0); }
  /* CON DOBLE NUCLEO HAY DOS BUFFERS y `s_count` es el del que core 0 esta LLENANDO —
   * si el emulador para justo tras frame_begin, vale 0 y el volcado sale vacio (paso con
   * sdkplay). `s_len[i]` guarda la longitud del frame ya PUBLICADO de cada buffer, asi
   * que se coge el que tenga contenido. Sin esto, "0 comandos" se lee como "el juego no
   * dibuja" cuando lo que pasa es que se miro el buffer equivocado. */
  const S_LEN = dir("s_len"), S_BUF = dir("s_buf");
  let cnt = rd32(S_COUNT) >>> 0, base_off = 0;

  /* EL BUFFER PUBLICADO, NUNCA EL QUE SE ESTA LLENANDO.
   *
   * Esto usaba `s_count` salvo que valiera cero, y `s_count` es el contador VIVO: si el
   * emulador para a mitad de frame —que es lo normal— se volcaba un frame a medio
   * construir. Sintoma: el juego decia 4115 comandos y el volcado traia 2941, y con eso
   * cualquier comparacion contra la captura compara media lista contra una entera. Me
   * costo dar dos veces por buena una divergencia que era mia.
   *
   * `s_len[i]` es la longitud del frame ya PUBLICADO y `uvm2_frame_done` dice cual fue el
   * ultimo servido. Se prefiere siempre eso; `s_count` solo si no hay `s_len`. */
  if (S_LEN) {
    const l0 = rd32(S_LEN) >>> 0, l1 = rd32(S_LEN + 4) >>> 0;
    if (l0 || l1) {
      const D = dir("uvm2_frame_done");
      let usa1 = l1 >= l0;
      if (D) { const d = rd32(D) >>> 0; if (l0 && l1) usa1 = (d & 1) === 1; }
      cnt = usa1 ? l1 : l0;
      base_off = usa1 ? 1 : 0;
    }
  } else if (S_BUF) {
    base_off = rd32(S_BUF) & 1;
  }
  /* Y SE COTEJA CON EL CONTADOR DEL JUEGO. Si no cuadran, el volcado NO es el frame que
   * las estadisticas describen, y hay que decirlo en vez de dejar que se compare. */
  {
    const ST = dir("uvm2_stats");
    if (ST) {
      const dice = rd32(ST) >>> 0;                     /* commands es el primer campo */
      if (dice && cnt !== dice)
        console.log(`  CMDDUMP: OJO, el juego dice ${dice} comandos y el buffer publicado ` +
                    `tiene ${cnt}. El volcado es de OTRO frame: no lo compares con las ` +
                    `estadisticas de arriba.`);
      else if (dice)
        console.log(`  CMDDUMP: buffer publicado s_len[${base_off}]=${cnt}, cuadra con las estadisticas`);
    }
  }
  const N = ['ORB','ORA','DDRB','DDRA','T1CL','T1CH','T1LL','T1LH','T2CL','T2CH','SR','ACR','PCR','IFR','IER','ORAnh'];
  let o = 'i\treg\tname\tdata\tdelay\n';
  for (let i=0;i<cnt && i<20000;i++) {
    const CAPB = capacidadCmds(nmc, elf);
    const B = S_CMDS + base_off * CAPB;
    const b0=ram[B-BASE+i*3], b1=ram[B-BASE+i*3+1], b2=ram[B-BASE+i*3+2];
    const w=b0|(b1<<8)|(b2<<16); const data=w&0xFF, reg=(w>>8)&0xF, delay=w>>12;
    o+=`${i}\t${reg.toString(16)}\t${N[reg]}\t${data.toString(16).padStart(2,'0')}\t${delay}\n`;
  }
  writeFileSync(process.env.CMDDUMP, o);
  console.log(`  s_cmds volcado: ${cnt} comandos -> ${process.env.CMDDUMP}`);
}
