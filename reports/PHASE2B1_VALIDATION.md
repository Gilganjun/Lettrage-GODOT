# Phase 2B1 Validation Report

**Status:** Automated validation **PASSED** — manual F5 gameplay **PENDING USER**

## Automated run

```
tools/validate_phase2b1.gd → 0 errors
```

| Check | Result |
|-------|--------|
| Phase 2B1 scene + scripts exist | PASSED |
| A–Z textures load | PASSED |
| Letter scene instantiates | PASSED |
| Dictionary load (EnglishWords4.txt) | PASSED — 194,304 words, ~259 ms |
| Known valid words (A, CAT) | PASSED |
| Invalid word rejected | PASSED |
| Append / delete / score formula | PASSED (len 4 → +10) |
| Spoken alphabet WAV A–Z (3 voices each) | PASSED |
| Spawner active-letter cap | PASSED |
| Authoritative level marker preserved | PASSED |
| Player movement config unchanged | PASSED |
| Phase 2A movement scene still loads | PASSED |
| Phase 2B1 test scene instantiates | PASSED |

## F5 main scene

`res://scenes/test/phase2b1_word_game_test.tscn`

Phase 2A reference (unchanged): `phase2a_movement_corrected.tscn`

## Manual checklist

- [ ] F5 — movement and camera unchanged
- [ ] Letters fall and despawn below y≈648
- [ ] Collect letters — pop SFX **and spoken letter name** (3 voice variants)
- [ ] Backspace deletes last letter
- [ ] Enter or C submits word
- [ ] Valid word adds score and clears word
- [ ] Invalid word shows error, no score change
- [ ] No Enemy present
- [ ] F3/V collision debug still works

## Controls

| Input | Action |
|-------|--------|
| Enter / C | Submit word (source uses **C**) |
| Backspace | Delete last letter |
| Shift+F2 | Toggle word debug HUD |
| F8 | Debug spawn Z |
| F9 | Debug clear word |
| F3 / V | Collision debug |

## Out of scope (confirmed)

Enemy, health, shield, mobile controls, level rebake.
