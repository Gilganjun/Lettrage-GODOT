# Phase 2B2B Validation

Run headless:

```powershell
& "C:\Godot\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" `
  --headless --path Lettrage_Godot --script res://tools/validate_phase2b2b.gd
```

Also re-run Phase 2B2A obstacle probe and Phase 2B1 after changes.

## Scope

- Shared `ShieldComponent` for Player and Enemy
- Player LCtrl toggle shield (`player_shield`)
- Enemy AI shield (collection gate + destroy-on-contact)
- Enemy letter targeting, collection, word state, auto-completion scoring
- Letter single-resolution authority
- HUD: player/enemy words, scores, shield states

## Manual F5 (pending user)

Main scene: `scenes/test/phase2b2b_shield_word_test.tscn`

- [ ] Player movement unchanged
- [ ] Player collects with spoken WAV
- [ ] LCtrl toggles player shield; shield breaks letters
- [ ] Enemy seeks needed letters and builds word in HUD
- [ ] Enemy scores on word complete
- [ ] Enemy shield AI activates/deactivates
- [ ] Obstacle avoidance still works
- [ ] No double collection

## Debug keys

| Key | Action |
|-----|--------|
| Shift+F2 | Toggle debug HUD |
| F10 | Force enemy shield on |
| F11 | Force enemy word validation |
| F12 | Clear enemy word |
