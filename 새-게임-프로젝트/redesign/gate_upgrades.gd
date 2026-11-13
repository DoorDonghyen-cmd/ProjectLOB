extends RefCounted
## Run-long gate modifications; no part slot or core-growth replacement.
const Ammo = preload("res://redesign/content.gd")
const VERSION := 1
const Roles=preload("res://redesign/combat_roles.gd")
const MAX_LEVEL := 2
const Growth = preload("res://redesign/core_growth.gd")
const GrowthV2 = preload("res://redesign/growth_structure.gd")
const NAMES := {"thermal":"축열 변환기", "chain":"연쇄 격발기", "production":"전용 탄약 생산권", "growth":"코어 성장 확장", "cadence":"급탄 기구 확장", "efficiency":"저발열 약실", "conduction":"전이 회로 확장", "mastery":"탄종 숙련", "mastery_support":"보조 숙련", "drive":"구동 강화"}

static func level(state: Dictionary, id: String) -> int:
	return int(state.get("gate_mods", {}).get(id, 0))

static func charge_limit(state: Dictionary) -> int:
	return [0, 6, 10][clampi(level(state,"thermal"),0,MAX_LEVEL)]

static func chain_limit(state: Dictionary) -> int:
	return [100, 175, 200][clampi(level(state,"chain"),0,MAX_LEVEL)]

static func chain_percent(state: Dictionary) -> int:
	return mini(chain_limit(state),100+25*int(state.get("gate_chain",0)))

static func begin(state: Dictionary) -> void:
	if not state.has("gate_mods"): return
	state.gate_charge = 0
	state.gate_chain = 0

static func after_reload(state: Dictionary, before: int, after: int, forced: bool) -> void:
	if not state.has("gate_mods"): return
	state.gate_chain = 0
	state.gate_charge = 0 if forced or state.phase not in ["plan","ready"] else mini(charge_limit(state), maxi(0,before-after))

static func specimens(deck: Array) -> Array:
	var result: Array = []
	for value in deck:
		var id := str(value)
		if Ammo.grade(id)==0 and Ammo.source_id(id)!="basic" and not Ammo.is_temporary(id) and not result.has(id): result.append(id)
	return result

static func basics(deck: Array) -> Array:
	return deck.filter(func(id): return Ammo.source_id(str(id))=="basic" and Ammo.grade(str(id))<=0 and not Ammo.is_temporary(str(id)))

static func options(state: Dictionary, late_growth: bool = false) -> Array:
	var result: Array = []
	for id in (["cadence","efficiency","conduction","chain"] if Roles.enabled(state) else ["thermal","chain"]):
		if id=="cadence" and state.get("gun","")=="amplifier":continue
		if id=="conduction" and Roles.builds(state) and not Ammo.active_parts(state).any(func(part):return part in ["volley_drive","siege_drive"]):continue
		if level(state,id)<MAX_LEVEL: result.append(id)
	if can_grow_drive(state): result.append("drive")
	if GrowthV2.can_master(state): result.append("mastery")
	if GrowthV2.can_master_support(state): result.append("mastery_support")
	if basics(state.deck).size()>=3 and not specimens(state.deck).is_empty(): result.append("production")
	if late_growth and not GrowthV2.enabled(state) and Growth.enabled(state) and level(state,"growth")<Growth.MAX_UPGRADES and (not Roles.builds(state) or Ammo.active_parts(state).any(func(part):return part in ["volley_drive","siege_drive","thermal_drive"])): result.append("growth")
	return result

## v2 drive growth (gate choice).
static func can_grow_drive(state: Dictionary) -> bool:
	var drive := Ammo.innate_engine(state)
	return GrowthV2.enabled(state) and not drive.is_empty() and int(state.get("engine", {}).get("levels", {}).get(drive, 0)) < Growth.V2_LIMIT

static func grow_drive(state: Dictionary) -> bool:
	if not can_grow_drive(state): return false
	var drive := Ammo.innate_engine(state)
	if not state.has("engine"): return false
	state.engine.levels[drive] = mini(Growth.V2_LIMIT, int(state.engine.levels.get(drive, 0)) + Growth.V2_STEP)
	return true

static func drive_name(state: Dictionary) -> String:
	return {"siege_drive": "돌파 구동", "volley_drive": "연쇄 구동", "thermal_drive": "열압 구동"}.get(Ammo.innate_engine(state), "내장 구동")

static func can_produce(state: Dictionary, specimen: String, sources: Array) -> bool:
	if sources.size()!=3 or not specimens(state.deck).has(specimen): return false
	var remaining := basics(state.deck)
	for id in sources:
		if not id is String or not remaining.has(id): return false
		remaining.erase(id)
	return true

