#!/usr/bin/env python3
"""Report Oxford words merged into EnglishWords5 via oxford_dictionary."""

from __future__ import annotations

import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import oxford_dictionary as oxford

ADDITIONS_PATH = ROOT / "dictionary" / "OxfordAdditions.txt"


def main() -> None:
    if not ADDITIONS_PATH.is_file():
        raise SystemExit(f"Run build_clean_dictionary.py first ({ADDITIONS_PATH.name} missing)")

    additions = {
        line.strip()
        for line in ADDITIONS_PATH.read_text(encoding="utf-8").splitlines()
        if line.strip()
    }
    raw_by_norm = {norm: raw for raw, norm, _ in oxford.iter_oxford_entries() if norm in additions}

    standalone = 0
    compounds = 0
    for norm in additions:
        raw = raw_by_norm.get(norm, norm)
        if raw.count("-") == 1 and raw.count(" ") == 0:
            compounds += 1
        else:
            standalone += 1

    print(f"Oxford additions in live dictionary: {len(additions):,}")
    print(f"  Standalone: {standalone:,}")
    print(f"  Normalized hyphen compounds: {compounds:,}")
    print()
    print("Samples:")
    for norm in sorted(additions)[:20]:
        raw = raw_by_norm.get(norm, norm)
        print(f"  {raw} -> {norm}")


if __name__ == "__main__":
    main()
