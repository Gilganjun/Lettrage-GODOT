#!/usr/bin/env python3
"""Offline Phase 1 validation (updated for dual-character architecture)."""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ERRORS: list[str] = []
OK: list[str] = []

PLAYER_ORDER = [
    "Idle", "Run", "Climb", "Jump", "Fall", "Death", "Sprint", "Crouch", "Roll", "Kick2", "Kick",
]
ENEMY_ORDER = ["Idle", "Run", "Climb", "Jump", "Fall", "Death"]


def check(cond: bool, ok_msg: str, err_msg: str) -> None:
    if cond:
        OK.append(ok_msg)
        print(f"[OK] {ok_msg}")
    else:
        ERRORS.append(err_msg)
        print(f"[FAIL] {err_msg}")


def parse_profile_order(tres_text: str) -> list[str]:
    m = re.search(r"animation_order = Array\[String\]\(\[(.*?)\]\)", tres_text, re.S)
    if not m:
        return []
    inner = m.group(1)
    return re.findall(r'"([^"]+)"', inner)


def main() -> int:
    print("=== Lettrage Phase 1 Validation (Python) ===\n")
    check((ROOT / "project.godot").is_file(), "project.godot", "project.godot missing")
    check((ROOT / "scenes/test/archive/animation_test.tscn").is_file(), "dual animation test scene", "test scene missing")
    check((ROOT / "scenes/test/archive/character_preview_slot.tscn").is_file(), "character preview slot scene", "slot scene missing")
    check((ROOT / "scripts/resources/character_visual_profile.gd").is_file(), "CharacterVisualProfile script", "profile script missing")

    for prof, order, label in (
        ("player_visual.tres", PLAYER_ORDER, "Player"),
        ("enemy_visual.tres", ENEMY_ORDER, "Enemy"),
    ):
        path = ROOT / "resources/characters" / prof
        check(path.is_file(), f"{label} profile", f"missing {path}")
        if path.is_file():
            text = path.read_text(encoding="utf-8")
            actual = parse_profile_order(text)
            check(actual == order, f"{label} explicit animation order", f"{label} order mismatch: {actual}")

    player_tres = (ROOT / "resources/characters/player_visual.tres").read_text(encoding="utf-8")
    enemy_tres = (ROOT / "resources/characters/enemy_visual.tres").read_text(encoding="utf-8")
    check("player_frames.tres" in player_tres, "Player profile -> player_frames.tres", "Player frames ref")
    check("enemy_frames.tres" in enemy_tres, "Enemy profile -> enemy_frames.tres", "Enemy frames ref")
    check(player_tres != enemy_tres, "Profiles are separate files", "profiles identical file")

    for ogg in ("assets/crickets.ogg", "assets/door.ogg"):
        check((ROOT / ogg).is_file(), f"AAC converted: {ogg}", f"Missing {ogg}")

    for obj, frames in (("player", "player_frames.tres"), ("enemy", "enemy_frames.tres")):
        tres = ROOT / "resources/sprite_frames" / frames
        paths = re.findall(r'path="(res://[^"]+)"', tres.read_text(encoding="utf-8"))
        missing = [p for p in set(paths) if not (ROOT / p.replace("res://", "")).is_file()]
        check(not missing, f"{obj}: textures on disk", f"{obj} missing: {missing[:3]}")

    out = ROOT / "reports" / "validation_results.json"
    out.write_text(json.dumps({"ok": OK, "errors": ERRORS}, indent=2), encoding="utf-8")
    print(f"\n=== Summary: {len(ERRORS)} errors, {len(OK)} passed ===")
    return 1 if ERRORS else 0


if __name__ == "__main__":
    sys.exit(main())
