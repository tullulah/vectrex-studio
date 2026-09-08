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

use crate::ramp::{escala, MIN_T1};
use core::sync::atomic::Ordering as Orden;

/// Escribe el encendido/apagado del haz por donde diga la perilla: por PCR (lo nuestro) o
/// por el registro de desplazamiento (la BIOS y el 6809). Un solo sitio para las dos formas,
/// para que no puedan divergir.
#[inline]
fn haz<S: BusSink>(sink: &mut S, encendido: bool, retardo: u32) {
    if crate::ramp::HAZ_POR_SR.load(Orden::Relaxed) != 0 {
        sink.emit(REG_SHIFT, if encendido { 0xFF } else { 0x00 }, retardo);
    } else {
        sink.emit(REG_CNTL, if encendido { 0xEE } else { 0xCE }, retardo);
    }
}
use core::sync::atomic::Ordering;

/// Registros de la VIA como DESPLAZAMIENTO (0..15), no como direccion absoluta.
/// Nuestro cartucho los mapea a $D000+ y la UVM2 los mete en A0-A3: esa traduccion es
/// del sumidero, que es donde vive lo que cambia entre placas.
pub const REG_PORT_B: u8 = 0x0;
pub const REG_PORT_A: u8 = 0x1;
pub const REG_T1_LO: u8 = 0x4;
pub const REG_T1_HI: u8 = 0x5;
pub const REG_SHIFT: u8 = 0xA;

/// Ultimo T1CL escrito (bit 8 = valido), para no repetirlo. Ver T1CL_CACHE.
static T1CL_ULTIMO: core::sync::atomic::AtomicU32 = core::sync::atomic::AtomicU32::new(0);

/// Olvidar el ultimo T1CL. Lo necesita quien vuelva a empezar una lista desde cero —y los
/// tests, porque el cache hace que la secuencia EMITIDA dependa del historial: el mismo
/// vector sale con o sin la escritura de T1CL segun lo que se dibujara antes. El TIEMPO no
/// cambia (el hueco anterior lo compensa), pero la lista si.
#[no_mangle]
pub extern "C" fn vx_t1cl_olvidar() { T1CL_ULTIMO.store(0, core::sync::atomic::Ordering::Relaxed); }

/// Escribe T1CL Y APUNTA lo que queda en el latch. TODO el que escriba T1CL tiene que pasar
/// por aqui.
///
/// El cache se actualizaba SOLO en `draw_line_seq`, pero el SALTO tambien escribe T1CL —con
/// su propio t1—, asi que tras cada salto el cache creia que la VIA tenia un valor que ya no
/// tenia y el trazo siguiente se saltaba una escritura que si hacia falta. `UNVEC` no lo
/// destapo porque tiene 9 saltos contra 56 trazos; dkong tiene 168 y salia destrozado.
#[inline]
fn emitir_t1cl<S: BusSink>(sink: &mut S, t1: u16, retardo: u32) {
    T1CL_ULTIMO.store((t1 & 0xff) as u32 | 0x100, Orden::Relaxed);
    sink.emit(REG_T1_LO, (t1 & 0xff) as u8, retardo);
}
pub const REG_CNTL: u8 = 0xC;

/// Un ciclo de E en las unidades de la costura.
pub const E: u32 = 256;

/* ── LOS HUECOS DEL MICROTRAMO, COMO GLOBALES Y NO EN EL STRUCT ──────────────────────
 *
 * Empezaron como campos de `Timings`/`CTimings`, que es donde conceptualmente van. NO
 * FUNCIONO: con los tamaños de los dos structs comprobados en compilacion (44 bytes en los
 * dos, `_Static_assert` en C y `assert!` en Rust) y el valor correcto en el lado C
 * (sondeado: 4), leerlos desde Rust hacia que UN comando por vector saliera con el hueco
 * saturado a 4095 y el frame se fuera de 23.831 a 788.661 ciclos. Y pasaba con CUALQUIERA
 * de los cuatro por separado, incluso con el que visiblemente producia su hueco correcto.
 * O sea que el tamaño cuadra y algo del paso por el ABI no.
 *
 * Los demas knobs de esta capa (VCAP, DRAW_SCALE, MIN_T1...) van por globales
 * `#[no_mangle]` y llevan meses funcionando. Se hace igual: es el camino probado, y de paso
 * el panel los puede tocar en caliente como a los otros.
 *
 * Son GAPS (lo que separa una escritura de la siguiente). 0 = el valor de siempre, que es
 * la cadencia medida de SU asterock. */
#[used] #[no_mangle]
pub static MT_ORA_Y: core::sync::atomic::AtomicU32 = core::sync::atomic::AtomicU32::new(0);
#[used] #[no_mangle]
pub static MT_ORB_KEEP: core::sync::atomic::AtomicU32 = core::sync::atomic::AtomicU32::new(0);
#[used] #[no_mangle]
pub static MT_SR_ON: core::sync::atomic::AtomicU32 = core::sync::atomic::AtomicU32::new(0);
#[used] #[no_mangle]
pub static MT_ORA_X_ON: core::sync::atomic::AtomicU32 = core::sync::atomic::AtomicU32::new(0);

/* SONDA: el campo tal como lo ve RUST, y el hueco que sale de el. El lado C dice 4 y el
 * comando emitido sale saturado a 4095, asi que hay que ver el valor AQUI. */
#[used] #[no_mangle]
pub static DBGX_CAMPO: core::sync::atomic::AtomicU32 = core::sync::atomic::AtomicU32::new(0);
#[used] #[no_mangle]
pub static DBGX_HUECO: core::sync::atomic::AtomicU32 = core::sync::atomic::AtomicU32::new(0);
#[inline(never)]
fn vx_dbg_x(campo: u32, hueco: u32) {
    DBGX_CAMPO.store(campo, core::sync::atomic::Ordering::Relaxed);
    DBGX_HUECO.store(hueco, core::sync::atomic::Ordering::Relaxed);
}


/// Por donde salen las escrituras. Lo implementa cada cartucho.
pub trait BusSink {
    /// Escribe `data` en el registro `reg` y espera `delay_q8` DESPUES.
    fn emit(&mut self, reg: u8, data: u8, delay_q8: u32);

    /// Alarga el hueco del ULTIMO comando ya emitido. Por defecto no hace nada.
    ///
    /// Existe porque quien apaga el haz es la llamada siguiente, no la que emitio la
    /// rampa: sin esto no hay forma de darle a la ultima rampa iluminada el tiempo de
    /// terminar. MEDIDO en su frame de Major Havoc — hueco 11 si el microtramo continua,
    /// 16 si lo que viene apaga, y la separacion es 175 de 175.
    fn alargar_ultimo(&mut self, _extra_q8: u32) {}

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

