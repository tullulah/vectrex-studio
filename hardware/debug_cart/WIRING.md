# Vectrex Debug Cart — Prototipo en Breadboard con Pico 2

## Limitaciones del Pico 2 (RP2350)

El Pico 2 tiene GP0–GP22 y GP26–GP28 accesibles en sus headers.  
GP23 (SMPS), GP24 (VBUS sense) y GP25 (LED) son **internos** y no están en los pines del header.

| Señal firmware | GPIO | ¿Accesible en Pico 2? |
|---|---|---|
| A0–A14 | GP0–GP14 | ✅ |
| D0–D7 | GP15–GP22 | ✅ |
| /CE | GP23 | ❌ interno |
| R/W | GP24 | ❌ interno |
| /OE | GP25 | ❌ interno |
| /NMI | GP26 | ✅ |
| /HALT | GP27 | ✅ |
| /RST | GP28 | ✅ |

**Consecuencia:**
- **Fase 1** (USB serial + HALT): 100% posible con Pico 2
- **Fase 2** (emulación ROM): requiere PCB custom (o soldar a los pads de test del Pico 2)

---

## Pinout Pico 2 (referencia rápida)

```
                       USB
           _____________||_____________
          |                            |
  GP0  [ 1]                        [40] VBUS
  GP1  [ 2]                        [39] VSYS  ←── 5V Vectrex (opcional)
  GND  [ 3]                        [38] GND   ──── GND Vectrex
  GP2  [ 4]                        [37] 3V3_EN
  GP3  [ 5]                        [36] 3V3   ──── VCC lógica 3.3V
  GP4  [ 6]                        [35] ADC_REF
  GP5  [ 7]                        [34] GP28  ──── /RST (fase 1+)
  GND  [ 8]                        [33] AGND
  GP6  [ 9]                        [32] GP27  ──── /HALT ← SEÑAL CLAVE
  GP7  [10]                        [31] GP26  ──── /NMI (fase 1+)
  GP8  [11]                        [30] RUN
  GP9  [12]                        [29] GP22  ──── D7
  GND  [13]                        [28] GND
  GP10 [14]                        [27] GP21  ──── D6
  GP11 [15]                        [26] GP20  ──── D5
  GP12 [16]                        [25] GP19  ──── D4
  GP13 [17]                        [24] GP18  ──── D3
  GND  [18]                        [23] GND
  GP14 [19]                        [22] GP17  ──── D2
  GP15 [20]                        [21] GP16  ──── D1
          |____________________________|
```

---

## Fase 1 — Mínima (solo HALT + USB serial)

Componentes necesarios:
- 1× transistor BSS138 (o cualquier N-MOSFET lógico: 2N7000, IRLML2502...)
- 1× resistencia 10 kΩ (pullup)
- Acceso al slot de cartucho del Vectrex

### Diagrama

```
Vectrex cartridge slot                Pico 2
──────────────────────               ────────
Pin 2: +5V ──┬──────────────────── VSYS [39] (alimenta Pico si no usas USB)
             │
             ├── R1 (10 kΩ) ──┐
             │                │
             │            Pin 1: /HALT
             │                │
             │            Gate─┤BSS138├─Source──→ GND
             │                      Drain

Pin 25: GND ─────────────────────── GND [38]

                                    GP27 [32] ──→ Gate BSS138
```

```
                    +5V (Vectrex pin 2)
                         │
                       10kΩ
                         │
VECTREX /HALT (pin 1) ───┤──── DRAIN
                         │        BSS138
                      SOURCE ──── GND
                         │
                       GATE
                         │
                   PICO2 GP27 (pin 32)
```

**Comportamiento:**
- GP27 = HIGH → FET conduce → /HALT se pone a GND → 6809 se para
- GP27 = LOW  → FET corta  → /HALT sube a 5V vía pullup → 6809 corre

### Cómo probarlo

1. Conecta Pico 2 al PC por USB
2. Abre un terminal serie (115200 baud) — ej: `screen /dev/tty.usbmodem* 115200`
3. Verás el banner de bienvenida
4. Pulsa `H` → HALT; `U` → release; `N` → pulsa NMI; `R` → reset

```
=== Vectrex Debug Cart v1 ===
RP2350 @ 150 MHz  |  4 MB flash  |  8 MB PSRAM  |  FPU
/HALT asserted: 6809 stopped.

PSRAM test... FAIL          ← normal, no hay PSRAM en breadboard
Bus master: NOT available (PCB v1 - DIR pins fixed)

Ready. Commands: [r]om-mode  [h]alt  [u]nhalt  [?]help
>
```

El `PSRAM test... FAIL` es **esperado** — no hay chip PSRAM en el prototipo.

---

## Fase 1+ — Control completo (HALT + NMI + RST)

Añade 2 BSS138 más para NMI y RST:

