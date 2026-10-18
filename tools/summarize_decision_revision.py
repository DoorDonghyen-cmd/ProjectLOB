"""Compare the frozen v10 audit with a fresh v11 run of the same policies."""
import collections
import gzip
import json
from pathlib import Path
import statistics

ROOT = Path(__file__).resolve().parent.parent
FROZEN = ROOT / "docs/qa/reports/decision_depth_2026-10-04_assets"
RUNTIME = ROOT / "qa_runtime"


def group(rows, keys):
    result = collections.defaultdict(list)
    for row in rows:
        result[tuple(row[key] for key in keys)].append(row)
    return result


def wins(rows, keys):
    return [dict(zip(keys, key), cases=len(items), wins=sum(r["won"] for r in items))
            for key, items in group(rows, keys).items()]


def summarize(baseline, depth):
    assert not baseline["failures"] and not depth["failures"]
    result = {
        "version": depth["version"],
        "baseline": wins(baseline["rows"], ["gun", "policy"]),
        "campaigns": wins(depth["campaigns"], ["gun", "growth", "policy"]),
        "builds": wins(depth["independent"], ["gun", "policy"]),
        "decks": wins(depth["independent"], ["deck", "policy"]),
        "heat": [], "all_hand": [], "matched_turns": [],
        "opening_states": len(depth["opening_choices"]),
        "opening_plans": sum(len(r["records"]) for r in depth["opening_choices"]),
    }
    for (policy,), rows in group(depth["independent"], ["policy"]).items():
        result["heat"].append(dict(policy=policy, cases=len(rows), wins=sum(r["won"] for r in rows),
                                  **{k: sum(r[k] for r in rows) for k in
                                     ["forced", "forced_no_unfired", "unfired_heat", "overheated", "terminal_heat_waived"]}))
    for gun in ["single", "burst", "scatter", "heavy", "amplifier"]:
        encounters = [e for r in depth["campaigns"] if r["gun"] == gun and r["growth"] == "expand"
                      and r["policy"] == "random" for e in r["encounters"] if e["region"] > 0]
        result["all_hand"].append(dict(gun=gun, loads=sum(e["loads"] for e in encounters),
                                       all_tactical_fit=sum(e["all_tactical_fit"] for e in encounters)))
    for gun in ["single", "heavy"]:
        cases = group([r for r in baseline["rows"] if r["gun"] == gun], ["seed", "node"])
        pairs = []
        for rows in cases.values():
            policies = {r["policy"]: r for r in rows}
            if all(policies[p]["won"] for p in ["random", "guided"]):
                pairs.append((policies["random"]["turns"], policies["guided"]["turns"]))
        result["matched_turns"].append(dict(gun=gun, pairs=len(pairs),
                                            random=statistics.mean(p[0] for p in pairs),
                                            guided=statistics.mean(p[1] for p in pairs)))
    return result


before = summarize(json.loads(gzip.decompress((FROZEN / "baseline.json.gz").read_bytes())),
                   json.loads(gzip.decompress((FROZEN / "depth.json.gz").read_bytes())))
after = summarize(json.loads((RUNTIME / "ammo_choice/ammo_choice_audit.json").read_text(encoding="utf-8-sig")),
                  json.loads((RUNTIME / "decision_depth/decision_depth.json").read_text(encoding="utf-8-sig")))
destination = RUNTIME / "decision_revision/comparison.json"
destination.parent.mkdir(parents=True, exist_ok=True)
destination.write_text(json.dumps(dict(before=before, after=after), ensure_ascii=False, indent=2), encoding="utf-8")
print(destination)
print(json.dumps(dict(heat=after["heat"], all_hand=after["all_hand"], matched_turns=after["matched_turns"]), indent=2))
