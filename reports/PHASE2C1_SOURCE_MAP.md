# Phase 2C1 Source Map — Health, Word Damage, Injury, Death

**Scene authority:** `Main2_heallthbartest` in `reference/GAME25.json`  
**Comparison only:** `Main2_RedoAI_CharAnim` (Enemy health branch parity — not automatic authority)

---

## Initial and maximum health

| Actor | Object variable | Initial | Maximum |
|-------|-----------------|---------|---------|
| Player | `Health` / `MaxHealth` | **50** | **50** |
| Enemy | `EnemyHealth` / `EnemyMaxHealth` | **50** | **50** |

**Scene variable (display only):** `PlayerHealth = 100` at scene start — UI scaling (2× object health). **Gameplay damage uses object `Health` (50), not scene `PlayerHealth`.**

---

## Health variable names

- **Player:** `Health`, `MaxHealth` (object); `PlayerHealth` (scene — HUD scaling)
- **Enemy:** `EnemyHealth`, `EnemyMaxHealth` (object)
- **Injury flags:** `InjuryFreeze` (player), `InjuryFreezeEnemy` (enemy) — scene variables, `0`/`1`
- **Death flag:** `PlayerDeath` (scene) — gates injury recovery

---

## Word-completion damage (active branches)

### Enemy word → Player damage

**Trigger:** `EnemyLetterIndex == StrLength(EnemyWord)` with **Once** (group HEALTH BARS / PLAYER INJURED, ~line 28935)

**Formula (active):**
```
damage = (EnemyLetterIndex / 2) + (EnemyLetterIndex * 2)
       = (word_len >> 1) + (2 * word_len)
```

Uses **word length** (`EnemyLetterIndex` at completion equals word length). **Not** Player score. **Not** a fixed constant.

**Disabled alternative:** separate `PlayerHealth` scene var subtract uses `damage * 2` — HUD-only scaling; object `Health` uses the formula above.

### Player valid word → Enemy damage

**Trigger:** C key + non-empty `SpellWord` + dictionary hit with **Once** (Enemy Injured block, ~line 29827)

**Formula (active):**
```
damage = (PlayerLetterIndex / 2) + (PlayerLetterIndex * 2)
```

Same structural formula as score delta. **Player completed words DO damage the Enemy.**

### Symmetry

| Direction | Damages opponent? |
|-----------|-------------------|
| Enemy completes target word | **Yes** → Player `Health` |
| Player submits valid dictionary word | **Yes** → Enemy `EnemyHealth` |

Both directions are source-confirmed. Damage formula matches score formula structure but is applied as **separate health subtraction**, not by reusing score value.

### Which completions cause damage?

- **Enemy:** only when full target word collected (`EnemyLetterIndex == StrLength(EnemyWord)`), not per-letter
- **Player:** only on **valid dictionary submission** (C key), not invalid words or letter collection alone

---

## Damage examples (formula `(len>>1) + 2*len`)

| Word length | Damage |
|-------------|--------|
| 2 (minimum) | 5 |
| 3 | 7 |
| 4 | 10 |
| 5 | 12 |
| 7 | 17 |

---

## Health clamping

- Object health subtracted via `ModVarObjet` with `- damage`; GDevelop does not show explicit floor clamp beyond death at `<= 0`
- **Godot:** clamp `current_health` to `[0, max_health]`; no overheal above max

---

## Injury / freeze behaviour

| | Player (`InjuryFreeze`) | Enemy (`InjuryFreezeEnemy`) |
|--|-------------------------|------------------------------|
| Set on hit | `1` | `1` |
| Duration | **Wait 3 seconds** then recover if `PlayerDeath == 0` | **Wait 3 seconds** then recover |
| Controls | `IgnoreDefaultControls` yes | `IgnoreDefaultControls` yes |
| Animation | Injury tweens ~1000ms, **90° angle** knock; some knockback tweens **disabled** | Same pattern toward player/LeftSpawn |
| Recovery | `InjuryFreeze = 0`, angle 0, **Idle** | `InjuryFreezeEnemy = 0`, angle 0, **Idle** |

