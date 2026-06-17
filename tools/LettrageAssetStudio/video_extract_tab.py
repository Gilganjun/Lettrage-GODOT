"""Tab 1: MP4 to frame extraction."""

from __future__ import annotations

import tkinter as tk
from collections.abc import Callable
from pathlib import Path
from tkinter import filedialog, messagebox, ttk

from services.frame_extractor import extract_frames
from services.preset_pipeline import run_preset_pipeline
from theme import BG, PANEL, TEXT_DIM, Theme
from utils import load_preview_image, run_in_thread


class VideoExtractTab(ttk.Frame):
    def __init__(
        self,
        parent: tk.Misc,
        theme: Theme,
        on_preset_complete: Callable[[Path], None] | None = None,
    ) -> None:
        super().__init__(parent, style="TFrame")
        self.theme = theme
        self.on_preset_complete = on_preset_complete
        self.file_path = tk.StringVar()
        self.skip_value = tk.IntVar(value=1)
        self.preset_shrink = tk.DoubleVar(value=33.0)
        self._preview_photo: tk.PhotoImage | None = None
        self._busy = False
        self._build_ui()

    def _build_ui(self) -> None:
        self.columnconfigure(0, weight=0, minsize=420)
        self.columnconfigure(1, weight=1)
        self.rowconfigure(0, weight=1)

        left = self.theme.panel(self, padx=16, pady=16)
        left.grid(row=0, column=0, sticky="nsew", padx=(12, 6), pady=12)
        left.columnconfigure(0, weight=1)
        left.rowconfigure(0, weight=1)
        left.rowconfigure(1, weight=0)

        controls = tk.Frame(left, bg=PANEL)
        controls.grid(row=0, column=0, sticky="nsew")

        footer = tk.Frame(left, bg=PANEL)
        footer.grid(row=1, column=0, sticky="ew", pady=(12, 0))

        self.theme.heading(controls, "Video Extract").pack(anchor="w", pady=(0, 4))
        self.theme.label(
            controls,
            "Convert Kling MP4 files into PNG frames.",
            bg=PANEL,
            fg=TEXT_DIM,
        ).pack(anchor="w", pady=(0, 12))

        self.theme.button(controls, "Select MP4 File", self._select_file).pack(anchor="w", pady=4)
        ttk.Entry(controls, textvariable=self.file_path, width=42).pack(anchor="w", pady=8, fill=tk.X)

        skip_row = tk.Frame(controls, bg=PANEL)
        skip_row.pack(anchor="w", pady=4)
        self.theme.label(skip_row, "Extract every Nth frame:", bg=PANEL).pack(side=tk.LEFT)
        ttk.Spinbox(skip_row, from_=1, to=120, textvariable=self.skip_value, width=6).pack(side=tk.LEFT, padx=8)

        preset_box = self.theme.panel(controls, padx=10, pady=10)
        preset_box.pack(anchor="w", fill=tk.X, pady=(16, 0))
        self.theme.heading(preset_box, "Quick Preset").pack(anchor="w", pady=(0, 4))
        self.theme.label(
            preset_box,
            "Extract → Green2Alpha → Shrink, then open Animation Tester.",
            bg=PANEL,
            fg=TEXT_DIM,
            wraplength=320,
        ).pack(anchor="w", pady=(0, 8))

        shrink_row = tk.Frame(preset_box, bg=PANEL)
        shrink_row.pack(anchor="w", pady=4)
        self.theme.label(shrink_row, "Preset shrink:", bg=PANEL).pack(side=tk.LEFT)
        ttk.Spinbox(shrink_row, from_=5, to=100, increment=1, textvariable=self.preset_shrink, width=6).pack(
            side=tk.LEFT, padx=8
        )
        self.theme.label(shrink_row, "%", bg=PANEL).pack(side=tk.LEFT)

        self.extract_btn = self.theme.button(footer, "Start Extraction", self._start_extraction)
        self.extract_btn.pack(anchor="w", fill=tk.X, pady=(0, 6))

        self.preset_btn = self.theme.button(footer, "Run Preset Pipeline", self._run_preset, accent=True)
        self.preset_btn.pack(anchor="w", fill=tk.X)

        self.progress = ttk.Progressbar(footer, orient="horizontal", mode="determinate")
        self.progress.pack(anchor="w", fill=tk.X, pady=(8, 4))

        self.status_label = self.theme.label(
            footer,
            "Select a video, then extract manually or run the preset pipeline.",
            bg=PANEL,
            fg=TEXT_DIM,
            wraplength=360,
            justify=tk.LEFT,
        )
        self.status_label.pack(anchor="w")

        right = self.theme.panel(self, padx=16, pady=16)
        right.grid(row=0, column=1, sticky="nsew", padx=(6, 12), pady=12)
        right.rowconfigure(1, weight=1)
        right.columnconfigure(0, weight=1)

        self.theme.heading(right, "First Frame Preview").pack(anchor="w", pady=(0, 8))
        self.preview_label = tk.Label(right, bg=PANEL, fg=TEXT_DIM, text="No preview yet")
        self.preview_label.pack(expand=True, fill=tk.BOTH)

    def _select_file(self) -> None:
        path = filedialog.askopenfilename(filetypes=[("MP4 files", "*.mp4"), ("Video files", "*.mp4 *.mov *.avi")])
        if path:
            self.file_path.set(path)
            self.status_label.config(text="Ready to extract or run preset.")

    def _validate_video(self) -> Path | None:
        path = self.file_path.get().strip()
        skip = self.skip_value.get()
        if not path or not Path(path).is_file():
            messagebox.showerror("Error", "Please select a valid MP4 file.")
            return None
        if skip < 1:
            messagebox.showerror("Error", "Skip value must be 1 or greater.")
            return None
        return Path(path)

    def _set_busy(self, busy: bool) -> None:
        self._busy = busy
        state = tk.DISABLED if busy else tk.NORMAL
        self.extract_btn.config(state=state)
        self.preset_btn.config(state=state)

    def _on_progress(self, current: int, total: int, message: str) -> None:
        self.after(0, lambda: self._update_progress(current, total, message))

    def _update_progress(self, current: int, total: int, message: str) -> None:
        self.progress["maximum"] = max(total, 1)
        self.progress["value"] = current
        self.status_label.config(text=message)

    def _show_preview(self, frame_path: Path | None) -> None:
        if not frame_path:
            return
        photo = load_preview_image(str(frame_path), (700, 700))
        if photo:
            self._preview_photo = photo
            self.preview_label.config(image=photo, text="")

    def _start_extraction(self) -> None:
        if self._busy:
            return
        video_path = self._validate_video()
        if not video_path:
            return

        skip = self.skip_value.get()
        self._set_busy(True)
        self.progress["value"] = 0
        self.status_label.config(text="Extracting frames...")

        def work() -> None:
            result = extract_frames(video_path, skip, on_progress=self._on_progress)

            def done() -> None:
                self._set_busy(False)
                self.status_label.config(
                    text=f"Done! {result.saved_count} frames saved to:\n{result.output_folder}"
                )
                self._show_preview(result.first_frame_path)
                messagebox.showinfo(
                    "Extraction Finished",
                    f"Saved {result.saved_count} frames to:\n{result.output_folder}",
                )

            self.after(0, done)

        run_in_thread(self, work)

    def _run_preset(self) -> None:
        if self._busy:
            return
        video_path = self._validate_video()
        if not video_path:
            return

        skip = self.skip_value.get()
        shrink = self.preset_shrink.get()
        if shrink <= 0 or shrink > 400:
            messagebox.showerror("Error", "Preset shrink must be between 1 and 400%.")
            return

        self._set_busy(True)
        self.progress["value"] = 0
        self.status_label.config(text="Running preset pipeline…")

        def work() -> None:
            result = run_preset_pipeline(
                video_path,
                skip=skip,
                shrink_percent=shrink,
                on_progress=self._on_progress,
            )

            def done() -> None:
                self._set_busy(False)
                self.status_label.config(
                    text=f"Preset done! {result.frame_count} frames ready in:\n{result.final_dir}"
                )
                self._show_preview(result.first_frame_path)
                messagebox.showinfo(
                    "Preset Pipeline Complete",
                    f"Processed {result.frame_count} frames.\n\n"
                    f"Final output:\n{result.final_dir}\n\n"
                    "Opening Animation Tester…",
                )
                if self.on_preset_complete:
                    self.on_preset_complete(result.final_dir)

            self.after(0, done)

        run_in_thread(self, work)
