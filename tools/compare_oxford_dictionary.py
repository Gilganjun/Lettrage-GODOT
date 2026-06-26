#!/usr/bin/env python3
"""Compare Oxford definition dictionary with live EnglishWords5.txt."""

from __future__ import annotations

import re
import unicodedata
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OXFORD = (
    ROOT
    / "dictionary"
    / "Dictionary_New"
    / "f7b7aca357778972040234cae7985db8-12d25c63f58daa5355c19b5b2270c200dee46a86"
    / "Oxford-Word-List-With-Definition.txt"
)
LIVE = ROOT / "dictionary" / "EnglishWords5.txt"
EW4 = ROOT / "dictionary" / "EnglishWords4.txt"
OMIT = ROOT / "dictionary" / "OmissionList.txt"
REPORT = ROOT / "reports" / "DICTIONARY_COMPARISON_REPORT.txt"

# Headword line: starts with letter, has definition body (not blank continuation only)
HEAD_RE = re.compile(
    r"^([A-Za-z][A-Za-z0-9'\-]*(?:\d+)?)\s{1,}(.*)$"
)


def strip_accents(text: str) -> str:
    nfkd = unicodedata.normalize("NFKD", text)
    return "".join(c for c in nfkd if not unicodedata.combining(c))


def normalize_word(raw: str) -> str:
    w = strip_accents(raw.strip())
    w = w.upper()
    # Remove trailing sense numbers for base form comparison
    w = re.sub(r"\d+$", "", w)
    return w


def load_word_set(path: Path) -> set[str]:
    return {
        line.strip().upper()
        for line in path.read_text(encoding="utf-8", errors="replace").splitlines()
        if line.strip().isalpha()
    }


def parse_oxford(path: Path) -> dict[str, list[str]]:
    """Return headword -> list of raw head forms (may include duplicates/senses)."""
    entries: dict[str, list[str]] = {}
    raw_lines = 0
    parsed_lines = 0
    skipped_lines: list[str] = []

    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        stripped = line.strip()
        if not stripped:
            continue
        raw_lines += 1
        m = HEAD_RE.match(stripped)
        if not m:
            skipped_lines.append(stripped[:80])
            continue
        head_raw, body = m.group(1), m.group(2)
        if not body.strip():
            skipped_lines.append(stripped[:80])
            continue
        norm = normalize_word(head_raw)
        if not norm or not norm.isalpha():
            skipped_lines.append(stripped[:80])
            continue
        parsed_lines += 1
        entries.setdefault(norm, []).append(head_raw)

    return {
        "_meta": {
            "raw_lines": raw_lines,
            "parsed_lines": parsed_lines,
            "unique_headwords": len(entries),
            "skipped_sample": skipped_lines[:30],
            "duplicate_headwords": sum(1 for v in entries.values() if len(v) > 1),
        },
        **entries,
    }


