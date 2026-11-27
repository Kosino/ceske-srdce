# Sprites siege-v1 (T-23) — siege workshop, battering ram, trebuchet (no code changes)

New age-4 siege sprites in the ORIGINAL PR #10 pipeline:
generated pixel-art sheets on magenta (GenerateImage, style_reference.jpg + v2_wagon / university as references)
→ key → defringe → crop → nearest-neighbour scale → shared 32-colour PR #10 palette (no dither).
No procedurally drawn pixels. Script: `siege/siege_process.py` (template: work/age34_process.py). QA: `siege/qa_siege.png` (3×, on grass).

## Import (worker)

```
base64 -d art_import/sprites_siege.tar.gz.b64 > /tmp/sprites_siege.tar.gz
cd /tmp && sha256sum -c <repo>/art_import/sprites_siege.tar.gz.sha256   # file must be named sprites_siege.tar.gz
tar -xzf /tmp/sprites_siege.tar.gz -C <repo>    # writes assets/sprites/{buildings,units}/*.png
```

## Notes for integration

- Building is bottom-centred on a transparent canvas: siege_workshop 120×90 (same scale as university 120×95 / market 120×80).
- Units: all four facings share one canvas, bottom-centred. ram 48×45, trebuchet 56×64 (packed, arm raised).
  `_left` faces screen-left; `_right` is its mirror (as in the original sheets).
- Trebuchet sprite is the packed/transport look; use it for packed and unpacked states (no separate unpacked frame yet).
- Camera: front 3/4 / almost straight-on, not isometric. Light top-left.

## Files
| File | Size |
|---|---|
| `assets/sprites/buildings/siege_workshop.png` | 120×90 |
| `assets/sprites/units/ram_down.png` | 48×45 |
| `assets/sprites/units/ram_left.png` | 48×45 |
| `assets/sprites/units/ram_right.png` | 48×45 |
| `assets/sprites/units/ram_up.png` | 48×45 |
| `assets/sprites/units/trebuchet_down.png` | 56×64 |
| `assets/sprites/units/trebuchet_left.png` | 56×64 |
| `assets/sprites/units/trebuchet_right.png` | 56×64 |
| `assets/sprites/units/trebuchet_up.png` | 56×64 |

## Process notes

- siege_workshop: v1 accepted (timber workshop on stone base, shingle roof, open bay with half-built trebuchet frame, log stack, hoist).
- ram: v1 (raw/ram_v1_REJECT_cart.jpg) rejected in review 7/10 — open cart / market stall look with thatch canopy. v2 used (redo 1/2): low closed gabled shed, hide-covered roof reaching near the ground, plank walls, iron-capped ram head out of the front gable / past the front in side views. Sheet view 2 (head pointing left) = `_left`, `_right` mirrored. Canvas 48×45. At 1× the dark/grey hide patches flatten to browns in the palette, so the roof reads as rough brown covering rather than distinct leather patches.
- trebuchet: v1 rejected (side views had a horizontal arm → wide, not tall; front view had a cannon-like stub copied from the wagon reference). v2 (packed, arm raised) used. The cannon-like stub under the front beam in the down/up views was removed by erasing those pixels in the cut before scaling (pixel removal only, nothing drawn); a small iron plate on the beam remains.
