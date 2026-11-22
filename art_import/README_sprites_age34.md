# Sprites age34-v1 — monastery, university, market, monk (no code changes)

New age-3/4 sprites in the ORIGINAL PR #10 pipeline:
generated pixel-art sheets on magenta → key → defringe → crop → nearest-neighbour scale →
shared 32-colour palette (the PR #10 palette, no dither).

Branch starts from main `e9cce3b`. Do not open a PR from this branch until the sprites are approved and wired in.

## Import (worker)

```
base64 -d art_import/sprites_age34.tar.gz.b64 > /tmp/sprites_age34.tar.gz
cd /tmp && sha256sum -c <repo>/art_import/sprites_age34.tar.gz.sha256   # file must be named sprites_age34.tar.gz
tar -xzf /tmp/sprites_age34.tar.gz -C <repo>    # writes assets/sprites/{buildings,units}/*.png
```

## Notes for integration

- Buildings are bottom-centred on a transparent canvas at the target size:
  monastery 120×100, university 120×95, market 120×80.
- Units: monk canvases are 24×46 (same scale as the original villager / spearman; staff overflows height like the spear).
  All four facings share that canvas, bottom-centred.
  `_left` faces screen-left; `_right` is its mirror (as in the original sheets).
- Camera: front 3/4 / almost straight-on (same as town_center / barracks / house), not isometric.
- Do NOT draw sprites procedurally. New art = generate on magenta + this pipeline.

## Files
| File | Size |
|---|---|
| `assets/sprites/buildings/monastery.png` | 120×100 |
| `assets/sprites/buildings/university.png` | 120×95 |
| `assets/sprites/buildings/market.png` | 120×80 |
| `assets/sprites/units/monk_down.png` | 24×46 |
| `assets/sprites/units/monk_left.png` | 24×46 |
| `assets/sprites/units/monk_right.png` | 24×46 |
| `assets/sprites/units/monk_up.png` | 24×46 |

## Process notes

- monastery: v1 was isometric and was rejected; v2 (front-facing Romanesque nave + bell tower) was used.
- market: v1 was a long 4-stall row that collapsed to an unreadable 120×42 strip; v2 (compact two-stall market with red/blue awnings) was used.
- university: first generate failed on a bad reference path; the accepted sheet is v1 (front gable, red tile roof, Gothic tracery window).
- monk: the generated right-facing pose still faced left, so `_right` is a mirror of `_left`, same as the original unit sheets. The pectoral crucifix is barely visible at 24 px.
