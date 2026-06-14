#!/usr/bin/env python3
"""Extract Main2_heallthbartest environment + player settings for Phase 2A."""
from __future__ import annotations

import json
import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
JSON_REF = ROOT / "reference" / "GAME25.json"
SOURCE = ROOT.parent / "SnatchWord1"
OUT_MANIFEST = ROOT / "resources" / "phase2a" / "layout_manifest.json"
OUT_ENV_DIR = ROOT / "assets" / "environment"

BASELINE = "Main2_heallthbartest"

# Instances included in Phase 2A physical baseline
INCLUDE_INSTANCES = {
    "Player",
    "Platform1",
    "Platform2",
    "Platform3",
    "Ladder",
    "LeftBoundary",
    "RightBoundary",
    "TopBoundary",
    "BottomBoundary",
    "PlatformCollision",
    "LeftCollision",
    "RightCollision",
    "TopCollision",
    "BG1",
    "BG2",
    "Tower1",
}

ENV_IMAGES = {
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
}


def load_game() -> dict:
    with open(JSON_REF, encoding="utf-8") as f:
        return json.load(f)


def layout_by_name(data: dict, name: str) -> dict:
    for lay in data.get("layouts", []):
        if lay.get("name") == name:
            return lay
    raise KeyError(name)


def resource_dims(data: dict, image_ref: str) -> tuple[int | None, int | None]:
    base = Path(image_ref.replace("\\", "/")).name
    for r in data.get("resources", {}).get("resources", []):
        f = str(r.get("file", "")).replace("\\", "/")
        n = str(r.get("name", "")).replace("\\", "/")
        if f == image_ref.replace("\\", "/") or n == image_ref.replace("\\", "/") or f.endswith(base) or n.endswith(base):
            sm = r.get("metadata", "")
            if isinstance(sm, str):
                wm = re.search(r'"width":(\d+)', sm)
                hm = re.search(r'"height":(\d+)', sm)
                if wm and hm:
                    return int(wm.group(1)), int(hm.group(1))
    return None, None


def first_image(obj: dict) -> str:
    for anim in obj.get("animations", []):
        for direction in anim.get("directions", []):
            for sprite in direction.get("sprites", []):
                img = sprite.get("image", "")
                if img:
                    return img.replace("\\", "/")
    return ""


def platform_behavior(obj: dict) -> dict:
    for b in obj.get("behaviors", []):
        if "PlatformBehavior" in str(b.get("type", "")) and "PlatformerObject" not in str(b.get("type", "")):
            return {
                "platform_type": b.get("platformType", "NormalPlatform"),
                "can_be_grabbed": bool(b.get("canBeGrabbed", False)),
            }
    return {}


def resolve_source_image(image_ref: str) -> Path | None:
    rel = image_ref.replace("\\", "/").lstrip("/")
    candidates = [
        SOURCE / rel,
        SOURCE / Path(rel).name,
        SOURCE / "assets" / Path(rel).name,
    ]
    for c in candidates:
        if c.is_file():
            return c
    return None


def copy_env_assets(data: dict, layout: dict) -> dict[str, str]:
    OUT_ENV_DIR.mkdir(parents=True, exist_ok=True)
    copied: dict[str, str] = {}
    obj_map = {o["name"]: o for o in layout.get("objects", [])}
    needed: set[str] = set()
    for name in INCLUDE_INSTANCES:
        if name in obj_map:
            img = first_image(obj_map[name])
            if img:
                needed.add(img)
    for img in needed:
        dest_name = ENV_IMAGES.get(img, ENV_IMAGES.get(img.replace("/", "\\"), Path(img).name))
        dest = OUT_ENV_DIR / dest_name
        src = resolve_source_image(img)
        status = "MISSING"
        if src:
            shutil.copy2(src, dest)
            status = "COPIED"
        copied[img] = {
            "godot_path": f"res://assets/environment/{dest_name}",
            "source": str(src) if src else None,
            "status": status,
            "width": resource_dims(data, img)[0],
            "height": resource_dims(data, img)[1],
        }
    return copied


def instance_size(data: dict, inst: dict, img: str) -> tuple[float, float]:
    w = float(inst.get("width") or 0)
    h = float(inst.get("height") or 0)
    if w > 0 and h > 0:
        return w, h
    nw, nh = resource_dims(data, img) if img else (None, None)
    if nw and nh:
        return float(nw), float(nh)
    dest_name = ENV_IMAGES.get(img, ENV_IMAGES.get(img.replace("/", "\\"), Path(img).name if img else ""))
    if dest_name:
        dest = OUT_ENV_DIR / dest_name
        if dest.is_file():
            try:
                from PIL import Image

                with Image.open(dest) as im:
                    return float(im.size[0]), float(im.size[1])
            except Exception:
                pass
    return max(w, 32.0), max(h, 32.0)


