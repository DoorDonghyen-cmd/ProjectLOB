extends RefCounted
## A trial room arms a mold worker with -1. Its original enemy index and
## distance are retained after death. Zero means the wreck cannot spawn again.
const SPECIES := "mold_worker"
const STACKS := 2

static func spawn(enemies: Array) -> Dictionary:
	var spawned := {}
	var occupied := enemies.any(func(enemy): return int(enemy.get("wreckage", 0)) > 0)
	for i in range(enemies.size()):
		var enemy: Dictionary = enemies[i]
		if int(enemy.get("wreckage", 0)) != -1 or int(enemy.hp) > 0: continue
		enemy.wreckage = 0 if occupied else STACKS
		if int(enemy.wreckage) == 0: continue
		spawned[i] = STACKS
		occupied = true
	return spawned

static func blocker(enemies: Array, target: int) -> int:
	if target < 0 or target >= enemies.size(): return -1
	var distance := int(enemies[target].distance)
	var nearest := -1
	for i in range(enemies.size()):
		var enemy: Dictionary = enemies[i]
		if int(enemy.get("wreckage", 0)) > 0 and int(enemy.distance) < distance:
			nearest = i
			distance = int(enemy.distance)
	return nearest

static func strike(enemies: Array, index: int, hits: int) -> Dictionary:
	var wreck: Dictionary = enemies[index]
	var removed := mini(int(wreck.wreckage), hits)
	wreck.wreckage -= removed
	return {"target": index, "kind": "wreckage", "damage": 0, "hp": 0, "wreckage_hit": removed, "wreckage_left": int(wreck.wreckage)}

static func valid(enemies: Array, reserves: Array) -> bool:
	var active := 0
	for enemy in enemies:
		if not enemy.has("wreckage"): continue
		var stacks: Variant = enemy.wreckage
		if enemy.get("species", "") != SPECIES or not (stacks is int or stacks is float): return false
		if not is_finite(float(stacks)) or floorf(float(stacks)) != float(stacks) or stacks < -1 or stacks > STACKS: return false
		if (int(enemy.hp) > 0) != (stacks == -1): return false
		if stacks > 0: active += 1
	return active <= 1 and not reserves.any(func(enemy): return enemy.has("wreckage"))
