"""Extract Phase 2B1 source data from GAME25.json group #13 (Letter Drop)."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
JSON_PATH = ROOT / "reference" / "GAME25.json"
OUT_PATH = ROOT / "reports" / "phase2b1_extract_raw.json"


def main() -> None:
    data = json.loads(JSON_PATH.read_text(encoding="utf-8"))
    layout = next(l for l in data["layouts"] if l["name"] == "Main2_heallthbartest")
    grp = layout["events"][13]

    letter_obj = next((o for o in data.get("objects", []) if o.get("name") == "Letter1"), None)

    # scene variables from layout
    variables = layout.get("variables", [])

    # collect relevant events as flat records
    records: list[dict] = []

    def walk(evs: list, path: str = "") -> None:
        for idx, ev in enumerate(evs):
            if ev.get("disabled"):
                continue
            et = ev.get("type", "")
            loc = f"{path}/{idx}"
            if et == "BuiltinCommonInstructions::Standard":
                conds = ev.get("conditions", [])
                acts = ev.get("actions", [])
                blob = json.dumps(conds + acts).lower()
                keywords = (
                    "letter", "spell", "dict", "score", "vowel", "delete", "word",
                    "spawn", "create", "timer", "random", "collect", "pick", "submit",
                    "erase", "alphabet", "consonant",
                )
                if any(k in blob for k in keywords):
                    records.append({
                        "path": loc,
                        "conditions": [
                            {"type": c.get("type", ""), "params": c.get("parameters", [])}
                            for c in conds
                        ],
                        "actions": [
                            {"type": a.get("type", ""), "params": a.get("parameters", [])}
                            for a in acts
                        ],
                    })
            elif et in (
                "BuiltinCommonInstructions::Repeat",
                "BuiltinCommonInstructions::While",
                "BuiltinCommonInstructions::ForEach",
                "BuiltinCommonInstructions::Group",
            ):
                walk(ev.get("events", []), loc)

    walk(grp.get("events", []))

    # global/scene vars mentioning spell/score/letter
    var_hits = []
    for v in variables:
        name = v.get("name", "")
        if re.search(r"spell|score|letter|word|dict|vowel", name, re.I):
            var_hits.append(v)

    out = {
        "group_index": 13,
        "group_name": grp.get("name"),
        "group_disabled": grp.get("disabled"),
        "event_record_count": len(records),
        "records": records,
        "scene_variables": var_hits,
        "letter1_object": letter_obj,
    }
    OUT_PATH.write_text(json.dumps(out, indent=2), encoding="utf-8")
    print(f"Wrote {OUT_PATH} ({len(records)} event records)")


if __name__ == "__main__":
    main()
