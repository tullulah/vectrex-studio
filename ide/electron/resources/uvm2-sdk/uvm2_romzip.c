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

static unsigned char s_zip[UVM2_ROMZIP_MAX];
static uintptr_t s_desc[4];                    /* [0]=magia [1]=base [2]=tamaño */

/* Pisa el game_header[] debil de romzip.c. Solo se mira la palabra 3. */
const uintptr_t game_header[4] = { 0u, 0u, 0u, (uintptr_t)s_desc };

uint32_t uvm2_romzip_bytes = 0;                /* para diagnosticar desde fuera */
int      uvm2_romzip_error = 0;

void uvm2_romzip_cargar(void)
{
    if (!&game_romset_name || !game_romset_name[0]) return;   /* juego sin romset */

    char ruta[80];
    int n = 0;
    const char *p = "roms/";
    while (*p) ruta[n++] = *p++;
    for (p = game_romset_name; *p && n < (int)sizeof ruta - 1; p++) ruta[n++] = *p;
    ruta[n] = 0;

    uvm2_romzip_bytes = uvm2_sd_leer(ruta, s_zip, sizeof s_zip);
    uvm2_romzip_error = uvm2_sd_error;
    if (!uvm2_romzip_bytes) return;

    s_desc[1] = (uintptr_t)s_zip;
    s_desc[2] = uvm2_romzip_bytes;
    s_desc[0] = 0x315A4D52u;                   /* 'RMZ1' — el ultimo en escribirse */
}
