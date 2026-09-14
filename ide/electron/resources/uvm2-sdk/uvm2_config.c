/* uvm2_config.c — ver uvm2_config.h para el porque de cada decision. */
#include "uvm2_config.h"
#include "uvm2_draw.h"
#include "uvm2_sd.h"
#include <string.h>

#include "hardware/flash.h"
#include "hardware/sync.h"

/* Los knobs del modelo viven en Rust y salen como simbolos; los del SDK, aqui. */
extern volatile uint32_t DRAW_SCALE, T1_EXTRA_Q8;
extern volatile int32_t  TASA_NEG_X, TASA_NEG_Y;   /* vectrex-draw, ver uvm2_config.h */
extern volatile int32_t  uvm2_cero_offset;
void uvm2_draw_intensity(int brightness);

#define RUTA_SD  "config/uvm2.cfg"

volatile int uvm2_hay_calibracion = 0;

/* EL ULTIMO SECTOR DE LA FLASH, y el tamaño sale del propio SDK (4096) en vez de a mano.
 * `PICO_FLASH_SIZE_BYTES` lo define el linker script del target. */
#ifndef UVM2_CONFIG_FLASH_OFF
#define UVM2_CONFIG_FLASH_OFF  (PICO_FLASH_SIZE_BYTES - FLASH_SECTOR_SIZE)
#endif

/* Una firma para distinguir "sin calibrar" de "calibrado a ceros", que es la trampa de
 * una-cadena-de-contrato-invisible: un cero se lee igual que «no hace falta». */
#define FIRMA  0x43414C31u   /* "CAL1" */

struct guardado { uint32_t firma; struct uvm2_config c; uint32_t suma; };

static uint32_t suma_de(const struct uvm2_config *c)
{
    return (uint32_t)c->escala * 2654435761u ^ (uint32_t)c->fijo_q8 * 40503u
         ^ (uint32_t)c->cero  * 2246822519u ^ (uint32_t)c->brillo * 374761393u
         ^ (uint32_t)c->hold_y_min * 668265263u ^ (uint32_t)c->hold_y_max * 3266489917u
         ^ (uint32_t)c->tasa_neg_x * 2654435769u ^ (uint32_t)c->tasa_neg_y * 40499u;
}

void uvm2_config_actual(struct uvm2_config *c)
{
    c->escala  = (int32_t)DRAW_SCALE;
    c->fijo_q8 = (int32_t)T1_EXTRA_Q8;
    c->cero    = uvm2_cero_offset;
    c->brillo  = uvm2_draw_intensity_actual();
    c->hold_y_min = uvm2_hold_y_min;
    c->hold_y_max = uvm2_hold_y_max;
    c->tasa_neg_x = TASA_NEG_X;
    c->tasa_neg_y = TASA_NEG_Y;
}

void uvm2_config_aplicar(const struct uvm2_config *c)
{
    if (c->escala > 0)  DRAW_SCALE  = (uint32_t)c->escala;
    T1_EXTRA_Q8     = (uint32_t)c->fijo_q8;
    uvm2_cero_offset = c->cero;
    if (c->brillo >= 0) uvm2_draw_intensity(c->brillo);
    /* UN CERO AQUI ES "el fichero es viejo", no "sin retencion". Una calibracion guardada
     * antes de que estos dos campos existieran los trae a cero, y muestrear cero ciclos
     * dejaria la Y sin cargar: se ignoran y se quedan los de siempre. Es la trampa de
     * una-cadena-de-contrato-invisible, y aqui se ve venir. */
    if (c->hold_y_min > 0) uvm2_hold_y_min = c->hold_y_min;
    if (c->hold_y_max > 0) uvm2_hold_y_max = c->hold_y_max;
    /* Estos SI pueden ser cero: cero es "sin correccion", que es el defecto honesto. */
    TASA_NEG_X = c->tasa_neg_x;
    TASA_NEG_Y = c->tasa_neg_y;
}

/* ── EL FICHERO DE TEXTO DE LA SD ────────────────────────────────────────────────────
 *
 * `clave valor` por linea, decimal con signo. Texto y no binario a proposito: se mira y se
 * edita desde el PC, que mientras estemos afinando el haz vale mas que la comodidad — y una
 * calibracion que no se puede leer es una calibracion que no se puede discutir. */
static int lee_entero(const char *s, int32_t *out)
{
    int32_t v = 0; int signo = 1, hay = 0;
    if (*s == '-') { signo = -1; s++; }
    while (*s >= '0' && *s <= '9') { v = v * 10 + (*s++ - '0'); hay = 1; }
    if (hay) *out = v * signo;
    return hay;
}

