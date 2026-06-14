# Phase 2B2A Source Map — Enemy Foundation (Group #14)

**Baseline layout:** `Main2_heallthbartest`  
**Comparison layout:** `Main2_RedoAI_CharAnim` (group #14 only)  
**Source:** `reference/GAME25.json` — event group index **14**, name **`ENEMY AI `**  
**Scope:** Enemy movement, animation, patrol foundation only. **No letter collection, word gameplay, health, shield, or projectiles.**

---

## Enemy spawn

| Field | Source value | Godot |
|-------|--------------|-------|
| Layout | `Main2_heallthbartest` | — |
| Object | `Enemy` | `scenes/enemy/enemy.tscn` |
| **X** | **740** | `resources/enemy/enemy_spawn.json` |
| **Y** | **406** | same |
| customSize | true | GDevelopTransform |
| width × height | 92.78 × 115.86 | collision + sprite sizing |
| zOrder | 100 | `z_index = 90` (below player) |

Enemy is **not** baked into `main2_heallthbartest_level.tscn` — spawned by test scene at source coordinates.

---

## PlatformerObject (Enemy)

Verified from `GAME25.json` Enemy object (`PlatformBehavior::PlatformerObjectBehavior`):

| Parameter | Enemy | Player (do not reuse) |
|-----------|-------|------------------------|
| **gravity** | **1700** | 900 |
| **jumpSpeed** | **900** | 500 |
| **maxSpeed** | **300** | 200 |
| **acceleration** | **1125** | 1125 |
| **deceleration** | **1125** | 1125 |
| **maxFallingSpeed** | **500** | 400 |
| **ladderClimbingSpeed** | **300** | 300 |
| **jumpSustainTime** | **0.3** | 0.3 |
| **ignoreDefaultControls** | **true** | false |
| canGoDownFromJumpthru | false | true |
| canGrabPlatforms | false | false |
| slopeMaxAngle | 60 | 60 |
| xGrabTolerance | 10 | 10 |

**Godot resource:** `resources/enemy/enemy_movement_config.tres`  
**Script:** `scripts/resources/enemy_movement_config.gd`

---

## Scene variables (patrol / AI)

| Variable | Initial | Active in heallthbartest? | Phase 2B2A |
|----------|---------|---------------------------|------------|
| **EnemyMinX** | 300 | **Disabled** events only | Implemented (patrol bound) |
| **EnemyMaxX** | 2000 | **Disabled** events only | Implemented (patrol bound) |
| **EnemyTargetX** | 0 | **Disabled** target wander | Implemented (random retarget) |
| **EnemyDirection** | 0 | Never referenced | Not used |
| **EnemyJumpCooldown** | 0 | Ticked, never read | Implemented as jump gate (0.35s) |
| ShieldToggleEnemy | 0 | Active (shield phase) | **Deferred** |
| InjuryFreezeEnemy | — | Gates Run/Idle | **Deferred** |
| EnemyDeath | — | Gates letter chase | **Deferred** |

### Disabled patrol logic (heallthbartest — design basis for 2B2A)

| Step | Source |
|------|--------|
| DepartScene | `EnemyMinX=300`, `EnemyMaxX=2000`, `EnemyTargetX=RandomInRange(min,max)` |
| Near target | `abs(Enemy.X - EnemyTargetX) < 20` → pick new target |
| Move right | `Enemy.X < EnemyTargetX - 5` → SimulateControl `"Right"` |
| Move left | `Enemy.X > EnemyTargetX + 5` → SimulateControl `"Left"` |

Godot: `EnemyMovementController` — target-X wander with 5px deadband, 20px retarget threshold.

### Active letter-chase (heallthbartest — **deferred to 2B2B**)

- `AddForceVers(Enemy, Ln, 300)` toward matching letter
- 26 per-letter branches, collection, shield — **not implemented in 2B2A**

---

## Edge / obstacle detection

| Mechanism | Source status | Godot 2B2A |
|-----------|---------------|------------|
| Raycast block | **Disabled** | FloorRayLeft/Right + WallRayLeft/Right |
| LeftBoundary flip | **Disabled** | Wall ray reverse |
| Platform3 auto-jump | **Disabled** | Jump on wall/stuck with cooldown |
| Pathfinding to ladder | **Disabled** | **Deferred** |

---

## Jump behaviour

| Rule | Source | Godot 2B2A |
|------|--------|------------|
| Letter-chase jump roll | `RandomInRange(1,4)` | **Deferred** |
| Obstacle jump | Disabled Platform3 branch | Jump when wall blocked + cooldown |
| Stuck recovery | — | Stuck timer → jump |
| **EnemyJumpCooldown** | Unused in source | 0.35s gate |

---

## Ladder / climb

**Active in source:**

```
IsOnLadder(Enemy) → SetAnimationName "Climb" + SimulateControl "Up"
```

Godot: overlap level ladder areas → climb up at `ladder_climbing_speed` (300).  
Ambiguous pathfinding-to-ladder branches remain **deferred**.

---

## Animation FSM

| State | Source condition | Godot animation |
|-------|------------------|-----------------|
| Idle | NOT `IsMovingEvenALittle` | Idle |
| Run | `IsMovingEvenALittle` | Run |
| Jump | `IsJumping` | Jump |
| Fall | `IsFalling`, dist to Platform1 **> 61** | Fall |
| Near-ground fall | `IsFalling`, dist **≤ 60** | Run |
| Climb | `IsOnLadder` | Climb |
| Death | — | **Unused** |

**Script:** `scripts/enemy/enemy_animation.gd` — does not restart same animation every frame.

Sprite faces movement direction via `flip_h`.

---

## Visual profile (independent from Player)

**Resource:** `resources/characters/enemy_visual.tres`  
**SpriteFrames:** `resources/sprite_frames/enemy_frames.tres` (separate from player)

| Effect | Source (GAME25.json) | Implemented now | Deferred |
|--------|----------------------|-----------------|----------|
| **DarkNight** | intensity=0.5, opacity=0.5 | **modulate (0.75, 0.75, 0.75, 1)** | — |
| **Glow** | RGB 255;42;17, dist=15, inner=1, outer=2 | Metadata in profile | Shader rendering |
| display_scale | object-level 0.45 | Stored in profile | — |

Replacing enemy artwork: assign new `sprite_frames` on `enemy_visual.tres` only — Player unchanged.

---

## Collision layers (Godot)

| Layer | Bit | Name | Enemy |
|-------|-----|------|-------|
| 1 | 1 | world | mask ✓ |
| 2 | 2 | ladder | mask ✓ |
| 3 | 4 | player | — |
| 4 | 8 | letters | — |
| 5 | 16 | **enemy** | **layer ✓** |

| Body | layer | mask | Notes |
|------|-------|------|-------|
| Player | 4 | 3 | Unchanged |
| Enemy | 16 | 3 | World + ladder only |
| Letters | 8 | 4 | Player only — enemy cannot collect |

**Player ↔ Enemy:** pass through (neither includes the other's layer in mask).

---

## heallthbartest vs RedoAI_CharAnim (group #14)

| Feature | heallthbartest | RedoAI_CharAnim |
|---------|----------------|-----------------|
| Spawn | (740, 406) | Same |
| PlatformerObject | Same values | Same |
| Letter chase force 300 | **Active** | Active — **deferred 2B2B** |
| Target-X patrol | **Disabled** | **Active** |
| Enemy Wander (dist > 250) | Absent | **Active** — experimental |
| Animations / climb | Active | Largely same |

**Phase 2B2A uses:** heallthbartest physics + animation + disabled patrol design (not RedoAI wander).

---

## Deferred to later phases

- Enemy letter collection / word / dictionary / score
- Shield toggle + glow runtime
- Injury freeze, death, health
- RedoAI wander block
- RedoAI sub#40
- Fly enemy (group #15)
- Pathfinding to ladder
- Projectiles, damage, mobile controls

---

## Phase 2B2A test scene

| Role | Path |
|------|------|
| **F5 main scene** | `scenes/test/phase2b2a_enemy_movement_test.tscn` |
| Enemy scene | `scenes/enemy/enemy.tscn` |
| Level (unchanged) | `scenes/levels/main2_heallthbartest_level.tscn` |
| Phase 2B1 test (unchanged) | `scenes/test/phase2b1_word_game_test.tscn` |
| Phase 2A test (unchanged) | `scenes/test/phase2a_movement_corrected.tscn` |
