# Phase 2A Source Map — Main2_heallthbartest

Baseline layout: **Main2_heallthbartest** (GAME25.json)

## Movement values (Player PlatformerObject)

| Property | JSON value | Godot usage |
|----------|------------|-------------|
| gravity | 900.0 | Applied each physics frame when not on ladder |
| jump_speed | 500.0 | Initial upward velocity (-Y) |
| max_speed | 200.0 | Horizontal cap |
| max_falling_speed | 400.0 | Vertical fall cap |
| acceleration | 1125.0 | Ground/air horizontal accel toward target |
| deceleration | 1125.0 | Horizontal decel when input released |
| ladder_climbing_speed | 300.0 | Vertical speed on ladder |
| jump_sustain_time | 0.3 | Hold-jump sustain window |
| can_go_down_from_jumpthru | True | Stored; no jump-thru platforms in baseline instances |
| slope_max_angle | 60.0 | Not used — all collision is AABB rectangles |
| x_grab_tolerance | 10.0 | Not used — canGrabPlatforms=false |
| y_grab_offset | 0.0 | Not used — platform grab disabled |
| can_grab_platforms | False | false — not implemented |

## Camera (SmoothCamera behavior)

- Follow X/Y: True / True
- Smoothing speeds (source): L/R=0.9, U/D=0.7
- **Interpretation:** Godot Camera2D position_smoothing_speed ≈ 9.5 (derived from 0.9 horizontal speed)
- Limits: left=0, top=-256, right=2272, bottom=766 (from boundary instances)

## Reconstructed environment objects

| GDevelop object | Position (x,y) | Size (w×h) | Godot node | Notes |
|-----------------|----------------|------------|------------|-------|
| Player | (279.0, 231.0) | 64.0×97.0 | PlayerMovement CharacterBody2D scene | z=6  |
| Ladder | (1281.0, 99.0) | 64.0×427.0 | Area2D (ladder detect) + Sprite2D | z=2 Ladder Area2D — not solid horizontally |
| LeftBoundary | (0.0, -256.0) | 135.0×928.0 | StaticBody2D (invisible boundary.png) + collision | z=38  |
| Platform1 | (920.0, 469.0) | 261.0×95.9 | StaticBody2D + Sprite2D + RectangleShape2D | z=3  |
| RightBoundary | (2112.0, -256.0) | 160.0×928.0 | StaticBody2D + collision | z=90  |
| TopBoundary | (0.0, -256.0) | 2272.0×128.0 | StaticBody2D + collision | z=59  |
| BottomBoundary | (51.0, 638.0) | 2272.0×128.0 | StaticBody2D + collision | z=60  |
| BG1 | (-136.0, -214.0) | 2664.0×1024.0 | StaticBody2D + Sprite2D (visual only, has collision from size) | z=-2  |
| Platform1 | (120.0, 469.0) | 814.0×221.0 | StaticBody2D + Sprite2D + RectangleShape2D | z=67  |
| Platform2 | (1464.0, -47.0) | 382.0×297.0 | StaticBody2D + Sprite2D + RectangleShape2D | z=0  |
| Platform1 | (1710.0, 469.0) | 261.0×95.9 | StaticBody2D + Sprite2D + RectangleShape2D | z=3  |
| Platform3 | (1702.0, 279.0) | 544.0×364.0 | StaticBody2D + Sprite2D + RectangleShape2D | z=502  |
| Platform3 | (937.0, 71.0) | 381.2×140.0 | StaticBody2D + Sprite2D + RectangleShape2D | z=1002  |
| Tower1 | (-17.0, -266.0) | 314.0×761.0 | StaticBody2D + Sprite2D + collision | z=2  |
| PlatformCollision | (-99.0, 574.0) | 2412.0×371.0 | StaticBody2D collision only (hidden sprite) | z=2020 Collision helper — sprite hidden |
| LeftCollision | (-132.0, -269.0) | 270.0×864.0 | StaticBody2D collision only | z=2021 Collision helper — sprite hidden |
| RightCollision | (2142.0, -238.0) | 353.0×1178.0 | StaticBody2D collision only | z=2022 Collision helper — sprite hidden |
| TopCollision | (-136.0, -596.0) | 2633.0×461.0 | StaticBody2D collision only | z=2023 Collision helper — sprite hidden |
| BG2 | (-136.0, -214.0) | 2664.0×1024.0 | StaticBody2D + Sprite2D | z=-1  |

## Phase 2A runtime (movement test) — COMPLETE

| Item | Value |
|------|-------|
| F5 main scene | `phase2a_movement_corrected.tscn` |
| **Authoritative level** | `scenes/levels/main2_heallthbartest_level.tscn` (manually edited — do not rebake) |
| Edit level in Godot | Open `main2_heallthbartest_level.tscn` (not the movement test scene) |
| Camera default | Always follows player at startup (no toggle) |
| Debug default | OFF (F3 / V toggle) |
| Player spawn | (279, 231) air spawn → fall to Platform1 |
| Zoom | 1.0 fixed — GDevelop jump/death zoom deferred |

### Manual level override (Phase 2A baseline)

The baked level `.tscn` **overrides** manifest geometry. Notable editor change:

- **`Platform1_003`** (bottom platform at 120, 469): collision shape extended to **~2031×32** with adjusted `CollisionShape2D` offset so the player traverses without gap fall-through.

`collision_manifest.json` and `gdevelop_level_baker.gd` are reference/regeneration tools only. Rebaking requires explicit approval.


## Interpretations (not 1:1 from JSON)

- GDevelop top-left instance coordinates → Godot body center at (x+w/2, y+h/2)
- Player uses one stable RectangleShape2D (38×82) — no per-frame collision polygons
- SmoothCamera exponential speeds mapped to Camera2D position_smoothing_speed
- Ladder implemented as Area2D overlap + climb input (GDevelop PlatformBehavior ladder type)
- Platform1 instance at (120,469) had zero custom size in JSON → native texture size 814×221 used

## Excluded baseline objects (representative)

- **DictionaryTEST** — Dictionary logic excluded
- **EndScreenBackground** — End screen excluded
- **Enemy** — Phase 2B — not started
- **ForeBush1** — Decorative — not required for traversal validation
- **Joystick** — Mobile controls excluded
- **JoystickThumb** — Mobile controls excluded
- **JumpButton** — Mobile controls excluded
- **Letter1** — Falling letters excluded
- **PlayerHealth** — Health UI excluded
- **PopPoopFx** — Particles excluded
- **Spelling** — Word UI excluded

See layout object list in GAME25.json for full baseline (171 object defs, 78 instances).