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

; Copy a $FF-terminated tile-index string to the BG tilemap (or anywhere).
; Strings are produced by `db "..."` in source files that include
; src/text.inc -- the CHARMAP there translates each ASCII byte to the
; matching font tile index, so the assembled bytes are already what we
; want to push into VRAM.
;
; Must be called during VBlank if hl points into VRAM ($8000..$9FFF).
;
; @param de: pointer to the $FF-terminated string
; @param hl: destination pointer (e.g. $9800 + col + row*32)
DrawText::
.loop:
    ld a, [de]
    cp $FF
    ret z
    ld [hli], a
    inc de
    jr .loop


; Step BGP through a sequence of palette bytes, holding each one for H
; vblanks. Used for fade-in/fade-out transitions: pre-set rBGP to the
; "from" value yourself, then call this with the path toward the "to" value.
;
; @param de: pointer to a packed sequence of B BGP bytes (read in order)
; @param b:  number of steps in the sequence
; @param h:  vblanks to hold each step (higher = slower fade)
FadeBgp::
.next:
    ld a, [de]
    ldh [rBGP], a
    inc de
    ld c, h
.wait:
    call WaitVBlank
    dec c
    jr nz, .wait
    dec b
    jr nz, .next
    ret

; --- Pre-baked fade tables --------------------------------------------------
; Each step lightens or darkens every palette slot by one DMG color level,
; so the perceived motion is a smooth crossfade.
;
; Menu / breakout normal BGP is $E4 (identity). Path: $E4 -> $F9 -> $FE -> $FF.
; Dino normal BGP is $1B (inverted).            Path: $1B -> $6F -> $BF -> $FF.

FadeBgpMenuOut::    db $F9, $FE, $FF
FadeBgpBreakoutIn:: db $FE, $F9, $E4
FadeBgpDinoIn::     db $BF, $6F, $1B

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
