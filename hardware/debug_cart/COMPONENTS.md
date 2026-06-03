# Debug Cart — Component Reference (RP2350 / PCB v2)

Schematic entry guide for KiCad 9.
Target MCU: **RP2350A** (QFN-60, 7×7mm, 0.4mm pitch).
PCB: card-edge cartucho directo (sin conector externo), grosor 1.6mm, gold fingers biselados 45°.

---

## Signal Glossary

| Net name | Description |
|---|---|
| +5V | Vectrex 5 V rail (from card edge) |
| +3V3 | 3.3 V regulated rail (AMS1117-3.3) |
| GND | Ground |
| GP0–GP29 | RP2350 GPIO — todos accesibles en QFN-60 |
| CART_A0–A14 | Vectrex address bus (5V, read-only en v1) |
| CART_D0–D7 | Vectrex data bus (5V, bidireccional) |
| CART_RW | Vectrex R/W line (5V → 3.3V divisor) |
| CART_nOE | Vectrex /OE (5V → 3.3V divisor) |
| CART_nCE | Vectrex /CE (5V, U3 B8 → GP23) |
| nNMI | Open-drain NMI line (BSS138 + 10k pullup a +5V) |
| nHALT | Open-drain HALT line (BSS138 + 10k pullup a +5V) |
| nRST | Open-drain RST line (BSS138 + 10k pullup a +5V) |
| DIR_CTRL | Data bus buffer direction (GP29 → U4 DIR) |
| QSPI_SD0–SD3 | RP2350 QSPI data lines |
| QSPI_SCK | RP2350 QSPI clock |
| QSPI_CSn | RP2350 QSPI CS0 → W25Q32JV boot flash |
| QSPI_SS1n | RP2350 QSPI CS1 (hardware QMI) → APS6404L PSRAM |
| SWD_IO / SWD_CLK | SWDIO / SWDCLK debug lines |
| XTAL_IN / XTAL_OUT | 12 MHz crystal |
| USB_DP / USB_DM | USB D+ / D− |

---

## U1 — RP2350B

| Field | Value |
|---|---|
| Symbol | `MCU_RaspberryPi:RP2350B` (KiCad 9) |
| Footprint | `Package_DFN_QFN:QFN-80-1EP_10x10mm_P0.4mm_EP3.4x3.4mm` |
| Value | `RP2350B` |
| Datasheet | https://datasheets.raspberrypi.com/rp2350/rp2350-datasheet.pdf |

> RP2350B vs RP2350A: mismo silicio (dual M33 + RISC-V, 520 KB SRAM, FPU),
> mismo pitch 0.4 mm, pero **QFN-80 con 48 GPIOs** vs QFN-60 con 30. Los GPIOs
> extra (GP30–47) permiten dedicar pines a CART_RW, PSRAM_CS y UART hardware
> sin hacks de multiplexación. Coste extra: ~0.40 €/ud.

### GPIO pin connections

