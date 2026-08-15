//! El reloj del PSG del Vectrex, en un solo sitio.
//!
//! # Por que existe este modulo
//!
//! Hasta ahora cada conversion de frecuencia a periodo llevaba su propio numero, y ese
//! numero era **1_411_200**, con este comentario al lado:
//!
//! ```text
//! // JSVecX emulator: buffer=512 samples, length<<1=1024 outer iterations,
//! //   left=2 ticks each ... 4 PSG ticks per output sample
//! //   tick_rate = 4 * 44100 = 176400 Hz
//! //   Virtual PSG clock = 16 * 88200 = 1411200 Hz
//! ```
//!
//! O sea: un "reloj virtual" deducido del TAMAÑO DEL BUFFER DE AUDIO DEL EMULADOR. Se
//! calibro contra el emulador en vez de contra el chip, y el error se propago a cinco
//! sitios (musres, sfxres x3, pitrex/assets) mas el editor de instrumentos.
//!
//! El resultado audible: **todo sonaba un 6,29 % alto, poco mas de un semitono**, en la
//! consola real y en cualquier target que no fuera ese emulador.
//!
//! # El numero bueno, y de donde sale
//!
//! **Del esquematico**: IC208 (AY-3-8912) pin 15 = CLK esta cableado a `E`, el reloj del
//! 6809. E son 1,5 MHz. No es una estimacion; es una red del netlist.
//!
//! **La formula**: `f = clk / (16 * TP)`. Confirmada leyendo el bucle de MAME
//! (`src/devices/sound/ay8910.cpp`, `sound_stream_update`): el stream corre a `clock/8`,
//! `tone->count += 1` por muestra y la salida CONMUTA al llegar a `period`, asi que un
//! ciclo completo son `2*period` muestras -> `f = (clk/8)/(2*TP) = clk/(16*TP)`.
//! Cuidado con `m_step`, que vale 2 para el AY: es del ENVOLVENTE, no del tono.
//!
//! # La comprobacion que ata todo esto
//!
//! La BIOS del Vectrex trae su propia tabla de notas (`Freq_Table`, $FD.., 63 semitonos).
//! Con 1,5 MHz y /16, su entrada 26 ($00D5 = 213) da **440,14 Hz**: un A440. Y la entrada
//! 0 ($03BD = 957) da 97,96 Hz, un G2. La tabla entera cuadra como escala cromatica.
//!
//! Eso esta puesto como test aqui abajo: si alguien vuelve a mover la constante, el test
//! rompe y dice por que. Ver el modulo `logic-board` del proyecto Vectrex para el
//! esquematico, y la nota "no magic numbers".

/// Reloj del AY-3-8912 del Vectrex: IC208 pin 15 (CLK) <- `E`, el reloj del 6809.
pub const PSG_CLOCK_HZ: f64 = 1_500_000.0;

/// Divisor interno del generador de tono del AY-3-8910/8912.
pub const PSG_TONE_DIV: f64 = 16.0;

/// El periodo de 12 bits que admite el registro (0 se comporta como 1).
pub const PSG_PERIOD_MIN: u16 = 1;
pub const PSG_PERIOD_MAX: u16 = 4095;

/// Hz -> periodo de tono del PSG. `f = clk / (16 * TP)`  =>  `TP = clk / (16 * f)`.
pub fn hz_to_period(hz: f64) -> u16 {
    if !(hz > 0.0) {
        return PSG_PERIOD_MAX;
    }
    let tp = (PSG_CLOCK_HZ / (PSG_TONE_DIV * hz)).round();
    (tp as i64).clamp(PSG_PERIOD_MIN as i64, PSG_PERIOD_MAX as i64) as u16
}

/// Periodo -> Hz, para mostrarlo en interfaces. Inversa exacta de `hz_to_period`.
pub fn period_to_hz(period: u16) -> f64 {
    let p = period.max(PSG_PERIOD_MIN) as f64;
    PSG_CLOCK_HZ / (PSG_TONE_DIV * p)
}

/// Nota MIDI -> Hz, afinacion estandar (A4 = nota 69 = 440 Hz).
pub fn midi_to_hz(midi: f64) -> f64 {
    440.0 * 2.0_f64.powf((midi - 69.0) / 12.0)
}

