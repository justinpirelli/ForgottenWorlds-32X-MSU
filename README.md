# Forgotten Worlds: CPS1 EDITION (Sega 32X + Sega CD Mode 1)

An open-source homebrew runtime and porting framework designed to bring a **1:1 arcade-perfect port** of Capcom's *Forgotten Worlds* (CPS-1) to original **Sega Genesis + Sega CD + 32X ("Tower of Power")** hardware—combining the **Capcom CPS-1 arcade graphics & 2-player gameplay** on the 32X with the **PC Engine Super CD-ROM² arranged soundtrack** streaming via **Sega CD Mode 1 (MSU-MD)** and **32X PWM stereo voice/SFX**.

---

## Multi-CPU Hardware Architecture

| Hardware Unit | Processor | Role in *Forgotten Worlds 32X* |
| :--- | :--- | :--- |
| **Sega Genesis / Mega Drive** | Motorola 68000 @ 7.67 MHz | Runs main 60Hz loop, 6-button controller polling (satellite rotation), and transcoded CPS-1 arcade logic (`src_68k/`). |
| **Sega 32X (Master)** | Hitachi SH-2 @ 23.01 MHz | Manages 256-color Packed Pixel VDP, 224-line table, 12-bit→15-bit palette sync, and 3-layer parallax scrolling (`Scroll 1/2/3` + per-scanline Row Scroll). |
| **Sega 32X (Slave)** | Hitachi SH-2 @ 23.01 MHz | Renders active CPS-1 sprite list with `384→320` camera panning (`cps1_blitter.c`) and mixes 4-channel 22.05 kHz stereo PWM voice clips & SFX (`pwm_audio.c`). |
| **Sega CD / Mega-CD** | Motorola 68000 @ 12.5 MHz | Boots in **Mode 1** from cartridge space (`src_scd/sub_cpu.s`) and streams Redbook CD-DA tracks from a companion PC Engine CD audio disc via `_CDBIOS`. |

---

## Project Status & Roadmap

- [x] **Automated Cloud Build Pipeline** (`.github/workflows/build.yml` + `Makefile` + `32x.ld`)
- [x] **32X Bootloader & TMSS Unlock** (`src_68k/boot_32x.s` & `src_sh2/sh2_boot.s`)
- [x] **Sega CD Mode 1 Sub-CPU Redbook Driver** (`src_68k/msu_mode1.s` & `src_scd/sub_cpu.s`)
- [x] **SH-2 CPS-1 Tile/Sprite Blitter & 256-Color VDP Engine** (`src_sh2/cps1_blitter.c`)
- [x] **SH-2 3-Layer Parallax & Per-Scanline Row Scroll Engine** (`src_sh2/cps1_scroll.c` + live hardware test pattern)
- [x] **32X 4-Channel Stereo PWM Voice & SFX Mixer** (`src_sh2/pwm_audio.c`)
- [x] **Legal MAME CPS-1 Asset & ADPCM Extraction Tool** (`tools/extract_cps1.py`)
- [x] **CPS-1 68000 Compatibility Shim & Binary Relocator** (`src_68k/cps1_bridge.s` & `tools/patch_cps1_rom.py`)

---

## How to Build & Play on Real Tower of Power Hardware

