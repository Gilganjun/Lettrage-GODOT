"""Export finished animation frames into Lettrage Assets/Characters/."""

from __future__ import annotations

import shutil
from pathlib import Path
from typing import Callable

from paths import get_characters_dir


ProgressCallback = Callable[[int, int, str], None]

ANIMATION_TYPES = ["Idle", "Walk", "Run", "Jump", "Attack", "Death", "Custom"]


def export_frames(
    source_paths: list[Path],
    character_name: str,
    animation_type: str,
    sequential_rename: bool = True,
    prefix: str = "",
    project_root: Path | None = None,
    on_progress: ProgressCallback | None = None,
) -> Path:
    character_name = character_name.strip()
    animation_type = animation_type.strip()
    if not character_name:
        raise ValueError("Character name is required.")
    if not animation_type:
        raise ValueError("Animation type is required.")
    if not source_paths:
        raise ValueError("No source frames to export.")
    if project_root is None:
        raise ValueError("Lettrage project is not linked.")

    dest_dir = get_characters_dir(project_root) / character_name / animation_type
    dest_dir.mkdir(parents=True, exist_ok=True)

    rename_prefix = prefix.strip() or animation_type.lower()
    total = len(source_paths)
    exported: list[Path] = []

    for i, src in enumerate(source_paths, start=1):
        if on_progress:
            on_progress(i, total, f"Exporting {src.name} ({i}/{total})")

        if sequential_rename:
            dest_name = f"{rename_prefix}_{i:03d}.png"
        else:
            dest_name = src.name

        dest = dest_dir / dest_name
        shutil.copy2(src, dest)
        exported.append(dest)

    return dest_dir
