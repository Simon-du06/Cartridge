INCLUDE "hardware.inc"

SECTION "Common Code", ROM0

; Wait for the start of VBlank. Returns once LY just rolled into the vblank
; window, leaving the maximum amount of time before vblank ends.
WaitVBlank::
    ld a, [rLY]
    cp 144
    jp nc, WaitVBlank
.wait
    ld a, [rLY]
    cp 144
    jp c, .wait
    ret

; Copy bytes from one area to another.
; @param de: source
; @param hl: destination
; @param bc: length
MemCopy::
    ld a, [de]
    ld [hli], a
    inc de
    dec bc
    ld a, b
    or a, c
    jp nz, MemCopy
    ret

; Clear the 160 bytes of OAM ($FE00..$FE9F).
ClearOam::
    xor a
    ld b, 160
    ld hl, STARTOF(OAM)
.loop:
    ld [hli], a
    dec b
    jp nz, .loop
    ret

; Read controller and update wCurKeys / wNewKeys (rising-edge mask).
UpdateKeys::
    ld a, JOYP_GET_BUTTONS
    call .onenibble
    ld b, a

    ld a, JOYP_GET_CTRL_PAD
    call .onenibble
    swap a
    xor a, b
    ld b, a

    ld a, JOYP_GET_NONE
    ldh [rJOYP], a

    ld a, [wCurKeys]
    xor a, b
    and a, b
    ld [wNewKeys], a
    ld a, b
    ld [wCurKeys], a
    ret

.onenibble
    ldh [rJOYP], a
    call .knownret
    ldh a, [rJOYP]
    ldh a, [rJOYP]
    ldh a, [rJOYP]
    or a, $F0
.knownret
    ret

SECTION "Common WRAM", WRAM0
wFrameCounter:: db
wCurKeys::      db
wNewKeys::      db
