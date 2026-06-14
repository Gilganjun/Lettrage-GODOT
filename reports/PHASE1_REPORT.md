# Phase 1 Report — Assets, AAC, SpriteFrames, Validation

## Phase 1 correction (dual-character test)

### Problem fixed
- Single character, alphabetically sorted animations (caused confusing cycle order)
- Space cycled animations instead of play/pause
- No Enemy instance, labels, frame counter, or UI buttons
- Player and Enemy shared one AnimatedSprite2D architecture

### Character visual architecture
| Component | Path |
|-----------|------|
| Resource script | `scripts/resources/character_visual_profile.gd` |
| Player profile | `resources/characters/player_visual.tres` |
| Enemy profile | `resources/characters/enemy_visual.tres` |
| Player SpriteFrames | `resources/sprite_frames/player_frames.tres` |
| Enemy SpriteFrames | `resources/sprite_frames/enemy_frames.tres` |

**Independence:** Two separate `CharacterVisualProfile` `.tres` instances. Each references its own `SpriteFrames` resource. Both SpriteFrames reference the same underlying PNG files under `res://characters/` (no duplicate PNG copies). Swapping `enemy_visual.tres` → different SpriteFrames does not change `player_visual.tres`.

### Source JSON effects applied (Main2_heallthbartest)

**Player**
- Glow: RGB(255, 28, 68), distance=30, inner=2, outer=2
- No modulate in source → `modulate = white`
- Glow shader not replicated in Phase 1; values stored on profile

**Enemy (placeholder art)**
- DarkNight: intensity=0.5, opacity=0.5 → `modulate = (0.75, 0.75, 0.75)` derived darkening only
- Glow: RGB(255, 42, 17), distance=15, inner=1, outer=2 (metadata; not final enemy design)

### Explicit animation order (never sorted at runtime)

**Player:** Idle, Run, Climb, Jump, Fall, Death, Sprint, Crouch, Roll, Kick2, Kick  
**Enemy:** Idle, Run, Climb, Jump, Fall, Death

### Controls
| Input | Action |
|-------|--------|
| A / D | Player prev / next animation |
| ← / → | Enemy prev / next animation |
| Space | Play / pause both |
| R | Restart both from frame 0 |
| UI buttons | Same actions per character |

### Files changed in correction
- `scripts/resources/character_visual_profile.gd` (new)
- `resources/characters/player_visual.tres` (new)
- `resources/characters/enemy_visual.tres` (new)
- `scenes/test/character_preview_slot.gd` (new)
- `scenes/test/character_preview_slot.tscn` (new)
- `scenes/test/animation_test.gd` (rewritten)
- `scenes/test/animation_test.tscn` (rewritten)
- `tools/validate_phase1.gd` (updated)
- `tools/validate_phase1_python.py` (updated)

---

## Asset copy (original Phase 1)
- Copy operations logged: **269**
- Unique character animation images: **64**
- Missing animation sources: **0**

## AAC conversion
- FFmpeg available: **True**
- crickets.aac → `assets/crickets.ogg` ✓
- door.aac → `assets/door.ogg` ✓

## SpriteFrames (Main2_heallthbartest baseline)
- Player: 11 animations
- Enemy: 6 animations
- Files: `resources/sprite_frames/player_frames.tres`, `enemy_frames.tres`

## Validation results

### Python (`tools/validate_phase1_python.py`)
**15/15 passed**

### Godot 4.6.3 headless
```
C:\Godot\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe
  --headless --path <Lettrage_Godot> --script res://tools/validate_phase1.gd
```
**PASSED** — profiles independent, animation order correct, dual scene instantiates, no missing textures.

### Manual visual test
Open project in Godot → F5. Both characters side-by-side with live frame counter.

## Not in scope
- Gameplay / Phase 2 systems
- Main2_RedoAI_CharAnim group #14
- Glow shader implementation (metadata only)

## Remaining Phase 1 issues
- Glow effect is documented but not visually rendered (GDevelop shader not ported)
- DarkNight approximated via modulate only; not identical to GDevelop Night effect
