/* uvm2_romzip.c — leer el romset de la SD y publicarlo, como hace el firmware de nuestro
 * cartucho. Aqui lo hace el juego, porque el firmware del UVM2 no lo hace.
 *
 * LA MAQUINARIA DE CARGA NO CAMBIA. romzip.c sigue leyendo un zip DE MEMORIA a traves de
 * un descriptor 'RMZ1' en game_header[3]; lo unico que cambia es quien lo rellena. En el
 * cartucho propio lo rellena el firmware antes de arrancar el juego; aqui lo rellenamos
 * nosotros despues de leer la tarjeta.
 *
 * El descriptor existe desde el principio con la magia a CERO, asi que si la lectura falla
 * romzip_open_cart() devuelve 0 igual que siempre y el juego pinta su cartel de "sin
 * romset" — que es la respuesta correcta y no un cuelgue.
 */
#include "uvm2_sd.h"

/* CUANTO ROMSET CABE. Es un array estatico en SRAM y la imagen del UVM2 vive en 496 KB,
 * asi que no se puede poner "grande por si acaso": con 64 KB, dkong no enlazaba (region
 * RAM overflowed by 37700 bytes). Se pone por juego, como AAE_ROM_STAGE:
 *
 *     UVM2_CFLAGS += -DUVM2_ROMZIP_MAX=$$((24*1024))
 *
 * El zip del juego manda: `ls -l arcade/roms/<juego>.zip` y se redondea hacia arriba. Si
 * se queda corto NO se cuelga — uvm2_sd_leer devuelve 0 con UVM2_SD_NO_CABE y el juego
 * pinta su cartel de "sin romset". */
#ifndef UVM2_ROMZIP_MAX
#define UVM2_ROMZIP_MAX (24u * 1024u)
#endif

/* Debil: un juego sin ROM externa no lo define y esto se queda en nada. */
__attribute__((weak)) extern const char game_romset_name[];

/* EL ROMSET, EN LA PSRAM. 23 KB de SRAM que estaban ocupados TODA la partida por algo que
 * solo se usa al arrancar: se lee de la tarjeta, se descomprime en las tablas de ROM del
 * juego, y ya no vuelve a hacer falta. En dkong eso es mas de lo que le queda libre.
 *
 * POR EL ALIAS SIN CACHE (0x15400000). Escribir por la ventana normal CORROMPE el dato:
 * medido, 2512 palabras malas de 4096; por el alias, cero. Y aqui la PSRAM esta en su
 * mejor caso — se escribe una vez y se lee una vez, sin nada que dependa del tiempo, que
 * es justo lo contrario de la lista de comandos.
 *
 * A 4 MB del principio para no pisar a nadie si alguna vez conviven. */
#ifdef UVM2_ROMZIP_IN_PSRAM
#  ifndef UVM2_ROMZIP_PSRAM_BASE
#    define UVM2_ROMZIP_PSRAM_BASE 0x15400000u
#  endif
static unsigned char *const s_zip = (unsigned char *)(uintptr_t)UVM2_ROMZIP_PSRAM_BASE;
#else
static unsigned char s_zip[UVM2_ROMZIP_MAX];
#endif
static uintptr_t s_desc[4];                    /* [0]=magia [1]=base [2]=tamaño */

/* NO SE LLAMA `game_header`, Y ESA ES LA CORRECCION.
 *
 * Lo era: un game_header[4] FUERTE que pisaba a proposito el debil de romzip.c para
 * publicar el descriptor en la palabra 3. Funcionaba para los puertos AAE... y rompia
 * TODOS los juegos VPy, que generan su propio game_header fuerte en su .S. Dos
 * definiciones fuertes del mismo simbolo:
 *
 *     multiple definition of `game_header'
 *     uvm2_romzip.c:52  /  SnowBros.S:(.game_rom+0x0) first defined here
 *
 * O sea que ningun juego VPy enlazaba para UVM2, y el fallo no aparecia en los 44 puertos
 * AAE porque alli el unico game_header rival es debil.
 *
 * Publicandolo con nombre propio nadie se disputa nada: el juego VPy conserva SU cabecera
 * y romzip.c mira aqui primero. */
/* La declara romzip.c como variable normal y aqui se RELLENA al arrancar. Ver su nota:
 * las dos versiones con simbolos debiles fallaron, una al enlazar y otra en silencio. */
extern unsigned long uvm2_romzip_desc;

uint32_t uvm2_romzip_bytes = 0;                /* para diagnosticar desde fuera */
int      uvm2_romzip_error = 0;

void uvm2_romzip_cargar(void)
{
    uvm2_romzip_desc = (unsigned long)(uintptr_t)s_desc;

    if (!&game_romset_name || !game_romset_name[0]) return;   /* juego sin romset */

    char ruta[80];
    int n = 0;
    const char *p = "roms/";
    while (*p) ruta[n++] = *p++;
    for (p = game_romset_name; *p && n < (int)sizeof ruta - 1; p++) ruta[n++] = *p;
    ruta[n] = 0;

    uvm2_romzip_bytes = uvm2_sd_leer(ruta, s_zip, UVM2_ROMZIP_MAX);
    uvm2_romzip_error = uvm2_sd_error;
    if (!uvm2_romzip_bytes) return;

    s_desc[1] = (uintptr_t)s_zip;
    s_desc[2] = uvm2_romzip_bytes;
    s_desc[0] = 0x315A4D52u;                   /* 'RMZ1' — el ultimo en escribirse */
}
