/*
 * uvm2_psram.c — ¿tiene PSRAM el UVM2, y la tenemos que levantar nosotros?
 *
 * El esquema dice que si: U3 cuelga del mismo bus QSPI que la flash (U6, un
 * W25Q128) y su select, PSRAM_CS, sale del pin 58 = GPIO47. GPIO47 es QMI CS1n
 * en la funcion F9 — la misma disposicion que nuestro cartucho, que usa el
 * GPIO 0. Ver hardware/uvm2/PSRAM.md.
 *
 * Lo que el esquema NO puede decir, y esto contesta:
 *   1. si el chip esta poblado (parece marcado DNP)
 *   2. que chip es y cuanto mide (READ_ID)
 *   3. si el firmware del multicart YA la deja mapeada, en cuyo caso no hay
 *      nada que levantar y basta con leer 0x11000000
 *
 * Portado de firmware/src/psram.rs, que lleva 8 MB funcionando en el cartucho.
 * Solo cambia el GPIO. Los registros salen de las cabeceras del pico-sdk: aqui
 * inventarse una direccion se paga muy caro.
 *
 * LOS RESULTADOS SON GLOBALES A PROPOSITO. Con SWD puesto se leen directamente
 * y no hay que descifrar parpadeos:
 *
 *     probe-rs read b32 --chip RP235x <&uvm2_psram_result> 8
 */

#include <stdint.h>
#include "hardware/address_mapped.h"
#include "hardware/flash.h"
#include "pico/bootrom.h"
#include "hardware/structs/qmi.h"
#include "hardware/structs/pads_bank0.h"
#include "hardware/structs/io_bank0.h"
#include "hardware/regs/qmi.h"
#include "hardware/structs/sio.h"
#include "uvm2_psram.h"

/* GPIO47 = PSRAM_CS en el UVM2 (pin 58). En nuestro cartucho es el 0. */
#define PSRAM_CS_GPIO   47u
/* Tabla 3 del datasheet: F9 en GPIO 0/8/19/47 es QMI CS1n. */
#define FUNCSEL_QMI_CS1N 9u

#define CMD_RESET_ENABLE 0x66u
#define CMD_RESET        0x99u
#define CMD_READ_ID      0x9Fu
/* APS6404: 0x35 entra en QPI, 0xF5 sale. En QPI el chip IGNORA los comandos de
 * una linea, que es exactamente lo que veiamos: transferencia real (rx_timeouts
 * = 0, BUSY y CS1 correctos) y respuesta 0x00. Y el cartucho lleva USB-C, asi
 * que apagar la consola no le quita la corriente: puede seguir en QPI de una
 * sesion anterior, incluidas nuestras propias sondas. */
#define CMD_EXIT_QPI     0xF5u
/* AP Memory. Es lo que responde el chip de nuestro cartucho. */
#define AP_MF_ID         0x0Du

/* Un dispositivo que no contesta no puede colgar el cartucho. */
#define QMI_SPIN_LIMIT   1000000u

/* La ventana XIP de CS1. */
#define PSRAM_XIP_BASE   0x11000000u

/* Valor de reset de M1_RFMT. Si difiere, alguien configuro CS1 antes que nosotros. */
#define QMI_M1_RFMT_RESET 0x00001000u

volatile uvm2_psram_result_t uvm2_psram_result;

static void spin(uint32_t n) { while (n--) __asm volatile ("nop"); }

/* Los pads del RP2350 arrancan AISLADOS, y un pad con ISO puesto no hace nada
 * diga lo que diga el FUNCSEL. Esto ya nos costo una sesion entera: el CS1 no
 * conducia y el autodiagnostico leia 0xFF sin una sola pista. */
static void configure_cs1_pad(void)
{
    pads_bank0_hw->io[PSRAM_CS_GPIO] &= ~PADS_BANK0_GPIO0_ISO_BITS;
    pads_bank0_hw->io[PSRAM_CS_GPIO] |=  PADS_BANK0_GPIO0_IE_BITS;
    pads_bank0_hw->io[PSRAM_CS_GPIO] &= ~PADS_BANK0_GPIO0_OD_BITS;
    io_bank0_hw->io[PSRAM_CS_GPIO].ctrl = FUNCSEL_QMI_CS1N;
}

static void direct_begin(void)
{
    uint32_t spins = 0;
    qmi_hw->direct_csr |= QMI_DIRECT_CSR_EN_BITS;
    /* Esperar a que termine cualquier transferencia XIP en curso. */
    while ((qmi_hw->direct_csr & QMI_DIRECT_CSR_BUSY_BITS) && ++spins < QMI_SPIN_LIMIT) { }
}

