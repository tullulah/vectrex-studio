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
| QSPI_CSn | RP2350 QSPI CS0 → W25Q64JV boot flash |
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
| GPIO34 | GP34 | SD_SCK → J_SD pin 5 (CLK) |
| GPIO35 | GP35 | SD_MOSI → J_SD pin 3 (CMD) |
| GPIO36 | GP36 | SD_MISO → J_SD pin 7 (DAT0) |
| GPIO37 | GP37 | SD_CS → J_SD pin 2 (DAT3/CS) — con pullup R10 |
| GPIO38 | GP38 | SD_CD → J_SD pin 9 (card-detect switch) |
| GPIO39 | GP39 | PB6 sense (CON1 pin 35 via divisor R11/R12) |
| GPIO40 | GP40 | CART sense (CON1 pin 32 via divisor R13/R14) |
| GPIO41 | GP41 | nIRQ drive (open-drain via Q4) |
| GPIO42–47 | — | reservados (libres) |

> **ABUS_DIR (GP24)** controla la dirección de los buffers U2/U3 del bus de
> direcciones: LOW = Vectrex→RP2350 (modo ROM, default). HIGH = RP2350→Vectrex
> (bus master). /OE de U2/U3 está cableado a GND (siempre habilitado).
>
> **CART_RW (vía U8 + R6)**: GP30 alimenta la entrada de U8 (74LVC1G07
> open-drain). GP30 LOW → U8 high-Z → R6 pulla CART_RW a +5V (read cycle).
> GP30 HIGH → U8 drives → CART_RW=LOW (write cycle). En modo normal (6809
> corriendo), GP30 se mantiene LOW → U8 high-Z → el 6809 conduce CART_RW
> sin conflicto. **Los GPIOs del RP2350 no son 5V tolerantes** — U8 hace de
> level shifter obligatorio.
>
> **Antiguo divisor de R/W sense eliminado** (ya no aparece en la BOM). El
> RP2350 ya no necesita leer R/W del 6809 porque solo opera en modo bus
> master — solo lo conduce vía U8.

### QSPI / power / debug pins

| Symbol pin | Net | Notas |
|---|---|---|
| QSPI_SD0 | QSPI_SD0 | Compartido flash + PSRAM |
| QSPI_SD1 | QSPI_SD1 | |
| QSPI_SD2 | QSPI_SD2 | |
| QSPI_SD3 | QSPI_SD3 | |
| QSPI_SCLK | QSPI_SCK | |
| ~{QSPI_SS} | QSPI_CSn | CS único expuesto → W25Q64JV (PSRAM CS por GPIO) |
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

## U7 — W25Q64JVSSIQ (8MB SPI NOR flash, boot RP2350)

| Field | Value |
|---|---|
| Symbol | `Memory_Flash:W25Q32JV` (pinout-compatible con W25Q16/32/64/128) |
| Footprint | `Package_SO:SOIC-8_3.9x4.9mm_P1.27mm` |
| Value | `W25Q64JVSSIQ` |
| LCSC | `C129437` |

> El símbolo de KiCad `W25Q32JV` es pin-compatible con toda la serie W25Q
> (16, 32, 64, 128 Mbit). Usamos W25Q64 (8 MB) por margen de capacidad —
> al mismo precio aproximado que W25Q32. La temperatura industrial (`-I-`)
> y el modo QPI default (`-Q-`) son ventajas pequeñas pero útiles para
> condiciones reales de uso.

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

R1 (10kΩ): +5V → nNMI (pullup).

---

## Q2 — BSS138 (HALT open-drain)

| Pad | Pin | Net |
|---|---|---|
| 1 | Gate | GP27 |
| 2 | Source | GND |
| 3 | Drain | nHALT |

R2 (10kΩ): +5V → nHALT (pullup).

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

R6 (10 kΩ) pullup de CART_RW a +5V. Cuando GP30=LOW (lectura o idle),
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

R3 (10kΩ): +5V → nRST (pullup).

---

## Q4 — BSS138 (IRQ open-drain)

| Pad | Pin | Net |
|---|---|---|
| 1 | Gate | GP41 |
| 2 | Source | GND |
| 3 | Drain | nIRQ |

R15 (10kΩ): +5V → nIRQ (pullup).

Inyecta /IRQ al 6809 (interrupción maskeable). Diferencia con /NMI: el 6809
puede ignorar /IRQ cuando el flag `I` del CC register está set. Útil para
protocols custom en modo ROM emulation o para debug stepping sincronizado.

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
| CC1 | CC1 → R7 (5.1kΩ) → GND |
| CC2 | CC2 → R8 (5.1kΩ) → GND |
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

## J_SD — microSD slot (Hirose DM3AT-SF push-push)

Slot push-push con interruptor de card-detect. Permite multi-juego (ROMs en
SD), save states persistentes, assets externos al firmware.

| Field | Value |
|---|---|
| Symbol | `Connector:Micro_SD_Card_Det_Hirose_DM3AT` |
| Footprint | `Connector_Card:microSD_HC_Hirose_DM3AT-SF-PEJM5` |
| Value | `microSD DM3AT-SF` |

Conexión en modo SPI (1-bit):

| Pad | Pin SD | Función SPI | Net |
|---|---|---|---|
| 1 | DAT2 | NC en SPI | NC |
| 2 | DAT3/CD | CS (chip select) | SD_CS (GP37) |
| 3 | CMD | MOSI | SD_MOSI (GP35) |
| 4 | VDD | +3V3 | +3V3 (con C14 cerca) |
| 5 | CLK | SCK | SD_SCK (GP34) |
| 6 | VSS | GND | GND |
| 7 | DAT0 | MISO | SD_MISO (GP36) |
| 8 | DAT1 | NC en SPI | NC |
| 9 | CD switch | Card detect | SD_CD (GP38, input con pullup interno) |
| 10 | Shield | Shield | GND |

