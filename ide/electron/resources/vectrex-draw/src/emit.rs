//! La COSTURA entre el modelo de haz y la placa.
//!
//! PASO 3 de la unificacion. El modelo emite una secuencia de escrituras a la VIA
//! separadas por retardos; quien las lleva al hardware es cosa de cada cartucho:
//!
//! el nuestro escribe el bus ya (por SIO o por el stream de PIO) y la imagen del
//! multicart de Ralf las apila en su lista de comandos, que un ejecutor reproduce
//! despues.
//!
//! ── Y LOS DOS SON LA MISMA COSA, que es mas de lo que yo creia ───────────────
//!
//! Llegue a hablar de "su lista" como si fuera una forma ajena a la que adaptarse. No lo
//! es: NOSOTROS HACEMOS LO MISMO. El camino de PIO tambien es una lista de comandos
//! —`ring_push` -> `BATCH_BUF[2][64]` -> DMA -> PIO— y el remate esta en `stream_park`:
//! con `USE_PARK_REPEAT` emite UNA palabra con un contador de repeticiones en vez de n
//! palabras. Eso es literalmente `(comando, retardo)`, la misma representacion que la
//! otra placa. Cambia la codificacion y quien reproduce (PIO+DMA contra un bucle de CPU
//! sincronizado a E), no la idea.
//!
//! Importa para el diseño y no solo para la prosa: la costura no impone una forma nueva
//! a nadie, NOMBRA la que ya tenian las dos. Y `e6809_raw` lo demuestra sin querer — ya
//! se bifurcaba entre `stream_park` y la espera en CPU, asi que `CartSink::emit` hereda
//! el comportamiento correcto en los dos caminos sin tocar una linea. Que encajara sin
//! esfuerzo era una señal, y la lei como suerte.
//!
//! Y esa es la frontera correcta: por debajo del sumidero viven el PIO, la
//! sincronizacion con E y el perfil de placa (`board.rs`), sin duplicar el modelo.
//!
//! ── LA UNIDAD DEL RETARDO, que es la decision de diseño de este fichero ──────
//!
//! Q8 de ciclo de E: 256 = un periodo de E (666 ns a 1,5 MHz).
//!
//! No es cosmetica. Los retardos del camino de dibujo estaban en unidades MEZCLADAS
//! —`Y_MUX_ECYC` en ciclos de E, `BLANK_SETTLE_CYC` en ciclos de CPU, y `e6809(n)`
//! escalado por `E6809_SCALE_Q8`— y con el valor de 64 que quedo medido el
//! 2026-08-17, `e6809(2)` es MEDIO ciclo de E. Si la costura llevara ciclos enteros,
//! ese medio se redondearia a cero y se perderia justo el ajuste que dio el +37% de
//! frame rate. Con Q8 el sumidero del UVM2 redondea a entero para su campo de
//! comando y el nuestro convierte a ciclos de CPU sin perder nada.

use crate::ramp::{DRAW_SCALE, MIN_T1};
use core::sync::atomic::Ordering;

/// Registros de la VIA como DESPLAZAMIENTO (0..15), no como direccion absoluta.
/// Nuestro cartucho los mapea a $D000+ y la UVM2 los mete en A0-A3: esa traduccion es
/// del sumidero, que es donde vive lo que cambia entre placas.
pub const REG_PORT_B: u8 = 0x0;
pub const REG_PORT_A: u8 = 0x1;
pub const REG_T1_LO: u8 = 0x4;
pub const REG_T1_HI: u8 = 0x5;
pub const REG_SHIFT: u8 = 0xA;
pub const REG_CNTL: u8 = 0xC;

/// Un ciclo de E en las unidades de la costura.
pub const E: u32 = 256;

/// Por donde salen las escrituras. Lo implementa cada cartucho.
pub trait BusSink {
    /// Escribe `data` en el registro `reg` y espera `delay_q8` DESPUES.
    fn emit(&mut self, reg: u8, data: u8, delay_q8: u32);

    /// Espera a que termine la rampa de `t1` cuentas, mas `extra_q8`. SIN escribir.
    ///
    /// SEPARADO DE `emit` A PROPOSITO: es la unica diferencia REAL entre las dos
    /// placas en todo el camino de dibujo. Nuestro cartucho pregunta al hardware —
    /// sondea el flag T1 de la VIA, como hace la BIOS en `LF345: BITB <VIA_int_flags`.
    /// La imagen del UVM2 no puede: su lista de comandos la reproduce un ejecutor, y
    /// leer la VIA a mitad de lista mientras conducimos el bus de datos es lo que
    /// causaba los vectores fantasma. Alli se cuenta el retardo y punto.
    ///
    /// Ponerlo en el `trait` obliga a que esa diferencia este ESCRITA, en vez de
    /// escondida en dos implementaciones que se creen iguales.
    ///
    /// VA SEPARADO DE `emit` POR UNA SEGUNDA RAZON, que aparecio con `draw_line`: en una
    /// de sus ramas la rampa arranca al escribir T1CH pero la espera ocurre DESPUES de
    /// encender el haz, dos escrituras mas tarde. Si esperar fuera un parametro de
    /// escribir, esa rama no se podria expresar sin mentir. En una lista de comandos el
    /// retardo se suma al comando ANTERIOR, que es exactamente donde vive.
    /// `extra_q8` va CON SIGNO a proposito. Negativo = apagar el haz ANTES de que la
    /// rampa termine, que es fisicamente lo que hace falta si la rampa dura mas que sus
    /// `t1` cuentas (el 6522 cuenta t1 + 1,5, y el transporte añade lo suyo). Con el tipo
    /// sin signo ese lado del ajuste no se podia ni expresar — medido en la UVM2 el
    /// 2026-08-18: subir el retardo ENSANCHA el hueco de los vertices, o sea que el codo
    /// esta por debajo de cero.
    fn wait_ramp(&mut self, t1: u16, extra_q8: i32);

