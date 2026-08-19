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
#include "hardware/clocks.h"
#include "uvm2_psram.h"

/* GPIO47 = PSRAM_CS en el UVM2 (pin 58). En nuestro cartucho es el 0. */
#define PSRAM_CS_GPIO   47u
/* Tabla 3 del datasheet: F9 en GPIO 0/8/19/47 es QMI CS1n. */
#define FUNCSEL_QMI_CS1N 9u

#define CMD_RESET_ENABLE 0x66u
#define CMD_RESET        0x99u
#define CMD_READ_ID      0x9Fu
/* Comandos quad, para la ventana XIP (no hacian falta en la sonda). */
#define CMD_QUAD_READ  0xEBu
#define CMD_QUAD_WRITE 0x38u
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

/* OE ENCENDIDO TAMBIEN EN UNA LINEA.
 *
 * Aqui habia una SUPOSICION escrita como si fuera un hecho: "en una sola linea SD0 es
 * salida siempre y por eso no hacia falta". Si es falsa, nunca hemos conducido MOSI —
 * y entonces ningun chip recibe nada y leemos el bus en reposo: 0x00 en una linea,
 * 0xcc en quad. Que es EXACTAMENTE lo que llevamos viendo.
 *
 * Lo que la delato: la misma transaccion contra la FLASH, que sabemos buena porque el
 * firmware arranca de ella, tambien devuelve cero. Con los dos chips mudos por el mismo
 * camino, el sospechoso deja de ser el chip.
 *
 * `uvm2_tx_oe` permite apagarlo para comparar A/B sin recompilar. */
/* EL DIVISOR DEL RELOJ DEL MODO DIRECTO. Sin fijarlo, DIRECT_CSR conserva lo que
 * tuviera, y con CLKDIV a cero NO HAY RELOJ: el QMI no transfiere nada, ningun chip
 * recibe nada, y todo el mundo parece mudo.
 *
 * MEDIDO CON OSCILOSCOPIO el 2026-08-19: con el martilleo corriendo, SCK y MOSI
 * PLANOS, milivoltios de ruido. Ni reloj ni dato. Y lo grave: la sonda original
 * (uvm2_psram_probe) TAMPOCO lo fijaba, asi que el diagnostico del 12 de agosto —"el
 * chip esta y no contesta"— se apoyaba en transacciones que quiza nunca se emitieron.
 * Solo las sondas QPI lo ponian, y son las unicas que llegaron a ver algo distinto
 * de cero (0xcc).
 *
 * 6 = 25 MHz a 150 MHz de reloj de sistema. */
#define RELOJ_DIRECTO_DIV 6u
static void reloj_directo(uint32_t div);

int uvm2_tx_oe = 1;

/* 1 = interroga al chip aunque la ventana ya este mapeada. Para poder correr el
 * camino completo donde el hardware SI funciona y comparar. */
int uvm2_psram_forzar = 0;

static void tx(uint8_t byte)
{
    uint32_t spins = 0;
    while ((qmi_hw->direct_csr & QMI_DIRECT_CSR_TXFULL_BITS) && ++spins < QMI_SPIN_LIMIT) { }
    qmi_hw->direct_tx = uvm2_tx_oe ? (QMI_DIRECT_TX_OE_BITS | byte) : (uint32_t)byte;
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
    reloj_directo(RELOJ_DIRECTO_DIV);   /* sin esto no hay reloj */
    configure_cs1_pad();
    qmi_hw->direct_csr |= QMI_DIRECT_CSR_EN_BITS;
    uint32_t spins = 0;
    while ((qmi_hw->direct_csr & QMI_DIRECT_CSR_BUSY_BITS) && ++spins < QMI_SPIN_LIMIT) { }
    if (asertado) qmi_hw->direct_csr |=  QMI_DIRECT_CSR_ASSERT_CS1N_BITS;
    else          qmi_hw->direct_csr &= ~QMI_DIRECT_CSR_ASSERT_CS1N_BITS;
    uvm2_psram_result.csr_after_cmd = qmi_hw->direct_csr;   /* releido, no supuesto */
}

