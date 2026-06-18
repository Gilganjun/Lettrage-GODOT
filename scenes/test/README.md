# Test scenes

## Active playtest (F5)

**`phase2c1_health_damage_test.tscn`**

This is the project main scene (`project.godot` → `run/main_scene`). Press **F5** to run it.

Includes: Main2 level, player, enemy, letter rain, word game, combat HUD, health/damage, death animation.

**Visual pass:** `Phase2C1VisualPass` applies readability treatment (see `VISUAL_STYLE.md`). Disable that node to compare before/after.

**F6** runs whichever scene tab you have open (use only if you intentionally want a different scene).

## Level editing

**`scenes/levels/main2_heallthbartest_level.tscn`** — geometry and platforms (instanced by the active test scene).

## Archive

Older phase test scenes live in **`archive/`**. They are kept for regression tools and history, not day-to-day playtesting.

When a new phase becomes the active playtest:

1. Move the old active scene into `archive/`.
2. Set **Project → Project Settings → Application → Run → Main Scene** to the new scene.
3. Update this README.
