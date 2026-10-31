# Playing an SN Scene from Assembly

**English** | [한국어](README.ko.md)

**[Complete assembly source](sn_sample.s)** · **[BASIC loader](hello.bas)** · **[API constants](t1scene.inc)**

Boot the sample disk or run `RUN HELLO` from BASIC.
The program plays the 83 frames of the Take 1 logo scene, `SN.TK`, once.

- After playback: keep the final image on screen and wait for a key. Press any key to return to BASIC.
- During playback: press ESC to return to BASIC immediately.

## The BASIC loader and the assembly client

The BASIC loader sets `HIMEM:8192` and runs `T1SC.INSTALL`.
It loads the scene, actor, and background, then calls `SN.SAMPLE` at `$6000`.
The sample program and data reuse the installer's temporary memory area.

The assembly client sets up the background and scene parameters, then calls the engine with `JSR $8E00`.
**The original Take 1 engine handles the scene's poses, positions, tempo, page flipping, and background restoration.**
The caller does not have to choose a pose on each frame as it does in the joystick sample.

| Address range | Purpose |
|---|---|
| `$0300–$03CF` | Scene parameters and actor table |
| `$0800–$1FFF` | BASIC program, variables, and strings |
| `$2000–$5FFF` | HGR pages 1 and 2 |
| `$6000–$60D5` | `SN.SAMPLE` client, 214 bytes |
| `$6200–$67F3` | `SN.TK` scene |
| `$6800–$6C69` | `AC.PTK4` actor |
| `$6E00–$8DFF` | `HGR.TK` background, 8192 bytes |
| `$8E00–$95FF` | Call gateway, sound, and workspace |
| LC bank 1 `$D000–$DFFF` | Original scene projector, 4096 bytes |
| LC common `$E000–$FFFF` | Background restoration page, 8192 bytes |

`HGR.TK` is the original background image, decompressed in advance.
The sample does not decompress a BK file at runtime.
Use a standard MAXFILES 3 or lower configuration with DOS buffers starting at `$9600` or above.

## Execution flow

1. `start` saves the caller's state and checks the `T1SC` installation signature.
2. `clear_params` initializes the parameter block, preserving DOS vectors at `$03D0` and above.
3. Set the scene address, playback length, background address, full-screen window, and callback addresses.
4. Register the snapshot count and memory address of `AC.PTK4` in the actor table.
5. Call the engine with A=`CMD_BACKGROUND` to copy the background to both display pages and the restoration page.
6. Call the engine with A=`CMD_PLAY`. The original scene loop at `$D024` plays the scene.
7. On normal completion, `wait_key` waits for a key. If ESC interrupted playback, return immediately.
8. `finish` restores the text screen and caller's state, then returns to BASIC with RTS.

## Main parameters

Addresses and command constants are defined in `t1scene.inc`.

| Constant | Sample value | Meaning |
|---|---|---|
| `SCENE_HEADER` | `$6200` | SN file header address |
| `FRAME_LIMIT` | `$FFFF` | Play to the end of the scene |
| `BACKGROUND` | `$6E00` | Address of the 8KB background image |
| `WIN_LEFT` / `WIN_RIGHT` | 0 / 40 | Horizontal window in seven-pixel HGR byte columns |
| `WIN_TOP` / `WIN_BOTTOM` | 0 / 192 | Vertical window in scanlines |
| `FIRST_PAGE` | `$20` | Initial HGR drawing page |
| `ACTOR_COUNT` | 1 | Number of actor files |
| `ACTOR_TABLE` | Snapshot count, address low byte, address high byte | Three bytes per actor |
| `SOUND_CALLBACK` | `$9000` | Entry point for the original sound effects |

The right and bottom window limits are exclusive. The frame callback runs while Language Card RAM
is mapped in. It should simply return with RTS as in this sample, or do work that does not depend on ROM or DOS.

To play another SN file, also load the actors and background it requires,
then update the addresses, actor count, and actor table accordingly.

## Switching between the two samples

The scene and joystick samples share LC bank 1. Each BASIC loader reinstalls its own engine,
so you can alternate between `RUN HELLO` and `RUN JOYSTICK CONTROL`.
The supplied source covers the sample clients and calling interface; it does not include the original engine's internal source.
