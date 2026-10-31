; THUNDER.JOY — 64K Apple II / DOS 3.3 / 6502 / ca65.
; 조이스틱 X축으로 좌우 이동하며 HGR page 1/2를 교대 표시한다.
;
;   BRUN T1LC.INSTALL
;   BLOAD AC.THUNDER RUN,A$8000
;   BLOAD AC.THUNDER LEFT,A$6F00
;   BRUN THUNDER.JOY                 ; 또는 BLOAD 후 JSR $6000
;
; ESC로 텍스트/DOS 복귀. A=0 정상, $FE 미설치, $FD 액터 개수 불일치,
; $FF 그리기 오류. 호출자의 ZP 전체·X/Y·I/D 등을 복원한다.
;
; 메모리 배치:
;   $0300-$03CF : T1LC 게이트. 실제 그리기 호출은 JSR $0300.
;   $0800-$1FFF : BASIC 프로그램·변수·문자열. HIMEM:8192로 보호한다.
;   $2000-$3FFF : HGR page 1
;   $4000-$5FFF : HGR page 2
;   $6000-$6376 : 이 프로그램. 설치기의 임시 영역을 재사용한다.
;   $6F00-$7F94 : 왼쪽 액터. 프로그램·화면·DOS와 겹치지 않는다.
;   $8000-$8F88 : 오른쪽 원본 액터
;   LC bank 1   : 렌더러 $D000-$D7FF, 작업 영역 $D800-$D8FF
;
; 원본/반전 액터의 12개 스냅샷을 직접 선택한다. AC 파일의 명명 액션
; 테이블이나 원본 액션 dx를 사용하지 않고 일정한 4픽셀씩 이동한다.
; 반전본은 검정 배경용이다. 별도의 배경 복원 버퍼는 사용하지 않는다.
; 이 기본 예제는 수직 귀선 동기화를 하지 않으므로 속도는 가변적이다.
.setcpu "6502"
.segment "CODE"
; 원본 12포즈 전체의 공통 외곽을 측정한 상수. 외부 include 없이 빌드 가능.
PLAYER_WIDTH = 70
X_MAX = 280-PLAYER_WIDTH            ; 캐릭터 전체가 화면 안에 남는 최대 X=210
RIGHT_LEFT_OFFSET = 1              ; 원본은 앵커보다 1픽셀 오른쪽에서 시작
.export start, frame_loop, shown, frames, player_x, facing, pose, joy_x
.export stage, result, motion, clear_band

DRAWSNAP = $0300
AC_LOC = $0303
SNAPSHOT = $0305
X_COORD = $0306
Y_COORD = $0308
WRAPFLAG = $030A
WINDTOP = $030B
WINDBTM = $030C
WINDLEFT = $030D
WINDRIGHT = $030E
DRAW_PAGE = $E6                     ; 표시 페이지가 아니라 '그릴' 페이지 상위 주소
ACTOR_RIGHT = $8000
ACTOR_LEFT = $6F00
PREAD = $FB1E                       ; 모니터 ROM: X=축 번호, Y=0..255 반환
JOY_LEFT = 96
JOY_RIGHT = 160                     ; 96..159는 중립 데드존
MOVE_STEP = 4
PLAYER_Y = 116
BAND_TOP = 104
BAND_ROWS = 60                      ; y=104..163만 매 프레임 지움
FLOOR_Y = 164                       ; 바닥선은 두 페이지에 한 번만 그림
FLOOR_OFF = ((FLOOR_Y & 7) << 10) | (((FLOOR_Y >> 3) & 7) << 7) | ((FLOOR_Y >> 6) * 40)

start:                             ; 링크 주소 $6000
        ; DOS/호출자 상태를 보관한다. $26/$27/$E6 및 렌더러가 사용하는
        ; ZP를 포함해 256바이트 전부 저장하고 종료 시 복원한다.
        php
        txa
        pha
        tya
        pha
        cld
        ldx #0
save_zp:
        lda $00,x
        sta saved_zp,x
        inx
        bne save_zp
        lda #0
        sta stage
        sta result
        sta frames
        sta frames+1
        sta facing                 ; 0=오른쪽, 1=왼쪽
        sta motion                 ; 0=정지, 1=오른쪽, $FF=왼쪽
        ; 설치 완료 서명 "T1LC",1을 확인한다. 액터 검사는 개수만 확인하며
        ; 손상된 AC 파일 전체를 검사하는 검증기는 아니다.
        ldx #4
