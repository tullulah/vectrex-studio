# Debug Cart — KiCad migration RP2040 → RP2350B

The current `.kicad_sch` and `.kicad_pcb` still target **RP2040 QFN-56** even
though `COMPONENTS.md`, `pins.rs` and the firmware all target **RP2350B
QFN-80**. Apply this migration in KiCad 9 GUI before generating Gerbers.

Estimated time: **45–60 minutes** (more than A variant because of UART
header + dedicated CART_RW + PSRAM_CS routing).

---

## Why RP2350B instead of RP2350A

Same silicon (dual M33 + RISC-V, 520 KB SRAM, FPU), same 0.4 mm pitch, but:

- **48 GPIOs** instead of 30 → no need to share GP29 between data direction
  and R/W; UART hardware on dedicated pins; PSRAM CS on dedicated pin.
- **+0.40 €/ud** extra cost — irrelevant at proto scale.
- **10×10 mm vs 7×7 mm** package — plenty of room on the cartridge PCB.

---

## 1. Swap the MCU symbol

1. Open `debug_cart.kicad_sch` in KiCad 9.
2. Locate **U1** (current symbol: `MCU_RaspberryPi:RP2040`).
3. Double-click U1 → **Edit Symbol Properties** → swap symbol to
   `MCU_RaspberryPi:RP2350B`.
4. KiCad shows a pin-remap dialog (56 → 80 pins, different layout). Use the
   pin mapping table in §3 below.
5. Update properties:
   - **Footprint**: `Package_DFN_QFN:QFN-80-1EP_10x10mm_P0.4mm_EP3.4x3.4mm`
   - **Value**: `RP2350B`

---

## 2. Power tree — LDO bypass mode

The RP2350B has the same SMPS topology as RP2350A. For 2 hand-built protos we
skip the external inductor + Schottky and run the core regulator in LDO
bypass mode by tying both LX and FB pins directly to +3V3 (≈50 mA at the core
rail).

Connect the **new** RP2350B power pins:

| Pin | Connect to | Why |
|---|---|---|
| `VREG_LX` | `+3V3` | LDO bypass — no inductor |
| `VREG_FB` | `+3V3` | LDO bypass — feedback tied high |
| `VREG_AVDD` | `+3V3` via 100 nF | Replaces RP2040's VREG_VIN |
| `QSPI_IOVDD` | `+3V3` via 100 nF | Dedicated QSPI IO rail (new) |
| `USB_OTP_VDD` | `+3V3` via 100 nF | OTP fuse programming rail (new) |
| Extra `IOVDD` / `DVDD` pins | `+3V3` | RP2350B has more power pins than RP2040 |

**Delete `C_VREG`** (1 µF was on RP2040's `VREG_VOUT` — that pin doesn't
exist on RP2350B).

**Add three 100 nF 0402 caps** (C11, C12, C13) close to VREG_AVDD,
QSPI_IOVDD, USB_OTP_VDD respectively.

---

## 3. GPIO assignment (RP2350B v1)

The current `pins.rs` is the source of truth. Connect each net to the GPIO
pin shown:

