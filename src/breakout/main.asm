INCLUDE "hardware.inc"

DEF BRICK_LEFT EQU $05
DEF BRICK_RIGHT EQU $06
DEF BLANK_TILE EQU $08

SECTION "Header", ROM0[$100]

    jp EntryPoint

    ds $150 - @ ; Make room for the nintendo logo

EntryPoint:
    ; Do not turn the LCD off outside of VBlank
    call WaitVBlank

    ; Turn the LCD off
    ld a, 0
    ld [rLCDC], a
    ; Copy the tile data
    ld de, Tiles
    ld hl, $9000
    ld bc, TilesEnd - Tiles
    call MemCopy
    ; Copy the tilemap
    ld de, Tilemap
    ld hl, $9800
    ld bc, TilemapEnd - Tilemap
    call MemCopy
	; Copy the ball tile
    ld de, Ball
    ld hl, $8010
    ld bc, BallEnd - Ball
    call MemCopy
    ; Initialize to start clear Oam
    ld a, 0	
    ld b, 160
    ld hl, STARTOF(OAM)
ClearOam:
    ld [hli], a
    dec b
    jp nz, ClearOam
    ld hl, STARTOF(OAM)
    ld a, 128 + 16
    ld [hli], a
    ld a, 16 + 8
    ld [hli], a
    ld a, 0
    ld [hli], a
    ld [hli], a
    ; Now initialize the ball sprite
    ld a, 100 + 16
    ld [hli], a
    ld a, 32 + 8
    ld [hli], a
    ld a, 1
    ld [hli], a
    ld a, 0
    ld [hli], a
	; The ball starts out going up and to the right
    ld a, 1
    ld [wBallMomentumX], a
    ld a, -1
    ld [wBallMomentumY], a


    ; Copy the paddle tile
    ld de, Paddle
    ld hl, $8000
    ld bc, PaddleEnd - Paddle
    call MemCopy



    ; Turn the LCD on
    ld a, LCDC_ON | LCDC_BG_ON | LCDC_OBJ_ON
    ld [rLCDC], a

    ; During the first (blank) frame, initialize display registers
    ld a, %11100100
    ld [rBGP], a
    ld a, %11100100
    ld [rOBP0], a

    ; Initialize global variables
    ld a, 0
    ld [wFrameCounter], a
    ld [wCurKeys], a
    ld [wNewKeys], a
    ld [wFailedCatchBallCounter], a


Main:
    call WaitVBlank
    ; Add the ball's momentum to its position in OAM.
    ld a, [wBallMomentumX]
    ld b, a
    ld a, [STARTOF(OAM) + 5]
    add a, b
    ld [STARTOF(OAM) + 5], a

    ld a, [wBallMomentumY]
    ld b, a
    ld a, [STARTOF(OAM) + 4]
    add a, b
    ld [STARTOF(OAM) + 4], a
BounceOnTop:
    ; Remember to offset the OAM position!
    ; (8, 16) in OAM coordinates is (0, 0) on the screen.
    ld a, [STARTOF(OAM) + 4]
    sub a, 16 + 1
    ld c, a
    ld a, [STARTOF(OAM) + 5]
    sub a, 8
    ld b, a
    call GetTileByPixel ; Returns tile address in hl
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
	; First, check if the ball is low enough to bounce off the paddle.
    ld a, [STARTOF(OAM)]
	sub a, 6
    ld b, a
    ld a, [STARTOF(OAM) + 4]
    cp a, b
    jp nz, PaddleBounceDone ; If the ball isn't at the same Y position as the paddle, it can't bounce.
    ; Now let's compare the X positions of the objects to see if they're touching.
    ld a, [STARTOF(OAM) + 5] ; Ball's X position.
    ld b, a
    ld a, [STARTOF(OAM) + 1] ; Paddle's X position.
    sub a, 8
    cp a, b
    jp nc, PaddleBounceDone
    add a, 8 + 16 ; 8 to undo, 16 as the width.
    cp a, b
    jp c, PaddleBounceDone

    ld a, -1
    ld [wBallMomentumY], a

PaddleBounceDone:
    ; Check the current keys every frame and move left or right.
    call UpdateKeys

    ; First, check if the left button is pressed.
CheckLeft:
    ld a, [wCurKeys]
    and a, PAD_LEFT
    jp z, CheckRight
