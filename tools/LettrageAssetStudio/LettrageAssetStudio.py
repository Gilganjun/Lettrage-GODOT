"""
Lettrage Asset Studio v1.0
Standalone desktop asset pipeline for Lettrage character animations.

Build standalone EXE (can live on Desktop — no Godot folder required):
    pyinstaller --onefile --windowed LettrageAssetStudio.py
"""

from __future__ import annotations

import sys
from pathlib import Path

APP_DIR = Path(__file__).resolve().parent
if str(APP_DIR) not in sys.path:
    sys.path.insert(0, str(APP_DIR))

from dependencies import ensure_dependencies

ensure_dependencies()

import tkinter as tk

from main_window import MainWindow


def main() -> None:
    root = tk.Tk()
    MainWindow(root)
    root.mainloop()


if __name__ == "__main__":
    main()
