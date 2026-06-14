#!/usr/bin/env python3
"""Build collision_manifest.json from GAME25.json with behavior-based classification."""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
JSON_REF = ROOT / "reference" / "GAME25.json"
TRANSFORMS = ROOT / "resources" / "phase2a" / "instance_transforms.json"
OUT = ROOT / "resources/phase2a/collision_manifest.json"
OUT_MD = ROOT / "reports/PHASE2A_COLLISION_MAP.md"

BASELINE = "Main2_heallthbartest"
MAIN_PLATFORM1_XY = (120.0, 469.0)
PLAYER_Z_INDEX = 100

FLOOR_VISUAL_NAMES = {"Platform1", "Platform2", "Platform3", "Tower1"}
WALL_NAMES = {"LeftBoundary", "RightBoundary"}
LADDER_NAMES = {"Ladder"}

EXCLUDED_HELPERS = {
    "PlatformCollision": "No PlatformBehavior — letter/gameplay helper, NOT platformer floor",
    "LeftCollision": "No PlatformBehavior — off-screen helper, NOT platformer wall",
    "RightCollision": "No PlatformBehavior — off-screen helper, NOT platformer wall",
    "TopCollision": "No PlatformBehavior — ceiling helper, NOT platformer ceiling",
    "TopBoundary": "No PlatformBehavior — used in events (TopBoundary.Y()), NOT physical platform",
    "BottomBoundary": "No PlatformBehavior — event/death bounds reference, NOT physical platform",
}


def load_transforms() -> dict:
    with open(TRANSFORMS, encoding="utf-8") as f:
        return json.load(f)


def object_sprite_map(layout: dict) -> dict[str, dict]:
    sprites: dict[str, dict] = {}
    for obj in layout.get("objects", []):
        name = obj.get("name", "")
        if not name:
            continue
        for anim in obj.get("animations", []):
            for direction in anim.get("directions", []):
                for sprite in direction.get("sprites", []):
                    sprites[name] = sprite
                    break
                if name in sprites:
                    break
            if name in sprites:
                break
    return sprites


def platform_type_for_object(layout: dict, obj_name: str) -> str:
    for obj in layout.get("objects", []):
        if obj.get("name") != obj_name:
            continue
        for b in obj.get("behaviors", []):
            if "PlatformBehavior" in str(b.get("type", "")) and "PlatformerObject" not in str(b.get("type", "")):
                return str(b.get("platformType", ""))
    return ""


def collision_mask_top_y(sprite: dict | None) -> float | None:
    if sprite is None or not sprite.get("hasCustomCollisionMask"):
        return None
    polygons = sprite.get("customCollisionMask", [])
    if not polygons or not polygons[0]:
        return None
    return min(float(p["y"]) for p in polygons[0])


def collision_mask_bottom_y(sprite: dict | None) -> float | None:
    if sprite is None or not sprite.get("hasCustomCollisionMask"):
        return None
    polygons = sprite.get("customCollisionMask", [])
    if not polygons or not polygons[0]:
        return None
    return max(float(p["y"]) for p in polygons[0])


def walk_surface_y(row: dict, sprite: dict | None) -> float:
    """GDevelop NormalPlatform uses the top edge of customCollisionMask in image space."""
    b = row["gd_bounds"]
    scale_y = float(b.get("scale_y", 1.0))
    origin_y = float(row.get("origin_y", 0.0))
    gd_y = float(row["source_y"])
    mask_top = collision_mask_top_y(sprite)
    if mask_top is not None:
        return gd_y + (mask_top - origin_y) * scale_y
    return float(b["top"])


def player_feet_offset(row: dict, player_sprite: dict | None) -> float:
    """Distance from GDevelop origin (top-left) to bottom of player collision mask."""
    if player_sprite is None:
        return float(row.get("display_height", 97.0))
    mask_bottom = collision_mask_bottom_y(player_sprite)
    if mask_bottom is None:
        return float(row.get("display_height", 97.0))
    native_h = float(row.get("native_height", 191.0))
    display_h = float(row.get("display_height", 97.0))
    if native_h <= 0.0:
        return display_h
    return mask_bottom * (display_h / native_h)


