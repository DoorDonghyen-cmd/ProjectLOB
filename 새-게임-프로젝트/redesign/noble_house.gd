extends RefCounted
## Roster 10: countable shield hits, followed by a public exposure window.
## Shields never limit HP damage after opening. Old rosters retain old behavior.
const VERSION := 10
const NOBLE := "shield_noble"
const DOOR := "double_door_servant"
const LABOR := "house_effigy"
const PRESSURE := "house_pressure"
const ELITE := "chief_servant"
const BOSS := "cupronickel_marquis"
const NAMES := {NOBLE:"차폐 귀족",DOOR:"겹문 시종",LABOR:"가문 시종",PRESSURE:"사설 경호기",ELITE:"수석 시종",BOSS:"백동 후작"}
const SHIELDS := {NOBLE:2,DOOR:2,ELITE:3,BOSS:4}
const PIERCE_WEAK := "weak"
const PIERCE_ONLY := "strict"
const SHIELD_OPEN_DELAY := 2

static func active(enemy: Dictionary) -> bool:
	return int(enemy.get("noble_version",0))==1 and NAMES.has(str(enemy.get("species","")))

static func shielded(enemy: Dictionary) -> bool:
	return active(enemy) and SHIELDS.has(str(enemy.species))

static func leader(enemy: Dictionary) -> bool:
	return active(enemy) and str(enemy.species) in [ELITE,BOSS]

static func shield_rule(enemy: Dictionary) -> String:
	return PIERCE_ONLY if enemy.has("shield_open_left") else str(enemy.get("shield_trial", ""))

static func exposure(enemy: Dictionary) -> int:
	if not shield_rule(enemy).is_empty(): return 3
	return 5 if leader(enemy) else 3

static func surge(enemy: Dictionary) -> int:
	return 3 if str(enemy.species)==BOSS else 2 if str(enemy.species)==ELITE else 0

static func unit(id: String, hp: int, distance: int) -> Array:
	var kind := "absorber" if SHIELDS.has(id) else "spitter" if id==PRESSURE else "runner"
	var data := {"species":id,"name":NAMES[id],"noble_version":1}
	if SHIELDS.has(id): data.merge({"barrier":SHIELDS[id],"barrier_max":SHIELDS[id],"exposure_left":0})
	if id in [ELITE,BOSS]: data.rank="elite" if id==ELITE else "boss"
	return [kind,hp,0,0 if id==PRESSURE else 1,distance,data]

static func rows(node: Dictionary, random: RandomNumberGenerator, fallback: Array) -> Array:
	if int(node.region)!=3: return fallback
	if str(node.kind)=="boss":
		return [unit(BOSS,64,46),unit(LABOR,6,34),unit(DOOR,10,40),unit(PRESSURE,10,50),
			unit(LABOR,7,38),unit(NOBLE,11,44),unit(LABOR,7,42)]
	if bool(node.get("elite",false)):
		var elite := unit(ELITE,36,42)
		elite[5].shield_open_left = SHIELD_OPEN_DELAY
		return [elite,unit(LABOR,6,34),unit(NOBLE,10,40),unit(PRESSURE,9,48),unit(LABOR,7,40),unit(DOOR,10,44)]
	var stage := mini(2,maxi(0,(int(node.floor)-1)/3))
	var variant := random.randi_range(0,2)
	var front := NOBLE if variant==0 else DOOR
	var result := [unit(LABOR,5+stage,32),unit(front,10+stage,37),unit(PRESSURE,9+stage,48),unit(LABOR,6+stage,42)]
	if variant==2: result[0]=unit(DOOR,10,32);result[1]=unit(LABOR,6+stage,37)
	result.append(unit(DOOR if front==NOBLE else NOBLE,10+stage,40))
	result.append(unit(LABOR,6+stage,44))
	# The pressure system permits one source per encounter, including reserves.
	if stage==2: result.append(unit(LABOR,9,46))
	return result

static func strip(enemy: Dictionary, amount: int, source: String = "") -> int:
	match shield_rule(enemy):
		PIERCE_WEAK: amount = 2 if source == "pierce" else 1
		PIERCE_ONLY: amount = 2 if source == "pierce" else 0
	var removed := mini(int(enemy.get("barrier",0)),amount)
	enemy.barrier=int(enemy.get("barrier",0))-removed
	if removed>0 and int(enemy.barrier)==0 and shielded(enemy): _open(enemy)
	return removed

static func _open(enemy: Dictionary) -> void:
	enemy.barrier = 0
	enemy.exposure_left = exposure(enemy)
	if enemy.has("shield_open_left"): enemy.shield_open_left = 0