    /// El haz ha quedado apagado. Contabilidad de quien quiera llevarla.
    fn beam_blanked(&mut self) {}

    /// El sample-and-hold de Y sostiene ahora `vy`, asi que el siguiente vector que
    /// repita ese valor puede saltarse el muestreo entero.
    fn y_held(&mut self, _vy: i8) {}

    /// ¿El S&H de Y ya sostiene `vy`? Si es que si, el muestreo entero sobra — cuatro
    /// escrituras y la ventana de carga, el 25% del coste del vector. La cuenta la lleva
    /// cada placa porque cada una tiene su propia cache; la DECISION es del modelo.
    fn y_can_skip(&mut self, _vy: i8) -> bool {
        false
    }

    /// ¿Esta el haz encendido ahora mismo? Solo lo mira `keep_lit`.
    fn beam_is_lit(&self) -> bool {
        false
    }

    /// El haz ha quedado ENCENDIDO.
    fn beam_lit(&mut self) {}
}

/// Los huecos del camino, todos en Q8 de ciclo de E.
///
/// Se pasan en vez de leerse de knobs globales porque HOY viven en sitios distintos y
/// en unidades distintas en cada cartucho, y moverlos a la vez que el codigo haria
/// imposible saber cual de las dos cosas rompio algo. Es deuda declarada, no diseño.
#[derive(Clone, Copy)]
pub struct Timings {
    /// Escala de los huecos que imitan al 6809 (`e6809`), en Q8. 256 = tal cual.
    pub e6809_q8: u32,
    /// Ventana de carga del sample-and-hold de Y.
    pub y_mux_q8: u32,
    /// El asentamiento de `Moveto_d`, dependiente del tamaño en la BIOS; aqui su
    /// peor caso. Una sola linea que llego a ser la mitad del retardo del sistema.
    pub moveto_settle_q8: u32,
    /// Entre arrancar la rampa y encender el haz, para que el punto ya viaje cuando se
    /// ilumina. Sin esto queda un punto brillante en el vertice de SALIDA.
    pub beam_on_q8: u32,
    /// Lo que el haz sigue encendido DESPUES de que los integradores paren: la rampa se
    /// acabo pero el haz aun esta llegando. NO es la misma cantidad que la de encender —
    /// medido por biseccion en consola el 2026-08-07, apagar pide 2,5 veces mas, y tiene
    /// sentido fisico: arrancar desde parado y frenar contra la inductancia del yugo no
    /// son el mismo transitorio.
    pub blank_settle_q8: i32,
    /// Encadenar trazos iluminados sin apagar entre medias. Ahorra la costura de cada
    /// vertice; a cambio, un frame que acabe iluminado deja el haz encendido.
    pub keep_lit: bool,
}

impl Timings {
    /// Un hueco de `n` "ciclos de 6809", con su escala aplicada. Es `e6809(n)`.
    #[inline(always)]
    fn e(&self, n: u32) -> u32 {
        n * self.e6809_q8
    }
}

/// `Moveto_d` ($F312) — reposicionar con el haz apagado.
///
/// MOVIDO desde `vinterface.rs`, no reescrito: la secuencia de registros, los huecos y
/// sus comentarios son los que estaban. Lo unico que cambia es que las escrituras salen
/// por el sumidero en vez de por `bus_write` directamente, que es lo que permite que la
/// imagen del UVM2 use ESTE codigo y no una copia suya.
/// LA CONTABILIDAD DE `Y_HELD` LA LLEVA EL EMISOR, no el backend.
///
/// `ramp_params` exige el bit 8 de `Y_HELD` para aplicar el tope selectivo, pero el
/// estatico lo escribia CADA BACKEND por su cuenta — y el del UVM2 no lo hacia: guardaba
/// su propio `s_y` para decidir el salto del mux y dejaba el de `ramp` a cero. Resultado:
/// **VCAP_SLOW no salto NUNCA en ese cartucho**. Medido en consola el 2026-08-24, con
/// VCAP_SLOW en 30, 16 y 8: VCAP_SLOW_HITS = 0 en los tres, y Y_HELD = 0 por la sonda.
///
/// Era un contrato invisible entre dos cajas: una lee un estatico que la otra tenia que
/// acordarse de escribir. Y NO SIRVE ponerlo de valor por defecto del trait, que fue mi
/// primer intento: `CSink` y el firmware SOBRESCRIBEN los dos metodos, asi que el defecto
/// no correria justo en los que fallan. Va en los puntos de llamada, donde no se esquiva.
///
/// El callback del sumidero se queda: cada backend lo sigue usando para SU cache.
/// QUIEN INVALIDA NO ES EL EMISOR. Apagar el haz NO descarga el S&H de Y: lo que lo
/// pierde es que alguien toque el canal 0 del mux, y eso pasa al leer el JOYSTICK, que
/// comparte el CD4052 con el haz. Es cosa de cada placa, asi que se expone y ya.
///
/// Casi lo llamo desde `beam_blanked`, que habria dejado `y_can_skip` en falso para
/// siempre: cuatro escrituras y la ventana de carga de mas POR VECTOR, el 25% de su
/// coste. Lo cazo el test del tope selectivo al salir a cero.
#[inline(always)]
pub fn y_hold_lost() {
    crate::ramp::Y_HELD.store(0, Ordering::Relaxed);
}

#[inline(always)]
fn y_hold_is(vy: i8) {
    crate::ramp::Y_HELD.store(0x100 | (vy as u8 as u32), Ordering::Relaxed);
}

