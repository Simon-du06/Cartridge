# Cartridge — Game Boy multi-game ROM

A Game Boy ROM written in RGBASM that boots into a selection menu and
lets the player launch either of two games:

- **Dino** — a Chrome Dino-inspired runner with animated sprites,
  parallax scrolling, progressively increasing speed, obstacles, sound,
  scoring and a high score saved to cartridge RAM.
- **Breakout** — a brick-breaking game with paddle and ball physics,
  three-stage brick destruction, a bomb power-up and a persistent
  leaderboard.

Built with [RGBDS](https://rgbds.gbdev.io/) (`rgbasm` 1.0.1+), no
external runtime libraries.

## Highlights

- Runs in an emulator or on original Game Boy hardware through a flash cart
- Two games packaged into a single 32 KB ROM with a shared menu
- Direct use of the PPU, VRAM, OAM, DMA, joypad, audio and cartridge SRAM
- Reusable assembly routines for input, text, fades and sprite-buffer management
- Hand-authored tile maps, sprites and collision/gameplay logic

> **Documentation map**
> - this file — overview, controls, build, file layout
> - [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — module graph,
>   state machine, per-frame loops, memory map, OAM layout, hardware
>   concepts the ROM relies on

---

## Quick start

```sh
make            # builds build/cartridge.gb and copies it to ./cartridge.gb
make re         # clean + rebuild
make clean      # wipe build/
make fclean     # also delete cartridge.gb
```

Open `cartridge.gb` in any Game Boy emulator (BGB, mGBA, SameBoy,
Emulicious, …) or flash it onto a real cart.

### Controls

| State            | Buttons                                          |
| ---------------- | ------------------------------------------------ |
| Menu             | `UP` / `DOWN` to choose, `START` to launch       |
| Dino             | `UP` to jump                                     |
| Breakout         | `LEFT` / `RIGHT` to slide the paddle             |
| Game-over screen | `START` to restart, `SELECT` to return to menu   |

---

## Repository layout

```
.
├── Makefile                  build (rgbasm + rgblink + rgbfix)
├── cartridge.gb              output ROM (committed for convenience)
├── README.md                 this file
├── docs/
│   └── ARCHITECTURE.md       diagrams + deep dive
├── assets/                   *.chr tile blobs + source PNGs
├── include/
│   └── hardware.inc          standard RGBDS register/flag definitions
└── src/
    ├── common.asm            shared utilities + shared WRAM + OAM DMA buffer
    ├── menu.asm              ROM Header + EntryPoint + selection menu
    ├── tiles.asm             ALL tile data + ALL tilemaps
    ├── text.inc              CHARMAP for "db \"...\"" string literals
    ├── dino_game/
    │   ├── main_dino.asm     EntryPointDino + dino main loop + game-over
    │   ├── duck.asm          duck state, physics, animation, OAM draw
    │   ├── cactus.asm        cactus state, scroll, collision, OAM draw
    │   ├── bird.asm          bird state, scroll, collision, OAM draw
    │   └── speed.asm         dino scroll-speed state + per-frame speed logic
    └── breakout/
        └── main.asm          EntryPointBreakout + physics + bricks + game-over
```

Five `.asm` files are linked together (see `SRC_FILES` in the Makefile).
  `duck.asm`, `cactus.asm`, `bird.asm`, and `speed.asm` are `INCLUDE`d
  into `main_dino.asm` rather than linked separately.

---

## Top-level flow

```
                   ┌──────────────────────────────┐
                   │   ROM start ($0100, menu.asm)│
                   │   - silence APU              │
                   │   - LCD off                  │
                   │   - load font tiles          │
                   │   - load TilemapMenu         │
                   │   - LCD on, BG only          │
                   └──────────────┬───────────────┘
                                  │
                          ┌───────▼────────┐
                          │  Menu loop     │
                          │  UP/DOWN: cursor│
                          │  START: launch │
                          └───────┬────────┘
                                  │   FadeBgpMenuOut (E4→F9→FE→FF)
                          ┌───────▼────────┐
                          │ Selection: 0?  │
                          └─┬────────────┬─┘
                            │ 0 (DINO)   │ 1 (BREAKOUT)
                            ▼            ▼
                ┌──────────────┐    ┌──────────────────┐
                │EntryPointDino│    │EntryPointBreakout│
                │ - load tiles │    │ - load tiles     │
                │ - load tilemap│   │ - load tilemap   │
                │ - load OBJ   │    │ - load OBJ       │
                │ - clear OAM  │    │ - clear OAM      │
                │ - InitDuck   │    │ - init paddle/   │
                │ - InitCactus │    │   ball OAM       │
                │ - BGP=$FF,LCD│    │ - BGP=$FF, LCD on│
                │ - FadeBgpDino│    │ - FadeBgpBreakout│
                │ - OBJs on    │    │ - OBJs on        │
                │       │      │    │       │          │
                └───────┼──────┘    └───────┼──────────┘
                        ▼                   ▼
                ┌──────────────┐    ┌──────────────────┐
                │ DinoMain loop│    │ BreakoutMain loop│
                │  WaitVBlank  │    │  WaitVBlank      │
                │  scroll BG   │    │  ball physics    │
                │  UpdateKeys  │    │  bounce checks   │
                │  UpdateDuck  │    │  brick break tick│
                │  UpdateCactus│    │  paddle input    │
                │  DrawDuck    │    │                  │
                │  DrawCactus  │    │                  │
                │  collision?──┼─┐  │  ball missed?────┼─┐
                └──────┬───────┘ │  └─────┬────────────┘ │
                       │ no      │        │ no           │
                       └─loop────┘        └─loop─────────┘
                  yes (carry set)│        │ yes (3rd miss)
                                 ▼        ▼
                        ┌────────────────────────┐
                        │  GameOver screen       │
                        │  - load font tiles     │
                        │  - load TilemapMort    │
                        │  - poll keys           │
                        └─┬──────────────────────┘
                          │ START → re-enter EntryPoint{Dino,Breakout}
                          │ SELECT → re-enter EntryPoint (menu)
                          ▼
                      (loops back)
```

For finer-grained diagrams (module dependency graph, per-frame
sequence diagrams, state machine), see
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

---

## What's reused vs. what's per-game

The ROM is organised so the two games share as much as possible
without leaking implementation details into each other:

| Module                   | Owns                                                  | Used by              |
| ------------------------ | ----------------------------------------------------- | -------------------- |
| `common.asm`             | `WaitVBlank`, `MemCopy`, `ClearOam`, `ClearOamBuffer`, `UpdateKeys`, `DrawText`, `FadeBgp` + tables | menu, dino, breakout |
| `menu.asm`               | ROM Header `$0100`, `EntryPoint`, cursor + dispatcher | (dispatch target)    |
| `tiles.asm`              | every tile blob, every tilemap                        | every game           |
| `text.inc`               | `CHARMAP " "→$0A`, `"G"→$0B`, …                       | `tiles.asm`, `DrawText` callers |
| `dino_game/main_dino.asm`| `EntryPointDino`, `DinoMain`, `DinoGameOver`          | (dispatch target)    |
| `dino_game/duck.asm`     | duck physics + foot animation                         | dino                 |
| `dino_game/cactus.asm`   | cactus scroll + collision                             | dino                 |
| `breakout/main.asm`      | `EntryPointBreakout`, ball physics, brick break, paddle, GameOver | (dispatch target) |

Highlights of the cross-game reuse:

- **`BreakoutBgTiles` doubles as the font tile set.** It contains the
  walls and bricks breakout needs *plus* every uppercase letter glyph,
  every digit, and the menu cursor at `$29`. Menu and game-over
  screens load this single blob.
- **`TilemapMort` is shared** between breakout's `GameOver` and
  dino's `DinoGameOver` — same death screen, two games.
- **`FadeBgp` is one routine, three tables.** Menu fade-out, breakout
  fade-in, dino fade-in (inverted palette) all reuse the same stepper.
- **`ClearOamBuffer` is part of the dino setup.** The shared WRAM DMA
  source is cleared before the first `hOamDma` call so stale sprites
  from the menu or a previous scene cannot leak into the first frame.

For the *visible* effect of this reuse on the player and the deeper
"why" behind each design choice, see
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

---

## Text rendering example

Strings are written naturally in source code; the assembler translates
each character to the right tile index automatically:

```asm
INCLUDE "src/text.inc"

; Inside a tilemap row -- assembles directly to tile bytes:
db "     GAME OVER      ", 0,0,0,0,0,0,0,0,0,0,0,0

; At runtime:
ld de, MyStr
ld hl, $9800 + 1*32 + 4         ; row 1, col 4
call DrawText                   ; copies until $FF terminator
...
MyStr: db "SCORE 0123", $FF
```

`text.inc` maps every printable character (lowercase letters aliased
to uppercase) to the tile index where its glyph already lives in
`BreakoutBgTiles`. The runtime terminator is `$FF` because that index
is outside the loaded tile range.

---

## Build pipeline

```
src/*.asm  ──rgbasm──▶  build/obj/*.o  ──rgblink──▶  build/cartridge.gb
                                                          │
                                              rgbfix -p0 -v (header
                                              checksum + Nintendo logo)
                                                          │
                                                          ▼
                                                   ./cartridge.gb
```

The Makefile lists `SRC_FILES` explicitly rather than wildcarding so
adding a module is a deliberate one-line edit. `INC_DIR` is just
`include/` (where `hardware.inc` lives); `INCLUDE`s like
`INCLUDE "src/text.inc"` work because rgbasm resolves them relative
to the project root.

---

## References

- [Pan Docs](https://gbdev.io/pandocs/) — authoritative DMG/CGB
  hardware documentation (PPU modes, OAM scan, APU registers, sprite
  priority).
- [RGBDS docs](https://rgbds.gbdev.io/docs/) — `rgbasm` syntax,
  `CHARMAP`, `INCBIN`, etc.
- [gbdev.io GB ASM tutorial — entry point chapter](https://gbdev.io/gb-asm-tutorial/part3/entry-point.html)
  — basis for our text-rendering system.

---

## Authors

Developed by [Simon Puccio](https://github.com/Simon-du06) and Enzo Bazin
as an Epitech student project. Simon worked primarily on the Dino game,
shared systems and project documentation; Enzo worked primarily on
Breakout, including its power-up and leaderboard features.

No license is currently granted for reuse or redistribution of the source
code. A license may be added later with the agreement of both authors.
