INCLUDE "hardware.inc"

DEF MENU_CURSOR_TILE       EQU $29
DEF MENU_BLANK_TILE        EQU $0A
DEF MENU_CURSOR_INITIAL_LO EQU $07
DEF MENU_CURSOR_INITIAL_HI EQU $99
DEF MENU_OPTION_DINO       EQU 0
DEF MENU_OPTION_BREAKOUT   EQU 1

SECTION "Header", ROM0[$100]
    jp EntryPoint
    ds $150 - @ ; Make room for the nintendo logo

SECTION "Menu Code", ROM0

; ROM entry point. Boots straight into the game-selection menu.
EntryPoint::
    call WaitVBlank

    ; LCD off so we can copy tiles/tilemap into VRAM safely.
    xor a
    ld [rLCDC], a

    ; Menu uses the breakout/font tile set (it carries the ASCII glyphs and
    ; the cursor icon).
    ld de, BreakoutBgTiles
    ld hl, $9000
    ld bc, BreakoutBgTilesEnd - BreakoutBgTiles
    call MemCopy

    ld de, TilemapMenu
    ld hl, $9800
    ld bc, TilemapMenuEnd - TilemapMenu
    call MemCopy

    call ClearOam

    ld a, LCDC_ON | LCDC_BG_ON
    ld [rLCDC], a

    ld a, %11100100
    ld [rBGP], a

    ; Reset shared state.
    xor a
    ld [wFrameCounter], a
    ld [wCurKeys], a
    ld [wNewKeys], a
    ld [wMenuSelection], a               ; start on the top option (DINO)

    ld a, MENU_CURSOR_INITIAL_LO
    ld [wMenuCursorAddr], a
    ld a, MENU_CURSOR_INITIAL_HI
    ld [wMenuCursorAddr + 1], a

.MenuLoop:
    call WaitVBlank
    call UpdateKeys

    ld a, [wNewKeys]
    and PAD_DOWN
    jr z, .CheckUp
    ld a, [wMenuSelection]
    cp MENU_OPTION_BREAKOUT
    jr z, .CheckUp                       ; already on the bottom option
    ld a, MENU_OPTION_BREAKOUT
    ld [wMenuSelection], a
    call MoveMenuCursorDown

.CheckUp:
    ld a, [wNewKeys]
    and PAD_UP | PAD_A
    jr z, .CheckStart
    ld a, [wMenuSelection]
    or a
    jr z, .CheckStart                    ; already on the top option
    xor a
    ld [wMenuSelection], a
    call MoveMenuCursorUp

.CheckStart:
    ld a, [wCurKeys]
    and PAD_START
    jp z, .MenuLoop

.LaunchSelection:
    ; Fade the menu out to black before swapping tilesets so the LCD-off
    ; flash is hidden and the transition feels intentional.
    ld de, FadeBgpMenuOut
    ld b, 3
    ld h, 6
    call FadeBgp

    ld a, [wMenuSelection]
    or a
    jp z, EntryPointDino
    jp EntryPointBreakout

; Move the on-screen cursor one BG row down, updating the stored address.
MoveMenuCursorDown:
    ld a, [wMenuCursorAddr]
    ld l, a
    ld a, [wMenuCursorAddr + 1]
    ld h, a
    ld a, MENU_BLANK_TILE
    ld [hl], a
    ld de, 32                            ; +1 BG row
    add hl, de
    ld a, MENU_CURSOR_TILE
    ld [hl], a
    ld a, l
    ld [wMenuCursorAddr], a
    ld a, h
    ld [wMenuCursorAddr + 1], a
    ret

; Move the on-screen cursor one BG row up.
MoveMenuCursorUp:
    ld a, [wMenuCursorAddr]
    ld l, a
    ld a, [wMenuCursorAddr + 1]
    ld h, a
    ld a, MENU_BLANK_TILE
    ld [hl], a
    ld de, $FFE0                         ; -32 (one BG row up)
    add hl, de
    ld a, MENU_CURSOR_TILE
    ld [hl], a
    ld a, l
    ld [wMenuCursorAddr], a
    ld a, h
    ld [wMenuCursorAddr + 1], a
    ret

SECTION "Menu WRAM", WRAM0
wMenuSelection:  db
wMenuCursorAddr: dw
