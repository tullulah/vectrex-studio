//! Capa de dibujo compartida entre el cartucho propio y el multicart de Ralf.
//!
//! PASO 1 SUPERADO EN HARDWARE (2026-08-18). Leido por SWD con SnowBros corriendo en el
//! multicart de Ralf: `uvm2_vx_probe = 0x56580001` y `uvm2_vx_probe_div = 142`. O sea que
//! la staticlib no solo enlaza — se CARGA Y EJECUTA dentro de su imagen, y los
//! intrinsecos enteros resuelven. El juego se ve igual y su firmware no se toco.
//!
//! PASO 1 DE 4, y a proposito no hace nada util todavia. Lo que se esta probando aqui no
//! es el dibujo: es que una `staticlib` de Rust ENLACE Y CORRA dentro de la imagen del
//! UVM2, que es la incognita que puede matar el plan entero (simbolos de panico,
//! `compiler_builtins`, y sobre todo los atributos de ABI). Si esto no enlaza, no importa
//! lo bueno que sea el resto del diseño.
//!
//! LA ABI, MEDIDA y no supuesta:
//!
//! ```text
//!     firmware      thumbv8m.main-none-eabihf   -> flotantes en registros VFP
//!     imagen UVM2   -mcpu=cortex-m33 -mfloat-abi=softfp
//!
//! ```
//! El enlazador compara `Tag_ABI_VFP_args` y protesta aunque no cruce ni un flotante, asi
//! que esta caja se compila para `thumbv8m.main-none-eabi` (coma flotante software).
//!
//! DE AHI SALE LA REGLA MAS IMPORTANTE DE ESTE FICHERO: **la API publica es entera pura,
//! ni un `f32` ni un `f64`, nunca**. No es una preferencia de estilo — es lo que permite
//! que la misma `.a` sirva a las dos placas. Nuestro modelo de haz ya es aritmetica entera
//! por diseño, asi que no cuesta nada mantenerlo.

#![no_std]

// `std` SOLO para los tests del host. La caja sigue siendo no_std en la build de verdad;
// esto es lo que permite verificar la secuencia en el Mac en vez de en la consola — y
// hace falta, porque en la placa de Ralf cada lectura por SWD la resetea.
#[cfg(test)]
extern crate std;

pub mod emit;
pub mod ramp;

/// Devuelve una constante reconocible. Es la sonda del paso 1: si el firmware de Ralf
/// carga la imagen y esto se puede leer por SWD, la cadena Rust -> .a -> CMake -> .um2
/// funciona y se puede empezar a mover codigo de verdad.
///
/// `extern "C"` y `#[no_mangle]` porque quien llama es C.
#[no_mangle]
pub extern "C" fn vx_probe() -> u32 {
    0x5658_0001 // "VX" + version
}

/// Aritmetica de 32 bits atravesando la frontera, para comprobar que no aparecen
/// intrinsecos sin resolver. Una division de 64 bits pedia `__aeabi_ldivmod`, que el
/// enlace del camino VPy no trae — paso hoy mismo. Mejor descubrirlo aqui que con el
/// modelo entero encima.
#[no_mangle]
pub extern "C" fn vx_probe_div(num: i32, den: i32) -> i32 {
    if den == 0 { return 0; }
    num / den
}
