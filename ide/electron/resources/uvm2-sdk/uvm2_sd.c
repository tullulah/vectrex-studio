/* uvm2_sd.c — SD por SPI a pelo + lector FAT minimo. Portado de sd.rs del cartucho
 * propio, que ya lleva dentro las lecciones que costaron sesiones alli.
 *
 * LOS PINES SALEN DEL ESQUEMATICO Y EL RANGO ESTA CONFIRMADO (GPIO32..39); la asignacion
 * uno a uno NO. Ver hardware/uvm2/PINES_SD.md: un desplazamiento de uno rompe esto SIN
 * DAR ERROR — habla con el GPIO equivocado y la tarjeta simplemente no contesta. Por eso
 * uvm2_sd_error distingue "no hay tarjeta" de "no arranca": con un solo codigo de fallo,
 * un pin mal puesto y una tarjeta ausente se ven igual.
 */
#include "uvm2_sd.h"

int uvm2_sd_error = UVM2_SD_OK;

/* LOS PINES ESTAN MEDIDOS DEL PROPIO FIRMWARE, no leidos del esquematico.
 *
 * Al cargar un modulo, el firmware del UVM2 deja TODO el banco de E/S en FUNCSEL 31
 * (nulo) — comprobado por SWD: de GPIO32 a GPIO47 no queda ni uno configurado. Pero
 * mientras esta en SU MENU si tiene la SD puesta en marcha, y ahi se le puede leer
 * IO_BANK0 sin tocar nada. Eso dio (2026-08-20):
 *
 *     GPIO34  FUNCSEL 1 = SPI0_SCLK   STATUS OETOPAD           -> conduce bajo: SCK
 *     GPIO35  FUNCSEL 1 = SPI0_TX     STATUS 0                 -> MOSI
 *     GPIO36  FUNCSEL 1 = SPI0_RX     STATUS INFROMPAD|IRQ     -> lee alto: MISO con pull-up
 *     GPIO39  FUNCSEL 5 = SIO         STATUS OUT|OE|IN|IRQ     -> conduce alto: CS activo bajo
 *
 * La lista anterior salia de leer etiquetas del esquematico al limite de la resolucion y
 * estaba DESPLAZADA DOS, con el CS ademas en otro pin. El sintoma fue exactamente el que
 * avisaba el comentario: la tarjeta no contesta y uvm2_sd_error se queda en NO_ARRANCA.
 *
 * Si algun dia hay que revisarlo, la receta es esa: consola en el menu del UVM2 y
 * `hardware/uvm2/tools/sonda.sh 0x40028100 32`. Es una MEDIDA, no una lectura.
 *
 * NO HAY DETECCION DE TARJETA. El firmware no configura ningun pin para eso (32, 33, 37 y
 * 38 estan nulos en su menu), asi que SD_DETECT no existe en este cableado. Antes se leia
 * el GPIO38: un pad sin dueño con pull-down interno, que devuelve 0 siempre — o sea "hay
 * tarjeta" pasara lo que pase. Un diagnostico que no puede fallar no diagnostica nada. */
/* ── EL LADO HARDWARE ─────────────────────────────────────────────────────────────────
 * Con -DUVM2_SD_HOST se compila el mismo FAT contra un FICHERO en vez de contra la tarjeta.
 * Existe para poder probar la ESCRITURA —crear un fichero toca la FAT y el directorio— sin
 * arriesgar la tarjeta de nadie, y contra imagenes FAT16 y FAT32 reales que despues valida
 * `fsck_msdos`. Ver hardware/uvm2/tools/prueba_fat.c. */
#ifndef UVM2_SD_HOST
#define PIN_SCK   34
#define PIN_MOSI  35
#define PIN_MISO  36
#define PIN_CS    39

#define PADS_BANK0 0x40038000u
#define IO_BANK0   0x40028000u
#define SIO        0xD0000000u
#define R(a)       (*(volatile uint32_t *)(uintptr_t)(a))

/* GP32-47 viven en el banco ALTO del SIO: registros distintos, y el bit es pin-32.
 *
 * LOS DESPLAZAMIENTOS DEL BANCO ALTO NO SON LOS DEL RP2040, y esto ya costo una pantalla
 * negra: alli HI_OUT_SET esta en 0x028 y aqui en 0x01C, de modo que escribir el numero
 * del RP2040 cae en GPIO_OE / GPIO_OE_SET del banco BAJO — o sea, en la direccion de los
 * pines del BUS DEL CARTUCHO. El sintoma no fue un error sino que el reloj del Vectrex
 * dejo de avanzar y uvm2_frame_end se quedo esperando para siempre.
 *
 * Los valores salen de hardware/regs/sio.h del pico-sdk, y el static_assert de abajo los
 * comprueba contra esa cabecera cuando esta disponible. No los escribas de memoria. */
#define SIO_HI_IN       0x008u
#define SIO_HI_OUT_SET  0x01Cu
#define SIO_HI_OUT_CLR  0x024u
#define SIO_HI_OE_SET   0x03Cu
#define SIO_HI_OE_CLR   0x044u

#if defined(__has_include)
#  if __has_include(<hardware/regs/sio.h>) && __has_include(<hardware/platform_defs.h>)
     /* sio.h envuelve cada numero en _u(), que vive en platform_defs.h: sin ella el
      * valor no es una constante y el static_assert no compila. */
#    include <hardware/platform_defs.h>
#    include <hardware/regs/sio.h>
_Static_assert(SIO_HI_IN      == SIO_GPIO_HI_IN_OFFSET,      "SIO_HI_IN");
_Static_assert(SIO_HI_OUT_SET == SIO_GPIO_HI_OUT_SET_OFFSET, "SIO_HI_OUT_SET");
_Static_assert(SIO_HI_OUT_CLR == SIO_GPIO_HI_OUT_CLR_OFFSET, "SIO_HI_OUT_CLR");
_Static_assert(SIO_HI_OE_SET  == SIO_GPIO_HI_OE_SET_OFFSET,  "SIO_HI_OE_SET");
_Static_assert(SIO_HI_OE_CLR  == SIO_GPIO_HI_OE_CLR_OFFSET,  "SIO_HI_OE_CLR");
#  endif
#endif

