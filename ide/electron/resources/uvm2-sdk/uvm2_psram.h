/*
 * uvm2_psram.h — resultado de la sonda de PSRAM del UVM2. Ver uvm2_psram.c.
 *
 * La estructura es global y volatil a proposito: con SWD puesto se lee tal cual
 * y no hay que descifrar parpadeos de LED.
 */
#ifndef UVM2_PSRAM_H
#define UVM2_PSRAM_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Centinela. Sin esto, leer la estructura de una imagen que NO esta cargada
 * devuelve el codigo de OTRO juego, y un `probed` distinto de cero se lee como
 * "la sonda corrio". Paso: dio un "ya esta mapeada" que era basura. Una palabra
 * improbable es la diferencia entre un dato y una casualidad. */
/* PSR2, no PSR1: la estructura ha crecido con la sonda del bootrom. Si se
 * quedara en PSR1, una imagen ANTERIOR que siguiera en la RAM del cartucho
 * pasaria el centinela y sus campos viejos se leerian en los sitios nuevos.
 * El centinela sube con el formato o no es un centinela. */
#define UVM2_PSRAM_MAGIC 0x50535233u   /* "PSR3" */

typedef struct {
    uint32_t magic;         /* UVM2_PSRAM_MAGIC si la sonda escribio esto   */
    uint32_t probed;        /* 1 = la sonda llego a ejecutarse            */
    uint32_t found;         /* 1 = el ID de fabricante es el esperado     */
    uint32_t mf_id;         /* byte 0 del READ_ID (0x0D = AP Memory)      */
    uint32_t kgd;           /* byte 1: known-good-die                     */
    uint32_t xip_before[4]; /* 0x11000000 ANTES de tocar nada             */
    /* Estado del QMI AL ENTRAR, antes de que la sonda toque nada. Sin esto no
     * se puede distinguir "el firmware la dejo montada" de "la montamos y luego
     * la rompimos": son dos lecturas distintas del mismo registro y hay que
     * capturar la primera. */
    uint32_t m1_timing_before;
    uint32_t m1_rfmt_before;
    uint32_t m1_rcmd_before;
    uint32_t direct_csr_before;
    /* Un rx() agotado y un chip que contesta cero devuelven LO MISMO: 0x00. Sin
     * contar los plantones, "no contesta" y "contesta cero" son la misma lectura,
     * y son diagnosticos opuestos. */
    uint32_t mf_id_spi;     /* READ_ID hablandole en UNA linea (SPI)        */
    uint32_t mf_id_after_qpi_exit; /* ...y despues de sacarlo de QPI          */
    /* Prueba electrica del UNICO cable exclusivo de U3: su chip select. El
     * resto del bus (SCK, SD0, SD1) lo comparte con la flash, y la flash
     * funciona —de ella arranca el firmware—, asi que esas lineas estan sanas.
     * Se conduce GPIO47 como salida normal y se lee lo que vuelve por el propio
     * pad: si no sigue a lo que conducimos, el problema es el cable, no el chip. */
    uint32_t cs_reads_when_high;
    uint32_t cs_reads_when_low;
    /* Indicio de CONTINUIDAD, no prueba. Se suelta la salida y se apagan los
     * pull INTERNOS, para que lo que se lea sea lo que hace la red de fuera. El
     * esquema pone un pull-up junto a U3: si la pista llega hasta el, un pin
     * conducido a cero y luego soltado vuelve solo a 1. Si esta cortada del lado
     * del chip, la red queda al aire y se queda en 0 por pura capacidad.
     * El discriminante es cs_float_tras_bajo. */
    uint32_t cs_float_tras_bajo;
    uint32_t cs_float_tras_alto;
    /* El mismo READ_ID a varias velocidades. Un chip bien cableado que calla
     * suele destaparse bajando el reloj. CLKDIV 6 = 25 MHz, 30 = 5 MHz,
     * 120 = 1,25 MHz. */
    uint32_t id_por_clkdiv[4];
    uint32_t clkdiv_probados[4];
    uint32_t rx_timeouts;
    uint32_t csr_after_cmd; /* DIRECT_CSR tras sacar el primer byte */
    uint32_t already_mapped;/* 1 = CS1 venia configurado: NO tocamos el chip  */

    /* ---- LA SONDA DEL BOOTROM (uvm2_psram_probe_bootrom) -------------------
     *
     * La primera sonda le habla al chip por modo directo, a mano. Esta le deja
     * hablar al BOOTROM, que es la unica pieza que sabe sacar de XIP a un
     * dispositivo de CS1 — y solo lo hace si FLASH_DEVINFO dice que CS1 mide
     * algo. Por defecto mide NONE, asi que esa secuencia NO SE HA MANDADO NUNCA.
     * Ver el comentario de flash_devinfo_set_cs_size() en hardware/flash.h. */
    uint32_t bootrom_probe_run;   /* 1 = esta sonda llego a ejecutarse         */
    /* CONTROL POSITIVO. El mismo READ_ID a la FLASH (CS0), que sabemos buena
     * porque de ella arranca el firmware. Un W25Q128 contesta EF 40 18. Si esto
     * sale mal, el camino de lectura esta roto y lo que diga CS1 no vale nada:
     * es la regla de "referencia antes que sospechoso, mismo montaje", solo que
     * en software y gratis. */
    uint32_t flash_jedec;
    uint32_t flash_jedec_tras_cs1; /* el mismo, despues de armar CS1           */
    uint32_t devinfo_cs1_before;  /* lo que decia FLASH_DEVINFO de CS1 al entrar */
    /* Y el chip, tras la secuencia de salida del bootrom. */
    uint32_t mf_id_bootrom;       /* byte 4: 0x0D = AP Memory                  */
    uint32_t kgd_bootrom;         /* byte 5: 0x5D = known good die             */
    uint32_t eid_bootrom;         /* byte 6: de aqui sale el tamaño            */
    uint32_t found_bootrom;       /* 1 = KGD correcto, que es lo que mira el SDK */
    uint32_t tam_bootrom;         /* bytes deducidos del EID, 0 si no contesta  */
    /* MIGAS. La primera version de esta sonda se colgo dentro de do_cmd_cs y lo
     * unico que se sabia era "no llego a escribir flash_jedec" — que abarca seis
     * llamadas. Esto se escribe ANTES de cada paso, asi que el ultimo valor que
     * sobreviva ES el paso que no volvio. Vale mas que cualquier hipotesis:
     * un cuelgue no deja traza, salvo la que le dejes puesta de antemano.
     * Codigo: llamada*100 + paso. Ver PASO_* en uvm2_psram.c. */
    uint32_t paso_bootrom;

    /* ---- HABLARLE EN QPI (uvm2_psram_probe_qpi) ---------------------------
     *
     * La hipotesis que ninguna sonda habia probado. Un APS6404 en QPI ignora
     * las ordenes de UNA linea, y el cartucho lleva USB-C: no se queda sin
     * corriente al apagar la consola, asi que puede llevar en QPI desde
     * nuestras propias sondas. Bajar el reloj no destapa eso — no es un
     * problema de velocidad, es de idioma.
     *
     * Y el driver oficial del pico-sdk 2.3.0 lo confirma por el otro lado: su
     * psram_initialize_internal() manda 0x35 (QUAD ENABLE), o sea que QUIERE el
     * chip en QPI. Si ya lo esta, no hay que sacarlo: hay que hablarle asi.
     *
     * Se guardan los OCHO bytes crudos de cada intento, sin decidir donde cae
     * el ID. Los ciclos de espera del 0x9F en QPI no los tenemos medidos, y
     * suponer una posicion convierte un desfase de un byte en "chip mudo" —
     * que es exactamente el error que ya cometimos con MF_ID contra KGD.
     * Busca 0d 5d en la tira y ya veras donde cae. */
    uint32_t qpi_probe_run;
    uint32_t qpi_directo[2];   /* READ_ID en QPI, tal cual esta el chip       */
    uint32_t qpi_tras_35[2];   /* ...y tras mandarle 0x35 en una linea        */
    /* EL RELOJ, APUNTADO. La primera version heredaba el CLKDIV = 120 que deja
     * uvm2_psram_probe() al acabar su barrido y no restaura — y a 1,25 MHz la
     * transaccion en quad tiene el select bajo ~19 us, contra un **tCEM de 8 us**
     * del APS6404. La prueba corria fuera de especificacion sin que se viera.
     * Guardar el divisor cuesta una palabra y evita deducirlo nunca mas. */
    uint32_t qpi_clkdiv;        /* 6 = 25 MHz                                  */
    uint32_t qpi_clkdiv_lento;  /* 30 = 5 MHz                                  */
    uint32_t qpi_lento[2];      /* el mismo READ_ID en quad, mas despacio      */
} uvm2_psram_result_t;