def extract() -> dict:
    data = load_game()
    layout = layout_by_name(data, BASELINE)
    obj_map = {o["name"]: o for o in layout.get("objects", [])}

    player_obj = obj_map["Player"]
    platformer = next(
        b for b in player_obj.get("behaviors", []) if b.get("name") == "PlatformerObject"
    )
    smooth_cam = next(
        (b for b in player_obj.get("behaviors", []) if b.get("name") == "SmoothCamera"), None
    )
    checkpoint = next(
        (b for b in player_obj.get("behaviors", []) if b.get("name") == "CheckpointPlayer"), None
    )

    assets = copy_env_assets(data, layout)
    instances = []
    for inst in layout.get("instances", []):
        name = inst.get("name", "")
        if name not in INCLUDE_INSTANCES:
            continue
        obj = obj_map.get(name, {})
        img = first_image(obj)
        w, h = instance_size(data, inst, img)
        entry = {
            "name": name,
            "x": float(inst.get("x", 0)),
            "y": float(inst.get("y", 0)),
            "width": w,
            "height": h,
            "angle": float(inst.get("angle", 0)),
            "z_order": int(inst.get("zOrder", 0)),
            "layer": inst.get("layer", ""),
            "image": img,
            "platform": platform_behavior(obj),
            "object_type": obj.get("type", ""),
        }
        if img in assets:
            entry["texture"] = assets[img]["godot_path"]
            entry["texture_status"] = assets[img]["status"]
        instances.append(entry)

    manifest = {
        "layout": BASELINE,
        "viewport": {"width": 960, "height": 540},
        "player_movement": {
            "gravity": float(platformer.get("gravity", 900)),
            "jump_speed": float(platformer.get("jumpSpeed", 500)),
            "max_speed": float(platformer.get("maxSpeed", 200)),
            "max_falling_speed": float(platformer.get("maxFallingSpeed", 400)),
            "acceleration": float(platformer.get("acceleration", 1125)),
            "deceleration": float(platformer.get("deceleration", 1125)),
            "ladder_climbing_speed": float(platformer.get("ladderClimbingSpeed", 300)),
            "jump_sustain_time": float(platformer.get("jumpSustainTime", 0.3)),
            "can_go_down_from_jumpthru": bool(platformer.get("canGoDownFromJumpthru", True)),
            "slope_max_angle": float(platformer.get("slopeMaxAngle", 60)),
            "x_grab_tolerance": float(platformer.get("xGrabTolerance", 10)),
            "y_grab_offset": float(platformer.get("yGrabOffset", 0)),
            "can_grab_platforms": bool(platformer.get("canGrabPlatforms", False)),
        },
        "camera": {
            "follow_x": bool(smooth_cam.get("FollowOnX", True)) if smooth_cam else True,
            "follow_y": bool(smooth_cam.get("FollowOnY", True)) if smooth_cam else True,
            "leftward_speed": float(smooth_cam.get("LeftwardSpeed", 0.9)) if smooth_cam else 0.9,
            "rightward_speed": float(smooth_cam.get("RightwardSpeed", 0.9)) if smooth_cam else 0.9,
            "upward_speed": float(smooth_cam.get("UpwardSpeed", 0.7)) if smooth_cam else 0.7,
            "downward_speed": float(smooth_cam.get("DownwardSpeed", 0.7)) if smooth_cam else 0.7,
            "offset_x": float(smooth_cam.get("CameraOffsetX", 0)) if smooth_cam else 0,
            "offset_y": float(smooth_cam.get("CameraOffsetY", 0)) if smooth_cam else 0,
        },
        "checkpoint_spawn": {
            "x": float(checkpoint.get("SpawnPointX", 224)) if checkpoint else 224,
            "y": float(checkpoint.get("SpawnPointY", 192)) if checkpoint else 192,
        },
        "instances": instances,
        "assets": assets,
        "instance_count": len(instances),
    }
    OUT_MANIFEST.parent.mkdir(parents=True, exist_ok=True)
    with open(OUT_MANIFEST, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2)
    return manifest


if __name__ == "__main__":
    m = extract()
    print(f"Wrote {OUT_MANIFEST} ({m['instance_count']} instances)")
    missing = [k for k, v in m["assets"].items() if v["status"] == "MISSING"]
    if missing:
        print(f"Missing assets ({len(missing)}): will use placeholder colors in Godot")
        for x in missing:
            print(f"  - {x}")
