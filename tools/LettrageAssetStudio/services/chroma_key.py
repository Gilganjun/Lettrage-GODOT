"""Green-screen to alpha conversion using OpenCV HSV."""

from __future__ import annotations

from pathlib import Path
from typing import Callable

import cv2
import numpy as np
from PIL import Image


ProgressCallback = Callable[[int, int, str], None]


def _build_green_mask(
    hsv: np.ndarray,
    sensitivity: int,
    feather_px: int,
) -> np.ndarray:
    """Build alpha mask where green becomes transparent."""
    sens = max(0, min(100, sensitivity))
    hue_width = int(10 + (sens / 100.0) * 35)
    sat_min = int(30 + (sens / 100.0) * 80)
    val_min = int(30 + (sens / 100.0) * 60)

    lower = np.array([max(0, 60 - hue_width), sat_min, val_min], dtype=np.uint8)
    upper = np.array([min(179, 60 + hue_width), 255, 255], dtype=np.uint8)
    mask = cv2.inRange(hsv, lower, upper)

    if feather_px > 0:
        k = feather_px * 2 + 1
        mask = cv2.GaussianBlur(mask, (k, k), 0)

    return 255 - mask


def _reduce_spill(bgr: np.ndarray, alpha: np.ndarray, spill: int) -> np.ndarray:
    if spill <= 0:
        return bgr

    strength = spill / 100.0
    result = bgr.astype(np.float32)
    avg_rb = (result[:, :, 0] + result[:, :, 2]) / 2.0
    green_excess = np.clip(result[:, :, 1] - avg_rb, 0, 255)
    edge = (alpha.astype(np.float32) / 255.0)
    result[:, :, 1] = np.clip(result[:, :, 1] - green_excess * strength * edge, 0, 255)
    return result.astype(np.uint8)


def _remove_foot_shadows(alpha: np.ndarray) -> np.ndarray:
    h, w = alpha.shape
    if h < 8 or w < 8:
        return alpha

    result = alpha.copy()
    bottom = int(h * 0.88)
    region = result[bottom:, :]
    _, shadow_mask = cv2.threshold(region, 200, 255, cv2.THRESH_BINARY_INV)
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 3))
    shadow_mask = cv2.morphologyEx(shadow_mask, cv2.MORPH_OPEN, kernel)
    shadow_mask = cv2.morphologyEx(shadow_mask, cv2.MORPH_CLOSE, kernel)
    region[shadow_mask > 0] = 0
    result[bottom:, :] = region
    return result


def process_image(
    image_path: Path,
    sensitivity: int = 40,
    spill_reduction: int = 50,
    feather_px: int = 1,
    remove_shadows: bool = True,
) -> Image.Image:
    bgr = cv2.imread(str(image_path), cv2.IMREAD_COLOR)
    if bgr is None:
        raise RuntimeError(f"Could not read image: {image_path.name}")

    hsv = cv2.cvtColor(bgr, cv2.COLOR_BGR2HSV)
    alpha = _build_green_mask(hsv, sensitivity, feather_px)

    if remove_shadows:
        alpha = _remove_foot_shadows(alpha)

    bgr = _reduce_spill(bgr, alpha, spill_reduction)
    rgba = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGBA)
    rgba[:, :, 3] = alpha
    return Image.fromarray(rgba)


def process_batch(
    input_paths: list[Path],
    output_dir: Path,
    sensitivity: int = 40,
    spill_reduction: int = 50,
    feather_px: int = 1,
    remove_shadows: bool = True,
    on_progress: ProgressCallback | None = None,
) -> list[Path]:
    output_dir.mkdir(parents=True, exist_ok=True)
    results: list[Path] = []
    total = len(input_paths)

    for i, src in enumerate(input_paths, start=1):
        if on_progress:
            on_progress(i, total, f"Processing {src.name} ({i}/{total})")
        img = process_image(src, sensitivity, spill_reduction, feather_px, remove_shadows)
        dest = output_dir / f"{src.stem}.png"
        img.save(dest, "PNG")
        results.append(dest)

    return results
