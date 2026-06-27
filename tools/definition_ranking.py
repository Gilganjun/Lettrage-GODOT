"""Game-focused Top 3 sense selection from collected dictionary entries."""

from __future__ import annotations

import re
from dataclasses import dataclass

from definition_common import MAX_SENSES_TOP3, decode_senses, is_abbreviation_gloss

_LETTER_RE = re.compile(
    r"\b(?:"
    r"(?:first|second|third|fourth|fifth|sixth|seventh|eighth|ninth|tenth|"
    r"eleventh|twelfth|thirteenth|fourteenth|fifteenth|sixteenth|"
    r"seventeenth|eighteenth|nineteenth|twentieth|twenty[- ]first|twenty[- ]second|"
    r"twenty[- ]third|twenty[- ]fourth|twenty[- ]fifth|twenty[- ]sixth)"
    r"\s+(?:letter|numeral)|"
    r"letter\s+of\s+the\s+alphabet|"
    r"alphabet(?:ical)?\s+letter"
    r")\b",
    re.I,
)
_PRONOUN_RE = re.compile(
    r"\b(?:pronoun|first[- ]person|second[- ]person|third[- ]person|"
    r"personal\s+pronoun|objective\s+case|subjective\s+case)\b",
    re.I,
)
_ARTICLE_RE = re.compile(
    r"\b(?:indefinite\s+article|definite\s+article|before\s+a\s+(?:noun|consonant|vowel))\b",
    re.I,
)
_ROMAN_NUMERAL_RE = re.compile(
    r"\b(?:roman\s+numeral|numeral\s+for\s+(?:one|five|ten|fifty|hundred|five\s+hundred|thousand)|"
    r"as\s+a\s+roman\s+numeral)\b",
    re.I,
)
_GAME_PRIORITY_RE = {
    "BANK": re.compile(r"\b(?:deposit|withdraw|borrow|money|financial|cheque|check)\b", re.I),
    "BARK": re.compile(r"\b(?:dog|fox|yelp|woof)\b", re.I),
    "DATE": re.compile(r"\b(?:day\s+of\s+the\s+month|calendar|year|appointment|romantic)\b", re.I),
    "LIGHT": re.compile(r"\b(?:not\s+heavy|weight|pale|blond|blonde)\b", re.I),
    "FAIR": re.compile(r"\b(?:just|equitable|funfair|carnival|market|blond|blonde)\b", re.I),
    "CRACK": re.compile(r"\b(?:joke|wisecrack|split|break|open)\b", re.I),
    "BE": re.compile(r"\b(?:exist|occur|take\s+place|equal|cost|remain)\b", re.I),
    "THE": re.compile(r"\b(?:definite\s+article|before\s+a\s+noun|already\s+mentioned|unique)\b", re.I),
}
_COMMON_VERB_RE = re.compile(
    r"\b(?:exist|occur|take\s+place|happen|cost|equal|remain|become)\b",
    re.I,
)
_OBSCURE_RE = re.compile(
    r"(?:"
    r"^initialism of\b|"
    r"^abbreviation of\b|"
    r"^\{\{|\}\}$|"
    r"^plural of\b|"
    r"^third-person singular\b|"
    r"^present participle of\b|"
    r"^past participle of\b|"
    r"^gerund of\b|"
    r"\bparticiple of\b|"
    r"\b(?:present|past) participle(?: and gerund)? of\b|"
    r"\bgerund of\b|"
    r"\balternative (?:form|spelling) of\b|"
    r"\b(?:paladin|palestinian)\b|"
    r"\bvagina\b|"
    r"\b(?:ångström|angstrom|ampere|nonmetallic|halogen|isotope|"
    r"nucleotide|nucleoside|blood\s+type|vitamin\s+[a-z]\b(?!\)|,)|"
    r"latin\s+script|script\s+letter|name\s+of\s+the\s+letter|"
    r"obsolete|archaic|dialect|historical|rare|technical\s+term|"
    r"paper\s+size|unit\s+of\s+(?:length|mass|electric|magnetic|"
    r"capacitance|conductance|inductance|luminance|illuminance))"
    r")",
    re.I,
)
_CHEMISTRY_RE = re.compile(
    r"\b(?:element|atomic|chemical|molecule|compound|ion|isotope|"
    r"dna|rna|nucleotide|nucleoside|adenine|thymine|guanine|cytosine|"
    r"beryllium|iodine|ferrous|valence)\b",
    re.I,
)
_SYMBOL_ONLY_RE = re.compile(r"^\d+$|^[a-z]$", re.I)
_COMPARE_PUNCT_RE = re.compile(r"[^\w\s]", re.UNICODE)
_CORE_PREFIX_RE = re.compile(
    r"^(?:the\s+)?(?:act\s+of\s+|action\s+of\s+|process\s+of\s+|state\s+of\s+|"
    r"condition\s+of\s+|quality\s+of\s+|to\s+|capable\s+of\s+|able\s+to\s+be\s+|"
    r"having\s+the\s+|displaying\s+a\s+|such\s+that\s+the\s+)",
    re.I,
)
_DEDUP_CLUSTERS: list[tuple[str, re.Pattern[str]]] = [
    ("friendly", re.compile(r"\b(?:friends?|friendly|pals?|amicable)\b", re.I)),
    ("abundant", re.compile(r"\b(?:abundant|copious|plentiful|profuse|producing much|large in number)\b", re.I)),
    ("melt", re.compile(r"\b(?:melt\w*|molten|liquef\w*|plastic.*heat|blend.*melting|liquid.*plastic)\b", re.I)),
    ("electrical_fuse", re.compile(r"\b(?:electrical device|circuit.*fuse|flow of electrical|fail.*fuse|equip with a fuse|provide with a fuse)\b", re.I)),
    ("sea", re.compile(r"\b(?:sea|seas|ocean|marine|pelagic|thalassic)\b", re.I)),
    ("endure", re.compile(r"\b(?:endur\w*|bearable|tolerable|sufferable|borne though unpleasant)\b", re.I)),
    ("exclude", re.compile(r"\b(?:reject\w*|exclud\w*|expel\w*|blackball\w*|veto|refuse to endorse|vote against)\b", re.I)),
    ("spike_point", re.compile(r"\b(?:spikes?|spiked|sharp points?|furnished.*spikes)\b", re.I)),
    ("scholarship_money", re.compile(r"\b(?:financial award|financial aid|grant-in-aid|grant.*student)\b", re.I)),
    ("scholarship_merit", re.compile(r"\b(?:academic achievement|scholarly achievement|good scholar)\b", re.I)),
    ("scholarship_knowledge", re.compile(r"\b(?:scholarly knowledge|realm of.*learning|sum of knowledge)\b", re.I)),
    ("unengaged_marriage", re.compile(r"\b(?:not engaged|not promised in marriage|unmarried|without a partner)\b", re.I)),
    ("dispraise", re.compile(r"\b(?:disprais\w*|contempt\w*|disparag\w*|disapprobation|censure|reproach|disapproval)\b", re.I)),
    ("depilation", re.compile(r"\b(?:depilat\w*|remov\w*.*hair|void of hair|hairless|stripping hair|unhairing|pulling out.*hair)\b", re.I)),
    ("annex_building", re.compile(r"\b(?:separate.*building|added building|extends a main building|addition that extends)\b", re.I)),
    ("annex_document", re.compile(r"\b(?:addition to a document|appendix|schedule)\b", re.I)),
    ("lovers_retreat", re.compile(r"\b(?:lover\w*|illicit|sexual intercourse|secluded retreat|couple|condominium|cabin)\b", re.I)),
    ("catercorner", re.compile(r"\b(?:diagonal|catercorner|catty-corner|cattycorner|catty corner)\b", re.I)),
    ("wintergreen_plant", re.compile(r"\b(?:wintergreen|pyrola|evergreen.*plant|green all winter)\b", re.I)),
    ("underpin_support", re.compile(r"\b(?:underpin\w*|foundation|support.*masonry|basis for something)\b", re.I)),
    ("rigour_strict", re.compile(r"\b(?:rigour|rigor|strictness|harshness|strict enforcement)\b", re.I)),
    ("light_brightness", re.compile(r"\b(?:brightness|stimulates sight|natural agent|electromagnetic radiation|medium or condition|source of light)\b", re.I)),
    ("light_weight", re.compile(r"\b(?:not heavy|low in weight|light arms|light blue)\b", re.I)),
    ("novel_new", re.compile(r"\b(?:new kind|not seen before|original and|pleasantly new)\b", re.I)),
    ("novel_book", re.compile(r"\b(?:prose story|book length|fictitious prose)\b", re.I)),
]
_TOPIC_STOP = frozenset(
    "a an the of in on at to for and or but with from by as is are was were be been being "
    "that this these those it its one's one's".split()
)
_COMPARE_STOP = _TOPIC_STOP | frozenset(
    "also esp colloq often used one any each other etc having being very more most some "
    "such with than then them they their there those through during without within "
    "between among about above below form part kind type especially particularly "
    "especially person thing things something someone something".split()
)