/* ---- LA REFERENCIA: LA MISMA PREGUNTA, A LA FLASH ------------------------
 *
 * REFERENCIA ANTES QUE SOSPECHOSO, MISMO MONTAJE. La flash U6 comparte SCK, MOSI y
 * MISO con la PSRAM y funciona — de ella arranca el firmware. Asi que si le pedimos su
 * JEDEC ID por EL MISMO modo directo, el mismo codigo y las mismas patas, cambiando
 * solo cual de los dos selects se aserta, el resultado parte el problema en dos:
 *
 *   la flash CONTESTA  -> el camino (reloj, MOSI, muestreo de MISO, modo directo) es
 *                         bueno. Lo que falla esta en U3 o en sus soldaduras.
 *   la flash CALLA     -> nuestro modo directo esta mal, y U3 lleva todo este tiempo
 *                         acusado por un fallo que es nuestro.
 *
 * NO PASA POR EL BOOTROM. do_cmd_cs() de abajo si, y rom_flash_exit_xip() NO VUELVE en
 * este cartucho (medido el 2026-08-17). Esta imagen corre entera desde SRAM, asi que
 * tomar el bus no molesta a nadie y no hace falta salir del XIP.
 *
 * Devuelve los tres bytes del ID empaquetados: (b0<<16)|(b1<<8)|b2. Una W25Q128 da
 * 0xEF4018; 0x000000 o 0xFFFFFF es "no contesta".
 */
/* Dejar la FLASH en un estado conocido: salir de lectura continua y resetearla.
 *
 * POR QUE IMPORTA PARA LA PSRAM. El codigo de la sonda es correcto —probado en nuestro
 * cartucho: mf_id 0x0D, kgd 0x5D— asi que lo que cambia en el UVM2 es el ENTORNO: la
 * imagen .um2 arranca sobre una maquina que configuro el firmware de Ralf, con su flash
 * en XIP y el QMI montado a su manera, en vez de poseerla desde el reset. Esto es el
 * primer intento de llegar al mismo punto de partida.
 *
 * Es seguro: la imagen corre entera desde SRAM, nadie esta leyendo de la flash, y al
 * reiniciar la bootrom la reinicializa. */
/* EL ESTADO QUE HEREDAMOS, tal cual, sin tocar nada.
 *
 * BUSY no se baja nunca en el UVM2 y si se baja en nuestro cartucho, con el MISMO
 * codigo. El QMI no se puede resetear (de el se arranca, no esta en el bloque de
 * resets) y el contador de stream del RP2040 no existe en el RP2350, asi que no hay
 * forma de desatascarlo a la fuerza. Lo que si se puede es MIRAR en que estado nos lo
 * dejan en cada placa y restar: eso ha resuelto dos cosas hoy.
 *
 * Se llama lo PRIMERO, antes de tocar nada, o se mide nuestro propio efecto. */
/* ENTRAR EN MODO DIRECTO SIN ENCALLAR EL QMI.
 *
 * En el UVM2 BUSY entra a CERO y se queda arriba EN CUANTO pedimos el modo directo:
 * no heredamos un QMI encallado, lo encallamos nosotros. La explicacion que encaja con
 * el volcado de las dos placas: al poner EN el QMI deja de servir XIP, y una lectura
 * XIP EN VUELO ya no puede terminar — el bus que la atenderia esta ocupado por el modo
 * directo. Bloqueo mutuo. Ralf lee la flash en 03h de UNA LINEA, que es lento, o sea
 * una ventana mucho mas ancha para pillar una lectura a medias; nuestro firmware hace
 * la init desde `.data` con el XIP en reposo y por eso nunca nos paso.
 *
 * `apagar_cache`: ademas de las barreras, apaga la cache del XIP antes de entrar, por
 * si lo que hay en vuelo es un relleno de linea y no una lectura del programa.
 *
 * Devuelve las vueltas que tardo BUSY en bajarse; el limite significa que no bajo.
 */
