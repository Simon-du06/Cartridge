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

    ; LCD comes back on with BG only and the palette pinned to all-black so
    ; the player doesn't see the fresh tilemap pop in. OBJs stay off until
    ; the fade completes so the duck/cactus appear *after* the world fades up.
    ld a, $FF
    ld [rBGP], a
    ld a, LCDC_ON | LCDC_BG_ON
    ld [rLCDC], a

    xor a
    ld [wFrameCounter], a
    ld [wCurKeys], a
    ld [wNewKeys], a

    ld [wScrollSkyX], a
    ld [wScrollGroundX], a

    ; Configure STAT_LYC to monitor line 93 (sky/ground boundary)
    ld a, 93
    ld [rLYC], a
    ld a, STAT_LYC
    ld [rSTAT], a

    ; Enable STAT interrupt
    ld a, [rIE]
    or a, IE_STAT
    ld [rIE], a

    ei  ; Enable global interrupts

    ; Fade the BG up to the dino palette, then enable sprites.
    ld de, FadeBgpDinoIn
    ld b, 3
    ld h, 6
    call FadeBgp

    ld a, %11011000
    ld [rOBP0], a
    ld a, LCDC_ON | LCDC_BG_ON | LCDC_OBJ_ON
    ld [rLCDC], a

DinoMain:
    call WaitVBlank

    ; Sky scroll (+1) - Appears at the top of the frame
    ld a, [wScrollSkyX]
    inc a
    ld [wScrollSkyX], a
    ld [rSCX], a

    ; Ground scroll (+3) - Handled mid-frame by STAT interrupt
    ld a, [wScrollGroundX]
    add a, 3
    ld [wScrollGroundX], a

    call UpdateKeys
    call UpdateDuck
    call UpdateCactus
    call DrawDuck
    call DrawCactus
    call CheckCactusCollision
    jp c, DinoGameOver
    jp DinoMain

; Reuse the breakout death screen (TilemapMort) sound a cactus hit kicks the
; player back to the menu. Reloads the font tile set first because
; TilemapMort references glyph tiles that don't live in DinoBgTiles.
DinoGameOver:
    ; Disable STAT interrupt so parallax doesn't affect death screen
    di
    ld a, [rIE]
    and a, ~IE_STAT
    ld [rIE], a

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
    jp nz, EntryPoint              ; SELECT -> back to the game-selection menu
    ld a, [wCurKeys]
    and PAD_START
    jp nz, EntryPointDino          ; START  -> restart dino
    jp .checkSelect

SECTION "Dino WRAM", WRAM0
wScrollSkyX:    db
wScrollGroundX: db

SECTION "Stat Handler", ROM0[$0048]
StatHandler::
    push af
    push hl

    ; Check if it's an LYC interrupt
    ld a, [rSTAT]
    and a, STAT_LYCF
    jp z, .exit

    ; Apply ground scroll position for the bottom half of the screen
    ld hl, wScrollGroundX
    ld a, [hl]
    ldh [rSCX], a

.exit:
    pop hl
    pop af
    reti
