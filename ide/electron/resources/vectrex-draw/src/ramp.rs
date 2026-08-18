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

use core::sync::atomic::{AtomicU32, Ordering};

pub const DRAW_SCALE: u8 = 0xA0; // T1CL scale factor (line length ∝ delta × scale).

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

/// Techo de t1. 160 = DRAW_SCALE, que es donde estaba cocido; 255 = el maximo
/// fisico del contador de 8 bits de la VIA. Subirlo alarga la rampa maxima y es
/// lo que le devuelve recorrido a VCAP — ver el comentario en `ramp_params`.
#[used]
#[no_mangle]
pub static T1_CEILING: AtomicU32 = AtomicU32::new(DRAW_SCALE as u32);

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
    let min_t1 = MIN_T1.load(Ordering::Relaxed) as i32;
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
    // 0xA0 = 160, NO 0x7F: el comentario que habia aqui decia 0x7F y llevaba tiempo
    // mintiendo. `s` gobierna la longitud Y la velocidad de todos los vectores
    // (vx = dx*s/t1, y t1 se acota a s), asi que razonar sobre ramp_params con 127 en la
    // cabeza da numeros mal. Se detecto porque el histograma de t1 tenia un cubo de >=128
    // que con s=127 no puede existir.
    let s = DRAW_SCALE as i32;
    let t1_floor = (s * m / 127).clamp(min_t1, s); // dwell floor (∝ length)
    // VELOCITY CAP: at MIN_T1=24 mid-length segments (24 < m ≤ 110) run at the full
    // ±127 swing, and the integrator op-amp overshoots the endpoint → platform
    // vectors "stretch". MIN_T1=110 avoided it by throttling their velocity (long
    // t1). Replicate that WITHOUT raising the global floor: if the dominant velocity
    // (m·0x7F / t1) would exceed VCAP, raise t1 so it lands at VCAP (distance is
    // preserved: velocity·t1 stays). Short vectors are already below VCAP → their
    // short dwell (the flicker win) is untouched. t1 is capped at 0x7F.
    let t1_vcap = (m * s / vcap.max(1)).max(1);
    // EL TECHO, COMO KNOB. Estaba fijo en `s` (DRAW_SCALE = 160) y eso hacia que
    // VCAP se quedara sin recorrido: con VCAP = 8 el calculo pide m*160/8 —2540 para
    // un vector largo— y el recorte lo aplastaba a 160, asi que bajar mas VCAP ya no
    // hacia nada. MEDIDO en pantalla el 2026-08-17: a VCAP = 8 el espolon casi se
    // cierra y no termina de irse, que es exactamente la firma de un knob saturado.
    //
    // t1 va al contador T1 de la VIA, que es de 8 bits: el techo fisico es 255, no
    // 160. Los 95 que faltan son el recorrido que le devolvemos a VCAP.
    let t1 = t1_floor.max(t1_vcap).min(T1_CEILING.load(Ordering::Relaxed) as i32);
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
    (vx, vy, t1 as u16)
}

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
