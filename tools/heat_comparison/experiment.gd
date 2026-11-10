extends RefCounted
## Experimental constants, NOT production rules or a public prediction system.
const Content = preload("res://redesign/content.gd")

static func extra_heat(state: Dictionary, id: String) -> int:
	var mode := str(state.get("qa_mode", "baseline"))
	if str(Content.AMMO[id].effect) in ["cool", "vent"]:
		state.qa_chain = 0
		return 0
	if not Content.is_attack(id): return 0
	var prior := int(state.get("qa_chain", 0))
	state.qa_chain = prior + 1
	if mode == "heat_plus1": return 1
	if mode == "sustained": return mini(2, prior / 2)
	if mode == "sustained_rebalanced": return clampi(prior - 2, -1, 3)
	return 0

static func probability(state: Dictionary, id: String) -> float:
	if not Content.is_attack(id): return 0.0
	match str(state.get("qa_mode", "")):
		"fault8": return 0.08
		"fault2": return 0.02
		"weapon_fault": return minf(0.20, 0.02 + int(state.get("qa_chain", 0)) * 0.02 + maxi(0, int(state.heat) - Content.hot_threshold(state)) * 0.01)
	return 0.0

static func fault(state: Dictionary, id: String) -> bool:
	var chance := probability(state, id)
	if chance <= 0: return false
	# Dedicated stream: comparing reliability must not reroll scatter targets.
	var rng := RandomNumberGenerator.new()
	if state.has("qa_fault_rng"): rng.state = int(state.qa_fault_rng)
	else: rng.seed = int(state.seed) + 900001
	var failed := rng.randf() < chance
	state.qa_fault_rng = str(rng.state)
	return failed