uint32_t uvm2_qmi_entrar_directo(int apagar_cache)
{
    volatile uint32_t *xip_ctrl = (volatile uint32_t *)0x400C8000u;
    uint32_t guardado = *xip_ctrl;
    uint32_t vueltas = 0;

    /* Sin interrupciones: una rutina de atencion que lea de la flash volveria a meter
     * una transferencia justo en el hueco que estamos intentando cerrar. */
    __asm volatile ("cpsid i" ::: "memory");

    if (apagar_cache) {
        *xip_ctrl = guardado & ~0x3u;      /* EN_SECURE | EN_NONSECURE */
        __asm volatile ("dsb" ::: "memory");
    }

    /* Que no quede NADA en vuelo antes de tomar el bus. */
    __asm volatile ("dsb" ::: "memory");
    __asm volatile ("isb" ::: "memory");

    qmi_hw->direct_csr |= QMI_DIRECT_CSR_EN_BITS;
    while ((qmi_hw->direct_csr & QMI_DIRECT_CSR_BUSY_BITS) && ++vueltas < 100000u) { }

    if (apagar_cache) *xip_ctrl = guardado;
    __asm volatile ("cpsie i" ::: "memory");
    return vueltas;
}

/* LEVANTAR EL QMI NOSOTROS. No hay entorno que heredar: el lanzador de Ralf copia la
 * imagen a SRAM y llama a rom_reboot(RAM_IMAGE) — venimos de un RESET, y la bootrom,
 * arrancando una imagen en RAM, no necesita XIP para nada y deja el QMI en minimos.
 * (Medido: M0_TIMING 40000004 y M0_RFMT 00001000, practicamente valores de reset,
 * contra 60007203 y 000492A8 en nuestro cartucho, que arranca de flash.)
 *
 * Lo que falta son los PADS del bus QSPI. En el RP2350 los pads arrancan AISLADOS, y
 * poner la funcion sin quitar ISO deja un pin mudo — ya nos costo una sesion con el
 * select de la PSRAM. Aqui son seis: reloj, cuatro datos y el select de la flash.
 *
 * Es exactamente el sintoma: el QMI acepta la transferencia y no sale nada por las
 * patas, porque conduce contra un aislamiento.
 */
/* ARMAR LA VENTANA XIP DE LA PSRAM (M1).
 *
 * Que el chip conteste su ID prueba el modo directo, NO la ventana: son dos caminos
 * distintos del QMI. Sin M1 configurado y sin WRITABLE_M1, las escrituras a 0x11000000
 * se descartan EN SILENCIO — el peor fallo posible, porque parece que funciona.
 *
 * Transcrito de firmware/src/psram.rs, que lleva 8 MB funcionando en nuestro cartucho.
 * Las dos constantes de temporizacion son las suyas: MAX_SELECT limita cuanto puede
 * estar bajo el select (el APS6404 es DRAM y necesita refrescarse) y MIN_DESELECT el
 * hueco entre transacciones. */
/* LA SECUENCIA MINIMA, la misma que psram.rs — que lleva 8 MB funcionando.
 *
 * El cargador usaba `uvm2_psram_probe()`, que es una SONDA DE DIAGNOSTICO: prueba
 * varios idiomas (SPI, QPI, entrar y salir de QPI) y no promete devolver el chip a un
 * estado concreto. Si lo deja en QPI, la ventana —que manda el comando por UNA linea—
 * lee basura. Y eso es justo lo que se veia: READ_ID correcto en modo directo, y la
 * lectura sin cache devolviendo un patron 0/4/8/C, o sea nadie conduciendo los datos.
 *
 * Para arrancar no hace falta diagnosticar: reset, comprobar el ID, y armar la ventana.
 */
int uvm2_psram_init(void)
{
    const uint8_t c_rsten[1] = { CMD_RESET_ENABLE };
    const uint8_t c_rst[1]   = { CMD_RESET };
    const uint8_t c_id[4]    = { CMD_READ_ID, 0x00, 0x00, 0x00 };
    uint8_t id[2] = { 0, 0 };

    reloj_directo(RELOJ_DIRECTO_DIV);
    configure_cs1_pad();

    direct_begin();
    cs1_xfer(c_rsten, 1, 0, 0);
    cs1_xfer(c_rst,   1, 0, 0);
    direct_end();
    spin(30000);                    /* tRST */

    direct_begin();
    cs1_xfer(c_id, 4, id, 2);
    direct_end();

    if (id[0] != 0x0D) return 0;
    uvm2_psram_enable_xip();
    return 1;
}

