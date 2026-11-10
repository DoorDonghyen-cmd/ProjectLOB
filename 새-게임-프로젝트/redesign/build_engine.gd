extends RefCounted
## Build engine trial (2026-11-08, user-approved direction; parts and numbers are director
## values before human play). First build: 연타·결정타.
## - 연타 공명기 (resonator): rule change. Each hit of a 연타 round on the same target
##   multiplies that hit: hit 1 ×1, hit 2 ×2, hit 3 ×3. Cost: 연타 rounds heat +1.
## - 타격 기록기 (tally): grows during the climb. Every 3 kills by a 연타 round while it is
##   equipped add +1 damage per 연타 hit, up to +6. The record stays with the part when it
##   is unequipped and is lost when the part is dismantled.
## Only runs started with build_engine_version (model.s) use these parts; older saves
## never see them offered and keep their rules.
const VERSION := 1
const NEW_PARTS := ["resonator", "tally"]
const TALLY_STEP := 3
const TALLY_LIMIT := 6
const RESONATOR_HEAT := 1

static func enabled(state: Dictionary) -> bool:
	return int(state.get("build_engine_version", 0)) == VERSION

static func is_volley_round(id: String) -> bool:
	return str(preload("res://redesign/content.gd").AMMO.get(id, {}).get("effect", "")) == "double"

static func tally_kills(state: Dictionary) -> int:
	return int(state.get("part_growth", {}).get("tally", 0))

static func tally_bonus(state: Dictionary) -> int:
	return mini(TALLY_LIMIT, tally_kills(state) / TALLY_STEP)

## Called once per primary direct kill. Counts only while the tally is equipped.
static func record_kill(state: Dictionary, id: String, parts: Array) -> void:
	if not enabled(state) or not parts.has("tally") or not is_volley_round(id): return
	if not state.has("part_growth"): state.part_growth = {}
	state.part_growth.tally = mini(TALLY_STEP * TALLY_LIMIT, tally_kills(state) + 1)

static func forget(state: Dictionary, id: String) -> void:
	if state.has("part_growth"): state.part_growth.erase(id)

static func resonance(state: Dictionary, id: String, parts: Array) -> bool:
	return enabled(state) and parts.has("resonator") and is_volley_round(id)

static func heat_bonus(state: Dictionary, id: String) -> int:
	var parts: Array = preload("res://redesign/content.gd").equipped_parts(state)
	return RESONATOR_HEAT if resonance(state, id, parts) else 0

static func progress_text(state: Dictionary) -> String:
	var bonus := tally_bonus(state)
	if bonus >= TALLY_LIMIT: return "기록 완료 · 연타 타격당 +%d" % bonus
	return "기록 %d / %d처치 · 현재 +%d" % [tally_kills(state) % TALLY_STEP, TALLY_STEP, bonus]

static func valid(state: Dictionary) -> bool:
	var version = state.get("build_engine_version", 0)
	if not (version is int or version is float) or int(version) != version or int(version) < 0 or int(version) > VERSION: return false
	if not state.has("part_growth"): return true
	var growth = state.part_growth
	if not growth is Dictionary or int(version) == 0: return false
	for key in growth:
		if not key in NEW_PARTS: return false
		var value = growth[key]
		if not (value is int or value is float) or int(value) != value or int(value) < 0 or int(value) > TALLY_STEP * TALLY_LIMIT: return false
	return true
