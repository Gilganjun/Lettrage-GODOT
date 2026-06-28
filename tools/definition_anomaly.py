"""Detect player-unfriendly or anomalous definition glosses."""

from __future__ import annotations

import re

_INHERITED_PREFIX_RE = re.compile(
    r"^(?:Past tense of |Plural of |-ING form of |Form of )",
    re.I,
)
_META_INFLECTION_RE = re.compile(
    r"(?i)^(?:"
    r"plural of (?P<base>[a-z][a-z-']+)|"
    r"(?:simple past and )?past participle of (?P<base2>[a-z][a-z-']+)|"
    r"present participle(?: and gerund)? of (?P<base3>[a-z][a-z-']+)|"
    r"third[- ]person(?: singular)?(?: simple present indicative)? of (?P<base4>[a-z][a-z-']+)|"
    r"third[- ]person singular simple present indicative of (?P<base5>[a-z][a-z-']+)"
    r")\.?$"
)
_WEAK_FRAGMENT_RE = re.compile(
    r"(?i)^(?:"
    r"engaged in|"
    r"used in|"
    r"of or relating to|"
    r"pertaining to|"
    r"characterized by"
    r")\.?$"
)
_OXFORD_GARBAGE_RE = re.compile(
    r"(?:"
    r"\(\s*foll\.|"
    r"\(\s*By in\)|"
    r"\(\s*by in\)|"
    r"^\s*a\s+\(\s*(?:foll\.|By in|by in)|"
    r"\.\s*[Bb]\s+[a-z]|"
    r"also cal\b|"
    r"—n\.|—v\.|—adj\."
    r")",
    re.I,
)
_TRUNCATED_RE = re.compile(
    r"(?:"
    r"\(\s*(?:a|an|the|By in|by in|foll\.)\s*$|"
    r"\(\s*$|"
    r":\s*$|"
    r";\s*$|"
    r",\s*$|"
    r"\b(?:in|of|to|with|for|at|by|from|on|as|or|and)\s*$"
    r")",
    re.I,
)
_NARROW_SENSE_RE = re.compile(
    r"(?i)(?:"
    r"^close enough to be \w+ed to|"
    r"^suitable for \w+ing|"
    r"^used for \w+ing(?:\.|$)|"
    r"^capable of being \w+ed|"
    r"^fit for \w+ing|"
    r"\battributive form of|"
    r"^pl\.?\s*of \*|"
    r"credit under the \w+ scheme"
    r")"
)
_WEAK_START_RE = re.compile(
    r"(?i)^(?:"
    r"engaged in|"
    r"involved in|"
    r"associated with|"
    r"connected with|"
    r"used in|"
    r"used for|"
    r"used to|"
    r"having been|"
    r"of or relating to|"
    r"pertaining to|"
    r"characterized by|"
    r"capable of being"
    r")(?:\s|$|\.|\()"
)
_ARCHAIC_LABEL_RE = re.compile(r"\b(?:obsolete|archaic|historical|dialect|rare)\b", re.I)
_BAD_INHERITED_BODY_RE = re.compile(
    r"(?i)(?:"
    r"^plural of [a-z-']+\s*$|"
    r"^past tense of [a-z-']+\s*$|"
    r"^-ing form of [a-z-']+\s*$|"
    r": (?:"
    r"archaic spelling of|"
    r"plural of [a-z-']+|"
    r"present participle of|"
    r"past participle of|"
    r"third[- ]person"
    r")"
    r")"
)


def parse_meta_inflection(gloss: str) -> tuple[str, str] | None:
    match = _META_INFLECTION_RE.match(gloss.strip())
    if not match:
        return None
    base = (
        match.group("base")
        or match.group("base2")
        or match.group("base3")
        or match.group("base4")
        or match.group("base5")
    )
    if not base:
        return None
    lowered = gloss.strip().lower()
    if lowered.startswith("plural of "):
        return ("plural", base.upper())
    if "past participle" in lowered or lowered.startswith("simple past"):
        return ("past", base.upper())
    if "present participle" in lowered or "gerund" in lowered:
        return ("ing", base.upper())
    return ("third", base.upper())


def is_weak_inflection_gloss(gloss: str) -> bool:
    text = gloss.strip()
    if not text:
        return True
    if parse_meta_inflection(text):
        return True
    if _WEAK_FRAGMENT_RE.match(text):
        return True
    if _WEAK_START_RE.match(text):
        return True
    if len(text) < 18 and text.endswith(" in"):
        return True
    if _NARROW_SENSE_RE.search(text):
        return True
    if _OXFORD_GARBAGE_RE.search(text):
        return True
    if _TRUNCATED_RE.search(text):
        return True
    if _INHERITED_PREFIX_RE.match(text) and _BAD_INHERITED_BODY_RE.search(text):
        return True
    return False


def should_replace_with_inherited(word: str, gloss: str) -> bool:
    text = gloss.strip()
    if text.startswith(("Past tense of ", "Plural of ", "-ING form of ", "Form of ")):
        if _BAD_INHERITED_BODY_RE.search(text):
            return True
        return False
    if parse_meta_inflection(text):
        return True
    if is_weak_inflection_gloss(text):
        return True
    if _OXFORD_GARBAGE_RE.search(text):
        return True
    if _TRUNCATED_RE.search(text):
        return True
    if _NARROW_SENSE_RE.search(text):
        return True
    if _WEAK_START_RE.match(text):
        return True
    return False


def classify_anomaly(word: str, gloss: str) -> list[str]:
    text = gloss.strip()
    if not text:
        return ["empty"]

    issues: list[str] = []
    if parse_meta_inflection(text) and not _INHERITED_PREFIX_RE.match(text):
        issues.append("meta_participle")
    if is_weak_inflection_gloss(text) and not _INHERITED_PREFIX_RE.match(text):
        issues.append("weak_inflection")
    if _WEAK_START_RE.match(text) and "weak_inflection" not in issues:
        issues.append("weak_fragment")
    if _OXFORD_GARBAGE_RE.search(text):
        issues.append("oxford_garbage")
    if _TRUNCATED_RE.search(text):
        issues.append("truncated")
    if _NARROW_SENSE_RE.search(text):
        issues.append("narrow_sense")
    if _ARCHAIC_LABEL_RE.search(text):
        issues.append("archaic_label")
    if _INHERITED_PREFIX_RE.match(text) and _BAD_INHERITED_BODY_RE.search(text):
        issues.append("bad_inherited_body")
    if should_replace_with_inherited(word, text):
        issues.append("should_inherit")
    return issues


def is_anomalous_primary(word: str, gloss: str) -> bool:
    issues = classify_anomaly(word, gloss)
    blocked = {"empty", "should_inherit"}
    serious = set(issues) - blocked
    if serious:
        return True
    return "should_inherit" in issues


def anomaly_severity(issues: list[str]) -> int:
    weights = {
        "meta_participle": 10,
        "weak_inflection": 9,
        "weak_fragment": 9,
        "oxford_garbage": 8,
        "truncated": 8,
        "narrow_sense": 7,
        "bad_inherited_body": 7,
        "archaic_label": 5,
        "should_inherit": 6,
    }
    return sum(weights.get(issue, 1) for issue in issues)
