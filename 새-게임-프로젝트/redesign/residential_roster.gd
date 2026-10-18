extends RefCounted
## Species presentation is separate from stable combat-role IDs.
const VERSION := 5
const SPECIES := {
	"runner": {"id": "foldrunner", "name": "숨접이", "rule": "긴 뒷다리로 빠르게 접근합니다. 충격탄으로 밀어내거나 먼저 처치하세요."},
	"wall": {"id": "eavesback", "name": "처마등", "rule": "겹등판이 매 타격의 피해를 줄입니다. 철갑탄의 관통이나 소이탄의 화상으로 대응하세요."},
	"evader": {"id": "rainpouch", "name": "빗주머니", "rule": "젖은 집수기관은 전기에 약합니다. 전기 속성의 주 타격에 추가 피해 2를 받습니다."},
	"spitter": {"id": "pressure_toad", "name": "압력두꺼비"},
}

static func rows(node: Dictionary, random: RandomNumberGenerator) -> Array:
	var depth := int(node.floor)
	if node.kind == "boss":
		# A recognizable enlarged population leader, not an unannounced fifth rule.
		return [["wall", 14, 2, 1, 23], ["runner", 4, 0, 2, 26], ["evader", 6, 0, 1, 29], ["spitter", 7, 0, 0, 32], ["runner", 4, 0, 2, 30]]
	if depth == 1:
		return [["runner", 8, 0, 2, 18], ["runner", 12, 0, 2, 22]]
	if depth == 2:
		# Pierce/boost can break the shell; burn or push buys a different route.
		return [["wall", 7, 3, 1, 20], ["runner", 5, 0, 2, 26]]
	if depth == 3:
		# Two action ticks to launch. Killing the shooter or intercepting its shot
		# are both valid; no required bypass/disrupt draw and no armor gate here.
		return [["runner", 4, 0, 2, 22], ["spitter", 6, 0, 0, 28]]
	if depth <= 5:
		# A second magazine matters: retain heat, choose a short volley, or cool.
		# Reserves arrive at their published distance, never on a real-time clock.
		return [["runner", 4, 0, 2, 23], ["wall", 6, 2, 1, 27],
			["evader", 5, 0, 1, 30], ["runner", 4, 0, 2, 32],
			["runner", 5, 0, 2, 26], ["evader", 5, 0, 1, 29]]
	var front: Array = [
		[["wall", 9, 3, 1, 23], ["spitter", 7, 0, 0, 29], ["runner", 6, 0, 2, 30], ["evader", 7, 0, 1, 33]],
		[["evader", 7, 0, 1, 23], ["runner", 6, 0, 2, 27], ["wall", 9, 3, 1, 29], ["spitter", 7, 0, 0, 33]],
	][random.randi_range(0, 1)].duplicate(true)
	front.append(["runner", 6, 0, 2, 30])
	return front

static func identify(enemy: Dictionary, leader: bool = false) -> void:
	var spec: Dictionary = SPECIES[str(enemy.kind)]
	enemy.species = spec.id
	enemy.name = "둥지 처마등" if leader else str(spec.name)

static func rule(enemy: Dictionary) -> String:
	var spec: Dictionary = SPECIES.get(str(enemy.get("kind", "")), {})
	return str(spec.get("rule", "")) if enemy.get("species", "") == spec.get("id", "") else ""
