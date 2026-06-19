"""Auto-font extraction from alphabet grid sheets."""

from __future__ import annotations

import json
from collections import deque
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable

import cv2
import numpy as np
from PIL import Image, ImageDraw

from paths import sanitize_folder_name

LETTERS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

ProgressCallback = Callable[[int, int, str], None]


@dataclass
class LetterResult:
    letter: str
    image: Image.Image
    status: str
    source_cell: tuple[int, int]
    source_cell_rect: tuple[int, int, int, int]
    bbox_in_cell: tuple[int, int, int, int] | None
    warnings: list[str] = field(default_factory=list)
    notes: list[str] = field(default_factory=list)
    visible_pixel_count: int = 0
    edit_source: Image.Image | None = None
    manual_adjust: dict | None = None
    logical_origin: tuple[int, int] | None = None
    logical_size: tuple[int, int] | None = None


@dataclass
class FontCutResult:
    letters: list[LetterResult]
    processed_sheet: Image.Image
    metadata: dict
    output_dir: Path | None = None


def letter_export_filename(font_set_name: str, letter: str) -> str:
    """e.g. Cyberpunk_Neon_02_A.png"""
    return f"{sanitize_folder_name(font_set_name)}_{letter}.png"


def load_font_sheet(path: Path) -> Image.Image:
    img = Image.open(path)
    return img.convert("RGBA")


