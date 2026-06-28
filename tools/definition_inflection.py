"""Build player-friendly glosses for inflected word forms from base-word definitions."""

from __future__ import annotations

import re
from typing import Callable

from definition_anomaly import (
    _BAD_INHERITED_BODY_RE,
    _INHERITED_PREFIX_RE,
    is_anomalous_primary,
    is_weak_inflection_gloss,
    parse_meta_inflection,
    should_replace_with_inherited,
)
from definition_common import clean_tsv_field

_POS_TAIL_RE = re.compile(r"\s*[—–-]\s*(?:n|v|adj|adv|prep|conj|int)\.?\s*.*$", re.I)
_INLINE_MAX = 64


def morph_base_candidates(word: str) -> list[str]:
    w = word.upper()
    out: list[str] = []

    def add(candidate: str) -> None:
        candidate = candidate.upper()
        if len(candidate) >= 2 and candidate not in out:
            out.append(candidate)

    if len(w) > 4 and w.endswith("ING"):
        add(w[:-3])
        if len(w) > 5 and w[-4] == w[-5]:
            add(w[:-4])
    if len(w) > 4 and w.endswith("IED"):
        add(w[:-3] + "Y")
    elif len(w) > 4 and w.endswith("ED"):
        if w.endswith("ATED") and len(w) > 5:
            add(w[:-1])
        add(w[:-2])
        if len(w) > 5 and w[-3] == w[-4]:
            add(w[:-3])
    if len(w) > 3 and w.endswith("ES"):
        add(w[:-2])
        add(w[:-1])
    elif len(w) > 3 and w.endswith("S") and not w.endswith("SS"):
        add(w[:-1])
    if w.endswith("GLASSES") and len(w) > 7:
        add(w[:-2])
    return out


def infer_form(word: str, base: str) -> str:
    w = word.upper()
    if w.endswith("ING"):
        return "ing"
    if w.endswith("ED") or w.endswith("EN"):
        return "past"
    if w.endswith("S"):
        if w.endswith("ES") or (len(w) > len(base) and w == base + "S"):
            if w.endswith("ES") or w[:-1] == base:
                return "plural" if w != base + "S" or len(w) > len(base) + 1 else "third"
        return "third"
    return "past"


def _shorten_inline(gloss: str, max_len: int = _INLINE_MAX) -> str:
    text = clean_tsv_field(gloss)
    text = _POS_TAIL_RE.sub("", text)
    text = re.sub(r"\(\s*foll\.[^)]*\)", "", text, flags=re.I)
    text = re.split(r"\.\s*[Bb]\s+", text, maxsplit=1)[0]
    text = re.sub(r"\s*\([^)]*\)\s*$", "", text).strip(" .;,")
    text = re.sub(r"^\s*a\s+", "", text, flags=re.I)
    if not text:
        return ""
    if len(text) <= max_len:
        return text[0].lower() + text[1:] if text[0].isupper() else text
    cut = text[: max_len + 1]
    if " " in cut:
        cut = cut.rsplit(" ", 1)[0]
    cut = cut.rstrip(".,;:").strip()
    if not cut:
        return text[:max_len].rstrip(".,;:")
    return cut[0].lower() + cut[1:] if cut[0].isupper() else cut


def format_inherited_gloss(form: str, base: str, base_definition: str) -> str:
    short = _shorten_inline(base_definition)
    if not short:
        return ""
    base_label = base.lower()
    if form == "plural":
        return f"Plural of {base_label}: {short}"
    if form == "past":
        return f"Past tense of {base_label}: {short}"
    if form == "ing":
        return f"-ING form of {base_label}: {short}"
    return f"Form of {base_label} (he/she): {short}"


def try_build_inflected_gloss(
    word: str,
    gloss: str,
    comprehensive: dict[str, list[str]],
    base_primary_fn: Callable[[str], str],
) -> str | None:
    meta = parse_meta_inflection(gloss)
    candidates: list[tuple[str, str]] = []
    if meta:
        candidates.append(meta)
    elif should_replace_with_inherited(word, gloss):
        for base in morph_base_candidates(word):
            if base == word or base not in comprehensive:
                continue
            candidates.append((infer_form(word, base), base))
    else:
        return None

    seen: set[str] = set()
    for form, base in candidates:
        if base in seen or base == word:
            continue
        seen.add(base)
        base_primary = base_primary_fn(base)
        if not base_primary:
            continue
        inherited = format_inherited_gloss(form, base, base_primary)
        if inherited and not is_anomalous_primary(word, inherited):
            return inherited
    return None