@dataclass(frozen=True)
class SenseEntry:
    text: str
    is_abbrev: bool
    order: int
    source: str = ""


def _cluster_tags(text: str) -> set[str]:
    return {name for name, pattern in _DEDUP_CLUSTERS if pattern.search(text)}


def _normalize_compare(text: str) -> str:
    text = text.lower()
    text = re.sub(r"\[[^\]]*\]", " ", text)
    text = re.sub(r"\([^)]*\)", " ", text)
    text = _COMPARE_PUNCT_RE.sub(" ", text)
    return re.sub(r"\s+", " ", text).strip()


def _content_tokens(text: str) -> set[str]:
    return {
        word
        for word in re.findall(r"[a-z]{4,}", _normalize_compare(text))
        if word not in _COMPARE_STOP
    }


def _stem_token(word: str) -> str:
    for suffix in (
        "ation",
        "ment",
        "ness",
        "ible",
        "able",
        "ous",
        "ful",
        "less",
        "ity",
        "ies",
        "ied",
        "ing",
        "ed",
        "es",
        "s",
    ):
        if len(word) > len(suffix) + 3 and word.endswith(suffix):
            return word[: -len(suffix)]
    return word


def _stem_set(tokens: set[str]) -> set[str]:
    return {_stem_token(token) for token in tokens}


