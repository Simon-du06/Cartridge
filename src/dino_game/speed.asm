SECTION "Dino Speed Logic", ROM0

; Initializes the speed variables. Call this when starting a new game (EntryPointDino).
InitSpeedSystem::
    ; Set starting speed to 1.5 pixels per frame
    ; Int = 1, Fraction = 128 (128/256 = 0.5)
    ld a, 1
    ld [wGameSpeedInt], a
    ld a, 128
    ld [wGameSpeedFraction], a
    
    ; Reset accumulators and timers
    xor a 
    ld [wScrollAccumFraction], a
    ld [wSpeedTimer], a
    ret


; Calculates how many pixels the ground should move this frame.
; Returns: Register 'a' contains the number of pixels to move.
UpdateScroll::
    ; 1. Add the speed fraction to the accumulator fraction
    ld a, [wScrollAccumFraction]
    ld hl, wGameSpeedFraction
    add a, [hl]
    ld [wScrollAccumFraction], a
    
    ; 2. Load the integer speed
    ld a, [wGameSpeedInt]
    
    ; 3. Add carry if the fraction overflowed
    ; If fraction addition above crossed 255, the Carry flag is set.
    ; adc a, 0 adds 0 + Carry flag to 'a'.
    adc a, 0
    
    ; 'a' now contains the exact pixel movement for this frame.
    ld [wCurrentFrameSpeed], a
    ret


; Increases the game speed gradually. Call this once per frame (in DinoMain).
IncreaseSpeed::
    ; 1. Increment our 60-frame timer
    ld a, [wSpeedTimer]
    inc a
    cp 60
    jr nz, .updateTimer  ; If not 60 yet, just save it and exit
    
    ; 2. 60 frames have passed, reset timer to 0
    xor a
    ld [wSpeedTimer], a
    
    ; Check if speed is already 3.75 (Int=3, Fraction=192)
    ld a, [wGameSpeedInt]
    cp 3
    jr c, .increase
    jr nz, .done
    ld a, [wGameSpeedFraction]
    cp 192
    jr nc, .done

.increase:
    ; 3. Increase the fractional speed by a small amount
    ; e.g., 16/256 = +0.0625 pixels per frame every second
    ld a, [wGameSpeedFraction]
    add a, 16
    ld [wGameSpeedFraction], a
    
    ; 4. If the fractional speed overflows, carry it over to the integer part
    ; (e.g., speed goes from 1.95 to 2.01)
    jr nc, .done
    ld a, [wGameSpeedInt]
    inc a
    ld [wGameSpeedInt], a
    jr .done

.updateTimer:
    ld [wSpeedTimer], a
.done:
    ret


SECTION "Dino Speed Variables", WRAM0
wGameSpeedInt::        db ; Integer speed (e.g., 1 pixel)
wGameSpeedFraction::   db ; Fractional speed (e.g., 128 = 0.5 pixels)
wScrollAccumFraction:: db ; Stores the accumulated fractional pixels
wSpeedTimer::          db ; Counts 60 frames (1 second) to trigger speedups
wCurrentFrameSpeed::   db ; Number of pixels the ground/objects move this frame