check_install:
        lda $03C8,x
        cmp signature,x
        beq install_ok
        lda #$FE
        jmp fail
install_ok:
        dex
        bpl check_install
        lda ACTOR_RIGHT
        cmp #12
        bne bad_actor
        lda ACTOR_LEFT
        cmp #12
        beq actors_ok
bad_actor:
        lda #$FD
        jmp fail
actors_ok:
        lda #100
        sta player_x
        lda #1
        sta pose
        lda #0
        ; 화면 밖은 랩하지 않고 클리핑. 윈도 하단/우단은 끝 다음 값이다.
        sta WRAPFLAG
        sta WINDTOP
        sta WINDLEFT
        sta Y_COORD+1
        lda #192
        sta WINDBTM
        lda #40
        sta WINDRIGHT
        lda #PLAYER_Y
        sta Y_COORD

        ; 시작할 때만 두 페이지의 8KB를 초기화. 이후에는 캐릭터 띠만 지운다.
        lda #$20
        sta DRAW_PAGE
        jsr clear_page
        jsr floor_line
        lda #$40
        sta DRAW_PAGE
        jsr clear_page
        jsr floor_line
        lda #$20
        sta DRAW_PAGE
        jsr draw_player
        beq initial_ok
        jmp fail
initial_ok:
        bit $C052                  ; 전체 화면
        bit $C057                  ; HGR
        bit $C054                  ; page 1 표시
        bit $C050                  ; 그래픽 모드
        bit $C010                  ; 시작 전 키 스트로브 정리
        lda #$40
        sta DRAW_PAGE              ; 첫 프레임은 숨겨진 page 2에 그림
        lda #1
        sta stage

frame_loop:
        lda $C000
        bpl read_joystick
        bit $C010
        cmp #$9B                   ; ESC
        bne read_joystick
        jmp finish

read_joystick:
        ldx #0                     ; paddle 0 = 조이스틱 가로축
        jsr PREAD                  ; ROM이 $C070 트리거 후 $C064 시간을 측정
        sty joy_x
        lda #0
        sta motion
        cpy #JOY_LEFT
        bcc move_left
        cpy #JOY_RIGHT
        bcs move_right
        jmp render_frame           ; 중립: 좌표·방향 유지, 포즈는 계속 진행

move_right:
        lda #1
        sta motion
        lda #0
        sta facing
        clc
        lda player_x
        adc #MOVE_STEP
        cmp #X_MAX+1               ; 전체 스프라이트 폭까지 고려한 오른쪽 경계
        bcc set_x
        lda #X_MAX
        jmp set_x
move_left:
        lda #$FF
        sta motion
        lda #1
        sta facing
        sec
        lda player_x
        sbc #MOVE_STEP
        bcs set_x
        lda #0                     ; 왼쪽 끝은 0에 고정
set_x:
        sta player_x

render_frame:
        ; 조이스틱 입력과 애니메이션을 분리한다. 중립에서도 매 프레임
        ; 포즈를 1..12로 순환하므로 마지막 방향으로 제자리 달리기를 한다.
        inc pose
        lda pose
        cmp #13
        bcc pose_ready
        lda #1
        sta pose

pose_ready:
        ; DRAW_PAGE는 항상 현재 표시 중인 페이지의 반대편이다.
        ; 그 페이지의 이전 캐릭터를 지우고 새 위치/포즈를 완성한다.
        ; 이전 프레임의 캐릭터는 두 페이지 각각에 남으므로, 표시 화면을
        ; 지우지 않고 매번 '그릴 페이지'의 캐릭터 띠만 지우는 것이 핵심이다.
        jsr clear_band
        jsr draw_player
        beq draw_ok
        jmp fail
draw_ok:
        lda DRAW_PAGE
        cmp #$20
        beq show_page1
        bit $C055                  ; 완성된 page 2를 표시
        jmp shown
show_page1:
        bit $C054                  ; 완성된 page 1을 표시
shown:
        lda DRAW_PAGE
        eor #$60                   ; $20 <-> $40: 다음 프레임의 숨겨진 페이지
        sta DRAW_PAGE
        inc frames
        bne next_frame
        inc frames+1
