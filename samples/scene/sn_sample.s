; SN.SAMPLE — 어셈블리에서 원본 Take 1 SN.TK를 재생하는 전체 예제.
;
; BRUN T1SC.INSTALL            ; 전체 4KB 프로젝터를 LC bank1에 설치
; BLOAD SN.TK,A$6200           ; 헤더는 256바이트 경계, 본체는 $6300
; BLOAD AC.PTK4,A$6800
; BLOAD HGR.TK,A$6E00          ; BK.TK를 오프라인 해제한 원본 배경 8KB
; BLOAD SN.SAMPLE,A$6000
; CALL 24576                  ; 또는 어셈블리 JSR $6000
;
; 배경 설정 후 T1SC_CALL의 PLAY를 한 번 호출한다. 포즈·좌표·템포·페이지
; 교대·배경 복원은 원본 엔진이 SN 레코드대로 실행한다. ESC로 중단 가능.
; 재생 완료 후 마지막 화면을 유지하며 키를 기다리고, 텍스트/BASIC으로 복귀.
; BASIC은 HIMEM:8192로 프로그램·변수·문자열을 $2000 아래에 둔다.
.setcpu "6502"
.segment "CODE"
.include "t1scene.inc"
.export start, stage, result
SN_FILE = $6200
ACTOR = $6800
HGR_SOURCE = $6E00
start:
        php
        txa
        pha
        tya
        pha
        cld
        lda #0
        sta stage
        sta result
        ldx #4
check_install:
        lda T1SC_SIGNATURE,x
        cmp signature,x
        beq signature_ok
        jmp missing
signature_ok:
        dex
        bpl check_install
        ; 공개 파라미터 설정. DOS 벡터 $03D0+는 건드리지 않는다.
        ldx #$CF
        lda #0
clear_params:
        sta $0300,x
        dex
        cpx #$FF
        bne clear_params
        lda #<SN_FILE
        sta SCENE_HEADER
        lda #>SN_FILE
        sta SCENE_HEADER+1
        lda #$FF
        sta FRAME_LIMIT
        sta FRAME_LIMIT+1
        lda #<HGR_SOURCE
        sta BACKGROUND
        lda #>HGR_SOURCE
        sta BACKGROUND+1
        lda #40
        sta WIN_RIGHT
        lda #192
        sta WIN_BOTTOM
        lda #$20
        sta FIRST_PAGE
        lda #<callback
        sta FRAME_CALLBACK
        lda #>callback
        sta FRAME_CALLBACK+1
        lda #$00
        sta SOUND_CALLBACK
        lda #$90               ; relocated original 18-effect sound entry
        sta SOUND_CALLBACK+1
        lda #1
        sta ACTOR_COUNT
        lda ACTOR
        sta ACTOR_TABLE
        lda #<ACTOR
        sta ACTOR_TABLE+1
        lda #>ACTOR
        sta ACTOR_TABLE+2
        lda #CMD_BACKGROUND
        jsr T1SC_CALL
        cmp #$FE
        bcs fail
        bit $C052              ; full HGR screen
        bit $C010
        lda #1
        sta stage
        lda #CMD_PLAY
        jsr T1SC_CALL          ; all scene frames handled by original $D024 loop
        sta result
        cmp #$FE
        bcs finish
        cmp #1                 ; ESC: return immediately, no extra key required
        beq finish
        lda #2
        sta stage
wait_key:
        lda $C000
        bpl wait_key
        bit $C010
        jmp finish
missing:
        lda #$FE
fail:
        sta result
finish:
        lda #3
        sta stage
        bit $C051
        bit $C054
        bit $C053
        pla
        tay
        pla
        tax
        plp
        lda result
        rts
callback:
        rts
signature: .byte "T1SC",1
stage: .byte 0                  ; 0=setup, 1=playing, 2=final image, 3=returned
result: .byte 0                 ; 0=end, 1=ESC, $FE=not installed
        .assert *-start <= $0200, error, "sample overlaps SN.TK"
