DEF CACTUS_Y      EQU 86
DEF CACTUS_START_X EQU 93
DEF CACTUS_VRAM_ADDR EQU $8190
DEF CACTUS_TILE_BASE EQU (CACTUS_VRAM_ADDR - $8000) / 16
DEF CACTUS_OAM_ADDR  EQU $FE00 + (9 * 4)

SECTION "Cactus State", WRAM0
wCactusX: DB

SECTION "Cactus Logic", ROM0

InitCactus:
    ld a, CACTUS_START_X
    ld [wCactusX], a
    ret

UpdateCactus:
    ld a, [rSCX]
    ld hl, wScrollTick
    add a, [hl]
    ld [wCactusX], a

DrawCactus:
    ld a, [wCactusX]
    add a, 16

    ld c, a
    ld a, CACTUS_Y
    add a, 16
    ld b, CACTUS_TILE_BASE
    ld hl, CACTUS_OAM_ADDR
    call Draw4x2Obj
    ret

; Draw a 3x3 block of 8x8 OBJ sprites.
; @param a: top-left Y (OAM space)
; @param c: top-left X (OAM space)
; @param b: first tile index (uses b..b+8)
; @param hl: destination OAM pointer
Draw4x2Obj:
	ld d, a
	ld e, c
	call Draw2ObjRow

	ld a, d
	add a, 8
	ld d, a
	call Draw2ObjRow

	ld a, d
	add a, 8
	ld d, a
	call Draw2ObjRow

    ld a, d
	add a, 8
	ld d, a
	call Draw2ObjRow
	ret

; Draw one row of 3 OBJ sprites at Y=d, starting X=e.
; @param d: row Y (OAM space)
; @param e: row start X (OAM space)
; @param b: next tile index (incremented by 3)
; @param hl: destination OAM pointer
Draw2ObjRow:
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
	ret