static void direct_end(void)
{
    /* Soltar CS1 ANTES de apagar: ASSERT_CSxN sigue aplicando con EN a cero, y
     * un chip select colgado corromperia las lecturas XIP de la flash en CS0. */
    qmi_hw->direct_csr &= ~QMI_DIRECT_CSR_ASSERT_CS1N_BITS;
    qmi_hw->direct_csr &= ~QMI_DIRECT_CSR_EN_BITS;
}

static void tx(uint8_t byte)
{
    uint32_t spins = 0;
    while ((qmi_hw->direct_csr & QMI_DIRECT_CSR_TXFULL_BITS) && ++spins < QMI_SPIN_LIMIT) { }
    qmi_hw->direct_tx = byte;
}

static uint8_t rx(void)
{
    uint32_t spins = 0;
    while ((qmi_hw->direct_csr & QMI_DIRECT_CSR_RXEMPTY_BITS) && ++spins < QMI_SPIN_LIMIT) { }
    if (spins >= QMI_SPIN_LIMIT) uvm2_psram_result.rx_timeouts++;
    return (uint8_t)qmi_hw->direct_rx;
}

/* Una transaccion sobre CS1: asertar, sacar `cmd`, meter `n_rx` bytes, soltar.
 * El QMI es full-duplex, asi que cada byte enviado produce uno recibido; los de
 * la fase de comando se tiran. */
/* Un byte suelto en QUAD. En cuatro lineas hay que encender la salida (OE): en
 * una sola, SD0 es salida siempre y por eso no hacia falta. */
static void cs1_xfer_quad1(uint8_t byte)
{
    qmi_hw->direct_csr |= QMI_DIRECT_CSR_ASSERT_CS1N_BITS;
    uint32_t spins = 0;
    while ((qmi_hw->direct_csr & QMI_DIRECT_CSR_TXFULL_BITS) && ++spins < QMI_SPIN_LIMIT) { }
    qmi_hw->direct_tx = QMI_DIRECT_TX_OE_BITS
                      | (QMI_DIRECT_TX_IWIDTH_VALUE_Q << QMI_DIRECT_TX_IWIDTH_LSB)
                      | byte;
    spins = 0;
    while ((qmi_hw->direct_csr & QMI_DIRECT_CSR_BUSY_BITS) && ++spins < QMI_SPIN_LIMIT) { }
    qmi_hw->direct_csr &= ~QMI_DIRECT_CSR_ASSERT_CS1N_BITS;
}

static void cs1_xfer(const uint8_t *cmd, uint32_t n_cmd, uint8_t *rx_buf, uint32_t n_rx)
{
    qmi_hw->direct_csr |= QMI_DIRECT_CSR_ASSERT_CS1N_BITS;   /* 1 = ASERTADO (bajo) */
    for (uint32_t i = 0; i < n_cmd; i++) {
        tx(cmd[i]);
        if (i == 0) uvm2_psram_result.csr_after_cmd = qmi_hw->direct_csr;
        (void)rx();
    }
    for (uint32_t i = 0; i < n_rx;  i++) { tx(0x00);   rx_buf[i] = rx(); }
    qmi_hw->direct_csr &= ~QMI_DIRECT_CSR_ASSERT_CS1N_BITS;
}

/* ---- CS EN CONTINUA, PARA EL POLIMETRO -------------------------------------
 *
 * QUE HUECO TAPA. La tabla del 2026-08-12 da por bueno que el QMI conduce CS1
 * porque durante la transaccion se leen EN=1, ASSERT_CS1N=1 y BUSY=1 — pero eso
 * son REGISTROS INTERNOS, no la pata. Y la comprobacion de continuidad de la
 * linea se hizo manejandola como GPIO, que prueba la PISTA, no el camino del
 * QMI hasta ella. Nadie ha medido nunca la pata 1 de U3 mientras el QMI la
 * conduce, y esa es la primera bifurcacion del arbol que queda.
 *
 * POR QUE EN CONTINUA. Un CS que conmuta durante 2 us no lo ve un polimetro, y
 * el osciloscopio en esta placa exige desmontar y UNA SOLA pinza de masa (dos en
 * nodos distintos ya destrozaron una consola). Manteniendolo asertado
 * indefinidamente la medida es de continua y la hace cualquier polimetro:
 *
 *     asertado    -> pata 1 de U3 a ~0 V   : el QMI SI llega al chip. Lo que
 *                                            queda es el chip o su die.
 *     asertado    -> pata 1 a ~3,3 V       : el QMI NO conduce la pata pese a
 *                                            que los registros digan que si.
 *                                            El fallo esta antes del chip.
 *     sin asertar -> pata 1 a ~3,3 V       : control, por el pull-up R6.
 *
 * NO SE PUEDE VOLVER de aqui: deja CS1 asertado a proposito, que es lo que hace
 * medible la prueba. Se sale reseteando.
 */
