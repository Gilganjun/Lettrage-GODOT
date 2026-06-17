"""One-click preset: MP4 → Green2Alpha → Shrink → ready for Animation Tester."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Callable

from PIL import Image

from paths import make_timestamped_output_dir
from services.chroma_key import process_batch
from services.frame_extractor import extract_frames
from services.image_resizer import compute_from_percentage, resize_and_save


ProgressCallback = Callable[[int, int, str], None]

# Default Green2Alpha settings (match Green2Alpha tab defaults)
DEFAULT_SENSITIVITY = 40
DEFAULT_SPILL = 50
DEFAULT_FEATHER = 1
DEFAULT_REMOVE_SHADOWS = True


@dataclass
class PresetPipelineResult:
    pipeline_dir: Path
    extract_dir: Path
    green2alpha_dir: Path
    final_dir: Path
    frame_count: int
    first_frame_path: Path | None


def run_preset_pipeline(
    video_path: Path,
    skip: int = 1,
    shrink_percent: float = 33.0,
    sensitivity: int = DEFAULT_SENSITIVITY,
    spill_reduction: int = DEFAULT_SPILL,
    feather_px: int = DEFAULT_FEATHER,
    remove_shadows: bool = DEFAULT_REMOVE_SHADOWS,
    on_progress: ProgressCallback | None = None,
) -> PresetPipelineResult:
    pipeline_dir = make_timestamped_output_dir("Preset_Pipeline")
    extract_dir = pipeline_dir / "1_extract"
    green2alpha_dir = pipeline_dir / "2_green2alpha"
    final_dir = pipeline_dir / "3_final"

    def stage_progress(stage: int, current: int, total: int, message: str) -> None:
        if not on_progress:
            return
        stage_size = 100 // 3
        base = stage * stage_size
        portion = int((current / max(total, 1)) * stage_size)
        on_progress(min(base + portion, 99), 100, message)

    extract_result = extract_frames(
        video_path,
        skip=skip,
        output_folder=extract_dir,
        on_progress=lambda c, t, m: stage_progress(0, c, t, f"[Extract] {m}"),
    )

    extract_paths = sorted(extract_dir.glob("*.png"))
    if not extract_paths:
        raise RuntimeError("No frames extracted for preset pipeline.")

    process_batch(
        extract_paths,
        green2alpha_dir,
        sensitivity=sensitivity,
        spill_reduction=spill_reduction,
        feather_px=feather_px,
        remove_shadows=remove_shadows,
        on_progress=lambda c, t, m: stage_progress(1, c, t, f"[Green2Alpha] {m}"),
    )

    green_paths = sorted(green2alpha_dir.glob("*.png"))
    if not green_paths:
        raise RuntimeError("Green2Alpha produced no frames.")

    final_dir.mkdir(parents=True, exist_ok=True)
    first_frame: Path | None = None
    total = len(green_paths)

    for i, src in enumerate(green_paths, start=1):
        with Image.open(src) as img:
            orig_w, orig_h = img.size
            params = compute_from_percentage(orig_w, orig_h, shrink_percent)
            dest = final_dir / src.name
            resize_and_save(src, dest, params.width, params.height)
            if first_frame is None:
                first_frame = dest
        stage_progress(2, i, total, f"[Shrink {shrink_percent:.0f}%] {src.name} ({i}/{total})")

    if on_progress:
        on_progress(100, 100, "Preset pipeline complete.")

    return PresetPipelineResult(
        pipeline_dir=pipeline_dir,
        extract_dir=extract_dir,
        green2alpha_dir=green2alpha_dir,
        final_dir=final_dir,
        frame_count=len(green_paths),
        first_frame_path=first_frame,
    )
