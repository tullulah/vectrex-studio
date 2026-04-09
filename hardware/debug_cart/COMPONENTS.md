# Debug Cart — Component Reference

Schematic entry guide. All symbols and footprints are from standard KiCad 9 libraries unless noted.
Re-enter each component manually in KiCad using the tables below.

---

## Signal Glossary

| Net name | Description |
|---|---|
| +5V | Vectrex 5 V rail (from edge connector) |
| +3V3 | 3.3 V regulated rail |
| GND | Ground |
| GP0–GP29 | RP2040 GPIO |
| CART_A0–A14 | Vectrex address bus |
| CART_D0–D7 | Vectrex data bus |
| CART_RW | Vectrex R/W line |
| CART_nOE | Vectrex /OE (output enable) |
| CART_nCE | Vectrex /CE (chip enable) |
| nNMI / nHALT | Open-drain NMI / HALT lines to Vectrex |
| QSPI_SD0–SD3 | RP2040 QSPI data lines |
| QSPI_SCK | RP2040 QSPI clock |
| QSPI_CSn | RP2040 QSPI chip select → W25Q16JV boot flash |
| PSRAM_CS | RP2040 GP29 → APS6404L PSRAM chip select |
| DIR_CTRL | Data bus buffer direction control (RP2040 GP29/RUN pin area) |
| SWD_IO / SWD_CLK | SWDIO / SWDCLK debug lines |
| XTAL_IN / XTAL_OUT | 12 MHz crystal |
| USB_DP / USB_DM | USB D+ / D− |
| TP_RESET | Reset test point |
| GP24_RW / GP25_nOE / GP26_nNMI / GP27_nHALT / GP28_nRST | RP2040 control GPIO |

---

## U1 — RP2040

| Field | Value |
|---|---|
| Symbol | `MCU_RaspberryPi:RP2040` |
| Footprint | `Package_DFN_QFN:QFN-56-1EP_7x7mm_P0.4mm_EP3.2x3.2mm` |
| Value | `RP2040` |

### Pin connections (symbol signal name → net)

| Symbol pin name | Net |
|---|---|
| GPIO0 | GP0 |
| GPIO1 | GP1 |
| GPIO2 | GP2 |
| GPIO3 | GP3 |
| GPIO4 | GP4 |
| GPIO5 | GP5 |
| GPIO6 | GP6 |
| GPIO7 | GP7 |
| GPIO8 | GP8 |
| GPIO9 | GP9 |
| GPIO10 | GP10 |
| GPIO11 | GP11 |
| GPIO12 | GP12 |
| GPIO13 | GP13 |
| GPIO14 | GP14 |
| GPIO15 | GP15 |
| GPIO16 | GP16 |
| GPIO17 | GP17 |
| GPIO18 | GP18 |
| GPIO19 | GP19 |
| GPIO20 | GP20 |
| GPIO21 | GP21 |
| GPIO22 | GP22 |
| GPIO23 | GP23 |
| GPIO24 | GP24_RW |
| GPIO25 | GP25_nOE |
| GPIO26/ADC0 | GP26_nNMI |
| GPIO27/ADC1 | GP27_nHALT |
| GPIO28/ADC2 | GP28_nRST |
| GPIO29/ADC3 | PSRAM_CS |
| RUN | DIR_CTRL |
| IOVDD (all) | +3V3 |
| DVDD (all) | +3V3 |
| VREG_VIN | +3V3 |
| VREG_VOUT | VREG_VOUT (local net — connect C_VREG 1 µF to GND) |
| ADC_AVDD | +3V3 |
| USB_VDD | +3V3 |
| XIN | XTAL_IN |
| XOUT | XTAL_OUT |
| USB_DP | USB_DP |
| USB_DM | USB_DM |
| SWDIO | SWD_IO |
| SWCLK | SWD_CLK |
| QSPI_SD0 | QSPI_SD0 |
| QSPI_SD1 | QSPI_SD1 |
| QSPI_SD2 | QSPI_SD2 |
| QSPI_SD3 | QSPI_SD3 |
| QSPI_SCLK | QSPI_SCK |
| ~{QSPI_SS} | QSPI_CSn |
| GND (all) | GND |
| TESTEN | GND |

