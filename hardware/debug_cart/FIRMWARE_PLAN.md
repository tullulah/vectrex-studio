# Debug Cart — Firmware Development Plan

## Objetivo

El RP2040 reemplaza funcionalmente al 6809 como procesador del juego. El 6809 queda
detenido (HALT), y el RP2040 ejecuta código VPy compilado nativamente (ARM Thumb2)
mientras controla el hardware del Vectrex (VIA 6522, AY-3-8912) directamente a través
del bus del cartucho.

**Resultado**: juegos VPy sin parpadeo, con toda la potencia del RP2040 (133 MHz,
264 KB RAM, hardware multiply/divide, dual core) y acceso completo al display vectorial
del Vectrex.

---

## Revisión de esquemático necesaria ANTES de fabricar

El diseño actual tiene U2/U3 (buffers de dirección) con DIR fijo a GND, lo que fija el
flujo Vectrex → RP2040. Para bus mastering el RP2040 necesita conducir el bus de
direcciones en dirección contraria.

### Cambios requeridos en el PCB

| Componente | Cambio |
|---|---|
| U2 pin 1 (DIR) | Desconectar de GND → conectar a nuevo GPIO del RP2040 (`ABUS_DIR`) |
| U3 pin 1 (DIR) | Ídem |
| U2 pin 19 (/OE) | Desconectar de GND → conectar a nuevo GPIO (`ABUS_nOE`) |
| U3 pin 19 (/OE) | Ídem |

Esto permite:
- **Modo ROM**: DIR=GND (Vectrex→RP2040), RP2040 lee direcciones y pone datos
- **Modo bus master**: DIR=VCC (RP2040→Vectrex), RP2040 conduce el bus de direcciones

El pin RUN del RP2040 (actualmente conectado a DIR_CTRL del bus de datos U4) es el
reset del RP2040, no un GPIO controlable. Usar en su lugar un GPIO libre (p.ej. GP24
ya conectado a RW con divisor — revisar si hay GPIOs libres o reutilizar).

> **Nota timing**: El reloj E del 6809 sigue corriendo cuando HALT está activo (el 6809
> tri-states el bus pero sigue generando E internamente). El VIA 6522 usa E para latching.
> El RP2040 no necesita sincronizarse con E: basta con mantener address/data/R̄W̄ estables
> durante al menos 2 ciclos de E (~1.4 µs) para garantizar que el VIA latchea el ciclo
> correctamente. El conector del cartucho no expone E directamente — el timing se logra
> con delay en el RP2040.

---

## Mapa de GPIOs del RP2040

| GPIO | Señal | Dirección | Descripción |
|---|---|---|---|
| GP0–GP7 | CART_A0–A7 (via U2) | IN/OUT | Bus de direcciones bajo |
| GP8–GP14 | CART_A8–A14 (via U3) | IN/OUT | Bus de direcciones alto |
| GP15–GP22 | CART_D0–D7 (via U4) | IN/OUT | Bus de datos bidireccional |
| GP23 | CART_nCE (via U3) | IN | Chip enable del cartucho |
| GP24 | CART_RW (via divisor) | IN/OUT | Read/Write |
| GP25 | CART_nOE (via divisor) | IN | Output enable |
| GP26 | nNMI (via Q1) | OUT | Non-maskable interrupt al 6809 |
| GP27 | nHALT (via Q2) | OUT | Halt al 6809 |
| GP28 | nRST (via Q3) | OUT | Reset al 6809 |
| GP29 | PSRAM_CS | OUT | Chip select de la PSRAM |
| QSPI | Flash + PSRAM | — | Bus QSPI compartido |
| USB | USB_DP/DM | — | USB para programación |
| SWD | SWD_IO/CLK | — | Debug SWD |

*Nota: si se añaden ABUS_DIR y ABUS_nOE para U2/U3, considerar usar GP24/GP25 en modo
bus master (ya que /OE y R/W del 6809 estarán inactivos con HALT activo).*