extern volatile uvm2_psram_result_t uvm2_psram_result;

/* Sondea. NO arma la ventana XIP ni escribe: primero saber que hay. */
int uvm2_psram_probe(void);

/* Mantiene CS1 asertado (o suelto) INDEFINIDAMENTE, para medir la pata 1 de U3
 * con un polimetro. Responde a lo que ninguna otra prueba ha mirado: si el QMI
 * conduce de verdad la pata, o solo lo dicen sus registros. No vuelve al estado
 * anterior — se sale reseteando. Ver el comentario largo en el .c. */
void uvm2_psram_hold_cs(int asertado);

/* Repite READ_ID SIN PARAR para que el reloj se pueda medir en continua en la pata 6
 * de U3: ~1,6 V = conmuta; 0 o 3,3 V fijos = el QMI no releojea. No vuelve ni dibuja
 * (la pantalla en negro ES la señal); se sale reseteando. */
void uvm2_psram_hammer(void);

/* `n` transacciones y VUELVE, para poder seguir dibujando. La señal de que esta
 * martilleando pasa a ser algo que se VE, no la falta de imagen — que es lo mismo que
 * se ve cuando el programa se cuelga. */
void uvm2_psram_rafaga(unsigned n);

/* DIRECT_CSR justo despues de escribir un byte: dice si la cola acepta y se vacia. */
extern volatile uint32_t uvm2_csr_tras_tx;