void uvm2_psram_enable_xip(void)
{
    const uint32_t Q = 2u;   /* ancho quad  */
    const uint32_t S = 0u;   /* ancho serie */

    *(volatile uint32_t *)0x400C8000u |= (1u << 11);   /* XIP_CTRL.WRITABLE_M1 */

    qmi_hw->m[1].timing =
/* EL DIVISOR ES AJUSTABLE, y por una razon: el 2 viene de nuestro cartucho, que corre
 * a 150 MHz porque su firmware lo fija. Aqui venimos de un reboot de la bootrom y NADIE
 * ha comprobado a que frecuencia arranca — un divisor pensado para otro reloj rompe las
 * LECTURAS (que exigen temporizacion de ida y vuelta) y no las escrituras, que es
 * exactamente el sintoma: la copia se verifica bien por cache y el codigo no se puede
 * ejecutar. */
/* MAX_SELECT acota cuanto puede estar CS bajo seguido, y de eso depende que la DRAM se
 * refresque. El APS6404L da tCEM = 8 us como maximo absoluto.
 *
 * A 150 MHz cada unidad son 64 ciclos = 427 ns, y un acceso ya en vuelo cuando salta el
 * limite TERMINA (unos 1,1 us mas). Con 15: 6,4 + 1,1 = 7,5 us de 8 — cabe, pero con 0,5
 * us de margen, y ese margen solo se pone a prueba en una copia LARGA: dos escrituras
 * sueltas nunca mantienen CS bajo el tiempo suficiente. Por eso la PSRAM parecia buena.
 * 8 unidades: 3,4 + 1,1 = 4,5 us, la mitad del limite. */
#ifndef UVM2_PSRAM_MAX_SELECT
#define UVM2_PSRAM_MAX_SELECT 15u
#endif

#ifndef UVM2_PSRAM_CLKDIV
#define UVM2_PSRAM_CLKDIV 2u
#endif
          (UVM2_PSRAM_CLKDIV << QMI_M1_TIMING_CLKDIV_LSB)
        | (1u  << QMI_M1_TIMING_RXDELAY_LSB)
        | (UVM2_PSRAM_MAX_SELECT << QMI_M1_TIMING_MAX_SELECT_LSB)   /* refresco: VER ABAJO */
        | (4u  << QMI_M1_TIMING_MIN_DESELECT_LSB)
        | (1u  << QMI_M1_TIMING_COOLDOWN_LSB);
    /* SIN PAGEBREAK Y CON MAX_SELECT=15, IGUAL QUE psram.rs.
     *
     * Llegue a poner PAGEBREAK=1024 y MAX_SELECT=8 por dos medidas que despues resultaron
     * viciadas: la copia se verificaba leyendo la CACHE, asi que ni el "COPIA FIN" ni los
     * offsets del barrido decian nada del chip. Nuestro cartucho lleva meses leyendo y
     * escribiendo este mismo APS6404L con 15 y sin trocear —su variante `R` cruza el borde
     * de fila en rafaga lineal— y es la unica configuracion con horas de vuelo detras.
     * Apartarse de ella exige una medida buena, y no la habia.
     *
     * (Lo que sigue abajo se conserva porque el razonamiento sobre el tCEM es correcto y
     * habra que volver a el si aparece una medida limpia que lo pida.)
     *
     * PAGEBREAK NO ES OPCIONAL EN ESTE CHIP -- SI la variante no cruza filas.
     *
     * El APS6404L tiene paginas de 1024 bytes: una rafaga lineal que cruza ese limite da
     * la vuelta DENTRO de la pagina en vez de seguir en la siguiente. Sin trocear ahi, una
     * copia larga escribe los primeros 1024 bytes donde toca y machaca esa misma pagina
     * con todo lo demas.
     *
     * Se nos escapo porque la prueba que dio la PSRAM por buena escribia dos palabras en
     * direcciones separadas 4 MB: dos transacciones cortas, ninguna cruzaba una pagina.
     * El sintoma solo aparece copiando de verdad — el cargador veia bien la PRIMERA
     * palabra del payload y mal la ULTIMA, que es exactamente esta forma. */

    qmi_hw->m[1].rcmd = CMD_QUAD_READ;               /* 0xEB, sufijo 0 */
    qmi_hw->m[1].rfmt =
          (S  << QMI_M1_RFMT_PREFIX_WIDTH_LSB)
        | (Q  << QMI_M1_RFMT_ADDR_WIDTH_LSB)
        | (Q  << QMI_M1_RFMT_SUFFIX_WIDTH_LSB)
        | (Q  << QMI_M1_RFMT_DUMMY_WIDTH_LSB)
        | (Q  << QMI_M1_RFMT_DATA_WIDTH_LSB)
        | (1u << QMI_M1_RFMT_PREFIX_LEN_LSB)         /* 8 bits */
        | (0u << QMI_M1_RFMT_SUFFIX_LEN_LSB)
        | (6u << QMI_M1_RFMT_DUMMY_LEN_LSB);         /* 24 bits = 6 ciclos quad */

    qmi_hw->m[1].wcmd = CMD_QUAD_WRITE;              /* 0x38 */
    qmi_hw->m[1].wfmt =
          (S  << QMI_M1_WFMT_PREFIX_WIDTH_LSB)
        | (Q  << QMI_M1_WFMT_ADDR_WIDTH_LSB)
        | (Q  << QMI_M1_WFMT_SUFFIX_WIDTH_LSB)
        | (Q  << QMI_M1_WFMT_DUMMY_WIDTH_LSB)
        | (Q  << QMI_M1_WFMT_DATA_WIDTH_LSB)
        | (1u << QMI_M1_WFMT_PREFIX_LEN_LSB)
        | (0u << QMI_M1_WFMT_SUFFIX_LEN_LSB)
        | (0u << QMI_M1_WFMT_DUMMY_LEN_LSB);
}

