# CPS-1 Arcade to Sega 32X + Sega CD Porting & Register Map

This document maps the original Capcom CPS-1 arcade hardware addresses used by *Forgotten Worlds* (`forgottn.zip`) to the shared 32X SDRAM mailboxes implemented in this repository.

## 1. Memory Map Translation (CPS-1 68000 → Genesis / 32X 68000)

| Subsystem | CPS-1 Arcade Address | Tower of Power Target | Notes |
| :--- | :--- | :--- | :--- |
| **Program ROM** | `0x000000 – 0x0FFFFF` | `0x010000 – 0x10FFFF` | Relocated above 32X boot/driver code (`64KB` offset) |
| **Main Work RAM** | `0xFF0000 – 0xFFFFFF` | `0xFF0000 – 0xFFFFFF` | **1:1 Native Match** (64KB Genesis Work RAM) |
| **Object / Sprite RAM** | `0x900000 – 0x9007FF` | `0x22000400` (32X SDRAM) | Converted into `CPS1_Sprite` structs for Slave SH-2 |
| **Palette RAM (12-bit RGB)** | `0x902000 – 0x902FFF` | `0x22000000` (32X SDRAM) | Synced to 32X CRAM via `cps1_update_palette()` |
| **Scroll 1/2/3 Tilemaps** | `0x904000 – 0x90FFFF` | `0x22010000+` (32X SDRAM) | Read directly by `cps1_scroll.c` on Master SH-2 |
| **CPS-B Scroll Registers** | `0x800100 – 0x80013F` | `CPS1_ScrollLayer` structs | Scroll X/Y & Row Scroll pointers |
| **Z80 Sound Latch** | `0x800180` (Byte write) | `cps1_sound_write(val)` | Routes BGM (`0x01–0x1F`) to Sega CD Mode 1 & SFX (`0x20+`) to 32X PWM |

## 2. Controller & Rotational Dial Mapping

In the arcade, *Forgotten Worlds* used an 8-way joystick plus a rotary dial ("Rolling Switch") to aim the player's satellite pod 360 degrees. In `src_68k/main_68k.c`, `read_genesis_pad()` reads a standard 6-button Genesis controller and maps:
- **D-Pad:** 8-Way Flight Movement
- **A / B / C:** Fire Weapon / Shop Confirm / Mega Crash
- **X / Z (or L / R):** Rotate Satellite Counter-Clockwise / Clockwise (emulating the arcade rotary dial accumulator)

## 3. Enabling Full Arcade Mode in `Makefile`

Once `python3 tools/extract_cps1.py forgottn.zip` has generated the binary assets in `assets/` and the disassembled 68000 hooks are linked:
1. Add `-DUSE_CPS1_ARCADE_ROM` to `M68K_CFLAGS` and `SH2_CFLAGS` in `Makefile`.
2. Run `make` to build `out/fw32x.32x` with full CPS-1 arcade graphics, 32X PWM voice samples, and Sega CD Mode 1 PC Engine CD music.