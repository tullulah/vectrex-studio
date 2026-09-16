/* uvm2_asistente.c — LA PANTALLA DE CALIBRACION.
 *
 * Ver uvm2_config.h para el porque de los cuatro parametros. Esto es solo la interfaz.
 *
 * EL PATRON MIDE, NO ADORNA. Se dibujan DOS cuadrados del MISMO tamaño, uno al lado del
 * otro: el de la izquierda con 4 trazos largos, el de la derecha con 40 cortos. Como miden
 * lo mismo, cualquier diferencia entre ellos es del NUMERO de trazos y no de la longitud, y
 * eso separa los dos terminos del error:
 *
 *     se abre el de 40 y el de 4 no   -> es el termino FIJO por trazo   (t1_tail_q8)
 *     se abren los dos en proporcion  -> es la ESCALA                   (scale)
 *
 * Un poligono cerrado que se abre acumula N veces la perdida fija; un error de escala lo
 * haria mas pequeño pero seguiria cerrado. Por eso el VecFever tiene una pantalla para
 * vectores y otra para texto: son estos mismos dos terminos.
 *
 * MANDO: arriba/abajo elige parametro, izquierda/derecha lo mueve, boton 4 guarda y sale.
 */
#include "uvm2_config.h"
#include "uvm2_draw.h"
#include "uvm2_text.h"

void uvm2_core1_start(void);
void uvm2_core1_stop(void);

/* LA ENTRADA SE LEE DE LA CACHE, NO DEL BUS.
 *
 * `uvm2_read_buttons()` y `uvm2_read_axes()` hablan con el PSG por el bus del Vectrex — y
 * ese bus lo esta usando CORE 1 para reproducir la lista. Llamarlas desde core 0, como hacia
 * esto al escribirlo, es meter a los dos nucleos en el mismo bus: medido en consola, el
 * asistente iba a 1 fps con `us_exec = 1.125.454 us` (1,1 segundos ejecutando una lista de
 * 17.111 ciclos, o sea 11 ms de trabajo). El emulador NO lo reproduce: alli iba a 50 Hz,
 * porque no modela la contienda por el bus.
 *
 * Core 1 ya las lee una vez por frame y las deja aqui; los juegos leen de aqui. `botones`
 * viene en CRUDO, activo a nivel bajo (0 = pulsado). */
extern volatile uint8_t  uvm2_cached_buttons;
extern volatile uint32_t uvm2_cached_axes;

#define LADO      44      /* lado del cuadrado, en unidades de dispositivo */
#define SEP       56      /* separacion entre los centros de los dos cuadrados */
/* `scale` de uvm2_print_text va en MEDIAS unidades y su valor de serie es 3 (x1,5). Puse 1
 * —un tercio de lo normal— y en consola no se leia. 4 es x2. */
#define TEXTO      4

/* LA FIGURA DE CALIBRACION DE VECTORBLADE (`displaySwarmCalibration`, objectEnemySwarm.asm),
 * que es opensource. Ocho segmentos largos y torcidos a escala 6 — no un cuadrado: lo que la
 * hace util es que mezcla trazos de longitudes y pendientes muy distintas, que es donde el
 * offset de la referencia de cero se nota.
 *
 * Sus macros llevan los deltas como (dy, dx) empaquetados en una palabra; aqui van tal cual,
 * ya desempaquetados y con las sumas que el escribe en linea (`$00-40`, `-$1B-10`, ...).
 * Daniel hara unos .vec propios para reemplazarla. */
static const signed char VB_SWARM[][2] = {   /* {dx, dy} */
    {  -40,  127 }, {  -50,  -37 }, {    6,   40 }, {  -52,    0 },
    {   36,  -40 }, {  -50,   47 }, {   40, -127 }, {   60,   25 },
};

static void figura_vectorblade(int cx, int cy)
{
    /* Su INIT_DRAW_6_MOVE_END mueve (dx, dy) = (60, -18) desde el centro antes de trazar. */
    uvm2_draw_move_abs(cx + 60 / 3, cy - 18 / 3);
    for (unsigned i = 0; i < sizeof VB_SWARM / sizeof VB_SWARM[0]; i++) {
        /* /3 porque su escala 6 sobre una pantalla de +-127 se sale; la FORMA es lo que
         * importa, y dividir por igual la conserva. */
        uvm2_draw_delta(VB_SWARM[i][0] / 3, VB_SWARM[i][1] / 3);
    }
}

/* LA LINEA DE REFERENCIA, tambien suya: cada pantalla de Vectorblade dibuja una recta de
 * longitud FIJA al lado de lo que se calibra (`ldd #$0080  jsr DrawLined`, o sea 128 en un
 * eje) y se ajusta hasta que CASAN. Comparar contra una referencia es medir; mirar una
 * figura sola y decidir si "se ve bien" no lo es. */
static void linea_referencia(int cx, int cy)
{
    uvm2_draw_move_abs(cx, cy);
    uvm2_draw_delta(0, 128 / 3);
}

