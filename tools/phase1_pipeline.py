#!/usr/bin/env python3
"""Phase 0/1 pipeline: reference copy, active assets, AAC convert, animation manifest."""
from __future__ import annotations

import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT.parent / "SnatchWord1"
JSON_SRC = SOURCE / "GAME25.json"
JSON_REF = ROOT / "reference" / "GAME25.json"
BASELINE_LAYOUT = "Main2_heallthbartest"
CHAR_OBJECTS = ("Player", "Enemy")

REPORT_PHASE0 = ROOT / "reports" / "PHASE0_REPORT.md"
REPORT_PHASE1 = ROOT / "reports" / "PHASE1_REPORT.md"
MANIFEST_PATH = ROOT / "resources" / "animation_manifest.json"
COPY_MANIFEST_PATH = ROOT / "reports" / "asset_copy_manifest.json"


def load_game() -> dict:
    with open(JSON_REF, encoding="utf-8") as f:
        return json.load(f)


def layout_by_name(data: dict, name: str) -> dict:
    for lay in data.get("layouts", []):
        if lay.get("name") == name:
            return lay
    raise KeyError(name)


def obj_by_name(layout: dict, name: str) -> dict:
    for obj in layout.get("objects", []):
        if obj.get("name") == name:
            return obj
    raise KeyError(name)


def action_type(a: dict) -> str:
    t = a.get("type")
    if isinstance(t, dict):
        return t.get("value", str(t))
    return str(t)


def is_probable_asset_path(raw: str) -> bool:
    if not raw or raw.startswith("Random"):
        return False
    if raw.isdigit():
        return False
    if "/" in raw or "\\" in raw:
        return True
    lower = raw.lower()
    return any(lower.endswith(ext) for ext in (".mp3", ".wav", ".ogg", ".aac", ".flac"))


def collect_audio_from_events(events: list, found: set[str]) -> None:
    def walk(evts):
        for e in evts:
            for a in e.get("actions", []):
                at = action_type(a)
                if "Sound" in at or "Music" in at:
                    params = a.get("parameters", [])
                    if len(params) > 1:
                        raw = str(params[1]).strip('"')
                        if is_probable_asset_path(raw):
                            found.add(raw.replace("\\", "/"))
            if "events" in e:
                walk(e["events"])

    walk(events)


def extract_animations(obj: dict) -> list[dict]:
    anims = []
    for anim in obj.get("animations", []):
        for direction in anim.get("directions", []):
            frames = [s.get("image", "") for s in direction.get("sprites", []) if s.get("image")]
            if not frames:
                continue
            anims.append(
                {
                    "name": anim.get("name") or "default",
                    "loop": bool(direction.get("looping", False)),
                    "time_between_frames": float(direction.get("timeBetweenFrames", 0.08) or 0.08),
                    "frames": frames,
                }
            )
    return anims


def resolve_source_path(rel: str) -> Path | None:
    rel_norm = rel.replace("\\", "/").lstrip("/")
    candidates = [
        SOURCE / rel_norm,
        SOURCE / "assets" / rel_norm,
        SOURCE / Path(rel_norm).name,
        SOURCE / "assets" / Path(rel_norm).name,
    ]
    if rel_norm.startswith("assets/"):
        candidates.append(SOURCE / rel_norm.replace("assets/audio/", "assets/", 1))
    seen: set[str] = set()
    for c in candidates:
        key = str(c)
        if key in seen:
            continue
        seen.add(key)
        if c.is_file():
            return c
    return None


def dest_for_source(rel: str) -> Path:
    rel_norm = rel.replace("\\", "/").lstrip("/")
    if rel_norm.startswith("assets/"):
        return ROOT / rel_norm
    if rel_norm.startswith("Images/"):
        return ROOT / "images" / rel_norm.replace("Images/", "", 1)
    # Root-level sprites / backgrounds used by characters
    if any(rel_norm.startswith(p) for p in ("Synfig ", "Character_", "Character ")):
        return ROOT / "characters" / Path(rel_norm).name
    return ROOT / "assets" / Path(rel_norm).name