static inline uint32_t hi(int pin) { return 1u << (pin - 32); }

static void cfg_pin(int pin, int salida)
{
    /* El pad arranca AISLADO en el RP2350: sin quitar ISO el pin queda mudo y no avisa. */
    volatile uint32_t *pad = (volatile uint32_t *)(uintptr_t)(PADS_BANK0 + 4 + 4*pin);
    /* PDE viene PUESTO en el valor de reset (0x0116). Dejarlo es la trampa hermana de ISO
     * que ya documenta sd.rs: en MISO, ese pull-down interno pelea con el pull-up de la
     * placa —el que se ve leyendo alto en el GPIO36 del menu— y puede tumbar la linea. */
    *pad = (*pad & ~((1u<<8) | (1u<<7) | (1u<<2))) | (1u<<6) | (salida ? 0u : (1u<<3));
                                          /* ISO=0, OD=0, PDE=0, IE=1, PUE en entradas */
    R(IO_BANK0 + 8*pin + 4) = 5u;                        /* FUNCSEL 5 = SIO   */
    if (salida) R(SIO + SIO_HI_OE_SET) = hi(pin);
    else        R(SIO + SIO_HI_OE_CLR) = hi(pin);
}
static inline void pon(int pin, int v)
{
    if (v) R(SIO + SIO_HI_OUT_SET) = hi(pin);
    else   R(SIO + SIO_HI_OUT_CLR) = hi(pin);
}
static inline int lee(int pin) { return (R(SIO + SIO_HI_IN) >> (pin - 32)) & 1u; }

/* Medio ciclo de reloj. Arranque lento (la tarjeta lo exige hasta salir de idle) y
 * rapido despues; sin las dos velocidades, o no arranca o tarda una eternidad. */
static volatile int s_lento = 1;
static void tick(void) { volatile int n = s_lento ? 24 : 1; while (n--) { } }

static uint8_t xfer(uint8_t out)
{
    uint8_t in = 0;
    for (int i = 7; i >= 0; i--) {
        pon(PIN_MOSI, (out >> i) & 1);
        tick();
        pon(PIN_SCK, 1);                 /* flanco de subida: se muestrea MISO */
        in = (uint8_t)((in << 1) | lee(PIN_MISO));
        tick();
        pon(PIN_SCK, 0);
    }
    return in;
}
static void cs(int on) { pon(PIN_CS, !on); }   /* CS es activo BAJO */

static uint8_t comando(uint8_t idx, uint32_t arg, uint8_t crc)
{
    xfer(0xFF);
    xfer((uint8_t)(0x40 | idx));
    xfer((uint8_t)(arg >> 24)); xfer((uint8_t)(arg >> 16));
    xfer((uint8_t)(arg >> 8));  xfer((uint8_t)arg);
    xfer(crc);
    for (int i = 0; i < 10; i++) {           /* R1: primer byte sin el bit 7 */
        uint8_t r = xfer(0xFF);
        if (!(r & 0x80)) return r;
    }
    return 0xFF;
}

static int s_sdhc = 0;

int uvm2_sd_init(void)
{
    uvm2_sd_error = UVM2_SD_OK;
    cfg_pin(PIN_SCK, 1); cfg_pin(PIN_MOSI, 1); cfg_pin(PIN_CS, 1);
    cfg_pin(PIN_MISO, 0);
    pon(PIN_SCK, 0); pon(PIN_MOSI, 1); cs(0);
    s_lento = 1;

    /* 80 pulsos con CS alto: la tarjeta los pide para entrar en modo SPI. */
    for (int i = 0; i < 10; i++) xfer(0xFF);

    cs(1);
    if (comando(0, 0, 0x95) != 0x01) { cs(0); uvm2_sd_error = UVM2_SD_NO_ARRANCA; return 0; }

    uint8_t r = comando(8, 0x1AA, 0x87);     /* v2 responde 0x01 + 4 bytes */
    int v2 = (r == 0x01);
    if (v2) for (int i = 0; i < 4; i++) xfer(0xFF);

    for (int intento = 0; ; intento++) {
        comando(55, 0, 0xFF);
        if (comando(41, v2 ? 0x40000000u : 0, 0xFF) == 0x00) break;
        if (intento > 20000) { cs(0); uvm2_sd_error = UVM2_SD_NO_ARRANCA; return 0; }
    }
    if (v2) {                                 /* CMD58: ¿direcciona por bloques? */
        if (comando(58, 0, 0xFF) == 0x00) {
            uint8_t ocr = xfer(0xFF); xfer(0xFF); xfer(0xFF); xfer(0xFF);
            s_sdhc = (ocr & 0x40) != 0;
        }
    }
    cs(0);
    s_lento = 0;
    return 1;
}

#else   /* UVM2_SD_HOST */
int uvm2_host_lee(uint32_t lba, unsigned char *b);
int uvm2_host_escribe(uint32_t lba, const unsigned char *b);
int uvm2_sd_init(void) { return 1; }
#endif

#ifdef UVM2_SD_HOST
static int lee_bloque(uint32_t lba, unsigned char *buf) { return uvm2_host_lee(lba, buf); }
static int escribe_bloque(uint32_t lba, const unsigned char *buf) { return uvm2_host_escribe(lba, buf); }
#else
static int lee_bloque(uint32_t lba, unsigned char *buf)
{
    cs(1);
    if (comando(17, s_sdhc ? lba : lba * 512u, 0xFF) != 0x00) { cs(0); return 0; }
    uint8_t t = 0xFF;
    for (int i = 0; i < 200000 && t == 0xFF; i++) t = xfer(0xFF);
    if (t != 0xFE) { cs(0); return 0; }
    for (int i = 0; i < 512; i++) buf[i] = xfer(0xFF);
    xfer(0xFF); xfer(0xFF);                   /* CRC, que no comprobamos */
    cs(0);
    return 1;
}

