#!/usr/bin/env python3
"""Regenerate Top 3 definitions from the local comprehensive dictionary."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

from definition_common import decode_senses, encode_senses
from definition_ranking import select_game_top3_from_senses

DEFAULT_COMPREHENSIVE = Path(r"C:\Lettrage\Dictionary\DefinitionsComprehensive.txt")
DEFAULT_TOP3 = Path(r"C:\Lettrage\Dictionary\DefinitionsTop3.txt")
DEFAULT_REPORT = Path(r"C:\Lettrage\Dictionary\DEFINITIONS_TOP3_REFINE_REPORT.txt")
DEFAULT_LIVE = ROOT / "dictionary" / "EnglishWords5.txt"
DEFAULT_PROJECT_TOP3 = ROOT / "dictionary" / "Definitions.txt"

PILOT_WORDS = ("A", "I", "THE", "BE", "BANK", "BARK", "DATE", "LIGHT", "CRACK", "FAIR", "NOVEL")
REVIEW_WORDS = (
    "BAB",
    "RIB",
    "FUSE",
    "TAFFY",
    "PALLY",
    "SPIKED",
    "ANNEXE",
    "RIGOUR",
    "COPIOUS",
    "LOVENEST",
    "DEPILATION",
    "DISPRAISE",
    "THALASSIC",
    "ENDURABLE",
    "UNENGAGED",
    "BLACKBALL",
    "CATERCORNER",
    "SCHOLARSHIP",
    "WINTERGREEN",
    "UNDERPINNING",
)


def load_live_words(path: Path) -> list[str]:
    words: list[str] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        word = line.strip().upper()
        if word.isalpha():
            words.append(word)
    return words


def load_comprehensive(path: Path) -> dict[str, list[str]]:
    lookup: dict[str, list[str]] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if "\t" not in line:
            continue
        word, payload = line.split("\t", 1)
        lookup[word.strip().upper()] = decode_senses(payload)
    return lookup


def refine_top3(
    live_words: list[str],
    comprehensive: dict[str, list[str]],
) -> dict[str, list[str]]:
    top3: dict[str, list[str]] = {}
    for word in live_words:
        senses = comprehensive.get(word, [])
        if not senses:
            continue
        picked = select_game_top3_from_senses(word, senses)
        if picked:
            top3[word] = picked
    return top3


def write_top3(path: Path, live_words: list[str], top3: dict[str, list[str]]) -> int:
    lines: list[str] = []
    for word in live_words:
        senses = top3.get(word, [])
        if senses:
            lines.append(f"{word}\t{encode_senses(senses)}")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return len(lines)


def write_report(path: Path, top3: dict[str, list[str]], written: int, live_count: int) -> None:
    counts = {1: 0, 2: 0, 3: 0}
    for senses in top3.values():
        bucket = min(len(senses), 3)
        counts[bucket] = counts.get(bucket, 0) + 1

    lines = [
        "=" * 72,
        "TOP 3 REFINE REPORT",
        "=" * 72,
        f"Live words:          {live_count:,}",
        f"Top 3 written:       {written:,}",
        f"1-sense entries:     {counts.get(1, 0):,}",
        f"2-sense entries:     {counts.get(2, 0):,}",
        f"3-sense entries:     {counts.get(3, 0):,}",
        "",
        "Pilot samples:",
    ]
    for sample in PILOT_WORDS:
        if sample in top3:
            lines.append(f"  {sample}: {' | '.join(top3[sample])}")
    lines.extend(["", "Review samples:"])
    for sample in REVIEW_WORDS:
        if sample in top3:
            lines.append(f"  {sample}: {' | '.join(top3[sample])}")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description="Refine Top 3 definitions from comprehensive dictionary.")
    parser.add_argument("--comprehensive", type=Path, default=DEFAULT_COMPREHENSIVE)
    parser.add_argument("--output", type=Path, default=DEFAULT_TOP3)
    parser.add_argument("--report", type=Path, default=DEFAULT_REPORT)
    parser.add_argument("--live-words", type=Path, default=DEFAULT_LIVE)
    parser.add_argument("--copy-to-project", action="store_true")
    args = parser.parse_args()

    if not args.comprehensive.is_file():
        raise SystemExit(f"Missing comprehensive dictionary: {args.comprehensive}")

    live_words = load_live_words(args.live_words)
    comprehensive = load_comprehensive(args.comprehensive)
    top3 = refine_top3(live_words, comprehensive)
    written = write_top3(args.output, live_words, top3)
    write_report(args.report, top3, written, len(live_words))

    if args.copy_to_project:
        DEFAULT_PROJECT_TOP3.write_text(args.output.read_text(encoding="utf-8"), encoding="utf-8")
        print(f"Copied Top 3 dictionary to {DEFAULT_PROJECT_TOP3}")

    print(f"Refined Top 3: {written:,} entries -> {args.output}")


if __name__ == "__main__":
    main()
