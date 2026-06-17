"""Auto-install required third-party packages."""

import importlib
import subprocess
import sys

REQUIRED_PACKAGES = {
    "opencv-python": "cv2",
    "pillow": "PIL",
    "numpy": "numpy",
}


def ensure_dependencies() -> None:
    for package, import_name in REQUIRED_PACKAGES.items():
        try:
            importlib.import_module(import_name)
        except ImportError:
            subprocess.check_call(
                [sys.executable, "-m", "pip", "install", package],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
