#!/usr/bin/env python3
"""Deep analysis of EnglishWords4.txt for casual word-spelling game suitability."""

from __future__ import annotations

import re
from collections import defaultdict
from datetime import datetime
from pathlib import Path

from wordfreq import zipf_frequency

DICT_PATH = Path(__file__).resolve().parent.parent / "dictionary" / "EnglishWords4.txt"
OLD_DICT_PATH = DICT_PATH.parent / "EnglishWords.txt"
REPORT_PATH = Path(__file__).resolve().parent.parent / "reports" / "DICTIONARY_OMISSION_REPORT.txt"

# Official Scrabble / Collins two-letter word list (CSW / OSPD).
# Every entry here is a legitimate English or accepted loanword — never flag for omission.
VALID_SCRABBLE_TWO = frozenset(
    """
    AA AB AD AE AG AH AI AL AM AN AR AS AT AW AX AY BA BE BI BO BY DA DE DO
    ED EF EH EL EM EN ER ES ET EX FA GO HE HI HM HO ID IF IN IS IT JO KA LA LI LO MA
    ME MI MM MO MU MY NA NE NO NU OD OE OF OH OI OM ON OP OR OS OW OX OY PA PE PI PO
    QI RE SH SI SO TA TI TO UH UM UN UP US UT WE WO XI XU YA YE YO ZA
    """.split()
)

# Additional two-letter real English not in every Scrabble list.
EXTRA_REAL_TWO = frozenset("OK HA".split())

# All two-letter real words — never treat as abbreviations (includes BE, WE, AM, IT, etc.).
REAL_TWO_LETTER = VALID_SCRABBLE_TWO | EXTRA_REAL_TWO

# Explicit two-letter codes / initialisms only — NOT ordinary vocabulary.
# Curated manually: country/media/state codes (TV, UK, JP…) and similar tokens.
TWO_LETTER_ABBREV_BLOCKLIST = frozenset(
    """
    BC BT CB CC CD CE CH CI CM CO CS CY DI DL DR DU EB EE EG EO FI FO FT FU FY
    GB GC GE GI GM GU IE II IL IO JE JP JR JU KB KC KG KM KO KU KY LC LE LP MB MD
    MG ML MP MR MS MX NW NY OO PC PM PS RA RH RI RO TB TE TU TV UG UK UR VC VI VU
    WC WU YU
    """.split()
)

# Three-letter codes / initialisms only — excludes ordinary words (RAM, WAN, VAT, DOM, PIN…).
THREE_LETTER_ABBREV = frozenset(
    """
    BBC BMX BST CMG DDT DFC DFM DSC DSM FLP FRS GCB GMT IOS KCB LLB LLD LTD MCC MDV
    MPS MSC PHD PLC PPS PST STD TNT WNW WSW
    """.split()
)

# Four+ letter initialisms — excludes homographs that are ordinary English words (LED, PIN, COO…).
ACRONYMS_4PLUS = frozenset(
    """
    AWOL BTW CAPTCHA CDROM CFO CIO CPA CPR CRM CTO CV DBA DIY DNA DSL DVD FAQ FYI
    GIF GMO GPS GUI HDD HDMI HIV HTML HTTP HTTPS IBM ICU IDK IEEE IIRC IMO IOW IOS
    IPO ISBN ISP JPEG JPG JSON KPI LAN LCD MBA MRI NASA NATO NBA NGO NLP OCR PDF PHP
    POS PPI PPO PR PSTN PTSD PVC RSVP SEO SIM SMS SQL SUV TBA THC TMI TSA UFO URL
    USB VIP VPN VR WIFI WWW XML XSS YTD ADSL ASAP BBS BFF
    """.split()
)

