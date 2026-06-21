#!/usr/bin/env python3
"""Count personal names in EnglishWords5.txt — report only."""

from __future__ import annotations

import csv
import io
import urllib.request
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DICT_PATH = ROOT / "dictionary" / "EnglishWords5.txt"

# Common nicknames / diminutives (short forms accepted as standalone words).
NICKNAMES = frozenset(
    """
    ABE AL ALF ANDY ART BART BEN BERT BILL BOB BRAD BRI BRYCE BUD CAL CHAD CHARLIE
    CHAS CHUCK CLIFF CLINT COLE CONNIE DAN DAVE DON DOUG ED EDDIE ELI ERNIE FRED
    GARY GENE GREG GUS HAL HANK HARRY HAZEL HEATH HERB HOWIE IAN IGGY IRA JACK JAKE
    JAMIE JAY JEFF JEM JIM JO JOAN JOE JON JOSH JUDE KEN KIT LEE LEO LEON LES LEX
    LIAM LIZ LOU LUC LUKE MAL MALCOLM MATT MAX MEG MEL MIKE MOLLY NAT NED NICK NIK
    NORM OLLIE OZ PAT PEG PETE PHIL RAY RICK ROB ROD RON ROSS ROY RUSS RUTH SAM
    SCOTT SEAN SETH SID STAN STEVE SUE TED TESS TIM TOM TONY TRACY TREV VAL VIC
    WALT WENDY WILL WILLY ZACK ZOE
    """.split()
)

# Forenames — SSA-style common + international (uppercase).
FORENAMES = frozenset(
    w.upper()
    for w in """
    AARON ABIGAIL ADAM ADRIAN AIDAN ALAN ALBERT ALEX ALICE ALICIA ALISON AMANDA
    AMBER AMELIA AMY ANDREA ANDREW ANGELA ANGELICA ANNA ANNE ANNIE ANTHONY ANTONIO
    ARTHUR ASHLEY AUDREY AUSTIN BARBARA BARRY BEATRICE BELINDA BENJAMIN BERNARD
    BETH BETTY BEVERLY BILL BILLY BOB BOBBY BRANDON BRENDA BRIAN BRIDGET BRUCE
    CALVIN CAMERON CARL CARLA CAROL CAROLINE CAROLYN CARTER CATHERINE CECILIA CHAD
    CHARLES CHARLOTTE CHERYL CHRIS CHRISTIAN CHRISTINA CHRISTINE CHRISTOPHER CINDY
    CLAIRE CLARA CLARENCE CLAUDIA CLIFFORD CLINTON COLIN CONNIE CONSTANCE COREY
    COURTNEY CRAIG CRYSTAL CURTIS CYNTHIA DALE DANIEL DANIELLE DARLENE DAVE DAVID
    DAWN DEAN DEBORAH DENISE DENNIS DEREK DIANA DIANE DONALD DONNA DORIS DOROTHY
    DOUG DOUGLAS DYLAN EARL ED EDITH EDWARD EDWIN EILEEN ELaine ELEANOR ELIZABETH
    ELLEN EMILY EMMA ERIC ERICA ERNEST ESTHER ETHAN EUGENE EVA EVELYN FELIX FLORENCE
    FRANCES FRANCIS FRANK FRANKLIN FRED FREDERICK GABRIEL GAIL GARY GENE GEORGE
    GEORGIA GERALD GERALDINE GERTRUDE GILBERT GLADYS GLEN GLENN GLORIA GRACE GREG
    GREGORY GUY HAROLD HARRY HAZEL HEATHER HELEN HENRY HERBERT HOLLY HOWARD IAN
    IRENE IRIS IRVING ISAAC ISABEL ISABELLE IVAN JACK JACKIE JACOB JACQUELINE JAMES
    JANE JANET JANICE JASON JEAN JEFF JEFFREY JENNIFER JEREMY JERRY JESSE JESSICA
    JILL JIM JIMMY JOAN JOANNE JOE JOEL JOHN JOHNNY JONATHAN JORDAN JOSE JOSEPH
    JOSHUA JOYCE JUDITH JUDY JULIA JULIE JULIE JUSTIN KAREN KATE KATHERINE KATHLEEN
    KATHY KATIE KEITH KELLY KENNETH KEVIN KIM KIMBERLY KIRK KRISTEN LARRY LAURA
    LAUREN LAWRENCE LEE LEON LEONARD LESLIE LEWIS LILLIAN LINDA LISA LLOYD LOIS
    LORENZO LORI LOUIS LOUISE LUCAS LUCY LUKE LYNN MADELINE MADISON MARGARET MARIA
    MARIE MARILYN MARION MARK MARLENE MARSHALL MARTHA MARTIN MARVIN MARY MATTHEW
    MAUREEN MAX MAURICE MEGAN MELISSA MICHAEL MICHELE MICHELLE MIKE MILDRED MIRANDA
    MITCHELL MONICA MORGAN NANCY NATALIE NATHAN NEIL NELSON NICHOLAS NICOLE NINA
    NOAH NORA NORMAN OLIVIA OSCAR PAMELA PAT PATRICIA PATRICK PAUL PAULA PAULINE
    PEGGY PENELOPE PETER PHIL PHILIP PHYLLIS RACHEL RALPH RANDALL RANDY RAYMOND
    REBECCA REGINALD RENE RICHARD RICK RITA ROBERT ROBIN RODNEY ROGER RONALD RONNIE
    ROSE ROSS ROY RUSSELL RUTH RYAN SAM SAMUEL SANDRA SARAH SCOTT SEAN SHARON
    SHAWN SHEILA SHIRLEY SIMON STANLEY STEPHANIE STEPHEN STEVE STEVEN STUART SUE
    SUSAN SYLVIA TAMMY TED TERESA TERRI TERRY THELMA THOMAS TIM TIMOTHY TINA TODD
    TOM TONY TRACY TRAVIS TROY TYLER VALERIE VANESSA VERA VERNON VICKI VICTOR
    VICTORIA VINCENT VIRGINIA WALTER WANDA WAYNE WENDY WESLEY WILLIAM WILLIE WILMA
    YOLANDA YVONNE ZACHARY
    """.split()
)