/* ESCRIBIR UN BLOQUE (CMD24). El unico camino de escritura del driver, y a proposito: se
 * usa SOLO para sobrescribir EN SITIO un fichero que ya existe, sin tocar la FAT ni el
 * directorio. Crear o redimensionar pide asignar clusters y reescribir las DOS copias de la
 * FAT, y equivocarse ahi corrompe la tarjeta del usuario — que no es nuestra. */
static int escribe_bloque(uint32_t lba, const unsigned char *buf)
{
    cs(1);
    if (comando(24, s_sdhc ? lba : lba * 512u, 0xFF) != 0x00) { cs(0); return 0; }
    xfer(0xFF);                                /* un byte de guarda antes del token */
    xfer(0xFE);                                /* token de inicio de bloque */
    for (int i = 0; i < 512; i++) xfer(buf[i]);
    xfer(0xFF); xfer(0xFF);                    /* CRC, que la tarjeta ignora en SPI */
    /* La respuesta de datos: xxx00101 = aceptado. Cualquier otra cosa es un fallo, y hay
     * que verlo aqui y no descubrirlo al releer. */
    uint8_t r = 0xFF;
    for (int i = 0; i < 1000 && (r & 0x11) != 0x01; i++) r = xfer(0xFF);
    if ((r & 0x1F) != 0x05) { cs(0); return 0; }
    /* Y ESPERAR A QUE SUELTE EL BUSY. La tarjeta mantiene MISO a 0 mientras programa; irse
     * antes deja la escritura a medias y el siguiente comando falla sin decir por que. */
    for (int i = 0; i < 500000; i++) if (xfer(0xFF) != 0x00) break;
    cs(0);
    return 1;
}

#endif  /* UVM2_SD_HOST */

/* ── FAT16/FAT32 ────────────────────────────────────────────────────────────── */
static uint16_t u16(const unsigned char *b, int o) { return (uint16_t)(b[o] | (b[o+1] << 8)); }
static uint32_t u32(const unsigned char *b, int o) {
    return (uint32_t)b[o] | ((uint32_t)b[o+1] << 8) | ((uint32_t)b[o+2] << 16) | ((uint32_t)b[o+3] << 24);
}

static struct {
    uint32_t inicio, fat, datos, raiz_cluster;
    uint16_t raiz_entradas; uint32_t raiz_sector;
    uint8_t  spc; int es32;
    /* Para ESCRIBIR hace falta saber cuantas copias de la FAT hay y cuanto mide cada una:
     * una FAT actualizada en una sola copia es una tarjeta que el PC ve corrupta. */
    uint8_t  nfats; uint32_t spf; uint32_t total_clusters;
    uint32_t fsinfo;            /* sector del FSInfo (FAT32); 0 si no hay */
} V;

/* Un BPB de verdad, no "los dos bytes que mire no son cero".
 *
 * El sector 0 de esta tarjeta es un MBR, y el codigo de arranque de un MBR puede tener
 * CUALQUIER cosa en los offsets 11 y 13 — que en un VBR son bytes-por-sector y
 * sectores-por-cluster. Si por casualidad no son cero, el sector 0 pasa por VBR, se monta
 * un volumen inventado y la busqueda falla con NO_ESTA, que es el mismo sintoma que un
 * fichero que no esta. Tres condiciones que un MBR no cumple por accidente: */
static int es_bpb(const unsigned char *b)
{
    if (b[0] != 0xEB && b[0] != 0xE9) return 0;          /* salto al codigo de arranque */
    if (u16(b, 11) != 512) return 0;                     /* bytes por sector */
    unsigned spc = b[13];
    return spc != 0 && (spc & (spc - 1)) == 0;           /* potencia de dos */
}

struct uvm2_sd_diag uvm2_sd_diag;

static int monta(unsigned char *b)
{
    if (!lee_bloque(0, b)) return 0;
    if (!(b[510] == 0x55 && b[511] == 0xAA)) return 0;

    uvm2_sd_diag.magia    = 0x47444453u;                 /* 'SDDG' */
    uvm2_sd_diag.sec0_b0  = b[0];
    uvm2_sd_diag.sec0_bps = u16(b, 11);
    uvm2_sd_diag.sec0_spc = b[13];

    uint32_t part = 0;
    if (!es_bpb(b)) {
        /* MBR: las CUATRO entradas, no solo la primera — una tarjeta puede traer la
         * particion en cualquiera de ellas, y una entrada vacia tiene tipo 0. */
        for (int i = 0; i < 4; i++) {
            const int e = 0x1BE + 16 * i;
            if (b[e + 4] == 0) continue;                 /* tipo 0 = entrada sin usar */
            uint32_t lba = u32(b, e + 8);
            if (!lba) continue;
            unsigned char v[512];
            if (!lee_bloque(lba, v)) continue;
            if (!es_bpb(v)) continue;
            part = lba;
            for (int k = 0; k < 512; k++) b[k] = v[k];
            break;
        }
        if (!part) return 0;
        uvm2_sd_diag.via_mbr = 1;
    }
    V.inicio = part;
    V.spc = b[13];
    uint16_t reservados = u16(b, 14);
    uint8_t  nfats = b[16];
    V.raiz_entradas = u16(b, 17);
    uint32_t spf = u16(b, 22);
    V.es32 = (spf == 0);
    if (V.es32) { spf = u32(b, 36); V.raiz_cluster = u32(b, 44); V.fsinfo = V.inicio + u16(b, 48); }
    else        { V.fsinfo = 0; }
    V.fat = part + reservados;
    V.nfats = nfats; V.spf = spf;
    V.raiz_sector = V.fat + (uint32_t)nfats * spf;
    V.datos = V.raiz_sector + (V.raiz_entradas * 32u + 511u) / 512u;
    /* CUANTOS CLUSTERS TIENE EL VOLUMEN. Sin este tope, buscar uno libre se sale de la FAT
     * y "encuentra" basura fuera del sistema de ficheros. */
    {
        uint32_t tot = u16(b, 19);
        if (tot == 0) tot = u32(b, 32);
        V.total_clusters = (tot > (V.datos - V.inicio))
                         ? (tot - (V.datos - V.inicio)) / (V.spc ? V.spc : 1u) + 2u : 0u;
    }

    uvm2_sd_diag.inicio        = V.inicio;
    uvm2_sd_diag.spc           = V.spc;
    uvm2_sd_diag.es32          = V.es32;
    uvm2_sd_diag.raiz_cluster  = V.raiz_cluster;
    uvm2_sd_diag.fat           = V.fat;
    uvm2_sd_diag.raiz_sector   = V.raiz_sector;
    uvm2_sd_diag.datos         = V.datos;
    uvm2_sd_diag.raiz_entradas = V.raiz_entradas;
    return V.spc != 0;
}