Left:
    ; Move the paddle one pixel to the left.
    ld a, [STARTOF(OAM) + 1]
    dec a
    ; If we've already hit the edge of the playfield, don't move.
    cp a, 15
    jp z, Main
    ld [STARTOF(OAM) + 1], a
    jp Main

; Then check the right button.
CheckRight:
    ld a, [wCurKeys]
    and a, PAD_RIGHT
    jp z, Main
Right:
    ; Move the paddle one pixel to the right.
    ld a, [STARTOF(OAM) + 1]
    inc a
    ; If we've already hit the edge of the playfield, don't move.
    cp a, 105
    jp z, Main
    ld [STARTOF(OAM) + 1], a
    jp Main


WaitVBlank:
    ; If we're already in VBlank, wait for it to end first.
    ld a, [rLY]
    cp 144
    jp nc, WaitVBlank
.wait
    ld a, [rLY]
    cp 144
    jp c, .wait
    ret

; Copy bytes from one area to another.
; @param de: Source
; @param hl: Destination
; @param bc: Length
MemCopy:
    ld a, [de]
    ld [hli], a
    inc de
    dec bc
    ld a, b
    or a, c
    jp nz, MemCopy
    ret

CheckAndHandleBrick:
    ld a, [hl]
    cp a, BRICK_LEFT
    jr nz, CheckAndHandleBrickRight
    ; Break a brick from the left side.
    ld [hl], BLANK_TILE
    inc hl
    ld [hl], BLANK_TILE
CheckAndHandleBrickRight:
    cp a, BRICK_RIGHT
    ret nz
    ; Break a brick from the right side.
    ld [hl], BLANK_TILE
    dec hl
    ld [hl], BLANK_TILE
    ret

UpdateKeys:
  ; Poll half the controller
  ld a, JOYP_GET_BUTTONS
  call .onenibble
  ld b, a ; B7-4 = 1; B3-0 = unpressed buttons

  ; Poll the other half
  ld a, JOYP_GET_CTRL_PAD
  call .onenibble
  swap a ; A7-4 = unpressed directions; A3-0 = 1
  xor a, b ; A = pressed buttons + directions
  ld b, a ; B = pressed buttons + directions

  ; And release the controller
  ld a, JOYP_GET_NONE
  ldh [rJOYP], a

  ; Combine with previous wCurKeys to make wNewKeys
  ld a, [wCurKeys]
  xor a, b ; A = keys that changed state
  and a, b ; A = keys that changed to pressed
  ld [wNewKeys], a
  ld a, b
  ld [wCurKeys], a
  ret

.onenibble
  ldh [rJOYP], a ; switch the key matrix
  call .knownret ; burn 10 cycles calling a known ret
  ldh a, [rJOYP] ; ignore value while waiting for the key matrix to settle
  ldh a, [rJOYP]
  ldh a, [rJOYP] ; this read counts
  or a, $F0 ; A7-4 = 1; A3-0 = unpressed keys
.knownret
  ret

; Convert a pixel position to a tilemap address
; hl = $9800 + X + Y * 32
; @param b: X
; @param c: Y
; @return hl: tile address
GetTileByPixel:
    ; First, we need to divide by 8 to convert a pixel position to a tile position.
    ; After this we want to multiply the Y position by 32.
    ; These operations effectively cancel out so we only need to mask the Y value.
    ld a, c
    and a, %11111000
    ld l, a
    ld h, 0
    ; Now we have the position * 8 in hl
    add hl, hl ; position * 16
    add hl, hl ; position * 32
    ; Convert the X position to an offset.
    ld a, b
    srl a ; a / 2
    srl a ; a / 4
    srl a ; a / 8
    ; Add the two offsets together.
    add a, l
    ld l, a
    adc a, h
    sub a, l
    ld h, a
    ; Add the offset to the tilemap's base address, and we are done!
    ld bc, $9800
    add hl, bc
    ret
; @param a: tile IDx
; @return z: set if a is a wall.
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
    ret

; @return z: if the wall touch is bellow the objbar
IsWallBellowBarObj:
    ld a, [STARTOF(OAM)]
    ld b, a
    ld a, [STARTOF(OAM) + 4]
    cp b
    jr z, NotGreater
    jr c, NotGreater
    ;else
    jp IncrementAndCheckNotLoose
NotGreater:
    ret

IncrementAndCheckNotLoose:
    ld a, [wFailedCatchBallCounter]
    inc a
    ld [wFailedCatchBallCounter], a
    ld b, a
    cp 3
    jr z, GameOver
    ret

