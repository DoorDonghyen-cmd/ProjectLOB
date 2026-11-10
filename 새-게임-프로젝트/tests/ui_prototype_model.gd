extends SceneTree
## Local HTML adapter. All combat commands and predictions use the real model.
## The HTTP server owns the isolated state; this runner never opens a user save.
const Model = preload("res://redesign/model.gd")
const Content = preload("res://redesign/content.gd")
const Forecast = preload("res://redesign/forecast.gd")
const CampaignContent = preload("res://redesign/campaign_content.gd")
const HandFace = preload("res://redesign/ammo_hand_face.gd")

func _initialize() -> void:
	var input_path := OS.get_environment("LOB_UI_REQUEST")
	var output_path := OS.get_environment("LOB_UI_RESPONSE")
	if not "/qa_runtime/ui_prototype_model/" in input_path.replace("\\", "/") or not "/qa_runtime/ui_prototype_model/" in output_path.replace("\\", "/"):
		quit(2); return
	var request: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(input_path))
	var response := execute(request)
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(response))
	file.close()
	quit(0 if response.get("ok", false) else 1)

func execute(request: Dictionary) -> Dictionary:
	var model = Model.new()
	var action := str(request.get("action", ""))
	if action == "new":
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("LOB_UI_DATA")))
		var deck: Array = request.get("deck", [])
		var parts: Array = request.get("parts", [])
		if deck.is_empty() or deck.size() > 40 or parts.size() > 5: return {"ok":false, "error":"빌드 범위를 확인하세요."}
		for id in deck:
			if not Content.AMMO.has(id): return {"ok":false, "error":"알 수 없는 탄환입니다."}
		for id in parts:
			if not Content.PARTS.has(id): return {"ok":false, "error":"알 수 없는 파츠입니다."}
		model.start("single", int(request.get("seed", 731042)))
		model.s.merge({"reserve_version":1, "inventory_version":1, "emergency_version":1, "magazine_trial_version":1, "weapon_magazine_version":1, "deck":deck, "equipped_parts":parts}, true)
		model.begin_encounter(0)
		var kind := str(request.get("kind", "combat"))
		if kind == "elite":
			model.s.enemies = data.combat.enemies.duplicate(true)
			model.s.reinforcements = data.combat.reinforcements.duplicate(true)
		else:
			# Preserve the reviewed mockup's encounter composition and tuning.
			var rows := [["runner",4,0,2,16,{"species":"slum_thief","name":"길목 도둑"}], ["evader",5,0,1,21,{"species":"slum_battery","name":"전지 약탈자"}], ["runner",4,0,2,25,{"species":"slum_thief","name":"길목 도둑"}]]
			if kind == "boss": rows = [["wall",12,3,1,15,{"species":"slum_plate","name":"철판 방패병"}], ["wall",20,1,1,18,{"species":"slum_leader","name":"약탈단 두목","rank":"boss","charge":0,"charge_max":3,"charge_pull":1}], ["runner",6,0,1,24,{"species":"slum_gunner","name":"길목 사수"}]]
			model.s.enemies = rows.map(func(row): return CampaignContent._enemy(row))
		model.assign_opening_lanes()
		model.s.encounter_total = model.s.enemies.size() + model.s.reinforcements.size()
		model.s.deployed = model.s.enemies.size()
		if not model.trial_load_magazine(): return {"ok":false, "error":"탄창을 채울 수 없습니다."}
	else:
		# Input comes only from this server's previous real-model output.
		model.s = request.get("state", {}).duplicate(true)
		if model.s.is_empty(): return {"ok":false, "error":"전투가 만료되었습니다. 다시 시작하세요."}
		if action == "reload" and model.s.draw.is_empty() and model.s.hand.is_empty(): return {"ok":false, "error":"교체할 예비 탄이 없습니다."}
		var accepted := false
		match action:
			"fire": accepted = model.fire()
			"cool": accepted = model.cool_magazine()
			"reload": accepted = model.reload_magazine()
			"emergency": accepted = model.emergency_resupply()
			"eject", "preview": accepted = model.eject_magazine_rounds(request.get("indices", []))
		if not accepted: return {"ok":false, "error":"현재 상태에서는 실행할 수 없습니다."}
	var detail: Dictionary = model.s.history.back().get("detail", {}) if action == "fire" else {}
	return {"ok":true, "state":model.s, "view":snapshot(model), "shots":detail.get("results", []), "overheat":detail.get("overheated", false)}

func snapshot(model) -> Dictionary:
	var state: Dictionary = model.s
	var active: bool = state.phase == "ready"
	var forecast: Dictionary = Forecast.analyze(state, true) if active and not state.magazine.is_empty() else {}
	var actions := {}
	for command in ["cool", "reload", "emergency"]:
		var copy = Model.new()
		copy.s = Model.simulation_state(state)
		var valid: bool = copy.cool_magazine() if command == "cool" else copy.emergency_resupply() if command == "emergency" else copy.reload_magazine()
		actions[command] = {"valid":valid, "cost":int(copy.s.turns)-int(state.turns), "heat":copy.s.heat, "lose":copy.s.phase == "lost", "win":copy.s.phase in ["won","reward"]}
	# Empty reserve cannot be rerolled for a fresh ejection allowance.
	if state.draw.is_empty() and state.hand.is_empty(): actions.reload.valid = false
	var ammo := {}
	for id in state.deck + state.magazine + [Model.Reserve.EMERGENCY_ROUND]:
		var stat: Dictionary = Content.primary_stat(id, state)
		ammo[id] = {"stat_label":stat.label, "stat_value":stat.value, "heat_label":Content.heat_label(id,state), "secondary":HandFace.secondary(id,state), "slots":Content.slot_cost(id), "anchor":Content.anchor(id), "pen":Content.penetration(id,state)}
	return {"magazine":state.magazine, "draw":state.draw + state.hand, "used":state.discard, "heat":state.heat, "actions":state.turns, "enemies":state.enemies, "reserve":state.reinforcements, "phase":state.phase, "loss_reason":state.get("loss_reason",""), "capacity":model.capacity(), "heat_limit":Content.heat_limit(state), "eject_left":model.ejection_remaining(), "emergency":model.can_emergency_resupply(), "emergency_cost":model.emergency_cost(), "forecast":forecast, "commands":actions, "ammo":ammo}