# Brand / trademark names — excludes words with ordinary English meanings (CANON, TARGET…).
BRAND_NAMES = frozenset(
    """
    ADOBE ADIDAS ADIPLEX XEROX EBAY GUCCI PRADA ROLEX VIAGRA CIALIS LIPITOR PROZAC
    ZOLOFT XANAX VALIUM DUPONT DUREX NINTENDO SONY NIKON CISCO
    YAHOO GOOGLE TWITTER FACEBOOK INSTAGRAM NETFLIX SPOTIFY STARBUCKS MCDONALDS
    BURGERKING WALMART COSTCO IKEA FEDEX DHL ABBA
    """.split()
)

# Geographic proper nouns (cities, countries, regions) — sample + pattern-expanded.
GEOGRAPHIC_PROPER = frozenset(
    w.upper()
    for w in """
    AACHEN AARHUS ABADAN ABERDEEN ADELAIDE AFGHANISTAN AFRICA ALABAMA ALASKA ALBANIA
    ALGERIA AMERICA AMSTERDAM ANTWERP ARIZONA ARKANSAS ATHENS ATLANTA AUSTRALIA AUSTRIA
    BAGHDAD BALTIMORE BANGKOK BARCELONA BEIJING BELGIUM BERLIN BIRMINGHAM BOSTON BRISTOL
    BRUSSELS BUDAPEST CAIRO CALCUTTA CALIFORNIA CAMBRIDGE CANADA CHICAGO CHINA COLORADO
    CONNECTICUT COPENHAGEN DALLAS DELHI DENMARK DETROIT DUBLIN DURBAN DUSSELDORF
    EDINBURGH EGYPT ENGLAND EUROPE FLORIDA FRANCE FRANKFURT GENEVA GEORGIA GERMANY
    GLASGOW GREECE HAMBURG HAWAII HOLLAND HOUSTON INDIA INDIANA IOWA IRELAND ISRAEL
    ITALY JAPAN KANSAS KENTUCKY KOREA LONDON MADRID MAINE MARYLAND MASSACHUSETTS
    MELBOURNE MEMPHIS MEXICO MIAMI MICHIGAN MINNESOTA MISSISSIPPI MISSOURI MONTANA
    MONTREAL MOSCOW MUNICH NEBRASKA NEVADA NORWAY OHIO OKLAHOMA OREGON OXFORD PARIS
    PENNSYLVANIA PHILADELPHIA PHOENIX PITTSBURGH POLAND PORTLAND PORTUGAL PRAGUE QUEBEC
    ROME RUSSIA SCOTLAND SEATTLE SEOUL SPAIN STOCKHOLM SWEDEN SWITZERLAND SYDNEY
    TENNESSEE TEXAS THAILAND TOKYO TORONTO TURKEY UTAH VANCOUVER VENICE VIENNA VIRGINIA
    WALES WARSAW WASHINGTON WISCONSIN WYOMING YORK ZURICH SEYCHELLES DURHAM DUSTIN
    AARON ABBOTT ABDULLAH ABRAHAM ADAMS ADRIAN ADOLF AGNEW ALFRED ALICE ALLEN ANDERSON
    ARMSTRONG ARNOLD ARTHUR AUSTEN BACON BACH BEATLES BEETHOVEN BELL BENNETT BIBLE
    BISMARCK BONAPARTE BOWIE BOWLES BOWMAN BRADLEY BRENNAN BRENT BREWER BREWSTER
    BRIDGES BRIGGS BRISTOL BROCK BROOKE BROOKS BROWN BRUCE BRYAN BUCK BUDDHA BUDDY
    BURKE BURNS BURTON BUSH BUTLER BYRON CAESAR CALVIN CAMERON CAMPBELL CARL CARLOS
    CAROL CAROLINE CAROLYN CARPENTER CARR CARTER CARVER CASEY CASSIDY CATHERINE
    CHAPMAN CHASE CHAUcer CHESTER CHICAGO CHILE CHINA CHOPIN CHRIST CHRISTIAN CHRISTIE
    CHURCHILL CLARENCE CLARK CLARKE CLAY CLEOPATRA CLIFFORD CLINTON COLE COLEMAN
    COLIN COLLINS COLUMBIA COLUMBUS COMSTOCK CONRAD COOK COOKE COOPER COPERNICUS
    """.split()
)

