#!/usr/bin/env python3
"""
Forgotten Worlds (CPS-1) 68000 Binary Relocator & Hardware Register Patcher
Reads:  assets/cps1_rom/cps1_prog.bin
Writes: assets/cps1_rom/cps1_patched.bin
"""

import os
import sys
import struct

RELOC_OFFSET     = 0x00020000
CPS1_ROM_LIMIT   = 0x00100000

CPS1_VRAM_BASE   = 0x00900000
CPS1_VRAM_END    = 0x00940000
GEN_VRAM_STAGE   = 0x00FF8000
GEN_VRAM_MASK    = 0x00003FFF

CPS1_REG_BASE    = 0x00800100
CPS1_REG_END     = 0x00800124
GEN_REG_SHADOW   = 0x00FFBF00

CPS1_WRAM_BASE   = 0x00FF0000
CPS1_WRAM_END    = 0x01000000
GEN_CPS1_WRAM    = 0x00FF0000
GEN_WRAM_MASK    = 0x00007FFF

BRIDGE_READ_P1   = 0x00000800
BRIDGE_READ_P2   = 0x00000806
BRIDGE_DIAL_P1   = 0x0000080C
BRIDGE_DIAL_P2   = 0x00000812
BRIDGE_SND_LATCH = 0x00000818


def is_long_addr_opcode(op: int) -> bool:
    if (op & 0xFFC0) in (0x4EC0, 0x4E80):
        return True
    if (op & 0xF1C0) == 0x41C0:
        return True
    if (op & 0xFFC0) == 0x4879:
        return True
    if (op & 0x003F) == 0x0039:
        return True
    if (op & 0x0FC0) == 0x0E40:
        return True
    return False
def patch_cps1_program(prog_data: bytes) -> bytearray:
    buf = bytearray(prog_data)
    length = len(buf)
    relocated_ptrs = remapped_vram = remapped_regs = remapped_wram = patched_io = 0

    if length >= 8:
        init_sp, init_pc = struct.unpack_from(">II", buf, 0)
        if CPS1_WRAM_BASE <= init_sp <= CPS1_WRAM_END:
            struct.pack_into(">I", buf, 0, GEN_CPS1_WRAM + ((init_sp - 2) & GEN_WRAM_MASK))
        if 0x00000008 <= init_pc < CPS1_ROM_LIMIT:
            struct.pack_into(">I", buf, 4, init_pc + RELOC_OFFSET)

    io_read_map = {
        0x00800000: BRIDGE_READ_P1, 0x00800001: BRIDGE_READ_P1,
        0x00800018: BRIDGE_READ_P2, 0x00800019: BRIDGE_READ_P2,
        0x00800052: BRIDGE_DIAL_P1, 0x00800053: BRIDGE_DIAL_P1,
        0x00800054: BRIDGE_DIAL_P2, 0x00800055: BRIDGE_DIAL_P2,
    }

    for offset in range(0x100, length - 5, 2):
        op = struct.unpack_from(">H", buf, offset)[0]
        addr = struct.unpack_from(">I", buf, offset + 2)[0]
        if op == 0x1039 and addr in io_read_map:
            struct.pack_into(">HI", buf, offset, 0x4EB9, io_read_map[addr])
            patched_io += 1
        elif op == 0x13C0 and addr == 0x00800180:
            struct.pack_into(">HI", buf, offset, 0x4EB9, BRIDGE_SND_LATCH)
            patched_io += 1

    for offset in range(0x100, length - 3, 2):
        val = struct.unpack_from(">I", buf, offset)[0]
        prev_op = struct.unpack_from(">H", buf, offset - 2)[0]
        if prev_op == 0x4EB9 and BRIDGE_READ_P1 <= val <= BRIDGE_SND_LATCH:
            continue

        if 0x00000100 <= val < CPS1_ROM_LIMIT and (val & 1) == 0:
            in_ptr_table = (offset >= 0x104) and (
                RELOC_OFFSET + 0x100 <= struct.unpack_from(">I", buf, offset - 4)[0] < RELOC_OFFSET + CPS1_ROM_LIMIT
            )
            if is_long_addr_opcode(prev_op) or in_ptr_table:
                struct.pack_into(">I", buf, offset, val + RELOC_OFFSET)
                relocated_ptrs += 1
        elif CPS1_VRAM_BASE <= val < CPS1_VRAM_END:
            struct.pack_into(">I", buf, offset, GEN_VRAM_STAGE + ((val - CPS1_VRAM_BASE) & GEN_VRAM_MASK))
            remapped_vram += 1
        elif CPS1_REG_BASE <= val < CPS1_REG_END:
            struct.pack_into(">I", buf, offset, GEN_REG_SHADOW + (val - CPS1_REG_BASE))
            remapped_regs += 1
        elif (CPS1_WRAM_BASE + 0x8000) <= val < CPS1_WRAM_END and is_long_addr_opcode(prev_op):
            struct.pack_into(">I", buf, offset, GEN_CPS1_WRAM + ((val - CPS1_WRAM_BASE) & GEN_WRAM_MASK))
            remapped_wram += 1

    print(f"[OK] Patched={patched_io}, Reloc={relocated_ptrs}, VRAM={remapped_vram}, Regs={remapped_regs}, WRAM={remapped_wram}")
    return buf


def main():
    in_path = sys.argv[1] if len(sys.argv) > 1 else "assets/cps1_rom/cps1_prog.bin"
    out_path = "assets/cps1_rom/cps1_patched.bin"
    if not os.path.isfile(in_path):
        print(f"Error: {in_path} not found.")
        sys.exit(1)
    patched = patch_cps1_program(open(in_path, "rb").read())
    open(out_path, "wb").write(patched)
    print(f"[DONE] Wrote {out_path} ({len(patched)} bytes)")


if __name__ == "__main__":
    main()
