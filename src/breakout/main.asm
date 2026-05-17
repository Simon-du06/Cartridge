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
DEF BOTTOM_RAIL_TILE       EQU $09
DEF BOMB_TILE              EQU $30
DEF BOMB_SPAWN_BREAKS       EQU 4
DEF SCORE_TENS   EQU $9870
DEF SCORE_ONES   EQU $9871
DEF DIGIT_OFFSET EQU $19
DEF RAMG_MAGIC_VALUE EQU $43
DEF RAMG_MAGIC_LOCATION EQU $A000
DEF SCORE1 EQU $A001
DEF SCORE2 EQU $A002
DEF SCORE3 EQU $A003

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
    ld [wBreakCounter], a
    ld [wBombActive], a
    ld [wBombTileAddr], a
    ld [wBombTileAddr + 1], a
    ld [wLastBrickAddr], a
    ld [wLastBrickAddr + 1], a
    ld [wFramePaddleCounter], a
    ld [wScore], a

    ld a, 1
    ld [wSpeedPaddle], a
    xor a

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
    call CheckPaddleFrameCounter

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
.OKBounce:
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
.OKBounce:
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
.OKBounce:
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
    ld b, a
    call IsWallTile
    jp nz, BounceDone
.OKBounce:
    ld a, b
    cp a, BOTTOM_RAIL_TILE
    jr nz, .SkipMissCheck
    call IsWallBellowBarObj
.SkipMissCheck:
    ld a, -1
    ld [wBallMomentumY], a

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
    ; ld a, [STARTOF(OAM) + 1]
    ; dec a
    ld a, [wSpeedPaddle]
    ld b, a
    ld a, [STARTOF(OAM) + 1]
    sub a, b
    cp 16
    jp c, CheckSubOne
    ; jp z, BreakoutMain
    ld [STARTOF(OAM) + 1], a
    jp BreakoutMain
CheckSubOne:
    ld a, [STARTOF(OAM) + 1]
    sub a, 1
    cp a, 15
    jp z, BreakoutMain
    ld [STARTOF(OAM) + 1], a
    jp BreakoutMain

CheckRight:
    ld a, [wCurKeys]
    and a, PAD_RIGHT
    jp z, BreakoutMain
Right:
    ; ld a, [STARTOF(OAM) + 1]
    ; inc a
    ld a, [STARTOF(OAM) + 1]
    ld b, a
    ld a, [wSpeedPaddle]
    add a, b
    cp 105
    jp nc, CheckAddOne
    ; jp z, BreakoutMain
    ld [STARTOF(OAM) + 1], a
    jp BreakoutMain
CheckAddOne:
    ld a, [STARTOF(OAM) + 1]
    add a, 1
    cp a, 105
    jp z, BreakoutMain
    ld [STARTOF(OAM) + 1], a
    jp BreakoutMain

; @return a = the tile (preserves it for the caller after the side effects)
CheckAndHandleBrick:
    cp a, BOMB_TILE
    jr nz, .CheckLeft
    call TriggerBombExplosion
    ld a, BOMB_TILE
    ret
.CheckLeft:
    cp a, BRICK_LEFT
    jr nz, CheckAndHandleBrickRight
    ld [hl], BRICK_LEFT_CRACKED
    inc hl
    ld [hl], BRICK_RIGHT_CRACKED
    dec hl
    call AddBreakingEntryAndCount
    ld a, [hl]
    ld b, a
    call UpdateScore
    ld a, b
    ret
CheckAndHandleBrickRight:
    cp a, BRICK_RIGHT
    ret nz
    ld [hl], BRICK_RIGHT_CRACKED
    dec hl
    ld [hl], BRICK_LEFT_CRACKED
    call AddBreakingEntryAndCount
    ld a, [hl]
    ld b, a
    call UpdateScore
    ld a, b
    ret

; --- Break-animation list (8 slots, 2 bytes per slot = left tile address) -
AddBreakingEntryAndCount:
    call RecordLastBrickAndMaybeSpawnBomb
    jp AddBreakingEntry

RecordLastBrickAndMaybeSpawnBomb:
    ld a, l
    ld [wLastBrickAddr], a
    ld a, h
    ld [wLastBrickAddr + 1], a

    ld a, [wBombActive]
    cp 1
    jr z, .Done

    ld a, [wBreakCounter]
    inc a
    ld [wBreakCounter], a
    cp BOMB_SPAWN_BREAKS
    jr nz, .Done
    xor a
    ld [wBreakCounter], a
    call SpawnBombAtLastBrick
.Done:
    ret

SpawnBombAtLastBrick:
    ld a, [wLastBrickAddr]
    ld l, a
    ld a, [wLastBrickAddr + 1]
    ld h, a

    ld a, BOMB_TILE
    ld [hl], a
    inc hl
    ld a, BLANK_TILE
    ld [hl], a
    dec hl

    ld a, l
    ld [wBombTileAddr], a
    ld a, h
    ld [wBombTileAddr + 1], a
    ld a, 1
    ld [wBombActive], a
    ret

