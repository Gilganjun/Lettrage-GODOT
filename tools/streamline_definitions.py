#!/usr/bin/env python3
"""Build DefinitionsStreamlined.txt from the main Top 3 dictionary."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

from definition_common import decode_senses, encode_senses
from definition_streamline import STREAMLINED_MAX_LEN, streamline_senses

DEFAULT_INPUT = Path(r"C:\Lettrage\Dictionary\DefinitionsMain.txt")
DEFAULT_OUTPUT = Path(r"C:\Lettrage\Dictionary\DefinitionsStreamlined.txt")
DEFAULT_REPORT = Path(r"C:\Lettrage\Dictionary\DEFINITIONS_STREAMLINE_REPORT.txt")
DEFAULT_LIVE = ROOT / "dictionary" / "EnglishWords5.txt"
DEFAULT_PROJECT_MAIN = ROOT / "dictionary" / "DefinitionsMain.txt"
DEFAULT_PROJECT_LIVE = ROOT / "dictionary" / "Definitions.txt"
DEFAULT_PROJECT_STREAMLINED = ROOT / "dictionary" / "DefinitionsStreamlined.txt"

PILOT_WORDS = ("A", "I", "THE", "BE", "BANK", "BARK", "DATE", "LIGHT", "CRACK", "FAIR", "NOVEL")
REVIEW_WORDS = ("PALLY", "FUSE", "COPIOUS", "SPIKED", "CAT", "HELLO", "WATER", "GAME")


def load_live_words(path: Path) -> list[str]:
    words: list[str] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        word = line.strip().upper()
        if word.isalpha():
            words.append(word)
    return words


def build_streamlined(input_path: Path, live_words: list[str]) -> tuple[dict[str, list[str]], dict[str, list[str]]]:
    lookup: dict[str, list[str]] = {}
    for line in input_path.read_text(encoding="utf-8").splitlines():
        if "\t" not in line:
            continue
        word, payload = line.split("\t", 1)
        lookup[word.strip().upper()] = decode_senses(payload)

    original: dict[str, list[str]] = {}
    streamlined: dict[str, list[str]] = {}
    for word in live_words:
        senses = lookup.get(word, [])
        if not senses:
            continue
        original[word] = senses
        streamlined[word] = streamline_senses(senses)
    return original, streamlined


def write_dictionary(path: Path, live_words: list[str], defs: dict[str, list[str]]) -> int:
    lines: list[str] = []
    for word in live_words:
        senses = defs.get(word, [])
        if senses:
            lines.append(f"{word}\t{encode_senses(senses)}")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return len(lines)


def write_report(
    path: Path,
    original: dict[str, list[str]],
    streamlined: dict[str, list[str]],
    written: int,
) -> None:
    lengths_before: list[int] = []
    lengths_after: list[int] = []
    for word, senses in original.items():
        for sense in senses:
            lengths_before.append(len(sense))
        for sense in streamlined.get(word, []):
            lengths_after.append(len(sense))

    avg_before = sum(lengths_before) / max(len(lengths_before), 1)
    avg_after = sum(lengths_after) / max(len(lengths_after), 1)
    shortened = 0
    for word, before_senses in original.items():
        after_senses = streamlined.get(word, [])
        for before, after in zip(before_senses, after_senses):
            if len(after) < len(before):
                shortened += 1

    lines = [
        "=" * 72,
        "DEFINITIONS STREAMLINE REPORT",
        "=" * 72,
        f"Entries:              {written:,}",
        f"Max length:           {STREAMLINED_MAX_LEN} chars",
        f"Avg sense length:     {avg_before:.1f} -> {avg_after:.1f} chars",
        f"Senses shortened:     {shortened:,}",
        "",
        "Pilot samples:",
    ]
    for sample in PILOT_WORDS:
        if sample in original:
            before = " | ".join(original[sample])
            after = " | ".join(streamlined.get(sample, []))
            lines.append(f"  {sample}:")
            lines.append(f"    before: {before}")
            lines.append(f"    after:  {after}")
    lines.extend(["", "Review samples:"])
    for sample in REVIEW_WORDS:
        if sample in original:
            before = " | ".join(original[sample])
            after = " | ".join(streamlined.get(sample, []))
            lines.append(f"  {sample}:")
            lines.append(f"    before: {before}")
            lines.append(f"    after:  {after}")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description="Build streamlined definitions for playtests.")
    parser.add_argument("--input", type=Path, default=DEFAULT_INPUT)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--report", type=Path, default=DEFAULT_REPORT)
    parser.add_argument("--live-words", type=Path, default=DEFAULT_LIVE)
    parser.add_argument("--copy-to-project", action="store_true", help="Copy streamlined file to live Definitions.txt.")
    args = parser.parse_args()

    input_path = args.input
    if not input_path.is_file() and DEFAULT_PROJECT_MAIN.is_file():
        input_path = DEFAULT_PROJECT_MAIN
    if not input_path.is_file():
        raise SystemExit(f"Missing input dictionary: {args.input}")

    live_words = load_live_words(args.live_words)
    original, streamlined = build_streamlined(input_path, live_words)
    written = write_dictionary(args.output, live_words, streamlined)
    write_report(args.report, original, streamlined, written)

    project_streamlined = DEFAULT_PROJECT_STREAMLINED
    project_streamlined.write_text(args.output.read_text(encoding="utf-8"), encoding="utf-8")
    print(f"Copied streamlined dictionary to {project_streamlined}")

    if args.copy_to_project:
        DEFAULT_PROJECT_LIVE.write_text(args.output.read_text(encoding="utf-8"), encoding="utf-8")
        print(f"Set live game dictionary to streamlined: {DEFAULT_PROJECT_LIVE}")

    print(f"Streamlined dictionary: {written:,} entries -> {args.output}")


if __name__ == "__main__":
    main()
