"""Summarize review probes without treating policy success as human win rate."""
import collections
import json
from pathlib import Path
import statistics

ROOT = Path(__file__).resolve().parent.parent
RUNTIME = ROOT / "qa_runtime" / "decision_depth"
depth = json.loads((RUNTIME / "decision_depth.json").read_text(encoding="utf-8-sig"))
baseline = json.loads((ROOT / "qa_runtime/ammo_choice/ammo_choice_audit.json").read_text(encoding="utf-8-sig"))
assert not depth["failures"] and not baseline["failures"]


def grouped(rows, keys):
    groups = collections.defaultdict(list)
    for row in rows:
        groups[tuple(row[key] for key in keys)].append(row)
    return groups


def success_table(rows, keys):
    return [dict(zip(keys, key), cases=len(items), wins=sum(item["won"] for item in items))
            for key, items in grouped(rows, keys).items()]


summary = {
    "model_version": depth["version"],
    "baseline": success_table(baseline["rows"], ["gun", "policy"]),
    "campaigns": success_table(depth["campaigns"], ["growth", "gun", "policy"]),
    "independent_decks": success_table(depth["independent"], ["deck", "policy"]),
    "independent_packages": success_table(depth["independent"], ["package", "policy"]),
    "independent_guns": success_table(depth["independent"], ["gun", "policy"]),
    "heat": [], "opening_choices": [], "random_campaign_encounters": [],
    "conditional_effects": [], "matched_turns": [],
    "baseline_cases": len(baseline["rows"]), "campaign_cases": len(depth["campaigns"]),
    "independent_cases": len(depth["independent"]),
    "opening_states": len(depth["opening_choices"]),
    "opening_plans": sum(len(item["records"]) for item in depth["opening_choices"]),
}
for (policy,), items in grouped(depth["independent"], ["policy"]).items():
    summary["heat"].append({"policy": policy, **{
        key: sum(item[key] for item in items) for key in
        ["overheated", "forced", "terminal_heat_waived", "forced_no_unfired", "unfired_heat", "loads", "volleys"]}})
for (gun, floor), states in grouped(depth["opening_choices"], ["gun", "floor"]).items():
    items = [row for state in states for row in state["records"]]
    summary["opening_choices"].append({"gun": gun, "floor": floor, "states": len(states),
        "plans": len(items), "wins": sum(row["won"] for row in items),
        "unsafe_extra_reload": sum(not row["next_reload_safe"] for row in items),
        "kills": dict(collections.Counter(row["kills"] for row in items))})
for (gun, growth), runs in grouped([r for r in depth["campaigns"] if r["policy"] == "random"], ["gun", "growth"]).items():
    items = [e for run in runs for e in run["encounters"]]
    won = [e for e in items if e["won"]]
    later = [e for e in items if e["region"] > 0]
    summary["random_campaign_encounters"].append({"gun": gun, "growth": growth,
        "encounters": len(items), "wins": len(won), "credit_offer_8": sum(e["credit_offer"] == 8 for e in won),
        "mean_credit_offer_won": statistics.mean(e["credit_offer"] for e in won),
        "forced": sum(e["forced"] for e in items), "overheated": sum(e["overheated"] for e in items),
        "volleys": sum(e["volleys"] for e in items), "loads": sum(e["loads"] for e in items),
        "later_loads": sum(e["loads"] for e in later),
        "later_all_tactical_fit": sum(e["all_tactical_fit"] for e in later),
        "maximum_equipped_parts": max(len(e["parts"]) for e in items)})
for (deck, policy), items in grouped(depth["independent"], ["deck", "policy"]).items():
    effects = {}
    for row in items:
        for effect, counts in row["conditional"].items():
            bucket = effects.setdefault(effect, {"active": 0, "fired": 0})
            for key in bucket:
                bucket[key] += counts[key]
    summary["conditional_effects"].append({"deck": deck, "policy": policy, "effects": effects})
for gun in ["single", "heavy"]:
    pairs = grouped([r for r in baseline["rows"] if r["gun"] == gun and r["policy"] in ["random", "guided"]], ["seed", "node"])
    common = [{r["policy"]: r for r in pair} for pair in pairs.values() if all(r["won"] for r in pair)]
    summary["matched_turns"].append({"gun": gun, "both_won": len(common),
        "random": statistics.mean(pair["random"]["turns"] for pair in common),
        "guided32": statistics.mean(pair["guided"]["turns"] for pair in common)})

assert summary["campaign_cases"] == 270 and summary["independent_cases"] == 2400
assert summary["baseline_cases"] == 2592 and summary["opening_states"] == 72
assert all(x["forced_no_unfired"] <= x["forced"] <= x["overheated"] for x in summary["heat"])
assert all(x["terminal_heat_waived"] + x["forced"] <= x["overheated"] for x in summary["heat"])
(RUNTIME / "summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(f"Summary verified: {summary['baseline_cases']} baseline encounters, {summary['campaign_cases']} campaigns, "
      f"{summary['independent_cases']} build encounters, {summary['opening_plans']} opening plans.")
