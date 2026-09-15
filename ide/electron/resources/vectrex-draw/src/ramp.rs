//! `ramp_params` y sus knobs — el corazon del modelo de haz, en UN solo sitio.
//!
//! PASO 2 de la unificacion. Esto no es codigo nuevo: es EXACTAMENTE el que vivia en
//! `vinterface.rs`, movido tal cual con sus comentarios. Se movio, no se reescribio, y
//! esa distincion es la verificacion — el cuerpo tiene que salir caracter a caracter
//! identico, porque cada constante de aqui costo una sesion en la consola.
//!
//! Lo consumen los dos cartuchos: el firmware lo enlaza como `rlib` y la imagen del
//! multicart de Ralf como `staticlib` a traves de `vx_ramp_params`.
//!
//! Los knobs van `#[no_mangle]` para que el panel (`knobs/knobs.py`) los siga
//! resolviendo por nombre corto ahora que no estan en el modulo `vinterface`.

use core::sync::atomic::{AtomicI32, AtomicU32, Ordering};

/// LA ESCALA DEL DIBUJO — y es un NUMERO MAGICO, dicho por su propio comentario mas abajo:
/// "vale 0xA0 = 160 y es empirico". Nadie lo derivo de nada; se subio hasta que las figuras
/// salieron del tamano que parecio bien. La implementacion de Ralf, que dibuja bien en esta
/// misma consola, usa 128 — otro numero magico, sólo que el suyo funciona.
///
/// EN TIEMPO DE EJECUCION desde el 2026-08-25, para poder barrerlo desde el panel en vez de
/// recompilar por cada valor. Eso no lo convierte en derivado: sigue siendo empirico, y lo
/// que hace falta es explicar de donde sale, no encontrar el que mejor quede.
#[used]
#[no_mangle]
pub static DRAW_SCALE: AtomicU32 = AtomicU32::new(0xA0);

/// AJUSTE FINO DE LAS TASAS NEGATIVAS, POR EJE, EN 1/256.
///
/// El DAC no se desvia igual en `+k` que en `-k`: son patrones de bits distintos, y eso ya
/// esta medido en este proyecto — el error depende del VALOR, no de la distancia. En un
/// trazo donde los dos ejes piden el MISMO numero (una diagonal a 45 grados hacia el noreste)
/// la desviacion es la misma en los dos y la direccion sale limpia; donde piden numeros
/// OPUESTOS (la diagonal noroeste-sureste) `|vx|` y `|vy|` dejan de ser iguales de verdad, la
/// ida y la vuelta se inclinan en sentidos contrarios y se ven DOS lineas.
///
/// Daniel lo vio asi en la estrella de calibracion: con el cero ajustado cierran siete
/// brazos, los cuatro rectos y la diagonal noreste-suroeste, y queda abierta SOLO la
/// noroeste-sureste. Eso no lo arregla ningun cero —mueve los dos ejes a la vez— ni ninguna
/// escala —`abs()`, simetrica—: pide corregir el signo.
///
/// `v' = v * (256 + k) / 256` para v < 0. Con k = 0 no hace nada, que es el defecto.
#[no_mangle]
pub static TASA_NEG_X: AtomicI32 = AtomicI32::new(0);
#[no_mangle]
pub static TASA_NEG_Y: AtomicI32 = AtomicI32::new(0);

fn trim_neg(v: i32, k: i32) -> i32 {
    if v >= 0 || k == 0 { return v; }
    (v * (256 + k) / 256).clamp(-128, 127)
}

/// SE APLICA AL ESCRIBIR EN EL DAC, NO AL CALCULAR LA RAMPA. Y esto no es un detalle:
/// estuvo en `ramp_params_q` y NO HACIA NADA en las figuras.
///
/// Los trazos van por `ramp_params_chain`, que lleva una DEUDA acumulada: lo que un trazo se
/// pasa se le resta al siguiente. En un brazo de la estrella —ida y vuelta— la deuda cancela
/// el trim y la figura sale igual; los saltos no llevan deuda, asi que lo unico que se movia
/// era DONDE cae lo siguiente. Daniel lo vio exactamente asi: "diagx solo mueve el texto en
/// X, la estrella ni se inmuta".
///
/// Puesto aqui, el modelo —la rampa, la deuda, la geometria— se queda con la `v` ideal y lo
/// unico que cambia es el numero que ve el DAC, que es justo lo que se quiere compensar.
pub fn trim_dac(vx: i8, vy: i8) -> (i8, i8) {
    (trim_neg(vx as i32, TASA_NEG_X.load(Ordering::Relaxed)) as i8,
     trim_neg(vy as i32, TASA_NEG_Y.load(Ordering::Relaxed)) as i8)
}

/// El valor actual. Se lee una vez por vector, no en bucle cerrado.
///
/// CON RAMPA FIJA, LA ESCALA ES LA DURACION. La distancia es `vx*t1/s`, asi que solo con
/// `s = t1` sale `vx = dx` exacto — y eso es lo que hace que `s_pos` (lo que el dibujante
/// CREE que ha avanzado) coincida con el recorrido real. Con s=160 y t1=127 divergen un 21%
/// por vector y cada `move_abs` parte de una posicion equivocada: MEDIDO en el emulador el
/// 2026-08-25, el Kong salia deformado hasta atar las dos.
///
/// Se ata aqui y no en quien llama, porque "acuerdate de poner las dos" es exactamente la
/// clase de divergencia que este proyecto lleva pagando. Y explica de paso por que el 128
/// de Ralf ES su escala: en el modelo de tiempo fijo son el mismo numero.
#[inline]
pub fn escala() -> i32 {
    let fija = RAMPA_FIJA.load(Ordering::Relaxed);
    if fija > 0 { fija as i32 } else { DRAW_SCALE.load(Ordering::Relaxed) as i32 }
}

/// Dwell floor, RUNTIME since 2026-08-05 so it can be swept against glyph shape.
///
/// **DEFAULT 31, MEASURED on hardware 2026-08-05**: below it glyph strokes come out
/// visibly stepped, at it they are straight. Swept on the calibration screen against
/// the sample text, which is 1-2 unit strokes — exactly the vectors this bounds.
///
/// WHY a floor is needed at all, and it is NOT the arithmetic. The first theory was
/// integer truncation in `vx = dx * s / t1`, and it was wrong: rounding to nearest
/// (now done below) should have made t1 = 8 the BEST case (127/8 = 15.875 -> 16,
/// +0.8%) against t1 = 31 (4.096 -> 4, -2.4%). 31 still won, so the error term does
/// not decide this.
///
/// What decides it is that **the deflection lag is FIXED while the vector duration is
/// not**. `BEAM_ON_DELAY_CYC` and `BLANK_SETTLE_CYC` are 2 E cycles each, so on an
/// 8-cycle stroke they are half its duration — the beam is lit from 25% to 125% of the
/// travel, which is what "stepped" letters are. At 31 the same fixed lag is ~13%.
///
/// So this is a property of the TUBE, not a tuning preference: the minimum vector
/// duration this yoke can render faithfully. Task #10 (scope on the yoke) would
/// measure the same thing directly instead of through the user's eye.
///
/// COSTS FRAME TIME. It is the dwell floor, so every short vector pays it — see the
/// measurement in the task list before lowering it for speed.
#[used]
#[no_mangle]
pub static MIN_T1: AtomicU32 = AtomicU32::new(8);
/* ^ 8 Y NO 31, POR DEFECTO DESDE 2026-09-04: es lo que mide el VecFever en TODOS sus trazos
 * iluminados cortos (1861 de ~1900 en 8 frames), y lo que ya ponian a mano los puertos
 * afinados. Ver el-no-parte-los-trazos. */

/// Suelo de rampa SOLO para las que arrancan paradas (el salto y el primer trazo tras el).
/// Ver el bloque largo de `ramp_params`. De fabrica igual que MIN_T1 = inerte.
#[used]
#[no_mangle]
pub static MIN_T1_ARRANQUE: AtomicU32 = AtomicU32::new(31);

/// `T1_LAG` para esas mismas rampas. De fabrica igual que T1_LAG = inerte.
#[used]
#[no_mangle]
pub static T1_LAG_ARRANQUE: AtomicU32 = AtomicU32::new(0);

/// Cuantas rampas cobraron el suelo de arranque. UN CONTADOR, porque una rama que se
/// dispara en silencio ya ha costado sesiones en este proyecto: si esto no sube, el
/// knob no esta haciendo nada y no hay que creerse la medida.
#[used]
#[no_mangle]
pub static ARRANQUE_HITS: AtomicU32 = AtomicU32::new(0);

/// 1 = la proxima rampa arranca parada. La pone `vx_chain_reset` (o sea: un salto o un
/// re-cero) y la consume el primer trazo ENCADENADO que venga detras.
static ARRANQUE: AtomicU32 = AtomicU32::new(1);

                       // brightness the studio intro was validated with. Glitch-
                       // safe (HW-tested). Vector geometry is unchanged (distance =
                       // vel·t1). Lower toward 64 if a denser scene overruns the
                       // 20 ms budget — that was the original intro-fit value.
// Peak DAC velocity (of 0x7F). Below the full ±127 swing so the integrator op-amp
// doesn't overshoot on mid-length segments (the platform "stretch" at low MIN_T1).
// ramp_params raises t1 to hold velocity ≤ VCAP; short vectors are already under it.
/// Velocity cap, RUNTIME alongside MIN_T1 — the two interact (t1 is the max of both
/// floors), so sweeping one without the other cannot find the optimum.
/* EL TOPE DE VELOCIDAD ES EL DEL DAC, Y NO ES UN AJUSTE.
 *
 * Aqui habia `VCAP`, un knob que acotaba la VELOCIDAD del haz porque frenarlo carga mas el
 * fosforo: mas brillo. El precio no se vio hasta el 2026-09-09, comparando comando a
 * comando nuestra lista contra su captura del MISMO cuadro (la pantalla de records):
 *
 *   sus 427 trazos iluminados van TODOS a t1 = 8, con tasas de mediana 49 y maximo 51.
 *   Los nuestros salian 315 a t1 = 8 y 109 a t1 = 16, y esos 109 con tasa 29-31: el
 *   elector veia que hacia falta ~50, la prohibia por VCAP = 42 y DOBLABA t1 para bajar
 *   la tasa a la mitad.
 *
 * Y UNA RAMPA DE t1 = 16 NO RECORRE LO QUE DOS DE t1 = 8. En consola la tabla salia con
 * las filas apiladas, y con -DUVM2_MICROTRAMOS —que parte esos trazos en tramos de 8— se
 * ENDEREZA. Ese fue el experimento que lo cerro.
 *
 * SU REGLA es la que queda: t1 es el mas pequeño que mantenga la tasa dentro del DAC. El
 * tope no es una preferencia, es el limite del convertidor. El brillo el lo saca de Z, no
 * de frenar el haz — y su permanencia por unidad (3,2 ciclos) le sale sola porque el trazo
 * es corto.
 *
 * LO QUE SE PIERDE AL QUITARLO, para que conste: un barrido a frame fijo daba VCAP = 42 a
 * un 2% de sus ciclos por unidad y un 4% de su carga de fosforo (VCAP 29/34/38/42 ->
 * cic/ud 5,54/4,85/4,26/3,93 contra sus 4,00). Ese ajuste igualaba la MEDIA del frame
 * frenando el texto por debajo de lo que su geometria admite: un solo numero no puede
 * servir a los vectores largos y a los glifos. */
const TOPE_DAC: u32 = 127;
/* ^ 48 Y NO 127, POR DEFECTO DESDE 2026-09-04.
 *
 * 127 no es un tope: es "sin tope", y con el TODO trazo corre a la velocidad maxima, que es
 * el MINIMO de carga por unidad de longitud — o sea el minimo brillo. Los puertos afinados
 * lo ponian a mano (mhavoc 42, asterock 48) y los que no lo listaban —dkong, asteroids,
 * snowbros_c— se quedaban con el 127 y salian apagados en consola.
 *
 * El 48 sale de SU captura, no de copiarle el numero a otro puerto: la tasa de sus 2028
 * trazos iluminados en 8 frames tiene mediana 48 y p90 51. O sea que ESA es la velocidad a
 * la que el VecFever dibuja de verdad. (Tiene una cola del 1% a 126, asi que el no clampea;
 * lo que reproducimos es su velocidad TIPICA, que es lo que fija el brillo.)
 *
 * Cuesta framerate: un trazo mas lento dura mas. Un juego que no llegue lo sube con
 * -DUVM2_VCAP=N, que es justo lo que hacen mhavoc y asterock. */