GameOver:
    call WaitVBlank
    ; Turn the LCD off
    ld a, 0
    ld [rLCDC], a
    ld de, TilemapMort
    ld hl, $9800
    ld bc, TilemapMortEnd - TilemapMort
    call MemCopy
    ; Turn the LCD on
    ld a, LCDC_ON | LCDC_BG_ON
    ld [rLCDC], a
    ; During the first (blank) frame, initialize display registers
    ld a, %11100100
    ld [rBGP], a
CheckSelectGameOver:
    call WaitVBlank
    ; Check if the select button is pressed to reset the game.
    call UpdateKeys
    ld a, [wCurKeys]
    and PAD_SELECT
    jp z, CheckStartGameOver
SelectGameOver:
    jp EntryPoint

; Then check the right button.
CheckStartGameOver:
    ld a, [wCurKeys]
    and PAD_START
    jp z, CheckSelectGameOver
StartGameOver:
    jp EntryPoint

Paddle:
    dw `13333331
    dw `30000003
    dw `13333331
    dw `00000000
    dw `00000000
    dw `00000000
    dw `00000000
    dw `00000000
PaddleEnd:


Ball:
    dw `00033000
    dw `00322300
    dw `03222230
    dw `03222230
    dw `00322300
    dw `00033000
    dw `00000000
    dw `00000000
BallEnd:



Tiles:
	dw `33333333
	dw `33333333
	dw `33333333
	dw `33322222
	dw `33322222
	dw `33322222
	dw `33322211
	dw `33322211

	dw `33333333
	dw `33333333
	dw `33333333
	dw `22222222
	dw `22222222
	dw `22222222
	dw `11111111
	dw `11111111

	dw `33333333
	dw `33333333
	dw `33333333
	dw `22222333
	dw `22222333
	dw `22222333
	dw `11222333
	dw `11222333

	dw `33333333
	dw `33333333
	dw `33333333
	dw `33333333
	dw `33333333
	dw `33333333
	dw `33333333
	dw `33333333

	dw `33322211
	dw `33322211
	dw `33322211
	dw `33322211
	dw `33322211
	dw `33322211
	dw `33322211
	dw `33322211

	dw `22222222
	dw `20000000
	dw `20111111
	dw `20111111
	dw `20111111
	dw `20111111
	dw `22222222
	dw `33333333

	dw `22222223
	dw `00000023
	dw `11111123
	dw `11111123
	dw `11111123
	dw `11111123
	dw `22222223
	dw `33333333

	dw `11222333
	dw `11222333
	dw `11222333
	dw `11222333
	dw `11222333
	dw `11222333
	dw `11222333
	dw `11222333

	dw `00000000
	dw `00000000
	dw `00000000
	dw `00000000
	dw `00000000
	dw `00000000
	dw `00000000
	dw `00000000

	dw `11001100
	dw `11111111
	dw `11111111
	dw `21212121
	dw `22222222
	dw `22322232
	dw `23232323
	dw `33333333

	; Paste your logo here!

        ; Tile $0A - Vide noir
    dw `00000000
    dw `00000000
    dw `00000000
    dw `00000000
    dw `00000000
    dw `00000000
    dw `00000000
    dw `00000000

    ; Tile $0B - "G"
    dw `00111100
    dw `01100000
    dw `01100000
    dw `01101110
    dw `01100110
    dw `01100110
    dw `00111100
    dw `00000000

    ; Tile $0C - "A"
    dw `00011000
    dw `00111100
    dw `01100110
    dw `01111110
    dw `01100110
    dw `01100110
    dw `01100110
    dw `00000000

    ; Tile $0D - "M"
    dw `01100011
    dw `01110111
    dw `01111111
    dw `01101011
    dw `01100011
    dw `01100011
    dw `01100011
    dw `00000000

    ; Tile $0E - "E"
    dw `01111110
    dw `01100000
    dw `01100000
    dw `01111100
    dw `01100000
    dw `01100000
    dw `01111110
    dw `00000000

    ; Tile $0F - "O"
    dw `00111100
    dw `01100110
    dw `01100110
    dw `01100110
    dw `01100110
    dw `01100110
    dw `00111100
    dw `00000000

    ; Tile $10 - "V"
    dw `01100110
    dw `01100110
    dw `01100110
    dw `01100110
    dw `01100110
    dw `00111100
    dw `00011000
    dw `00000000

    ; Tile $11 - "R"
    dw `01111100
    dw `01100110
    dw `01100110
    dw `01111100
    dw `01111000
    dw `01101100
    dw `01100110
    dw `00000000

    ; Tile $12 - "P"
    dw `01111100
    dw `01100110
    dw `01100110
    dw `01111100
    dw `01100000
    dw `01100000
    dw `01100000
    dw `00000000

    ; Tile $13 - "S"
    dw `00111110
    dw `01100000
    dw `01100000
    dw `00111100
    dw `00000110
    dw `00000110
    dw `01111100
    dw `00000000

    ; Tile $14 - "T"
    dw `01111110
    dw `00011000
    dw `00011000
    dw `00011000
    dw `00011000
    dw `00011000
    dw `00011000
    dw `00000000

    ; Tile $15 - "L"
    dw `01100000
    dw `01100000
    dw `01100000
    dw `01100000
    dw `01100000
    dw `01100000
    dw `01111110
    dw `00000000

    ; Tile $16 - "C"
    dw `00111100
    dw `01100110
    dw `01100000
    dw `01100000
    dw `01100000
    dw `01100110
    dw `00111100
    dw `00000000

    ; Tile $17 - "N"
    dw `01100011
    dw `01110011
    dw `01111011
    dw `01101111
    dw `01100111
    dw `01100011
    dw `01100011
    dw `00000000

    ; Tile $18 - "U"
    dw `01100110
    dw `01100110
    dw `01100110
    dw `01100110
    dw `01100110
    dw `01100110
    dw `00111100
    dw `00000000

