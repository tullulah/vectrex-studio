/* LOS CONTADORES DEL PROPIO JUEGO, LEIDOS DEL EMULADOR.
 *
 *   node tools/contadores.mjs <imagen.um2> <frames> <elf>
 *
 * Lee `uvm2_stats` en la memoria del emulador, por su direccion del ELF, y saca los MISMOS
 * cuatro numeros que dkong dibuja en su HUD con DK_FPSHUD. Sirve para una cosa concreta:
 * comparar emulador contra consola con el MISMO codigo y el MISMO contador, en vez de
 * discutir si el emulador va lento "en general".
 */
import { readFileSync, readdirSync, statSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { execFileSync } from "node:child_process";
import { Uvm2System } from "./.uvm2emu-built.mjs";

const [img, nFrames = "300", elf] = process.argv.slice(2);
if (!img || !elf) { console.error("uso: contadores.mjs <img.um2> <frames> <elf>"); process.exit(2); }

const NM = "/Applications/ArmGNUToolchain/15.2.rel1/arm-none-eabi/bin/arm-none-eabi-nm";
const linea = execFileSync(NM, ["-S", elf], { encoding: "utf8" })
  .split("\n").find(l => / \w uvm2_stats$/.test(l) || l.endsWith(" uvm2_stats"));
if (!linea) { console.error("el ELF no trae uvm2_stats"); process.exit(1); }
const base = parseInt(linea.split(/\s+/)[0], 16);

/* Los desplazamientos salen de compilar la MISMA cabecera en el host (todo son uint32_t,
 * asi que la disposicion no cambia entre ARM y x86). Se rehacen con:
 *     cc -I<sdk> -o off off.c   con offsetof sobre uvm2_stats_t                    */
const OFF = { commands: 0, bus_cycles: 4, vectors: 8, dropped: 24, exec_cycles: 32,
              wait_spins: 48, us_exec: 52, us_input: 56, us_rest: 60, us_wait: 64,
              us_frame_last: 68, us_frame_min: 72, us_frame_max: 76,
              frames_lentos: 84, frames_medidos: 88,
              us_emul_acum: 344, us_emul_n: 348, us_lista_acum: 352, us_lista_n: 356 };

const sys = new Uvm2System();
sys.setElf(new Uint8Array(readFileSync(elf)));
{
  const raiz = join(homedir(), "VectrexStudio", "sd"); const files = {};
  const anda = (dir, rel) => {
    let ent = []; try { ent = readdirSync(dir, { withFileTypes: true }); } catch { return; }
    for (const e of ent) {
      if (e.name.startsWith(".")) continue;
      const p = join(dir, e.name), r = rel ? `${rel}/${e.name}` : e.name;
      if (e.isDirectory()) anda(p, r);
      else try { if (statSync(p).size <= 2 << 20) files[r.toLowerCase()] = new Uint8Array(readFileSync(p)); } catch {}
    }
  };
  anda(raiz, ""); sys.setSdFiles(files);
}
sys.init(new Uint8Array(readFileSync(img)));

/* Las pulsaciones, con el MISMO mecanismo que correr_uvm2.mjs: una mascara activa-baja
 * sobre setJoyButtons. Con `sys.setButton` —que no existe— el juego se queda en el menu y
 * los contadores del bucle de partida salen a CERO, que se lee igual que "roto". */
const guion = (process.env.PULSA || "").split(",").filter(Boolean)
  .map(x => ({ f: Number(x.split(":")[0]),
               bs: (x.split(":")[1] || "1").split("").map(Number) }));
const N = +nFrames;
for (let f = 0; f < N; f++) {
  const pulsa = guion.find(g => f >= g.f && f < g.f + 6);
  if (guion.length) {
    let m = 0xF0;
    if (pulsa) for (const b of pulsa.bs) m &= ~(1 << (3 + b));
    sys.setJoyButtons(m);
  }
  sys.runFrame();
}

const u32 = a => (sys.read8(a) | (sys.read8(a+1)<<8) | (sys.read8(a+2)<<16) | (sys.read8(a+3)<<24)) >>> 0;
const v = {}; for (const k in OFF) v[k] = u32(base + OFF[k]);

const e = v.us_emul_n  ? Math.floor(Math.floor(v.us_emul_acum  / v.us_emul_n)  / 100) : 0;
const l = v.us_lista_n ? Math.floor(Math.floor(v.us_lista_acum / v.us_lista_n) / 100) : 0;
console.log(`uvm2_stats en 0x${base.toString(16)}, tras ${N} frames`);
console.log(`  HUD (fps r e l):   r=${v.bus_cycles >> 9}  e=${e}  l=${l}`);
console.log(`  us_emul  medio: ${v.us_emul_n  ? (v.us_emul_acum  / v.us_emul_n  / 1000).toFixed(2) : "-"} ms  (n=${v.us_emul_n})`);
console.log(`  us_lista medio: ${v.us_lista_n ? (v.us_lista_acum / v.us_lista_n / 1000).toFixed(2) : "-"} ms  (n=${v.us_lista_n})`);
console.log(`  core 1:  us_exec=${v.us_exec}  us_input=${v.us_input}  us_rest=${v.us_rest}  us_wait=${v.us_wait}`);
console.log(`  frame del JUEGO: ult=${(v.us_frame_last/1000).toFixed(2)} ms  min=${(v.us_frame_min/1000).toFixed(2)}  max=${(v.us_frame_max/1000).toFixed(2)}  ->  ${v.us_frame_last?(1e6/v.us_frame_last).toFixed(1):"-"} fps`);
/* LA RELACION QUE TIENE QUE SALIR 1,5. El bus va a 1,5 MHz y el TIMER del juego cuenta
 * microsegundos, asi que por cada microsegundo de juego tienen que pasar 1,5 ciclos de bus.
 * Si sale otra cosa, hay ciclos de bus que se regalan sin cobrar tiempo de CPU. */
console.log(`  bus/us:  ${(sys.busCycle / (sys.cpuCiclos/150)).toFixed(3)}  (tiene que ser 1.500)   busCycle=${sys.busCycle} us=${Math.round(sys.cpuCiclos/150)}`);
console.log(`  lista:   commands=${v.commands}  bus_cycles=${v.bus_cycles}  vectors=${v.vectors}  dropped=${v.dropped}  wait_spins=${v.wait_spins}`);
