# Phase 2A Validation Report (Corrected Movement)

**Phase 2A status: COMPLETE** (2026-06-14)

Automated validation and physics probe passed. Manual level edits in the baked scene are the authoritative baseline. Phase 2B has not started.

## Validation tiers

| Tier | Status |
|------|--------|
| Syntax / parse validation | **PASSED** (headless, 0 errors) |
| Resource loading validation | **PASSED** |
| Collision-data validation | **PASSED** (behavior-based; PlatformCollision excluded from physics) |
| Camera-state validation | **PASSED** (follow enabled at startup, zoom 1.0, no toggle) |
| Physics probe (air spawn → land) | **PASSED** (headless, exit 0) |
| Authoritative level scene | **PASSED** — `main2_heallthbartest_level.tscn` (manually edited) |
| Manual gameplay validation | **PASSED** (user confirmed traversal after collision extension) |

## Authoritative level baseline

**Do not rebake or regenerate without explicit approval.**

| Item | Path |
|------|------|
| Edit level in Godot 2D | `res://scenes/levels/main2_heallthbartest_level.tscn` |
| Play movement test (F5) | `res://scenes/test/phase2a_movement_corrected.tscn` |

The movement test **instances** the baked level scene. Manual `.tscn` edits override manifest-derived geometry in `collision_manifest.json`.

### Manual collision edit (Phase 2A close)

Bottom platform **`Platforms/Platform1_003`** collision was extended in the Godot editor so the player can traverse without falling through gaps:

- `StaticBody2D/CollisionShape2D` shape width: **2031×32** (was ~814×32 from initial bake)
- Collision shape local offset adjusted to cover the full walkable strip
- User confirmed: character no longer falls through at platform transitions

Manifests and `gdevelop_level_baker.gd` remain reference/regeneration tools only.

## F5 main scene

`res://scenes/test/phase2a_movement_corrected.tscn`

Preserved diagnostic scenes (unchanged):

- `phase2a_layout_verification.tscn`
- `phase2a_movement_test_failed.tscn`
- `animation_test.tscn`

## Startup defaults

| Setting | Value |
|---------|-------|
| Camera | **Always follows player** at startup (no keyboard toggle) |
| Debug | **OFF** (toggle with F3 or V) |
| Player spawn | **(279, 231)** — original GDevelop air spawn |
| Camera zoom | **Vector2(1, 1)** — dynamic jump/death zoom deferred |

## Input

| Key | Action |
|-----|--------|
| A / D | Move left / right |
| Space | Jump |
| W / S | Climb up / down (on ladder) |
| Double-tap A or D | Sprint (floor only, max speed 400) |
| F3 / V | Toggle collision debug |
| Esc | Quit |

No camera toggle — scrolling is always on during gameplay.

## Godot headless commands

```powershell
& "C:\Godot\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" `
  --headless --path Lettrage_Godot --script res://tools/validate_phase2a_corrected.gd

& "C:\Godot\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" `
  --headless --path Lettrage_Godot --script res://tools/probe_phase2a_physics.gd
```

### Latest automated run (Phase 2A close)

**validate_phase2a_corrected.gd:** Summary **0 errors** — PASSED

**probe_phase2a_physics.gd:** Exit **0** — PASSED

- 9 static bodies detected in baked level
- Player spawn at (279, 231)
- Camera enabled and current at startup
- Air spawn → lands on floor within expected Y range

## Manual gameplay checklist (signed off)

- [x] F5 — camera scrolls immediately (no key press required)
- [x] Player starts at **(279, 231)**, falls, lands on Platform1 walk surface
- [x] A/D walk scrolls camera automatically
- [x] Bottom platform collision extended — no fall-through at gaps
- [x] F3 / V toggles debug outlines
- [x] Camera follow always enabled (no C-key toggle)

## Key collision decisions (unchanged)

- **PlatformCollision** and other helpers without PlatformBehavior remain **excluded from physics**
- Original GDevelop walk-surface math uses **customCollisionMask top** (documented in `PHASE2A_COLLISION_MAP.md`)
- Runtime movement test uses collision shapes from the **edited baked level**, not runtime manifest spawning

## Phase 2B

**Not started.** Enemy, letters, dictionary gameplay, score, health, shield, projectiles, and mobile controls remain out of scope.

## Git

Repository root: `Lettrage_Godot/`  
Remote: `https://github.com/Gilganjun/Lettrage-GODOT`

See latest commit hash in project README or `git log -1`.
