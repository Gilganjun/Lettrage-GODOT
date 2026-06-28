# Lettrage Visual Style Guide

Readable playable screens take priority over beautiful backgrounds. This document defines the visual hierarchy for Lettrage. The first implementation pass targets `phase2c1_health_damage_test.tscn` only.

## Good vs bad

| Bad (current prototype) | Good (target) |
|-------------------------|---------------|
| Background as sharp and contrast-heavy as gameplay | Background recedes; gameplay band is calmer |
| Rainbow sticker letters | Unified glowing alphabet tiles |
| Platforms blend into scenery | Strong top edge, dark underside |
| Raw yellow HUD text | Framed panels and word slots |
| Small characters lost in mid-tones | Same designs, brighter with soft backlight |

## Layer hierarchy

1. **Background** — atmosphere only (darker, softer, lower saturation)
2. **Platforms** — navigation (clear standable silhouette)
3. **Characters** — action (unchanged design, improved readability)
4. **Letters** — objective (readable glyphs, consistent tint from alphabet catalog)
5. **HUD** — information (framed panels, slots)

**Rule:** backgrounds may be detailed; gameplay objects must be simple, bold, and readable.

## Background

- Darker and less saturated than gameplay objects
- Lower contrast in the central play band (roughly 15%–85% of viewport height)
- Optional soft fog/darken overlay between background and platforms
- Decorative depth at edges is fine; avoid sharp detail directly behind characters and letters

Prototype values (`GameplayFocusBand`):

- Background sprite modulate: `Color(0.68, 0.70, 0.76)`
- Play-band overlay alpha: ~0.22 (centre), fading at top/bottom

## Platforms

- Bright or rim-lit **top edge** (`#E8C878` warm highlight)
- **Darker underside** shadow strip
- Collision surface should match the visible top edge
- Less painterly noise on walkable surfaces

## Characters

- Keep existing fox and enemy designs
- Subtle diffused backlight and top rim via shader (no hard outline)
- Slight visual scale boost (~5%) for readability
- Do not change character art assets in the first pass

## Letters

Falling letters use the existing `letter_tint` shader and `AlphabetCatalog` colours at spawn time.

Dictionary lookup is used **only when the player submits a word** — not while letters are falling or being collected.

## HUD

- Move away from raw debug text toward framed panels
- **Full current word** in a framed label (no fixed slot cap — spelling is not limited by the HUD)
- Health bars use a fixed width inside the panel
- Debug labels stay behind Shift+F2

## Scope and reversibility

- Phase 2C1 visual pass is enabled only from `phase2c1_health_damage_test.tscn`
- Orchestrator: `scripts/visual/phase2c1_visual_pass.gd`
- Toggle: set `enabled = false` on the `Phase2C1VisualPass` node to revert runtime treatment

## Changed files (visual pass)

| File | Role |
|------|------|
| `VISUAL_STYLE.md` | This guide |
| `scripts/visual/gameplay_focus_band.gd` | Background recede + play-band overlay |
| `scripts/visual/platform_readability.gd` | Platform rim lines and underside shadow |
| `scripts/visual/character_readability.gd` | Character backlight + rim shader |
| `scripts/visual/phase2c1_visual_pass.gd` | Scene orchestrator |
| `scenes/visual/phase2c1_visual_pass.tscn` | Instanced by phase2c1 test scene |
| `shaders/character_outline.gdshader` | Diffused backlight + subtle rim |