/* ── VCAP DE LOS SALTOS, APARTE DEL DE LOS TRAZOS ───────────────────────────────────
 *
 * VCAP acota la VELOCIDAD del haz, y frenarlo es lo que da brillo: el fosforo se carga
 * con intensidad x TIEMPO, asi que un trazo rapido sale oscuro. Pero eso **solo cuenta
 * con el haz encendido**. Un salto va a oscuras: frenarlo no ilumina nada y solo gasta
 * frame.
 *
 * MEDIDO en la captura del VecFever (816 frames de asterock), separando sus unidades de
 * rampa por el estado del haz:
 *
 *     ENCENDIDO (dibuja) : tasa mediana 35    1.403 ciclos/frame  (175 unidades)
 *     APAGADO   (salta)  : tasa mediana 64   10.232 ciclos/frame  (317 unidades)
 *     -> SALTA A 1,8x LA VELOCIDAD A LA QUE DIBUJA
 *
 * Nosotros usabamos UN SOLO VCAP para las dos cosas, y eso obliga a elegir entre trazos
 * brillantes y saltos rapidos cuando no hay que elegir. El coste medido en asterock: para
 * igualar su carga de fosforo (3,27 ciclos encendido por unidad de longitud) haciamos
 * falta VCAP=48, y con el el frame pasaba de 33.205 a 72.578 ciclos —de 45 a 20,7 Hz—
 * porque los ~266 saltos por frame se alargaban con los trazos: ~267 ciclos por salto
 * contra los ~32 del VecFever.
 *
 * CERO = USAR EL MISMO QUE LOS TRAZOS, y es el defecto a proposito: mientras nadie le
 * ponga valor, ningun puerto cambia de comportamiento. */
#[used]
#[no_mangle]
/* `VCAP_SALTO` tambien se va. Existia para no frenar los saltos (van a oscuras, frenarlos
 * no ilumina nada) mientras VCAP frenaba los trazos; los cuatro objetivos que lo fijaban lo
 * ponian a 127, o sea que ya era el tope del DAC. Sin VCAP no hay nada de lo que eximirlos. */

/// TOPE DE TRANSPORTE — no es una preferencia, es el ancho de un campo.
///
/// Sustituye a `T1_CEILING`, que valia 160 (o sea DRAW_SCALE: el sitio donde estaba
/// cocido) con una justificacion FALSA escrita al lado. Decia que el contador T1 de la VIA
/// es de 8 bits y que 255 era su tope fisico: el T1 del 6522 cuenta **16 bits** y `emit`
/// escribe las dos mitades (T1CL y T1CH, ver `emit.rs`), asi que ni 160 ni 255 limitaban
/// nada. El techo de verdad se calcula por vector en `ramp_params`.
///
/// Lo unico que queda como constante es esto, y por una razon comprobable: el retardo
/// viaja en un campo de 12 BITS del comando del UVM2 (retardo 12 + registro 4 + dato 8 =
/// 24 bits, 3 bytes por comando), asi que 4095 cuentas es lo maximo que el ejecutor puede
/// esperar. Por encima el valor SE DERRAMA en los campos de registro y dato: comandos
/// corruptos y pantalla negra sin un aviso.
///
/// En ciclos de E son 2,73 ms, un 13,7% de un frame, contra un t1 geometrico que no pasa
/// de 160 — 25x de holgura. Runtime porque otra placa puede transportar el retardo de otra
/// forma; si alguna lo hace mas estrecho, bajarlo aqui es todo lo que hace falta.
#[used]
#[no_mangle]
/// POR DEFECTO 160, NO 4095, y eso es una RETIRADA con motivo. 4095 es el limite real del
/// transporte y el analisis sigue siendo correcto; pero soltar el techo a la vez que se
/// desperto VCAP_SLOW dejo que los vectores frenados pasaran de 160 a 677, y en consola el
/// dibujo se rompio en los dos cartuchos. 160 reproduce el T1_CEILING de siempre.
/// Subirlo es un experimento, y se hace con UNA variable y midiendo.
pub static T1_TRANSPORT: AtomicU32 = AtomicU32::new(160);

/// Map a vector delta to (velocity_x, velocity_y, t1_scale) for the variable-T1
/// model. Preserves the exact displacement of the fixed model (delta·0x7F):
///   distance = velocity · T1, so velocity = delta·0x7F / T1.
/// T1 ∝ length (dominant axis → full ±127 swing) but is clamped to [MIN_T1,0x7F];
/// deriving velocity from the CLAMPED T1 keeps the distance correct even when the
/// clamp kicks in (short vectors), instead of over-drawing them.
/// ---- TOPE DE VELOCIDAD SELECTIVO -------------------------------------------
///
/// MEDIDO en esta consola (reparada, ver ESTADO.md #31): con `VCAP = 127` el zigzag
/// de platform.vec se sale de su caja; con 30 entra. Pero bajar VCAP para TODO
/// cuesta **9,7 fps de 43,2 — un 22%** y el resto del dibujo no lo necesita: el
/// logo, la intro y las figuras largas salen bien a 127.
///
/// Lo que distingue al zigzag es que **invierte el signo de vy en cada vector**.
/// Asi que el tope se aplica SOLO cuando el salto de velocidad respecto al trazo
/// anterior pasa de un umbral, y el resto del frame corre a velocidad plena.
///
/// `Y_HELD` ya lleva el vy anterior (bit 8 = valido), asi que no hace falta estado
/// nuevo. Se calcula primero con el tope normal y, si el salto es grande, se
/// recalcula con el lento — dos divisiones de mas solo en los vectores afectados.
///
///   VCAP_SLOW = 0  -> desactivado, comportamiento de siempre
///   VCAP_DV        -> umbral del salto |vy - vy_anterior| que lo dispara
#[used]
// POR DEFECTO ACTIVO, con el valor MEDIDO en esta consola. El coste esta acotado:
// 43,2 fps sin regla, 40,9 con ella, 33,5 bajando VCAP para todo. O sea 2,3 fps en
// vez de 9,7 — el 76% del precio, eliminado.
//
// Una consola sana no lo necesita y paga esos 2,3 fps para nada: se apaga poniendolo
// a 0. Cuando VCAP salga del codigo y pase a ser calibracion de usuario (ESTADO.md
// #31), este valor viaja con el, no con el binario.
/// 1 = el TECHO del eje menor manda sobre el tope de velocidad. ES EL POR DEFECTO, y no
/// por inercia: `el_techo_de_t1_es_por_vector` afirma que ningun eje con delta se queda
/// parado, y soltarlo ya se probo una vez y rompio el dibujo en los dos cartuchos.
///
/// 0 hace ganar al tope de velocidad. Lo que compra y lo que cuesta esta en la nota de
/// `ramp_params_q`; se compara en consola con la imagen MHAVOCT.
#[no_mangle]
pub static TECHO_MANDA: AtomicU32 = AtomicU32::new(1);

/// 1 = la cadena corrige con la deuda (por defecto). 0 = no la aplica (la sigue apuntando).
///
/// Existe para poder MEDIR que aporta. Con la geometria de entrada en 1/16 la deuda es
/// necesaria —el redondeo de la entrada se acumula—, pero con 1/256 la entrada ya es casi
/// exacta y la correccion puede estar METIENDO el +-1 en vez de quitarlo.
#[no_mangle]
pub static DEUDA_ON: AtomicU32 = AtomicU32::new(1);

#[no_mangle]
/* `VCAP_SLOW` / `VCAP_DV` / `VCAP_SLOW_HITS` RETIRADOS con VCAP (2026-09-09).
 *
 * Bajaban el tope para los vectores frenados, y su condicion era `m <= VCAP_DV` — o sea que
 * se aplicaban a los CORTOS, que son justo los glifos del texto. Con el tope ya en el limite
 * del DAC no hay nada que bajar, y bajarlo reintroduciria el t1 largo por otra puerta.
 * Ningun objetivo los fijaba nunca. */


/// SALTO A TIEMPO FIJO, COMO EL VECFEVER. 0 = el modelo de siempre (tiempo variable).
///
/// MEDIDO en la captura de Major Havoc (`via.csv`, un frame de 20 ms, 593 unidades):
///
/// ```text
/// T1=8  microtramos : 501 unidades, haz ENCENDIDO en el 79%   -> dibujo
/// T1=31 saltos      :  72 unidades, haz APAGADO   en el 99%   -> mover
///                      |vx| mediana 64, maximo 126
/// otros             :  20 unidades, T1 hasta 191, |vx| mediana 113 -> saltos LARGOS
/// ```
///
/// O sea que su idioma de salto es **tiempo fijo y tasa variable**, justo al reves que el
/// nuestro (tasa fija a `VCAP_SALTO`, tiempo variable). La diferencia es de coste: su
/// salto cuesta ~40 ciclos SIEMPRE; el nuestro 53, con T1 mediana 9 y maximo 160.
///
/// El tiempo solo se alarga cuando la tasa se desbordaria del DAC — que es exactamente de
/// donde salen sus 20 unidades largas: a s=160 un salto de mas de 127*31/160 = 24 unidades
/// ya no cabe en +-127 con t1=31, y entonces el tiempo minimo es `m*s/127`.
///
/// CERO DE FABRICA a proposito: mientras nadie le ponga valor, ningun puerto cambia.
#[used]
#[no_mangle]
pub static T1_SALTO: AtomicU32 = AtomicU32::new(0);

#[inline(always)]
/// `ramp_params` para un SALTO: igual que el de los trazos pero con `VCAP_SALTO`, porque
/// el haz va apagado y el brillo no cuenta. Ver el bloque de VCAP_SALTO.
pub fn ramp_params_salto(dx: i8, dy: i8) -> (i8, i8, u16) {
    let fijo = T1_SALTO.load(Ordering::Relaxed) as i32;
    if fijo > 0 {
        return salto_tiempo_fijo(dx, dy, fijo);
    }
    ramp_params_con(dx, dy, TOPE_DAC)
}

/// El modelo de salto del VecFever: `t1` fijo, y la tasa es lo que salga.
///
/// No comparte cuerpo con `ramp_params_con` porque los dos suelos de aquel (`t1_floor`
/// proporcional a la longitud y `t1_vcap` por el tope de velocidad) existen para REPARTIR
/// la distancia entre velocidad y tiempo — y aqui no hay reparto que hacer: el tiempo esta
/// dado. Lo unico que se conserva es el redondeo, que tiene que ser el MISMO (misma
/// division con `T1_EXTRA_Q8`) o los saltos dejarian de casar con los trazos.
fn salto_tiempo_fijo(dx: i8, dy: i8, fijo: i32) -> (i8, i8, u16) {
    let s = escala();
    let m = core::cmp::max((dx as i32).abs(), (dy as i32).abs());
    if m == 0 {
        return (0, 0, MIN_T1.load(Ordering::Relaxed) as u16);
    }
    // El tiempo minimo para que la tasa quepa en el DAC, hacia ARRIBA: truncando, la tasa
    // se pasa, el DAC la recorta a +-127 y el salto se queda CORTO siempre en el mismo
    // sentido — el sesgo sistematico que documenta `t1_vcap` en el modelo de los trazos.
    let t1_cabe = (m * s + 126) / 127;
    let t1 = fijo.max(t1_cabe).min(T1_TRANSPORT.load(Ordering::Relaxed) as i32).max(1);
    let den = (t1 as i64) * 256 + T1_EXTRA_Q8.load(Ordering::Relaxed) as i64;
    let round_div = |num: i32| -> i32 {
        let n = num as i64 * 256;
        (if n >= 0 { (n + den / 2) / den } else { (n - den / 2) / den }) as i32
    };
    let vx = round_div(dx as i32 * s).clamp(-128, 127) as i8;
    let vy = round_div(dy as i32 * s).clamp(-128, 127) as i8;
    (vx, vy, t1 as u16)
}

pub fn ramp_params(dx: i8, dy: i8) -> (i8, i8, u16) {
    ramp_params_con(dx, dy, TOPE_DAC)
}

/// El modelo, con el tope de velocidad que le pase quien llame. Los trazos usan `VCAP` y
/// los saltos `VCAP_SALTO`: es el MISMO reparto de distancia entre velocidad y tiempo,
/// con distinto techo de velocidad.
fn ramp_params_con(dx: i8, dy: i8, vcap_in: u32) -> (i8, i8, u16) {
    ramp_params_q(dx as i32, dy as i32, vcap_in, 0)
}

/* EL MISMO MODELO CON SUB-UNIDADES. `dx`/`dy` vienen en 1/2^q unidades de dispositivo;
 * q = 0 es exactamente el comportamiento de siempre.
 *
 * POR QUE. La API de dibujo tomaba enteros de dispositivo, y esa rejilla es DIEZ VECES mas
 * basta que la del VecFever: el coloca puntos con la granularidad de la tasa (1/20 de
 * unidad a t1=8) y nosotros solo en el entero. MEDIDO en mhavoc sobre 81.552 vectores:
 * 0,22 unidades de error por eje —el maximo teorico es 0,5, o sea redondeo uniforme sin
 * sesgo pero con todo el ruido—, el 3,6% de los vectores enteramente sub-unidad y el 0,26%
 * DESAPARECIENDO porque sus dos extremos caen en el mismo punto. Con movimientos de 2
 * unidades de mediana y glifos de 2-3 unidades de alto, eso es la deformacion que se ve.
 *
 * El hardware no lo impedia: la distancia es v*t1/s y con t1 libre las distancias
 * fraccionarias se expresan solas (el pide v=51,t1=8 = 2,55 unidades). Lo imponia nuestra
 * aritmetica. Aqui se arregla dividiendo por 2^q en cada sitio donde una LONGITUD se
 * multiplica por la escala. */
