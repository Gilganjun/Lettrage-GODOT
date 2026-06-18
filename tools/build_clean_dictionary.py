#!/usr/bin/env python3
"""Build EnglishWords5.txt by removing non-words from EnglishWords4.txt.

Removes: Tier-1 abbreviations/codes, obscure 3-letter tokens, Welsh vocabulary.
"""

from __future__ import annotations

import re
from pathlib import Path

import analyze_dictionary as ad

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "dictionary" / "EnglishWords4.txt"
OMISSION_PATH = ROOT / "dictionary" / "OmissionList.txt"
OUTPUT = ROOT / "dictionary" / "EnglishWords5.txt"

# Always include these valid words even if absent from EnglishWords4.txt.
EXTRA_INCLUSIONS = frozenset("EID".split())

# Very obscure 3-letter entries (not ordinary English: CRY, SKY, TRY, etc.).
OBSCURE_THREE_LETTER = frozenset(
    """
    BSC BYS CLY CWM CWT FYS GYP HYP LYM LYS MYS NYM NYX PYM PYX SNY SWY TWP TYG TYR WYF WYN
    """.split()
)

# LLAN- exceptions that are Spanish/English, not Welsh placenames.
LLAN_NOT_WELSH = frozenset("LLAMA LLAMAS LLANO LLANOS LLANERO LLANEROS".split())

# ABER- Welsh placenames only (not Scottish ABERNETHY or English aberration*).
ABER_WELSH = frozenset(
    """
    ABERAERON ABERAVON ABERDARE ABERDARON ABERDOVEY ABERFELDY ABERGELE ABERSOCH
    ABERTILLY ABERYSTWYTH ABERTAWE
    """.split()
)

WELSH_REGEX = [
    re.compile(r"CRWTH"),
    re.compile(r"GHYLL"),
    re.compile(r"CYMRY"),
    re.compile(r"CYMRU"),
    re.compile(r"EISTEDDFOD"),
    re.compile(r"^HWYL"),
    re.compile(r"CWMBRAN"),
    re.compile(r"^CWM$"),
    re.compile(r"^CWMS$"),
    re.compile(r"^LLWYD"),
    re.compile(r"^LLWYN"),
    re.compile(r"^CLWYD$"),
    re.compile(r"^AWDL"),
    re.compile(r"ABERYSTWYTH"),
    re.compile(r"ABERDOVEY"),
    re.compile(r"ABERSOCH"),
    re.compile(r"ABERTAWE"),
    re.compile(r"ABERFELDY"),
    re.compile(r"ABERGELE"),
    re.compile(r"ABERAERON"),
    re.compile(r"ABERAVON"),
    re.compile(r"ABERDARE"),
    re.compile(r"ABERDARON"),
    re.compile(r"ABERTILLY"),
    re.compile(r"^CAERNARFON"),
    re.compile(r"^PONTYPRIDD"),
    re.compile(r"^PONTYPOOL"),
    re.compile(r"PONTERWYD"),
    re.compile(r"^BANGOR$"),
    re.compile(r"^BRYN$"),
    re.compile(r"^BRYNS$"),
    re.compile(r"^GWYN$"),
    re.compile(r"^GWYNS$"),
    re.compile(r"^GLYN$"),
    re.compile(r"^GLYNS$"),
    re.compile(r"^DAFYDD"),
    re.compile(r"^MYRDDIN"),
    re.compile(r"^SIAN$"),
    re.compile(r"^SION$"),
    re.compile(r"^IAGO$"),
    re.compile(r"^IFAN$"),
    re.compile(r"^RHYS$"),
    re.compile(r"^OWAIN"),
    re.compile(r"^GRUFFYDD"),
    re.compile(r"^GWENLLIAN"),
    re.compile(r"^BLYTH$"),
    re.compile(r"PENDRAGON"),
    re.compile(r"FFESTINIOG"),
    re.compile(r"^LLEYN$"),
    re.compile(r"^PWLL"),
    re.compile(r"^TYDDYN"),
    re.compile(r"^YNYS"),
    re.compile(r"^COLWYN$"),
    re.compile(r"^DILWYN$"),
    re.compile(r"^TOWYN$"),
    re.compile(r"^WELWYN$"),
    re.compile(r"^FFERM"),
    re.compile(r"^FFALD"),
    re.compile(r"^GWLAN"),
]


def tier1_omissions(words: set[str]) -> set[str]:
    return words & (
        ad.TWO_LETTER_ABBREV_BLOCKLIST
        | ad.THREE_LETTER_ABBREV
        | ad.ACRONYMS_4PLUS
    )


def welsh_omissions(words: set[str]) -> set[str]:
    omit: set[str] = set()
    for word in words:
        if word in OBSCURE_THREE_LETTER:
            omit.add(word)
            continue
        if word.startswith("LLAN") and word not in LLAN_NOT_WELSH:
            omit.add(word)
            continue
        if word in ABER_WELSH:
            omit.add(word)
            continue
        for pattern in WELSH_REGEX:
            if pattern.search(word):
                omit.add(word)
                break
    return omit


def all_omissions(words: set[str]) -> set[str]:
    return tier1_omissions(words) | welsh_omissions(words)


def main() -> None:
    if not SOURCE.is_file():
        raise SystemExit(f"Missing source dictionary: {SOURCE}")

    words: list[str] = []
    for line in SOURCE.read_text(encoding="utf-8", errors="replace").splitlines():
        w = line.strip().upper()
        if w and w.isalpha():
            words.append(w)

    word_set = set(words)
    omit = all_omissions(word_set)
    kept_set = {w for w in words if w not in omit} | (EXTRA_INCLUSIONS - omit)
    kept = sorted(kept_set)

    OMISSION_PATH.write_text("\n".join(sorted(omit)) + "\n", encoding="utf-8")
    OUTPUT.write_text("\n".join(kept) + "\n", encoding="utf-8")

    t1 = tier1_omissions(word_set)
    welsh = welsh_omissions(word_set) - t1

    print(f"Source:  {SOURCE.name} ({len(words):,} words)")
    print(f"Omitted: {len(omit):,} -> {OMISSION_PATH.relative_to(ROOT)}")
    print(f"  Tier 1 abbrev/codes: {len(t1):,}")
    print(f"  Welsh + obscure 3-letter: {len(welsh):,}")
    print(f"Output:  {len(kept):,} -> {OUTPUT.relative_to(ROOT)}")
    print()
    print("Note: BHS is not in the source dictionary; BSC is removed.")
    checks = {
        "TV": False,
        "BSC": False,
        "CWM": False,
        "CRWTH": False,
        "LLANELLI": False,
        "CRY": True,
        "SKY": True,
        "TRY": True,
        "BE": True,
        "CAT": True,
        "GOOGLE": True,
        "JAMES": True,
        "ABERNETHY": True,
        "EID": True,
    }
    kept_set = set(kept)
    for word, should_keep in checks.items():
        ok = (word in kept_set) == should_keep
        status = "OK" if ok else "FAIL"
        print(f"  [{status}] {word}: {'kept' if word in kept_set else 'removed'}")


if __name__ == "__main__":
    main()