def main() -> None:
    if not OXFORD.is_file():
        raise SystemExit(f"Oxford file missing: {OXFORD}")
    if not LIVE.is_file():
        raise SystemExit(f"Live dictionary missing: {LIVE}")

    live = load_word_set(LIVE)
    ew4 = load_word_set(EW4) if EW4.is_file() else set()
    omit = load_word_set(OMIT) if OMIT.is_file() else set()

    parsed = parse_oxford(OXFORD)
    meta = parsed.pop("_meta")
    oxford_words = set(parsed.keys())

    # Base forms without sense numbers (PUNT1 -> PUNT)
    oxford_with_senses = sum(len(v) for v in parsed.values())

    in_live_not_oxford = sorted(live - oxford_words)
    in_oxford_not_live = sorted(oxford_words - live)
    in_both = live & oxford_words

    # Among live-only: how many were intentionally omitted from EW4?
    live_only_in_ew4 = live & ew4
    live_only_not_in_ew4 = live - ew4  # e.g. EID extra inclusion

    oxford_missing_from_ew4 = sorted(oxford_words - ew4)
    oxford_in_omit_list = sorted(oxford_words & omit)

    # Oxford entries that are abbreviations in Oxford text
    abbr_heads = []
    for line in OXFORD.read_text(encoding="utf-8", errors="replace").splitlines():
        s = line.strip()
        if " abbr." in s.lower() or s.lower().startswith("abbr."):
            m = HEAD_RE.match(s)
            if m:
                abbr_heads.append(normalize_word(m.group(1)))

    def len_dist(words: set[str]) -> Counter:
        return Counter(len(w) for w in words)

    live_len = len_dist(live)
    ox_len = len_dist(oxford_words)

    # Oxford has words we removed (omit list)
    removed_in_oxford = sorted(omit & oxford_words)
    removed_live_has_not = sorted((ew4 & omit) - oxford_words)

    # Words in Oxford marked as abbrev
    abbr_in_live = sorted(set(abbr_heads) & live)
    abbr_in_oxford_not_live = sorted(set(abbr_heads) - live)

    lines = [
        "=" * 78,
        "DICTIONARY COMPARISON REPORT",
        "=" * 78,
        f"Live dictionary:     {LIVE.name} ({len(live):,} words)",
        f"Oxford dictionary:   {OXFORD.name}",
        f"Source (unfiltered):  {EW4.name} ({len(ew4):,} words)" if ew4 else "",
        f"Omission list:        {OMIT.name} ({len(omit):,} words)" if omit else "",
        "",
        "OXFORD FILE FORMAT",
        "-" * 78,
        f"Non-empty lines parsed:     {meta['parsed_lines']:,}",
        f"Unique headwords (normalized): {meta['unique_headwords']:,}",
        f"Total headword entries (incl. senses Punt1/Punt2): {oxford_with_senses:,}",
        f"Headwords with multiple entries: {meta['duplicate_headwords']:,}",
        f"Lines skipped by parser (sample): {len(meta['skipped_sample'])} shown below",
        "",
    ]
    for s in meta["skipped_sample"][:15]:
        lines.append(f"  ? {s}")
    lines.append("")

    lines.extend([
        "SUMMARY",
        "-" * 78,
        f"Words in BOTH dictionaries:              {len(in_both):,}",
        f"In LIVE only (not in Oxford):             {len(in_live_not_oxford):,}",
        f"In OXFORD only (not in LIVE):            {len(in_oxford_not_live):,}",
        f"Oxford coverage of live dictionary:      {100 * len(in_both) / len(live):.2f}%",
        f"Live coverage of Oxford headwords:       {100 * len(in_both) / len(oxford_words):.2f}%",
        "",
        "LIVE vs SOURCE (EnglishWords4)",
        "-" * 78,
        f"Live words also in EW4:                  {len(live & ew4):,}",
        f"Live words NOT in EW4 (extra inclusions): {len(live_only_not_in_ew4):,}  {sorted(live_only_not_in_ew4)}",
        f"EW4 words removed to create live:        {len(omit):,}",
        "",
        "OMISSION LIST vs OXFORD",
        "-" * 78,
        f"Omitted words still present in Oxford:   {len(removed_in_oxford):,}",
        f"Omitted words absent from Oxford:        {len(omit - oxford_words):,}",
        "",
        "ABBREVIATION ENTRIES IN OXFORD",
        "-" * 78,
        f"Oxford lines containing 'abbr.':         {len(set(abbr_heads)):,} unique headwords",
        f"Those abbr. headwords in LIVE:           {len(abbr_in_live):,}",
        f"Those abbr. headwords NOT in LIVE:       {len(abbr_in_oxford_not_live):,}",
        "",
    ])

    # Categorize live-only words
    lines.append("LIVE-ONLY BREAKDOWN (not in Oxford)")
    lines.append("-" * 78)
    live_only_omit = sorted((live - oxford_words) & omit)
    live_only_not_omit = sorted((live - oxford_words) - omit)
    lines.append(f"  Were intentionally omitted from EW4 but kept... n/a (omit means removed FROM live)")
    lines.append(f"  In live, not in Oxford, and on omission list: {len(live_only_omit)} (should be 0)")
    lines.append(f"  In live, not in Oxford, not on omission list: {len(live_only_not_omit):,}")
    lines.append("")

    lines.append("WORD LENGTH DISTRIBUTION (top differences)")
    lines.append("-" * 78)
    all_lens = sorted(set(live_len) | set(ox_len))
    lines.append(f"{'Len':>4}  {'Live':>8}  {'Oxford':>8}  {'Delta':>8}")
    for n in all_lens[:20]:
        lines.append(f"{n:>4}  {live_len.get(n,0):>8,}  {ox_len.get(n,0):>8,}  {live_len.get(n,0)-ox_len.get(n,0):>+8,}")
    lines.append("  ...")
    for n in all_lens[-5:]:
        lines.append(f"{n:>4}  {live_len.get(n,0):>8,}  {ox_len.get(n,0):>8,}  {live_len.get(n,0)-ox_len.get(n,0):>+8,}")
    lines.append("")

    def write_samples(title: str, items: list[str], limit: int = 80) -> None:
        lines.append(title)
        lines.append("-" * 78)
        lines.append(f"Count: {len(items):,}")
        if items:
            lines.append(", ".join(items[:limit]))
            if len(items) > limit:
                lines.append(f"... and {len(items) - limit:,} more")
        lines.append("")

    write_samples("SAMPLE: In LIVE only (first 80)", in_live_not_oxford)
    write_samples("SAMPLE: In OXFORD only (first 80)", in_oxford_not_live)
    write_samples("SAMPLE: Omitted from live but IN Oxford (first 80)", removed_in_oxford)
    write_samples("SAMPLE: Oxford abbr. entries NOT in live (first 80)", abbr_in_oxford_not_live)

    lines.append("NOTES")
    lines.append("-" * 78)
    lines.append("- Oxford headwords are Title Case with definitions; compared as UPPERCASE ASCII.")
    lines.append("- Sense numbers stripped for matching (Punt1 -> PUNT).")
    lines.append("- Oxford includes prefixes (A-, Ab-), abbreviations (Aa abbr.), and duplicates.")
    lines.append("- Live dictionary is word-list only; Oxford adds part-of-speech and definitions.")
    lines.append("- Accented forms (Abbé) normalize to ABbe -> AB? need check")
    lines.append("")
    lines.append("END OF REPORT")

    REPORT.parent.mkdir(parents=True, exist_ok=True)
    REPORT.write_text("\n".join(lines), encoding="utf-8")

    print(REPORT)
    print(f"Live: {len(live):,}  Oxford: {len(oxford_words):,}  Both: {len(in_both):,}")
    print(f"Live only: {len(in_live_not_oxford):,}  Oxford only: {len(in_oxford_not_live):,}")


if __name__ == "__main__":
    main()
