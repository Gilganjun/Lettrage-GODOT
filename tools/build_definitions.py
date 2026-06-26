#!/usr/bin/env python3
"""Build dictionary/Definitions.txt from Oxford, OEWN, Kaikki, and GCIDE."""

from __future__ import annotations

import argparse
import gzip
import json
import re
import shutil
import sys
import tarfile
import tempfile
import urllib.request
import zipfile
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

from definition_common import clean_tsv_field, normalize_word, shorten_definition

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
REPORT_PATH = ROOT / "reports" / "DEFINITIONS_BUILD_REPORT.txt"
CACHE_DIR = ROOT / "dictionary" / "cache"

OEWN_URL = "https://en-word.net/static/english-wordnet-2025-json.zip"
KAIKKI_URL = "https://kaikki.org/dictionary/English/kaikki.org-dictionary-English.jsonl.gz"
GCIDE_URL = "https://ftp.gnu.org/gnu/gcide/gcide-0.54.tar.gz"

OXFORD_POS = re.compile(
    r"\s{2,}(?:—|n\.|v\.|adj\.|adv\.|prep\.|conj\.|int\.|abbr\.|prefix|suffix|predic\.)",
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
KAIKKI_SKIP_TAG_RE = re.compile(
    r"given-name|male-given-name|female-given-name|surname|family-name|patronymic|"
    r"matronymic|place-name|toponym|forename",
    re.I,
)

GCIDE_HW = re.compile(r"^<hw>([^<]+)</hw>", re.I | re.M)
GCIDE_DEF = re.compile(r"<def>(.*?)</def>", re.I | re.S)


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


def missing_words(all_words: list[str], defs: dict[str, str]) -> set[str]:
    return {w for w in all_words if w not in defs}


def add_defs(
    defs: dict[str, str],
    sources: dict[str, str],
    new_items: dict[str, str],
    source_name: str,
) -> int:
    added = 0
    for word, definition in new_items.items():
        if word in defs or not definition:
            continue
        defs[word] = definition
        sources[word] = source_name
        added += 1
    return added


def parse_oxford(needed: set[str]) -> dict[str, str]:
    if not OXFORD_PATH.is_file():
        return {}
    out: dict[str, str] = {}
    for line in OXFORD_PATH.read_text(encoding="utf-8", errors="replace").splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("-"):
            continue
        match = OXFORD_POS.search(stripped)
        if not match:
            continue
        raw = stripped[: match.start()].strip()
        word = normalize_word(raw)
        if not word or word not in needed:
            continue
        body = stripped[match.end() :].strip()
        body = re.sub(r"\x7f.*", "", body).strip()
        definition = shorten_definition(body)
        if definition and word not in out:
            out[word] = definition
    return out


def parse_oewn(zip_path: Path, needed: set[str]) -> dict[str, str]:
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

        out: dict[str, str] = {}
        for name in archive.namelist():
            if not name.startswith("entries-") or not name.endswith(".json"):
                continue
            entries = json.loads(archive.read(name))
            for lemma, poses in entries.items():
                word = normalize_word(lemma)
                if not word or word not in needed or word in out:
                    continue
                if not isinstance(poses, dict):
                    continue
                for pos_data in poses.values():
                    if not isinstance(pos_data, dict):
                        continue
                    for sense in pos_data.get("sense", []):
                        synset_id = sense.get("synset", "")
                        gloss = synsets.get(synset_id, "")
                        if gloss:
                            out[word] = gloss
                            break
                    if word in out:
                        break
    return out


def kaikki_gloss(entry: dict) -> str:
    for sense in entry.get("senses") or []:
        if not isinstance(sense, dict):
            continue
        tags = sense.get("tags") or []
        if any(KAIKKI_SKIP_TAG_RE.search(str(tag)) for tag in tags):
            continue
        glosses = sense.get("glosses") or []
        if glosses:
            return shorten_definition(str(glosses[0]))
    return ""


def parse_kaikki(gz_path: Path, needed: set[str]) -> dict[str, str]:
    out: dict[str, str] = {}
    with gzip.open(gz_path, "rt", encoding="utf-8") as handle:
        for line_no, line in enumerate(handle, 1):
            if line_no % 500_000 == 0:
                print(f"    kaikki line {line_no:,}, matched {len(out):,}")
            if len(out) >= len(needed):
                break
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
            except json.JSONDecodeError:
                continue
            if entry.get("lang_code") not in (None, "en"):
                continue
            pos = str(entry.get("pos", "")).lower()
            if pos in KAIKKI_SKIP_POS:
                continue
            word = normalize_word(str(entry.get("word", "")))
            if not word or word not in needed or word in out:
                continue
            definition = kaikki_gloss(entry)
            if definition:
                out[word] = definition
    return out


def parse_gcide(tar_path: Path, needed: set[str]) -> dict[str, str]:
    out: dict[str, str] = {}
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
                if not word or word not in needed or word in out:
                    continue
                raw_def = re.sub(r"<[^>]+>", " ", def_match.group(1))
                definition = shorten_definition(raw_def)
                if definition:
                    out[word] = definition
    return out


def write_outputs(
    all_words: list[str],
    defs: dict[str, str],
    sources: dict[str, str],
    source_counts: Counter,
) -> None:
    lines: list[str] = []
    for word in all_words:
        definition = defs.get(word, "")
        if definition:
            lines.append(f"{word}\t{clean_tsv_field(definition)}")
    OUTPUT_PATH.write_text("\n".join(lines) + "\n", encoding="utf-8")

    missing = [w for w in all_words if w not in defs]
    MISSING_PATH.write_text("\n".join(missing) + ("\n" if missing else ""), encoding="utf-8")

    report = [
        "=" * 72,
        "DEFINITIONS BUILD REPORT",
        "=" * 72,
        f"Live words:        {len(all_words):,}",
        f"Defined:           {len(defs):,} ({100 * len(defs) / len(all_words):.2f}%)",
        f"Missing:           {len(missing):,}",
        f"Output:            {OUTPUT_PATH.relative_to(ROOT)}",
        f"Missing list:      {MISSING_PATH.relative_to(ROOT)}",
        f"Output size:       {OUTPUT_PATH.stat().st_size / 1e6:.2f} MB",
        "",
        "Added by source:",
    ]
    for name, count in source_counts.most_common():
        report.append(f"  {name}: {count:,}")
    report.append("")
    report.append("Sample definitions:")
    for word in all_words[:15]:
        if word in defs:
            report.append(f"  {word}: {defs[word]} [{sources.get(word, '?')}]")
    report.append("")
    if missing:
        report.append(f"Missing sample: {', '.join(missing[:40])}")
        if len(missing) > 40:
            report.append(f"... and {len(missing) - 40:,} more")
    report.append("")
    report.append("END OF REPORT")
    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    REPORT_PATH.write_text("\n".join(report), encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description="Build Definitions.txt for Lettrage.")
    parser.add_argument("--skip-kaikki", action="store_true", help="Skip Kaikki download/parse.")
    parser.add_argument("--skip-gcide", action="store_true", help="Skip GCIDE download/parse.")
    parser.add_argument("--skip-download", action="store_true", help="Use cached downloads only.")
    args = parser.parse_args()

    if not LIVE_PATH.is_file():
        raise SystemExit(f"Missing live dictionary: {LIVE_PATH}")

    all_words = load_live_words()
    needed = set(all_words)
    defs: dict[str, str] = {}
    sources: dict[str, str] = {}
    source_counts: Counter = Counter()

    print(f"Live words: {len(all_words):,}")

    print("Oxford...")
    oxford = parse_oxford(needed)
    n = add_defs(defs, sources, oxford, "oxford")
    source_counts["oxford"] += n
    print(f"  +{n:,} ({len(defs):,} total)")

    oewn_zip = CACHE_DIR / "english-wordnet-2025-json.zip"
    if not args.skip_download:
        download(OEWN_URL, oewn_zip)
    elif not oewn_zip.is_file():
        raise SystemExit(f"Missing cached OEWN zip: {oewn_zip}")

    print("Open English WordNet...")
    oewn = parse_oewn(oewn_zip, missing_words(all_words, defs))
    n = add_defs(defs, sources, oewn, "oewn")
    source_counts["oewn"] += n
    print(f"  +{n:,} ({len(defs):,} total)")

    if not args.skip_kaikki:
        kaikki_gz = CACHE_DIR / "kaikki.org-dictionary-English.jsonl.gz"
        if not args.skip_download:
            download(KAIKKI_URL, kaikki_gz)
        elif not kaikki_gz.is_file():
            raise SystemExit(f"Missing cached Kaikki gzip: {kaikki_gz}")
        print("Kaikki (English Wiktionary)...")
        kaikki = parse_kaikki(kaikki_gz, missing_words(all_words, defs))
        n = add_defs(defs, sources, kaikki, "kaikki")
        source_counts["kaikki"] += n
        print(f"  +{n:,} ({len(defs):,} total)")

    if not args.skip_gcide:
        gcide_tar = CACHE_DIR / "gcide-0.54.tar.gz"
        if not args.skip_download:
            download(GCIDE_URL, gcide_tar)
        elif not gcide_tar.is_file():
            raise SystemExit(f"Missing cached GCIDE tarball: {gcide_tar}")
        print("GCIDE...")
        gcide = parse_gcide(gcide_tar, missing_words(all_words, defs))
        n = add_defs(defs, sources, gcide, "gcide")
        source_counts["gcide"] += n
        print(f"  +{n:,} ({len(defs):,} total)")

    write_outputs(all_words, defs, sources, source_counts)
    print()
    print(f"Defined: {len(defs):,} / {len(all_words):,}")
    print(f"Wrote {OUTPUT_PATH.relative_to(ROOT)} ({OUTPUT_PATH.stat().st_size / 1e6:.2f} MB)")
    print(f"Report: {REPORT_PATH.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