def build() -> dict:
    with open(JSON_REF, encoding="utf-8") as f:
        game = json.load(f)
    layout = next(l for l in game["layouts"] if l["name"] == BASELINE)
    transforms = load_transforms()
    sprites = object_sprite_map(layout)

    player_row = next((r for r in transforms.get("visual_instances", []) if r["name"] == "Player"), {})
    feet_offset = player_feet_offset(player_row, sprites.get("Player"))

    colliders = []
    excluded = []
    main_surface_y = 508.64

    for row in transforms.get("visual_instances", []):
        name = row["name"]
        if name == "Player":
            continue
        if name in FLOOR_VISUAL_NAMES:
            pt = platform_type_for_object(layout, name)
            entry = _collider_entry(row, "floor", pt or "NormalPlatform", True, name, sprites.get(name))
            colliders.append(entry)
            if name == "Platform1" and float(row["source_x"]) == MAIN_PLATFORM1_XY[0]:
                main_surface_y = entry["walk_surface_y"]
        elif name in LADDER_NAMES:
            colliders.append(_collider_entry(row, "ladder", "Ladder", True, name, sprites.get(name)))

    for row in transforms.get("collision_helper_instances", []):
        name = row["name"]
        if name in WALL_NAMES:
            pt = platform_type_for_object(layout, name)
            colliders.append(_collider_entry(row, "wall", pt or "NormalPlatform", False, name, sprites.get(name)))
        elif name in EXCLUDED_HELPERS:
            excluded.append(
                {
                    "name": name,
                    "source_x": row["source_x"],
                    "source_y": row["source_y"],
                    "bounds": row["gd_bounds"],
                    "reason": EXCLUDED_HELPERS[name],
                }
            )

    spawn_y_on_platform = main_surface_y - feet_offset
    spawn_x = float(player_row.get("source_x", 279.0))
    spawn_y_air = float(player_row.get("source_y", 231.0))
    p1_sprite = sprites.get("Platform1", {})
    p1_mask_top = collision_mask_top_y(p1_sprite)

    manifest = {
        "layout": BASELINE,
        "physics_layers": {"world": 1, "player": 4},
        "player_spawn": {
            "x": spawn_x,
            "y": spawn_y_air,
            "z_index": PLAYER_Z_INDEX,
            "note": "Original GDevelop air spawn — falls to Platform1 grass collision",
        },
        "player_spawn_diagnostic_on_platform": {
            "x": spawn_x,
            "y": spawn_y_on_platform,
            "z_index": PLAYER_Z_INDEX,
            "feet_offset": feet_offset,
            "note": "Diagnostic only — standing on Platform1 collision mask top",
        },
        "player_spawn_original_gdevelop": {
            "x": spawn_x,
            "y": spawn_y_air,
            "note": "Alias of active player_spawn for GDevelop reference",
        },
        "expected_landing": {
            "object": "Platform1",
            "instance_xy": list(MAIN_PLATFORM1_XY),
            "walk_surface_y": main_surface_y,
            "bounds_top_y": 344.6409683227539,
            "bottom_point_y": 568.8712838864794,
            "note": "Use customCollisionMask top (image y=%s), NOT bounds.top or Bottom point"
            % (p1_mask_top if p1_mask_top is not None else "?"),
        },
        "platform1_collision_mask": {
            "mask_top_image_y": p1_mask_top,
            "formula": "walk_y = source_y + (mask_top.y - origin.y) * scale_y",
        },
        "colliders": colliders,
        "excluded_from_physics": excluded,
        "collider_count": len(colliders),
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2)
    write_md(manifest)
    return manifest


