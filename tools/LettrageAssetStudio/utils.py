"""Threading and UI helpers."""

from __future__ import annotations

import threading
import tkinter as tk
from collections.abc import Callable
from tkinter import messagebox

from PIL import Image, ImageTk


def run_in_thread(root: tk.Misc, work: Callable[[], None], on_done: Callable[[], None] | None = None) -> None:
    def wrapper() -> None:
        try:
            work()
        except Exception as exc:
            root.after(0, lambda: messagebox.showerror("Error", str(exc)))
        finally:
            if on_done:
                root.after(0, on_done)

    threading.Thread(target=wrapper, daemon=True).start()


def load_preview_image(
    path: str | None,
    max_size: tuple[int, int],
    zoom: float = 1.0,
) -> ImageTk.PhotoImage | None:
    if not path:
        return None
    try:
        with Image.open(path) as img:
            img = img.convert("RGBA")
            w, h = img.size
            tw = int(w * zoom)
            th = int(h * zoom)
            max_w, max_h = max_size
            scale = min(max_w / max(tw, 1), max_h / max(th, 1), 1.0)
            display_w = max(1, int(tw * scale))
            display_h = max(1, int(th * scale))
            img = img.resize((display_w, display_h), Image.Resampling.LANCZOS)
            return ImageTk.PhotoImage(img)
    except Exception:
        return None


def checkerboard_canvas(canvas: tk.Canvas, width: int, height: int, cell: int = 12) -> None:
    canvas.delete("checker")
    colors = ("#2A2A2A", "#1E1E1E")
    for y in range(0, height, cell):
        for x in range(0, width, cell):
            c = colors[((x // cell) + (y // cell)) % 2]
            canvas.create_rectangle(x, y, x + cell, y + cell, fill=c, outline=c, tags="checker")