def _token_similarity(left: set[str], right: set[str]) -> float:
    if not left or not right:
        return 0.0
    overlap = left & right
    union = left | right
    jaccard = len(overlap) / len(union)
    containment = len(overlap) / min(len(left), len(right))
    return max(jaccard, containment)


def _core_phrase(text: str) -> str:
    phrase = _normalize_compare(text)
    phrase = _CORE_PREFIX_RE.sub("", phrase)
    phrase = re.sub(r"^(?:a|an|the)\s+", "", phrase)
    return phrase.strip()


def _shared_prefix(a: str, b: str, min_words: int = 3) -> bool:
    words_a = _normalize_compare(a).split()
    words_b = _normalize_compare(b).split()
    shared = min(len(words_a), len(words_b), 5)
    return shared >= min_words and words_a[:shared] == words_b[:shared]


def _core_overlap(a: str, b: str) -> bool:
    core_a = _core_phrase(a)
    core_b = _core_phrase(b)
    if not core_a or not core_b:
        return False
    shorter, longer = sorted((core_a, core_b), key=len)
    if shorter in longer and len(shorter) >= 8:
        return True
    tokens_a = _content_tokens(core_a)
    tokens_b = _content_tokens(core_b)
    return _token_similarity(tokens_a, tokens_b) >= 0.6


def _topic_tokens(text: str) -> set[str]:
    words = re.findall(r"[a-z]{3,}", text.lower())
    return {word for word in words if word not in _TOPIC_STOP}


def _is_letter_sense(text: str) -> bool:
    return bool(_LETTER_RE.search(text))


