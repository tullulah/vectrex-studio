#!/usr/bin/env python3
"""Disassemble Read_Btns ($F1BA) from the Vectrex BIOS binary."""
import sys, os

BIOS_PATH = 'ide/frontend/src/assets/bios.bin'
BASE = 0xE000

bios = open(BIOS_PATH, 'rb').read()

def rb(a): return bios[a - BASE]
def rw(a): return (bios[a - BASE] << 8) | bios[a - BASE + 1]

def idx(pb):
    r = ['X','Y','U','S'][(pb >> 5) & 3]
    if pb & 0x80 == 0:
        off = pb & 0x1F
        if off & 0x10: off -= 0x20
        return f'{off},{r}'
    sub = pb & 0x1F
    if sub == 0x04: return f',{r}'
    if sub == 0x00: return f',{r}+'
    if sub == 0x01: return f',{r}++'
    if sub == 0x02: return f',-{r}'
    if sub == 0x03: return f',--{r}'
    if sub == 0x08: return 'n,r (8-bit)'
    if sub == 0x09: return 'n,r (16-bit)'
    return f'?idx({pb:02X})'

def dis(start, n=50):
    a = start
    for _ in range(n):
        op = rb(a)
        s = f'  {a:04X}: '
        if op == 0x8E:
            v = rw(a+1); print(s + f'LDX  #{v:04X}'); a += 3
        elif op == 0xA6:
            pb = rb(a+1); print(s + f'LDA  {idx(pb)}'); a += 2
        elif op == 0xA7:
            pb = rb(a+1); print(s + f'STA  {idx(pb)}'); a += 2
        elif op == 0x86:
            print(s + f'LDA  #{rb(a+1):02X}'); a += 2
        elif op == 0x97:
            v = rb(a+1); print(s + f'STA  <${v:02X}  ; [${0xD000+v:04X}]'); a += 2
        elif op == 0xCC:
            v = rw(a+1); print(s + f'LDD  #{v:04X}'); a += 3
        elif op == 0x12:
            print(s + 'NOP'); a += 1
        elif op == 0xD7:
            v = rb(a+1); print(s + f'STB  <${v:02X}  ; [${0xD000+v:04X}]'); a += 2
        elif op == 0x0F:
            v = rb(a+1); print(s + f'CLR  <${v:02X}  ; [${0xD000+v:04X}]'); a += 2
        elif op == 0x96:
            v = rb(a+1); print(s + f'LDA  <${v:02X}  ; [${0xD000+v:04X}]'); a += 2
        elif op == 0x43:
            print(s + 'COMA'); a += 1
        elif op == 0xA4:
            pb = rb(a+1); print(s + f'ANDA {idx(pb)}'); a += 2
        elif op == 0xAA:
            pb = rb(a+1); print(s + f'ORA  {idx(pb)}'); a += 2
        elif op == 0xA8:
            pb = rb(a+1); print(s + f'EORA {idx(pb)}'); a += 2
        elif op == 0xA3:
            pb = rb(a+1); print(s + f'SUBD {idx(pb)}'); a += 2
        elif op == 0x39:
            print(s + 'RTS'); break
        elif op == 0x34:
            v = rb(a+1); print(s + f'PSHS #{v:02X}'); a += 2
        elif op == 0x35:
            v = rb(a+1); print(s + f'PULS #{v:02X}'); a += 2
        elif op == 0x30:
            pb = rb(a+1)
            r = ['X','Y','U','S'][(pb >> 5) & 3]
            off = pb & 0x1F
            if off & 0x10: off -= 0x20
            print(s + f'LEAX {off},{r}'); a += 2
        elif op == 0x49:
            print(s + 'ROLA'); a += 1
        elif op == 0x48:
            print(s + 'LSLA/ASLA'); a += 1
        elif op == 0x84:
            print(s + f'ANDA #{rb(a+1):02X}'); a += 2
        elif op == 0x8A:
            print(s + f'ORA  #{rb(a+1):02X}'); a += 2
        elif op == 0x88:
            print(s + f'EORA #{rb(a+1):02X}'); a += 2
        elif op == 0xA4:
            pb = rb(a+1); print(s + f'ANDA {idx(pb)}'); a += 2
        elif op == 0xA1:
            pb = rb(a+1); print(s + f'CMPA {idx(pb)}'); a += 2
        elif op == 0x9A:
            v = rb(a+1); print(s + f'ORA  <${v:02X}  ; [${0xC800+v:04X}] (DP=C8)'); a += 2
        elif op == 0x94:
            v = rb(a+1); print(s + f'ANDA <${v:02X}  ; [${0xD000+v:04X}]'); a += 2
        elif op == 0x98:
            v = rb(a+1); print(s + f'EORA <${v:02X}  ; [${0xC800+v:04X}] (DP=C8)'); a += 2
        else:
            print(s + f'??? {op:02X}'); a += 1

print('=== Read_Btns ($F1BA), called with DP=$D0 ===')
dis(0xF1BA, 40)
