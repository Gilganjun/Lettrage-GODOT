# Phase 2A Root Cause Analysis — Failed Layout Reconstruction

**Status:** Phase 2A **NOT complete**. Static layout verification scene rebuilt for manual inspection.

## Observed failure (user screenshot)

- Player at `(1223, 529.9)` standing on invisible floor
- Platforms and ladder visually scrambled
- Large red rectangle visible
- Component assets present but wrong positions/scales

## Root causes (confirmed from GAME25.json + failed code review)

### 1. Wrong coordinate anchor (primary)

**Failed assumption:** GDevelop instance `(x, y)` is the **top-left** of the object bounds.

**Actual GDevelop rule:** `(x, y)` is the **world position of the originPoint** (see sprite `originPoint` in object definition).

**Impact:** Every object was placed at `(x + w/2, y + h/2)` in Godot — systematically wrong.

**Example — Platform1:**
- originPoint = `(11.05, 124.36)` (not top-left)
- Instance at `(920, 469)` with display `261 × 95.92`
- **Correct** bounds top-left ≈ `(916.5, 415.0)`
- **Failed** code placed center at `(1050.5, 517.0)` — ~130px error

### 2. Non-zero origin ignored

Only Platform1 had a custom origin in this layout, but the code ignored `originPoint` entirely for all objects.

### 3. Incorrect zero width/height handling (secondary)

Platform1 at `(120, 469)` has `customSize: false`, `width: 0`, `height: 0`.

**Documented rule (from JSON evidence):** use **natural unscaled sprite dimensions** at scale 1.0.

Evidence: same object type at `(920, 469)` stores explicit `261 × 95.92` with `customSize: false`.

The failed build used native 814×221 **size** but combined it with the **wrong anchor**, producing a misplaced full-width ground strip.

### 4. Collision helpers rendered as visible platforms

| Object | Position | Size | Effect in failed build |
|--------|----------|------|------------------------|
| **PlatformCollision** | (-99, 574) | 2412×371 | **Invisible walkable floor** — player at y≈530 stood here |
| **TopBoundary** | (0, -256) | 2272×128 | **Large red bar** (boundary.png stretched) |
| **BottomBoundary** | (51, 638) | 2272×128 | Red boundary sprite |
| **LeftBoundary** | (0, -256) | 135×928 | Side boundary collision + visible sprite |
| **RightBoundary** | (2112, -256) | 160×928 | Side boundary |

`PlatformCollision` uses `NewSprite4-1-8.png`; boundaries use `assets/boundary.png` (32×32 red tile scaled to thousands of pixels).

### 5. The large red rectangle

**Most likely:** `TopBoundary` or `PlatformCollision` — both use flat placeholder sprites stretched to massive custom sizes. `boundary.png` is a solid red 32×32 tile.

At y=574, **PlatformCollision** is the invisible surface supporting the player in the screenshot.

### 6. Player spawn error

Failed code computed spawn from top-left + half size. Correct spawn origin is `(279, 231)` — the GDevelop origin point with `customSize: true`, `64 × 97`.

### 7. Camera masked layout errors

Camera followed the player across the misaligned world, making static inspection difficult.

## Corrected conversion formula

```
godot_node.position = Vector2(source_x, source_y)     # GDevelop origin
sprite.centered = false
sprite.offset = Vector2(-origin_x, -origin_y)
sprite.scale = Vector2(display_w / native_w, display_h / native_h)

bounds.left   = source_x - origin_x * scale.x
bounds.top    = source_y - origin_y * scale.y
bounds.right  = bounds.left + display_w
bounds.bottom = bounds.top + display_h
```

## Corrective action taken

1. Preserved failed scene: `scenes/test/phase2a_movement_test_failed.tscn`
2. Preserved failed level script: `scripts/level/phase2a_level_failed.gd`
3. Created transform library: `scripts/conversion/gdevelop_transform.gd`
4. Created static verification scene: `scenes/test/phase2a_layout_verification.tscn`
5. Full per-instance report: `reports/PHASE2A_INSTANCE_TRANSFORMS.md`
6. **No collision, no physics, no player movement** in verification scene

## Next steps (not done yet)

- [ ] Manual visual approval of static layout scene
- [ ] Re-add collision aligned to verified visuals
- [ ] Re-add player movement and camera