def copy_file(src_rel: str, log: list[dict]) -> str | None:
    src = resolve_source_path(src_rel)
    if not src:
        log.append({"source": src_rel, "status": "MISSING"})
        return None
    dest = dest_for_source(src_rel)
    dest.parent.mkdir(parents=True, exist_ok=True)
    if not dest.exists() or src.stat().st_size != dest.stat().st_size:
        shutil.copy2(src, dest)
    rel_dest = dest.relative_to(ROOT).as_posix()
    log.append({"source": src_rel, "dest": rel_dest, "status": "COPIED"})
    return rel_dest


def godot_path_for(rel_dest: str) -> str:
    return f"res://{rel_dest}"


def phase0() -> dict:
    ROOT.mkdir(parents=True, exist_ok=True)
    (ROOT / "reference").mkdir(exist_ok=True)
    (ROOT / "reports").mkdir(exist_ok=True)
    (ROOT / "resources" / "sprite_frames").mkdir(parents=True, exist_ok=True)
    (ROOT / "scenes" / "test").mkdir(parents=True, exist_ok=True)
    (ROOT / "tools").mkdir(exist_ok=True)

    if not JSON_SRC.is_file():
        raise FileNotFoundError(JSON_SRC)

    shutil.copy2(JSON_SRC, JSON_REF)
    src_hash = hashlib.sha256(JSON_SRC.read_bytes()).hexdigest()
    ref_hash = hashlib.sha256(JSON_REF.read_bytes()).hexdigest()

    project_godot = ROOT / "project.godot"
    if not project_godot.exists():
        project_godot.write_text(
            """; Lettrage — Phase 0/1 foundation (Snatch Word GDevelop conversion)
; Source: SnatchWord1/GAME25.json | Baseline layout: Main2_heallthbartest

config_version=5

[application]
config/name="Lettrage"
config/description="Snatch Word — GDevelop to Godot conversion"
config/version="0.1.0-phase1"
run/main_scene="res://scenes/test/animation_test.tscn"
config/features=PackedStringArray("4.6", "Forward Plus")

[display]
window/size/viewport_width=960
window/size/viewport_height=540
window/size/window_width_override=1280
window/size/window_height_override=720
window/stretch/mode="canvas_items"
window/handheld/orientation=4

[rendering]
textures/canvas_textures/default_texture_filter=0
""",
            encoding="utf-8",
        )

    return {
        "reference_copied": True,
        "source_hash": src_hash,
        "ref_hash": ref_hash,
        "hashes_match": src_hash == ref_hash,
        "project_godot": project_godot.exists(),
    }


def convert_aac(log: list[dict]) -> dict:
    pairs = [
        (SOURCE / "assets" / "crickets.aac", ROOT / "assets" / "crickets.ogg"),
        (SOURCE / "assets" / "door.aac", ROOT / "assets" / "door.ogg"),
    ]
    ffmpeg = shutil.which("ffmpeg")
    result = {"ffmpeg_available": bool(ffmpeg), "conversions": []}
    if not ffmpeg:
        for src, dest in pairs:
            log.append({"file": src.name, "status": "BLOCKED_NO_FFMPEG"})
        return result

    for src, dest in pairs:
        dest.parent.mkdir(parents=True, exist_ok=True)
        if not src.is_file():
            log.append({"file": src.name, "status": "SOURCE_MISSING"})
            result["conversions"].append({"file": src.name, "status": "SOURCE_MISSING"})
            continue
        cmd = [ffmpeg, "-y", "-i", str(src), "-c:a", "libvorbis", str(dest)]
        proc = subprocess.run(cmd, capture_output=True, text=True)
        ok = proc.returncode == 0 and dest.is_file()
        entry = {
            "file": src.name,
            "output": dest.relative_to(ROOT).as_posix(),
            "status": "OK" if ok else "FAILED",
        }
        if not ok:
            entry["stderr"] = proc.stderr[-500:]
        log.append(entry)
        result["conversions"].append(entry)
    return result