def _corner_samples(rgb: np.ndarray) -> list[tuple[int, int, int]]:
    h, w = rgb.shape[:2]
    points = [
        (0, 0),
        (w - 1, 0),
        (0, h - 1),
        (w - 1, h - 1),
        (w // 2, 0),
        (w // 2, h - 1),
        (0, h // 2),
        (w - 1, h // 2),
    ]
    return [tuple(int(v) for v in rgb[y, x]) for x, y in points]


def _is_bright_chroma_green(r: int, g: int, b: int) -> bool:
    """True only for neon #00FF00-style background, not forest-green letter art."""
    return g >= 180 and r <= 120 and b <= 120 and (g - max(r, b)) >= 80


def _is_dark(rgb: np.ndarray) -> bool:
    luminance = 0.299 * rgb[:, :, 0] + 0.587 * rgb[:, :, 1] + 0.114 * rgb[:, :, 2]
    return float(np.mean(luminance)) < 45


def detect_background_mode(img: Image.Image) -> str:
    """Return 'transparent', 'green', 'dark', or 'opaque'."""
    arr = np.array(img)
    alpha = arr[:, :, 3]
    if np.any(alpha < 250):
        transparent_ratio = np.sum(alpha < 16) / alpha.size
        if transparent_ratio > 0.05:
            return "transparent"

    rgb = arr[:, :, :3]
    corners = _corner_samples(rgb)
    if all(sum(c) < 60 for c in corners):
        return "dark"

    green_hits = sum(1 for c in corners if _is_bright_chroma_green(*c))
    if green_hits >= len(corners) // 2:
        return "green"
    return "opaque"


def _narrow_chroma_mask(hsv: np.ndarray, tolerance: int) -> np.ndarray:
    """
    Match pure chroma-key green (#00FF00) only — not forest/jungle greens in letter art.
    tolerance 0-100 controls how tight the match is (higher = stricter).
    """
    t = max(0, min(100, tolerance))
    hue_width = int(4 + (100 - t) * 0.10)
    sat_min = int(170 + (100 - t) * 0.4)
    val_min = int(185 + (100 - t) * 0.25)
    lower = np.array([max(0, 60 - hue_width), sat_min, val_min], dtype=np.uint8)
    upper = np.array([min(179, 60 + hue_width), 255, 255], dtype=np.uint8)
    return cv2.inRange(hsv, lower, upper)


def _border_connected_mask(binary: np.ndarray) -> np.ndarray:
    """Pixels in binary mask that touch the image border (background chroma)."""
    if not np.any(binary):
        return np.zeros_like(binary)
    h, w = binary.shape
    num_labels, labels = cv2.connectedComponents(binary)
    border_labels: set[int] = set()
    for x in range(w):
        if binary[0, x]:
            border_labels.add(int(labels[0, x]))
        if binary[h - 1, x]:
            border_labels.add(int(labels[h - 1, x]))
    for y in range(h):
        if binary[y, 0]:
            border_labels.add(int(labels[y, 0]))
        if binary[y, w - 1]:
            border_labels.add(int(labels[y, w - 1]))
    border_labels.discard(0)
    if not border_labels:
        return np.zeros_like(binary)
    return np.isin(labels, list(border_labels)).astype(np.uint8) * 255


def green_to_alpha(img: Image.Image, tolerance: int = 60) -> Image.Image:
    """
    Remove chroma-key green using tight HSV matching.
    Only neon #00FF00-style background is keyed — green letter artwork is preserved.
    Also removes enclosed hole chroma (A, O, etc.) while keeping forest-green foliage.
    """
    rgba = np.array(img.convert("RGBA"))
    bgr = cv2.cvtColor(rgba[:, :, :3], cv2.COLOR_RGB2BGR)
    hsv = cv2.cvtColor(bgr, cv2.COLOR_BGR2HSV)

    chroma = _narrow_chroma_mask(hsv, tolerance)
    border = _border_connected_mask(chroma)
    enclosed = cv2.bitwise_and(chroma, cv2.bitwise_not(border))
    remove = cv2.bitwise_or(border, enclosed)

    if np.any(remove):
        remove = cv2.GaussianBlur(remove, (3, 3), 0)
        remove = (remove > 127).astype(np.uint8) * 255

    alpha = rgba[:, :, 3].astype(np.float32)
    alpha[remove > 0] = 0
    rgba[:, :, 3] = np.clip(alpha, 0, 255).astype(np.uint8)
    return Image.fromarray(rgba, "RGBA")


def apply_background_processing(
    img: Image.Image,
    mode: str,
    green_delta: int = 60,
) -> tuple[Image.Image, str]:
    if mode == "transparent":
        return img.convert("RGBA"), "transparent"
    if mode == "green":
        return green_to_alpha(img, green_delta), "green2alpha"
    detected = detect_background_mode(img)
    if detected == "green":
        return green_to_alpha(img, green_delta), "green2alpha"
    if detected in ("transparent", "dark", "opaque"):
        return img.convert("RGBA"), detected
    return img.convert("RGBA"), "opaque"


def _cell_rect(col: int, row: int, w: int, h: int, cols: int, rows: int) -> tuple[int, int, int, int]:
    x0 = round(col * w / cols)
    x1 = round((col + 1) * w / cols)
    y0 = round(row * h / rows)
    y1 = round((row + 1) * h / rows)
    return x0, y0, x1, y1


def _alpha_mask(img: Image.Image, alpha_threshold: int = 16) -> np.ndarray:
    return np.array(img)[:, :, 3] > alpha_threshold


def _column_fill(mask: np.ndarray, x: int, y0: int, y1: int) -> float:
    h, w = mask.shape
    if x < 0 or x >= w:
        return 1.0
    y0 = max(0, y0)
    y1 = min(h, y1)
    if y1 <= y0:
        return 1.0
    return float(np.mean(mask[y0:y1, x]))


def _row_fill(mask: np.ndarray, y: int, x0: int, x1: int) -> float:
    h, w = mask.shape
    if y < 0 or y >= h:
        return 1.0
    x0 = max(0, x0)
    x1 = min(w, x1)
    if x1 <= x0:
        return 1.0
    return float(np.mean(mask[y, x0:x1]))


def _measure_cell_gutters(
    mask: np.ndarray,
    x0: int,
    y0: int,
    x1: int,
    y1: int,
    max_dist: int = 48,
    fill_limit: float = 0.08,
) -> tuple[int, int, int, int]:
    """Transparent clearance (px) inward from each logical cell edge on the full sheet."""
    left = right = top = bottom = 0
    for d in range(1, max_dist + 1):
        if _column_fill(mask, x0 - d, y0, y1) > fill_limit:
            break
        left = d
    for d in range(1, max_dist + 1):
        if _column_fill(mask, x1 - 1 + d, y0, y1) > fill_limit:
            break
        right = d
    for d in range(1, max_dist + 1):
        if _row_fill(mask, y0 - d, x0, x1) > fill_limit:
            break
        top = d
    for d in range(1, max_dist + 1):
        if _row_fill(mask, y1 - 1 + d, x0, x1) > fill_limit:
            break
        bottom = d
    return left, right, top, bottom


OVERLAP_RATIO = 0.14
OVERLAP_MIN_PX = 6


def _cell_crop_rect(
    col: int,
    row: int,
    w: int,
    h: int,
    cols: int,
    rows: int,
) -> tuple[tuple[int, int, int, int], tuple[int, int, int, int]]:
    """
    Expanded crop rect plus logical cell position inside that crop.
    Fixed 14% overlap — AI sheet art routinely extends past grid lines.
    """
    x0, y0, x1, y1 = _cell_rect(col, row, w, h, cols, rows)
    cw, ch = x1 - x0, y1 - y0
    ox = max(OVERLAP_MIN_PX, int(cw * OVERLAP_RATIO))
    oy = max(OVERLAP_MIN_PX, int(ch * OVERLAP_RATIO))
    ex0 = max(0, x0 - ox)
    ey0 = max(0, y0 - oy)
    ex1 = min(w, x1 + ox)
    ey1 = min(h, y1 + oy)
    logical_x = x0 - ex0
    logical_y = y0 - ey0
    return (ex0, ey0, ex1, ey1), (logical_x, logical_y, cw, ch)


def compute_sheet_cell_centers(
    w: int,
    h: int,
    cols: int,
    rows: int,
) -> list[tuple[float, float]]:
    """Sheet-space center (cx, cy) for each letter index 0..25."""
    centers: list[tuple[float, float]] = []
    for i in range(len(LETTERS)):
        row = i // cols
        col = i % cols
        x0, y0, x1, y1 = _cell_rect(col, row, w, h, cols, rows)
        centers.append(((x0 + x1) / 2.0, (y0 + y1) / 2.0))
    return centers


def _voronoi_ownership_mask(
    crop_sheet_x: int,
    crop_sheet_y: int,
    crop_w: int,
    crop_h: int,
    letter_index: int,
    sheet_centers: list[tuple[float, float]],
) -> np.ndarray:
    """True where this cell owns the pixel (nearest center on sheet)."""
    my_cx, my_cy = sheet_centers[letter_index]
    ys = np.arange(crop_h, dtype=np.float32) + crop_sheet_y
    xs = np.arange(crop_w, dtype=np.float32) + crop_sheet_x
    sheet_x, sheet_y = np.meshgrid(xs, ys)
    my_dist = (sheet_x - my_cx) ** 2 + (sheet_y - my_cy) ** 2
    ownership = np.ones((crop_h, crop_w), dtype=bool)
    for i, (cx, cy) in enumerate(sheet_centers):
        if i == letter_index:
            continue
        other_dist = (sheet_x - cx) ** 2 + (sheet_y - cy) ** 2
        ownership &= my_dist <= other_dist
    return ownership


def _find_center_seed(
    fg_mask: np.ndarray,
    cx: float,
    cy: float,
    search_radius: int,
) -> tuple[int, int] | None:
    """Locate a foreground seed at or near the logical cell center."""
    h, w = fg_mask.shape
    icx = int(round(cx))
    icy = int(round(cy))
    icx = max(0, min(w - 1, icx))
    icy = max(0, min(h - 1, icy))

    if fg_mask[icy, icx]:
        return icy, icx

    for r in range(1, search_radius + 1):
        for dy in range(-r, r + 1):
            for dx in range(-r, r + 1):
                if max(abs(dx), abs(dy)) != r:
                    continue
                x = icx + dx
                y = icy + dy
                if 0 <= x < w and 0 <= y < h and fg_mask[y, x]:
                    return y, x

    if not np.any(fg_mask):
        return None
    ys, xs = np.where(fg_mask)
    dists = (xs - cx) ** 2 + (ys - cy) ** 2
    idx = int(np.argmin(dists))
    return int(ys[idx]), int(xs[idx])


def _select_letter_component(
    full_mask: np.ndarray,
    owned_mask: np.ndarray,
    seed: tuple[int, int],
    cell_cx: float,
    cell_cy: float,
    min_pixels: int,
) -> tuple[np.ndarray, int]:
    """
    Grow letter mask from center seed: connected component + attached halos,
    bounded by Voronoi ownership (with small halo allowance).
    """
    seed_y, seed_x = seed
    owned_fg = full_mask & owned_mask
    if owned_fg[seed_y, seed_x]:
        search_mask = owned_fg
    elif full_mask[seed_y, seed_x]:
        search_mask = full_mask
    elif np.any(owned_fg):
        search_mask = owned_fg
    else:
        search_mask = full_mask

    num, labels, stats, centroids = cv2.connectedComponentsWithStats(
        search_mask.astype(np.uint8),
        connectivity=8,
    )
    if num <= 1:
        return np.zeros_like(full_mask), 0

    seed_label = int(labels[seed_y, seed_x]) if search_mask[seed_y, seed_x] else 0
    if seed_label == 0:
        best_label = -1
        best_score = -1.0
        max_dist = float(np.hypot(full_mask.shape[1] / 2, full_mask.shape[0] / 2))
        for label_id in range(1, num):
            area = int(stats[label_id, cv2.CC_STAT_AREA])
            if area < min_pixels:
                continue
            ccx, ccy = centroids[label_id]
            dist = float(np.hypot(ccx - cell_cx, ccy - cell_cy))
            center_weight = 1.0 - min(dist / max(max_dist, 1.0), 1.0) * 0.85
            score = area * center_weight
            if score > best_score:
                best_score = score
                best_label = label_id
        seed_label = best_label

    if seed_label <= 0:
        return np.zeros_like(full_mask), 0

    core = labels == seed_label
    num_full, full_labels = cv2.connectedComponents(full_mask.astype(np.uint8), connectivity=8)
    keep_labels: set[int] = set()
    for label_id in range(1, num_full):
        if np.any(core & (full_labels == label_id)):
            keep_labels.add(label_id)

    letter_mask = np.isin(full_labels, list(keep_labels)) if keep_labels else core
    halo_allow = cv2.dilate(core.astype(np.uint8), np.ones((5, 5), np.uint8), iterations=2) > 0
    letter_mask = letter_mask & (owned_mask | halo_allow)

    removed = int(np.sum(full_mask & ~letter_mask))
    return letter_mask, removed


def strip_residual_chroma(img: Image.Image, tolerance: int = 60) -> Image.Image:
    """Remove leftover key-green inside a cell crop (border + enclosed holes)."""
    rgba = np.array(img.convert("RGBA"))
    bgr = cv2.cvtColor(rgba[:, :, :3], cv2.COLOR_RGB2BGR)
    hsv = cv2.cvtColor(bgr, cv2.COLOR_BGR2HSV)
    chroma = _narrow_chroma_mask(hsv, tolerance)
    border = _border_connected_mask(chroma)
    enclosed = cv2.bitwise_and(chroma, cv2.bitwise_not(border))
    remove = cv2.bitwise_or(border, enclosed)
    if np.any(remove):
        remove = cv2.GaussianBlur(remove, (3, 3), 0)
        remove = (remove > 127).astype(np.uint8) * 255
    alpha = rgba[:, :, 3].astype(np.float32)
    alpha[remove > 0] = 0
    rgba[:, :, 3] = np.clip(alpha, 0, 255).astype(np.uint8)
    return Image.fromarray(rgba, "RGBA")


def _verify_margin_clearance(
    letter_mask: np.ndarray,
    full_mask: np.ndarray,
    bbox: tuple[int, int, int, int],
    margin_px: int,
) -> list[str]:
    """Warn if foreign foreground sits inside the uniform margin ring."""
    x0, y0, x1, y1 = bbox
    h, w = letter_mask.shape
    ex0 = max(0, x0 - margin_px)
    ey0 = max(0, y0 - margin_px)
    ex1 = min(w, x1 + margin_px)
    ey1 = min(h, y1 + margin_px)
    foreign = full_mask & ~letter_mask
    ring = np.zeros_like(letter_mask)
    ring[ey0:ey1, ex0:ex1] = True
    ring[y0:y1, x0:x1] = False
    foreign_in_ring = int(np.sum(foreign & ring))
    if foreign_in_ring > max(24, margin_px * 4):
        return ["Margin contains foreign art"]
    return []


def center_on_canvas_from_mask(
    letter_img: Image.Image,
    letter_mask: np.ndarray,
    output_size: int = 512,
    margin_ratio: float = 0.06,
    max_fill: float = 0.88,
) -> Image.Image:
    """Crop masked letter with uniform margin; center using mask centroid."""
    canvas = Image.new("RGBA", (output_size, output_size), (0, 0, 0, 0))
    if not np.any(letter_mask):
        return canvas

    ys, xs = np.where(letter_mask)
    x0, x1 = int(xs.min()), int(xs.max()) + 1
    y0, y1 = int(ys.min()), int(ys.max()) + 1
    bw, bh = max(1, x1 - x0), max(1, y1 - y0)
    margin = max(8, int(max(bw, bh) * margin_ratio))

    crop_w, crop_h = letter_img.size
    px0 = max(0, x0 - margin)
    py0 = max(0, y0 - margin)
    px1 = min(crop_w, x1 + margin)
    py1 = min(crop_h, y1 + margin)

    arr = np.array(letter_img.crop((px0, py0, px1, py1))).copy()
    local_mask = letter_mask[py0:py1, px0:px1]
    arr[~local_mask, 3] = 0

    ly, lx = np.where(local_mask)
    if len(lx) == 0:
        return canvas
    centroid_x = float(np.mean(lx))
    centroid_y = float(np.mean(ly))

    ch, cw = arr.shape[:2]
    max_dim = int(output_size * max_fill)
    scale = min(max_dim / max(cw, 1), max_dim / max(ch, 1))
    new_w = max(1, int(cw * scale))
    new_h = max(1, int(ch * scale))
    resized = Image.fromarray(arr, "RGBA").resize((new_w, new_h), Image.Resampling.LANCZOS)

    scaled_cx = centroid_x * scale
    scaled_cy = centroid_y * scale
    paste_x = int(output_size / 2 - scaled_cx)
    paste_y = int(output_size / 2 - scaled_cy)
    canvas.paste(resized, (paste_x, paste_y), resized)
    return canvas


def extract_letter_mask_center_outward(
    cell_img: Image.Image,
    logical_origin: tuple[int, int],
    logical_size: tuple[int, int],
    letter_index: int,
    sheet_centers: list[tuple[float, float]],
    crop_sheet_origin: tuple[int, int],
    alpha_threshold: int = 16,
    min_pixels: int = 80,
    strip_chroma: bool = False,
    green_delta: int = 60,
) -> tuple[np.ndarray, np.ndarray, tuple[int, int, int, int] | None, int, list[str], list[str]]:
    """
    Center-outward letter segmentation.
    Returns (full_mask, letter_mask, bbox, removed_px, warnings, notes).
    """
    work = strip_residual_chroma(cell_img, green_delta) if strip_chroma else cell_img
    arr = np.array(work)
    full_mask = arr[:, :, 3] > alpha_threshold
    warnings: list[str] = []
    notes: list[str] = ["Center-out detect"]

    if not np.any(full_mask):
        return full_mask, full_mask, None, 0, warnings, notes

    lx, ly = logical_origin
    lw, lh = logical_size
    cell_cx = lx + lw / 2.0
    cell_cy = ly + lh / 2.0
    search_radius = max(16, int(min(lw, lh) * 0.35))

    crop_sheet_x, crop_sheet_y = crop_sheet_origin
    owned = _voronoi_ownership_mask(
        crop_sheet_x,
        crop_sheet_y,
        work.width,
        work.height,
        letter_index,
        sheet_centers,
    )

    seed = _find_center_seed(full_mask, cell_cx, cell_cy, search_radius)
    if seed is None:
        return full_mask, np.zeros_like(full_mask), None, 0, ["Missing / empty"], notes

    min_area = max(min_pixels, int(lw * lh * 0.004))
    letter_mask, removed = _select_letter_component(
        full_mask,
        owned,
        seed,
        cell_cx,
        cell_cy,
        min_area,
    )

    if not np.any(letter_mask):
        warnings.append("Missing / empty")
        return full_mask, letter_mask, None, removed, warnings, notes

    bbox = find_alpha_bbox(work, alpha_threshold, letter_mask)
    if bbox is None:
        warnings.append("Missing / empty")
        return full_mask, letter_mask, None, removed, warnings, notes

    margin_px = max(8, int(max(bbox[2] - bbox[0], bbox[3] - bbox[1]) * 0.06))
    warnings.extend(_verify_margin_clearance(letter_mask, full_mask, bbox, margin_px))
    warnings.extend(validate_bbox_in_cell(bbox, work.size, logical_origin, logical_size))

    if removed > 0:
        notes.append(f"Excluded {removed} foreign px")
    if strip_chroma:
        notes.append("Cell chroma stripped")

    return full_mask, letter_mask, bbox, removed, warnings, notes


def find_alpha_bbox(
    cell_img: Image.Image,
    alpha_threshold: int = 16,
    mask: np.ndarray | None = None,
) -> tuple[int, int, int, int] | None:
    arr = np.array(cell_img)
    if mask is None:
        mask = arr[:, :, 3] > alpha_threshold
    if not np.any(mask):
        return None
    ys, xs = np.where(mask)
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def isolate_primary_letter(
    cell_img: Image.Image,
    logical_origin: tuple[int, int],
    logical_size: tuple[int, int],
    alpha_threshold: int = 16,
) -> tuple[Image.Image, tuple[int, int, int, int] | None, int]:
    """
    Keep the letter component nearest the logical cell center.
    Removes neighbor glow slivers and preserves halos attached to the main glyph.
    """
    arr = np.array(cell_img).copy()
    alpha = arr[:, :, 3]
    lx, ly = logical_origin
    lw, lh = logical_size
    cell_cx = lx + lw / 2.0
    cell_cy = ly + lh / 2.0

    full_mask = alpha > alpha_threshold
    if not np.any(full_mask):
        return cell_img, None, 0

    core_threshold = min(255, max(alpha_threshold * 2, 48))
    core_mask = alpha > core_threshold
    if not np.any(core_mask):
        core_mask = full_mask

    num_core, core_labels, core_stats, core_centroids = cv2.connectedComponentsWithStats(
        core_mask.astype(np.uint8),
        connectivity=8,
    )

    removed_count = 0
    if num_core <= 1:
        bbox = find_alpha_bbox(cell_img, alpha_threshold, full_mask)
        return cell_img, bbox, 0

    min_pixels = max(80, int(lw * lh * 0.004))
    best_label = -1
    best_score = -1.0
    max_dist = float(np.hypot(lw / 2, lh / 2))

    for label_id in range(1, num_core):
        pixel_count = int(core_stats[label_id, cv2.CC_STAT_AREA])
        if pixel_count < min_pixels:
            continue
        cx, cy = core_centroids[label_id]
        dist = float(np.hypot(cx - cell_cx, cy - cell_cy))
        center_weight = 1.0 - min(dist / max(max_dist, 1.0), 1.0) * 0.9
        score = pixel_count * center_weight
        if score > best_score:
            best_score = score
            best_label = label_id

    if best_label < 0:
        bbox = find_alpha_bbox(cell_img, alpha_threshold, full_mask)
        return cell_img, bbox, 0

    selected_core = core_labels == best_label
    num_full, full_labels = cv2.connectedComponents(full_mask.astype(np.uint8), connectivity=8)
    keep_labels: set[int] = set()
    for label_id in range(1, num_full):
        if np.any(selected_core & (full_labels == label_id)):
            keep_labels.add(label_id)

    keep_mask = np.isin(full_labels, list(keep_labels)) if keep_labels else selected_core

    removed_count = int(np.sum(full_mask & ~keep_mask))
    arr[:, :, 3] = np.where(keep_mask, alpha, 0).astype(np.uint8)
    bbox = find_alpha_bbox(Image.fromarray(arr, "RGBA"), alpha_threshold, keep_mask)
    return Image.fromarray(arr, "RGBA"), bbox, removed_count


def _expand_and_clamp_bbox(
    bbox: tuple[int, int, int, int],
    padding: int,
    cell_size: tuple[int, int],
) -> tuple[int, int, int, int]:
    cw, ch = cell_size
    x0, y0, x1, y1 = bbox
    return (
        max(0, x0 - padding),
        max(0, y0 - padding),
        min(cw, x1 + padding),
        min(ch, y1 + padding),
    )


def _label_components(mask: np.ndarray) -> tuple[np.ndarray, int]:
    h, w = mask.shape
    labels = np.zeros((h, w), dtype=np.int32)
    current = 0
    for y in range(h):
        for x in range(w):
            if not mask[y, x] or labels[y, x]:
                continue
            current += 1
            queue: deque[tuple[int, int]] = deque([(y, x)])
            labels[y, x] = current
            while queue:
                cy, cx = queue.popleft()
                for ny, nx in ((cy - 1, cx), (cy + 1, cx), (cy, cx - 1), (cy, cx + 1)):
                    if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and labels[ny, nx] == 0:
                        labels[ny, nx] = current
                        queue.append((ny, nx))
    return labels, current


def remove_tiny_islands(
    cell_img: Image.Image,
    alpha_threshold: int = 16,
    min_pixels: int = 20,
) -> tuple[Image.Image, int]:
    arr = np.array(cell_img).copy()
    mask = arr[:, :, 3] > alpha_threshold
    if not np.any(mask):
        return cell_img, 0

    labels, count = _label_components(mask)
    if count <= 1:
        return cell_img, 0

    sizes = np.bincount(labels.ravel())
    if len(sizes) <= 1:
        return cell_img, 0

    main_label = int(np.argmax(sizes[1:]) + 1)
    removed = 0
    for label_id in range(1, count + 1):
        if label_id == main_label:
            continue
        component_size = int(sizes[label_id]) if label_id < len(sizes) else 0
        if component_size < min_pixels:
            arr[labels == label_id, 3] = 0
            removed += component_size
    return Image.fromarray(arr, "RGBA"), removed


def validate_bbox_in_cell(
    bbox: tuple[int, int, int, int],
    crop_size: tuple[int, int],
    logical_origin: tuple[int, int] | None = None,
    logical_size: tuple[int, int] | None = None,
) -> list[str]:
    """Return warnings only for likely real problems."""
    crop_w, crop_h = crop_size
    x0, y0, x1, y1 = bbox
    warnings: list[str] = []

    if logical_origin is not None and logical_size is not None:
        lx, ly = logical_origin
        lw, lh = logical_size
        bleed_margin = max(6, int(min(lw, lh) * 0.08))
        if x0 < lx - bleed_margin or y0 < ly - bleed_margin:
            warnings.append("Possible neighbor bleed")
        if x1 > lx + lw + bleed_margin or y1 > ly + lh + bleed_margin:
            warnings.append("Possible neighbor bleed")
        touches_logical = (
            x0 <= lx + 2
            or y0 <= ly + 2
            or x1 >= lx + lw - 2
            or y1 >= ly + lh - 2
        )
        fills_logical = (x1 - x0) > lw * 0.98 and (y1 - y0) > lh * 0.98
        if touches_logical and fills_logical and min(lw, lh) > 64:
            warnings.append("Possible clipping at cell edge")

    touches_crop = x0 <= 1 or y0 <= 1 or x1 >= crop_w - 1 or y1 >= crop_h - 1
    fills_crop = (x1 - x0) > crop_w * 0.98 and (y1 - y0) > crop_h * 0.98
    if touches_crop and fills_crop and not warnings:
        warnings.append("Possible clipping at crop edge")

    return warnings


def default_manual_adjust(
    edit_source: Image.Image,
    output_size: int,
    bbox_in_cell: tuple[int, int, int, int] | None = None,
) -> dict:
    bbox = bbox_in_cell or find_alpha_bbox(edit_source)
    if bbox is None:
        fit = min(output_size * 0.88 / max(edit_source.width, 1), output_size * 0.88 / max(edit_source.height, 1))
        return {"pan_x": 0.0, "pan_y": 0.0, "zoom": fit}
    x0, y0, x1, y1 = bbox
    bw = max(1, x1 - x0)
    bh = max(1, y1 - y0)
    zoom = min(output_size * 0.82 / bw, output_size * 0.82 / bh)
    bcx = (x0 + x1) / 2.0
    bcy = (y0 + y1) / 2.0
    sw = edit_source.width * zoom
    sh = edit_source.height * zoom
    pan_x = output_size / 2.0 - bcx * zoom - (output_size - sw) / 2.0
    pan_y = output_size / 2.0 - bcy * zoom - (output_size - sh) / 2.0
    return {"pan_x": pan_x, "pan_y": pan_y, "zoom": zoom}


def render_manual_letter(
    edit_source: Image.Image,
    output_size: int,
    pan_x: float = 0.0,
    pan_y: float = 0.0,
    zoom: float = 1.0,
) -> Image.Image:
    """Pan/zoom edit_source into a fixed square export canvas."""
    canvas = Image.new("RGBA", (output_size, output_size), (0, 0, 0, 0))
    if edit_source is None:
        return canvas
    scaled_w = max(1, int(edit_source.width * zoom))
    scaled_h = max(1, int(edit_source.height * zoom))
    scaled = edit_source.resize((scaled_w, scaled_h), Image.Resampling.LANCZOS)
    paste_x = (output_size - scaled_w) // 2 + int(pan_x)
    paste_y = (output_size - scaled_h) // 2 + int(pan_y)
    canvas.paste(scaled, (paste_x, paste_y), scaled)
    return canvas


def render_editor_preview(
    edit_source: Image.Image,
    viewport: int,
    output_size: int,
    pan_x: float,
    pan_y: float,
    zoom: float,
    logical_origin: tuple[int, int] | None = None,
    logical_size: tuple[int, int] | None = None,
) -> Image.Image:
    """Draw full cell crop with export window overlay for the manual editor."""
    scale = viewport / float(output_size)
    frame = Image.new("RGBA", (viewport, viewport), (30, 30, 30, 255))
    draw = ImageDraw.Draw(frame)
    step = 16
    for y in range(0, viewport, step):
        for x in range(0, viewport, step):
            if (x // step + y // step) % 2:
                draw.rectangle([x, y, x + step, y + step], fill=(42, 42, 42, 255))

    sw = max(1, int(edit_source.width * zoom * scale))
    sh = max(1, int(edit_source.height * zoom * scale))
    scaled = edit_source.resize((sw, sh), Image.Resampling.LANCZOS)
    paste_x = int((viewport - sw) // 2 + pan_x * scale)
    paste_y = int((viewport - sh) // 2 + pan_y * scale)
    frame.alpha_composite(scaled, (paste_x, paste_y))

    margin = int(viewport * 0.06)
    overlay = Image.new("RGBA", (viewport, viewport), (0, 0, 0, 0))
    overlay_draw = ImageDraw.Draw(overlay)
    overlay_draw.rectangle([0, 0, viewport, margin], fill=(0, 0, 0, 120))
    overlay_draw.rectangle([0, viewport - margin, viewport, viewport], fill=(0, 0, 0, 120))
    overlay_draw.rectangle([0, 0, margin, viewport], fill=(0, 0, 0, 120))
    overlay_draw.rectangle([viewport - margin, 0, viewport, viewport], fill=(0, 0, 0, 120))
    frame.alpha_composite(overlay)

    border = ImageDraw.Draw(frame)
    border.rectangle(
        [margin, margin, viewport - margin, viewport - margin],
        outline=(0, 229, 204, 220),
        width=2,
    )

    if logical_origin is not None and logical_size is not None:
        lx, ly = logical_origin
        lw, lh = logical_size
        gx0 = int(paste_x + lx * zoom * scale)
        gy0 = int(paste_y + ly * zoom * scale)
        gx1 = int(paste_x + (lx + lw) * zoom * scale)
        gy1 = int(paste_y + (ly + lh) * zoom * scale)
        border.rectangle([gx0, gy0, gx1, gy1], outline=(255, 200, 60, 140), width=1)

    return frame


def apply_manual_to_letter_result(lr: LetterResult, output_size: int) -> LetterResult:
    if lr.edit_source is None:
        return lr
    adjust = lr.manual_adjust or default_manual_adjust(
        lr.edit_source, output_size, lr.bbox_in_cell
    )
    lr.manual_adjust = adjust
    lr.image = render_manual_letter(
        lr.edit_source,
        output_size,
        adjust.get("pan_x", 0.0),
        adjust.get("pan_y", 0.0),
        adjust.get("zoom", 1.0),
    )
    if "Manual crop applied" not in lr.notes:
        lr.notes.append("Manual crop applied")
    return lr


def center_on_canvas(
    letter_img: Image.Image,
    output_size: int = 512,
    max_fill: float = 0.92,
) -> Image.Image:
    canvas = Image.new("RGBA", (output_size, output_size), (0, 0, 0, 0))
    bbox = find_alpha_bbox(letter_img, alpha_threshold=1)
    if bbox is None:
        return canvas

    crop = letter_img.crop(bbox)
    cw, ch = crop.size
    max_dim = int(output_size * max_fill)
    scale = min(max_dim / max(cw, 1), max_dim / max(ch, 1))
    new_w = max(1, int(cw * scale))
    new_h = max(1, int(ch * scale))
    resized = crop.resize((new_w, new_h), Image.Resampling.LANCZOS)
    paste_x = (output_size - new_w) // 2
    paste_y = (output_size - new_h) // 2
    canvas.paste(resized, (paste_x, paste_y), resized)
    return canvas


def extract_letter_from_cell(
    cell_img: Image.Image,
    letter: str,
    col: int,
    row: int,
    cell_rect: tuple[int, int, int, int],
    output_size: int = 512,
    padding_px: int = 32,
    alpha_threshold: int = 16,
    remove_strays: bool = True,
    min_island_size: int = 20,
    logical_origin: tuple[int, int] | None = None,
    logical_size: tuple[int, int] | None = None,
    letter_index: int = 0,
    sheet_centers: list[tuple[float, float]] | None = None,
    crop_sheet_origin: tuple[int, int] | None = None,
    detection_mode: str = "center_out",
    strip_chroma: bool = False,
    green_delta: int = 60,
) -> LetterResult:
    crop_w, crop_h = cell_img.size
    if strip_chroma:
        edit_source = strip_residual_chroma(cell_img.copy(), green_delta)
    else:
        edit_source = cell_img.copy()
    if logical_origin is None:
        logical_origin = (0, 0)
    if logical_size is None:
        logical_size = (crop_w, crop_h)
    if crop_sheet_origin is None:
        crop_sheet_origin = (0, 0)

    warnings: list[str] = []
    notes: list[str] = []
    removed_count = 0
    bbox: tuple[int, int, int, int] | None = None
    work_img = cell_img

    use_center_out = (
        detection_mode == "center_out"
        and sheet_centers is not None
        and len(sheet_centers) > letter_index
    )

    if use_center_out:
        _full, letter_mask, bbox, removed_count, warnings, notes = extract_letter_mask_center_outward(
            cell_img,
            logical_origin,
            logical_size,
            letter_index,
            sheet_centers,
            crop_sheet_origin,
            alpha_threshold=alpha_threshold,
            min_pixels=min_island_size,
            strip_chroma=strip_chroma,
            green_delta=green_delta,
        )
        if bbox is None:
            return LetterResult(
                letter=letter,
                image=Image.new("RGBA", (output_size, output_size), (0, 0, 0, 0)),
                status="missing",
                source_cell=(col, row),
                source_cell_rect=cell_rect,
                bbox_in_cell=None,
                warnings=warnings or ["Missing / empty"],
                visible_pixel_count=0,
                edit_source=edit_source,
                logical_origin=logical_origin,
                logical_size=logical_size,
            )

        work_arr = np.array(strip_residual_chroma(cell_img, green_delta) if strip_chroma else cell_img)
        masked = work_arr.copy()
        masked[~letter_mask, 3] = 0
        work_img = Image.fromarray(masked, "RGBA")
        visible_count = int(np.sum(letter_mask))
        output = center_on_canvas_from_mask(work_img, letter_mask, output_size)
    else:
        bbox = find_alpha_bbox(cell_img, alpha_threshold)
        if bbox is None:
            return LetterResult(
                letter=letter,
                image=Image.new("RGBA", (output_size, output_size), (0, 0, 0, 0)),
                status="missing",
                source_cell=(col, row),
                source_cell_rect=cell_rect,
                bbox_in_cell=None,
                warnings=["Missing / empty"],
                visible_pixel_count=0,
                edit_source=edit_source,
                logical_origin=logical_origin,
                logical_size=logical_size,
            )

        if remove_strays:
            cleaned, removed_count = remove_tiny_islands(cell_img.copy(), alpha_threshold, min_island_size)
            cleaned_bbox = find_alpha_bbox(cleaned, alpha_threshold)
            if cleaned_bbox is not None:
                cb = cleaned_bbox
                bb = bbox
                cleaned_area = (cb[2] - cb[0]) * (cb[3] - cb[1])
                base_area = (bb[2] - bb[0]) * (bb[3] - bb[1])
                if cleaned_area >= base_area * 0.75:
                    bbox = cleaned_bbox

        visible_count = int(np.sum(np.array(cell_img)[:, :, 3] > alpha_threshold))
        warnings.extend(
            validate_bbox_in_cell(bbox, (crop_w, crop_h), logical_origin, logical_size)
        )
        if removed_count > 0:
            notes.append(f"Cleaned {removed_count} stray px")

        padded = _expand_and_clamp_bbox(bbox, padding_px, (crop_w, crop_h))
        crop = cell_img.crop(padded)
        output = center_on_canvas(crop, output_size)

    if visible_count < 50:
        if "Missing / empty" not in warnings:
            warnings.append("Missing / empty")

    if "Missing / empty" in warnings:
        status = "missing"
    elif warnings:
        status = "warning"
    else:
        status = "ok"

    return LetterResult(
        letter=letter,
        image=output,
        status=status,
        source_cell=(col, row),
        source_cell_rect=cell_rect,
        bbox_in_cell=bbox,
        warnings=warnings,
        notes=notes,
        visible_pixel_count=visible_count,
        edit_source=edit_source,
        logical_origin=logical_origin,
        logical_size=logical_size,
    )


def process_font_sheet(
    source_path: Path,
    font_set_name: str = "FontSet",
    cols: int = 7,
    rows: int = 4,
    output_size: int = 512,
    padding_px: int = 32,
    alpha_threshold: int = 16,
    green_delta: int = 60,
    background_mode: str = "auto",
    remove_strays: bool = True,
    min_island_size: int = 20,
    detection_mode: str = "center_out",
    output_dir: Path | None = None,
    save_files: bool = False,
    save_metadata: bool = True,
    on_progress: ProgressCallback | None = None,
) -> FontCutResult:
    img = load_font_sheet(source_path)
    processed, bg_mode_used = apply_background_processing(img, background_mode, green_delta)
    w, h = processed.size
    strip_chroma = bg_mode_used == "green2alpha"
    sheet_centers = compute_sheet_cell_centers(w, h, cols, rows)

    metadata: dict = {
        "type": "lettrage_font_set",
        "font_set_name": font_set_name,
        "source_file": source_path.name,
        "source_size": [w, h],
        "grid": {
            "columns": cols,
            "rows": rows,
            "letter_order": LETTERS,
        },
        "background_processing": {
            "mode": bg_mode_used,
            "requested_mode": background_mode,
            "green_delta": green_delta,
            "alpha_threshold": alpha_threshold,
        },
        "export": {
            "size": [output_size, output_size],
            "padding_px": padding_px,
            "detection_mode": detection_mode,
        },
        "letters": {},
    }

    results: list[LetterResult] = []
    total = len(LETTERS)

    for i, letter in enumerate(LETTERS):
        if on_progress:
            on_progress(i + 1, total, f"Processing {letter} ({i + 1}/{total})")

        row = i // cols
        col = i % cols
        rect = _cell_rect(col, row, w, h, cols, rows)
        crop_rect, logical = _cell_crop_rect(col, row, w, h, cols, rows)
        cell = processed.crop(crop_rect)
        logical_origin = (logical[0], logical[1])
        logical_size = (logical[2], logical[3])

        result = extract_letter_from_cell(
            cell,
            letter,
            col,
            row,
            rect,
            output_size=output_size,
            padding_px=padding_px,
            alpha_threshold=alpha_threshold,
            remove_strays=remove_strays,
            min_island_size=min_island_size,
            logical_origin=logical_origin,
            logical_size=logical_size,
            letter_index=i,
            sheet_centers=sheet_centers,
            crop_sheet_origin=(crop_rect[0], crop_rect[1]),
            detection_mode=detection_mode,
            strip_chroma=strip_chroma,
            green_delta=green_delta,
        )
        results.append(result)

        metadata["letters"][letter] = {
            "status": result.status,
            "export_file": letter_export_filename(font_set_name, letter),
            "source_cell": list(result.source_cell),
            "source_cell_rect": list(result.source_cell_rect),
            "bbox_in_cell": list(result.bbox_in_cell) if result.bbox_in_cell else None,
            "visible_pixel_count": result.visible_pixel_count,
            "warnings": result.warnings,
            "notes": result.notes,
        }

        if save_files and output_dir:
            output_dir.mkdir(parents=True, exist_ok=True)
            result.image.save(output_dir / letter_export_filename(font_set_name, letter), "PNG")

    if save_files and output_dir and save_metadata:
        meta_path = output_dir / "metadata.json"
        meta_path.write_text(json.dumps(metadata, indent=2), encoding="utf-8")

    return FontCutResult(
        letters=results,
        processed_sheet=processed,
        metadata=metadata,
        output_dir=output_dir if save_files else None,
    )
