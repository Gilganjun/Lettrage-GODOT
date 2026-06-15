# Phase 2C1 Validation Report

**Date:** 2026-06-13  
**Baseline:** `3a7eb0fca8fadb2aee9e2bc24378878e517c5ff1`  
**F5 scene:** `res://scenes/test/phase2c1_health_damage_test.tscn`

## Automated command

```bash
godot --headless --path Lettrage_Godot --script res://tools/validate_phase2c1.gd
```

## Phase 2C1 result

**Summary: 0 errors** — PASSED

### Covered checks

- Health component (50/50 init, clamp, death once, reset)
- Injury component (3s freeze, action block, recovery)
- Damage formula: `(len>>1) + 2*len` for lengths 2, 3, 4, 5, 7
- Word damage bridge (player word → enemy, enemy word → player, independent HP)
- Duplicate event guard
- Player/enemy death + 2.5s test respawn
- Shield letter regression (no double resolve, no collect after shield break)
- Level baseline marker `2031.0498` unchanged
- Scene instantiation (2C1, 2B2B, 2B1, 2A, player, enemy)

### Deterministic simulations

| Sim | Result |
|-----|--------|
| Enemy word damages Player | HP 50 → 43 (len 3) |
| Player word damages Enemy | HP 50 → 40 (len 4) |
| Player death + respawn | HP restored 50 |
| Enemy death + respawn | Position (740, 406) |
| Duplicate guard | Same event id blocked |

## Regression validators

| Validator | Result |
|-----------|--------|
| `validate_phase2a_corrected.gd` | PASSED |
| `validate_phase2b1.gd` | 0 errors |
| `validate_phase2b2a.gd` | 0 errors |
| `validate_phase2b2b.gd` | 0 errors |
| `validate_phase2c1.gd` | 0 errors |

## Manual F5

**PENDING USER** — verify health bars, injury freeze, word damage both directions, death animation, test respawn, shields, spoken WAVs, enemy AI.

## Debug keys (Shift+F2 for detail HUD)

| Key | Action |
|-----|--------|
| Alt+1 | Damage Player 10 |
| Alt+2 | Damage Enemy 10 |
| Alt+3 | Heal Player |
| Alt+4 | Heal Enemy |
| Alt+5 | Force Player death |
| Alt+6 | Force Enemy death |
| Alt+0 | Reset both combat states |

## Out of scope (confirmed)

- No level rebake
- No push
- No Phase 2C2 (projectiles/kick/roll)
- No EndScreen / production flow
