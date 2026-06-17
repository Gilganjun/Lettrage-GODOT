"""Tab 3: Batch image resize with live preview."""

from __future__ import annotations

import tempfile
import tkinter as tk
from pathlib import Path
from tkinter import filedialog, messagebox, ttk

from paths import IMAGE_EXTENSIONS, make_timestamped_output_dir
from services.image_resizer import (
    compute_for_target_kb,
    compute_from_height,
    compute_from_percentage,
    compute_from_width,
    resize_batch,
    resize_image,
)
from theme import BG, PANEL, TEXT_DIM, Theme
from utils import load_preview_image, run_in_thread


class ResizeTab(ttk.Frame):
    def __init__(self, parent: tk.Misc, theme: Theme) -> None:
        super().__init__(parent, style="TFrame")
        self.theme = theme
        self.input_paths: list[Path] = []
        self.preview_path: Path | None = None
        self.orig_w = 0
        self.orig_h = 0
        self._syncing = False

        self.percentage = tk.DoubleVar(value=100.0)
        self.width = tk.IntVar(value=256)
        self.height = tk.IntVar(value=256)
        self.target_kb = tk.DoubleVar(value=100.0)
        self.mode = tk.StringVar(value="percentage")

        self._preview_photo: tk.PhotoImage | None = None
        self._busy = False
        self._preview_job: str | None = None
        self._build_ui()
        self._bind_sync()

    def _build_ui(self) -> None:
        self.columnconfigure(0, weight=0, minsize=380)
        self.columnconfigure(1, weight=1)
        self.rowconfigure(0, weight=1)

        left = self.theme.panel(self, padx=16, pady=16)
        left.grid(row=0, column=0, sticky="nsew", padx=(12, 6), pady=12)
        left.columnconfigure(0, weight=1)
        left.rowconfigure(0, weight=1)
        left.rowconfigure(1, weight=0)

        controls = tk.Frame(left, bg=PANEL)
        controls.grid(row=0, column=0, sticky="nsew")
        controls.columnconfigure(0, weight=1)

        footer = tk.Frame(left, bg=PANEL)
        footer.grid(row=1, column=0, sticky="ew", pady=(12, 0))

        self.theme.heading(controls, "Resize").pack(anchor="w", pady=(0, 4))
        self.theme.label(
            controls,
            "Shrink or resize PNG frames. Controls stay in sync.",
            bg=PANEL,
            fg=TEXT_DIM,
            wraplength=340,
        ).pack(anchor="w", pady=(0, 8))

        btn_row = tk.Frame(controls, bg=PANEL)
        btn_row.pack(anchor="w", pady=4)
        self.theme.button(btn_row, "Add Images", self._add_images).pack(side=tk.LEFT, padx=(0, 8))
        self.theme.button(btn_row, "Add Folder", self._add_folder).pack(side=tk.LEFT)

        self.file_count_label = self.theme.label(controls, "0 images loaded", bg=PANEL, fg=TEXT_DIM)
        self.file_count_label.pack(anchor="w", pady=(4, 8))

        mode_frame = tk.Frame(controls, bg=PANEL)
        mode_frame.pack(anchor="w", pady=(0, 6))
        for text, value in [
            ("%", "percentage"),
            ("Width", "width"),
            ("Height", "height"),
            ("Target KB", "target_kb"),
        ]:
            ttk.Radiobutton(
                mode_frame,
                text=text,
                value=value,
                variable=self.mode,
                command=self._on_mode_change,
            ).pack(side=tk.LEFT, padx=(0, 10))

        self._field(controls, "Percentage (%)", self.percentage, 1, 400, decimals=1)
        self._field(controls, "Width (px)", self.width, 1, 4096, decimals=0)
        self._field(controls, "Height (px)", self.height, 1, 4096, decimals=0)
        self._field(controls, "Target KB", self.target_kb, 1, 5000, decimals=1)

        self.est_kb_label = self.theme.label(controls, "Estimated size: —", bg=PANEL, fg=TEXT_DIM)
        self.est_kb_label.pack(anchor="w", pady=(6, 0))

        self.save_btn = self.theme.button(footer, "Save", self._save_all, accent=True)
        self.save_btn.pack(anchor="w", fill=tk.X)

        self.progress = ttk.Progressbar(footer, orient="horizontal", mode="determinate")
        self.progress.pack(anchor="w", fill=tk.X, pady=(8, 4))

        self.status_label = self.theme.label(
            footer,
            "Load images, adjust size, then click Save.",
            bg=PANEL,
            fg=TEXT_DIM,
            wraplength=340,
            justify=tk.LEFT,
        )
        self.status_label.pack(anchor="w")

        right = self.theme.panel(self, padx=16, pady=16)
        right.grid(row=0, column=1, sticky="nsew", padx=(6, 12), pady=12)
        right.rowconfigure(1, weight=1)
        right.columnconfigure(0, weight=1)

        self.theme.heading(right, "Live Preview").pack(anchor="w", pady=(0, 8))
        self.preview_label = tk.Label(right, bg=PANEL, fg=TEXT_DIM, text="No preview")
        self.preview_label.pack(expand=True, fill=tk.BOTH)

    def _field(
        self,
        parent: tk.Misc,
        label: str,
        variable: tk.Variable,
        from_: float,
        to: float,
        decimals: int = 0,
    ) -> None:
        frame = tk.Frame(parent, bg=PANEL)
        frame.pack(anchor="w", fill=tk.X, pady=2)
        row = tk.Frame(frame, bg=PANEL)
        row.pack(fill=tk.X)
        self.theme.label(row, label, bg=PANEL).pack(side=tk.LEFT)
        val_label = self.theme.label(row, "", bg=PANEL, fg=TEXT_DIM)
        val_label.pack(side=tk.RIGHT)

        def update(*_args: object) -> None:
            val = variable.get()
            if decimals == 0:
                val_label.config(text=str(int(round(float(val)))))
            else:
                val_label.config(text=f"{float(val):.{decimals}f}")

        variable.trace_add("write", update)
        update()
        ttk.Scale(frame, from_=from_, to=to, variable=variable, orient=tk.HORIZONTAL).pack(fill=tk.X)

    def _bind_sync(self) -> None:
        self.percentage.trace_add("write", lambda *_: self._on_percent_change())
        self.width.trace_add("write", lambda *_: self._on_width_change())
        self.height.trace_add("write", lambda *_: self._on_height_change())
        self.target_kb.trace_add("write", lambda *_: self._on_target_kb_change())

    def _on_mode_change(self) -> None:
        self._apply_mode_driver()

    def _apply_mode_driver(self) -> None:
        if self.orig_w <= 0 or self.orig_h <= 0:
            return
        mode = self.mode.get()
        self._syncing = True
        try:
            if mode == "percentage":
                params = compute_from_percentage(self.orig_w, self.orig_h, self.percentage.get())
            elif mode == "width":
                params = compute_from_width(self.orig_w, self.orig_h, self.width.get())
            elif mode == "height":
                params = compute_from_height(self.orig_w, self.orig_h, self.height.get())
            else:
                from PIL import Image

                if self.preview_path:
                    with Image.open(self.preview_path) as img:
                        params = compute_for_target_kb(img, self.target_kb.get(), self.orig_w, self.orig_h)
                else:
                    return
            self.width.set(params.width)
            self.height.set(params.height)
            self.percentage.set(round(params.percentage, 2))
        finally:
            self._syncing = False
        self._schedule_preview()

    def _on_percent_change(self) -> None:
        if self._syncing or self.mode.get() != "percentage":
            self._schedule_preview()
            return
        self._syncing = True
        try:
            params = compute_from_percentage(self.orig_w, self.orig_h, self.percentage.get())
            self.width.set(params.width)
            self.height.set(params.height)
        finally:
            self._syncing = False
        self._schedule_preview()

    def _on_width_change(self) -> None:
        if self._syncing or self.mode.get() != "width":
            self._schedule_preview()
            return
        self._syncing = True
        try:
            params = compute_from_width(self.orig_w, self.orig_h, self.width.get())
            self.height.set(params.height)
            self.percentage.set(round(params.percentage, 2))
        finally:
            self._syncing = False
        self._schedule_preview()

    def _on_height_change(self) -> None:
        if self._syncing or self.mode.get() != "height":
            self._schedule_preview()
            return
        self._syncing = True
        try:
            params = compute_from_height(self.orig_w, self.orig_h, self.height.get())
            self.width.set(params.width)
            self.percentage.set(round(params.percentage, 2))
        finally:
            self._syncing = False
        self._schedule_preview()

    def _on_target_kb_change(self) -> None:
        if self._syncing or self.mode.get() != "target_kb":
            return
        self._apply_mode_driver()

    def _schedule_preview(self) -> None:
        if self._preview_job:
            self.after_cancel(self._preview_job)
        self._preview_job = self.after(150, self._update_preview)

    def _collect_paths(self, folder: Path) -> list[Path]:
        paths: list[Path] = []
        for ext in IMAGE_EXTENSIONS:
            paths.extend(folder.glob(f"*{ext}"))
            paths.extend(folder.glob(f"*{ext.upper()}"))
        return sorted(set(paths))

    def _add_images(self) -> None:
        files = filedialog.askopenfilenames(filetypes=[("Images", "*.png *.jpg *.jpeg *.webp *.bmp")])
        if files:
            for f in files:
                p = Path(f)
                if p.suffix.lower() in IMAGE_EXTENSIONS and p not in self.input_paths:
                    self.input_paths.append(p)
            self._refresh_files()

    def _add_folder(self) -> None:
        folder = filedialog.askdirectory()
        if folder:
            for p in self._collect_paths(Path(folder)):
                if p not in self.input_paths:
                    self.input_paths.append(p)
            self._refresh_files()

    def _refresh_files(self) -> None:
        self.input_paths.sort(key=lambda p: p.name.lower())
        self.file_count_label.config(text=f"{len(self.input_paths)} images loaded")
        if self.input_paths:
            self.preview_path = self.input_paths[0]
            from PIL import Image

            with Image.open(self.preview_path) as img:
                self.orig_w, self.orig_h = img.size
            self.width.set(self.orig_w)
            self.height.set(self.orig_h)
            self.percentage.set(100.0)
            self._update_preview()
        else:
            self.preview_path = None
            self.preview_label.config(image="", text="No preview")

    def _update_preview(self) -> None:
        if not self.preview_path:
            return
        try:
            from PIL import Image

            with Image.open(self.preview_path) as img:
                resized = resize_image(img, self.width.get(), self.height.get())
                with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as tmp_file:
                    tmp = Path(tmp_file.name)
                resized.save(tmp, "PNG")
                kb = tmp.stat().st_size / 1024.0
                self.est_kb_label.config(
                    text=f"Estimated size: {kb:.1f} KB ({self.width.get()}×{self.height.get()})"
                )
                photo = load_preview_image(str(tmp), (700, 700))
                tmp.unlink(missing_ok=True)
                if photo:
                    self._preview_photo = photo
                    self.preview_label.config(image=photo, text="")
        except Exception as exc:
            self.preview_label.config(image="", text=str(exc))

    def _set_busy(self, busy: bool) -> None:
        self._busy = busy
        self.save_btn.config(state=tk.DISABLED if busy else tk.NORMAL)

    def _on_progress(self, current: int, total: int, message: str) -> None:
        self.after(0, lambda: self._update_progress(current, total, message))

    def _update_progress(self, current: int, total: int, message: str) -> None:
        self.progress["maximum"] = max(total, 1)
        self.progress["value"] = current
        self.status_label.config(text=message)

    def _save_all(self) -> None:
        if self._busy:
            return
        if not self.input_paths:
            messagebox.showerror("Error", "Please load at least one image.")
            return

        output_dir = make_timestamped_output_dir("Shrink_Output")
        w, h = self.width.get(), self.height.get()
        paths = list(self.input_paths)
        self._set_busy(True)
        self.status_label.config(text="Saving…")

        def work() -> None:
            resize_batch(paths, output_dir, w, h, on_progress=self._on_progress)

            def done() -> None:
                self._set_busy(False)
                self.status_label.config(text=f"Saved to {output_dir}")
                messagebox.showinfo("Save Complete", f"Saved {len(paths)} images to:\n{output_dir}")

            self.after(0, done)

        run_in_thread(self, work)