next_frame:
        jmp frame_loop

draw_player:
        ; 공개 파라미터는 게이트 $0300 뒤의 $0303-$030E에 둔다.
        ; Y/윈도/wrap은 초기화 후 고정, 여기서는 포즈/액터/X만 갱신한다.
        lda pose
        sta SNAPSHOT
        lda facing
        bne use_left
        lda #<ACTOR_RIGHT
        sta AC_LOC
        lda #>ACTOR_RIGHT
        sta AC_LOC+1
        ; player_x는 그림 전체의 왼쪽 위치이다. 원본 액터는 앵커에서
        ; RIGHT_LEFT_OFFSET만큼 오른쪽에서 시작하므로 그 차이를 뺀다.
        sec
        lda player_x
        sbc #RIGHT_LEFT_OFFSET
        sta X_COORD
        lda #0
        sbc #0                     ; x=0일 때 -1 같은 signed 좌표도 올바르게 전달
        sta X_COORD+1
        jmp DRAWSNAP               ; 게이트가 ROM 복귀 후 호출자에게 RTS
use_left:
        ; 반전 파일은 헤더 dx=+1로 색상 위상을 보정해 두었다.
        ; 여기서 X를 1 빼면 보정이 취소되므로 player_x를 그대로 전달한다.
        lda #<ACTOR_LEFT
        sta AC_LOC
        lda #>ACTOR_LEFT
        sta AC_LOC+1
        lda player_x
        sta X_COORD
        lda #0
        sta X_COORD+1
        jmp DRAWSNAP

clear_page:                        ; 시작할 때만 8KB 전체 클리어
        lda #0
        sta $26
        lda DRAW_PAGE
        sta $27
        ldx #32
        ldy #0
        lda #0
clear_page_loop:
        sta ($26),y
        iny
        bne clear_page_loop
        inc $27
        dex
        bne clear_page_loop
        rts

clear_band:                        ; HGR 줄 주소는 선형이 아니므로 표를 사용
        ldx #0
band_line:
        lda band_lo,x
        sta $26
        lda band_hi,x
        ora DRAW_PAGE              ; 표의 $00-$1F에 $20/$40을 OR해 페이지 선택
        sta $27
        ldy #39
        lda #0
band_byte:
        sta ($26),y
        dey
        bpl band_byte
        inx
        cpx #BAND_ROWS
        bne band_line
        rts

floor_line:
        lda #<FLOOR_OFF
        sta $26
        lda #>FLOOR_OFF
        ora DRAW_PAGE
        sta $27
        ldy #39
        lda #$7F                   ; 바닥선: 연속된 흰 픽셀
floor_byte:
        sta ($26),y
        dey
        bpl floor_byte
        rts

fail:
        sta result
finish:
        lda stage
        beq restore
        lda #2
        sta stage                  ; 이후 화면 선택은 실행 중 페이지 플립과 구분
        bit $C051                  ; 텍스트 모드로 복귀
        bit $C054
        bit $C053
restore:
        lda #2
        sta stage
        ldx #0
restore_zp:
        lda saved_zp,x
        sta $00,x
        inx
        bne restore_zp
        pla
        tay
        pla
        tax
        plp
        lda result
        rts

; 페이지를 제외한 HGR 주소: y&7, y/8, y/64의 인터리브를 풀어 놓은 표.
band_lo:
.repeat BAND_ROWS, I
        .byte <((((BAND_TOP+I)&7)<<10) | ((((BAND_TOP+I)>>3)&7)<<7) | (((BAND_TOP+I)>>6)*40))
.endrepeat
band_hi:
.repeat BAND_ROWS, I
        .byte >((((BAND_TOP+I)&7)<<10) | ((((BAND_TOP+I)>>3)&7)<<7) | (((BAND_TOP+I)>>6)*40))
.endrepeat
signature: .byte "T1LC",1
stage: .byte 0                     ; 0=초기화, 1=실행, 2=복귀
result: .byte 0
frames: .word 0
player_x: .byte 100
facing: .byte 0
pose: .byte 1
joy_x: .byte 128
motion: .byte 0
saved_zp: .res 256                  ; ZP 백업도 프로그램 바이너리 안에 확보
