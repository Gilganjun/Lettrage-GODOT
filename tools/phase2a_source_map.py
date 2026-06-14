#!/usr/bin/env python3
"""Generate reports/PHASE2A_SOURCE_MAP.md from layout manifest."""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "resources" / "phase2a" / "layout_manifest.json"
OUT = ROOT / "reports" / "PHASE2A_SOURCE_MAP.md"

EXCLUDED = {
    "Enemy": "Phase 2A scope — no enemy",
    "JumpButton": "Mobile controls excluded",
    "Joystick": "Mobile controls excluded",
    "JoystickThumb": "Mobile controls excluded",
    "Letter1": "Falling letters excluded",
    "Spelling": "Word UI excluded",
    "EndScreenBackground": "End screen excluded",
    "PlayerHealth": "Health UI excluded",
    "DictionaryTEST": "Dictionary logic excluded",
    "ForeBush1": "Decorative — not required for traversal validation",
    "PopPoopFx": "Particles excluded",
}


def main() -> None:
    with open(MANIFEST, encoding="utf-8") as f:
        m = json.load(f)
    lines = [
        "# Phase 2A Source Map — Main2_heallthbartest",
        "",
        "Baseline layout: **Main2_heallthbartest** (GAME25.json)",
        "",
        "## Movement values (Player PlatformerObject)",
        "",
        "| Property | JSON value | Godot usage |",
        "|----------|------------|-------------|",
    ]
    mv = m["player_movement"]
    mapping = [
        ("gravity", "gravity", "Applied each physics frame when not on ladder"),
        ("jump_speed", "jumpSpeed", "Initial upward velocity (-Y)"),
        ("max_speed", "maxSpeed", "Horizontal cap"),
        ("max_falling_speed", "maxFallingSpeed", "Vertical fall cap"),
        ("acceleration", "acceleration", "Ground/air horizontal accel toward target"),
        ("deceleration", "deceleration", "Horizontal decel when input released"),
        ("ladder_climbing_speed", "ladderClimbingSpeed", "Vertical speed on ladder"),
        ("jump_sustain_time", "jumpSustainTime", "Hold-jump sustain window"),
        ("can_go_down_from_jumpthru", "canGoDownFromJumpthru", "Stored; no jump-thru platforms in baseline instances"),
        ("slope_max_angle", "slopeMaxAngle", "Not used — all collision is AABB rectangles"),
        ("x_grab_tolerance", "xGrabTolerance", "Not used — canGrabPlatforms=false"),
        ("y_grab_offset", "yGrabOffset", "Not used — platform grab disabled"),
        ("can_grab_platforms", "canGrabPlatforms", "false — not implemented"),
    ]
    for gd_key, json_key, note in mapping:
        lines.append(f"| {gd_key} | {mv[gd_key]} | {note} |")
    lines += [
        "",
        "## Camera (SmoothCamera behavior)",
        "",
    ]
    cam = m["camera"]
    lines.append(f"- Follow X/Y: {cam['follow_x']} / {cam['follow_y']}")
    lines.append(f"- Smoothing speeds (source): L/R={cam['leftward_speed']}, U/D={cam['upward_speed']}")
    lines.append("- **Interpretation:** Godot Camera2D position_smoothing_speed ≈ 9.5 (derived from 0.9 horizontal speed)")
    lines.append("- Limits: left=0, top=-256, right=2272, bottom=766 (from boundary instances)")
    lines += [
        "",
        "## Reconstructed environment objects",
        "",
        "| GDevelop object | Position (x,y) | Size (w×h) | Godot node | Notes |",
        "|-----------------|----------------|------------|------------|-------|",
    ]
    godot_map = {
        "Platform1": "StaticBody2D + Sprite2D + RectangleShape2D",
        "Platform2": "StaticBody2D + Sprite2D + RectangleShape2D",
        "Platform3": "StaticBody2D + Sprite2D + RectangleShape2D",
        "Ladder": "Area2D (ladder detect) + Sprite2D",
        "LeftBoundary": "StaticBody2D (invisible boundary.png) + collision",
        "RightBoundary": "StaticBody2D + collision",
        "TopBoundary": "StaticBody2D + collision",
        "BottomBoundary": "StaticBody2D + collision",
        "PlatformCollision": "StaticBody2D collision only (hidden sprite)",
        "LeftCollision": "StaticBody2D collision only",
        "RightCollision": "StaticBody2D collision only",
        "TopCollision": "StaticBody2D collision only",
        "BG1": "StaticBody2D + Sprite2D (visual only, has collision from size)",
        "BG2": "StaticBody2D + Sprite2D",
        "Tower1": "StaticBody2D + Sprite2D + collision",
        "Player": "PlayerMovement CharacterBody2D scene",
    }
    for inst in m["instances"]:
        name = inst["name"]
        w, h = inst["width"], inst["height"]
        note = ""
        if name in COLLISION_ONLY:
            note = "Collision helper — sprite hidden"
        elif inst.get("platform", {}).get("platform_type") == "Ladder":
            note = "Ladder Area2D — not solid horizontally"
        lines.append(
            f"| {name} | ({inst['x']}, {inst['y']}) | {w:.1f}×{h:.1f} | {godot_map.get(name, 'StaticBody2D')} | z={inst['z_order']} {note} |"
        )
    lines += [
        "",
        f"**Total converted instances:** {m['instance_count']} (including Player spawn)",
        "",
        "## Interpretations (not 1:1 from JSON)",
        "",
        "- GDevelop top-left instance coordinates → Godot body center at (x+w/2, y+h/2)",
        "- Player uses one stable RectangleShape2D (38×82) — no per-frame collision polygons",
        "- SmoothCamera exponential speeds mapped to Camera2D position_smoothing_speed",
        "- Ladder implemented as Area2D overlap + climb input (GDevelop PlatformBehavior ladder type)",
        "- Platform1 instance at (120,469) had zero custom size in JSON → native texture size 814×221 used",
        "",
        "## Excluded baseline objects (representative)",
        "",
    ]
    for obj, reason in sorted(EXCLUDED.items()):
        lines.append(f"- **{obj}** — {reason}")
    lines.append("")
    lines.append("See layout object list in GAME25.json for full baseline (171 object defs, 78 instances).")
    OUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {OUT}")


COLLISION_ONLY = ["PlatformCollision", "LeftCollision", "RightCollision", "TopCollision"]

if __name__ == "__main__":
    main()
