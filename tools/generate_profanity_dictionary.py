#!/usr/bin/env python3
"""Build ProfanityDictionary.txt from EnglishWords4.txt using curated stems."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
EW4 = ROOT / "dictionary" / "EnglishWords4.txt"
OUT = ROOT / "dictionary" / "ProfanityDictionary.txt"

STEM_PATTERNS = [
    re.compile(r"^FUCK\w*$"),
    re.compile(r"^CUNT\w*$"),
    re.compile(r"^SHIT\w*$"),
    re.compile(r"^BITCH\w*$"),
    re.compile(r"^ASSHOLE\w*$"),
    re.compile(r"^ARSEHOLE\w*$"),
    re.compile(r"^BOLLOCK\w*$"),
    re.compile(r"^FAGGOT\w*$"),
    re.compile(r"^NIGGER\w*$"),
    re.compile(r"^PORN\w*$"),
    re.compile(r"^WHORE\w*$"),
    re.compile(r"^SLUT\w*$"),
    re.compile(r"^TWAT\w*$"),
    re.compile(r"^WANK\w*$"),
    re.compile(r"^MOTHERFUCK\w*$"),
    re.compile(r"^CLUSTERFUCK\w*$"),
    re.compile(r"^BULLSHIT\w*$"),
    re.compile(r"^DOUCHE\w*$"),
]

EXTRA_EXACT = frozenset("BASTARD BASTARDS".split())


def main() -> None:
    words = [
        line.strip().upper()
        for line in EW4.read_text(encoding="utf-8").splitlines()
        if line.strip().isalpha()
    ]
    matched: set[str] = set()
    for w in words:
        if w in EXTRA_EXACT:
            matched.add(w)
        for pat in STEM_PATTERNS:
            if pat.match(w):
                matched.add(w)
    OUT.write_text("\n".join(sorted(matched)) + "\n", encoding="utf-8")
    print(f"Wrote {len(matched)} words to {OUT}")


if __name__ == "__main__":
    main()