| Symbol pin | Net | Función |
|---|---|---|
| GPIO0 | GP0 | A0 (vía U2) |
| GPIO1 | GP1 | A1 |
| GPIO2 | GP2 | A2 |
| GPIO3 | GP3 | A3 |
| GPIO4 | GP4 | A4 |
| GPIO5 | GP5 | A5 |
| GPIO6 | GP6 | A6 |
| GPIO7 | GP7 | A7 |
| GPIO8 | GP8 | A8 (vía U3) |
| GPIO9 | GP9 | A9 |
| GPIO10 | GP10 | A10 |
| GPIO11 | GP11 | A11 |
| GPIO12 | GP12 | A12 |
| GPIO13 | GP13 | A13 |
| GPIO14 | GP14 | A14 |
| GPIO15 | GP15 | D0 (vía U4) |
| GPIO16 | GP16 | D1 |
| GPIO17 | GP17 | D2 |
| GPIO18 | GP18 | D3 |
| GPIO19 | GP19 | D4 |
| GPIO20 | GP20 | D5 |
| GPIO21 | GP21 | D6 |
| GPIO22 | GP22 | D7 |
| GPIO23 | GP23 | /CE (CART_nCE, vía U3 B8) |
| GPIO24 | GP24 | ABUS_DIR (U2 pin 1 + U3 pin 1) |
| GPIO25 | GP25 | /OE (CART_nOE, divisor 10k+18k) |
| GPIO26/ADC0 | GP26 | /NMI (open-drain vía Q1) |
| GPIO27/ADC1 | GP27 | /HALT (open-drain vía Q2) |
| GPIO28/ADC2 | GP28 | /RST (open-drain vía Q3) |
| GPIO29/ADC3 | GP29 | DIR_CTRL (U4 pin 1) — solo dirección de datos |
| GPIO30 | GP30 | CART_RW drive — input de U8 (74LVC1G07) |
| GPIO31 | GP31 | PSRAM_CS (dedicado a U6 pin 1) |
| GPIO32 | GP32 | UART0 TX → J_UART pin 3 |
| GPIO33 | GP33 | UART0 RX → J_UART pin 2 |
| GPIO34–47 | — | reservados (libres) |

> **ABUS_DIR (GP24)** controla la dirección de los buffers U2/U3 del bus de
> direcciones: LOW = Vectrex→RP2350 (modo ROM, default). HIGH = RP2350→Vectrex
> (bus master). /OE de U2/U3 está cableado a GND (siempre habilitado).
>
> **CART_RW (vía U8 + R13)**: GP30 alimenta la entrada de U8 (74LVC1G07
> open-drain). GP30 LOW → U8 high-Z → R13 pulla CART_RW a +5V (read cycle).
> GP30 HIGH → U8 drives → CART_RW=LOW (write cycle). En modo normal (6809
> corriendo), GP30 se mantiene LOW → U8 high-Z → el 6809 conduce CART_RW
> sin conflicto. **Los GPIOs del RP2350 no son 5V tolerantes** — U8 hace de
> level shifter obligatorio.
>
> **R7/R8 (antiguo divisor de R/W sense) eliminados.** El RP2350 ya no
> necesita leer R/W del 6809 porque solo opera en modo bus master.

### QSPI / power / debug pins

| Symbol pin | Net | Notas |
|---|---|---|
| QSPI_SD0 | QSPI_SD0 | Compartido flash + PSRAM |
| QSPI_SD1 | QSPI_SD1 | |
| QSPI_SD2 | QSPI_SD2 | |
| QSPI_SD3 | QSPI_SD3 | |
| QSPI_SCLK | QSPI_SCK | |
| ~{QSPI_SS} | QSPI_CSn | CS único expuesto → W25Q32JV (PSRAM CS por GPIO) |
| RUN | RUN | Pulled up a +3V3 (100kΩ); TP de reset |
| IOVDD (×6) | +3V3 | |
| DVDD (×2) | +3V3 | |
| QSPI_IOVDD | +3V3 | Pin nuevo en RP2350A vs RP2040 |
| USB_OTP_VDD | +3V3 | Pin nuevo en RP2350A vs RP2040 |
| ADC_AVDD | +3V3 | |
| VREG_AVDD | +3V3 | Reemplaza VREG_VIN del RP2040 |
| VREG_LX | +3V3 | **Modo bypass/LDO** — tie a +3V3 directamente, sin inductor |
| VREG_FB | +3V3 | **Modo bypass/LDO** — tie a +3V3 directamente |
| XIN | XTAL_IN | |
| XOUT | XTAL_OUT | |
| USB_DP | USB_DP | |
| USB_DM | USB_DM | |
| SWDIO | SWD_IO | |
| SWCLK | SWD_CLK | |
| TESTEN | GND | Siempre a GND |
| GND (×7) | GND | |
| EP (pad central) | GND | Conectar a plano GND en PCB |

