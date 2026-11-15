#!/usr/bin/env python3
"""
Forgotten Worlds (CPS-1) 68000 Binary Relocator & Hardware Register Patcher
Reads:  assets/cps1_rom/cps1_prog.bin
Writes: assets/cps1_rom/cps1_patched.bin

Performs static binary translation of CPS-1 68000 memory references:
  1. Relocates 32-bit ROM pointers from 0x000000..0x0FFFFF -> 0x020000..0x11FFFF
  2. Remaps CPS-1 Video/Object/Palette RAM (0x00900000..0x00903FFF) -> 0x00FF8000
  3. Logs all CPS-B hardware register accesses (0x00800000..0x008001FF) for bridge hooks
"""

import os
import sys
import struct

RELOC_OFFSET   = 0x00020000  # Relocate CPS-1 Program ROM to 128KB mark in 32X ROM
CPS1_ROM_LIMIT = 0x00100000  # 1MB CPS-1 68000 ROM space
CPS1_VRAM_BASE = 0x00900000
CPS1_VRAM_END  = 0x00904000
GEN_VRAM_STAGE = 0x00FF8000  # Genesis Work RAM staging buffer


def patch_cps1_program(prog_data: bytes) -> bytearray:
    buf = bytearray(prog_data)
    length = len(buf)

    relocated_ptrs = 0
    remapped_vram  = 0
    hw_reg_hits    = {}

    # Scan word-aligned 32-bit immediate operands & pointer tables
    for offset in range(0, length - 3, 2):
        val = struct.unpack_from(">I", buf, offset)[0]

        # 1. Relocate 32-bit Program ROM pointers (skip vector table header < 0x100)
        if offset >= 0x100 and 0x00000100 <= val < CPS1_ROM_LIMIT:
            # Verify preceding opcode is an absolute long jump/call/move/lea (heuristic)
            prev_op = struct.unpack_from(">H", buf, offset - 2)[0]
            is_abs_long_op = (
                (prev_op & 0xFFC0) in (0x4EC0, 0x4E80) or  # JMP (xxx).L / JSR (xxx).L
                (prev_op & 0xF1C0) == 0x41C0 or            # LEA (xxx).L, An
                (prev_op & 0x003F) == 0x0039 or            # xxx (xxx).L source
                (prev_op & 0x0FC0) == 0x0E40               # xxx (xxx).L dest
            )
            if is_abs_long_op:
                struct.pack_into(">I", buf, offset, val + RELOC_OFFSET)
                relocated_ptrs += 1

        # 2. Remap CPS-1 Palette & Object VRAM (0x00900000..0x00903FFF -> 0x00FF8000)
        elif CPS1_VRAM_BASE <= val < CPS1_VRAM_END:
            new_addr = GEN_VRAM_STAGE + (val - CPS1_VRAM_BASE)
            struct.pack_into(">I", buf, offset, new_addr)
            remapped_vram += 1

        # 3. Record CPS-B Hardware Register & Z80 Sound Latch accesses (0x00800000..0x008001FF)
        elif 0x00800000 <= val <= 0x008001FF:
            hw_reg_hits[val] = hw_reg_hits.get(val, 0) + 1

    print(f"[OK] Relocated {relocated_ptrs} absolute 68000 ROM pointers (+0x{RELOC_OFFSET:06X})")
    print(f"[OK] Remapped  {remapped_vram} CPS-1 VRAM accesses -> 0x{GEN_VRAM_STAGE:08X}")
    print("[INFO] Detected CPS-B hardware register references:")
    for reg in sorted(hw_reg_hits):
        print(f"       0x{reg:08X} : {hw_reg_hits[reg]} references")

    return buf


def main():
    in_path  = sys.argv if len(sys.argv) > 1 else "assets/cps1_rom/cps1_prog.bin"
    out_path = "assets/cps1_rom/cps1_patched.bin"

    if not os.path.isfile(in_path):
        print(f"Error: {in_path} not found. Run tools/extract_cps1.py first.")
        sys.exit(1)

    with open(in_path, "rb") as f:
        raw_prog = f.read()

    patched = patch_cps1_program(raw_prog)
    with open(out_path, "wb") as f:
        f.write(patched)

    print(f"\n[DONE] Wrote patched 68000 binary to {out_path} ({len(patched)} bytes)")


if __name__ == "__main__":
    main()