# Debug Cart — KiCad migration RP2040 → RP2350A

The current `.kicad_sch` and `.kicad_pcb` still target **RP2040 QFN-56** even
though `COMPONENTS.md`, `pins.rs` and the firmware all target **RP2350A
QFN-60**. Apply this migration in KiCad 9 GUI before generating Gerbers.

Estimated time: **30–45 minutes**.

---

## 1. Swap the MCU symbol

1. Open `debug_cart.kicad_sch` in KiCad 9.
2. Locate **U1** (current symbol: `MCU_RaspberryPi:RP2040`, footprint
   `Package_DFN_QFN:QFN-56-1EP_7x7mm_P0.4mm_EP3.2x3.2mm`).
3. Double-click U1 → **Edit Symbol Properties** → click the library link icon
   next to the symbol field → choose `MCU_RaspberryPi:RP2350A`.
4. KiCad shows a pin remap dialog because pin counts differ (56 → 60). Use the
   table in §3 below to map each net to its new pin number.
5. Update properties:
   - **Footprint**: `Package_DFN_QFN:QFN-60-1EP_7x7mm_P0.4mm_EP3.4x3.4mm`
     (KiCad 9 stock library — note EP is 3.4×3.4 mm, slightly larger than the
     RP2040's 3.2×3.2 mm).
   - **Value**: `RP2350A`.

---

## 2. Power tree — LDO bypass mode (recommended for v1)

The RP2350A integrates an SMPS that requires an external inductor + Schottky.
For 2 hand-built prototypes we skip the SMPS and run the core regulator in
LDO/bypass mode by tying both LX and FB pins directly to +3V3. This consumes
~50 mA at the core rail instead of ~10 mA but eliminates the inductor and
diode entirely.

Connect the **new** RP2350A power pins (vs RP2040) as follows:

| New RP2350A pin | Connect to | Why |
|---|---|---|
| `VREG_LX` | `+3V3` | LDO bypass — no inductor |
| `VREG_FB` | `+3V3` | LDO bypass — feedback tied high |
| `VREG_AVDD` | `+3V3` via 100 nF | Was `VREG_VIN` on RP2040, renamed |
| `QSPI_IOVDD` | `+3V3` via 100 nF | Dedicated QSPI IO rail (new) |
| `USB_OTP_VDD` | `+3V3` via 100 nF | OTP fuse programming rail (new) |
| Extra `IOVDD` / `DVDD` | `+3V3` | RP2350A has more power pins than RP2040 |

**Delete `C_VREG`** (1 µF was on `VREG_VOUT` of RP2040 — that pin doesn't
exist on RP2350A).

**Add three 100 nF 0402 caps** (C11, C12, C13) for the three new rails above.

---

## 3. Pin mapping table (RP2040 → RP2350A QFN-60)

Update each net connection from the RP2040 pin number to the RP2350A pin
number. The KiCad symbol places these pins automatically, so you mostly need
to verify each net survived the symbol swap. Function ↔ net unchanged.

| Function | Net name (unchanged) | RP2040 pin | RP2350A pin |
|---|---|---|---|
| GPIO0..7 | `CART_A0`..`CART_A7` (via U2) | 2–9 | 2–9 |
| GPIO8..14 | `CART_A8`..`CART_A14` (via U3) | 11–17 | 12–18 |
| GPIO15..22 | `CART_D0`..`CART_D7` (via U4) | 27–34 | 32–41 |
| GPIO23 | `CART_nCE` | 35 | 42 |
| **GPIO24** | **`ABUS_DIR`** (was CART_RW) | 36 | 43 |
| GPIO25 | `CART_nOE` | 37 | 44 |
| GPIO26 | `nNMI` (via Q1) | 38 | 46 |
| GPIO27 | `nHALT` (via Q2) | 39 | 47 |
| GPIO28 | `nRST` (via Q3) | 40 | 48 |
| GPIO29 | `DIR_CTRL` (U4 pin 1) | 41 | 49 |
| XIN | `XTAL_IN` | 20 | 26 |
| XOUT | `XTAL_OUT` | 21 | 27 |
| RUN | `RUN` | 26 | 31 |
| SWCLK | `SWD_CLK` | 24 | 29 |
| SWDIO | `SWD_IO` | 25 | 30 |
| QSPI_SCLK | `QSPI_SCK` | 53 | 56 |
| QSPI_SD0 | `QSPI_SD0` | 54 | 57 |
| QSPI_SD1 | `QSPI_SD1` | 56 | 59 |
| QSPI_SD2 | `QSPI_SD2` | 55 | 58 |
| QSPI_SD3 | `QSPI_SD3` | 52 | 55 |
| ~{QSPI_SS} | `QSPI_CSn` (U7 only) | 51 | 60 |
| USB_DM | `USB_DM` | 47 | 53 |
| USB_DP | `USB_DP` | 48 | 54 |
| TESTEN | `GND` | 19 | n/a (TEST pin on RP2350 → GND) |
| EP pad | `GND` | EP | EP |

> The RP2350A pin numbers above are from the RP2350 datasheet QFN-60 pinout
> diagram (Chapter 2.5). **Cross-check against the symbol you actually use in
> KiCad** — symbol pin numbers must match the footprint pad numbers.

---

## 4. PSRAM CS — important change

`COMPONENTS.md` originally claimed PSRAM CE# was driven by a hardware
`QSPI_SS1` pin on the RP2350. **That pin does not exist** on the KiCad
RP2350A symbol (only one `~{QSPI_SS}` is exposed). PSRAM CS is controlled by
a **GPIO** (net `PSRAM_CS`) with the firmware driving the QMI in direct mode.

If your current schematic already wires U6 (APS6404L) pin 1 to net
`PSRAM_CS`, no change is needed. If it wires to `QSPI_SS1n`, rename the net
to `PSRAM_CS` and connect it to a free GPIO (your current schematic already
allocates this; verify with `grep PSRAM_CS debug_cart.kicad_sch`).

---

## 5. Re-annotate, ERC, sync to PCB

1. **Tools → Annotate Schematic Symbols** (reuse existing references).
2. **Tools → Electrical Rules Check** — fix any "unconnected pin" errors
   (every IOVDD/DVDD must go somewhere; floating power pins are forbidden).
3. **Tools → Update PCB from Schematic** (F8) — KiCad will replace the U1
   footprint and warn about footprint pad count change. Accept.
4. The PCB now has the new QFN-60 footprint over the old QFN-56 placement.
   You'll need to **re-route** all U1 traces.

---

## 6. PCB layout adjustments

- The QFN-60 footprint (7×7 mm with 3.4×3.4 mm EP) is slightly larger than
  QFN-56 (7×7 mm with 3.2×3.2 mm EP). Most pads land in a similar area but
  the corner pads on QFN-60 are 4 more — you'll need to manually verify
  decoupling cap placement still has clearance.
- Add 3 new 0402 caps (C11, C12, C13) close to their respective power pins.
- The thermal EP needs **at least 4 vias** to the GND plane (datasheet
  recommends a 2×2 via array minimum, 5×5 ideal).

---

## 7. Verification before fab

- **DRC**: zero errors, zero warnings except acceptable ones (silk on pads
  for QFN — common).
- **3D viewer**: visually check the RP2350A part sits flat, EP visible.
- **Netlist export**: `File → Export → Netlist → KiCadXML`. Compare against
  `COMPONENTS.md` pin-by-pin (script it if you want).
- **Gerbers**: `File → Fabrication Outputs → Gerbers...` — protel naming for
  JLCPCB compatibility.

---

## 8. After fab — first power-on

The current `firmware/` already targets RP2350 (`rp235x-hal`, target
`thumbv8m.main-none-eabihf`). It built clean in release mode after today's
fixes. Flash via BOOTSEL + UF2 the first time; thereafter you can use
picotool or SWD.

Expected boot output (USB CDC at 115200):
```
=== Vectrex Debug Cart v1 ===
RP2350 @ 150 MHz  |  4 MB flash  |  8 MB PSRAM  |  FPU
/HALT asserted: 6809 stopped.

PSRAM test... OK (8 MB)         ← or FAIL if PSRAM mis-soldered
Bus master: NOT available (PCB v1 - DIR pins fixed)
ROM emulation mode only.

Ready. Commands: [r]om-mode  [H]alt  [U]nhalt  [F]lash  [?]help
>
```

The `Bus master: NOT available` line will stay even on v1 because v1 has no
R/W drive to the Vectrex (we removed R7/R8). Bus master writes need a v2 with
an inverter on `CART_RW` driven from `GP29`/`DIR_CTRL` — see §6 of
`FIRMWARE_PLAN.md`. Bus master *reads* would work on v1 but the firmware
guard is conservative until v2.