# Unassimilated foreign words (not ordinary English vocabulary).
FOREIGN_WORDS = frozenset(
    w.upper()
    for w in """
    DURCHKOMPONIERT DURCHSCHNITT ZUGZWANG ZUGZWANGS ZWISCHENZUG ZWISCHENZUGS
    SFUMATO SFUMATOS SFORZANDO SFORZANDOS SFORZATI SFORZATO SFORZATOS
    AASVOGEL AASVOGELS ABEND ABENDS MENGE MENGES MENGED MENGING MENGS
    POLTERGEIST POLTERGEISTS WELTSCHMERZ SCHADENFREUDE KINDERGARTEN
    """.split()
)

# Taxonomic / scientific Latin patterns.
LATIN_REGEX = [
    re.compile(r".*ACEAE$"),
    re.compile(r".*IDAE$"),
    re.compile(r".*CHIATA$"),
    re.compile(r".*CHIATE$"),
    re.compile(r".*FORMES$"),
    re.compile(r".*PHYTA$"),
    re.compile(r".*MYCES$"),
    re.compile(r".*CETOUS$"),
    re.compile(r"^ZYGO[A-Z]+$"),
    re.compile(r"^ZYM[A-Z]+$"),
]

FOREIGN_REGEX = [
    re.compile(r"^DURCH[A-Z]+$"),
    re.compile(r".*ZWISCHEN.*"),
    re.compile(r".*KOMPONIERT$"),
    re.compile(r".*SCHNITT$"),
]

# Personal-name heuristic suffixes (low-frequency surnames).
SURNAME_SUFFIXES = ("SSON", "SKI", "SKY", "BURY", "FORD", "FIELD", "WOOD", "WORTH", "CHESTER")


def load_words(path: Path) -> list[str]:
    words = []
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        w = line.strip().upper()
        if w and w.isalpha():
            words.append(w)
    return words


def zipf(word: str) -> float:
    return zipf_frequency(word.lower(), "en")


def is_likely_surname(word: str, freq: float) -> bool:
    if len(word) < 5 or freq >= 1.2:
        return False
    for suf in SURNAME_SUFFIXES:
        if word.endswith(suf) and len(word) > len(suf) + 3:
            return True
    # Famous-name pattern: MENDELSSOHN, SHACKLETON
    if freq < 0.6 and len(word) >= 7:
        if word.endswith(("TON", "SON", "MAN", "SEN")):
            return True
    return False


def categorize(word: str) -> list[str]:
    reasons: list[str] = []
    n = len(word)
    freq = zipf(word)

    if word in BRAND_NAMES:
        reasons.append("BRAND_OR_TRADEMARK")

    if word in ACRONYMS_4PLUS:
        reasons.append("ACRONYM_OR_INITIALISM")

    if n == 2:
        if word in REAL_TWO_LETTER:
            return reasons  # be, we, am, it, etc. — real words (stored uppercase)
        if word in TWO_LETTER_ABBREV_BLOCKLIST:
            reasons.append("TWO_LETTER_ABBREVIATION")
        return reasons

    if n == 3 and word in THREE_LETTER_ABBREV:
        reasons.append("THREE_LETTER_ABBREVIATION")

    if word in GEOGRAPHIC_PROPER:
        reasons.append("PROPER_NOUN_GEOGRAPHIC")

    if word in FOREIGN_WORDS:
        reasons.append("FOREIGN_WORD")

    for pat in FOREIGN_REGEX:
        if pat.match(word):
            if "FOREIGN_WORD" not in reasons:
                reasons.append("FOREIGN_WORD")
            break

    for pat in LATIN_REGEX:
        if pat.match(word) and n >= 8:
            reasons.append("SCIENTIFIC_TAXONOMIC_LATIN")
            break

    if is_likely_surname(word, freq) and "PROPER_NOUN_GEOGRAPHIC" not in reasons:
        reasons.append("PROPER_NOUN_SURNAME_LIKELY")

    # Archaic forms
    if word.endswith(("ETH", "HATH", "DOTH")) and freq < 2.5:
        reasons.append("ARCHAIC_OBSOLETE")

    # Very long competitive-Scrabble words
    if n >= 14 and freq < 2.0:
        reasons.append("VERY_LONG_OBSCURE")

    # Frequency-based obscurity (conservative thresholds)
    if n >= 4:
        if freq < 0.5:
            reasons.append("EXTREMELY_OBSCURE")
        elif freq < 0.9 and n >= 9:
            reasons.append("HIGHLY_OBSCURE")
        elif freq < 1.1 and n >= 12:
            reasons.append("HIGHLY_OBSCURE")

    return reasons