fn ramp_params_q(dx: i32, dy: i32, vcap_in: u32, q: u32) -> (i8, i8, u16) {
    let f = 1i32 << q;
    let m = core::cmp::max(dx.abs(), dy.abs());
    /* ── DOS SUELOS, SEGUN SI LA RAMPA ARRANCA PARADA ────────────────────────────────
     *
     * Un trazo que CONTINUA al anterior entra con los integradores ya moviendose; el
     * primero despues de un salto en blanco tiene que acelerar desde el reposo, y esa es
     * la distancia que se pierde. Los dos pagaban el mismo suelo, asi que subirlo para
     * salvar al segundo se lo cobraba tambien al primero.
     *
     * MEDIDO EN CONSOLA (2026-08-26, dkong en el UVM2): con MIN_T1 = 31 los travesaños
     * sueltos de las escaleras salen desplazados y las vigas encadenadas salen bien; con
     * 94 sale TODO bien y el framerate cae de 23 a 14,3 fps. La cuenta dice por que:
     *
     *     23 -> 14,3 fps son 26,4 ms/frame; a 1,5 MHz, 39.700 ciclos
     *     39.700 / (94-31) = 630 operaciones pagando el suelo
     *     y el cartucho declara 549 vectores + 179 saltos = 728
     *
     * O sea que el 86% de lo dibujado estaba en el suelo: MIN_T1 no rescataba a unos
     * pocos trazos cortos, fijaba la duracion de casi todo. Con el suelo separado, solo
     * lo pagan las rampas que arrancan paradas — los saltos y el primer trazo de cada
     * figura— y no los cientos de tramos interiores.
     *
     * QUIEN ES QUIEN, y no hace falta ningun dato nuevo: `vx_chain_reset()` lo llama
     * quien reposiciona el haz (un salto o un re-cero), asi que "arranca parada" es
     * exactamente "es la primera rampa despues de un reset". El salto LEE la bandera sin
     * consumirla y el primer trazo iluminado la consume, de modo que los dos —el salto y
     * el trazo que lo sigue, que tambien parte del reposo— cobran el suelo de arranque.
     *
     * DE FABRICA VALEN LO MISMO QUE LOS DE SIEMPRE: mientras no se barran, el
     * comportamiento es identico al anterior, byte a byte. */
    let arranque = ARRANQUE.load(Ordering::Relaxed) != 0;
    if arranque { ARRANQUE_HITS.fetch_add(1, Ordering::Relaxed); }
    let min_t1 = if arranque { MIN_T1_ARRANQUE.load(Ordering::Relaxed) }
                 else        { MIN_T1.load(Ordering::Relaxed) } as i32;
    let mut vcap = vcap_in as i32;

    // ¿Este vector pide un salto grande de velocidad en Y respecto al anterior?
    // Se estima con la velocidad que TENDRIA al tope normal; no hace falta que sea
    // exacta, solo distinguir el zigzag del resto.
    // EL DISPARADOR ES EL CAMBIO DE SIGNO, NO LA MAGNITUD.
    //
    // La primera version disparaba con "salto grande de vy respecto al anterior" y
    // MEDIDO en hardware salto 218.591 veces en 2.767 frames — 79 vectores por frame,
    // o sea casi todos. No seleccionaba nada: equivalia a bajar VCAP para todo, pero
    // por un camino mas fragil. El umbral no separaba porque casi cualquier par de
    // vectores consecutivos da un salto grande en vy.
    //
    // La firma REAL del zigzag es otra: el signo de dy **se invierte en cada trazo**.
    //
    //     zigzag:  (5,-7) (5,9) (6,-9) (6,9)   <- alterna en cada uno
    //     logo:    trazos consecutivos que mantienen el signo
    //
    // Y ademas son CORTOS. Las dos condiciones juntas describen el zigzag y casi nada
    // mas. `Y_HELD` guarda el vy anterior (bit 8 = valido) y su signo es el de dy,
    // porque vy = dy * s / t1 con s y t1 positivos.
    if m == 0 {
        return (0, 0, min_t1 as u16); // degenerate (dot); minimal ramp
    }

    /* ── EL MODELO DE TIEMPO FIJO, COMO LA BIOS Y COMO RALF ──────────────────────
     *
     * RAMPA_FIJA = 0 -> el modelo de siempre (tiempo variable). >0 -> ese valor es la
     * duracion de TODAS las rampas, y la longitud sale entera del DAC: vx = dx.
     *
     * POR QUE. El asm de 6809 que dibuja bien esta misma figura en esta misma consola
     * carga `T1CL = $7F` UNA VEZ y despues, por cada vector, solo hace `CLR T1CH` para
     * dispararla. Todos los vectores duran 127 cuentas. Ralf hace lo mismo con
     * m_Scale = 128. Nosotros repartimos la distancia entre `vx` Y `t1`, con t1 de 31 a
     * 160 — y eso hace que CUALQUIER error en el modelo de DURACION (el +1,5 del
     * contador, el asentamiento, la fase de E) se convierta en error de distancia
     * dividido por t1: 1% en un trazo largo, 5% en uno corto, 19% con MIN_T1=8.
     *
     * Eso es exactamente el sintoma medido el 2026-08-25: perimetro de Kong perfecto y
     * detalle interior desplazado, la misma recta en 8 rampas mas larga que en 1, y el
     * 6809 dibujando bien lo que nosotros torcemos.
     *
     * Con tiempo fijo no hay reparto, asi que no hay donde concentrar el error — y
     * ademas vx = dx exacto, o sea que el residuo de redondeo desaparece y la cadena de
     * deuda se queda sin trabajo. El coste es el otro lado de la moneda: un trazo corto
     * dura lo mismo que uno largo, que es justo el ahorro que perseguia MIN_T1. Por eso
     * es una perilla y no una sustitucion: hay que MEDIR las dos en la misma consola. */
    let fija = RAMPA_FIJA.load(Ordering::Relaxed) as i32;
    if fija > 0 {
        return ((dx / f).clamp(-128, 127) as i8, (dy / f).clamp(-128, 127) as i8, fija as u16);
    }
    // 0xA0 = 160, NO 0x7F: el comentario que habia aqui decia 0x7F y llevaba tiempo
    // mintiendo. `s` gobierna la longitud Y la velocidad de todos los vectores
    // (vx = dx*s/t1, y t1 se acota a s), asi que razonar sobre ramp_params con 127 en la
    // cabeza da numeros mal. Se detecto porque el histograma de t1 tenia un cubo de >=128
    // que con s=127 no puede existir.
    let s = escala();
    let t1_floor = (s * m / (127 * f)).clamp(min_t1, s); // dwell floor (∝ length)
    // VELOCITY CAP: at MIN_T1=24 mid-length segments (24 < m ≤ 110) run at the full
    // ±127 swing, and the integrator op-amp overshoots the endpoint → platform
    // vectors "stretch". MIN_T1=110 avoided it by throttling their velocity (long
    // t1). Replicate that WITHOUT raising the global floor: if the dominant velocity
    // (m·0x7F / t1) would exceed VCAP, raise t1 so it lands at VCAP (distance is
    // preserved: velocity·t1 stays). Short vectors are already below VCAP → their
    // short dwell (the flicker win) is untouched. t1 is capped at 0x7F.
    // DIVISION HACIA ARRIBA, y aqui vivia un sesgo SISTEMATICO de -0,79 unidades por
    // vector. `t1_vcap` es un SUELO: el tiempo minimo para que la velocidad no pase de
    // VCAP. Truncando hacia abajo el suelo se queda corto, la velocidad se pasa, el DAC la
    // recorta a +-127 y el vector sale CORTO — siempre en el mismo sentido, asi que se
    // acumula LINEALMENTE con el numero de trazos.
    //
    //   m=50, VCAP=127:  50*160/127 = 62,99 -> 62    vx = round(8000/62) = 129 -> 127
    //                    recorrido = 127*62/160 = 49,2                        -> -0,79
    //   con techo:                          -> 63    vx = round(8000/63) = 127
    //                    recorrido = 127*63/160 = 50,006                      -> +0,006
    //
    // MEDIDO en el host el 2026-08-24 sobre los 127 deltas: peor caso -0,788 antes, y una
    // fila de cuatro trazos acumulaba -3,15. Es el sesgo que describe el comentario de
    // VPY_MAX_CONSECUTIVE_DRAWS en el SDK ("fixed per movement, accumulates by count") y
    // que se estaba tapando re-cerando el haz cada pocos trazos.
    let vc = vcap.max(1);
    let t1_vcap = ((m * s + vc * f - 1) / (vc * f)).max(1);
    // EL TECHO SE CALCULA POR VECTOR, NO SE FIJA.
    //
    // `t1` y la velocidad son las dos mitades del mismo producto —v = d*s/t1— asi que
    // alargar la rampa hunde la velocidad, y el primero en morir es el EJE MENOR: cuando su
    // v se redondea a cero el vector se aplasta contra su eje mayor. Exigiendo solo que se
    // mueva, |v| >= 1:
    //
    //     t1 <= d_menor * s
    //
    // NO PUEDE CONTRADECIR AL SUELO: d_menor >= 1 da un techo >= s, y `t1_floor` ya esta
    // acotado a s, asi que el intervalo nunca se invierte. Y NO SE PUEDE EXIGIR MAS: con
    // |v| >= 2 el techo baja a d_menor*s/2, que para un (127,1) da 80 cuando su geometria
    // pide 160 — le robaria longitud al eje mayor para salvarle precision al menor. Un
    // vector muy alargado TIENE el eje menor casi parado; eso no es un defecto que
    // arreglar, es lo que significa alargado.
    //
    // LO QUE ESTO ARREGLA. Con el techo fijo en 160, `t1_vcap` se aplastaba y VCAP se
    // quedaba sin recorrido: a VCAP = 8 pedia 2540 y recibia 160, un knob saturado — que es
    // exactamente lo que se veia en pantalla el 2026-08-17, el espolon casi cerrado sin
    // terminar de irse. Ahora un diagonal largo llega a sus 2540, y en cambio el (127,1) se
    // queda en 160, que es la respuesta CORRECTA para EL y la que una constante global no
    // puede dar: frenarlo mas lo aplanaria contra la horizontal.
    //
    // A VALORES DE FABRICA NO CAMBIA NADA. Con VCAP = 127 ningun vector pasa de t1 = 160
    // (barrido sobre los 65.024 deltas: 0,0% lo rebasan), asi que esto abre rango solo
    // cuando se baja VCAP a proposito.
    let d_menor = match (dx.abs(), dy.abs()) {
        (0, b) => b,                  // sin eje X que perder
        (a, 0) => a,
        (a, b) => a.min(b),
    };
    let techo = (d_menor * s / f)
        .min(T1_TRANSPORT.load(Ordering::Relaxed) as i32)
        .max(min_t1);                 // por si el transporte se deja por debajo del suelo
    /* QUIEN MANDA CUANDO EL TECHO Y EL TOPE SE CONTRADICEN.
     *
     * `techo` protege la pendiente: pasado el, la tasa del eje MENOR redondea a 0 y la
     * diagonal se endereza. `t1_vcap` protege la velocidad. En una diagonal tumbada los dos
     * no caben, y hasta ahora ganaba el techo — con lo que la tasa se salta el tope.
     *
     * MEDIDO en un frame de nuestro Major Havoc: 341 de 754 trazos iluminados (45%) salen
     * por encima de 51, y algunos a 125. A esa velocidad el trazo reparte 2,5 veces menos
     * carga por unidad de longitud que uno a 51, mientras la junta entre microtramos sigue
     * quemando sus 22-24 ciclos QUIETO: linea tenue con un punto brillante en cada extremo,
     * que es el sintoma de "se ven todos los puntos de los microtramos".
     *
     * (Y OJO CON LA COMPARACION FACIL: el VecFever no pasa de 51 en su captura, pero eso NO
     * es un tope suyo — su frame es 85% trazos rectos de texto y su diagonal mas tumbada
     * tiene pendiente 0,48. Nunca se encuentra con este caso. Ver puntos-no-estan-en-la-lista.)
     *
     * Con el tope mandando, el eje menor se pierde en UN microtramo pero NO se pierde: la
     * deuda lo apunta y lo cobra en el siguiente, que es justo para lo que esta. Esa deuda
     * no existia cuando se escribio el techo.
     *
     * TECHO_MANDA = 0 hace ganar al tope. NO es el por defecto: el invariante "ningun eje
     * con delta se queda parado" esta afirmado en `el_techo_de_t1_es_por_vector`, y soltar
     * el techo ya se probo una vez y rompio el dibujo en los DOS cartuchos. Se compara en
     * consola antes de decidir, no aqui. */
    let t1 = if TECHO_MANDA.load(Ordering::Relaxed) != 0 {
        t1_floor.max(t1_vcap).min(techo)
    } else {
        t1_floor.max(t1_vcap).min(techo.max(t1_vcap))
    };
    // COMPENSAR EL ARRANQUE EN VEZ DE FRENAR EL HAZ.
    //
    // OBSERVADO en consola el 2026-08-24 sobre la rejilla: con VCAP alto el dibujo "se va"
    // —se queda corto— pero NO tiembla, o sea que el error es ESTATICO. Con VCAP bajo la
    // geometria sale bien y lo que tiembla es el framerate, porque t1 se dispara.
    //
    // Un error estatico no se arregla frenando: se compensa. Si el amplificador tarda un
    // tiempo FIJO en coger velocidad, el haz recorre v*(t1 - T) en vez de v*t1. Alargar t1
    // en T devuelve la distancia SIN tocar la velocidad, y cuesta T ciclos por vector en
    // vez de multiplicar t1 por 2,5 como hace bajar VCAP.
    //
    // T es un TIEMPO, asi que su peso relativo es mayor en los vectores cortos — que es
    // exactamente la firma de "el dibujo se va" cuando el haz corre rapido.
    //
    // 0 = como siempre. Se ajusta en caliente desde el panel; el valor bueno es el que
    // hace que la rejilla mida lo que dice medir.
    // SE APLICA AL FINAL, NO AQUI — ver el final de la funcion.
    //
    // Estuvo aqui, sumado a `t1` ANTES de calcular `vx`, y eso lo anulaba exactamente: la
    // distancia mandada es `vx*t1/s`, asi que al recalcular `vx` con el `t1` ya alargado el
    // resultado vuelve a ser `dx`. El knob solo hacia la rampa mas lenta y mas larga, sin
    // devolver una sola unidad de distancia. MEDIDO en consola el 2026-08-25: T1_LAG=8 no
    // cambio el dibujo NADA, y por eso se descarto una hipotesis que en realidad no se
    // habia llegado a probar.

    // ELEGIR EL t1 QUE MENOS SE DESVIA, entre el calculado y el siguiente.
    //
    // Redondear `vx` al mas cercano acota el error de UN trazo, pero no lo centra: segun
    // donde caiga s/t1, el redondeo tira casi siempre para el mismo lado y entonces deja de
    // ser ruido y pasa a ser una DEUDA que se suma. MEDIDO con el test `el_error_de_la_
    // rampa_no_tiene_sesgo`: +0,028 unidades por trazo a VCAP=96, o sea 2,4 al cabo de 84.
    //
    // t1 y t1+1 dan dos productos vx*t1 distintos y uno de los dos cae mas cerca. Cuesta
    // una division mas y un ciclo de rampa como mucho, y el error deja de tener direccion
    // preferida — que es lo unico que hace que se acumule.
    let error_de = |t: i32| -> i64 {
        if t <= 0 { return i64::MAX; }
        let v = {
            let den = (t as i64) * 256 + T1_EXTRA_Q8.load(Ordering::Relaxed) as i64;
            let n = (m as i64) * (s as i64) * 256 / (f as i64);
            let q = if n >= 0 { (n + den / 2) / den } else { (n - den / 2) / den };
            q.clamp(-128, 127)
        };
        ((v * t as i64) - (m as i64) * (s as i64) / (f as i64)).abs()
    };
    let t1 = if t1 < techo && error_de(t1 + 1) < error_de(t1) { t1 + 1 } else { t1 };
    // ROUND, DO NOT TRUNCATE. Distance is velocity x time, so `vx * t1` has to stay
    // proportional to `dx * s` — but integer division always rounds DOWN, and the loss
    // is the fractional part of `s / t1`, which lands wherever it lands:
    //
    //   t1 =  8 -> 127/8  = 15.875 -> 15  ->  94.5% of the length   (glyphs stepped)
    //   t1 = 24 -> 127/24 =  5.29  ->  5  ->  94.5%
    //   t1 = 31 -> 127/31 =  4.096 ->  4  ->  97.6%                 (glyphs clean)
    //
    // MEASURED on hardware 2026-08-05: the user found letters stepped at MIN_T1 = 8 and
    // straight at 31, which is this table and nothing else — the error is not monotonic
    // in the floor, so no choice of floor fixes it. Rounding to nearest halves the worst
    // case and, more importantly, removes the dependence on where s/t1 happens to fall.
    // Symmetric around zero so a stroke and its mirror get the same length.
    // El divisor es la duracion REAL de la rampa, no `t1`. Ver T1_EXTRA_Q8: el 6522
    // cuenta t1 + 1,5 en un disparo, y dividir por `t1` a secas recorre de mas.
    // Con T1_EXTRA_Q8 = 0 esto es exactamente la aritmetica de antes.
    let den = (t1 as i64) * 256 + T1_EXTRA_Q8.load(Ordering::Relaxed) as i64;
    let round_div = |num: i32| -> i32 {
        let n = num as i64 * 256;
        (if n >= 0 { (n + den / 2) / den } else { (n - den / 2) / den }) as i32
    };
    let vx = round_div(dx * s / f).clamp(-128, 127) as i8;
    let vy = round_div(dy * s / f).clamp(-128, 127) as i8;
    // Y AHORA SI, EL RETARDO DE ARRANQUE. Con `vx` ya elegido, alargar la rampa en T hace
    // que el haz recorra `vx*(t1+T)/s` — mas de lo pedido, que es justo la distancia que
    // pierde mientras coge velocidad. Es un TIEMPO, asi que pesa mas en los trazos cortos:
    // la firma de "el dibujo se va" cuando el haz corre rapido.
    let t1 = t1 + if arranque { T1_LAG_ARRANQUE.load(Ordering::Relaxed) }
                  else        { T1_LAG.load(Ordering::Relaxed) } as i32;
    (vx, vy, t1 as u16)
}

