INCLUDE "hardware.inc"

DEF BRICK_LEFT             EQU $05
DEF BRICK_RIGHT            EQU $06
DEF BRICK_LEFT_CRACKED     EQU $23
DEF BRICK_RIGHT_CRACKED    EQU $24
DEF BRICK_LEFT_BROKEN      EQU $25
DEF BRICK_RIGHT_BROKEN     EQU $26
DEF BRICK_LEFT_VERY_BROKEN EQU $27
DEF BRICK_RIGHT_VERY_BROKEN EQU $28
DEF BLANK_TILE             EQU $08

SECTION "Breakout Game Code", ROM0

; Reached via the menu (jp EntryPointBreakout). Self-contained: loads
; tileset/tilemap, sprites, OAM and per-game state, then drops into the
; breakout main loop.
EntryPointBreakout::
    call WaitVBlank

    xor a
    ld [rLCDC], a

    ; BG tiles (font glyphs included).
    ld de, BreakoutBgTiles
    ld hl, $9000
    ld bc, BreakoutBgTilesEnd - BreakoutBgTiles
    call MemCopy

    ; Playfield tilemap.
    ld de, TilemapBreakout
    ld hl, $9800
    ld bc, TilemapBreakoutEnd - TilemapBreakout
    call MemCopy

    ; Paddle OBJ tile at $8000 ($00), ball at $8010 ($01).
    ld de, BreakoutPaddle
    ld hl, $8000
    ld bc, BreakoutPaddleEnd - BreakoutPaddle
    call MemCopy

    ld de, BreakoutBall
    ld hl, $8010
    ld bc, BreakoutBallEnd - BreakoutBall
    call MemCopy

    call ClearOam

    ; Paddle OAM (slot 0).
    ld hl, STARTOF(OAM)
    ld a, 128 + 16
    ld [hli], a
    ld a, 16 + 8
    ld [hli], a
    xor a
    ld [hli], a
    ld [hli], a

    ; Ball OAM (slot 1).
    ld a, 100 + 16
    ld [hli], a
    ld a, 32 + 8
    ld [hli], a
    ld a, 1
    ld [hli], a
    xor a
    ld [hli], a

    ; Ball heads up-right.
    ld a, 1
    ld [wBallMomentumX], a
    ld a, -1
    ld [wBallMomentumY], a

    ; LCD on with BG only and palette pinned to all-black -- the playfield
    ; will fade up below, then OBJs (paddle + ball) get enabled afterwards.
    ld a, $FF
    ld [rBGP], a
    ld a, LCDC_ON | LCDC_BG_ON
    ld [rLCDC], a

    xor a
    ld [wFrameCounter], a
    ld [wCurKeys], a
    ld [wNewKeys], a
    ld [wFailedCatchBallCounter], a
    ld [wBlockBreakingID], a
    ld [wBlockBreakingID + 1], a

    ld hl, BreakingList
    ld b, 16
.ClearBreakingList:
    ld [hli], a
    dec b
    jr nz, .ClearBreakingList

    ; Fade the playfield up, then bring sprites in.
    ld de, FadeBgpBreakoutIn
    ld b, 3
    ld h, 6
    call FadeBgp

    ld a, %11100100
    ld [rOBP0], a
    ld a, LCDC_ON | LCDC_BG_ON | LCDC_OBJ_ON
    ld [rLCDC], a

BreakoutMain:
    call WaitVBlank

    ; Apply ball X momentum.
    ld a, [wBallMomentumX]
    ld b, a
    ld a, [STARTOF(OAM) + 5]
    add a, b
    ld [STARTOF(OAM) + 5], a

    ; Tick the brick-break animation every 4 frames.
    ld a, [wFrameCounter]
    inc a
    ld [wFrameCounter], a
    cp 4
    jr nz, .SkipAnimationForBrick
    call UpdateBreakingList
    xor a
    ld [wFrameCounter], a
.SkipAnimationForBrick:

    ; Apply ball Y momentum.
    ld a, [wBallMomentumY]
    ld b, a
    ld a, [STARTOF(OAM) + 4]
    add a, b
    ld [STARTOF(OAM) + 4], a

