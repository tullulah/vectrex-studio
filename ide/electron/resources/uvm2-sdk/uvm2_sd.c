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

/* ── FAT16/FAT32, solo lectura y lo justo ──────────────────────────────────── */
static uint16_t u16(const unsigned char *b, int o) { return (uint16_t)(b[o] | (b[o+1] << 8)); }
static uint32_t u32(const unsigned char *b, int o) {
    return (uint32_t)b[o] | ((uint32_t)b[o+1] << 8) | ((uint32_t)b[o+2] << 16) | ((uint32_t)b[o+3] << 24);
}

static struct {
    uint32_t inicio, fat, datos, raiz_cluster;
    uint16_t raiz_entradas; uint32_t raiz_sector;
    uint8_t  spc; int es32;
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
    if (V.es32) { spf = u32(b, 36); V.raiz_cluster = u32(b, 44); }
    V.fat = part + reservados;
    V.raiz_sector = V.fat + (uint32_t)nfats * spf;
    V.datos = V.raiz_sector + (V.raiz_entradas * 32u + 511u) / 512u;

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

uint32_t uvm2_sd_leer(const char *ruta, unsigned char *dst, uint32_t max)
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
    if (len > max) { uvm2_sd_error = UVM2_SD_NO_CABE; return 0; }

    uint32_t escrito = 0;
    while (c >= 2 && c < 0x0FFFFFF8u && escrito < len) {
        uint32_t sec = sector_de(c);
        for (uint32_t s = 0; s < V.spc && escrito < len; s++) {
            if (!lee_bloque(sec + s, b)) return 0;
            uint32_t n = (len - escrito < 512u) ? (len - escrito) : 512u;
            for (uint32_t i = 0; i < n; i++) dst[escrito + i] = b[i];
            escrito += n;
        }
        c = siguiente(c, b);
    }
    return escrito;
}
