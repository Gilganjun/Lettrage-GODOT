# Phase 2A — Manual Level Editing (Godot 2D Editor)

**Phase 2A complete.** This scene is the **authoritative baseline** for level layout and collision.

## Which scene to open

| Task | Scene |
|------|-------|
| **Edit platforms, ladders, collision** | `res://scenes/levels/main2_heallthbartest_level.tscn` |
| **Play movement test (F5)** | `res://scenes/test/phase2a_movement_corrected.tscn` |

The movement test **instances** the baked level. Changes saved in the level scene persist across F5 runs.

## Authoritative baseline — do not rebake casually

**`main2_heallthbartest_level.tscn` overrides manifest geometry.**

The initial bake used `collision_manifest.json` and `instance_transforms.json`. Since Phase 2A close, the level has been **manually edited in Godot**, including:

- **Bottom platform (`Platform1_003`)** — collision shape extended (~**2031×32**) so the player traverses without falling through gaps

**Do not run the baker unless explicitly approved.** Regeneration overwrites manual work:

```powershell
# DESTRUCTIVE — overwrites main2_heallthbartest_level.tscn
python tools/phase2a_collision_manifest.py
& "C:\Godot\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" `
  --headless --path Lettrage_Godot --script res://tools/bake_main2_level.gd
```

Manifests and `gdevelop_level_baker.gd` remain reference tools only.

## Level structure

```text
Main2_heallthbartestLevel
├── Backgrounds/          (BG1, BG2)
├── Decorations/
├── Platforms/            (Platform1_001, Platform1_002, Platform1_003, …)
├── Ladders/
├── Boundaries/
├── CollisionHelpers/     (visual only — no platformer physics)
└── SpawnPoints/
    └── PlayerSpawn       (Marker2D at 279, 231)
```

Each platform group:

```text
Platform1_003 (Node2D)     ← drag to move sprite + collider together
├── Sprite2D
└── StaticBody2D
    └── CollisionShape2D   ← resize independently for walk surface
```

## How to move a platform

1. Open `main2_heallthbartest_level.tscn`
2. Click **2D**
3. Expand **Platforms**, select the group root (e.g. `Platform1_003`)
4. Drag or set **Position** in Inspector
5. **Ctrl+S**

## How to resize platform collision

1. Select `StaticBody2D → CollisionShape2D` under the platform group
2. Drag orange handles or edit **RectangleShape2D → Size**
3. Save

**Tip:** Duplicating only `Sprite2D` copies artwork, not physics. Duplicate the **parent Node2D** or extend `CollisionShape2D` to match visuals.

## How to move a ladder

Select `Ladders/Ladder_001` parent to move visual + `Area2D` together. Resize `Area2D/CollisionShape2D` for climb volume only.

## Z-order

Set **Z Index** on the platform group. Player spawns at z_index 100 — use higher values to draw platform in front of the player.

## Player spawn

`SpawnPoints/PlayerSpawn` — F5 movement test reads this marker.

## Grid snapping

**View → Grids** and the snapping toolbar above the 2D viewport.

## Diagnostic scenes (preserved)

- `scenes/test/phase2a_layout_verification.tscn`
- `scenes/test/phase2a_movement_test_failed.tscn`

Do not delete when editing the baked level.

## Phase 2B

Not started. Do not add enemy, letters, or gameplay systems to this level workflow until Phase 2B is approved.
