// El reloj del PSG del Vectrex — el mismo numero que usa el generador de codigo.
//
// Gemelo TypeScript de `buildtools/vpy_codegen/src/psg.rs`. Alli esta la derivacion
// completa y los tests contra la tabla de notas de la BIOS; aqui va el resumen:
//
//   - IC208 (AY-3-8912) pin 15 = CLK esta cableado a `E` en el esquematico. E = 1,5 MHz.
//   - El generador de tono divide por 16:  f = clk / (16 * TP).
//   - Comprobado: con estos dos numeros reproducimos los 63 periodos de `Freq_Table`
//     de la BIOS original EXACTOS, sin una unidad de diferencia.
//
// Lo que habia antes en este fichero (repetido a mano en cuatro sitios) era 88200, o
// sea un reloj de 1.411.200 Hz deducido del tamaño del buffer de audio del emulador
// JSVecX. Con el, todo lo que salia al hardware sonaba un 6,29 % alto — poco mas de un
// semitono. La previsualizacion del editor no lo notaba porque toca el oscilador de
// WebAudio a los Hz verdaderos; el error solo aparecia al convertir a periodo.
//
// SI CAMBIAS ESTO, cambia tambien psg.rs: son el mismo chip.

export const PSG_CLOCK_HZ = 1_500_000;
export const PSG_TONE_DIV = 16;

/** clk / 16 — la constante que aparece dividida por los Hz. Antes valia 88200. */
export const PSG_PERIOD_NUMERATOR = PSG_CLOCK_HZ / PSG_TONE_DIV; // 93750

export const PSG_PERIOD_MIN = 1;
export const PSG_PERIOD_MAX = 4095;

/** Hz -> periodo de tono del PSG (12 bits). */
export function hzToPeriod(hz: number): number {
  if (!(hz > 0)) return PSG_PERIOD_MAX;
  const tp = Math.round(PSG_PERIOD_NUMERATOR / hz);
  return Math.min(PSG_PERIOD_MAX, Math.max(PSG_PERIOD_MIN, tp));
}

/** Periodo -> Hz. Inversa de `hzToPeriod`. */
export function periodToHz(period: number): number {
  return PSG_PERIOD_NUMERATOR / Math.max(PSG_PERIOD_MIN, period);
}
