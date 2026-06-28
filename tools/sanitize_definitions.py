#!/usr/bin/env python3
"""Remove incomplete or Oxford-junk senses from definition TSV files."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

from definition_common import decode_senses, encode_senses
from definition_quality import filter_senses

DEFAULT_PATHS = [
    ROOT / "dictionary" / "DefinitionsMain.txt",
    ROOT / "dictionary" / "DefinitionsStreamlined.txt",
    ROOT / "dictionary" / "Definitions.txt",
    Path(r"C:\Lettrage\Dictionary\DefinitionsComprehensive.txt"),
    Path(r"C:\Lettrage\Dictionary\DefinitionsTop3.txt"),
    Path(r"C:\Lettrage\Dictionary\DefinitionsStreamlined.txt"),
]


def sanitize_file(path: Path) -> tuple[int, int, int]:
    if not path.is_file():
        raise FileNotFoundError(path)
    lines_out: list[str] = []
    words_in = 0
    senses_in = 0
    senses_out = 0
    for line in path.read_text(encoding="utf-8").splitlines():
        if "\t" not in line:
            continue
        word, payload = line.split("\t", 1)
        word = word.strip().upper()
        senses = decode_senses(payload)
        if not senses:
            continue
        words_in += 1
        senses_in += len(senses)
        cleaned = filter_senses(senses)
        if not cleaned:
            continue
        senses_out += len(cleaned)
        lines_out.append(f"{word}\t{encode_senses(cleaned)}")
    path.write_text("\n".join(lines_out) + "\n", encoding="utf-8")
    return words_in, senses_in, senses_out


def main() -> None:
    parser = argparse.ArgumentParser(description="Sanitize definition dictionaries.")
    parser.add_argument("paths", nargs="*", type=Path, default=DEFAULT_PATHS)
    args = parser.parse_args()
    for path in args.paths:
        before_words, before_senses, after_senses = sanitize_file(path)
        removed = before_senses - after_senses
        print(
            f"{path}: {before_words:,} words, "
            f"{before_senses:,} -> {after_senses:,} senses "
            f"({removed:,} removed)"
        )


if __name__ == "__main__":
    main()
