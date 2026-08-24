/* ¿Dicen lo MISMO las dos rampas? La de Rust (vectrex-draw, la que corre en los cartuchos)
 * y la de TypeScript (Ramp.ts, la que corre en el emulador), sobre los 65.024 deltas.
 *
 * Una segunda implementacion del mismo modelo diverge sola, y cuando lo hace el emulador
 * deja de servir justo para lo que se hizo: enseñar lo que la consola va a hacer. Esto lo
 * rompe en cuanto discrepan en UN delta.
 *
 *   node tools/comparar_rampa.mjs        (necesita ../../../buildtools o el .a de cabi)
 */
import { execFileSync } from "node:child_process";
import { writeFileSync, mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { rampParams, knobs } from "../src/emulator/hardware/Ramp.ts";

const CABI = process.env.CABI ??
  "/Users/daniel/projects/vectrex-pseudo-python/ide/electron/resources/vectrex-draw/cabi/target/release/libvectrex_draw_cabi.a";

/* Se saca la referencia del BINARIO DE RUST, no de una copia de su formula: comparar dos
 * traducciones mias del mismo papel no prueba nada. */
const dir = mkdtempSync(join(tmpdir(), "rampa-"));
writeFileSync(join(dir, "v.c"), `
#include <stdio.h>
#include <stdint.h>
void vx_ramp_params(int32_t,int32_t,int32_t*,int32_t*,uint32_t*);
void rust_eh_personality(void){}
int main(void){
  for (int dx=-127; dx<=127; dx++) for (int dy=-127; dy<=127; dy++){
    int32_t vx,vy; uint32_t t1; vx_ramp_params(dx,dy,&vx,&vy,&t1);
    printf("%d %d %d %d %u\\n", dx,dy,vx,vy,t1);
  }
  return 0; }
`);
execFileSync("cc", ["-O1", "-o", join(dir, "v"), join(dir, "v.c"), CABI]);
const ref = execFileSync(join(dir, "v"), { maxBuffer: 1 << 28 }).toString().trim().split("\n");

let mal = 0, primeros = [];
for (const linea of ref) {
  const [dx, dy, vx, vy, t1] = linea.split(" ").map(Number);
  const [tx, ty, tt] = rampParams(dx, dy);
  if (tx !== vx || ty !== vy || tt !== t1) {
    mal++;
    if (primeros.length < 8)
      primeros.push(`  (${dx},${dy}): rust ${vx},${vy},${t1}  ts ${tx},${ty},${tt}`);
  }
}
console.log(`  comparados ${ref.length} deltas con MIN_T1=${knobs.MIN_T1} VCAP=${knobs.VCAP}`);
if (mal) {
  console.log(`  DISCREPAN en ${mal}:\n${primeros.join("\n")}`);
  process.exit(1);
}
console.log("  las dos rampas dicen lo mismo en todos");
