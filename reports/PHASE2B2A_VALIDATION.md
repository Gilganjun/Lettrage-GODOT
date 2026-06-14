# Phase 2B2A Validation Report

**Status:** Automated validation **PASSED** — manual F5 gameplay **PENDING USER**

Run:

```text
godot --headless --path Lettrage_Godot --script res://tools/validate_phase2b2a.gd
```

## Automated checks

| Check | Result |
|-------|--------|
| Scenes + enemy movement config | PASSED |
| Enemy visual profile independent | PASSED |
| Animations Idle/Run/Jump/Fall/Climb | PASSED |
| Spawn (740, 406) | PASSED |
| Level marker preserved | PASSED |
| Player movement unchanged | PASSED |
| Physics probe (seed **90210**) | PASSED |

## Physics probe (seed 90210, 540 frames)

| Metric | Value |
|--------|-------|
| Path length | ~2450 px |
| Obstacle decisions | 3 |
| Jumps chosen | 1 |
| Reverses chosen | 4 |
| Stuck fallbacks | 1 |
| Max consecutive stuck | 11 frames |
| Min X / Max X | 183 / 844 |
| Escape | **Reverse** (min X left obstacle zone) |
| Oscillation | None |

## Obstacle escape system

| Component | Path |
|-----------|------|
| Sensors | `scripts/enemy/enemy_obstacle_sensor.gd` |
| Weighted decisions | `scripts/enemy/enemy_obstacle_response.gd` |
| Shield placeholder | `scripts/enemy/enemy_shield.gd`, `scripts/player/player_shield.gd` |

### Decision weights (defaults)

| Condition | Jump | Reverse |
|-----------|------|---------|
| Jumpable + floor beyond | 70 | 30 |
| Uncertain landing | 30 | 70 |
| After failed jump | 10 | 90 |
| Pause before action | 25% chance | 25% chance |

### Cooldowns

| Timer | Duration |
|-------|----------|
| Decision cooldown | 0.55 s |
| Reversal cooldown | 0.35 s |
| Pause | 0.15–0.45 s |
| Stuck fallback | 1.25 s |
| Pushing-block detect | 0.18 s |

## Manual F5 checklist

- [ ] Enemy approaches protruding platform
- [ ] One visible decision (jump or reverse, no frame-by-frame re-roll)
- [ ] Failed jump eventually reverses
- [ ] Shift+F2 shows obstacle debug fields
- [ ] Player word/score unchanged; letters Player-only

## Out of scope

Shield activation, letter breaking, Enemy word gameplay, level rebake.
