extends RefCounted
## Versioned acquisition policy. Retired cards remain valid for legacy ownership.
const VERSION := 3
const PAUSED_AMMO := ["prepare", "disrupt"]
const PAUSED_PARTS := ["indexer"]
const LINKS := {
	"volley_drive": ["precise", "charge", "shatter", "chase"],
	"thermal_drive": ["thermal", "charge_heat", "cool", "vent", "charge_hot"],
	"siege_drive": ["pierce", "charge_hot", "bypass", "sequence", "charge"],
	"cooling_breech": ["charge_hot", "cool"],
	"ember_core": ["thermal", "charge_heat", "precise", "vent"],
	"inferno": ["bore", "detonate", "spread", "push"],
	"arc_splitter": ["arc", "chase"],
	"momentum": ["push", "bore"],
	"triad": ["sequence", "cool", "shatter"],
	"overbore": ["pierce", "bore"],
	"field_press": ["pierce", "precise", "arc"],
	"coil": ["bore", "detonate", "spread"],
	"igniter": ["bore", "precise", "detonate"],
	"capacitor": ["arc"],
	"rammer": ["push"],
	"sequencer": ["charge", "charge_heat", "precise"],
	"duplex": ["precise", "charge"],
	"breaker": ["precise"],
	"lens": ["pierce", "bypass"],
	"executioner": ["precise", "chase"],
	"reclaimer": ["chase", "precise", "arc"],
	"radiator": ["charge_hot", "precise", "thermal"],
	"chain_sink": ["sequence", "charge", "precise"],
	"supply": ["charge", "charge_hot", "cool", "sequence"],
	"ordinary_chain": ["precise", "pierce", "chase", "sequence"],
	"compression_sink": ["pierce", "precise", "arc"],
	"opening": ["precise", "bypass"],
	"afterburner": ["vent", "sequence", "chase"]
}

static func ammo(pool: Array, version: int = 1) -> Array:
	var result := pool.filter(func(id): return not PAUSED_AMMO.has(id) and (version < 2 or id != "sequence"))
	if version >= 2: result.append("basic")
	return result

static func parts(pool: Array) -> Array:
	return pool.filter(func(id): return not PAUSED_PARTS.has(id))

static func fitting(pool: Array, equipped: Array, version: int = 1) -> Array:
	var connected: Array = []
	for part in equipped:
		var links: Array = ["basic","precise","pierce","charge","cool","shatter","arc"] if part == "ordinary_chain" and version >= 2 else LINKS.get(part, [])
		for id in links:
			if not connected.has(id): connected.append(id)
	# Keep the caller's seeded order; this is one choice, never a recipe or a lock.
	return pool.filter(func(id): return connected.has(id))

static func modules(pool: Array, equipped: Array) -> Array:
	var candidates := preload("res://redesign/build_affinity.gd").candidates(pool, equipped, true)
	# A second core cannot amplify the equipped core; do not recommend that as a module.
	return candidates.filter(func(id): return not preload("res://redesign/content.gd").is_core_part(id) and not PAUSED_PARTS.has(id))
