"""Tab 2: Green-screen to transparent PNG conversion."""

from __future__ import annotations

import tempfile
import tkinter as tk
from pathlib import Path
from tkinter import filedialog, messagebox, ttk

from paths import IMAGE_EXTENSIONS, make_timestamped_output_dir
from services.chroma_key import process_batch, process_image
from theme import BG, PANEL, TEXT_DIM, Theme
from utils import load_preview_image, run_in_thread


class Green2AlphaTab(ttk.Frame):
    def __init__(self, parent: tk.Misc, theme: Theme) -> None:
        super().__init__(parent, style="TFrame")
        self.theme = theme
        self.input_paths: list[Path] = []
        self.preview_index = 0
        self.zoom = tk.DoubleVar(value=1.0)

        self.sensitivity = tk.IntVar(value=40)
        self.spill = tk.IntVar(value=50)
        self.feather = tk.IntVar(value=1)
        self.remove_shadows = tk.BooleanVar(value=True)

        self._before_photo: tk.PhotoImage | None = None
        self._after_photo: tk.PhotoImage | None = None
        self._busy = False
        self._preview_job: str | None = None
        self._build_ui()
        self._bind_preview_updates()

    def _build_ui(self) -> None:
        self.columnconfigure(0, weight=0, minsize=340)
        self.columnconfigure(1, weight=1)
        self.rowconfigure(0, weight=1)

        left = self.theme.panel(self, padx=16, pady=16)
        left.grid(row=0, column=0, sticky="nsew", padx=(12, 6), pady=12)

        self.theme.heading(left, "Green2Alpha").pack(anchor="w", pady=(0, 8))
        self.theme.label(left, "Convert green-screen images to transparent PNGs.", bg=PANEL, fg=TEXT_DIM, wraplength=300).pack(anchor="w", pady=(0, 12))

        btn_row = tk.Frame(left, bg=PANEL)
        btn_row.pack(anchor="w", pady=4)
        self.theme.button(btn_row, "Add Images", self._add_images).pack(side=tk.LEFT, padx=(0, 8))
        self.theme.button(btn_row, "Add Folder", self._add_folder).pack(side=tk.LEFT)

        self.file_count_label = self.theme.label(left, "0 images loaded", bg=PANEL, fg=TEXT_DIM)
        self.file_count_label.pack(anchor="w", pady=8)

        self._slider(left, "Green Sensitivity", self.sensitivity, 0, 100)
        self._slider(left, "Spill Reduction", self.spill, 0, 100)
        self._slider(left, "Edge Feather (px)", self.feather, 0, 5)

        ttk.Checkbutton(left, text="Remove Foot Shadows", variable=self.remove_shadows).pack(anchor="w", pady=8)

        zoom_row = tk.Frame(left, bg=PANEL)
        zoom_row.pack(anchor="w", pady=8, fill=tk.X)
        self.theme.label(zoom_row, "Preview Zoom:", bg=PANEL).pack(side=tk.LEFT)
        ttk.Scale(zoom_row, from_=0.5, to=3.0, variable=self.zoom, orient=tk.HORIZONTAL).pack(side=tk.LEFT, fill=tk.X, expand=True, padx=8)

        self.process_btn = self.theme.button(left, "Process All", self._process_all, accent=True)
        self.process_btn.pack(anchor="w", pady=16)

        self.progress = ttk.Progressbar(left, orient="horizontal", mode="determinate", length=300)
        self.progress.pack(anchor="w", fill=tk.X, pady=4)
        self.status_label = self.theme.label(left, "Load images to begin.", bg=PANEL, fg=TEXT_DIM, wraplength=300)
        self.status_label.pack(anchor="w", pady=4)

        right = tk.Frame(self, bg=BG)
        right.grid(row=0, column=1, sticky="nsew", padx=(6, 12), pady=12)
        right.columnconfigure(0, weight=1)
        right.columnconfigure(1, weight=1)
        right.rowconfigure(1, weight=1)

        self.theme.heading(right, "Before").grid(row=0, column=0, sticky="w", padx=8, pady=4)
        self.theme.heading(right, "After").grid(row=0, column=1, sticky="w", padx=8, pady=4)

        self.before_label = tk.Label(right, bg=PANEL, fg=TEXT_DIM, text="No image")
        self.before_label.grid(row=1, column=0, sticky="nsew", padx=8, pady=4)
        self.after_label = tk.Label(right, bg=PANEL, fg=TEXT_DIM, text="No preview")
        self.after_label.grid(row=1, column=1, sticky="nsew", padx=8, pady=4)

        nav = tk.Frame(right, bg=BG)
        nav.grid(row=2, column=0, columnspan=2, pady=8)
        self.theme.button(nav, "◀ Prev", self._prev_preview).pack(side=tk.LEFT, padx=4)
        self.preview_nav_label = self.theme.label(nav, "—")
        self.preview_nav_label.pack(side=tk.LEFT, padx=12)
        self.theme.button(nav, "Next ▶", self._next_preview).pack(side=tk.LEFT, padx=4)

    def _slider(self, parent: tk.Misc, label: str, variable: tk.IntVar, from_: int, to: int) -> None:
        frame = tk.Frame(parent, bg=PANEL)
        frame.pack(anchor="w", fill=tk.X, pady=4)
        row = tk.Frame(frame, bg=PANEL)
        row.pack(fill=tk.X)
        self.theme.label(row, label, bg=PANEL).pack(side=tk.LEFT)
        val_label = self.theme.label(row, "", bg=PANEL, fg=TEXT_DIM)
        val_label.pack(side=tk.RIGHT)

        def update(*_args: object) -> None:
            val_label.config(text=str(variable.get()))

        variable.trace_add("write", update)
        update()
        ttk.Scale(frame, from_=from_, to=to, variable=variable, orient=tk.HORIZONTAL).pack(fill=tk.X, pady=2)

    def _bind_preview_updates(self) -> None:
        for var in (self.sensitivity, self.spill, self.feather, self.remove_shadows, self.zoom):
            var.trace_add("write", lambda *_: self._schedule_preview())

    def _schedule_preview(self) -> None:
        if self._preview_job:
            self.after_cancel(self._preview_job)
        self._preview_job = self.after(200, self._update_preview)

    def _collect_paths(self, folder: Path) -> list[Path]:
        paths: list[Path] = []
        for ext in IMAGE_EXTENSIONS:
            paths.extend(folder.glob(f"*{ext}"))
            paths.extend(folder.glob(f"*{ext.upper()}"))
        return sorted(set(paths))

    def _add_images(self) -> None:
        files = filedialog.askopenfilenames(
            filetypes=[
                ("Images", "*.png *.jpg *.jpeg *.webp *.bmp"),
                ("All files", "*.*"),
            ]
        )
        if files:
            for f in files:
                p = Path(f)
                if p.suffix.lower() in IMAGE_EXTENSIONS and p not in self.input_paths:
                    self.input_paths.append(p)
            self._refresh_file_list()

    def _add_folder(self) -> None:
        folder = filedialog.askdirectory()
        if folder:
            for p in self._collect_paths(Path(folder)):
                if p not in self.input_paths:
                    self.input_paths.append(p)
            self._refresh_file_list()

    def _refresh_file_list(self) -> None:
        self.input_paths.sort(key=lambda p: p.name.lower())
        self.file_count_label.config(text=f"{len(self.input_paths)} images loaded")
        if self.input_paths:
            self.preview_index = min(self.preview_index, len(self.input_paths) - 1)
            self._update_preview()
        else:
            self.before_label.config(image="", text="No image")
            self.after_label.config(image="", text="No preview")

    def _prev_preview(self) -> None:
        if not self.input_paths:
            return
        self.preview_index = (self.preview_index - 1) % len(self.input_paths)
        self._update_preview()

    def _next_preview(self) -> None:
        if not self.input_paths:
            return
        self.preview_index = (self.preview_index + 1) % len(self.input_paths)
        self._update_preview()

    def _update_preview(self) -> None:
        if not self.input_paths:
            return

        src = self.input_paths[self.preview_index]
        self.preview_nav_label.config(text=f"{self.preview_index + 1} / {len(self.input_paths)} — {src.name}")

        zoom = self.zoom.get()
        before = load_preview_image(str(src), (520, 520), zoom=zoom)
        if before:
            self._before_photo = before
            self.before_label.config(image=before, text="")

        try:
            result = process_image(
                src,
                self.sensitivity.get(),
                self.spill.get(),
                self.feather.get(),
                self.remove_shadows.get(),
            )
            with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as tmp_file:
                tmp_path = Path(tmp_file.name)
            result.save(tmp_path, "PNG")
            after = load_preview_image(str(tmp_path), (520, 520), zoom=zoom)
            tmp_path.unlink(missing_ok=True)
            if after:
                self._after_photo = after
                self.after_label.config(image=after, text="")
        except Exception as exc:
            self.after_label.config(image="", text=str(exc))

    def _set_busy(self, busy: bool) -> None:
        self._busy = busy
        self.process_btn.config(state=tk.DISABLED if busy else tk.NORMAL)

    def _on_progress(self, current: int, total: int, message: str) -> None:
        self.after(0, lambda: self._update_progress(current, total, message))

    def _update_progress(self, current: int, total: int, message: str) -> None:
        self.progress["maximum"] = max(total, 1)
        self.progress["value"] = current
        self.status_label.config(text=message)

    def _process_all(self) -> None:
        if self._busy:
            return
        if not self.input_paths:
            messagebox.showerror("Error", "Please load at least one image.")
            return

        output_dir = make_timestamped_output_dir("Green2Alpha_Output")
        self._set_busy(True)
        self.progress["value"] = 0

        paths = list(self.input_paths)

        def work() -> None:
            process_batch(
                paths,
                output_dir,
                self.sensitivity.get(),
                self.spill.get(),
                self.feather.get(),
                self.remove_shadows.get(),
                on_progress=self._on_progress,
            )

            def done() -> None:
                self._set_busy(False)
                self.status_label.config(text=f"Done! Output: {output_dir}")
                messagebox.showinfo("Green2Alpha Complete", f"Saved {len(paths)} PNGs to:\n{output_dir}")

            self.after(0, done)

        run_in_thread(self, work)
