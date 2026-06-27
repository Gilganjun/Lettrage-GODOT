"""Shared helpers for building the game definition dictionary."""

from __future__ import annotations

import re
import unicodedata

MAX_DEFINITION_LEN = 80
MAX_SENSES_PER_WORD = 10
SENSE_DELIMITER = "|"

_POS_PREFIX = re.compile(
    r"^(?:—|n\.|v\.|adj\.|adv\.|prep\.|conj\.|int\.|abbr\.|prefix|suffix|predic\.|symb\.)\s*",
    re.I,
)
_WS = re.compile(r"\s+")
_ETYM_SUFFIX = re.compile(r"\s*\[[^\]]+\]\s*$")
_LEADING_PAREN = re.compile(r"^\([^)]*\)\s*")
_NUMBERED_SPLIT = re.compile(r"\s+(?=\d+\s+)")
_INITIALISM_RE = re.compile(r"^initialism of\b", re.I)
_ABBREV_RE = re.compile(r"^abbreviation of\b", re.I)
_PAPER_SIZE_RE = re.compile(r"^paper size,?\s+\d", re.I)


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


def strip_display_prefixes(text: str) -> str:
    text = clean_tsv_field(text)
    while text.startswith("("):
        trimmed = _LEADING_PAREN.sub("", text, count=1).strip()
        if trimmed == text:
            break
        text = trimmed
    text = re.sub(r"^\d+\s+", "", text)
    text = _POS_PREFIX.sub("", text)
    return text.strip()


def is_cross_reference_gloss(text: str) -> bool:
    return text.strip().startswith("=")


def is_paper_size_gloss(text: str) -> bool:
    return bool(_PAPER_SIZE_RE.search(text.strip()))


def is_abbreviation_gloss(text: str, pos_marker: str = "") -> bool:
    if is_cross_reference_gloss(text):
        return True
    marker = pos_marker.lower()
    if "abbr" in marker or "symb" in marker:
        return True
    lowered = text.lower().strip()
    if _INITIALISM_RE.search(lowered) or _ABBREV_RE.search(lowered):
        return True
    if lowered.startswith("abbrev.") or lowered.startswith("symb."):
        return True
    return False


def split_numbered_senses(text: str) -> list[str]:
    text = strip_display_prefixes(text)
    if not text:
        return []
    parts = _NUMBERED_SPLIT.split(text)
    numbered_out: list[str] = []
    other_out: list[str] = []
    for part in parts:
        raw = part.strip()
        if not raw:
            continue
        is_numbered = bool(re.match(r"^\d+\s", raw))
        cleaned = re.sub(r"^\d+\s*", "", raw).rstrip(".")
        if cleaned:
            if is_numbered:
                numbered_out.append(cleaned)
            else:
                other_out.append(cleaned)
    if numbered_out:
        return numbered_out
    return other_out if other_out else [text]


def shorten_definition(text: str, max_len: int = MAX_DEFINITION_LEN) -> str:
    text = strip_display_prefixes(text)
    if not text:
        return ""
    if len(text) <= max_len:
        return text
    cut = text[: max_len - 1]
    if " " in cut:
        cut = cut.rsplit(" ", 1)[0]
    return cut.rstrip(".,;:") + "…"


def encode_senses(senses: list[str]) -> str:
    return SENSE_DELIMITER.join(senses)


def decode_senses(payload: str) -> list[str]:
    if not payload.strip():
        return []
    return [part.strip() for part in payload.split(SENSE_DELIMITER) if part.strip()]
