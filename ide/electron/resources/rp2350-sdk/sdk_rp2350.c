/* sdk_rp2350.c — el backend RP2350 del contrato de libvpy.
 *
 * libvpy (vpy.c) y los puertos SBT/AAE dibujan TODO por v_directDraw32, suenan por
 * v_writePSG, leen mandos por v_readButtons / v_readJoystick1Analog y marcan el frame con
 * v_WaitRecal. Este fichero es ese contrato sobre las dos placas RP2350:
 *
 *   - la UVM2 (.um2, UVM2_PICO_RUNTIME): el SDK (uvm2_draw.c) va DENTRO de la imagen y se
 *     llama directo;
 *   - el cartucho de Vectrex Studio (VPY_DUAL_CORE): el SDK vive en la BIOS y el juego lo
 *     llama por la tabla de funciones que la BIOS publica (`struct uvm2_api`).
 *
 * UN SOLO CAMINO DE GEOMETRIA, EN SUBUNIDADES (2026-09-16). Cada v_directDraw32 es tres
 * llamadas al SDK con las coordenadas en 1/16 de unidad: intensidad, salto absoluto, trazo.
 * Todo lo que hubo aqui antes —fusion de colineales, Douglas-Peucker, reordenacion de
 * trazos por vecino mas cercano, cache de intensidad, presupuesto de re-ceros, recorte de
 * trazos cortos, rampa con huecos— trabajaba en enteros sobre OTRA codificacion y cada
 * pieza se midio alguna vez como un temblor, un trazo desplazado o geometria que faltaba.
 * Lo que se validó como optimo es la lista en subunidades tal cual la genera uvm2_draw.c,
 * y ese es el unico camino: sin knobs. Daniel: "todos los proyectos deben ir con
 * subunidades ... hay que unificarlo todo". Lo que el juego pide es lo que se dibuja.
 */
#include <stdint.h>

/* SOLO HAY DOS FORMAS DE LLEGAR AL SDK, y una build que no diga cual es no compila: en la
 * .um2 el runtime (UVM2_PICO_RUNTIME) y en el cartucho propio la tabla (VPY_DUAL_CORE).
 * Antes habia una tercera —dibujo por svc, uno a uno, en enteros— y era la que salia por
 * defecto en cualquier regla vieja; con ella el juego no pasaba por subunidades ni tenia
 * menu de configuracion, y nadie lo veia hasta la consola. */
#if !defined(VPY_DUAL_CORE) && !defined(UVM2_PICO_RUNTIME)
#error "sdk_rp2350.c: hace falta -DVPY_DUAL_CORE (cartucho de Vectrex Studio, por la tabla de la BIOS) o UVM2_PICO_RUNTIME (.um2). Usa la receta rp2350-cart de uvm2.mk."
#endif

/* ── Los svc de la BIOS que quedan (Thumb `svc #imm`; r0-r3, AAPCS). En el cartucho el
 * dibujo NO va por svc (va por la tabla); estos son sonido, musica y texto raster para
 * la .um2, cuyo puente es uvm2_svc.c. ── */
static inline void sys_reset0ref(void)       { __asm__ volatile("svc #0"  ::: "r0","r1","r2","r3","memory"); }
static inline void sys_wait_recal(void)      { __asm__ volatile("svc #1"  ::: "r0","r1","r2","r3","memory"); }
static inline void sys_set_intensity(int b)  { register int r0 __asm__("r0")=b; __asm__ volatile("svc #2" : "+r"(r0) :: "memory"); }
static inline void sys_psg_write(int reg,int val){ register int r0 __asm__("r0")=reg; register int r1 __asm__("r1")=val; __asm__ volatile("svc #5" : "+r"(r0) : "r"(r1) : "memory"); }
static inline int  sys_read_buttons(void)    { register int r0 __asm__("r0"); __asm__ volatile("svc #7"  : "=r"(r0) :: "memory"); return r0; }
static inline int  sys_read_axes(void)       { register int r0 __asm__("r0"); __asm__ volatile("svc #13" : "=r"(r0) :: "memory"); return r0; }
static inline void sys_play_music(const void *p){ register const void *r0 __asm__("r0")=p; __asm__ volatile("svc #21" : "+r"(r0) :: "memory"); }
static inline void sys_stop_music(void)      { __asm__ volatile("svc #22" ::: "r0","r1","r2","r3","memory"); }
/* SYS_RASTER_TEXT = 26 (23 es SYS_PLAY_SFX en la BIOS: con ese numero un puntero a texto
 * llegaba al reproductor de SFX como pista y colgaba el nucleo). */
