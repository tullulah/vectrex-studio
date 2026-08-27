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
pub static MIN_T1: AtomicU32 = AtomicU32::new(31);

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
#[used]
#[no_mangle]
pub static VCAP: AtomicU32 = AtomicU32::new(127);

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
#[no_mangle]
pub static VCAP_SLOW: AtomicU32 = AtomicU32::new(30);

#[used]
// LONGITUD MAXIMA del vector para que la regla aplique (no un salto de velocidad;
// ver la nota del disparador). Los segmentos del zigzag miden 7..9, asi que 32 los
// cubre con holgura. 16 tambien, y quedo sin decidir cual es mejor: el barrido que
// lo comparaba se perdio con un reinicio a mitad.
#[no_mangle]
pub static VCAP_DV: AtomicU32 = AtomicU32::new(32);

/// Cuantos vectores han caido en el tope lento. Si esto es 0 el umbral no salta;
/// si se parece al total de vectores, el selectivo no esta seleccionando nada y
/// estas pagando el 22% igual.
#[used]
#[no_mangle]
pub static VCAP_SLOW_HITS: AtomicU32 = AtomicU32::new(0);

#[inline(always)]
pub fn ramp_params(dx: i8, dy: i8) -> (i8, i8, u16) {
    let m = core::cmp::max((dx as i32).abs(), (dy as i32).abs());
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
    let mut vcap = VCAP.load(Ordering::Relaxed) as i32;

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
    let lento = VCAP_SLOW.load(Ordering::Relaxed) as i32;
    if lento != 0 && dy != 0 && m <= VCAP_DV.load(Ordering::Relaxed) as i32 {
        let held = Y_HELD.load(Ordering::Relaxed);
        if held & 0x100 != 0 {
            let prev = (held & 0xff) as u8 as i8 as i32;
            if prev != 0 && (prev < 0) != ((dy as i32) < 0) {
                vcap = lento;
                VCAP_SLOW_HITS.fetch_add(1, Ordering::Relaxed);
            }
        }
    }
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
        return (dx.clamp(-128, 127) as i8, dy.clamp(-128, 127) as i8, fija as u16);
    }
    // 0xA0 = 160, NO 0x7F: el comentario que habia aqui decia 0x7F y llevaba tiempo
    // mintiendo. `s` gobierna la longitud Y la velocidad de todos los vectores
    // (vx = dx*s/t1, y t1 se acota a s), asi que razonar sobre ramp_params con 127 en la
    // cabeza da numeros mal. Se detecto porque el histograma de t1 tenia un cubo de >=128
    // que con s=127 no puede existir.
    let s = escala();
    let t1_floor = (s * m / 127).clamp(min_t1, s); // dwell floor (∝ length)
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
    let t1_vcap = ((m * s + vc - 1) / vc).max(1);
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
    let d_menor = match ((dx as i32).abs(), (dy as i32).abs()) {
        (0, b) => b,                  // sin eje X que perder
        (a, 0) => a,
        (a, b) => a.min(b),
    };
    let techo = (d_menor * s)
        .min(T1_TRANSPORT.load(Ordering::Relaxed) as i32)
        .max(min_t1);                 // por si el transporte se deja por debajo del suelo
    let t1 = t1_floor.max(t1_vcap).min(techo);
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
            let n = (m as i64) * (s as i64) * 256;
            let q = if n >= 0 { (n + den / 2) / den } else { (n - den / 2) / den };
            q.clamp(-128, 127)
        };
        ((v * t as i64) - (m as i64) * (s as i64)).abs()
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
    let vx = round_div(dx as i32 * s).clamp(-128, 127) as i8;
    let vy = round_div(dy as i32 * s).clamp(-128, 127) as i8;
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
pub static T1_EXTRA_Q8: AtomicU32 = AtomicU32::new(0);

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
pub static HAZ_POR_SR: AtomicU32 = AtomicU32::new(0);

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
static DEUDA_X: AtomicI32 = AtomicI32::new(0);
static DEUDA_Y: AtomicI32 = AtomicI32::new(0);

/// Se olvida la deuda. Lo llama quien reposicione el haz: un salto o un re-cero.
#[no_mangle]
pub extern "C" fn vx_chain_reset() {
    DEUDA_X.store(0, Ordering::Relaxed);
    DEUDA_Y.store(0, Ordering::Relaxed);
    /* El haz se reposiciona: la proxima rampa parte del reposo. Ver `ramp_params`. */
    ARRANQUE.store(1, Ordering::Relaxed);
}

/// Lo que la rampa recorre DE VERDAD, en milesimas: v * t1 / DRAW_SCALE con su fraccion.
#[inline(always)]
fn recorrido_mil(v: i32, t1: u16) -> i32 {
    ((v as i64 * t1 as i64 * 1000) / escala() as i64) as i32
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
