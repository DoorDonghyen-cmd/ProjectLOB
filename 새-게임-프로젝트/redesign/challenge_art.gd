extends RefCounted
const Challenges = preload("res://redesign/residential_challenges.gd")
const BOSS_ATLAS = preload("res://assets/art/elite_boss_20261018/closure_watch_states.png")
const ELITE_ATLAS = preload("res://assets/art/elite_boss_20261018/resonant_eavesback_states.png")

static func pose(enemy: Dictionary, releasing: bool = false) -> Dictionary:
	if str(enemy.get("species","")) == Challenges.BOSS:
		var opened := str(enemy.get("ranged_phase","guard")) != "guard"
		return {"texture":BOSS_ATLAS,"source":Rect2(736,80,784,858) if opened else Rect2(142,80,586,858),
			"anchor":Vector2(424,848) if opened else Vector2(328,848),"scale":0.173,"height":148.0,"open":opened}
	var opened := releasing or int(enemy.get("charge",0)) >= 2
	return {"texture":ELITE_ATLAS,"source":Rect2(768 if opened else 0,80,768,824),
		"anchor":Vector2(396 if opened else 380,808),"scale":0.15,"height":124.0,"open":opened}
