extends RefCounted
## An optional late gate investment; existing growth speed and early ceiling stay intact.
const VERSION := 1
const BASE_LIMIT := 8
const STEP := 2
const MAX_UPGRADES := 3

static func enabled(state: Dictionary) -> bool:
	return int(state.get("growth_version",0)) == VERSION

static func limit(state: Dictionary) -> int:
	return BASE_LIMIT + STEP * clampi(int(state.get("gate_mods",{}).get("growth",0)),0,MAX_UPGRADES) if enabled(state) else BASE_LIMIT
