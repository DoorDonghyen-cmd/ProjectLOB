extends RefCounted
## Roster 9: visible, finite leap cycles. No real-time timer or airborne immunity.
const VERSION := 9
const ELITE := "longleg_foldrunner"
const BOSS := "waterway_mother"

static func active(enemy: Dictionary) -> bool:
	return int(enemy.get("garden_version",0)) == 1 and str(enemy.get("species","")) in [ELITE,BOSS]

static func leader(id: String) -> Array:
	return ["runner",26 if id==ELITE else 42,0,0,38 if id==ELITE else 44,{
		"species":id,"name":"긴발 숨접이" if id==ELITE else "수로의 어미","rank":"elite" if id==ELITE else "boss",
		"garden_version":1,"leap_left":2,"leap_distance":6 if id==ELITE else 7,"recovering":false}]

static func rows(node: Dictionary, fallback: Array) -> Array:
	if int(node.region)!=2: return fallback
	if str(node.kind)=="boss":
		return [leader(BOSS),["runner",5,0,3,38],["evader",6,0,2,43],["wall",8,2,1,46],
			["runner",5,0,3,40],["spitter",7,0,0,46],["runner",5,0,3,44]]
	if bool(node.get("elite",false)):
		return [leader(ELITE),["runner",5,0,3,36],["evader",6,0,2,42],["wall",8,2,1,45],
			["runner",5,0,3,40],["spitter",7,0,0,46]]
	return fallback

static func movement(enemy: Dictionary) -> Dictionary:
	var action := "prepare"
	var step := 0
	if bool(enemy.recovering):
		enemy.recovering=false
	elif int(enemy.get("jammed",0))>0:
		action="jammed"
	else:
		enemy.leap_left-=1
		if int(enemy.leap_left)==0:
			enemy.leap_left=2
			enemy.recovering=true
			step=int(enemy.leap_distance)
			action="leap"
	if action=="prepare" and int(enemy.leap_left)==2: action="recover"
	return {"step":step,"action":action,"left":int(enemy.leap_left),"recovering":bool(enemy.recovering)}

static func intent(enemy: Dictionary, show_distance: bool = true) -> String:
	return _movement_intent(enemy, show_distance) + preload("res://redesign/boss_skills.gd").call_intent(enemy)

static func _movement_intent(enemy: Dictionary, show_distance: bool = true) -> String:
	if not show_distance:
		if bool(enemy.get("recovering", false)): return "숨고르기 · 다음 행동 접근 없음"
		if int(enemy.get("jammed", 0)) > 0: return "도약 차단 · %d턴" % int(enemy.jammed)
		return "도약 준비 · %d턴" % int(enemy.leap_left)
	if bool(enemy.get("recovering",false)): return "숨고르기 · 다음 행동 0m"
	if int(enemy.get("jammed",0))>0: return "도약 차단 · %d턴" % int(enemy.jammed)
	return "도약 %d턴 → %dm 접근" % [int(enemy.leap_left),int(enemy.leap_distance)]

static func valid(enemy: Dictionary) -> bool:
	if not enemy.has("garden_version"):
		return str(enemy.get("species","")) not in [ELITE,BOSS]
	var numbers=preload("res://redesign/foundry_workers.gd")
	if not numbers.number(enemy.garden_version,1,1) or not active(enemy): return false
	if not numbers.number(enemy.get("leap_left",-1),1,2): return false
	var distance:=6 if str(enemy.species)==ELITE else 7
	if not numbers.number(enemy.get("leap_distance",-1),distance,distance): return false
	if not enemy.get("recovering") is bool or (enemy.recovering and int(enemy.leap_left)!=2): return false
	return str(enemy.get("kind",""))=="runner" and int(enemy.get("speed",-1))==0 and int(enemy.get("charge_max",0))==0 and not enemy.get("stance",false) and not enemy.has("foundry_version")
