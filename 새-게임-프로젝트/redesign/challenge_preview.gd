extends RefCounted
## Isolated developer entry; production uses the same encounter_pack.
static func campaign(kind: String, gun: String = "single") -> RefCounted:
	var run = preload("res://redesign/campaign.gd").new()
	run.start(gun,731042,0,"balanced",3,"carrier")
	run.s.departure_step = 3
	var candidates: Array = run.current_nodes().filter(func(node): return node.kind == "boss" if kind == "boss" else bool(node.get("elite",false)))
	assert(not candidates.is_empty(), "Challenge preview seed needs a real elite route")
	var node: Dictionary = candidates[0]
	run.s.node = node.id
	run.s.floor = node.floor
	run.s.parts = ["volley_drive","radiator"]
	run.s.equipped_parts = run.s.parts.duplicate()
	run.model.s.deck = ["charge","precise_p3","basic_p3","pierce_p3","cool","basic_p2","basic_p2","basic_p3","basic_p2","basic_p2"]
	run._begin_combat(node)
	run.model.s.engine.levels.volley_drive = 2
	run.model.s.hand = run.model.s.deck.slice(0,6)
	run.model.s.draw = run.model.s.deck.slice(6)
	run.model.s.discard = []
	return run