> El switch del card-detect cierra a GND cuando hay tarjeta insertada.
> Configurar GP38 como input con pullup interno del RP2350 — leer LOW =
> tarjeta presente, HIGH = vacío.

C14 (10 µF) cerca del VDD del slot para absorber picos de corriente al
insertar la tarjeta (puede consumir ~100 mA pico).

---

## Vextreme extended cart-edge signals (PB6 + CART)

El símbolo `vextreme:vectrex-edge-connector` añade 2 pines extra sobre el
card edge estándar Vectrex (sobre los antiguos NC pins 32 y 35):

| Pin CON1 | Net | Conexión interna en el Vectrex |
|---|---|---|
| 32 | CART | Salida de IC203A pin 3 (74LS32 OR gate) — derivada del address decoder |
| 35 | PB6 | VIA 6522 pin 16 (PB6) — comparador del DAC X |

**Estos pines requieren modificación del Vectrex** (cables soldados desde el
VIA / 74LS32 a los pads del card edge previamente NC). Sin esa modificación,
los signal no estarán presentes.

### PB6 (pin 35)

- Bidireccional según DDR del VIA. En uso típico = input al VIA (comparador
  del DAC X detecta cruce por cero del eje horizontal).
- Sample directo desde el card edge → permite al RP2350 saber el estado del
  comparador analógico sin un ciclo de bus al VIA.
- Útil para: sincronización fina del beam, debug del DAC analógico, overlays
  que necesitan timing exacto del haz.

### CART (pin 32)

- Output de la lógica del Vectrex (IC203A pin 3 del 74LS32 OR gate).
- Estado derivado del address decoder — útil para saber qué zona de memoria
  está accediendo el bus sin replicar el decoder en firmware.

### Acceso desde el firmware

Ambos signal entran al MCU a través de divisores 10k+18k (5V→3.21V) porque
los GPIOs del RP2350 no toleran 5V:

| GPIO | Signal | Divisor |
|---|---|---|
| GP39 | PB6 | R11 (top) + R12 (bottom) |
| GP40 | CART | R13 (top) + R14 (bottom) |

Configura ambos GPIOs como input en el firmware. Su lectura es asíncrona;
si necesitas detectar transiciones rápidas usa interrupción.

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
| R1 | 10kΩ | +5V | nNMI | Pullup /NMI |
| R2 | 10kΩ | +5V | nHALT | Pullup /HALT |
| R3 | 10kΩ | +5V | nRST | Pullup /RST |
| R4 | 10kΩ | CART_nOE | GP25 | Divisor /OE (top) |
| R5 | 18kΩ | GP25 | GND | Divisor /OE (bottom) |
| R6 | 10kΩ | +5V | CART_RW | Pullup CART_RW (open-drain via U8) |
| R7 | 5.1kΩ | GND | CC1 | USB-C CC pull-down |
| R8 | 5.1kΩ | GND | CC2 | USB-C CC pull-down |
| R9 | 100kΩ | +3V3 | RUN | Pullup RUN (reset hardware del MCU) |
| R10 | 10kΩ | +3V3 | SD_CS | Pullup CS de SD (inicio determinístico) |
| R11 | 10kΩ | CON1 pin 35 (PB6) | GP39 | Divisor PB6 (top) — vextreme ext |
| R12 | 18kΩ | GP39 | GND | Divisor PB6 (bottom) — 5V→3.21V |
| R13 | 10kΩ | CON1 pin 32 (CART) | GP40 | Divisor CART (top) — vextreme ext |
| R14 | 18kΩ | GP40 | GND | Divisor CART (bottom) |
| R15 | 10kΩ | +5V | nIRQ | Pullup /IRQ (open-drain via Q4) |

> Antiguo divisor de R/W sense eliminado. GP24 ahora drives ABUS_DIR (U2/U3
> pin 1). CART_RW se conduce vía U8 (74LVC1G07 open-drain) con pullup R6 —
> GP30 LOW = CART_RW HIGH (read), GP30 HIGH = CART_RW LOW (write). Esto da
> capacidad completa de bus master en v1.

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
| C14 | 10µF | +3V3 | GND | Bulk para microSD (picos al insertar) — 0805 |
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
| W25Q64JVSSIQ SOIC-8 (8MB flash, industrial) | 1 | ~0.60€ |
| APS6404L SOIC-8 (8MB PSRAM) | 1 | ~1.50€ |
| 74LVC245A TSSOP-20 | 3 | ~0.90€ |
| AMS1117-3.3 SOT-223 | 1 | ~0.15€ |
| BSS138 SOT-23 | 4 | ~0.20€ |
| 74LVC1G07 SOT-353 | 1 | ~0.15€ |
| Crystal 12MHz 3225 | 1 | ~0.30€ |
| USB-C receptáculo | 1 | ~0.40€ |
| Header 1×4 2.54 mm (J_UART) | 1 | ~0.10€ |
| Tactile switch SMD (SW1, opcional) | 1 | ~0.10€ |
| microSD Hirose DM3AT-SF push-push | 1 | ~2.00€ |
| Resistencias 0402 | 15 | ~0.15€ |
| Condensadores 0402/0805 | 14 | ~0.20€ |
| **Componentes total** | | **~8.15€** |
| PCB Aisler 3 uds (gold fingers + bisel) | | ~35€ (~12€/ud) |
| **TOTAL por unidad** | | **~20€** |

> Cambio de RP2350A → RP2350B suma ~0.40€/ud, añade UART hardware,
> CART_RW dedicado, PSRAM_CS dedicado y 14 GPIOs libres.
