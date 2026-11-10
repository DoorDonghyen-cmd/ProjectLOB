extends "res://tests/playtest_revision_ui_runner.gd"

func prepare(ids: Array, gun: String, heat: int = 0, legacy: bool = false) -> void:
	screen.campaign = Campaign.new()
	screen.campaign.start(gun,731042,0,"balanced",3,"carrier")
	screen.campaign.enter(int(screen.campaign.choices()[0].id))
	screen.model = screen.campaign.model
	screen.model.s.deck = ids.duplicate()
	while screen.model.s.deck.size() < 10: screen.model.s.deck.append("pierce")
	screen.model.begin_encounter()
	screen.model.s.hand = ids.duplicate();screen.model.s.draw = screen.model.s.deck.duplicate()
	for id in ids: screen.model.s.draw.erase(id)
	screen.page = "run";screen.debug_session = true;screen.hand_layout_key = ""
	screen.model.s.heat = heat
	screen.model.s.sustained_version = 0 if legacy else 1
	screen.campaign.s.sustained_version = 0 if legacy else 1
	screen.model.s.sustained_attacks = 0
	screen.model.s.enemies = [Data._enemy(["wall",200,0,1,80])]
	screen.model.s.encounter_total = 1;screen.model.s.deployed = 1
	screen.model.assign_opening_lanes()
	screen.redraw();await settle()
	for id in Ammo.loading_order(ids):
		for button in screen.find_children("load_*","Button",true,false):
			if not button.disabled and button.name.begins_with("load_"+str(id)):
				await tap(str(button.name));break
	check(screen.model.s.plan.size() == ids.size(), "all rounds loaded using touch")
	check(not screen.main_scroll.get_h_scroll_bar().visible, "combat fits width")
	check(CombatModel.new().restore_state(screen.model.s), "render fixture is valid saved state")

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/playtest_revision_20261026/"):quit(2);return
	screen = load("res://redesign/main.tscn").instantiate()
	screen.save_enabled = false;screen.presentation_speed = 0.03
	root.add_child(screen);await settle()
	for resolution in [Vector2i(1008,630),Vector2i(1280,576),Vector2i(1280,800)]:
		root.size = resolution;await settle()
		var label := "%dx%d" % [resolution.x,resolution.y]
		var six: Array = ["basic_p2","basic_p2","basic_p2","basic_p2","basic_p2","basic_p2"]
		await prepare(six,"heavy")
		check(screen.magazine_view.sustained_note(2) == "연속 열 +1" and screen.magazine_view.sustained_note(4) == "연속 열 +2", "rail exposes heat tiers")
		check(screen.combat_forecast.heat.forced_cost_max == 4, "rail predicts Reactor forced reload")
		await capture("reactor_overheat_"+label)
		await tap("confirm");await tap("fire")
		check(screen.model.s.turns == 5 and screen.model.s.sustained_attacks == 0, "real touch fire pays forced reload and resets")
		check(screen.last_presentation.shown_enemies == screen.model.s.enemies, "animation ends at real result")
		await capture("reactor_cooled_"+label)
		six[5] = "cool"
		await prepare(six,"heavy")
		check(screen.magazine_view.sustained_note(5) == "연속 초기화" and screen.combat_forecast.heat.forced_cost_max == 0, "cooling alternative shows reset and avoids forced cost")
		await capture("cooling_choice_"+label)
		await tap("confirm");await tap("fire")
		check(screen.model.s.heat == 11 and screen.model.s.sustained_attacks == 0, "cooling shot is applied")
		await prepare(["basic_p2","basic_p2","basic_p2"],"amplifier")
		await tap("confirm");await tap("fire");await tap("fire")
		var gauge = screen.find_child("HeatGauge",true,false)
		check(gauge.sustained_note() == "연속 2 · 다음 공격 +1열", "separate Spike inputs show next heat")
		check(screen.magazine_view.sustained_note(0) == "연속 열 +1", "remaining Spike shot predicts new tier")
		var available: float = gauge.size.x - gauge.READING_LEFT - gauge.FONT.get_string_size(gauge.reading_text(),HORIZONTAL_ALIGNMENT_LEFT,-1,gauge.reading_font_size()).x - 46
		check(gauge.FONT.get_string_size(gauge.sustained_note(),HORIZONTAL_ALIGNMENT_LEFT,-1,16).x <= available, "gauge count fits narrow screen")
		await capture("spike_next_"+label)
		screen.model.s.gate_mods = {"thermal":1,"chain":1}
		screen.model.s.gate_charge = 6;screen.model.s.gate_chain = 2
		screen.redraw();await settle()
		gauge = screen.find_child("HeatGauge",true,false)
		available = gauge.size.x - gauge.READING_LEFT - gauge.FONT.get_string_size(gauge.reading_text(),HORIZONTAL_ALIGNMENT_LEFT,-1,gauge.reading_font_size()).x - 46
		check(gauge.sustained_note().contains(gauge.gate_note) and gauge.FONT.get_string_size(gauge.sustained_note(),HORIZONTAL_ALIGNMENT_LEFT,-1,16).x <= available, "streak and gate charge both remain visible")
		await capture("gate_and_streak_"+label)
		await tap("fire")
		check(screen.model.s.heat == 7 and screen.model.s.sustained_attacks == 3, "third Spike touch uses extra heat")
		await tap("hand_details")
		check(screen.find_children("*","Label",true,false).any(func(node):return node.text.contains("연속 공격 1~2발")), "ammo details explain tiers and reset")
		check(screen.find_children("*","Label",true,false).any(func(node):return node.text.begins_with("기본 발열")), "ammo details identify base heat")
		check(screen.find_children("*","Label",true,false).any(func(node):return node.text.contains("이번 전투에 돌아오지 않으며") and not node.text.contains("다시 섞습니다")), "finite ammo detail does not promise a reshuffle")
		await capture("ammo_detail_"+label)
		await tap("workspace_close")
		await prepare(["basic_p2","basic_p2","basic_p2","basic_p2"],"burst",8)
		check(screen.combat_forecast.heat.fired_max == 3, "early stop predicts one unfired round")
		await capture("stopped_round_"+label)
		await tap("confirm");await tap("fire")
		check(screen.model.s.shots == 3 and screen.model.s.sustained_attacks == 0, "unfired fourth card is not counted")
		await prepare(["basic_p2","basic_p2","basic_p2"],"scatter")
		check(screen.magazine_view.sustained_note(2) == "연속 열 +1", "worker scatter forecast shows extra heat")
		await prepare(["basic_p2","basic_p2","basic_p2"],"heavy",0,true)
		check(screen.magazine_view.sustained_note(2).is_empty() and screen.find_child("HeatGauge",true,false).sustained_note().is_empty(), "legacy UI hides inactive rule")
		await capture("legacy_"+label)
	print("PLAYTEST REVISION SUSTAINED UI COMPLETE checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
