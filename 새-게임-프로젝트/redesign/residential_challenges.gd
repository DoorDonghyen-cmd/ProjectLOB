extends RefCounted
## Authored first-region threats. Version 5 only; earlier runs keep their packs.
const ELITE := "resonant_eavesback"
const BOSS := "closure_watch"

static func rows(node: Dictionary, fallback: Array) -> Array:
	if int(node.region) != 0: return fallback
	if str(node.kind) == "boss":
		return [["spitter",44,2,0,32,{"species":BOSS,"name":"폐쇄 당직","rank":"boss","guard_armor":2,"ranged_phase":"guard","ranged_left":2}],
			["runner",5,0,2,35],["runner",5,0,2,39],["evader",5,0,1,42],
			["wall",8,1,1,32],["runner",5,0,2,36]]
	if bool(node.get("elite",false)):
		return [["wall",16,1,1,25,{"species":ELITE,"name":"공명 처마등","rank":"elite","charge":0,"charge_max":3,"charge_pull":2}],
			["runner",4,0,2,30],["runner",4,0,2,34],["evader",5,0,1,37],["runner",5,0,2,32]]
	return fallback

static func identify(enemy: Dictionary, row: Array) -> void:
	if row.size() < 6 or not row[5].has("rank"): return
	for key in ["species","name","rank"]: enemy[key] = row[5][key]

static func named(enemy: Dictionary) -> bool:
	return str(enemy.get("species","")) in [ELITE,BOSS]