```
Componentes extra:
- 2× BSS138
- 2× resistencia 10 kΩ (pullups)

Vectrex pin 34: /NMI ── (mismo circuito BSS138) ── PICO2 GP26 (pin 31)
Vectrex pin 1:  /RST ── (mismo circuito BSS138) ── PICO2 GP28 (pin 34)
```

Todos los pullups van de +5V (Vectrex) al drenaje del FET.

---

## Fase 2 — Emulación ROM (requiere PCB custom o pads de test)

Para emulación ROM necesitas acceso a:
- **GP23** → /CE (Vectrex pin 16)
- **GP24** → R/W  (Vectrex pin 30, con divisor 10k+18k → 3.3V)
- **GP25** → /OE  (Vectrex pin 12, con divisor 10k+18k → 3.3V)
- **3× 74LVC245A** → translación de nivel 5V↔3.3V para bus A y D

GP23-GP25 no están en los headers del Pico 2. Opciones:
1. Usar el **PCB custom** (diseño en `hardware/debug_cart/`)
2. Soldar cables finos a los **pads de test** del Pico 2 (TP3=GP23, TP4=GP25)

### Bus de direcciones (cuando tengas PCB o acceso a los pads)

```
                   74LVC245A (U2)          74LVC245A (U3)
Vectrex A0 ──→ A1 ─────────── B1 → GP0    A1 ─── B1 → GP8
Vectrex A1 ──→ A2             B2 → GP1    A2     B2 → GP9
Vectrex A2 ──→ A3             B3 → GP2    A3     B3 → GP10
Vectrex A3 ──→ A4             B4 → GP3    A4     B4 → GP11
Vectrex A4 ──→ A5             B5 → GP4    A5     B5 → GP12
Vectrex A5 ──→ A6             B6 → GP5    A6     B6 → GP13
Vectrex A6 ──→ A7             B7 → GP6    A7     B7 → GP14
Vectrex A7 ──→ A8             B8 → GP7    A8(/CE)── B8 → GP23
              DIR=GND (→)                  DIR=GND
              /OE=GND                      /OE=GND
              VCC=3.3V                     VCC=3.3V
```

### Bus de datos

```
                   74LVC245A (U4) — bidireccional
Vectrex D0 ←→ A1 ─────────── B1 ↔ GP15
Vectrex D1 ←→ A2             B2 ↔ GP16
Vectrex D2 ←→ A3             B3 ↔ GP17
Vectrex D3 ←→ A4             B4 ↔ GP18
Vectrex D4 ←→ A5             B5 ↔ GP19
Vectrex D5 ←→ A6             B6 ↔ GP20
Vectrex D6 ←→ A7             B7 ↔ GP21
Vectrex D7 ←→ A8             B8 ↔ GP22
              DIR ←── GP24 (Vectrex→Pico cuando LOW)
              /OE = GND
```

### Señales de control con divisor de tensión (5V → 3.3V)

```
Vectrex R/W (pin 30) ──┬── 10kΩ ──┬── GP24
                        │          │
                        │        18kΩ
                        │          │
                       5V         GND
                    (solo lectura — no escribir desde Pico en v1)

Vectrex /OE (pin 12) ── mismo divisor ──→ GP25
```

---

## Conector de cartucho Vectrex — referencia de pines

```
 Pines ODD (lado A)    Pines EVEN (lado B)
 ──────────────────    ──────────────────
  1: /HALT              2: +5V
  3: A7                 4: +5V
  5: A6                 6: A8
  7: A5                 8: A9
  9: A4                10: A11
 11: A3                12: /OE
 13: A2                14: A10
 15: A1                16: /CE
 17: A0                18: D7
 19: D0                20: D6
 21: D1                22: D5
 23: D2                24: D4
 25: GND               26: D3
 27: GND               28: GND
 29: A12               30: R/W
 31: A13               32: NC
 33: A14               34: /NMI
 35: NC                36: /IRQ (NC)
```

El conector es un **edge connector de 36 pines, paso 2.54mm**.  
Si no tienes el conector, puedes acceder a los pines soldando en un cartucho vacío.

---

## Lista de compras para el prototipo Fase 1

| Componente | Qty | Precio aprox |
|---|---|---|
| Raspberry Pi Pico 2 | 1 | ~5€ |
| BSS138 (SOT-23) o 2N7000 (TO-92) | 3 | <1€ |
| Resistencia 10 kΩ | 3 | <1€ |
| Cartucho Vectrex vacío o adaptador edge | 1 | variable |
| Cables Dupont macho-macho | varios | ~2€ |

**Total Fase 1: ~8€**

Para Fase 2 añadir:
| Componente | Qty | Precio aprox |
|---|---|---|
| 74LVC245A (TSSOP-20 o DIP-20) | 3 | ~1€ c/u |
| Resistencia 18 kΩ | 2 | <1€ |

**Total Fase 2: ~12€** (más el PCB custom cuando esté listo)
