# Running Left and Right with the Joystick

**English** | [한국어](README.ko.md)

**[Complete assembly source](thunder_joystick.s)** · **[BASIC loader](joystick_control.bas)**

Run `RUN JOYSTICK CONTROL` from the sample disk.

- Joystick left/right: face and move in that direction.
- Centered: keep facing the last direction and continue running in place.
- ESC: return to the text screen and BASIC.

## What the BASIC loader does

`HIMEM:8192` keeps the BASIC program, variables, and strings below `$2000`.
The loader runs `T1LC.INSTALL` to install the snapshot renderer in Language Card upper RAM.
It loads the right- and left-facing actor data, loads `THUNDER.JOY` at `$6000`, and calls it with
`CALL 24576`. From assembly, the equivalent entry is `JSR $6000`.

| Address range | Purpose |
|---|---|
| `$0300–$03CF` | Renderer call gateway and parameters |
| `$0800–$1FFF` | BASIC program, variables, and strings |
| `$2000–$3FFF` | HGR page 1 |
| `$4000–$5FFF` | HGR page 2 |
| `$6000–$6376` | Joystick program, 887 bytes |
| `$6F00–$7F94` | Left-facing actor, `AC.THUNDER LEFT` |
| `$8000–$8F88` | Original right-facing actor, `AC.THUNDER RUN` |
| LC bank 1 `$D000–$D8FF` | Renderer and workspace |

After installation, the joystick program reuses the installer's temporary area at `$6000`.
The program calls the renderer with `JSR $0300`. The gateway handles upper RAM banking.

## One frame of the main loop

Execution repeats from `frame_loop` in the source.

1. Check for ESC.
2. In `read_joystick`, call the ROM `PREAD` routine at `$FB1E`. X=0 selects the horizontal axis;
   Y returns a value from 0 to 255.
3. Treat 0–95 as left, 96–159 as centered, and 160–255 as right.
   Only left/right input changes `player_x`, by 4 pixels, clamped to 0–210.
4. In `render_frame`, cycle `pose` through 1–12 regardless of joystick input.
   This keeps the running animation moving while the joystick is centered.
5. Clear the previous character area on the hidden page, then draw the current pose with `draw_player`.
6. Display the completed page and select the other page for the next frame.

Take 1's snapshot renderer draws one specified pose per call.
This sample chooses the pose and position on every frame. It does not execute a named action
or use the movement deltas stored in the original actor file.

## Flipping HGR pages 1 and 2

`DRAW_PAGE` at `$E6` selects the **drawing page**: `$20` for page 1, `$40` for page 2.

`clear_band` clears only scanlines y=104–163 on the hidden page. After drawing the actor,
the program reads `$C054` to display page 1 or `$C055` to display page 2.

```asm
        lda DRAW_PAGE
        eor #$60           ; $20 <-> $40
        sta DRAW_PAGE      ; draw on the other page next time
```

The clearing operation stays hidden from view. The floor line is drawn once on both pages
during initialization. There is no vertical blank synchronization, so playback speed depends on the environment.

## Facing direction and the one-pixel adjustment

Right uses the original `AC.THUNDER RUN`; left uses the mirrored `AC.THUNDER LEFT`.
The mirrored actor's header has dx=+1, shifting it one pixel to the right to adjust the Apple II color phase.
Do not subtract 1 from X again in `use_left`, as that would undo the adjustment.

This actor is intended for a black background. The reflection is not a general conversion
that preserves every NTSC edge color exactly.

## Returning and adapting the sample

`finish`/`restore` restore the text screen, zero page, X/Y, and the caller's flags,
then return with RTS. The BASIC loader continues by printing `BACK TO BASIC`.

Movement speed is defined by `MOVE_STEP`, the centered range by `JOY_LEFT`/`JOY_RIGHT`,
and the vertical position by `PLAYER_Y`. If you change the character's height or vertical position,
review the cleared area and floor position as well.
