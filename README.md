# Lettrage — Godot Conversion Project

Snatch Word conversion from GDevelop (`SnatchWord1/GAME25.json`) to Godot 4.6.

**Baseline layout:** `Main2_heallthbartest`  
**Sibling folder:** `SnatchWord1/` is read-only reference — do not modify.

## Phase 0/1 status
- Project foundation and `project.godot` (960×540)
- Reference copy: `reference/GAME25.json`
- Active assets copied (characters, alphabet, dictionary, fonts, gameplay audio)
- AAC converted: `assets/crickets.ogg`, `assets/door.ogg`
- SpriteFrames: `resources/sprite_frames/player_frames.tres`, `enemy_frames.tres`
- Phase 1 test: `scenes/test/animation_test.tscn`

## Phase 2A status (movement test)
- **F5 main scene:** `scenes/test/phase2a_movement_corrected.tscn` (platformer movement + collision)
- Static layout reference: `scenes/test/phase2a_layout_verification.tscn`
- Phase 1 animation test (not F5): `scenes/test/animation_test.tscn`
- Failed movement test preserved: `phase2a_movement_test_failed.tscn`
- Reports: `PHASE2A_ROOT_CAUSE.md`, `PHASE2A_INSTANCE_TRANSFORMS.md`

## Commands
```powershell
# Re-run asset pipeline
python tools/phase1_pipeline.py

# Phase 2A layout extract + source map
python tools/phase2a_extract.py
python tools/phase2a_source_map.py

# Offline validation
python tools/validate_phase1_python.py

# Godot headless validation (Godot 4.6.3)
& "C:\Godot\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" `
  --headless --path . --script res://tools/validate_phase1.gd
& "C:\Godot\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" `
  --headless --path . --script res://tools/validate_phase2a.gd
```

Reports: `reports/PHASE0_REPORT.md`, `reports/PHASE1_REPORT.md`, `reports/PHASE2A_SOURCE_MAP.md`, `reports/PHASE2A_VALIDATION.md`