BounceOnTop:
    ld a, [STARTOF(OAM) + 4]
    sub a, 16 + 1
    ld c, a
    ld a, [STARTOF(OAM) + 5]
    sub a, 8
    ld b, a
    call GetTileByPixel
    ld a, [hl]
    call CheckAndHandleBrick
    call IsWallTile
    jp nz, BounceOnRight
    ld a, 1
    ld [wBallMomentumY], a

BounceOnRight:
    ld a, [STARTOF(OAM) + 4]
    sub a, 16
    ld c, a
    ld a, [STARTOF(OAM) + 5]
    sub a, 8 - 1
    ld b, a
    call GetTileByPixel
    ld a, [hl]
    call CheckAndHandleBrick
    call IsWallTile
    jp nz, BounceOnLeft
    ld a, -1
    ld [wBallMomentumX], a

BounceOnLeft:
    ld a, [STARTOF(OAM) + 4]
    sub a, 16
    ld c, a
    ld a, [STARTOF(OAM) + 5]
    sub a, 8 + 1
    ld b, a
    call GetTileByPixel
    ld a, [hl]
    call CheckAndHandleBrick
    call IsWallTile
    jp nz, BounceOnBottom
    ld a, 1
    ld [wBallMomentumX], a

BounceOnBottom:
    ld a, [STARTOF(OAM) + 4]
    sub a, 16 - 1
    ld c, a
    ld a, [STARTOF(OAM) + 5]
    sub a, 8
    ld b, a
    call GetTileByPixel
    ld a, [hl]
    call CheckAndHandleBrick
    call IsWallTile
    jp nz, BounceDone
    ld a, -1
    ld [wBallMomentumY], a
    call IsWallBellowBarObj

BounceDone:
    ; Paddle bounce check (Y match then X overlap).
    ld a, [STARTOF(OAM)]
    sub a, 6
    ld b, a
    ld a, [STARTOF(OAM) + 4]
    cp a, b
    jp nz, PaddleBounceDone
    ld a, [STARTOF(OAM) + 5]
    ld b, a
    ld a, [STARTOF(OAM) + 1]
    sub a, 8
    cp a, b
    jp nc, PaddleBounceDone
    add a, 8 + 16
    cp a, b
    jp c, PaddleBounceDone

    ld a, -1
    ld [wBallMomentumY], a

PaddleBounceDone:
    call UpdateKeys

CheckLeft:
    ld a, [wCurKeys]
    and a, PAD_LEFT
    jp z, CheckRight
Left:
    ld a, [STARTOF(OAM) + 1]
    dec a
    cp a, 15
    jp z, BreakoutMain
    ld [STARTOF(OAM) + 1], a
    jp BreakoutMain

CheckRight:
    ld a, [wCurKeys]
    and a, PAD_RIGHT
    jp z, BreakoutMain
Right:
    ld a, [STARTOF(OAM) + 1]
    inc a
    cp a, 105
    jp z, BreakoutMain
    ld [STARTOF(OAM) + 1], a
    jp BreakoutMain

; @return a = the tile (preserves it for the caller after the side effects)
CheckAndHandleBrick:
    cp a, BRICK_LEFT
    jr nz, CheckAndHandleBrickRight
    ld [hl], BRICK_LEFT_CRACKED
    inc hl
    ld [hl], BRICK_RIGHT_CRACKED
    dec hl
    call AddBreakingEntry
    ld a, [hl]
    ret
CheckAndHandleBrickRight:
    cp a, BRICK_RIGHT
    ret nz
    ld [hl], BRICK_RIGHT_CRACKED
    dec hl
    ld [hl], BRICK_LEFT_CRACKED
    call AddBreakingEntry
    ld a, [hl]
    ret

; --- Break-animation list (8 slots, 2 bytes per slot = left tile address) -

AddBreakingEntry:
    ld de, BreakingList
    ld c, 8
.FindSlot:
    ld a, [de]
    ld b, a
    inc de
    ld a, [de]
    or b
    dec de
    jr nz, .Occupied
    ld a, h
    ld [de], a
    inc de
    ld a, l
    ld [de], a
    dec de
    ret
.Occupied:
    inc de
    inc de
    dec c
    jr nz, .FindSlot
    ret

UpdateBreakingList:
    ld de, BreakingList
    ld c, 8