static inline void sys_raster_text(int x,int y,const unsigned char*s,int n){ register int r0 __asm__("r0")=x; register int r1 __asm__("r1")=y; register const unsigned char* r2 __asm__("r2")=s; register int r3 __asm__("r3")=n; __asm__ volatile("svc #26" :: "r"(r0),"r"(r1),"r"(r2),"r"(r3) : "memory"); }

/* ── La entrada, tal como la leen libvpy y los puertos (externs). ── */
uint8_t currentButtonState = 0;
int8_t  currentJoy1X = 0;
int8_t  currentJoy1Y = 0;

/* libvpy escala las unidades logicas de VPy (pantalla ±127) por VPY_SCALE; el SDK quiere
 * unidades de pantalla en 1/16. La multiplicacion fue exacta, asi que aqui se conserva lo
 * que el entero perdia: un trazo de 2,5 unidades sigue siendo de 2,5. */
#define VPY_SCALE 127
#define VS_Q4(v) ((int)(((v) < 0 ? (long)(v) * 16 - VPY_SCALE / 2 \
                                 : (long)(v) * 16 + VPY_SCALE / 2) / VPY_SCALE))

/* ── Ciclo de vida (la BIOS o el runtime ya pusieron relojes, pines y VIA). ── */
void vectrexinit(int mode) { (void)mode; }
#if defined(VPY_DUAL_CORE) && !defined(UVM2_PICO_RUNTIME)
static void dc_cfg_init(void);          /* abajo, con la API de configuracion por la tabla */
void v_init(void)          { dc_cfg_init(); }
#else
void v_init(void)          {}
#endif
void v_setRefresh(int hz)  { (void)hz; }   /* el ritmo lo fija uvm2_refresco */

#ifdef VPY_DUAL_CORE
/* EL MODELO DE LA UVM2 EN EL CARTUCHO DE VECTREX STUDIO (2026-09-15). El juego corre en
 * core 1 y construye la lista llamando al SDK que vive en la BIOS -las MISMAS funciones y
 * los mismos enteros de 32 bits que uvm2_draw.c recibe en la .um2- a traves de una tabla
 * de funciones que la BIOS publica en una direccion fija (uvm2c.rs, `Uvm2Api`). Core 0
 * es el ejecutor (uvm2_core1.c): reproduce las listas por PIO+DMA, lee los mandos y vacia
 * el PSG entre listas. Sin svc por vector y sin anillo de ops: lo que hubo aqui antes
 * (DC_OP_*, deltas en i8 y luego en cuartos empaquetados) era una segunda codificacion y
 * sus limites se veian (vigas de lado a lado invertidas). El orden de los campos es el
 * contrato con la BIOS; solo se anade al final. */
