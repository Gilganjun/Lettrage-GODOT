# Phase 2A Validation Report (Corrected Movement)

**Phase 2A status: NOT COMPLETE — manual gameplay validation pending user confirmation**

## Validation tiers

| Tier | Status |
|------|--------|
| Syntax / parse validation | **PASSED** (headless) |
| Resource loading validation | **PASSED** |
| Collision-data validation | **PASSED** (behavior-based, PlatformCollision excluded) |
| Camera-state validation | **PASSED** (follow enabled at startup, zoom 1.0) |
| Static visual layout | **PASSED** (user approved) |
| Physics probe (air spawn → land) | **PASSED** (headless) |
| Manual gameplay validation | **PENDING USER** |

## F5 main scene

`res://scenes/test/phase2a_movement_corrected.tscn`

Preserved scenes (unchanged):
- `phase2a_layout_verification.tscn`
- `phase2a_movement_test_failed.tscn`
- `animation_test.tscn`

## Startup defaults (corrected)

| Setting | Value |
|---------|-------|
| Camera | Always follows player (no keyboard toggle) |
| Debug | **OFF** (toggle with F3 or V) |
| Player spawn | **(279, 231)** — original GDevelop air spawn |
| Camera zoom | **Vector2(1, 1)** — dynamic jump/death zoom deferred |

## Input

| Key | Action |
|-----|--------|
| F3 / V | Toggle collision debug (`toggle_collision_debug`) |

No camera toggle — scrolling is always on during gameplay.

## Godot headless commands

```
Godot_v4.6.3-stable_win64_console.exe --headless --path Lettrage_Godot --script res://tools/validate_phase2a_corrected.gd
Godot_v4.6.3-stable_win64_console.exe --headless --path Lettrage_Godot --script res://tools/probe_phase2a_physics.gd
```

## Manual gameplay checklist

- [ ] F5 — camera scrolls immediately (no key press required)
- [ ] Player starts at **(279, 231)**, falls, lands on green Platform1 grass (~Y 508.6)
- [ ] Fall / Idle / Run / Jump / Climb animations correct
- [ ] A/D walk scrolls camera automatically
- [ ] **C** toggles FOLLOW / FIXED; HUD updates
- [ ] **Ctrl+C** does nothing
- [ ] **F3** or **V** toggles debug outlines; HUD shows Debug ON/OFF
- [ ] Debug shows environment colliders + player body + ladder areas
- [ ] No invisible walkable surfaces return

## Key collision decision (unchanged)

**PlatformCollision** and other helpers without PlatformBehavior remain excluded from physics. Walk surface uses **customCollisionMask top** for Platform1 (Y ≈ 508.6).

## Git commit hash

Not available — workspace is not a git repository.
