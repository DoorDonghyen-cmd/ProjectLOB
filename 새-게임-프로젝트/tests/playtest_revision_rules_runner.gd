extends "res://tests/ammo_expansion_rules_runner.gd"
const Worker = preload("res://redesign/forecast_worker.gd")

func without_history(state: Dictionary) -> Dictionary:
	var copy := state.duplicate(false)
	copy.erase("history")
	return copy

func check_commands(state: Dictionary, label: String) -> void:
	var original := JSON.stringify(state)
	var full = Model.new(); full.s = state.duplicate(true)
	var small = Model.new(); small.s = Model.simulation_state(state)
	check(full._recent_part_rounds()==small._recent_part_rounds(),"same partial-magazine history "+label)
	var forecast := Forecast.analyze(state,true,true)
	if full.s.phase=="plan":check(full.confirm()==small.confirm(),"same confirm "+label)
	for step in 5:
		var full_fired: bool = full.fire()
		check(full_fired==small.fire(),"same accepted fire "+label)
		check(without_history(full.s)==without_history(small.s),"identical command state/RNG "+label)
		if not full_fired:break
		check(full.s.history.back()==small.s.history.back(),"same complete receipt "+label)
		if step==0 and state.gun!="scatter":
			check(forecast.enemies==full.s.enemies and forecast.projectiles==full.s.projectiles,"forecast matches live fire "+label)
	check(full.reload_magazine()==small.reload_magazine(),"same accepted reload "+label)
	check(without_history(full.s)==without_history(small.s),"same reload, supply, heat and RNG "+label)
	check(JSON.stringify(state)==original,"full player history and state retained "+label)

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/playtest_revision_20261026/"):quit(2);return
	var path := ProjectSettings.globalize_path("res://../qa_runtime/central_live/balance/final_731042/combat_burst_731042_r5_n41002.json")
	var past: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var campaign = Campaign.new()
	check(campaign.restore_state(past),"full earned campaign restores")
	var original_history := JSON.stringify(campaign.model.s.history)
	Forecast.analyze(campaign.model.s,true,true)
	check(campaign.save("user://history_roundtrip.json")==OK,"isolated campaign save succeeds")
	var restored_campaign = Campaign.new()
	check(restored_campaign.restore("user://history_roundtrip.json"),"saved campaign restores")
	check(JSON.stringify(restored_campaign.model.s.history)==original_history,"complete run history retained across disk save")
	for gun in Ammo.GUNS:
		for parts in [["volley_drive","duplex","ordinary_chain","chain_sink"],["thermal_drive","reclaimer","sequencer"],["siege_drive","opening","afterburner"]]:
			var m = fixture(["charge","precise","basic","pierce","cool"],[["runner",1,0,1,40],["wall",200,3,1,50]],gun)
			m.s.equipped_parts = parts.duplicate()
			var current: Array = m.s.history
			m.s.history = past.combat.history.duplicate(true)
			m.s.history.append_array(current)
			for id in Ammo.loading_order(["basic","pierce","precise"]):m.load_round(id)
			check_commands(m.s,gun+str(parts))
			m.confirm();m.fire()
			check_commands(m.s,gun+" after partial or heat stop")
	# A compact simulation must have no aliases into the live save, including
	# nested arrays, current-magazine receipts, engine progress and future enemies.
	var m = fixture(["basic","pierce"],[],"scatter")
	m.confirm()
	var unchanged := JSON.stringify(m.s)
	var detached := Model.simulation_state(m.s)
	detached.enemies[0].hp=1
	detached.history.back().detail.clear()
	detached.hand.append("basic")
	check(unchanged==JSON.stringify(m.s),"nested snapshot mutations isolated")
	var worker = Worker.new();root.add_child(worker)
	var first = fixture(["charge","precise","pierce","basic","cool"],[],"scatter")
	for id in first.s.hand.duplicate():first.load_round(id)
	worker.request(first.s)
	var second = fixture(["pierce","basic"],[],"scatter")
	for id in second.s.hand.duplicate():second.load_round(id)
	worker.request(second.s)
	var deadline := Time.get_ticks_msec()+15000
	while worker.ready_key!=worker.wanted_key and Time.get_ticks_msec()<deadline:await process_frame
	check(worker.ready_key==worker.wanted_key,"replacement worker request finishes")
	check(worker.request(second.s)==Forecast.analyze(second.s,true,true),"worker returns latest exact forecast")
	worker.queue_free();await process_frame
	print("PLAYTEST REVISION RULES COMPLETE checks=%d failures=%d"%[checks,failures])
	quit(1 if failures else 0)
