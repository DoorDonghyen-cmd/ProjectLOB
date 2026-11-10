extends RefCounted
## Opt-in campaign revision. First pass: foundry leaders trade a stronger rush
## for one public, armor-free counterattack window. Existing saves keep v2.
const VERSION := 1
const Workers = preload("res://redesign/foundry_workers.gd")

static func enabled(state: Dictionary) -> bool:
	return int(state.get("enemy_pattern_version", 0)) == VERSION

static func valid(state: Dictionary) -> bool:
	var version = state.get("enemy_pattern_version", 0)
	if not Workers.number(version, 0, VERSION): return false
	return not enabled(state) or (int(state.get("fire_control_version", 0)) == 1 and int(state.get("magazine_build_version", 0)) >= 2)

static func prepare(state: Dictionary, node: Dictionary) -> void:
	if not enabled(state) or int(node.region) != 1: return
	for enemy in state.enemies + state.reinforcements:
		if not Workers.winding(enemy) or int(enemy.foundry_version) != 2: continue
		enemy.foundry_version = 3
		enemy.shell_armor = int(enemy.def)
		enemy.surge = 5 if str(enemy.species) == Workers.ELITE else 6