/// Cuentas que se le suman a t1 para compensar lo que el amplificador tarda en coger
/// velocidad. Ver el bloque en `ramp_params`. 0 = comportamiento de siempre.
#[used]
#[no_mangle]
pub static T1_LAG: AtomicU32 = AtomicU32::new(0);

/// 0 = no se sabe que hay en el S&H. Si no, 0x100 | vy.
#[used]
#[no_mangle]
pub static Y_HELD: AtomicU32 = AtomicU32::new(0);

/// Cuentas EXTRA que T1 corre de mas, en Q8 (256 = 1 cuenta). **0 = comportamiento
/// actual**, 384 = 1,5 cuentas, que es lo que el 6522 hace en un disparo.
///
/// EL 6522 CUENTA t1 + 1,5, NO t1. Y `ramp_params` programa la velocidad suponiendo que
/// la rampa dura `t1`, asi que cada vector se recorre un 1,5/t1 DE MAS. Con t1 = 31, que
/// es el suelo de MIN_T1 y donde cae la mayoria, eso es un 4,8% por vector — y no es
/// ruido aleatorio sino un sesgo SIEMPRE en el sentido de la marcha, asi que se acumula
/// LINEALMENTE con el numero de movimientos.
///
/// Eso es exactamente lo que describe el comentario de VPY_MAX_CONSECUTIVE_DRAWS en el
/// SDK: "the position error is FIXED PER MOVEMENT ... so it accumulates by COUNT". La
/// descripcion era correcta; la atribucion ("the deflection lag at the end of each blanked
/// move") no. Medido 2026-08-07: con MOVETO_SETTLE_ECYC = 8, que son ~900 ciclos y SEIS
/// VECES el retraso de deflexion real (125-150 ciclos, medido por biseccion ese mismo
/// dia), DKNZ4 seguia temblando igual.
///
/// Si esta es la causa, corregirla deja el error acotado en vez de creciente, y entonces
/// VPY_MAX_CONSECUTIVE_DRAWS puede subir de 1 — que son 3 de cada 4 zero_beam menos, el
/// 23% del trafico del bus y ~5% del frame.
///
/// OJO CON DRAW_SCALE. Vale 0xA0 = 160 y es empirico: si se ajusto para que las figuras
/// salieran del tamano correcto, ya esta absorbiendo el sesgo MEDIO. Corregirlo aqui hara
/// que todo salga un poco mas pequeno de forma uniforme, y puede que haya que subir
/// DRAW_SCALE para compensar. Lo que NO puede absorber DRAW_SCALE es que el sesgo dependa
/// de t1: hoy los vectores cortos salen proporcionalmente mas largos que los largos.
#[used]
#[no_mangle]
/* LA COLA DE LA RAMPA, MEDIDA: 2,5 ciclos de E = 640 en Q8. En consola (2026-09-15, banco
 * hardware/uvm2/rampas en modo ojo, filas de control al 1%) cada rampa recorre
 * v * (t1 + 2,5): la rampa sigue ~2,5 ciclos despues de expirar T1. Con 0 aqui, un trozo
 * de t1=8 salia un 31% largo y una viga de t1~90 un 2,7%, y por eso los peldanos (cortos)
 * se salian del larguero (largo). Este es el numero; la calibracion de consola lo llama
 * TEXTO / fijo_q8 y lo puede afinar por tubo. [[la-rampa-sigue-2-5-ciclos]] */
pub static T1_EXTRA_Q8: AtomicU32 = AtomicU32::new(640);

/// Encender el haz por el REGISTRO DE DESPLAZAMIENTO ($FF/$00), como la BIOS y como el asm
/// de 6809 que dibuja bien, en vez de por PCR ($EE/$CE). Exige ACR = 0x98 en el arranque,
/// que lo pone `via_setup` mirando esta misma perilla. 0 = por PCR, como hasta ahora.
///
/// El comentario de `draw_line_seq` dice que el camino del SR "no llego a dibujar nada en
/// este hardware" — pero eso se probo con el resto del emisor como estaba, y desde entonces
/// han cambiado cosas. Se vuelve a probar porque es UNA de las cuatro diferencias medidas
/// contra una implementacion que si funciona.
#[used]
#[no_mangle]
pub static HAZ_POR_SR: AtomicU32 = AtomicU32::new(1);
/* ^ EL IDIOMA DE HAZ DEL VECFEVER, POR DEFECTO DESDE 2026-09-04.
 *
 * Estaba a 0, y encenderlo era cosa de que CADA juego pusiera `-DUVM2_HAZ_POR_SR` en su
 * lista de defines. Resultado medido: de los objetivos de build_uvm2.sh, `dkong`,
 * `asteroids` y `snowbros_c` NO lo pedian — y son exactamente los que Daniel reporta "sin
 * brillo" en consola, mientras mhavoc y asterock, que si lo piden, se ven.
 *
 * Un puerto que no listaba el define corria con blanking por PCR, MIN_T1 = 31 y VCAP = 127:
 * un camino DISTINTO al que llevamos toda la sesion midiendo contra su captura. El
 * conocimiento no puede vivir en 44 listas de defines; vive aqui, y quien necesite lo
 * anterior lo apaga con `-DUVM2_HAZ_POR_PCR`. */

/// No reescribir T1CL si no ha cambiado, como hace el 6809 (lo carga una vez y luego solo
/// dispara con `CLR T1CH`). Ahorra una escritura de bus por vector.
#[used]
#[no_mangle]
pub static T1CL_CACHE: AtomicU32 = AtomicU32::new(1);  // por defecto SI: el 6809 carga T1CL una vez

/// Poner el DAC a cero al acabar cada rampa, como hace el 6809 (`CLR VIA_port_a`).
/// 0 = como hasta ahora (se queda `vx` puesto todo el hueco). Ver el bloque en emit.rs.
#[used]
#[no_mangle]
pub static DAC_CERO: AtomicU32 = AtomicU32::new(1);   // por defecto SI: la referencia lo hace

/// Duracion FIJA de la rampa, como la BIOS ($7F) y Ralf (128). 0 = modelo de tiempo
/// variable, el de siempre. Ver el bloque en `ramp_params` para el porque.
#[used]
#[no_mangle]
pub static RAMPA_FIJA: AtomicU32 = AtomicU32::new(0);