TriggerBombExplosion:
    ld a, [wBombActive]
    cp 1
    jp nz, .Done

    ld a, [wBombTileAddr]
    ld l, a
    ld a, [wBombTileAddr + 1]
    ld h, a

    ld a, BLANK_TILE
    ld [hl], a
    inc hl
    ld [hl], a
    dec hl

    xor a
    ld [wBombActive], a

    ld a, [wBombTileAddr]
    ld l, a
    ld a, [wBombTileAddr + 1]
    ld h, a
    ld bc, $FFDF
    add hl, bc
    call HandleBombNeighborAtHL

    ld a, [wBombTileAddr]
    ld l, a
    ld a, [wBombTileAddr + 1]
    ld h, a
    ld bc, $FFE0
    add hl, bc
    call HandleBombNeighborAtHL

    ld a, [wBombTileAddr]
    ld l, a
    ld a, [wBombTileAddr + 1]
    ld h, a
    ld bc, $FFE1
    add hl, bc
    call HandleBombNeighborAtHL

    ld a, [wBombTileAddr]
    ld l, a
    ld a, [wBombTileAddr + 1]
    ld h, a
    ld bc, $FFFF
    add hl, bc
    call HandleBombNeighborAtHL

    ld a, [wBombTileAddr]
    ld l, a
    ld a, [wBombTileAddr + 1]
    ld h, a
    ld bc, $0001
    add hl, bc
    call HandleBombNeighborAtHL

    ld a, [wBombTileAddr]
    ld l, a
    ld a, [wBombTileAddr + 1]
    ld h, a
    ld bc, $001F
    add hl, bc
    call HandleBombNeighborAtHL

    ld a, [wBombTileAddr]
    ld l, a
    ld a, [wBombTileAddr + 1]
    ld h, a
    ld bc, $0020
    add hl, bc
    call HandleBombNeighborAtHL

    ld a, [wBombTileAddr]
    ld l, a
    ld a, [wBombTileAddr + 1]
    ld h, a
    ld bc, $0021
    add hl, bc
    call HandleBombNeighborAtHL
.Done:
    ret

HandleBombNeighborAtHL:
    ld a, [hl]
    cp a, BRICK_LEFT
    jr nz, .CheckRight
    ld [hl], BRICK_LEFT_CRACKED
    inc hl
    ld [hl], BRICK_RIGHT_CRACKED
    dec hl
    call AddBreakingEntry
    ret
.CheckRight:
    cp a, BRICK_RIGHT
    jr nz, .CheckCrackedLeft
    ld [hl], BRICK_RIGHT_CRACKED
    dec hl
    ld [hl], BRICK_LEFT_CRACKED
    call AddBreakingEntry
    ret
.CheckCrackedLeft:
    cp a, BRICK_LEFT_CRACKED
    jr z, .AddLeft
    cp a, BRICK_LEFT_BROKEN
    jr z, .AddLeft
    cp a, BRICK_LEFT_VERY_BROKEN
    jr z, .AddLeft
    cp a, BRICK_RIGHT_CRACKED
    jr z, .AddRight
    cp a, BRICK_RIGHT_BROKEN
    jr z, .AddRight
    cp a, BRICK_RIGHT_VERY_BROKEN
    jr z, .AddRight
    ret
.AddLeft:
    call AddBreakingEntry
    ret
.AddRight:
    dec hl
    call AddBreakingEntry
    ret

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
    cp BLANK_TILE
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
    cp a, $09
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
    cp a, BOMB_TILE
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
    cp a, $09
    jp z, IncrementAndCheckNotLoose
    ret 
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

CheckPaddleFrameCounter:
    ld a, [wFramePaddleCounter]
    inc a
    ld [wFramePaddleCounter], a
    cp 255
    jr nz, .NotTimeToChangeSpeed
    xor a
    ld [wFramePaddleCounter], a
    call IncreaseSpeed
.NotTimeToChangeSpeed:
    ret

IncreaseSpeed:
    ld a, [wSpeedPaddle]
    inc a
    ld [wSpeedPaddle], a
    ret

UpdateScore:
    ld hl, wScore
    ld a, [hl]
    add 1
    daa
    ld [hl], a
    ld hl, SCORE_TENS
    call UpdateScoreTileMap
    ret

; Game over: show the death screen, wait for Start/Select, then bounce back
; to the menu via the ROM EntryPoint.
GameOver:
    call SaveScore
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

; Draw a packed BCD score into the BG tilemap.
; @param a: score in BCD (tens in high nibble)
; @param hl: tilemap address for tens digit (ones is hl+1)
UpdateScoreTileMap::
    push af
    and %11110000
    swap a
    add a, DIGIT_OFFSET
    ld [hli], a
    pop af
    and %00001111
    add a, DIGIT_OFFSET
    ld [hl], a
    ret

InitScoresIfMissing::
    ld a, RAMG_SRAM_ENABLE
    ld [rRAMG], a
    ld a, [RAMG_MAGIC_LOCATION]
    cp a, RAMG_MAGIC_VALUE
    ret z
    ld a, RAMG_MAGIC_VALUE
    ld [RAMG_MAGIC_LOCATION], a
    xor a
    ld [SCORE1], a
    ld [SCORE2], a
    ld [SCORE3], a
    ret

SaveScore::
    call InitScoresIfMissing
    ld a, [wScore]
    ld hl, SCORE2
    cp a, [hl]
    jr c, .Done
    ld [SCORE2], a
.Done:
    ret

SECTION "Breakout WRAM", WRAM0
wFailedCatchBallCounter: db
wBallMomentumX:          db
wBallMomentumY:          db
wBlockBreakingID:        dw
BreakingList:            ds 16
wBreakCounter:           db
wBombActive:             db
wBombTileAddr:           dw
wLastBrickAddr:          dw
wSpeedPaddle:            db
wFramePaddleCounter:     db
wScore:                  db