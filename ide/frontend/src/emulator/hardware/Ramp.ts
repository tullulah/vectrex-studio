/* Ramp.ts — la aritmetica del haz, EN EL EMULADOR.
 *
 * POR QUE EXISTE. El emulador dibujaba sumando el delta PEDIDO:
 *
 *     case 3: // OP_DRAW
 *       const nx = this.armBeamX + a * ARM_ALG_SCALE;
 *
 * O sea que pintaba lo que el juego QUISO decir, no lo que el cartucho DIJO. El hardware no
 * mueve el haz un delta: programa una velocidad y un tiempo, los dos ENTEROS, y recorre
 * vx * t1 / DRAW_SCALE — que casi nunca es el delta. Ese resto tiene signo constante y se
 * acumula: el 2026-08-24 valia +6,30 unidades en una cadena de 84 trazos, un 2,5% de
 * pantalla, y costo una tarde de knobs en la consola porque AQUI no se veia.
 *
 * Daniel: "lo que me choca es no haberlo reproducido en el emulador. si hay una deriva
 * acumulada no deberia pasar tambien alli? es mas, es lo deseable". Exacto: un emulador que
 * solo reproduce nuestras intenciones no puede enseñar un fallo de nuestra ejecucion.
 *
 * ESTO ES UNA SEGUNDA IMPLEMENTACION del modelo que vive en vectrex-draw/src/ramp.rs, y una
 * segunda implementacion diverge sola. tools/comparar_rampa.mjs las compara sobre los
 * 65.024 deltas posibles y falla si discrepan en uno.
 */

export const DRAW_SCALE = 160;

/** Los mismos knobs que el cartucho, con sus valores de fabrica. */
export const knobs = { MIN_T1: 31, VCAP: 127, T1_TRANSPORT: 160, T1_LAG: 0 };

function redondea(num: number, den: number): number {
  return num >= 0 ? Math.floor((num + den / 2) / den) : Math.ceil((num - den / 2) / den);
}

/** Devuelve [vx, vy, t1] igual que `ramp_params`. Ver ramp.rs para el porque de cada paso. */
export function rampParams(dx: number, dy: number): [number, number, number] {
  const s = DRAW_SCALE;
  const m = Math.max(Math.abs(dx), Math.abs(dy));
  const minT1 = knobs.MIN_T1;
  if (m === 0) return [0, 0, minT1];

  const piso = Math.min(Math.max(Math.floor((s * m) / 127), minT1), s);
  const vc = Math.max(knobs.VCAP, 1);
  const porVcap = Math.max(Math.ceil((m * s) / vc), 1);        // HACIA ARRIBA: es un suelo

  const menor = dx === 0 ? Math.abs(dy) : dy === 0 ? Math.abs(dx)
                                                   : Math.min(Math.abs(dx), Math.abs(dy));
  const techo = Math.max(Math.min(menor * s, knobs.T1_TRANSPORT), minT1);

  let t1 = Math.min(Math.max(piso, porVcap), techo) + knobs.T1_LAG;

  // el t1 que menos se desvia, entre el calculado y el siguiente
  const errorDe = (t: number) => {
    if (t <= 0) return Infinity;
    const v = Math.max(-128, Math.min(127, redondea(m * s, t)));
    return Math.abs(v * t - m * s);
  };
  if (t1 < techo && errorDe(t1 + 1) < errorDe(t1)) t1 += 1;

  const vx = Math.max(-128, Math.min(127, redondea(dx * s, t1)));
  const vy = Math.max(-128, Math.min(127, redondea(dy * s, t1)));
  return [vx, vy, t1];
}

/** Lo que la rampa recorre DE VERDAD, en unidades del haz (con su fraccion). */
export function recorrido(v: number, t1: number): number {
  return (v * t1) / DRAW_SCALE;
}