# Famous surnames / people often in Scrabble lexicons.
FAMOUS_SURNAMES = frozenset(
    w.upper()
    for w in """
    ABBOTT ADAMS ALLEN ANDERSON ARMSTRONG ARNOLD AUSTEN BACON BACH BEATLES BEETHOVEN
    BELL BENNETT BISMARCK BONAPARTE BOWIE BROWN BRUCE BUDDHA BURKE BURNS BURTON BUSH
    BUTLER BYRON CAESAR CALVIN CAMERON CAMPBELL CARTER CHAPMAN CHASE CHOPIN CHURCHILL
    CLARK CLINTON COLEMAN COLLINS COLUMBUS COOPER COPERNICUS DARWIN DICKENS DISNEY
    EINSTEIN FORD GRAHAM GRANT HARRISON HAWKING HITLER HOMER JACKSON JEFFERSON JONES
    KENNEDY KING LEWIS LINCOLN MADONNA MARX MICHAEL MONROE MOSES MOZART NAPOLEON
    NEWTON NIXON PICASSO PLATO QUEEN ROBINSON ROOSEVELT SHAKESPEARE SMITH SOCRATES
    STEVENSON TAYLOR THATCHER THOMAS TRUMP TURING VICTORIA WASHINGTON WILSON WINSTON
    WOODROW ZEPPELIN AARON ABDULLAH ABRAHAM ADOLF AGNEW ALFRED ALICE ANDERSON
    MENDELSSOHN SHACKLETON
    """.split()
)


def load_dictionary() -> set[str]:
    return {
        line.strip().upper()
        for line in DICT_PATH.read_text(encoding="utf-8").splitlines()
        if line.strip().isalpha()
    }


def fetch_census_surnames(limit: int = 5000) -> set[str]:
    url = "https://www2.census.gov/topics/genealogy/data/2010surnames/names.zip"
    try:
        with urllib.request.urlopen(url, timeout=30) as resp:
            data = resp.read()
        with zipfile.ZipFile(io.BytesIO(data)) as zf:
            name = zf.namelist()[0]
            text = zf.read(name).decode("utf-8", errors="replace")
        surnames: set[str] = set()
        for row in csv.DictReader(text.splitlines()):
            word = row.get("name", "").strip().upper()
            if word and word.isalpha():
                surnames.add(word)
            if len(surnames) >= limit:
                break
        return surnames
    except Exception as exc:
        print(f"  (Census surname fetch failed: {exc})")
        return set()