static int cargar_de_sd(struct uvm2_config *c)
{
    static unsigned char buf[512];
    uint32_t n = uvm2_sd_leer(RUTA_SD, buf, sizeof buf - 1);
    if (n == 0 || n >= sizeof buf) return 0;
    buf[n] = 0;
    int visto = 0;
    for (unsigned char *p = buf; *p; ) {
        unsigned char *ln = p;
        while (*p && *p != '\n') p++;
        if (*p) *p++ = 0;
        while (*ln == ' ' || *ln == '\t') ln++;
        if (*ln == '#' || *ln == 0) continue;
        char *v = (char *)ln;
        while (*v && *v != ' ' && *v != '\t') v++;
        if (!*v) continue;
        *v++ = 0;
        while (*v == ' ' || *v == '\t') v++;
        int32_t x;
        if (!lee_entero(v, &x)) continue;
        if      (!strcmp((char *)ln, "escala"))  { c->escala  = x; visto = 1; }
        else if (!strcmp((char *)ln, "fijo_q8")) { c->fijo_q8 = x; visto = 1; }
        else if (!strcmp((char *)ln, "cero"))    { c->cero    = x; visto = 1; }
        else if (!strcmp((char *)ln, "brillo"))  { c->brillo  = x; visto = 1; }
        else if (!strcmp((char *)ln, "hold_y_min")) { c->hold_y_min = x; visto = 1; }
        else if (!strcmp((char *)ln, "hold_y_max")) { c->hold_y_max = x; visto = 1; }
        else if (!strcmp((char *)ln, "tasa_neg_x")) { c->tasa_neg_x = x; visto = 1; }
        else if (!strcmp((char *)ln, "tasa_neg_y")) { c->tasa_neg_y = x; visto = 1; }
    }
    return visto;
}

/* ── LA FLASH ────────────────────────────────────────────────────────────────────────── */
static const struct guardado *en_flash(void)
{
    return (const struct guardado *)(XIP_BASE + UVM2_CONFIG_FLASH_OFF);
}

static int cargar_de_flash(struct uvm2_config *c)
{
    const struct guardado *g = en_flash();
    if (g->firma != FIRMA || g->suma != suma_de(&g->c)) return 0;
    *c = g->c;
    return 1;
}

int uvm2_config_cargar(void)
{
    struct uvm2_config c;
    uvm2_config_actual(&c);            /* de partida, lo que traiga el juego compilado */
    /* LA SD MANDA SI EXISTE: asi se prueba un ajuste dejando caer un fichero, sin pasar por
     * el asistente ni por la flash. */
    int hay = cargar_de_sd(&c) || cargar_de_flash(&c);
    if (hay) uvm2_config_aplicar(&c);
    return hay;
}

/* GUARDAR EN FLASH, Y LA CONDICION QUE NO SE PUEDE ESCONDER.
 *
 * Borrar y programar flash PARA EL XIP: mientras dura, cualquier nucleo que ejecute o lea
 * desde flash se cuelga. Nuestro core 1 corre el ejecutor de la lista, asi que **el llamante
 * tiene que haberlo parado** — el asistente lo hace porque es el dueño del bucle de frame.
 * No lo hago aqui a proposito: pararlo por mi cuenta desde una funcion de configuracion
 * seria justo el tipo de efecto lateral escondido que este proyecto ya ha pagado.
 *
 * Se hace de una sola vez y con las interrupciones fuera: un sector son 4096 bytes y lo que
 * escribimos son 24, pero la flash solo se borra por sectores. */
/* Un entero a texto, sin printf: meterlo por cuatro numeros cuesta 20 KB de flash. */
static int pon_int(char *d, int32_t v)
{
    int p = 0;
    if (v < 0) { d[p++] = '-'; v = -v; }
    char t[8]; int k = 0;
    do { t[k++] = (char)('0' + v % 10); v /= 10; } while (v && k < 7);
    while (k) d[p++] = t[--k];
    return p;
}

static int pon_campo(char *d, const char *nombre, int32_t v)
{
    int p = 0;
    while (*nombre) d[p++] = *nombre++;
    d[p++] = ' ';
    p += pon_int(d + p, v);
    d[p++] = '\n';
    return p;
}

