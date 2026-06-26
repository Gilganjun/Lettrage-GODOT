"""Shared helpers for building the game definition dictionary."""

from __future__ import annotations

import re
import unicodedata

MAX_DEFINITION_LEN = 120

_POS_PREFIX = re.compile(
    r"^(?:—|n\.|v\.|adj\.|adv\.|prep\.|conj\.|int\.|abbr\.|prefix|suffix|predic\.)\s*",
    re.I,
)
_WS = re.compile(r"\s+")
_ETYM_SUFFIX = re.compile(r"\s*\[[^\]]+\]\s*$")


def strip_accents(text: str) -> str:
    nfkd = unicodedata.normalize("NFKD", text)
    return "".join(c for c in nfkd if not unicodedata.combining(c))


def normalize_word(raw: str) -> str:
    word = strip_accents(raw.strip()).upper()
    word = re.sub(r"\d+$", "", word)
    return re.sub(r"[^A-Z]", "", word)


def clean_tsv_field(text: str) -> str:
    text = _WS.sub(" ", text.replace("\t", " ").replace("\r", " ").replace("\n", " ")).strip()
    while True:
        trimmed = _ETYM_SUFFIX.sub("", text).strip()
        if trimmed == text:
            break
        text = trimmed
    return text


def shorten_definition(text: str, max_len: int = MAX_DEFINITION_LEN) -> str:
    text = clean_tsv_field(text)
    if not text:
        return ""
    text = _POS_PREFIX.sub("", text)
    if len(text) <= max_len:
        return text
    cut = text[: max_len - 1]
    if " " in cut:
        cut = cut.rsplit(" ", 1)[0]
    return cut.rstrip(".,;:") + "…"
