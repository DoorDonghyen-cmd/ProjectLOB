"""Summarize explicitly selected fresh runs and validated continuations."""
from pathlib import Path
import csv
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parents[1]
RUNTIME = ROOT / "qa_runtime/economy_20261029"
MATRIX = [
    "b1_heavy_carrier", "b1_single_burst_carrier", "b1_scatter_spike_carrier",
    "b1_scout", "b1_expedition", "prior_heat_carrier", "workshop_bag",
    "workshop_compress", "supply_route",
]
CONTINUATIONS = {
    ("b1_single_burst_carrier", "burst", 17): "burst_17_prepared",
    ("b1_scatter_spike_carrier", "scatter", 17): "scatter_17_prepared",
    ("b1_scout", "burst", 731042): "scout_burst_adaptive",
    ("b1_scout", "heavy", 731042): "scout_heavy_prepared_v2",
    ("b1_scout", "scatter", 731042): "scout_scatter_final",
}
PROBES = ["scatter_17_diagnosis", "burst_17_diagnosis", "scout_burst_diagnosis",
          "scout_heavy_diagnosis", "scout_scatter_diagnosis", "compressed_heavy_diagnosis",
          "scout_heavy_final_diagnosis"]


def load(tag, filename="balance.json"):
    return json.loads((RUNTIME / tag / filename).read_text(encoding="utf-8"))


def main():
    runs, battle_rows, diagnostics, artifacts, growth, resupplies = [], [], [], [], [], []
    for tag in MATRIX:
        data = load(tag)
        for endpoint in data["endpoints"]:
            gun, seed, outfit = endpoint["gun"], int(endpoint["seed"]), endpoint["outfit"]
            relevant = [b for b in data["battles"]
                        if (b["gun"], int(b["seed"]), b["outfit"]) == (gun, seed, outfit)]
            solved = {int(b["node"]): b for b in relevant if b["solved"]}
            won = endpoint["won"]
            followup = CONTINUATIONS.get((tag, gun, seed), "")
            preparation = ""
            if followup:
                continuation = load(followup)
                assert len(continuation["endpoints"]) == 1
                final = continuation["endpoints"][0]
                assert final["gun"] == gun and int(final["seed"]) == seed and final["outfit"] == outfit
                assert Path(final["source"]).parent.name == tag
                solved.update({int(b["node"]): b for b in continuation["battles"] if b["solved"]})
                won = final["won"]
                preparation = final["preparation"]
            battles = list(solved.values())
            for battle in battles:
                if not battle["generated"]:
                    continue
                traces = battle["metrics"]["traces"]
                first = next(i for i, trace in enumerate(traces) if trace["action"] == "emergency")
                shots = [shot for trace in traces[first + 1:] if trace["action"] == "fire"
                         for shot in trace["detail"].get("results", [])]
                resupplies.append(dict(tag=tag, gun=gun, seed=seed, region=battle["region"],
                                       node=battle["node"], generated=battle["generated"],
                                       cost=battle["metrics"]["emergency_turns"], remaining=battle["remaining"],
                                       shots_after_resupply=[dict(id=s["id"], damage=s["damage"], target=s["target"])
                                                              for s in shots]))
            if tag in ["b1_heavy_carrier", "b1_single_burst_carrier", "b1_scatter_spike_carrier"]:
                capped = next((b for b in battles if 8 in b.get("end_engine", {}).get("levels", {}).values()), None)
                if capped:
                    growth.append(dict(gun=gun, seed=seed, region=capped["region"], floor=capped["floor"]))
            battle_rows.extend([dict(tag=tag, gun=gun, seed=seed, outfit=outfit, node=b["node"],
                                     region=b["region"], turns=b["turns"], start_ammo=b["start_ammo"],
                                     generated=b["generated"], used=b["used"], remaining=b["remaining"],
                                     forced_turns=b["metrics"]["forced_turns"], margin=b["margin"],
                                     hand=b["hand_capacity"], core_levels=json.dumps(b.get("end_engine", {}).get("levels", {})))
                                for b in battles])
            runs.append(dict(tag=tag, gun=gun, seed=seed, outfit=outfit,
                             heat_rule=endpoint["heat_rule"], route=endpoint["route"],
                             workshop=endpoint.get("workshop_policy", "refit"),
                             direct_won=endpoint["won"], after_followup_won=won,
                             followup=followup, preparation=preparation,
                             solved_combats=len(battles), turns=sum(b["turns"] for b in battles),
                             forced_turns=sum(b["metrics"]["forced_turns"] for b in battles),
                             forced_reloads=sum(b["metrics"]["forced_reloads"] for b in battles),
                             emergency_packs=sum(b["generated"] for b in battles) // 4,
                             min_remaining=min(b["remaining"] for b in battles),
                             final_remaining=battles[-1]["remaining"] if won else None,
                             final_turns=battles[-1]["turns"] if won else None,
                             max_hand=max(b["hand_capacity"] for b in battles),
                             final_parts=battles[-1]["parts"]))
    for tag in PROBES:
        data = load(tag, "probe.json")
        for row in data["rows"]:
            diagnostics.append(dict(tag=tag, mode=row["mode"], solved=row["solved"],
                                    turns=row["turns"] if row["solved"] else None,
                                    remaining=row["remaining"] if row["solved"] else None,
                                    preparation=[s for s in row["path"] if s["action"] in ["exchange", "field_compress"]]))
    for tag in MATRIX + list(CONTINUATIONS.values()) + PROBES:
        folder = RUNTIME / tag
        text = (folder / "stdout.log").read_text(encoding="utf-8")
        match = re.search(r"ECONOMY (?:CAMPAIGN|RECOVERY|PROBE) COMPLETE checks=(\d+) failures=(\d+)", text)
        if not match:
            raise RuntimeError(f"Incomplete execution: {tag}")
        artifacts.append(dict(tag=tag, checks=int(match[1]), failures=int(match[2])))
    result = dict(note="31 fresh runs. Failed bounded searches are not defeats or proof of impossibility. "
                       "Validated followups preserve the earned prefix and use recorded legal commands. "
                       "Turn totals are found routes, not optimal/human win rates. Compare full runs only.",
                  fresh_runs=len(runs), direct_completed=sum(r["direct_won"] for r in runs),
                  completed_after_followups=sum(r["after_followup_won"] for r in runs),
                  integrated_solved_combats=len(battle_rows), checks=sum(a["checks"] for a in artifacts),
                  failures=sum(a["failures"] for a in artifacts), runs=runs, diagnostics=diagnostics,
                  core_cap_reached=growth, resupplies=resupplies, artifacts=artifacts)
    (RUNTIME / "summary.json").write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    for name, rows in [("runs.csv", runs), ("battles.csv", battle_rows)]:
        with (RUNTIME / name).open("w", newline="", encoding="utf-8-sig") as stream:
            writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
            writer.writeheader(); writer.writerows(rows)
    print(json.dumps({k: result[k] for k in ["fresh_runs", "direct_completed", "completed_after_followups", "integrated_solved_combats", "checks", "failures"]}))
    # Production was deliberately kept unchanged during this audit.
    before = json.loads((RUNTIME / "production_before.json").read_text(encoding="utf-8"))
    changed = [name for name, digest in before.items()
               if hashlib.sha256((ROOT / name).read_bytes()).hexdigest() != digest]
    print("Production changes:", changed)
    if changed:
        raise RuntimeError("Production source changed during the audit")


if __name__ == "__main__":
    main()