def phase1() -> dict:
    data = load_game()
    layout = layout_by_name(data, BASELINE_LAYOUT)
    copy_log: list[dict] = []

    # Dictionary (foundation)
    for name in ("EnglishWords4.txt", "EnglishWords.txt", "EnemyDictionary.txt"):
        src = SOURCE / "Dictionary" / name
        dest = ROOT / "dictionary" / name
        if src.is_file():
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, dest)
            copy_log.append({"source": f"Dictionary/{name}", "dest": dest.relative_to(ROOT).as_posix(), "status": "COPIED"})

    # Fonts referenced in project resources
    for res in data.get("resources", {}).get("resources", []):
        if res.get("kind") == "font":
            copy_file(res.get("file", ""), copy_log)

    animation_manifest: dict = {"layout": BASELINE_LAYOUT, "objects": {}}
    image_set: set[str] = set()

    for obj_name in CHAR_OBJECTS:
        obj = obj_by_name(layout, obj_name)
        anims = extract_animations(obj)
        mapped_anims = []
        for anim in anims:
            mapped_frames = []
            for frame in anim["frames"]:
                image_set.add(frame)
                dest_rel = copy_file(frame, copy_log)
                if dest_rel:
                    mapped_frames.append(godot_path_for(dest_rel))
            if mapped_frames:
                speed = 1.0 / anim["time_between_frames"] if anim["time_between_frames"] > 0 else 12.5
                mapped_anims.append(
                    {
                        "name": anim["name"],
                        "loop": anim["loop"],
                        "speed_fps": round(speed, 4),
                        "time_between_frames": anim["time_between_frames"],
                        "frames": mapped_frames,
                    }
                )
        animation_manifest["objects"][obj_name] = mapped_anims

    # Active audio from baseline layout events
    audio_refs: set[str] = set()
    collect_audio_from_events(layout.get("events", []), audio_refs)
    for audio in sorted(audio_refs):
        # Map known AAC to converted OGG in Godot project
        if audio in ("crickets.aac", "assets/crickets.aac"):
            copy_log.append({"source": "crickets.aac", "dest": "assets/crickets.ogg", "status": "AAC_CONVERTED"})
            continue
        if audio in ("door.aac", "assets/door.aac"):
            copy_log.append({"source": "door.aac", "dest": "assets/door.ogg", "status": "AAC_CONVERTED"})
            continue
        copy_file(audio, copy_log)

    # Alphabet images for active letter system (referenced by L1-L26 types)
    alpha_dir = SOURCE / "Images" / "Alphabet"
    if alpha_dir.is_dir():
        for png in alpha_dir.glob("*.png"):
            dest = ROOT / "images" / "Alphabet" / png.name
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(png, dest)
            copy_log.append(
                {
                    "source": f"Images/Alphabet/{png.name}",
                    "dest": dest.relative_to(ROOT).as_posix(),
                    "status": "COPIED",
                }
            )

    aac_log: list[dict] = []
    aac_result = convert_aac(aac_log)

    MANIFEST_PATH.parent.mkdir(parents=True, exist_ok=True)
    with open(MANIFEST_PATH, "w", encoding="utf-8") as f:
        json.dump(animation_manifest, f, indent=2)

    copy_summary = {
        "total_copy_ops": len(copy_log),
        "unique_images": len(image_set),
        "missing": [x for x in copy_log if x.get("status") == "MISSING"],
        "aac": aac_result,
        "aac_log": aac_log,
    }
    with open(COPY_MANIFEST_PATH, "w", encoding="utf-8") as f:
        json.dump({"copy_log": copy_log, "summary": copy_summary}, f, indent=2)

    return {
        "animation_manifest": animation_manifest,
        "copy_summary": copy_summary,
    }


def write_sprite_frames_tres(manifest: dict) -> list[str]:
    """Generate SpriteFrames .tres files from manifest (no Godot CLI required)."""
    created = []
    for obj_name, anims in manifest.get("objects", {}).items():
        if not anims:
            continue
        out_path = ROOT / "resources" / "sprite_frames" / f"{obj_name.lower()}_frames.tres"
        ext_resources: dict[str, str] = {}
        ext_lines = []
        anim_blocks = []
        step = 1
        for anim in anims:
            frame_entries = []
            for gpath in anim["frames"]:
                if gpath not in ext_resources:
                    ext_id = f"{step}"
                    step += 1
                    ext_resources[gpath] = ext_id
                    rel = gpath.replace("res://", "")
                    ext_lines.append(f'[ext_resource type="Texture2D" path="res://{rel}" id="{ext_id}"]')
                eid = ext_resources[gpath]
                frame_entries.append(
                    f'{{\n"duration": 1.0,\n"texture": ExtResource("{eid}")\n}}'
                )
            frames_str = ", ".join(frame_entries)
            loop_val = "true" if anim["loop"] else "false"
            anim_blocks.append(
                f'{{\n"frames": [{frames_str}],\n"loop": {loop_val},\n"name": &"{anim["name"]}",\n"speed": {anim["speed_fps"]}\n}}'
            )
        load_steps = len(ext_resources) + 1
        uid = hashlib.md5(obj_name.encode()).hexdigest()[:13]
        content = (
            f'[gd_resource type="SpriteFrames" load_steps={load_steps} format=3 uid="uid://phase1_{uid}"]\n\n'
            + "\n".join(ext_lines)
            + "\n\n[resource]\nanimations = ["
            + ", ".join(anim_blocks)
            + "]\n"
        )
        out_path.write_text(content, encoding="utf-8")
        created.append(out_path.relative_to(ROOT).as_posix())
    return created


