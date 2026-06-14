#!/usr/bin/env python3
"""Extract per-instance GDevelop transforms for Phase 2A layout verification."""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
JSON_REF = ROOT / "reference" / "GAME25.json"
ENV_DIR = ROOT / "assets" / "environment"
OUT_JSON = ROOT / "resources" / "phase2a" / "instance_transforms.json"
OUT_MD = ROOT / "reports" / "PHASE2A_INSTANCE_TRANSFORMS.md"

BASELINE = "Main2_heallthbartest"

VISUAL_NAMES = {
    "BG1",
    "BG2",
    "Tower1",
    "Platform1",
    "Platform2",
    "Platform3",
    "Ladder",
    "Player",
}

ENV_MAP = {
    "Ground2(Comp).png": "Ground2_Comp.png",
    "platform1Compr.png": "platform1Compr.png",
    "platform2Compr.png": "platform2Compr.png",
    "Ladder1 (7).png": "Ladder1_7.png",
    "assets/boundary.png": "boundary.png",
    "assets\\boundary.png": "boundary.png",
    "Tower1.png": "Tower1.png",
    "out (18).jpg": "out_18.jpg",
    "out (18)_3.png": "out_18_3.png",
    "NewSprite4-1-8.png": "NewSprite4-1-8.png",
    "Character_Idle.png": "Character_Idle.png",
}

# Objects that caused the failed build — documented for root-cause report
COLLISION_HELPERS = {
    "PlatformCollision",
    "LeftCollision",
    "RightCollision",
    "TopCollision",
    "LeftBoundary",
    "RightBoundary",
    "TopBoundary",
    "BottomBoundary",
}


def load_game() -> dict:
    with open(JSON_REF, encoding="utf-8") as f:
        return json.load(f)


def layout_by_name(data: dict, name: str) -> dict:
    for lay in data.get("layouts", []):
        if lay.get("name") == name:
            return lay
    raise KeyError(name)


def native_size(image_name: str) -> tuple[float, float]:
    fname = ENV_MAP.get(image_name.replace("\\", "/"), Path(image_name).name)
    path = ENV_DIR / fname
    if not path.is_file():
        return 0.0, 0.0
    try:
        from PIL import Image

        with Image.open(path) as im:
            return float(im.size[0]), float(im.size[1])
    except Exception:
        return 0.0, 0.0


def first_sprite_meta(obj: dict) -> dict:
    for anim in obj.get("animations", []):
        for direction in anim.get("directions", []):
            sprites = direction.get("sprites", [])
            if sprites:
                s = sprites[0]
                return {
                    "image": str(s.get("image", "")).replace("\\", "/"),
                    "origin_x": float(s.get("originPoint", {}).get("x", 0)),
                    "origin_y": float(s.get("originPoint", {}).get("y", 0)),
                    "center_automatic": bool(s.get("centerPoint", {}).get("automatic", True)),
                    "center_x": float(s.get("centerPoint", {}).get("x", 0)),
                    "center_y": float(s.get("centerPoint", {}).get("y", 0)),
                }
    return {
        "image": "",
        "origin_x": 0.0,
        "origin_y": 0.0,
        "center_automatic": True,
        "center_x": 0.0,
        "center_y": 0.0,
    }


def derive_display_size(custom_size: bool, iw: float, ih: float, nw: float, nh: float) -> tuple[float, float, str, str]:
    if custom_size and iw > 0 and ih > 0:
        return iw, ih, "customSize=true, use instance width/height", "high"
    if not custom_size and iw > 0 and ih > 0:
        return iw, ih, "customSize=false, use stored instance width/height (editor scale)", "high"
    if not custom_size and iw <= 0 and ih <= 0:
        return nw, nh, "customSize=false, width/height=0 → natural unscaled sprite size", "high"
    w = iw if iw > 0 else nw
    h = ih if ih > 0 else nh
    return w, h, "partial/zero dimensions — filled from native texture", "low"


def compute_bounds(ox: float, oy: float, x: float, y: float, dw: float, dh: float, nw: float, nh: float) -> dict:
    sx = dw / nw if nw else 1.0
    sy = dh / nh if nh else 1.0
    left = x - ox * sx
    top = y - oy * sy
    return {
        "left": left,
        "top": top,
        "right": left + dw,
        "bottom": top + dh,
        "width": dw,
        "height": dh,
        "scale_x": sx,
        "scale_y": sy,
    }