| GPIO | Net | Component |
|---|---|---|
| GP0–7 | CART_A0..7 (via U2) | already wired |
| GP8–14 | CART_A8..14 (via U3) | already wired |
| GP15–22 | CART_D0..7 (via U4) | already wired |
| GP23 | CART_nCE (via U3 B8) | already wired |
| **GP24** | **ABUS_DIR** (U2 pin 1 + U3 pin 1) | already wired (today's rework) |
| GP25 | CART_nOE (via R4/R5 divider) | already wired |
| GP26 | nNMI (via Q1) | already wired |
| GP27 | nHALT (via Q2) | already wired |
| GP28 | nRST (via Q3) | already wired |
| GP29 | DIR_CTRL (U4 pin 1) — now data direction only | already wired |
| **GP30** | **CART_RW drive (U8 pin 1 input)** | new |
| **GP31** | **PSRAM_CS (U6 pin 1)** | rename existing PSRAM_CS net to land on GP31 |
| **GP32** | **UART0 TX → J_UART pin 3** | new |
| **GP33** | **UART0 RX → J_UART pin 2** | new |
| **GP34** | **SD_SCK** (J_SD pin 5, SPI0 SCK) | new |
| **GP35** | **SD_MOSI** (J_SD pin 3, SPI0 TX) | new |
| **GP36** | **SD_MISO** (J_SD pin 7, SPI0 RX) | new |
| **GP37** | **SD_CS** (J_SD pin 2, SPI0 CSn, pullup R10) | new |
| **GP38** | **SD_CD** (J_SD pin 9, card-detect, internal pullup) | new |
| **GP39** | **PB6 sense** (CON1 pin 35 via R11/R12 divider) | new — vextreme ext |
| **GP40** | **CART sense** (CON1 pin 32 via R13/R14 divider) | new — vextreme ext |
| **GP41** | **nIRQ drive** (gate of Q4, open-drain to CON1 pin 36) | new |
| GP42–47 | spare | leave unconnected |

The exact RP2350B QFN-80 pin numbers for each GPIO come from KiCad's symbol
— let KiCad place them, then route from there.

---

## 4. Components to add

### U8 — 74LVC1G07 (CART_RW open-drain driver)

- Symbol: `74xx:74LVC1G07`
- Footprint: `Package_TO_SOT_SMD:SOT-353_SC-70-5`
- Reference: **U8**
- Connections:
  - pin 1 (A input) → `CART_RW_DRIVE` (= GP30)
  - pin 2 (GND) → `GND`
  - pin 3 (Y open-drain output) → `CART_RW`
  - pin 4 (VCC) → `+3V3`

### R6 — 10 kΩ pullup for CART_RW

- Symbol: `Device:R`, footprint `Resistor_SMD:R_0402_1005Metric`
- Reference: **R6**, value **10k**
- Connections: pin 1 → `+5V`, pin 2 → `CART_RW`

### J_UART — UART header (1×4, 2.54 mm)

- Symbol: `Connector_Generic:Conn_01x04`
- Footprint: `Connector_PinHeader_2.54mm:PinHeader_1x04_P2.54mm_Vertical`
- Reference: **J_UART**
- Pinout (looking at the header from above):

| Pin | Net | Notes |
|---|---|---|
| 1 | `GND` | |
| 2 | `UART_RX` | = GP33 |
| 3 | `UART_TX` | = GP32 |
| 4 | `+3V3` | optional power for external probe |

### J_SD — microSD slot (Hirose DM3AT-SF push-push)

- Symbol: `Connector:Micro_SD_Card_Det_Hirose_DM3AT`
- Footprint: `Connector_Card:microSD_HC_Hirose_DM3AT-SF-PEJM5`
- Reference: **J_SD**
- Connections (SPI mode):

| Pad | Net | GPIO |
|---|---|---|
| 1 (DAT2) | NC | — |
| 2 (DAT3/CD) | `SD_CS` | GP37 |
| 3 (CMD) | `SD_MOSI` | GP35 |
| 4 (VDD) | `+3V3` | — |
| 5 (CLK) | `SD_SCK` | GP34 |
| 6 (VSS) | `GND` | — |
| 7 (DAT0) | `SD_MISO` | GP36 |
| 8 (DAT1) | NC | — |
| 9 (CD switch) | `SD_CD` | GP38 |
| 10 (shield) | `GND` | — |

### R10 — 10 kΩ pullup on SD_CS

- Symbol: `Device:R`, footprint `Resistor_SMD:R_0402_1005Metric`
- Reference: **R10**, value **10k**
- Connections: `+3V3` → `SD_CS`

### C14 — 10 µF bulk near SD slot

- Footprint: `Capacitor_SMD:C_0805_2012Metric`, value **10µF**
- Reference: **C14**
- Connections: `+3V3` → `GND`, placed within 5 mm of J_SD VDD pin.

### Q4 + R15 — /IRQ open-drain control

Mirrors the Q1/Q2/Q3 pattern for HALT/NMI/RST. Allows the RP2350 to inject
maskable interrupts into the 6809 (useful in ROM emulation mode for custom
protocols or debug stepping).

- **Q4**: `Transistor_FET:BSS138`, footprint `Package_TO_SOT_SMD:SOT-23`
  - Pin 1 (Gate) → `GP41`
  - Pin 2 (Source) → `GND`
  - Pin 3 (Drain) → `nIRQ` (= CON1 pin 36)
- **R15**: 10 kΩ pullup, footprint `Resistor_SMD:R_0402_1005Metric`
  - Pin 1 → `+5V`, pin 2 → `nIRQ`

### R11, R12, R13, R14 — Vextreme extended cart-edge signal dividers

The vextreme card-edge symbol exposes two extra signals (PB6 on pin 35 and
CART on pin 32) that are 5V on the Vectrex side. Both need a 10k+18k divider
to land safely on a 3.3V GPIO of the RP2350B.

- Symbol: `Device:R`, footprint `Resistor_SMD:R_0402_1005Metric`
- **R11** = 10k: CON1 pin 35 (PB6) → GP39 (top of divider)
- **R12** = 18k: GP39 → GND (bottom of divider)
- **R13** = 10k: CON1 pin 32 (CART) → GP40 (top of divider)
- **R14** = 18k: GP40 → GND (bottom of divider)

Resulting voltage at GP39/GP40 when input is 5V: `5 × 18/(10+18) = 3.21V`
— compatible with 3.3V CMOS input thresholds.

### SW1 — BOOTSEL button (optional)

- Symbol: `Switch:SW_Push`
- Footprint: `Button_Switch_SMD:SW_SPST_PTS810_SJM_W`
- Reference: **SW1**
- Connections: pin 1 → `TP_BOOTSEL` (= `QSPI_CSn`), pin 2 → `GND`
- Replaces the "short TP_BOOTSEL with tweezers" trick.

### C11, C12, C13 — new decoupling

- Footprint: `Capacitor_SMD:C_0402_1005Metric`, value **100nF**
- C11: VREG_AVDD → GND
- C12: QSPI_IOVDD → GND
- C13: USB_OTP_VDD → GND

---

## 5. Re-annotate, ERC, sync to PCB

1. **Tools → Annotate Schematic Symbols** (reuse existing references).
2. **Tools → Electrical Rules Check** — fix every floating power pin.
3. **Tools → Update PCB from Schematic** (F8) — accept footprint change for U1
   and addition of U8, R6, J_UART, SW1, C11–C13.

---

## 6. PCB layout adjustments

- The new RP2350B footprint (QFN-80 10×10 mm) is bigger than QFN-56. You'll
  need to slightly enlarge the U1 placement area on the PCB.
- 4 vias minimum on the EP to the GND plane (2×2 array; 5×5 ideal).
- U8 (SOT-353) placed close to U1 GP30 and to the card-edge CART_RW pin.
- R6 (0402) placed close to U8 output and to the +5V plane.
- J_UART placed on a free edge of the PCB for cable access. Note that pin
  headers are 2.54 mm pitch — leave clearance for the connector.
- SW1 (PTS810 tactile switch) placed where you can reach it without removing
  the cart from the Vectrex; near the USB-C is a good spot.
- J_SD: the microSD slot opening should face the edge of the cart that
  remains accessible when inserted in the Vectrex (top edge, away from the
  gold fingers). The slot occupies ~12×15 mm. Place C14 within 5 mm of the
  VDD pad.
- Keep SD SCK/MOSI/MISO traces grouped and short (< 50 mm) for clean signals
  at 25 MHz. No length matching needed at this speed.

---

## 7. Verification before fab

- **DRC**: zero errors. QFN silk-on-pad warnings are acceptable.
- **3D viewer**: RP2350B sits flat, EP visible. UART header sticks up.
- **Netlist export**: compare against `COMPONENTS.md` GPIO table.
- **Gerbers**: `File → Fabrication Outputs → Gerbers...` — protel naming for
  JLCPCB/Aisler compatibility.

---

## 8. After fab — first power-on

The current `firmware/` already targets RP2350
(`rp235x-hal`, target `thumbv8m.main-none-eabihf`). Already updated for B
variant pin map (`pins.rs` v2). Flash via BOOTSEL + UF2 the first time.

Expected boot output (USB CDC at 115200):
```
=== Vectrex Debug Cart v1 ===
RP2350B @ 150 MHz  |  4 MB flash  |  8 MB PSRAM  |  FPU
/HALT asserted: 6809 stopped.

PSRAM test... OK (8 MB)
Bus master: available (CART_RW via U8/R6)

Ready. Commands: [r]om-mode  [H]alt  [U]nhalt  [F]lash  [?]help
>
```

UART0 on `J_UART` mirrors the same console at 115200-8-N-1 (firmware
forwards `usb_print` to UART0 too — to be implemented). Useful when USB is
in BOOTSEL mode and you still want to see early-boot logs from an external
probe.
