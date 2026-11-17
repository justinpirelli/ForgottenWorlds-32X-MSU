#!/usr/bin/env python3
"""
Forgotten Worlds (CPS-1) Asset & ROM Extractor for Sega 32X + Sega CD Mode 1
Converts a user-supplied MAME 'forgottn.zip' archive into linear 32X assets:
  1. assets/cps1_rom/cps1_prog.bin - Byte-interleaved 68000 arcade program ROM
  2. assets/gfx/cps1_tiles.bin     - 4-way interleaved linear 8-bit 16x16 tiles
  3. assets/sfx/cps1_pcm.bin       - 128-entry PWM_SampleAsset table + 8-bit PCM
"""

import os
import sys
import zipfile
import struct

OKI_INDEX_TABLE = [-1, -1, -1, -1, 2, 4, 6, 8, -1, -1, -1, -1, 2, 4, 6, 8]
OKI_STEP_TABLE = [
    16, 17, 19, 21, 23, 25, 28, 31, 34, 37, 41, 45, 50, 55, 60, 66,
    73, 80, 88, 97, 107, 118, 130, 143, 157, 173, 190, 209, 230, 253, 279, 307,
    337, 371, 408, 449, 494, 544, 598, 658, 724, 796, 876, 963, 1060, 1166, 1282, 1411,
    1552
]

CART_SFX_BASE_ADDR = 0x22300000
MAX_OKI_PHRASES    = 128
HEADER_TABLE_BYTES = MAX_OKI_PHRASES * 12  # 128 * sizeof(PWM_SampleAsset) = 1536 bytes


def interleave_even_odd(even_bytes: bytes, odd_bytes: bytes) -> bytes:
    size = min(len(even_bytes), len(odd_bytes))
    out = bytearray(size * 2)
    out[0::2] = even_bytes[:size]
    out[1::2] = odd_bytes[:size]
    return bytes(out)


def interleave_4way(rom0: bytes, rom1: bytes, rom2: bytes, rom3: bytes) -> bytes:
    size = min(len(rom0), len(rom1), len(rom2), len(rom3))
    out = bytearray(size * 4)
    out[0::4] = rom0[:size]
    out[1::4] = rom1[:size]
    out[2::4] = rom2[:size]
    out[3::4] = rom3[:size]
    return bytes(out)


def decode_oki_phrase(adpcm_bytes: bytes) -> bytes:
    predictor = 0
    step_index = 0
    out = bytearray(len(adpcm_bytes) * 2)
    idx = 0

    for byte in adpcm_bytes:
        for nibble in ((byte >> 4) & 0x0F, byte & 0x0F):
            step = OKI_STEP_TABLE[step_index]
            diff = step >> 3
            if nibble & 1:
                diff += step >> 2
            if nibble & 2:
                diff += step >> 1
            if nibble & 4:
                diff += step
            predictor = predictor - diff if (nibble & 8) else predictor + diff
            predictor = max(-2048, min(2047, predictor))
            out[idx] = (predictor >> 4) & 0xFF
            idx += 1
            step_index = max(0, min(48, step_index + OKI_INDEX_TABLE[nibble]))

    return bytes(out)
def build_sfx_bank(oki_rom: bytes) -> bytes:
    table_buf = bytearray(HEADER_TABLE_BYTES)
    pcm_blob = bytearray()
    valid_phrases = 0

    for phrase_id in range(MAX_OKI_PHRASES):
        entry_off = phrase_id * 8
        if entry_off + 6 > len(oki_rom):
            break

        start_addr = ((oki_rom[entry_off] << 16) | (oki_rom[entry_off + 1] << 8) | oki_rom[entry_off + 2]) & 0x03FFFF
        end_addr = ((oki_rom[entry_off + 3] << 16) | (oki_rom[entry_off + 4] << 8) | oki_rom[entry_off + 5]) & 0x03FFFF

        if start_addr < 0x400 or end_addr <= start_addr or end_addr > len(oki_rom):
            continue

        decoded = decode_oki_phrase(oki_rom[start_addr:end_addr])
        sh2_ptr = CART_SFX_BASE_ADDR + HEADER_TABLE_BYTES + len(pcm_blob)
        struct.pack_into(">IIBBH", table_buf, phrase_id * 12, sh2_ptr, len(decoded), 0, 0, 0)
        pcm_blob.extend(decoded)
        while len(pcm_blob) & 3:
            pcm_blob.append(0)
        valid_phrases += 1

    print(f"[OK] Decoded {valid_phrases} OKI MSM6295 voice/SFX phrases")
    return bytes(table_buf) + bytes(pcm_blob)


