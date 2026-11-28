# Sprites walk-v2 — archer + spearman walk cycles (no code changes)

Same ORIGINAL PR #10 pipeline as walk-v1: GenerateImage sheets on flat magenta (idle sprite of the unit +
walk-v1 soldier sheets / earlier generations as references) → key → defringe → crop → nearest-neighbour scale →
shared 32-colour PR #10 palette (foliage thresholds, int32, team-blue forbidden, no dither).
No procedurally drawn pixels, no deforming of idle sprites. Script: `walk-v2/walk_v2_process.py` (runs walk/walk_process.py unchanged, only paths differ).

## Import (worker)
```
base64 -d art_import/sprites_walk_v2.tar.gz.b64 > /tmp/sprites_walk_v2.tar.gz
cd /tmp && sha256sum -c <repo>/art_import/sprites_walk_v2.tar.gz.sha256   # file must be named sprites_walk_v2.tar.gz
tar -xzf /tmp/sprites_walk_v2.tar.gz -C <repo>   # writes assets/sprites/units/{archer,spearman}_walk.png (+ this README)
```
Do not commit the .b64 to main. Unit.gd already loads `res://assets/sprites/units/{unit_key}_walk.png` (unit keys `archer`, `spearman`).

## Layout (engine contract, identical to walk-v1)
- `assets/sprites/units/{unit}_walk.png`, 128×160, 4 cols (frames 0–3) × 4 rows (down, left, right, up), cell 32×40.
- Feet on the cell's bottom row, horizontal anchor = head/torso centre; tallest frame per generated sheet = 40 px.
- `right` row = mirror of `left`. No team-blue (40,86,160) pixels → modulate / T-18 fallback tint as before.

## Files
| File | Size | Colours |
|---|---|---|
| `assets/sprites/units/archer_walk.png` | 128×160 | 26 of 32 PR #10 palette |
| `assets/sprites/units/spearman_walk.png` | 128×160 | 27 of 32 PR #10 palette |

## Frame sources (walk-v2/raw/)
- archer: `archer_side_v1.jpg` frames 1–4 (left; right = mirror), `archer_frontback_v1.jpg` row 1 (down), row 2 (up).
- spearman: `spearman_side_v3.jpg` frames 1–4, `spearman_frontback_v3.jpg` rows 1/2.
- Rejected: `spearman_side_v1.jpg` (grey chainmail, one frame with different trousers), `spearman_side_v2.jpg` and
  `spearman_frontback_v1/v2.jpg` (upright spear far above the helmet → body ~20 % smaller than idle after the 40 px fit).

## Art debt
- Spearman carries the spear slanted (tip ≈ helmet height) while idle holds it upright above the head (idle is 45 px tall,
  over the 40 px cell) — silhouette changes when he starts walking; body size now matches idle.
- Spearman faces quantize to warm yellow/orange and the helmet is darker than idle's light grey.
- Archer figures are a little slimmer than idle (19 vs 21 px in down row, front frames 38 px tall); bow string is dotted
  (same as idle); a couple of stray red pixels on the bow in down/up frame 2; side frames 0 and 3 are both wide strides.