/* ── ESCRITURA: crear un fichero de UN cluster ────────────────────────────────────────
 *
 * Solo AÑADE: coge un cluster que la FAT marca libre y una entrada de directorio libre. No
 * mueve, no borra y no toca nada que ya estuviera en uso. Si algo no cuadra, aborta ANTES de
 * escribir — mas vale no guardar la calibracion que dejar la tarjeta del usuario tocada.
 *
 * Un cluster basta: el fichero de configuracion son cuatro lineas. Ficheros mayores pedirian
 * encadenar clusters, y eso no hace falta para esto. */

/* Escribe una entrada de la FAT en TODAS sus copias. Una FAT actualizada en una sola copia
 * es una tarjeta que el PC ve corrupta — y eso lo nota el usuario, no nosotros. */
static int fat_pon(uint32_t c, uint32_t valor, unsigned char *b)
{
    const uint32_t off = V.es32 ? c * 4u : c * 2u;
    const uint32_t sec = off / 512u, dentro = off % 512u;
    for (uint8_t f = 0; f < V.nfats; f++) {
        const uint32_t lba = V.fat + (uint32_t)f * V.spf + sec;
        if (!lee_bloque(lba, b)) return 0;
        if (V.es32) {
            uint32_t v = u32(b, (int)dentro);
            v = (v & 0xF0000000u) | (valor & 0x0FFFFFFFu);   /* los 4 bits altos son reservados */
            b[dentro] = (uint8_t)v; b[dentro+1] = (uint8_t)(v >> 8);
            b[dentro+2] = (uint8_t)(v >> 16); b[dentro+3] = (uint8_t)(v >> 24);
        } else {
            b[dentro] = (uint8_t)valor; b[dentro+1] = (uint8_t)(valor >> 8);
        }
        if (!escribe_bloque(lba, b)) return 0;
    }
    return 1;
}

/* El primer cluster LIBRE (entrada de FAT a 0), marcado ya como fin de cadena. 0 si no hay. */
static uint32_t asigna_este(uint32_t c, unsigned char *b);

/* UN SECTOR DE FAT SE LEE UNA VEZ, NO UNA VEZ POR CLUSTER.
 *
 * Esto recorria cluster a cluster y en CADA uno leia el sector entero de la tarjeta: en
 * FAT32 caben 128 entradas por sector, asi que hacia 128 veces las lecturas necesarias (256
 * en FAT16). En una tarjeta de 16 GB con el primer hueco lejos eso son decenas de miles de
 * lecturas por SPI a pedal — y en consola se ve como un cuelgue, que es lo que le pasaba a
 * Daniel al terminar la calibracion.
 *
 * Y SE EMPIEZA POR LA PISTA DEL FSInfo, que existe justo para esto: FAT32 guarda "el
 * siguiente cluster libre" y lo mantenemos al asignar. Si la pista miente —puede, es solo
 * una pista— se vuelve a barrer desde el principio. */
static uint32_t asigna_cluster(unsigned char *b)
{
    const uint32_t fin = V.total_clusters ? V.total_clusters : 0xFFFFFFu;
    uint32_t desde = 2;
    if (V.es32 && V.fsinfo && lee_bloque(V.fsinfo, b)
        && u32(b, 0) == 0x41615252u && u32(b, 484) == 0x61417272u) {
        const uint32_t pista = u32(b, 492);
        if (pista >= 2 && pista < fin) desde = pista;
    }
    for (int vuelta = 0; vuelta < 2; vuelta++) {
        const uint32_t c0 = vuelta ? 2u : desde;
        const uint32_t c1 = vuelta ? desde : fin;
        const uint32_t por_sector = V.es32 ? 128u : 256u;
        for (uint32_t base = c0 - (c0 % por_sector); base < c1; base += por_sector) {
            const uint32_t off = V.es32 ? base * 4u : base * 2u;
            if (!lee_bloque(V.fat + off / 512u, b)) return 0;
            for (uint32_t k = 0; k < por_sector; k++) {
                const uint32_t c = base + k;
                if (c < c0 || c >= c1 || c < 2) continue;
                const uint32_t dentro = V.es32 ? k * 4u : k * 2u;
                const uint32_t v = V.es32 ? (u32(b, (int)dentro) & 0x0FFFFFFFu)
                                          : u16(b, (int)dentro);
                if (v != 0) continue;
                return asigna_este(c, b);
            }
        }
    }
    return 0;
}

/* Marca `c` como fin de cadena y actualiza el FSInfo. Separado para que el barrido de arriba
 * no tenga que salir de dos bucles anidados. */