void uvm2_psram_hold_cs(int asertado)
{
    configure_cs1_pad();
    qmi_hw->direct_csr |= QMI_DIRECT_CSR_EN_BITS;
    uint32_t spins = 0;
    while ((qmi_hw->direct_csr & QMI_DIRECT_CSR_BUSY_BITS) && ++spins < QMI_SPIN_LIMIT) { }
    if (asertado) qmi_hw->direct_csr |=  QMI_DIRECT_CSR_ASSERT_CS1N_BITS;
    else          qmi_hw->direct_csr &= ~QMI_DIRECT_CSR_ASSERT_CS1N_BITS;
    uvm2_psram_result.csr_after_cmd = qmi_hw->direct_csr;   /* releido, no supuesto */
}

/* ---- LA SONDA DEL BOOTROM ---------------------------------------------------
 *
 * QUE LE FALTABA A LA OTRA. La sonda de abajo le habla al chip por modo directo,
 * a mano, y midio que el QMI SI transfiere (rx_timeouts = 0, CS1 y BUSY
 * correctos) y que el chip calla — a 25, 12,5, 5 y 1,25 MHz. De ahi salio
 * "software agotado, toca osciloscopio". Era falso, y lo dice nuestro propio
 * SDK en hardware/flash.h:
 *
 *   "The ROM uses this device information to control some low-level flash API
 *    behaviour, such as issuing an XIP exit sequence to CS 1 IF ITS SIZE IS
 *    NONZERO."
 *
 * FLASH_DEVINFO da NONE a CS1 mientras la OTP no diga otra cosa, asi que **esa
 * secuencia no se le ha mandado nunca a la PSRAM**: ni el bootrom, ni el
 * firmware del multicart (Ralf: "I actually never used it so far"), ni nosotros.
 * Y encaja con lo que la otra sonda ya sospechaba: un APS6404 en QPI ignora las
 * ordenes de una linea, el cartucho lleva USB-C y no se queda sin corriente al
 * apagar la consola, asi que puede llevar en QPI desde nuestras propias sondas.
 * Bajar el reloj no destapa eso: no es un problema de velocidad, es de idioma.
 *
 * Asi que aqui no inventamos nada. Se le dice a FLASH_DEVINFO que CS1 mide algo
 * y se deja que el bootrom haga SU secuencia. Es la pieza que el hardware_psram
 * del pico-sdk 2.3.0 usa para lo mismo (psram_detect_size), portada a nuestro
 * 2.2.0 con API publica y sin tocar el SDK.
 *
 * NO ESCRIBE NADA EN LA FLASH. Las dos ordenes que salen de aqui son 0x9F,
 * lecturas de identificador; flash_do_cmd deja el XIP como estaba al terminar.
 */
#define AP_KGD_ID  0x5Du   /* known good die; es lo que mira el SDK, no el MF ID */

/* Del EID al tamaño, igual que psram_eid_to_size() del 2.3.0. */
static uint32_t eid_a_tam(uint8_t kgd, uint8_t eid)
{
    if (kgd != AP_KGD_ID) return 0;
    uint32_t mb = 1u << 20;
    uint8_t  s  = (uint8_t)(eid >> 5);
    if (s == 4)                          return mb * 16u;
    if (eid == 0x26 || s == 2 || s == 3) return mb * 8u;
    if (s == 1)                          return mb * 4u;
    return mb * 2u;
}

/* flash_do_cmd() del SDK, con el chip select como parametro.
 *
 * NO ES UNA COPIA POR GUSTO. Hacen falta dos cosas que el SDK no da aqui:
 *   - CS1. flash_do_cmd fija CS0 a pelo; la version con parametro es
 *     flash_do_cmd_cs, y esa no llega hasta el pico-sdk 2.3.0.
 *   - Que exista. Todo el bloque vive dentro de `#if !PICO_NO_FLASH` y nuestras
 *     imagenes son no_flash, asi que el enlace no lo encuentra — comprobado.
 * Lo que se copia es la secuencia, y solo usa API publica de pico/bootrom.h.
 *
 * El paso que importa es rom_flash_exit_xip(), y su documentacion en
 * pico/bootrom.h dice ademas que rom_connect_internal_flash() inicializa el GPIO
 * del segundo chip select "si se ha configurado por OTP o ESCRIBIENDO LA COPIA
 * EN BOOTRAM DE FLASH_DEVINFO". O sea que el bootrom nos pone hasta el pad. */
/* Migas: el ultimo valor que sobreviva en paso_bootrom es el paso que no volvio.
 * Un cuelgue no deja traza salvo la que le dejes puesta de antemano — esta sonda
 * ya se colgo una vez y lo unico que se supo fue "en alguna de seis llamadas". */
