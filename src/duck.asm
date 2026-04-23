DEF DUCK_X            EQU 13
DEF DUCK_START_Y      EQU 93
DEF DUCK_MAX_Y        EQU 93
DEF DUCK_OAM_X        EQU DUCK_X + 8
DEF DUCK_JUMP_FORCE   EQU 4
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
	ld [wDuckGravityTick], a
	cp GRAVITY_TICK_RATE
	jp c, .checkGround
	xor a
	ld [wDuckGravityTick], a
	ld a, [wDuckSpeed]
	sub GRAVITY
	ld [wDuckSpeed], a
	jp .checkGround

.checkGround
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
	ld a, [wDuckY]
	add a, 16
	ld c, DUCK_OAM_X
	ld b, 0
	ld hl, STARTOF(OAM)
	call Draw3x3Obj
	ret

; Draw a 3x3 block of 8x8 OBJ sprites.
; @param a: top-left Y (OAM space)
; @param c: top-left X (OAM space)
; @param b: first tile index (uses b..b+8)
; @param hl: destination OAM pointer
Draw3x3Obj:
	ld d, a
	ld e, c
	call Draw3ObjRow

	ld a, d
	add a, 8
	ld d, a
	call Draw3ObjRow

	ld a, d
	add a, 8
	ld d, a
	call Draw3ObjRow
	ret

; Draw one row of 3 OBJ sprites at Y=d, starting X=e.
; @param d: row Y (OAM space)
; @param e: row start X (OAM space)
; @param b: next tile index (incremented by 3)
; @param hl: destination OAM pointer
Draw3ObjRow:
	ld c, e
	ld a, d
	call DrawObj
	inc b

	ld a, e
	add a, 8
	ld c, a
	ld a, d
	call DrawObj
	inc b

	ld a, e
	add a, 16
	ld c, a
	ld a, d
	call DrawObj
	inc b
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
