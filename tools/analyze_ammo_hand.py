"""Compare paired A/B playtest logs without confusing fired shots with load decisions.

Usage: python tools/analyze_ammo_hand.py INPUT_DIRECTORY --output REPORT.json
Only matched seed/scenario/gun/parts/deck/policy cohorts are compared. Missing
loadout telemetry remains unknown; it is never inferred from truncated shots.
"""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
import json
from pathlib import Path


def bullet_id(bullet):
    return bullet.get("resource_path", "").replace("\\", "/").rsplit("/", 1)[-1].removesuffix(".tres") or bullet.get("id", "unknown")


def summarize(encounters):
    orders, combinations, axes = Counter(), Counter(), Counter()
    shots = basic_shots = effective_tactical = windows = diverse_windows = 0
    available_types = 0
    missing = 0
    results = Counter()
    for encounter in encounters:
        results[encounter.get("result", "unknown")] += 1
        if "loadouts" not in encounter:
            missing += 1
        for loadout in encounter.get("loadouts", []):
            firing = loadout.get("fire_order", [])
            if not firing:
                continue
            order = tuple(bullet_id(b) for b in firing)
            orders[order] += 1
            combinations[tuple(sorted(order))] += 1
            tactical = [b for b in firing if not b.get("is_basic", False)]
            specialty = tuple(b.get("specialty", "") for b in tactical)
            if specialty:
                axes[specialty] += 1
            offered = loadout.get("available_tactical", [])
            offered_axes = {b.get("specialty") for b in offered if b.get("specialty")}
            available_types += len({bullet_id(b) for b in offered})
            windows += 1
            # This measures opportunity and observed selection, not human meaning.
            diverse_windows += bool(tactical) and len(offered_axes) >= 2
        for shot in encounter.get("shots", []):
            shots += 1
            basic = bool(shot.get("bullet", {}).get("is_basic", False))
            basic_shots += basic
            effective_tactical += not basic and bool(shot.get("effective", False))
    return {
        "encounters": len(encounters), "outcomes": dict(results),
        "load_windows": windows, "missing_loadout_logs": missing,
        "distinct_firing_orders": len(orders), "distinct_combinations": len(combinations),
        "distinct_tactical_axis_orders": len(axes),
        "repeated_order_fraction": (windows - len(orders)) / windows if windows else None,
        "shots": shots, "basic_shot_fraction": basic_shots / shots if shots else None,
        "effective_tactical_shots": effective_tactical,
        "mean_offered_tactical_types": available_types / windows if windows else None,
        "diverse_choice_windows_with_tactical_selection": diverse_windows,
        "human_meaningful_choices": None,
        "firing_orders": [{"ids": list(k), "count": v} for k, v in sorted(orders.items())],
    }


def analyze(documents):
    cohorts = defaultdict(lambda: {"A": [], "B": []})
    rejected = []
    for source, document in documents:
        entries = document.get("encounters", [])
        if "shots" in document:
            entries = [document]
        for encounter in entries:
            variant = encounter.get("ammo_hand", {}).get("comparison_variant", "")
            if variant not in ("A", "B"):
                continue
            match = encounter.get("comparison", {})
            required = ("seed", "scenario", "gun_id", "parts", "deck", "policy")
            if not all(k in match for k in required):
                rejected.append({"source": source, "reason": "missing explicit paired conditions"})
                continue
            key = json.dumps({k: match[k] for k in required}, sort_keys=True, ensure_ascii=False)
            cohorts[key][variant].append(encounter)
    pairs, flat = [], {"A": [], "B": []}
    for key, variants in sorted(cohorts.items()):
        if len(variants["A"]) != 1 or len(variants["B"]) != 1:
            rejected.append({"conditions": json.loads(key), "reason": "missing or duplicate paired encounter"})
            continue
        pairs.append({"conditions": json.loads(key), **{v: summarize(es) for v, es in variants.items()}})
        for variant in flat:
            flat[variant].extend(variants[variant])
    metrics = {v: summarize(es) for v, es in flat.items()}
    deltas = {}
    for key in ("repeated_order_fraction", "basic_shot_fraction", "distinct_combinations",
                "distinct_firing_orders", "diverse_choice_windows_with_tactical_selection"):
        a, b = metrics["A"][key], metrics["B"][key]
        deltas[key] = b - a if a is not None and b is not None else None
    return {
        "schema": "lob.ammo_hand_comparison", "version": 1,
        "matched_pairs": len(pairs), "metrics": metrics, "delta_B_minus_A": deltas,
        "pairs": pairs, "rejected": rejected,
        "decision": "HUMAN_PLAY_REQUIRED" if pairs else "INSUFFICIENT_PAIRED_DATA",
        "limitations": [
            "Choice windows are an opportunity proxy, not a measurement of human enjoyment.",
            "Basic ammunition availability does not prove that every encounter is solvable.",
            "Policy probe wins are not a campaign win-rate estimate.",
        ],
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    paths = sorted(args.input.rglob("*.json")) if args.input.is_dir() else [args.input]
    documents = []
    for path in paths:
        if path.resolve() == args.output.resolve():
            continue
        try:
            document = json.loads(path.read_text(encoding="utf-8-sig"))
        except (ValueError, OSError):
            continue
        if isinstance(document, dict):
            documents.append((str(path), document))
    report = analyze(documents)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"matched_pairs": report["matched_pairs"], "decision": report["decision"],
                      "rejected": len(report["rejected"]), "metrics": report["metrics"]}, ensure_ascii=False))
    return 0 if report["matched_pairs"] and not report["rejected"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
