extends RefCounted
## Escaped residential organisms now inhabit the garden's containment/water channels.
const Residential = preload("res://redesign/residential_roster.gd")
const Challenges = preload("res://redesign/residential_challenges.gd")

static func rows(node: Dictionary, random: RandomNumberGenerator, fallback: Array) -> Array:
	if int(node.region) != 2: return fallback
	# Retain the existing barrier gate and machine controller; replace its organic escorts.
	if str(node.kind) == "boss":
		return [["absorber",36,1,1,40,{"species":"garden_regulator","name":"집수 조정기","rank":"boss","barrier":3,"barrier_max":3}],
			["runner",7,0,2,34],["wall",10,2,1,40],["evader",8,0,1,43],
			["spitter",8,0,0,40],["runner",7,0,2,38],["evader",8,0,1,42]]
	if bool(node.get("elite",false)):
		return [["wall",26,2,1,36,{"species":Challenges.ELITE,"name":"공명 처마등","rank":"elite","charge":0,"charge_max":3,"charge_pull":2}],
			["runner",7,0,2,38],["evader",8,0,1,42],["spitter",8,0,0,46],
			["runner",7,0,2,38],["wall",9,2,1,42]]
	var late := int(node.floor) >= 5
	var groups: Array = [
		[["wall",10,3,1,34],["runner",7,0,2,38],["evader",8,0,1,42],["spitter",8,0,0,46]],
		[["evader",8,0,1,34],["wall",10,3,1,38],["runner",7,0,2,42],["spitter",8,0,0,46]],
	]
	var result: Array = groups[random.randi_range(0,1)].duplicate(true)
	result.append(["runner",7,0,2,38])
	result.append(["evader",8,0,1,42])
	if late: result.append(["wall",10,3,1,40])
	return result

static func identify(enemy: Dictionary) -> void:
	if enemy.has("rank"): return
	if Residential.SPECIES.has(str(enemy.kind)): Residential.identify(enemy)