> **EP (exposed pad):** No existe en el símbolo. Conectar a GND **solo en el PCB** mediante copper fill / via a plano GND.

### C_VREG — condensador de VREG_VOUT

Añadir un condensador adicional (no está en la lista de C1–C10):

| Field | Value |
|---|---|
| Symbol | `Device:C` |
| Footprint | `Capacitor_SMD:C_0402_1005Metric` |
| Value | `1µF` |
| Pad 1 | VREG_VOUT |
| Pad 2 | GND |

---

## U2 — 74LVC245A (Address bus lower byte, A0–A7)

| Field | Value |
|---|---|
| Symbol | `74xx:74LVC245A` |
| Footprint | `Package_SO:TSSOP-20_4.4x6.5mm_P0.65mm` |
| Value | `74LVC245A` |

Direction fixed: DIR tied to GND (always A→B), /OE tied to GND (always enabled).

| Pad | Pin name | Net |
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

---

## U3 — 74LVC245A (Address bus upper byte + control signals, A8–A14 + /CE)

| Field | Value |
|---|---|
| Symbol | `74xx:74LVC245A` |
| Footprint | `Package_SO:TSSOP-20_4.4x6.5mm_P0.65mm` |
| Value | `74LVC245A` |

Direction fixed: DIR tied to GND, /OE tied to GND.

| Pad | Pin name | Net |
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

## U4 — 74LVC245A (Data bus, D0–D7, bidirectional)

| Field | Value |
|---|---|
| Symbol | `74xx:74LVC245A` |
| Footprint | `Package_SO:TSSOP-20_4.4x6.5mm_P0.65mm` |
| Value | `74LVC245A` |

Direction controlled by RP2040 (DIR_CTRL), /OE tied to GND (always enabled).

| Pad | Pin name | Net |
|---|---|---|
| 1 | DIR | DIR_CTRL |
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

## U5 — AMS1117-3.3 (3.3 V LDO regulator)

| Field | Value |
|---|---|
| Symbol | `Regulator_Linear:AMS1117-3.3` |
| Footprint | `Package_TO_SOT_SMD:SOT-223-3_TabPin2` |
| Value | `AMS1117-3.3` |

| Pad | Pin name | Net |
|---|---|---|
| 1 | ADJ/GND | GND |
| 2 | OUTPUT (tab) | +3V3 |
| 3 | INPUT | +5V |

---

## U6 — APS6404L-3SQR (8 MB QSPI PSRAM)

| Field | Value |
|---|---|
| Symbol | Custom — use `Memory_RAM:Generic_QSPI_RAM_SOIC8` or create manually |
| Footprint | `Package_SO:SOIC-8_3.9x4.9mm_P1.27mm` |
| Value | `APS6404L-3SQR` |

Datasheet pin names (AP Memory APS6404L):

| Pad | Pin name | Net |
|---|---|---|
| 1 | CE# (chip enable, active low) | PSRAM_CS |
| 2 | SIO1 (MISO / QSPI D1) | QSPI_SD1 |
| 3 | SIO2 (QSPI D2) | QSPI_SD2 |
| 4 | VSS | GND |
| 5 | SIO0 (MOSI / QSPI D0) | QSPI_SD0 |
| 6 | SCLK | QSPI_SCK |
| 7 | SIO3 (QSPI D3) | QSPI_SD3 |
| 8 | VCC | +3V3 |

> **Note:** PSRAM_CS is driven by RP2040 GP29.
> The QSPI bus (SD0–SD3, SCK) is shared with U7 (boot flash).

---

## U7 — W25Q16JV (2 MB SPI NOR flash, RP2040 boot)

| Field | Value |
|---|---|
| Symbol | `Memory_Flash:W25Q16JV` or `Memory_Flash:W25Q16xx` |
| Footprint | `Package_SO:SOIC-8_3.9x4.9mm_P1.27mm` |
| Value | `W25Q16JV` |

| Pad | Pin name | Net |
|---|---|---|
| 1 | /CS | QSPI_CSn |
| 2 | DO (MISO / IO1) | QSPI_SD1 |
| 3 | /WP (IO2) | QSPI_SD2 |
| 4 | GND | GND |
| 5 | DI (MOSI / IO0) | QSPI_SD0 |
| 6 | CLK | QSPI_SCK |
| 7 | /HOLD (IO3) | QSPI_SD3 |
| 8 | VCC | +3V3 |

