extends RefCounted
## Finite ammunition is versioned per run; old saves keep their original cycle.
const VERSION := 1
const LIMIT := 32
const INVENTORY_VERSION := 1
const EMERGENCY_VERSION := 1
const EMERGENCY_ROUND := "basic_p2"
const EMERGENCY_COUNT := 4

static func emergency_enabled(state: Dictionary) -> bool:
	return enabled(state) and int(state.get("emergency_version", 0)) == EMERGENCY_VERSION

static func generated_count(state: Dictionary) -> int:
	return EMERGENCY_COUNT * int(state.get("emergency_uses", 0)) if emergency_enabled(state) else 0

static func remaining(state: Dictionary) -> int:
	return state.deck.size() + generated_count(state) - state.discard.size()

static func emergency_available(state: Dictionary, attack: Callable) -> bool:
	if not emergency_enabled(state) or state.phase not in ["plan", "ready"]: return false
	for zone in ["hand", "draw", "magazine", "plan", "held_front"]:
		for id in state.get(zone, []):
			if attack.call(str(id)): return false
	return true
const CARRY_LIMITS := {"scout":28, "work":30, "carrier":32, "heatworker":34, "hoist":36, "recovery":38, "expedition":40}

static func inventory_enabled(state: Dictionary) -> bool:
	return int(state.get("inventory_version", 0)) == INVENTORY_VERSION

static func enabled(state: Dictionary) -> bool:
	return int(state.get("reserve_version", 0)) == VERSION

static func start_deck() -> Array:
	var result: Array = []
	for row in [["basic_p1", 6], ["basic_p2", 8], ["basic_p3", 6]]:
		for unused in range(int(row[1])): result.append(row[0])
	return result

static func limit(state: Dictionary) -> int:
	if preload("res://redesign/combat_roles.gd").enabled(state):return preload("res://redesign/combat_roles.gd").carry(state)
	if enabled(state) and inventory_enabled(state):
		return mini(40, int(CARRY_LIMITS.get(state.get("outfit", ""), LIMIT)) + 2 * int(state.get("bag_upgrades", 0)))
	return LIMIT if enabled(state) else 14

static func prepare_opening(state: Dictionary, family: Callable) -> void:
	if not enabled(state): return
	# The seeded shuffle has already sampled copy order. Promote its first earned
	# special, never create an unowned round or consume a second random stream.
	for index in range(state.draw.size()):
		if family.call(str(state.draw[index])) != "basic":
			state.draw.push_front(state.draw.pop_at(index))
			return

static func exhausted(state: Dictionary) -> bool:
	if emergency_enabled(state): return false
	if not enabled(state) or state.phase not in ["plan", "ready"]: return false
	# held_front: rounds a 예약탄 set aside for the next magazine (ammo_revision.gd).
	for zone in ["hand", "draw", "magazine", "plan", "held_front"]:
		if not state.get(zone, []).is_empty(): return false
	if not state.get("fire_zones",[]).is_empty():return false
	# A final burning enemy can still die while the player waits/reloads.
	for enemy in state.get("enemies", []):
		if int(enemy.hp) > 0 and int(enemy.get("burn", 0)) > 0: return false
	return true
