INCLUDE "hardware.inc"
INCLUDE "src/dino_game/speed.asm"
INCLUDE "src/dino_game/duck.asm"
INCLUDE "src/dino_game/cactus.asm"
INCLUDE "src/dino_game/bird.asm"

; Reuses Enzo's BCD digit tiles ($19..$22) and his SRAM helpers
; (UpdateScoreTileMap / InitScoresIfMissing) by copying the digit
; glyphs out of BreakoutBgTiles into the dino BG tile area at $9190
; (= tile index $19 with the 8800 addressing mode used here).
DEF DIGIT_OFFSET            EQU $19
DEF DIGITS_VRAM_DEST        EQU $9190
DEF DIGITS_SRC_OFFSET       EQU DIGIT_OFFSET * 16
DEF DIGITS_BYTES            EQU 10 * 16

; Window tilemap at $9C00 hosts a single visible row at the top of the
; screen showing "HI score" (left) and "current score" (right). The row
; is forced via STAT IRQ: window enabled at frame start, disabled at
; LY=8 so the rest of the screen renders the BG normally.
DEF WINDOW_TILEMAP          EQU $9C00
DEF SCORE_HI_TILEMAP        EQU WINDOW_TILEMAP + 4   ; cols 4..7
DEF SCORE_CUR_TILEMAP       EQU WINDOW_TILEMAP + 14  ; cols 14..17
DEF SCORE_INCREMENT_FRAMES  EQU 6                    ; +1 every 6 frames -> ~10/sec
DEF WINDOW_DISABLE_LY       EQU 8
DEF GROUND_SCROLL_LY        EQU 93

DEF DINO_HI_SCORE_LO        EQU $A001  ; SCORE1 (low BCD byte)
DEF DINO_HI_SCORE_HI        EQU $A003  ; SCORE3 (high BCD byte)

DEF DINO_LCDC_GAME EQU LCDC_ON | LCDC_BG_ON | LCDC_OBJ_ON | LCDC_WIN_ON | LCDC_WIN_9C00
DEF DINO_LCDC_NOWIN EQU LCDC_ON | LCDC_BG_ON | LCDC_OBJ_ON

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

    ; Initialize the window's first tile row to the dino sky tile so the
    ; score row blends with the BG sky above the parallax boundary.
    call InitScoreWindowRow

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

    ; Bird OBJ tiles
    ld de, BirdTiles
    ld hl, BIRD_VRAM_ADDR
    ld bc, BirdTilesEnd - BirdTiles
    call MemCopy

    call ClearOam

    call InitDma

    call InitDuck
    call InitCactus
    call InitBird
    call InitSpeedSystem
    call InitDinoScore

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

    ; Window pinned to the top-left corner; STAT IRQ disables it after the
    ; score row so the BG/sprites render normally below.
    xor a
    ld [rWY], a
    ld a, 7
    ld [rWX], a

    ; STAT IRQ first fires at LY=8 (window-off), then bounces between 8 and
    ; 93 (ground-scroll switch) so a single STAT handles both.
    ld a, WINDOW_DISABLE_LY
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
    ld a, DINO_LCDC_GAME
    ld [rLCDC], a

DinoMain:
    call WaitVBlank

    ; Apply OAM DMA transfer from wOAMBuffer safely
    ld a, HIGH(wOAMBuffer)
    call hOamDma

    ; STAT disabled the window mid-frame; re-enable it so the score row
    ; renders again on the next frame.
    ld a, DINO_LCDC_GAME
    ld [rLCDC], a

    call UpdateDinoScore

    ; We need to call IncreaseSpeed once per frame
    call IncreaseSpeed

    ; Sky scroll (slower)
    ld a, [wScrollSkyX]
    add a, 1
    ld [wScrollSkyX], a
    ld [rSCX], a

    ; Ground scroll (dynamical based on UpdateScroll)
    call UpdateScroll ; Sets wCurrentFrameSpeed
    ld a, [wScrollGroundX]
    ld hl, wCurrentFrameSpeed
    add a, [hl]
    ld [wScrollGroundX], a

    call UpdateKeys
    call UpdateDuck
    call UpdateCactus
    call UpdateBird
    call DrawDuck
    call DrawCactus
    call DrawBird
    call CheckCactusCollision
    jp c, DinoGameOver
    call CheckBirdCollision
    jp c, DinoGameOver
    jp DinoMain

