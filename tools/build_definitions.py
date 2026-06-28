#!/usr/bin/env python3
"""Build Top 3 and comprehensive definition dictionaries for Lettrage."""

from __future__ import annotations

import argparse
import gzip
import json
import re
import sys
import tarfile
import urllib.request
import zipfile
from collections import defaultdict
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

from definition_common import (
    MAX_SENSES_COMPREHENSIVE,
    MAX_SENSES_TOP3,
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
from definition_quality import is_acceptable_gloss, is_oxford_junk_gloss
from definition_ranking import SenseEntry, select_game_top3

LIVE_PATH = ROOT / "dictionary" / "EnglishWords5.txt"
OXFORD_PATH = (
    ROOT
    / "dictionary"
    / "Dictionary_New"
    / "f7b7aca357778972040234cae7985db8-12d25c63f58daa5355c19b5b2270c200dee46a86"
    / "Oxford-Word-List-With-Definition.txt"
)
DEFAULT_OUTPUT_DIR = Path(r"C:\Lettrage\Dictionary")
PROJECT_OUTPUT_DIR = ROOT / "dictionary"
TOP3_FILENAME = "DefinitionsTop3.txt"
COMPREHENSIVE_FILENAME = "DefinitionsComprehensive.txt"
MISSING_FILENAME = "DefinitionsMissing.txt"
ABBREV_ONLY_FILENAME = "AbbrevOnlyRemovals.txt"
REPORT_FILENAME = "DEFINITIONS_BUILD_REPORT.txt"

OEWN_URL = "https://en-word.net/static/english-wordnet-2025-json.zip"
KAIKKI_URL = "https://kaikki.org/dictionary/English/kaikki.org-dictionary-English.jsonl.gz"
GCIDE_URL = "https://ftp.gnu.org/gnu/gcide/gcide-0.54.tar.gz"

OXFORD_POS = re.compile(
    r"\s{2,}(?:—|n\.|v\.|adj\.|adv\.|prep\.|conj\.|int\.|pron\.|abbr\.|prefix|suffix|predic\.|symb\.)",
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
    senses: dict[str, list[SenseEntry]] = field(default_factory=lambda: defaultdict(list))
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
        if is_oxford_junk_gloss(text):
            return
        short = shorten_definition(text)
        if not short or not is_acceptable_gloss(short):
            return
        key = short.lower()
        if key in self._seen[word]:
            return
        self._seen[word].add(key)
        order = self._order[word]
        self._order[word] += 1
        self.senses[word].append(SenseEntry(short, is_abbrev, order, source))
        if word not in self.sources:
            self.sources[word] = source

    def add_many(self, word: str, texts: list[str], is_abbrev: bool, source: str) -> None:
        for text in texts:
            self.add(word, text, is_abbrev, source)

    def finalize(
        self,
    ) -> tuple[dict[str, list[str]], dict[str, list[str]], set[str]]:
        comprehensive: dict[str, list[str]] = {}
        top3: dict[str, list[str]] = {}
        abbrev_only: set[str] = set()
        sorted_entries: dict[str, list[SenseEntry]] = {}
        for word, entries in self.senses.items():
            entries.sort(key=lambda item: (item.is_abbrev, item.order))
            sorted_entries[word] = entries
            ordered = [entry.text for entry in entries]
            if ordered:
                comprehensive[word] = ordered[:MAX_SENSES_COMPREHENSIVE]
                if all(entry.is_abbrev for entry in entries):
                    abbrev_only.add(word)
        for word, entries in sorted_entries.items():
            if word in comprehensive:
                top3[word] = select_game_top3(
                    word,
                    entries,
                    comprehensive=comprehensive,
                )[:MAX_SENSES_TOP3]
        return comprehensive, top3, abbrev_only


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


def _write_dictionary(path: Path, all_words: list[str], defs: dict[str, list[str]], abbrev_only: set[str]) -> int:
    lines: list[str] = []
    for word in all_words:
        if word in abbrev_only:
            continue
        senses = defs.get(word, [])
        if senses:
            lines.append(f"{word}\t{encode_senses(senses)}")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return len(lines)


def write_outputs(
    output_dir: Path,
    all_words: list[str],
    comprehensive: dict[str, list[str]],
    top3: dict[str, list[str]],
    abbrev_only: set[str],
) -> None:
    top3_path = output_dir / TOP3_FILENAME
    comprehensive_path = output_dir / COMPREHENSIVE_FILENAME
    missing_path = output_dir / MISSING_FILENAME
    abbrev_path = output_dir / ABBREV_ONLY_FILENAME
    report_path = output_dir / REPORT_FILENAME

    top3_count = _write_dictionary(top3_path, all_words, top3, abbrev_only)
    comprehensive_count = _write_dictionary(comprehensive_path, all_words, comprehensive, abbrev_only)

    missing = [w for w in all_words if w not in comprehensive and w not in abbrev_only]
    missing_path.write_text("\n".join(missing) + ("\n" if missing else ""), encoding="utf-8")
    abbrev_path.write_text("\n".join(sorted(abbrev_only)) + ("\n" if abbrev_only else ""), encoding="utf-8")

    multi_comp = sum(1 for senses in comprehensive.values() if len(senses) > 1)
    multi_top3 = sum(1 for senses in top3.values() if len(senses) > 1)
    pilot = ("A", "I", "THE", "BE", "BANK", "BARK", "DATE", "LIGHT", "CRACK", "FAIR", "NOVEL")
    report = [
        "=" * 72,
        "DEFINITIONS BUILD REPORT",
        "=" * 72,
        f"Live words:                 {len(all_words):,}",
        f"Top 3 defined:              {top3_count:,} ({100 * top3_count / len(all_words):.2f}%)",
        f"Comprehensive defined:      {comprehensive_count:,} ({100 * comprehensive_count / len(all_words):.2f}%)",
        f"Top 3 multi-sense:          {multi_top3:,}",
        f"Comprehensive multi-sense:  {multi_comp:,}",
        f"Abbrev-only drops:           {len(abbrev_only):,}",
        f"Missing:                    {len(missing):,}",
        f"Top 3 output:               {top3_path} ({top3_path.stat().st_size / 1e6:.2f} MB)",
        f"Comprehensive output:       {comprehensive_path} ({comprehensive_path.stat().st_size / 1e6:.2f} MB)",
        "",
        "Pilot Top 3 samples:",
    ]
    for sample in pilot:
        if sample in top3:
            report.append(f"  {sample}: {' | '.join(top3[sample])}")
    report.extend(["", "Comprehensive samples:"])
    for sample in ("HE", "CAT", "ABANDON", "AARDVARK"):
        if sample in comprehensive:
            report.append(f"  {sample}: {' | '.join(comprehensive[sample][:4])}")
    if abbrev_only:
        report.append("")
        report.append(f"Abbrev-only sample: {', '.join(sorted(abbrev_only)[:30])}")
    report_path.write_text("\n".join(report) + "\n", encoding="utf-8")


def copy_to_project(output_dir: Path) -> None:
    top3_src = output_dir / TOP3_FILENAME
    if not top3_src.is_file():
        return
    PROJECT_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    project_top3 = PROJECT_OUTPUT_DIR / "Definitions.txt"
    project_top3.write_text(top3_src.read_text(encoding="utf-8"), encoding="utf-8")
    print(f"Copied Top 3 dictionary to {project_top3}")


def main() -> None:
    print("Definitions build starting...", flush=True)
    parser = argparse.ArgumentParser(description="Build Top 3 and comprehensive dictionaries for Lettrage.")
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    parser.add_argument("--copy-to-project", action="store_true", help="Copy Top 3 file into the Godot project.")
    parser.add_argument("--skip-kaikki", action="store_true")
    parser.add_argument("--skip-gcide", action="store_true")
    parser.add_argument("--skip-download", action="store_true")
    args = parser.parse_args()

    cache_dir = args.output_dir / "cache"
    cache_dir.mkdir(parents=True, exist_ok=True)

    all_words = load_live_words()
    collector = SenseCollector(needed=set(all_words))
    print(f"Live words: {len(all_words):,}")
    print(f"Output dir: {args.output_dir}")

    print("Oxford...")
    print(f"  +{parse_oxford(collector):,} words touched")

    oewn_zip = cache_dir / "english-wordnet-2025-json.zip"
    if not args.skip_download:
        download(OEWN_URL, oewn_zip)
    elif not oewn_zip.is_file():
        raise SystemExit(f"Missing cached OEWN zip: {oewn_zip}")
    print("Open English WordNet...")
    print(f"  +{parse_oewn(collector, oewn_zip):,} words touched")

    if not args.skip_kaikki:
        kaikki_gz = cache_dir / "kaikki.org-dictionary-English.jsonl.gz"
        if not args.skip_download:
            download(KAIKKI_URL, kaikki_gz)
        elif not kaikki_gz.is_file():
            raise SystemExit(f"Missing cached Kaikki gzip: {kaikki_gz}")
        print("Kaikki...")
        print(f"  +{parse_kaikki(collector, kaikki_gz):,} words touched")

    if not args.skip_gcide:
        gcide_tar = cache_dir / "gcide-0.54.tar.gz"
        if not args.skip_download:
            download(GCIDE_URL, gcide_tar)
        elif not gcide_tar.is_file():
            raise SystemExit(f"Missing cached GCIDE tarball: {gcide_tar}")
        print("GCIDE...")
        print(f"  +{parse_gcide(collector, gcide_tar):,} words touched")

    comprehensive, top3, abbrev_only = collector.finalize()
    write_outputs(args.output_dir, all_words, comprehensive, top3, abbrev_only)
    if args.copy_to_project:
        copy_to_project(args.output_dir)
    removed = apply_abbrev_removals(abbrev_only & set(all_words), args.output_dir)
    print(
        f"Top 3 defined: {len(top3) - len(abbrev_only):,}, "
        f"comprehensive defined: {len(comprehensive) - len(abbrev_only):,}, "
        f"abbrev-only removed from live: {removed:,}"
    )


def apply_abbrev_removals(words_to_remove: set[str], output_dir: Path) -> int:
    abbrev_path = output_dir / ABBREV_ONLY_FILENAME
    if not words_to_remove:
        abbrev_path.write_text("", encoding="utf-8")
        return 0
    kept = [w for w in load_live_words() if w not in words_to_remove]
    LIVE_PATH.write_text("\n".join(kept) + "\n", encoding="utf-8")
    return len(words_to_remove)


if __name__ == "__main__":
    main()
