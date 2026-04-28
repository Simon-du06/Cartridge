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

DinoGameOver:
    jr DinoGameOver

SECTION "Dino WRAM", WRAM0
wScrollTick: db