void uvm2_qmi_levantar(void)
{
    /* DOS BLOQUES, no uno. El pad (PADS_QSPI) dice como es electricamente el pin; el
     * FUNCSEL (IO_QSPI) dice QUIEN LO CONDUCE. Configurar el pad y no la funcion deja
     * un pin mudo — es exactamente el error que ya nos costo una sesion con el select
     * de la PSRAM, y lo acabo de repetir: los pads salieron 0x56 (sin aislamiento, IE
     * puesto) antes y despues, o sea que ese lado ya estaba bien.
     *
     * CTRL de cada pin en IO_QSPI, y FUNCSEL 0 = XIP (lo conduce el QMI). */
    {
        volatile uint32_t *io = (volatile uint32_t *)0x40030000u;
        static const unsigned ctrl[6] = { 0x14, 0x1C, 0x24, 0x2C, 0x34, 0x3C };
        int k;
        for (k = 0; k < 6; k++) {
            volatile uint32_t *r = (volatile uint32_t *)((char *)io + ctrl[k]);
            *r = (*r & ~0x1Fu) | 0u;      /* FUNCSEL = 0: XIP */
        }
    }

    {
    volatile uint32_t *pq = (volatile uint32_t *)0x40040000u;
    int i;
    /* [1]=SCLK [2..5]=SD0..SD3 [6]=SS. El [0] es VOLTAGE_SELECT, no se toca. */
    for (i = 1; i <= 6; i++) {
        uint32_t v = pq[i];
        v &= ~(1u << 8);      /* ISO: fuera el aislamiento */
        v &= ~(1u << 7);      /* OD: salida NO deshabilitada */
        v |=  (1u << 6);      /* IE: entrada habilitada (el QMI tiene que leer) */
        pq[i] = v;
    }
    }
}