pub fn moveto_seq<S: BusSink>(sink: &mut S, vx: i8, vy: i8, t1: u16, k: &Timings) {
    sink.emit(REG_PORT_A, vy as u8, k.e(2)); // STA — Y velocity into D/A
    // VENTANA DE Y: se probo alargarla de `e(9)` a `y_mux_q8` (2 -> 14 ciclos de E),
    // razonando que un condensador no admite el descuento de `e6809_q8`, que se midio por
    // frame rate. La fisica respaldaba el cambio: tau = 1,8 us = 2,7 ciclos, asi que 2
    // ciclos cargan al 52%.
    //
    // MEDIDO EN CONSOLA el 2026-08-18 y REVERTIDO: bus_cycles 29529 -> 30333, exactamente
    // los +804 que predice 67 movimientos x 12 ciclos, con overrun pasando de 0 a 1295. El
    // mecanismo se confirmo al digito Y EL DIBUJO NO CAMBIO NADA. Asi que la ventana corta
    // no era la causa, y alargarla solo saca del presupuesto de frame.
    //
    // Se queda como estaba, con la nota, para que nadie vuelva a "arreglarlo" leyendo la
    // fisica sin mirar la medida.
    sink.emit(REG_PORT_B, 0x00, k.e(9)); // CLR — enable mux ch0 (Y sampling STARTS)
                                         // PSHS D (7) + LDA #$CE (2) — Y S&H charging
    sink.emit(REG_CNTL, 0xCE, k.e(2)); // STA — blank low, zero high (can move)
    sink.beam_blanked();
    sink.emit(REG_SHIFT, 0x00, k.e(4)); // CLR shift — beam off
                                        // (CLR = 6 cyc; Y S&H still charging)
    sink.emit(REG_PORT_B, 0x01, k.e(4)); // INC — disable mux (Y sampled + held)
    sink.y_held(vy); y_hold_is(vy); // deja el S&H cargado con SU vy: un draw_line que lo repita se lo salta
    sink.emit(REG_PORT_A, vx as u8, k.e(4)); // STB — X velocity into D/A (direct, no mux)
    sink.emit(REG_T1_LO, (t1 & 0xff) as u8, 0); // T1CL = escala (∝ longitud)
    // EL BYTE ALTO, DE VERDAD. Estuvo cocido a 0, y eso techaba la rampa en 255 aunque
    // el contador T1 de la VIA sea de 16 bits — 8 bits de recorrido tirados.
    sink.emit(REG_T1_HI, (t1 >> 8) as u8, 0);
    sink.wait_ramp(t1, k.moveto_settle_q8 as i32);
}

/// `Draw_Line_d` — el trazo iluminado. El grueso del camino de dibujo.
///
/// MOVIDO desde `vinterface.rs`: la secuencia, el orden de las tres ramas y sus huecos
/// son los que estaban. Lo unico nuevo es que las escrituras salen por el sumidero.
///
/// DESVIACION DE LA BIOS, heredada y deliberada: el haz se enciende por CNTL (0xEE/0xCE)
/// y no por el registro de desplazamiento con ACR = 0x98. El camino del SR no llego a
/// dibujar nada en este hardware; el de CNTL esta probado.
pub fn draw_line_seq<S: BusSink>(sink: &mut S, vx: i8, vy: i8, t1: u16, k: &Timings) {
    // Si el S&H de Y ya sostiene este vy, todo el muestreo sobra: cuatro escrituras y la
    // ventana de carga, el 25% del coste del vector.
    if !sink.y_can_skip(vy) {
        sink.emit(REG_PORT_A, vy as u8, k.e(2)); // STA — Y velocity
        sink.emit(REG_PORT_B, 0x00, k.y_mux_q8); // CLR — mux ch0 (empieza a cargar Y)
        sink.emit(REG_PORT_B, 0x01, k.e(4)); // INC — mux off (Y muestreado y retenido)
        sink.y_held(vy); y_hold_is(vy);
    }
    sink.emit(REG_PORT_A, vx as u8, k.e(3)); // STB — X velocity / LDD #$FF00
    sink.emit(REG_T1_LO, (t1 & 0xff) as u8, 0); // T1CL = escala (∝ longitud)

    // EL ORDEN IMPORTA, y en su dia estaba al reves. Encender ANTES de arrancar la rampa
    // deja el punto quieto e iluminado durante una escritura entera: un punto brillante
    // en el vertice de SALIDA, el espejo del que arregla `blank_settle_q8` al final.
    if k.keep_lit && sink.beam_is_lit() {
        // Continuacion de una tirada iluminada: el haz ya esta encendido Y ya se mueve,
        // asi que no necesita ni la escritura ni el hueco para arrancar. Esta es la
        // costura que perdia cuatro ciclos de E de recorrido en cada vertice.
        sink.emit(REG_T1_HI, (t1 >> 8) as u8, 0);
    } else if k.beam_on_q8 != 0 {
        sink.emit(REG_T1_HI, (t1 >> 8) as u8, k.beam_on_q8); // arranca la rampa PRIMERO
        sink.emit(REG_CNTL, 0xEE, 0); // haz ON — ya viajando
        sink.beam_lit();
    } else {
        sink.emit(REG_CNTL, 0xEE, k.e(2)); // haz ON (BIOS: STA shift 0xFF)
        sink.beam_lit();
        sink.emit(REG_T1_HI, (t1 >> 8) as u8, 0); // STB — arranca la rampa
    }

    // Asentamiento de la deflexion: la rampa acabo (T1 paro los integradores) pero el HAZ
    // sigue llegando. Se espera un tiempo fijo y se apaga. Es el termino que convierte los
    // puntos brillantes en los vertices y las esquinas abiertas en los dos extremos de un
    // mismo knob, en vez de en dos fallos distintos.
    sink.wait_ramp(t1, k.e(4) as i32 + k.blank_settle_q8);

    if !k.keep_lit {
        sink.emit(REG_CNTL, 0xCE, 0); // haz OFF (BIOS: STA shift 0x00)
        sink.beam_blanked();
    }
}