/* GUARDAR: EN LA SD, Y NO EN LA FLASH.
 *
 * La flash de este cartucho NO ES NUESTRA: el firmware del UVM2 ocupa ~15,6 MB de los 16
 * del RP2350, asi que el "ultimo sector libre" era muy probablemente suyo y borrarlo puede
 * dejarlo sin arrancar. Ver la nota de `#if 0` mas abajo.
 *
 * Se intenta primero SOBRESCRIBIR EN SITIO —que no toca la FAT ni el directorio y es lo mas
 * barato y seguro— y si el fichero no esta, se CREA, con su carpeta si hace falta.
 *
 * La creacion toca la FAT y el directorio, asi que esta probada contra imagenes FAT16 y
 * FAT32 REALES en el host (`tools/prueba_fat.c`): `fsck_msdos` no da un solo error en
 * ninguna de las dos, y macOS monta las imagenes y lee el fichero. Sin esa prueba no habria
 * tenido derecho a escribir en la tarjeta de nadie.
 */
int uvm2_config_guardar(void)
{
    struct uvm2_config c;
    uvm2_config_actual(&c);
    char txt[256];
    int p = 0;
    p += pon_campo(txt + p, "escala",  c.escala);
    p += pon_campo(txt + p, "fijo_q8", c.fijo_q8);
    p += pon_campo(txt + p, "cero",    c.cero);
    p += pon_campo(txt + p, "brillo",  c.brillo);
    p += pon_campo(txt + p, "hold_y_min", c.hold_y_min);
    p += pon_campo(txt + p, "hold_y_max", c.hold_y_max);
    p += pon_campo(txt + p, "tasa_neg_x", c.tasa_neg_x);
    p += pon_campo(txt + p, "tasa_neg_y", c.tasa_neg_y);
    if (uvm2_sd_sobrescribir(RUTA_SD, (const unsigned char *)txt, (uint32_t)p)) return 1;
    if (uvm2_sd_error != UVM2_SD_NO_ESTA && uvm2_sd_error != UVM2_SD_NO_CABE) return 0;
    return uvm2_sd_crear(RUTA_SD, (const unsigned char *)txt, (uint32_t)p);
}

/* ── EL CAMINO DE LA FLASH, PARADO ────────────────────────────────────────────────── */
static int guardar_en_flash_NO_USAR(void)

{
    struct guardado g;
    memset(&g, 0xFF, sizeof g);        /* el resto de la pagina, como la deja el borrado */
    g.firma = FIRMA;
    uvm2_config_actual(&g.c);
    g.suma = suma_de(&g.c);

    static uint8_t pagina[FLASH_PAGE_SIZE];
    memset(pagina, 0xFF, sizeof pagina);
    memcpy(pagina, &g, sizeof g < sizeof pagina ? sizeof g : sizeof pagina);

    /* ── PARADO: LA FLASH DE ESTE CARTUCHO NO ES NUESTRA ────────────────────────────
     *
     * El firmware del UVM2 (Ultimate Vectrex Multicart 2 v1.1.8a) ocupa ~15,6 MB de los
     * 16 del RP2350, asi que el "ultimo sector libre" que este codigo daba por hecho es
     * muy probablemente SUYO. Borrarlo puede dejar el cartucho sin arrancar — y eso no es
     * un fallo que se arregle con otro flasheo, porque el que flashea es el firmware.
     *
     * Nuestras imagenes .um2 se cargan desde la SD a RAM/PSRAM: no somos los dueños de esa
     * flash y no tenemos ningun mapa que diga que sobra. Hasta tener ese mapa, esto NO
     * escribe. La persistencia va por la SD, sobrescribiendo EN SITIO un fichero que ya
     * existe — sin tocar la FAT ni el directorio, que es lo unico que se puede hacer sin
     * riesgo con un lector de solo lectura.
     *
     * Se deja el codigo, no se borra: cuando se sepa que region esta libre, se descomenta y
     * ya esta. Un `#if 0` con el porque al lado vale mas que un hueco. */
#if 0
    uint32_t irq = save_and_disable_interrupts();
    flash_range_erase(UVM2_CONFIG_FLASH_OFF, FLASH_SECTOR_SIZE);
    flash_range_program(UVM2_CONFIG_FLASH_OFF, pagina, FLASH_PAGE_SIZE);
    restore_interrupts(irq);
#else
    (void)pagina;
    return 0;                 /* todavia no hay donde guardar: ver el bloque de arriba */
#endif

    /* Y SE COMPRUEBA LEYENDO. Una escritura que no se relee es una suposicion: si la flash
     * estaba protegida o el offset cae fuera, esto lo dice ahora y no tres sesiones despues
     * cuando alguien note que la calibracion "no se guarda". */
    return cargar_de_flash(&g.c);
}
