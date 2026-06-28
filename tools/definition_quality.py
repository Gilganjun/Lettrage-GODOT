"""Quality checks for dictionary glosses shown to players."""

from __future__ import annotations

import re

_OXFORD_JUNK_RE = re.compile(
    r"(?:"
    r"\*[a-z0-9]+|"
    r"(?:^|\s)=\s*\*|"
    r"^\s*=\s|"
    r"objective case of \*|"
    r"pl\.?\s*of \*|"
    r"see also \*|"
    r"\(see \*|"
    r"\(cf\. \*|"
    r"related to \*|"
    r"\{\{|\}\}"
    r")",
    re.I,
)
_LATIN_ETYM_RE = re.compile(r"\[latin:", re.I)
_ELLIPSIS_END_RE = re.compile(r"(?:…|\.\.\.)$")
_BRACKET_ELLIPSIS_RE = re.compile(r"\[\s*…\s*\]")
_UNCLOSED_BRACKET_END_RE = re.compile(r"\[[^\]]*$")
_WIKI_JUNK_RE = re.compile(r"(?:\.\.\.\}|/\s*\.\.\.|^\.\.\.$|\{\{\s*|\s*\}\})")
_MID_CITATION_TRUNC_RE = re.compile(r"\)\s*…\w")
_INCOMPLETE_TRUNC_TAIL_RE = re.compile(
    r"(?:"
    r", and$|"
    r" grown for$|"
    r" a cattle$|"
    r" having an$|"
    r" ecclesiastical$|"
    r" for rope$|"
    r" counters$|"
    r" termites$|"
    r" yellowish fur$|"
    r" Apollyon and$|"
    r" Philippines grown for$|"
    r" from about$|"
    r" equal to$|"
    r" divest oneself of$|"
    r" evidence for$|"
    r" more comm$|"
    r" or to$|"
    r" used only in$|"
    r" thus, s , as in fa$|"
    r",\s*$|"
    r"\(\s*$|"
    r";\s*$|"
    r":\s*$"
    r")",
    re.I,
)


def is_oxford_junk_gloss(text: str) -> bool:
    stripped = text.strip()
    if not stripped:
        return True
    if stripped.startswith("="):
        return True
    return bool(_OXFORD_JUNK_RE.search(stripped) or _LATIN_ETYM_RE.search(stripped))


def is_incomplete_gloss(text: str) -> bool:
    stripped = text.strip()
    if not stripped:
        return True
    if _ELLIPSIS_END_RE.search(stripped):
        return True
    if _BRACKET_ELLIPSIS_RE.search(stripped):
        return True
    if _UNCLOSED_BRACKET_END_RE.search(stripped):
        return True
    if _WIKI_JUNK_RE.search(stripped):
        return True
    if _MID_CITATION_TRUNC_RE.search(stripped):
        return True
    if _INCOMPLETE_TRUNC_TAIL_RE.search(stripped):
        return True
    if "[" in stripped and stripped.endswith(","):
        return True
    return False


def is_acceptable_gloss(text: str) -> bool:
    return not is_oxford_junk_gloss(text) and not is_incomplete_gloss(text)


def filter_senses(senses: list[str]) -> list[str]:
    out: list[str] = []
    seen: set[str] = set()
    for sense in senses:
        cleaned = sense.strip()
        if not is_acceptable_gloss(cleaned):
            continue
        key = cleaned.lower()
        if key in seen:
            continue
        seen.add(key)
        out.append(cleaned)
    return out
