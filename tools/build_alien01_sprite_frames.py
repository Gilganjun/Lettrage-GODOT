#!/usr/bin/env python3
"""Generate res://resources/sprite_frames/alien01_frames.tres from Alien01 PNG folders."""

from __future__ import annotations

import re
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[1]
ALIEN_ROOT = PROJECT / "assets" / "Characters" / "Alien01"
OUT_PATH = PROJECT / "resources" / "sprite_frames" / "alien01_frames.tres"

ANIMATIONS: list[tuple[str, str, str, bool, float]] = [
	("Idle", "Idle", "idle", True, 10.0),
	("Run", "Run", "run", True, 14.0),
	("Walk", "Walk", "walk", True, 10.0),
	("Jump", "Jump", "jump", False, 12.0),
	("Climb", "Walk", "walk", True, 10.0),
	("Death", "Death", "death", False, 12.0),
	("Impact", "Impact", "IImpact", False, 24.0),
]


def collect_frames(folder: str, prefix: str) -> list[Path]:
	dir_path = ALIEN_ROOT / folder
	files = sorted(
		dir_path.glob(f"{prefix}_*.png"),
		key=lambda p: int(re.search(r"(\d+)", p.stem).group(1)),
	)
	if not files:
		raise FileNotFoundError(f"No frames in {dir_path} for prefix {prefix}")
	return files


def godot_path(path: Path) -> str:
	return "res://" + path.relative_to(PROJECT).as_posix()


def main() -> None:
	path_to_id: dict[str, int] = {}
	texture_paths: list[str] = []

	def texture_id(path: Path) -> int:
		key = godot_path(path)
		if key not in path_to_id:
			path_to_id[key] = len(texture_paths) + 1
			texture_paths.append(key)
		return path_to_id[key]

	anim_specs: list[tuple[str, list[Path], bool, float]] = []
	for anim_name, folder, prefix, loop, fps in ANIMATIONS:
		anim_specs.append((anim_name, collect_frames(folder, prefix), loop, fps))

	jump_frames = collect_frames("Jump", "jump")
	anim_specs.insert(4, ("Fall", jump_frames[-4:], True, 8.0))

	anim_blocks: list[str] = []
	for anim_name, frames, loop, fps in anim_specs:
		frame_entries = [
			'{\n"duration": 1.0,\n"texture": ExtResource("%d")\n}' % texture_id(frame)
			for frame in frames
		]
		anim_blocks.append(
			"{\n"
			f'"frames": [{", ".join(frame_entries)}],\n'
			f'"loop": {"true" if loop else "false"},\n'
			f'"name": &"{anim_name}",\n'
			f'"speed": {fps}\n'
			"}"
		)

	ext_lines = [
		f'[ext_resource type="Texture2D" path="{path}" id="{index}"]'
		for index, path in enumerate(texture_paths, start=1)
	]
	load_steps = len(texture_paths) + 1
	content = (
		f'[gd_resource type="SpriteFrames" load_steps={load_steps} format=3 uid="uid://alien01_sprite_frames"]\n\n'
		+ "\n".join(ext_lines)
		+ "\n\n[resource]\nanimations = ["
		+ ", ".join(anim_blocks)
		+ "]\n"
	)

	OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
	OUT_PATH.write_text(content, encoding="utf-8")
	print(
		f"Wrote {OUT_PATH} ({len(texture_paths)} unique textures, {len(anim_blocks)} animations)"
	)


if __name__ == "__main__":
	main()