/// Una recta CON HUECOS, en UNA SOLA RAMPA.
///
/// El algoritmo del pintor en un display vectorial no puede ser un orden de dibujo —aqui
/// nada tapa a nada— sino quitar geometria. Pero partir una viga en trozos cuesta una
/// rampa por trozo: fijar los dos DAC, la cuenta de T1, abrir y cerrar. Y no hace falta:
/// la velocidad del haz la fijan los DAC, asi que mientras no se toquen el haz sigue
/// recorriendo LA MISMA RECTA. Lo unico que cambia por el camino es el BLANK.
///
/// `huecos` son tramos apagados en CUENTAS DE T1 dentro de 0..t1, ordenados y sin solapar.
/// Una cuenta de T1 es un periodo de E (los dos van a phi2), asi que el retardo de cada
/// tramo es `k.e(cuentas)` y la resolucion es una escritura de bus: para un vector de 62
/// cuentas, 62 puntos de conmutacion posibles. De sobra para un hueco.
///
/// LAS CONMUTACIONES INTERMEDIAS VAN CONTADAS, no sondeadas, y eso es deliberado: el
/// `trait` ya dice que sondear el flag T1 es lo unico que separa a las dos placas, y que
/// la imagen del UVM2 NO puede leer la VIA a mitad de lista sin sacar vectores fantasma.
/// Contar por dentro y sondear solo al final deja el asentamiento —que es donde se nota—
/// exactamente igual que en `draw_line_seq`, y hace que esto valga en las dos placas.
pub fn draw_line_patterned_seq<S: BusSink>(
    sink: &mut S, vx: i8, vy: i8, t1: u16, k: &Timings, huecos: &[(u16, u16)],
) {
    if huecos.is_empty() {
        return draw_line_seq(sink, vx, vy, t1, k);
    }
    if !sink.y_can_skip(vy) {
        sink.emit(REG_PORT_A, vy as u8, k.e(2));
        sink.emit(REG_PORT_B, 0x00, k.y_mux_q8);
        sink.emit(REG_PORT_B, 0x01, k.e(4));
        sink.y_held(vy); y_hold_is(vy);
    }
    sink.emit(REG_PORT_A, vx as u8, k.e(3));
    sink.emit(REG_T1_LO, (t1 & 0xff) as u8, 0);
    // La rampa arranca ANTES de encender, igual que en draw_line_seq: encender con el
    // punto quieto deja un punto brillante en el vertice de salida.
    sink.emit(REG_T1_HI, (t1 >> 8) as u8, k.beam_on_q8);

    let mut cur: u16 = 0;
    // Encendido hasta el primer hueco. Si el primer hueco empieza en 0, no se enciende.
    if huecos[0].0 > 0 {
        sink.emit(REG_CNTL, 0xEE, k.e(huecos[0].0 as u32));
        sink.beam_lit();
        cur = huecos[0].0;
    }
    for (i, &(a, b)) in huecos.iter().enumerate() {
        let _ = a;                       // ya se llego hasta `a` con el retardo anterior
        let fin = b.min(t1);
        let siguiente = huecos.get(i + 1).map(|g| g.0).unwrap_or(t1);
        // apagado durante el hueco
        sink.emit(REG_CNTL, 0xCE, k.e((fin.saturating_sub(cur)) as u32));
        sink.beam_blanked();
        cur = fin;
        // y encendido hasta el siguiente hueco (o hasta el final)
        if siguiente > cur {
            sink.emit(REG_CNTL, 0xEE, k.e((siguiente - cur) as u32));
            sink.beam_lit();
            cur = siguiente;
        }
    }
    // Lo que quede de rampa, sondeando como siempre: el asentamiento del final es lo que
    // convierte los puntos brillantes en los vertices, y ahi no se cuenta, se pregunta.
    sink.wait_ramp(t1.saturating_sub(cur), k.e(4) as i32 + k.blank_settle_q8);
    sink.emit(REG_CNTL, 0xCE, 0);
    sink.beam_blanked();
}

/// Los dos valores que `moveto` usa cuando `VARIABLE_T1` esta apagado, para que el
/// llamante no tenga que conocer `DRAW_SCALE`.
pub fn fixed_ramp(dx: i8, dy: i8) -> (i8, i8, u16) {
    let _ = MIN_T1.load(Ordering::Relaxed);
    (dx, dy, DRAW_SCALE as u16)
}

#[cfg(test)]
mod prueba {
    use super::*;

    /// Un sumidero que solo APUNTA. Es la verificacion del paso 3: la secuencia se
    /// comprueba en el Mac, sin consola — y hace falta que sea asi, porque en la placa
    /// de Ralf cada lectura por SWD la resetea.
    #[derive(Default)]
    struct Papel {
        v: std::vec::Vec<(u8, u8, u32)>,
        apagados: u32,
        y: std::vec::Vec<i8>,
        saltar_y: Option<i8>,
        encendido: bool,
    }
    impl BusSink for Papel {
        fn emit(&mut self, r: u8, d: u8, q: u32) {
            self.v.push((r, d, q));
        }
        fn wait_ramp(&mut self, t1: u16, extra: i32) {
            // Se apunta como un pseudo-comando para poder afirmar DONDE cae la espera.
            self.v.push((0xFF, 0, 0x8000_0000 | t1 as u32));
            self.v.push((0xFE, 0, extra as u32));
        }
        fn y_can_skip(&mut self, vy: i8) -> bool {
            self.saltar_y == Some(vy)
        }
        fn beam_is_lit(&self) -> bool {
            self.encendido
        }
        fn beam_lit(&mut self) {
            self.encendido = true;
        }
        fn beam_blanked(&mut self) {
            self.apagados += 1;
        }
        fn y_held(&mut self, vy: i8) {
            self.y.push(vy);
        }
    }