def fetch_ssa_forenames() -> set[str]:
    """SSA national baby names 1920-2024 (names with count >= 100 in any year)."""
    names: set[str] = set()
    base = "https://raw.githubusercontent.com/hadley/data-baby-names/master/baby-names.csv"
    try:
        with urllib.request.urlopen(base, timeout=30) as resp:
            text = resp.read().decode("utf-8", errors="replace")
        for row in csv.DictReader(text.splitlines()):
            n = row.get("name", "").strip().upper()
            if n.isalpha():
                names.add(n)
        return names
    except Exception as exc:
        print(f"  (SSA forename fetch failed: {exc})")
        return set()


def main() -> None:
    words = load_dictionary()
    print(f"Dictionary: {DICT_PATH.name} — {len(words):,} words\n")

    ssa = fetch_ssa_forenames()
    census = fetch_census_surnames(8000)

    forenames_in_dict = words & (FORENAMES | ssa)
    nicknames_in_dict = words & NICKNAMES
    # Nicknames not already counted as forenames
    nicknames_only = nicknames_in_dict - forenames_in_dict

    surnames_in_dict = words & (FAMOUS_SURNAMES | census)
    # Remove obvious forenames from surname set for overlap stats
    forename_surname_overlap = forenames_in_dict & surnames_in_dict

    all_personal = forenames_in_dict | surnames_in_dict | nicknames_in_dict
    # Words that are primarily names (in name lists) — union
    name_union = forenames_in_dict | surnames_in_dict | nicknames_only

    print("=== COUNTS (words in EnglishWords5 that match name lists) ===")
    print(f"  Forenames (curated + SSA dataset):     {len(forenames_in_dict):,}")
    print(f"    — from SSA baby-names CSV only:      {len(words & ssa):,}")
    print(f"    — from curated forename list only:   {len(words & FORENAMES):,}")
    print(f"  Nicknames / diminutives (curated):     {len(nicknames_in_dict):,}")
    print(f"    — nicknames not in forename sets:    {len(nicknames_only):,}")
    print(f"  Surnames (Census top 8k + famous):     {len(surnames_in_dict):,}")
    print(f"    — from Census 2010 surnames only:    {len(words & census):,}")
    print(f"    — from famous-surname list only:     {len(words & FAMOUS_SURNAMES):,}")
    print(f"  Forename ∩ surname overlap:            {len(forename_surname_overlap):,}")
    print(f"  UNION (any personal-name list):        {len(name_union):,}")
    print(f"  As % of dictionary:                    {100 * len(name_union) / len(words):.2f}%")

    print("\n=== SHORT NICKNAMES IN DICTIONARY (2–4 letters) ===")
    short_nicks = sorted(w for w in nicknames_in_dict if len(w) <= 4)
    print(f"  Count: {len(short_nicks)}")
    print("  " + ", ".join(short_nicks))

    print("\n=== SAMPLE FORENAMES IN DICTIONARY (random-ish by length) ===")
    for n in (3, 4, 5, 6):
        sample = sorted(w for w in forenames_in_dict if len(w) == n)[:12]
        if sample:
            print(f"  {n}-letter: {', '.join(sample)}")

    print("\n=== SAMPLE SURNAMES IN DICTIONARY ===")
    census_only = sorted((words & census) - FAMOUS_SURNAMES)[:25]
    famous = sorted(words & FAMOUS_SURNAMES)[:25]
    print(f"  Census (sample): {', '.join(census_only)}")
    print(f"  Famous (sample): {', '.join(famous)}")

    print("\n=== HOMOGRAPH WARNING (name AND common word) ===")
    homographs = sorted(
        w
        for w in name_union
        if w
        in """
        GRANT CHASE MARK GRACE VICTORIA CHRISTIAN WILL MARKS ROSE IVY JUNE MAY APRIL
        AUGUST FAITH HOPE JOY KING PRINCE DUKE EARL COUNT MARKS BROWN WHITE GREEN
        YOUNG LONG SHORT SHARP SWIFT STONE WOLF FOX HART LAMB FISH BIRD HILL FIELD
        BROOK RIVER LAKE FOREST PARK HUNTER FISHER MASON TAYLOR COOK BAKER MILLER
        """.split()
    )
    print(f"  {len(homographs)} examples: {', '.join(homographs[:30])}")

    print("\n=== NOTES ===")
    print("  • Counts are list-matched, not linguistically verified per entry.")
    print("  • Many 'names' are also ordinary English (BROWN, GRANT, APRIL).")
    print("  • True personal-name-only count is lower than UNION figure.")
    print("  • Census covers US surnames; forenames from SSA; nicknames curated.")


if __name__ == "__main__":
    main()
