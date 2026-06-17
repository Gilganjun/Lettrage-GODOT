"""Tab 4: Animation preview and frame cleanup — adapted from AnimationTester."""

from __future__ import annotations

import os
import shutil
import tkinter as tk
from pathlib import Path
from tkinter import filedialog, messagebox, ttk

from paths import make_timestamped_output_dir
from theme import BG, PANEL, TEXT_DIM, Theme
from utils import load_preview_image, run_in_thread


class AnimationTesterTab(ttk.Frame):
    ZOOM = 2.0

    def __init__(self, parent: tk.Misc, theme: Theme) -> None:
        super().__init__(parent, style="TFrame")
        self.theme = theme
        self.frames: list[Path] = []
        self.source_folder: Path | None = None
        self.index = 0
        self.playing = False
        self.loop = tk.BooleanVar(value=True)
        self.fps = tk.IntVar(value=12)
        self._dirty = False

        self._preview_photo: tk.PhotoImage | None = None
        self._drag_index: int | None = None
        self._busy = False
        self._build_ui()

    def _build_ui(self) -> None:
        self.columnconfigure(0, weight=0, minsize=280)
        self.columnconfigure(1, weight=1)
        self.rowconfigure(0, weight=1)

        left = self.theme.panel(self, padx=12, pady=12)
        left.grid(row=0, column=0, sticky="nsew", padx=(12, 6), pady=12)
        left.columnconfigure(0, weight=1)
        left.rowconfigure(0, weight=1)
        left.rowconfigure(1, weight=0)

        body = tk.Frame(left, bg=PANEL)
        body.grid(row=0, column=0, sticky="nsew")
        body.columnconfigure(0, weight=1)
        body.rowconfigure(1, weight=1)

        footer = tk.Frame(left, bg=PANEL)
        footer.grid(row=1, column=0, sticky="ew", pady=(8, 0))

        self.theme.heading(body, "Frame List").grid(row=0, column=0, sticky="w", pady=(0, 6))

        btn_row = tk.Frame(body, bg=PANEL)
        btn_row.grid(row=0, column=0, sticky="e", pady=(0, 6))
        self.theme.button(btn_row, "Load Folder", self._load_folder).pack(side=tk.LEFT, padx=(0, 4))
        self.theme.button(btn_row, "Add Frames", self._add_frames).pack(side=tk.LEFT)

        list_frame = tk.Frame(body, bg=PANEL)
        list_frame.grid(row=1, column=0, sticky="nsew")
        list_frame.columnconfigure(0, weight=1)
        list_frame.rowconfigure(0, weight=1)

        scrollbar = ttk.Scrollbar(list_frame, orient=tk.VERTICAL)
        self.frame_listbox = tk.Listbox(
            list_frame,
            bg="#222222",
            fg="#E8E8E8",
            selectbackground="#00A896",
            selectforeground="#101010",
            activestyle="none",
            exportselection=False,
            selectmode=tk.EXTENDED,
            yscrollcommand=scrollbar.set,
            font=self.theme.mono_font,
        )
        scrollbar.config(command=self.frame_listbox.yview)
        self.frame_listbox.grid(row=0, column=0, sticky="nsew")
        scrollbar.grid(row=0, column=1, sticky="ns")

        self.frame_listbox.bind("<<ListboxSelect>>", self._on_list_select)
        self.frame_listbox.bind("<ButtonPress-1>", self._on_drag_start)
        self.frame_listbox.bind("<B1-Motion>", self._on_drag_motion)
        self.frame_listbox.bind("<ButtonRelease-1>", self._on_drag_end)

        del_row = tk.Frame(footer, bg=PANEL)
        del_row.pack(fill=tk.X, pady=(0, 6))
        self.theme.button(del_row, "Delete Current", self._remove_current_frame).pack(side=tk.LEFT, padx=(0, 4))
        self.theme.button(del_row, "Delete Selected", self._remove_selected_frames).pack(side=tk.LEFT)

        self.save_btn = self.theme.button(footer, "Save", self._save_sequence, accent=True)
        self.save_btn.pack(fill=tk.X)

        self.status_label = self.theme.label(
            footer,
            "Load frames, clean up, reorder, then Save.",
            bg=PANEL,
            fg=TEXT_DIM,
            wraplength=260,
            justify=tk.LEFT,
        )
        self.status_label.pack(anchor="w", pady=(6, 0))

        right = tk.Frame(self, bg=BG)
        right.grid(row=0, column=1, sticky="nsew", padx=(6, 12), pady=12)
        right.rowconfigure(1, weight=1)
        right.columnconfigure(0, weight=1)

        top = tk.Frame(right, bg=BG)
        top.grid(row=0, column=0, sticky="ew", pady=(0, 8))

        self.theme.button(top, "▶ Play", self._start_animation).pack(side=tk.LEFT, padx=4)
        self.theme.button(top, "⏹ Stop", self._stop_animation).pack(side=tk.LEFT, padx=4)
        self.theme.button(top, "◀ Prev", self._prev_frame).pack(side=tk.LEFT, padx=4)
        self.theme.button(top, "Next ▶", self._next_frame).pack(side=tk.LEFT, padx=4)

        ttk.Checkbutton(top, text="Loop", variable=self.loop).pack(side=tk.LEFT, padx=16)

        fps_row = tk.Frame(top, bg=BG)
        fps_row.pack(side=tk.LEFT, padx=8)
        self.theme.label(fps_row, "FPS:").pack(side=tk.LEFT)
        ttk.Scale(fps_row, from_=1, to=60, variable=self.fps, orient=tk.HORIZONTAL, length=160).pack(
            side=tk.LEFT, padx=8
        )
        self.fps_label = self.theme.label(fps_row, "12")
        self.fps_label.pack(side=tk.LEFT)
        self.fps.trace_add("write", lambda *_: self.fps_label.config(text=str(self.fps.get())))

        self.info_label = self.theme.label(top, "Frame — / —  |  Est. FPS: —")
        self.info_label.pack(side=tk.RIGHT, padx=8)

        preview_panel = self.theme.panel(right, padx=16, pady=16)
        preview_panel.grid(row=1, column=0, sticky="nsew")
        preview_panel.rowconfigure(0, weight=1)
        preview_panel.columnconfigure(0, weight=1)

        self.preview_label = tk.Label(preview_panel, bg=PANEL, fg=TEXT_DIM, text="Load a folder of PNG frames")
        self.preview_label.pack(expand=True, fill=tk.BOTH)

    def _mark_dirty(self) -> None:
        self._dirty = True
        self.status_label.config(text="Unsaved changes — click Save to write sequence.")

    def _refresh_listbox(self) -> None:
        self.frame_listbox.delete(0, tk.END)
        for i, path in enumerate(self.frames):
            self.frame_listbox.insert(tk.END, f"{i + 1:03d}  {path.name}")
        if self.frames:
            self.frame_listbox.selection_clear(0, tk.END)
            self.frame_listbox.selection_set(self.index)
            self.frame_listbox.see(self.index)

    def _load_folder(self) -> None:
        folder = filedialog.askdirectory()
        if not folder:
            return
        self.load_from_folder(Path(folder))

    def load_from_folder(self, folder: Path) -> None:
        paths = sorted(folder.glob("*.png"))
        if not paths:
            paths = sorted(folder.glob("*.PNG"))
        if not paths:
            messagebox.showinfo("Load Folder", "No PNG frames found in that folder.")
            return
        self.source_folder = folder
        self.frames = list(paths)
        self.index = 0
        self._dirty = False
        self._refresh_listbox()
        self._show_frame()
        self.status_label.config(text=f"Loaded {len(self.frames)} frames from {folder.name}.")

    def _add_frames(self) -> None:
        files = filedialog.askopenfilenames(filetypes=[("PNG files", "*.png")])
        if files:
            for f in sorted(files):
                p = Path(f)
                if p not in self.frames:
                    self.frames.append(p)
            self._mark_dirty()
            self._refresh_listbox()
            self._show_frame()

    def _on_list_select(self, _event: tk.Event | None = None) -> None:
        sel = self.frame_listbox.curselection()
        if sel:
            self.index = sel[0]
            self._show_frame()

    def _on_drag_start(self, event: tk.Event) -> None:
        idx = self.frame_listbox.nearest(event.y)
        if 0 <= idx < len(self.frames):
            self._drag_index = idx

    def _on_drag_motion(self, event: tk.Event) -> None:
        if self._drag_index is None:
            return
        target = self.frame_listbox.nearest(event.y)
        if target == self._drag_index or target < 0 or target >= len(self.frames):
            return
        item = self.frames.pop(self._drag_index)
        self.frames.insert(target, item)
        self._drag_index = target
        self.index = target
        self._mark_dirty()
        self._refresh_listbox()

    def _on_drag_end(self, _event: tk.Event) -> None:
        self._drag_index = None

    def _remove_current_frame(self) -> None:
        if not self.frames:
            return
        removed = self.frames.pop(self.index)
        if not messagebox.askyesno("Confirm Delete", f"Delete from disk?\n{removed.name}"):
            self.frames.insert(self.index, removed)
            return
        try:
            os.remove(removed)
        except OSError as exc:
            messagebox.showerror("Delete Failed", str(exc))
            self.frames.insert(self.index, removed)
            return
        self.index = max(0, min(self.index, len(self.frames) - 1))
        self._refresh_listbox()
        self._show_frame()
        self.status_label.config(text=f"Deleted {removed.name} from disk.")

    def _remove_selected_frames(self) -> None:
        sel = list(self.frame_listbox.curselection())
        if not sel:
            messagebox.showinfo("Delete Frames", "Select one or more frames to delete.")
            return
        if not messagebox.askyesno("Confirm Delete", f"Delete {len(sel)} frame(s) from disk?"):
            return
        removed_paths = [self.frames[i] for i in sel]
        for i in reversed(sel):
            self.frames.pop(i)
        for path in removed_paths:
            try:
                os.remove(path)
            except OSError:
                pass
        self.index = max(0, min(self.index, len(self.frames) - 1))
        self._refresh_listbox()
        self._show_frame()
        self.status_label.config(text=f"Deleted {len(removed_paths)} frame(s) from disk.")

    def _save_sequence(self) -> None:
        if self._busy:
            return
        if not self.frames:
            messagebox.showerror("Error", "No frames to save.")
            return

        self._stop_animation()
        self._set_busy(True)
        frames = list(self.frames)

        def work() -> None:
            output_dir = make_timestamped_output_dir("AnimationTester_Output")
            saved: list[Path] = []
            for i, src in enumerate(frames, start=1):
                dest = output_dir / f"frame_{i:03d}.png"
                shutil.copy2(src, dest)
                saved.append(dest)

            def done() -> None:
                self._set_busy(False)
                self.frames = saved
                self.source_folder = output_dir
                self.index = min(self.index, len(self.frames) - 1)
                self._dirty = False
                self._refresh_listbox()
                self._show_frame()
                self.status_label.config(text=f"Saved {len(saved)} frames to {output_dir.name}")
                messagebox.showinfo("Save Complete", f"Saved {len(saved)} frames to:\n{output_dir}")

            self.after(0, done)

        run_in_thread(self, work)

    def _set_busy(self, busy: bool) -> None:
        self._busy = busy
        self.save_btn.config(state=tk.DISABLED if busy else tk.NORMAL)

    def _show_frame(self) -> None:
        if not self.frames:
            self.preview_label.config(image="", text="No frames loaded")
            self.info_label.config(text="Frame — / —  |  Est. FPS: —")
            return

        path = self.frames[self.index]
        photo = load_preview_image(str(path), (900, 700), zoom=self.ZOOM)
        if photo:
            self._preview_photo = photo
            self.preview_label.config(image=photo, text="")
        est_fps = self.fps.get()
        self.info_label.config(
            text=f"Frame {self.index + 1} / {len(self.frames)}  |  Est. FPS: {est_fps}"
        )

    def _prev_frame(self) -> None:
        if not self.frames:
            return
        self._stop_animation()
        self.index = (self.index - 1) % len(self.frames)
        self._refresh_listbox()
        self._show_frame()

    def _next_frame(self) -> None:
        if not self.frames:
            return
        self._stop_animation()
        self.index = (self.index + 1) % len(self.frames)
        self._refresh_listbox()
        self._show_frame()

    def _start_animation(self) -> None:
        if not self.frames:
            return
        self.playing = True
        self._update_frame()

    def _stop_animation(self) -> None:
        self.playing = False

    def _update_frame(self) -> None:
        if not self.playing or not self.frames:
            return

        if self.index >= len(self.frames) - 1:
            if self.loop.get():
                self.index = 0
            else:
                self.playing = False
                return
        else:
            self.index += 1

        self._refresh_listbox()
        self._show_frame()
        delay = max(1, int(1000 / max(1, self.fps.get())))
        self.after(delay, self._update_frame)