static uint32_t asigna_este(uint32_t c, unsigned char *b)
{
    {
        if (!fat_pon(c, V.es32 ? 0x0FFFFFFFu : 0xFFFFu, b)) return 0;
        /* EL FSInfo DE FAT32, que lleva la cuenta del espacio libre. Es solo una PISTA —el
         * sistema puede recalcularla— pero dejarla desfasada hace que `fsck_msdos` avise, y
         * un aviso en la tarjeta del usuario es nuestro aunque no rompa nada. Medido: sin
         * esto, "Free space in FSInfo block (258077) not correct (258076)". */
        if (V.fsinfo) {
            if (lee_bloque(V.fsinfo, b) && u32(b, 0) == 0x41615252u && u32(b, 484) == 0x61417272u) {
                uint32_t libres = u32(b, 488);
                if (libres != 0xFFFFFFFFu && libres > 0) {
                    libres--;
                    b[488] = (uint8_t)libres; b[489] = (uint8_t)(libres >> 8);
                    b[490] = (uint8_t)(libres >> 16); b[491] = (uint8_t)(libres >> 24);
                }
                b[492] = (uint8_t)(c + 1); b[493] = (uint8_t)((c + 1) >> 8);      /* pista */
                b[494] = (uint8_t)((c + 1) >> 16); b[495] = (uint8_t)((c + 1) >> 24);
                escribe_bloque(V.fsinfo, b);      /* si falla, solo queda la pista vieja */
            }
        }
        return c;
    }
    return 0;
}

static uint32_t siguiente(uint32_t c, unsigned char *b)
{
    uint32_t off = V.es32 ? c * 4u : c * 2u;
    if (!lee_bloque(V.fat + off / 512u, b)) return 0x0FFFFFFF;
    return V.es32 ? (u32(b, (int)(off % 512)) & 0x0FFFFFFFu) : u16(b, (int)(off % 512));
}
static uint32_t sector_de(uint32_t c) { return V.datos + (c - 2) * V.spc; }

/* Busca `nombre` (formato 8.3, ya en mayusculas y sin punto: "DKONG   ZIP") en el
 * directorio que empieza en `cluster` (0 = la raiz FAT16). Devuelve 1 y deja el cluster y
 * el tamaño. */
static int busca(uint32_t cluster, const char *n83, uint32_t *out_c, uint32_t *out_len,
                 unsigned char *b)
{
    uint32_t sec, quedan;
    if (cluster == 0 && !V.es32) { sec = V.raiz_sector; quedan = (V.raiz_entradas * 32u + 511u) / 512u; }
    else                         { sec = sector_de(cluster); quedan = V.spc; }
    for (;;) {
        for (uint32_t s = 0; s < quedan; s++) {
            if (!lee_bloque(sec + s, b)) return 0;
            for (int e = 0; e < 512; e += 32) {
                if (b[e] == 0x00) return 0;             /* fin del directorio */
                uvm2_sd_diag.entradas++;
                if (b[e] == 0xE5 || (b[e+11] & 0x0F) == 0x0F) continue;   /* borrada / VFAT */
                int igual = 1;
                for (int i = 0; i < 11; i++) if (b[e+i] != (unsigned char)n83[i]) { igual = 0; break; }
                if (!igual) continue;
                *out_c   = ((uint32_t)u16(b, e+20) << 16) | u16(b, e+26);
                *out_len = u32(b, e+28);
                return 1;
            }
        }
        if (cluster == 0 && !V.es32) return 0;
        cluster = siguiente(cluster, b);
        if (cluster < 2 || cluster >= 0x0FFFFFF8u) return 0;
        sec = sector_de(cluster); quedan = V.spc;
    }
}

/* "roms/dkong.zip" -> "ROMS       " y "DKONG   ZIP". Sin comodines ni nombres largos:
 * el cartucho pide un nombre exacto que ya viene declarado en el juego. */
static void a83(const char *s, int n, char *out)
{
    int i = 0, j = 0;
    for (; i < 11; i++) out[i] = ' ';
    for (i = 0; i < n && s[i] && s[i] != '.'; i++)
        if (j < 8) out[j++] = (s[i] >= 'a' && s[i] <= 'z') ? (char)(s[i] - 32) : s[i];
    if (i < n && s[i] == '.') {
        i++; j = 8;
        for (; i < n && s[i]; i++)
            if (j < 11) out[j++] = (s[i] >= 'a' && s[i] <= 'z') ? (char)(s[i] - 32) : s[i];
    }
}

/* LEER UN TROZO, NO EL FICHERO ENTERO.
 *
 * `uvm2_sd_leer` lee el fichero completo y falla con NO_CABE si no entra en el buffer, lo
 * cual basta para un romset de 68 KB y no para una captura de 20 segundos (unos 14 MB de
 * comandos). Con un desplazamiento, la RAM que hace falta deja de depender de lo largo que
 * sea el fichero: se leen dos frames y se va pidiendo el siguiente.
 *
 * `desde` es una posicion en BYTES dentro del fichero. Devuelve lo copiado, que puede ser
 * menos que `max` si el fichero se acaba antes. La busqueda del fichero es la misma, asi
 * que un lector que avance frame a frame vuelve a recorrer el directorio en cada llamada —
 * a 50 Hz eso es barato comparado con leer los datos, pero conviene saberlo. */
