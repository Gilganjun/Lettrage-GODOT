#!/usr/bin/env python3
from __future__ import annotations

import re
from pathlib import Path

from definition_common import decode_senses
from definition_ranking import serious_primary_issues

ROOT = Path(__file__).resolve().parent.parent
MAIN = ROOT / "dictionary" / "DefinitionsMain.txt"
COMP = Path(r"C:\Lettrage\Dictionary\DefinitionsComprehensive.txt")


def load_comp() -> dict[str, list[str]]:
    lookup: dict[str, list[str]] = {}
    for line in COMP.read_text(encoding="utf-8").splitlines():
        if "\t" not in line:
            continue
        word, payload = line.split("\t", 1)
        lookup[word.strip().upper()] = decode_senses(payload)
    return lookup


def bucket_word(word: str, primary: str) -> str | None:
    if "participle_form" not in serious_primary_issues(word, primary):
        return None
    lowered = primary.lower()
    if re.search(r"\b(?:present participle|gerund) of\b", lowered):
        return "ING"
    if re.search(r"\b(?:past participle|simple past and past participle) of\b", lowered):
        return "ED"
    if lowered.startswith("plural of "):
        return "S"
    if "third-person singular" in lowered:
        return "THIRD"
    if word.endswith("ING"):
        return "ING"
    if word.endswith("ED"):
        return "ED"
    return "OTHER"


def main() -> None:
    comp = load_comp()
    examples: dict[str, list[tuple[str, list[str], list[str]]]] = {
        "ING": [],
        "ED": [],
        "S": [],
        "THIRD": [],
    }

    for line in MAIN.read_text(encoding="utf-8").splitlines():
        if "\t" not in line:
            continue
        word, payload = line.split("\t", 1)
        word = word.strip().upper()
        senses = decode_senses(payload)
        if not senses:
            continue
        key = bucket_word(word, senses[0])
        if not key or key not in examples or len(examples[key]) >= 6:
            continue
        examples[key].append((word, senses, comp.get(word, [])))

    titles = {
        "ING": "-ING words whose primary is “present participle / gerund of …”",
        "ED": "-ED words whose primary is “past participle of …”",
        "S": "-S words whose primary is “plural of …”",
        "THIRD": "Verb -S forms whose primary is “third-person singular of …”",
    }

    for key, title in titles.items():
        print("=" * 72)
        print(title)
        print("=" * 72)
        for word, top3, comprehensive in examples[key]:
            print(f"\n{word}")
            print(f"  Primary (Top 3 #1): {top3[0]}")
            if len(top3) > 1:
                print(f"  Top 3 #2–3:         {' | '.join(top3[1:])}")
            if comprehensive:
                print(f"  All comprehensive:  {' | '.join(comprehensive[:5])}")
            else:
                print("  All comprehensive:  (none)")
        print()


if __name__ == "__main__":
    main()