TilesEnd:

Tilemap:
	db $00, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $02, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $08, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $08, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $08, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $0A, $0B, $0C, $0D, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $0E, $0F, $10, $11, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $12, $13, $14, $15, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $16, $17, $18, $19, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $09, $09, $09, $09, $09, $09, $09, $09, $09, $09, $09, $09, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
TilemapEnd:

TilemapMort:
    db $0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,0,0,0,0,0,0,0,0,0,0,0,0
    db $0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,0,0,0,0,0,0,0,0,0,0,0,0
    db $0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,0,0,0,0,0,0,0,0,0,0,0,0
    db $0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,0,0,0,0,0,0,0,0,0,0,0,0
    db $0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,0,0,0,0,0,0,0,0,0,0,0,0
    db $0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,0,0,0,0,0,0,0,0,0,0,0,0
    db $0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,0,0,0,0,0,0,0,0,0,0,0,0
    db $0A,$0A,$0A,$0A,$0A,$0A,$0B,$0C,$0D,$0E,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,0,0,0,0,0,0,0,0,0,0,0,0
    db $0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,0,0,0,0,0,0,0,0,0,0,0,0
    db $0A,$0A,$0A,$0A,$0A,$0A,$0F,$10,$0E,$11,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,0,0,0,0,0,0,0,0,0,0,0,0
    db $0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,0,0,0,0,0,0,0,0,0,0,0,0
    db $0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,0,0,0,0,0,0,0,0,0,0,0,0
    db $0A,$0A,$0A,$12,$11,$0E,$13,$13,$0A,$13,$14,$0C,$11,$14,$0A,$14,$0F,$0A,$0A,$0A,0,0,0,0,0,0,0,0,0,0,0,0
    db $0A,$0A,$0A,$0A,$0A,$0A,$11,$0E,$13,$14,$0C,$11,$14,$0A,$0A,$0A,$0A,$0A,$0A,$0A,0,0,0,0,0,0,0,0,0,0,0,0
    db $0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,0,0,0,0,0,0,0,0,0,0,0,0
    db $0A,$0A,$12,$11,$0E,$13,$13,$0A,$13,$0E,$15,$0E,$16,$14,$0A,$14,$0F,$0A,$0A,$0A,0,0,0,0,0,0,0,0,0,0,0,0
    db $0A,$0A,$0A,$0A,$0A,$0B,$0F,$0A,$14,$0F,$0A,$0D,$0E,$17,$18,$0A,$0A,$0A,$0A,$0A,0,0,0,0,0,0,0,0,0,0,0,0
    db $0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,0,0,0,0,0,0,0,0,0,0,0,0
TilemapMortEnd:

SECTION "Counter", WRAM0
wFrameCounter: db
wFailedCatchBallCounter: db

SECTION "Input Variables", WRAM0
wCurKeys: db
wNewKeys: db

SECTION "Ball Data", WRAM0
wBallMomentumX: db
wBallMomentumY: db