; Reuse the breakout death screen (TilemapMort) sound a cactus hit kicks the
; player back to the menu. Reloads the font tile set first because
; TilemapMort references glyph tiles that don't live in DinoBgTiles.
DinoGameOver:
    call SaveDinoHiScore

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
    and PAD_START | PAD_A
    jp nz, EntryPointDino          ; START  -> restart dino
    jp .checkSelect

; ---------------------------------------------------------------------------
; Score helpers
; ---------------------------------------------------------------------------

; Fill the first 32 tiles of the window tilemap with the dino sky tile so
; the score row blends with the BG sky color. Called with LCD off.
InitScoreWindowRow:
    ld hl, WINDOW_TILEMAP
    ld b, 32
    xor a
.loop:
    ld [hli], a
    dec b
    jr nz, .loop
    ret

; Reset the in-game score, load the persisted HI score from SRAM, and
; render both into the window tilemap. Called with LCD off so direct VRAM
; writes are safe.
InitDinoScore::
    xor a
    ld [wDinoScoreLo], a
    ld [wDinoScoreHi], a
    ld [wDinoScoreFrameTimer], a

    call InitScoresIfMissing
    ld a, [DINO_HI_SCORE_HI]
    ld hl, SCORE_HI_TILEMAP
    call UpdateScoreTileMap
    ld a, [DINO_HI_SCORE_LO]
    ld hl, SCORE_HI_TILEMAP + 2
    call UpdateScoreTileMap

    xor a
    ld hl, SCORE_CUR_TILEMAP
    call UpdateScoreTileMap
    xor a
    ld hl, SCORE_CUR_TILEMAP + 2
    call UpdateScoreTileMap
    ret

; Tick the per-frame score timer; on rollover bump the BCD score by 1
; and rewrite the four current-score digits. Capped at 9999.
UpdateDinoScore::
    ld a, [wDinoScoreFrameTimer]
    inc a
    cp SCORE_INCREMENT_FRAMES
    jr nc, .tick
    ld [wDinoScoreFrameTimer], a
    ret
.tick:
    xor a
    ld [wDinoScoreFrameTimer], a

    ld a, [wDinoScoreLo]
    add a, 1
    daa
    ld [wDinoScoreLo], a
    ld a, [wDinoScoreHi]
    adc a, 0
    daa
    ld [wDinoScoreHi], a
    jr nc, .draw
    ; Overflow past 9999 -> pin to max
    ld a, $99
    ld [wDinoScoreLo], a
    ld [wDinoScoreHi], a
.draw:
    ld a, [wDinoScoreHi]
    ld hl, SCORE_CUR_TILEMAP
    call UpdateScoreTileMap
    ld a, [wDinoScoreLo]
    ld hl, SCORE_CUR_TILEMAP + 2
    call UpdateScoreTileMap
    ret

; Persist the current run's score as the new HI score if it beats the
; stored value. BCD bytes compare correctly with plain `cp`.
SaveDinoHiScore::
    call InitScoresIfMissing
    ld a, [wDinoScoreHi]
    ld b, a
    ld a, [DINO_HI_SCORE_HI]
    cp b
    jr c, .save
    jr nz, .done
    ld a, [wDinoScoreLo]
    ld b, a
    ld a, [DINO_HI_SCORE_LO]
    cp b
    jr nc, .done
.save:
    ld a, [wDinoScoreHi]
    ld [DINO_HI_SCORE_HI], a
    ld a, [wDinoScoreLo]
    ld [DINO_HI_SCORE_LO], a
.done:
    ret

SECTION "Dino WRAM", WRAM0
wScrollSkyX:           db
wScrollGroundX:        db
wDinoScoreLo:          db
wDinoScoreHi:          db
wDinoScoreFrameTimer:  db

SECTION "Stat Handler", ROM0[$0048]
StatHandler::
    push af
    push hl

    ; Check if it's an LYC interrupt
    ld a, [rSTAT]
    and a, STAT_LYCF
    jp z, .exit

    ld a, [rLYC]
    cp GROUND_SCROLL_LY
    jr z, .atGroundLine

    ; LY=8: turn the window off so the rest of the frame renders BG-only.
    ld a, DINO_LCDC_NOWIN
    ld [rLCDC], a
    ld a, GROUND_SCROLL_LY
    ld [rLYC], a
    jr .exit

.atGroundLine:
    ; LY=93: switch SCX to the ground scroll position for the parallax
    ; ground band, then arm the next frame's window-disable trigger.
    ld hl, wScrollGroundX
    ld a, [hl]
    ldh [rSCX], a
    ld a, WINDOW_DISABLE_LY
    ld [rLYC], a

.exit:
    pop hl
    pop af
    reti