def _is_near_duplicate(a: str, b: str) -> bool:
    left = a.lower().strip()
    right = b.lower().strip()
    if left == right:
        return True
    if left in right or right in left:
        return True
    if _is_letter_sense(a) and _is_letter_sense(b):
        return True
    tags_a = _cluster_tags(a)
    tags_b = _cluster_tags(b)
    if tags_a & tags_b:
        return True
    if _shared_prefix(a, b):
        return True
    if _core_overlap(a, b):
        return True

    tokens_a = _content_tokens(a)
    tokens_b = _content_tokens(b)
    if tokens_a and tokens_b:
        if _token_similarity(tokens_a, tokens_b) >= 0.38:
            return True
        if _token_similarity(_stem_set(tokens_a), _stem_set(tokens_b)) >= 0.45:
            return True

    legacy_a = _topic_tokens(a)
    legacy_b = _topic_tokens(b)
    if legacy_a and legacy_b:
        overlap = legacy_a & legacy_b
        if overlap:
            smaller = min(len(legacy_a), len(legacy_b))
            if len(overlap) >= max(2, smaller // 2):
                return True
    return False


def _looks_unrelated_to_word(word: str, text: str) -> bool:
    if len(word) < 8:
        return False
    lowered = word.lower()
    body = text.lower()
    for length in (6, 5, 4):
        if len(lowered) >= length and lowered[:length] in body:
            return False
    return True


def is_obscure_for_game(word: str, text: str, is_abbrev: bool) -> bool:
    if is_abbrev or is_abbreviation_gloss(text):
        return True
    stripped = text.strip()
    if not stripped or _SYMBOL_ONLY_RE.match(stripped):
        return True
    if _OBSCURE_RE.search(stripped):
        return True
    if len(word) == 1 and _CHEMISTRY_RE.search(stripped):
        return True
    if len(word) <= 2 and re.search(r"\bunit of\b", stripped, re.I):
        return True
    if _looks_unrelated_to_word(word, stripped):
        return True
    return False


def _game_score(word: str, entry: SenseEntry) -> tuple[int, int]:
    text = entry.text
    score = entry.order

    if entry.is_abbrev:
        score += 500
    if entry.source == "oxford":
        score -= 40
    elif entry.source == "oewn":
        score -= 10

    if _is_letter_sense(text):
        score -= 200
    if _PRONOUN_RE.search(text):
        score -= 180
    if _ARTICLE_RE.search(text) or (
        word in {"A", "AN", "THE"} and re.search(r"\b(?:before|preceding|article)\b", text, re.I)
    ):
        score -= 170
    if _ROMAN_NUMERAL_RE.search(text):
        score -= 120
    if _COMMON_VERB_RE.search(text):
        score -= 80

    priority = _GAME_PRIORITY_RE.get(word)
    if priority and priority.search(text):
        score -= 150

    if is_obscure_for_game(word, text, entry.is_abbrev):
        score += 300
    if _CHEMISTRY_RE.search(text):
        score += 120
    if len(text) <= 3 and not _is_letter_sense(text):
        score += 80

    return (score, entry.order)


def entries_from_sense_texts(senses: list[str], source: str = "comprehensive") -> list[SenseEntry]:
    return [
        SenseEntry(
            text=sense,
            is_abbrev=is_abbreviation_gloss(sense),
            order=index,
            source=source,
        )
        for index, sense in enumerate(senses)
        if sense.strip()
    ]


def select_game_top3(word: str, entries: list[SenseEntry]) -> list[str]:
    """Pick up to three game-focused senses, deduping rephrased meanings."""
    if not entries:
        return []

    ranked = sorted(entries, key=lambda entry: _game_score(word, entry))
    chosen: list[str] = []

    for entry in ranked:
        if is_obscure_for_game(word, entry.text, entry.is_abbrev):
            continue
        if any(_is_near_duplicate(entry.text, kept) for kept in chosen):
            continue
        chosen.append(entry.text)
        if len(chosen) >= MAX_SENSES_TOP3:
            break

    if chosen:
        return chosen[:MAX_SENSES_TOP3]

    for entry in ranked:
        if any(_is_near_duplicate(entry.text, kept) for kept in chosen):
            continue
        chosen.append(entry.text)
        if len(chosen) >= MAX_SENSES_TOP3:
            break
    return chosen[:MAX_SENSES_TOP3]


def select_game_top3_from_senses(word: str, senses: list[str]) -> list[str]:
    """Build Top 3 from an ordered comprehensive sense list."""
    return select_game_top3(word, entries_from_sense_texts(senses))