    /// La lista ESPERADA esta transcrita del `moveto` original de vinterface.rs, no
    /// generada por este codigo. Si se generara con lo mismo que verifica, no verificaria
    /// nada — solo diria que la funcion es igual a si misma.
    #[test]
    fn moveto_emite_la_secuencia_de_la_bios() {
        let k = tiempos(0, 0);
        let mut p = Papel::default();
        moveto_seq(&mut p, 40, -20, 0x5A, &k);

        assert_eq!(
            p.v,
            std::vec![
                (REG_PORT_A, (-20i8) as u8, 2 * E),  // STA — Y al D/A
                (REG_PORT_B, 0x00, 9 * E),           // CLR — mux ch0, empieza a cargar Y
                (REG_CNTL, 0xCE, 2 * E),             // STA — blank low, zero high
                (REG_SHIFT, 0x00, 4 * E),            // CLR shift — haz apagado
                (REG_PORT_B, 0x01, 4 * E),           // INC — mux off, Y retenido
                (REG_PORT_A, 40u8, 4 * E),           // STB — X al D/A, directo
                (REG_T1_LO, 0x5A, 0),                // T1CL
                (REG_T1_HI, 0x00, 0),                // T1CH arranca la rampa
                (0xFF, 0, 0x8000_005A),              // y se espera a que termine
                (0xFE, 0, 0),                        // mas el asentamiento de Moveto_d
            ]
        );
        assert_eq!(p.apagados, 1, "el haz se apaga UNA vez, en el 0xCE");
        assert_eq!(p.y, std::vec![-20i8], "el S&H queda con SU vy tras cerrar el mux");
    }

    fn tiempos(beam_on_q8: u32, blank_settle_q8: i32) -> Timings {
        Timings {
            e6809_q8: 256,
            y_mux_q8: 14 * 256,
            moveto_settle_q8: 0,
            beam_on_q8,
            blank_settle_q8,
            keep_lit: false,
        }
    }

    /// El orden de `draw_line`: arrancar la rampa y encender DESPUES. Al reves deja el
    /// punto quieto e iluminado una escritura entera — un punto brillante en el vertice
    /// de salida. Estuvo asi.
    #[test]
    fn draw_line_arranca_la_rampa_antes_de_encender() {
        let k = tiempos(2 * E, 11 * E as i32);
        let mut p = Papel::default();
        draw_line_seq(&mut p, 30, -10, 0x3E, &k);
        assert_eq!(
            p.v,
            std::vec![
                (REG_PORT_A, (-10i8) as u8, 2 * E), // STA — Y
                (REG_PORT_B, 0x00, 14 * E),         // CLR — mux ch0
                (REG_PORT_B, 0x01, 4 * E),          // INC — mux off
                (REG_PORT_A, 30u8, 3 * E),          // STB — X
                (REG_T1_LO, 0x3E, 0),               // T1CL
                (REG_T1_HI, 0x00, 2 * E),           // rampa PRIMERO, luego el hueco
                (REG_CNTL, 0xEE, 0),                // y ahora si, el haz
                (0xFF, 0, 0x8000_003E),             // esperar la rampa
                (0xFE, 0, 4 * E + 11 * E),          // + latencia y asentamiento
                (REG_CNTL, 0xCE, 0),                // apagar
            ]
        );
        assert!(p.encendido, "beam_lit tiene que haberse llamado");
        assert_eq!(p.apagados, 1);
    }

    /// UNA RECTA CON UN HUECO, EN UNA SOLA RAMPA. Lo que hay que ver: los DAC y T1 se
    /// programan UNA vez —no hay una segunda cabecera a mitad—, el haz se apaga y se
    /// vuelve a encender mientras la rampa corre, y la espera final es por el RESTO,
    /// no por `t1` entero: si no, en la placa que cuenta el retardo se esperaria dos veces.
    #[test]
    fn una_rampa_con_un_hueco() {
        let k = tiempos(2 * E, 11 * E as i32);
        let mut p = Papel::default();
        // 62 cuentas de rampa, apagado de la 20 a la 30
        draw_line_patterned_seq(&mut p, 30, -10, 0x3E, &k, &[(20, 30)]);
        assert_eq!(
            p.v,
            std::vec![
                (REG_PORT_A, (-10i8) as u8, 2 * E), // STA — Y
                (REG_PORT_B, 0x00, 14 * E),         // CLR — mux ch0
                (REG_PORT_B, 0x01, 4 * E),          // INC — mux off
                (REG_PORT_A, 30u8, 3 * E),          // STB — X
                (REG_T1_LO, 0x3E, 0),               // T1CL
                (REG_T1_HI, 0x00, 2 * E),           // la rampa arranca, y solo aqui
                (REG_CNTL, 0xEE, 20 * E),           // encendido las primeras 20 cuentas
                (REG_CNTL, 0xCE, 10 * E),           // apagado 10 cuentas — EL HUECO
                (REG_CNTL, 0xEE, 32 * E),           // encendido hasta el final
                (0xFF, 0, 0x8000_0000),             // esperar el RESTO (ya no queda)
                (0xFE, 0, 4 * E + 11 * E),          // + latencia y asentamiento
                (REG_CNTL, 0xCE, 0),                // apagar
            ]
        );
        // dos programaciones de DAC/T1 costaria partir la recta en dos; aqui hay UNA
        assert_eq!(p.v.iter().filter(|c| c.0 == REG_T1_HI).count(), 1);
        assert_eq!(p.v.iter().filter(|c| c.0 == REG_PORT_A).count(), 2); // vy y vx
    }

    /// Con el S&H de Y ya cargado, el muestreo entero se salta: cuatro escrituras menos.
    #[test]
    fn draw_line_se_salta_el_muestreo_de_y() {
        let k = tiempos(2 * E, 0);
        let mut p = Papel { saltar_y: Some(-10), ..Default::default() };
        draw_line_seq(&mut p, 30, -10, 0x3E, &k);
        assert_eq!(p.v[0], (REG_PORT_A, 30u8, 3 * E), "deberia empezar ya por la X");
        assert!(p.y.is_empty(), "si se salta el muestreo, el S&H no cambia de valor");
    }