/// La misma funcion para quien llama desde C (la imagen del UVM2). Punteros porque una
/// tupla de Rust no tiene representacion C — y ENTEROS, que es la regla de la caja: la
/// imagen se compila `softfp` y el firmware `eabihf`, asi que ni un flotante cruza.
#[no_mangle]
pub extern "C" fn vx_ramp_params(dx: i32, dy: i32, out_vx: *mut i32, out_vy: *mut i32,
                                 out_t1: *mut u32) {
    let (vx, vy, t1) = ramp_params(dx.clamp(-128, 127) as i8, dy.clamp(-128, 127) as i8);
    unsafe {
        if !out_vx.is_null() { *out_vx = vx as i32; }
        if !out_vy.is_null() { *out_vy = vy as i32; }
        if !out_t1.is_null() { *out_t1 = t1 as u32; }
    }
}

/// `vx_ramp_params` CON SUB-UNIDADES: `dx`/`dy` en 1/16 de unidad de dispositivo.
///
/// Existe porque la rejilla entera es diez veces mas basta que la del VecFever y eso es lo
/// que deforma los glifos — ver el bloque de `ramp_params_q`. El puente ya tomaba `i32`, asi
/// que lo unico que cambiaba era que aqui se recortaba a `i8` y se perdia la fraccion.
///
/// Q4 y no mas: con 1/16 el paso de posicion es 160/16 = 10 cuentas de tasa a t1=8, o sea
/// mas fino que las ~20 con las que el VecFever coloca sus puntos. Mas bits no compran nada
/// que el DAC pueda expresar.
#[no_mangle]
pub extern "C" fn vx_ramp_params_q4(dx_q4: i32, dy_q4: i32, out_vx: *mut i32,
                                    out_vy: *mut i32, out_t1: *mut u32) {
    let v = TOPE_DAC;
    let (vx, vy, t1) = ramp_params_salto_con_deuda(dx_q4, dy_q4, v, 4);
    unsafe {
        if !out_vx.is_null() { *out_vx = vx as i32; }
        if !out_vy.is_null() { *out_vy = vy as i32; }
        if !out_t1.is_null() { *out_t1 = t1 as u32; }
    }
}

/// La gemela para los SALTOS, con su propio tope de velocidad.
/// EL SALTO ABSORBE LA DEUDA ENTERA, que es donde corregir no se ve.
///
/// La deuda es `pedido - recorrido` acumulado sobre TODO — trazos y saltos. El trazo solo
/// la apunta; el salto pide `d + deuda` y con eso la posicion vuelve a cuadrar, porque el
/// haz va apagado y ese trozo de mas nadie lo ve.
///
/// LO QUE ESTO ARREGLA, medido integrando nuestro stream contra la geometria de entrada:
/// la posicion al empezar cada trazo se iba +8,45 unidades de mediana en X y crecia a lo
/// largo del frame (+2,64 -> +13,29 por tercios). La del VecFever es +0,00.
///
/// Y POR QUE NO ESTABA: el intento anterior encadeno tambien los saltos REPARTIENDO la
/// deuda, y salio peor — lo que el salto no absorbia lo pagaba el siguiente trazo
/// iluminado, que se doblaba. La diferencia es absorber entero, no repartir. El comentario
/// de `move_una` en el SDK ya lo pedia asi y no estaba hecho.
fn ramp_params_salto_con_deuda(dx_q4: i32, dy_q4: i32, vcap: u32, q: u32) -> (i8, i8, u16) {
    let (rx, ry) = (DEUDA_X.load(Ordering::Relaxed), DEUDA_Y.load(Ordering::Relaxed));
    let f = 1i32 << q;
    let a_q4 = |r: i32| if r >= 0 { (r * f + 500) / 1000 } else { (r * f - 500) / 1000 };
    /* UN EJE QUE NO SE PIDE NO SE MUEVE — TAMPOCO EN EL SALTO. La guarda estaba solo en el
     * trazo, y aqui faltaba: un salto con dx = 0 salia con vx = 1 porque la deuda se colaba
     * como movimiento. MEDIDO en los comandos crudos del frame — el salto entre el segmento
     * 0 y el 1 tiene dx = 0 y emite ORA=0x01, o sea 1*8/160 = 0,05 unidades de deriva. Por
     * 187 saltos son 9,3 unidades, del orden de la deriva que se estaba persiguiendo.
     *
     * La deuda de ese eje NO se pierde: se queda para el proximo salto que si lo mueva. */
    let px = if dx_q4 == 0 { 0 } else { dx_q4 + a_q4(rx) };
    let py = if dy_q4 == 0 { 0 } else { dy_q4 + a_q4(ry) };
    let (vx, vy, t1) = ramp_params_q(px, py, vcap, q);
    /* La deuda queda con lo que el salto NO ha llegado a absorber: pedido (con la
     * correccion dentro) menos recorrido. Si el salto la absorbe entera, queda en cero. */
    if dx_q4 != 0 {
        DEUDA_X.store((rx + dx_q4 * 1000 / f - recorrido_mil(vx as i32, t1)).clamp(-4000, 4000),
                      Ordering::Relaxed);
    }
    if dy_q4 != 0 {
        DEUDA_Y.store((ry + dy_q4 * 1000 / f - recorrido_mil(vy as i32, t1)).clamp(-4000, 4000),
                      Ordering::Relaxed);
    }
    (vx, vy, t1)
}

/// LAS TASAS PARA UN t1 DADO, sin elegirlo.
///
/// Hace falta porque el VecFever no calcula la duracion del salto: la ELIGE de una escalera
/// corta. Medido en sus 1041 saltos que siguen a un trazo, la escalera {8, 18, 31} con tope
/// de tasa 120 explica 1008 (97%) — y en su frame 120 los explica TODOS. Nuestro modelo
/// derivaba t1 del tope de velocidad y daba valores continuos (9, 13, 15) donde el pone 18.
#[no_mangle]
pub extern "C" fn vx_ramp_params_con_t1(dx: i32, dy: i32, f: i32, t1: u32,
                                        out_vx: *mut i32, out_vy: *mut i32) {
    /* TOMA EL DIVISOR YA HECHO, no los bits. Con `q` y `1 << q` la placa devolvia
     * `f = 0` donde el host da 256 — un desplazamiento en tiempo de ejecucion, que es la
     * misma familia que el RRX que costo media sesion. Aqui no hace falta: el llamante tiene
     * `UVM2_Q` como constante de compilacion. */
    let f = if f > 0 { f } else { 1 };
    let s = escala();
    /* TODO EN 32 BITS, A PROPOSITO. La version con i64 daba en la placa `vy = 127` para
     * `dy = 0` —aritmeticamente imposible— mientras el host daba el valor correcto. La unica
     * operacion de 64 bits era `t1 * 256`, o sea un desplazamiento de 64 bits: la misma
     * familia que el RRX que costo media sesion. Y no hace falta ninguno: con t1 <= 255 el
     * divisor no pasa de 65.280, y el numerador de 5,2 millones. Ver emulador-sin-rrx. */
    let den = (t1 as i32) * 256 + T1_EXTRA_Q8.load(Ordering::Relaxed) as i32;
    let den = if den > 0 { den } else { 1 };
    let r = |p: i32| -> i32 {
        let n = (p / f) * s * 256 + ((p % f) * s * 256) / f;
        let v = if n >= 0 { (n + den / 2) / den } else { (n - den / 2) / den };
        v.clamp(-128, 127)
    };
    unsafe {
        if !out_vx.is_null() { *out_vx = r(dx); }
        if !out_vy.is_null() { *out_vy = r(dy); }
    }
}

#[no_mangle]
pub extern "C" fn vx_ramp_params_salto_qn(dx: i32, dy: i32, q: u32, out_vx: *mut i32,
                                          out_vy: *mut i32, out_t1: *mut u32) {
    let v = TOPE_DAC;
    let (vx, vy, t1) = ramp_params_q(dx, dy, v, q);
    unsafe {
        if !out_vx.is_null() { *out_vx = vx as i32; }
        if !out_vy.is_null() { *out_vy = vy as i32; }
        if !out_t1.is_null() { *out_t1 = t1 as u32; }
    }
}

#[no_mangle]
pub extern "C" fn vx_ramp_params_salto_q4(dx_q4: i32, dy_q4: i32, out_vx: *mut i32,
                                          out_vy: *mut i32, out_t1: *mut u32) {
    let v = TOPE_DAC;
    let (vx, vy, t1) = ramp_params_q(dx_q4, dy_q4, v, 4);
    unsafe {
        if !out_vx.is_null() { *out_vx = vx as i32; }
        if !out_vy.is_null() { *out_vy = vy as i32; }
        if !out_t1.is_null() { *out_t1 = t1 as u32; }
    }
}


/* ── LA CADENA, CON SU DEUDA ────────────────────────────────────────────────────────
 *
 * UNA sola implementacion para los tres consumidores. El 2026-08-24 habia tres decisiones
 * distintas sobre lo mismo: la imagen del UVM2 difundia el residuo, el emulador tambien
 * (por su cuenta) y el firmware del cartucho propio no lo hacia. Tres copias de una regla
 * es la forma exacta de divergencia que costo la tarde entera.
 *
 * POR QUE HACE FALTA. `ramp_params` reparte un delta entre velocidad y tiempo, los dos
 * ENTEROS, asi que un trazo suelto NO puede ser exacto. Su error vale como mucho media
 * unidad y eso es inevitable. Lo evitable es que se SUME: llevando la cuenta de lo que se
 * debe y pidiendoselo al trazo siguiente, la cadena queda exacta y no cuesta un ciclo.
 *
 * MEDIDO por el camino real, 84 trazos de 33 unidades: +6,30 unidades de deriva (2,5% de
 * pantalla) sin esto, +0,04 con esto.
 *
 * LA DEUDA MUERE EN CADA SALTO. Un `moveto` reestablece la posicion por su cuenta, asi que
 * arrastrarle el residuo de la cadena anterior seria corregir un error que ya no existe —
 * el mismo fallo que el acumulador de deriva que sobrevivia a un re-cero. */

/// Lo que se le debe al dibujo, en MILESIMAS de unidad, por eje.
#[used]
#[no_mangle]
pub static DEUDA_X: AtomicI32 = AtomicI32::new(0);
#[used]
#[no_mangle]
pub static DEUDA_Y: AtomicI32 = AtomicI32::new(0);

/// Se olvida la deuda. Lo llama quien reposicione el haz: un salto o un re-cero.
#[no_mangle]
pub extern "C" fn vx_chain_reset() {
    /* LA DEUDA YA NO SE TIRA AQUI, Y ERA EL FALLO.
     *
     * Esto ponia DEUDA_X/Y a cero, y lo llama `move_una` en CADA salto. Con un `move_abs`
     * por segmento —que es lo que hace cualquier dibujante que no encadene— la deuda se
     * borraba entre vector y vector y NUNCA acumulaba: se calculaba al final de cada trazo
     * y el salto siguiente la tiraba antes de que nadie la corrigiera.
     *
     * El sintoma, medido integrando nuestro stream contra la geometria de entrada: la
     * posicion al empezar cada trazo se iba +8,45 unidades de mediana en X, creciendo de
     * +2,64 en el primer tercio del frame a +13,29 en el ultimo. La del VecFever es +0,00
     * con un peor caso de 0,03 en los 427 trazos del frame.
     *
     * Y explica por que tres arreglos seguidos de la contabilidad de la deuda no movieron
     * la salida NI UN BYTE: no habia deuda que corregir.
     *
     * La deuda es "donde esta el haz de verdad menos donde creemos que esta". Un salto no
     * arregla eso — es justo el sitio donde corregirlo sin que se vea, porque va a
     * oscuras. Lo absorbe `ramp_params_salto_con_deuda`.
     *
     * Lo que si se reinicia es el ARRANQUE: el haz se reposiciona, asi que la proxima
     * rampa parte del reposo. Eso no tiene nada que ver con la deuda y son dos cosas que
     * estaban juntas por costumbre.
     *
     * PROBADO Y REVERTIDO (2026-09-04): conservar la deuda entre saltos + que el salto la
     * absorbiera entera dejo la **Y practicamente perfecta** (+0,01 de mediana contra el
     * +0,00 del VecFever, viniendo de -0,52) y **disparo la X a +705** — la correccion en X
     * entra en realimentacion positiva. La asimetria no esta explicada: el codigo trata los
     * dos ejes igual, pero 145 de los 427 segmentos del frame tienen dx=0 y casi ninguno
     * dy=0, asi que la X pasa por el camino de "eje que no se pide" muchas mas veces.
     * Sospechoso principal: el tope de +-4000 milesimas esta pensado para la rejilla
     * ENTERA (4 unidades), y en 1/16 son 64 cuantos — una correccion enorme para un delta
     * pequeño. Ahi es por donde hay que seguir. */
    ARRANQUE.store(1, Ordering::Relaxed);
}

/// Tirar la deuda de verdad. La usa el RE-CERO, que si devuelve el haz a un punto conocido:
/// ahi lo que creiamos y lo que hay vuelven a coincidir y no queda nada que deber.
#[no_mangle]
pub extern "C" fn vx_deuda_reset() {
    DEUDA_X.store(0, Ordering::Relaxed);
    DEUDA_Y.store(0, Ordering::Relaxed);
}

