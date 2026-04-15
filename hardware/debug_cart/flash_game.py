#!/usr/bin/env python3
"""
flash_game.py — Upload a game ROM to the Vectrex Debug Cart over USB CDC.

Usage:
    python flash_game.py <game.bin> [--port /dev/ttyACM0]

The script auto-detects the debug cart port if --port is omitted.
Requires: pyserial  (pip install pyserial)
"""

import argparse
import struct
import sys
import time
import serial
import serial.tools.list_ports

GAME_ROM_MAX = 32 * 1024  # 32KB
BAUD = 115200
TIMEOUT = 30  # seconds to wait for flash + reset


def find_port() -> str:
    """Auto-detect the debug cart by USB VID:PID (0x2E8A:0x000A = Pico CDC)."""
    for p in serial.tools.list_ports.comports():
        if p.vid == 0x2E8A and p.pid == 0x000A:
            return p.device
    # Fallback: first available serial port
    ports = [p.device for p in serial.tools.list_ports.comports()]
    if ports:
        return ports[0]
    raise RuntimeError("No serial port found. Connect the debug cart and try again.")


def flash(port: str, rom_path: str) -> None:
    with open(rom_path, "rb") as f:
        data = f.read()

    if len(data) > GAME_ROM_MAX:
        print(f"ERROR: ROM too large ({len(data)} bytes, max {GAME_ROM_MAX})")
        sys.exit(1)

    print(f"ROM: {rom_path}  ({len(data)} bytes)")
    print(f"Port: {port}")

    with serial.Serial(port, BAUD, timeout=5) as s:
        # Drain any pending output
        time.sleep(0.1)
        s.reset_input_buffer()

        # Send 'F' command
        print("Sending flash command...", end=" ", flush=True)
        s.write(b"F")

        # Wait for "SEND SIZE"
        resp = s.read_until(b"\n").decode(errors="replace").strip()
        if "SEND SIZE" not in resp:
            print(f"\nERROR: unexpected response: {resp!r}")
            sys.exit(1)
        print("OK")

        # Send 4-byte little-endian size
        s.write(struct.pack("<I", len(data)))

        # Wait for "SEND DATA"
        resp = s.read_until(b"\n").decode(errors="replace").strip()
        if "SEND DATA" not in resp:
            print(f"ERROR: unexpected response: {resp!r}")
            sys.exit(1)

        # Send binary data with progress bar
        print("Uploading: ", end="", flush=True)
        chunk_size = 256
        sent = 0
        while sent < len(data):
            chunk = data[sent:sent + chunk_size]
            s.write(chunk)
            sent += len(chunk)
            pct = sent * 100 // len(data)
            print(f"\rUploading: {pct:3d}%  ({sent}/{len(data)} bytes)", end="", flush=True)
        print()

        # Wait for "OK" or "ERR"
        print("Flashing...", end=" ", flush=True)
        s.timeout = TIMEOUT
        resp = s.read_until(b"\n").decode(errors="replace").strip()

        if resp.startswith("OK"):
            print("Done! Cart is resetting.")
        else:
            print(f"\nERROR: {resp}")
            sys.exit(1)


def main() -> None:
    parser = argparse.ArgumentParser(description="Flash game ROM to Vectrex Debug Cart")
    parser.add_argument("rom", help="Game ROM binary (.bin)")
    parser.add_argument("--port", help="Serial port (auto-detected if omitted)")
    args = parser.parse_args()

    port = args.port or find_port()
    flash(port, args.rom)


if __name__ == "__main__":
    main()