void uvm2_qmi_snapshot(uvm2_qmi_estado *e)
{
    /* LOS PADS QSPI, que viven en SU PROPIO bloque (0x40040000) y no en el de los GPIO
     * normales. Nunca los hemos mirado: configuramos a mano el del select (GPIO47, que
     * si es un pad normal) y dimos por hecho que los del bus estaban bien porque de esa
     * flash arranca el firmware. Pero nuestra imagen corre desde SRAM: desde que
     * arranca, NADIE usa la flash, asi que un pad aislado no se notaria.
     *
     * MOSI clavado en 3,3 V y SCK quieto, con el QMI dando la transferencia por buena,
     * es exactamente lo que se ve si la salida esta deshabilitada. */
    {
        volatile uint32_t *pq = (volatile uint32_t *)0x40040000u;
        e->pad_sclk = pq[1];   /* GPIO_QSPI_SCLK */
        e->pad_sd0  = pq[2];   /* GPIO_QSPI_SD0  */
        e->pad_ss   = pq[6];   /* GPIO_QSPI_SS   */
        e->fn_sclk  = *(volatile uint32_t *)0x40030014u;   /* SCLK_CTRL */
        e->fn_sd0   = *(volatile uint32_t *)0x40030024u;   /* SD0_CTRL  */
    }
    e->direct_csr = qmi_hw->direct_csr;
    e->xip_ctrl   = *(volatile uint32_t *)0x400C8000u;   /* XIP_CTRL */
    e->m0_timing  = qmi_hw->m[0].timing;
    e->m0_rfmt    = qmi_hw->m[0].rfmt;
    e->m0_rcmd    = qmi_hw->m[0].rcmd;
    e->m1_timing  = qmi_hw->m[1].timing;
}

void uvm2_flash_exit_xip(void)
{
    const uint8_t salida[3] = { 0xFFu, 0x66u, 0x99u };
    int k;
    reloj_directo(RELOJ_DIRECTO_DIV);
    qmi_hw->direct_csr |= QMI_DIRECT_CSR_EN_BITS;
    {
        uint32_t spins = 0;
        while ((qmi_hw->direct_csr & QMI_DIRECT_CSR_BUSY_BITS) && ++spins < QMI_SPIN_LIMIT) { }
    }
    for (k = 0; k < 3; k++) {
        qmi_hw->direct_csr |= QMI_DIRECT_CSR_ASSERT_CS0N_BITS;
        tx(salida[k]); (void)rx();
        qmi_hw->direct_csr &= ~QMI_DIRECT_CSR_ASSERT_CS0N_BITS;
    }
    qmi_hw->direct_csr &= ~QMI_DIRECT_CSR_EN_BITS;
}

uint32_t uvm2_flash_id(void)
{
    reloj_directo(RELOJ_DIRECTO_DIV);   /* sin esto no hay reloj */
    const uint8_t cmd = 0x9Fu;          /* JEDEC ID: sin direccion, tres bytes */
    uint8_t id[3] = { 0, 0, 0 };
    uint32_t spins = 0;
    int i;

    qmi_hw->direct_csr |= QMI_DIRECT_CSR_EN_BITS;
    while ((qmi_hw->direct_csr & QMI_DIRECT_CSR_BUSY_BITS) && ++spins < QMI_SPIN_LIMIT) { }

    /* SACARLA DEL MODO XIP PRIMERO. El firmware de Ralf arranca desde esta flash, y
     * una flash en `continuous read` NO contesta a comandos normales: se queda
     * esperando direcciones. Por eso existe rom_flash_exit_xip() — que aqui no vuelve.
     * Se hace a mano, que son tres bytes sueltos, cada uno en su propia seleccion:
     *   0xFF  reset del modo de lectura continua
     *   0x66  habilitar reset      0x99  reset
     * Es seguro: esta imagen corre entera desde SRAM, nadie esta leyendo de la flash,
     * y al reiniciar la bootrom la reinicializa. */
    uvm2_flash_exit_xip();

    qmi_hw->direct_csr |= QMI_DIRECT_CSR_ASSERT_CS0N_BITS;
    tx(cmd); (void)rx();
    for (i = 0; i < 3; i++) { tx(0x00); id[i] = rx(); }
    qmi_hw->direct_csr &= ~QMI_DIRECT_CSR_ASSERT_CS0N_BITS;
    qmi_hw->direct_csr &= ~QMI_DIRECT_CSR_EN_BITS;

    return ((uint32_t)id[0] << 16) | ((uint32_t)id[1] << 8) | id[2];
}