#define PASO_ENTRA        1
#define PASO_CONNECT      2   /* va a llamar a rom_connect_internal_flash */
#define PASO_EXIT_XIP     3   /* va a llamar a rom_flash_exit_xip         */
#define PASO_BUCLE        4   /* va a mover los bytes                     */
#define PASO_FLUSH        5   /* va a llamar a rom_flash_flush_cache      */
#define PASO_ENTER_XIP    6   /* va a llamar a rom_flash_enter_cmd_xip    */
#define PASO_SALE         7
static uint32_t n_llamada = 0;
#define MIGA(p) (uvm2_psram_result.paso_bootrom = n_llamada * 100u + (p))

static void do_cmd_cs(const uint8_t *tx, uint8_t *rx, uint32_t count, int cs)
{
    const uint32_t cs_bit = cs ? QMI_DIRECT_CSR_ASSERT_CS1N_BITS
                               : QMI_DIRECT_CSR_ASSERT_CS0N_BITS;
    uint32_t txr = count, rxr = count, spins = 0;

    n_llamada++;
    MIGA(PASO_ENTRA);

    MIGA(PASO_CONNECT);
    rom_connect_internal_flash();
    MIGA(PASO_EXIT_XIP);
    rom_flash_exit_xip();
    MIGA(PASO_BUCLE);

    hw_set_bits(&qmi_hw->direct_csr, cs_bit);
    hw_set_bits(&qmi_hw->direct_csr, QMI_DIRECT_CSR_EN_BITS);
    /* El QMI se atasca solo cuando DIRECT_RX se llena, asi que no hay que contar
     * cuantos van en vuelo — pero el limite de vueltas se queda: un dispositivo
     * que no contesta no puede colgar el cartucho. */
    while ((txr || rxr) && ++spins < QMI_SPIN_LIMIT) {
        uint32_t f = qmi_hw->direct_csr;
        if (txr && !(f & QMI_DIRECT_CSR_TXFULL_BITS))  { qmi_hw->direct_tx = *tx++; txr--; }
        if (rxr && !(f & QMI_DIRECT_CSR_RXEMPTY_BITS)) { *rx++ = (uint8_t)qmi_hw->direct_rx; rxr--; }
    }
    if (spins >= QMI_SPIN_LIMIT) uvm2_psram_result.rx_timeouts++;
    /* Soltar el select ANTES de apagar, por lo mismo que direct_end(). */
    hw_clear_bits(&qmi_hw->direct_csr, cs_bit);
    hw_clear_bits(&qmi_hw->direct_csr, QMI_DIRECT_CSR_EN_BITS);

    MIGA(PASO_FLUSH);
    rom_flash_flush_cache();
    MIGA(PASO_ENTER_XIP);
    rom_flash_enter_cmd_xip();
    MIGA(PASO_SALE);
}

/* READ_ID por CS0, a la flash. Es el control positivo: si esto no contesta
 * EF 40 18, el que esta roto es el camino y no el chip de CS1. */
static uint32_t jedec_de_la_flash(void)
{
    const uint8_t tx[4] = { CMD_READ_ID, 0x00, 0x00, 0x00 };
    uint8_t       rx[4] = { 0, 0, 0, 0 };
    do_cmd_cs(tx, rx, 4, 0);
    /* El 0x9F de una flash NO lleva direccion: contesta ya en el byte 1. */
    return ((uint32_t)rx[1] << 16) | ((uint32_t)rx[2] << 8) | rx[3];
}

/* ---- HABLARLE EN QPI --------------------------------------------------------
 *
 * Una transaccion ENTERA en cuatro lineas, con el select puesto de principio a
 * fin. Es lo que faltaba: cs1_xfer_quad1() mandaba UN byte suelto y volvia a una
 * linea, asi que nunca se le ha leido nada al chip en su propio idioma.
 *
 * La fase de mando lleva OE puesto (nosotros conducimos las cuatro lineas); la
 * de datos lo quita, para que conduzca el chip. En una linea no hacia falta
 * porque SD0 es salida siempre — de ahi que la sonda vieja se apañara sin ello.
 */
#define CMD_ENTER_QPI    0x35u

/* CLKDIV vive en DIRECT_CSR, asi que se cambia con el modo directo APAGADO.
 * Ponerlo con EN puesto no da error: se queda el de antes, en silencio. */
static void reloj_directo(uint32_t div)
{
    uint32_t csr = qmi_hw->direct_csr & ~QMI_DIRECT_CSR_EN_BITS;
    csr = (csr & ~QMI_DIRECT_CSR_CLKDIV_BITS)
        | (div << QMI_DIRECT_CSR_CLKDIV_LSB);
    qmi_hw->direct_csr = csr;
}