/// Lo que la rampa recorre DE VERDAD, en milesimas: v * t1 / DRAW_SCALE con su fraccion.
#[inline(always)]
fn recorrido_mil(v: i32, t1: u16) -> i32 {
    /* CON LA COLA. La tasa se calcula para (t1 + T1_EXTRA_Q8/256) y el recorrido REAL es
     * ese: contabilizar aqui v*t1 a secas hacia que la deuda viera cada trazo un 24% corto
     * (t1=8) y se lo cargara al siguiente — con T1_EXTRA_Q8=640 en consola "todo se veia
     * muchisimo peor" (Daniel, 2026-09-15). La cola es fisica, no una decision del emisor:
     * el haz recorre v*(t1+2,5) pida lo que pida la tasa. [[la-rampa-sigue-2-5-ciclos]] */
    let t_q8 = t1 as i64 * 256 + T1_EXTRA_Q8.load(Ordering::Relaxed) as i64;
    ((v as i64 * t_q8 * 1000) / (escala() as i64 * 256)) as i32
}

/// `ramp_params` para un trazo DENTRO DE UNA CADENA: pide el delta mas lo que se debia y
/// anota lo que queda debiendo.
pub fn ramp_params_chain(dx: i8, dy: i8) -> (i8, i8, u16) {
    let (rx, ry) = (DEUDA_X.load(Ordering::Relaxed), DEUDA_Y.load(Ordering::Relaxed));
    /* Al mas cercano, no truncando: truncar reintroduce el sesgo que esto viene a quitar. */
    let redondea = |r: i32| if r >= 0 { (r + 500) / 1000 } else { (r - 500) / 1000 };
    let px = (dx as i32 + redondea(rx)).clamp(-128, 127) as i8;
    let py = (dy as i32 + redondea(ry)).clamp(-128, 127) as i8;

    let (vx, vy, t1) = ramp_params(px, py);
    /* Consumida AQUI y no en el salto: el salto y el trazo que lo sigue arrancan los dos
     * parados, asi que los dos tienen que cobrar el suelo de arranque. */
    ARRANQUE.store(0, Ordering::Relaxed);

    /* Acotada: si un trazo se recorta, la deuda no puede crecer sin freno o el siguiente
     * saldria disparado. Cuatro unidades es mucho mas de lo que un redondeo puede deber. */
    DEUDA_X.store((rx + dx as i32 * 1000 - recorrido_mil(vx as i32, t1)).clamp(-4000, 4000),
                  Ordering::Relaxed);
    DEUDA_Y.store((ry + dy as i32 * 1000 - recorrido_mil(vy as i32, t1)).clamp(-4000, 4000),
                  Ordering::Relaxed);
    (vx, vy, t1)
}

/// `ramp_params_chain` CON SUB-UNIDADES: `dx`/`dy` en 1/16 de unidad.
///
/// LAS DOS COSAS SON COMPLEMENTARIAS Y CONVIENE NO CONFUNDIRLAS. La deuda de la cadena
/// corrige el residuo que comete LA RAMPA al redondear `v` — pero recibia `i8`, asi que no
/// podia corregir lo que la API ya habia tirado antes: `VS_RND` divide las coordenadas del
/// juego por 127 y redondea a entero ANTES de que la cadena vea nada. MEDIDO en mhavoc:
/// 0,22 unidades de error por eje ahi, con el 3,6% de los vectores enteramente sub-unidad.
///
/// La deuda se sigue guardando en MILESIMAS DE UNIDAD, sin cambiar su semantica ni sus
/// topes: solo se convierte a 1/16 al entrar y desde 1/16 al salir.
pub fn ramp_params_chain_q4(dx_q4: i32, dy_q4: i32) -> (i8, i8, u16) {
    ramp_params_chain_qn(dx_q4, dy_q4, 4)
}

/* LA PRECISION DE LA ENTRADA ES UN PARAMETRO, y no un detalle del banco.
 *
 * MEDIDO contra los 210 vectores de un frame suyo de Major Havoc: con la geometria en 1/16
 * de unidad, 22 de sus tasas (10,5%) NO se pueden reproducir — no por como redondeamos,
 * sino porque a esa rejilla no cabe lo que el pide. Su vector de tasa 32 con t1 = 8 mide
 * 32*8/160 = 1,6 unidades exactas, y 1/16 solo sabe decir 1,5625 o 1,625. Con 1/64 o mas
 * fino salen las 210 EXACTAS.
 *
 * `dx * s / f` TRUNCA antes de que `round_div` redondee, y esa es la unica division que
 * pierde: por eso subir la precision de la entrada arregla el 10,5% entero. */
pub fn ramp_params_chain_qn(dx_q4: i32, dy_q4: i32, q: u32) -> (i8, i8, u16) {
    let (rx, ry) = (DEUDA_X.load(Ordering::Relaxed), DEUDA_Y.load(Ordering::Relaxed));
    let f = 1i32 << q;
    /* Al mas cercano, no truncando: truncar reintroduce el sesgo que esto viene a quitar. */
    let a_q4 = |r: i32| if r >= 0 { (r * f + 500) / 1000 } else { (r * f - 500) / 1000 };
    /* UN EJE QUE NO SE PIDE NO SE MUEVE, NI POR LA DEUDA.
     *
     * La deuda existe para corregir el residuo del redondeo, pero sumandola a ciegas mete
     * movimiento en un eje cuyo delta es CERO — y eso no es corregir, es inventar. MEDIDO
     * con la geometria del VecFever de entrada: de sus 189 vectores verticales puros, los
     * 189 salen con vx = 0 en su stream y NINGUNO en el nuestro (vx en {-2, 1, 2}), con
     * suma +81, o sea +4 unidades de deriva a la derecha por frame que se acumulan hasta
     * el siguiente re-cero. Es la deriva diagonal vista en consola.
     *
     * `un_vertical_no_mueve_la_x` ya cubria esto para `ramp_params`, pero no para la
     * version con cadena, que es la que usan los trazos.
     *
     * La deuda NO se pierde: se queda para el proximo vector que si mueva ese eje. */
    let usa = DEUDA_ON.load(Ordering::Relaxed) != 0;
    let px = if dx_q4 == 0 || !usa { dx_q4 } else { dx_q4 + a_q4(rx) };
    let py = if dy_q4 == 0 || !usa { dy_q4 } else { dy_q4 + a_q4(ry) };

    let (vx, vy, t1) = ramp_params_q(px, py, TOPE_DAC, q);
    /* EL REDONDEO A MICROTRAMOS, AQUI Y NO EN EL EMISOR — SI NO, LA DEUDA NO LO VE.
     *
     * `draw_line_seq` parte el trazo en n microtramos de 8 cuentas y reescala la tasa para
     * el tiempo que de verdad va a correr. Esa reescala REDONDEA, y su residuo quedaba
     * fuera de la contabilidad: la deuda se calculaba con el (vx, t1) de antes, veia
     * `pedido - recorrido = 0` y no corregia nada.
     *
     * MEDIDO integrando nuestro stream contra la geometria de entrada: la posicion al
     * empezar cada trazo se iba +8,45 unidades de mediana en X, creciendo de +2,64 en el
     * primer tercio del frame a +13,29 en el ultimo, con la deuda constantemente a cero.
     * La del VecFever es +0,00 con un peor caso de 0,03 en los 427 trazos.
     *
     * Devolviendo ya el t1 redondeado y la tasa calculada PARA EL, la deuda mide lo que se
     * emite y el emisor no tiene nada que reescalar.
     *
     * EL 8 ES EL MISMO QUE `T1M` en emit.rs. Si uno cambia, cambia el otro: son la misma
     * decision (el microtramo del idioma del VecFever) escrita en dos sitios. */
    const MICRO: i32 = 8;
    let n = core::cmp::max(1, (t1 as i32 + MICRO / 2) / MICRO);
    let corridos = n * MICRO;
    /* AQUI SE REDONDEA DOS VECES, Y SE SABE. `ramp_params_q` calculo la tasa para SU t1 y
     * esto la reescala al t1 que de verdad corre. MEDIDO en el unico trazo que quedaba
     * distinto del VecFever en su frame 120: pide 1,3477 unidades; el emite 27
     * (1,3477*160/8 = 26,95); a nosotros nos sale 22 para t1 = 10 y al reescalar a 8 da
     * 22*10/8 = 27,5 -> 28.
     *
     * INTENTO FALLIDO (2026-09-04): calcularla directa para `corridos`, con el mismo
     * divisor que `ramp_params_q`. En el HOST da exactamente su 27; en el CARTUCHO satura a
     * 127 casi todos los trazos y el parecido cae del 99,8% al 2,1%. El test
     * `tasa_directa::el_trazo_391` deja la version del host, que es correcta — la causa de
     * la divergencia entre las dos maquinas NO esta encontrada, y hasta que lo este esto se
     * queda como estaba. No es un knob: es una trampa a la que ya se cayo. */
    /* LA TASA, CALCULADA UNA VEZ PARA EL t1 QUE DE VERDAD CORRE — Y EN 32 BITS.
     *
     * Reescalar la tasa que `ramp_params_q` calculo para OTRO t1 redondea dos veces. En su
     * frame 120 quedaba un trazo distinto por eso: pide 1,3477 unidades, el emite 27
     * (1,3477*160/8 = 26,95) y a nosotros nos salia 22 para t1 = 10 que al reescalar a 8
     * daba 27,5 -> 28.
     *
     * ESTE MISMO CAMBIO SE INTENTO POR LA MAÑANA Y SATURABA EN LA PLACA dando 127 en casi
     * todos los trazos, con el host correcto. La causa era la aritmetica de 64 bits, no la
     * formula: reescrita en 32 bits, la placa coincide con el host. Ver emulador-sin-rrx —
     * el RRX arreglado no era el unico camino de 64 bits roto. */
    let sc = escala();
    let den32 = corridos * 256 + T1_EXTRA_Q8.load(Ordering::Relaxed) as i32;
    let den32 = if den32 > 0 { den32 } else { 1 };
    let fq = 1i32 << q;
    let directo = |p: i32| -> i8 {
        let n = (p / fq) * sc * 256 + ((p % fq) * sc * 256) / fq;
        let v = if n >= 0 { (n + den32 / 2) / den32 } else { (n - den32 / 2) / den32 };
        v.clamp(-128, 127) as i8
    };
    let (vx, vy, t1) = (directo(px), directo(py), corridos as u16);
    ARRANQUE.store(0, Ordering::Relaxed);

    /* Y la deuda solo se toca en el eje que se ha movido: si no se pidio nada, no hay
     * residuo nuevo que apuntar, y el que ya habia sigue esperando su turno. */
    if dx_q4 != 0 {
        DEUDA_X.store((rx + dx_q4 * 1000 / f - recorrido_mil(vx as i32, t1)).clamp(-4000, 4000),
                      Ordering::Relaxed);
    }
    if dy_q4 != 0 {
        DEUDA_Y.store((ry + dy_q4 * 1000 / f - recorrido_mil(vy as i32, t1)).clamp(-4000, 4000),
                      Ordering::Relaxed);
    }
    (vx, vy, t1)
}

#[no_mangle]
pub extern "C" fn vx_ramp_params_chain_qn(dx: i32, dy: i32, q: u32, out_vx: *mut i32,
                                          out_vy: *mut i32, out_t1: *mut u32) {
    let (vx, vy, t1) = ramp_params_chain_qn(dx, dy, q);
    unsafe {
        if !out_vx.is_null() { *out_vx = vx as i32; }
        if !out_vy.is_null() { *out_vy = vy as i32; }
        if !out_t1.is_null() { *out_t1 = t1 as u32; }
    }
}

#[no_mangle]
pub extern "C" fn vx_ramp_params_chain_q4(dx_q4: i32, dy_q4: i32, out_vx: *mut i32,
                                          out_vy: *mut i32, out_t1: *mut u32) {
    let (vx, vy, t1) = ramp_params_chain_q4(dx_q4, dy_q4);
    unsafe {
        if !out_vx.is_null() { *out_vx = vx as i32; }
        if !out_vy.is_null() { *out_vy = vy as i32; }
        if !out_t1.is_null() { *out_t1 = t1 as u32; }
    }
}

