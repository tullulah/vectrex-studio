//! Envoltorio C de `vectrex-draw`, para la imagen del Ultimate Vectrex Multicart 2.
//!
//! No implementa nada: reexporta los simbolos `extern "C"` del modelo y pone el
//! manejador de panico que una `staticlib` exige. Toda la logica esta en la caja de al
//! lado, que es la que enlaza tambien el firmware — que es el punto de todo esto.

#![no_std]

// Sin esto el enlazador descarta la caja entera: nada en este fichero la referencia, y
// los `#[no_mangle]` de una dependencia no arrastran por si solos.
pub use vectrex_draw::emit::{vx_draw_line_seq, vx_moveto_seq};
pub use vectrex_draw::ramp::vx_ramp_params;
pub use vectrex_draw::{vx_probe, vx_probe_div};

/// Un panico dentro de una imagen bare-metal no tiene a donde ir. Se para en seco: es
/// visible (la pantalla se congela) y no corrompe nada.
#[panic_handler]
fn panic(_info: &core::panic::PanicInfo) -> ! {
    loop {
        core::hint::spin_loop();
    }
}
