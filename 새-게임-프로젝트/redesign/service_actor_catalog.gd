extends RefCounted
## Shared rooms, selected costume; unknown legacy IDs use the work fallback.
const POSES := {
	"work":{
		"shop":preload("res://redesign/service_actor_shop_work_cohesive.tres"),
		"supply":preload("res://redesign/service_actor_supply_work_cohesive.tres"),
		"workshop":preload("res://redesign/service_actor_workshop_work_cohesive.tres"),
	},
	"carrier":{
		"shop":preload("res://redesign/service_actor_shop_carrier_cohesive.tres"),
		"supply":preload("res://redesign/service_actor_supply_carrier_cohesive.tres"),
		"workshop":preload("res://redesign/service_actor_workshop_carrier_cohesive.tres"),
	},
	"scout":{
		"shop":preload("res://redesign/service_actor_shop_scout_cohesive.tres"),
		"supply":preload("res://redesign/service_actor_supply_scout_cohesive.tres"),
		"workshop":preload("res://redesign/service_actor_workshop_scout_cohesive.tres"),
	},
	"heatworker":{
		"shop":preload("res://redesign/service_actor_shop_heatworker_cohesive.tres"),
		"supply":preload("res://redesign/service_actor_supply_heatworker_cohesive.tres"),
		"workshop":preload("res://redesign/service_actor_workshop_heatworker_cohesive.tres"),
	},
	"hoist":{
		"shop":preload("res://redesign/service_actor_shop_hoist_cohesive.tres"),
		"supply":preload("res://redesign/service_actor_supply_hoist_cohesive.tres"),
		"workshop":preload("res://redesign/service_actor_workshop_hoist_cohesive.tres"),
	},
	"recovery":{
		"shop":preload("res://redesign/service_actor_shop_recovery_cohesive.tres"),
		"supply":preload("res://redesign/service_actor_supply_recovery_cohesive.tres"),
		"workshop":preload("res://redesign/service_actor_workshop_recovery_cohesive.tres"),
	},
	"expedition":{
		"shop":preload("res://redesign/service_actor_shop_expedition_cohesive.tres"),
		"supply":preload("res://redesign/service_actor_supply_expedition_cohesive.tres"),
		"workshop":preload("res://redesign/service_actor_workshop_expedition_cohesive.tres"),
	},
}

static func resolve(outfit: String, place: String) -> Dictionary:
	var selected: Dictionary = POSES.get(outfit, {})
	var available := selected.has(place)
	return {"profile": selected[place] if available else POSES.work.get(place), "requested": outfit, "displayed": outfit if available else "work", "fallback": not available}
