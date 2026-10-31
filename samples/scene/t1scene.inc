; Full original 4KB scene/snapshot projector in LC bank 1 $D000-$DFFF.
; Restore HGR page: common LC $E000-$FFFF. LC bank 2 is untouched.
; Main resident gateway/sound/workspace: $8E00-$95FF (MAXFILES3 or less).
T1SC_CALL = $8E00
T1SC_SIGNATURE = $8E04          ; "T1SC",1
SCENE_HEADER = $0300           ; word: page-aligned SN header
SCENE_BODY = $0302             ; word: filled by PLAY
FRAME_LIMIT = $0304            ; word: $FFFF = until end
BACKGROUND = $0306             ; word: uncompressed 8192-byte HGR source
CHARSET = $0308                ; word: optional CS file
SNAPSHOT = $030A               ; byte: raw DRAW command snapshot
WIN_LEFT = $030C
WIN_RIGHT = $030D              ; exclusive byte column, usually 40
WIN_TOP = $030E
WIN_BOTTOM = $030F             ; exclusive scanline, usually 192
FRAME_CALLBACK = $0310         ; word: called under LC mapping
SOUND_CALLBACK = $0312         ; word: default is relocated original sound
SCENE_TEMPO = $0314            ; filled from SN header by PLAY
FIRST_PAGE = $0315             ; $20/$40
ACTOR_COUNT = $038D
ACTOR_TABLE = $038E            ; [snapshot count, pointer lo, pointer hi] * N
CMD_CLEAR = 0                  ; clear pages 1/2/restore, reset rect lists
CMD_PLAY = 1                   ; play SN using actor table; A=0 end/1 ESC
CMD_BACKGROUND = 2             ; copy raw HGR to restore + pages 1/2
CMD_DRAW = 3                   ; raw original D027 API, caller supplies its ZP
