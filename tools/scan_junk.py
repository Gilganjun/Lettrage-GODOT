#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from definition_common import decode_senses

patterns = {
    "bracket_ellipsis": re.compile(r"\[\s*…\s*\]"),
    "mid_ellipsis": re.compile(r"…"),
    "wiki_junk": re.compile(r"\.\.\.\}|/\s*\.\.\.|^\.\.\.$"),
    "unclosed_bracket": re.compile(r"\[[^\]]*$"),
    "from_about": re.compile(r" from about$", re.I),
    "equal_to": re.compile(r" equal to$", re.I),
    "oxford_star": re.compile(r"\*[a-z0-9]+", re.I),
}
paths = {
    "main": Path(__file__).resolve().parent.parent / "dictionary" / "DefinitionsMain.txt",
    "live": Path(__file__).resolve().parent.parent / "dictionary" / "Definitions.txt",
    "comp": Path(r"C:\Lettrage\Dictionary\DefinitionsComprehensive.txt"),
}

for label, path in paths.items():
    counts = {k: 0 for k in patterns}
    samples = {k: [] for k in patterns}
    for line in path.read_text(encoding="utf-8").splitlines():
        if "\t" not in line:
            continue
        word, payload = line.split("\t", 1)
        for sense in decode_senses(payload):
            for name, rx in patterns.items():
                if rx.search(sense):
                    counts[name] += 1
                    if len(samples[name]) < 4:
                        samples[name].append(f"{word}: {sense[:110]}")
    print(f"=== {label} ===")
    for key, value in counts.items():
        if value:
            print(f"  {key}: {value}")
            for sample in samples[key]:
                print(f"    - {sample}")
