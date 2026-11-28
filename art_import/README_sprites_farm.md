# Sprites farm-v1 (T-19) — farm plots empty / sown / ripe

New farm-plot sprites in the ORIGINAL PR #10 pipeline:
generated pixel-art sheet on magenta (GenerateImage, mill + berry + dirt + siege_workshop refs)
→ key → defringe → crop → nearest-neighbour scale → shared 32-colour PR #10 palette (no dither).
No procedurally drawn pixels.

## Notes for integration

- Canvases are bottom-centred: 80×53–54 (footprint 80×80). Feet/anchor via `Building._anchor_sprite`.
- Ghost texture: `farm.png` (= ripe). New complete farm uses `farm_sown.png` until farming → ripe → empty.
- Camera: front 3/4 / almost straight-on (same as mill / siege), not isometric.
- Do NOT draw sprites procedurally. New art = generate on magenta + this pipeline.

## Files
| File | Size |
|---|---|
| `assets/sprites/buildings/farm.png` | 80×53 |
| `assets/sprites/buildings/farm_empty.png` | 80×54 |
| `assets/sprites/buildings/farm_sown.png` | 80×54 |
| `assets/sprites/buildings/farm_ripe.png` | 80×53 |

## Process notes

- Sheet v1 rejected (too isometric / diamond plots).
- Sheet v2 used: axis-aligned rectangular plots, empty / sown / ripe in one row on magenta.
