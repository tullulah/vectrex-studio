#!/usr/bin/env python3
"""uvm2_fault.py -- read the witness a VPy game (uvm2, C backend) leaves on the SD card when
it HardFaults: VPYFAULT.TXT (registers) and VPYRAM.BIN (all of SRAM), against the game's ELF
(build/<game>.elf, copied next to the .um2 by every uvm2 build).

    python3 tools/uvm2_fault.py <game.elf> <VPYFAULT.TXT> [VPYRAM.BIN] [--vars]

Prints where it faulted (function, file:line, inlined callers), why (CFSR/HFSR decoded), the
call chain read off the stack in the dump, and with --vars the game's globals (G_* symbols).
Needs arm-none-eabi-addr2line / -nm on the PATH.
"""
import re
import struct
import subprocess
import sys

SRAM = 0x20000000
STACK_TOP = {0: 0x20082000, 1: 0x20081000}      # pico-sdk: core 0 in SCRATCH_Y, core 1 below it
STACK_BOTTOM = {0: 0x20081000, 1: 0x20080000}

CFSR_BITS = {
    0: "IACCVIOL: instruction fetch from a forbidden address",
    1: "DACCVIOL: data access to a forbidden address (MMFAR)",
    3: "MUNSTKERR: unstacking on exception return",
    4: "MSTKERR: stacking on exception entry (stack overflow?)",
    5: "MLSPERR: lazy FP state",
    7: "MMARVALID: MMFAR holds the address",
    8: "IBUSERR: instruction bus error",
    9: "PRECISERR: data bus error at BFAR (precise)",
    10: "IMPRECISERR: data bus error (imprecise: the pc is after the store)",
    11: "UNSTKERR: bus error unstacking",
    12: "STKERR: bus error stacking (stack overflow?)",
    13: "LSPERR: bus error, lazy FP",
    15: "BFARVALID: BFAR holds the address",
    16: "UNDEFINSTR: undefined instruction (jumped into data?)",
    17: "INVSTATE: Thumb bit clear (a call through a bad function pointer?)",
    18: "INVPC: bad EXC_RETURN",
    19: "NOCP: coprocessor (FPU) access while disabled",
    20: "STKOF: stack limit (MSPLIM) crossed: stack overflow",
    24: "UNALIGNED: unaligned access",
    25: "DIVBYZERO: division by zero",
}
HFSR_BITS = {1: "VECTTBL: vector table read", 30: "FORCED: a configurable fault escalated", 31: "DEBUGEVT"}


def tool(name, *args):
    return subprocess.run([f"arm-none-eabi-{name}", *args], capture_output=True, text=True, check=True).stdout


def where(elf, addr):
    out = tool("addr2line", "-f", "-i", "-C", "-p", "-e", elf, hex(addr)).strip()
    return out.replace("\n", "\n        ")


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if len(args) < 2:
        sys.exit(__doc__)
    elf, txt = args[0], args[1]
    ram = open(args[2], "rb").read() if len(args) > 2 else None
    lines = open(txt, errors="replace").read().splitlines()
    regs = {}
    for ln in lines:
        m = re.match(r"(\w+)=0x([0-9a-fA-F]+)$", ln.strip())
        if m:
            regs[m.group(1)] = int(m.group(2), 16)
    print("\n".join(l for l in lines[:2]))
    build = next((l for l in lines if l.startswith("build=")), None)
    if build and build.encode() not in open(elf, "rb").read():
        print(f"!! {elf} is NOT the build that faulted ({build}): the addresses below mean nothing")
    syms, data = {}, set()
    for ln in tool("nm", "-S", elf).splitlines():
        p = ln.split()
        if len(p) == 4:
            syms[p[3]] = (int(p[0], 16), int(p[1], 16))
            if p[2] in "BbDd":
                data.add(p[3])
    if "handler" in regs and "vpyf_hardfault" in syms and (regs["handler"] & ~1) != syms["vpyf_hardfault"][0]:
        print("!! the handler's address differs from this ELF's: wrong ELF")
    core = regs.get("core", 0)
    print(f"\ncore {core}, frame {regs.get('frame', 0)}")
    print(f"pc  0x{regs['pc']:08x}  {where(elf, regs['pc'])}")
    print(f"lr  0x{regs['lr']:08x}  {where(elf, regs['lr'] & ~1)}")
    sp = regs.get("sp", 0)
    print(f"sp  0x{sp:08x}", end="")
    if core in STACK_BOTTOM and sp < STACK_BOTTOM[core]:
        print(f"   !! BELOW core {core}'s stack (0x{STACK_BOTTOM[core]:08x}): stack overflow", end="")
    print()
    print("     " + "  ".join(f"r{i}=0x{regs.get(f'r{i}', 0):08x}" for i in range(0, 13)))
    cfsr, hfsr = regs.get("cfsr", 0), regs.get("hfsr", 0)
    print(f"\ncfsr 0x{cfsr:08x}  hfsr 0x{hfsr:08x}  mmfar 0x{regs.get('mmfar', 0):08x}  bfar 0x{regs.get('bfar', 0):08x}"
          f"  sfsr 0x{regs.get('sfsr', 0):08x}  sfar 0x{regs.get('sfar', 0):08x}")
    for b, why in CFSR_BITS.items():
        if cfsr >> b & 1:
            print("  " + why)
    for b, why in HFSR_BITS.items():
        if hfsr >> b & 1:
            print("  " + why)
    if regs.get("sfsr", 0):
        print("  SecureFault status set (SFSR): see SFAR")

    if ram is None:
        return
    word = lambda a: struct.unpack_from("<I", ram, a - SRAM)[0] if SRAM <= a < SRAM + len(ram) - 3 else None
    text = syms.get("__etext", (None,))[0] or max(a for a, _ in syms.values() if a < 0x20060000)
    # the call chain: return addresses on the stack (odd, in the code, right after a BL/BLX)
    print(f"\nthe stack, 0x{sp:08x} up (return addresses after a call):")
    top = STACK_TOP.get(core, sp + 0x1000)
    seen = 0
    for a in range(sp & ~3, top, 4):
        v = word(a)
        if v is None or not (v & 1) or not (SRAM <= v < text):
            continue
        ret = v & ~1
        h1, h2 = word(ret - 4), word(ret - 2)
        is_bl = h1 is not None and (h1 & 0xD000F800) == 0xD000F000          # 32-bit BL
        is_blx = h2 is not None and (h2 >> 16 & 0xFF87) == 0x4780           # 16-bit BLX rm
        if not (is_bl or is_blx):
            continue
        print(f"  [0x{a:08x}] 0x{v:08x}  {where(elf, ret - 2)}")
        seen += 1
        if seen >= 24:
            break
    if "--vars" in sys.argv:
        print("\nthe game's variables:")
        for name, (addr, size) in sorted(syms.items(), key=lambda kv: kv[1][0]):
            if not name.startswith("G_") or name not in data or word(addr) is None:
                continue
            if size == 4:
                v = word(addr)
                print(f"  {name[2:]:32} {v if v < 0x80000000 else v - (1 << 32)}")
            elif size <= 64:
                vals = [word(addr + 4 * i) for i in range(size // 4)]
                print(f"  {name[2:]:32} {[x if x < 0x80000000 else x - (1 << 32) for x in vals]}")


if __name__ == "__main__":
    main()
