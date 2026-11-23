# Agent notes — České srdce

Godot **4.7** RTS (GDScript). Main scene: `res://scenes/ui/MainMenu.tscn`.

## Autoloads

| Autoload | Path |
|----------|------|
| `GameManager` | `res://autoload/GameManager.gd` |
| `SelectionManager` | `res://autoload/SelectionManager.gd` |
| `NotificationManager` | `res://autoload/NotificationManager.gd` |
| `BalanceSim` | `res://autoload/BalanceSim.gd` (no-op unless `--sim` / `--sim-smoke`) |
| `AudioManager` | `res://autoload/AudioManager.gd` (SFX/Music buses; silent under headless/`--sim`) |

## Headless commands

Use the Godot 4.7 console binary on this machine (path may differ per host):

```powershell
# Smoke suite (DoD gate)
& "<Godot_4.7_console.exe>" --headless --path .

# Full AI vs AI balance suite → docs/balance/report.md
& "<Godot_4.7_console.exe>" --headless --path . -- --sim

# One-game sim harness smoke
& "<Godot_4.7_console.exe>" --headless --path . -- --sim-smoke
```

User args after `--` are read by `BalanceSim` / Map shot helpers (`--ai-shot`, `--hud-shot`, …).

## Definition of done

1. Headless smokes print **`[TEST] all headless smokes finished`** with every relevant **`[TEST] PASS`** (no FAIL).
2. Feature PRs include a **screenshot** under `docs/screenshots/` when UI/art/gameplay is visible.
3. Self-review / Bugbot-style bar: aim for **≥ 8/10** before asking for merge.

## Rules

- **Do not bend smoke tests** to make a change pass. Fix the game or escalate.
- After **2 failed** fix attempts on the same smoke/CI failure, **escalate** (ask the user / coordinator) instead of endless retries.
- **Sprites** come only from the original art pipeline / imported assets. **No procedural sprite generation.**
- **Audio** is ready **CC0** clips only (Kenney packs); see `assets/audio/LICENSES.md`. **No procedural synthesis.**
- Design contract (outside this repo — mention only, do not invent a local copy): `/workspace/handoffs/contracts/principal-cs-designer.md`.

## Balance sim notes

- `--sim` runs 20 games per civ pair with strategies `rush` / `boom` / `fast_castle`.
- Report: win %, Wilson CI, length percentiles, strategy mix, age-reach %, army composition.
- Sim-only TC pacing exists under `--sim`; normal play must stay unchanged when BalanceSim is inactive.