---

## Fases de desarrollo

---

### Fase 1 — Entorno y bringup  *(~1 semana)*

**Objetivo**: RP2040 arranca, USB funciona, PSRAM accesible.

**Tareas**:
- Configurar proyecto con [pico-sdk](https://github.com/raspberrypi/pico-sdk) + CMake
- Verificar alimentación: +5V del conector → AMS1117 → +3.3V
- Bringup USB CDC (consola serie para debug)
- Test de PSRAM: init QSPI en modo QPI, escribir/leer patrón, verificar 8 MB
- Test de flash W25Q16JV: leer ID, escribir/leer sector
- LED de estado via APA102 (QSPI compartido — manejar CS correctamente)

**Entregable**: `hello_world` via USB, "PSRAM OK / FLASH OK" en consola.

---

### Fase 2 — Modo ROM (emulación de cartucho)  *(~1 semana)*

**Objetivo**: RP2040 actúa como ROM para el 6809. El Vectrex arranca un juego VPy
compilado para 6809 cargado en la flash del RP2040. Permite validar el hardware antes
de implementar bus mastering.

**Funcionamiento**:
1. RP2040 copia imagen ROM desde flash W25Q16JV a PSRAM al arrancar
2. PIO state machine monitoriza `/CE` + `/OE` + A0-A14
3. Cuando `/CE` y `/OE` bajan: lee dirección, busca byte en PSRAM, pone dato en D0-D7
4. Cuando `/OE` sube: tri-state el bus de datos (DIR_CTRL)

**PIO program (pseudo)**:
```asm
rom_server:
    wait 0 gpio CE_PIN          ; espera /CE = 0
    wait 0 gpio OE_PIN          ; espera /OE = 0
    in pins, 15                 ; lee A0-A14 → ISR
    push noblock                ; envía dirección al core 0
    pull noblock                ; recibe byte de datos del core 0
    out pins, 8                 ; pone dato en D0-D7
    wait 1 gpio OE_PIN          ; espera fin del ciclo
    set pins, 0                 ; tri-state (via DIR_CTRL)
    jmp rom_server
```

**Core 0**: gestiona USB, flash, configura PIO  
**Core 1**: sirve datos en respuesta a ISR del PIO (< 150 ns para cumplir timing del 6809)

**Timing crítico**: el 6809 a 1.5 MHz espera dato en ~200 ns desde /OE bajo.
El RP2040 a 133 MHz tiene ~26 ciclos — con PSRAM en QPI (latencia ~80 ns) es factible.
Si el acceso a PSRAM es demasiado lento: cachear la ROM completa en SRAM del RP2040
(32 KB de ROM caben perfectamente en los 264 KB de SRAM).

**Entregable**: Vectrex arranca y ejecuta un juego VPy compilado para 6809 desde el RP2040.

---

### Fase 3 — Bus master: toma de control del bus  *(~1 semana)*

**Objetivo**: RP2040 detiene el 6809 y toma el bus, pudiendo leer/escribir cualquier
dirección del mapa de memoria del Vectrex.

**Secuencia de HALT**:
```
1. GP27 → LOW  (activa Q2 → nHALT bajo)
2. Esperar BA=HIGH + BS=HIGH del 6809 (indica que el bus está libre)
   → BA y BS no están en el conector del cartucho; alternativa: esperar ~10 ciclos
     de E (~7 µs) que es el máximo que tarda el 6809 en terminar el ciclo actual
3. Cambiar DIR de U2/U3 a HIGH (RP2040 → Vectrex en bus de direcciones)
4. Configurar GP0-GP14 como OUTPUTs
5. Bus master activo
```

**Primitivas de bus**:
```c
// Escribe un byte en cualquier dirección del mapa del Vectrex
void bus_write(uint16_t addr, uint8_t data);

// Lee un byte de cualquier dirección
uint8_t bus_read(uint16_t addr);
```

**Implementación**:
```c
void bus_write(uint16_t addr, uint8_t data) {
    gpio_put_masked(ADDR_MASK, addr);   // A0-A14
    gpio_put_masked(DATA_MASK, data);   // D0-D7
    gpio_put(RW_PIN, 0);                // R/W = write
    // DIR_CTRL ya HIGH (RP2040→bus)
    busy_wait_us(2);                    // ≥ 2 ciclos de E = 1.4 µs → VIA latchea
    gpio_put(RW_PIN, 1);               // restore
}
```

**Test**: leer/escribir registros del VIA, verificar que el VIA responde (ej: toggle
un bit del puerto B y medir con osciloscopio).

**Entregable**: función `bus_read/write` verificada. Lectura correcta de $D000 (VIA IFR).

---

### Fase 4 — HAL del VIA 6522  *(~2 semanas)*

**Objetivo**: abstracción completa del hardware del Vectrex equivalente a la BIOS.
Todas las funciones que el compilador VPy necesita emitir.

**Mapa de registros VIA** (base $D000):

| Offset | Registro | Uso en Vectrex |
|---|---|---|
| $0 | Port B | Control de integrador: bit0=mux Y/X, bit1=beam on/off, bit2=Z-axis |
| $1 | Port A | DAC: valor analógico Y o X |
| $2 | DDR B | Configuración dirección Puerto B |
| $3 | DDR A | Configuración dirección Puerto A |
| $4/$5 | T1 (lo/hi) | Timer 1: controla duración del vector (escala) |
| $8 | SR | Shift Register: control del haz (DSWM) |
| $B | ACR | Auxiliary Control Register |
| $C | PCR | Peripheral Control Register: /ZERO, CB2 |
| $D | IFR | Interrupt Flag Register: bit6 = T1 done |
| $E | IER | Interrupt Enable |

**Funciones HAL a implementar**:

```c
// --- Frame control ---
void vectrex_wait_recal(void);
// Equivale a WAIT_RECAL: espera sincronismo de frame (30 Hz = 33 ms)
// Implementación: polling de T1 overflow o contador de tiempo fijo

void vectrex_set_intensity(uint8_t intensity);
// Escribe intensidad al DAC vía Puerto A

// --- Dibujo ---
void vectrex_reset0ref(void);
// Reset integrators: PCR=$CE, Puerto B sequence, esperar T1

void vectrex_moveto(int8_t dy, int8_t dx);
// Mueve el haz sin dibujar (beam off durante T1)
// Igual que DV3D_MOVETO: PA=dy, PB=0, PCR=$CE, SR=0, PB=1, PA=dx, T1=$7F, esperar IFR.6

void vectrex_drawline(int8_t dy, int8_t dx);
// Dibuja segmento (beam on durante T1)
// SR=$FF (haz activo), T1=$7F, esperar IFR.6, SR=0

void vectrex_draw_abs(int8_t x0, int8_t y0, int8_t x1, int8_t y1);
// Helper: moveto (x0,y0) relativo a origen, drawline a (x1,y1)

// --- Texto ---
void vectrex_print_text(int8_t x, int8_t y, const char* str);
// Usa tabla de vectores de caracteres en RAM del RP2040 (extraída de la BIOS)

void vectrex_print_number(int8_t x, int8_t y, int16_t value);

// --- Joystick ---
int8_t vectrex_j1_x(void);
int8_t vectrex_j1_y(void);
uint8_t vectrex_j1_buttons(void);  // bits 0-3

// --- Sonido (AY-3-8912 via VIA shift register) ---
void vectrex_sound_byte(uint8_t reg, uint8_t value);
void vectrex_play_music(const uint8_t* vmus_data);
void vectrex_stop_music(void);
void vectrex_music_update(void);   // llamar 1 vez por frame
void vectrex_play_sfx(const uint8_t* vsfx_data);
```

**Nota sobre texto**: La BIOS del Vectrex contiene las tablas de vectores de caracteres
en ROM ($E000-$FFFF). El RP2040 puede leer esa zona via `bus_read()` con el 6809 detenido,
o incluir una copia en su propia flash.

**Entregable**: demo que dibuja líneas, texto y reproduce un tono — sin 6809 activo.

---

### Fase 5 — Motor de display y frame loop  *(~1 semana)*

**Objetivo**: frame loop estable a 30 Hz con doble buffer de comandos de display.

**Arquitectura dual-core**:

```
Core 0 (game logic):
  loop:
    run_game_frame()        // lógica del juego: física, IA, input
    swap_display_buffer()   // entrega lista de comandos al core 1
    wait_frame_sync()       // espera a que core 1 haya terminado de dibujar

Core 1 (display):
  loop:
    wait_for_buffer()       // espera nueva lista de comandos
    vectrex_wait_recal()    // sincronismo de frame
    execute_display_list()  // ejecuta comandos: moveto, drawline, text, etc.
    signal_done()
```

**Display list** (estructura de comandos):
```c
typedef enum { CMD_MOVETO, CMD_DRAWLINE, CMD_INTENSITY, CMD_TEXT, CMD_END } CmdType;
typedef struct { CmdType type; int8_t a, b; } DisplayCmd;
// Buffer de 512 comandos — suficiente para escenas complejas
DisplayCmd display_buffer[2][512];
```

**Límite físico**: ~380 segmentos/frame a T1=$7F antes de fading del fósforo.
El frame loop debe truncar la display list si supera este límite.

**Entregable**: frame loop estable verificado con osciloscopio (30 Hz, sin glitches).

---

### Fase 6 — Backend del compilador VPy para ARM Thumb2  *(~3 semanas)*

**Objetivo**: `cargo run --bin vpy_cli -- asm --target rp2040 src/main.vpy` genera
código C (o ensamblador Thumb2) que enlaza con la HAL del Fase 4.

**Opción A — Generar C** (más sencillo, más portable):
- Phase 5 alternativa emite `.c` en lugar de `.asm`
- Variables globales VPy → variables C globales (`int16_t VAR_SCORE;`)
- Funciones VPy → funciones C
- Builtins → llamadas a la HAL (`vectrex_drawline(dy, dx);`)
- Compilar con `arm-none-eabi-gcc -mthumb -mcpu=cortex-m0plus -O2`

**Opción B — Generar Thumb2 ASM directamente** (más control, más trabajo):
- Instrucciones ARM: `LDR`, `STR`, `ADD`, `MUL`, `BL`, etc.
- Ventaja: control total de registros y ciclos

**Recomendación**: Opción A para la primera versión. El GCC optimizará mejor que
un codegen manual en esta etapa, y el ahorro de tiempo de desarrollo es grande.

**Cambios en el pipeline del compilador**:

```
Phase 5 actual:   UnifiedModule → GeneratedIR (MC6809 ASM)
Phase 5 nuevo:    UnifiedModule → GeneratedIR { asm_6809: String, c_rp2040: Option<String> }
```

**Estructura del código generado** (Opción A):

```c
// main_game.c — generado por vpy_codegen --target rp2040

#include "vectrex_hal.h"

// Variables globales
int16_t VAR_SCORE = 0;
int16_t VAR_ANGLE_X = 0;

// Función principal — llamada una vez
void vpy_main(void) {
    VAR_SCORE = 0;
    VAR_ANGLE_X = 0;
}

// Loop — llamada cada frame por el motor de display
void vpy_loop(void) {
    VAR_ANGLE_X = VAR_ANGLE_X + 2;
    vectrex_draw_vector_3d("triangle", VAR_ANGLE_X, 0, 0, 0, 0);
    vectrex_print_text(-80, -50, "VECTREX STUDIO");
}
```

**Builtins que necesitan implementación en HAL**:
- `DRAW_LINE` → `vectrex_draw_abs()`
- `DRAW_VECTOR` → `vectrex_draw_vector()` (leer datos .vec desde flash)
- `DRAW_VECTOR_3D` → `vectrex_draw_vector_3d()` (rotación nativa ARM — sin LUT, usar FPU si disponible o int32 mul)
- `PRINT_TEXT` / `PRINT_NUMBER` → `vectrex_print_text/number()`
- `PLAY_MUSIC` / `PLAY_SFX` → HAL de sonido
- `J1_X/Y`, `J1_BUTTON_*` → HAL de joystick
- `LOAD_LEVEL` / `SHOW_LEVEL` → leer .vplay desde flash, dibujar tiles

**Ventaja clave de DRAW_VECTOR_3D en ARM**:
```c
// Rotación 3D en ARM — sin LUT, sin SMUL_LUT hacks
// Hardware multiply del Cortex-M0+ hace MUL en 1 ciclo
int8_t scr_x = (int8_t)((rx * cos_y - rz * sin_y) / 128);
// vs. 200+ ciclos en el 6809 con LUT
```
Para 88 vértices (benchy): <0.1 ms en RP2040 vs ~17 ms en 6809.

**Entregable**: `3d test` del ejemplo compila y corre en RP2040 sin parpadeo.

---

### Fase 7 — Integración con el IDE  *(~1 semana)*

**Objetivo**: "Build & Flash" desde el IDE de Vectrex Studio graba directamente
al RP2040 via USB (modo UF2 o picotool).

**Flujo**:
```
VPy source → vpy_cli --target rp2040 → main_game.c
           → arm-none-eabi-gcc → main_game.o
           → enlazar con vectrex_hal.a + pico_runtime
           → .uf2
           → picotool load --force game.uf2
```

**Configuración del proyecto** (`.vpyproj`):
```toml
[build]
target = "rp2040"           # nuevo campo; default "vectrex_6809"
flash_method = "picotool"   # o "uf2_drag"
```

**IDE**:
- Nuevo botón "Flash RP2040" en la toolbar del IDE
- Detecta automáticamente el RP2040 en modo BOOTSEL via USB
- Muestra progreso de flash en panel de output

**Entregable**: flujo completo one-click desde el IDE.

---

## Resumen de fases y dependencias

```
Fase 0 (PCB fix)
    └── Fase 1 (bringup)
            ├── Fase 2 (ROM mode)         ← validación de hardware independiente
            └── Fase 3 (bus master)
                    └── Fase 4 (VIA HAL)
                            └── Fase 5 (frame loop)
                                    └── Fase 6 (compilador)
                                            └── Fase 7 (IDE)
```

## Herramientas necesarias

| Herramienta | Uso |
|---|---|
| `pico-sdk` | SDK oficial de Raspberry Pi para RP2040 |
| `arm-none-eabi-gcc` | Compilador ARM bare-metal |
| `picotool` | Flash y debug via USB |
| `OpenOCD` + adaptador SWD | Debug via SWD (probe recomendado: Raspberry Pi Debug Probe) |
| `probe-rs` | Alternativa a OpenOCD, mejor integración con Rust |
| `pioasm` | Ensamblador PIO (incluido en pico-sdk) |
| Osciloscopio | Verificar timing del bus y señales VIA |

## Repositorio de firmware

Crear `hardware/debug_cart/firmware/` con estructura:
```
firmware/
  CMakeLists.txt
  pico_sdk_import.cmake
  src/
    main.c
    pio/
      rom_server.pio      ← Fase 2
      bus_master.pio      ← Fase 3
    hal/
      vectrex_hal.h       ← Fase 4
      vectrex_hal.c
      via.h
      ay_sound.c
      joystick.c
    display/
      frame_loop.c        ← Fase 5
      display_list.h
    game/
      main_game.c         ← generado por compilador (Fase 6)
```
