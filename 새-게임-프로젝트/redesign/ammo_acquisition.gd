extends RefCounted
## New-run foundation and earned discoveries. Existing saved decks stay untouched.
const Ammo = preload("res://redesign/content.gd")
const FIRST_POOL := ["pierce", "precise", "charge", "bore", "arc", "push", "thermal"]

static func start_deck() -> Array:
	return ["basic_p1", "basic_p1", "basic_p2", "basic_p2", "basic_p2", "basic_p2", "basic_p2", "basic_p2", "basic_p3", "basic_p3"]

static func first_options(seed_value: int, gun: String, parts: Array, loadout: String) -> Array:
	var random := RandomNumberGenerator.new()
	random.seed = seed_value + 81439
	var preferred := "charge"
	if parts.has("volley_drive"): preferred = "precise"
	elif parts.has("thermal_drive"): preferred = "thermal"
	elif parts.has("siege_drive"): preferred = "pierce"
	preferred = str({"amplify":"precise", "thermal":"bore", "voltage":"arc"}.get(loadout, preferred))
	var weapon_choices: Array = {"single":["charge","pierce"], "burst":["precise","charge"], "scatter":["arc","pierce"], "heavy":["bore","arc"], "amplifier":["charge","pierce"]}[gun].duplicate()
	var families: Array = [preferred]
	for candidate in weapon_choices:
		if not families.has(candidate): families.append(candidate);break
	var remaining := FIRST_POOL.filter(func(id): return not families.has(id))
	families.append(remaining[random.randi_range(0, remaining.size()-1)])
	return families.map(func(id): return Ammo.Variants.key(id,2) if Ammo.Variants.FAMILIES.has(id) else id)

static func replaceable(deck: Array) -> Array:
	var result: Array = []
	for id in deck:
		if Ammo.source_id(str(id)) == "basic" and not Ammo.is_compressed(str(id)) and not result.has(id): result.append(id)
	result.sort_custom(func(a,b): return Ammo.AMMO[a].dmg < Ammo.AMMO[b].dmg)
	return result

static func opening_rows(node: Dictionary, fallback: Array) -> Array:
	if int(node.region) != 0 or node.kind == "boss": return fallback
	match int(node.floor):
		1: return [["runner",6,0,2,20],["runner",8,0,2,24]]
		2: return [["runner",3,0,2,24],["wall",5,1,1,28],["runner",4,0,2,32]]
		3: return [["runner",3,0,2,24],["runner",3,0,2,28],["spitter",5,0,0,32],["evader",4,0,1,34]]
		4,5: return [["runner",3,0,2,25],["evader",4,0,1,28],["wall",6,1,1,31],["runner",3,0,2,34],
			["runner",4,0,2,30],["spitter",5,0,0,34]]
	return fallback
