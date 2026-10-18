extends RefCounted
## Run growth is earned once per won encounter; previews mutate only their copy.
const IDS := ["volley_drive", "thermal_drive", "siege_drive"]
const LIMIT := 8

static func fresh() -> Dictionary:
	return {"levels":{},"hits":0,"hot":false,"siege":false,"settled":false,"gains":[]}

static func begin(state: Dictionary) -> void:
	var levels: Dictionary = state.get("engine",{}).get("levels",{}).duplicate()
	state.engine = fresh()
	state.engine.levels = levels

static func level(state: Dictionary, id: String) -> int:
	return int(state.get("engine",{}).get("levels",{}).get(id,0))

static func flat(state: Dictionary, parts: Array) -> int:
	return 1 + level(state,"volley_drive") if parts.has("volley_drive") else 0

static func percent(state: Dictionary, parts: Array, hits: int, hot: bool) -> int:
	if parts.has("thermal_drive") and hot: return 150 + 25 * level(state,"thermal_drive")
	if parts.has("siege_drive") and hits == 1: return 200 + 25 * level(state,"siege_drive")
	return 100

static func observe(state: Dictionary, parts: Array, hits: int, hot: bool, single_damage: int) -> void:
	if not state.has("engine"): state.engine = fresh()
	if state.engine.settled: return
	if parts.has("volley_drive"): state.engine.hits = mini(3,int(state.engine.hits)+hits)
	if parts.has("thermal_drive") and hits > 0 and hot: state.engine.hot = true
	if parts.has("siege_drive") and single_damage >= 8: state.engine.siege = true

static func settle(state: Dictionary, parts: Array) -> void:
	if state.get("phase","") not in ["reward","won"]: return
	if not state.has("engine"): state.engine = fresh()
	if state.engine.settled: return
	state.engine.settled = true
	for id in IDS:
		var earned := int(state.engine.hits) >= 3 if id == "volley_drive" else bool(state.engine.hot if id == "thermal_drive" else state.engine.siege)
		if parts.has(id) and earned and level(state,id) < LIMIT:
			state.engine.levels[id] = level(state,id)+1
			state.engine.gains.append(id)

static func value(state: Dictionary, id: String) -> String:
	match id:
		"volley_drive": return "타격 +%d" % (1+level(state,id))
		"thermal_drive": return "고열 ×%.2f" % ((150+25*level(state,id))/100.0)
		"siege_drive": return "단타 ×%.2f" % ((200+25*level(state,id))/100.0)
	return ""

static func progress(state: Dictionary, id: String) -> String:
	if not IDS.has(id): return ""
	var e: Dictionary = state.get("engine",fresh())
	var condition := "%d/3회 피해 타격" % int(e.hits) if id == "volley_drive" else ("고열 피해 성공" if e.hot else "고열 피해 필요") if id == "thermal_drive" else ("단타 8피해 달성" if e.siege else "단타 8피해 필요")
	return "성장 %d/%d · %s · 승리 시 성장" % [level(state,id),LIMIT,condition] if level(state,id)<LIMIT else "성장 완료 · 이번 등반에 유지"

static func valid(e: Variant) -> bool:
	if not e is Dictionary or e.size()!=6: return false
	for key in ["levels","hits","hot","siege","settled","gains"]:
		if not e.has(key): return false
	if not e.levels is Dictionary or not e.gains is Array or e.gains.size()>1: return false
	for key in e.levels:
		if not IDS.has(key) or not whole(e.levels[key],LIMIT): return false
	for id in e.gains:
		if not IDS.has(id) or not e.levels.has(id) or int(e.levels[id])<1: return false
	return whole(e.hits,3) and e.hot is bool and e.siege is bool and e.settled is bool and (e.gains.is_empty() or e.settled)

static func whole(v: Variant, maximum: int) -> bool:
	return (v is int or v is float) and is_finite(v) and float(v)==floorf(v) and v>=0 and v<=maximum
