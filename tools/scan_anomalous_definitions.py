#!/usr/bin/env python3
"""Scan dictionary primaries for anomalous glosses like WALKING/PLAYED cases."""

from __future__ import annotations

import argparse
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

from definition_anomaly import classify_anomaly, is_anomalous_primary
from definition_common import decode_senses
from definition_inflection import morph_base_candidates

DEFAULT_PATH = ROOT / "dictionary" / "DefinitionsMain.txt"
DEFAULT_REPORT = Path(r"C:\Lettrage\Dictionary\DEFINITIONS_ANOMALY_SCAN.txt")


def scan(path: Path) -> dict[str, object]:
    issue_counts: Counter[str] = Counter()
    anomalous_words: list[str] = []
    total = 0

    for line in path.read_text(encoding="utf-8").splitlines():
        if "\t" not in line:
            continue
        word, payload = line.split("\t", 1)
        word = word.strip().upper()
        senses = decode_senses(payload)
        if not senses:
            continue
        total += 1
        primary = senses[0]
        issues = classify_anomaly(word, primary)
        if is_anomalous_primary(word, primary):
            bases = morph_base_candidates(word)
            anomalous_words.append(
                f"{word}: [{', '.join(issues)}] {primary[:110]}"
                + (f" | bases={','.join(bases[:3])}" if bases else "")
            )
            for issue in issues:
                issue_counts[issue] += 1

    return {
        "path": str(path),
        "total_words": total,
        "anomalous_count": len(anomalous_words),
        "issue_counts": dict(issue_counts),
        "samples": anomalous_words,
    }


def write_report(path: Path, result: dict[str, object]) -> None:
    lines = [
        "=" * 72,
        "DEFINITION ANOMALY SCAN",
        "=" * 72,
        f"File: {result['path']}",
        f"Words: {result['total_words']:,}",
        f"Anomalous primaries: {result['anomalous_count']:,}",
        "",
        "Issue counts:",
    ]
    counts: dict[str, int] = result["issue_counts"]  # type: ignore[assignment]
    for issue, count in sorted(counts.items(), key=lambda item: (-item[1], item[0])):
        lines.append(f"  {issue:24} {count:7,}")
    lines.extend(["", "Samples (up to 100):"])
    for sample in result["samples"][:100]:  # type: ignore[index]
        lines.append(f"  - {sample}")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description="Scan dictionary for anomalous primaries.")
    parser.add_argument("--input", type=Path, default=DEFAULT_PATH)
    parser.add_argument("--report", type=Path, default=DEFAULT_REPORT)
    args = parser.parse_args()
    if not args.input.is_file():
        raise SystemExit(f"Missing dictionary: {args.input}")
    result = scan(args.input)
    write_report(args.report, result)
    print(f"Words: {result['total_words']:,}")
    print(f"Anomalous primaries: {result['anomalous_count']:,}")
    print(f"Report: {args.report}")


if __name__ == "__main__":
    main()