/* ── LA DEUDA DE LOS SALTOS: PROBADA Y DESCARTADA (2026-09-03) ──────────────────────
 *
 * Aqui vivio `ramp_params_salto`, con su propio par de acumuladores para que el residuo
 * de un salto se lo cobrara a OTRO salto —donde el haz va apagado y corregir no se ve—
 * en vez de contaminar el siguiente trazo iluminado, que es lo que la nota de `move_una`
 * pedia y por lo que el intento anterior (meterlos en la misma cadena) habia fallado.
 *
 * MEDIDO sobre los 255 saltos reales de un frame de asterock: el error acumulado SUBE de
 * 86,8 a 99,8 unidades en X y de 91,6 a 100,6 en Y. Empeora. Se retira en vez de dejarla
 * sin llamar: una funcion que compila y no usa nadie es la trampa que este fichero ya
 * pago con `set_ramp` y con `fixup`.
 *
 * Y UNA ADVERTENCIA SOBRE COMO SE MIDIO ESO. La cifra viene de una copia del modelo en
 * Python, y en la misma sesion escribi TRES medidas del sesgo de la rampa y las TRES
 * salieron artefacto: una clampaba a -127 en vez de -128, otra no simulaba `error_de`
 * ni T1_EXTRA_Q8, y la tercera —un arnes que llamaba a la funcion de verdad dentro de la
 * CPU emulada— devolvia 0,0,0 para toda entrada, asi que estaba midiendo el propio delta.
 * Antes de volver a tocar esto: el arnes bueno es el que ya vive en `correr_uvm2.mjs`
 * (imprime "vx_ramp_params EN LA CPU EMULADA" con casos cuyo resultado se conoce del
 * host), y lo primero que hay que comprobar es que NO devuelve ceros. */

/// El salto, desde C. Lo llama quien reposicione el haz (moveto).
#[no_mangle]
pub extern "C" fn vx_ramp_params_salto(dx: i32, dy: i32, out_vx: *mut i32, out_vy: *mut i32,
                                       out_t1: *mut u32) {
    let (vx, vy, t1) = ramp_params_salto(dx.clamp(-128, 127) as i8, dy.clamp(-128, 127) as i8);
    unsafe {
        if !out_vx.is_null() { *out_vx = vx as i32; }
        if !out_vy.is_null() { *out_vy = vy as i32; }
        if !out_t1.is_null() { *out_t1 = t1 as u32; }
    }
}

/// La misma, para quien llama desde C. Ver `vx_ramp_params`.
#[no_mangle]
pub extern "C" fn vx_ramp_params_chain(dx: i32, dy: i32, out_vx: *mut i32, out_vy: *mut i32,
                                       out_t1: *mut u32) {
    let (vx, vy, t1) = ramp_params_chain(dx.clamp(-128, 127) as i8, dy.clamp(-128, 127) as i8);
    unsafe {
        if !out_vx.is_null() { *out_vx = vx as i32; }
        if !out_vy.is_null() { *out_vy = vy as i32; }
        if !out_t1.is_null() { *out_t1 = t1 as u32; }
    }
}

#[cfg(test)]
mod sesgo_vertical {
    use super::*;
    /// UN VECTOR VERTICAL NO PUEDE MOVER LA X. La sonda de la CPU emulada devolvia
    /// `(0,50) -> vx=1`, y en la lista real de asterock TODOS los trazos verticales
    /// salian con vx=1 (351 de ellos con `vx=1 vy=24`): 0,39 unidades de desplazamiento
    /// por trazo, siempre al mismo lado, que es la deriva horizontal vista en consola.
    /// Este test dice si el sesgo esta en el MODELO o en el emulador.
    /// Imprime lo que da el HOST para los mismos casos que la sonda de la CPU emulada,
    /// para poder poner los dos lados uno al lado del otro. `cargo test -- --nocapture`.
    #[test]
    fn imprime_los_casos_de_la_sonda() {
        /* EL TURNO, como los demas tests de este fichero: estos knobs son ESTADO
         * GLOBAL y sin serializar se pisan entre tests (rompi
         * `el_techo_de_t1_es_por_vector` al añadirlos sin el lock). */
        let _t = crate::emit::TURNO.lock().unwrap_or_else(|e| e.into_inner());
        MIN_T1.store(8, Ordering::Relaxed);
        MIN_T1_ARRANQUE.store(8, Ordering::Relaxed);
        DRAW_SCALE.store(160, Ordering::Relaxed);
        T1_TRANSPORT.store(160, Ordering::Relaxed);
        /* IGUALADO AL CARTUCHO. Sin esto el test corre con los DEFECTOS de la caja y el
         * cartucho con lo que le pone uvm2_draw_init: comparar los dos era comparar dos
         * configuraciones, no dos implementaciones. */
        T1_EXTRA_Q8.store(0, Ordering::Relaxed);
        T1_LAG.store(0, Ordering::Relaxed);
        T1_LAG_ARRANQUE.store(0, Ordering::Relaxed);
        for (dx, dy) in [(0i8, 50i8), (50, 0), (68, 0), (-46, 0), (6, 0)] {
            let (vx, vy, t1) = ramp_params(dx, dy);
            std::println!("  HOST ({dx},{dy}) -> vx={vx} vy={vy} t1={t1}");
        }
    }

    #[test]
    fn un_vertical_no_mueve_la_x() {
        /* EL TURNO, como los demas tests de este fichero: estos knobs son ESTADO
         * GLOBAL y sin serializar se pisan entre tests (rompi
         * `el_techo_de_t1_es_por_vector` al añadirlos sin el lock). */
        let _t = crate::emit::TURNO.lock().unwrap_or_else(|e| e.into_inner());
        MIN_T1.store(8, Ordering::Relaxed);
        MIN_T1_ARRANQUE.store(8, Ordering::Relaxed);
        DRAW_SCALE.store(160, Ordering::Relaxed);
        for dy in [3i8, 7, 24, 50, 60, 120, -24, -60] {
            let (vx, _vy, _t1) = ramp_params(0, dy);
            assert_eq!(vx, 0, "dx=0 dy={dy} deberia dar vx=0 y da vx={vx}");
        }
    }

    #[test]
    fn el_salto_a_tiempo_fijo_solo_se_alarga_cuando_no_cabe() {
        let _t = crate::emit::TURNO.lock().unwrap_or_else(|e| e.into_inner());
        MIN_T1.store(8, Ordering::Relaxed);
        MIN_T1_ARRANQUE.store(8, Ordering::Relaxed);
        DRAW_SCALE.store(160, Ordering::Relaxed);
        T1_TRANSPORT.store(160, Ordering::Relaxed);
        T1_EXTRA_Q8.store(0, Ordering::Relaxed);
        T1_SALTO.store(31, Ordering::Relaxed);

        // A s=160 y t1=31 la tasa cabe en +-127 hasta 127*31/160 = 24 unidades.
        for m in [1i8, 5, 12, 24] {
            let (vx, _vy, t1) = ramp_params_salto(m, 0);
            assert_eq!(t1, 31, "m={m} deberia caber en el tiempo fijo y da t1={t1}");
            assert!(vx.abs() as i32 <= 127);
        }
        // Y a partir de ahi se alarga LO JUSTO, en vez de recortar la tasa: si se quedara
        // en 31 el DAC saturaria y el salto saldria corto siempre en el mismo sentido.
        for m in [40i8, 80, 127] {
            let (vx, _vy, t1) = ramp_params_salto(m, 0);
            assert!(t1 > 31, "m={m} no cabe en t1=31 y deberia alargarse; da t1={t1}");
            let recorrido = (vx as i32) * (t1 as i32) / 160;
            assert!((recorrido - m as i32).abs() <= 1,
                    "m={m}: pedido {m}, recorrido {recorrido} (vx={vx} t1={t1})");
        }
        // El eje menor no se pierde: un salto casi horizontal conserva su dy.
        let (_vx, vy, _t1) = ramp_params_salto(24, 3);
        assert!(vy != 0, "el eje menor de un salto no puede redondearse a cero");

        T1_SALTO.store(0, Ordering::Relaxed); // no contaminar a los demas tests
    }

    #[test]
    fn la_deuda_no_mueve_un_eje_que_no_se_pide() {
        let _t = crate::emit::TURNO.lock().unwrap_or_else(|e| e.into_inner());
        MIN_T1.store(8, Ordering::Relaxed);
        MIN_T1_ARRANQUE.store(8, Ordering::Relaxed);
        DRAW_SCALE.store(160, Ordering::Relaxed);
        T1_TRANSPORT.store(160, Ordering::Relaxed);
        T1_EXTRA_Q8.store(0, Ordering::Relaxed);
        T1_SALTO.store(0, Ordering::Relaxed);
        DEUDA_X.store(0, Ordering::Relaxed);
        DEUDA_Y.store(0, Ordering::Relaxed);

        /* Diagonales que dejan deuda, y verticales puros intercalados: los verticales NO
         * pueden llevarse esa deuda a la X. Es el caso real — 189 verticales en un frame
         * del VecFever, todos con vx = 0. */
        let mut suma_vx = 0i32;
        for k in 0..40 {
            ramp_params_chain_q4(37 + k % 5, 23 + k % 7, );
            let (vx, _vy, _t1) = ramp_params_chain_q4(0, 40 + k % 3);
            assert_eq!(vx, 0, "un vertical con dx=0 no puede salir con vx={vx}");
            suma_vx += vx as i32;
        }
        assert_eq!(suma_vx, 0, "y sin deriva acumulada en X");
    }

    #[test]
    fn las_subunidades_dan_posiciones_que_el_entero_no_puede() {
        let _t = crate::emit::TURNO.lock().unwrap_or_else(|e| e.into_inner());
        MIN_T1.store(8, Ordering::Relaxed);
        MIN_T1_ARRANQUE.store(8, Ordering::Relaxed);
        DRAW_SCALE.store(160, Ordering::Relaxed);
        T1_TRANSPORT.store(160, Ordering::Relaxed);
        T1_EXTRA_Q8.store(0, Ordering::Relaxed);
        T1_SALTO.store(0, Ordering::Relaxed);

        // 2,5 unidades no se puede pedir en enteros: o 2 o 3. En Q4 son 40 dieciseisavos.
        let (vx_e, _, t1_e) = ramp_params(2, 0);
        let (vx_q, _, t1_q) = ramp_params_q(40, 0, 42, 4);
        let rec = |v: i8, t: u16| v as f64 * t as f64 / 160.0;
        let d_e = (rec(vx_e, t1_e) - 2.5).abs();
        let d_q = (rec(vx_q, t1_q) - 2.5).abs();
        assert!(d_q < d_e / 2.0,
                "Q4 deberia acercarse mucho mas a 2,5: entero {:.3} (err {:.3}), \
                 Q4 {:.3} (err {:.3})", rec(vx_e, t1_e), d_e, rec(vx_q, t1_q), d_q);

        // Y un vector SUB-UNIDAD, que en enteros ni existe: 0,5 unidades = 8 dieciseisavos.
        let (vx0, vy0, _) = ramp_params(0, 0);
        assert_eq!((vx0, vy0), (0, 0), "en enteros medio pixel se pierde entero");
        let (vxh, _, t1h) = ramp_params_q(8, 0, TOPE_DAC, 4);
        assert!(rec(vxh, t1h) > 0.3 && rec(vxh, t1h) < 0.7,
                "media unidad deberia salir ~0,5 y sale {:.3}", rec(vxh, t1h));

        // Q4 con valores ya enteros no puede cambiar lo que hacia antes.
        for d in [1i8, 3, 7, 20, 60, -5, -33] {
            assert_eq!(ramp_params(d, 0), ramp_params_q(d as i32 * 16, 0, TOPE_DAC, 4),
                       "d={d}: un entero exacto tiene que dar lo mismo por los dos caminos");
        }
    }
}

#[cfg(test)]
mod sesgo_x_2026_09_04 {
    use super::*;
    /// LOS CASOS REALES DEL FRAME. Con la geometria del VecFever de entrada, su vx y la
    /// nuestra difieren en 1-2 en el 88% de los microtramos mientras la vy coincide. Esto
    /// pregunta al MODELO por esos mismos casos, sin cartucho de por medio.
    #[test]
    fn imprime_el_sesgo_de_x() {
        let _t = crate::emit::TURNO.lock().unwrap_or_else(|e| e.into_inner());
        MIN_T1.store(8, Ordering::Relaxed);
        MIN_T1_ARRANQUE.store(8, Ordering::Relaxed);
        DRAW_SCALE.store(160, Ordering::Relaxed);
        T1_TRANSPORT.store(160, Ordering::Relaxed);
        T1_EXTRA_Q8.store(0, Ordering::Relaxed);
        DEUDA_X.store(0, Ordering::Relaxed);
        DEUDA_Y.store(0, Ordering::Relaxed);
        // (dx_q4, dy_q4) -> lo que el emite
        let casos = [((0, 40), (50, 0)), ((41, 0), (0, 51)), ((0, -40), (-50, 0)),
                     ((-11, 20), (25, -13)), ((11, 20), (25, 13)), ((21, 0), (0, 26))];
        for ((dx, dy), (svy, svx)) in casos {
            let (vx, vy, t1) = ramp_params_chain_q4(dx, dy);
            std::println!("  dx_q4={dx:4} dy_q4={dy:4} -> nuestro vy={vy:4} vx={vx:4} t1={t1:3} | suyo vy={svy:4} vx={svx:4}");
        }
    }
}


