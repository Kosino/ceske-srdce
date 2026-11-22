# Sprites v2 — original-style re-art (no code changes)

Re-creation of the procedurally drawn sprites in the ORIGINAL PR #10 pipeline:
generated pixel-art sheets on magenta → key → defringe → crop → nearest-neighbour scale →
shared 32-colour palette (the PR #10 palette, no dither). Spearman restored byte-identical from 12d8bcd.

## Import (worker)

```
base64 -d art_import/sprites_v2.tar.gz.b64 > /tmp/sprites_v2.tar.gz
cd /tmp && sha256sum -c <repo>/art_import/sprites_v2.tar.gz.sha256   # run with the file named sprites_v2.tar.gz
tar -xzf /tmp/sprites_v2.tar.gz -C <repo>    # overwrites assets/sprites/{buildings,units}/*.png
```

## Notes for integration

- Buildings keep the exact canvas sizes from main (stable 128×72, lumber_camp 100×88, mining_camp 96×90,
  castle 156×172, blacksmith 72×100), sprite bottom-centred on transparent canvas.
- NEW (for walls PR): palisade 40×31, stone_wall 40×36, gate 120×82 (3 tiles), watch_tower 44×111 (40 px footprint, tall).
- Units: canvases changed vs main because real scale was kept (infantry body ≈ 40 px, cavalry ~54 px wide):
  bojovnik 36×44 (same), lancknecht 36×55 (pike), light_cavalry 54×67, knight 54×75, druzinik 54×63,
  valecny_vuz 56×48, spearman original 24×45 / 18×46 / 16×46 / 23×45.
  Unit.gd centres the sprite with offset.y = 8, so taller canvases shift feet down a few px —
  consider offset.y = 16 - tex_height/2 + 8 (bottom anchoring) when importing.
- Facing: _left faces screen-left, _right is its mirror (as in the original sheets).
- Do NOT draw sprites procedurally. New art = generate on magenta + this pipeline.

## Files
| File | Size |
|---|---|
| `assets/sprites/buildings/blacksmith.png` | 72×100 |
| `assets/sprites/buildings/castle.png` | 156×172 |
| `assets/sprites/buildings/gate.png` | 120×82 |
| `assets/sprites/buildings/lumber_camp.png` | 100×88 |
| `assets/sprites/buildings/mining_camp.png` | 96×90 |
| `assets/sprites/buildings/palisade.png` | 40×31 |
| `assets/sprites/buildings/stable.png` | 128×72 |
| `assets/sprites/buildings/stone_wall.png` | 40×36 |
| `assets/sprites/buildings/watch_tower.png` | 44×111 |
| `assets/sprites/units/bojovnik_bradatice_down.png` | 36×44 |
| `assets/sprites/units/bojovnik_bradatice_left.png` | 36×44 |
| `assets/sprites/units/bojovnik_bradatice_right.png` | 36×44 |
| `assets/sprites/units/bojovnik_bradatice_up.png` | 36×44 |
| `assets/sprites/units/druzinik_down.png` | 54×63 |
| `assets/sprites/units/druzinik_left.png` | 54×63 |
| `assets/sprites/units/druzinik_right.png` | 54×63 |
| `assets/sprites/units/druzinik_up.png` | 54×63 |
| `assets/sprites/units/knight_down.png` | 54×75 |
| `assets/sprites/units/knight_left.png` | 54×75 |
| `assets/sprites/units/knight_right.png` | 54×75 |
| `assets/sprites/units/knight_up.png` | 54×75 |
| `assets/sprites/units/lancknecht_down.png` | 36×55 |
| `assets/sprites/units/lancknecht_left.png` | 36×55 |
| `assets/sprites/units/lancknecht_right.png` | 36×55 |
| `assets/sprites/units/lancknecht_up.png` | 36×55 |
| `assets/sprites/units/light_cavalry_down.png` | 54×67 |
| `assets/sprites/units/light_cavalry_left.png` | 54×67 |
| `assets/sprites/units/light_cavalry_right.png` | 54×67 |
| `assets/sprites/units/light_cavalry_up.png` | 54×67 |
| `assets/sprites/units/spearman_down.png` | 24×45 |
| `assets/sprites/units/spearman_left.png` | 18×46 |
| `assets/sprites/units/spearman_right.png` | 16×46 |
| `assets/sprites/units/spearman_up.png` | 23×45 |
| `assets/sprites/units/valecny_vuz_down.png` | 56×48 |
| `assets/sprites/units/valecny_vuz_left.png` | 56×48 |
| `assets/sprites/units/valecny_vuz_right.png` | 56×48 |
| `assets/sprites/units/valecny_vuz_up.png` | 56×48 |
