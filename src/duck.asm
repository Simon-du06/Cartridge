DEF DUCK_X            EQU 13
DEF DUCK_START_Y      EQU 93
DEF DUCK_MAX_Y        EQU 93
DEF DUCK_OAM_X        EQU DUCK_X + 8
DEF DUCK_JUMP_FORCE   EQU 7
DEF GRAVITY			  EQU 1
DEF GRAVITY_TICK_RATE EQU 4

SECTION "Duck State", WRAM0
wDuckY: DB
wDuckSpeed: DB
wIsJumping: DB
wDuckGravityTick: DB

SECTION "Duck Logic", ROM0

InitDuck:
	ld a, DUCK_START_Y
	ld [wDuckY], a
	ld a, 1
	ld [wDuckSpeed], a
	ld a, 0
	ld [wIsJumping], a
	ld [wDuckGravityTick], a
	call DrawDuck
	ret

; Update duck Y based on input (X is fixed).
UpdateDuck:
	ld a, [wIsJumping]
	or a
	jp nz, .applyJump

	ld a, [wCurKeys]
	and PAD_UP
	jp z, .jumpOver

	ld a, 1
	ld [wIsJumping], a
	xor a
	ld [wDuckGravityTick], a
	ld a, DUCK_JUMP_FORCE
	ld [wDuckSpeed], a
	jp .applyJump


	; ld a, [wDuckY]
	; cp a, DUCK_MIN_Y
	; jp z, .checkDown
	; dec a
	; ld [wDuckY], a


.applyJump
	ld a, [wDuckSpeed]
	ld b, a
	ld a, [wDuckY]
	sub b
	ld [wDuckY], a

	ld a, [wDuckGravityTick]
	inc a
	cp GRAVITY_TICK_RATE
	jp c, .checkGround
	xor a
	ld [wDuckGravityTick], a
	ld a, [wDuckSpeed]
	sub GRAVITY
	ld [wDuckSpeed], a
	jp .checkGround

.checkGround
	ld [wDuckGravityTick], a

	ld a, [wDuckY]
	cp DUCK_MAX_Y
	jp nc, .land
	jp .jumpOver

.land
	ld a, DUCK_MAX_Y
	ld [wDuckY], a
	xor a
	ld [wDuckSpeed], a
	ld [wIsJumping], a
	ld [wDuckGravityTick], a
	ret

.jumpOver
	ret


; Draw duck as a 3x3 group of 8x8 OBJ sprites using a compact layout table.
DrawDuck:
	ld hl, STARTOF(OAM)
	call DrawDuckTopRow
	call DrawDuckMiddleRow
	call DrawDuckBottomRow
	ret

DrawDuckTopRow:
	ld a, [wDuckY]
	add a, 16
	ld d, a

	ld a, d
	ld c, DUCK_OAM_X
	ld b, 0
	call DrawObj

	ld a, d
	ld c, DUCK_OAM_X + 8
	ld b, 1
	call DrawObj

	ld a, d
	ld c, DUCK_OAM_X + 16
	ld b, 2
	call DrawObj
	ret

DrawDuckMiddleRow:
	ld a, [wDuckY]
	add a, 24
	ld d, a

	ld a, d
	ld c, DUCK_OAM_X
	ld b, 3
	call DrawObj

	ld a, d
	ld c, DUCK_OAM_X + 8
	ld b, 4
	call DrawObj

	ld a, d
	ld c, DUCK_OAM_X + 16
	ld b, 5
	call DrawObj
	ret

DrawDuckBottomRow:
	ld a, [wDuckY]
	add a, 32
	ld d, a

	ld a, d
	ld c, DUCK_OAM_X
	ld b, 6
	call DrawObj

	ld a, d
	ld c, DUCK_OAM_X + 8
	ld b, 7
	call DrawObj

	ld a, d
	ld c, DUCK_OAM_X + 16
	ld b, 8
	call DrawObj
	ret

; Write one OBJ entry at [HL]: Y, X, tile, attrs(0)
; @param a: Y (OAM space)
; @param c: X (OAM space)
; @param b: tile index
; @param hl: destination OAM pointer
DrawObj:
	ld [hli], a
	ld a, c
	ld [hli], a
	ld a, b
	ld [hli], a
	xor a
	ld [hli], a
	ret
