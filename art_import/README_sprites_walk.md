# Sprites walk-v1 (T-17) — villager + soldier walk cycles

Expected finished walk sheets via branch `art/walk-v1` in the ORIGINAL PR #10 pipeline:
generated pixel-art sheet on magenta → key → defringe → crop → nearest-neighbour scale →
shared 32-colour palette (the PR #10 palette, no dither).

Until that pack lands, `assets/sprites/units/{villager,soldier}_walk.png` are **temporary
solid-color bordered placeholders** (prefs) so walk-frame switching can be smoke-tested.
They are not production pixel art.

## Layout (engine contract)

- One sheet per unit: `assets/sprites/units/{unit}_walk.png`
- **4 columns** (walk frames 0–3) × **4 rows** (down, left, right, up)
- Cell size ~32×40 (body height ~40 px, same scale as idle facings)
- Idle remains `{unit}_{down,left,right,up}.png` (unchanged)
- Front 3/4, consistent with existing static sprites; `_right` may be a mirror of `_left`
- Do NOT draw sprites procedurally. Do NOT slide/deform a static idle image as animation.

## Files (target)

| File | Size |
|---|---|
| `assets/sprites/units/villager_walk.png` | 128×160 (4×4 × 32×40) |
| `assets/sprites/units/soldier_walk.png` | 128×160 (4×4 × 32×40) |
