extends "res://redesign/campaign.gd"
## Optional first-part offer on an otherwise ordinary region-one reward.

const DEMO_SEED := 17
const StrikerUpgrade = preload("res://redesign/samples/opening_build/third_striker_trial.gd")
const FIRST_PARTS := {"single": "third_striker", "burst": "resonator", "heavy": "cooling_breech"}
const PACKAGES := {"single": "pierce_p2", "burst": "precise_p2", "heavy": "vent"}
const EARNED_ROUTES := {
	17: {
		"single": [["fire", "fire"], ["fire", "fire", "fire"]],
		"burst": [["fire", "fire", "fire"], ["fire", "fire", "fire"]],
		"heavy": [["fire", "reload", "fire", "fire"], ["fire", "fire", "fire"]],
	},
	23: {
		"single": [["fire", "fire", "fire"], ["fire", "fire"]],
		"burst": [["fire", "fire", "fire"], ["fire", "fire", "fire"]],
		"heavy": [["fire", "fire", "fire"], ["fire", "fire", "fire"]],
	},
}

var offer_enabled := false
var upgrade_enabled := false

func can_upgrade_striker() -> bool:
	return upgrade_enabled and s.phase == "shop" and int(s.region) == 1 and is_equipped(StrikerUpgrade.PART) and not StrikerUpgrade.upgraded(model.s) and int(s.credits) >= StrikerUpgrade.PRICE

func upgrade_striker() -> bool:
	if not can_upgrade_striker(): return false
	s.credits -= StrikerUpgrade.PRICE
	model.s[StrikerUpgrade.FLAG] = true
	_log("trial_striker_upgrade", {"cost": StrikerUpgrade.PRICE})
	return true

func part_rewards() -> Array:
	if offer_enabled and s.phase == "reward" and not s.resolved and int(s.region) == 0 and int(s.clears) == 2 and s.parts.is_empty():
		var current := node()
		var id: String = FIRST_PARTS.get(s.gun, "")
		if current.kind == "combat" and not current.get("elite", false) and not id.is_empty() and can_equip_reward(id):
			return [id]
	return super.part_rewards()

func prepare_checkpoint(gun: String, seed: int = DEMO_SEED) -> bool:
	var route: Array = EARNED_ROUTES.get(seed, {}).get(gun, [])
	if route.is_empty(): return false
	start(gun, seed, 0, "balanced", Content.RouteMap.VERSION, "carrier", true)
	while departure_pending():
		if not advance_departure(true): return false
	return _earn_reward(route[0]) and reward(PACKAGES[gun]) and _earn_reward(route[1])

func prepare_investment(plan: Dictionary) -> bool:
	offer_enabled = true
	if not prepare_checkpoint("single", int(plan.seed)) or not reward(StrikerUpgrade.PART): return false
	if not _follow_visits(plan.before_gate) or not gate("cadence") or not depart_gate(): return false
	if not _follow_visits(plan.after_gate) or not enter(int(plan.shop)) or s.phase != "shop": return false
	upgrade_enabled = true
	return true

func next_normal_encounter() -> int:
	for room in choices():
		if room.kind == "combat" and not room.get("elite", false): return int(room.id)
	return -1

func _earn_reward(moves: Array) -> bool:
	return enter(next_normal_encounter()) and _replay_win(moves)

func _follow_visits(visits: Array) -> bool:
	for visit in visits:
		if not enter(int(visit[0])): return false
		if s.phase == "combat":
			if visit.size() != 2 or not _replay_win(visit[1]) or not reward("skip" if boss_loot() else "credits"): return false
		else:
			if s.phase in ["supply", "event"] and not resolve("skip"): return false
			if not leave(): return false
	return true

func _replay_win(moves: Array) -> bool:
	for move in moves:
		if s.phase == "reward": return true
		var accepted := false
		if move is int or move is float:
			model.s.fire_heat_trial.rounds = int(move)
			accepted = model.fire()
		elif move is Array:
			accepted = model.eject_magazine_rounds(move.map(func(index): return int(index)))
		else:
			match str(move):
				"fire":
					model.s.fire_heat_trial.rounds = 0
					accepted = model.fire()
				"reload": accepted = model.reload_magazine()
				"cool": accepted = model.cool_magazine()
				"emergency": accepted = model.emergency_resupply()
		if not accepted: return false
		sync_combat()
	return s.phase == "reward"
