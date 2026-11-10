"""Report actual earned routes; retain unresolved searches separately from errors."""
from pathlib import Path
import csv
import json
import re

ROOT = Path(__file__).resolve().parents[1]
RUNTIME = ROOT / "qa_runtime/late_growth_20261030"
BASE = ROOT / "qa_runtime/economy_20261029"
TAGS = ["carrier_731042", "carrier_17", "scout_731042", "compression_heavy"]
FOLLOWUPS = {("carrier_17", "burst"): "burst_17_prepared",
             ("carrier_17", "scatter"): "scatter_17_prepared",
             ("scout_731042", "heavy"): "scout_heavy_prepared"}


def read(path):
    return json.loads(path.read_text(encoding="utf-8"))


def old_tag(tag, gun):
    if tag == "scout_731042":
        return "b1_scout"
    if tag == "compression_heavy":
        return "workshop_compress"
    return "b1_heavy_carrier" if gun == "heavy" else "b1_single_burst_carrier" if gun in ["single", "burst"] else "b1_scatter_spike_carrier"


def main():
    rows, growth, early_changes, early_count = [], [], [], 0
    for tag in TAGS:
        data = read(RUNTIME / tag / "balance.json")
        for endpoint in data["endpoints"]:
            gun, seed = endpoint["gun"], int(endpoint["seed"])
            battles = {int(b["node"]): b for b in data["battles"] if b["gun"] == gun and int(b["seed"]) == seed and b["solved"]}
            baseline = read(BASE / old_tag(tag, gun) / "balance.json")
            old = {int(b["node"]): b for b in baseline["battles"] if b["gun"] == gun and int(b["seed"]) == seed and b["solved"]}
            for node, battle in battles.items():
                if battle["region"] > 2:
                    continue
                early_count += 1
                keys = ["path", "turns", "used", "generated", "remaining", "end_engine"]
                if any(battle[k] != old[node][k] for k in keys):
                    early_changes.append(dict(tag=tag, gun=gun, seed=seed, node=node))
            won = endpoint["won"]
            followup = FOLLOWUPS.get((tag, gun), "")
            if followup:
                continuation = read(RUNTIME / followup / "balance.json")
                final = continuation["endpoints"][0]
                assert final["gun"] == gun and int(final["seed"]) == seed
                assert Path(final["source"]).parent.name == tag
                battles.update({int(b["node"]): b for b in continuation["battles"] if b["solved"]})
                won = final["won"]
            ordered = sorted(battles.values(), key=lambda b: int(b["node"]))
            reached = {}
            for battle in ordered:
                level = max(battle["end_engine"]["levels"].values(), default=0)
                for threshold in [8, 10, 12, 14]:
                    if level >= threshold and threshold not in reached:
                        reached[threshold] = dict(region=battle["region"], floor=battle["floor"])
            growth.append(dict(tag=tag, gun=gun, seed=seed, reached=reached))
            rows.append(dict(tag=tag, gun=gun, seed=seed, outfit=endpoint["outfit"], direct_won=endpoint["won"],
                             after_preparation_won=won, followup=followup, battles=len(ordered),
                             turns=sum(b["turns"] for b in ordered), min_remaining=min(b["remaining"] for b in ordered),
                             final_remaining=ordered[-1]["remaining"] if won else None,
                             forced_turns=sum(b["metrics"]["forced_turns"] for b in ordered),
                             final_core_levels=ordered[-1]["end_engine"]["levels"]))
    logs = [RUNTIME / tag / "stdout.log" for tag in TAGS + list(FOLLOWUPS.values()) +
            ["burst_17_probe", "scatter_17_probe", "rules_release", "ui_release_final"]]
    logs += [ROOT / "qa_runtime/gate/rules/stdout.log", ROOT / "qa_runtime/gate/ui/stdout.log",
             ROOT / "qa_runtime/damage_engines/rules/stdout.log",
             ROOT / "qa_runtime/playtest_revision_20261026/sustained/late_growth_20261030/stdout.log"]
    checks = []
    for path in logs:
        match = re.search(r"COMPLETE checks=(\d+) failures=(\d+)", path.read_text(encoding="utf-8"))
        assert match, str(path)
        checks.append(dict(path=path.relative_to(ROOT).as_posix(), checks=int(match[1]), failures=int(match[2])))
    summary = dict(note="Bounded search knows future draws and RNG. Neither human win rates nor optimal routes. Preparation uses actual campaign commands; repeated prefixes are not counted twice as battles.",
                   fresh_runs=len(rows), direct_endings=sum(r["direct_won"] for r in rows),
                   endings_after_preparation=sum(r["after_preparation_won"] for r in rows),
                   integrated_battles=sum(r["battles"] for r in rows), early_battles=early_count,
                   early_changes=early_changes, checks=sum(r["checks"] for r in checks),
                   failures=sum(r["failures"] for r in checks), runs=rows, growth=growth, executions=checks)
    (RUNTIME / "summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
    with (RUNTIME / "runs.csv").open("w", newline="", encoding="utf-8-sig") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0])); writer.writeheader(); writer.writerows(rows)
    print(json.dumps({k:v for k,v in summary.items() if k not in ["note", "runs", "growth", "executions"]}))
    assert not early_changes, "Early combat outcomes changed"
    assert not summary["failures"], "Functional failures remain"


if __name__ == "__main__":
    main()
