"""Manual letter crop editor — pan, zoom, and fine-tune a single letter export."""

from __future__ import annotations

import tkinter as tk
from typing import Callable

from PIL import ImageTk

from services.font_cutter import (
    LetterResult,
    default_manual_adjust,
    render_editor_preview,
    render_manual_letter,
)
from theme import ACCENT, BG, PANEL, TEXT_DIM, Theme


class LetterCropEditor(tk.Toplevel):
    VIEWPORT = 440
    PAN_STEP = 8
    ZOOM_STEP = 1.1

    def __init__(
        self,
        parent: tk.Misc,
        theme: Theme,
        letter_result: LetterResult,
        output_size: int,
        on_apply: Callable[[LetterResult], None],
    ) -> None:
        super().__init__(parent)
        self.theme = theme
        self.lr = letter_result
        self.output_size = output_size
        self.on_apply = on_apply
        self._photo: ImageTk.PhotoImage | None = None
        self._drag_start: tuple[int, int] | None = None

        if self.lr.edit_source is None:
            self.destroy()
            return

        self.title(f"Edit Letter — {self.lr.letter}")
        self.configure(bg=BG)
        self.geometry("560x680")
        self.transient(parent)
        self.grab_set()

        adjust = self.lr.manual_adjust or default_manual_adjust(
            self.lr.edit_source, output_size, self.lr.bbox_in_cell
        )
        self.pan_x = float(adjust.get("pan_x", 0.0))
        self.pan_y = float(adjust.get("pan_y", 0.0))
        self.zoom = float(adjust.get("zoom", 1.0))

        self._build_ui()
        self._redraw()
        self.bind("<Key>", self._on_key)

    def _build_ui(self) -> None:
        header = tk.Frame(self, bg=PANEL, padx=12, pady=8)
        header.pack(fill=tk.X)
        self.theme.heading(header, f"Letter {self.lr.letter}").pack(anchor="w")
        self.theme.label(
            header,
            "Full cell crop shown · Cyan = export window · Gold = grid cell",
            bg=PANEL,
            fg=TEXT_DIM,
        ).pack(anchor="w")
        self.theme.label(
            header,
            "Drag to pan · Mouse wheel to zoom · Arrow keys to nudge",
            bg=PANEL,
            fg=TEXT_DIM,
        ).pack(anchor="w")

        frame = tk.Frame(self, bg=BG, padx=12, pady=8)
        frame.pack(fill=tk.BOTH, expand=True)

        self.canvas = tk.Canvas(
            frame,
            width=self.VIEWPORT,
            height=self.VIEWPORT,
            bg="#0a0a0a",
            highlightthickness=2,
            highlightbackground=ACCENT,
        )
        self.canvas.pack()
        self.canvas.bind("<ButtonPress-1>", self._on_drag_start)
        self.canvas.bind("<B1-Motion>", self._on_drag_move)
        self.canvas.bind("<ButtonRelease-1>", self._on_drag_end)
        self.canvas.bind("<MouseWheel>", self._on_wheel)
        self.canvas.bind("<Button-4>", lambda _e: self._zoom_at(1 / self.ZOOM_STEP))
        self.canvas.bind("<Button-5>", lambda _e: self._zoom_at(self.ZOOM_STEP))

        controls = tk.Frame(self, bg=PANEL, padx=12, pady=10)
        controls.pack(fill=tk.X)

        row1 = tk.Frame(controls, bg=PANEL)
        row1.pack(fill=tk.X, pady=(0, 6))
        self.theme.button(row1, "Zoom −", lambda: self._zoom_at(1 / self.ZOOM_STEP)).pack(side=tk.LEFT, padx=(0, 6))
        self.theme.button(row1, "Zoom +", lambda: self._zoom_at(self.ZOOM_STEP)).pack(side=tk.LEFT, padx=(0, 6))
        self.theme.button(row1, "Fit Letter", self._reset).pack(side=tk.LEFT, padx=(0, 6))
        self.theme.button(row1, "Fit Cell", self._fit_full_cell).pack(side=tk.LEFT)

        self.info_label = self.theme.label(row1, "", bg=PANEL, fg=TEXT_DIM)
        self.info_label.pack(side=tk.RIGHT)

        row2 = tk.Frame(controls, bg=PANEL)
        row2.pack(fill=tk.X)
        self.theme.button(row2, "Cancel", self.destroy).pack(side=tk.RIGHT, padx=(6, 0))
        self.theme.button(row2, "Apply", self._apply, accent=True).pack(side=tk.RIGHT)

    def _reset(self) -> None:
        adjust = default_manual_adjust(
            self.lr.edit_source, self.output_size, self.lr.bbox_in_cell
        )
        self.pan_x = float(adjust["pan_x"])
        self.pan_y = float(adjust["pan_y"])
        self.zoom = float(adjust["zoom"])
        self._redraw()

    def _fit_full_cell(self) -> None:
        src = self.lr.edit_source
        fit = min(
            self.output_size * 0.92 / max(src.width, 1),
            self.output_size * 0.92 / max(src.height, 1),
        )
        self.pan_x = 0.0
        self.pan_y = 0.0
        self.zoom = fit
        self._redraw()

    def _zoom_at(self, factor: float) -> None:
        self.zoom = max(0.05, min(self.zoom * factor, 8.0))
        self._redraw()

    def _on_wheel(self, event: tk.Event) -> None:
        if event.delta > 0:
            self._zoom_at(self.ZOOM_STEP)
        else:
            self._zoom_at(1 / self.ZOOM_STEP)

    def _on_drag_start(self, event: tk.Event) -> None:
        self._drag_start = (event.x, event.y)

    def _on_drag_move(self, event: tk.Event) -> None:
        if self._drag_start is None:
            return
        scale = self.VIEWPORT / float(self.output_size)
        dx = (event.x - self._drag_start[0]) / scale
        dy = (event.y - self._drag_start[1]) / scale
        self.pan_x += dx
        self.pan_y += dy
        self._drag_start = (event.x, event.y)
        self._redraw()

    def _on_drag_end(self, _event: tk.Event) -> None:
        self._drag_start = None

    def _on_key(self, event: tk.Event) -> None:
        step = self.PAN_STEP
        key = event.keysym
        if key in ("Left", "a"):
            self.pan_x -= step
        elif key in ("Right", "d"):
            self.pan_x += step
        elif key in ("Up", "w"):
            self.pan_y -= step
        elif key in ("Down", "s"):
            self.pan_y += step
        elif key in ("plus", "equal"):
            self._zoom_at(self.ZOOM_STEP)
        elif key == "minus":
            self._zoom_at(1 / self.ZOOM_STEP)
        elif key == "Escape":
            self.destroy()
            return
        else:
            return
        self._redraw()

    def _redraw(self) -> None:
        if self.lr.edit_source is None:
            return
        preview = render_editor_preview(
            self.lr.edit_source,
            self.VIEWPORT,
            self.output_size,
            self.pan_x,
            self.pan_y,
            self.zoom,
            self.lr.logical_origin,
            self.lr.logical_size,
        )
        self._photo = ImageTk.PhotoImage(preview)
        self.canvas.delete("all")
        self.canvas.create_image(0, 0, anchor="nw", image=self._photo)
        self.info_label.config(
            text=(
                f"Source {self.lr.edit_source.width}×{self.lr.edit_source.height}px  ·  "
                f"Zoom {self.zoom:.2f}  ·  Pan ({int(self.pan_x)}, {int(self.pan_y)})"
            )
        )

    def _apply(self) -> None:
        self.lr.manual_adjust = {
            "pan_x": self.pan_x,
            "pan_y": self.pan_y,
            "zoom": self.zoom,
        }
        self.lr.image = render_manual_letter(
            self.lr.edit_source,
            self.output_size,
            self.pan_x,
            self.pan_y,
            self.zoom,
        )
        if "Manual crop applied" not in self.lr.notes:
            self.lr.notes.append("Manual crop applied")
        if self.lr.warnings and self.lr.status == "warning":
            self.lr.status = "ok"
            self.lr.warnings = []
        self.on_apply(self.lr)
        self.destroy()