/* Cuanto tiempo se queda /CS ABAJO en una transaccion, en nanosegundos. El tCEM del
 * APS6404 son 8000 ns: por encima de eso el chip tiene derecho a abandonar, y callaria
 * igual que el nuestro. Medido con el contador de ciclos del nucleo, no estimado
 * contando relojes — que es lo que se hacia y no incluye el sondeo entre bytes. */
uint32_t uvm2_psram_cs_low_ns(void);

/* LA REFERENCIA. El mismo READ_ID por el mismo modo directo pero a la FLASH (CS0), que
 * comparte reloj y datos con la PSRAM y sabemos que funciona. Si contesta, el camino es
 * bueno y el sospechoso es U3; si calla, el fallo es nuestro. Sin bootrom: aqui
 * rom_flash_exit_xip() no vuelve. Devuelve (b0<<16)|(b1<<8)|b2. */
/* Saca la flash de lectura continua y la resetea, para partir de un estado
 * conocido antes de hablarle a CS1. Ver la nota larga en el .c. */
/* El estado del QMI/XIP tal como nos lo deja el firmware de turno. Se toma ANTES de
 * tocar nada; comparar el de las dos placas es lo unico que queda cuando el QMI no se
 * puede resetear y el codigo ya esta exonerado. */
typedef struct {
    uint32_t direct_csr, xip_ctrl, m0_timing, m0_rfmt, m0_rcmd, m1_timing;
    uint32_t pad_sclk, pad_sd0, pad_ss;   /* bloque PADS_QSPI, 0x40040000 */
    uint32_t fn_sclk, fn_sd0;             /* FUNCSEL, bloque IO_QSPI 0x40030000 */
} uvm2_qmi_estado;

/* Quita el aislamiento de los pads del bus QSPI. Hace falta porque la imagen la
 * lanza la bootrom tras un reset y, siendo imagen en RAM, no los prepara. */
void uvm2_qmi_levantar(void);

/* Arma la ventana XIP de la PSRAM (M1) y permite escribir en ella. Sin esto, las
 * escrituras a 0x11000000 se descartan en silencio. */
/* Arranque MINIMO, como psram.rs: reset, ID y ventana. Devuelve 1 si el chip esta.
 * Para arrancar no hace falta la sonda de diagnostico, que puede dejar el chip en QPI. */
int uvm2_psram_init(void);

void uvm2_psram_enable_xip(void);

void uvm2_qmi_snapshot(uvm2_qmi_estado *e);

/* Entra en modo directo cerrando el hueco por el que se encalla: interrupciones fuera,
 * barreras, y opcionalmente la cache del XIP apagada. Devuelve las vueltas que tardo
 * BUSY en bajarse (100000 = no bajo). */
uint32_t uvm2_qmi_entrar_directo(int apagar_cache);

void uvm2_flash_exit_xip(void);

uint32_t uvm2_flash_id(void);

/* 1 = enciende OE al transmitir en UNA linea (por defecto). Existe para comparar A/B
 * sin recompilar: el codigo daba por hecho que en una linea SD0 se conduce solo. */
extern int uvm2_tx_oe;

/* 1 = no tomar el atajo de "ya esta mapeada": hacer el READ_ID igualmente. */
extern int uvm2_psram_forzar;

/* La misma pregunta, hablandole en QPI. Sin bootrom: no se puede colgar. */
int uvm2_psram_probe_qpi(void);

/* La misma pregunta por el camino del bootrom.
 *
 * OJO: MEDIDO 2026-08-17, rom_flash_exit_xip() NO VUELVE en este cartucho — y
 * ya en la primera llamada, la de CS0, antes de tocar CS1. Por eso vive detras
 * de -DUVM2_PSRAM_BOOTROM y por defecto no se compila: una sonda que cuelga
 * cuesta un viaje de tarjeta entero y devuelve un solo bit. */
int uvm2_psram_probe_bootrom(void);

#ifdef __cplusplus
}
#endif

#endif /* UVM2_PSRAM_H */