#[cfg(test)]
mod deriva {
    use super::*;
    /// REPRODUCE EL FRAME ENTERO EN EL HOST y sigue la deuda vector a vector.
    ///
    /// Existe porque medir esto en el cartucho cuesta un build y una corrida del emulador
    /// por intento, y porque un build que falla en silencio se lee igual que un cambio sin
    /// efecto — ya paso. Aqui la geometria es la misma (el frame 120 de Major Havoc, leido
    /// del header que genera sdkplay) y el modelo es el que se compila, asi que lo que
    /// diga esto es lo que hara la placa.
    /// LA PRECISION LA DICE EL FICHERO. Estaba escrita a mano como 16 en cinco sitios, y
    /// al regenerar la tabla en 1/256 el banco reventaba por desbordamiento en vez de
    /// avisar de que estaba leyendo otra unidad.
    fn qbits() -> u32 {
        let t = std::fs::read_to_string(
            "/Users/daniel/projects/vectrex-arcade-private/hardware/uvm2/sdkplay/src/vf_geom_mh.h")
            .unwrap_or_default();
        t.lines()
            .find_map(|l| l.trim().strip_prefix("#define VF_GEOM_QBITS "))
            .and_then(|v| v.trim().parse().ok())
            .unwrap_or(4)
    }

    fn geometria() -> std::vec::Vec<(i32, i32, i32, i32)> {
        let t = std::fs::read_to_string(
            "/Users/daniel/projects/vectrex-arcade-private/hardware/uvm2/sdkplay/src/vf_geom_mh.h")
            .unwrap_or_default();
        let mut v = std::vec::Vec::new();
        for l in t.lines() {
            let l = l.trim();
            if !l.starts_with('{') { continue; }
            let n: std::vec::Vec<i32> = l.trim_matches(|c| c=='{'||c=='}'||c==',')
                .split(',').filter_map(|x| x.trim().parse().ok()).collect();
            if n.len() >= 4 { v.push((n[0], n[1], n[2], n[3])); }
        }
        v
    }

    #[test]
    fn la_deuda_no_se_desboca() {
        let _t = crate::emit::TURNO.lock().unwrap_or_else(|e| e.into_inner());
        MIN_T1.store(8, Ordering::Relaxed);
        MIN_T1_ARRANQUE.store(8, Ordering::Relaxed);
        DRAW_SCALE.store(160, Ordering::Relaxed);
        T1_TRANSPORT.store(160, Ordering::Relaxed);
        T1_EXTRA_Q8.store(0, Ordering::Relaxed);
        T1_SALTO.store(0, Ordering::Relaxed);
        DEUDA_X.store(0, Ordering::Relaxed); DEUDA_Y.store(0, Ordering::Relaxed);
        knobs_como_el_cartucho();
        let q = qbits();
        let f = (1u32 << q) as f64;

        let g = geometria();
        if g.is_empty() { return; }                 // sin header, no hay nada que probar
        let (mut bx, mut by) = (0.0f64, 0.0f64);    // donde esta el haz, en unidades
        let (mut px_, mut py_) = (0.0f64, 0.0f64);  // donde CREE el dibujante que esta
        let mut errores: std::vec::Vec<f64> = std::vec::Vec::new();
        let mut peor_x = 0.0f64; let mut peor_deuda = 0i32;
        let mut satur = 0usize; let mut saltos = 0usize;
        for (i, (x0, y0, x1, y1)) in g.iter().enumerate() {
            /* EL SALTO SOLO SI HACE FALTA, COMO EL CARTUCHO. `uvm2_draw_move_abs` no emite
             * nada si el haz ya esta donde toca, asi que DENTRO DE UNA CADENA no hay salto
             * — y por tanto no hay quien absorba la deuda. Llamandolo siempre, la replica
             * absorbia en cada segmento y daba -0,18 donde la placa da +4,70. */
            let (jx4, jy4) = (*x0 - (px_*f).round() as i32,
                              *y0 - (py_*f).round() as i32);
            if jx4 != 0 || jy4 != 0 {
                let (vx, vy, t1) = ramp_params_salto_con_deuda(
                    jx4, jy4, TOPE_DAC, q);
                if vx.abs() == 127 || vy.abs() == 127 { satur += 1; }
                bx += vx as f64 * t1 as f64 / 160.0; by += vy as f64 * t1 as f64 / 160.0;
                saltos += 1;
            }
            px_ = *x0 as f64/f; py_ = *y0 as f64/f;
            // el trazo
            let (vx, vy, t1) = ramp_params_chain_qn(x1 - x0, y1 - y0, q);
            if vx.abs() == 127 || vy.abs() == 127 { satur += 1; }
            bx += vx as f64 * t1 as f64 / 160.0; by += vy as f64 * t1 as f64 / 160.0;
            px_ = *x1 as f64/f; py_ = *y1 as f64/f;
            let e = bx - px_;
            errores.push(e);
            if e.abs() > peor_x.abs() { peor_x = e; }
            let d = DEUDA_X.load(Ordering::Relaxed);
            if d.abs() > peor_deuda.abs() { peor_deuda = d; }
            if i < 10 {
                std::println!("  HOST seg {i:3}: vy={vy:4} vx={vx:4} t1={t1:3}   haz X {bx:8.3}  error {e:+7.3}  deuda {d:+5}");
            }
        }
        let mediana = { let mut v: std::vec::Vec<f64> = errores.clone(); v.sort_by(|a,b| a.partial_cmp(b).unwrap()); v[v.len()/2] };
        std::println!("  X mediana {mediana:+.2}  peor {peor_x:+.2}   deuda peor {peor_deuda:+}   saltos {saltos}  saturadas {satur}");
    }
}

/* Los knobs son atomicas GLOBALES y `cargo test` corre los tests en paralelo dentro del
 * mismo proceso: un test que toca VCAP se lo cambia a otro a media medida. Todo banco que
 * compare contra el cartucho tiene que fijar la configuracion ENTERA, y correr con
 * --test-threads=1. Estos valores estan leidos de la imagen que corre en la consola
 * (`correr_uvm2.mjs ... sdkplaymh.elf`), no elegidos aqui. */
#[cfg(test)]
pub(crate) fn knobs_como_el_cartucho() {
    T1_EXTRA_Q8.store(0, Ordering::Relaxed);
    T1_LAG.store(0, Ordering::Relaxed);
    T1_LAG_ARRANQUE.store(0, Ordering::Relaxed);
    MIN_T1.store(8, Ordering::Relaxed);
    MIN_T1_ARRANQUE.store(8, Ordering::Relaxed);
    T1_SALTO.store(0, Ordering::Relaxed);
    T1_TRANSPORT.store(160, Ordering::Relaxed);
    DRAW_SCALE.store(160, Ordering::Relaxed);
    RAMPA_FIJA.store(0, Ordering::Relaxed);
}

#[cfg(test)]
mod primera_llamada {
    use super::*;
    /* El mismo delta que sonde en el cartucho (dx_q4=0, dy_q4=40, primera llamada del
     * arranque). Si aqui sale otro (vx,vy,t1) que en la placa, la diferencia es un knob. */
    #[test]
    fn el_primer_delta_del_frame() {
        knobs_como_el_cartucho();
        vx_chain_reset(); vx_deuda_reset();
        let (vx, vy, t1) = ramp_params_chain_q4(0, 40);
        std::println!("HOST:     vy={vy}  t1={t1}  vx={vx}");
    }
}

#[cfg(test)]
mod tasa_directa {
    use super::*;
    #[test]
    fn el_trazo_391() {
        knobs_como_el_cartucho();
        DEUDA_ON.store(0, Ordering::Relaxed);
        vx_chain_reset(); vx_deuda_reset();
        // la geometria pide dx=1,3477 dy=-2,4023 unidades, o sea 345 y -615 en Q8
        let (vx, vy, t1) = ramp_params_chain_qn(345, -615, 8);
        std::println!("  chain_qn(345,-615,q=8) -> vx={vx} vy={vy} t1={t1}   (el suyo: 27, -48, 8)");
        let (ax, ay, at1) = ramp_params_q(345, -615, TOPE_DAC, 8);
        std::println!("  ramp_params_q crudo    -> vx={ax} vy={ay} t1={at1}");
        std::println!("  escala()={}  T1_EXTRA_Q8={}", escala(), T1_EXTRA_Q8.load(Ordering::Relaxed));
    }
}

#[cfg(test)]
mod escalera {
    use super::*;
    /// Las tasas para un t1 dado. Su transporte #156 pide 11,81 unidades en +X y el emite
    /// (105, 0) con t1 = 18.
    #[test]
    fn tasas_para_un_t1_dado() {
        knobs_como_el_cartucho();
        let dx = (11.8125 * 256.0) as i32;      // 11,81 unidades en Q8
        let mut vx = 0i32; let mut vy = 0i32;
        vx_ramp_params_con_t1(dx, 0, 256, 18, &mut vx, &mut vy);
        std::println!("  HOST: dx={dx} q=8 t1=18  ->  vx={vx} vy={vy}   (el suyo: 105, 0)");
    }
}

#[cfg(test)]
mod sesgo_del_salto {
    use super::*;
    /// IS THE JUMP'S ERROR A BIAS THAT DEPENDS ON THE SIGN? `move_una` says so, measured on
    /// asterock BEFORE sub-unit precision: "negative delta X falls 1.3 units short, positive
    /// delta Y overshoots by 3.9, the other two directions are exact". If that survives in
    /// Q4 it is what makes reordering unsafe -- change the order, change the mix of signs,
    /// change the frame's accumulated error, and THAT flickers. Not a fractional residue
    /// another ramp can absorb: a bias, so it adds up linearly.
    ///
    /// dkong's configuration, not the crate's defaults.  `cargo test -- --nocapture
    /// --test-threads=1 sesgo_del_salto`
    #[test]
    fn el_sesgo_por_signo_del_salto() {
        let _t = crate::emit::TURNO.lock().unwrap_or_else(|e| e.into_inner());
        MIN_T1.store(8, Ordering::Relaxed);
        MIN_T1_ARRANQUE.store(31, Ordering::Relaxed);
        DRAW_SCALE.store(127, Ordering::Relaxed);
        T1_TRANSPORT.store(110, Ordering::Relaxed);
        T1_EXTRA_Q8.store(0, Ordering::Relaxed);
        T1_LAG.store(0, Ordering::Relaxed);
        T1_LAG_ARRANQUE.store(0, Ordering::Relaxed);
        TECHO_MANDA.store(1, Ordering::Relaxed);
        RAMPA_FIJA.store(0, Ordering::Relaxed);
        let s = DRAW_SCALE.load(Ordering::Relaxed) as i64;
        let q: i64 = 16;                       // Q4
        // Every jump dkong actually makes: 1..120 units, both signs, both axes.
        for (nom, sx, sy) in [("dx>0 dy=0", 1i64, 0i64), ("dx<0 dy=0", -1, 0),
                              ("dx=0 dy>0", 0, 1),      ("dx=0 dy<0", 0, -1),
                              ("dx>0 dy>0", 1, 1),      ("dx<0 dy<0", -1, -1),
                              ("dx<0 dy>0", -1, 1),     ("dx>0 dy<0", 1, -1)] {
            let (mut sx_e, mut sy_e, mut n) = (0.0f64, 0.0f64, 0i64);
            let (mut px, mut py) = (0.0f64, 0.0f64);
            // Only as far as ONE ramp reaches: 127 * min(DRAW_SCALE, T1_TRANSPORT)
            // / DRAW_SCALE. Past that `trocear` splits, and what would be measured here is
            // the clipping, not the bias.
            let alcance = 127 * T1_TRANSPORT.load(Ordering::Relaxed).min(s as u32) as i64 / s;
            for u in 1..=alcance {
                let dx = (sx * u * q) as i32;
                let dy = (sy * u * q) as i32;
                let (vx, vy, t1) = ramp_params_q(dx, dy, TOPE_DAC, 4);
                // what the ramp actually covers, in the same internal units
                let rx = (vx as i64) * (t1 as i64) * q / s;
                let ry = (vy as i64) * (t1 as i64) * q / s;
                // SIGNED, PER AXIS. Taking the magnitude and guessing a sign says nothing
                // in the mixed quadrants, where the two axes can err in opposite ways.
                let ex = (rx - dx as i64) as f64 / q as f64;
                let ey = (ry - dy as i64) as f64 / q as f64;
                sx_e += ex; sy_e += ey; n += 1;
                if ex.abs() > px.abs() { px = ex; }
                if ey.abs() > py.abs() { py = ey; }
            }
            std::println!("  {nom}   X {:+.3} (peor {:+.2})   Y {:+.3} (peor {:+.2})   {n} saltos",
                          sx_e / n as f64, px, sy_e / n as f64, py);
        }
    }
}
