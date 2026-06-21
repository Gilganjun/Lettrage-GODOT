"""Export I_Love_You cinematic intro layout data from GAME25.json."""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
JSON_PATH = ROOT / "reference" / "GAME25.json"
OUT_PATH = ROOT / "resources" / "intro" / "i_love_you_intro_manifest.json"

CINEMATIC_LAYERS = {
    "BlackOverlay",
    "BabyScene",
    "BabyScene2",
    "Doorway",
    "WomanBack",
    "WomanFront",
    "LabHall",
    "WhiteFlash",
    "CineOverlay",
}

OBJECT_TEXTURES: dict[str, list[str]] = {
    "Baby": ["Baby.png", "images/BabyAnim/Baby2.png"],
    "Baby2": ["Baby.png"],
    "WomanBack": ["WomanBack.png"],
    "WomanFront": ["WomanFront2.png"],
    "LabCribBG": ["CribBG2.png"],
    "LabCribBG2": ["CribBG2.png"],
    "CineOverlay": ["images/BabyAnim/CineOverlay1.png"],
    "WhiteFlash": ["images/WhiteFlash.png"],
    "LabDoor": ["LabDoor1B.png"],
    "LabDoorway": ["LabDoorway_Compressed.png"],
    "LabHall": ["LabHall_compressed.png"],
    "WomanBG": ["images/WomanBG.png"],
    "BlackOverlay": ["NewSprite-1-1.png"],
}


def first_sprite_image(obj: dict, anim_name: str = "") -> str:
    for anim in obj.get("animations", []):
        if anim_name and anim.get("name") != anim_name:
            continue
        dirs = anim.get("directions", [])
        if not dirs:
            continue
        sprites = dirs[0].get("sprites", [])
        if sprites:
            return sprites[0]["image"].replace("\\", "/")
    return ""


def collect_animation_frames(obj: dict, anim_name: str) -> list[str]:
    for anim in obj.get("animations", []):
        if anim.get("name") != anim_name:
            continue
        dirs = anim.get("directions", [])
        if not dirs:
            continue
        frames: list[str] = []
        for sprite in dirs[0].get("sprites", []):
            path = sprite["image"].replace("\\", "/")
            if path.startswith("Images/BabyAnim/"):
                path = "images/BabyAnim/" + path.split("Images/BabyAnim/", 1)[1]
            elif path.startswith("Images\\BabyAnim\\"):
                path = "images/BabyAnim/" + path.split("Images\\BabyAnim\\", 1)[1]
            frames.append(path)
        return frames
    return []


def map_godot_path(raw: str) -> str:
    raw = raw.replace("\\", "/")
    if raw in ("WhiteFlash", "WomanBG"):
        return f"images/{raw}.png"
    if raw.startswith("Images/BabyAnim/"):
        return "images/BabyAnim/" + raw.split("Images/BabyAnim/", 1)[1]
    return f"images/{Path(raw).name}"


def main() -> None:
    data = json.loads(JSON_PATH.read_text(encoding="utf-8"))
    layout = next(l for l in data["layouts"] if l["name"] == "I_Love_You")
    objects = {o["name"]: o for o in layout.get("objects", [])}

    layer_visibility = {
        layer.get("name", ""): bool(layer.get("visibility", True))
        for layer in layout.get("layers", [])
    }

    instances: list[dict] = []
    for inst in layout.get("instances", []):
        layer = inst.get("layer", "")
        if layer not in CINEMATIC_LAYERS:
            continue
        name = inst["name"]
        obj = objects.get(name, {})
        texture = first_sprite_image(obj)
        if texture:
            texture = map_godot_path(texture)
        elif name in OBJECT_TEXTURES:
            texture = f"res://assets/intro/{OBJECT_TEXTURES[name][0]}"
        if name == "WomanFront":
            texture = "res://assets/intro/images/WomanFront2.png"

        if not texture:
            continue
        if not texture.startswith("res://"):
            texture = f"res://assets/intro/{texture}"

        entry = {
            "name": name,
            "layer": layer,
            "x": inst["x"],
            "y": inst["y"],
            "width": inst.get("width", 0),
            "height": inst.get("height", 0),
            "angle": inst.get("angle", 0),
            "z_order": inst.get("zOrder", 0),
            "custom_size": inst.get("customSize", False),
            "texture": texture,
        }
        instances.append(entry)

    animations = {
        "Baby_BabyAnim": [
            f"res://assets/intro/{p}" if not p.startswith("res://") else p
            for p in collect_animation_frames(objects["Baby"], "BabyAnim")
        ],
        "WomanFront_FaceMove": [
            f"res://assets/intro/{p}" if not p.startswith("res://") else p
            for p in collect_animation_frames(objects["WomanFront"], "FaceMove")
        ],
    }

    variables = {
        v["name"]: v.get("value")
        for v in layout.get("variables", [])
        if v["name"]
        in {
            "BabyZoom",
            "BabyZoom2",
            "DoorwayZoom",
            "WomanZoom",
            "LabHallZoom",
            "LabCribBrightness",
            "CamSwitch",
            "EndLetters",
        }
    }

    letter_spawns = [
        {"time": 1.0, "letter_index": 9},
        {"time": 3.0, "letter_index": 12},
        {"time": 4.0, "letter_index": 15},
    ]

    manifest = {
        "source_layout": "I_Love_You",
        "viewport": {"width": 960, "height": 540},
        "layer_visibility": layer_visibility,
        "variables": variables,
        "instances": sorted(instances, key=lambda r: r["z_order"]),
        "animations": animations,
        "letter_spawns_pre_baby": letter_spawns,
        "audio": {
            "music_main": "res://assets/intro/audio/Filaments_by_Scott_Buckley.mp3",
            "music_secondary": "res://assets/intro/audio/Signal_to_noise_Scott_Bukley.mp3",
            "ambient_thunder": "res://assets/intro/audio/Thunderstorm.mp3",
            "ambient_wind": "res://assets/intro/audio/Wind.mp3",
            "baby_cry_1": "res://assets/intro/audio/BabyCry1.mp3",
            "baby_cry_2": "res://assets/intro/audio/BabyCry2.mp3",
            "door_hiss": "res://assets/intro/audio/DoorHiss.mp3",
        },
    }

    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUT_PATH.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(f"Wrote {OUT_PATH} ({len(instances)} instances)")


if __name__ == "__main__":
    main()
