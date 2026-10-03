extends SceneTree
## Fixed-budget actual-model benchmark. Knows RNG; not a player win-rate test.
const Model = preload("res://redesign/model.gd")
const Content = preload("res://redesign/content.gd")
const Data = preload("res://redesign/campaign_content.gd")
const PACKAGES := {
	"baseline": [], "focus": ["sequencer", "duplex", "opening"],
	"thermal": ["coil", "igniter", "inferno"], "electric": ["capacitor", "arc_splitter"],
	"distance": ["rammer", "momentum"], "mixed": ["opening", "afterburner", "triad"],
	"compression": ["field_press", "supply"], "reserve": ["reserve"]
}
const ORDERS := [
	["charge", "precise", "pierce", "arc", "bore", "push", "basic"],
	["bore", "push", "charge", "precise", "arc", "pierce", "basic"],
	["arc", "charge", "arc", "precise", "pierce", "bore", "push", "basic"],
	["pierce", "precise", "charge", "arc", "bore", "push", "basic"],
	["precise", "charge", "pierce", "arc", "bore", "push", "basic"],
	["push", "bore", "arc", "charge", "precise", "pierce", "basic"],
	["charge", "bore", "arc", "pierce", "precise", "push", "basic"],
	["basic", "basic", "basic", "basic", "basic", "basic"]
]
var rows: Array = []

func _initialize() -> void:
	run.call_deferred()

func clone(model):
	var copy = Model.new()
	copy.s = model.s.duplicate(true)
	return copy

func score(model) -> float:
	if model.s.phase == "lost": return -10000
	var value := 10000.0 if model.s.phase in ["reward", "won"] else 0.0
	for enemy in model.s.enemies:
		value += (int(enemy.max_hp) - int(enemy.hp)) * 10
		value += 80 if int(enemy.hp) == 0 else float(enemy.distance) / maxi(1, int(enemy.speed)) + int(enemy.burn) * 3
		value -= int(enemy.get("barrier", 0)) * 20
	return value - int(model.s.turns) * 2

func one_magazine(model):
	var best = null
	var best_score := -INF
	var compressions: Array = [""]
	for id in model.s.hand:
		if not compressions.has(id) and model.can_field_compress(id): compressions.append(id)
	for compress_id in compressions:
		for order in ORDERS:
			var copy = clone(model)
			if compress_id != "": copy.field_compress(compress_id)
			# Ordered preferences fill through legal commands, including anchored compression.
			for id in order:
				if copy.available(id) > 0: copy.load_round(id)
			if copy.s.plan.is_empty() or not copy.confirm(): continue
			while copy.s.phase == "ready" and not copy.s.magazine.is_empty(): copy.fire()
			var value := score(copy)
			if value > best_score:
				best_score = value
				best = copy
	return best

func run() -> void:
	for gun in Content.GUNS:
		for package in PACKAGES:
			for seed_value in [17, 42, 109, 731042, 913, 2048]:
				for scenario in ["armor", "crowd", "shield"]:
					var model = Model.new()
					model.start(gun, seed_value)
					model.s.equipped_parts = PACKAGES[package].duplicate()
					model.s.deck = ["charge", "charge", "precise", "precise", "bore", "bore", "arc", "arc", "push", "pierce"]
					model.begin_encounter(1)
					var enemy_rows: Array
					match scenario:
						"armor": enemy_rows = [["wall", 36, 4, 1, 22], ["wall", 18, 2, 1, 27]]
						"crowd": enemy_rows = [["runner", 9, 0, 2, 20], ["evader", 9, 0, 2, 23], ["runner", 9, 0, 2, 26], ["evader", 9, 0, 2, 29]]
						_: enemy_rows = [["absorber", 18, 1, 1, 21], ["caster", 12, 0, 1, 25], ["runner", 8, 0, 2, 28]]
					model.s.enemies = []
					for row in enemy_rows: model.s.enemies.append(Data._enemy(row))
					model.assign_opening_lanes()
					for cycle in range(6):
						if model.s.phase == "ready": model.reload_magazine()
						if model.s.phase != "plan": break
						var next = one_magazine(model)
						if next == null: break
						model = next
					var margin := 99.0
					for e in model.s.enemies:
						if int(e.hp) > 0: margin = minf(margin, float(e.distance) / maxi(1, int(e.speed)))
					rows.append({"gun": gun, "package": package, "seed": seed_value, "scenario": scenario, "outcome": model.s.phase, "turns": model.s.turns, "shots": model.s.shots, "reloads": model.s.reloads, "capacity": model.capacity(), "reload_cost": model.reload_cost(), "remaining_contact_turns": margin, "compression_left": model.s.field_compression_left})
		print("AUDIT " + gun + " complete")
	var file := FileAccess.open(OS.get_environment("QA_OUTPUT_DIR").path_join("build_diversity.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"method": "eight fixed order policies; actual commands; one-step scoring; RNG visible to benchmark; six reload cycles; no exchange search; not human win rate", "rows": rows}, "\t"))
	print("BUILD DIVERSITY COMPLETE cases=%d" % rows.size())
	quit()
