"""MP4 frame extraction — adapted from MP4FrameExtractor."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Callable

import cv2


@dataclass
class ExtractionResult:
    output_folder: Path
    saved_count: int
    total_frames: int
    first_frame_path: Path | None


ProgressCallback = Callable[[int, int, str], None]


def extract_frames(
    video_path: Path,
    skip: int = 1,
    output_folder: Path | None = None,
    on_progress: ProgressCallback | None = None,
) -> ExtractionResult:
    if skip < 1:
        raise ValueError("Skip value must be 1 or greater.")

    cap = cv2.VideoCapture(str(video_path))
    if not cap.isOpened():
        raise RuntimeError("Failed to open video file.")

    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    if total_frames <= 0:
        cap.release()
        raise RuntimeError("Failed to read video frame count.")

    if output_folder is None:
        output_folder = Path(str(video_path.with_suffix("")) + "_frames")
    output_folder.mkdir(parents=True, exist_ok=True)

    frame_count = 0
    saved_count = 0
    first_frame_path: Path | None = None

    while cap.isOpened():
        ret, frame = cap.read()
        if not ret:
            break

        if frame_count % skip == 0:
            filename = output_folder / f"frame_{frame_count:04d}.png"
            cv2.imwrite(str(filename), frame)
            if first_frame_path is None:
                first_frame_path = filename
            saved_count += 1

        frame_count += 1
        if on_progress:
            on_progress(frame_count, total_frames, f"Extracting frame {frame_count}/{total_frames}")

    cap.release()

    if saved_count == 0:
        raise RuntimeError("No frames were extracted from the video.")

    return ExtractionResult(
        output_folder=output_folder,
        saved_count=saved_count,
        total_frames=total_frames,
        first_frame_path=first_frame_path,
    )
