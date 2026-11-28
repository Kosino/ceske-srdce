# Sprites cavalry walk + rally flag (T-34)

Same ORIGINAL PR #10 / walk-v2 pipeline as archer/spearman:
GenerateImage sheets on flat magenta/hot-pink (idle cavalry sprites + soldier_walk as
references) → key → defringe → crop → nearest-neighbour scale → shared 32-colour
production palette (no dither). No procedurally drawn pixels, no deforming of idle sprites.

## Layout (engine contract)

- `assets/sprites/units/{light_cavalry,knight}_walk.png`, **256×320**
- **4 columns** (frames 0–3) × **4 rows** (down, left, right, up), cell **64×80**
  (larger than infantry 32×40 so the horse fits).
- Feet on the cell's bottom row; horizontal anchor = torso/head centre.
- `_right` row = horizontal mirror of `_left`.
- Light cavalry: no team-blue. Knight: team-blue on barding/shield (T-18).

## Rally flag

- `assets/sprites/fx/rally_flag.png` (~19×30) — wooden stake + red banner, same pipeline.
- Wired in `RallyPointController` as a nearest-filter Sprite2D (replaces `_draw` polygon).

## Frame sources (raw/)

- light_cavalry: `light_cavalry_side_v1.jpg` (left×4), `light_cavalry_frontback_v2.jpg` (down/up).
  Rejected: `light_cavalry_frontback_v1.jpg` (came out as a wagon).
- knight: `knight_side_v1.jpg`, `knight_frontback_v1.jpg`.
- flag: `rally_flag_v1.jpg`.
