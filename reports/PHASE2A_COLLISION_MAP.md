# Phase 2A Collision Map

Baseline: **Main2_heallthbartest**

## Player spawn

- **Active spawn (F5):** (279.0, 231.0) z=100
- Diagnostic on-platform spawn: (279.0, 413.2)
- Platform1 walk surface (collision mask top): **Y ≈ 508.6**
- bounds.top (sprite top, NOT walk surface): Y ≈ 344.6
- Bottom point (below collision, NOT walk surface): Y ≈ 568.9

## Active colliders

| Object | Type | Walk surface Y | Shape note |
|--------|------|----------------|------------|
| Ladder @ (1281.0, 99.0) | ladder | 105.0 | ladder |
| Platform1 @ (920.0, 469.0) | floor | 486.2 | floor mask-top y=486.2 (image y=164.0) |
| Platform1 @ (120.0, 469.0) | floor | 508.6 | floor mask-top y=508.6 (image y=164.0) |
| Platform2 @ (1464.0, -47.0) | floor | 115.6 | floor mask-top y=115.6 (image y=273.8) |
| Platform1 @ (1710.0, 469.0) | floor | 486.2 | floor mask-top y=486.2 (image y=164.0) |
| Platform3 @ (1702.0, 279.0) | floor | 482.0 | floor mask-top y=482.0 (image y=278.9) |
| Platform3 @ (937.0, 71.0) | floor | 149.1 | floor mask-top y=149.1 (image y=278.9) |
| Tower1 @ (-17.0, -266.0) | floor | -266.0 | floor mask-top y=-266.0 (image y=0.0) |
| LeftBoundary @ (0.0, -256.0) | wall | -256.0 | wall |
| RightBoundary @ (2112.0, -256.0) | wall | -256.0 | wall |

**Total active colliders:** 10

## Platform1 collision mask (from JSON)

- Mask top in image space: y=164.0
- Formula: `walk_y = source_y + (mask_top.y - origin.y) * scale_y`

## Excluded from platformer physics

- **TopBoundary** @ (0.0, -256.0): No PlatformBehavior — used in events (TopBoundary.Y()), NOT physical platform
- **BottomBoundary** @ (51.0, 638.0): No PlatformBehavior — event/death bounds reference, NOT physical platform
- **PlatformCollision** @ (-99.0, 574.0): No PlatformBehavior — letter/gameplay helper, NOT platformer floor
- **LeftCollision** @ (-132.0, -269.0): No PlatformBehavior — off-screen helper, NOT platformer wall
- **RightCollision** @ (2142.0, -238.0): No PlatformBehavior — off-screen helper, NOT platformer wall
- **TopCollision** @ (-136.0, -596.0): No PlatformBehavior — ceiling helper, NOT platformer ceiling

## Walk surface reference

GDevelop NormalPlatform uses **customCollisionMask** top edge, not sprite bounds.top or Bottom point.
Platform1 mask is a grass slab at image y=164..221; walk surface is mask top ≈ Y 508.6.

Player z_index=100 renders in front of Platform1 foreground (z=67).
Static bodies: layer=1, mask=4. Player: layer=4, mask=3.