/* ---- CUANTO TIEMPO SE QUEDA /CS ABAJO ------------------------------------
 *
 * EL APS6404 ES DRAM POR DENTRO y exige refrescarse: su **tCEM son 8 us**, o sea que
 * tiene derecho a abandonar una transaccion que mantenga /CS bajo mas que eso. Un chip
 * que aborta por tCEM calla EXACTAMENTE como el nuestro.
 *
 * El codigo de aqui ya razonaba sobre tCEM, pero contando RELOJES: "12 bytes en quad a
 * 25 MHz son ~1 us, holgado". Eso ignora lo que tarda el software entre byte y byte —
 * y en modo directo cada byte lleva un sondeo de TXFULL/RXEMPTY, que son accesos a
 * registro, con el select BAJO todo el rato. La estimacion puede quedarse corta por un
 * orden de magnitud y nadie lo ha medido.
 *
 * Se mide con el contador de ciclos del nucleo (DWT), que da 6,7 ns de resolucion a
 * 150 MHz — un `time_us_32()` no vale para distinguir 2 us de 8.
 */
uint32_t uvm2_psram_cs_low_ns(void)
{
    reloj_directo(RELOJ_DIRECTO_DIV);   /* sin esto no hay reloj */
    const uint8_t cmd[4] = { CMD_READ_ID, 0, 0, 0 };
    uint8_t id[2];
    uint32_t t0, t1;

    /* DWT: habilitar la traza y el contador de ciclos. */
    *(volatile uint32_t *)0xE000EDFC |= (1u << 24);   /* DEMCR.TRCENA  */
    *(volatile uint32_t *)0xE0001000 |= 1u;           /* DWT_CTRL.CYCCNTENA */

    configure_cs1_pad();
    qmi_hw->direct_csr |= QMI_DIRECT_CSR_EN_BITS;
    uint32_t spins = 0;
    while ((qmi_hw->direct_csr & QMI_DIRECT_CSR_BUSY_BITS) && ++spins < QMI_SPIN_LIMIT) { }

    t0 = *(volatile uint32_t *)0xE0001004;            /* DWT_CYCCNT */
    cs1_xfer(cmd, 4, id, 2);                          /* asserta, transfiere, suelta */
    t1 = *(volatile uint32_t *)0xE0001004;

    qmi_hw->direct_csr &= ~QMI_DIRECT_CSR_EN_BITS;

    {
        uint32_t ciclos = t1 - t0;
        uint32_t hz = clock_get_hz(clk_sys);
        if (!hz) return 0;
        /* ns, sin flotantes y sin desbordar: ciclos * (1e9/hz). */
        return (uint32_t)((unsigned long long)ciclos * 1000000000ull / hz);
    }
}

/* ---- EL RELOJ, TAMBIEN PARA EL POLIMETRO ----------------------------------
 *
 * Sabemos (2026-08-19) que el QMI conduce CS1 hasta la pata 1 de U3: asertado da 0 V
 * y suelto 3,3 V. Lo que NADIE ha mirado es si el RELOJ llega mientras tanto. Si SCK
 * no conmuta, el chip no puede contestar por muy bien que le llegue el select — y eso
 * explicaria todo sin necesidad de que el chip este muerto.
 *
 * TAMBIEN CON POLIMETRO, y sin osciloscopio: una transaccion suelta dura microsegundos
 * y no la ve un tester, pero repitiendola SIN PARAR el reloj pasa la mitad del tiempo
 * alto, y en continua eso se lee como ~1,65 V. Parado se lee un nivel fijo (0 o 3,3).
 *
 *     ~1,6 V en la pata 6 de U3  -> el reloj SI le llega. El chip recibe select y
 *                                   reloj y aun asi calla: el sospechoso es U3.
 *     0 o 3,3 V fijos            -> el QMI no esta relojeando. El fallo es de
 *                                   configuracion del QMI, no del chip.
 *
 * NO DIBUJA NADA a proposito: la pantalla se queda negra, y eso es la señal de que
 * esta martilleando. Se sale reseteando.
 */
