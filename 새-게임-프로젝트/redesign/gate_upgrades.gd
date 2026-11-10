extends RefCounted
## Run-long gate modifications; no part slot or core-growth replacement.
const Ammo = preload("res://redesign/content.gd")
const VERSION := 1
const Roles=preload("res://redesign/combat_roles.gd")
const MAX_LEVEL := 2
const Growth = preload("res://redesign/core_growth.gd")
const NAMES := {"thermal":"축열 변환기", "chain":"연쇄 격발기", "production":"전용 탄약 생산권", "growth":"코어 성장 확장", "cadence":"급탄 기구 확장", "efficiency":"저발열 약실", "conduction":"전이 회로 확장"}

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
		if id=="conduction" and Roles.builds(state) and not Ammo.equipped_parts(state).any(func(part):return part in ["volley_drive","siege_drive"]):continue
		if level(state,id)<MAX_LEVEL: result.append(id)
	if basics(state.deck).size()>=3 and not specimens(state.deck).is_empty(): result.append("production")
	if late_growth and Growth.enabled(state) and level(state,"growth")<Growth.MAX_UPGRADES and (not Roles.builds(state) or Ammo.equipped_parts(state).any(func(part):return part in ["volley_drive","siege_drive","thermal_drive"])): result.append("growth")
	return result

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
		"cadence": return "사격 상한 +%d발"%level(copy,id)
		"efficiency": return "탄환 기본 발열 −%d"%level(copy,id)
		"conduction": return "처치 전이 최대 추가 %d기"%(1+level(copy,id))
		"growth": return "성장 상한 %d → %d" % [Growth.limit(state),Growth.limit(copy)] if next else "성장 상한 %d단계" % Growth.limit(state)
		"thermal": return "첫 타격 +%d까지" % charge_limit(copy)
		"chain": return "처치 연쇄 ×%.2f까지" % (chain_limit(copy)/100.0)
	return "기본탄 3장 → 특수탄 3장"

static func description(id: String) -> String:
	match id:
		"cadence": return "한 번에 선택할 수 있는 탄을 1발 늘립니다. 과열 중단·리액터 강행·스파이크 처치 연쇄 조건은 유지됩니다."
		"efficiency": return "모든 탄의 양수 기본 발열을 1 낮춥니다(최소 1). 연속 사격 추가 열·증폭 부하·파츠의 추가 열은 유지합니다."
		"conduction": return "연쇄·돌파 코어의 처치 후 전이 대상을 1기 늘립니다. 주 표적은 세지 않으며 직접 피해량은 바꾸지 않습니다."
		"growth": return "성장 코어의 상한을 2단계 높입니다. 이후 전투에서 기존 성장 조건을 달성하고 승리하면 추가로 성장합니다."
		"thermal": return "일반 재장전으로 식힌 열을 다음 공격탄의 첫 타격 피해로 전환합니다."
		"chain": return "탄창에서 직접 처치를 낸 탄마다 이후 공격의 피해 배율이 0.25 증가합니다."
	return "보유한 일반 특수탄을 견본으로 골라 기본탄 3장을 동일한 탄으로 교체합니다."

static func caution(id: String) -> String:
	match id:
		"cadence": return "탄창 크기·열 한계는 유지 · 최대 2회 투자"
		"efficiency": return "탄약 지급·열 한계 변경 없음 · 최대 2회 투자"
		"conduction": return "연쇄·돌파 코어에 적용 · 광역탄/열압 충격파 제외"
		"growth": return "즉시 피해 증가 없음 · 다른 관문 개조 대신 선택 · 코어를 바꿔도 상한 유지"
		"thermal": return "강제 냉각 제외 · 중첩 없음 · 장갑·보호막 적용"
		"chain": return "재장전 시 초기화 · 한 탄당 한 단계 · 속성 처치 제외"
	return "탄약 총량 유지 · 바꿀 기본탄은 직접 선택"

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