    /// El byte alto de T1 tiene que VIAJAR. Estuvo cocido a 0 y eso techaba la rampa en
    /// 255 aunque el contador sea de 16 bits, dejando a VCAP sin recorrido.
    #[test]
    fn t1_lleva_los_dos_bytes() {
        let k = tiempos(0, 0);
        let mut p = Papel::default();
        moveto_seq(&mut p, 1, 1, 0x0123, &k);
        assert_eq!(p.v[6], (REG_T1_LO, 0x23, 0));
        assert_eq!(p.v[7].1, 0x01, "el byte alto se pierde otra vez");
    }
}

// ── Puente a C: el sumidero de la imagen del UVM2 ────────────────────────────
//
// Punteros a funcion porque quien implementa el sumidero alli es C. El contexto viaja
// opaco: a `uvm2_draw.c` le basta con su propio estado global.
//
// TODO ENTERO, sin un solo flotante, que es la regla de la caja: la imagen se compila
// `softfp` y el firmware `eabihf`, y el enlazador compara Tag_ABI_VFP_args aunque no
// cruce ninguno.

use core::ffi::c_void;

/// El sumidero visto desde C.
#[repr(C)]
pub struct CSink {
    pub ctx: *mut c_void,
    pub emit: extern "C" fn(*mut c_void, u32, u32, u32),
    pub wait_ramp: extern "C" fn(*mut c_void, u32, i32),
    /// Opcionales: la placa que no lleve esa contabilidad pasa null.
    pub beam_blanked: Option<extern "C" fn(*mut c_void)>,
    pub y_held: Option<extern "C" fn(*mut c_void, i32)>,
}

impl BusSink for CSink {
    fn emit(&mut self, reg: u8, data: u8, delay_q8: u32) {
        (self.emit)(self.ctx, reg as u32, data as u32, delay_q8);
    }
    fn wait_ramp(&mut self, t1: u16, extra_q8: i32) {
        (self.wait_ramp)(self.ctx, t1 as u32, extra_q8);
    }
    fn beam_blanked(&mut self) {
        if let Some(f) = self.beam_blanked {
            f(self.ctx);
        }
    }
    fn y_held(&mut self, vy: i8) {
        if let Some(f) = self.y_held {
            f(self.ctx, vy as i32);
        }
    }
}

/// Los huecos, vistos desde C. Mismos campos y misma unidad (Q8 de ciclo de E).
#[repr(C)]
pub struct CTimings {
    pub e6809_q8: u32,
    pub y_mux_q8: u32,
    pub moveto_settle_q8: u32,
    pub beam_on_q8: u32,
    pub blank_settle_q8: i32,
    pub keep_lit: u32,
}

impl CTimings {
    fn a_timings(&self) -> Timings {
        Timings {
            e6809_q8: self.e6809_q8,
            y_mux_q8: self.y_mux_q8,
            moveto_settle_q8: self.moveto_settle_q8,
            beam_on_q8: self.beam_on_q8,
            blank_settle_q8: self.blank_settle_q8,
            keep_lit: self.keep_lit != 0,
        }
    }
}

/// `Draw_Line_d` para quien llama desde C.
#[no_mangle]
pub extern "C" fn vx_draw_line_seq(sink: *mut CSink, vx: i32, vy: i32, t1: u32,
                                   k: *const CTimings) {
    if sink.is_null() || k.is_null() {
        return;
    }
    let (s, kk) = unsafe { (&mut *sink, &*k) };
    draw_line_seq(s, vx.clamp(-128, 127) as i8, vy.clamp(-128, 127) as i8, t1 as u16,
                  &kk.a_timings());
}

/// La recta con huecos, para quien llama desde C.
///
/// `huecos` apunta a `n` pares (inicio, fin) en cuentas de T1, ordenados y sin solapar.
/// Un puntero nulo o `n == 0` es exactamente una recta normal, asi que el llamante no
/// necesita dos caminos.
#[no_mangle]
pub extern "C" fn vx_draw_line_patterned_seq(sink: *mut CSink, vx: i32, vy: i32, t1: u32,
                                             k: *const CTimings,
                                             huecos: *const u16, n: u32) {
    if sink.is_null() || k.is_null() {
        return;
    }
    let (s, kk) = unsafe { (&mut *sink, &*k) };
    let t = kk.a_timings();
    let vx8 = vx.clamp(-128, 127) as i8;
    let vy8 = vy.clamp(-128, 127) as i8;
    if huecos.is_null() || n == 0 {
        return draw_line_seq(s, vx8, vy8, t1 as u16, &t);
    }
    // Tope fijo a proposito: esto corre en una imagen bare-metal, sin asignador. Un hueco
    // de mas se pierde —el tramo sale encendido— y eso se ve; una reserva dinamica aqui
    // seria un fallo que no se ve.
    const MAX: usize = 16;
    let cuantos = (n as usize).min(MAX);
    let mut buf = [(0u16, 0u16); MAX];
    for i in 0..cuantos {
        buf[i] = unsafe { (*huecos.add(i * 2), *huecos.add(i * 2 + 1)) };
    }
    draw_line_patterned_seq(s, vx8, vy8, t1 as u16, &t, &buf[..cuantos]);
}

/// `Moveto_d` para quien llama desde C. La MISMA funcion que usa el firmware: eso es
/// todo el objetivo de este fichero.
#[no_mangle]
pub extern "C" fn vx_moveto_seq(sink: *mut CSink, vx: i32, vy: i32, t1: u32, k: *const CTimings) {
    if sink.is_null() || k.is_null() {
        return;
    }
    let (s, kk) = unsafe { (&mut *sink, &*k) };
    let t = kk.a_timings();
    moveto_seq(s, vx.clamp(-128, 127) as i8, vy.clamp(-128, 127) as i8, t1 as u16, &t);
}

#[cfg(test)]
mod comparativa {
    use crate::ramp::ramp_params;
    use std::println;

