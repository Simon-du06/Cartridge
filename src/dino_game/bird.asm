DEF BIRD_Y      EQU 86
DEF BIRD_START_X EQU 93
DEF BIRD_VRAM_ADDR EQU $8210
DEF BIRD_TILE_BASE EQU (BIRD_VRAM_ADDR - $8000) / 16
DEF BIRD_OAM_ADDR  EQU $C000 + (17 * 4)
DEF BIRD_HITBOX_X  EQU 16
DEF BIRD_HITBOX_Y  EQU 16
DEF BIRD_HITBOX_W  EQU 4
DEF BIRD_HITBOX_H  EQU 12

SECTION "Bird State", WRAM0
wBirdX: DB

SECTION "Bird Logic", ROM0

InitBird:
    ld a, BIRD_START_X
    ld [wBirdX], a
    ret

UpdateBird:
    ; The bird sits on the ground, so it scrolls with the ground speed (3 pixels)
    ld a, [wBirdX]
    sub a, 2
    ld [wBirdX], a

DrawBird:
    ld a, [wBirdX]
    add a, 16

    ld c, a
    ld a, BIRD_Y
    add a, 16
    ld b, BIRD_TILE_BASE
    ld hl, BIRD_OAM_ADDR
    call Draw2x2Obj
    ret



; Returns carry set when the duck overlaps the narrow bird hitbox.
CheckBirdCollision:
	ld a, [wBirdX]
	add a, BIRD_HITBOX_X
	ld b, a
	add a, BIRD_HITBOX_W
	ld c, a

	ld a, DUCK_X
	ld d, a
	add a, 18
	ld e, a

	ld a, b
	cp e
	ret nc
	ld a, d
	cp c
	ret nc

	ld a, [wDuckY]
	ld d, a
	add a, 16
	ld e, a

	ld a, BIRD_Y + BIRD_HITBOX_Y
	ld b, a
	add a, BIRD_HITBOX_H
	ld c, a

	ld a, b
	cp e
	ret nc
	ld a, d
	cp c
	ret nc

	scf
	ret

; Draw a 2*16 block of 8x8 OBJ sprites.
; @param a: top-left Y (OAM space)
; @param c: top-left X (OAM space)
; @param b: first tile index (uses b..b+8)
; @param hl: destination OAM pointer
Draw2x2Obj:
	ld d, a
	ld e, c
	call Draw2ObjRow

	ld a, d
	add a, 8
	ld d, a
	call Draw2ObjRow
	ret