#include "uvm2_config.h"
struct uvm2_api {
    unsigned magic, version;
    void (*draw_intensity)(int);
    void (*draw_reset)(void);
    void (*draw_move)(int, int);
    void (*draw_delta)(int, int);
    void (*draw_move_abs_q4)(int, int);
    void (*draw_delta_q4)(int, int);
    void (*draw_delta_patterned)(int, int, const unsigned char *, int);
    void (*print_text)(int, int, const char *, int, int);
    void (*wait_recal)(void);
    unsigned (*read_buttons)(void);
    unsigned (*read_axes)(void);
    void (*psg_queue)(unsigned, unsigned);
    void (*config_actual)(int32_t *);
    void (*config_aplicar)(const int32_t *);
    int  (*config_guardar)(void);
    void (*refresco)(unsigned);
};
#define UVM2_API        ((const struct uvm2_api *)0x20077000u)
#define UVM2_API_MAGIC  0x50415356u   /* 'VSAP' */
#define BEAM_ZERO()       UVM2_API->draw_reset()
#define BEAM_INTENSITY(b) UVM2_API->draw_intensity((int)(signed char)(b) & 0x7F)
static void api_raster(int x, int y, const unsigned char *s, int n) {
    char t[97]; int k = 0;
    while (k < n && k < 96) { t[k] = (char)s[k]; k++; }
    t[k] = 0;
    UVM2_API->print_text(x, y, t, 1, 0x5F);   /* como SYS_RASTER_TEXT en uvm2_svc.c */
}
#define BEAM_RASTER(x,y,s,n) api_raster((x),(y),(s),(n))
/* LA API DE CONFIGURACION DEL SDK, la misma firma que uvm2_config.h, sobre la tabla. */
volatile int32_t uvm2_ajuste_hz = 50, uvm2_ajuste_menu = 1;
void uvm2_config_actual(struct uvm2_config *c) {
    UVM2_API->config_actual((int32_t *)c);
    c->hz = uvm2_ajuste_hz; c->start_menu = uvm2_ajuste_menu;
}
void uvm2_config_aplicar(const struct uvm2_config *c) {
    uvm2_ajuste_hz = (c->hz == 60) ? 60 : (c->hz == 0) ? 0 : 50;
    uvm2_ajuste_menu = c->start_menu ? 1 : 0;
    UVM2_API->config_aplicar((const int32_t *)c);
}
int uvm2_config_guardar(void) {
    struct uvm2_config c; UVM2_API->config_actual((int32_t *)&c);
    c.hz = uvm2_ajuste_hz; c.start_menu = uvm2_ajuste_menu;
    UVM2_API->config_aplicar((const int32_t *)&c);
    return UVM2_API->config_guardar();
}
void uvm2_refresco(unsigned hz) { UVM2_API->refresco(hz); }
/* Al arrancar el juego: los ajustes con los que la BIOS lo lanzo. */
static void dc_cfg_init(void) {
    struct uvm2_config c; UVM2_API->config_actual((int32_t *)&c);
    uvm2_ajuste_hz = c.hz; uvm2_ajuste_menu = c.start_menu;
}
#else
#define BEAM_ZERO()       sys_reset0ref()
#define BEAM_INTENSITY(b) sys_set_intensity(b)
#define BEAM_RASTER(x,y,s,n) sys_raster_text((x),(y),(s),(n)) /* SYS #26 */
#endif

/* Texto raster (fuente de la BIOS / uvm2_text.c) en coordenadas de dispositivo (i8). */
void v_rasterText(int x, int y, const unsigned char *s, int n) { BEAM_RASTER(x, y, s, n); }
/* UNA fila de bytes crudos (8 pixeles por byte, bit7 el de la izquierda), misma primitiva. */
void v_rasterRow(int x, int y, const unsigned char *s, int n) { BEAM_RASTER(x, y, s, n); }
/* Intensidad Z para lo que siga (las filas raster la necesitan puesta ANTES). */
void v_setIntensity(int b) { BEAM_INTENSITY((signed char)b); }

#ifdef UVM2_CUENTA_ENTRADA
unsigned uvm2_cuenta_entrada;   /* DIAGNOSTICO, ver uvm2_frame_end */
#endif

/* ── EL DIBUJO: tres llamadas al SDK por trazo, en 1/16 de unidad. ─────────────────────
 *
 * Es lo que hace la .um2 y lo que hace el cartucho propio, con las mismas funciones y los
 * mismos enteros; solo cambia por donde se llega a ellas (directo o por la tabla). El SDK
 * es quien trocea por el limite REAL de la rampa, quien decide los re-ceros
 * (uvm2_cero_cada, medido contra el VecFever) y quien conoce la calibracion de la
 * consola. Aqui no se decide nada de eso. */
void uvm2_draw_move_abs_q4(int x_q4, int y_q4);
void uvm2_draw_delta_q4(int dx_q4, int dy_q4);
void uvm2_draw_intensity(int z);