static void cs1_qpi(const uint8_t *cmd, uint32_t n_cmd, uint8_t *rx, uint32_t n_rx)
{
    const uint32_t Q = QMI_DIRECT_TX_IWIDTH_VALUE_Q << QMI_DIRECT_TX_IWIDTH_LSB;
    uint32_t spins;

    qmi_hw->direct_csr |= QMI_DIRECT_CSR_ASSERT_CS1N_BITS;

    for (uint32_t i = 0; i < n_cmd; i++) {
        spins = 0;
        while ((qmi_hw->direct_csr & QMI_DIRECT_CSR_TXFULL_BITS) && ++spins < QMI_SPIN_LIMIT) { }
        /* NOPUSH: la fase de mando no produce dato que valga, y sin esto llena
         * el FIFO de recepcion y desalinea todo lo que viene detras. */
        qmi_hw->direct_tx = QMI_DIRECT_TX_OE_BITS | QMI_DIRECT_TX_NOPUSH_BITS | Q | cmd[i];
    }
    for (uint32_t i = 0; i < n_rx; i++) {
        spins = 0;
        while ((qmi_hw->direct_csr & QMI_DIRECT_CSR_TXFULL_BITS) && ++spins < QMI_SPIN_LIMIT) { }
        qmi_hw->direct_tx = Q | 0xffu;          /* sin OE: ahora conduce el chip */
        spins = 0;
        while ((qmi_hw->direct_csr & QMI_DIRECT_CSR_RXEMPTY_BITS) && ++spins < QMI_SPIN_LIMIT) { }
        if (spins >= QMI_SPIN_LIMIT) uvm2_psram_result.rx_timeouts++;
        rx[i] = (uint8_t)qmi_hw->direct_rx;
    }

    spins = 0;
    while ((qmi_hw->direct_csr & QMI_DIRECT_CSR_BUSY_BITS) && ++spins < QMI_SPIN_LIMIT) { }
    qmi_hw->direct_csr &= ~QMI_DIRECT_CSR_ASSERT_CS1N_BITS;
}

static void empaqueta(uint8_t *b, volatile uint32_t *dst)
{
    dst[0] = ((uint32_t)b[0] << 24) | ((uint32_t)b[1] << 16) | ((uint32_t)b[2] << 8) | b[3];
    dst[1] = ((uint32_t)b[4] << 24) | ((uint32_t)b[5] << 16) | ((uint32_t)b[6] << 8) | b[7];
}

int uvm2_psram_probe_qpi(void)
{
    volatile uvm2_psram_result_t *r = &uvm2_psram_result;
    /* 0x9F + 24 bits de direccion, todo en quad. Se leen OCHO bytes y se
     * guardan crudos: los ciclos de espera del 0x9F en QPI no los tenemos
     * medidos, y suponer una posicion convierte un desfase de un byte en un
     * "chip mudo". Que aparezca 0d 5d en la tira ya es la respuesta. */
    const uint8_t c_id[4] = { CMD_READ_ID, 0x00, 0x00, 0x00 };
    uint8_t       b[8];

    /* Abajo el centinela: esta corre la ULTIMA, asi que si se colgara aqui, el
     * que dejo puesto uvm2_psram_probe() daria la estructura por completa. */
    r->magic = 0;

    /* EL RELOJ, A MANO Y APUNTADO.
     *
     * La primera version de esta sonda no lo tocaba, y heredaba el CLKDIV = 120
     * con el que uvm2_psram_probe() termina su barrido y no restaura. A 1,25 MHz
     * los doce bytes de la transaccion en quad son ~19 us con el select BAJO, y
     * el **tCEM del APS6404 son 8 us**: el chip tiene derecho a abandonar a
     * mitad. O sea que la unica prueba que ataca la hipotesis del idioma la
     * estaba corriendo fuera de especificacion.
     *
     * CLKDIV 6 = 25 MHz: 12 bytes en quad son 24 relojes ~= 1 us, holgado. Y se
     * guarda el divisor en el resultado, para no volver a deducirlo nunca. */
    r->qpi_clkdiv = 6;
    reloj_directo(6);

    configure_cs1_pad();

    /* A. Tal cual esta. Si lleva en QPI desde una sonda anterior, contesta. */
    for (int i = 0; i < 8; i++) b[i] = 0;
    direct_begin();
    cs1_qpi(c_id, 4, b, 8);
    direct_end();
    empaqueta(b, r->qpi_directo);

    /* B. Y si estaba en SPI: se le mete en QPI con 0x35 —en UNA linea, que es
     *    donde se escucha ese mando— y se vuelve a preguntar en quad. Entre A y
     *    B queda cubierto el idioma en los dos sentidos. */
    {
        const uint8_t c35[1] = { CMD_ENTER_QPI };
        direct_begin();
        cs1_xfer(c35, 1, 0, 0);
        direct_end();
        spin(30000);
    }
    for (int i = 0; i < 8; i++) b[i] = 0;
    direct_begin();
    cs1_qpi(c_id, 4, b, 8);
    direct_end();
    empaqueta(b, r->qpi_tras_35);

    /* C. Y otra vez a 5 MHz (12 bytes ~= 5 us, todavia por debajo de tCEM).
     *    Dos velocidades separan "no me oye" de "no me da tiempo", que a estas
     *    alturas es la unica distincion que queda por hacer sin instrumentos. */
    r->qpi_clkdiv_lento = 30;
    reloj_directo(30);
    for (int i = 0; i < 8; i++) b[i] = 0;
    direct_begin();
    cs1_qpi(c_id, 4, b, 8);
    direct_end();
    empaqueta(b, r->qpi_lento);

    r->qpi_probe_run = 1;

    /* ---- MODO SONDA PARA EL OSCILOSCOPIO (-DUVM2_PSRAM_BUCLE) --------------
     *
     * Todo lo de arriba dura ~1 us y pasa UNA vez en el arranque. En un
     * osciloscopio de dos canales eso no se captura: no hay con que disparar.
     * Con esto la misma transaccion se repite para siempre, con un hueco entre
     * ráfagas, y el disparo por flanco de /CS es trivial.
     *
     * El juego NO arranca en este modo, a proposito: la imagen es un
     * instrumento, no un cartucho. Que la pantalla se quede negra es la señal
     * de que estas en el modo correcto.
     *
     * Que se mide, y en este orden (referencia antes que sospechoso, mismo
     * montaje, misma sonda):
     *   1. SCK en U6 pata 6 — la flash, que funciona. Es la regla.
     *   2. SCK en U3 pata 6 — ¿llega el mismo reloj al chip mudo?
     *   3. /CS en U3 pata 1 — ¿se asierta? Si U3 es dificil de pinchar, el pad
     *      de R6 esta en la MISMA red y es mucho mas grande; sirve de
     *      referencia, pero NO sustituye a la pata: lo que esta en duda es
     *      justo el ultimo salto.
     */
#ifdef UVM2_PSRAM_BUCLE
    for (;;) {
        direct_begin();
        cs1_qpi(c_id, 4, b, 8);
        direct_end();
        /* Hueco largo y limpio entre ráfagas: separa una de otra en pantalla y
         * deja que el disparo se rearme sin cazar el final de la anterior. */
        spin(200000);
    }
#endif
    r->magic = UVM2_PSRAM_MAGIC;   /* esta es la ultima que corre */
    return (r->qpi_directo[0] || r->qpi_tras_35[0]) ? 1 : 0;
}

