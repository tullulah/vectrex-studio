/* uvm2_sd.h — leer un fichero de la tarjeta SD del UVM2, desde el propio juego.
 *
 * POR QUE EXISTE. El firmware del UVM2 (de Ralf) carga el .um2 y se aparta: no sirve
 * romsets. Nuestro cartucho si lo hace —lee roms/<juego>.zip y publica un descriptor—, y
 * sin eso los 44 puertos AAE pintan su cartel de "sin romset" en esa placa. Empotrar el
 * zip en la imagen funciona pero devuelve la ROM al binario, que es justo lo que la
 * conversion a ROM externa quito.
 *
 * Asi que lo leemos nosotros. Despues del reset el modulo es dueño de la maquina, la SD
 * incluida.
 */
#ifndef UVM2_SD_H
#define UVM2_SD_H

#include <stdint.h>

/* 0 = no hay tarjeta o no arranco. Distinto de 0 = lista para leer. */
int uvm2_sd_init(void);

/* Copia <ruta> (por ejemplo "roms/dkong.zip") en dst. Devuelve los bytes leidos, o 0.
 * La ruta admite UN subdirectorio, que es lo que necesita roms/<juego>.zip. */
uint32_t uvm2_sd_leer(const char *ruta, unsigned char *dst, uint32_t max);

/* Un TROZO del fichero, desde `desde` bytes. Devuelve lo copiado, que puede ser menos que
 * `max` sin que eso sea un fallo (a diferencia de uvm2_sd_leer, donde no caber SI lo es).
 * Existe para reproducir capturas largas sin meterlas enteras en RAM. */
/** Crea un fichero de UN cluster (max 512 bytes de contenido) y lo escribe. Si la ruta
 *  lleva subdirectorio y no existe, lo crea en la RAIZ. 1 si se creo. */
int uvm2_sd_crear(const char *ruta, const unsigned char *datos, uint32_t n);

/** Sobrescribe EN SITIO el primer sector de un fichero que YA EXISTE (max 512 bytes).
 *  No crea, no redimensiona y no toca la FAT: es lo unico seguro con un lector de solo
 *  lectura. 1 si se escribio. Ver el bloque de uvm2_sd.c. */
int uvm2_sd_sobrescribir(const char *ruta, const unsigned char *datos, uint32_t n);

/** Escribe un fichero de CUALQUIER tamaño, encadenando clusters en la FAT; crea la carpeta
 *  si falta. 1 si se escribio. Es el que sirve para volcar trazas, partidas o capturas;
 *  `uvm2_sd_crear` se queda para el caso de un cluster y `uvm2_sd_sobrescribir` para
 *  reescribir en sitio sin tocar la FAT. */
int uvm2_sd_escribir(const char *ruta, const unsigned char *datos, uint32_t n);

uint32_t uvm2_sd_leer_desde(const char *ruta, unsigned char *dst, uint32_t max, uint32_t desde);

/* Lo que el montaje entendio del disco, para poder mirarlo por SWD sin adivinar. Un
 * NO_ESTA puede ser un fichero ausente o un volumen mal interpretado, y desde fuera se
 * ven igual; esto los separa. Se lee de un tiron:
 *
 *     hardware/uvm2/tools/sonda.sh <&uvm2_sd_diag> 13
 */
struct uvm2_sd_diag {
    uint32_t magia;          /* 'SDDG' = 0x47444453; 0 si no llego a montar    */
    uint32_t sec0_b0;        /* byte 0 del sector 0: 0xEB/0xE9 en un VBR       */
    uint32_t sec0_bps;       /* offset 11: bytes por sector                    */
    uint32_t sec0_spc;       /* offset 13: sectores por cluster                */
    uint32_t via_mbr;        /* 1 = el sector 0 era un MBR y se salto a la part */
    uint32_t inicio, spc, es32, raiz_cluster, fat, raiz_sector, datos, raiz_entradas;
    uint32_t paso;           /* 1 = buscando el subdirectorio, 2 = el fichero  */
    uint32_t dir_cluster;    /* cluster del subdirectorio, si lo encontro      */
    uint32_t entradas;       /* entradas de directorio examinadas en total     */
};
extern struct uvm2_sd_diag uvm2_sd_diag;

/* Ultimo fallo, para que "no hay tarjeta" y "falta el fichero" no se vean igual. */
extern int uvm2_sd_error;
#define UVM2_SD_OK          0
#define UVM2_SD_SIN_TARJETA 1
#define UVM2_SD_NO_ARRANCA  2
#define UVM2_SD_SIN_FAT     3
#define UVM2_SD_NO_ESTA     4
#define UVM2_SD_NO_CABE     5

#endif
