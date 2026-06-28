#!/usr/bin/env python3
"""Audit Top 3 dictionaries for archaic/grammatical primary definitions."""

from __future__ import annotations

import argparse
import sys
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

from definition_common import decode_senses
from definition_ranking import (
    SenseEntry,
    _game_score,
    _polish_gloss,
    classify_primary_issues,
    entries_from_sense_texts,
    is_obscure_for_game,
    is_playable_primary,
    serious_primary_issues,
)
from definition_quality import is_acceptable_gloss

DEFAULT_TOP3 = ROOT / "dictionary" / "DefinitionsMain.txt"
DEFAULT_COMPREHENSIVE = Path(r"C:\Lettrage\Dictionary\DefinitionsComprehensive.txt")
DEFAULT_REPORT = Path(r"C:\Lettrage\Dictionary\DEFINITIONS_TOP3_RANKING_AUDIT.txt")
SCORE_GAP = 40


def _entry_score(word: str, text: str, order: int = 0) -> int:
    return _game_score(
        word,
        SenseEntry(
            text=text,
            is_abbrev=False,
            order=order,
            source="comprehensive",
        ),
    )[0]


def _best_playable_primary(word: str, comprehensive: list[str]) -> tuple[str | None, int]:
    best_text: str | None = None
    best_score = 10**9
    for order, sense in enumerate(comprehensive):
        if is_obscure_for_game(word, sense, False):
            continue
        polished = _polish_gloss(word, sense)
        if not is_acceptable_gloss(polished):
            continue
        if not is_playable_primary(word, polished):
            continue
        score = _entry_score(word, polished, order)
        if score < best_score:
            best_score = score
            best_text = polished
    return best_text, best_score


def audit_top3(
    top3_path: Path,
    comprehensive_path: Path,
) -> dict[str, object]:
    comprehensive_lookup: dict[str, list[str]] = {}
    for line in comprehensive_path.read_text(encoding="utf-8").splitlines():
        if "\t" not in line:
            continue
        word, payload = line.split("\t", 1)
        comprehensive_lookup[word.strip().upper()] = decode_senses(payload)

    issue_counts: Counter[str] = Counter()
    misranked: list[str] = []
    bad_no_alt: list[str] = []
    bad_any_sense: list[str] = []
    total_words = 0
    total_senses = 0

    for line in top3_path.read_text(encoding="utf-8").splitlines():
        if "\t" not in line:
            continue
        word, payload = line.split("\t", 1)
        word = word.strip().upper()
        senses = decode_senses(payload)
        if not senses:
            continue
        total_words += 1
        total_senses += len(senses)
        comp = comprehensive_lookup.get(word, [])

        for index, sense in enumerate(senses):
            issues = serious_primary_issues(word, sense)
            if issues:
                bad_any_sense.append(f"{word}[{index + 1}]: {sense[:100]} ({', '.join(issues)})")
                if index == 0:
                    for issue in issues:
                        issue_counts[issue] += 1

        primary = senses[0]
        primary_issues = serious_primary_issues(word, primary)
        if not primary_issues:
            continue

        best_text, best_score = _best_playable_primary(word, comp)
        primary_score = _entry_score(word, primary, 0)
        if best_text and best_text.lower() != primary.lower() and best_score + SCORE_GAP < primary_score:
            misranked.append(
                f"{word}: [{', '.join(primary_issues)}] "
                f"PRIMARY={primary[:90]} | BETTER={best_text[:90]}"
            )
        else:
            bad_no_alt.append(
                f"{word}: [{', '.join(primary_issues)}] PRIMARY={primary[:100]}"
            )

    return {
        "top3_path": str(top3_path),
        "comprehensive_path": str(comprehensive_path),
        "total_words": total_words,
        "total_senses": total_senses,
        "issue_counts": dict(issue_counts),
        "misranked_count": len(misranked),
        "bad_no_alt_count": len(bad_no_alt),
        "bad_any_sense_count": len(bad_any_sense),
        "misranked": misranked,
        "bad_no_alt": bad_no_alt,
        "bad_any_sense": bad_any_sense,
    }


def write_report(path: Path, result: dict[str, object]) -> None:
    lines = [
        "=" * 72,
        "TOP 3 RANKING AUDIT",
        "=" * 72,
        f"Top 3 file:          {result['top3_path']}",
        f"Comprehensive file:  {result['comprehensive_path']}",
        f"Words audited:       {result['total_words']:,}",
        f"Senses audited:      {result['total_senses']:,}",
        f"Misranked primaries: {result['misranked_count']:,}",
        f"Bad primaries (no better alt): {result['bad_no_alt_count']:,}",
        f"Any bad sense slot:  {result['bad_any_sense_count']:,}",
        "",
        "Primary issue counts:",
    ]
    counts: dict[str, int] = result["issue_counts"]  # type: ignore[assignment]
    for issue, count in sorted(counts.items(), key=lambda item: (-item[1], item[0])):
        lines.append(f"  {issue:24} {count:7,}")

    lines.extend(["", "Misranked primaries (sample up to 80):"])
    for sample in result["misranked"][:80]:  # type: ignore[index]
        lines.append(f"  - {sample}")

    lines.extend(["", "Bad primaries with no better alternative (sample up to 40):"])
    for sample in result["bad_no_alt"][:40]:  # type: ignore[index]
        lines.append(f"  - {sample}")

    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description="Audit Top 3 primary definition ranking.")
    parser.add_argument("--top3", type=Path, default=DEFAULT_TOP3)
    parser.add_argument("--comprehensive", type=Path, default=DEFAULT_COMPREHENSIVE)
    parser.add_argument("--report", type=Path, default=DEFAULT_REPORT)
    args = parser.parse_args()

    if not args.top3.is_file():
        raise SystemExit(f"Missing Top 3 dictionary: {args.top3}")
    if not args.comprehensive.is_file():
        raise SystemExit(f"Missing comprehensive dictionary: {args.comprehensive}")

    result = audit_top3(args.top3, args.comprehensive)
    write_report(args.report, result)

    print(f"Words: {result['total_words']:,}")
    print(f"Misranked primaries: {result['misranked_count']:,}")
    print(f"Bad primaries (no better alt): {result['bad_no_alt_count']:,}")
    print(f"Report: {args.report}")


if __name__ == "__main__":
    main()