---

## Q1 — BSS138 (NMI open-drain driver)

| Field | Value |
|---|---|
| Symbol | `Transistor_FET:BSS138` |
| Footprint | `Package_TO_SOT_SMD:SOT-23` |
| Value | `BSS138` |

| Pad | Pin name | Net |
|---|---|---|
| 1 | Gate | GP26_nNMI |
| 2 | Source | GND |
| 3 | Drain | nNMI |

---

## Q2 — BSS138 (HALT open-drain driver)

| Field | Value |
|---|---|
| Symbol | `Transistor_FET:BSS138` |
| Footprint | `Package_TO_SOT_SMD:SOT-23` |
| Value | `BSS138` |

| Pad | Pin name | Net |
|---|---|---|
| 1 | Gate | GP27_nHALT |
| 2 | Source | GND |
| 3 | Drain | nHALT |

---

## Q3 — BSS138 (Reset open-drain driver)

| Field | Value |
|---|---|
| Symbol | `Transistor_FET:BSS138` |
| Footprint | `Package_TO_SOT_SMD:SOT-23` |
| Value | `BSS138` |

| Pad | Pin name | Net |
|---|---|---|
| 1 | Gate | GP28_nRST |
| 2 | Source | GND |
| 3 | Drain | TP_RESET |

---

## Y1 — 12 MHz Crystal

| Field | Value |
|---|---|
| Symbol | `Device:Crystal_GND24` |
| Footprint | `Crystal:Crystal_SMD_3225-4Pin_3.2x2.5mm` |
| Value | `12MHz` |

| Pad | Pin name | Net |
|---|---|---|
| 1 | XIN | XTAL_IN |
| 2 | GND | GND |
| 3 | XOUT | XTAL_OUT |
| 4 | GND | GND |

---

## J1 — Vectrex 36-pin card edge connector

| Field | Value |
|---|---|
| Symbol | Custom — use `Connector_PinHeader_2.54mm:Conn_02x18` (copy footprint from another project) |
| Footprint | Custom `VPyDebugCart:CardEdge_36` (36 pads, 1.52×8.8 mm oval, 2.54 mm pitch) |
| Value | `VECTREX_CART_36` |

Odd pads (1,3,5…35) = B.Cu side; even pads (2,4,6…36) = F.Cu side.

| Pin | Signal name | Net |
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
| 36 | /IRQ | (unconnected — Vectrex does not use /IRQ for cartridges) |

---

## J_SWD1 — SWD Debug Header

| Field | Value |
|---|---|
| Symbol | `Connector_PinHeader_2.54mm:Conn_01x04` |
| Footprint | `Connector_PinHeader_2.54mm:PinHeader_1x04_P2.54mm_Vertical` |
| Value | `Conn_01x04` |

| Pad | Net |
|---|---|
| 1 | GND |
| 2 | SWD_CLK |
| 3 | SWD_IO |
| 4 | +3V3 |

---

## J_USB1 — USB-C Receptacle

| Field | Value |
|---|---|
| Symbol | `Connector_USB:USB_C_Receptacle_USB2.0` |
| Footprint | `Connector_USB:USB_C_Receptacle_HRO_TYPE-C-31-M-12` |
| Value | `USB_C_Receptacle` |

| Symbol pin | Net |
|---|---|
| VBUS (A4) | +5V |
| CC1 (A5) | CC1 |
| CC2 (B5) | CC2 |
| D- (A7) | USB_DM |
| D- (B7) | USB_DM |
| D+ (A6) | USB_DP |
| D+ (B6) | USB_DP |
| SBU1 (A8) | No connect |
| SBU2 (B8) | No connect |
| GND (A1) | GND |
| SHIELD (S1) | GND |

> CC1 → R11 (5.1 kΩ) → GND; CC2 → R12 (5.1 kΩ) → GND.
> Conectar A7 y B7 juntos al mismo net USB_DM; A6 y B6 juntos a USB_DP.

---

## Resistors

