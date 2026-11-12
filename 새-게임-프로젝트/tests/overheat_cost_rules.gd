extends SceneTree
## Overheat cost rules (2026-11-11, overheat_cost.gd): new runs carry the flag, forced cooling
## costs reload + 1 + extra enemy actions (+2, 리액터 +1), voluntary cooling stays 1, the fire
## forecast counts the same turns, old saves keep the old cost, saves validate the flag.
const Campaign = preload("res://redesign/campaign.gd")
const Model = preload("res://redesign/model.gd")
const Content = preload("res://redesign/content.gd")
const Forecast = preload("res://redesign/forecast.gd")
const Overheat = preload("res://redesign/overheat_cost.gd")
var checks := 0
var failures: Array = []

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(label); print("FAIL: " + label)
	return ok

func first_combat(gun: String):
	var c = Campaign.new()
	c.start(gun, 731042, 0, "balanced", Campaign.Content.RouteMap.VERSION, "carrier", true)
	while c.departure_pending(): c.advance_departure(true)
	c.enter(int(c.choices()[0].id))
	return c

## Fire one round from just under the heat limit; returns the fire record and turns used.
func overheat_shot(m) -> Dictionary:
	m.s.heat = Content.heat_limit(m.s) - 1
	for e in m.s.enemies: e.hp = 999; e.max_hp = 999
	if m.FireHeatTrial.enabled(m.s): m.s.fire_heat_trial.rounds = 1
	var hot: String = ""
	for id in m.s.magazine:
		if Content.AMMO[id].heat >= 1: hot = str(id); break
	if not hot.is_empty():
		m.s.magazine.erase(hot); m.s.magazine.push_front(hot)
	var forecast: Dictionary = Forecast.analyze(m.s, true)
	var before := int(m.s.turns)
	m.fire()
	var detail: Dictionary = m.s.history.back().detail
	return {"detail": detail, "turns": int(m.s.turns) - before, "forecast": forecast}

func run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/"): quit(2); return
	for gun in ["single", "burst", "heavy"]:
		var c = first_combat(gun)
		var m = c.model
		check(Overheat.enabled(m.s), "new %s run carries the overheat cost" % gun)
		var expected_extra := 1 if gun == "heavy" else 2
		check(Overheat.extra(m.s) == expected_extra, "%s extra = %d" % [gun, expected_extra])
		var shot := overheat_shot(m)
		var cooling: Dictionary = shot.detail.get("forced_cooling", {})
		var overdrive := 1 if shot.detail.get("overdrive", false) else 0
		if check(not cooling.is_empty(), "%s overheat forces cooling" % gun):
			check(int(cooling.cost) == m.base_reload_cost() + 1 + overdrive + expected_extra, "%s forced cooling = reload %d + 1 + %d (cost %d)" % [gun, m.base_reload_cost(), expected_extra, int(cooling.cost)])
		var predicted := int(shot.forecast.get("turns", -1))
		print("TURNS %s actual %d forecast %d" % [gun, shot.turns, predicted])
		check(predicted == shot.turns, "%s fire forecast counts the overheat turns (%d)" % [gun, shot.turns])
		# The same shot without the flag: the old cost.
		var old = first_combat(gun)
		old.model.s.erase("overheat_version")
		var plain := overheat_shot(old.model)
		var plain_cooling: Dictionary = plain.detail.get("forced_cooling", {})
		var plain_overdrive := 1 if plain.detail.get("overdrive", false) else 0
		check(not plain_cooling.is_empty() and int(plain_cooling.cost) == old.model.base_reload_cost() + 1 + plain_overdrive, "%s without the flag keeps reload + 1" % gun)
		# Voluntary cooling is still one enemy action.
		var cool = first_combat(gun)
		cool.model.s.heat = 3
		var before := int(cool.model.s.turns)
		check(cool.model.cool_magazine() and int(cool.model.s.turns) - before == 1, "%s voluntary cooling costs 1" % gun)
		# Saves.
		var back = Model.new()
		check(back.restore_state(JSON.parse_string(cool.model.serialized_state())) and Overheat.enabled(back.s), "%s flag survives save" % gun)
	var broken: Dictionary = JSON.parse_string(first_combat("single").model.serialized_state())
	broken.overheat_version = 2
	check(not Model.new().restore_state(broken), "unknown overheat version rejected")
	broken.overheat_version = 1.5
	check(not Model.new().restore_state(broken), "fractional overheat version rejected")
	print("OVERHEAT COST RULES checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