def write_reports(p0: dict, p1: dict, sprite_files: list[str]) -> None:
    missing = p1["copy_summary"]["missing"]
    aac = p1["copy_summary"]["aac"]
    player_anims = p1["animation_manifest"]["objects"].get("Player", [])
    enemy_anims = p1["animation_manifest"]["objects"].get("Enemy", [])

    REPORT_PHASE0.write_text(
        f"""# Phase 0 Report — Lettrage_Godot Foundation

## Completed
- Created `Lettrage_Godot/` as sibling of `SnatchWord1/`
- **SnatchWord1 was not modified** (read-only copy only)
- Copied reference: `reference/GAME25.json`
- Source SHA-256: `{p0['source_hash']}`
- Reference SHA-256: `{p0['ref_hash']}`
- Hashes match: **{p0['hashes_match']}**
- Created `project.godot` (960×540, main scene → animation test)
- Baseline layout: **Main2_heallthbartest**

## Folder structure
```
Lettrage_Godot/
├── project.godot
├── reference/GAME25.json
├── tools/
├── reports/
├── assets/
├── characters/
├── images/
├── dictionary/
├── resources/sprite_frames/
└── scenes/test/
```
""",
        encoding="utf-8",
    )

    REPORT_PHASE1.write_text(
        f"""# Phase 1 Report — Assets, AAC, SpriteFrames, Validation

## Asset copy
- Copy operations logged: **{p1['copy_summary']['total_copy_ops']}**
- Unique character animation images: **{p1['copy_summary']['unique_images']}**
- Missing sources: **{len(missing)}**
{chr(10).join(f'  - `{m["source"]}`' for m in missing[:20])}

## AAC conversion
- FFmpeg available: **{aac['ffmpeg_available']}**
{chr(10).join(f"- {c['file']}: {c['status']}" + (f" → `{c.get('output')}`" if c.get('output') else "") for c in aac.get('conversions', []))}

## SpriteFrames (Main2_heallthbartest baseline)
- Player animations: **{len(player_anims)}** ({', '.join(a['name'] for a in player_anims)})
- Enemy animations: **{len(enemy_anims)}** ({', '.join(a['name'] for a in enemy_anims)})
- Generated files:
{chr(10).join(f'  - `{f}`' for f in sprite_files)}

## Manifests
- `resources/animation_manifest.json`
- `reports/asset_copy_manifest.json`

## Not in scope (Phase 1)
- Gameplay conversion
- Full main scene
- Main2_RedoAI_CharAnim group #14 implementation (reference-only)
""",
        encoding="utf-8",
    )


def main() -> int:
    print("Phase 0...")
    p0 = phase0()
    print("Phase 1...")
    p1 = phase1()
    print("Generating SpriteFrames .tres...")
    sprite_files = write_sprite_frames_tres(p1["animation_manifest"])
    write_reports(p0, p1, sprite_files)
    print(f"Done. SpriteFrames: {sprite_files}")
    anim_missing = [
        m for m in p1["copy_summary"]["missing"]
        if any(
            m["source"].endswith(ext)
            for ext in (".png", ".jpg", ".jpeg", ".webp")
        )
        or "Synfig" in m["source"]
        or "Character_" in m["source"]
    ]
    if anim_missing:
        print(f"ERROR: {len(anim_missing)} missing animation images")
        for m in anim_missing:
            print(f"  - {m['source']}")
        return 1
    if p1["copy_summary"]["missing"]:
        print(f"Note: {len(p1['copy_summary']['missing'])} optional audio paths not copied (see manifest)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