/* Un cuadrado dibujado con `n` trazos por lado, centrado en (cx, cy). Con n = 1 son los 4
 * trazos largos; con n = 10, los 40 cortos. El recorrido total es EL MISMO. */
static void cuadrado(int cx, int cy, int n)
{
    static const int dx[4] = { 1, 0, -1, 0 };
    static const int dy[4] = { 0, 1,  0, -1 };
    const int lado = LADO;
    uvm2_draw_move_abs(cx - lado / 2, cy - lado / 2);
    for (int l = 0; l < 4; l++) {
        /* El reparto exacto, para que n trazos midan lo mismo que uno: se acumula la
         * posicion ideal y se emite la diferencia, en vez de repetir lado/n y perder el
         * resto n veces. */
        int hecho = 0;
        for (int i = 1; i <= n; i++) {
            int ideal = lado * i / n;
            uvm2_draw_delta(dx[l] * (ideal - hecho), dy[l] * (ideal - hecho));
            hecho = ideal;
        }
    }
}

struct campo { const char *nombre; int32_t *valor; int32_t min, max, paso; };

/* LA FIGURA LA PUEDE PONER EL JUEGO.
 *
 * El patron del SDK (la figura de Vectorblade y los dos cuadrados) separa bien los dos
 * terminos del error, pero calibrar contra el no es lo mismo que calibrar contra LO QUE
 * SALE MAL. Daniel: "ponlo de momento para calibrar el logo en dkong" — y tiene razon en
 * que el arbitro es el dibujo que molesta, no una figura de laboratorio.
 *
 * Con `figura` a cero se dibuja el patron de siempre. Con una funcion, se dibuja esa EN SU
 * LUGAR y el resto de la pantalla —los cuatro valores, el mando, el guardado— es identico.
 * El juego la pasa ya centrada y a su escala: el asistente no sabe nada de ella. */
