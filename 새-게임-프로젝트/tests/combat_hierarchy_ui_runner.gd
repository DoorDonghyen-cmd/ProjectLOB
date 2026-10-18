extends "res://tests/ammo_cycle_ui_runner.gd"

func refresh() -> void:
	screen.redraw()
	await settle()

func layout_snapshot() -> Dictionary:
	var result := {}
	for key in ["BattleView", "FiringRailHeader", "FiringRail", "ThermalOutcome", "CandidatesPanel", "AmmoGrid"]:
		result[key] = screen.find_child(key, true, false).get_global_rect()
	return result

func aligned_rail() -> void:
	var panel = screen.find_child("QueuePanel",true,false)
	var surface = panel.get_node("CombatSurface")
	var shelf: Rect2 = surface.header_shelf_rect()
	shelf.position += surface.global_position
	for key in ["slot_previous","slot_next","remove_selected","inspect_slots"]:
		var edit = screen.find_child(key,true,false)
		if edit.is_visible_in_tree():
			check(shelf.grow(-2).encloses(edit.get_global_rect()), "header shelf contains editing button with inset: " + key)
	var action = screen.find_child("confirm",true,false)
	if action == null: action = screen.find_child("fire",true,false)
	var cards: Rect2 = screen.magazine_view.get_global_rect().grow(-3)
	var button: Rect2 = action.get_global_rect()
	check(absf(cards.position.y-button.position.y) <= 1, "action and cartridge top edges align")
	check(absf(cards.end.y-button.end.y) <= 1, "action and cartridge bottom edges align")

