INCLUDE "hardware.inc"
INCLUDE "src/dino_game/duck.asm"
INCLUDE "src/dino_game/cactus.asm"

SECTION "Dino Game Code", ROM0

; Reached via the menu (jp EntryPointDino). Loads the dino tileset and
; tilemap into VRAM, sets up sprites, then runs the dino game loop.
EntryPointDino::
    call WaitVBlank

    xor a
    ld [rLCDC], a

    ; BG tiles
    ld de, DinoBgTiles
    ld hl, $9000
    ld bc, DinoBgTilesEnd - DinoBgTiles
    call MemCopy

    ; BG tilemap
    ld de, TilemapDino
    ld hl, $9800
    ld bc, TilemapDinoEnd - TilemapDino
    call MemCopy

    ; Duck OBJ tiles ($8000)
    ld de, DuckTiles
    ld hl, $8000
    ld bc, DuckTilesEnd - DuckTiles
    call MemCopy

    ; Cactus OBJ tiles
    ld de, CactusTiles
    ld hl, CACTUS_VRAM_ADDR
    ld bc, CactusTilesEnd - CactusTiles
    call MemCopy

    call ClearOam

    call InitDuck
    call InitCactus

    ld a, LCDC_ON | LCDC_BG_ON | LCDC_OBJ_ON
    ld [rLCDC], a

    ld a, %00011011
    ld [rBGP], a
    ld a, %11011000
    ld [rOBP0], a

    xor a
    ld [wFrameCounter], a
    ld [wCurKeys], a
    ld [wNewKeys], a

    ld a, 2
    ld [wScrollTick], a

DinoMain:
    call WaitVBlank

    ; Scroll the BG horizontally.
    ld a, [rSCX]
    ld hl, wScrollTick
    add a, [hl]
    ld [rSCX], a

    call UpdateKeys
    call UpdateDuck
    call UpdateCactus
    call DrawDuck
    call DrawCactus
    call CheckCactusCollision
    jp c, DinoGameOver
    jp DinoMain

; Reuse the breakout death screen (TilemapMort) so a cactus hit kicks the
; player back to the menu. Reloads the font tile set first because
; TilemapMort references glyph tiles that don't live in DinoBgTiles.
DinoGameOver:
    call WaitVBlank
    xor a
    ld [rLCDC], a

    ld de, BreakoutBgTiles
    ld hl, $9000
    ld bc, BreakoutBgTilesEnd - BreakoutBgTiles
    call MemCopy

    ld de, TilemapMort
    ld hl, $9800
    ld bc, TilemapMortEnd - TilemapMort
    call MemCopy

    ; Re-zero the BG scroll so the death screen isn't drawn shifted.
    xor a
    ld [rSCX], a
    ld [rSCY], a

    ld a, LCDC_ON | LCDC_BG_ON
    ld [rLCDC], a
    ld a, %11100100
    ld [rBGP], a

.checkSelect:
    call WaitVBlank
    call UpdateKeys
    ld a, [wCurKeys]
    and PAD_SELECT
    jp nz, EntryPoint
    ld a, [wCurKeys]
    and PAD_START
    jp nz, EntryPoint
    jp .checkSelect

SECTION "Dino WRAM", WRAM0
wScrollTick: db
