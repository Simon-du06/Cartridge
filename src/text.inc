; Character map for the cartridge font tile set. Each glyph is mapped to the
; tile index it actually lives at in BreakoutBgTiles, so a string literal
; like `db "GAME OVER"` assembles directly to the matching tile bytes.
;
; The font is uppercase only -- lowercase letters are aliased to the same
; tile indices as their uppercase counterpart so case is forgiving.
;
; Use $FF as the end-of-string terminator for runtime DrawText calls,
; since it is outside the loaded tile range.

CHARMAP " ", $0A
CHARMAP "G", $0B
CHARMAP "A", $0C
CHARMAP "M", $0D
CHARMAP "E", $0E
CHARMAP "O", $0F
CHARMAP "V", $10
CHARMAP "R", $11
CHARMAP "P", $12
CHARMAP "S", $13
CHARMAP "T", $14
CHARMAP "L", $15
CHARMAP "C", $16
CHARMAP "N", $17
CHARMAP "U", $18
CHARMAP "0", $19
CHARMAP "1", $1A
CHARMAP "2", $1B
CHARMAP "3", $1C
CHARMAP "4", $1D
CHARMAP "5", $1E
CHARMAP "6", $1F
CHARMAP "7", $20
CHARMAP "8", $21
CHARMAP "9", $22
CHARMAP "B", $2A
CHARMAP "D", $2B
CHARMAP "I", $2C
CHARMAP "K", $2D

; Lowercase aliases (same tile index as uppercase glyph).
CHARMAP "g", $0B
CHARMAP "a", $0C
CHARMAP "m", $0D
CHARMAP "e", $0E
CHARMAP "o", $0F
CHARMAP "v", $10
CHARMAP "r", $11
CHARMAP "p", $12
CHARMAP "s", $13
CHARMAP "t", $14
CHARMAP "l", $15
CHARMAP "c", $16
CHARMAP "n", $17
CHARMAP "u", $18
CHARMAP "b", $2A
CHARMAP "d", $2B
CHARMAP "i", $2C
CHARMAP "k", $2D
