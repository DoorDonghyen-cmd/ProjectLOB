extends RefCounted
## Discovery bias, not recipe bonuses or a locked reward pool.
const AMMO := {
	"volley_drive":["precise","charge","shatter","prepare"],
	"thermal_drive":["thermal","charge_heat","cool","vent","charge_hot"],
	"siege_drive":["pierce","charge_hot","bypass","sequence","charge"]
}
const PARTS := {
	"volley_drive":["duplex","sequencer","reclaimer","breaker"],
	"thermal_drive":["radiator","chain_sink","ember_core","reserve"],
	"siege_drive":["lens","supply","afterburner","sequencer"]
}

static func core(equipped: Array) -> String:
	for id in equipped:
		if AMMO.has(id): return id
	return ""

static func candidates(pool: Array, equipped: Array, parts: bool = false) -> Array:
	var id := core(equipped)
	var preferred: Array = (PARTS if parts else AMMO).get(id,[])
	return pool.filter(func(item): return preferred.has(item))
