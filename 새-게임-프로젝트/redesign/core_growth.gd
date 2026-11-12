extends RefCounted
## An optional late gate investment; existing growth speed and early ceiling stay intact.
const VERSION := 1
const BASE_LIMIT := 8
const STEP := 2
const MAX_UPGRADES := 3

static func enabled(state: Dictionary) -> bool:
	return int(state.get("growth_version",0)) == VERSION

## Growth structure v2: drives grow only by the gate choice '구동 강화' (+4 each, up to 12).
const V2_LIMIT := 12
const V2_STEP := 4

static func limit(state: Dictionary) -> int:
	if int(state.get("growth_structure_version", 0)) == 1: return V2_LIMIT
	return BASE_LIMIT + STEP * clampi(int(state.get("gate_mods",{}).get("growth",0)),0,MAX_UPGRADES) if enabled(state) else BASE_LIMIT
