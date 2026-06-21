# Lettrage Godot — Agent Handoff

**Date:** June 2026  
**Engine:** Godot 4.6.3  
**Repo root:** `Lettrage_Godot/`  
**Remote:** https://github.com/Gilganjun/Lettrage-GODOT  
**GDevelop source (read-only, outside git):** `SnatchWord1/GAME25.json`  
**Baseline level:** `Main2_heallthbartest` → `scenes/levels/main2_heallthbartest_level.tscn`

---

## Executive summary

Since the last agent handoff (which still treated `phase2c1_health_damage_test.tscn` as the active F5 scene), the project has moved to a **production main scene** with best-of-3 rounds, round intro cinematics, unified debug tooling, and several combat/visual polish fixes. **Most of this work is local and uncommitted** — last git commit on `master` is `a624f0b`; production gameplay, match flow, intro, debug dock, letter backdrops, and many related files are **untracked or modified** in the working tree.

**Run F5** on `scenes/main/lettrage_gameplay.tscn` for the intended experience.  
**Run F6** on `scenes/test/phase2c1_health_damage_test.tscn` only as a **legacy harness** — do not develop new features there unless explicitly asked.

---

## Scene architecture (critical)

| Scene | Purpose |
|-------|---------|
| **`scenes/main/lettrage_gameplay.tscn`** | **Production (F5 main scene)** — match loop, intro, debug dock |
| `scenes/test/phase2c1_health_damage_test.tscn` | Legacy debug harness — frozen reference |
| `scenes/levels/main2_heallthbartest_level.tscn` | Shared level geometry (single source of truth) |

Both production and legacy harness **instance the same level**. Divergence is in **orchestrator scripts only** (`lettrage_gameplay.gd` vs `phase2c1_health_damage_test.gd`). The user wants **one living production scene** with `@export debug_mode`; phase2c1 should stay untouched as legacy.

### Production-only features (do not remove)

These exist **only** in `lettrage_gameplay` and were a source of confusion when comparing to phase2c1:

- **`MatchController`** + **`MatchOverlay`** — best-of-3 rounds, countdown, FIGHT flash, round/match win/loss
- **`GameplayRoundReset`** — resets positions, HP, words, letters, ammo, ACTION charges between rounds
- **Round intro cinematic** — player drops from above, camera zooms from close to normal (`camera_zoom_controller.gd`, `intro_fall_fx.gd`, `gameplay_round_reset.gd`)
- **`LevelGameplayConfig`** (`resources/gameplay/level1_config.tres`) — font set, intro timing, round counts
- Letter/ACTION spawner **paused until round active**; player/enemy **movement_locked** until FIGHT
- **No auto-respawn** — death ends round via match controller
- **`YouWinVoicePlayer`** / splash FX on match overlay

**Known intro bug (fixed):** Do **not** call `activate_follow_camera()` deferred after match intro starts — it resets zoom immediately. Comment in `lettrage_gameplay.gd` explains this.

---

## Work completed since last handoff

### 1. Phase 2C3 — Production playable loop

**Files:** `scripts/main/lettrage_gameplay.gd`, `scenes/main/lettrage_gameplay.tscn`, `scripts/gameplay/match_controller.gd`, `gameplay_round_reset.gd`, `level_gameplay_config.gd`, `scenes/ui/match_overlay.tscn`

- Best-of-3 match (`rounds_to_win = 2`, `match_rounds = 3`)
- Countdown → intro fall → FIGHT → round play → round result → inter-round countdown
- Waits for ACTION sequence to finish before round-end presentation when applicable
- Temp debug key **F7** (debug mode only): set enemy to 2 HP for quick word-kill testing

### 2. Round intro cinematic

**Files:** `scripts/player/camera_zoom_controller.gd` (intro API), `scripts/player/intro_fall_fx.gd`, `scripts/player/player_movement.gd` (intro fall), `gameplay_round_reset.gd`

- Player drops from configurable top Y (`intro_drop_top_y = -320` in level config)
- Camera starts zoomed in (`intro_close_zoom_percent = 175`) and eases out during countdown
- Upward streak particles during fall (`IntroFallFx` on player scene)
- Intro shields forced on player/enemy during drop

### 3. Letter visibility & readability

**Files:** `shaders/letter_tint.gdshader`, `scripts/letters/letter_tint.gd`, `scripts/resources/alphabet_catalog.gd`, `scripts/letters/letter.gd`

- Multi-layer outline (dark rim, white inner ring, outer glow), brightness/saturation boost
- Fixed double-tint darkening (`letter.gd` keeps `modulate = WHITE` on shader path)
- Fixed invalid `boosted.to_hsv()` → Godot 4 uses `.h`, `.s`, `.v` on `Color`
- Hue-aware boost for purple/blue letters in catalog

