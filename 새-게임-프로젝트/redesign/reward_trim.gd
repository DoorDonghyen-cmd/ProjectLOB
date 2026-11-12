extends RefCounted
## Normal-fight reward, third row: remove one round (2026-11-11, user: "전투 종료 후 탄환 선택만
## 나오는데 이것도 사양인지", "좋아 우선 다음단계까지 진행"). First step of reward B in
## docs/direction/reward-economy.md: new round / remove one round / credits. New runs only
## (model.s.reward_trim_version). Elites, bosses and the first (package) reward stay as before.
const VERSION := 1

static func enabled(state: Dictionary) -> bool:
	return int(state.get("reward_trim_version", 0)) == VERSION

## Owned rounds to offer for removal: one entry per kind, basic rounds first, then the most held.
static func options(deck: Array) -> Array:
	var kinds: Array = []
	for value in deck:
		if not kinds.has(str(value)): kinds.append(str(value))
	kinds.sort_custom(func(a, b):
		var basic_a := str(a).begins_with("basic")
		var basic_b := str(b).begins_with("basic")
		if basic_a != basic_b: return basic_a
		if deck.count(a) != deck.count(b): return deck.count(a) > deck.count(b)
		return str(a) < str(b))
	return kinds

static func valid(state: Dictionary) -> bool:
	var version = state.get("reward_trim_version", 0)
	return (version is int or version is float) and int(version) == version and int(version) >= 0 and int(version) <= VERSION