---

## U2 — 74LVC245A (Address bus A0–A7)

| Field | Value |
|---|---|
| Symbol | `74xx:74LVC245A` |
| Footprint | `Package_SO:TSSOP-20_4.4x6.5mm_P0.65mm` |
| Value | `74LVC245A` |

Dirección fija: DIR=GND (A→B siempre), /OE=GND (siempre activo).
Nivel: A side = 5V Vectrex, B side = 3.3V RP2350.

| Pad | Pin | Net |
|---|---|---|
| 1 | DIR | GND |
| 2 | A1 | CART_A0 |
| 3 | A2 | CART_A1 |
| 4 | A3 | CART_A2 |
| 5 | A4 | CART_A3 |
| 6 | A5 | CART_A4 |
| 7 | A6 | CART_A5 |
| 8 | A7 | CART_A6 |
| 9 | A8 | CART_A7 |
| 10 | GND | GND |
| 11 | B8 | GP7 |
| 12 | B7 | GP6 |
| 13 | B6 | GP5 |
| 14 | B5 | GP4 |
| 15 | B4 | GP3 |
| 16 | B3 | GP2 |
| 17 | B2 | GP1 |
| 18 | B1 | GP0 |
| 19 | /OE | GND |
| 20 | VCC | +3V3 |

> VCC_A (side A, pines 2-9) debe conectarse a +5V. VCC_B (side B, pines 11-18) a +3V3.
> Verificar que el símbolo KiCad tiene pines de alimentación separados por side.

---

## U3 — 74LVC245A (Address bus A8–A14 + /CE)

| Field | Value |
|---|---|
| Symbol | `74xx:74LVC245A` |
| Footprint | `Package_SO:TSSOP-20_4.4x6.5mm_P0.65mm` |
| Value | `74LVC245A` |

Dirección fija: DIR=GND (A→B siempre), /OE=GND.

| Pad | Pin | Net |
|---|---|---|
| 1 | DIR | GND |
| 2 | A1 | CART_A8 |
| 3 | A2 | CART_A9 |
| 4 | A3 | CART_A10 |
| 5 | A4 | CART_A11 |
| 6 | A5 | CART_A12 |
| 7 | A6 | CART_A13 |
| 8 | A7 | CART_A14 |
| 9 | A8 | CART_nCE |
| 10 | GND | GND |
| 11 | B8 | GP23 |
| 12 | B7 | GP14 |
| 13 | B6 | GP13 |
| 14 | B5 | GP12 |
| 15 | B4 | GP11 |
| 16 | B3 | GP10 |
| 17 | B2 | GP9 |
| 18 | B1 | GP8 |
| 19 | /OE | GND |
| 20 | VCC | +3V3 |

---

## U4 — 74LVC245A (Data bus D0–D7, bidireccional)

| Field | Value |
|---|---|
| Symbol | `74xx:74LVC245A` |
| Footprint | `Package_SO:TSSOP-20_4.4x6.5mm_P0.65mm` |
| Value | `74LVC245A` |

Dirección controlada por GP29 (DIR_CTRL). /OE=GND (siempre activo).
- DIR_CTRL LOW → A→B (Vectrex→RP2350, modo ROM/lectura)
- DIR_CTRL HIGH → B→A (RP2350→Vectrex, modo bus master/escritura)

| Pad | Pin | Net |
|---|---|---|
| 1 | DIR | GP29 (DIR_CTRL) |
| 2 | A1 | CART_D0 |
| 3 | A2 | CART_D1 |
| 4 | A3 | CART_D2 |
| 5 | A4 | CART_D3 |
| 6 | A5 | CART_D4 |
| 7 | A6 | CART_D5 |
| 8 | A7 | CART_D6 |
| 9 | A8 | CART_D7 |
| 10 | GND | GND |
| 11 | B8 | GP22 |
| 12 | B7 | GP21 |
| 13 | B6 | GP20 |
| 14 | B5 | GP19 |
| 15 | B4 | GP18 |
| 16 | B3 | GP17 |
| 17 | B2 | GP16 |
| 18 | B1 | GP15 |
| 19 | /OE | GND |
| 20 | VCC | +3V3 |

