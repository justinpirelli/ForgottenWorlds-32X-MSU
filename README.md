# ForgottenWorlds-32X-MSU
An open-source effort to bring a 1:1 arcade perfect port of Capcom's "Forgotten Worlds" (CPS-1) to the Sega 32X paired with the PC Engine Super CD-ROM arranged soundtrack streaming via Sega CD Mode 1 (MSU-MD architecture). 

## Hardware Target
- **Sega Genesis / Mega Drive** (Motorola 68000): Runs transcoded CPS-1 arcade game logic.
- **Sega 32X** (Dual Hitachi SH-2): Software tile/sprite renderer (384x224 CPS-1 viewport, 256-color packed pixel mode) + PWM SFX/Voice playback.
- **Sega CD / Mega-CD** (Mode 1): Streams Redbook CD-DA tracks from the PC Engine CD version.

## Project Status & Architecture
- [x] Repository & Hardware Mailbox Skeleton (`src_68k` / `src_sh2`)
- [ ] Sega CD Mode 1 CD-DA Initialization (`msu_mode1.s`)
- [ ] SH-2 CPS-1 Scroll & Sprite Blitter (`src_sh2/renderer.c`)
- [ ] CPS-1 68000 Disassembly & Hardware Register Relocation (`patches/`)

## How to Build (Requires `marsdev`)
1. Place legally dumped MAME CPS-1 ROMs (`forgottn.zip`) into `assets/cps1_rom/`.
2. Run `make` using the `marsdev` (`m68k-elf` + `sh-elf`) toolchain.
3. Burn the `.cue`/`.bin` PC Engine CD audio pack to a CD-R and boot `out/fw32x.32x` via flashcart on a Genesis + Sega CD + 32X stack.
