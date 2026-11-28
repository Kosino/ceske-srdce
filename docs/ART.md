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
| `assets/sprites/buildings/farm.png` (+ `_empty` / `_sown` / `_ripe`) | 80×53–54 | footprint 80×80 | Farma / Farm | wired (T-19); ghost = ripe; new build = sown |

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
Farm           Vector2(80, 80)
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

## T-19 farm plots (pole u mlýna)

Farm field sprites from the original PR #10 pipeline (magenta key → defringe → crop → NN scale → shared 32-colour palette). No procedural script drawing. Front 3/4, same style as T-23 siege / mill.

| File | Size | State |
|---|---|---|
| `assets/sprites/buildings/farm_empty.png` | 80×54 | tilled dirt + corner posts |
| `assets/sprites/buildings/farm_sown.png` | 80×54 | green seedlings |
| `assets/sprites/buildings/farm_ripe.png` | 80×53 | golden wheat |
| `assets/sprites/buildings/farm.png` | 80×53 | alias of ripe (default place / ghost) |

Wired as `Farm` building (requires Mill). Gather: 0.33 food/s, stockpile 175, max 1 farmer; drop-off Mill/TC. States: sown (new) → ripe (farming) → empty (depleted) → reseed 60 wood → sown. Screenshots: `docs/screenshots/t19_farms.png`, `docs/screenshots/t25_reseed.png`.

## T-18 team recolour (palette swap)

AoE II-style team colour via `assets/shaders/team_recolour.gdshader` + `TeamColors` (`scripts/data/TeamColors.gd`):

- PNGs keep the shared 32-colour palette. Only the baked **team blue** `(40, 86, 160)` is swapped.
- Player → `TeamColors.PLAYER` (same blue); AI → `TeamColors.AI` (red `188, 42, 36`). Constants live in one place for more teams later.
- Applied on unit/building/`DropOff` visuals. Sprites **with** team-blue use the palette-swap shader and modulate WHITE. Sprites **without** team-blue (detected at texture load, cached) keep the previous soft AI tint for the AI team — units `Color(1.0, 0.55, 0.55)`, buildings/`DropOff` `Color(0.75, 0.45, 0.45)` — so enemies stay readable until artists paint team indices. Minimap unit/building dots use the same blue/red.
- Screenshot: `docs/screenshots/t18_team_colours.png`.

### Art debt (no team pixels yet — do not hand-paint)

Sprites without distinguishable `(40, 86, 160)` team indices (shader is a no-op on them; tint fallback applies for AI until artists add cloth/banner/shield team blue):

- **Units:** villager, soldier, spearman, archer, monk, light_cavalry, bojovnik_bradatice, druzinik, lancknecht, valecny_vuz, ram, trebuchet
- **Buildings:** town_center, house, lumber_camp, mill, farm, barracks, archery_range, blacksmith, stable, castle, monastery, university, siege_workshop, walls/gates/towers, construction_site
- **Has team blue today:** knight (shield), market (awning/banner)

## T-17 walk-cycle (villager + soldier)

Code in `Unit.gd`: optional walk sheet `assets/sprites/units/{unit}_walk.png`
(4 columns × 4 rows: frames × down/left/right/up, cell 32×40, bottom-centred). Idle = existing
static facing PNGs. Units without a walk sheet keep the static facing sprite. Frame swaps do
**not** reset `modulate` / shader material (T-18 palette-swap + AI tint preserved). Feet/anchor
uses the same per-frame height as idle (40 px) so idle↔walk does not jump.

| File | Size | Notes |
|---|---|---|
| `assets/sprites/units/villager_walk.png` | 128×160 | walk-v1 (PR #10 pipeline) |
| `assets/sprites/units/soldier_walk.png` | 128×160 | walk-v1 (PR #10 pipeline) |

Import source branch: `art/walk-v1` (`art_import/sprites_walk.tar.gz` sha256 `10038ed3…d36f`).
No `gen_*` procedural drawing. Screenshot: `docs/screenshots/t17_walk.png`.

### Art debt (walk-v1)

- Villager **front (down)** walk: slight head turn in frame 2 (body sway); frames 1/3 repeat the passing pose.
- Walk figures a few px narrower than idle fronts (villager ~21 vs ~26 px wide in the down row).
- A few olive pixels on the axe head (quantize / foliage thresholds).

## T-27 walk-v2 (archer + spearman)

Same engine contract and PR #10 pipeline as walk-v1. `Unit.gd` auto-loads
`res://assets/sprites/units/{unit_key}_walk.png` when present (keys `archer`, `spearman`) —
no gameplay logic changes for this import.

| File | Size | Notes |
|---|---|---|
| `assets/sprites/units/archer_walk.png` | 128×160 | walk-v2 (PR #10 pipeline) |
| `assets/sprites/units/spearman_walk.png` | 128×160 | walk-v2 (PR #10 pipeline) |

Import source branch: `art/walk-v2` @ `6571e66`
(`art_import/sprites_walk_v2.tar.gz` sha256 `94d986afd7adaf570e1b8d4a45bf27f0764d121fde7c55188d9fd42f4cb2dfbf`).
No `gen_*` procedural drawing. Screenshot: `docs/screenshots/t27_walk_v2.png`.

### Art debt (walk-v2)

- Spearman spear is **diagonal** (tip ≈ helmet height) while idle holds it **vertical** above the head
  (idle is 45 px tall, over the 40 px cell) — silhouette changes when he starts walking; body size now matches idle.
- Spearman faces quantize to warm yellow/orange; helmet darker than idle's light grey.
- Archer is ~**2 px slimmer** than idle (19 vs 21 px in down row; front frames 38 px tall); bow string dotted
  (same as idle); a couple of stray red pixels on the bow in down/up frame 2; side frames 0 and 3 are both wide strides.

## What this pack does not include

- Walk-cycle sheets for units beyond villager, soldier, archer, and spearman (others idle-only).
- Dedicated trebuchet unpacked / firing frames (T-23 uses packed art + subtle deploy cue).
- Full team-blue coverage on every unit/building (see art debt above).
