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

; Power on the APU and route every channel to both speakers at full volume.
; Call once during boot before triggering any sound.
InitAudio::
    ld a, $80
    ldh [rNR52], a       ; APU master power on
    ld a, $FF
    ldh [rNR51], a       ; CH1..4 -> both speakers
    ld a, $77
    ldh [rNR50], a       ; max volume left + right
    ret

; Fire-and-forget jump blip on CH1 (square wave). Mirrors the chrome dino's
; short ascending pluck: max-volume tone with a fast envelope decay so the
; APU silences itself a few frames later -- no per-frame state needed.
PlayJumpBeep::
    xor a
    ldh [rNR10], a       ; no frequency sweep
    ld a, $80
    ldh [rNR11], a       ; 50% duty, length disabled
    ld a, $F1
    ldh [rNR12], a       ; envelope: full volume, decreasing, fast decay
    ld a, LOW(1750)
    ldh [rNR13], a
    ld a, HIGH(1750) | $80
    ldh [rNR14], a       ; trigger (bit 7) + frequency high bits
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
