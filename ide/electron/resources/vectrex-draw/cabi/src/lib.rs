//! Envoltorio C de `vectrex-draw`, para la imagen del Ultimate Vectrex Multicart 2.
//!
//! No implementa nada: reexporta los simbolos `extern "C"` del modelo y pone el
//! manejador de panico que una `staticlib` exige. Toda la logica esta en la caja de al
//! lado, que es la que enlaza tambien el firmware — que es el punto de todo esto.

#![no_std]

// Sin esto el enlazador descarta la caja entera: nada en este fichero la referencia, y
// los `#[no_mangle]` de una dependencia no arrastran por si solos.
pub use vectrex_draw::emit::{vx_draw_line_patterned_seq, vx_draw_line_seq, vx_moveto_seq};
pub use vectrex_draw::ramp::{vx_ramp_params, vx_ramp_params_chain, vx_chain_reset};
pub use vectrex_draw::{vx_probe, vx_probe_div};

/// Un panico dentro de una imagen bare-metal no tiene a donde ir. Se para en seco: es
/// visible (la pantalla se congela) y no corrompe nada.
#[panic_handler]
fn panic(_info: &core::panic::PanicInfo) -> ! {
    loop {
        core::hint::spin_loop();
    }
}


// ── EL STREAM DE BUS, EN EL MISMO ENVOLTORIO ─────────────────────────────────
//
// POR QUE AQUI Y NO EN SU PROPIA .a: una `staticlib` EXIGE un `#[panic_handler]` en
// COMPILACION —no se puede diferir al enlace— y dos manejadores en el mismo enlace es un
// error duro. Dos envoltorios separados no pueden coexistir en una imagen. Asi que hay UN
// envoltorio y dos cajas detras, que es donde vive la logica.
//
// Detras de la caracteristica `bus`: con la perilla apagada no entra ni un byte del stream,
// que importa en una imagen con 3,8 KB libres como la de dkong.
#[cfg(feature = "bus")]
mod bus_c {
    use vectrex_bus as bus;
    
    /// El reparto de campos de ESTA placa. Lo pone el llamante en C, porque el mapa de pines es
    /// suyo: en la UVM2 la direccion esta partida (A14/A15 saltan sobre PB6) y esa cuenta la
    /// hace `uvm2_bus.h`, no esta caja.
    static mut LAYOUT: bus::Layout = bus::Layout {
        out_base: 0,
        out_count: 0,
        out_dirs: 0,
        park: 0,
    };
    
    /// Pines al PIO, programa dentro, SM corriendo y preambulo empujado.
    ///
    /// `out_dirs` va alineado a `out_base` y **no tiene por que ser todo unos**: en la UVM2,
    /// PB6 (GP22) es una entrada y GP23 no existe, asi que sus bits van a 0 y el `out pins`
    /// sobre ellos queda inocuo.
    #[no_mangle]
    pub unsafe extern "C" fn vbus_install(out_base: u32, out_count: u32, out_dirs: u32, park: u32) {
        LAYOUT = bus::Layout { out_base, out_count, out_dirs, park };
        let (codigo, wt, wr) = bus::programa();
        bus::install(&LAYOUT, codigo, wt, wr);
    }
    
    /// Una escritura: la palabra de bus YA armada con el mapa de la placa.
    #[no_mangle]
    pub unsafe extern "C" fn vbus_word(bus_word: u32) -> u32 {
        LAYOUT.word(bus_word)
    }
    
    /// Aparcar `n` periodos de E con una sola palabra.
    #[no_mangle]
    pub extern "C" fn vbus_repeat(n: u32) -> u32 {
        bus::Layout::repeat(n)
    }
    
    /// Un periodo en silencio: ni conduce ni aparca.
    #[no_mangle]
    pub unsafe extern "C" fn vbus_silence() -> u32 {
        LAYOUT.silence()
    }
    
    #[no_mangle]
    pub unsafe extern "C" fn vbus_push(word: u32) {
        bus::push(word)
    }
    
    /// Vaciar el lote parcial. OBLIGATORIO antes de una LECTURA del bus: sin esto, una lectura
    /// adelanta a hasta 63 escrituras encoladas (~42 us). Leer un mando es escribir la columna
    /// y luego leer, y los botones son activos bajos: adelantarse = "pulsado".
    #[no_mangle]
    pub unsafe extern "C" fn vbus_flush() {
        bus::flush()
    }
    
    #[no_mangle]
    pub unsafe extern "C" fn vbus_drain() {
        bus::drain()
    }

    #[no_mangle]
    pub unsafe extern "C" fn vbus_sm_parar() {
        bus::sm_parar()
    }

    #[no_mangle]
    pub unsafe extern "C" fn vbus_sm_arrancar() {
        bus::sm_arrancar()
    }
    
    /// Los contadores, por indice, para poder leerlos por SWD desde C sin exportar simbolos
    /// Rust uno a uno. El orden lo fija `uvm2_bus.h`; LOS DOS SE MUEVEN JUNTOS.
    #[no_mangle]
    pub extern "C" fn vbus_stat(idx: u32) -> u32 {
        use core::sync::atomic::Ordering::Relaxed;
        match idx {
            0 => bus::STREAM_PUSHES.load(Relaxed),
            1 => bus::STREAM_STALLS.load(Relaxed),
            2 => bus::BATCH_SENT.load(Relaxed),
            3 => bus::BATCH_WAITS.load(Relaxed),
            4 => bus::RING_FULL_SEEN.load(Relaxed),
            5 => bus::RING_OVERRUNS.load(Relaxed),
            _ => 0,
        }
    }
}
