"""Tab 5: Export frames into a linked Lettrage Godot project."""

from __future__ import annotations

import tkinter as tk
from collections.abc import Callable
from pathlib import Path
from tkinter import filedialog, messagebox, ttk

from paths import get_characters_dir, load_lettrage_project, save_lettrage_project
from services.exporter import ANIMATION_TYPES, export_frames
from theme import PANEL, TEXT_DIM, Theme
from utils import run_in_thread


class ExportTab(ttk.Frame):
    def __init__(
        self,
        parent: tk.Misc,
        theme: Theme,
        on_project_changed: Callable[[], None] | None = None,
    ) -> None:
        super().__init__(parent, style="TFrame")
        self.theme = theme
        self.on_project_changed = on_project_changed
        self.project_root = load_lettrage_project()
        self.source_paths: list[Path] = []

        self.character_name = tk.StringVar(value="Alien01")
        self.animation_type = tk.StringVar(value="Walk")
        self.custom_type = tk.StringVar(value="")
        self.sequential_rename = tk.BooleanVar(value=True)
        self.rename_prefix = tk.StringVar(value="walk")

        self._busy = False
        self._build_ui()
        self._update_dest_preview()

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
        controls.columnconfigure(0, weight=1)

        footer = tk.Frame(left, bg=PANEL)
        footer.grid(row=1, column=0, sticky="ew", pady=(12, 0))

        self.theme.heading(controls, "Export to Lettrage").pack(anchor="w", pady=(0, 4))
        self.theme.label(
            controls,
            "Export frames into Assets/Characters/ in your linked Godot project.",
            bg=PANEL,
            fg=TEXT_DIM,
            wraplength=380,
        ).pack(anchor="w", pady=(0, 8))

        proj_row = tk.Frame(controls, bg=PANEL)
        proj_row.pack(anchor="w", pady=2)
        self.theme.button(proj_row, "Link Project…", self._link_project).pack(side=tk.LEFT, padx=(0, 8))
        self.theme.button(proj_row, "Select Source…", self._select_folder).pack(side=tk.LEFT)

        self.project_label = self.theme.label(
            controls, self._project_label_text(), bg=PANEL, fg=TEXT_DIM, wraplength=380
        )
        self.project_label.pack(anchor="w", pady=(4, 2))

        self.source_label = self.theme.label(controls, "No source folder", bg=PANEL, fg=TEXT_DIM, wraplength=380)
        self.source_label.pack(anchor="w", pady=(0, 8))

        form = tk.Frame(controls, bg=PANEL)
        form.pack(anchor="w", fill=tk.X, pady=4)

        self.theme.label(form, "Character:", bg=PANEL).grid(row=0, column=0, sticky="w", pady=4)
        ttk.Entry(form, textvariable=self.character_name, width=28).grid(row=0, column=1, sticky="w", pady=4, padx=8)
        self.character_name.trace_add("write", lambda *_: self._update_dest_preview())

        self.theme.label(form, "Animation:", bg=PANEL).grid(row=1, column=0, sticky="w", pady=4)
        type_combo = ttk.Combobox(
            form, textvariable=self.animation_type, values=ANIMATION_TYPES, width=26, state="readonly"
        )
        type_combo.grid(row=1, column=1, sticky="w", pady=4, padx=8)
        type_combo.bind("<<ComboboxSelected>>", self._on_type_change)

        self.custom_type_label = self.theme.label(form, "Custom:", bg=PANEL)
        self.custom_entry = ttk.Entry(form, textvariable=self.custom_type, width=28)
        self.custom_type.trace_add("write", lambda *_: self._update_dest_preview())

        rename_row = tk.Frame(controls, bg=PANEL)
        rename_row.pack(anchor="w", fill=tk.X, pady=(4, 0))
        ttk.Checkbutton(
            rename_row,
            text="Sequential rename",
            variable=self.sequential_rename,
            command=self._update_dest_preview,
        ).pack(side=tk.LEFT)
        self.theme.label(rename_row, "Prefix:", bg=PANEL).pack(side=tk.LEFT, padx=(12, 4))
        ttk.Entry(rename_row, textvariable=self.rename_prefix, width=12).pack(side=tk.LEFT)
        self.rename_prefix.trace_add("write", lambda *_: self._update_dest_preview())

        self.export_btn = self.theme.button(footer, "Export", self._export, accent=True)
        self.export_btn.pack(anchor="w", fill=tk.X)

        self.progress = ttk.Progressbar(footer, orient="horizontal", mode="determinate")
        self.progress.pack(anchor="w", fill=tk.X, pady=(8, 4))

        self.status_label = self.theme.label(
            footer,
            "Configure options above, then click Export.",
            bg=PANEL,
            fg=TEXT_DIM,
            wraplength=380,
            justify=tk.LEFT,
        )
        self.status_label.pack(anchor="w")

        right = self.theme.panel(self, padx=16, pady=16)
        right.grid(row=0, column=1, sticky="nsew", padx=(6, 12), pady=12)
        right.rowconfigure(1, weight=1)
        right.columnconfigure(0, weight=1)

        self.theme.heading(right, "Export Preview").pack(anchor="w", pady=(0, 4))
        self.dest_label = self.theme.label(right, "", bg=PANEL, fg=TEXT_DIM, wraplength=600, justify=tk.LEFT)
        self.dest_label.pack(anchor="w", pady=(0, 8))

        self.preview_text = tk.Text(
            right,
            bg="#222222",
            fg="#E8E8E8",
            insertbackground="#00E5CC",
            relief=tk.FLAT,
            font=self.theme.mono_font,
            wrap=tk.NONE,
        )
        self.preview_text.pack(fill=tk.BOTH, expand=True)
        self._on_type_change()

    def _project_label_text(self) -> str:
        if self.project_root:
            return f"Linked: {self.project_root.name}"
        return "Not linked"

    def _link_project(self) -> None:
        folder = filedialog.askdirectory(title="Select Lettrage Godot Project Folder")
        if not folder:
            return
        try:
            save_lettrage_project(Path(folder))
        except ValueError as exc:
            messagebox.showerror("Invalid Project", str(exc))
            return
        self.project_root = load_lettrage_project()
        self.project_label.config(text=self._project_label_text())
        self._update_dest_preview()
        if self.on_project_changed:
            self.on_project_changed()

    def _resolved_animation_type(self) -> str:
        if self.animation_type.get() == "Custom":
            return self.custom_type.get().strip() or "Custom"
        return self.animation_type.get()

    def _on_type_change(self, _event: object | None = None) -> None:
        is_custom = self.animation_type.get() == "Custom"
        if is_custom:
            self.custom_type_label.grid(row=2, column=0, sticky="w", pady=4)
            self.custom_entry.grid(row=2, column=1, sticky="w", pady=4, padx=8)
        else:
            self.custom_type_label.grid_remove()
            self.custom_entry.grid_remove()
            prefix = self.animation_type.get().lower()
            self.rename_prefix.set(prefix)
        self._update_dest_preview()

    def _update_dest_preview(self) -> None:
        char_name = self.character_name.get().strip() or "<CharacterName>"
        anim = self._resolved_animation_type() or "<AnimationType>"

        if self.project_root:
            dest = get_characters_dir(self.project_root) / char_name / anim
            self.dest_label.config(text=f"Destination: {dest}")
        else:
            dest = None
            self.dest_label.config(text="Destination: (link a Lettrage project first)")

        self.preview_text.delete("1.0", tk.END)
        if not self.source_paths:
            self.preview_text.insert(tk.END, "No frames loaded.\n")
            return
        if not dest:
            return

        prefix = self.rename_prefix.get().strip() or anim.lower()
        lines = []
        for i, src in enumerate(self.source_paths[:20], start=1):
            if self.sequential_rename.get():
                name = f"{prefix}_{i:03d}.png"
            else:
                name = src.name
            lines.append(name)
        if len(self.source_paths) > 20:
            lines.append(f"… and {len(self.source_paths) - 20} more")
        self.preview_text.insert(tk.END, "\n".join(lines))

    def _select_folder(self) -> None:
        folder = filedialog.askdirectory()
        if not folder:
            return
        paths = sorted(Path(folder).glob("*.png"))
        if not paths:
            paths = sorted(Path(folder).glob("*.PNG"))
        self.load_frames(list(paths), Path(folder))

    def load_frames(self, paths: list[Path], source_folder: Path | None = None) -> None:
        """Load frames for export, preserving order from Animation Tester."""
        self.source_paths = list(paths)
        if source_folder:
            label = source_folder.name
        elif paths:
            label = paths[0].parent.name
        else:
            label = "—"
        self.source_label.config(text=f"{len(self.source_paths)} frames — {label}")
        self.status_label.config(text="Frames loaded — ready to export.")
        self._update_dest_preview()

    def _set_busy(self, busy: bool) -> None:
        self._busy = busy
        self.export_btn.config(state=tk.DISABLED if busy else tk.NORMAL)

    def _on_progress(self, current: int, total: int, message: str) -> None:
        self.after(0, lambda: self._update_progress(current, total, message))

    def _update_progress(self, current: int, total: int, message: str) -> None:
        self.progress["maximum"] = max(total, 1)
        self.progress["value"] = current
        self.status_label.config(text=message)

    def _export(self) -> None:
        if self._busy:
            return
        if not self.project_root:
            messagebox.showerror("Error", "Please link your Lettrage Godot project first.")
            return
        if not self.source_paths:
            messagebox.showerror("Error", "Please select a source folder with PNG frames.")
            return

        char_name = self.character_name.get().strip()
        anim_type = self._resolved_animation_type()
        if not char_name:
            messagebox.showerror("Error", "Character name is required.")
            return
        if not anim_type:
            messagebox.showerror("Error", "Animation type is required.")
            return

        paths = list(self.source_paths)
        self._set_busy(True)
        self.progress["value"] = 0
        self.status_label.config(text="Exporting…")

        def work() -> None:
            dest = export_frames(
                paths,
                char_name,
                anim_type,
                sequential_rename=self.sequential_rename.get(),
                prefix=self.rename_prefix.get(),
                project_root=self.project_root,
                on_progress=self._on_progress,
            )

            def done() -> None:
                self._set_busy(False)
                self.status_label.config(text=f"Exported to {dest}")
                messagebox.showinfo("Export Complete", f"Exported {len(paths)} frames to:\n{dest}")

            self.after(0, done)

        run_in_thread(self, work)
