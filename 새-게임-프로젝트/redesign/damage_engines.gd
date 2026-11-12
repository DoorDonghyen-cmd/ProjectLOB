extends RefCounted
## Run growth is earned once per won encounter; previews mutate only their copy.
const IDS := ["volley_drive", "thermal_drive", "siege_drive"]
const Growth = preload("res://redesign/core_growth.gd")
const LIMIT := Growth.BASE_LIMIT
const Content = preload("res://redesign/content.gd")

static func fresh() -> Dictionary:
	return {"levels":{},"hits":0,"hot":false,"siege":false,"settled":false,"gains":[]}

static func begin(state: Dictionary) -> void:
	var levels: Dictionary = state.get("engine",{}).get("levels",{}).duplicate()
	state.engine = fresh()
	state.engine.levels = levels

static func level(state: Dictionary, id: String) -> int:
	return int(state.get("engine",{}).get("levels",{}).get(id,0))

static func flat(state: Dictionary, parts: Array) -> int:
	var growth := level(state,"volley_drive")
	return 1 + (growth / 2 if Content.revised_combat(state) else growth) if parts.has("volley_drive") else 0

static func percent(state: Dictionary, parts: Array, hits: int, hot: bool) -> int:
	var step := 15 if Content.revised_combat(state) else 25
	if parts.has("thermal_drive") and hot: return 150 + step * level(state,"thermal_drive")
	if parts.has("siege_drive") and hits == 1: return 200 + step * level(state,"siege_drive")
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
	# v2 (2026-11-10): winning while meeting the drive's condition still grows it, but only up to
	# 8. Levels 9-12 come only from choices: the gate's 구동 강화 (+4) and the shop's 구동 정비 (+2).
	# Removing this growth entirely failed the 리벳 climb and slowed 리액터 from 463 to 669 turns.
	var earned_cap := Growth.BASE_LIMIT if int(state.get("growth_structure_version", 0)) == 1 else Growth.limit(state)
	for id in IDS:
		var earned := int(state.engine.hits) >= 3 if id == "volley_drive" else bool(state.engine.hot if id == "thermal_drive" else state.engine.siege)
		if parts.has(id) and earned and level(state,id) < earned_cap:
			state.engine.levels[id] = level(state,id)+1
			state.engine.gains.append(id)

static func value(state: Dictionary, id: String) -> String:
	match id:
		"volley_drive": return "타격 +%d" % flat(state,[id])
		"thermal_drive": return "고열 ×%.2f" % (percent(state,[id],1,true)/100.0)
		"siege_drive": return "단타 ×%.2f" % (percent(state,[id],1,false)/100.0)
	return ""

static func progress(state: Dictionary, id: String) -> String:
	if not IDS.has(id): return ""
	var e: Dictionary = state.get("engine",fresh())
	var condition := "%d/3회 피해 타격" % int(e.hits) if id == "volley_drive" else ("고열 피해 성공" if e.hot else "고열 피해 필요") if id == "thermal_drive" else ("단타 8피해 달성" if e.siege else "단타 8피해 필요")
	var cap := Growth.limit(state)
	if level(state,id)<cap: return "성장 %d/%d · %s · 승리 시 성장" % [level(state,id),cap,condition]
	return "성장 %d/%d · 추가 성장은 관문 확장 필요" % [level(state,id),cap] if Growth.enabled(state) and cap < LIMIT+Growth.STEP*Growth.MAX_UPGRADES else "성장 완료 · 이번 등반에 유지"

static func gain_summary(state: Dictionary, id: String) -> String:
	if not state.get("engine",{}).get("gains",[]).has(id): return ""
	var previous := state.duplicate(false)
	previous.engine = state.engine.duplicate(false)
	previous.engine.levels = state.engine.levels.duplicate()
	previous.engine.levels[id] = maxi(0,level(state,id)-1)
	var before := value(previous,id)
	var after := value(state,id)
	if before == after:
		previous.engine.levels[id] = mini(Growth.limit(state),level(state,id)+1)
		return "성장 축적 1/2 · 다음 성장 시 " + value(previous,id)
	return before + " → " + after

static func growth_rule(state: Dictionary, id: String) -> String:
	var sample := {"combat_revision":state.get("combat_revision",0),"engine":{"levels":{id:0}}}
	if id=="volley_drive":
		var initial := flat(sample,[id])
		sample.engine.levels[id]=1
		return "3회 피해 타격 후 승리 · " + ("2회 성장마다 타격 +1" if flat(sample,[id])==initial else "타격 +1")
	var initial := percent(sample,[id],1,true)
	sample.engine.levels[id]=1
	var step := percent(sample,[id],1,true)-initial
	var rule: String=("고열 피해 후 승리" if id=="thermal_drive" else "한 발로 8피해 후 승리") + " → 배율 +%.2f" % (step/100.0)
	if id=="thermal_drive" and int(state.get("combat_roles_version",0))>=2:rule+=" · 성장 %d회마다 화상 +1"%Content.Roles.burn_growth_step(state)
	return rule

static func valid(e: Variant, maximum: int = LIMIT) -> bool:
	if not e is Dictionary or e.size()!=6: return false
	for key in ["levels","hits","hot","siege","settled","gains"]:
		if not e.has(key): return false
	if not e.levels is Dictionary or not e.gains is Array or e.gains.size()>1: return false
	for key in e.levels:
		if not IDS.has(key) or not whole(e.levels[key],maximum): return false
	for id in e.gains:
		if not IDS.has(id) or not e.levels.has(id) or int(e.levels[id])<1: return false
	return whole(e.hits,3) and e.hot is bool and e.siege is bool and e.settled is bool and (e.gains.is_empty() or e.settled)

static func whole(v: Variant, maximum: int) -> bool:
	return (v is int or v is float) and is_finite(v) and float(v)==floorf(v) and v>=0 and v<=maximum
