# Test scenes

## Production gameplay (F5)

**`scenes/main/lettrage_gameplay.tscn`**

This is the project main scene. Best-of-3 rounds, countdown, win/loss overlays, level font config.

## Debug harness

**`phase2c1_health_damage_test.tscn`**

Full combat tuning scene: collision debug, font cycling (0), Alt combat keys, keyboard help panel.

Open this scene directly and press **F6** to run it without changing the main scene.

## Level editing

**`scenes/levels/main2_heallthbartest_level.tscn`** — geometry and platforms (instanced by the active test scene).

## Archive

Older phase test scenes live in **`archive/`**. They are kept for regression tools and history, not day-to-day playtesting.

When a new phase becomes the active playtest:

1. Move the old active scene into `archive/`.
2. Set **Project → Project Settings → Application → Run → Main Scene** to the new scene.
3. Update this README.
