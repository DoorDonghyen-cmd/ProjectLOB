extends RefCounted
## Roster 8: durable labor machines. Winding advances the source, never escorts.
const VERSION := 8
const ELITE := "mold_warden"
const BOSS := "foundry_overseer"
const SPECIES := ["labor_effigy","mold_worker","pressure_worker","ash_catcher",ELITE,BOSS]

static func active(enemy: Dictionary) -> bool:
	return int(enemy.get("foundry_version",0)) in [1,2,3] and str(enemy.get("species","")) in SPECIES

static func revise(rows: Array) -> Array:
	var result := rows.duplicate(true)
	for row in result:
		if row.size()<6 or not row[5].has("foundry_version"): continue
		row[5].foundry_version=2
		var id := str(row[5].species)
		if id=="mold_worker": row[2]=3
		if id in [ELITE,BOSS]:
			row[1]=28 if id==ELITE else 48
			row[2]=3
			row[5].windup_max=2
	return result

static func winding(enemy: Dictionary) -> bool:
	return active(enemy) and str(enemy.species) in [ELITE,BOSS]

static func worker(id: String, hp: int, distance: int) -> Array:
	var kind := "spitter" if id=="pressure_worker" else "wall" if id=="mold_worker" else "runner"
	var armor := 1 if id=="mold_worker" else 0
	var speed := 0 if id=="pressure_worker" else 2 if id=="ash_catcher" else 1
	var names := {"labor_effigy":"노역 인형","mold_worker":"금형공","pressure_worker":"압력공","ash_catcher":"재받이"}
	return [kind,hp,armor,speed,distance,{"species":id,"name":names[id],"foundry_version":1}]

static func leader(id: String, hp: int, distance: int) -> Array:
	return ["wall",hp,2 if id==ELITE else 1,1,distance,{
		"species":id,"name":"금형 파수꾼" if id==ELITE else "주조 감독","rank":"elite" if id==ELITE else "boss",
		"foundry_version":1,"windup":0,"windup_max":3,"surge":3 if id==ELITE else 4,"recovering":false}]

static func rows(node: Dictionary, random: RandomNumberGenerator, fallback: Array) -> Array:
	if int(node.region)!=1: return fallback
	if str(node.kind)=="boss":
		return [leader(BOSS,56,40),worker("ash_catcher",4,34),worker("labor_effigy",8,38),worker("pressure_worker",10,46),
			worker("ash_catcher",4,36),worker("mold_worker",12,40),worker("labor_effigy",7,40),worker("ash_catcher",4,42)]
	if bool(node.get("elite",false)):
		return [leader(ELITE,32,36),worker("ash_catcher",4,34),worker("labor_effigy",8,38),worker("pressure_worker",10,46),
			worker("labor_effigy",7,36),worker("mold_worker",12,40),worker("ash_catcher",4,42)]
	var stage := mini(2,maxi(0,(int(node.floor)-1)/3))
	var variant := random.randi_range(0,2)
	var result := [worker("labor_effigy",7+stage,32),worker("mold_worker",13+stage*2,36),
		worker("ash_catcher",4,38),worker("pressure_worker",9+stage,46)]
	# Two variants give a light chain target; the third trades it for durable labor.
	if variant==1:
		result[0]=worker("ash_catcher",4,32)
		result[2]=worker("labor_effigy",7+stage,38)
	elif variant==2: result[2]=worker("labor_effigy",7+stage,38)
	result.append_array([worker("labor_effigy",7+stage,36),worker("ash_catcher",4,42)])
	if stage>=1: result.append(worker("mold_worker",11,40))
	if stage>=2: result.append(worker("labor_effigy",8,42))
	return result

static func movement(enemy: Dictionary) -> Dictionary:
	# Called once per surviving enemy turn, also in the real-model forecast copy.
	if bool(enemy.recovering):
		enemy.recovering=false
		if int(enemy.foundry_version) == 3: enemy.def = int(enemy.shell_armor)
		var result := {"step":0,"action":"recover","windup":0,"recovering":false}
		if int(enemy.foundry_version) == 3: result.armor = int(enemy.def)
		return result
	if int(enemy.get("jammed",0))>0:
		return {"step":int(enemy.speed),"action":"jammed","windup":int(enemy.windup),"recovering":false}
	var charged := int(enemy.windup)+1
	var release := charged>=int(enemy.windup_max)
	enemy.windup=0 if release else charged
	enemy.recovering=release
	if release and int(enemy.foundry_version) == 3: enemy.def = 0
	var result := {"step":int(enemy.speed)+(int(enemy.surge) if release else 0),"action":"surge" if release else "windup","windup":int(enemy.windup),"recovering":release}
	if int(enemy.foundry_version) == 3: result.armor = int(enemy.def)
	return result

static func intent(enemy: Dictionary, show_distance: bool = true) -> String:
	if int(enemy.get("foundry_version", 0)) == 3 and bool(enemy.get("recovering", false)):
		return "반격 기회 · 장갑 개방"
	if not show_distance:
		if bool(enemy.get("recovering", false)): return "정지 · 다음 행동 접근 없음"
		if int(enemy.get("jammed", 0)) > 0: return "축압 정지 %d턴 · 일반 접근" % int(enemy.jammed)
		return "축압 %d턴 → 돌진" % (int(enemy.windup_max) - int(enemy.windup))
	if bool(enemy.get("recovering",false)): return "정지 · 다음 행동 전진 0m"
	if int(enemy.get("jammed",0))>0: return "축압 정지 %d턴 · 전진 %dm" % [int(enemy.jammed),int(enemy.speed)]
	return "축압 %d턴 → 본체 %dm 전진" % [int(enemy.windup_max)-int(enemy.windup),int(enemy.speed)+int(enemy.surge)]

static func valid(enemy: Dictionary) -> bool:
	if not enemy.has("foundry_version"): return true
	if not number(enemy.foundry_version,1,3) or not active(enemy): return false
	if int(enemy.foundry_version) == 3:
		if not winding(enemy) or not number(enemy.get("shell_armor", -1), 0, 3): return false
		if int(enemy.get("def", -1)) != (0 if enemy.get("recovering", false) else int(enemy.shell_armor)): return false
		if not number(enemy.get("surge", -1), 5 if str(enemy.species) == ELITE else 6, 5 if str(enemy.species) == ELITE else 6): return false
	elif enemy.has("shell_armor"): return false
	if not winding(enemy): return true
	var period := 2 if int(enemy.foundry_version)>=2 else 3
	if not number(enemy.get("windup",-1),0,period-1) or not number(enemy.get("windup_max",-1),period,period): return false
	if not number(enemy.get("surge",-1),1,9) or not enemy.get("recovering") is bool: return false
	if bool(enemy.recovering) and int(enemy.windup)!=0: return false
	return int(enemy.get("charge_max",0))==0 and not bool(enemy.get("stance",false))

static func number(value: Variant, lo: int, hi: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value)) and value>=lo and value<=hi
