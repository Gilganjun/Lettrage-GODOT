"""Tab: Auto-Font Cutter — extract A–Z from alphabet grid sheets."""

from __future__ import annotations

import tkinter as tk
from pathlib import Path
from tkinter import filedialog, messagebox, ttk

import json

from PIL import Image, ImageTk

from paths import get_font_export_dir, get_fonts_dir, load_lettrage_project
from letter_crop_editor import LetterCropEditor
from services.font_cutter import FontCutResult, LETTERS, apply_manual_to_letter_result, process_font_sheet
from theme import BG, ERROR, PANEL, SUCCESS, TEXT_DIM, Theme
from utils import load_preview_image, run_in_thread


class AutoFontCutterTab(ttk.Frame):
    EXPORT_SIZES = [256, 384, 512, 1024]
    GRID_COLS = 7
    GRID_ROWS = 4

    def __init__(self, parent: tk.Misc, theme: Theme) -> None:
        super().__init__(parent, style="TFrame")
        self.theme = theme
        self.source_path: Path | None = None
        self._cut_result: FontCutResult | None = None
        self._preview_photos: list[tk.PhotoImage] = []
        self._sheet_photo: tk.PhotoImage | None = None
        self._busy = False

        self.font_set_name = tk.StringVar(value="Cyberpunk_Neon_02")
        self.project_root = load_lettrage_project()
        self.bg_mode = tk.StringVar(value="auto")
        self.use_alphabet_preset = tk.BooleanVar(value=True)
        self.cols = tk.IntVar(value=7)
        self.rows = tk.IntVar(value=4)
        self.export_size = tk.StringVar(value="512")
        self.padding = tk.IntVar(value=32)
        self.alpha_threshold = tk.IntVar(value=16)
        self.green_tolerance = tk.IntVar(value=60)
        self.remove_strays = tk.BooleanVar(value=True)
        self.min_island = tk.IntVar(value=20)
        self.center_out_detect = tk.BooleanVar(value=True)
        self.show_warnings = tk.BooleanVar(value=True)
        self.save_metadata = tk.BooleanVar(value=True)

        self._build_ui()
        self._on_preset_toggle()
        self.use_alphabet_preset.trace_add("write", lambda *_: self._on_preset_toggle())

    def _build_ui(self) -> None:
        self.columnconfigure(0, weight=0, minsize=340)
        self.columnconfigure(1, weight=1)
        self.rowconfigure(0, weight=1)

        # --- Left panel (scrollable controls + pinned footer) ---
        left = self.theme.panel(self, padx=12, pady=12)
        left.grid(row=0, column=0, sticky="nsew", padx=(12, 6), pady=12)
        left.columnconfigure(0, weight=1)
        left.rowconfigure(0, weight=1)
        left.rowconfigure(1, weight=0)

        scroll_wrap = tk.Frame(left, bg=PANEL)
        scroll_wrap.grid(row=0, column=0, sticky="nsew")
        scroll_wrap.columnconfigure(0, weight=1)
        scroll_wrap.rowconfigure(0, weight=1)

        scroll_canvas = tk.Canvas(scroll_wrap, bg=PANEL, highlightthickness=0, width=300)
        scroll_bar = ttk.Scrollbar(scroll_wrap, orient=tk.VERTICAL, command=scroll_canvas.yview)
        controls = tk.Frame(scroll_canvas, bg=PANEL)
        controls.bind("<Configure>", lambda e: scroll_canvas.configure(scrollregion=scroll_canvas.bbox("all")))
        scroll_canvas.create_window((0, 0), window=controls, anchor="nw", width=300)
        scroll_canvas.configure(yscrollcommand=scroll_bar.set)
        scroll_canvas.grid(row=0, column=0, sticky="nsew")
        scroll_bar.grid(row=0, column=1, sticky="ns")

        footer = tk.Frame(left, bg=PANEL)
        footer.grid(row=1, column=0, sticky="ew", pady=(10, 0))

        self.theme.heading(controls, "Auto-Font Cutter").pack(anchor="w", pady=(0, 4))
        self.theme.label(
            controls,
            "Import an A–Z grid sheet and export 26 transparent letter PNGs.",
            bg=PANEL,
            fg=TEXT_DIM,
            wraplength=280,
        ).pack(anchor="w", pady=(0, 8))

        self.theme.button(controls, "Import Font Sheet", self._import_sheet).pack(anchor="w", pady=4)
        self.source_label = self.theme.label(controls, "No sheet loaded", bg=PANEL, fg=TEXT_DIM, wraplength=280)
        self.source_label.pack(anchor="w", pady=(0, 8))

        self._section(controls, "Font Name")
        ttk.Entry(controls, textvariable=self.font_set_name, width=28).pack(anchor="w", pady=(0, 2))
        self.font_set_name.trace_add("write", lambda *_: self._update_dest_preview())
        self.dest_label = self.theme.label(
            controls, self._dest_label_text(), bg=PANEL, fg=TEXT_DIM, wraplength=280, justify=tk.LEFT
        )
        self.dest_label.pack(anchor="w", pady=(0, 6))

        self._section(controls, "Background Mode")
        for text, value in [("Auto Detect", "auto"), ("Transparent", "transparent"), ("Green Screen", "green")]:
            ttk.Radiobutton(controls, text=text, value=value, variable=self.bg_mode).pack(anchor="w")

        ttk.Checkbutton(controls, text="Alphabet A–Z 7×4", variable=self.use_alphabet_preset).pack(anchor="w", pady=(6, 2))

        grid_row = tk.Frame(controls, bg=PANEL)
        grid_row.pack(anchor="w", pady=2)
        self.theme.label(grid_row, "Cols:", bg=PANEL).pack(side=tk.LEFT)
        self.cols_spin = ttk.Spinbox(grid_row, from_=1, to=16, textvariable=self.cols, width=4)
        self.cols_spin.pack(side=tk.LEFT, padx=(4, 10))
        self.theme.label(grid_row, "Rows:", bg=PANEL).pack(side=tk.LEFT)
        self.rows_spin = ttk.Spinbox(grid_row, from_=1, to=16, textvariable=self.rows, width=4)
        self.rows_spin.pack(side=tk.LEFT, padx=4)

        self._section(controls, "Export Size")
        ttk.Combobox(
            controls,
            textvariable=self.export_size,
            values=[str(s) for s in self.EXPORT_SIZES],
            width=8,
            state="readonly",
        ).pack(anchor="w")

        self._spin_row(controls, "Padding", self.padding, 0, 128)
        self._spin_row(controls, "Alpha Threshold", self.alpha_threshold, 1, 128)
        self._spin_row(controls, "Green Tolerance", self.green_tolerance, 10, 120)
        self._spin_row(controls, "Min Island", self.min_island, 1, 500)

        ttk.Checkbutton(controls, text="Remove stray pixels", variable=self.remove_strays).pack(anchor="w")
        ttk.Checkbutton(
            controls,
            text="Center-out detect (recommended)",
            variable=self.center_out_detect,
        ).pack(anchor="w")
        ttk.Checkbutton(controls, text="Show warnings", variable=self.show_warnings).pack(anchor="w")
        ttk.Checkbutton(controls, text="Save metadata.json", variable=self.save_metadata).pack(anchor="w", pady=(0, 8))

        self.preview_btn = self.theme.button(footer, "Preview Cuts", self._preview_cuts)
        self.preview_btn.pack(fill=tk.X, pady=(0, 6))
        self.export_btn = self.theme.button(footer, "Export Font Set", self._export_font_set, accent=True)
        self.export_btn.pack(fill=tk.X)
        self.progress = ttk.Progressbar(footer, orient="horizontal", mode="determinate")
        self.progress.pack(fill=tk.X, pady=(8, 4))
        self.status_label = self.theme.label(
            footer, "Import a font sheet, then Preview or Export.", bg=PANEL, fg=TEXT_DIM, wraplength=300
        )
        self.status_label.pack(anchor="w")

        # --- Right panel (sheet preview + letter grid) ---
        right = self.theme.panel(self, padx=16, pady=16)
        right.grid(row=0, column=1, sticky="nsew", padx=(6, 12), pady=12)
        right.columnconfigure(0, weight=1)
        right.rowconfigure(2, weight=1)

        self.theme.heading(right, "Source Sheet").pack(anchor="w", pady=(0, 4))
        self.sheet_label = tk.Label(right, bg="#111111", fg=TEXT_DIM, text="No sheet preview", height=12)
        self.sheet_label.pack(fill=tk.X, pady=(0, 12))

        header_row = tk.Frame(right, bg=PANEL)
        header_row.pack(fill=tk.X, pady=(0, 6))
        self.theme.heading(header_row, "Letter Cuts").pack(side=tk.LEFT)
        self.summary_label = self.theme.label(header_row, "—", bg=PANEL, fg=TEXT_DIM)
        self.summary_label.pack(side=tk.RIGHT)
        self.theme.label(
            right,
            "Scroll to see all letters · Click a letter to open the crop editor",
            bg=PANEL,
            fg=TEXT_DIM,
        ).pack(anchor="w", pady=(0, 4))

        grid_outer = tk.Frame(right, bg=PANEL)
        grid_outer.pack(fill=tk.BOTH, expand=True)
        grid_outer.columnconfigure(0, weight=1)
        grid_outer.rowconfigure(0, weight=1)

        self.preview_canvas = tk.Canvas(grid_outer, bg="#111111", highlightthickness=0)
        preview_scroll_y = ttk.Scrollbar(grid_outer, orient=tk.VERTICAL, command=self.preview_canvas.yview)
        preview_scroll_x = ttk.Scrollbar(grid_outer, orient=tk.HORIZONTAL, command=self.preview_canvas.xview)
        self.preview_canvas.configure(yscrollcommand=preview_scroll_y.set, xscrollcommand=preview_scroll_x.set)
        self.preview_canvas.grid(row=0, column=0, sticky="nsew")
        preview_scroll_y.grid(row=0, column=1, sticky="ns")
        preview_scroll_x.grid(row=1, column=0, sticky="ew")
        self.grid_frame = tk.Frame(self.preview_canvas, bg="#111111")
        self._canvas_window = self.preview_canvas.create_window((0, 0), window=self.grid_frame, anchor="nw")
        self.preview_canvas.bind("<Configure>", self._on_preview_canvas_resize)
        self.grid_frame.bind("<Configure>", self._on_grid_configure)
        self.preview_canvas.bind("<Enter>", self._bind_preview_wheel)
        self.preview_canvas.bind("<Leave>", self._unbind_preview_wheel)

        self._build_placeholder_grid()

    def _dest_label_text(self) -> str:
        name = self.font_set_name.get().strip() or "<FontName>"
        if self.project_root:
            try:
                dest = get_fonts_dir(self.project_root) / name
                return f"Saves to:\n{dest}"
            except ValueError:
                pass
        return "Saves to: assets/fonts/<FontName>/"

    def _update_dest_preview(self) -> None:
        self.dest_label.config(text=self._dest_label_text())

    def _section(self, parent: tk.Misc, text: str) -> None:
        self.theme.label(parent, text, bg=PANEL, fg=TEXT_DIM).pack(anchor="w", pady=(6, 2))

    def _spin_row(self, parent: tk.Misc, label: str, variable: tk.IntVar, from_: int, to: int) -> None:
        row = tk.Frame(parent, bg=PANEL)
        row.pack(anchor="w", pady=2)
        self.theme.label(row, label + ":", bg=PANEL).pack(side=tk.LEFT)
        ttk.Spinbox(row, from_=from_, to=to, textvariable=variable, width=6).pack(side=tk.LEFT, padx=8)

    def _on_preset_toggle(self) -> None:
        if self.use_alphabet_preset.get():
            self.cols.set(self.GRID_COLS)
            self.rows.set(self.GRID_ROWS)
            self.cols_spin.config(state=tk.DISABLED)
            self.rows_spin.config(state=tk.DISABLED)
        else:
            self.cols_spin.config(state=tk.NORMAL)
            self.rows_spin.config(state=tk.NORMAL)

    def _bind_preview_wheel(self, _event: tk.Event) -> None:
        self.preview_canvas.bind_all("<MouseWheel>", self._on_preview_wheel)

    def _unbind_preview_wheel(self, _event: tk.Event) -> None:
        self.preview_canvas.unbind_all("<MouseWheel>")

    def _on_preview_wheel(self, event: tk.Event) -> None:
        if event.delta:
            self.preview_canvas.yview_scroll(int(-event.delta / 120), "units")

    def _on_preview_canvas_resize(self, event: tk.Event) -> None:
        self.preview_canvas.itemconfig(self._canvas_window, width=event.width)
        if self._cut_result:
            self._render_preview_grid(self._cut_result)

    def _on_grid_configure(self, _event: tk.Event) -> None:
        self.preview_canvas.configure(scrollregion=self.preview_canvas.bbox("all"))

    def _cell_size(self) -> int:
        """Thumbnail size — fixed so all 26 letters scroll cleanly."""
        return 120

    def _open_letter_editor(self, letter_result) -> None:
        if letter_result.edit_source is None:
            messagebox.showinfo("Edit Letter", "No editable source for this letter.")
            return
        LetterCropEditor(
            self,
            self.theme,
            letter_result,
            int(self.export_size.get()),
            self._on_letter_edited,
        )

    def _on_letter_edited(self, _letter_result) -> None:
        if self._cut_result:
            self._render_preview_grid(self._cut_result)
            ok = sum(1 for lr in self._cut_result.letters if lr.status == "ok")
            warn = sum(1 for lr in self._cut_result.letters if lr.status == "warning")
            miss = sum(1 for lr in self._cut_result.letters if lr.status == "missing")
            self.summary_label.config(text=f"OK: {ok}  |  Warn: {warn}  |  Missing: {miss}")
            self.status_label.config(text="Manual crop applied — Export when ready.")

    def _export_font_set(self) -> None:
        if self._cut_result:
            self._save_existing_cut()
        else:
            self._run_cut(save=True)

    def _save_existing_cut(self) -> None:
        if not self._validate() or self._cut_result is None:
            return
        if not self.project_root:
            messagebox.showerror("Error", "Lettrage project not found.")
            return
        font_name = self.font_set_name.get().strip() or "FontSet"
        output_dir = get_font_export_dir(font_name, self.project_root)
        if any(output_dir.iterdir()):
            if not messagebox.askyesno(
                "Folder Exists",
                f"{output_dir.name} already exists in assets/fonts/.\n\nOverwrite/add files?",
            ):
                return
        from services.font_cutter import letter_export_filename

        output_size = int(self.export_size.get())
        output_dir.mkdir(parents=True, exist_ok=True)
        for lr in self._cut_result.letters:
            if lr.manual_adjust:
                apply_manual_to_letter_result(lr, output_size)
            lr.image.save(output_dir / letter_export_filename(font_name, lr.letter), "PNG")
        if self.save_metadata.get():
            (output_dir / "metadata.json").write_text(
                json.dumps(self._cut_result.metadata, indent=2),
                encoding="utf-8",
            )
        self.status_label.config(text=f"Exported to {output_dir}")
        messagebox.showinfo("Export Complete", f"Exported 26 letters to:\n{output_dir}")

    def _build_placeholder_grid(self) -> None:
        for child in self.grid_frame.winfo_children():
            child.destroy()
        size = self._cell_size()
        cols = self.cols.get()
        rows = self.rows.get()
        for r in range(rows):
            self.grid_frame.rowconfigure(r, weight=1)
            for c in range(cols):
                self.grid_frame.columnconfigure(c, weight=1)
                cell = tk.Frame(self.grid_frame, bg="#222222", width=size, height=size + 36)
                cell.grid(row=r, column=c, padx=5, pady=5, sticky="nsew")
                cell.grid_propagate(False)
                tk.Label(cell, text="?", bg="#222222", fg=TEXT_DIM, font=self.theme.heading_font).pack(
                    expand=True
                )

    def _show_sheet_preview(self, path: Path | None = None, processed: Image.Image | None = None) -> None:
        if processed is not None:
            img = processed
        elif path and path.is_file():
            img = Image.open(path).convert("RGBA")
        else:
            self.sheet_label.config(image="", text="No sheet preview")
            return

        max_w, max_h = 900, 220
        preview = img.copy()
        preview.thumbnail((max_w, max_h), Image.Resampling.LANCZOS)
        self._sheet_photo = ImageTk.PhotoImage(preview)
        self.sheet_label.config(image=self._sheet_photo, text="", height=0)

    def _import_sheet(self) -> None:
        path = filedialog.askopenfilename(
            filetypes=[("Images", "*.png *.jpg *.jpeg *.webp *.bmp"), ("All files", "*.*")]
        )
        if not path:
            return
        self.source_path = Path(path)
        self._cut_result = None
        self.source_label.config(text=self.source_path.name)
        self.status_label.config(text="Sheet loaded — click Preview Cuts.")
        self._show_sheet_preview(path=self.source_path)
        self._build_placeholder_grid()
        self.summary_label.config(text="—")

    def _params(self) -> dict:
        return {
            "font_set_name": self.font_set_name.get().strip() or "FontSet",
            "cols": self.cols.get(),
            "rows": self.rows.get(),
            "output_size": int(self.export_size.get()),
            "padding_px": self.padding.get(),
            "alpha_threshold": self.alpha_threshold.get(),
            "green_delta": self.green_tolerance.get(),
            "background_mode": self.bg_mode.get(),
            "remove_strays": self.remove_strays.get(),
            "min_island_size": self.min_island.get(),
            "detection_mode": "center_out" if self.center_out_detect.get() else "bbox",
        }

    def _validate(self) -> bool:
        if not self.source_path or not self.source_path.is_file():
            messagebox.showerror("Error", "Please import a font sheet first.")
            return False
        if self.cols.get() < 1 or self.rows.get() < 1:
            messagebox.showerror("Error", "Grid columns and rows must be at least 1.")
            return False
        return True

    def _set_busy(self, busy: bool) -> None:
        self._busy = busy
        state = tk.DISABLED if busy else tk.NORMAL
        self.preview_btn.config(state=state)
        self.export_btn.config(state=state)

    def _on_progress(self, current: int, total: int, message: str) -> None:
        self.after(0, lambda: self._update_progress(current, total, message))

    def _update_progress(self, current: int, total: int, message: str) -> None:
        self.progress["maximum"] = max(total, 1)
        self.progress["value"] = current
        self.status_label.config(text=message)

    def _run_cut(self, save: bool) -> None:
        if self._busy or not self._validate():
            return

        params = self._params()
        output_dir = None
        if save:
            if not self.project_root:
                messagebox.showerror(
                    "Error",
                    "Lettrage project not found.\n\n"
                    "The tool must be run from the Lettrage Godot project folder.",
                )
                return
            font_name = params["font_set_name"]
            if not font_name.strip():
                messagebox.showerror("Error", "Please enter a font name.")
                return
            output_dir = get_font_export_dir(font_name, self.project_root)
            if any(output_dir.iterdir()):
                if not messagebox.askyesno(
                    "Folder Exists",
                    f"{output_dir.name} already exists in assets/fonts/.\n\nOverwrite/add files?",
                ):
                    return

        self._set_busy(True)
        self.progress["value"] = 0
        source = self.source_path

        def work() -> None:
            result = process_font_sheet(
                source,
                output_dir=output_dir,
                save_files=save,
                save_metadata=self.save_metadata.get(),
                on_progress=self._on_progress,
                **params,
            )

            def done() -> None:
                self._set_busy(False)
                self._cut_result = result
                self._show_sheet_preview(processed=result.processed_sheet)
                self._render_preview_grid(result)
                ok = sum(1 for lr in result.letters if lr.status == "ok")
                warn = sum(1 for lr in result.letters if lr.status == "warning")
                miss = sum(1 for lr in result.letters if lr.status == "missing")
                self.summary_label.config(text=f"OK: {ok}  |  Warn: {warn}  |  Missing: {miss}")
                if save and result.output_dir:
                    self.status_label.config(text=f"Exported to {result.output_dir}")
                    messagebox.showinfo("Export Complete", f"Exported 26 letters to:\n{result.output_dir}")
                else:
                    self.status_label.config(text="Preview ready — adjust settings or Export.")

            self.after(0, done)

        run_in_thread(self, work)

    def _preview_cuts(self) -> None:
        self._run_cut(save=False)

    def _render_preview_grid(self, result: FontCutResult) -> None:
        for child in self.grid_frame.winfo_children():
            child.destroy()
        self._preview_photos.clear()

        cols = self.cols.get()
        rows = self.rows.get()
        cell_size = self._cell_size()
        thumb_size = cell_size - 16
        letter_map = {lr.letter: lr for lr in result.letters}

        idx = 0
        for r in range(rows):
            self.grid_frame.rowconfigure(r, weight=1)
            for c in range(cols):
                self.grid_frame.columnconfigure(c, weight=1)
                cell = tk.Frame(self.grid_frame, bg="#222222", width=cell_size, height=cell_size + 40)
                cell.grid(row=r, column=c, padx=5, pady=5, sticky="nsew")
                cell.grid_propagate(False)

                if idx < len(LETTERS):
                    letter = LETTERS[idx]
                    lr = letter_map[letter]

                    img_frame = tk.Frame(cell, bg="#1a1a1a", width=thumb_size, height=thumb_size, cursor="hand2")
                    img_frame.pack(pady=(6, 2))
                    img_frame.pack_propagate(False)
                    img_frame.bind("<Button-1>", lambda _e, lr=lr: self._open_letter_editor(lr))

                    thumb = _pil_to_photo(lr.image, (thumb_size, thumb_size))
                    if thumb:
                        self._preview_photos.append(thumb)
                        img_label = tk.Label(img_frame, image=thumb, bg="#1a1a1a", cursor="hand2")
                        img_label.pack(expand=True)
                        img_label.bind("<Button-1>", lambda _e, lr=lr: self._open_letter_editor(lr))

                    status_color = SUCCESS if lr.status == "ok" else ERROR if lr.status == "missing" else "#FFAA00"
                    status_text = f"{letter} · {lr.status.upper()}"
                    if lr.manual_adjust:
                        status_text += " · edited"
                    status_lbl = tk.Label(
                        cell,
                        text=status_text,
                        bg="#222222",
                        fg=status_color,
                        font=self.theme.body_font,
                        cursor="hand2",
                    )
                    status_lbl.pack()
                    status_lbl.bind("<Button-1>", lambda _e, lr=lr: self._open_letter_editor(lr))
                    cell.bind("<Button-1>", lambda _e, lr=lr: self._open_letter_editor(lr))

                    if self.show_warnings.get() and lr.warnings:
                        tk.Label(
                            cell,
                            text=lr.warnings[0][:24],
                            bg="#222222",
                            fg="#FFAA00",
                            font=self.theme.mono_font,
                            wraplength=cell_size - 8,
                        ).pack()
                    elif lr.notes:
                        tk.Label(
                            cell,
                            text=lr.notes[0][:24],
                            bg="#222222",
                            fg=TEXT_DIM,
                            font=self.theme.mono_font,
                            wraplength=cell_size - 8,
                        ).pack()
                    idx += 1
                else:
                    tk.Label(cell, text="—", bg="#222222", fg=TEXT_DIM, font=self.theme.heading_font).pack(
                        expand=True
                    )

        self.grid_frame.update_idletasks()
        self.preview_canvas.configure(scrollregion=self.preview_canvas.bbox("all"))


def _pil_to_photo(img: Image.Image, max_size: tuple[int, int]) -> ImageTk.PhotoImage | None:
    preview = img.copy()
    preview.thumbnail(max_size, Image.Resampling.LANCZOS)
    return ImageTk.PhotoImage(preview)
