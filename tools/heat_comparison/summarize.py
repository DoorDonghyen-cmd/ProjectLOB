"""Validate paired controls and emit reviewable tables from the isolated runs."""
from pathlib import Path
from collections import defaultdict
import csv
import hashlib
import json
import statistics
import sys

root = Path(__file__).resolve().parents[2]
runtime = root / 'qa_runtime/heat_comparison' / sys.argv[1]
before = json.loads((runtime/'original/results.json').read_text(encoding='utf-8'))
after = json.loads((runtime/'experiment/results.json').read_text(encoding='utf-8'))
assert before['failures'] == after['failures'] == 0
baseline = [row for row in after['rows'] if row['mode'] == 'baseline']
assert before['rows'] == baseline, 'Experiment hooks changed the baseline'
assert before['tactics'] == [row for row in after['tactics'] if row['mode'] == 'baseline']
manifest = json.loads((runtime/'source_manifest.json').read_text(encoding='utf-8'))
project = Path(manifest['source_project'])
for name, digest in manifest['source_sha256'].items():
    assert hashlib.sha256((project/name).read_bytes()).hexdigest() == digest, name


def identity(row):
    return tuple(row.get(key) for key in ['gun', 'build', 'scenario', 'warm', 'seed'])


def aggregate(rows):
    base = {identity(row): row for row in rows if row['mode'] == 'baseline'}
    groups = defaultdict(list)
    for row in rows:
        groups[row['mode']].append(row)
    result = []
    for mode, group in groups.items():
        assert len(group) == len(base)
        result.append(dict(
            mode=mode, cases=len(group),
            mean_damage=statistics.mean(row['damage'] for row in group),
            mean_turns=statistics.mean(row['turns'] for row in group),
            mean_cycle_turns=statistics.mean(row['cycle_turns'] for row in group),
            mean_cycle_damage=statistics.mean(row['cycle_damage'] for row in group),
            mean_spent=statistics.mean(row['spent'] for row in group),
            overheat_reload_percent=100*statistics.mean(row['overheat_events']>0 for row in group),
            misfire_percent=100*statistics.mean(row['failures']>0 for row in group),
            losses=sum(row['phase']=='lost' for row in group),
            cycle_losses=sum(row['cycle_phase']=='lost' for row in group),
            lower_damage_cases=sum(row['damage']<base[identity(row)]['damage'] for row in group),
            higher_turn_cases=sum(row['turns']>base[identity(row)]['turns'] for row in group),
            higher_cycle_turn_cases=sum(row['cycle_turns']>base[identity(row)]['cycle_turns'] for row in group),
        ))
    return result


def csv_file(name, rows):
    with (runtime/name).open('w', encoding='utf-8-sig', newline='') as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


table = aggregate(after['rows'])
sensitivity = aggregate(after['fault_sensitivity'])
subgroups = []
for gun in dict.fromkeys(row['gun'] for row in after['rows']):
    for build in dict.fromkeys(row['build'] for row in after['rows']):
        subgroups.extend(dict(gun=gun, build=build, **item) for item in aggregate([row for row in after['rows'] if row['gun']==gun and row['build']==build]))
csv_file('mode_summary.csv', table)
csv_file('gun_build_summary.csv', subgroups)
csv_file('fault_sensitivity.csv', sensitivity)
summary = dict(
    main_cases=len(after['rows']), control_cases=len(before['rows']),
    sensitivity_cases=len(after['fault_sensitivity']), tactics_cases=len(after['tactics']),
    checks=before['checks']+after['checks'], failures=0,
    identical_baseline=True, production_source_unchanged=True,
    modes=table, sensitivity=sensitivity,
    limitations=[
        'One magazine, not an entire fight/campaign or player win rate.',
        'Fixed synthetic decks/owned builds; acquisition costs not simulated.',
        'The 16 shared seeds are paired conditions, not independent trials for every row.',
        'Fault sensitivity uses 256 paired seeds, cold final boss, three weapons/two builds.',
        'Faults are added to current heat. Full heat replacement was not implemented.',
        'No public fault forecast, UI, product save migration, mobile performance or human-fun validation.',
    ],
)
(runtime/'comparison_summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
(runtime/'tactics.json').write_text(json.dumps(after['tactics'],ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(summary,ensure_ascii=False,indent=2))
