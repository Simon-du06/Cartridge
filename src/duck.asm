DEF DUCK_X            EQU 13
DEF DUCK_START_Y      EQU 93
DEF DUCK_MIN_Y        EQU 0
DEF DUCK_MAX_Y        EQU 93
DEF DUCK_OAM_X        EQU DUCK_X + 8

SECTION "Duck State", WRAM0
wDuckY: db

SECTION "Duck Logic", ROM0

InitDuck:
	ld a, DUCK_START_Y
	ld [wDuckY], a
	call DrawDuck
	ret

; Update duck Y based on input (X is fixed).
UpdateDuck:
	ld a, [wCurKeys]
	and a, PAD_UP
	jp z, .checkDown

	ld a, [wDuckY]
	cp a, DUCK_MIN_Y
	jp z, .checkDown
	dec a
	ld [wDuckY], a

.checkDown
	ld a, [wCurKeys]
	and a, PAD_DOWN
	ret z

	ld a, [wDuckY]
	cp a, DUCK_MAX_Y
	ret z
	inc a
	ld [wDuckY], a
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
	xor a, a
	ld [hli], a
	ret
