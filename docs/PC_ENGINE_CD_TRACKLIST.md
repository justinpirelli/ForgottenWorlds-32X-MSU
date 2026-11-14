
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