### What You Need
- **Console Stack:** Sega Genesis / Mega Drive + Sega CD / Mega-CD + Sega 32X (properly connected with the 32X-to-Genesis link cable and Model 1 stereo mixing cable if using a Model 1 Genesis).
- **Flashcart:** Any standard Genesis/32X flashcart (e.g., EverDrive X3/X5/X7) inserted into the **top of the 32X**. *(Note: Do not use a Mega EverDrive Pro's internal Sega CD FPGA core while attached to a physical Sega CD unit; use a standard flashcart or disable FPGA CD emulation so the physical Sega CD drive handles Mode 1 audio).*
- **Controllers:** One or two **Sega 6-Button Controllers** (recommended for 360-degree satellite rotation).
- **Your Own Legal Game Backups:**
  - MAME CPS-1 ROM set for *Forgotten Worlds* (`forgottn.zip`)
  - PC Engine Super CD-ROM² / TurboGrafx-CD *Forgotten Worlds* Redbook audio tracks (`44.1 kHz, 16-bit Stereo WAV/BIN`)

---

### Step 1: Build the `.32x` Cartridge ROM
1. Clone this repository on a computer with `m68k-elf` and `sh-elf` cross-compilers installed (or `marsdev` / Ubuntu `gcc-m68k-linux-gnu` + `gcc-sh-elf`).
2. Extract and convert your legal `forgottn.zip` arcade ROMs into linear 32X assets:
   ```bash
   python3 tools/extract_cps1.py path/to/forgottn.zip
   python3 tools/patch_cps1_rom.py
   ```
   This populates `assets/cps1_rom/cps1_patched.bin`, `assets/gfx/cps1_tiles.bin`, and `assets/sfx/cps1_pcm.bin`.
3. Compile the full `.32x` ROM with arcade mode enabled:
   ```bash
   make CFLAGS_EXTRA="-DUSE_CPS1_ARCADE_ROM"
   ```
4. Copy the resulting **`out/fw32x.32x`** onto your flashcart's SD card.

*(Want to test the 32X hardware & Sega CD Mode 1 audio pipeline without providing an arcade ROM? Download the pre-built **`ForgottenWorlds32X-TestBuild`** artifact from the **Actions** tab—it boots a live 256-color parallax test screen while playing Track 02 from your Sega CD!)*

---

### Step 2: Burn the Companion PC Engine CD Audio Disc
1. Rip the Redbook audio tracks from your *Forgotten Worlds* (PC Engine Super CD-ROM²) disc as `44.1 kHz, 16-bit Stereo PCM` files following the track map in [`docs/PC_ENGINE_CD_TRACKLIST.md`](docs/PC_ENGINE_CD_TRACKLIST.md).
2. Pair **Track 01** (a 2-second dummy Mode 1 data track) with **Tracks 02–12** (the PC Engine CD music tracks) in a `.cue` sheet.
3. Burn the `.cue`/`.bin` image onto a high-quality **CD-R** at the slowest supported write speed (e.g., **4x–8x**) using ImgBurn or similar disc-burning software so your Sega CD laser reads every track reliably.

---

### Step 3: Boot & Controls on Real Hardware
1. Place your burned PC Engine CD audio disc into the **Sega CD** drive.
2. Insert your flashcart into the **Sega 32X**, power on the Tower of Power, and launch **`fw32x.32x`**.
3. The 32X will initialize 256-color video mode, the Sega CD will spin up Track 02, and 32X PWM will mix arcade voice samples and sound effects over the CD soundtrack.

#### 6-Button Controller Mapping

| Button | Action |
| :--- | :--- |
| **D-Pad** | 8-Way Flight Movement |
| **B** | Fire Primary Weapon / Shop Confirm |
| **C** | Mega Crash (Screen-Clearing Attack) |
| **X** | Rotate Satellite Pod Counter-Clockwise (Arcade Rotary Dial CCW) |
| **Z** | Rotate Satellite Pod Clockwise (Arcade Rotary Dial CW) |
| **Start** | Insert Coin & Start Game (1P / 2P) |

---

## Repository Structure

```text
├── .github/workflows/build.yml   # Automated cloud cross-compiler (outputs fw32x.32x artifact)
├── Makefile                      # 3-stage build script (Sega CD Sub-CPU -> Dual SH-2 -> Genesis 68k)
├── 32x.ld                        # 32X + Genesis memory map & linker script
├── src_68k/
│   ├── boot_32x.s                # 32X MARS security header, TMSS unlock & SH-2 bootstrapper
│   ├── main_68k.c                # 60Hz frame loop, 6-button pad reader & CPS-1 sound latch router
│   ├── msu_mode1.s               # Sega CD Mode 1 PRG-RAM loader & Main<->Sub CPU handshake
│   └── cps1_bridge.s             # CPS-1 JAMMA input, rotary dial & VRAM staging shim
├── src_scd/
│   └── sub_cpu.s                 # Sega CD Sub-CPU payload (_CDBIOS DRVINIT / MSCPLAYR / MSCSTOP)
├── src_sh2/
│   ├── sh2_boot.s                # Master & Slave SH-2 entry trampolines (0x06000000)
│   ├── sh2_main.c                # Dual SH-2 VDP Line Table setup & frame render loop
│   ├── cps1_blitter.c / .h       # 16x16 tile/sprite blitter, flipping, transparency & camera pan
│   ├── cps1_scroll.c / .h        # Scroll 1 (8x8), Scroll 2 (16x16 + Row Scroll), Scroll 3 (32x32)
│   └── pwm_audio.c / .h          # 4-channel stereo 32X PWM mixer for OKI ADPCM voices & SFX
├── tools/
│   ├── extract_cps1.py           # Legal user-supplied MAME ROM converter (GFX, OKI ADPCM, 68k)
│   └── patch_cps1_rom.py         # 68000 binary relocator & CPS-1 VRAM/register patcher
└── docs/
    ├── PC_ENGINE_CD_TRACKLIST.md # Redbook CD track mapping for Sega CD Mode 1 companion disc
    └── CPS1_PORTING_GUIDE.md     # CPS-1 arcade register -> 32X SDRAM mailbox memory map
```
