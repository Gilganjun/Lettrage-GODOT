# Phase 2B2A Validation Report

**Status:** Automated validation **PENDING GODOT RUN** — manual F5 gameplay **PENDING USER**

Run locally:

```text
godot --headless --path Lettrage_Godot --script res://tools/validate_phase2b2a.gd
```

## Automated checks (`tools/validate_phase2b2a.gd`)

| Check | Expected |
|-------|----------|
| Phase 2B2A / 2B1 / 2A scenes exist and instantiate | PASS |
| Enemy scene + movement config + spawn JSON | PASS |
| Enemy visual profile independent from Player | PASS |
| Enemy animations Idle/Run/Jump/Fall/Climb | PASS |
| Enemy movement config matches source (gravity 1700, jump 900, max 300) | PASS |
| Enemy spawn (740, 406) | PASS |
| Authoritative level marker preserved | PASS |
| Player movement config unchanged | PASS |
| Physics probe: floor contact | PASS |
| Physics probe: distance travelled | PASS |
| Physics probe: direction changes | PASS |
| Physics probe: stuck detection | PASS |

## F5 main scene

`res://scenes/test/phase2b2a_enemy_movement_test.tscn`

Previous scenes unchanged:

- `phase2b1_word_game_test.tscn`
- `phase2a_movement_corrected.tscn`

## Manual checklist

- [ ] F5 — Player movement and camera unchanged
- [ ] Letters fall; Player collects; spoken + pop audio unchanged
- [ ] Enemy spawns at ~(740, 406), falls, lands on visible platform
- [ ] Enemy patrols with direction reversals at edges/walls
- [ ] Enemy animations: Idle, Run, Jump, Fall, Climb as appropriate
- [ ] Enemy does **not** collect letters or change Player word/score
- [ ] Shift+F2 shows Enemy debug section
- [ ] No level collision regression

## Controls

| Input | Action |
|-------|--------|
| Enter / C | Submit word |
| Backspace | Delete last letter |
| Shift+F2 | Word + enemy debug HUD |
| F3 / V | Collision debug |
| F8 | Debug spawn Z |
| F9 | Debug clear word |

## Collision (this phase)

| Body | Layer | Mask | Player interaction |
|------|-------|------|-------------------|
| Enemy | 16 (enemy) | 3 (world+ladder) | Pass-through |
| Player | 4 | 3 | Unchanged |
| Letters | 8 | 4 (player only) | Enemy ignored |

## Out of scope (confirmed)

Letter collection, word/dictionary, shield, health, damage, projectiles, RedoAI wander, level rebake.