---

## U5 — AMS1117-3.3 (LDO 3.3V)

| Field | Value |
|---|---|
| Symbol | `Regulator_Linear:AMS1117-3.3` |
| Footprint | `Package_TO_SOT_SMD:SOT-223-3_TabPin2` |
| Value | `AMS1117-3.3` |

| Pad | Pin | Net |
|---|---|---|
| 1 | GND/ADJ | GND |
| 2 | OUTPUT (tab) | +3V3 |
| 3 | INPUT | +5V |

Añadir C_LDO_IN (10µF, 0805) entre +5V y GND, y C_LDO_OUT (10µF, 0805) entre +3V3 y GND.

---

## U6 — APS6404L-3SQR (8MB QSPI PSRAM)

| Field | Value |
|---|---|
| Symbol | Crear manualmente o usar `Memory_RAM:Generic_QSPI_RAM_SOIC8` |
| Footprint | `Package_SO:SOIC-8_3.9x4.9mm_P1.27mm` |
| Value | `APS6404L-3SQR` |

CS# controlado por GPIO software (net `PSRAM_CS`). El símbolo KiCad del RP2350A
no expone un pin dedicado `QSPI_SS1` — la PSRAM se selecciona via GPIO con
secuencia QSPI emitida desde el firmware (`pac::QMI` direct mode).

| Pad | Pin | Net |
|---|---|---|
| 1 | CE# | PSRAM_CS |
| 2 | SIO1 | QSPI_SD1 |
| 3 | SIO2 | QSPI_SD2 |
| 4 | VSS | GND |
| 5 | SIO0 | QSPI_SD0 |
| 6 | SCLK | QSPI_SCK |
| 7 | SIO3 | QSPI_SD3 |
| 8 | VCC | +3V3 |

---

## U7 — W25Q32JV (4MB SPI NOR flash, boot RP2350)

| Field | Value |
|---|---|
| Symbol | `Memory_Flash:W25Q32JV` |
| Footprint | `Package_SO:SOIC-8_3.9x4.9mm_P1.27mm` |
| Value | `W25Q32JV` |

| Pad | Pin | Net |
|---|---|---|
| 1 | /CS | QSPI_CSn |
| 2 | DO / IO1 | QSPI_SD1 |
| 3 | /WP / IO2 | QSPI_SD2 |
| 4 | GND | GND |
| 5 | DI / IO0 | QSPI_SD0 |
| 6 | CLK | QSPI_SCK |
| 7 | /HOLD / IO3 | QSPI_SD3 |
| 8 | VCC | +3V3 |

---

## Q1 — BSS138 (NMI open-drain)

| Pad | Pin | Net |
|---|---|---|
| 1 | Gate | GP26 |
| 2 | Source | GND |
| 3 | Drain | nNMI |

R4 (10kΩ): +5V → nNMI (pullup).

---

## Q2 — BSS138 (HALT open-drain)

| Pad | Pin | Net |
|---|---|---|
| 1 | Gate | GP27 |
| 2 | Source | GND |
| 3 | Drain | nHALT |

R5 (10kΩ): +5V → nHALT (pullup).

---

## U8 — 74LVC1G07 (CART_RW open-drain driver)

Buffer single-gate non-inverting open-drain. Permite que el RP2350 conduzca
CART_RW en modo bus master sin un GPIO dedicado (señal derivada de GP29).

| Field | Value |
|---|---|
| Symbol | `74xx:74LVC1G07` |
| Footprint | `Package_TO_SOT_SMD:SOT-353_SC-70-5` |
| Value | `74LVC1G07` |

