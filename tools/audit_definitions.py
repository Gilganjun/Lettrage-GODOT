#!/usr/bin/env python3
"""Audit definition dictionaries for incomplete glosses and Oxford junk."""

from __future__ import annotations

import argparse
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

from definition_common import decode_senses
from definition_quality import is_acceptable_gloss, is_incomplete_gloss, is_oxford_junk_gloss

DEFAULT_PATHS = {
    "main": ROOT / "dictionary" / "DefinitionsMain.txt",
    "streamlined": ROOT / "dictionary" / "DefinitionsStreamlined.txt",
    "live": ROOT / "dictionary" / "Definitions.txt",
    "comprehensive": Path(r"C:\Lettrage\Dictionary\DefinitionsComprehensive.txt"),
}

_OXFORD_STAR = re.compile(r"\*[a-z0-9]+", re.I)
_OXFORD_EQ = re.compile(r"(?:^|\s)=\s*\*", re.I)
_OXFORD_XREF_PHRASE = re.compile(
    r"(?:"
    r"objective case of \*|"
    r"pl\.?\s*of \*|"
    r"see also \*|"
    r"\(see \*|"
    r"\(cf\. \*|"
    r"related to \*|"
    r"^\s*=\s*\*"
    r")",
    re.I,
)
_ELLIPSIS = re.compile(r"…$")
_DANGLING_END = re.compile(
    r"(?:"
    r", and of many$|"
    r", and of$|"
    r"\bto feel great$|"
    r"\bwith a$|"
    r"\bof a$|"
    r"\bfor a$|"
    r"\bby a$|"
    r"\bthe$|"
    r"\ba$|"
    r"\ban$|"
    r"\band$|"
    r"\bor$|"
    r"\bto$|"
    r"\bof$|"
    r"\bin$|"
    r"\bon$|"
    r"\bas$|"
    r"\bfrom$|"
    r"\bwith$|"
    r"\bwithout$|"
    r"\binto$|"
    r"\bupon$|"
    r"\babout$|"
    r"\bthrough$|"
    r"\bunder$|"
    r"\bover$|"
    r"\bnot$|"
    r"\bneither$|"
    r"\bnor$|"
    r"\bthan$|"
    r"\bthat$|"
    r"\bwhich$|"
    r"\bwho$|"
    r"\bwhom$|"
    r"\bwhose$|"
    r"\bwhen$|"
    r"\bwhere$|"
    r"\bwhile$|"
    r"\bbecause$|"
    r"\bif$|"
    r"\bbut$|"
    r"\byet$|"
    r"\bso$|"
    r"\bfor$|"
    r"\bat$|"
    r"\bby$|"
    r"\bis$|"
    r"\bare$|"
    r"\bwas$|"
    r"\bwere$|"
    r"\bbe$|"
    r"\bbeen$|"
    r"\bbeing$|"
    r"\bhave$|"
    r"\bhas$|"
    r"\bhad$|"
    r"\bdo$|"
    r"\bdoes$|"
    r"\bdid$|"
    r"\bcan$|"
    r"\bcould$|"
    r"\bmay$|"
    r"\bmight$|"
    r"\bmust$|"
    r"\bshall$|"
    r"\bshould$|"
    r"\bwill$|"
    r"\bwould$|"
    r"\betc$|"
    r"\betc\.$|"
    r"\besp$|"
    r"\besp\.$|"
    r"\bcf$|"
    r"\bcf\.$|"
    r"\be\.g$|"
    r"\be\.g\.$|"
    r"\bi\.e$|"
    r"\bi\.e\.$|"
    r"\bviz$|"
    r"\bviz\.$|"
    r"\bcolloq$|"
    r"\bcolloq\.$|"
    r"\babbr$|"
    r"\babbr\.$|"
    r"\bsymb$|"
    r"\bsymb\.$|"
    r"\bus var$|"
    r"\bus var\.$|"
    r"\bus =$|"
    r"\bus=$|"
    r"\bpoet\.$|"
    r"\bpoet$|"
    r"\bslang$|"
    r"\bslang\.$|"
    r"\battrib\.$|"
    r"\battrib$|"
    r"\banat\.$|"
    r"\banat$|"
    r"\bmath\.$|"
    r"\bmath$|"
    r"\bchess$|"
    r"\bchess\.$|"
    r"\bhist\.$|"
    r"\bhist$|"
    r"\barch\.$|"
    r"\barch$|"
    r"\btheol\.$|"
    r"\btheol$|"
    r"\bgeol\.$|"
    r"\bgeol$|"
    r"\bbot\.$|"
    r"\bbot$|"
    r"\bzool\.$|"
    r"\bzool$|"
    r"\bchem\.$|"
    r"\bchem$|"
    r"\bphys\.$|"
    r"\bphys$|"
    r"\bgram\.$|"
    r"\bgram$|"
    r"\binterrog\.$|"
    r"\binterrog$|"
    r"\bemphat\.$|"
    r"\bemphat$|"
    r"\bint\.$|"
    r"\bint$|"
    r"\badj\.$|"
    r"\badj$|"
    r"\badv\.$|"
    r"\badv$|"
    r"\bn\.$|"
    r"\bn$|"
    r"\bv\.$|"
    r"\bv$|"
    r"\bprep\.$|"
    r"\bprep$|"
    r"\bconj\.$|"
    r"\bconj$|"
    r"\bpron\.$|"
    r"\bpron$|"
    r"\(\s*$|"
    r",\s*$|"
    r";\s*$|"
    r":\s*$|"
    r"\(\.\.\.$|"
    r"\.\.\.$"
    r")",
    re.I,
)
_LATIN_ETYM = re.compile(r"\[latin:", re.I)
_WIKI_TEMPLATE = re.compile(r"\{\{|\}\}")


