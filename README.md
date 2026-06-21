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
| Phase 2B1 — Player letters, spelling, dictionary, score | **Implemented** |
| Phase 2B2A — Enemy movement, obstacle escape | **Implemented** |
| Phase 2B2B — Shields, enemy word AI, HUD | **Implemented** — manual F5 sign-off pending |
| Phase 2C2 — Combat actions (ammo, roll, ACTION) | **Implemented** |
| Phase 2C3 — Production playable loop | **Implemented** — `lettrage_gameplay` main scene |

## Scenes

| Purpose | Scene |
|---------|-------|
| **F5 — production gameplay** | `scenes/main/lettrage_gameplay.tscn` |
| **Debug / tuning harness** | `scenes/test/phase2c1_health_damage_test.tscn` |
| **Edit level in Godot 2D** | `scenes/levels/main2_heallthbartest_level.tscn` |
| Older phase tests (archived) | `scenes/test/archive/` |

See `scenes/test/README.md` for details. Archived scenes are not used for F5.

Visual hierarchy rules: `VISUAL_STYLE.md` (phase2c1 visual pass).

### Authoritative level baseline

**`main2_heallthbartest_level.tscn` is the source of truth** for platform positions, collision shapes, ladders, and spawn.

- Manual Godot editor changes **override** manifest-generated geometry.
- **Do not rebake** casually — `tools/bake_main2_level.gd` and `gdevelop_level_baker.gd` **overwrite** the `.tscn` and destroy manual edits (including `Platform1_003` extended collision).
- Rebaking requires **explicit approval**. See `reports/PHASE2A_LEVEL_EDITING.md`.

## Current gameplay (Phase 2B2B)

- Falling letters A–Z with per-letter tint colours (`letter_tint.gdshader`)
- Player collection → spoken letter WAVs + pop SFX → spell → dictionary validation → score
- Player **LCtrl** toggle shield — breaks letters (pop SFX only, no spoken letter)
- Enemy patrol, obstacle escape, letter chase, word building, auto-score
- Enemy shield AI — collection gate + destroy non-target letters
- Letter destroy shatter VFX on collect/shield break
- HUD: **Shift+F2** toggles full HUD; **player word always visible**

**Not implemented:** health, damage, death, respawn, projectiles, menus, mobile controls, production main scene.

## Validation

```powershell
& "C:\Godot\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" `
  --headless --path . --script res://tools/validate_phase2a_corrected.gd

& "C:\Godot\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" `
  --headless --path . --script res://tools/validate_phase2b1.gd

& "C:\Godot\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" `
  --headless --path . --script res://tools/validate_phase2b2a.gd

& "C:\Godot\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" `
  --headless --path . --script res://tools/validate_phase2b2b.gd
```

## Reports

- `reports/PHASE2B2B_VALIDATION.md` — current phase sign-off checklist
- `reports/PHASE2B2B_SOURCE_MAP.md` — GDevelop → Godot mapping
- `reports/PHASE2A_LEVEL_EDITING.md` — how to edit level (do not rebake)
- `reports/BACKGROUND_COVERAGE_ANALYSIS.md` — camera vs BG edge gaps
- Earlier phases: `PHASE0_REPORT.md` through `PHASE2B2A_VALIDATION.md`

## Repository layout

Git root is **`Lettrage_Godot/`** only. Parent workspace may contain `SnatchWord1/` (untracked, not in repo).