int uvm2_config_asistente_con(void (*figura)(void))
{
    struct uvm2_config c;
    uvm2_config_actual(&c);

    /* LOS PARAMETROS, SACADOS DE VECTORBLADE Y NO DEDUCIDOS POR MI.
     *
     * `calibration.asm` de Vectorblade tiene TRES pantallas y las tres ajustan UNA cosa: un
     * byte que se ceba en la REFERENCIA DE CERO (`calibrateString` hace `ORB=$82` —mux en el
     * canal 1— y `ORA = calibrationValueString`), que es exactamente lo que emite nuestro
     * bloque de cero con `uvm2_cero_offset`.
     *
     * Sus valores de fabrica: `calibrationValue16 = $23` (35) y `calibrationValue50 = $56`
     * (86). **El nuestro estaba en 7**, treinta unidades por debajo de donde empieza a
     * importar — por eso moverlo de 7 a 5 en consola no hacia nada. Ya lo teniamos anotado
     * en [[zero-reference-calibration]] y no lo habiamos aplicado.
     *
     * Tiene TRES porque el valor depende de la ESCALA de lo que se dibuje: uno para el jefe
     * (trazos largos), otro para el texto. Es la misma division que describe Technobly
     * ("separate ones for vectors and text"), y no dos terminos de un modelo de error como
     * yo habia supuesto.
     *
     * `scale` y `t1_tail_q8` se quedan porque son knobs REALES del dibujo, pero al final: no
     * son lo que calibra una consola. */
    /* LOS DE LA CONSOLA SIEMPRE; LOS DEL JUEGO, SOLO LOS QUE EL JUEGO DECLARA SUYOS
     * (uvm2_config_juego). Un interruptor que no significa nada en este juego no se enseña:
     * Donkey Kong es vertical y no tiene que ver un GIRO, y el menu se oculta por juego y no
     * para todos. */
    struct campo campos[8];
    int n = 0;
    campos[n++] = (struct campo){ "CERO",    &c.zero,       0, 255, 1 };
    campos[n++] = (struct campo){ "BRILLO",  &c.bright,     0, 127, 1 };
    campos[n++] = (struct campo){ "ESCALA",  &c.scale,   80, 400, 1 };
    campos[n++] = (struct campo){ "FIJO",    &c.t1_tail_q8, -512, 512, 8 };
    {
        const unsigned mios = uvm2_config_ajustes_juego();
        /* GIRO: la pantalla es vertical y bastantes recreativas son horizontales. Se ve al
         * instante sobre la propia figura, que es justo lo que un ajuste asi necesita. */
        if (mios & UVM2_AJUSTE_GIRO) campos[n++] = (struct campo){ "GIRO", &c.rotate,     0, 1, 1 };
        if (mios & UVM2_AJUSTE_MENU) campos[n++] = (struct campo){ "MENU", &c.start_menu, 0, 1, 1 };
        if (mios & UVM2_AJUSTE_HZ)   campos[n++] = (struct campo){ "HZ",   &c.hz,         0, 60, 10 };
    }
    int sel = 0, guardado = 0;
    /* LOS BOTONES SON ACTIVOS A NIVEL BAJO (PSG reg 14 en crudo: 0 = pulsado), asi que se
     * invierten aqui UNA vez y el resto del codigo razona con 1 = pulsado. Sin invertir, el
     * flanco detecta el SOLTAR y en reposo todos los bits valen 1. */
    uint8_t antes = (uint8_t)~uvm2_cached_buttons;

    for (;;) {
        uvm2_config_aplicar(&c);          /* se ve el efecto MIENTRAS se mueve */
        uvm2_frame_begin();
        uvm2_draw_intensity(c.bright);

        if (figura) {
            figura();                     /* la del juego, ver arriba */
        } else {
            /* La figura de Vectorblade con su linea de referencia al lado, y debajo los dos
             * cuadrados —4 trazos contra 40— que siguen sirviendo para ver el termino fijo. */
            linea_referencia(-100, 20);
            figura_vectorblade(-40, 38);
            cuadrado( 70, 60,  1);
            cuadrado( 70, 10, 10);
        }

        for (int i = 0; i < n; i++) {
            char linea[24];
            int p = 0;
            linea[p++] = (i == sel) ? '>' : ' ';
            for (const char *s = campos[i].nombre; *s; s++) linea[p++] = *s;
            linea[p++] = ' ';
            /* El valor, a mano: el SDK no lleva printf y meterlo por esto seria pagar 20 KB
             * de flash por cuatro numeros. */
            int32_t v = *campos[i].valor;
            if (v < 0) { linea[p++] = '-'; v = -v; }
            char d[8]; int k = 0;
            do { d[k++] = (char)('0' + v % 10); v /= 10; } while (v && k < 7);
            while (k) linea[p++] = d[--k];
            linea[p] = 0;
            uvm2_print_text(-112, -18 - i * 26, linea, TEXTO, c.bright);
        }
        uvm2_frame_end();

        /* EL MANDO, POR FLANCO. Sin esto un toque mueve el valor treinta veces: el bucle
         * corre a 50 Hz y el dedo tarda mas. */
        uint8_t b = (uint8_t)~uvm2_cached_buttons;
        uint8_t nuevo = (uint8_t)(b & ~antes);
        antes = b;
        /* (J1X << 24) | (J1Y << 16) | (J2X << 8) | J2Y — el mando 1 va en los bytes ALTOS.
         * Leer los bajos es leer el mando 2, que es lo que hacia esto al escribirlo. */
        uint32_t ejes = uvm2_cached_axes;
        int jx = (int8_t)(ejes >> 24), jy = (int8_t)(ejes >> 16);

        /* ARRIBA/ABAJO ELIGE, POR FLANCO. Un toque, un cambio de linea. */
        static int repos_y = 1;
        if (jy > -40 && jy < 40) repos_y = 1;
        else if (repos_y) {
            repos_y = 0;
            sel = (jy > 40) ? (sel + n - 1) % n : (sel + 1) % n;
        }

        /* IZQUIERDA/DERECHA AJUSTA, CONTINUO MIENTRAS SE MANTIENE — como Vectorblade, que
         * mueve +-1 cada dos frames (`Vec_Loop_Count+1 & 1`). Por flanco era inservible: el
         * rango util de la referencia de cero va de 0 a 255, y a un paso por pulsacion hacen
         * falta cien toques para llegar a donde empieza a notarse. */
        static uint32_t tic = 0;
        tic++;
        if ((jx > 40 || jx < -40) && (tic & 1u) == 0) {
            int32_t *v = campos[sel].valor;
            *v += (jx > 0 ? campos[sel].paso : -campos[sel].paso);
            if (*v < campos[sel].min) *v = campos[sel].min;
            if (*v > campos[sel].max) *v = campos[sel].max;
        }

        if (nuevo & 0x08) {               /* boton 4: guardar y salir */
            /* AQUI NO SE PARA CORE 1, Y ESTE COMENTARIO ESTABA MINTIENDO.
             *
             * Decia "parar core 1 antes de tocar la flash", y era cierto cuando
             * `uvm2_config_guardar` escribia en flash. Ya no: ese camino esta desactivado
             * (`guardar_en_flash_NO_USAR`, y la razon esta ahi) y ahora escribe en la SD.
             * El comentario se quedo y la llamada tambien.
             *
             * Y no es inofensivo: `uvm2_frame_end` tiene la UNICA espera de core 0
             * —`while (uvm2_frame_done - (s_frame_no-1) < 0)`— y quien avanza ese contador
             * es core 1. Reseteandolo, core 0 se queda ahi para siempre. Colgo dkong en
             * consola el 2026-09-14; por SWD, pc clavado en uvm2_draw.c:2757 en tres
             * muestras, y la pantalla NO en negro porque core 1 repetia la ultima lista. */
            guardado = uvm2_config_guardar();
            break;
        }
    }
    return guardado;
}

int uvm2_config_asistente(void) { return uvm2_config_asistente_con(0); }