**Letter collection:** blocked while frozen (ignore default controls + injury state in Godot via `blocks_collection` / `blocks_ai`).

**Shield during injury:** source does not explicitly toggle shield off on injury; shield toggle blocked while injured/dead in Godot Phase 2C1.

---

## Invulnerability / damage cooldown

**No separate i-frames** in active source beyond injury freeze blocking controls. Repeated word completions during injury could theoretically stack damage in GDevelop; Godot applies damage whenever `apply_damage` is called and character is not dead.

---

## Hit feedback (source)

| Effect | Player hit | Enemy hit |
|--------|------------|-----------|
| Flash | Yes (colour modulation) | `Flash` behaviour, 3 flashes |
| Explosion | `ExplosionHealth1`, `ExplosionHealth2` | `ExplosionHealth1`, `ExplosionHealth2` |
| BasicExplosion variants | Player injury block | — |
| Sound | Artillery strike WAV | Artillery strike WAV |
| Camera shake | Not explicit in health block | Not explicit |

**Godot Phase 2C1:** hit flash + `530886__eflexmusic__incoming-artillery-strike-cinematic-explosion.wav`. Explosion particles optional/deferred.

---

## Death conditions

| Actor | Condition | Once? | UI text |
|-------|-----------|-------|---------|
| Player | `Health <= 0` | Yes | Spelling → `"YOU LOSE"` |
| Enemy | `EnemyHealth <= 0` | Yes | EnemyCollectedLetters → `"YOU WIN"` |

**Death animation:** `Death` animation name on Player/Enemy sprites when health depleted (injury block sets Death anim when `InjuryFreeze==1` and health path — death uses `Health <= 0` branch).

**Movement/AI while dead:** platformer ignore controls; no patrol/targeting.

---

## Death timing and reset

- Source: **no test respawn** in `Main2_heallthbartest` — EndScreen / production flow out of scope
- **Godot Phase 2C1:** documented **2.5s test respawn** at spawn positions (Player spawn from level, Enemy `(740, 406)`)

---

## Health bar HUD (source)

| Element | Logic |
|---------|---------|
| Player bar width | `clamp(Health/MaxHealth * 130, 0, 130)` |
| Enemy bar width | `clamp(EnemyHealth/EnemyMaxHealth * 130, 0, 1230)` — **1230 is typo; 130 intended** |
| Bulb fill height | `clamp(health/max * 63, 0, 63)` |
| Art | `Health Bar Box.png`, `Healthbar1*.png` — **not imported**; Godot uses procedural bars at 130px max width |

**Positions:** screen-fixed HUD layer; adapted for 960×540 with top-left margin bars.

**Shift+F2:** health bars remain visible (core gameplay UI); numeric debug + combat debug label toggle with word HUD debug.

---

## Shield vs word-completion damage

**Shields block letter collision/collection only** (destroy letter, no WAV, no word append).  
**No source rule** makes shields block completed-word damage. Phase 2C1 preserves this separation.

---

## Disabled / obsolete branches (do not port)

- Injury knockback Y tween to `Platform1.Y()-150` — **disabled: true**
- Post-injury Y snap when tween finished — **disabled: true**
- Alternate damage experiments using only score without health subtract
- `PlayerHealth` scene var `* 2` damage path — HUD mirror only
- EndScreen / production lose-win flow
- Projectile / kick / roll damage branches

---

## Score independence

- Score uses same **formula** as damage: `(len/2) + len + len`
- Score and health are **independent variables**; taking damage does not double-apply score
- Death/reset must not award score

---

## Godot implementation mapping

| Source | Godot |
|--------|-------|
| `Health` / `EnemyHealth` | `HealthComponent` on `CharacterCombat` |
| `InjuryFreeze*` | `InjuryComponent` (3.0s) |
| Word damage | `WordDamageBridge` + `WordDamageCalculator` |
| HUD bars | `CombatHud` + `HealthBar` (130px) |
| Test respawn | `CharacterCombat.death_respawn_delay = 2.5` |