def extract() -> dict:
    data = load_game()
    layout = layout_by_name(data, BASELINE)
    obj_map = {o["name"]: o for o in layout.get("objects", [])}
    visual_rows = []
    helper_rows = []
    for idx, inst in enumerate(layout.get("instances", [])):
        name = inst.get("name", "")
        obj = obj_map.get(name, {})
        meta = first_sprite_meta(obj)
        nw, nh = native_size(meta["image"])
        custom_size = bool(inst.get("customSize", False))
        iw = float(inst.get("width") or 0)
        ih = float(inst.get("height") or 0)
        dw, dh, size_rule, confidence = derive_display_size(custom_size, iw, ih, nw, nh)
        ox, oy = meta["origin_x"], meta["origin_y"]
        x, y = float(inst.get("x", 0)), float(inst.get("y", 0))
        bounds = compute_bounds(ox, oy, x, y, dw, dh, nw, nh)
        fname = ENV_MAP.get(meta["image"], Path(meta["image"]).name if meta["image"] else "")
        row = {
            "id": idx,
            "name": name,
            "source_x": x,
            "source_y": y,
            "source_angle": float(inst.get("angle", 0)),
            "source_z_order": int(inst.get("zOrder", 0)),
            "source_layer": inst.get("layer", ""),
            "source_custom_size": custom_size,
            "source_width": iw,
            "source_height": ih,
            "origin_x": ox,
            "origin_y": oy,
            "center_automatic": meta["center_automatic"],
            "center_x": meta["center_x"],
            "center_y": meta["center_y"],
            "texture_file": meta["image"],
            "texture_godot": f"res://assets/environment/{fname}" if fname else "",
            "native_width": nw,
            "native_height": nh,
            "display_width": dw,
            "display_height": dh,
            "size_rule": size_rule,
            "confidence": confidence,
            "gd_bounds": bounds,
            "godot_node_position": {"x": x, "y": y},
            "godot_sprite_offset": {"x": -ox, "y": -oy},
            "godot_sprite_scale": {"x": bounds["scale_x"], "y": bounds["scale_y"]},
            "conversion_formula": (
                "node.position = (source_x, source_y) [GDevelop origin]; "
                "sprite.offset = (-origin_x, -origin_y); "
                "sprite.scale = (display_w/native_w, display_h/native_h)"
            ),
        }
        if name in VISUAL_NAMES:
            visual_rows.append(row)
        if name in COLLISION_HELPERS:
            helper_rows.append(row)
    result = {
        "layout": BASELINE,
        "viewport": {"width": 960, "height": 540},
        "visual_instances": visual_rows,
        "collision_helper_instances": helper_rows,
        "zero_size_rule": (
            "When customSize=false AND width=0 AND height=0, GDevelop uses natural sprite "
            "dimensions at scale 1.0. Confirmed by Platform1 instances: (920,469) stores "
            "261×95.92 while (120,469) stores 0×0 for the same object type."
        ),
        "failed_conversion_errors": [
            "Previous code treated (x,y) as top-left and placed node at (x+w/2, y+h/2)",
            "Previous code ignored non-zero originPoint (Platform1 origin 11.05, 124.36)",
            "Platform1 (120,469) incorrectly forced to 814×221 at center anchor — wrong position and scale intent",
            "Collision helpers and boundaries were rendered as visible scaled sprites (red boundary.png)",
            "PlatformCollision (2412×371 at y=574) created invisible walkable floor",
            "Player used center-of-AABB spawn from wrong top-left assumption",
        ],
    }
    OUT_JSON.parent.mkdir(parents=True, exist_ok=True)
    with open(OUT_JSON, "w", encoding="utf-8") as f:
        json.dump(result, f, indent=2)
    write_md(result)
    return result


def write_md(result: dict) -> None:
    lines = [
        "# Phase 2A Instance Transforms",
        "",
        "Baseline: **Main2_heallthbartest**",
        "",
        "## Zero width/height rule (documented from JSON)",
        "",
        result["zero_size_rule"],
        "",
        "## Conversion formula",
        "",
        "```",
        "godot_node.position = Vector2(source_x, source_y)  # GDevelop origin, NOT top-left",
        "sprite.offset = Vector2(-origin_x, -origin_y)",
        "sprite.scale = Vector2(display_w / native_w, display_h / native_h)",
        "bounds.left = source_x - origin_x * scale.x",
        "bounds.top = source_y - origin_y * scale.y",
        "```",
        "",
        "## Visual instances",
        "",
        "| Object | Src X,Y | customSize | Src W×H | Origin | Display W×H | GDevelop bounds L,T,R,B | Godot node X,Y | Scale | Rule | Conf |",
        "|--------|---------|------------|---------|--------|-------------|-------------------------|----------------|-------|------|------|",
    ]
    for r in result["visual_instances"]:
        b = r["gd_bounds"]
        lines.append(
            f"| {r['name']} | ({r['source_x']}, {r['source_y']}) | {r['source_custom_size']} | "
            f"{r['source_width']}×{r['source_height']} | ({r['origin_x']:.1f}, {r['origin_y']:.1f}) | "
            f"{r['display_width']:.1f}×{r['display_height']:.1f} | "
            f"({b['left']:.1f}, {b['top']:.1f}, {b['right']:.1f}, {b['bottom']:.1f}) | "
            f"({r['godot_node_position']['x']}, {r['godot_node_position']['y']}) | "
            f"{r['godot_sprite_scale']['x']:.3f}×{r['godot_sprite_scale']['y']:.3f} | "
            f"{r['size_rule'][:40]}… | {r['confidence']} |"
        )
    lines += [
        "",
        "## Collision helpers (NOT in static visual scene)",
        "",
        "These caused invisible floors and red rectangles in the failed build:",
        "",
        "| Object | Src X,Y | Size | Notes |",
        "|--------|---------|------|-------|",
    ]
    for r in result["collision_helper_instances"]:
        notes = ""
        if r["name"] == "PlatformCollision":
            notes = "Invisible floor — player stood at y≈530 on this"
        elif "Boundary" in r["name"]:
            notes = "boundary.png stretched — large red visual in failed build"
        lines.append(
            f"| {r['name']} | ({r['source_x']}, {r['source_y']}) | "
            f"{r['display_width']:.0f}×{r['display_height']:.0f} | {notes} |"
        )
    OUT_MD.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {OUT_MD}")


if __name__ == "__main__":
    r = extract()
    print(f"Wrote {OUT_JSON} ({len(r['visual_instances'])} visual instances)")