static uint32_t leer_rango(const char *ruta, unsigned char *dst, uint32_t max,
                           uint32_t desde, uint32_t *len_out)
{
    static unsigned char b[512];
    uvm2_sd_error = UVM2_SD_OK;

    /* Sin pin de deteccion: si no hay tarjeta, se ve como NO_ARRANCA. */
    if (!uvm2_sd_init()) return 0;
    if (!monta(b)) { uvm2_sd_error = UVM2_SD_SIN_FAT; return 0; }

    const char *barra = 0;
    for (const char *p = ruta; *p; p++) if (*p == '/') barra = p;

    uint32_t dir = V.es32 ? V.raiz_cluster : 0;
    char n83[11];
    if (barra) {
        uint32_t len;
        a83(ruta, (int)(barra - ruta), n83);
        uvm2_sd_diag.paso = 1;                    /* buscando el subdirectorio */
        if (!busca(dir, n83, &dir, &len, b)) { uvm2_sd_error = UVM2_SD_NO_ESTA; return 0; }
        uvm2_sd_diag.dir_cluster = dir;
        ruta = barra + 1;
    }
    uint32_t c, len;
    a83(ruta, 64, n83);
    uvm2_sd_diag.paso = 2;                        /* buscando el fichero */
    if (!busca(dir, n83, &c, &len, b)) { uvm2_sd_error = UVM2_SD_NO_ESTA; return 0; }
    if (len_out) *len_out = len;
    if (desde >= len) return 0;                   /* pasado el final: cero, sin error */
    uint32_t queda = len - desde;
    if (queda > max) queda = max;                 /* lo que quepa; NO es un fallo */

    uint32_t pos = 0, escrito = 0;
    while (c >= 2 && c < 0x0FFFFFF8u && escrito < queda) {
        uint32_t sec = sector_de(c);
        for (uint32_t s = 0; s < V.spc && escrito < queda; s++) {
            /* SALTAR SECTORES ENTEROS SIN LEERLOS. Un desplazamiento grande no puede
             * costar una lectura de bloque por cada 512 bytes que nos saltamos. */
            if (pos + 512u <= desde) { pos += 512u; continue; }
            if (!lee_bloque(sec + s, b)) return 0;
            uint32_t ini = (desde > pos) ? (desde - pos) : 0;   /* dentro de este bloque */
            uint32_t n   = 512u - ini;
            if (n > queda - escrito) n = queda - escrito;
            for (uint32_t i = 0; i < n; i++) dst[escrito + i] = b[ini + i];
            escrito += n; pos += 512u;
        }
        c = siguiente(c, b);
    }
    return escrito;
}

/* Un trozo desde `desde`: lo que quepa, y quedarse corto NO es un fallo. */
uint32_t uvm2_sd_leer_desde(const char *ruta, unsigned char *dst, uint32_t max, uint32_t desde)
{
    return leer_rango(ruta, dst, max, desde, 0);
}

/* El fichero ENTERO, con la semantica de siempre: si no cabe es un FALLO. Es lo que espera
 * el cargador de romsets — un romset a medias no es un romset — y por eso se comprueba
 * aqui y no dentro, donde el lector por trozos necesita justo lo contrario. */
uint32_t uvm2_sd_leer(const char *ruta, unsigned char *dst, uint32_t max)
{
    uint32_t len = 0;
    uint32_t n = leer_rango(ruta, dst, max, 0, &len);
    if (len > max) { uvm2_sd_error = UVM2_SD_NO_CABE; return 0; }
    return n;
}

/* SOBRESCRIBIR EN SITIO EL PRIMER SECTOR DE UN FICHERO QUE YA EXISTE.
 *
 * Lo unico que se puede hacer sin riesgo con un lector de solo lectura: no toca la FAT ni la
 * entrada de directorio, asi que ni el tamaño ni la cadena de clusters cambian. Por eso NO
 * crea el fichero: si no esta, devuelve 0 y quien llame que lo diga en pantalla.
 *
 * `n` tiene que caber en 512 y el fichero medir al menos eso. El sector se lee primero y se
 * rellena el resto con espacios y un salto de linea, para que el fichero siga siendo texto
 * legible desde el PC y no arrastre lo que hubiera antes.
 */
int uvm2_sd_sobrescribir(const char *ruta, const unsigned char *datos, uint32_t n)
{
    static unsigned char b[512];
    uvm2_sd_error = UVM2_SD_OK;
    if (n == 0 || n > 512) { uvm2_sd_error = UVM2_SD_NO_CABE; return 0; }
    if (!uvm2_sd_init()) return 0;
    if (!monta(b)) { uvm2_sd_error = UVM2_SD_SIN_FAT; return 0; }

    const char *barra = 0;
    for (const char *p = ruta; *p; p++) if (*p == '/') barra = p;
    uint32_t dir = V.es32 ? V.raiz_cluster : 0;
    char n83[11];
    if (barra) {
        uint32_t len;
        a83(ruta, (int)(barra - ruta), n83);
        if (!busca(dir, n83, &dir, &len, b)) { uvm2_sd_error = UVM2_SD_NO_ESTA; return 0; }
        ruta = barra + 1;
    }
    uint32_t c, len;
    a83(ruta, 64, n83);
    if (!busca(dir, n83, &c, &len, b)) { uvm2_sd_error = UVM2_SD_NO_ESTA; return 0; }
    if (len < 512) { uvm2_sd_error = UVM2_SD_NO_CABE; return 0; }

    const uint32_t lba = sector_de(c);
    if (!lee_bloque(lba, b)) return 0;
    for (uint32_t i = 0; i < n; i++) b[i] = datos[i];
    for (uint32_t i = n; i < 512; i++) b[i] = ' ';
    b[511] = '\n';
    return escribe_bloque(lba, b);
}

static int crea_entrada_attr(uint32_t dir, const char *n83, uint32_t cluster, uint32_t len,
                             unsigned char attr, unsigned char *b);

/* Añade una entrada de directorio en el primer hueco (borrada 0xE5 o fin 0x00). Devuelve 0
 * si el directorio esta lleno — no lo extiende: extender el directorio raiz de FAT16 es
 * IMPOSIBLE (es de tamaño fijo) y extender uno de FAT32 pediria encadenar clusters. Con un
 * directorio lleno, mejor no guardar que inventar. */