func stable_layout(before: Dictionary, context: String) -> void:
	aligned_rail()
	for key in before:
		var after: Rect2 = screen.find_child(key, true, false).get_global_rect()
		var previous: Rect2 = before[key]
		check(absf(after.position.y - previous.position.y) <= 1.0 and absf(after.size.y - previous.size.y) <= 1.0, "%s stable %s before=%s after=%s" % [context, key, previous, after])
	fit()

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/combat_hierarchy/ui"):
		quit(1)
		return
	screen = load("res://redesign/main.tscn").instantiate()
	screen.save_enabled = false
	screen.presentation_speed = 0.02
	root.add_child(screen)
	await settle()
	for resolution in [Vector2i(1008, 630), Vector2i(1280, 900), Vector2i(1440, 630)]:
		root.size = resolution
		await setup_hand(["basic", "charge_hot", "cool", "pierce", "push"])
		fit()
		bounds("HeatGauge")
		bounds("reload")
		check(screen.find_child("HeatGauge", true, false).size.y >= 68, "large thermal decision strip")
		check(not screen.find_child("EditActions", true, false).visible, "no edits for empty magazine")
		check(not screen.find_child("ForecastLabel", true, false).visible, "no empty forecast panel")
		for removed in ["EncounterLesson", "ReserveAmmo", "CombatMetrics", "ConfirmCost", "undo"]:
			check(screen.find_child(removed, true, false) == null, "remove persistent clutter " + removed)
		check(screen.find_child("ReinforcementCount", true, false) == null, "zero reinforcements hidden")
		await capture("empty_%d" % resolution.x)
		await tap("ammo_bag")
		await tap("bag_tab_draw")
		check(screen.workspace_overlay.find_children("reserve_bag_next_*", "PanelContainer", true, false).size() == 2, "known next two cards remain accessible")
		await tap("workspace_close")
		var empty_layout := layout_snapshot()
		await tap("load_basic")
		stable_layout(empty_layout, "first load")
		await capture("first_load_%d" % resolution.x)
		check(screen.find_child("EditActions", true, false).visible and screen.find_child("ForecastLabel", true, false).visible, "selected card reveals editing and results")
		await tap("remove_selected")
		check(screen.model.s.plan.is_empty(), "contextual removal works")
		stable_layout(empty_layout, "remove last")
		screen.model.s.gun = "burst"
		screen.campaign.s.gun = "burst"
		screen.model.s.heat = 11
		await refresh()
		var reload_button: Button = screen.find_child("reload", true, false)
		check(reload_button.text.contains("11 → 2") and reload_button.text.contains("2턴") and reload_button.text.contains("냉각 9"), "actual cooling and enemy time visible before reload")
		var before_turns: int = screen.model.s.turns
		await capture("cooling_%d" % resolution.x)
		await tap("reload")
		check(screen.model.s.heat == 2 and screen.model.s.turns == before_turns + 2, "button matches actual cooling and elapsed turns")
		await setup_hand(["basic", "charge_hot", "cool", "pierce", "push"])
		screen.model.s.gun = "burst"
		screen.campaign.s.gun = "burst"
		screen.model.s.heat = 12
		await refresh()
		var hot_empty_layout := layout_snapshot()
		await tap("load_basic")
		await tap("load_charge_hot")
		stable_layout(hot_empty_layout, "overheat load")
		var heat: Dictionary = screen.combat_forecast.heat
		check(heat.forced_probability == 1.0 and heat.fired_max == 1, "fixture interrupts before second bullet")
		check(screen.find_child("OverheatWarning", true, false).text.contains("3턴"), "forced cost near primary action")
		check(screen.find_child("HeatGauge", true, false).prediction.peak_max >= 14, "peak shown before forced cooling resets it")
		check(screen.magazine_view.forecast.heat.overheat_probability == 1.0, "rail carries overheat markers and unfired slots")
		fit()
		await capture("overheat_plan_%d" % resolution.x)
		await tap("confirm")
		stable_layout(hot_empty_layout, "confirm")
		check(not screen.find_child("EditActions", true, false).visible, "confirmed magazine hides edit buttons")
		bounds("fire")
		bounds("OverheatWarning")
		await capture("overheat_ready_%d" % resolution.x)
		await tap("fire")
		check(screen.model.s.phase == "plan" and screen.model.s.heat == 0 and screen.model.s.history.back().detail.forced_reload.cost == 3, "forced reload actual result agrees")
		stable_layout(hot_empty_layout, "after forced reload")
		await capture("after_overheat_%d" % resolution.x)
		# Random target + kill cooling yields a genuine conditional overheat.
		await setup_hand(["basic", "basic", "cool", "pierce", "push"])
		screen.model.s.gun = "scatter"
		screen.campaign.s.gun = "scatter"
		screen.model.s.equipped_parts = ["reclaimer"]
		screen.model.s.enemies = [Data._enemy(["runner", 1, 0, 1, 24]), Data._enemy(["wall", 90, 0, 1, 26])]
		screen.model.s.encounter_total = 2
		screen.model.s.deployed = 2
		screen.model.assign_opening_lanes()
		screen.model.s.heat = 15
		await refresh()
		await tap("load_basic")
		await tap("load_basic_2")
		var chance: float = screen.combat_forecast.heat.overheat_probability
		check(chance > 0 and chance < 1, "uncertain overheat branch")
		check(screen.find_child("OverheatWarning", true, false).text.contains("가능") and screen.find_child("OverheatWarning", true, false).text.contains("%"), "random risk never presented as certainty")
		fit()
		await capture("random_%d" % resolution.x)
		# Terminal overheat must not promise a reload that never happens.
		await setup_hand(["basic", "charge_hot", "cool", "pierce", "push"])
		screen.model.s.enemies[0].hp = 1
		screen.model.s.heat = 11
		await refresh()
		await tap("load_basic")
		check(screen.combat_forecast.heat.overheat_probability == 1 and screen.combat_forecast.heat.forced_probability == 0, "terminal overheat has no reload")
		check(screen.find_child("OverheatWarning", true, false).text.contains("재장전 없음"), "terminal outcome described correctly")
		# A dangerous voluntary reload is marked even with an empty magazine.
		await setup_hand(["basic", "charge_hot", "cool", "pierce", "push"])
		screen.model.s.enemies[0].distance = 1
		await refresh()
		check(screen.find_child("reload", true, false).text.contains("접촉 위험"), "reload contact risk visible without a planned shot")
		bounds("reload")
		var risk_button := screen.find_child("reload",true,false) as Button
		check(risk_button.get_theme_stylebox("normal") is StyleBoxTexture,"risk reload keeps shared skin")
		check(absf(risk_button.size.x-screen.find_child("confirm",true,false).size.x) <= 1,"risk text preserves action alignment")
		check(risk_button.get_theme_font("font").get_height(risk_button.get_theme_font_size("font_size"))*risk_button.text.split("\n").size()+8 <= risk_button.size.y,"reload warning fits its button")
		await capture("reload_risk_%d" % resolution.x)
		# Multi-action single-shot weapon adds a scope control to the result row.
		await setup_hand(["basic", "basic", "charge_hot", "pierce", "push"])
		screen.model.s.gun = "amplifier"
		screen.campaign.s.gun = "amplifier"
		screen.model.s.heat = 8
		await refresh()
		await tap("load_charge_hot")
		await tap("load_basic")
		await tap("load_basic_2")
		bounds("forecast_scope")
		var scope_layout := layout_snapshot()
		await tap("forecast_scope")
		stable_layout(scope_layout, "switch scope")
		check(screen.find_child("OverheatWarning", true, false).visible, "full multi-action preview reveals later overheat")
		await capture("amplifier_full_%d" % resolution.x)
		await tap("forecast_scope")
		check(not screen.find_child("OverheatWarning", true, false).visible, "next action does not inherit later overheat")
	check(not screen.save_enabled, "personal saves untouched")
	screen.queue_free()
	await process_frame
	print("COMBAT HIERARCHY UI COMPLETE checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
