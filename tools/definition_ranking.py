"""Game-focused Top 3 sense selection from collected dictionary entries."""

from __future__ import annotations

import re
from dataclasses import dataclass

from definition_common import MAX_SENSES_TOP3, decode_senses, is_abbreviation_gloss
from definition_anomaly import (
    is_anomalous_primary,
    is_weak_inflection_gloss,
    parse_meta_inflection,
    should_replace_with_inherited,
)
from definition_inflection import try_build_inflected_gloss
from definition_quality import is_acceptable_gloss, is_oxford_junk_gloss

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
_ALPHABET_LETTER_RE = re.compile(
    r"\b(?:"
    r"(?:\d+(?:st|nd|rd|th)|first|second|third|fourth|fifth|sixth|seventh|eighth|ninth|tenth|"
    r"eleventh|twelfth|thirteenth|fourteenth|fifteenth|sixteenth|seventeenth|"
    r"eighteenth|nineteenth|twentieth|twenty[- ]first|twenty[- ]second|twenty[- ]third|"
    r"twenty[- ]fourth|twenty[- ]fifth|twenty[- ]sixth)"
    r"\s+letter of (?:the )?(?:english|roman|latin|cyrillic)?\s*alphabet|"
    r"numeral symbol of the english alphabet|"
    r"letter of the alphabet"
    r")\b",
    re.I,
)
_VERBOSE_GLOSS_RE = re.compile(
    r"(?:"
    r"numeral symbol of the english alphabet|"
    r"called [a-z]+ and written|"
    r"metric unit of (?:length|mass)|"
    r"systeme international|"
    r"adopted under the|"
    r"nucleotide derived from|"
    r"purine base found in|"
    r"blood group whose red cells|"
    r"ten billionth of a meter"
    r")",
    re.I,
)
_ORDINAL_WORDS = (
    "first",
    "second",
    "third",
    "fourth",
    "fifth",
    "sixth",
    "seventh",
    "eighth",
    "ninth",
    "tenth",
    "eleventh",
    "twelfth",
    "thirteenth",
    "fourteenth",
    "fifteenth",
    "sixteenth",
    "seventeenth",
    "eighteenth",
    "nineteenth",
    "twentieth",
    "twenty-first",
    "twenty-second",
    "twenty-third",
    "twenty-fourth",
    "twenty-fifth",
    "twenty-sixth",
)
_SINGLE_LETTER_SEEDS: dict[str, list[str]] = {
    "A": ["The word a or an before a noun"],
    "I": ["The pronoun meaning myself or me"],
}
_PRONOUN_TOP3: dict[str, list[str]] = {
    "ME": [
        "Refers to yourself as the object (Give it to me)",
        "Used when someone does something to you",
        "The word for the speaker as object, not I",
    ],
    "HE": [
        "The male person already mentioned (He is here)",
        "A man or boy (Who is he?)",
        "Anyone, of either sex (informal)",
    ],
    "SHE": [
        "The female person already mentioned (She is here)",
        "A woman or girl (Who is she?)",
    ],
    "WE": [
        "You and I, or I and others (We are ready)",
        "Used by a king or queen to mean I",
        "People in general (We need rain)",
    ],
    "US": [
        "You and me, or me and others (Help us)",
        "The objective form of we (They saw us)",
    ],
    "MY": [
        "Belonging to me (my book, my name)",
        "An exclamation of surprise (My goodness!)",
    ],
}
_OXFORD_CROSSREF_RE = re.compile(
    r"(?:"
    r"^\s*(?:=|\&|pl\.?\s*=|us\s*=|var\.?\s*of)\s*\*|"
    r"\*i\d\b|"
    r"objective case of \*"
    r")",
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
    "BYE": re.compile(r"\b(?:goodbye|farewell|parting|leave-taking)\b", re.I),
    "HI": re.compile(r"\b(?:hello|greeting|informal\s+greeting)\b", re.I),
    "NO": re.compile(r"\b(?:denial or refusal|utterance of the word|refuse|disagree|answer.{0,20}negative)\b", re.I),
    "GIG": re.compile(r"\b(?:musician|musical group|performing engagement|booking for musicians|live performance)\b", re.I),
    "YES": re.compile(r"\b(?:affirmation|assent|agree|utterance of the word yes)\b", re.I),
    "GO": re.compile(r"\b(?:move|travel|leave|depart|function|operate|start)\b", re.I),
    "PLAY": re.compile(r"\b(?:game|sport|music|perform|amuse|occupy oneself|children|fun)\b", re.I),
}
_OXFORD_ENUM_RE = re.compile(r"(?:\(\s*foll\.|^\s*a\s+\(\s*foll\.|\.\s*[Bb]\s+[a-z])", re.I)
_COMMON_VERB_RE = re.compile(
    r"\b(?:exist|occur|take\s+place|happen|cost|equal|remain|become)\b",
    re.I,
)
_EVERYDAY_RE = re.compile(
    r"\b(?:"
    r"goodbye|farewell|hello|greeting|parting|leave-taking|"
    r"thank(?:s| you)|please|sorry|welcome|"
    r"informal\s+(?:word|term)\s+for\s+(?:goodbye|hello)"
    r")\b",
    re.I,
)
_GRAMMAR_OK_WORDS = frozenset(
    {"A", "AN", "THE", "OR", "AND", "BUT", "IF", "AS", "TO", "OF", "IN", "ON", "AT", "BY", "FOR", "NOR"}
)
_AFFIRMATIVE_INTERJECTION_RE = re.compile(
    r"\b(?:"
    r"utterance of the word yes|"
    r"affirmation or assent|"
    r"used to agree|"
    r"expressing agreement|"
    r"informal yes|"
    r"used to say yes"
    r")\b",
    re.I,
)
_PARTICIPLE_FORM_RE = re.compile(
    r"(?:^|\b)(?:"
    r"present participle of|"
    r"past participle of|"
    r"gerund of|"
    r"third-person singular of|"
    r"plural of|"
    r"simple past and past participle of"
    r")\b",
    re.I,
)
_GRAMMAR_META_RE = re.compile(
    r"(?:"
    r"\bnot any\b|"
    r"\bnot any\s*\(|"
    r"\bnot a,\s*quite other than\b|"
    r"\bhardly any\b|"
    r"\bhardly any\s*\(|"
    r"\bused elliptically\b|"
    r"\bindicating that the answer\b|"
    r"\bby no amount\b|"
    r"\bquite other than\b|"
    r"\bquite other than\s*\(|"
    r"\bindefinite article\b|"
    r"\bdefinite article\b|"
    r"\bobjective case\b|"
    r"\bsubjective case\b|"
    r"\bpossessive case\b|"
    r"\bused before a\b|"
    r"\bused after a\b|"
    r"^not a\b|"
    r"\bparticle used\b"
    r")",
    re.I,
)
_REFUSAL_INTERJECTION_RE = re.compile(
    r"\b(?:"
    r"denial or refusal|"
    r"utterance of the word|"
    r"used to refuse|used to disagree|"
    r"answer.{0,24}negative|"
    r"negative.{0,24}answer|"
    r"forbid etc|"
    r"'no' vote|"
    r"\brefusal\b"
    r")\b",
    re.I,
)
_MUSIC_GIG_RE = re.compile(
    r"\b(?:musician|musical group|performing engagement|booking for musicians|live performance|concert|theater|theatre)\b",
    re.I,
)
_ARCHAIC_TRANSPORT_RE = re.compile(
    r"\b(?:horse-drawn carriage|two-wheeled|ship's boat|rowing[- ]boat|row boat|one-horse carriage)\b",
    re.I,
)
_FISHING_GEAR_RE = re.compile(
    r"\b(?:barbed point|cluster of hooks|school of fish|catching fish|drawn through a school)\b",
    re.I,
)
_DOMAIN_JARGON_RE = re.compile(
    r"\b(?:"
    r"cricket|batsman|wicket|striker|innings|"
    r"checkmate|chess\s+(?:piece|opening)|"
    r"geologic(?:al)?\s+(?:epoch|period|era)|"
    r"paleozoic|mesozoic|cenozoic|"
    r"nucleotide|isotope|angstrom|"
    r"unpaired competitor.*tournament|"
    r"automatic advance to the next round"
    r")\b",
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
    ("letter", re.compile(r"\b(?:letter of the alphabet|numeral symbol.*alphabet|\d+(?:st|nd|rd|th) letter)\b", re.I)),
    ("tournament_advance", re.compile(r"\b(?:advance\w* to the next round|proceed\w* to the next round|without playing an opponent|unpaired competitor)\b", re.I)),
    ("negative_determiner", re.compile(r"\b(?:not any|not a|hardly any|quite other than)\b", re.I)),
    ("rowing_boat", re.compile(r"\b(?:rowing[- ]boat|row boat|ship's boat|light ship)\b", re.I)),
    ("horse_carriage", re.compile(r"\b(?:horse-drawn carriage|one-horse carriage|two-wheeled)\b", re.I)),
    ("music_gig", re.compile(r"\b(?:musician|musical group|performing engagement|booking for musicians)\b", re.I)),
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
    return bool(_LETTER_RE.search(text) or _ALPHABET_LETTER_RE.search(text))


def _canonical_letter_gloss(letter: str) -> str:
    if len(letter) != 1 or not letter.isalpha():
        return ""
    index = ord(letter.upper()) - ord("A")
    if index < 0 or index >= len(_ORDINAL_WORDS):
        return ""
    return f"The {_ORDINAL_WORDS[index]} letter of the English alphabet"


def _is_letter_like(text: str) -> bool:
    return _is_letter_sense(text) or bool(_VERBOSE_GLOSS_RE.search(text) and _ALPHABET_LETTER_RE.search(text))


def _polish_gloss(word: str, text: str) -> str:
    if len(word) == 1 and word.isalpha() and _is_letter_like(text):
        canonical = _canonical_letter_gloss(word)
        if canonical:
            return canonical
    if word == "A" and re.search(r"\b(?:fat-soluble )?vitamin", text, re.I):
        return "Vitamin A, needed for healthy vision"
    if word == "I" and (_PRONOUN_RE.search(text) or "speaker or writer" in text.lower()):
        return "The pronoun meaning myself or me"
    if word == "I" and re.search(r"\b(?:smallest whole number|roman numeral)\b", text, re.I):
        return "The Roman numeral for one"
    if word == "BYE" and re.search(r"\bfarewell\b", text, re.I):
        return "Informal word for goodbye"
    if word == "NO":
        if re.search(r"\bdenial or refusal\b", text, re.I):
            return "Used to refuse or disagree"
        if re.search(r"\butterance of the word\b", text, re.I):
            return "The word said to refuse or disagree"
        if re.search(r"\bindicating that the answer\b", text, re.I):
            return "Used to refuse or disagree"
        if re.search(r"\bforbid\b", text, re.I):
            return "Used to forbid something (No parking)"
    if word == "GIG" and _MUSIC_GIG_RE.search(text):
        if "booking" in text.lower():
            return "Paid job for a musician or performer"
        return "Live music performance or paid booking"
    if word == "YES" and _AFFIRMATIVE_INTERJECTION_RE.search(text):
        return "Used to agree or say yes"
    if word == "EYEGLASSES" and re.search(r"\bpair of lenses\b", text, re.I):
        return re.sub(r"\.\s*(?:Also called|See also).*$", "", text, flags=re.I).strip(" .")
    return text


def _base_primary_for_inheritance(
    base_word: str,
    comprehensive: dict[str, list[str]] | None,
) -> str:
    if not comprehensive:
        return ""
    senses = comprehensive.get(base_word, [])
    if not senses:
        return ""
    top3 = select_game_top3(
        base_word,
        entries_from_sense_texts(senses),
        comprehensive=None,
        allow_inherit=False,
    )
    for gloss in top3:
        if is_anomalous_primary(base_word, gloss):
            continue
        return gloss
    return top3[0] if top3 else ""


def _apply_inflection_inheritance(
    word: str,
    gloss: str,
    comprehensive: dict[str, list[str]] | None,
) -> str:
    if not comprehensive or not should_replace_with_inherited(word, gloss):
        return gloss
    inherited = try_build_inflected_gloss(
        word,
        gloss,
        comprehensive,
        lambda base: _base_primary_for_inheritance(base, comprehensive),
    )
    return inherited or gloss


def _polish_with_context(
    word: str,
    text: str,
    comprehensive: dict[str, list[str]] | None,
) -> str:
    polished = _polish_gloss(word, text)
    return _apply_inflection_inheritance(word, polished, comprehensive)


def _insert_seed_senses(word: str, chosen: list[str]) -> list[str]:
    seeds = _SINGLE_LETTER_SEEDS.get(word, [])
    for seed in seeds:
        if any(_is_near_duplicate(seed, kept) for kept in chosen):
            continue
        if len(chosen) >= MAX_SENSES_TOP3:
            break
        if word == "A" and chosen:
            chosen.insert(min(1, len(chosen)), seed)
        else:
            chosen.append(seed)
    return chosen


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
    if _VERBOSE_GLOSS_RE.search(stripped):
        return True
    if _OXFORD_CROSSREF_RE.search(stripped):
        return True
    if is_oxford_junk_gloss(stripped):
        return True
    if len(word) <= 3 and re.search(r"\b(?:hebrew alphabet|solfeggio|mus\.)\b", stripped, re.I):
        return True
    if word == "ME" and re.search(r"\bindefinite pronoun\b", stripped, re.I):
        return True
    if word == "GIG" and (
        _ARCHAIC_TRANSPORT_RE.search(stripped) or _FISHING_GEAR_RE.search(stripped)
    ):
        return True
    if len(word) <= 3 and _GRAMMAR_META_RE.search(stripped):
        return True
    if (
        len(word) <= 5
        and word not in _GRAMMAR_OK_WORDS
        and _GRAMMAR_META_RE.search(stripped)
    ):
        return True
    if (
        len(word) >= 3
        and word not in _GRAMMAR_OK_WORDS
        and _PARTICIPLE_FORM_RE.search(stripped)
    ):
        return True
    if len(word) == 1 and re.search(r"\b(?:metric unit|blood group|nucleotide|purine base|ace\.|acre\b|including in card games)\b", stripped, re.I):
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
    if _VERBOSE_GLOSS_RE.search(text):
        score += 260
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

    if _EVERYDAY_RE.search(text):
        score -= 140
    if _REFUSAL_INTERJECTION_RE.search(text):
        score -= 160
    if _AFFIRMATIVE_INTERJECTION_RE.search(text):
        score -= 160
    if _GRAMMAR_META_RE.search(text):
        score += 220
    if _PARTICIPLE_FORM_RE.search(text):
        score += 240
    if _MUSIC_GIG_RE.search(text):
        score -= 170
    if _ARCHAIC_TRANSPORT_RE.search(text):
        score += 200
    if _FISHING_GEAR_RE.search(text):
        score += 180
    if _DOMAIN_JARGON_RE.search(text):
        score += 180
    if len(word) <= 4 and _DOMAIN_JARGON_RE.search(text):
        score += 80
    if len(word) <= 5 and _GRAMMAR_META_RE.search(text) and word not in _GRAMMAR_OK_WORDS:
        score += 100
    if len(word) <= 3 and _REFUSAL_INTERJECTION_RE.search(text):
        score -= 80
    if len(word) <= 3 and _AFFIRMATIVE_INTERJECTION_RE.search(text):
        score -= 80
    if len(text) > 100:
        score += 60 + max(0, (len(text) - 100) // 15)
    if is_weak_inflection_gloss(text):
        score += 200
    if parse_meta_inflection(text):
        score += 260
    if _OXFORD_ENUM_RE.search(text):
        score += 210

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


def select_game_top3(
    word: str,
    entries: list[SenseEntry],
    comprehensive: dict[str, list[str]] | None = None,
    allow_inherit: bool = True,
) -> list[str]:
    """Pick up to three game-focused senses, deduping rephrased meanings."""
    if word in _PRONOUN_TOP3:
        return _PRONOUN_TOP3[word][:MAX_SENSES_TOP3]
    if not entries:
        return []

    ranked = sorted(entries, key=lambda entry: _game_score(word, entry))
    chosen: list[str] = []

    if len(word) == 1 and word.isalpha():
        canonical = _canonical_letter_gloss(word)
        if canonical:
            chosen.append(canonical)
        chosen = _insert_seed_senses(word, chosen)

    polish = (
        (lambda w, t: _polish_with_context(w, t, comprehensive))
        if allow_inherit
        else _polish_gloss
    )

    for entry in ranked:
        if is_obscure_for_game(word, entry.text, entry.is_abbrev):
            continue
        if len(word) == 1 and word.isalpha() and _is_letter_like(entry.text):
            continue
        polished = polish(word, entry.text)
        if not is_acceptable_gloss(polished):
            continue
        if any(_is_near_duplicate(polished, kept) for kept in chosen):
            continue
        chosen.append(polished)
        if len(chosen) >= MAX_SENSES_TOP3:
            break

    if chosen:
        chosen = _promote_best_primary(word, chosen[:MAX_SENSES_TOP3], ranked, polish)
    else:
        for entry in ranked:
            polished = polish(word, entry.text)
            if not is_acceptable_gloss(polished):
                continue
            if any(_is_near_duplicate(polished, kept) for kept in chosen):
                continue
            chosen.append(polished)
            if len(chosen) >= MAX_SENSES_TOP3:
                break
        chosen = _promote_best_primary(word, chosen[:MAX_SENSES_TOP3], ranked, polish)

    if allow_inherit and comprehensive and chosen:
        primary = chosen[0]
        if should_replace_with_inherited(word, primary) or is_anomalous_primary(word, primary):
            inherited = try_build_inflected_gloss(
                word,
                primary,
                comprehensive,
                lambda base: _base_primary_for_inheritance(base, comprehensive),
            )
            if inherited:
                rest = [sense for sense in chosen[1:] if not _is_near_duplicate(sense, inherited)]
                chosen = [inherited] + rest

    cleaned: list[str] = []
    for sense in chosen:
        if is_anomalous_primary(word, sense) and comprehensive:
            replacement = try_build_inflected_gloss(
                word,
                sense,
                comprehensive,
                lambda base: _base_primary_for_inheritance(base, comprehensive),
            )
            if replacement:
                sense = replacement
        if any(_is_near_duplicate(sense, kept) for kept in cleaned):
            continue
        cleaned.append(sense)
    chosen = cleaned or chosen

    return chosen[:MAX_SENSES_TOP3]


def classify_primary_issues(word: str, text: str) -> list[str]:
    stripped = text.strip()
    if not stripped:
        return ["empty"]
    issues: list[str] = []
    if is_abbreviation_gloss(stripped):
        issues.append("abbreviation")
    if _PARTICIPLE_FORM_RE.search(stripped):
        issues.append("participle_form")
    if _GRAMMAR_META_RE.search(stripped) and word not in _GRAMMAR_OK_WORDS:
        issues.append("grammar")
    if _is_letter_sense(stripped) and len(word) != 1:
        issues.append("letter_sense")
    if _VERBOSE_GLOSS_RE.search(stripped):
        issues.append("verbose")
    if _DOMAIN_JARGON_RE.search(stripped):
        issues.append("domain_jargon")
    if _ARCHAIC_TRANSPORT_RE.search(stripped):
        issues.append("archaic_transport")
    if _FISHING_GEAR_RE.search(stripped):
        issues.append("fishing_gear")
    if _CHEMISTRY_RE.search(stripped):
        issues.append("chemistry")
    if re.search(r"\b(?:obsolete|archaic|historical|dialect|rare)\b", stripped, re.I):
        issues.append("archaic_label")
    return issues


def serious_primary_issues(word: str, text: str) -> list[str]:
    serious = {
        "grammar",
        "participle_form",
        "letter_sense",
        "verbose",
        "domain_jargon",
        "archaic_transport",
        "fishing_gear",
        "chemistry",
        "archaic_label",
        "abbreviation",
    }
    return [issue for issue in classify_primary_issues(word, text) if issue in serious]


def is_playable_primary(word: str, text: str) -> bool:
    issues = classify_primary_issues(word, text)
    blocked = {
        "empty",
        "abbreviation",
        "participle_form",
        "grammar",
        "letter_sense",
        "verbose",
        "domain_jargon",
        "archaic_transport",
        "fishing_gear",
        "chemistry",
        "archaic_label",
    }
    return not (set(issues) & blocked)


def _promote_best_primary(
    word: str,
    chosen: list[str],
    ranked: list[SenseEntry],
    polish=_polish_gloss,
) -> list[str]:
    playable_ranked: list[str] = []
    for entry in ranked:
        if is_obscure_for_game(word, entry.text, entry.is_abbrev):
            continue
        if len(word) == 1 and word.isalpha() and _is_letter_like(entry.text):
            continue
        polished = polish(word, entry.text)
        if not is_acceptable_gloss(polished):
            continue
        if not is_playable_primary(word, polished):
            continue
        if any(_is_near_duplicate(polished, kept) for kept in playable_ranked):
            continue
        playable_ranked.append(polished)
        if len(playable_ranked) >= MAX_SENSES_TOP3:
            break

    if playable_ranked:
        return playable_ranked[:MAX_SENSES_TOP3]

    if len(word) == 1 and word.isalpha():
        seeds = _insert_seed_senses(word, [])
        if seeds:
            return seeds[:MAX_SENSES_TOP3]

    return chosen[:MAX_SENSES_TOP3]


def select_game_top3_from_senses(
    word: str,
    senses: list[str],
    comprehensive: dict[str, list[str]] | None = None,
) -> list[str]:
    """Build Top 3 from an ordered comprehensive sense list."""
    return select_game_top3(
        word,
        entries_from_sense_texts(senses),
        comprehensive=comprehensive,
    )
