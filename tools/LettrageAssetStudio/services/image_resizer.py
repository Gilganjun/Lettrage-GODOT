"""Image resizing with aspect-ratio sync and target-KB compression."""

from __future__ import annotations

import io
from dataclasses import dataclass
from pathlib import Path
from typing import Callable

from PIL import Image


ProgressCallback = Callable[[int, int, str], None]


@dataclass
class ResizeParams:
    width: int
    height: int
    percentage: float


def compute_from_percentage(orig_w: int, orig_h: int, percentage: float) -> ResizeParams:
    scale = max(1.0, percentage) / 100.0
    return ResizeParams(
        width=max(1, int(orig_w * scale)),
        height=max(1, int(orig_h * scale)),
        percentage=percentage,
    )


def compute_from_width(orig_w: int, orig_h: int, width: int) -> ResizeParams:
    if orig_w <= 0:
        raise ValueError("Invalid source width.")
    width = max(1, width)
    ratio = width / orig_w
    return ResizeParams(
        width=width,
        height=max(1, int(orig_h * ratio)),
        percentage=round(ratio * 100, 2),
    )


def compute_from_height(orig_w: int, orig_h: int, height: int) -> ResizeParams:
    if orig_h <= 0:
        raise ValueError("Invalid source height.")
    height = max(1, height)
    ratio = height / orig_h
    return ResizeParams(
        width=max(1, int(orig_w * ratio)),
        height=height,
        percentage=round(ratio * 100, 2),
    )


def estimate_kb_for_size(img: Image.Image, width: int, height: int) -> float:
    preview = resize_image(img, width, height)
    buf = io.BytesIO()
    preview.save(buf, format="PNG", optimize=True)
    return len(buf.getvalue()) / 1024.0


def resize_image(img: Image.Image, width: int, height: int) -> Image.Image:
    if img.mode not in ("RGBA", "RGB", "P", "LA"):
        img = img.convert("RGBA")
    return img.resize((max(1, width), max(1, height)), Image.Resampling.LANCZOS)


def compute_for_target_kb(
    img: Image.Image,
    target_kb: float,
    orig_w: int,
    orig_h: int,
) -> ResizeParams:
    if target_kb <= 0:
        raise ValueError("Target KB must be positive.")

    lo, hi = 1, max(orig_w, orig_h)
    best = compute_from_percentage(orig_w, orig_h, 100)

    for _ in range(20):
        mid_pct = (lo + hi) / 2.0
        params = compute_from_percentage(orig_w, orig_h, mid_pct)
        kb = estimate_kb_for_size(img, params.width, params.height)
        best = params
        if kb > target_kb:
            hi = mid_pct
        else:
            lo = mid_pct

    return best


def resize_and_save(
    src: Path,
    dest: Path,
    width: int,
    height: int,
) -> Path:
    with Image.open(src) as img:
        resized = resize_image(img, width, height)
        dest.parent.mkdir(parents=True, exist_ok=True)
        resized.save(dest, "PNG", optimize=True)
    return dest


def resize_batch(
    input_paths: list[Path],
    output_dir: Path,
    width: int,
    height: int,
    on_progress: ProgressCallback | None = None,
) -> list[Path]:
    output_dir.mkdir(parents=True, exist_ok=True)
    results: list[Path] = []
    total = len(input_paths)

    for i, src in enumerate(input_paths, start=1):
        if on_progress:
            on_progress(i, total, f"Resizing {src.name} ({i}/{total})")
        dest = output_dir / src.name
        if dest.suffix.lower() not in (".png",):
            dest = dest.with_suffix(".png")
        resize_and_save(src, dest, width, height)
        results.append(dest)

    return results