int uvm2_psram_probe_bootrom(void)
{
    volatile uvm2_psram_result_t *r = &uvm2_psram_result;
    /* Esta sonda corre la SEGUNDA, y por eso el centinela se baja aqui y se
     * vuelve a subir al final: si no, uvm2_psram_probe() lo habria dejado
     * puesto con la mitad nueva de la estructura todavia sin escribir, y una
     * lectura por SWD entre medias pasaria por buena. */
    r->magic = 0;

    /* 1. El control, ANTES de tocar CS1: asi su valor no depende de nada que
     *    hagamos despues. Un control que se mide al final no es un control. */
    r->flash_jedec = jedec_de_la_flash();

    /* 2. Declarar CS1. El tamaño da igual mientras no sea NONE — el bootrom solo
     *    mira si es cero para decidir si manda la secuencia. */
    r->devinfo_cs1_before = flash_devinfo_get_cs_size(1);
    flash_devinfo_set_cs_gpio(1, PSRAM_CS_GPIO);
    flash_devinfo_set_cs_size(1, FLASH_DEVINFO_SIZE_8M);

    /* 3. El pad, o el CS1 no conduce por mucho FUNCSEL que tenga. */
    configure_cs1_pad();

    /* 4. Y ahora una orden cualquiera. LO QUE IMPORTA NO ES LA ORDEN: es que
     *    flash_do_cmd llama a connect_internal_flash() + flash_exit_xip() del
     *    bootrom, y esa salida de XIP alcanza AHORA tambien a CS1. De paso
     *    vuelve a leer el control, que debe salir igual que en el paso 1. */
    r->flash_jedec_tras_cs1 = jedec_de_la_flash();

    /* 5. Al chip, en una linea, por el MISMO camino que acaba de contestar bien
     *    en CS0. Si estaba en QPI, la salida de XIP del bootrom ya lo ha sacado.
     *
     *    Ocho bytes y no seis, igual que psram_detect_size() del 2.3.0: el 0x9F
     *    del APS6404 SI lleva tres bytes de direccion, asi que los datos empiezan
     *    en el 4 — MF_ID, KGD, EID. Contar mal esas posiciones da un cero que
     *    parece un chip mudo. */
    {
        const uint8_t c_id[8] = { CMD_READ_ID, 0xff, 0xff, 0xff,
                                  0xff, 0xff, 0xff, 0xff };
        uint8_t       id[8]   = { 0 };
        do_cmd_cs(c_id, id, 8, 1);
        r->mf_id_bootrom = id[4];
        r->kgd_bootrom   = id[5];
        r->eid_bootrom   = id[6];
        /* El SDK mira el KGD, no el fabricante. Nosotros mirabamos el MF_ID. */
        r->found_bootrom = (id[5] == AP_KGD_ID);
        r->tam_bootrom   = eid_a_tam(id[5], id[6]);
    }

    /* 6. FLASH_DEVINFO, como estaba. Esto es una SONDA: contesta la pregunta y
     *    devuelve la maquina al estado en que la encontro. Quien quiera montar
     *    la ventana lo hara a proposito y con el resultado delante. */
    flash_devinfo_set_cs_size(1, (flash_devinfo_size_t)r->devinfo_cs1_before);

    r->bootrom_probe_run = 1;
    r->magic = UVM2_PSRAM_MAGIC;   /* al final, con todo escrito */
    return (int)r->found_bootrom;
}

