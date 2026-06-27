#!/usr/bin/env python3
"""Build dictionary/Definitions.txt from Oxford, OEWN, Kaikki, and GCIDE."""

from __future__ import annotations

import argparse
import gzip
import json
import re
import sys
import tarfile
import urllib.request
import zipfile
from collections import Counter, defaultdict
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

from definition_common import (
    MAX_SENSES_PER_WORD,
    clean_tsv_field,
    encode_senses,
    is_abbreviation_gloss,
    is_cross_reference_gloss,
    is_paper_size_gloss,
    normalize_word,
    shorten_definition,
    split_numbered_senses,
    strip_display_prefixes,
)

LIVE_PATH = ROOT / "dictionary" / "EnglishWords5.txt"
OXFORD_PATH = (
    ROOT
    / "dictionary"
    / "Dictionary_New"
    / "f7b7aca357778972040234cae7985db8-12d25c63f58daa5355c19b5b2270c200dee46a86"
    / "Oxford-Word-List-With-Definition.txt"
)
OUTPUT_PATH = ROOT / "dictionary" / "Definitions.txt"
MISSING_PATH = ROOT / "dictionary" / "DefinitionsMissing.txt"
ABBREV_ONLY_PATH = ROOT / "dictionary" / "AbbrevOnlyRemovals.txt"
REPORT_PATH = ROOT / "reports" / "DEFINITIONS_BUILD_REPORT.txt"
CACHE_DIR = ROOT / "dictionary" / "cache"

OEWN_URL = "https://en-word.net/static/english-wordnet-2025-json.zip"
KAIKKI_URL = "https://kaikki.org/dictionary/English/kaikki.org-dictionary-English.jsonl.gz"
GCIDE_URL = "https://ftp.gnu.org/gnu/gcide/gcide-0.54.tar.gz"

OXFORD_POS = re.compile(
    r"\s{2,}(?:—|n\.|v\.|adj\.|adv\.|prep\.|conj\.|int\.|abbr\.|prefix|suffix|predic\.|symb\.)",
    re.I,
)

KAIKKI_SKIP_POS = frozenset(
    {
        "name",
        "proper noun",
        "proper name",
        "prefix",
        "suffix",
        "symbol",
        "punctuation",
        "character",
        "circumfix",
        "infix",
        "interfix",
    }
)
KAIKKI_ABBREV_POS = frozenset({"abbreviation", "initialism", "acronym"})
KAIKKI_SKIP_TAG_RE = re.compile(
    r"given-name|male-given-name|female-given-name|surname|family-name|patronymic|"
    r"matronymic|place-name|toponym|forename",
    re.I,
)

GCIDE_HW = re.compile(r"^<hw>([^<]+)</hw>", re.I | re.M)
GCIDE_DEF = re.compile(r"<def>(.*?)</def>", re.I | re.S)


@dataclass
class SenseCollector:
    needed: set[str]
    senses: dict[str, list[tuple[str, bool, int]]] = field(default_factory=lambda: defaultdict(list))
    _seen: dict[str, set[str]] = field(default_factory=lambda: defaultdict(set))
    _order: dict[str, int] = field(default_factory=lambda: defaultdict(int))
    sources: dict[str, str] = field(default_factory=dict)

    def add(self, word: str, text: str, is_abbrev: bool, source: str) -> None:
        if word not in self.needed or not text:
            return
        if is_cross_reference_gloss(text):
            return
        if is_paper_size_gloss(text):
            return
        short = shorten_definition(text)
        if not short:
            return
        key = short.lower()
        if key in self._seen[word]:
            return
        self._seen[word].add(key)
        order = self._order[word]
        self._order[word] += 1
        self.senses[word].append((short, is_abbrev, order))
        if word not in self.sources:
            self.sources[word] = source

    def add_many(self, word: str, texts: list[str], is_abbrev: bool, source: str) -> None:
        for text in texts:
            self.add(word, text, is_abbrev, source)

    def finalize(self) -> tuple[dict[str, list[str]], set[str]]:
        defs: dict[str, list[str]] = {}
        abbrev_only: set[str] = set()
        for word, entries in self.senses.items():
            entries.sort(key=lambda item: (item[1], item[2]))
            ordered = [text for text, _, _ in entries]
            if ordered:
                defs[word] = ordered[:MAX_SENSES_PER_WORD]
                if all(is_abbrev for _, is_abbrev, _ in entries):
                    abbrev_only.add(word)
        return defs, abbrev_only


def load_live_words() -> list[str]:
    words: list[str] = []
    for line in LIVE_PATH.read_text(encoding="utf-8").splitlines():
        word = line.strip().upper()
        if word.isalpha():
            words.append(word)
    return words