    /// El `fixup` de Ralf, transcrito de uvm2_draw.c: mientras los dos deltas quepan en
    /// medio DAC y quede rampa, DOBLA el delta y PARTE la duracion. Conserva la distancia
    /// (delta x tiempo) y usa mas recorrido del DAC, que es su forma de acortar el trazo.
    fn ralf(dx: i32, dy: i32) -> (i32, i32, u32) {
        let (mut x, mut y, mut s) = (dx, dy, 160u32);
        while x.abs() < 64 && y.abs() < 64 && s > 32 {
            x *= 2;
            y *= 2;
            s /= 2;
        }
        (x, y, s)
    }

    /// LA PREGUNTA: ¿los dos modelos mueven el haz LO MISMO?
    ///
    /// La distancia es velocidad x tiempo en los dos. Si no coinciden, la geometria sale
    /// mal y no hay knob de tiempo que lo arregle — que es justo lo que la consola lleva
    /// diciendo toda la tarde.
    #[test]
    fn recorrido_de_los_dos_modelos() {
        println!("\n  dx  dy |    Ralf: dac x t = dist |   T1: v x t1 = dist |  error");
        println!("  -------+-------------------------+---------------------+-------");
        let mut peor = 0i64;
        for &(dx, dy) in &[(1, 0), (2, 0), (3, 1), (5, 0), (8, 3), (12, 0), (20, 7),
                           (32, 0), (48, 16), (64, 0), (100, 40), (127, 0)] {
            let (rx, _ry, rs) = ralf(dx, dy);
            let dr = rx as i64 * rs as i64;
            let (vx, _vy, t1) = ramp_params(dx as i8, dy as i8);
            let dt = vx as i64 * t1 as i64;
            let err = if dr != 0 { (dt - dr) * 100 / dr } else { 0 };
            if err.abs() > peor.abs() { peor = err; }
            println!("  {dx:3} {dy:3} | {rx:6} x {rs:3} = {dr:7} | {vx:5} x {t1:3} = {dt:7} | {err:4}%");
        }
        println!("\n  peor desviacion: {peor}%\n");
    }
}

#[cfg(test)]
mod pentagono {
    use crate::ramp::{ramp_params, DRAW_SCALE};
    use std::println;

    /// EL PENTAGONO DE `individual_tests/draw_line`, que en la UVM2 sale con los vertices
    /// abiertos. Coordenadas del fuente .vpy; el SDK manda DELTAS relativos y lleva el la
    /// posicion, asi que es una polilinea: un movimiento y cinco trazos encadenados.
    ///
    /// Si cada trazo recorriera su delta exacto, los vertices cerrarian por construccion.
    /// Aqui se comprueba cuanto se desvia cada uno, en unidades de dispositivo
    /// (distancia = velocidad x tiempo, contra el delta x DRAW_SCALE que se pedia).
    #[test]
    fn cierra_el_pentagono() {
        let v = [(0i32, 60i32), (-57, 19), (-35, -49), (35, -49), (57, 19), (0, 60)];
        let s = DRAW_SCALE as i64;
        println!("\n  trazo |   delta   |  vx  vy  t1 | recorrido    | pedido      | error");
        println!("  ------+-----------+-------------+--------------+-------------+-------");
        let (mut ex, mut ey) = (0i64, 0i64);
        for i in 0..5 {
            let (dx, dy) = (v[i + 1].0 - v[i].0, v[i + 1].1 - v[i].1);
            let (vx, vy, t1) = ramp_params(dx as i8, dy as i8);
            let (rx, ry) = (vx as i64 * t1 as i64, vy as i64 * t1 as i64);
            let (px, py) = (dx as i64 * s, dy as i64 * s);
            ex += rx - px;
            ey += ry - py;
            println!("  {i:5} | {dx:4},{dy:4} | {vx:4}{vy:4}{t1:4} | {rx:6},{ry:6} | {px:5},{py:5} | {:3},{:3}",
                     rx - px, ry - py);
        }
        println!("\n  DESVIACION ACUMULADA al cerrar: {ex}, {ey} unidades de dispositivo");
        println!("  (un delta de 1 son {s} unidades, asi que son {:.2}, {:.2} unidades de pantalla)\n",
                 ex as f64 / s as f64, ey as f64 / s as f64);
    }
}

#[cfg(test)]
mod velocidad {
    use crate::ramp::{ramp_params, DRAW_SCALE, MIN_T1, VCAP, VCAP_SLOW};
    use core::sync::atomic::Ordering;
    use std::println;

    /// VCAP es un GLOBAL y cargo corre los tests en paralelo: sin turno, el que barre
    /// valores se los cambia al otro por debajo y el fallo aparece una vez de cada diez.
    static TURNO: std::sync::Mutex<()> = std::sync::Mutex::new(());

    fn ralf(dx: i32, dy: i32) -> (i32, u32) {
        let (mut x, mut y, mut s) = (dx, dy, 160u32);
        while x.abs() < 64 && y.abs() < 64 && s > 32 { x *= 2; y *= 2; s /= 2; }
        (x.abs().max(y.abs()), s)
    }

    /// QUE VCAP hace que nuestra velocidad de pico NO pase de la suya.
    ///
    /// La distancia la conservan los dos, pero el REPARTO entre velocidad y tiempo no:
    /// nosotros vamos mas rapido durante menos tiempo. Y el amplificador de deflexion
    /// tiene velocidad de respuesta finita — pedirle mas de la que sigue deja el trazo
    /// corto, que es el hueco en los vertices.
    #[test]
    fn cual_es_el_vcap_que_iguala_a_ralf() {
        let _t = TURNO.lock().unwrap_or_else(|e| e.into_inner());
        let v = [(0i32, 60i32), (-57, 19), (-35, -49), (35, -49), (57, 19), (0, 60)];
        for cap in [127u32, 96, 80, 70, 64] {
            VCAP.store(cap, Ordering::Relaxed);
            let (mut peor, mut suyo_peor) = (0i32, 0i32);
            for i in 0..5 {
                let (dx, dy) = (v[i + 1].0 - v[i].0, v[i + 1].1 - v[i].1);
                let (vx, vy, _) = ramp_params(dx as i8, dy as i8);
                let n = (vx as i32).abs().max((vy as i32).abs());
                let (r, _) = ralf(dx, dy);
                if n > peor { peor = n; }
                if r > suyo_peor { suyo_peor = r; }
            }
            println!("  VCAP {cap:3} -> pico nuestro {peor:4}   pico de Ralf {suyo_peor:4}   {}",
                     if peor <= suyo_peor { "OK, no lo pasamos" } else { "MAS RAPIDO QUE EL" });
        }
        VCAP.store(127, Ordering::Relaxed);
    }

