"""Main application window for Lettrage Asset Studio."""

from __future__ import annotations

import tkinter as tk
from pathlib import Path
from tkinter import ttk

from animation_tester_tab import AnimationTesterTab
from auto_font_cutter_tab import AutoFontCutterTab
from export_tab import ExportTab
from green2alpha_tab import Green2AlphaTab
from paths import load_lettrage_project
from resize_tab import ResizeTab
from theme import BG, Theme
from video_extract_tab import VideoExtractTab


class MainWindow:
    APP_TITLE = "LETTRAGE ASSET STUDIO v1.0"
    TAB_ANIMATION_TESTER = 4
    TAB_EXPORT = 5

    def __init__(self, root: tk.Tk) -> None:
        self.root = root
        self.root.title(self.APP_TITLE)
        self.root.geometry("1440x920")
        self.theme = Theme(root)
        self.notebook: ttk.Notebook | None = None
        self.animation_tester_tab: AnimationTesterTab | None = None
        self.export_tab: ExportTab | None = None
        self._build_ui()

    def _build_ui(self) -> None:
        header = tk.Frame(self.root, bg=BG, height=56)
        header.pack(fill=tk.X, padx=12, pady=(12, 0))
        header.pack_propagate(False)

        tk.Label(
            header,
            text=self.APP_TITLE,
            bg=BG,
            fg="#00E5CC",
            font=self.theme.title_font,
        ).pack(side=tk.LEFT)

        project = load_lettrage_project()
        project_text = project.name if project else "No Lettrage project linked"
        self.project_label = tk.Label(
            header,
            text=f"Export target: {project_text}",
            bg=BG,
            fg="#888888",
            font=self.theme.body_font,
        )
        self.project_label.pack(side=tk.RIGHT)

        self.notebook = ttk.Notebook(self.root)
        self.notebook.pack(fill=tk.BOTH, expand=True, padx=12, pady=12)

        self.export_tab = ExportTab(self.notebook, self.theme, on_project_changed=self._refresh_project_label)
        self.animation_tester_tab = AnimationTesterTab(
            self.notebook,
            self.theme,
            on_save_complete=self._on_animation_save_complete,
        )

        tabs: list[tuple[str, ttk.Frame]] = [
            ("Video Extract", VideoExtractTab(self.notebook, self.theme, on_preset_complete=self._on_preset_complete)),
            ("Green2Alpha", Green2AlphaTab(self.notebook, self.theme)),
            ("Resize", ResizeTab(self.notebook, self.theme)),
            ("Auto-Font Cutter", AutoFontCutterTab(self.notebook, self.theme)),
            ("Animation Tester", self.animation_tester_tab),
            ("Export", self.export_tab),
        ]
        for title, tab in tabs:
            self.notebook.add(tab, text=title)

        footer = tk.Frame(self.root, bg=BG, height=28)
        footer.pack(fill=tk.X, padx=12, pady=(0, 8))
        tk.Label(
            footer,
            text="Separate desktop tool — stored in Lettrage repo, not part of the Godot game",
            bg=BG,
            fg="#666666",
            font=self.theme.mono_font,
        ).pack(side=tk.LEFT)

    def _on_preset_complete(self, final_folder: Path) -> None:
        if self.notebook and self.animation_tester_tab:
            self.notebook.select(self.TAB_ANIMATION_TESTER)
            self.animation_tester_tab.load_from_folder(final_folder)

    def _on_animation_save_complete(self, paths: list[Path], output_folder: Path) -> None:
        if self.notebook and self.export_tab:
            self.export_tab.load_frames(paths, output_folder)
            self.notebook.select(self.TAB_EXPORT)

    def _refresh_project_label(self) -> None:
        project = load_lettrage_project()
        text = project.name if project else "No Lettrage project linked"
        self.project_label.config(text=f"Export target: {text}")