/* Una RAFAGA de transacciones, no un bucle infinito. Devuelve el control para que el
 * programa siga dibujando: asi "esta martilleando" tiene una señal POSITIVA en pantalla
 * en vez de la ausencia de imagen — que es indistinguible de un cuelgue, y era el
 * eslabon debil de la medida con osciloscopio. Al osciloscopio le basta con rafagas:
 * dispara por flanco, no por nivel medio. */
/* DIRECT_CSR justo despues de escribir un byte en la cola. */
volatile uint32_t uvm2_csr_tras_tx = 0;

void uvm2_psram_rafaga(unsigned n)
{
    const uint8_t cmd[4] = { CMD_READ_ID, 0, 0, 0 };
    uint8_t id[2];
    unsigned i;

    reloj_directo(RELOJ_DIRECTO_DIV);
    configure_cs1_pad();
    for (i = 0; i < n; i++) {
        qmi_hw->direct_csr |= QMI_DIRECT_CSR_EN_BITS;
        uint32_t spins = 0;
        while ((qmi_hw->direct_csr & QMI_DIRECT_CSR_BUSY_BITS) && ++spins < QMI_SPIN_LIMIT) { }
        /* LA FOTO QUE FALTA. CS se mueve —lo movemos nosotros con un bit— pero ni
         * reloj ni dato salen. Falta saber si la escritura llega a la cola y no se
         * vacia, o si no llega: TXEMPTY (bit 11) y TXLEVEL (bits 12-14) lo dicen. */
        qmi_hw->direct_csr |= QMI_DIRECT_CSR_ASSERT_CS1N_BITS;
        qmi_hw->direct_tx = 0x9Fu;
        uvm2_csr_tras_tx = qmi_hw->direct_csr;
        qmi_hw->direct_csr &= ~QMI_DIRECT_CSR_ASSERT_CS1N_BITS;
        cs1_xfer(cmd, 4, id, 2);
        qmi_hw->direct_csr &= ~QMI_DIRECT_CSR_EN_BITS;
    }
}

void uvm2_psram_hammer(void)
{
    reloj_directo(RELOJ_DIRECTO_DIV);   /* sin esto no hay reloj */
    const uint8_t cmd[4] = { CMD_READ_ID, 0, 0, 0 };
    uint8_t id[2];

    configure_cs1_pad();
    for (;;) {
        qmi_hw->direct_csr |= QMI_DIRECT_CSR_EN_BITS;
        uint32_t spins = 0;
        while ((qmi_hw->direct_csr & QMI_DIRECT_CSR_BUSY_BITS) && ++spins < QMI_SPIN_LIMIT) { }
        cs1_xfer(cmd, 4, id, 2);
        qmi_hw->direct_csr &= ~QMI_DIRECT_CSR_ASSERT_CS1N_BITS;
        qmi_hw->direct_csr &= ~QMI_DIRECT_CSR_EN_BITS;
    }
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
    reloj_directo(RELOJ_DIRECTO_DIV);   /* NO lo hacia: ver la nota de arriba */
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
        /* SALIDA TEMPRANA, y hay que poder saltarsela. Si alguien ya levanto la
         * ventana no hace falta interrogar al chip... salvo cuando lo que se quiere
         * probar es precisamente el interrogatorio. Paso justo eso: en nuestro
         * cartucho el firmware levanta la PSRAM antes de lanzar el juego, la sonda
         * salio por aqui devolviendo 1, y ese 1 se leyo como "el chip contesta"
         * cuando significaba "ya estaba montada". READ_ID no llego a ejecutarse. */
        if (!uvm2_psram_forzar) return 1;
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