| Pad | Pin | Net |
|---|---|---|
| 1 | A (input) | GP30 (CART_RW drive) |
| 2 | GND | GND |
| 3 | Y (output, open-drain) | CART_RW |
| 4 | VCC | +3V3 |

R13 (10 kΩ) pullup de CART_RW a +5V. Cuando GP30=LOW (lectura o idle),
salida high-Z → pullup pone CART_RW=HIGH. Cuando GP30=HIGH (escritura),
salida open-drain a GND → CART_RW=LOW. Con el 6809 corriendo (sin HALT),
firmware mantiene GP30=LOW → salida high-Z → el 6809 conduce CART_RW
normalmente sin conflicto.

---

## Q3 — BSS138 (RST open-drain)

| Pad | Pin | Net |
|---|---|---|
| 1 | Gate | GP28 |
| 2 | Source | GND |
| 3 | Drain | nRST |

R6 (10kΩ): +5V → nRST (pullup).

---

## Y1 — Crystal 12MHz

| Field | Value |
|---|---|
| Symbol | `Device:Crystal_GND24` |
| Footprint | `Crystal:Crystal_SMD_3225-4Pin_3.2x2.5mm` |
| Value | `12MHz` |

| Pad | Net |
|---|---|
| 1 | XTAL_IN |
| 2 | GND |
| 3 | XTAL_OUT |
| 4 | GND |

---

## J1 — Card edge 36 pines (cartucho Vectrex)

Sin conector físico — los pads del PCB son el cartucho.
Footprint custom: 36 pads dorados (gold fingers), paso 2.54mm, bisel 45°, grosor PCB 1.6mm.
Pads impares (1,3,5…35) = cara inferior; pares (2,4,6…36) = cara superior.

| Pin | Señal | Net |
|---|---|---|
| 1 | /HALT | nHALT |
| 2 | +5V | +5V |
| 3 | A7 | CART_A7 |
| 4 | +5V | +5V |
| 5 | A6 | CART_A6 |
| 6 | A8 | CART_A8 |
| 7 | A5 | CART_A5 |
| 8 | A9 | CART_A9 |
| 9 | A4 | CART_A4 |
| 10 | A11 | CART_A11 |
| 11 | A3 | CART_A3 |
| 12 | /OE | CART_nOE |
| 13 | A2 | CART_A2 |
| 14 | A10 | CART_A10 |
| 15 | A1 | CART_A1 |
| 16 | /CE | CART_nCE |
| 17 | A0 | CART_A0 |
| 18 | D7 | CART_D7 |
| 19 | D0 | CART_D0 |
| 20 | D6 | CART_D6 |
| 21 | D1 | CART_D1 |
| 22 | D5 | CART_D5 |
| 23 | D2 | CART_D2 |
| 24 | D4 | CART_D4 |
| 25 | GND | GND |
| 26 | D3 | CART_D3 |
| 27 | GND | GND |
| 28 | GND | GND |
| 29 | A12 | CART_A12 |
| 30 | R/W | CART_RW |
| 31 | A13 | CART_A13 |
| 32 | NC | — |
| 33 | A14 | CART_A14 |
| 34 | /NMI | nNMI |
| 35 | NC | — |
| 36 | /IRQ | NC |

---

## TP_BOOTSEL — Pad de test BOOTSEL

Pad de test (no botón) accesible con pinzas o puente.
Conectado a `QSPI_CSn` (mismo net que U7 pin 1).

Para entrar en modo bootloader USB (unbrick):
1. Puentea TP_BOOTSEL a GND con unas pinzas
2. Conecta o reconecta el USB
3. Suelta el puente
4. Aparece disco USB `RP2350` — arrastra el `.uf2`

| Campo | Valor |
|---|---|
| Symbol | `TestPoint:TestPoint_Pad_D1.5mm` |
| Net | QSPI_CSn |