### 4. Letter circle backdrops (BG1–BG4)

**Files:** `scripts/letters/letter_backdrop_registry.gd`, `assets/Letter_Circle_BG*.png`, `letter.gd` (`refresh_backdrop`, `_get_letter_display_size`)

- Four backdrop assets resized to **256×256**
- Backdrop sized from **on-screen letter size** (`_target_world_size`), not full 512×512 export canvas — fixes oversized circles on Cyberpunk font
- **KEY 9** cycles backdrops in **legacy phase2c1 only**; production cycles via **debug mode KEY 9**

### 5. Enemy idle sliding fix

**Files:** `scripts/enemy/enemy.gd`, `scripts/enemy/enemy_movement_controller.gd`

**Problem:** Enemy played Idle animation while still drifting horizontally.

**Fixes applied:**
- `IDLE_VELOCITY_EPSILON := 2.0` — aligned idle vs run threshold and velocity snap
- Re-fetch `patrol_dir` **after** `clear_letter_chase()` in `_process_platformer()`
- `_refresh_patrol_direction()` for clean patrol direction in animation/watchdog paths
- Snap `velocity.x = 0` when entering Idle on floor with no move intent
- Prior fix retained: `get_desired_direction()` returns `0` at patrol deadband (not stale `direction`)

**Status:** User reported improvement; verify at patrol turnaround and after letter chase ends if regressions appear.

### 6. ACTION enemy hard freeze (all attacks)

**Files:** `scripts/player/player_action_controller.gd`, `scripts/enemy/enemy.gd`

**Previous behavior:** Hard position freeze (`begin_action_strike_freeze`) only on **Attack 3** (side-slide combo), because freeze was tied to `_uses_side_slides()`.

**Current behavior:** **Attack 1, 2, and 3** all call `begin_action_strike_freeze()` on **first hit** and `end_action_strike_freeze()` on **last hit**. Knockback skip during combo remains Attack-3-only (`skip_knockback := _uses_side_slides()`).

Enemy freeze mechanics in `enemy.gd`:
- `_action_strike_frozen` — pins `global_position`, zero velocity for strike duration
- `set_action_sequence_targeted(true)` at ACTION start — blocks animation state updates (not movement until first hit on non-side-slide attacks before this change; now first hit triggers freeze)

### 7. Production vs phase2 investigation

User noticed features "missing" in production. Finding: **shared combat code**, but **orchestrator drift**. Production had match/intro; phase2c1 had debug keys, font/backdrop cycling, collision overlay, infinite ACTION. Not a missing freeze implementation — rotation through Attack 1/2 looked like no freeze.

**Decision:** Unify on production scene + `debug_mode`; leave phase2c1 as legacy.

### 8. Debug mode in production + collapsible dock

**Files:** `scripts/main/lettrage_gameplay.gd`, `scripts/ui/gameplay_debug_dock.gd`, `scenes/ui/gameplay_debug_dock.tscn`, `scripts/ui/word_game_hud.gd`, `scripts/ui/combat_hud.gd`, `scripts/ui/game_keyboard_commands.gd`

**How it works:**
- `@export var debug_mode: bool = false` on production root
- **Shift+F2** toggles debug mode at runtime
- When on: small **⚙** icon top-left only (collapsed by default)
- Click ⚙ to expand scroll panel with all debug readouts; **×** to collapse
- **No scattered on-screen debug text** (removed top bar, floating labels, ? button, HUD debug overlays)

**Debug panel contents when expanded:** font/backdrop names, spawn stats, enemy AI dump, combat HP details, keyboard shortcuts (`GameKeyboardCommands.format_as_text()`).

**Debug features when `debug_mode` true:**
- Infinite ACTION charges
- Collision overlay (V / F3)
- Font cycle (0), backdrop cycle (9)
- F7–F12, Alt+1–6 combat cheats
- Esc quits (debug only)

**Production when `debug_mode` false:** normal shipping behavior — ACTION pickups required, no debug keys.

---

## ACTION combat system (reference)

**Orchestrator:** `scripts/player/player_action_controller.gd`  
**Attacks:** Rotate by default (Attack1 → Attack2 → Attack3 on each J press)

| Attack | Hits | Side slides | Hard enemy freeze |
|--------|------|-------------|-------------------|
| Attack1 | 3 (frames 17, 56, 91) | No | Yes (since unification) |
| Attack2 | 7 | No | Yes |
| Attack3 | 10 | Yes | Yes |

Camera zoom + hit shake on strikes. Attack2/3 use reduced VFX scale/particle count.

---

## Key file map

