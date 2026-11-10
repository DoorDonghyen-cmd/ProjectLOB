extends RefCounted
## New full campaigns opt in. Existing campaigns keep their acquired combat rules.
const VERSION := 1
const BURN_GROWTH_STEP := 3
const COIL_GROUND_BONUS := 1
const SPECIALIST_FIRE_DURATION := 3
const NORMAL_APPROACH := 0.82
const ELITE_APPROACH := 0.90

static func enabled(state: Dictionary) -> bool:
	return int(state.get("balance_version",0)) == VERSION

static func valid(state: Dictionary) -> bool:
	var version = state.get("balance_version",0)
	if not (version is int or version is float) or not is_finite(float(version)) or version != floorf(version) or version < 0 or version > VERSION: return false
	return not enabled(state) or (int(state.get("combat_roles_version",0)) == 3 and int(state.get("magazine_build_version",0)) >= 2 and int(state.get("fire_control_version",0)) == 1)

static func approach(state: Dictionary, node: Dictionary) -> void:
	# Early bosses already have tight reload windows. Later ordinary fights had
	# kept the v2 HP allowance after core growth outpaced their approach.
	if not enabled(state) or int(node.region) < 2 or node.kind == "boss": return
	var factor: float = ELITE_APPROACH if node.get("elite",false) else NORMAL_APPROACH
	for enemy in state.enemies + state.reinforcements:
		if int(enemy.get("speed",0)) > 0:
			enemy.distance = maxi(6, ceili(int(enemy.distance) * factor))
