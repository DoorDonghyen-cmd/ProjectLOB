extends RefCounted
## Opening-only candidate; existing campaigns never opt in. No damage/HP changes.
const VERSION := 1
const ROLES := ["breach", "boss", "ambush", "sweep", "payoff"]
const NODES := {"breach":401, "boss":802, "ambush":301, "sweep":201, "payoff":602}
const TITLES := {"breach":"교대 방패 진지", "boss":"첫 관문 · 보스", "ambush":"사수 매복", "sweep":"흩어진 약탈단", "payoff":"모여든 약탈단"}
const PROFILES := {
	"breach": {"distance_scale":0.5, "speed_bonus":1},
	"boss": {"distance_scale":0.5, "speed_bonus":1},
	"ambush": {"distance_scale":1.0, "speed_bonus":0},
	"sweep": {"distance_scale":1.0, "speed_bonus":0},
	"payoff": {"distance_scale":1.0, "speed_bonus":0}
}

static func apply_opening(state: Dictionary, role: String) -> bool:
	if not ROLES.has(role) or state.get("phase", "") != "plan" or state.has("approach_trial_version") or int(state.get("magazine_trial_version", 0)) != 1 or int(state.get("encounter_id", 0)) != int(NODES[role]): return false
	if not state.get("plan", []).is_empty() or not state.get("magazine", []).is_empty(): return false
	var profile: Dictionary = PROFILES[role].duplicate()
	# Five-weapon comparison: boss escorts allow a full swap while still advancing faster.
	if preload("res://redesign/magazine_trial.gd").weapons_enabled(state) and role == "boss": profile.distance_scale = 0.8
	for enemy in state.enemies + state.reinforcements:
		# Stationary shooters retain their position and shot clock. Moving guards
		# cross in front naturally; reserves still enter at their authored timing.
		if int(enemy.speed) <= 0: continue
		enemy.distance = maxi(4, ceili(float(enemy.distance) * float(profile.distance_scale)))
		enemy.speed = int(enemy.speed) + int(profile.speed_bonus)
	state.approach_trial_version = VERSION
	state.approach_trial_role = role
	return true

static func valid(state: Dictionary) -> bool:
	var version: Variant = state.get("approach_trial_version", 0)
	if not (version is int or version is float): return false
	if float(version) != 0.0 and float(version) != float(VERSION): return false
	if version == 0: return not state.has("approach_trial_role")
	var role: Variant = state.get("approach_trial_role", "")
	return role is String and ROLES.has(role) and int(state.get("magazine_trial_version", 0)) == 1 and int(state.get("encounter_id", 0)) == int(NODES[role])