static int crea_entrada_attr(uint32_t dir, const char *n83, uint32_t cluster, uint32_t len,
                             unsigned char attr, unsigned char *b)
{
    uint32_t sec, quedan;
    if (dir == 0 && !V.es32) { sec = V.raiz_sector; quedan = (V.raiz_entradas * 32u + 511u) / 512u; }
    else                     { sec = sector_de(dir); quedan = V.spc; }
    for (;;) {
        for (uint32_t s = 0; s < quedan; s++) {
            if (!lee_bloque(sec + s, b)) return 0;
            for (int e = 0; e < 512; e += 32) {
                if (b[e] != 0x00 && b[e] != 0xE5) continue;
                const int era_fin = (b[e] == 0x00);
                for (int i = 0; i < 32; i++) b[e + i] = 0;
                for (int i = 0; i < 11; i++) b[e + i] = (unsigned char)n83[i];
                b[e + 11] = attr;                                  /* 0x20 fichero, 0x10 directorio */
                b[e + 26] = (unsigned char)cluster;                /* cluster bajo */
                b[e + 27] = (unsigned char)(cluster >> 8);
                if (V.es32) {
                    b[e + 20] = (unsigned char)(cluster >> 16);    /* cluster alto */
                    b[e + 21] = (unsigned char)(cluster >> 24);
                }
                b[e + 28] = (unsigned char)len;
                b[e + 29] = (unsigned char)(len >> 8);
                b[e + 30] = (unsigned char)(len >> 16);
                b[e + 31] = (unsigned char)(len >> 24);
                /* SI OCUPABAMOS EL FIN DE DIRECTORIO, HAY QUE PONER UNO NUEVO DETRAS. Sin
                 * esto el recorrido no sabe donde parar y lee basura como entradas. */
                if (era_fin && e + 32 < 512) b[e + 32] = 0x00;
                return escribe_bloque(sec + s, b);
            }
        }
        if (dir == 0 && !V.es32) return 0;          /* raiz de FAT16: no se puede extender */
        dir = siguiente(dir, b);
        if (dir < 2 || dir >= 0x0FFFFFF8u) return 0;
        sec = sector_de(dir); quedan = V.spc;
    }
}

static int crea_entrada(uint32_t dir, const char *n83, uint32_t cluster, uint32_t len,
                        unsigned char *b)
{
    return crea_entrada_attr(dir, n83, cluster, len, 0x20, b);
}

/* CREA UN SUBDIRECTORIO VACIO y devuelve su cluster (0 si no se pudo).
 *
 * Un directorio es un fichero cuyo contenido son entradas, con dos obligatorias al
 * principio: `.` que apunta a si mismo y `..` al padre — y en `..` la RAIZ se escribe como
 * cluster 0 aunque en FAT32 la raiz tenga cluster de verdad. Ese detalle es de la norma y
 * saltarselo hace que el PC no sepa subir. */