def classify_sense(sense: str) -> list[str]:
    issues: list[str] = []
    text = sense.strip()
    if not text:
        issues.append("empty")
        return issues
    if not is_acceptable_gloss(text):
        if is_oxford_junk_gloss(text):
            issues.append("oxford_junk")
        if is_incomplete_gloss(text):
            issues.append("incomplete")
        if _ELLIPSIS.search(text):
            issues.append("ellipsis_truncation")
        if _OXFORD_STAR.search(text):
            issues.append("oxford_star")
        if _OXFORD_EQ.search(text):
            issues.append("oxford_equals")
        if _OXFORD_XREF_PHRASE.search(text):
            issues.append("oxford_xref_phrase")
        if _LATIN_ETYM.search(text):
            issues.append("latin_etym")
        if _WIKI_TEMPLATE.search(text):
            issues.append("wiki_template")
        if _DANGLING_END.search(text):
            issues.append("dangling_end")
        if not issues:
            issues.append("quality_reject")
    return issues


def audit_file(path: Path) -> dict[str, object]:
    issue_counts: Counter[str] = Counter()
    examples: dict[str, list[str]] = defaultdict(list)
    words_with_issues: set[str] = set()
    total_senses = 0
    total_words = 0

    for line in path.read_text(encoding="utf-8").splitlines():
        if "\t" not in line:
            continue
        word, payload = line.split("\t", 1)
        word = word.strip().upper()
        senses = decode_senses(payload)
        if not senses:
            continue
        total_words += 1
        word_hit = False
        for sense in senses:
            total_senses += 1
            for issue in classify_sense(sense):
                issue_counts[issue] += 1
                word_hit = True
                if len(examples[issue]) < 8:
                    examples[issue].append(f"{word}: {sense[:120]}")
        if word_hit:
            words_with_issues.add(word)

    return {
        "path": str(path),
        "exists": path.is_file(),
        "total_words": total_words,
        "total_senses": total_senses,
        "words_with_issues": len(words_with_issues),
        "issue_counts": dict(issue_counts),
        "examples": dict(examples),
    }


def print_report(label: str, result: dict[str, object]) -> None:
    print(f"\n{'=' * 72}")
    print(label)
    print(f"Path: {result['path']}")
    if not result["exists"]:
        print("MISSING")
        return
    print(f"Words: {result['total_words']:,}  Senses: {result['total_senses']:,}")
    print(f"Words with any issue: {result['words_with_issues']:,}")
    counts: dict[str, int] = result["issue_counts"]  # type: ignore[assignment]
    if not counts:
        print("No issues found.")
        return
    for issue, count in sorted(counts.items(), key=lambda item: (-item[1], item[0])):
        print(f"  {issue:24} {count:7,}")
        for sample in result["examples"].get(issue, []):  # type: ignore[union-attr]
            print(f"    - {sample}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Audit definition dictionaries.")
    parser.add_argument("--main", type=Path, default=DEFAULT_PATHS["main"])
    parser.add_argument("--streamlined", type=Path, default=DEFAULT_PATHS["streamlined"])
    parser.add_argument("--live", type=Path, default=DEFAULT_PATHS["live"])
    parser.add_argument("--comprehensive", type=Path, default=DEFAULT_PATHS["comprehensive"])
    args = parser.parse_args()

    for label, path in (
        ("MAIN (Top 3)", args.main),
        ("STREAMLINED", args.streamlined),
        ("LIVE", args.live),
        ("COMPREHENSIVE", args.comprehensive),
    ):
        print_report(label, audit_file(path))


if __name__ == "__main__":
    main()
