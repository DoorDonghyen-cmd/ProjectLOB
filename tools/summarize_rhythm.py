"""Collect only final rhythm QA runs; archive their exact inputs and code."""
from pathlib import Path
import hashlib
import json
import shutil
import zipfile

ROOT = Path(__file__).resolve().parents[1]
RUNTIME = ROOT / "qa_runtime/combat_rhythm_20261030"
ASSETS = ROOT / "docs/qa/reports/assets/combat_rhythm_2026-10-30"
TAGS = ["rules_final3", "matrix_final", "work17_final", "scout_final", "probes_final", "ui_verified", "continuation_final"]


def read(path):
    return json.loads(path.read_text(encoding="utf-8"))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    ASSETS.mkdir(parents=True, exist_ok=True)
    reports = {}
    for tag in TAGS:
        report = read(RUNTIME / tag / ("ui.json" if tag == "ui_verified" else "results.json"))
        if tag == "continuation_final":
            allowed = {"fresh earned route heavy_731042_r5_n41002", "earned equipment reaches ending heavy"}
            assert set(report["failures"]).issubset(allowed), (tag, report["failures"])
            if report["failures"]:
                missed = [b for b in report["battles"] if not b["solved"]]
                assert len(missed) == 1 and missed[0]["gun"] == "heavy" and missed[0]["node"] == 41002 and not missed[0]["path"]
        else:
            assert not report["failures"], (tag, report["failures"])
        assert "COMPLETE" in (RUNTIME / tag / "stdout.log").read_text(encoding="utf-8")
        assert not (RUNTIME / tag / "stderr.log").read_text(encoding="utf-8").strip(), tag
        reports[tag] = report
    slices = [row for tag in ["matrix_final", "work17_final", "scout_final"] for row in reports[tag]["battles"]]
    endpoints = [row for tag in ["matrix_final", "work17_final", "scout_final"] for row in reports[tag]["endpoints"]]
    summary = {
        "note": "Bounded search with future draw/RNG; not human win rate, optimality or fun validation.",
        "checks": sum(r["checks"] for r in reports.values()),
        "failures": reports["continuation_final"]["failures"],
        "failure_classification": "Continuation failures, if present, are two unmet reachability assertions for one heavy final-boss condition. They are retained, not counted as successful checks. No other failure is accepted.",
        "runs": {tag: {"checks": r["checks"], "battles": len(r.get("battles", []))} for tag, r in reports.items()},
        "slice_runs": len(endpoints),
        "slice_success": sum(row["won"] for row in endpoints),
        "new_slice_runs": sum(row["version"] == 12 for row in endpoints),
        "slice_battles": len(slices),
        "continuations": [{k: v for k, v in row.items() if k != "commands"} for row in reports["continuation_final"]["endpoints"]],
        "continuation_battles": len(reports["continuation_final"]["battles"]),
        "matrix": [{k: row[k] for k in ["gun", "version", "floor", "role", "turns", "used"]} for row in reports["matrix_final"]["battles"]],
        "timing": [{k: v for k, v in row.items() if k not in ["commands", "traces", "detail"]} for row in reports["probes_final"]["comparisons"]],
    }
    before = read(RUNTIME / "production_before.json")
    current = {str(p.relative_to(ROOT)): sha(p) for p in (ROOT / "새-게임-프로젝트/redesign").glob("*.gd")}
    summary["changed_production"] = [p for p, digest in current.items() if digest != before.get(p)]
    legacy = read(RUNTIME / "legacy_heavy/combat_heavy_731042_r5_n41002.json")
    latest = read(RUNTIME / "continuation_final/combat_heavy_731042_r5_n41002.json")
    differences = {section: sorted(k for k in set(legacy[section]) | set(latest[section]) if legacy[section].get(k) != latest[section].get(k)) for section in ["campaign", "combat"]}
    assert differences["campaign"] == ["log", "roster_version"]
    assert differences["combat"] == ["history", "reloads", "shots", "turns"]
    summary["heavy_final_legacy_comparison"] = differences
    (ASSETS / "summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
    for p in (RUNTIME / "ui_verified").glob("*.png"):
        shutil.copy2(p, ASSETS / p.name)
    paths = []
    for tag in TAGS:
        paths += [p for p in (RUNTIME / tag).glob("*") if p.is_file() and p.suffix in [".json", ".log"]]
    for tag in ["continuation", "legacy_heavy", "matrix"]:
        # Keep the earlier thermal-progression finding, separate from final totals.
        paths += [p for p in (RUNTIME / tag).glob("*") if p.is_file() and p.suffix in [".json", ".log"]]
    paths += list((RUNTIME / "source_before").rglob("*.gd"))
    paths += [RUNTIME / "production_before.json", RUNTIME / "status_before.txt"]
    paths += list((ROOT / "새-게임-프로젝트/redesign").glob("*.gd"))
    # Include inherited QA scripts: rerunning does not silently change its solver.
    paths += list((ROOT / "새-게임-프로젝트/tests").glob("*.gd"))
    paths += [ROOT / "tools/run_rhythm_checks.ps1", Path(__file__)]
    manifest = {p.relative_to(ROOT).as_posix(): sha(p) for p in paths}
    with zipfile.ZipFile(ASSETS / "evidence.zip", "w", zipfile.ZIP_DEFLATED) as archive:
        for p in paths:
            archive.write(p, p.relative_to(ROOT).as_posix())
    (ASSETS / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({k: v for k, v in summary.items() if k not in ["matrix", "timing", "changed_production"]}, ensure_ascii=False, indent=2))
    print("Evidence files:", len(paths), "bytes:", (ASSETS / "evidence.zip").stat().st_size)


if __name__ == "__main__":
    main()
