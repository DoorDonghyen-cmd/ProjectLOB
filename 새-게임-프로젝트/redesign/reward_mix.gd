extends RefCounted
## Mixed round rewards (2026-11-11, user: "계속 쓰던 탄만 쓰게 돼, 탄 보충이 해당 탄만 되어서",
## "A를 먼저 진행해 줘"). Focus-build rewards offered [main copy, support, main upgrade]: two of
## three were the main round and no other attack round ever came, so decks ended as one attack
## round plus basics. New runs (model.s.reward_mix_version) offer one card per row instead:
## the main round (upgrade when one exists, else a copy) / another attack round (the family
## held least) / a support round for the main. Normal-fight rewards and depots both use it.
const Content = preload("res://redesign/content.gd")
const VERSION := 1

static func enabled(state: Dictionary) -> bool:
	return int(state.get("reward_mix_version", 0)) == VERSION

## Another attack round from the place's pool: not basic, not the main family, the family the
## deck holds least; ties broken by the seeded order of the pool.
static func other_attack(pool: Array, deck: Array, main_family: String, seed_value: int) -> String:
	var candidates: Array = []
	for value in pool:
		var id := str(value)
		if not Content.AMMO.has(id) or not Content.is_attack(id): continue
		var family := Content.source_id(id)
		if family == "basic" or family == main_family or Content.is_temporary(id): continue
		if not candidates.has(id): candidates.append(id)
	if candidates.is_empty(): return ""
	var offset := absi(seed_value) % candidates.size()
	var rotated: Array = candidates.slice(offset) + candidates.slice(0, offset)
	var best := ""
	var fewest := 1000000
	for id in rotated:
		var held := deck.filter(func(owned): return Content.source_id(str(owned)) == Content.source_id(str(id))).size()
		if held < fewest:
			fewest = held
			best = str(id)
	return best

static func valid(state: Dictionary) -> bool:
	var version = state.get("reward_mix_version", 0)
	return (version is int or version is float) and int(version) == version and int(version) >= 0 and int(version) <= VERSION
