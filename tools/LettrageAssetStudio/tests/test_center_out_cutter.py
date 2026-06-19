"""Smoke test for center-out font extraction."""

from __future__ import annotations

import sys
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from services.font_cutter import process_font_sheet  # noqa: E402


def _make_test_sheet(path: Path, cols: int = 7, rows: int = 4) -> None:
    w, h = 700, 400
    img = Image.new("RGBA", (w, h), (0, 255, 0, 255))
    draw = ImageDraw.Draw(img)
    letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    for i, ch in enumerate(letters):
        row, col = divmod(i, cols)
        cw, ch_h = w // cols, h // rows
        x0 = col * cw + cw // 4
        y0 = row * ch_h + ch_h // 4
        x1 = x0 + cw // 2
        y1 = y0 + ch_h // 2
        draw.rectangle([x0, y0, x1, y1], fill=(255, 0, 0, 255))
        draw.text((x0 + 8, y0 + 8), ch, fill=(255, 255, 255, 255))
    img.save(path)


def main() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        sheet = Path(tmp) / "test_sheet.png"
        out = Path(tmp) / "out"
        _make_test_sheet(sheet)
        result = process_font_sheet(
            sheet,
            font_set_name="TestFont",
            cols=7,
            rows=4,
            output_size=256,
            background_mode="green",
            detection_mode="center_out",
            output_dir=out,
            save_files=True,
        )
        ok = sum(1 for lr in result.letters if lr.status == "ok")
        warn = sum(1 for lr in result.letters if lr.status == "warning")
        miss = sum(1 for lr in result.letters if lr.status == "missing")
        assert miss == 0, f"expected no missing, got {miss}"
        assert ok >= 20, f"expected mostly ok, got ok={ok} warn={warn} miss={miss}"
        for lr in result.letters:
            arr = np.array(lr.image)
            assert arr[:, :, 3].max() > 0, f"{lr.letter} export empty"
        print(f"PASS center-out: ok={ok} warn={warn} miss={miss}")


if __name__ == "__main__":
    main()
