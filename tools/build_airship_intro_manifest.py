"""Export Intro_1 airship layout data from GAME25.json."""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
JSON_PATH = ROOT / "reference" / "GAME25.json"
OUT_PATH = ROOT / "resources" / "intro" / "airship_intro_manifest.json"
ASSET_PREFIX = "res://assets/intro/airship"

AIRSHIP_LAYERS = {
    "Passenger1",
    "Passenger2",
    "JetFlyByAlien",
    "RedBGFlyBy",
}

SKIP_INSTANCES = {
    "NewParticlesEmitter",
    "JetStartPoint",
    "JetStartPoint2",
    "Jet",
}


def sprite_origin(obj: dict, anim_index: int = 0) -> tuple[float, float]:
    anims = obj.get("animations", [])
    if anim_index >= len(anims):
        anim_index = 0
    if not anims:
        return 0.0, 0.0
    sprites = anims[anim_index].get("directions", [{}])[0].get("sprites", [])
    if not sprites:
        return 0.0, 0.0
    origin = sprites[0].get("originPoint", {})
    return float(origin.get("x", 0)), float(origin.get("y", 0))


def first_image(obj: dict, anim_index: int = 0) -> str:
    anims = obj.get("animations", [])
    if anim_index >= len(anims):
        return ""
    sprites = anims[anim_index].get("directions", [{}])[0].get("sprites", [])
    if not sprites:
        return ""
    return Path(sprites[0]["image"].replace("\\", "/")).name


def jet_animation_paths(obj: dict) -> list[str]:
    paths: list[str] = []
    for anim in obj.get("animations", []):
        sprites = anim.get("directions", [{}])[0].get("sprites", [])
        if sprites:
            name = Path(sprites[0]["image"].replace("\\", "/")).name
            paths.append(f"{ASSET_PREFIX}/images/{name}")
    return paths


def main() -> None:
    data = json.loads(JSON_PATH.read_text(encoding="utf-8"))
    layout = next(l for l in data["layouts"] if l["name"] == "Intro_1")
    objects = {o["name"]: o for o in layout.get("objects", [])}

    layer_visibility = {
        layer.get("name", ""): bool(layer.get("visibility", True))
        for layer in layout.get("layers", [])
    }

    instances: list[dict] = []
    name_counts: dict[str, int] = {}
    for inst in layout.get("instances", []):
        layer = inst.get("layer", "")
        if layer not in AIRSHIP_LAYERS:
            continue
        name = inst["name"]
        if name in SKIP_INSTANCES:
            continue
        obj = objects.get(name, {})
        tex_name = first_image(obj)
        if not tex_name:
            continue
        name_counts[name] = name_counts.get(name, 0) + 1
        suffix = "" if name_counts[name] == 1 else f"_{name_counts[name]}"
        ox, oy = sprite_origin(obj)
        instances.append(
            {
                "id": f"{layer}::{name}{suffix}",
                "name": name,
                "layer": layer,
                "x": inst["x"],
                "y": inst["y"],
                "width": inst.get("width", 0),
                "height": inst.get("height", 0),
                "angle": inst.get("angle", 0),
                "z_order": inst.get("zOrder", 0),
                "custom_size": inst.get("customSize", False),
                "texture": f"{ASSET_PREFIX}/images/{tex_name}",
                "origin_x": ox,
                "origin_y": oy,
            }
        )

    jet_obj = objects["Jet"]
    jet_anims = jet_animation_paths(jet_obj)
    jet_origins = [sprite_origin(jet_obj, i) for i in range(len(jet_obj.get("animations", [])))]

    markers = {}
    for inst in layout.get("instances", []):
        if inst["name"] == "JetStartPoint":
            markers["jet_start_1"] = {"x": inst["x"], "y": inst["y"]}
        elif inst["name"] == "JetStartPoint2":
            markers["jet_start_2"] = {"x": inst["x"], "y": inst["y"]}

    manifest = {
        "source_layout": "Intro_1",
        "viewport": {"width": 960, "height": 540},
        "layer_visibility": layer_visibility,
        "variables": {v["name"]: v.get("value") for v in layout.get("variables", [])},
        "instances": sorted(instances, key=lambda r: r["z_order"]),
        "jet": {
            "animation_textures": jet_anims,
            "origins": [
                {"x": o[0], "y": o[1]} for o in jet_origins
            ],
            "start_markers": markers,
        },
        "audio": {
            "music_main": f"{ASSET_PREFIX}/audio/Adventures in the Clockwork Lands.mp3",
            "sfx_convoy": f"{ASSET_PREFIX}/audio/160357__qubodup__humvee-truck-driving-inside-convoy-assault-ops-p1u5o3hkt1o.mp3",
        },
    }

    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUT_PATH.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(f"Wrote {OUT_PATH} ({len(instances)} instances, {len(jet_anims)} jet frames)")


if __name__ == "__main__":
    main()