| Ref | Value | Symbol | Footprint | Pad 1 → Net | Pad 2 → Net |
|---|---|---|---|---|---|
| R4 | 10 kΩ | `Device:R` | `Resistor_SMD:R_0402_1005Metric` | +5V | nNMI |
| R5 | 10 kΩ | `Device:R` | `Resistor_SMD:R_0402_1005Metric` | +5V | nHALT |
| R6 | 10 kΩ | `Device:R` | `Resistor_SMD:R_0402_1005Metric` | +5V | TP_RESET |
| R7 | 10 kΩ | `Device:R` | `Resistor_SMD:R_0402_1005Metric` | CART_RW | GP24_RW |
| R8 | 18 kΩ | `Device:R` | `Resistor_SMD:R_0402_1005Metric` | GP24_RW | GND |
| R9 | 10 kΩ | `Device:R` | `Resistor_SMD:R_0402_1005Metric` | CART_nOE | GP25_nOE |
| R10 | 18 kΩ | `Device:R` | `Resistor_SMD:R_0402_1005Metric` | GP25_nOE | GND |
| R11 | 5.1 kΩ | `Device:R` | `Resistor_SMD:R_0402_1005Metric` | GND | CC1 |
| R12 | 5.1 kΩ | `Device:R` | `Resistor_SMD:R_0402_1005Metric` | GND | CC2 |

> R7/R8 form a voltage divider for CART_RW (5 V → 3.3 V level shift, approx 3.21 V at GP24).
> R9/R10 form a similar divider for CART_nOE → GP25_nOE.
> R11/R12 are USB-C CC pull-down resistors (device/UFP mode, 5 V / 500 mA).

---

## Decoupling Capacitors

All 100 nF, 0402.

| Ref | Symbol | Footprint | Pad 1 → Net | Pad 2 → Net | Notes |
|---|---|---|---|---|---|
| C1 | `Device:C` | `Capacitor_SMD:C_0402_1005Metric` | +3V3 | GND* | RP2040 decoupling |
| C2 | `Device:C` | `Capacitor_SMD:C_0402_1005Metric` | +3V3 | GND* | RP2040 decoupling |
| C3 | `Device:C` | `Capacitor_SMD:C_0402_1005Metric` | +3V3 | GND* | RP2040 decoupling |
| C4 | `Device:C` | `Capacitor_SMD:C_0402_1005Metric` | +3V3 | GND* | RP2040 decoupling |
| C5 | `Device:C` | `Capacitor_SMD:C_0402_1005Metric` | +5V | GND | +5V decoupling |
| C6 | `Device:C` | `Capacitor_SMD:C_0402_1005Metric` | +5V | GND | +5V decoupling |
| C7 | `Device:C` | `Capacitor_SMD:C_0402_1005Metric` | +3V3 | GND | General +3V3 decoupling |
| C8 | `Device:C` | `Capacitor_SMD:C_0402_1005Metric` | +3V3 | GND | General +3V3 decoupling |
| C9 | `Device:C` | `Capacitor_SMD:C_0402_1005Metric` | +3V3 | GND | U6 (PSRAM) decoupling |
| C10 | `Device:C` | `Capacitor_SMD:C_0402_1005Metric` | +3V3 | GND | U7 (flash) decoupling |

> \* C1–C4 pad 2 is labeled `Net-(C1-Pad2)` in the current PCB file — these should all connect to GND.
> Connect pad 2 of C1–C4 to GND when re-entering the schematic.

---

## RP2040 QSPI Bus Summary

Both U6 (PSRAM) and U7 (boot flash) share the 4-wire QSPI bus. Chip select is separate:

| Signal | RP2040 pad | U6 (PSRAM) pin | U7 (Flash) pin |
|---|---|---|---|
| QSPI_SD0 | 45 | 5 (SIO0) | 5 (DI) |
| QSPI_SD1 | 46 | 2 (SIO1) | 2 (DO) |
| QSPI_SD2 | 47 | 3 (SIO2) | 3 (/WP) |
| QSPI_SD3 | 48 | 7 (SIO3) | 7 (/HOLD) |
| QSPI_SCK | 49 | 6 (SCLK) | 6 (CLK) |
| QSPI_CSn | 50 | — | 1 (/CS) |
| PSRAM_CS (GP29) | 30 | 1 (CE#) | — |