int uvm2_psram_probe(void)
{
    volatile uvm2_psram_result_t *r = &uvm2_psram_result;
    r->magic = 0;   /* se pone AL FINAL: una estructura a medio llenar no vale */

    /* 1. NO SE TOCA LA VENTANA XIP TODAVIA.
     *
     *    La primera version leia 0x11000000 lo primero, "para ver si ya estaba
     *    mapeada". Con CS1 SIN configurar esa lectura deja el QMI colgado: se
     *    leyo DIRECT_CSR = 0x01810802 al entrar, o sea BUSY = 1 con EN = 0. A
     *    partir de ahi direct_begin agota su millon de vueltas esperando a que
     *    BUSY baje, sigue igualmente, y rx() no ve nunca un dato: devuelve 0x00.
     *
     *    O sea que el 0x00 del READ_ID —y los 0xcccccccc de la ventana— los
     *    causaba MIRAR. Primero los registros, que leerlos no cuesta nada. */
    /* 2. El estado del QMI AL ENTRAR. Esto va ANTES que nada, y su ausencia fue
     *    el error de la primera version: se leyeron los M1 DESPUES de sondear y
     *    salieron configurados, lo cual no distingue "venia asi del firmware" de
     *    "lo dejamos asi nosotros". Un registro leido tarde no es evidencia. */
    r->m1_timing_before  = qmi_hw->m[1].timing;
    r->m1_rfmt_before    = qmi_hw->m[1].rfmt;
    r->m1_rcmd_before    = qmi_hw->m[1].rcmd;
    r->direct_csr_before = qmi_hw->direct_csr;

    /* 3. Si CS1 YA esta configurado, el firmware la ha levantado y el chip estara
     *    en QPI. Mandarle ahi comandos SPI de una linea no es inofensivo: se
     *    interpretan como otra cosa y rompen lo que habia montado (paso, y la
     *    ventana empezo a devolver 0xcccccccc). Asi que no se toca. */
    if (r->m1_rfmt_before != QMI_M1_RFMT_RESET) {
        /* Solo AHORA es seguro mirar la ventana: con CS1 configurado, leerla es
         * una lectura normal. */
        const volatile uint32_t *xip = (const volatile uint32_t *)PSRAM_XIP_BASE;
        for (int i = 0; i < 4; i++) r->xip_before[i] = xip[i];
        r->already_mapped = 1;
        r->probed = 1;
        r->magic  = UVM2_PSRAM_MAGIC;
        return 1;
    }

    /* 4. Nadie la ha levantado: la levantamos nosotros. */
    configure_cs1_pad();

    const uint8_t c_rsten[1] = { CMD_RESET_ENABLE };
    const uint8_t c_rst[1]   = { CMD_RESET };
    /* READ_ID lleva tres bytes de direccion antes de los datos. */
    const uint8_t c_id[4]    = { CMD_READ_ID, 0x00, 0x00, 0x00 };

    direct_begin();
    cs1_xfer(c_rsten, 1, 0, 0);
    cs1_xfer(c_rst,   1, 0, 0);
    direct_end();

    spin(30000);            /* asentamiento tras el reset */

    uint8_t id[2] = { 0, 0 };
    direct_begin();
    cs1_xfer(c_id, 4, id, 2);
    direct_end();

    r->mf_id_spi = id[0];

    /* Si en una linea no contesta, puede estar en QPI. Sacarlo de ahi y repetir.
     * Esto SI es seguro aunque no lo estuviera: 0xF5 en cuatro lineas a un chip
     * que escucha en una es un byte que no reconoce, no un cambio de modo. */
    if (id[0] != AP_MF_ID) {
        direct_begin();
        cs1_xfer_quad1(CMD_EXIT_QPI);
        direct_end();
        spin(30000);

        direct_begin();
        cs1_xfer(c_rsten, 1, 0, 0);
        cs1_xfer(c_rst,   1, 0, 0);
        direct_end();
        spin(30000);

        id[0] = id[1] = 0;
        direct_begin();
        cs1_xfer(c_id, 4, id, 2);
        direct_end();
        r->mf_id_after_qpi_exit = id[0];
    }

    /* Barrido de velocidad. CLKDIV vive en DIRECT_CSR, asi que se cambia con el
     * modo directo apagado y se vuelve a entrar. */
    {
        static const uint8_t divs[4] = { 6, 12, 30, 120 };
        for (int k = 0; k < 4; k++) {
            uint32_t csr = qmi_hw->direct_csr;
            csr = (csr & ~QMI_DIRECT_CSR_CLKDIV_BITS)
                | ((uint32_t)divs[k] << QMI_DIRECT_CSR_CLKDIV_LSB);
            qmi_hw->direct_csr = csr;

            direct_begin();
            cs1_xfer(c_rsten, 1, 0, 0);
            cs1_xfer(c_rst,   1, 0, 0);
            direct_end();
            spin(30000);

            uint8_t idk[2] = { 0, 0 };
            direct_begin();
            cs1_xfer(c_id, 4, idk, 2);
            direct_end();

            r->clkdiv_probados[k] = divs[k];
            r->id_por_clkdiv[k]   = ((uint32_t)idk[0] << 8) | idk[1];
        }
    }

    /* El cable, ya que el chip no habla. FUNCSEL 5 = SIO. */
    io_bank0_hw->io[PSRAM_CS_GPIO].ctrl = 5u;
    sio_hw->gpio_hi_oe_set = 1u << (PSRAM_CS_GPIO - 32);
    sio_hw->gpio_hi_set    = 1u << (PSRAM_CS_GPIO - 32);
    spin(2000);
    r->cs_reads_when_high  = (sio_hw->gpio_hi_in >> (PSRAM_CS_GPIO - 32)) & 1u;
    sio_hw->gpio_hi_clr    = 1u << (PSRAM_CS_GPIO - 32);
    spin(2000);
    r->cs_reads_when_low   = (sio_hw->gpio_hi_in >> (PSRAM_CS_GPIO - 32)) & 1u;
    /* Y ahora el indicio de continuidad: soltar la salida con los pull internos
     * APAGADOS, para que mande la red de fuera y no nosotros. */
    {
        uint32_t pad = pads_bank0_hw->io[PSRAM_CS_GPIO];
        pads_bank0_hw->io[PSRAM_CS_GPIO] = (pad & ~(PADS_BANK0_GPIO0_PUE_BITS |
                                                    PADS_BANK0_GPIO0_PDE_BITS))
                                         | PADS_BANK0_GPIO0_IE_BITS;
        /* conducido a CERO, y soltamos: si hay pull-up externo, sube solo */
        sio_hw->gpio_hi_oe_set = 1u << (PSRAM_CS_GPIO - 32);
        sio_hw->gpio_hi_clr    = 1u << (PSRAM_CS_GPIO - 32);
        spin(2000);
        sio_hw->gpio_hi_oe_clr = 1u << (PSRAM_CS_GPIO - 32);
        spin(20000);
        r->cs_float_tras_bajo = (sio_hw->gpio_hi_in >> (PSRAM_CS_GPIO - 32)) & 1u;

        /* control: conducido a UNO y soltado. Aqui deberia leer 1 en los dos
         * casos, asi que solo sirve para ver que la lectura no esta pegada. */
        sio_hw->gpio_hi_oe_set = 1u << (PSRAM_CS_GPIO - 32);
        sio_hw->gpio_hi_set    = 1u << (PSRAM_CS_GPIO - 32);
        spin(2000);
        sio_hw->gpio_hi_oe_clr = 1u << (PSRAM_CS_GPIO - 32);
        spin(20000);
        r->cs_float_tras_alto = (sio_hw->gpio_hi_in >> (PSRAM_CS_GPIO - 32)) & 1u;

        pads_bank0_hw->io[PSRAM_CS_GPIO] = pad;   /* el pad, como estaba */
    }

    /* Dejarlo como estaba: soltar y devolver el pin al QMI. */
    sio_hw->gpio_hi_oe_clr = 1u << (PSRAM_CS_GPIO - 32);
    io_bank0_hw->io[PSRAM_CS_GPIO].ctrl = FUNCSEL_QMI_CS1N;

    r->mf_id  = id[0];
    r->kgd    = id[1];
    r->found  = (id[0] == AP_MF_ID);
    r->probed = 1;
    r->magic  = UVM2_PSRAM_MAGIC;

    /* A PROPOSITO no se arma la ventana XIP ni se escribe nada. Esto es una
     * SONDA: primero hay que saber que chip hay y si alguien lo habia levantado
     * ya. Armarla sin saberlo podria pisar lo que el firmware del multicart
     * tenga montado en CS1, y este cartucho no es nuestro. */
    return r->found;
}
