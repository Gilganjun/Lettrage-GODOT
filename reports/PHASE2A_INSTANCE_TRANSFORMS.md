# Phase 2A Instance Transforms

Baseline: **Main2_heallthbartest**

## Zero width/height rule (documented from JSON)

When customSize=false AND width=0 AND height=0, GDevelop uses natural sprite dimensions at scale 1.0. Confirmed by Platform1 instances: (920,469) stores 261×95.92 while (120,469) stores 0×0 for the same object type.

## Conversion formula

```
godot_node.position = Vector2(source_x, source_y)  # GDevelop origin, NOT top-left
sprite.offset = Vector2(-origin_x, -origin_y)
sprite.scale = Vector2(display_w / native_w, display_h / native_h)
bounds.left = source_x - origin_x * scale.x
bounds.top = source_y - origin_y * scale.y
```

## Visual instances

| Object | Src X,Y | customSize | Src W×H | Origin | Display W×H | GDevelop bounds L,T,R,B | Godot node X,Y | Scale | Rule | Conf |
|--------|---------|------------|---------|--------|-------------|-------------------------|----------------|-------|------|------|
| Player | (279.0, 231.0) | True | 64.0×97.0 | (0.0, 0.0) | 64.0×97.0 | (279.0, 231.0, 343.0, 328.0) | (279.0, 231.0) | 0.441×0.508 | customSize=true, use instance width/heig… | high |
| Ladder | (1281.0, 99.0) | True | 64.0×427.0 | (0.0, 0.0) | 64.0×427.0 | (1281.0, 99.0, 1345.0, 526.0) | (1281.0, 99.0) | 0.366×0.723 | customSize=true, use instance width/heig… | high |
| Platform1 | (920.0, 469.0) | False | 261.0×95.92308044433594 | (11.0, 124.4) | 261.0×95.9 | (916.5, 415.0, 1177.5, 510.9) | (920.0, 469.0) | 0.321×0.434 | customSize=false, use stored instance wi… | high |
| BG1 | (-136.0, -214.0) | True | 2664.0×1024.0 | (0.0, 0.0) | 2664.0×1024.0 | (-136.0, -214.0, 2528.0, 810.0) | (-136.0, -214.0) | 1.156×0.667 | customSize=true, use instance width/heig… | high |
| Platform1 | (120.0, 469.0) | False | 0.0×0.0 | (11.0, 124.4) | 814.0×221.0 | (109.0, 344.6, 923.0, 565.6) | (120.0, 469.0) | 1.000×1.000 | customSize=false, width/height=0 → natur… | high |
| Platform2 | (1464.0, -47.0) | True | 382.0098876953125×297.0 | (0.0, 0.0) | 382.0×297.0 | (1464.0, -47.0, 1846.0, 250.0) | (1464.0, -47.0) | 0.478×0.594 | customSize=true, use instance width/heig… | high |
| Platform1 | (1710.0, 469.0) | False | 261.0×95.92308044433594 | (11.0, 124.4) | 261.0×95.9 | (1706.5, 415.0, 1967.5, 510.9) | (1710.0, 469.0) | 0.321×0.434 | customSize=false, use stored instance wi… | high |
| Platform3 | (1702.0, 279.0) | True | 544.0×364.0 | (0.0, 0.0) | 544.0×364.0 | (1702.0, 279.0, 2246.0, 643.0) | (1702.0, 279.0) | 0.680×0.728 | customSize=true, use instance width/heig… | high |
| Platform3 | (937.0, 71.0) | True | 381.155059814453×140.0 | (0.0, 0.0) | 381.2×140.0 | (937.0, 71.0, 1318.2, 211.0) | (937.0, 71.0) | 0.476×0.280 | customSize=true, use instance width/heig… | high |
| Tower1 | (-17.0, -266.0) | True | 314.0×761.0 | (0.0, 0.0) | 314.0×761.0 | (-17.0, -266.0, 297.0, 495.0) | (-17.0, -266.0) | 1.000×1.486 | customSize=true, use instance width/heig… | high |
| BG2 | (-136.0, -214.0) | True | 2664.0×1024.0 | (0.0, 0.0) | 2664.0×1024.0 | (-136.0, -214.0, 2528.0, 810.0) | (-136.0, -214.0) | 1.156×0.667 | customSize=true, use instance width/heig… | high |

## Collision helpers (NOT in static visual scene)

These caused invisible floors and red rectangles in the failed build:

| Object | Src X,Y | Size | Notes |
|--------|---------|------|-------|
| LeftBoundary | (0.0, -256.0) | 135×928 | boundary.png stretched — large red visual in failed build |
| RightBoundary | (2112.0, -256.0) | 160×928 | boundary.png stretched — large red visual in failed build |
| TopBoundary | (0.0, -256.0) | 2272×128 | boundary.png stretched — large red visual in failed build |
| BottomBoundary | (51.0, 638.0) | 2272×128 | boundary.png stretched — large red visual in failed build |
| PlatformCollision | (-99.0, 574.0) | 2412×371 | Invisible floor — player stood at y≈530 on this |
| LeftCollision | (-132.0, -269.0) | 270×864 |  |
| RightCollision | (2142.0, -238.0) | 353×1178 |  |
| TopCollision | (-136.0, -596.0) | 2633×461 |  |