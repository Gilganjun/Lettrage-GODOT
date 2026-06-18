"""Compute death-frame sprite offsets aligned to Character_Idle foot position."""
from __future__ import annotations

from pathlib import Path

from PIL import Image
import numpy as np

ROOT = Path(__file__).resolve().parent.parent
IDLE_PATH = ROOT / "characters/Character_Idle.png"
DEATH_DIR = ROOT / "assets/Characters/Original_Char/Death"
GDSCRIPT_PATH = ROOT / "scripts/player/player_death_frame_alignment.gd"


def foot_metrics(path: Path) -> tuple[float, float]:
	im = Image.open(path).convert("RGBA")
	arr = np.array(im)
	alpha = arr[:, :, 3]
	rows = np.where(alpha.max(axis=1) > 20)[0]
	if len(rows) == 0:
		return 0.0, 0.0
	foot = int(rows.max())
	width = arr.shape[1]
	x0, x1 = int(width * 0.2), int(width * 0.8)
	row_alpha = alpha[foot, x0:x1]
	xs = np.where(row_alpha > 20)[0] + x0
	cx = float(xs.mean()) if len(xs) else width / 2.0
	return cx, float(foot)


def main() -> None:
	idle_cx, idle_foot = foot_metrics(IDLE_PATH)
	offsets: list[tuple[float, float]] = []
	for i in range(1, 33):
		name = f"death_{i:03d}.png" if i != 31 else "death_031_.png"
		cx, foot = foot_metrics(DEATH_DIR / name)
		offsets.append((round(idle_cx - cx, 2), round(idle_foot - foot, 2)))

	lines = ["\tVector2(%s, %s)," % (ox, oy) for ox, oy in offsets]
	block = "const DEATH_FRAME_OFFSETS: Array[Vector2] = [\n" + "\n".join(lines) + "\n]"
	content = GDSCRIPT_PATH.read_text(encoding="utf-8")
	start = content.index("const DEATH_FRAME_OFFSETS")
	end = content.index("]", start) + 1
	GDSCRIPT_PATH.write_text(content[:start] + block + content[end:], encoding="utf-8", newline="\n")
	print(f"Updated {GDSCRIPT_PATH.name} with {len(offsets)} offsets")


if __name__ == "__main__":
	main()
