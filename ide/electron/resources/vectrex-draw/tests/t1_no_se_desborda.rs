//! EL TECHO ACOTA t1; SOLTARLO LO DESACOTA.
//!
//! `techo` esta limitado por T1_TRANSPORT (110 en la BIOS del cartucho). `t1_vcap` no lo
//! esta por arriba — su propio comentario dice que a VCAP = 8 pide 2540. Mientras el techo
//! mandaba siempre, t1 no podia pasar de 110; la rama que lo suelta existia solo bajo
//! TECHO_MANDA = 0, que no es el defecto.
//!
//! Lo que t1 alimenta es el hueco del comando, un campo de DOCE BITS. Un hueco saturado
//! dispara el frame — 788.661 ciclos medidos una vez con un ORA+4096 — y un frame de medio
//! segundo deja la consola dibujando a 2 fps: la entrada se lee una vez por frame, asi que
//! el mando parece muerto aunque el dibujo siga ahi. Es el sintoma exacto del 2026-09-23.
//!
//! El emulador no lo ve: reproduce la GEOMETRIA, no los tiempos (su us_exec sale 8,4 ms
//! para una lista que el bus tarda 20 en pasar), asi que dos builds con los mismos
//! segmentos y huecos distintos le salen identicas. Por eso el A/B de la BIOS no acuso.
use std::sync::atomic::Ordering;
use vectrex_draw::ramp::{ramp_params_chain_qn, MIN_T1, T1_TRANSPORT, TECHO_A_CUENTA};

#[test]
fn t1_cabe_en_el_hueco_del_comando() {
    /* La configuracion del cartucho, ENTERA: un banco que solo fija lo que mira hereda el
     * resto del test anterior, y estos son estaticos del proceso. */
    T1_TRANSPORT.store(110, Ordering::Relaxed);
    MIN_T1.store(8, Ordering::Relaxed);

    /* LAS DOS ARMAS, y lo que importa no es solo el maximo sino la SUMA: t1 es tiempo de
     * rampa, asi que sumarlo sobre los deltas de una escena es lo que dura el frame. */
    let barrido = || {
        let (mut peor, mut donde, mut suma, mut n) = (0u16, (0, 0), 0u64, 0u32);
        for dx in (-2048..=2048).step_by(17) {
            for dy in (-2048..=2048).step_by(17) {
                if dx == 0 && dy == 0 { continue; }
                let (_vx, _vy, t1) = ramp_params_chain_qn(dx, dy, 4);
                n += 1; suma += t1 as u64;
                if t1 > peor { peor = t1; donde = (dx, dy); }
            }
        }
        (n, peor, donde, suma)
    };
    TECHO_A_CUENTA.store(0, Ordering::Relaxed);
    let (n, peor0, donde0, suma0) = barrido();
    TECHO_A_CUENTA.store(1, Ordering::Relaxed);
    let (_, peor1, donde1, suma1) = barrido();
    println!("  {n} deltas");
    println!("  el techo manda SIEMPRE (como antes): t1 max {peor0} en {donde0:?}, suma {suma0}");
    println!("  el techo manda SI SALE A CUENTA    : t1 max {peor1} en {donde1:?}, suma {suma1}");
    println!("  el frame cuesta un {:+.1}% en tiempo de rampa",
             100.0 * (suma1 as f64 - suma0 as f64) / suma0 as f64);
    assert!(peor1 <= 4095, "t1 = {peor1} en {donde1:?} no cabe en el hueco de 12 bits");
}