void v_directDraw32(int32_t x0, int32_t y0, int32_t x1, int32_t y1, uint8_t b)
{
    if (b == 0) return;                       /* z=0 es un salto en blanco, no un trazo */
#ifdef UVM2_CUENTA_ENTRADA
    uvm2_cuenta_entrada++;   /* DIAGNOSTICO: cuantas llamadas de dibujo ENTRAN al SDK */
#endif
#ifdef VPY_DUAL_CORE
    UVM2_API->draw_intensity((int)b);
    UVM2_API->draw_move_abs_q4(VS_Q4(x0), VS_Q4(y0));
    UVM2_API->draw_delta_q4(VS_Q4(x1) - VS_Q4(x0), VS_Q4(y1) - VS_Q4(y0));
#else
    uvm2_draw_intensity((int)b);
    uvm2_draw_move_abs_q4(VS_Q4(x0), VS_Q4(y0));
    uvm2_draw_delta_q4(VS_Q4(x1) - VS_Q4(x0), VS_Q4(y1) - VS_Q4(y0));
#endif
}

void v_WaitRecal(void)
{
#ifdef VPY_DUAL_CORE
    UVM2_API->wait_recal();     /* cierra la lista, se la entrega al ejecutor, abre la siguiente */
#else
    sys_wait_recal();
#endif
}

/* Un re-cero a peticion del juego. El SDK ya pincha el cero por su cuenta cada
 * uvm2_cero_cada saltos; esto solo añade uno donde el juego lo pide. */
void v_beamNewStroke(void) { BEAM_ZERO(); }

/* Quedan por compatibilidad: los juegos con texto vectorial las llaman. Ya no acotan nada
 * (no hay fusion ni recorte que evitar): el texto se dibuja como todo lo demas. */
void v_textBegin(void) {}
void v_textEnd(void)   {}

uint8_t v_readButtons(void)
{
#ifdef VPY_DUAL_CORE
    currentButtonState = (uint8_t)UVM2_API->read_buttons();
#else
    currentButtonState = (uint8_t)sys_read_buttons();
#endif
    return currentButtonState;
}

void v_readJoystick1Analog(void)
{
#ifdef VPY_DUAL_CORE
    unsigned int a = UVM2_API->read_axes();
#else
    unsigned int a = (unsigned int)sys_read_axes();
#endif
    currentJoy1X = (int8_t)(a >> 24);
    currentJoy1Y = (int8_t)(a >> 16);
}

__attribute__((weak)) int8_t currentJoy2X = 0;
__attribute__((weak)) int8_t currentJoy2Y = 0;
__attribute__((weak)) void v_readJoystick2Analog(void)
{
#ifdef VPY_DUAL_CORE
    unsigned int a = UVM2_API->read_axes();
#else
    unsigned int a = (unsigned int)sys_read_axes();
#endif
    currentJoy2X = (int8_t)(a >> 8);
    currentJoy2Y = (int8_t)a;
}

void v_writePSG(uint8_t reg, uint8_t val)
{
#ifdef VPY_DUAL_CORE
    UVM2_API->psg_queue(reg, val);
#else
    sys_psg_write(reg, val);
#endif
}

/* Muestras digitalizadas (AAE Sega G80): sin voz software aun, en silencio. */
void v_playSample(int idx, int voice, int loop) { (void)idx; (void)voice; (void)loop; }
void v_stopSample(int voice)                    { (void)voice; }
int  v_samplePlaying(int voice)                 { (void)voice; return 0; }

void v_playMusic(const unsigned char *vmus) { sys_play_music(vmus); }
void v_stopMusic(void)                      { sys_stop_music(); }

#include <stddef.h>
#ifndef UVM2_PICO_RUNTIME
void *memset(void *d, int c, size_t n)  { unsigned char *p = d; while (n--) *p++ = (unsigned char)c; return d; }
void *memcpy(void *d, const void *s, size_t n) { unsigned char *pd = d; const unsigned char *ps = s; while (n--) *pd++ = *ps++; return d; }
void *memmove(void *d, const void *s, size_t n) {
    unsigned char *pd = d; const unsigned char *ps = s;
    if (pd < ps) { while (n--) *pd++ = *ps++; }
    else { pd += n; ps += n; while (n--) *--pd = *--ps; }
    return d;
}
#endif