def decode_cps1_gfx_to_linear(gfx_data: bytes) -> bytes:
    num_tiles = len(gfx_data) // 128
    linear_out = bytearray(num_tiles * 256)

    for tile in range(num_tiles):
        base_in, base_out = tile * 128, tile * 256
        for row in range(16):
            row_offset = base_in + (row * 8)
            for half in range(2):
                p0, p1, p2, p3 = gfx_data[row_offset + (half * 4):row_offset + (half * 4) + 4]
                for bit in range(8):
                    shift = 7 - bit
                    pixel = (
                        (((p0 >> shift) & 1) << 0) | (((p1 >> shift) & 1) << 1) |
                        (((p2 >> shift) & 1) << 2) | (((p3 >> shift) & 1) << 3)
                    )
                    linear_out[base_out + (row * 16) + (half * 8) + bit] = pixel
    return bytes(linear_out)


def find_rom(files_by_lower: dict, *prefixes: str) -> bytes:
    for name, data in files_by_lower.items():
        if any(os.path.basename(name).startswith(p) for p in prefixes):
            return data
    return b""


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 tools/extract_cps1.py <path/to/forgottn.zip>")
        sys.exit(1)

    zip_path = sys.argv[1]
    if not os.path.isfile(zip_path):
        print(f"Error: File not found: {zip_path}")
        sys.exit(1)

    os.makedirs("assets/cps1_rom", exist_ok=True)
    os.makedirs("assets/gfx", exist_ok=True)
    os.makedirs("assets/sfx", exist_ok=True)

    with zipfile.ZipFile(zip_path, "r") as zf:
        files = {name.lower(): zf.read(name) for name in sorted(zf.namelist())}

        pairs = [
            (find_rom(files, "lw_36", "lw-36", "fwe_36", "fwu_36"), find_rom(files, "lw_31", "lw-31", "fwe_31", "fwu_31")),
            (find_rom(files, "lw_35", "lw-35", "fwe_35", "fwu_35"), find_rom(files, "lw_30", "lw-30", "fwe_30", "fwu_30")),
            (find_rom(files, "lw_37", "lw-37", "fwe_37", "fwu_37"), find_rom(files, "lw_32", "lw-32", "fwe_32", "fwu_32")),
        ]
        prog_bin = bytearray()
        for ev, od in pairs:
            if ev and od:
                prog_bin.extend(interleave_even_odd(ev, od))
        if prog_bin:
            open("assets/cps1_rom/cps1_prog.bin", "wb").write(prog_bin)

        g0, g1, g2, g3 = find_rom(files, "lw-01", "lw_01"), find_rom(files, "lw-02", "lw_02"), find_rom(files, "lw-03", "lw_03"), find_rom(files, "lw-04", "lw_04")
        if g0 and g1 and g2 and g3:
            open("assets/gfx/cps1_tiles.bin", "wb").write(decode_cps1_gfx_to_linear(interleave_4way(g0, g1, g2, g3)))

        oki0, oki1 = find_rom(files, "lw-18", "lw_18"), find_rom(files, "lw-19", "lw_19")
        if oki0:
            open("assets/sfx/cps1_pcm.bin", "wb").write(build_sfx_bank(oki0 + oki1))

    print("[DONE] Asset extraction complete!")


if __name__ == "__main__":
    main()