    /// EL TECHO DE t1 SE CALCULA POR VECTOR. Tres cosas, y las tres son comprobables:
    ///
    ///   a) a valores de fabrica no cambia nada — ningun delta pasa de DRAW_SCALE
    ///   b) el eje menor NUNCA se redondea a cero, que es el limite que define el techo
    ///   c) bajar VCAP le da recorrido de verdad al vector que puede frenarse, y NO se lo
    ///      da al que se aplanaria — que es justo lo que una constante global no podia
    ///
    /// El (c) es el que justifica el cambio: con el techo fijo en 160 los dos recibian
    /// 160 y VCAP quedaba saturado.
    #[test]
    fn el_techo_de_t1_es_por_vector() {
        let _t = TURNO.lock().unwrap_or_else(|e| e.into_inner());
        let s = DRAW_SCALE as i32;
        let piso = MIN_T1.load(Ordering::Relaxed) as i32;
        let lento = VCAP_SLOW.swap(0, Ordering::Relaxed);   // la regla del zigzag, aparte

        // (a) y (b), sobre los 65.024 deltas posibles
        VCAP.store(127, Ordering::Relaxed);
        let (mut peor, mut cuantos) = (0i32, 0u32);
        for dx in -127i32..=127 {
            for dy in -127i32..=127 {
                if dx == 0 && dy == 0 { continue; }
                let (vx, vy, t1) = ramp_params(dx as i8, dy as i8);
                let t1 = t1 as i32;
                assert!(t1 >= piso, "t1 {t1} por debajo del suelo en ({dx},{dy})");
                if t1 > peor { peor = t1; }
                if t1 > s { cuantos += 1; }
                // (b) ningun eje con delta se queda parado
                if dx != 0 { assert_ne!(vx, 0, "eje X muerto en ({dx},{dy}) con t1={t1}"); }
                if dy != 0 { assert_ne!(vy, 0, "eje Y muerto en ({dx},{dy}) con t1={t1}"); }
            }
        }
        assert_eq!(cuantos, 0, "a VCAP=127 nadie deberia pasar de DRAW_SCALE");
        assert_eq!(peor, s, "el maximo geometrico ES DRAW_SCALE, ni mas ni menos");

        // (c) el mismo VCAP, dos vectores, dos respuestas
        VCAP.store(8, Ordering::Relaxed);
        let (_, _, diagonal) = ramp_params(127, 127);
        let (_, vy_plano, plano) = ramp_params(127, 1);
        println!("  VCAP=8 -> diagonal (127,127) t1={diagonal}   alargado (127,1) t1={plano}");
        assert!(diagonal as i32 > s,
                "el diagonal tiene eje menor de sobra: deberia poder frenarse mucho mas alla de {s}");
        assert_eq!(plano as i32, s,
                   "el alargado no puede frenarse mas sin aplanarse contra la horizontal");
        assert_ne!(vy_plano, 0, "y por eso mismo su Y sigue viva");

        VCAP.store(127, Ordering::Relaxed);
        VCAP_SLOW.store(lento, Ordering::Relaxed);
    }

    /// EL TOPE SELECTIVO TIENE QUE DISPARARSE. Un contador a cero se lee igual que "no
    /// hace falta", y asi paso desapercibido en el UVM2 desde siempre: su backend nunca
    /// escribia `Y_HELD`, `ramp_params` no veia el bit 8 y la regla no salto NUNCA.
    ///
    /// Este test dibuja un zigzag por el emisor —el camino de verdad, con su sumidero— y
    /// exige que el contador suba. Es lo unico que distingue "la regla no hace falta" de
    /// "la regla esta muerta".
    #[test]
    fn el_tope_selectivo_se_dispara_de_verdad() {
        use crate::emit::{draw_line_seq, BusSink, Timings};
        use crate::ramp::VCAP_SLOW_HITS;
        let _t = TURNO.lock().unwrap_or_else(|e| e.into_inner());

        /// Un sumidero que NO implementa y_held ni beam_blanked, como el del UVM2: si la
        /// contabilidad dependiera del backend, este no la llevaria y el test fallaria.
        struct Mudo;
        impl BusSink for Mudo {
            fn emit(&mut self, _r: u8, _d: u8, _e: u32) {}
            fn wait_ramp(&mut self, _t1: u16, _e: i32) {}
        }

        VCAP.store(127, Ordering::Relaxed);
        VCAP_SLOW.store(30, Ordering::Relaxed);
        let antes = VCAP_SLOW_HITS.load(Ordering::Relaxed);

        // zigzag: cortos y con el signo de dy invertido en cada trazo, que es su firma
        let mut s = Mudo;
        let k = Timings { e6809_q8: 256, y_mux_q8: 256 * 14, moveto_settle_q8: 0,
                          beam_on_q8: 0, blank_settle_q8: 256 * 12, keep_lit: false };
        for i in 0..8 {
            let dy = if i % 2 == 0 { -7 } else { 9 };
            let (vx, vy, t1) = ramp_params(5, dy);
            draw_line_seq(&mut s, vx, vy, t1, &k);
        }
        let saltos = VCAP_SLOW_HITS.load(Ordering::Relaxed) - antes;
        println!("  el tope selectivo salto {saltos} veces en 8 trazos de zigzag");
        assert!(saltos > 0,
                "VCAP_SLOW no se disparo ni una vez: la regla esta MUERTA, no es que no haga falta");
    }
}
