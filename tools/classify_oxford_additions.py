#!/usr/bin/env python3
"""Classify Oxford-only headwords for potential addition to EnglishWords5."""

from __future__ import annotations

import re
import sys
import unicodedata
from collections import Counter, defaultdict
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
LIVE_PATH = ROOT / "dictionary" / "EnglishWords5.txt"
OMIT_PATH = ROOT / "dictionary" / "OmissionList.txt"

POS = re.compile(
    r"\s{2,}(?:—|n\.|v\.|adj\.|adv\.|prep\.|conj\.|int\.|abbr\.|prefix|suffix|predic\.)",
    re.I,
)
ABBR_LINE = re.compile(r"\babbr\.", re.I)


def strip_accents(text: str) -> str:
    nfkd = unicodedata.normalize("NFKD", text)
    return "".join(c for c in nfkd if not unicodedata.combining(c))


def norm_letters(raw: str) -> str:
    w = strip_accents(raw.strip()).upper()
    w = re.sub(r"\d+$", "", w)
    return re.sub(r"[^A-Z]", "", w)


def load_upper_set(path: Path) -> set[str]:
    return {
        line.strip().upper()
        for line in path.read_text(encoding="utf-8").splitlines()
        if line.strip()
    }


def parse_oxford_only(live: set[str]) -> dict[str, dict]:
    ox_only: dict[str, dict] = {}
    for line in OXFORD_PATH.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("-"):
            continue
        m = POS.search(stripped)
        raw = stripped[: m.start()].strip() if m else re.split(r"\s{2,}", stripped, maxsplit=1)[0]
        norm = norm_letters(raw)
        if not norm or not norm.isalpha() or norm in live:
            continue
        is_abbr = bool(ABBR_LINE.search(stripped))
        if norm not in ox_only:
            ox_only[norm] = {"raw": raw, "is_abbr": is_abbr}
        else:
            ox_only[norm]["is_abbr"] = ox_only[norm]["is_abbr"] or is_abbr
    return ox_only


def classify(ox_only: dict[str, dict], omit: set[str]) -> tuple[list, dict, Counter]:
    add: list[tuple[str, str, str]] = []
    exclude: dict[str, list[tuple[str, str]]] = defaultdict(list)
    cats: Counter = Counter()

    for norm, info in sorted(ox_only.items()):
        raw = info["raw"]
        reasons: list[str] = []

        if norm in omit:
            reasons.append("omit_list")
        if norm in bcd.all_omissions({norm}):
            reasons.append("tier1_or_welsh")
        if info["is_abbr"] and len(norm) <= 5:
            reasons.append("oxford_abbr_short")
        if len(norm) <= 2 and norm not in ad.REAL_TWO_LETTER:
            reasons.append("short_nonword")
        if norm == "ACEOUS" or raw.lower().startswith("-"):
            reasons.append("suffix_entry")

        spaces = raw.count(" ")
        hyphens = raw.count("-")

        compound_type: str | None = None
        if spaces >= 1:
            reasons.append("multi_word_phrase")
        elif hyphens == 1:
            parts = strip_accents(raw).split("-")
            if len(parts) == 2 and all(p and p[0].isalpha() for p in parts):
                compound_type = "hyphen_compound"
            else:
                reasons.append("odd_hyphen")
        elif hyphens > 1:
            reasons.append("multi_hyphen")
        else:
            compound_type = "standalone"

        hard_exclude = {
            "omit_list",
            "tier1_or_welsh",
            "multi_word_phrase",
            "suffix_entry",
            "short_nonword",
        }
        if hard_exclude & set(reasons):
            for key in (
                "omit_list",
                "tier1_or_welsh",
                "multi_word_phrase",
                "suffix_entry",
                "short_nonword",
            ):
                if key in reasons:
                    cats[key] += 1
                    exclude[key].append((raw, norm))
                    break
            continue

        if compound_type in ("standalone", "hyphen_compound"):
            if "oxford_abbr_short" in reasons:
                cats["oxford_abbr_debatable"] += 1
                exclude["oxford_abbr_debatable"].append((raw, norm))
            cats["add_recommended"] += 1
            add.append((raw, norm, compound_type))
        else:
            cats["unclassified"] += 1
            exclude["unclassified"].append((raw, norm))

    return add, exclude, cats


def main() -> None:
    live = load_upper_set(LIVE_PATH)
    omit = load_upper_set(OMIT_PATH)
    ox_only = parse_oxford_only(live)
    add, exclude, cats = classify(ox_only, omit)

    standalone = [x for x in add if x[2] == "standalone"]
    compounds = [x for x in add if x[2] == "hyphen_compound"]
    no_abbr = [x for x in add if x[1] not in {n for _, n in exclude["oxford_abbr_debatable"]}]

    print(f"Oxford-only unique headwords: {len(ox_only)}")
    print()
    print("SHOULD NOT ADD")
    for key in (
        "omit_list",
        "tier1_or_welsh",
        "multi_word_phrase",
        "suffix_entry",
        "short_nonword",
        "oxford_abbr_debatable",
        "unclassified",
    ):
        if cats.get(key):
            print(f"  {key}: {cats[key]}")
    print()
    print("SHOULD ADD TO LIVE")
    print(f"  Total recommended: {len(add)}")
    print(f"    Standalone: {len(standalone)}")
    print(f"    Hyphen compounds (letters-only token): {len(compounds)}")
    print(f"    Excluding Oxford abbr.-flagged short (<=5): {len(no_abbr)}")
    print()
    print("Samples (standalone):")
    for raw, norm, _ in standalone[:15]:
        print(f"  {raw} -> {norm}")
    print("Samples (hyphen compounds):")
    for raw, norm, _ in compounds[:15]:
        print(f"  {raw} -> {norm}")


if __name__ == "__main__":
    main()
