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
