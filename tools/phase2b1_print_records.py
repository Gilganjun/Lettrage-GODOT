"""Summarize Phase 2B1 mechanics from phase2b1_extract_raw.json."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "reports" / "phase2b1_extract_raw.json"


def short_type(t) -> str:
    if isinstance(t, dict):
        return t.get("value", str(t))
    return str(t)


def main() -> None:
    data = json.loads(RAW.read_text(encoding="utf-8"))
    for rec in data["records"]:
        path = rec["path"]
        print(f"\n=== {path} ===")
        for c in rec["conditions"]:
            print("  C:", short_type(c["type"]), c["params"])
        for a in rec["actions"]:
            print("  A:", short_type(a["type"]), a["params"][:8])


if __name__ == "__main__":
    main()
