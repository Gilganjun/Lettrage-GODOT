"""Cyberpunk dark theme shared across all tabs."""

from __future__ import annotations

import tkinter as tk
from tkinter import font as tkfont
from tkinter import ttk

# Color palette
BG = "#101010"
PANEL = "#1A1A1A"
PANEL_ALT = "#222222"
ACCENT = "#00E5CC"
ACCENT_DIM = "#00A896"
TEXT = "#E8E8E8"
TEXT_DIM = "#888888"
BORDER = "#333333"
ERROR = "#FF4466"
SUCCESS = "#00FF88"

MIN_WIDTH = 1400
MIN_HEIGHT = 900

FONT_FAMILY = "Orbitron"
FONT_FALLBACK = "Segoe UI"


class Theme:
    def __init__(self, root: tk.Tk) -> None:
        self.root = root
        self.title_font = self._pick_font(18, bold=True)
        self.heading_font = self._pick_font(12, bold=True)
        self.body_font = self._pick_font(10)
        self.mono_font = self._pick_font(9)
        self._apply()

    def _pick_font(self, size: int, bold: bool = False) -> tkfont.Font:
        weight = "bold" if bold else "normal"
        families = tkfont.families()
        family = FONT_FAMILY if FONT_FAMILY in families else FONT_FALLBACK
        return tkfont.Font(family=family, size=size, weight=weight)

    def _apply(self) -> None:
        self.root.configure(bg=BG)
        self.root.minsize(MIN_WIDTH, MIN_HEIGHT)

        style = ttk.Style(self.root)
        try:
            style.theme_use("clam")
        except tk.TclError:
            pass

        style.configure(".", background=BG, foreground=TEXT, font=self.body_font)
        style.configure("TFrame", background=BG)
        style.configure("Panel.TFrame", background=PANEL)
        style.configure("TLabel", background=BG, foreground=TEXT, font=self.body_font)
        style.configure("Panel.TLabel", background=PANEL, foreground=TEXT, font=self.body_font)
        style.configure("Dim.TLabel", background=BG, foreground=TEXT_DIM, font=self.body_font)
        style.configure("Title.TLabel", background=BG, foreground=ACCENT, font=self.title_font)
        style.configure("Heading.TLabel", background=PANEL, foreground=ACCENT, font=self.heading_font)
        style.configure(
            "TButton",
            background=PANEL_ALT,
            foreground=TEXT,
            borderwidth=1,
            focusthickness=0,
            padding=(12, 6),
            font=self.body_font,
        )
        style.map(
            "TButton",
            background=[("active", ACCENT_DIM), ("pressed", ACCENT)],
            foreground=[("active", BG), ("pressed", BG)],
        )
        style.configure(
            "Accent.TButton",
            background=ACCENT_DIM,
            foreground=BG,
            font=self.heading_font,
        )
        style.map(
            "Accent.TButton",
            background=[("active", ACCENT), ("pressed", ACCENT_DIM)],
        )
        style.configure(
            "TEntry",
            fieldbackground=PANEL_ALT,
            foreground=TEXT,
            insertcolor=ACCENT,
            bordercolor=BORDER,
        )
        style.configure(
            "TSpinbox",
            fieldbackground=PANEL_ALT,
            foreground=TEXT,
            arrowcolor=ACCENT,
            bordercolor=BORDER,
        )
        style.configure(
            "TCheckbutton",
            background=PANEL,
            foreground=TEXT,
            indicatorcolor=PANEL_ALT,
        )
        style.map("TCheckbutton", background=[("active", PANEL)])
        style.configure(
            "TRadiobutton",
            background=PANEL,
            foreground=TEXT,
        )
        style.map("TRadiobutton", background=[("active", PANEL)])
        style.configure(
            "TScale",
            background=PANEL,
            troughcolor=PANEL_ALT,
        )
        style.configure(
            "TProgressbar",
            background=ACCENT,
            troughcolor=PANEL_ALT,
            bordercolor=BORDER,
            lightcolor=ACCENT,
            darkcolor=ACCENT_DIM,
        )
        style.configure(
            "TNotebook",
            background=BG,
            borderwidth=0,
            tabmargins=[2, 4, 2, 0],
        )
        style.configure(
            "TNotebook.Tab",
            background=PANEL,
            foreground=TEXT_DIM,
            padding=[16, 8],
            font=self.heading_font,
        )
        style.map(
            "TNotebook.Tab",
            background=[("selected", PANEL_ALT)],
            foreground=[("selected", ACCENT)],
        )
        style.configure(
            "Horizontal.TScrollbar",
            background=PANEL_ALT,
            troughcolor=PANEL,
            arrowcolor=ACCENT,
        )
        style.configure(
            "Vertical.TScrollbar",
            background=PANEL_ALT,
            troughcolor=PANEL,
            arrowcolor=ACCENT,
        )
        style.configure(
            "Treeview",
            background=PANEL_ALT,
            foreground=TEXT,
            fieldbackground=PANEL_ALT,
            bordercolor=BORDER,
            rowheight=24,
        )
        style.configure(
            "Treeview.Heading",
            background=PANEL,
            foreground=ACCENT,
            font=self.heading_font,
        )
        style.map("Treeview", background=[("selected", ACCENT_DIM)])

    def panel(self, parent: tk.Misc, **kwargs) -> tk.Frame:
        frame = tk.Frame(parent, bg=PANEL, highlightbackground=BORDER, highlightthickness=1, **kwargs)
        return frame

    def label(self, parent: tk.Misc, text: str, **kwargs) -> tk.Label:
        bg = kwargs.pop("bg", BG)
        fg = kwargs.pop("fg", TEXT)
        return tk.Label(parent, text=text, bg=bg, fg=fg, font=self.body_font, **kwargs)

    def heading(self, parent: tk.Misc, text: str) -> tk.Label:
        return tk.Label(parent, text=text, bg=PANEL, fg=ACCENT, font=self.heading_font)

    def button(self, parent: tk.Misc, text: str, command=None, accent: bool = False) -> tk.Button:
        return tk.Button(
            parent,
            text=text,
            command=command,
            bg=ACCENT_DIM if accent else PANEL_ALT,
            fg=BG if accent else TEXT,
            activebackground=ACCENT,
            activeforeground=BG,
            relief=tk.FLAT,
            font=self.heading_font if accent else self.body_font,
            padx=12,
            pady=6,
            cursor="hand2",
        )
