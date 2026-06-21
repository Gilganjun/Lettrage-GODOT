#!/usr/bin/env python3
"""Export forenames, nicknames, and surnames found in EnglishWords5.txt."""

from __future__ import annotations

import csv
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DICT_PATH = ROOT / "dictionary" / "EnglishWords5.txt"
OUTPUT_PATH = ROOT / "dictionary" / "NamesInDictionary.txt"
OUTPUT_BY_LENGTH_PATH = ROOT / "dictionary" / "NamesInDictionaryByLength.txt"

NICKNAMES = frozenset(
    """
    ABE AL ALF ANDY ART BART BEN BERT BILL BOB BRAD BRI BRYCE BUD CAL CHAD CHARLIE
    CHAS CHUCK CLIFF CLINT COLE CONNIE DAN DAVE DON DOUG ED EDDIE ELI ERNIE FRED
    GARY GENE GREG GUS HAL HANK HARRY HAZEL HEATH HERB HOWIE IAN IGGY IRA JACK JAKE
    JAMIE JAY JEFF JEM JIM JO JOAN JOE JON JOSH JUDE KEN KIT LEE LEO LEON LES LEX
    LIAM LIZ LOU LUC LUKE MAL MALCOLM MATT MAX MEG MEL MIKE MOLLY NAT NED NICK NIK
    NORM OLLIE OZ PAT PEG PETE PHIL RAY RICK ROB ROD RON ROSS ROY RUSS RUTH SAM
    SCOTT SEAN SETH SID STAN STEVE SUE TED TESS TIM TOM TONY TRACY TREV VAL VIC
    WALT WENDY WILL WILLY ZACK ZOE
    """.split()
)

SSA_URL = "https://raw.githubusercontent.com/hadley/data-baby-names/master/baby-names.csv"
CENSUS_URL = "https://raw.githubusercontent.com/fivethirtyeight/data/master/most-common-name/surnames.csv"


def load_dictionary() -> set[str]:
    return {
        line.strip().upper()
        for line in DICT_PATH.read_text(encoding="utf-8").splitlines()
        if line.strip().isalpha()
    }


def load_ssa_forenames() -> set[str]:
    with urllib.request.urlopen(SSA_URL, timeout=60) as resp:
        text = resp.read().decode("utf-8", errors="replace")
    names: set[str] = set()
    for row in csv.DictReader(text.splitlines()):
        name = row.get("name", "").strip().upper()
        if name.isalpha():
            names.add(name)
    return names


def load_census_surnames() -> set[str]:
    with urllib.request.urlopen(CENSUS_URL, timeout=60) as resp:
        text = resp.read().decode("utf-8", errors="replace")
    names: set[str] = set()
    for row in csv.DictReader(text.splitlines()):
        name = row.get("name", "").strip().upper()
        if name.isalpha():
            names.add(name)
    return names


def sort_alphabetical(items: set[str]) -> list[str]:
    return sorted(items)


def sort_by_length(items: set[str]) -> list[str]:
    return sorted(items, key=lambda w: (len(w), w))


def write_section(lines: list[str], title: str, items: list[str], *, by_length: bool) -> None:
    lines.append("=" * 78)
    lines.append(title)
    lines.append("=" * 78)
    lines.append(f"Count: {len(items):,}")
    if by_length:
        lines.append("Sorted by word length (shortest first), then alphabetically within each length.")
    else:
        lines.append("Sorted alphabetically.")
    lines.append("")

    if by_length:
        current_len = -1
        for item in items:
            n = len(item)
            if n != current_len:
                current_len = n
                lines.append(f"--- {n} letter{'s' if n != 1 else ''} ---")
            lines.append(item)
    else:
        for item in items:
            lines.append(item)
    lines.append("")


def build_report(
    words: set[str],
    forenames: set[str],
    surnames: set[str],
    *,
    by_length: bool,
) -> list[str]:
    sort_fn = sort_by_length if by_length else sort_alphabetical
    forename_items = sort_fn(forenames)
    surname_items = sort_fn(surnames)

    sort_label = "BY WORD LENGTH" if by_length else "ALPHABETICAL"
    lines = [
        f"LETTRAGE — PERSONAL NAMES IN ENGLISHWORDS5.TXT ({sort_label})",
        f"Source dictionary: {DICT_PATH.name} ({len(words):,} words)",
        "",
        "Forenames include US SSA baby-name records plus common nicknames/diminutives.",
        "Surnames include US Census 2010 surname records present in the dictionary.",
        "Some entries are also ordinary English words (e.g. GRACE, GRANT, MAY).",
        "",
    ]

    write_section(lines, "FORENAMES (INCLUDING NICKNAMES)", forename_items, by_length=by_length)
    write_section(lines, "SURNAMES", surname_items, by_length=by_length)
    lines.append("END OF FILE")
    return lines


def main() -> None:
    if not DICT_PATH.is_file():
        raise SystemExit(f"Dictionary missing: {DICT_PATH}")

    words = load_dictionary()
    ssa = load_ssa_forenames()
    census = load_census_surnames()

    forenames = words & (ssa | NICKNAMES)
    surnames = words & census

    OUTPUT_PATH.write_text(
        "\n".join(build_report(words, forenames, surnames, by_length=False)) + "\n",
        encoding="utf-8",
    )
    OUTPUT_BY_LENGTH_PATH.write_text(
        "\n".join(build_report(words, forenames, surnames, by_length=True)) + "\n",
        encoding="utf-8",
    )

    print(f"Wrote {OUTPUT_PATH}")
    print(f"Wrote {OUTPUT_BY_LENGTH_PATH}")
    print(f"  Forenames + nicknames: {len(forenames):,}")
    print(f"  Surnames: {len(surnames):,}")


if __name__ == "__main__":
    main()