    /// ¿El DAC sostiene YA este `vx`? X es el DAC VIVO (sin sample-and-hold), asi que esto
    /// es "lo ultimo escrito en PORT_A es vx". Es la MITAD QUE FALTABA de `keep_lit`.
    fn x_can_skip(&mut self, _vx: i8) -> bool {
        false
    }
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
    /// LO QUE SE LE DEJA AL DAC PARA ASENTAR LA VELOCIDAD EN X, antes de arrancar la rampa.
    ///
    /// LOS DOS EJES NO ESTAN EN IGUALDAD, y esto lo iguala. La Y se MUESTREA: se escribe al
    /// DAC, se abre el mux `y_mux_q8` ciclos para que cargue el sample-and-hold, y se
    /// cierra — o sea que llega asentada. La X va DIRECTA al DAC y la rampa arranca tres
    /// comandos despues, sin ventana ninguna. Si el DAC no ha llegado, la velocidad en X
    /// del principio del trazo es la que sea.
    ///
    /// OBSERVADO en consola el 2026-08-24 sobre la rejilla, geometria QUIETA: las lineas
    /// VERTICALES se mueven unos 5 mm en horizontal y las horizontales estan bastante mas
    /// quietas. Una vertical se dibuja con vx = 0 y su X la fija el salto anterior; una
    /// horizontal lleva la X en la rampa. Que tiemble justo el eje sin ventana de
    /// asentamiento es la firma que hay que comprobar.
    ///
    /// 0 = como siempre. Es un knob para poder refutarlo en un minuto y sin recompilar.
    pub x_settle_q8: u32,

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

/* REVERTIDO 2026-08-24. Esto lo escribia el emisor para que VCAP_SLOW pudiera dispararse
 * tambien en el UVM2, donde llevaba muerto desde siempre. El diagnostico era correcto —
 * `Y_HELD` lo escribia cada backend y el del UVM2 no lo hacia— pero ACTIVARLO cambia como
 * se dibuja el 37% de los vectores en TODOS los juegos de los dos cartuchos, y en consola
 * salio mucho peor: dkong y SnowBros rotos.
 *
 * Reactivarlo es un cambio de comportamiento y merece su propia prueba, no venir de gorra
 * con un arreglo de contabilidad. La contabilidad vuelve al backend. */
#[allow(dead_code)]
#[inline(always)]
fn y_hold_is(vy: i8) {
    crate::ramp::Y_HELD.store(0x100 | (vy as u8 as u32), Ordering::Relaxed);
}

/* EL HUECO TRAS `T1CH`, SEGUN LO QUE VENGA DESPUES.
 *
 * MEDIDO en su frame 120 de Major Havoc, sobre sus 623 rampas de t1 = 8: deja 11 ciclos de
 * E cuando el microtramo CONTINUA (424 casos) y 16 cuando lo siguiente APAGA el haz (175),
 * sin un solo caso cruzado — clasificado por si hay una escritura al SR antes del proximo
 * T1CH. Es fisico y no una manía suya: la ultima rampa de un trazo iluminado tiene que
 * terminar ANTES de cerrar el haz, y cortandola sale un trazo corto.
 *
 * Se aplica alargando el hueco YA emitido (`alargar_ultimo`), porque quien apaga es la
 * llamada siguiente y el emisor del trazo no puede saberlo cuando emite. */
/// 1 = un trazo iluminado se emite como UNA rampa con su t1 entero, como el VecFever.
/// **ES EL POR DEFECTO desde 2026-09-04**, confirmado en consola: con microtramos Major
/// Havoc salia punteado y con el trazo entero sale LIMPIO. 0 vuelve a la serie de
/// microtramos de T1=8 (`-DUVM2_MICROTRAMOS`).
///
/// MEDIDO en su captura de Major Havoc (8 frames repartidos por los 20 s): **no parte un
/// trazo iluminado NI UNA VEZ** —cero rachas de microtramos iguales seguidos— y usa t1 de 8
/// hasta 252, con trazos de hasta 200 unidades en UNA rampa. Nosotros emitimos t1 = 8 en
/// todos, sin excepcion (427 de 427 en el banco, 754 de 754 en mhavoc), asi que un trazo
/// que no cabe en una rampa de 8 se parte — y cada junta son 22-24 ciclos con el haz
/// ENCENDIDO Y QUIETO, o sea un punto. Encaja con la consola: el banco (texto, trazos
/// cortos) nunca parte y sale limpio; mhavoc (diagonales largas) parte casi todo y puntea.
///
/// El comentario de abajo tomo la serie de microtramos de la captura de ASTEROCK. Las dos
/// capturas no dicen lo mismo — ver `vecfever-no-hay-una-cadencia`.
#[no_mangle]
pub static TRAZO_ENTERO: core::sync::atomic::AtomicU32 = core::sync::atomic::AtomicU32::new(1);

const H_T1CH_SIGUE:  u32 = 11;
const H_T1CH_CIERRA: u32 = 16;
/* Y CUANDO EL SR VA JUSTO DETRAS DEL T1CH, 29 — no 16. Misma captura: 21 casos, y en los
 * 175 de hueco 16 el comando siguiente es SIEMPRE ORA, nunca SR. El hueco no lo fija el
 * apagado, lo fija CUANTO se tarda en llegar a el. */
const H_T1CH_APAGA:  u32 = 29;
/* Y 21 CUANDO LO QUE VIENE ES LA UNIDAD LARGA QUE APAGA EN SU VENTANA. Cuarto valor de la
 * misma regla, medido igual que los otros tres: con t1 = 8 sus huecos de T1CH son 11 (sigue
 * el microtramo, x424), 16 (x175), 21 (x3) y 29 (apaga ya, x21). Los 3 de 21 son justo los
 * que llevan detras `ORA ORB=00+3 SR=00+8`, o sea la forma larga en ventana. */
const H_T1CH_CIERRA_LARGO: u32 = 21;
/* La rejilla del hueco tras el T1CH de un trazo iluminado, y su base. Ver draw_line_seq. */
const CUANTO_T1CH: u32 = 7;
const BASE_T1CH:   u32 = 13;
/* El hueco DESPUES de SR=00: 3 si le sigue ORB (175 casos suyos, y ya lo haciamos) y 15 si
 * le sigue ORA (13 suyos; nosotros poniamos 0 en 24). */
const H_SR_OFF_A_ORA: u32 = 15;

/// 1 = detras de esta unidad ciega viene OTRA antes del proximo trazo iluminado.
///
/// DECIDE DONDE SE APAGA EL HAZ, y la regla es suya, medida en su frame 120. De sus 199
/// apagados (uno por trazo, exactamente):
///
///   * 178 caen DENTRO de la ventana del mux de la unidad ciega — y en los 178 esa unidad
///     es la UNICA que hay hasta el proximo trazo.
///   * 21 caen ANTES, pegados al T1CH — y en los 21 vienen DOS unidades (cebado + salto) o
///     el bloque de re-cero.
///
/// Ni un caso cruzado. Y es fisico: con una sola unidad no hay viaje que dibujar, asi que
/// el apagado puede ir dentro; en cuanto hay transporte de verdad el haz tiene que estar
/// muerto ANTES de moverse o la travesia sale pintada.
///
/// Nosotros deciamos `t1 <= 8`, que acierta en las 178 y falla en las 21: la unidad de
/// cebado tambien lleva t1 = 8, asi que apagabamos dentro de su ventana y el salto que
/// venia detras se dibujaba. Es la clase de artefacto de la "estrella de rayos al centro".
/// 1 = permite omitir la recarga del sample-and-hold de Y cuando ya sostiene el valor.
/// **Apagado por defecto**: ver la medida en `moveto_seq`.
#[no_mangle]
pub static SALTAR_Y: core::sync::atomic::AtomicU32 = core::sync::atomic::AtomicU32::new(0);

#[no_mangle]
pub static SIGUEN_UNIDADES: core::sync::atomic::AtomicU32 =
    core::sync::atomic::AtomicU32::new(0);

pub fn moveto_seq<S: BusSink>(sink: &mut S, vx: i8, vy: i8, t1: u16, k: &Timings) {
    let sr = crate::ramp::HAZ_POR_SR.load(Orden::Relaxed) != 0;
    // QUE LA ULTIMA RAMPA ILUMINADA TERMINE. El cuanto depende de si el SR va JUSTO
    // detras del T1CH (rama de abajo) o si antes van ORA y ORB (salto corto del idioma SR).
    let encendido = sink.beam_is_lit();
    let solo_esta = SIGUEN_UNIDADES.load(Orden::Relaxed) == 0;
    /* EL t1 NO ENTRA EN LA REGLA: solo el recuento. Lo tuvimos como `t1 <= 8` y fallaba en
     * los dos sentidos — apagabamos fuera en sus 3 unidades solitarias de t1 = 18, y dentro
     * en las 21 de cebado+salto. Ver SIGUEN_UNIDADES. */
    let apaga_ya = encendido && !(sr && solo_esta);
    if encendido {
        let h = if apaga_ya { H_T1CH_APAGA }
                else if sr && t1 > 8 { H_T1CH_CIERRA_LARGO }
                else { H_T1CH_CIERRA };
        sink.alargar_ultimo((h - H_T1CH_SIGUE) * E);
    }
    // APAGAR LO PRIMERO (SR=0x00). Con keep-lit el haz llega ENCENDIDO al salto; si se
    // toca Y/mux antes de apagar, la travesia al destino se dibuja iluminada. El salto
    // CORTO del idioma SR es la excepcion: su unidad pen-up apaga DENTRO de la ventana
    // del mux, como el VecFever, asi que ahi el apagado no se adelanta.
    if apaga_ya {
        sink.emit(REG_SHIFT, 0x00, H_SR_OFF_A_ORA * E);
        sink.beam_blanked();
    }
    if sr {
        if t1 <= 8 {
            // SALTO CORTO = unidad PEN-UP del VecFever, verbatim: con el haz encendido
            // apaga DENTRO de la ventana del mux (x18.1/frame: ORA+4 ORB=00+9 SR=00+4
            // ORB=01+1 ORA+4 T1CL+1 T1CH+12); ya apagado, la unidad sin SR
            // (x27.9/frame: ORA+6 ORB=00+11 ORB=01+1 ORA+4 T1CL+1 T1CH+12).
            if sink.beam_is_lit() {
                sink.emit(REG_PORT_A, vy as u8, 3 * E);  // Y; hueco 4
                sink.emit(REG_PORT_B, 0x00, 8 * E);      // abre mux; hueco 9
                sink.emit(REG_SHIFT, 0x00, 3 * E);       // haz OFF en la ventana; hueco 4
                sink.beam_blanked();
            } else {
                /* EL HUECO DEL ORA(Y) ES 3, TAMBIEN CON EL HAZ YA APAGADO. Medido en su
                 * frame 120: de sus 270 unidades sin SR dentro, las 270 llevan hueco 3 —
                 * (3,9) x228 y (3,10) x42, o sea que lo que cambia con el estado del haz
                 * es la VENTANA DEL MUX, no el ORA. El 5 salio de la captura de asterock,
                 * que no dice lo mismo ([[vecfever-no-hay-una-cadencia]]). */
                sink.emit(REG_PORT_A, vy as u8, 3 * E);  // Y; hueco 4
                sink.emit(REG_PORT_B, 0x00, 10 * E);     // abre mux; hueco 11
            }
            sink.emit(REG_PORT_B, 0x01, 0);              // cierra mux; hueco 1
            sink.y_held(vy);
            sink.emit(REG_PORT_A, vx as u8, 3 * E + k.x_settle_q8); // X; hueco 4
            emitir_t1cl(sink, t1, 0);                    // T1CL; hueco 1
            sink.emit(REG_T1_HI, 0x00, H_T1CH_SIGUE * E);          // T1CH arma; hueco 12
            return;
        }
        // SALTO LARGO del VecFever, VERBATIM de la captura (su clase de "vectores
        // largos", x2475: ORA+4 ORB=00+11 ORB=01+1 ORA+9 T1CL+1 T1CH+t1+17). Sin PCR,
        // sin SR dentro de la unidad (el apagado ya salio arriba), T1 con la cuenta real.
        // CICLOS DE E CRUDOS, como el microtramo: k.e() escala por e6809_q8 (64 en
        // el UVM2) y deja los huecos a la mitad — medido: la cadencia salia 1/3/1/3.
        /* SI EL S&H DE Y YA SOSTIENE ESTE VALOR, EL MUESTREO ENTERO SOBRA — y el VecFever
         * se lo salta. Es su clase de salto MAS COMUN: `ORA+7 T1CL+1 T1CH+42`, tres
         * escrituras, 70 de sus 96 saltos en el frame. Nosotros haciamos las seis siempre.
         *
         * Las tres que se ahorran son ORA(Y), abrir el mux y cerrarlo: escribir el mismo
         * valor en un condensador que ya lo tiene no cambia nada y cuesta la ventana de
         * carga entera. `y_can_skip` es la misma pregunta que ya usa el camino con huecos.
         *
         * El hueco del ORA(X) pasa a 7 cuando se salta (su patron de tres) y sigue en 9
         * cuando no (su patron de seis, que es identico al nuestro). */
        /* MEDIDO OTRA VEZ, Y SALE LO CONTRARIO. En su frame 120 de Major Havoc el
         * VecFever carga la Y en **647 de 647** unidades, saltos incluidos, y 98 de esas
         * cargas son REDUNDANTES (el mismo valor que ya sostenia). No se la salta nunca.
         *
         * El "70 de sus 96 saltos" del parrafo de arriba salio de la captura de ASTEROCK, y
         * las dos capturas no dicen lo mismo ([[vecfever-no-hay-una-cadencia]]). Entre las
         * dos gana la fisica: el canal 0 es C304, 10 nF, y un condensador se descarga —
         * saltarse la recarga es apostar a que no ha derivado. Por eso la deriva medida era
         * 7 veces mayor en Y que en X, que es el DAC vivo y no retiene nada.
         *
         * Se deja el mecanismo detras de un knob por si alguna consola necesita los ciclos,
         * pero apagado: `SALTAR_Y=1` lo devuelve. */
        /* UNIDAD LARGA QUE ES LA UNICA CIEGA: el apagado va DENTRO de su ventana de mux,
         * igual que en la corta pero con el SR en el otro extremo de la ventana. Suyo,
         * verbatim (x3 en el frame 120, todas t1 = 18):
         *
         *     ORA(y)+3  ORB=00+3  SR=00+8  ORB=01+0  ORA(x)+6  T1CL+0  T1CH+34
         *
         * La ventana del mux mide 11 ciclos en las DOS formas (3+8 aqui, 8+3 en la corta):
         * lo que cambia es donde cae el SR dentro de ella, no cuanto carga C304. Y el hueco
         * del ORA(x) baja de 9 a 7 porque la escritura del SR ya se comio bus. */
        if sink.beam_is_lit() {
            sink.emit(REG_PORT_A, vy as u8, 3 * E);   // Y; hueco 4
            sink.emit(REG_PORT_B, 0x00, 3 * E);       // abre mux; hueco 4
            sink.emit(REG_SHIFT, 0x00, 8 * E);        // haz OFF en la ventana; hueco 9
            sink.beam_blanked();
            sink.emit(REG_PORT_B, 0x01, 0);           // cierra mux; hueco 1
            sink.y_held(vy);
            sink.emit(REG_PORT_A, vx as u8, 6 * E + k.x_settle_q8); // X; hueco 7
            emitir_t1cl(sink, t1, 0);
            sink.emit(REG_T1_HI, (t1 >> 8) as u8, 0);
            // Y LA ESPERA DE LA RAMPA, que aqui se me quedo en cero: el T1CH salia con
            // hueco 0 contra sus 34 (t1 = 18), o sea que la unidad no llegaba a recorrer
            // lo que pedia. Misma cuenta que el salto largo de abajo: t1 + 16.
            sink.wait_ramp(t1, k.moveto_settle_q8 as i32 + 16 * E as i32);
            return;
        }
        let saltar_y = SALTAR_Y.load(Orden::Relaxed) != 0 && sink.y_can_skip(vy);
        if !saltar_y {
            sink.emit(REG_PORT_A, vy as u8, 3 * E);   // Y al DAC; hueco 4
            sink.emit(REG_PORT_B, 0x00, 10 * E);      // abre mux; ventana 11
            sink.emit(REG_PORT_B, 0x01, 0);           // cierra mux; hueco 1
            sink.y_held(vy);
        }
        sink.emit(REG_PORT_A, vx as u8,
                  (if saltar_y { 6 * E } else { 8 * E }) + k.x_settle_q8); // X; hueco 7 o 9
        emitir_t1cl(sink, t1, 0);                 // T1CL; hueco 1
        sink.emit(REG_T1_HI, (t1 >> 8) as u8, 0);
        // La espera del VecFever tras armar: t1 + 16 (medido: +141 para t1=124,
        // +78 para t1=64 — o sea t1 + 14..17; se toma 16 y es barrible).
        /* EL HUECO TRAS EL T1CH ES MULTIPLO DE 7.
         *
         * En su frame 120 los de esta clase son 35, 42, 49, 56, 70 y 77 — todos 7*n, sin
         * excepcion — y con `hueco = 7 * techo((t1 + 13) / 7)` salen los NUEVE t1 distintos
         * clavados (22, 26, 28, 29, 31, 37, 41, 52, 56, 60). Es una ley y no un ajuste: el
         * 13 es el UNICO entero que satisface las nueve desigualdades a la vez. El 7 sera
         * su bucle de sondeo.
         *
         * Poniamos `t1 + 16`, que es la media de eso y falla por +-3 en la mitad: cada
         * error es rampa de mas o de menos, o sea un vector que se pasa o se queda corto.
         *
         * La unidad LARGA QUE APAGA EN VENTANA (la rama de arriba) NO va en esta rejilla:
         * sus tres casos de t1 = 18 dan 34, y 7*techo(31/7) seria 35. Por eso el cambio va
         * solo aqui y no en `wait_ramp`. */
        let hueco = CUANTO_T1CH * ((t1 as u32 + BASE_T1CH + CUANTO_T1CH - 1) / CUANTO_T1CH);
        sink.wait_ramp(t1, (hueco as i32 - t1 as i32) * E as i32 + k.moveto_settle_q8 as i32);
        return;
    }
    sink.emit(REG_PORT_A, vy as u8, k.e(5)); // STA — Y al DAC; hueco 6 (CLR dp)
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
    /* HUECOS EXACTOS DEL SALTO DEL 6809 (BIOS Moveto_d), contados de su asm en pagina
     * directa; su ciclo es un ciclo de E, asi que son nuestros retardos menos el ciclo de
     * la escritura:
     *     CLR VIA_port_b   (6) abrir mux;  PSHS A (5) + LDA# (2) + STA VIA_cntl (4) -> 11
     *     STA VIA_cntl     (4) PCR;        CLR VIA_shift_reg (6)                    ->  6
     *     CLR VIA_shift_reg(6) SR=0;       INC VIA_port_b (6)                       ->  6
     *     INC VIA_port_b   (6) cierra mux; PULS A (5) + STA VIA_port_a (4)          ->  9
     *     STA VIA_port_a   (4) X al DAC;   LDA# (2) + STA VIA_t1_cnt_lo (4)         ->  6
     *     STA VIA_t1_cnt_lo(4) T1CL;       CLR VIA_t1_cnt_hi (6)                    ->  6
     *
     * Arrancabamos la rampa del salto NUEVE ciclos antes, con el DAC de X aun llegando. Y
     * como todo lo que se dibuja despues parte de donde aterrice el salto, eso desplazaba
     * los trazos interiores — el sintoma que quedaba tras hacer ciclo-exacto solo el trazo. */
    sink.emit(REG_PORT_B, 0x00, k.e(10)); // CLR — abre mux; hueco 11
    sink.emit(REG_CNTL, 0xCE, k.e(5)); // STA — PCR; hueco 6
    sink.beam_blanked();
    /* AQUI NO VA `alargar_ultimo`: el comando ya emitido es el PCR, no el T1CH del trazo.
     * Lo hace el principio de `moveto_seq`, que es donde el ultimo emitido si es el T1CH. */
    sink.emit(REG_SHIFT, 0x00, k.e(5)); // CLR shift — haz off; hueco 6
    sink.emit(REG_PORT_B, 0x01, k.e(8)); // INC — cierra mux; hueco 9
    sink.y_held(vy); // deja el S&H cargado con SU vy: un draw_line que lo repita se lo salta
    sink.emit(REG_PORT_A, vx as u8, k.e(5) + k.x_settle_q8); // STB — X al DAC; hueco 6
    emitir_t1cl(sink, t1, k.e(5)); // T1CL; hueco 6 (CLR T1CH dp)
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
    // ── PLOTTER DEL VECFEVER, VERBATIM ($CA51) ───────────────────────────────────
    //
    // Cada vector es una serie de microtramos T1=8, misma tasa (vx,vy). El haz se
    // enciende UNA vez (SR=0x01, su valor exacto) cuando no lo estaba, y NO se apaga
    // entre trazos encadenados — solo un salto (moveto) o el re-cero apagan. Cadencia en
    // CICLOS DE E CRUDOS, medida de vecfever-asterock-bus.csv (no por k.e(), que escala
    // por el 6809 y partia los huecos a la mitad):
    //   ORA(Y) -6-> ORB=0 -8-> ORB=1 -1-> ORA(X) -4-> T1CL=8 -1-> T1CH=0 -12-> siguiente
    // El hueco de 12 tras T1CH deja terminar la rampa de 8 antes del siguiente microtramo.
    // t1 SE REDONDEA A MULTIPLOS DE 8: nada de microtramo de resto.
    //
    // Aqui emiti un dia la cola con la cuenta que quedara (T1CL = t1 % 8), justificandolo
    // con que el VecFever tiene T1CL=4/6/7 en su captura. LO MEDI MAL: son 1,11 por FRAME
    // contra sus 230,2 de T1=8, o sea el 0,5%. Con la cola, nosotros emitiamos 71 de 308
    // unidades por frame con T1 entre 1 y 6 — el 23%.
    //
    // Y una rampa de 1 a 6 cuentas no dibuja: el haz apenas se mueve, pero la unidad
    // cuesta sus ~32 ciclos de bus CON EL HAZ ENCENDIDO, asi que es un PUNTO entero. Eran
    // los puntos que se veian en cada vertice en consola.
    //
    // El precio del redondeo son hasta 4 cuentas de t1 por trazo, que a la tasa tipica
    // (48) es ~1,2 unidades de dispositivo — y la cadena de deuda se lo cobra al trazo
    // siguiente, asi que no se acumula.
    const T1M: u16 = 8;
    let n = core::cmp::max(1, ((t1 as u32) + (T1M as u32) / 2) / (T1M as u32));

    /* LA TASA SE RECALCULA PARA EL TIEMPO QUE DE VERDAD SE VA A CORRER.
     *
     * `ramp_params` reparte la distancia entre velocidad y tiempo y devuelve un `t1`
     * cualquiera; aqui ese tiempo se redondea a n microtramos de 8 — y hasta hoy la TASA se
     * dejaba como estaba. La distancia es `v*t1/s`, asi que cambiar el tiempo sin tocar la
     * velocidad cambia lo que se dibuja.
     *
     * MEDIDO con la geometria del VecFever de entrada, su primer segmento pide 2,5
     * unidades: `ramp_params` daba `t1=10, vy=40` (correcto: 40*10/160 = 2,5), esto lo
     * corria en `t1=8` con la misma tasa y salian **2,0 unidades — un 20% corto**. El
     * VecFever dibuja ese mismo segmento con `t1=8, vy=50`: elige la tasa PARA el tiempo,
     * que es lo que faltaba aqui.
     *
     * El error no es aleatorio: depende de donde caiga t1 respecto al multiplo de 8, asi
     * que trazos parecidos se acortan parecido y la figura sale deformada de forma
     * sistematica, no ruidosa. */
    /* LOS CUATRO HUECOS, RESUELTOS UNA VEZ. Son GAPS (lo que separa una escritura de la
     * siguiente); el emisor quiere gap-1 escalado por E. Fuera del bucle y sin clausura:
     * asi se ve el valor que se usa y no hay dudas de captura. */
    let hueco = |v: u32, def: u32| -> u32 {
        let gap = if v > 0 { v } else { def };
        (gap.max(1) - 1) * E
    };
    use core::sync::atomic::Ordering as O;
    /* LOS CUATRO HUECOS POR DEFECTO SON LOS MEDIDOS, DESDE 2026-09-04. Eran 6/8/4/9, de la
     * captura de asterock, y los puertos afinados los pisaban a mano con 4/10/9/4 — que son
     * los que hemos validado todo el dia contra su captura de Major Havoc (el banco sale al
     * 99,8% de sus trazos con ellos). Un valor medido que hay que recordar poner en cada
     * juego no es un valor por defecto, es una trampa. */
    let h_ora_y    = hueco(MT_ORA_Y.load(O::Relaxed), 4);
    let h_orb_keep = hueco(MT_ORB_KEEP.load(O::Relaxed), 10);
    let h_sr_on    = hueco(MT_SR_ON.load(O::Relaxed), 9);
    let h_ora_x    = hueco(MT_ORA_X_ON.load(O::Relaxed), 4);

    /* AQUI YA NO SE REESCALA. Lo hace `ramp_params_chain_q4`, que devuelve el t1 ya
     * redondeado a n microtramos y la tasa calculada para el — y asi la DEUDA ve ese
     * redondeo. Cuando se hacia aqui, su residuo quedaba fuera de la contabilidad y la
     * posicion se iba +8,45 unidades en X a lo largo del frame con la deuda a cero.
     *
     * Se conserva para el camino ENTERO (sin sub-unidades), donde la rampa no redondea a
     * multiplos de 8 y este ajuste sigue haciendo falta: sin el, un trazo que pide 2,5
     * unidades sale de 2,0 (medido con la geometria del VecFever). */
    let entero = TRAZO_ENTERO.load(O::Relaxed) != 0;
    let (n, t1u) = if entero { (1u32, t1) } else { (n, T1M) };
    let corridos = if entero { t1 as i32 } else { (n as i32) * (T1M as i32) };
    let (vx, vy) = if corridos as u16 == t1 {
        (vx, vy)                                  // ya viene ajustado
    } else {
        let reescala = |v: i8| -> i8 {
            let num = (v as i32) * (t1 as i32);
            let q = if num >= 0 { (num + corridos / 2) / corridos }
                    else        { (num - corridos / 2) / corridos };
            q.clamp(-128, 127) as i8
        };
        (reescala(vx), reescala(vy))
    };

    for i in 0..n {
        sink.emit(REG_PORT_A, vy as u8, h_ora_y); // ORA=Y
        let encender = !sink.beam_is_lit();
        if encender {
            sink.emit(REG_PORT_B, 0x00, 5 * E); // ORB=0 mux abre, late Y ; hueco 6
            sink.emit(REG_SHIFT, 0x01, h_sr_on);  // SR=0x01 haz ON (una vez)
            sink.beam_lit();
        } else {
            sink.emit(REG_PORT_B, 0x00, h_orb_keep); // ORB=0 mux abre, late Y
        }
        sink.emit(REG_PORT_B, 0x01, 0);         // ORB=1 mux cierra ; hueco 1
        // En la unidad que ENCIENDE, el VecFever deja hueco 9 tras la X (su patron
        // SR=01 mas comun: ORA+6 ORB+6 SR=01+4 ORB+1 ORA+9 T1CL+1 T1CH+12): el patron
        // 0x01 tarda 7 ciclos en llegar al bit encendido y ese hueco pone la rampa ya
        // corriendo cuando el haz aparece. En las encadenadas, hueco 4.
        sink.emit(REG_PORT_A, vx as u8,
                  if encender { h_ora_x } else { 3 * E }); // ORA=X
        emitir_t1cl(sink, t1u, 0);              // la duracion de ESTA rampa ; hueco 1
        /* El hueco tras T1CH deja terminar la rampa: con microtramos son los 8 fijos mas 3;
         * con el trazo entero, su duracion mas los mismos 3. */
        sink.emit(REG_T1_HI, 0x00, (H_T1CH_SIGUE - T1M as u32 + t1u as u32) * E);
    }
    sink.y_held(vy);
    // SIN apagar: keep-lit entre trazos encadenados, como el VecFever. Apagan moveto_seq
    // (salto) y el re-cero.
}


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
        sink.y_held(vy);
    }
    sink.emit(REG_PORT_A, vx as u8, k.e(3));
    emitir_t1cl(sink, t1, 0);
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
    (dx, dy, escala() as u16)
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
        /* ESTE TEST PRUEBA EL BLANKING POR PCR, que desde 2026-09-04 ya no es el de serie
         * (`HAZ_POR_SR` arranca en 1). Sigue siendo un camino vivo —`-DUVM2_HAZ_POR_PCR`—
         * asi que se fija aqui en vez de borrar el test. */
        crate::ramp::HAZ_POR_SR.store(0, core::sync::atomic::Ordering::Relaxed);
        /* LA CADENCIA QUE ESTE TEST AFIRMA ES LA DE ASTEROCK (6/8/4/9). Desde 2026-09-04 los
         * valores por defecto son los de MAJOR HAVOC (4/10/9/4), que son los validados
         * contra su captura; las dos son suyas y reales — ver `vecfever-no-hay-una-cadencia`.
         * Se fijan aqui para que el test pruebe UNA cadencia concreta y no lo que traiga el
         * defecto del dia. */
        MT_ORA_Y.store(6, core::sync::atomic::Ordering::Relaxed);
        MT_ORB_KEEP.store(8, core::sync::atomic::Ordering::Relaxed);
        MT_SR_ON.store(4, core::sync::atomic::Ordering::Relaxed);
        MT_ORA_X_ON.store(9, core::sync::atomic::Ordering::Relaxed);
        let k = tiempos(0, 0);
        let mut p = Papel::default();
        moveto_seq(&mut p, 40, -20, 0x5A, &k);

        assert_eq!(
            p.v,
            std::vec![
                // LOS HUECOS SON LOS DEL 6809 (BIOS Moveto_d), contados de su asm en
                // pagina directa: retardo = hueco - 1, porque la escritura gasta un ciclo.
                (REG_PORT_A, (-20i8) as u8, 5 * E),  // Y al D/A;     hueco 6
                (REG_PORT_B, 0x00, 10 * E),          // abre mux;     hueco 11
                (REG_CNTL, 0xCE, 5 * E),             // PCR;          hueco 6
                (REG_SHIFT, 0x00, 5 * E),            // SR=0;         hueco 6
                (REG_PORT_B, 0x01, 8 * E),           // cierra mux;   hueco 9
                (REG_PORT_A, 40u8, 5 * E),           // X al D/A;     hueco 6
                (REG_T1_LO, 0x5A, 5 * E),            // T1CL;         hueco 6
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
            x_settle_q8: 0,
        }
    }

    /// EL PLOTTER DEL VECFEVER, que es la especificacion desde el 2026-09-03: el trazo
    /// es una serie de microtramos T1=8 con la MISMA tasa, cadencia cruda 6/8/1/4/1/12
    /// (ciclos de E, medida de vecfever-asterock-bus.csv), el haz se enciende UNA vez
    /// por SR=0x01 (el patron tarda 7 ciclos en llegar al bit encendido: la rampa ya
    /// corre cuando el haz aparece) y NO se apaga al final — keep-lit; apagan el salto
    /// y el re-cero.
    #[test]
    fn draw_line_arranca_la_rampa_antes_de_encender() {
        /* LA CADENCIA QUE ESTE TEST AFIRMA ES LA DE ASTEROCK (6/8/4/9). Desde 2026-09-04 los
         * valores por defecto son los de MAJOR HAVOC (4/10/9/4), que son los validados
         * contra su captura; las dos son suyas y reales — ver `vecfever-no-hay-una-cadencia`.
         * Se fijan aqui para que el test pruebe UNA cadencia concreta y no lo que traiga el
         * defecto del dia. */
        MT_ORA_Y.store(6, core::sync::atomic::Ordering::Relaxed);
        MT_ORB_KEEP.store(8, core::sync::atomic::Ordering::Relaxed);
        MT_SR_ON.store(4, core::sync::atomic::Ordering::Relaxed);
        MT_ORA_X_ON.store(9, core::sync::atomic::Ordering::Relaxed);
        /* ESTE TEST CUBRE EL CAMINO DE MICROTRAMOS, que desde 2026-09-04 ya no es el por
         * defecto pero sigue existiendo tras `-DUVM2_MICROTRAMOS`. El del trazo entero es
         * `un_trazo_es_una_rampa`. */
        TRAZO_ENTERO.store(0, core::sync::atomic::Ordering::Relaxed);
        vx_t1cl_olvidar(); // el cache de T1CL es estado global entre tests
        let k = tiempos(2 * E, 11 * E as i32);
        let mut p = Papel::default();
        draw_line_seq(&mut p, 30, -10, 0x3E, &k);
        /* 0x3E = 62 cuentas -> 8 microtramos de 8, o sea 64 cuentas de verdad. El PRIMERO,
         * literal.
         *
         * LA X SALE 29 Y NO LOS 30 QUE SE PIDEN, Y ES LO CORRECTO: la distancia es v*t1/s,
         * asi que 30 durante las 62 pedidas son 11,6 unidades, y en las 64 que realmente se
         * corren hace falta v = 29. Antes se dejaba la tasa como venia y se dibujaban 12,0
         * — un 3% de mas aqui, y hasta un 20% en los trazos cortos. Ver el bloque de
         * `reescala` arriba. */
        assert_eq!(
            &p.v[..7],
            &[
                (REG_PORT_A, (-10i8) as u8, 5 * E), // Y al DAC;   hueco 6
                (REG_PORT_B, 0x00, 5 * E),          // abre mux;   hueco 6
                (REG_SHIFT, 0x01, 3 * E),           // haz ON (una vez); hueco 4
                (REG_PORT_B, 0x01, 0),              // cierra mux; hueco 1
                (REG_PORT_A, 29u8, 8 * E),          // X al DAC (reescalada);   hueco 9
                (REG_T1_LO, 8, 0),                  // T1CL=8;     hueco 1
                (REG_T1_HI, 0x00, H_T1CH_SIGUE * E),          // T1CH arma;  hueco 12
            ]
        );
        // Los invariantes del idioma, sobre la lista entera:
        assert_eq!(p.v.iter().filter(|c| c.0 == REG_T1_HI).count(), 8, "62 -> round(62/8) = 8 microtramos");
        assert!(p.v.iter().filter(|c| c.0 == REG_T1_LO).all(|c| c.1 == 8),
                "TODOS los microtramos son T1=8: una rampa mas corta no dibuja, quema un punto");
        assert_eq!(p.v.iter().filter(|c| c.0 == REG_SHIFT).count(), 1, "SR=0x01 UNA vez");
        assert!(p.v.iter().all(|c| c.0 != REG_CNTL), "el PCR no pinta nada en este idioma");
        assert!(p.encendido, "beam_lit tiene que haberse llamado");
        assert_eq!(p.apagados, 0, "keep-lit: draw_line NO apaga; apagan salto y re-cero");
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

    /// El muestreo de Y NO se salta nunca en el idioma microtramo: el VecFever re-latchea
    /// la Y en CADA unidad (medido en la captura: ORB=00/01 en los 187.850 microtramos),
    /// porque el condensador del S&H derrama y la unidad es la que lo refresca. La
    /// optimizacion de saltarse el muestreo era del modelo de una-rampa-por-vector.
    #[test]
    fn draw_line_se_salta_el_muestreo_de_y() {
        /* LA CADENCIA QUE ESTE TEST AFIRMA ES LA DE ASTEROCK (6/8/4/9). Desde 2026-09-04 los
         * valores por defecto son los de MAJOR HAVOC (4/10/9/4), que son los validados
         * contra su captura; las dos son suyas y reales — ver `vecfever-no-hay-una-cadencia`.
         * Se fijan aqui para que el test pruebe UNA cadencia concreta y no lo que traiga el
         * defecto del dia. */
        MT_ORA_Y.store(6, core::sync::atomic::Ordering::Relaxed);
        MT_ORB_KEEP.store(8, core::sync::atomic::Ordering::Relaxed);
        MT_SR_ON.store(4, core::sync::atomic::Ordering::Relaxed);
        MT_ORA_X_ON.store(9, core::sync::atomic::Ordering::Relaxed);
        /* ESTE TEST CUBRE EL CAMINO DE MICROTRAMOS, que desde 2026-09-04 ya no es el por
         * defecto pero sigue existiendo tras `-DUVM2_MICROTRAMOS`. El del trazo entero es
         * `un_trazo_es_una_rampa`. */
        TRAZO_ENTERO.store(0, core::sync::atomic::Ordering::Relaxed);
        vx_t1cl_olvidar(); // el cache de T1CL es estado global entre tests
        let k = tiempos(2 * E, 0);
        let mut p = Papel { saltar_y: Some(-10), ..Default::default() };
        draw_line_seq(&mut p, 30, -10, 0x3E, &k);
        assert_eq!(p.v[0], (REG_PORT_A, (-10i8) as u8, 5 * E),
                   "empieza por la Y aunque el S&H diga que ya la tiene");
        let ventanas = p.v.iter().filter(|c| c.0 == REG_PORT_B && c.1 == 0x00).count();
        assert_eq!(ventanas, 8, "una ventana de mux por microtramo, como el VecFever");
    }

    /// El byte alto de T1 tiene que VIAJAR. Estuvo cocido a 0 y eso techaba la rampa en
    /// 255 aunque el contador sea de 16 bits, dejando a VCAP sin recorrido.
    #[test]
    fn t1_lleva_los_dos_bytes() {
        /* ESTE TEST PRUEBA EL BLANKING POR PCR, que desde 2026-09-04 ya no es el de serie
         * (`HAZ_POR_SR` arranca en 1). Sigue siendo un camino vivo —`-DUVM2_HAZ_POR_PCR`—
         * asi que se fija aqui en vez de borrar el test. */
        crate::ramp::HAZ_POR_SR.store(0, core::sync::atomic::Ordering::Relaxed);
        let k = tiempos(0, 0);
        let mut p = Papel::default();
        moveto_seq(&mut p, 1, 1, 0x0123, &k);
        assert_eq!(p.v[6], (REG_T1_LO, 0x23, 5 * E), "T1CL del salto; hueco 6 (CLR T1CH dp)");
        assert_eq!(p.v[7].1, 0x01, "el byte alto se pierde otra vez");
    }

    /// UN TRAZO ILUMINADO ES UNA SOLA RAMPA, con su t1 entero — como el VecFever.
    ///
    /// MEDIDO en 8 frames de su captura de Major Havoc: no parte un trazo NI UNA VEZ, y sus
    /// t1 iluminados van de 8 a 252. Nosotros emitiamos t1 = 8 SIEMPRE y partiamos el
    /// resto; cada junta deja el haz encendido y quieto 22-24 ciclos, o sea un punto.
    /// Confirmado en consola: con microtramos Major Havoc puntea, con el trazo entero no.
    #[test]
    fn un_trazo_es_una_rampa() {
        vx_t1cl_olvidar();
        TRAZO_ENTERO.store(1, core::sync::atomic::Ordering::Relaxed);
        let k = tiempos(2 * E, 11 * E as i32);
        let mut p = Papel::default();
        draw_line_seq(&mut p, 30, -10, 0x3E, &k);
        let t1cl: std::vec::Vec<_> = p.v.iter().filter(|(r, _, _)| *r == REG_T1_LO).collect();
        assert_eq!(t1cl.len(), 1, "una sola rampa, no ocho microtramos");
        assert_eq!(t1cl[0].1, 62, "y con el t1 que se pidio, no con 8");
        /* Y LA TASA NO SE REESCALA, porque ya no hace falta: la rampa corre exactamente las
         * 62 cuentas pedidas, asi que los 30 de entrada son los 30 que se emiten. Con
         * microtramos corrian 64 y habia que bajarla a 29. */
        let ora: std::vec::Vec<_> = p.v.iter().filter(|(r, _, _)| *r == REG_PORT_A).collect();
        assert_eq!(ora[1].1, 30u8, "la tasa se emite tal cual");
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
    /* AL FINAL, Y OPCIONALES, a proposito. El consumidor de C construye su sumidero con
     * `struct vx_sink s = { 0 }`, asi que una placa que no rellene estas tres se queda
     * exactamente con el comportamiento de antes en vez de leer basura.
     *
     * POR QUE APARECEN AHORA. El emisor pregunta por ellas desde hace tiempo
     * (`y_can_skip`, `beam_is_lit`), pero `CSink` no las tenia: cualquier llamador desde C
     * caia en los valores por defecto del trait —falso y falso— sin que nada lo dijera. El
     * firmware del cartucho propio SI las implementa, porque usa la caja como rlib y el
     * trait directamente. Resultado: las dos placas compartian emisor y sólo una tenia las
     * optimizaciones. Medido el 2026-08-26 en el UVM2: `Y_HELD` a 0 todo el tiempo y
     * `VCAP_SLOW_HITS` a 0, que fue lo que lo destapó. */
    pub y_can_skip: Option<extern "C" fn(*mut c_void, i32) -> i32>,
    pub beam_is_lit: Option<extern "C" fn(*mut c_void) -> i32>,
    pub beam_lit: Option<extern "C" fn(*mut c_void)>,
    pub x_can_skip: Option<extern "C" fn(*mut c_void, i32) -> i32>,
    pub alargar_ultimo: Option<extern "C" fn(*mut c_void, u32)>,
}

impl BusSink for CSink {
    fn emit(&mut self, reg: u8, data: u8, delay_q8: u32) {
        (self.emit)(self.ctx, reg as u32, data as u32, delay_q8);
    }
    fn wait_ramp(&mut self, t1: u16, extra_q8: i32) {
        (self.wait_ramp)(self.ctx, t1 as u32, extra_q8);
    }
    fn alargar_ultimo(&mut self, extra_q8: u32) {
        if let Some(f) = self.alargar_ultimo {
            f(self.ctx, extra_q8);
        }
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
    fn y_can_skip(&mut self, vy: i8) -> bool {
        match self.y_can_skip {
            Some(f) => f(self.ctx, vy as i32) != 0,
            None => false,
        }
    }
    fn beam_is_lit(&self) -> bool {
        match self.beam_is_lit {
            Some(f) => f(self.ctx) != 0,
            None => false,
        }
    }
    fn beam_lit(&mut self) {
        if let Some(f) = self.beam_lit {
            f(self.ctx);
        }
    }
    fn x_can_skip(&mut self, vx: i8) -> bool {
        match self.x_can_skip {
            Some(f) => f(self.ctx, vx as i32) != 0,
            None => false,
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
    /* AL FINAL A PROPOSITO: este struct cruza la caja hacia C, asi que un campo nuevo va
     * detras para no mover los que ya estaban. Ver x_settle_q8 en Timings. */
    pub x_settle_q8: u32,
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
            x_settle_q8: self.x_settle_q8,
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

/// UN SOLO TURNO PARA TODOS LOS TESTS QUE MUEVEN KNOBS.
///
/// VCAP y MIN_T1 son GLOBALES y cargo corre los tests en paralelo. Habia un mutex POR
/// MODULO, y dos candados distintos no se serializan entre si: `el_techo_de_t1_es_por_vector`
/// fallaba solo cuando corria a la vez que los de `pentagono`, y pasaba al ejecutarlo suelto
/// — el peor fallo posible, porque invita a culpar al codigo que acabas de tocar.
#[cfg(test)]
pub(crate) static TURNO: std::sync::Mutex<()> = std::sync::Mutex::new(());

#[cfg(test)]
mod pentagono {
    use crate::ramp::{ramp_params, escala, MIN_T1};
    use core::sync::atomic::Ordering;
    use std::{format, println, vec, vec::Vec};

    /// UNA FIGURA CERRADA TIENE QUE CERRAR. Es la propiedad que caza esta familia entera
    /// de fallos, y por eso se comprueba sobre varias formas y varios ajustes en vez de
    /// sobre un pentagono suelto.
    ///
    /// ESTE TEST YA EXISTIA Y NO PODIA FALLAR. Media la desviacion acumulada al cerrar, la
    /// IMPRIMIA, y no tenia un solo assert: un informe disfrazado de test, que sale "ok" en
    /// cada `cargo test` mientras la cifra crece. El error de +6,30 unidades que se encontro
    /// el 2026-08-24 —y que costo una tarde de knobs en la consola— estaba ahi desde el
    /// principio, impreso, sin que nadie lo leyera.
    ///
    /// POR QUE ESTA PROPIEDAD BASTA: `ramp_params` reparte un delta entre velocidad y
    /// tiempo, los dos enteros, asi que un trazo suelto NO puede ser exacto. El error de
    /// uno solo es invisible; lo que se ve es que tiene SIGNO CONSTANTE y se suma. Un
    /// poligono cerrado convierte esa suma en una cifra: si el sesgo existe, no cierra.
    fn desvio_al_cerrar(v: &[(i32, i32)]) -> (f64, f64) {
        let s = escala() as i64;
        let (mut ex, mut ey) = (0i64, 0i64);
        for i in 0..v.len() - 1 {
            let (dx, dy) = (v[i + 1].0 - v[i].0, v[i + 1].1 - v[i].1);
            let (vx, vy, t1) = ramp_params(dx as i8, dy as i8);
            ex += vx as i64 * t1 as i64 - dx as i64 * s;
            ey += vy as i64 * t1 as i64 - dy as i64 * s;
        }
        (ex as f64 / s as f64, ey as f64 / s as f64)
    }

    use super::TURNO;

    #[test]
    fn las_figuras_cerradas_cierran() {
        let _t = TURNO.lock().unwrap_or_else(|e| e.into_inner());

        // pentagono, cuadrado grande, cuadrado pequeño, zigzag que vuelve, diagonal larga
        let figuras: [(&str, Vec<(i32, i32)>); 5] = [
            ("pentagono", vec![(0,60),(-57,19),(-35,-49),(35,-49),(57,19),(0,60)]),
            ("cuadrado grande", vec![(-100,-100),(100,-100),(100,100),(-100,100),(-100,-100)]),
            ("cuadrado pequeño", vec![(-6,-6),(6,-6),(6,6),(-6,6),(-6,-6)]),
            // el zigzag vuelve EN PASOS: cerrarlo de un trazo pedia -180 unidades y una
            // rampa solo expresa +-127, asi que se recortaba y el test acusaba al modelo de
            // un fallo que era de la figura. Lo caz el propio test.
            ("zigzag", { let mut v = vec![(-90,0)];
                         for i in 1..=12 { v.push((-90 + i*15, if i % 2 == 0 { 0 } else { 9 })); }
                         for i in 1..=12 { v.push((90 - i*15, 0)); }
                         v }),
            ("diagonal", vec![(-120,-120),(120,120),(-120,-120)]),
        ];

        // TOLERANCIA POR TRAZO, no absoluta: un trazo no puede ser exacto, pero el error no
        // puede CRECER con la longitud de la cadena. Media unidad por trazo es generoso —
        // el redondeo de una rampa vale como mucho eso— y aun asi el sesgo lo rompe.
        let mut mal = Vec::new();
        // SIN LA DIMENSION DE VCAP: el tope de velocidad ya no es un ajuste, es el limite
        // del DAC (ver TOPE_DAC en ramp.rs). Se conserva el barrido de MIN_T1, que es el
        // otro suelo del reparto y sigue existiendo — la propiedad que caza este test
        // (una figura cerrada CIERRA) no dependia del knob.
        for piso in [31u32, 8, 60] {
            MIN_T1.store(piso, Ordering::Relaxed);
            for (nombre, v) in figuras.iter() {
                let (ex, ey) = desvio_al_cerrar(v);
                let n = (v.len() - 1) as f64;
                let tope = 0.5 * n;
                println!("  MIN_T1 {piso:3}  {nombre:16} cierra a {ex:+7.2},{ey:+7.2}  (tope +-{tope:.1})");
                if ex.abs() > tope || ey.abs() > tope {
                    mal.push(format!("{nombre} a MIN_T1={piso}: {ex:+.2},{ey:+.2}"));
                }
            }
        }
        MIN_T1.store(31, Ordering::Relaxed);
        assert!(mal.is_empty(), "figuras que no cierran:\n  {}", mal.join("\n  "));
    }

    /// EL SESGO SE DETECTA EN LA MEDIA, NO EN EL TAMAÑO, y esto es lo que habria cazado el
    /// fallo del 2026-08-24 cuando se introdujo.
    ///
    /// Un trazo suelto NO puede ser exacto: velocidad y tiempo son enteros. Su error vale
    /// como mucho media unidad y eso es inevitable. Lo que NO es inevitable es que el error
    /// tenga siempre el MISMO SIGNO — entonces deja de ser ruido y pasa a ser una deuda que
    /// se suma trazo a trazo. El fallo real eran +0,075 unidades por trazo: invisible en
    /// cualquier tope por trazo, y +6,30 al cabo de 84.
    ///
    /// Asi que se mide la MEDIA sobre todos los deltas. Ruido honesto promedia a cero;
    /// un sesgo, no.
    #[test]
    fn el_error_de_la_rampa_no_tiene_sesgo() {
        let _t = TURNO.lock().unwrap_or_else(|e| e.into_inner());
        let s = escala() as f64;
        let mut mal = Vec::new();
        // SIN BARRER VCAP: ya no existe. La propiedad —que el error de la rampa promedie a
        // cero y no sea una deuda con signo— no dependia del tope de velocidad, y se
        // comprueba en la unica configuracion que hay.
        {
            let (mut suma, mut n) = (0f64, 0f64);
            for d in 1..=127i32 {
                let (vx, _, t1) = ramp_params(d as i8, 0);
                suma += (vx as f64 * t1 as f64 - d as f64 * s) / s;
                n += 1.0;
            }
            let media = suma / n;
            println!("  error medio por trazo: {media:+.4} unidades");
            // 0,02 unidades por trazo son 1,7 al cabo de 84 — ya visible. El listen tiene
            // que estar por debajo de lo que se ve, no por debajo de lo que molesta.
            if media.abs() > 0.02 {
                mal.push(format!("sesgo de {media:+.4} por trazo"));
            }
        }
        assert!(mal.is_empty(), "la rampa tiene SESGO, y un sesgo se acumula:\n  {}",
                mal.join("\n  "));
    }
}

#[cfg(test)]
mod velocidad {
    use crate::ramp::{ramp_params, escala, MIN_T1};
    use core::sync::atomic::Ordering;
    use std::println;

    use super::TURNO;

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
        /* `cual_es_el_vcap_que_iguala_a_ralf` RETIRADO (2026-09-09). Barria VCAP buscando el
     * valor que igualaba las velocidades de Ralf, y VCAP ya no existe: el tope es el del
     * DAC. Un test de un knob se va con el knob. */


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
        let s = escala();
        let piso = MIN_T1.load(Ordering::Relaxed) as i32;

        // (a) y (b), sobre los 65.024 deltas posibles
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
        assert_eq!(cuantos, 0, "nadie deberia pasar de DRAW_SCALE");
        assert_eq!(peor, s, "el maximo geometrico ES DRAW_SCALE, ni mas ni menos");

        // (c) EL TRANSPORTE MANDA SOBRE LA GEOMETRIA, y por defecto vale 160.
        //
        // Este trozo afirmaba lo contrario: que a VCAP=8 el diagonal llegaba a 2540. Es
        // cierto con T1_TRANSPORT=4095, y asi lo deje esta mañana — pero soltar el techo a
        // la vez que se desperto VCAP_SLOW rompio el dibujo en los dos cartuchos, asi que
        // el valor por defecto volvio a 160. El test sigue al codigo, no al reves.
        use crate::ramp::T1_TRANSPORT;
        // La parte que forzaba t1 con VCAP=8 se retira con el knob; lo que se conserva
        // es que el techo se calcula POR VECTOR, que es lo que este test caza.
        let (_, vy_plano, plano) = ramp_params(127, 1);
        let (_, _, diagonal) = ramp_params(127, 127);
        let tope = T1_TRANSPORT.load(Ordering::Relaxed) as i32;
        assert!(diagonal as i32 <= tope && plano as i32 <= tope,
                "nadie puede pasar del tope de transporte");
        assert_ne!(vy_plano, 0, "y ningun eje con delta se queda parado");

        // Y LA LEY POR VECTOR, comprobada sobre el techo y no sobre t1.
        //
        // Antes se observaba indirectamente: con VCAP forzando t1 hacia arriba, dos
        // vectores acababan en t1 distintos y eso delataba que sus techos eran distintos.
        // Sin tope de velocidad t1 no llega al techo, asi que hay que mirar el techo — que
        // es `d_menor * DRAW_SCALE` y sigue siendo por vector.
        T1_TRANSPORT.store(4095, Ordering::Relaxed);
        for (dx, dy) in [(127i8, 127i8), (127, 1), (60, 20), (5, 5)] {
            let (_, _, t) = ramp_params(dx, dy);
            let menor = (dx as i32).abs().min((dy as i32).abs()).max(1);
            assert!(t as i32 <= menor * s,
                    "({dx},{dy}): t1={t} pasa de su techo por vector {}", menor * s);
        }
        T1_TRANSPORT.store(tope as u32, Ordering::Relaxed);

    }

    /* `el_tope_selectivo_depende_del_backend` RETIRADO (2026-09-09) junto con VCAP_SLOW.
     *
     * Fijaba un CONTRATO que vale la pena no perder de vista: quien no escriba `Y_HELD` no
     * tenia tope selectivo. Ya no hay tope selectivo para nadie — la regla bajaba el tope a
     * los vectores CORTOS, que son los glifos del texto, y eso les alargaba t1. */




}
