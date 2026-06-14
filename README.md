# Lettrage — Godot Conversion Project

Snatch Word conversion from GDevelop (`SnatchWord1/GAME25.json`) to Godot 4.6.

**Baseline layout:** `Main2_heallthbartest`  
**Sibling folder:** `SnatchWord1/` is read-only local reference — **outside this git repository**, do not modify.

**GitHub:** https://github.com/Gilganjun/Lettrage-GODOT

## Phase status

| Phase | Status |
|-------|--------|
| Phase 0 — Foundation | **Complete** |
| Phase 1 — Assets, SpriteFrames, animation test | **Complete** |
| Phase 2A — Movement, collision, editable baked level | **Complete** |
| Phase 2B1 — Player letters, spelling, dictionary, score | **Implemented** — manual F5 pending |
| Phase 2B2+ — Enemy AI, health, etc. | **Not started** |

## Scenes

| Purpose | Scene |
|---------|-------|
| **F5 — play word game test** | `scenes/test/phase2b1_word_game_test.tscn` |
| Phase 2A movement reference | `scenes/test/phase2a_movement_corrected.tscn` |
| **Edit level in Godot 2D** | `scenes/levels/main2_heallthbartest_level.tscn` |
| Phase 1 animation test | `scenes/test/animation_test.tscn` |
| Static layout reference | `scenes/test/phase2a_layout_verification.tscn` |

The movement test **instances** the baked level. Save edits in `main2_heallthbartest_level.tscn` — they persist across F5 runs.

### Authoritative level baseline

**`main2_heallthbartest_level.tscn` is the source of truth** for platform positions, collision shapes, ladders, and spawn.

- Manual Godot editor changes **override** old manifest-generated geometry.
- **Do not rebake** casually — `tools/bake_main2_level.gd` overwrites the `.tscn` and destroys manual edits.
- Rebaking requires **explicit approval**.

## Phase 2B1 features

- Falling letters (A–Z) from GDevelop group #13 spawn rules
- Player collection → spelling HUD
- Dictionary validation (`EnglishWords4.txt`)
- Score on valid word: `(len/2) + 2×len`
- Submit: **Enter** or **C** (source key) | Delete: **Backspace**

```powershell
& "C:\Godot\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" `
  --headless --path . --script res://tools/validate_phase2b1.gd
```

## Phase 2A features

- GDevelop-origin player movement (walk, jump, ladder, double-tap sprint)
- Camera always follows player at startup (no toggle)
- Baked editable level with grouped platform/ladder nodes
- Collision debug: **F3** or **V**
- Player spawn: **(279, 231)**

## Commands

```powershell
# Phase 1 asset pipeline
python tools/phase1_pipeline.py
python tools/validate_phase1_python.py

# Phase 2A validation (Godot 4.6.3 headless)
& "C:\Godot\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" `
  --headless --path . --script res://tools/validate_phase2a_corrected.gd

& "C:\Godot\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" `
  --headless --path . --script res://tools/probe_phase2a_physics.gd
```

### Regenerate level from manifests (destructive — approval required)

```powershell
python tools/phase2a_collision_manifest.py
& "C:\Godot\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" `
  --headless --path . --script res://tools/bake_main2_level.gd
```

## Reports

- `reports/PHASE0_REPORT.md`
- `reports/PHASE1_REPORT.md`
- `reports/PHASE2A_VALIDATION.md` — Phase 2A sign-off
- `reports/PHASE2A_LEVEL_EDITING.md` — how to edit the level in Godot
- `reports/PHASE2A_SOURCE_MAP.md`
- `reports/PHASE2B1_SOURCE_MAP.md`
- `reports/PHASE2B1_VALIDATION.md`

## Repository layout

Git root is **`Lettrage_Godot/`** only. Parent workspace may contain `SnatchWord1/` (untracked, not in repo).
