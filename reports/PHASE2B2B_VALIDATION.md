# Phase 2B2B Validation

**Status:** Automated validation **PASSED** — manual F5 gameplay **PENDING USER**

Run headless:

```powershell
& "C:\Godot\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" `
  --headless --path Lettrage_Godot --script res://tools/validate_phase2b2b.gd
```

Also re-run Phase 2B2A obstacle probe and Phase 2B1 after changes.

## Scope (implemented)

- Shared `ShieldComponent` for Player and Enemy (visuals in `ce97b1f`; audio polish in stabilization commit)
- Player LCtrl toggle shield (`player_shield`)
- Enemy AI shield (collection gate + destroy-on-contact)
- Enemy letter targeting, collection, word state, auto-completion scoring
- Letter single-resolution authority
- Per-letter tint colours + letter shatter VFX
- HUD: player/enemy words, scores, shield states
- **Shift+F2** — toggle full HUD; player word label always visible; top bar hidden in minimal mode
- Spoken letter WAVs on **player collection only** (not shield breaks)

## Not in scope (Phase 2C+)

Health, damage, death, respawn, projectiles, menus, mobile controls, production scene.

## Manual F5 (pending user)

Main scene: `scenes/test/phase2b2b_shield_word_test.tscn`

- [ ] Player movement unchanged
- [ ] Player collects with spoken WAV
- [ ] LCtrl toggles player shield; shield breaks letters (pop only, no spoken letter)
- [ ] Enemy seeks needed letters and builds word in HUD
- [ ] Enemy scores on word complete
- [ ] Enemy shield AI activates/deactivates
- [ ] Obstacle avoidance still works
- [ ] No double collection
- [ ] Per-letter colours visible; shatter VFX on destroy
- [ ] Shift+F2 minimal HUD shows player word only

## Debug keys

| Key | Action |
|-----|--------|
| Shift+F2 | Toggle full HUD (player word always visible) |
| F3 / V | Collision debug |
| F8 | Spawn letter Z |
| F9 | Clear player word |
| F10 | Force enemy shield on |
| F11 | Force enemy word validation |
| F12 | Clear enemy word |
| LCtrl | Player shield toggle |
| Enter / C | Submit word |
| Backspace | Delete last letter |

## Level baseline

Do **not** rebake `main2_heallthbartest_level.tscn`. Manual `Platform1_003` collision (~2031×32) is authoritative.

## Background edge issue

See `reports/BACKGROUND_COVERAGE_ANALYSIS.md` — camera `limit_top` extends above BG; fix deferred to post-stabilization.
