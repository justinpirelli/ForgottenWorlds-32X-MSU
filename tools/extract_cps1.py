#!/usr/bin/env python3
"""
Forgotten Worlds (CPS-1) Asset & ROM Extractor for Sega 32X + Sega CD Mode 1
Converts a user-supplied MAME 'forgottn.zip' archive into linear 32X assets:
  1. assets/cps1_rom/cps1_prog.bin  - Interleaved 68000 arcade program ROM
  2. assets/gfx/cps1_tiles.bin      - Linear 8-bit indexed 16x16 tiles/sprites
  3. assets/sfx/cps1_pcm.bin        - Decoded 8-bit signed PCM voice/SFX bank
"""

import os
import sys
import zipfile
import struct

# Standard OKI MSM6295 / Dialogic 4-bit ADPCM Step Size & Index Tables
OKI_INDEX_TABLE = [-1, -1, -1, -1, 2, 4, 6, 8, -1, -1, -1, -1, 2, 4, 6, 8]
OKI_STEP_TABLE = [
    16, 17, 19, 21, 23, 25, 28, 31, 34, 37, 41, 45, 50, 55, 60, 66,
    73, 80, 88, 97, 107, 118, 130, 143, 157, 173, 190, 209, 230, 253, 279, 307,
    337, 371, 408, 449, 494, 544, 598, 658, 724, 796, 876, 963, 1060, 1166, 1282, 1411,
    1552
]


def decode_oki_adpcm(adpcm_bytes: bytes) -> bytes:
    """Decode OKI MSM6295 4-bit ADPCM data into 8-bit signed PCM for 32X PWM."""
    predictor = 0
    step_index = 0
    out = bytearray()

    for byte in adpcm_bytes:
        # High nibble first, then low nibble on MSM6295
        for nibble in ((byte >> 4) & 0x0F, byte & 0x0F):
            step = OKI_STEP_TABLE[step_index]
            diff = step >> 3
            if nibble & 1:
                diff += step >> 2
            if nibble & 2:
                diff += step >> 1
            if nibble & 4:
                diff += step

            if nibble & 8:
                predictor -= diff
            else:
                predictor += diff

            # Clamp 12-bit OKI range (-2048..2047) and scale to 8-bit signed (-128..127)
            predictor = max(-2048, min(2047, predictor))
            out.append((predictor >> 4) & 0xFF)

            step_index = max(0, min(48, step_index + OKI_INDEX_TABLE[nibble]))

    return bytes(out)


def decode_cps1_gfx_to_linear(gfx_data: bytes) -> bytes:
    """
    Convert CPS-1 4bpp interleaved planar GFX ROM data into 1-byte-per-pixel
    linear 16x16 tiles (256 bytes per tile) for fast SH-2 blitting.
    """
    num_tiles = len(gfx_data) // 128  # Each 16x16 4bpp CPS-1 tile = 128 bytes
    linear_out = bytearray(num_tiles * 256)

    for tile in range(num_tiles):
        base_in = tile * 128
        base_out = tile * 256

        for row in range(16):
            # Left 8 pixels (bytes 0..3) and Right 8 pixels (bytes 4..7) per row
            row_offset = base_in + (row * 8)
            for half in range(2):
                p0 = gfx_data[row_offset + (half * 4) + 0]
                p1 = gfx_data[row_offset + (half * 4) + 1]
                p2 = gfx_data[row_offset + (half * 4) + 2]
                p3 = gfx_data[row_offset + (half * 4) + 3]

                for bit in range(8):
                    shift = 7 - bit
                    pixel = (
                        (((p0 >> shift) & 1) << 0) |
                        (((p1 >> shift) & 1) << 1) |
                        (((p2 >> shift) & 1) << 2) |
                        (((p3 >> shift) & 1) << 3)
                    )
                    dst_x = (half * 8) + bit
                    linear_out[base_out + (row * 16) + dst_x] = pixel

    return bytes(linear_out)


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
        names = sorted(zf.namelist())
        print(f"Opened {zip_path} ({len(names)} ROM files found)")

        # Collect 68000 program ROMs, GFX ROMs, and OKI ADPCM sample ROMs
        prog_chunks = []
        gfx_chunks = []
        oki_chunks = []

        for name in names:
            lower = name.lower()
            data = zf.read(name)
            # Forgotten Worlds (lw / fw CPS-1 naming conventions)
            if any(tag in lower for tag in ("lw_29", "lw_30", "lw_31", "lw_35", "lw_36", "lw_37", "fwe_", "fwu_")):
                prog_chunks.append((name, data))
            elif any(tag in lower for tag in ("lw-01", "lw-02", "lw-03", "lw-04", "lw_01", "lw_02", "lw_03", "lw_04")):
                gfx_chunks.append((name, data))
            elif any(tag in lower for tag in ("lw_18", "lw_19", "lw-18", "lw-19")):
                oki_chunks.append((name, data))

        if prog_chunks:
            prog_bin = b"".join(chunk for _, chunk in prog_chunks)
            with open("assets/cps1_rom/cps1_prog.bin", "wb") as f:
                f.write(prog_bin)
            print(f"[OK] Wrote assets/cps1_rom/cps1_prog.bin ({len(prog_bin)} bytes)")

        if gfx_chunks:
            raw_gfx = b"".join(chunk for _, chunk in gfx_chunks)
            linear_gfx = decode_cps1_gfx_to_linear(raw_gfx)
            with open("assets/gfx/cps1_tiles.bin", "wb") as f:
                f.write(linear_gfx)
            print(f"[OK] Wrote assets/gfx/cps1_tiles.bin ({len(linear_gfx)} bytes, {len(linear_gfx)//256} tiles)")

        if oki_chunks:
            raw_oki = b"".join(chunk for _, chunk in oki_chunks)
            pcm_audio = decode_oki_adpcm(raw_oki)
            with open("assets/sfx/cps1_pcm.bin", "wb") as f:
                f.write(pcm_audio)
            print(f"[OK] Wrote assets/sfx/cps1_pcm.bin ({len(pcm_audio)} bytes 8-bit PCM)")

    print("\nAsset extraction complete! Ready to link with USE_CPS1_ARCADE_ROM=1.")


if __name__ == "__main__":
    main()