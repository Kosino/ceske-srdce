# České srdce — prototype pixel-art sprite pack

Top-down (front 3/4, Stardew Valley / classic Zelda camera — **not** isometric),
crisp pixel art, limited earthy palette, light from the top-left,
9th-century Slavic look (log walls, thatch / shingle roofs, palisades; no half-timbering, no heraldry).

Grid: **1 tile = 40 px**, as in `docs/DESIGN.md`.
Production PNGs live under `assets/sprites/{buildings,units,resources,terrain,fx}/` and are wired into scenes (Sprite2D / TileMapLayer, nearest filter).

## Preview

- Production PNGs: `assets/sprites/` (RGBA, nearest-neighbour, shared ~32-colour palette).

## Sprite list

| File | Size (px) | In-game footprint | Code identifier / class | Placeholder today |
|---|---|---|---|---|
| `assets/sprites/buildings/town_center.png` | 80×93 | Virtual footprint 80×80 | Radnice / DropOff | `DropOff.tscn` Sprite2D |
| `assets/sprites/buildings/house.png` | 56×80 | 56×56 | Dům / House | `House.tscn` Sprite2D |
| `assets/sprites/buildings/lumber_camp.png` | 72×72 | 72×72 | Pila / LumberCamp | `LumberCamp.tscn` |
| `assets/sprites/buildings/mill.png` | 72×96 | 72×72 | Mlýn / Mill | `Mill.tscn` |
| `assets/sprites/buildings/barracks.png` | 124×76 | 80×80 (sprite wider on purpose) | Kasárna / Barracks | `Barracks.tscn` |
| `assets/sprites/buildings/archery_range.png` | 100×80 | 80×80 | Střelnice / ArcheryRange | `ArcheryRange.tscn` |
| `assets/sprites/buildings/construction_site.png` | 80×84 | under-construction swap | construction site | `Building.gd` |
| `assets/sprites/units/{villager,soldier,spearman,archer}_{down,left,right,up}.png` | ~20–28×40–46 | Collision 16×16 | units | facing from velocity |
| `assets/sprites/resources/tree_oak.png` / `tree_pine.png` | 40×46 / 32×53 | wood (alternating) | ResourceNode | |
| `assets/sprites/resources/berry_bush.png` | 40×35 | food | ResourceNode | |
| `assets/sprites/resources/gold_mine.png` | 40×28 | gold | ResourceNode | |
| `assets/sprites/resources/stone_mine.png` | 40×27 | stone | ResourceNode | |
| `assets/sprites/fx/arrow.png` | 24×4 | tip faces right | Projectile | rotated by aim |
| `assets/sprites/terrain/grass_1.png` / `grass_2.png` / `dirt.png` | 40×40 | TileMapLayer | Map.gd | random grass + dirt near Radnice |
| `assets/sprites/buildings/siege_workshop.png` | 120×90 | footprint 80×80 | Obléhací dílna / SiegeWorkshop | wired (T-23) |
| `assets/sprites/units/ram_{down,left,right,up}.png` | 48×45 | collision ~20×20 | Beranidlo / Ram | facing from velocity |
| `assets/sprites/units/trebuchet_{down,left,right,up}.png` | 56×64 | collision ~22×22 | Trebuchet | packed look; unpack = offset/modulate |

## Integration (done)

- Project `default_texture_filter = Nearest`; Sprite2D / TileMapLayer use nearest; PNG import lossless, no mipmaps.
- Buildings / DropOff / resources / projectile: `Sprite2D` replaces Polygon2D placeholders. Footprints/collisions unchanged.
- Buildings: `offset.y = footprint.y/2 - sprite_height/2`. Construction uses `construction_site.png` (no modulate.a). Ghost placer = final sprite at ~45% alpha.
- Units: four facing textures from velocity; idle keeps last facing; selection ring + HP bar above sprite.
- Map: `TileMapLayer` 75×75 of 40 px grass (random A/B + light modulate alts); dirt paths near Radnice.

Footprints unchanged:

```
House          Vector2(56, 56)
LumberCamp     Vector2(72, 72)
Mill           Vector2(72, 72)
Barracks       Vector2(80, 80)
ArcheryRange   Vector2(80, 80)
DropOff / Radnice: virtual 80×80
Units: collision 16×16, selection radius 14
```

## Style & production notes

- barracks: kept front-facing v1 (good). Scaled to 76px height so logs stay readable; sprite is wider than the 80px footprint (palisade overflows). A width-locked 80px scale would crush logs below 1px and make the hall shorter than a house.
- construction_site: v2 retry used (v1 was isometric). Axis-aligned scaffold, interior left transparent so grass shows through. Scaled to 80px width.
- soldier & spearman: units sheet v2 (v1 left poses were 3/4, not profiles). Factor 0.227 so infantry front pose is 40px tall. Spear overflows height.
- archer: v3 retry used. v1/v2 on-style sheet was missing the bow in the front, right and back poses. v3 is slightly more detailed (no helmet, ribbed leather jerkin) but has a bow in all four directions. Scaled so head-to-toe is 40px (body 389px, factor 0.103).
- archery_range: v2 retry used (v1 was isometric). Dangling palisade legs removed at the gap between the shed floor and the targets. Roof scaled to 80 px; sprite may be slightly wider.
- terrain tiles: hand-authored 40×40 wrap-safe grass (two variants) and dirt, using the shared leaf / dirt palette colours. Generated squares were used only as colour reference; they were not tileable.
- Source sheets were generated as 'pixel-art look' JPEGs on magenta, then keyed with a tolerant pink threshold, defringed, cropped, and nearest-neighbour scaled to the footprint width (or 40 px body height for units).
- A shared 32-colour palette is applied with no dithering. Vegetation, skin, metal, gold, and target red/blue are anchored so they are not swallowed by the brown building colours.
## T-23 siege sprites (siege-v1)

Finished age-4 siege art from the original PR #10 pipeline (magenta key → defringe → crop → NN scale → shared 32-colour palette). No procedural script drawing.

- **siege_workshop** 120×90 — timber workshop on stone base, shingle roof, open bay; bottom-centred; feet/anchor via `Building._anchor_sprite` (`offset.y = footprint.y/2 - h/2`).
- **ram** 48×45 ×4 facings — low closed gabled shed with iron-capped ram head; `_left` / `_right` mirrored from sheet; feet-centred via `Unit._anchor_sprite_to_feet`.
- **trebuchet** 56×64 ×4 facings — packed/transport look (arm raised) for all states. Unpacked uses the same frames with a subtle warm modulate + 4 px lift (no separate unpacked sheet yet).

Import source branch: `art/siege-v1` (`art_import/sprites_siege.tar.gz` sha256 `16661f7b…fc5779`). Screenshot: `docs/screenshots/siege.png`.

## What this pack does not include

- Walk-cycle frames (only one pose per facing).
- Dedicated enemy-team recolours (enemy units/buildings use a light modulate tint).
- Dedicated trebuchet unpacked / firing frames (T-23 uses packed art + subtle deploy cue).