def primary_category(reasons: list[str]) -> str:
    priority = [
        "TWO_LETTER_ABBREVIATION",
        "THREE_LETTER_ABBREVIATION",
        "ACRONYM_OR_INITIALISM",
        "BRAND_OR_TRADEMARK",
        "FOREIGN_WORD",
        "SCIENTIFIC_TAXONOMIC_LATIN",
        "PROPER_NOUN_GEOGRAPHIC",
        "PROPER_NOUN_SURNAME_LIKELY",
        "ARCHAIC_OBSOLETE",
        "VERY_LONG_OBSCURE",
        "EXTREMELY_OBSCURE",
        "HIGHLY_OBSCURE",
    ]
    for p in priority:
        if p in reasons:
            return p
    return reasons[0] if reasons else ""


def main() -> None:
    overlap = REAL_TWO_LETTER & TWO_LETTER_ABBREV_BLOCKLIST
    if overlap:
        raise SystemExit(f"Blocklist incorrectly includes real two-letter words: {sorted(overlap)}")

    words = load_words(DICT_PATH)
    all_buckets: dict[str, list[str]] = defaultdict(list)
    word_reasons: dict[str, list[str]] = {}
    flagged: set[str] = set()

    for word in words:
        reasons = categorize(word)
        if reasons:
            flagged.add(word)
            word_reasons[word] = reasons
            all_buckets[primary_category(reasons)].append(word)

    # Scan old EnglishWords.txt for junk that leaked into EW4 (tight patterns only)
    old_junk_in_ew4: list[str] = []
    if OLD_DICT_PATH.exists():
        old_words = set()
        for line in OLD_DICT_PATH.read_text(encoding="utf-8", errors="replace").splitlines():
            w = line.strip().strip('"').upper()
            if w:
                old_words.add(w)
        ew4_set = set(words)
        garbage_exact = frozenset(
            """
            ACDBENTITY ADIPLEX ADWARE ADSL ZDNET ZSHOPS ZOPE ZOLOFT ZU ZUS
            """.split()
        )
        for w in sorted(old_words & ew4_set):
            if w in garbage_exact:
                old_junk_in_ew4.append(w)

    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)

    category_order = [
        "TWO_LETTER_ABBREVIATION",
        "THREE_LETTER_ABBREVIATION",
        "ACRONYM_OR_INITIALISM",
        "BRAND_OR_TRADEMARK",
        "FOREIGN_WORD",
        "SCIENTIFIC_TAXONOMIC_LATIN",
        "PROPER_NOUN_GEOGRAPHIC",
        "PROPER_NOUN_SURNAME_LIKELY",
        "ARCHAIC_OBSOLETE",
        "VERY_LONG_OBSCURE",
        "EXTREMELY_OBSCURE",
        "HIGHLY_OBSCURE",
    ]

    descriptions = {
        "TWO_LETTER_ABBREVIATION": "Two-letter codes (TV, UK, JP, BC…) — not English words",
        "THREE_LETTER_ABBREVIATION": "Three-letter abbreviations (BBC, GMT, PHD, TNT…)",
        "ACRONYM_OR_INITIALISM": "Acronyms and initialisms (DNA, HTML, NASA…) — not ordinary vocabulary",
        "BRAND_OR_TRADEMARK": "Company, product, or trademark names",
        "FOREIGN_WORD": "Unassimilated foreign vocabulary (German, Italian, Afrikaans…)",
        "SCIENTIFIC_TAXONOMIC_LATIN": "Scientific / taxonomic Latin (genus, family names)",
        "PROPER_NOUN_GEOGRAPHIC": "Place names, countries, cities, regions",
        "PROPER_NOUN_SURNAME_LIKELY": "Likely personal surnames (heuristic, low frequency)",
        "ARCHAIC_OBSOLETE": "Archaic verb forms (HATH, DOTH…) — obsolete in modern English",
        "VERY_LONG_OBSCURE": "Very long (14+ letter) rare words — tournament Scrabble fodder",
        "EXTREMELY_OBSCURE": "Zipf frequency below 0.5 — virtually unknown to general players",
        "HIGHLY_OBSCURE": "Zipf below ~1.1 on long words — specialist/archaic vocabulary",
    }

    lines = [
        "=" * 78,
        "LETTRAGE — ENGLISH WORDS DICTIONARY OMISSION REPORT",
        "=" * 78,
        f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
        f"Source file: {DICT_PATH.name}",
        f"Full path: {DICT_PATH}",
        f"Total words analyzed: {len(words):,}",
        f"Words flagged for omission: {len(flagged):,}",
        f"Words recommended to keep (unflagged): {len(words) - len(flagged):,}",
        "",
        "IMPORTANT: ALL-CAPS STORAGE",
        "-" * 78,
        "Every entry in EnglishWords4.txt is stored in UPPERCASE. This is a storage",
        "convention only — BE means \"be\", WE means \"we\", IT means \"it\", etc. Common",
        "two-letter words are NEVER flagged. Only genuine codes (TV, UK, JP…) are listed",
        "under TWO_LETTER_ABBREVIATION.",
        "",
        "PROFANITY POLICY",
        "-" * 78,
        "Profane, vulgar, and explicit words are intentionally ALLOWED in the dictionary",
        "and are not listed in this report.",
        "",
        "EXECUTIVE SUMMARY",
        "-" * 78,
        "EnglishWords4.txt is the active dictionary (dictionary_service.gd). It is a",
        "large (~194k entry) comprehensive word list consistent with a Scrabble /",
        "Collins-style lexicon: it includes archaic English, scientific Latin, foreign",
        "borrowings, and proper nouns alongside everyday vocabulary.",
        "",
        "KEY FINDINGS:",
        f"  • {len(all_buckets.get('TWO_LETTER_ABBREVIATION', []))} two-letter codes only (TV, UK, JP, BC — not BE/WE/IT)",
        f"  • {len(all_buckets.get('THREE_LETTER_ABBREVIATION', []))} three-letter abbreviations (BBC, GMT, PHD, …)",
        f"  • {len(all_buckets.get('ACRONYM_OR_INITIALISM', []))} acronyms / initialisms",
        f"  • {len(all_buckets.get('PROPER_NOUN_GEOGRAPHIC', []))} geographic / personal proper nouns (curated seed list)",
        f"  • {len(all_buckets.get('SCIENTIFIC_TAXONOMIC_LATIN', []))} scientific / taxonomic Latin forms",
        f"  • {len(all_buckets.get('EXTREMELY_OBSCURE', [])) + len(all_buckets.get('HIGHLY_OBSCURE', [])):,} highly / extremely obscure words (frequency-based)",
        "",
        "EnglishWords.txt (10,000 entries) is NOT used at runtime. It is a legacy",
        "web-scraped list with abbreviations (ac, adsl, abc) and junk tokens. Only",
        "~9,145 entries overlap EnglishWords4; most legacy garbage did NOT carry over.",
        "",
        "PURPOSE OF THIS REPORT",
        "-" * 78,
        "Lists every dictionary entry recommended for OMISSION from a casual English",
        "word-spelling game. Categories are ordered from highest-confidence removals",
        "(abbreviations, brands) to judgment calls (obscure vocabulary).",
        "",
        "METHODOLOGY",
        "-" * 78,
        "1. Two-letter: explicit code blocklist only; all Scrabble-legal and common",
        "   real words (BE, WE, AM, IT, QI, ZA, …) are kept.",
        "2. Three-letter and longer: curated abbreviation lists; homographs removed",
        "   (RAM, WAN, VAT, DOM, LED, PIN, COO are real words and not flagged).",
        "3. Curated acronym, brand, geographic, and foreign-word lists.",
        "4. Regex patterns for taxonomic Latin (-aceae, -idae, zygo-, zym-).",
        "5. wordfreq Zipf scores (en): words below 0.5 flagged EXTREMELY_OBSCURE;",
        "   long words (9–12+ chars) with Zipf < 0.9–1.1 flagged HIGHLY_OBSCURE.",
        "6. Heuristic surname detection (suffix patterns + low frequency).",
        "7. Homograph check: ordinary English words are not flagged as abbreviations.",
        "",
        "RECOMMENDED ACTION",
        "-" * 78,
        "Priority 1 — Remove immediately: TWO_LETTER_ABBREVIATION, THREE_LETTER_",
        "ABBREVIATION, ACRONYM_OR_INITIALISM, BRAND_OR_TRADEMARK.",
        "Priority 2 — Strongly consider: FOREIGN_WORD, PROPER_NOUN_*, SCIENTIFIC_*.",
        "Priority 3 — Game-design choice: HIGHLY_OBSCURE, EXTREMELY_OBSCURE",
        "(removing ~80k+ words yields a ~100k casual dictionary).",
        "",
        "LIMITATIONS",
        "-" * 78,
        "- Proper-noun coverage is incomplete; many surnames/places remain unflagged.",
        "- British spellings (MEMORISE) are intentionally kept.",
        "- Some HIGHLY_OBSCURE words are valid English (e.g. technical terms).",
        "- Frequency thresholds are tunable; adjust before bulk deletion.",
        "",
    ]

    if old_junk_in_ew4:
        lines.extend([
            "LEGACY EnglishWords.txt JUNK STILL IN EnglishWords4",
            "-" * 78,
            " ".join(old_junk_in_ew4[:50]),
            "",
        ])

    for cat in category_order:
        items = sorted(set(all_buckets.get(cat, [])))
        if not items:
            continue
        lines.append("=" * 78)
        lines.append(f"CATEGORY: {cat}")
        lines.append(f"Count: {len(items):,}")
        lines.append(descriptions.get(cat, ""))
        lines.append("=" * 78)
        for w in items:
            lines.append(f"  {w}  (zipf={zipf(w):.2f})")
        lines.append("")

    lines.append("=" * 78)
    lines.append("SUMMARY BY CATEGORY")
    lines.append("=" * 78)
    total_listed = 0
    for cat in category_order:
        c = len(set(all_buckets.get(cat, [])))
        if c:
            lines.append(f"  {cat}: {c:,}")
            total_listed += c
    lines.append(f"  TOTAL UNIQUE FLAGGED: {len(flagged):,}")
    lines.append("")
    lines.append("END OF REPORT")

    REPORT_PATH.write_text("\n".join(lines), encoding="utf-8")
    print(f"Report: {REPORT_PATH}")
    print(f"Analyzed {len(words):,}; flagged {len(flagged):,}")
    for cat in category_order:
        c = len(set(all_buckets.get(cat, [])))
        if c:
            print(f"  {cat}: {c:,}")


if __name__ == "__main__":
    main()