def download(url: str, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.is_file() and dest.stat().st_size > 0:
        print(f"  cache hit: {dest.name} ({dest.stat().st_size / 1e6:.1f} MB)")
        return
    print(f"  downloading {url} ...")
    tmp = dest.with_suffix(dest.suffix + ".part")
    urllib.request.urlretrieve(url, tmp)
    tmp.replace(dest)
    print(f"  saved {dest.name} ({dest.stat().st_size / 1e6:.1f} MB)")


def oxford_pos_marker(line: str, match: re.Match[str]) -> str:
    return line[match.start() : match.end()].lower()


def parse_oxford(collector: SenseCollector) -> int:
    if not OXFORD_PATH.is_file():
        return 0
    before = len(collector.senses)
    with OXFORD_PATH.open(encoding="utf-8", errors="replace") as handle:
        for line in handle:
            stripped = line.strip()
            if not stripped or stripped.startswith("-"):
                continue
            match = OXFORD_POS.search(stripped)
            if not match:
                continue
            raw = stripped[: match.start()].strip()
            word = normalize_word(raw)
            if not word or word not in collector.needed:
                continue
            marker = oxford_pos_marker(stripped, match)
            if "prefix" in marker or "suffix" in marker:
                continue
            body = stripped[match.end() :].strip()
            body = re.sub(r"\x7f.*", "", body).strip()
            is_abbrev = is_abbreviation_gloss(body, marker)
            for sense in split_numbered_senses(body):
                collector.add(word, sense, is_abbrev, "oxford")
    return len(collector.senses) - before


def parse_oewn(collector: SenseCollector, zip_path: Path) -> int:
    before = len(collector.senses)
    synsets: dict[str, str] = {}
    with zipfile.ZipFile(zip_path) as archive:
        for name in archive.namelist():
            if not name.endswith(".json") or name.startswith("entries"):
                continue
            data = json.loads(archive.read(name))
            if not isinstance(data, dict):
                continue
            for synset_id, payload in data.items():
                if not isinstance(payload, dict):
                    continue
                defs = payload.get("definition") or payload.get("gloss")
                if isinstance(defs, list) and defs:
                    synsets[synset_id] = shorten_definition(str(defs[0]))
                elif isinstance(defs, str):
                    synsets[synset_id] = shorten_definition(defs)

        for name in archive.namelist():
            if not name.startswith("entries-") or not name.endswith(".json"):
                continue
            entries = json.loads(archive.read(name))
            for lemma, poses in entries.items():
                word = normalize_word(lemma)
                if not word or not isinstance(poses, dict):
                    continue
                for pos_data in poses.values():
                    if not isinstance(pos_data, dict):
                        continue
                    for sense in pos_data.get("sense", []):
                        gloss = synsets.get(str(sense.get("synset", "")), "")
                        if gloss:
                            collector.add(word, gloss, False, "oewn")
    return len(collector.senses) - before


def kaikki_senses(entry: dict) -> list[tuple[str, bool]]:
    pos = str(entry.get("pos", "")).lower()
    if pos in KAIKKI_SKIP_POS:
        return []
    is_pos_abbrev = pos in KAIKKI_ABBREV_POS
    found: list[tuple[str, bool]] = []
    for sense in entry.get("senses") or []:
        if not isinstance(sense, dict):
            continue
        tags = [str(tag) for tag in (sense.get("tags") or [])]
        if any(KAIKKI_SKIP_TAG_RE.search(tag) for tag in tags):
            continue
        glosses = sense.get("glosses") or []
        if not glosses:
            continue
        gloss = strip_display_prefixes(str(glosses[0]))
        if not gloss:
            continue
        tag_abbrev = any(
            tag.lower() in {"abbreviation", "initialism", "acronym", "alt-of", "alternative"}
            for tag in tags
        )
        is_abbrev = is_pos_abbrev or tag_abbrev or is_abbreviation_gloss(gloss)
        for part in split_numbered_senses(gloss):
            found.append((part, is_abbrev))
    return found


def parse_kaikki(collector: SenseCollector, gz_path: Path) -> int:
    before = len(collector.senses)
    with gzip.open(gz_path, "rt", encoding="utf-8") as handle:
        for line_no, line in enumerate(handle, 1):
            if line_no % 500_000 == 0:
                print(f"    kaikki line {line_no:,}, words {len(collector.senses):,}")
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
            except json.JSONDecodeError:
                continue
            if entry.get("lang_code") not in (None, "en"):
                continue
            word = normalize_word(str(entry.get("word", "")))
            if not word or word not in collector.needed:
                continue
            for sense_text, is_abbrev in kaikki_senses(entry):
                collector.add(word, sense_text, is_abbrev, "kaikki")
    return len(collector.senses) - before


def parse_gcide(collector: SenseCollector, tar_path: Path) -> int:
    before = len(collector.senses)
    with tarfile.open(tar_path, "r:gz") as archive:
        for member in archive.getmembers():
            name = Path(member.name).name
            if not name.startswith("CIDE."):
                continue
            text = archive.extractfile(member).read().decode("utf-8", errors="replace")
            for block in re.split(r"\n\s*\n", text):
                hw_match = GCIDE_HW.search(block)
                def_match = GCIDE_DEF.search(block)
                if not hw_match or not def_match:
                    continue
                word = normalize_word(hw_match.group(1))
                if not word:
                    continue
                raw_def = re.sub(r"<[^>]+>", " ", def_match.group(1))
                collector.add(word, raw_def, False, "gcide")
    return len(collector.senses) - before


def write_outputs(
    all_words: list[str],
    defs: dict[str, list[str]],
    abbrev_only: set[str],
    sources: dict[str, str],
) -> None:
    lines: list[str] = []
    for word in all_words:
        if word in abbrev_only:
            continue
        senses = defs.get(word, [])
        if senses:
            lines.append(f"{word}\t{encode_senses(senses)}")

    OUTPUT_PATH.write_text("\n".join(lines) + "\n", encoding="utf-8")

    missing = [w for w in all_words if w not in defs and w not in abbrev_only]
    MISSING_PATH.write_text("\n".join(missing) + ("\n" if missing else ""), encoding="utf-8")
    ABBREV_ONLY_PATH.write_text("\n".join(sorted(abbrev_only)) + ("\n" if abbrev_only else ""), encoding="utf-8")

    multi = sum(1 for senses in defs.values() if len(senses) > 1)
    report = [
        "=" * 72,
        "DEFINITIONS BUILD REPORT",
        "=" * 72,
        f"Live words:        {len(all_words):,}",
        f"Defined:           {len(lines):,} ({100 * len(lines) / len(all_words):.2f}%)",
        f"Multi-sense:       {multi:,}",
        f"Abbrev-only drops:  {len(abbrev_only):,}",
        f"Missing:           {len(missing):,}",
        f"Output size:       {OUTPUT_PATH.stat().st_size / 1e6:.2f} MB",
        "",
        "Samples:",
    ]
    for sample in ("HE", "CAT", "ABANDON", "AARDVARK"):
        if sample in defs:
            report.append(f"  {sample}: {' | '.join(defs[sample][:4])}")
    if abbrev_only:
        report.append("")
        report.append(f"Abbrev-only sample: {', '.join(sorted(abbrev_only)[:30])}")
    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    REPORT_PATH.write_text("\n".join(report) + "\n", encoding="utf-8")


def main() -> None:
    print("Definitions build starting...", flush=True)
    parser = argparse.ArgumentParser(description="Build Definitions.txt for Lettrage.")
    parser.add_argument("--skip-kaikki", action="store_true")
    parser.add_argument("--skip-gcide", action="store_true")
    parser.add_argument("--skip-download", action="store_true")
    args = parser.parse_args()

    all_words = load_live_words()
    collector = SenseCollector(needed=set(all_words))
    print(f"Live words: {len(all_words):,}")

    print("Oxford...")
    print(f"  +{parse_oxford(collector):,} words touched")

    oewn_zip = CACHE_DIR / "english-wordnet-2025-json.zip"
    if not args.skip_download:
        download(OEWN_URL, oewn_zip)
    elif not oewn_zip.is_file():
        raise SystemExit(f"Missing cached OEWN zip: {oewn_zip}")
    print("Open English WordNet...")
    print(f"  +{parse_oewn(collector, oewn_zip):,} words touched")

    if not args.skip_kaikki:
        kaikki_gz = CACHE_DIR / "kaikki.org-dictionary-English.jsonl.gz"
        if not args.skip_download:
            download(KAIKKI_URL, kaikki_gz)
        elif not kaikki_gz.is_file():
            raise SystemExit(f"Missing cached Kaikki gzip: {kaikki_gz}")
        print("Kaikki...")
        print(f"  +{parse_kaikki(collector, kaikki_gz):,} words touched")

    if not args.skip_gcide:
        gcide_tar = CACHE_DIR / "gcide-0.54.tar.gz"
        if not args.skip_download:
            download(GCIDE_URL, gcide_tar)
        elif not gcide_tar.is_file():
            raise SystemExit(f"Missing cached GCIDE tarball: {gcide_tar}")
        print("GCIDE...")
        print(f"  +{parse_gcide(collector, gcide_tar):,} words touched")

    defs, abbrev_only = collector.finalize()
    write_outputs(all_words, defs, abbrev_only, collector.sources)
    removed = apply_abbrev_removals(abbrev_only & set(all_words))
    print(f"Defined: {len(defs) - len(abbrev_only):,}, abbrev-only removed from live: {removed:,}")


def apply_abbrev_removals(words_to_remove: set[str]) -> int:
    if not words_to_remove:
        ABBREV_ONLY_PATH.write_text("", encoding="utf-8")
        return 0
    kept = [w for w in load_live_words() if w not in words_to_remove]
    LIVE_PATH.write_text("\n".join(kept) + "\n", encoding="utf-8")
    return len(words_to_remove)


if __name__ == "__main__":
    main()