> El bootloader está en ROM del RP2350 — no puede corromperse con firmware.
> Es el método de recuperación (unbrick) ante un firmware inválido.

---

## J_SWD1 — Header SWD (1×4, 2.54mm)

| Pad | Net |
|---|---|
| 1 | GND |
| 2 | SWD_CLK |
| 3 | SWD_IO |
| 4 | +3V3 |

---

## J_USB1 — USB-C Receptáculo (USB 2.0)

| Symbol pin | Net |
|---|---|
| VBUS | +5V |
| CC1 | CC1 → R11 (5.1kΩ) → GND |
| CC2 | CC2 → R12 (5.1kΩ) → GND |
| D− (A7+B7) | USB_DM |
| D+ (A6+B6) | USB_DP |
| GND / SHIELD | GND |

---

## J_UART — Header UART (1×4, 2.54 mm)

Header para consola UART hardware del RP2350. Independiente del USB CDC —
útil cuando el USB está en modo BOOTSEL (UF2 flashing) o cuando quieres
loguear desde un Picoprobe / FTDI / Raspberry Pi.

Pinout estilo Picoprobe (mirando desde arriba del header):

| Pin | Net | Función |
|---|---|---|
| 1 | GND | Tierra |
| 2 | UART_RX | RP2350 GP33 recibe — conectar a TX del adaptador |
| 3 | UART_TX | RP2350 GP32 transmite — conectar a RX del adaptador |
| 4 | +3V3 | Salida para alimentar adaptador externo si hace falta |

| Field | Value |
|---|---|
| Symbol | `Connector_Generic:Conn_01x04` |
| Footprint | `Connector_PinHeader_2.54mm:PinHeader_1x04_P2.54mm_Vertical` |

Configura UART0 en el firmware con 115200-8-N-1.

---

## SW1 — BOOTSEL button (opcional)

Tactile switch SMD 2-pin entre `TP_BOOTSEL` (= `QSPI_CSn`) y `GND`.
Sustituye al método "puentea TP_BOOTSEL con pinzas" — más cómodo.

| Field | Value |
|---|---|
| Symbol | `Switch:SW_Push` |
| Footprint | `Button_Switch_SMD:SW_SPST_PTS810_SJM_W` |
| Value | `SW_PUSH` |

| Pad | Net |
|---|---|
| 1 | TP_BOOTSEL (= QSPI_CSn) |
| 2 | GND |

Procedimiento de entrada en BOOTSEL: pulsa SW1 mientras conectas USB, suelta
al cabo de 1 segundo. Aparece disco USB `RP2350` para arrastrar el `.uf2`.

---

## Resistencias

| Ref | Valor | Pad 1 | Pad 2 | Función |
|---|---|---|---|---|
| R4 | 10kΩ | +5V | nNMI | Pullup /NMI |
| R5 | 10kΩ | +5V | nHALT | Pullup /HALT |
| R6 | 10kΩ | +5V | nRST | Pullup /RST |
| R9 | 10kΩ | CART_nOE | GP25 | Divisor /OE (top) |
| R10 | 18kΩ | GP25 | GND | Divisor /OE (bottom) |
| R11 | 5.1kΩ | GND | CC1 | USB-C CC pull-down |
| R12 | 5.1kΩ | GND | CC2 | USB-C CC pull-down |
| R13 | 10kΩ | +5V | CART_RW | Pullup CART_RW (open-drain via U8) |

> R7/R8 eliminados (eran el divisor para sensar CART_RW). GP24 ahora drives
> ABUS_DIR (U2/U3 pin 1). CART_RW se conduce vía U8 (74LVC1G07 open-drain)
> con pullup R13 — GP29 LOW = CART_RW HIGH (read), GP29 HIGH = CART_RW LOW
> (write). Esto da capacidad completa de bus master en v1.

Todas en footprint `Resistor_SMD:R_0402_1005Metric`.

---

## Condensadores

