# Take 1 — Apple II 어셈블리 샘플

**64K Apple II와 DOS 3.3 호환 환경**에서 Take 1 액터와 씬을 실행하는 예제입니다.
바로 실행할 수 있는 샘플 디스크와, 프로그램을 읽고 응용하기 위한 주석 달린 소스를 제공합니다.

## 샘플 디스크

**[take1-samples.dsk 다운로드](disk/take1-samples.dsk)** — 140KB, DOS 섹터 순서.

디스크로 부팅하면 **SN 씬 재생 예제**가 자동으로 시작됩니다.
장면이 끝난 뒤 아무 키를 누르면 BASIC으로 돌아옵니다. 재생 중에는 ESC로 중단할 수 있습니다.

BASIC에서 예제를 선택해 실행할 수도 있습니다.

```text
RUN HELLO
RUN JOYSTICK CONTROL
```

| 프로그램 | 내용 | 소스와 해설 |
|---|---|---|
| `HELLO` | 어셈블리에서 Take 1 엔진을 호출하여 로고 씬 재생 | [SN 씬 예제](samples/scene/README.md) |
| `JOYSTICK CONTROL` | 좌우 달리기·중립 제자리 달리기·화면 1/2 교대 | [조이스틱 예제](samples/joystick/README.md) |

Apple II 에뮬레이터 또는 실제 Apple II에서 사용합니다. 언어 카드 RAM을 포함한
64KB가 필요합니다. 조이스틱 예제는 Apple II의 paddle 0 가로축을 사용합니다.

## 실행 화면

샘플 디스크를 64K Apple IIe 환경의 MAME에서 실행한 화면입니다.

**SN 씬 재생** — 로고 씬이 끝난 뒤 마지막 화면을 유지합니다.

![SN 씬 재생 완료 화면](screenshots/scene.png)

| 조이스틱 오른쪽 | 조이스틱 왼쪽 |
|---|---|
| ![오른쪽으로 달리는 액터](screenshots/joystick-right.png) | ![왼쪽으로 달리는 액터](screenshots/joystick-left.png) |

## 소스코드

- [SN 재생 어셈블리](samples/scene/sn_sample.s) · [BASIC 로더](samples/scene/hello.bas)
- [조이스틱 어셈블리](samples/joystick/thunder_joystick.s) · [BASIC 로더](samples/joystick/joystick_control.bas)
- [씬 호출 상수](samples/scene/t1scene.inc) · [$6000 메모리 설정](samples/ram6000.cfg)

BASIC 로더는 필요한 파일을 로드하고 `$6000`의 어셈블리 프로그램을 호출합니다.
애니메이션과 화면 처리는 어셈블리에서 수행합니다. 각 예제를 시작할 때 필요한 엔진을
다시 설치하므로, BASIC으로 돌아온 뒤 다른 예제를 실행할 수 있습니다.

## 권리 표시

직접 작성한 샘플 소스와 설명은 [MIT License](LICENSE)를 따릅니다.
디스크에 포함된 원본 Take 1 엔진·샘플 아트·씬·DOS는 각각의 권리자에게 권리가 있습니다.
**MIT 조건을 디스크 전체에 적용하지 않습니다.** [권리 구분](NOTICE.md)을 참고하세요.
