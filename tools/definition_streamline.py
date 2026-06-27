"""Shorten dictionary glosses for on-screen display and simpler reading."""

from __future__ import annotations

import re

from definition_common import (
    MAX_DEFINITION_LEN,
    SENSE_DELIMITER,
    clean_tsv_field,
    strip_display_prefixes,
)

STREAMLINED_MAX_LEN = 48

_FILLER_RE = re.compile(
    r"\b(?:colloq|esp|e\.g|etc|i\.e|viz|cf|foll|predic|often offens|offens|abbr|symb)\.?\s*",
    re.I,
)
_ORPHAN_PUNCT_RE = re.compile(r",\s*\.(\s*)")
_DOUBLE_PUNCT_RE = re.compile(r"\s+\.\s+")
_POS_TAIL_RE = re.compile(r"\s*[—–-]\s*(?:n|v|adj|adv|prep|conj|int)\.?\s*$", re.I)
_ENUM_SPLIT_RE = re.compile(r"\.\s*[Bb]\s+")
_EXAMPLE_PAREN_RE = re.compile(r"\([^)]{8,}\)")
_TRAILING_CLAUSE_RE = re.compile(r"\s*[;,]\s*(?:especially|particularly|including|such as|e\.g\.).*$", re.I)
_ARTICLE_VERB_RE = re.compile(r"^(?:a|an)\s+(?=[a-z]{3,}\b)", re.I)
_MULTI_SPACE_RE = re.compile(r"\s+")

_SIMPLE_REPLACEMENTS: list[tuple[re.Pattern[str], str]] = [
    (re.compile(r"\butiliz(?:e|es|ed|ing)\b", re.I), "use"),
    (re.compile(r"\bcommenc(?:e|es|ed|ing)\b", re.I), "start"),
    (re.compile(r"\bapproximately\b", re.I), "about"),
    (re.compile(r"\bnumerous\b", re.I), "many"),
    (re.compile(r"\bsufficient\b", re.I), "enough"),
    (re.compile(r"\bfrequently\b", re.I), "often"),
    (re.compile(r"\bimmediately\b", re.I), "at once"),
    (re.compile(r"\bnevertheless\b", re.I), "still"),
    (re.compile(r"\btherefore\b", re.I), "so"),
    (re.compile(r"\bindividual\b", re.I), "person"),
    (re.compile(r"\bresidence\b", re.I), "home"),
    (re.compile(r"\bestablishment\b", re.I), "place"),
    (re.compile(r"\bobtain\b", re.I), "get"),
    (re.compile(r"\bpossess(?:es|ed|ing)?\b", re.I), "have"),
    (re.compile(r"\bassist(?:s|ed|ing)?\b", re.I), "help"),
    (re.compile(r"\battempt(?:s|ed|ing)?\b", re.I), "try"),
    (re.compile(r"\brequire(?:s|d|ing)?\b", re.I), "need"),
    (re.compile(r"\bdemonstrat(?:e|es|ed|ing)\b", re.I), "show"),
    (re.compile(r"\bindicat(?:e|es|ed|ing)\b", re.I), "show"),
    (re.compile(r"\bpertaining to\b", re.I), "about"),
    (re.compile(r"\bregarding\b", re.I), "about"),
    (re.compile(r"\bdenoting\b", re.I), "meaning"),
    (re.compile(r"\bin accordance with\b", re.I), "by"),
    (re.compile(r"\bpreviously mentioned\b", re.I), "already said"),
    (re.compile(r"\bunder discussion\b", re.I), "being talked about"),
    (re.compile(r"\bconsisting of\b", re.I), "made of"),
    (re.compile(r"\bcomprising\b", re.I), "with"),
    (re.compile(r"\bterminate(?:s|d|ing)?\b", re.I), "end"),
    (re.compile(r"\bcommence\b", re.I), "start"),
    (re.compile(r"\boccurrence\b", re.I), "event"),
    (re.compile(r"\bnevertheless\b", re.I), "still"),
    (re.compile(r"\bfinancial institution\b", re.I), "bank"),
    (re.compile(r"\belectromagnetic radiation\b", re.I), "light energy"),
    (re.compile(r"\bprose story\b", re.I), "story"),
    (re.compile(r"\bfictitious prose story of book length\b", re.I), "long made-up story"),
    (re.compile(r"\bsharp explosive cry\b", re.I), "sudden loud bark"),
    (re.compile(r"\bday of the month\b", re.I), "calendar day"),
    (re.compile(r"\bnot heavy\b", re.I), "light in weight"),
    (re.compile(r"\bjust, equitable\b", re.I), "fair and just"),
    (re.compile(r"\bsecluded retreat\b", re.I), "private hideaway"),
    (re.compile(r"\bestablishment for depositing, withdrawing, and borrowing money\b", re.I), "place that keeps and lends money"),
    (re.compile(r"\bdepositing, withdrawing, and borrowing money\b", re.I), "keeping and lending money"),
]


def _trim_to_clause(text: str) -> str:
    parts = _ENUM_SPLIT_RE.split(text, maxsplit=1)
    if len(parts) > 1 and len(parts[0]) >= 12:
        return parts[0].strip()
    if ";" in text:
        head, tail = text.split(";", 1)
        if len(head) >= 12 and len(tail) > len(head):
            return head.strip()
    return text


def _apply_simple_words(text: str) -> str:
    for pattern, replacement in _SIMPLE_REPLACEMENTS:
        text = pattern.sub(replacement, text)
    return text


def _cap_length(text: str, max_len: int = STREAMLINED_MAX_LEN) -> str:
    if len(text) <= max_len:
        return text
    cut = text[: max_len - 1]
    if " " in cut:
        cut = cut.rsplit(" ", 1)[0]
    return cut.rstrip(".,;:") + "…"


def streamline_definition(text: str, max_len: int = STREAMLINED_MAX_LEN) -> str:
    text = strip_display_prefixes(text)
    if not text:
        return ""
    text = _FILLER_RE.sub(" ", text)
    text = _ORPHAN_PUNCT_RE.sub(",", text)
    text = _DOUBLE_PUNCT_RE.sub(" ", text)
    text = _POS_TAIL_RE.sub("", text)
    text = _TRAILING_CLAUSE_RE.sub("", text)
    text = _EXAMPLE_PAREN_RE.sub("", text)
    text = _trim_to_clause(text)
    text = _apply_simple_words(text)
    text = _ARTICLE_VERB_RE.sub("", text)
    text = clean_tsv_field(text)
    text = _MULTI_SPACE_RE.sub(" ", text).strip(" .;,")
    if not text:
        return ""
    if text and text[0].islower():
        text = text[0].upper() + text[1:]
    return _cap_length(text, max_len)


def streamline_senses(senses: list[str]) -> list[str]:
    out: list[str] = []
    seen: set[str] = set()
    for sense in senses:
        short = streamline_definition(sense)
        if not short:
            continue
        key = short.lower()
        if key in seen:
            continue
        seen.add(key)
        out.append(short)
    return out


def encode_streamlined_senses(senses: list[str]) -> str:
    return SENSE_DELIMITER.join(streamline_senses(senses))