def _collider_entry(
    row: dict,
    ctype: str,
    platform_type: str,
    has_visible: bool,
    visible_name: str,
    sprite: dict | None,
) -> dict:
    b = row["gd_bounds"]
    ws_y = walk_surface_y(row, sprite)
    slab_h = 32.0 if ctype == "floor" else float(b["height"])
    if ctype == "floor":
        center_y = ws_y + slab_h / 2.0
        center_x = float(b["left"]) + float(b["width"]) / 2.0
        mask_top = collision_mask_top_y(sprite)
        shape_note = (
            f"floor mask-top y={ws_y:.1f} (image y={mask_top:.1f})"
            if mask_top is not None
            else f"floor bounds-top y={ws_y:.1f}"
        )
    else:
        center_x = float(b["left"]) + float(b["width"]) / 2.0
        center_y = float(b["top"]) + float(b["height"]) / 2.0
        shape_note = ctype
    return {
        "source_name": row["name"],
        "source_x": row["source_x"],
        "source_y": row["source_y"],
        "origin_x": row["origin_x"],
        "origin_y": row["origin_y"],
        "display_width": row["display_width"],
        "display_height": row["display_height"],
        "bounds": b,
        "walk_surface_y": ws_y,
        "collision_type": ctype,
        "platform_type": platform_type,
        "visible_sprite": has_visible,
        "visible_pair": visible_name,
        "godot_collision_layer": 1,
        "godot_collision_mask": 4,
        "shape": "floor_top_slab" if ctype == "floor" else "rectangle",
        "slab_height": slab_h,
        "center_x": center_x,
        "center_y": center_y,
        "shape_note": shape_note,
    }


def write_md(manifest: dict) -> None:
    exp = manifest["expected_landing"]
    mask = manifest["platform1_collision_mask"]
    lines = [
        "# Phase 2A Collision Map",
        "",
        "Baseline: **Main2_heallthbartest**",
        "",
        "## Player spawn",
        "",
        f"- **Active spawn (F5):** ({manifest['player_spawn']['x']}, {manifest['player_spawn']['y']}) z={manifest['player_spawn'].get('z_index', 100)}",
        f"- Diagnostic on-platform spawn: ({manifest['player_spawn_diagnostic_on_platform']['x']}, {manifest['player_spawn_diagnostic_on_platform']['y']:.1f})",
        f"- Platform1 walk surface (collision mask top): **Y ≈ {exp['walk_surface_y']:.1f}**",
        f"- bounds.top (sprite top, NOT walk surface): Y ≈ {exp['bounds_top_y']:.1f}",
        f"- Bottom point (below collision, NOT walk surface): Y ≈ {exp['bottom_point_y']:.1f}",
        "",
        "## Active colliders",
        "",
        "| Object | Type | Walk surface Y | Shape note |",
        "|--------|------|----------------|------------|",
    ]
    for c in manifest["colliders"]:
        lines.append(
            f"| {c['source_name']} @ ({c['source_x']}, {c['source_y']}) | {c['collision_type']} | "
            f"{c.get('walk_surface_y', 0):.1f} | {c.get('shape_note', '')} |"
        )
    lines += [
        "",
        f"**Total active colliders:** {manifest['collider_count']}",
        "",
        "## Platform1 collision mask (from JSON)",
        "",
        f"- Mask top in image space: y={mask.get('mask_top_image_y')}",
        f"- Formula: `{mask['formula']}`",
        "",
        "## Excluded from platformer physics",
        "",
    ]
    for e in manifest["excluded_from_physics"]:
        lines.append(f"- **{e['name']}** @ ({e['source_x']}, {e['source_y']}): {e['reason']}")
    lines += [
        "",
        "## Walk surface reference",
        "",
        "GDevelop NormalPlatform uses **customCollisionMask** top edge, not sprite bounds.top or Bottom point.",
        "Platform1 mask is a grass slab at image y=164..221; walk surface is mask top ≈ Y 508.6.",
        "",
        "Player z_index=100 renders in front of Platform1 foreground (z=67).",
        "Static bodies: layer=1, mask=4. Player: layer=4, mask=3.",
    ]
    OUT_MD.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {OUT_MD}")


if __name__ == "__main__":
    m = build()
    print(f"Wrote {OUT} ({m['collider_count']} colliders)")
    print(f"Spawn air: ({m['player_spawn']['x']}, {m['player_spawn']['y']})")
