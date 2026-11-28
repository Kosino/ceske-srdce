# Sprites walk-v1 (T-17) — villager + soldier walk cycles (no code changes)

Production walk sheets in the ORIGINAL PR #10 pipeline:
generated pixel-art sheets on flat magenta (GenerateImage, idle sprites + style_reference.jpg /
sheet_military_units_v2.jpg as references) → key → defringe → crop → nearest-neighbour scale →
shared 32-colour PR #10 palette (no dither). No procedurally drawn pixels, no sliding/deforming of idle sprites.
Script: `walk/walk_process.py` (reuses siege/siege_process.py key/defringe/finish + work/palette.png).

## Import (worker)

```
base64 -d art_import/sprites_walk.tar.gz.b64 > /tmp/sprites_walk.tar.gz
cd /tmp && sha256sum -c <repo>/art_import/sprites_walk.tar.gz.sha256   # file must be named sprites_walk.tar.gz
tar -xzf /tmp/sprites_walk.tar.gz -C <repo>    # writes assets/sprites/units/{villager,soldier}_walk.png (+ this README)
```
Do not commit the .b64 to main (same as the siege pack).

## Layout (engine contract)

- One sheet per unit: `assets/sprites/units/{unit}_walk.png`, **128×160**
- **4 columns** (walk frames 0–3) × **4 rows** (down, left, right, up), cell **32×40**
- Character bottom-centred in each cell (feet on the cell's bottom row); horizontal anchor = head/torso
  centre, so strides do not make the body jitter. Tallest frame per facing = 40 px, same as idle.
- `_right` row = horizontal mirror of `_left` (left faces screen-left).
- No team-blue (40,86,160) pixels (idle sprites have none) → keep using modulate / T-18 fallback tint.
- Suggested playback: 4 frames at ~6–8 fps while moving; idle sprite when stopped.

## Files
| File | Size | Colours |
|---|---|---|
| `assets/sprites/units/villager_walk.png` | 128×160 | 28 of the 32 PR #10 palette |
| `assets/sprites/units/soldier_walk.png` | 128×160 | 27 of the 32 PR #10 palette |

## Frame sources (raw generations in walk/raw/)
- villager left/right: `villager_side_v2.jpg` frames 1–4 (contact, down, passing, up).
- villager down: `villager_frontback_v3.jpg` frames 1, 2 (mirrored), 4 (mirrored), 2 (mirrored) — mirrors only
  so the axe stays in the screen-right hand like `villager_down.png`; frame 3 of the generation (sideways stride) dropped.
- villager up: `villager_frontback_v3.jpg` frames 5–8.
- soldier left/right: `soldier_side_v2.jpg` frames 1–4; soldier down/up: `soldier_frontback_v2.jpg` rows 1/2.
- Rejected: `villager_walk_v1.jpg` (4×4 sheet: side rows mixed facings/axe hands, slimmer proportions than idle),
  `soldier_walk_v1.jpg` (side frames all the same stride pose), `soldier_side_v3.jpg` (asked for green mail, came out identical to v2).

## Notes / art debt
- Quantize uses the PR #10 foliage thresholds (work/polish.py) with int32 maths, so the soldier's grey-olive mail lands
  on the same olive greens as `soldier_*.png`; a few axe-head pixels also pick up an olive tint.
- Villager down row: frame 2 has a slight 3/4 head turn (body sway) and frames 1/3 repeat the passing pose.
- Villager up row leans slightly 3/4 to the right; side rows are the strongest part of the pack.
- Walk figures are a little slimmer than the idle front sprites (villager 21 px vs 26 px wide in the down row).
