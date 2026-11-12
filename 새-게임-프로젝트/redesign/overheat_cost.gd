extends RefCounted
## Overheat cost (2026-11-11, user: "아무탄이나 막 발사해도 클리어 되는 문제", "진행해 줘").
## Naive play measured equal to the solver in region 1 and safe elsewhere: forced cooling cost
## only reload + 1 enemy actions against a voluntary cool of 1, so overheating was never a loss.
## New runs (model.s.overheat_version) add EXTRA enemy actions to every forced cooling, so
## "fire everything every turn" pays and choosing how many rounds / when to cool matters.
## Report: docs/qa/reports/naive_play_2026-11-11/README.md.
const VERSION := 1
const EXTRA := 2
## 리액터 runs hot by design (thermal drive, 강행): +2 made a region-5 elite unwinnable even for
## the solver (seed 23), +1 keeps every solver climb winning and still sinks naive play early.
const EXTRA_BY_GUN := {"heavy": 1}
## QA only: try other sizes on the same rule (tests/growth_v2_climb.gd QA_OVERHEAT_EXTRA).
static var extra_override := -1

static func enabled(state: Dictionary) -> bool:
	return int(state.get("overheat_version", 0)) == VERSION

static func extra(state: Dictionary) -> int:
	if not enabled(state): return 0
	return extra_override if extra_override >= 0 else int(EXTRA_BY_GUN.get(str(state.get("gun", "")), EXTRA))

static func valid(state: Dictionary) -> bool:
	var version = state.get("overheat_version", 0)
	return (version is int or version is float) and int(version) == version and int(version) >= 0 and int(version) <= VERSION
