#!/usr/bin/env python3
"""Parse Oxford definition list and collect normalized words for the live dictionary."""

from __future__ import annotations

import re
import sys
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import analyze_dictionary as ad
import build_clean_dictionary as bcd

OXFORD_PATH = (
    ROOT
    / "dictionary"
    / "Dictionary_New"
    / "f7b7aca357778972040234cae7985db8-12d25c63f58daa5355c19b5b2270c200dee46a86"
    / "Oxford-Word-List-With-Definition.txt"
)
OXFORD_ADDITIONS_PATH = ROOT / "dictionary" / "OxfordAdditions.txt"

POS = re.compile(
    r"\s{2,}(?:—|n\.|v\.|adj\.|adv\.|prep\.|conj\.|int\.|abbr\.|prefix|suffix|predic\.)",
    re.I,
)
ABBR_LINE = re.compile(r"\babbr\.", re.I)


def strip_accents(text: str) -> str:
    nfkd = unicodedata.normalize("NFKD", text)
    return "".join(c for c in nfkd if not unicodedata.combining(c))


def normalize_headword(raw: str) -> str:
    """Uppercase A-Z token: hyphens/spaces removed, accents stripped, sense numbers dropped."""
    word = strip_accents(raw.strip()).upper()
    word = re.sub(r"\d+$", "", word)
    return re.sub(r"[^A-Z]", "", word)


def _parse_headword_line(stripped: str) -> tuple[str, str, bool] | None:
    if not stripped or stripped.startswith("-"):
        return None
    match = POS.search(stripped)
    raw = stripped[: match.start()].strip() if match else re.split(r"\s{2,}", stripped, maxsplit=1)[0]
    norm = normalize_headword(raw)
    if not norm or not norm.isalpha():
        return None
    is_abbr = bool(ABBR_LINE.search(stripped))
    return raw, norm, is_abbr


def iter_oxford_entries() -> list[tuple[str, str, bool]]:
    """Yield (raw_headword, normalized_word, is_abbreviation_entry) for each Oxford line."""
    entries: list[tuple[str, str, bool]] = []
    if not OXFORD_PATH.is_file():
        return entries
    for line in OXFORD_PATH.read_text(encoding="utf-8", errors="replace").splitlines():
        parsed = _parse_headword_line(line.strip())
        if parsed is not None:
            entries.append(parsed)
    return entries


def _should_add(norm: str, raw: str, is_abbr: bool, existing: set[str]) -> bool:
    if norm in existing:
        return False
    if norm in bcd.all_omissions({norm}):
        return False
    if norm == "ACEOUS" or raw.lower().startswith("-"):
        return False
    if is_abbr and len(norm) <= 5:
        return False
    if len(norm) <= 2 and norm not in ad.REAL_TWO_LETTER:
        return False

    spaces = raw.count(" ")
    hyphens = raw.count("-")
    if spaces >= 1:
        return False
    if hyphens == 1:
        parts = strip_accents(raw).split("-")
        return len(parts) == 2 and all(part and part[0].isalpha() for part in parts)
    if hyphens > 1:
        return False
    return True


def collect_oxford_additions(existing: set[str]) -> set[str]:
    """Return normalized Oxford words to merge into EnglishWords5 (not already in `existing`)."""
    by_norm: dict[str, dict] = {}
    for raw, norm, is_abbr in iter_oxford_entries():
        if norm not in by_norm:
            by_norm[norm] = {"raw": raw, "is_abbr": is_abbr}
        else:
            by_norm[norm]["is_abbr"] = by_norm[norm]["is_abbr"] or is_abbr

    additions: set[str] = set()
    for norm, info in by_norm.items():
        if _should_add(norm, info["raw"], info["is_abbr"], existing):
            additions.add(norm)
    return additions


def write_additions_manifest(words: set[str]) -> None:
    OXFORD_ADDITIONS_PATH.write_text(
        "\n".join(sorted(words)) + ("\n" if words else ""),
        encoding="utf-8",
    )
