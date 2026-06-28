#!/usr/bin/env python3
"""Compare dictionary primaries before/after a fix run."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

from definition_anomaly import classify_anomaly, is_anomalous_primary
from definition_common import decode_senses

DEFAULT_BEFORE = Path(r"C:\Lettrage\Dictionary\DefinitionsMain.before_anomaly_fix.txt")
DEFAULT_AFTER = ROOT / "dictionary" / "DefinitionsMain.txt"
DEFAULT_REPORT = Path(r"C:\Lettrage\Dictionary\DEFINITIONS_ANOMALY_FIX_REPORT.txt")


def load_primaries(path: Path) -> dict[str, str]:
    out: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if "\t" not in line:
            continue
        word, payload = line.split("\t", 1)
        senses = decode_senses(payload)
        if senses:
            out[word.strip().upper()] = senses[0]
    return out


def compare(before: dict[str, str], after: dict[str, str]) -> dict[str, object]:
    fixed: list[str] = []
    still_bad: list[str] = []
    changed = 0
    for word, old_primary in before.items():
        new_primary = after.get(word)
        if new_primary is None or new_primary == old_primary:
            if new_primary and is_anomalous_primary(word, new_primary):
                still_bad.append(f"{word}: {new_primary[:100]} ({', '.join(classify_anomaly(word, new_primary))})")
            continue
        changed += 1
        old_bad = is_anomalous_primary(word, old_primary)
        new_bad = is_anomalous_primary(word, new_primary)
        if old_bad and not new_bad:
            fixed.append(f"{word}: {old_primary[:70]} -> {new_primary[:90]}")
        elif old_bad and new_bad:
            still_bad.append(f"{word}: {new_primary[:100]} ({', '.join(classify_anomaly(word, new_primary))})")
    return {
        "changed": changed,
        "fixed_count": len(fixed),
        "still_bad_count": len(still_bad),
        "fixed": fixed,
        "still_bad": still_bad,
    }


def write_report(path: Path, result: dict[str, object]) -> None:
    lines = [
        "=" * 72,
        "ANOMALY FIX COMPARISON",
        "=" * 72,
        f"Primary definitions changed: {result['changed']:,}",
        f"Anomalous primaries fixed:   {result['fixed_count']:,}",
        f"Still anomalous after fix:   {result['still_bad_count']:,}",
        "",
        "Fixed examples (up to 60):",
    ]
    for sample in result["fixed"][:60]:  # type: ignore[index]
        lines.append(f"  - {sample}")
    lines.extend(["", "Still anomalous (up to 40):"])
    for sample in result["still_bad"][:40]:  # type: ignore[index]
        lines.append(f"  - {sample}")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description="Compare dictionary primaries before/after fix.")
    parser.add_argument("--before", type=Path, default=DEFAULT_BEFORE)
    parser.add_argument("--after", type=Path, default=DEFAULT_AFTER)
    parser.add_argument("--report", type=Path, default=DEFAULT_REPORT)
    args = parser.parse_args()
    if not args.before.is_file() or not args.after.is_file():
        raise SystemExit("Missing before/after dictionary files.")
    result = compare(load_primaries(args.before), load_primaries(args.after))
    write_report(args.report, result)
    print(f"Fixed: {result['fixed_count']:,}")
    print(f"Still bad: {result['still_bad_count']:,}")
    print(f"Report: {args.report}")


if __name__ == "__main__":
    main()
