# Phase 2A — Manual Level Editing (Godot 2D Editor)

## Which scene to open

**Edit the level layout:**

`res://scenes/levels/main2_heallthbartest_level.tscn`

**Play movement test (F5 main scene):**

`res://scenes/test/phase2a_movement_corrected.tscn`

The movement test **instances** the baked level. Changes saved in the level scene persist across F5 runs.

## Regenerating from JSON (optional)

If you re-run the GDevelop importer and need to rebuild nodes from manifests:

```powershell
python tools/phase2a_collision_manifest.py
& "C:\Godot\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" `
  --headless --path Lettrage_Godot --script res://tools/bake_main2_level.gd
```

After rebaking, re-check any manual editor tweaks you want to keep.

## Level structure

```text
Main2_heallthbartestLevel
├── Backgrounds/          (BG1, BG2)
├── Decorations/          (empty — future use)
├── Platforms/            (Platform1, Platform2, Platform3, Tower1)
├── Ladders/
├── Boundaries/           (LeftBoundary, RightBoundary + wall collision)
├── CollisionHelpers/     (visual helpers — no platformer physics)
└── SpawnPoints/
    └── PlayerSpawn       (Marker2D at 279, 231)
```

Each platform / ladder / boundary group:

```text
Platform1_001 (Node2D)     ← drag this to move artwork + collision together
├── Sprite2D
└── StaticBody2D           ← local offset from parent
    └── CollisionShape2D   ← resize handles in 2D editor
```

## How to move a platform

1. Open `main2_heallthbartest_level.tscn`
2. Click the **2D** tab at the top of the editor
3. In the Scene tree, expand **Platforms**
4. Select **Platform1_001** (or any platform group root)
5. Drag in the viewport **or** set **Position** in the Inspector
6. **Save the scene** (Ctrl+S)

Moving the parent moves both the sprite and its `StaticBody2D` child.

## How to resize platform collision

1. Select the platform group (e.g. `Platform1_001`)
2. Expand it and select **StaticBody2D → CollisionShape2D**
3. In the 2D viewport, drag the orange collision handles
4. Or set **RectangleShape2D → Size** in the Inspector
5. Save the scene

The `Sprite2D` stays put; only the collision slab moves/resizes relative to the group origin.

## How to move a ladder

1. Under **Ladders**, select **Ladder_001**
2. Drag the parent node to move visual + `Area2D` together
3. To adjust climb volume only: select **Area2D → CollisionShape2D** and resize

## How to change Z-order (draw order)

1. Select any group node (e.g. `Platform1_001`)
2. In Inspector, change **CanvasItem → Z Index**
3. Higher values draw in front (matches GDevelop z-order intent)

## How to move player spawn

1. Expand **SpawnPoints**
2. Select **PlayerSpawn** (`Marker2D`)
3. Drag or edit **Position** in the Inspector
4. Save — F5 movement test uses this marker

## Grid snapping

- **View → Grids** — toggle grid visibility
- **Snapping toolbar** (above 2D viewport) — enable **Use Grid Snap** / **Use Smart Snap**
- **Project → Project Settings → Editor → 2D** — change **Grid Offset** and **Grid Step**

## Diagnostic scenes (preserved)

Runtime-built references kept for comparison:

- `scenes/test/phase2a_layout_verification.tscn`
- `scenes/test/phase2a_movement_test_failed.tscn`

Do not delete these when editing the baked level.

## What was not changed

Baking copies current positions, collision-mask walk surfaces, layers/masks, and z-order from the approved Phase 2A manifests. Player movement, camera follow, and collision math are unchanged.