| Area | Primary files |
|------|----------------|
| Production root | `scripts/main/lettrage_gameplay.gd`, `scenes/main/lettrage_gameplay.tscn` |
| Match / rounds | `scripts/gameplay/match_controller.gd`, `gameplay_round_reset.gd`, `level1_config.tres` |
| Intro | `camera_zoom_controller.gd`, `intro_fall_fx.gd`, `player_movement.gd` |
| Player ACTION | `player_action_controller.gd`, `action_attack_definition.gd` |
| Enemy | `enemy.gd`, `enemy_movement_controller.gd`, `enemy_animation.gd` |
| Letters | `letter.gd`, `letter_tint.gd`, `letter_spawn_director.gd`, `alphabet_catalog.gd` |
| Debug dock | `gameplay_debug_dock.gd`, `game_keyboard_commands.gd` |
| Legacy harness | `scripts/test/phase2c1_health_damage_test.gd` (do not extend) |
| Level editing | `main2_heallthbartest_level.tscn` — **do not rebake without approval** |

---

## User preferences & constraints

- **Do not push to git** unless explicitly asked
- **Do not commit** unless explicitly asked
- **Do not rebake level** casually — see `reports/PHASE2A_LEVEL_EDITING.md`
- **Minimize scope** on fixes — production intro/match features are sacred
- **Single production scene** + debug flag is the target architecture
- README body still has stale line ("Not implemented: health, damage…") — outdated vs reality

---

## Known gaps / follow-ups

1. **README.md** — "Current gameplay" section outdated; production main scene exists
2. **Git** — Large uncommitted surface (production scene, gameplay scripts, assets, intro, backdrops). Consider commit when user asks
3. **Enemy idle slide** — fixes in place; user should confirm no edge cases remain
4. **Font cycling in production** — only in debug mode; level font from config in normal play
5. **`project.godot` version string** — still `0.5.0-phase2b2b`
6. **Temp debug** — F7 nearly-dead enemy, `debug_infinite_action` flag marked TEMP in action controller
7. **Attack rotation** — user may want FIXED mode for testing specific attacks via Inspector on `PlayerActionController` (runtime-created on player, not in scene tree by default)
8. **Level difficulty — enemy ICON AI** — `EnemyActionController.icon_jump_enabled` (default `true`): when `false`, enemy only runs under the icon (passive pickup); when `true`, jumps to reach falling icons. Wire per-level via `LevelGameplayConfig` or enemy spawn row on later levels for escalating intelligence/difficulty.
9. **Enemy ACTION approach** — `Enemy.tick_action_approach_movement()` scans obstacles and auto-jumps during approach; tune hop speeds via `_compute_obstacle_hop_speed()` if obstacles still block on specific levels.
10. **Strike camera experiment** — `ActionStrikeCameraDirector` randomly picks PRIMARY (existing approach zoom + hit shake) vs DRAMATIC (per-hit slow-mo + tight zoom 4 frames before → 2 frames after each hit frame). Tunables on `PlayerActionController` / `EnemyActionController`: `dramatic_strike_camera_chance` (default 0.35), `dramatic_strike_slow_scale`, `dramatic_strike_screen_fill`. Set chance to `1.0` to test dramatic only; `0.0` for legacy camera only.

---

## How to test

```text
F5  → scenes/main/lettrage_gameplay.tscn     (production)
F6  → scenes/test/phase2c1_health_damage_test.tscn  (legacy only)

Shift+F2  → toggle debug mode (production)
⚙ icon    → expand/collapse debug panel
V / F3    → collision overlay (debug mode)
J         → ACTION attack (needs charge unless debug mode)
```

**Verify round intro:** F5 production — countdown, player fall from top, camera zoom-out, then FIGHT. Not present in phase2c1.

**Verify enemy freeze:** J with debug mode on — enemy should pin on first hit for all three attack types in rotation.

---

## Agent transcript

Full conversation JSONL (includes prior handoff context, letter visibility, intro bug, idle slide, production/phase2 analysis, debug dock):

`C:\Users\sbash\.cursor\projects\c-Users-sbash-OneDrive-Documents-Lettrage-GD-to-Godot-Cursor\agent-transcripts\6573a5c1-028c-4691-8c9a-051d77fec3ae\6573a5c1-028c-4691-8c9a-051d77fec3ae.jsonl`

Search keywords: `strike_freeze`, `idle slide`, `lettrage_gameplay`, `debug_mode`, `GameplayDebugDock`, `intro_drop`, `letter_backdrop`.

---

## Suggested next steps for incoming agent

1. User playtest F5 — confirm intro, debug dock UX, enemy freeze on all attacks, idle at patrol stops
2. If user asks to commit — stage production + gameplay + related assets; avoid `tools/__pycache__`
3. Do **not** duplicate features into phase2c1 — extend production `lettrage_gameplay.gd` only
4. Update README when user requests — reflect F5 production, debug_mode, deprecate phase2c1 as primary
5. Any new keyboard shortcuts → add to `game_keyboard_commands.gd` (single source of truth)
