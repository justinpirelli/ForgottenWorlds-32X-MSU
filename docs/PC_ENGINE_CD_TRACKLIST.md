
# PC Engine Super CD-ROM² to CPS-1 Sound ID Mapping

To build the companion audio disc for Sega CD Mode 1 playback, rip the Redbook audio tracks from *Forgotten Worlds* (PC Engine Super CD-ROM²) as `44.1kHz, 16-bit Stereo PCM (.wav/.bin)` and pair them with a dummy Track 01 data track.

| CD Track | CPS-1 Sound ID | Track Title / Usage | Loop? |
| :--- | :--- | :--- | :--- |
| **Track 01** | — | *(Dummy Mode 1 Data Track - 2 Seconds)* | No |
| **Track 02** | `0x01` | Opening / Attract Demo | Yes |
| **Track 03** | `0x02` | Stage 1: Ancient Ruins | Yes |
| **Track 04** | `0x03` | Item Shop (Sylphie's Shop) | Yes |
| **Track 05** | `0x04` | Boss Theme 1 (Dust Dragon / Paramecium) | Yes |
| **Track 06** | `0x05` | Stage Clear Fanfare | No |
| **Track 07** | `0x06` | Stage 2: Sky & Clouds | Yes |
| **Track 08** | `0x07` | Stage 3: Underwater / Pyramid | Yes |
| **Track 09** | `0x08` | Stage 4: Tower / War God | Yes |
| **Track 10** | `0x09` | Final Boss: Emperor Bios | Yes |
| **Track 11** | `0x0A` | Ending & Credits | No |
| **Track 12** | `0x0B` | Game Over | No |

## How to Create `track01.bin` (Dummy Mode 1 Data Track)

The Sega CD BIOS requires **Track 01** to be a valid `MODE1/2048` data track at least **4 seconds (300 sectors = 614,400 bytes)** long before it will read Redbook audio tracks (`Track 02+`).

Generate a compliant `track01.bin` file in one command, then burn it alongside your ripped `track02.wav`–`track12.wav` files using [`docs/ForgottenWorlds_MSU.cue`](ForgottenWorlds_MSU.cue):

- **macOS / Linux:**
  ```bash
  dd if=/dev/zero of=track01.bin bs=2048 count=300
  ```
- **Windows (Command Prompt):**
  ```cmd
  fsutil file createnew track01.bin 614400
  ```
- **Python (Any OS):**
  ```bash
  python3 -c "open('track01.bin','wb').write(b'\x00'*614400)"
  ```
