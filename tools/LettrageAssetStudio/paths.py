"""Path resolution — standalone app, stored in Lettrage repo but not part of Godot."""

from __future__ import annotations

import json
import sys
from datetime import datetime
from pathlib import Path


def get_app_dir() -> Path:
    if getattr(sys, "frozen", False):
        return Path(sys.executable).resolve().parent
    return Path(__file__).resolve().parent


def get_settings_path() -> Path:
    return get_app_dir() / "settings.json"


def load_settings() -> dict:
    path = get_settings_path()
    if not path.is_file():
        return {}
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return {}


def save_settings(settings: dict) -> None:
    get_settings_path().write_text(json.dumps(settings, indent=2), encoding="utf-8")


def is_godot_project(path: Path) -> bool:
    return (path / "project.godot").is_file()


def _default_project_when_stored_in_repo() -> Path | None:
    """When stored at Tools/LettrageAssetStudio/, the Godot project root is two levels up."""
    app_dir = get_app_dir()
    if app_dir.parent.name.lower() == "tools":
        candidate = app_dir.parent.parent
        if is_godot_project(candidate):
            return candidate
    return None


def load_lettrage_project() -> Path | None:
    raw = load_settings().get("lettrage_project", "")
    if raw:
        project = Path(raw)
        if is_godot_project(project):
            return project
    return _default_project_when_stored_in_repo()


def save_lettrage_project(project_root: Path) -> None:
    if not is_godot_project(project_root):
        raise ValueError("Selected folder is not a Godot project (project.godot not found).")
    settings = load_settings()
    settings["lettrage_project"] = str(project_root.resolve())
    save_settings(settings)


def get_characters_dir(project_root: Path) -> Path:
    return project_root / "Assets" / "Characters"


def timestamped_output_name(prefix: str) -> str:
    stamp = datetime.now().strftime("%Y%m%d_%H%M")
    return f"{prefix}_{stamp}"


def get_outputs_dir() -> Path:
    """Central folder for all tool-generated output (Green2Alpha, Shrink, etc.)."""
    output_dir = get_app_dir() / "Outputs"
    output_dir.mkdir(parents=True, exist_ok=True)
    return output_dir


def make_timestamped_output_dir(prefix: str) -> Path:
    """Create a timestamped subfolder inside Outputs/."""
    output_dir = get_outputs_dir() / timestamped_output_name(prefix)
    output_dir.mkdir(parents=True, exist_ok=True)
    return output_dir


IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp", ".bmp"}
