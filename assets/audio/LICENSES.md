# Audio licenses

All shipped clips are **CC0 1.0** (public domain). Credit to authors is appreciated but not required.

| Game file | Original file | Pack / author | License | Source |
|-----------|---------------|---------------|---------|--------|
| `sfx/select.ogg` | `select_001.ogg` | Interface Sounds (Kenney) | CC0 | https://kenney.nl/assets/interface-sounds |
| `sfx/command.ogg` | `click_001.ogg` | Interface Sounds (Kenney) | CC0 | https://kenney.nl/assets/interface-sounds |
| `sfx/building_complete.ogg` | `maximize_001.ogg` | Interface Sounds (Kenney) | CC0 | https://kenney.nl/assets/interface-sounds |
| `sfx/under_attack.ogg` | `error_001.ogg` | Interface Sounds (Kenney) | CC0 | https://kenney.nl/assets/interface-sounds |
| `sfx/defeat.ogg` | `jingles_SAX07.ogg` | Music Jingles (Kenney) | CC0 | https://kenney.nl/assets/music-jingles |
| `sfx/victory.ogg` | `jingles_NES00.ogg` | Music Jingles (Kenney) | CC0 | https://kenney.nl/assets/music-jingles |
| `sfx/wood_chop.ogg` | `wood_hammer_01.ogg` | 100 CC0 metal and wood SFX (rubberduck) | CC0 | https://opengameart.org/content/100-cc0-metal-and-wood-sfx |
| `sfx/mining.ogg` | `impactMetal_light_000.ogg` | Impact Sounds (Kenney) | CC0 | https://kenney.nl/assets/impact-sounds |
| `sfx/building_destroyed.ogg` | `wood_falling_05.ogg` | 100 CC0 metal and wood SFX (rubberduck) | CC0 | https://opengameart.org/content/100-cc0-metal-and-wood-sfx |
| `sfx/age_advance.ogg` | `impactBell_heavy_000.ogg` | Impact Sounds (Kenney) | CC0 | https://kenney.nl/assets/impact-sounds |
| `sfx/melee_hit.ogg` | `knifeSlice.ogg` | RPG Audio (Kenney) | CC0 | https://kenney.nl/assets/rpg-audio |
| `sfx/bow_shot.wav` | `Bow.wav` | Battle Sound Effects (artisticdude) | CC0 | https://opengameart.org/content/battle-sound-effects |

## T-22 sound pass 2 notes

Replaced provisional stand-ins with better-fitting CC0:

- **building_destroyed** — was Kenney light metal impact; now rubberduck heavy wood fall/collapse.
- **victory / defeat** — were Kenney Interface UI blips; now Music Jingles NES fanfare (~1.8 s) and somber sax motif (~1.7 s), both under 4 s.
- **bow_shot** — was Kenney knife draw; now artisticdude bowstring release.
- **wood_chop** — was Kenney wood footstep; now rubberduck wood hammer (axe-into-wood).

Pack `License*.txt` copies live under `assets/audio/licenses/`.

No procedural synthesis. No non-CC0 sources. AudioManager API (`play_sfx` ids) unchanged.
