extends RefCounted
## Older golden command histories predate optional presentation observations.
## Exclude only that field; every rule outcome, command and RNG stays comparable.
static func history(source: Array) -> Array:
	var result := source.duplicate(true)
	for event in result:
		for shot in event.get("detail", {}).get("results", []):
			shot.erase("part_effects")
	return result

static func state(source: Dictionary) -> Dictionary:
	var result := source.duplicate(true)
	result.history = history(result.get("history", []))
	return result