| Ref | Valor | Pad 1 | Pad 2 | Notas |
|---|---|---|---|---|
| C1–C8 | 100nF | +3V3 | GND | Decoupling RP2350 (uno por par IOVDD/DVDD) |
| C9 | 100nF | +3V3 | GND | Decoupling U6 (PSRAM) |
| C10 | 100nF | +3V3 | GND | Decoupling U7 (flash) |
| C11 | 100nF | +3V3 | GND | Decoupling QSPI_IOVDD |
| C12 | 100nF | +3V3 | GND | Decoupling USB_OTP_VDD |
| C13 | 100nF | +3V3 | GND | Decoupling VREG_AVDD |
| C_LDO_IN | 10µF | +5V | GND | LDO input (0805) |
| C_LDO_OUT | 10µF | +3V3 | GND | LDO output (0805) |

> Modo SMPS interno NO usado en v1: `VREG_LX` y `VREG_FB` van a +3V3 (bypass).
> Para activar SMPS en v2 hay que añadir inductor 470nH + diodo Schottky en `VREG_LX`
> según §5.4 fig.18 del datasheet RP2350. En v1 el core consume ~50mA en LDO, OK
> para alimentación vía AMS1117.

C1–C10 y C_VREG en `Capacitor_SMD:C_0402_1005Metric`.

---

## QSPI Bus Summary

U6 (PSRAM) y U7 (flash) comparten el bus QSPI de 4 bits. Chip select separado:

| Señal | RP2350 pin | U6 PSRAM | U7 Flash |
|---|---|---|---|
| QSPI_SD0 | QSPI_SD0 | 5 (SIO0) | 5 (DI) |
| QSPI_SD1 | QSPI_SD1 | 2 (SIO1) | 2 (DO) |
| QSPI_SD2 | QSPI_SD2 | 3 (SIO2) | 3 (/WP) |
| QSPI_SD3 | QSPI_SD3 | 7 (SIO3) | 7 (/HOLD) |
| QSPI_SCK | QSPI_SCLK | 6 (SCLK) | 6 (CLK) |
| QSPI_CSn | ~{QSPI_SS} | — | 1 (/CS) |
| QSPI_SS1n | ~{QSPI_SS1} | 1 (CE#) | — |

> QSPI_SS1n es el CS1 hardware del QMI del RP2350. El firmware lo controla
> directamente desde `pac::QMI` sin necesidad de un GPIO de software.

---

## BOM resumen (1 unidad)

| Componente | Qty | Precio aprox |
|---|---|---|
| RP2350B QFN-80 | 1 | ~1.60€ |
| W25Q32JV SOIC-8 (4MB flash) | 1 | ~0.50€ |
| APS6404L SOIC-8 (8MB PSRAM) | 1 | ~1.50€ |
| 74LVC245A TSSOP-20 | 3 | ~0.90€ |
| AMS1117-3.3 SOT-223 | 1 | ~0.15€ |
| BSS138 SOT-23 | 3 | ~0.15€ |
| 74LVC1G07 SOT-353 | 1 | ~0.15€ |
| Crystal 12MHz 3225 | 1 | ~0.30€ |
| USB-C receptáculo | 1 | ~0.40€ |
| Header 1×4 2.54 mm (J_UART) | 1 | ~0.10€ |
| Tactile switch SMD (SW1, opcional) | 1 | ~0.10€ |
| Resistencias 0402 | 9 | ~0.10€ |
| Condensadores 0402/0805 | 13 | ~0.15€ |
| **Componentes total** | | **~6.10€** |
| PCB Aisler 3 uds (gold fingers + bisel) | | ~35€ (~12€/ud) |
| **TOTAL por unidad** | | **~18€** |

> Cambio de RP2350A → RP2350B suma ~0.40€/ud, añade UART hardware,
> CART_RW dedicado, PSRAM_CS dedicado y 14 GPIOs libres.