.SlotLoop:
    ld a, [de]
    ld b, a
    inc de
    ld a, [de]
    or b
    dec de
    jr z, .NextSlot
    ld a, [de]
    ld h, a
    inc de
    ld a, [de]
    ld l, a
    dec de
    ld a, [hl]
    cp BRICK_LEFT_CRACKED
    jr z, .DoPutBroken
    cp BRICK_LEFT_BROKEN
    jr z, .DoPutVeryBroken
    cp BRICK_LEFT_VERY_BROKEN
    jr z, .DoPutBlank
    jr .NextSlot
.DoPutBroken:
    call PutBrokenAtHL
    jr .NextSlot
.DoPutVeryBroken:
    call PutVeryBrokenAtHL
    jr .NextSlot
.DoPutBlank:
    call PutBlankAtHL
    xor a
    ld [de], a
    inc de
    ld [de], a
    dec de
.NextSlot:
    inc de
    inc de
    dec c
    jr nz, .SlotLoop
    ret

PutBrokenAtHL:
    ld [hl], BRICK_LEFT_BROKEN
    inc hl
    ld [hl], BRICK_RIGHT_BROKEN
    dec hl
    ret

PutVeryBrokenAtHL:
    ld [hl], BRICK_LEFT_VERY_BROKEN
    inc hl
    ld [hl], BRICK_RIGHT_VERY_BROKEN
    dec hl
    ret

PutBlankAtHL:
    ld [hl], BLANK_TILE
    inc hl
    ld [hl], BLANK_TILE
    dec hl
    ret

; Convert a pixel position to a $9800-relative tilemap address.
; @param b: pixel X
; @param c: pixel Y
; @return hl: tile address
GetTileByPixel:
    ld a, c
    and a, %11111000
    ld l, a
    ld h, 0
    add hl, hl
    add hl, hl
    ld a, b
    srl a
    srl a
    srl a
    add a, l
    ld l, a
    adc a, h
    sub a, l
    ld h, a
    ld bc, $9800
    add hl, bc
    ret

; @param a: tile id
; @return z: set if a is a wall (or any breakable brick state)
IsWallTile:
    cp a, $00
    ret z
    cp a, $01
    ret z
    cp a, $02
    ret z
    cp a, $04
    ret z
    cp a, $05
    ret z
    cp a, $06
    ret z
    cp a, $07
    ret z
    cp a, BRICK_LEFT_BROKEN
    ret z
    cp a, BRICK_LEFT_CRACKED
    ret z
    cp a, BRICK_LEFT_VERY_BROKEN
    ret z
    cp a, BRICK_RIGHT_BROKEN
    ret z
    cp a, BRICK_RIGHT_CRACKED
    ret z
    cp a, BRICK_RIGHT_VERY_BROKEN
    ret

; If the bottom-bounce wall is *below* the paddle, the player missed the ball.
IsWallBellowBarObj:
    ld a, [STARTOF(OAM)]
    ld b, a
    ld a, [STARTOF(OAM) + 4]
    cp b
    jr z, .notGreater
    jr c, .notGreater
    jp IncrementAndCheckNotLoose
.notGreater:
    ret

IncrementAndCheckNotLoose:
    ld a, [wFailedCatchBallCounter]
    inc a
    ld [wFailedCatchBallCounter], a
    ld b, a
    cp 3
    jr z, GameOver
    ret

; Game over: show the death screen, wait for Start/Select, then bounce back
; to the menu via the ROM EntryPoint.
GameOver:
    call WaitVBlank
    xor a
    ld [rLCDC], a
    ld de, TilemapMort
    ld hl, $9800
    ld bc, TilemapMortEnd - TilemapMort
    call MemCopy
    ld a, LCDC_ON | LCDC_BG_ON
    ld [rLCDC], a
    ld a, %11100100
    ld [rBGP], a
CheckSelectGameOver:
    call WaitVBlank
    call UpdateKeys
    ld a, [wCurKeys]
    and PAD_SELECT
    jp nz, EntryPoint              ; SELECT -> back to the game-selection menu
    ld a, [wCurKeys]
    and PAD_START
    jp nz, EntryPointBreakout      ; START  -> restart breakout
    jp CheckSelectGameOver

SECTION "Breakout WRAM", WRAM0
wFailedCatchBallCounter: db
wBallMomentumX:          db
wBallMomentumY:          db
wBlockBreakingID:        dw
BreakingList:            ds 16
