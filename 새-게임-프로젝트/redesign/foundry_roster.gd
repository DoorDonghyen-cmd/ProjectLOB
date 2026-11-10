extends RefCounted
## Version 6: authored second-region pressure, independent of the player's build.
const VERSION := 6
const ELITE := "mold_warden"
const BOSS := "foundry_overseer"

static func named(enemy: Dictionary) -> bool:
	return str(enemy.get("species","")) in [ELITE,BOSS]

static func rows(node: Dictionary, random: RandomNumberGenerator, fallback: Array) -> Array:
	if int(node.region) != 1: return fallback
	if str(node.kind) == "boss":
		return [
			["stance",48,6,1,38,{"species":BOSS,"name":"주조 감독","rank":"boss","charge":0,"charge_max":3,"charge_pull":3}],
			["wall",8,2,1,30],["runner",6,0,2,34],["evader",6,0,2,40],
			["runner",6,0,2,34],["wall",8,2,1,36],["runner",6,0,2,38],["evader",6,0,2,40]]
	if bool(node.get("elite",false)):
		return [
			["stance",26,5,1,34,{"species":ELITE,"name":"금형 파수꾼","rank":"elite"}],
			["runner",5,0,2,32],["evader",6,0,2,38],["caster",8,0,1,42,{"charge_max":3,"charge_pull":2}],
			["runner",5,0,2,34],["wall",8,2,1,38],["runner",5,0,2,40]]
	var depth := int(node.floor)
	var stage := mini(2,maxi(0,(depth-1)/3))
	var variant := random.randi_range(0,1)
	var opening: Array
	if stage == 0:
		# A visible front plate and one slow support clock; no stacked rush clocks.
		opening = [["wall",9,2,1,30],["runner",5,0,2,34],["caster",7,0,1,40,{"charge_max":4,"charge_pull":2}],["evader",5,0,1,42]]
		if variant == 1:
			opening[0] = ["runner",5,0,2,30]
			opening[1] = ["wall",9,3,1,34]
	elif stage == 1:
		opening = [["wall",11,3,1,30],["runner",5,0,2,34],["caster",8,0,1,40],["evader",6,0,2,44]]
		if variant == 1: opening[0] = ["absorber",10,0,1,30,{"barrier":2,"barrier_max":2}]
	else:
		opening = [["stance",13,4,1,30],["runner",6,0,2,34],["caster",9,0,1,40],["evader",6,0,2,44]]
		if variant == 1: opening[0] = ["wall",13,4,1,30]
	opening.append_array([["runner",5+stage/2,0,2,34],["evader",5,0,1,40]])
	if stage >= 1: opening.append(["wall",8,2,1,38])
	if stage >= 2: opening.append(["runner",6,0,2,40])
	return opening

static func intent(enemy: Dictionary, escorts: int, show_distance: bool = true) -> String:
	if preload("res://redesign/foundry_workers.gd").winding(enemy): return preload("res://redesign/foundry_workers.gd").intent(enemy, show_distance)
	var armor := "장갑 %d → %d" % [int(enemy.def),0 if bool(enemy.get("stance_closed",true)) else int(enemy.get("stance_def",4))]
	if str(enemy.get("species","")) == ELITE: return armor + " · 적 행동마다 교대"
	var command := "호위 없음"
	if int(enemy.get("jammed",0)) > 0: command = "독려 정지 %d턴" % int(enemy.jammed)
	elif escorts > 0: command = "%d턴 뒤 호위 +%dm" % [int(enemy.charge_max)-int(enemy.charge),int(enemy.charge_pull)] if show_distance else "%d턴 뒤 호위 접근" % (int(enemy.charge_max)-int(enemy.charge))
	return armor + " · " + command