static func movement(enemy: Dictionary) -> Dictionary:
	var action := "guard"
	var step := int(enemy.speed)
	if int(enemy.barrier)==0:
		if int(enemy.get("jammed",0))>0: action="jammed"
		else:
			enemy.exposure_left-=1
			action="exposed"
			if int(enemy.exposure_left)==0:
				step+=surge(enemy)
				enemy.barrier=int(enemy.barrier_max)
				if enemy.has("shield_open_left"): enemy.shield_open_left = SHIELD_OPEN_DELAY
				action="rearm"
	elif enemy.has("shield_open_left") and int(enemy.get("jammed", 0)) == 0:
		enemy.shield_open_left = int(enemy.shield_open_left) - 1
		if int(enemy.shield_open_left) == 0:
			_open(enemy)
			action = "timed_open"
	var result := {"action":action,"step":step,"barrier":int(enemy.barrier),"exposure_left":int(enemy.exposure_left)}
	if enemy.has("shield_open_left"): result.shield_open_left = int(enemy.shield_open_left)
	return result

static func intent(enemy: Dictionary, show_distance: bool = true) -> String:
	if not shielded(enemy): return ""
	if int(enemy.barrier)>0:
		match shield_rule(enemy):
			PIERCE_WEAK: return "차폐 %d · 철갑 약점" % int(enemy.barrier)
			PIERCE_ONLY: return "철갑 전용 · %d행동 뒤 노출" % int(enemy.shield_open_left)
		return "차폐 %d회" % int(enemy.barrier)
	var left := int(enemy.exposure_left)
	if int(enemy.get("jammed",0))>0: return "노출 · 복구 정지 %d턴" % int(enemy.jammed)
	if left==1 and surge(enemy)>0: return "재차폐 1턴 · %dm 돌진" % (int(enemy.speed)+surge(enemy)) if show_distance else "재차폐 1턴 · 돌진"
	return "노출 · 재차폐 %d턴" % left

static func detail(enemy: Dictionary) -> String:
	if not active(enemy): return ""
	if not shielded(enemy):
		return "차폐 없는 가문 시종. 낮은 체력의 전열을 처치해 연쇄 화력의 출발점으로 삼을 수 있습니다." if str(enemy.species)==LABOR else "시종 뒤에서 압력탄을 발사합니다. 전열을 돌파하거나 날아오는 탄을 요격하세요."
	var rule_id := shield_rule(enemy)
	if not rule_id.is_empty():
		var rule := "철갑탄은 차폐 2칸, 그 외 타격은 1칸을 깎습니다. 차폐가 깨질 때까지 타격을 막습니다."
		if rule_id == PIERCE_ONLY:
			rule = "철갑탄만 차폐를 2칸씩 깎습니다. 차폐가 닫힌 채로 적이 %d행동하면 본체가 열립니다." % SHIELD_OPEN_DELAY
		return "%s\n본체는 적 행동 %d회 동안 노출됩니다. 차폐를 복구할 때 추가로 전진합니다.\n%s" % [rule, exposure(enemy), intent(enemy, false)]
	var text := "차폐는 일반 타격당 1회, 전기 주 타격당 2회 소모됩니다. 파쇄 파츠는 타격당 1회를 더 제거합니다. 마지막 차폐를 깨는 타격까지 직접 피해를 막습니다.\n차폐가 깨지면 %d 적 행동 동안 노출됩니다. 연타의 남은 타격은 즉시 HP에 들어갑니다. 소이탄의 화상은 차폐를 무시합니다." % exposure(enemy)
	text+="\n%s" % intent(enemy)
	if surge(enemy)>0: text+=" · 복구할 때 본체만 추가 %dm 전진합니다." % surge(enemy)
	return text

static func valid(enemy: Dictionary) -> bool:
	var numbers=preload("res://redesign/foundry_workers.gd")
	var timed := enemy.has("shield_open_left")
	if enemy.has("shield_trial") and enemy.shield_trial != (PIERCE_ONLY if timed else PIERCE_WEAK): return false
	if timed or enemy.has("shield_trial"):
		if not active(enemy) or str(enemy.species) != ELITE: return false
	if timed:
		var closed := int(enemy.get("barrier", 0)) > 0
		if not numbers.number(enemy.shield_open_left, 1 if closed else 0, SHIELD_OPEN_DELAY if closed else 0): return false
	if not enemy.has("noble_version"): return not NAMES.has(str(enemy.get("species","")))
	if not numbers.number(enemy.noble_version,1,1) or not active(enemy): return false
	if enemy.has("garden_version") or enemy.has("foundry_version") or enemy.get("stance",false) or int(enemy.get("charge_max",0))>0: return false
	var id:=str(enemy.species)
	if shielded(enemy):
		if str(enemy.kind)!="absorber" or int(enemy.speed)!=1 or int(enemy.def)!=0: return false
		if not numbers.number(enemy.get("barrier_max",-1),SHIELDS[id],SHIELDS[id]): return false
		if not numbers.number(enemy.get("barrier",-1),0,SHIELDS[id]): return false
		if not numbers.number(enemy.get("exposure_left",-1),0,exposure(enemy)): return false
		if (int(enemy.get("barrier",0))>0)!=(int(enemy.exposure_left)==0): return false
		if leader(enemy) and str(enemy.get("rank",""))!=("boss" if id==BOSS else "elite"): return false
	else:
		if int(enemy.get("barrier_max",0))!=0 or enemy.has("exposure_left"): return false
		if str(enemy.kind)!=("spitter" if id==PRESSURE else "runner"): return false
		if int(enemy.speed)!=(0 if id==PRESSURE else 1): return false
	return true