static uint32_t crea_directorio(uint32_t padre, const char *n83, unsigned char *b)
{
    const uint32_t c = asigna_cluster(b);
    if (c == 0) return 0;

    for (int i = 0; i < 512; i++) b[i] = 0;
    static const char punto[11]  = { '.',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ' };
    static const char dosp[11]   = { '.','.',' ',' ',' ',' ',' ',' ',' ',' ',' ' };
    for (int i = 0; i < 11; i++) b[i] = (unsigned char)punto[i];
    b[11] = 0x10;                                   /* DIRECTORY */
    b[26] = (unsigned char)c; b[27] = (unsigned char)(c >> 8);
    b[20] = (unsigned char)(c >> 16); b[21] = (unsigned char)(c >> 24);
    for (int i = 0; i < 11; i++) b[32 + i] = (unsigned char)dosp[i];
    b[32 + 11] = 0x10;
    /* `..` a la raiz se escribe SIEMPRE como cluster 0, tambien en FAT32. */
    const uint32_t pc = (padre == V.raiz_cluster && V.es32) ? 0u : padre;
    b[32 + 26] = (unsigned char)pc;       b[32 + 27] = (unsigned char)(pc >> 8);
    b[32 + 20] = (unsigned char)(pc >> 16); b[32 + 21] = (unsigned char)(pc >> 24);
    if (!escribe_bloque(sector_de(c), b)) return 0;
    for (uint32_t sx = 1; sx < V.spc; sx++) {
        static unsigned char z[512];
        for (int i = 0; i < 512; i++) z[i] = 0;
        if (!escribe_bloque(sector_de(c) + sx, z)) return 0;
    }
    if (!crea_entrada_attr(padre, n83, c, 0u, 0x10, b)) return 0;
    return c;
}

/* CREA UN FICHERO DE UN CLUSTER Y LE ESCRIBE `datos`.
 *
 * Si la ruta lleva subdirectorio y ese subdirectorio NO existe, el fichero se crea en la
 * RAIZ con el mismo nombre. Crear directorios pediria escribir sus entradas '.' y '..' y
 * duplica la superficie de fallo por muy poco: con la raiz, cualquier tarjeta vale.
 */
/* Resuelve la carpeta de `ruta`, creandola si hace falta, y deja el nombre 8.3 del fichero.
 * Lo compartian `crear` y ahora tambien `escribir`, y estaba duplicado. */
static int carpeta_de(const char **ruta, char *n83, uint32_t *dir, unsigned char *b)
{
    const char *barra = 0;
    for (const char *p = *ruta; *p; p++) if (*p == '/') barra = p;
    *dir = V.es32 ? V.raiz_cluster : 0;
    if (barra) {
        uint32_t c, len;
        a83(*ruta, (int)(barra - *ruta), n83);
        if (busca(*dir, n83, &c, &len, b)) *dir = c;
        else {
            const uint32_t nd = crea_directorio(*dir, n83, b);
            if (nd == 0) { uvm2_sd_error = UVM2_SD_NO_CABE; return 0; }
            *dir = nd;
        }
        *ruta = barra + 1;
    }
    a83(*ruta, 64, n83);
    return 1;
}

/* UN FICHERO DE CUALQUIER TAMAÑO (2026-09-16).
 *
 * `uvm2_sd_crear` escribe un solo cluster y `uvm2_sd_sobrescribir` un solo sector, y con eso
 * un juego no puede volcar nada de verdad — ni una traza, ni una partida guardada, ni una
 * captura. La limitacion era mia, no del sistema de ficheros: encadenar clusters en la FAT es
 * justamente para lo que sirve la FAT, y el asignador ya marca cada uno como fin de cadena al
 * darlo, asi que basta con repasar el anterior para que apunte al siguiente.
 *
 * El orden importa y es el mismo que en `crear`: primero los datos, luego la entrada de
 * directorio. Si algo se corta a medias quedan clusters en uso sin nadie que los apunte —
 * espacio perdido que un chkdsk recupera — y no una entrada apuntando a basura, que el PC
 * lee como fichero corrupto.
 *
 * Probado como se debe: `hardware/uvm2/tools/prueba_fat.c` lo ejecuta contra imagenes FAT16 y
 * FAT32 reales hechas con newfs_msdos, y despues `fsck_msdos -n` tiene que salir limpio. */
int uvm2_sd_escribir(const char *ruta, const unsigned char *datos, uint32_t n)
{
    static unsigned char b[512];
    uint32_t dir, primero = 0, anterior = 0, escrito = 0, i;
    char n83[11];

    uvm2_sd_error = UVM2_SD_OK;
    if (n == 0) { uvm2_sd_error = UVM2_SD_NO_CABE; return 0; }
    if (!uvm2_sd_init()) return 0;
    if (!monta(b)) { uvm2_sd_error = UVM2_SD_SIN_FAT; return 0; }
    if (!carpeta_de(&ruta, n83, &dir, b)) return 0;

    {
        const uint32_t por_cluster = 512u * (uint32_t)V.spc;
        const uint32_t cuantos = (n + por_cluster - 1u) / por_cluster;

        for (i = 0; i < cuantos; i++) {
            const uint32_t c = asigna_cluster(b);
            uint32_t sec;
            if (c == 0) { uvm2_sd_error = UVM2_SD_NO_CABE; return 0; }
            /* Encadenar: el anterior deja de ser fin de cadena y apunta a este. */
            if (anterior) { if (!fat_pon(anterior, c, b)) return 0; }
            else          { primero = c; }
            anterior = c;

            for (sec = 0; sec < V.spc && escrito < n; sec++) {
                uint32_t k = 0;
                while (k < 512u && escrito < n) b[k++] = datos[escrito++];
                while (k < 512u)                b[k++] = 0;   /* la cola del ultimo sector */
                if (!escribe_bloque(sector_de(c) + sec, b)) return 0;
            }
        }
    }

    return crea_entrada(dir, n83, primero, n, b);
}

int uvm2_sd_crear(const char *ruta, const unsigned char *datos, uint32_t n)
{
    static unsigned char b[512];
    uvm2_sd_error = UVM2_SD_OK;
    if (n == 0 || n > 512) { uvm2_sd_error = UVM2_SD_NO_CABE; return 0; }
    if (!uvm2_sd_init()) return 0;
    if (!monta(b)) { uvm2_sd_error = UVM2_SD_SIN_FAT; return 0; }

    const char *barra = 0;
    for (const char *p = ruta; *p; p++) if (*p == '/') barra = p;
    uint32_t dir = V.es32 ? V.raiz_cluster : 0;
    char n83[11];
    if (barra) {
        uint32_t c, len;
        a83(ruta, (int)(barra - ruta), n83);
        if (busca(dir, n83, &c, &len, b)) dir = c;
        else {
            /* NO EXISTE: SE CREA. Antes esto caia a la raiz con el mismo nombre, y era un
             * apaño: el lector busca en `config/` y no lo habria encontrado nunca. */
            const uint32_t nd = crea_directorio(dir, n83, b);
            if (nd == 0) { uvm2_sd_error = UVM2_SD_NO_CABE; return 0; }
            dir = nd;
        }
        ruta = barra + 1;
    }
    a83(ruta, 64, n83);

    const uint32_t c = asigna_cluster(b);
    if (c == 0) { uvm2_sd_error = UVM2_SD_NO_CABE; return 0; }

    /* El dato ANTES que la entrada: si algo falla, queda un cluster marcado en uso y nada
     * que apunte a el — se pierde espacio, que es reparable con un chkdsk. Al reves quedaria
     * una entrada apuntando a basura, que el PC lee como fichero corrupto. */
    for (uint32_t i = 0; i < n; i++) b[i] = datos[i];
    for (uint32_t i = n; i < 512; i++) b[i] = ' ';
    b[511] = '\n';
    if (!escribe_bloque(sector_de(c), b)) return 0;
    /* EL RESTO DEL CLUSTER NO SE PONE A CERO, Y ANTES SI.
     *
     * Decia "lo que hubiera antes no es nuestro y confunde al leerlo", y no: el fichero mide
     * 512 bytes y NADIE lee mas alla de su longitud — eso es hueco de cluster, y ningun
     * sistema de ficheros lo mira. Lo que si costaba era tiempo: en una tarjeta de 16 GB el
     * cluster son 32 o 64 KB, o sea entre 63 y 127 escrituras de UN sector cada una, y una
     * escritura suelta en una SD barata puede irse a decenas de milisegundos porque obliga a
     * borrar un bloque entero. Eso son SEGUNDOS por fichero, y en consola se ve como un
     * cuelgue.
     *
     * Un directorio SI hay que ponerlo a cero —sus entradas vacias tienen que valer 0x00
     * para que el recorrido pare— y `crea_directorio` lo sigue haciendo. */
    return crea_entrada(dir, n83, c, 512u, b);
}
