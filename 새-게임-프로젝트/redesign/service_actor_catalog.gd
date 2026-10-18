extends RefCounted
## New outfits register only their three poses here; room art is independent.
const POSES := {
	"work": {
		"shop": preload("res://redesign/service_actor_shop_work.tres"),
		"supply": preload("res://redesign/service_actor_supply_work.tres"),
		"workshop": preload("res://redesign/service_actor_workshop_work.tres")
	},
	"heatworker": {
		"shop": preload("res://redesign/service_actor_shop_heatworker.tres"),
		"supply": preload("res://redesign/service_actor_supply_heatworker.tres"),
		"workshop": preload("res://redesign/service_actor_workshop_heatworker.tres"),
	},
	"hoist": {
		"shop": preload("res://redesign/service_actor_shop_hoist.tres"),
		"supply": preload("res://redesign/service_actor_supply_hoist.tres"),
		"workshop": preload("res://redesign/service_actor_workshop_hoist.tres"),
	},
	"recovery": {
		"shop": preload("res://redesign/service_actor_shop_recovery.tres"),
		"supply": preload("res://redesign/service_actor_supply_recovery.tres"),
		"workshop": preload("res://redesign/service_actor_workshop_recovery.tres"),
	},
	"expedition": {
		"shop": preload("res://redesign/outfit_preview_shop.tres"),
		"supply": preload("res://redesign/outfit_preview_supply.tres"),
		"workshop": preload("res://redesign/outfit_preview_workshop.tres"),
	},

}

static func resolve(outfit: String, place: String) -> Dictionary:
	var selected: Dictionary = POSES.get(outfit, {})
	var available := selected.has(place)
	return {"profile": selected[place] if available else POSES.work.get(place), "requested": outfit, "displayed": outfit if available else "work", "fallback": not available}