static func summary(id: String, state: Dictionary, next: bool = false) -> String:
	var copy := state.duplicate(false)
	copy.gate_mods = state.get("gate_mods",{}).duplicate()
	if next and id!="production": copy.gate_mods[id] = mini(Growth.MAX_UPGRADES if id=="growth" else MAX_LEVEL,level(state,id)+1)
	match id:
		"drive":
			var drive_level := int(state.get("engine", {}).get("levels", {}).get(Ammo.innate_engine(state), 0))
			return "%s Lv%d → Lv%d" % [drive_name(state), drive_level, mini(Growth.V2_LIMIT, drive_level + Growth.V2_STEP)] if next else "%s Lv%d" % [drive_name(state), drive_level]
		"mastery_support":
			var level := GrowthV2.mastery(state, GrowthV2.support_family(state))
			return "%s 숙련 Lv%d → Lv%d" % [GrowthV2.support_name(state), level, level + 1] if next else "%s 숙련 Lv%d" % [GrowthV2.support_name(state), level]
		"mastery":
			var now := GrowthV2.mastery(state, GrowthV2.mastery_family(state))
			return "%s 숙련 Lv%d → Lv%d" % [GrowthV2.family_name(state), now, now + 1] if next else "%s 숙련 Lv%d" % [GrowthV2.family_name(state), now]
		"cadence": return "한 번에 쏠 발수 +%d"%level(copy,id)
		"efficiency": return "탄 기본 열 −%d"%level(copy,id)
		"conduction": return "처치 뒤 피해를 넘기는 대상 %d기"%(1+level(copy,id))
		"growth": return "성장 상한 %d → %d" % [Growth.limit(state),Growth.limit(copy)] if next else "성장 상한 %d단계" % Growth.limit(state)
		"thermal": return "첫 타격 +%d까지" % charge_limit(copy)
		"chain": return "처치 연쇄 ×%.2f까지" % (chain_limit(copy)/100.0)
	return "기본탄 3장 → 특수탄 3장"

static func description(id: String) -> String:
	match id:
		"drive": return "내장 구동을 4단계 키웁니다. 승리로는 8단계까지만 자라고, 그 위는 관문과 상점에서만 오릅니다."
		"mastery_support": return "가장 많이 가진 지원탄 계열의 효과가 단계마다 커집니다. 증폭 +1, 잔열 증폭 +2, 파쇄 장갑 −1, 냉각 열 −1, 불씨 화상 이동 +1."
		"mastery": return "주력 계열 공격탄의 타격당 피해 +1(한 번만 맞히는 탄은 +2). 나중에 얻는 같은 계열 탄에도 적용됩니다."
		"cadence": return "한 번에 쏠 수 있는 발수가 1발 늘어납니다."
		"efficiency": return "모든 탄의 기본 열 −1(최소 1). 이어 쏠 때 붙는 추가 열은 그대로입니다."
		"conduction": return "연쇄·돌파 구동이 처치 뒤 피해를 넘기는 대상이 1기 늘어납니다."
		"growth": return "성장 코어의 상한을 2단계 높입니다. 이후 전투에서 기존 성장 조건을 달성하고 승리하면 추가로 성장합니다."
		"thermal": return "일반 재장전으로 식힌 열을 다음 공격탄의 첫 타격 피해로 전환합니다."
		"chain": return "한 탄창 안에서 탄으로 적을 처치할 때마다 이후 공격의 피해 배율 +0.25."
	return "보유한 일반 특수탄을 견본으로 골라 기본탄 3장을 동일한 탄으로 교체합니다."

static func caution(id: String) -> String:
	match id:
		"drive": return "최대 12단계"
		"mastery_support": return "지원탄 계열 하나에만 적용 · 최대 4단계"
		"mastery": return "주력 계열에만 적용 · 최대 4단계"
		"cadence": return "최대 2회"
		"efficiency": return "최대 2회"
		"conduction": return "연쇄·돌파 구동에만 적용"
		"growth": return "즉시 피해 증가 없음 · 다른 관문 개조 대신 선택 · 코어를 바꿔도 상한 유지"
		"thermal": return "강제 냉각 제외 · 중첩 없음 · 장갑·보호막 적용"
		"chain": return "탄창을 교체하면 처음부터 · 화상·전이 처치는 세지 않음"
	return "탄약 수는 그대로 · 바꿀 기본탄은 직접 고릅니다"

static func active_summary(state: Dictionary) -> String:
	var lines: PackedStringArray = []
	for id in ["thermal","chain","growth","cadence","efficiency","conduction"]:
		if level(state,id)>0: lines.append(NAMES[id]+" · "+summary(id,state))
	return " / ".join(lines)

static func valid(state: Dictionary) -> bool:
	var mods = state.get("gate_mods",{})
	if not mods is Dictionary: return false
	for id in mods:
		if id == "growth":
			if not Growth.enabled(state) or not whole(mods[id],1,Growth.MAX_UPGRADES): return false
		elif id in ["cadence","efficiency","conduction"]:
			if not Roles.enabled(state) or not whole(mods[id],1,MAX_LEVEL):return false
		elif id not in ["thermal","chain"] or not whole(mods[id],1,MAX_LEVEL): return false
	if not whole(state.get("gate_charge",0),0,charge_limit(state)): return false
	if not whole(state.get("gate_chain",0),0,4 if level(state,"chain")>0 else 0): return false
	if state.get("phase","") in ["reward","won","lost"] and (int(state.get("gate_charge",0))>0 or int(state.get("gate_chain",0))>0): return false
	return true

static func whole(v: Variant, low: int, high: int) -> bool:
	return (v is int or v is float) and is_finite(v) and v==floorf(v) and v>=low and v<=high