/// Nota MIDI -> periodo de tono del PSG.
pub fn midi_to_period(midi: f64) -> u16 {
    hz_to_period(midi_to_hz(midi))
}

#[cfg(test)]
mod tests {
    use super::*;

    /// La tabla de notas de la BIOS original (`Freq_Table`), transcrita de
    /// `docs/vec_prog_docs/DIS/TOMLIN/NEW/BIOS.ASM:3185`. 63 semitonos + terminador.
    const BIOS_FREQ_TABLE: [u16; 63] = [
        0x03BD, 0x0387, 0x0354, 0x0324, 0x02F7, 0x02CD, 0x02A4, 0x027E,
        0x025B, 0x0239, 0x0219, 0x01FB, 0x01DE, 0x01C3, 0x01AA, 0x0192,
        0x017C, 0x0166, 0x0152, 0x013F, 0x012D, 0x011C, 0x010C, 0x00FD,
        0x00EF, 0x00E2, 0x00D5, 0x00C9, 0x00BE, 0x00B3, 0x00A9, 0x00A0,
        0x0097, 0x008E, 0x0086, 0x007F, 0x0078, 0x0071, 0x006B, 0x0065,
        0x005F, 0x005A, 0x0055, 0x0050, 0x004B, 0x0047, 0x0043, 0x003F,
        0x003C, 0x0038, 0x0035, 0x0032, 0x002F, 0x002D, 0x002A, 0x0028,
        0x0026, 0x0024, 0x0022, 0x0020, 0x001E, 0x001C, 0x001B,
    ];

    /// La entrada 26 de la tabla de la BIOS es un A440. Si esto falla, la constante de
    /// reloj o el divisor estan mal — no el test.
    #[test]
    fn la_bios_afina_a_440() {
        let hz = period_to_hz(BIOS_FREQ_TABLE[26]);
        assert!(
            (hz - 440.0).abs() < 1.0,
            "la entrada 26 de Freq_Table deberia ser A440 y sale {hz:.2} Hz \
             (reloj {PSG_CLOCK_HZ}, divisor {PSG_TONE_DIV})"
        );
    }

    /// Y la tabla ENTERA, entrada por entrada, con igualdad EXACTA.
    ///
    /// Nuestra conversion reproduce los 63 periodos de la BIOS sin una sola unidad de
    /// diferencia. No es "parecido": es el mismo numero. Los autores de la BIOS usaron
    /// exactamente 1,5 MHz, divisor 16 y A440, y esta funcion los recupera.
    ///
    /// Comparar contra los periodos y no contra los Hz es deliberado: a periodo 56 un
    /// solo LSB ya son 31 centesimas, asi que una tolerancia en centesimas o es
    /// inutilmente laxa abajo o falsamente estricta arriba.
    #[test]
    fn reproducimos_exactamente_la_tabla_de_la_bios() {
        for (i, &periodo) in BIOS_FREQ_TABLE.iter().enumerate() {
            // entrada 0 = G2 = nota MIDI 43 (26 semitonos por debajo de A4)
            let nuestro = midi_to_period(43.0 + i as f64);
            assert_eq!(
                nuestro, periodo,
                "entrada {i}: la BIOS pone ${periodo:04X} y nosotros ${nuestro:04X}"
            );
        }
    }

    /// El fallo concreto que motivo este modulo: el reloj virtual del emulador dejaba
    /// todo 1,06 semitonos alto. Se deja escrito para que el sintoma sea reconocible.
    #[test]
    fn el_reloj_virtual_del_emulador_subia_un_semitono() {
        const RELOJ_VIRTUAL_JSVECX: f64 = 1_411_200.0;
        let periodo_malo = (RELOJ_VIRTUAL_JSVECX / (PSG_TONE_DIV * 440.0)).round() as u16;
        let sonaba = period_to_hz(periodo_malo);
        let centesimas = 1200.0 * (sonaba / 440.0).log2();
        assert!(
            centesimas > 90.0 && centesimas < 120.0,
            "el error historico deberia rondar el semitono y sale {centesimas:.1} centesimas"
        );
    }
}
