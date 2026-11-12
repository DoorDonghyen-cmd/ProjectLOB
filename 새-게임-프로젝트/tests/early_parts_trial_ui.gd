extends "res://tests/campaign_magazine_ui.gd"

const Preview = preload("res://redesign/samples/opening_build/early_parts_trial.tscn")
const Trial = preload("res://redesign/samples/opening_build/early_parts_campaign.gd")
const Forecast = preload("res://redesign/forecast.gd")
const ACTIONS := {"single": [2, 2], "burst": [2], "heavy": [3, "Cool", 1]}

func choose_mode(preview: Control, id: String) -> void:
	var choice := preview.find_child(id, true, false) as Button
	if not check(choice != null and choice.is_visible_in_tree(), "comparison choice is visible " + id): return
	var point := choice.get_global_transform_with_canvas() * (choice.size * 0.5)
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.position = point
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
	await settle()

func run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/"):
		quit(2)
		return
	output = OS.get_environment("QA_OUTPUT_DIR")
	Input.emulate_mouse_from_touch = true
	root.content_scale_size = Vector2i.ZERO
	var preview := Preview.instantiate()
	root.add_child(preview)
	for extent in [Vector2i(1280, 800), Vector2i(1170, 540), Vector2i(1008, 454)]:
		root.size = extent
		await settle()
		var suffix := "%dx%d" % [extent.x, extent.y]
		await capture("chooser_" + suffix)
		for gun: String in Trial.FIRST_PARTS:
			var part: String = Trial.FIRST_PARTS[gun]
			var control := Trial.new()
			if not check(control.prepare_checkpoint(gun), "real control checkpoint " + gun): continue
			var reward_deck: Array = control.model.s.deck.duplicate()
			var offers: Array = control.reward_options()
			for enabled in [false, true]:
				await choose_mode(preview, gun + ("_trial" if enabled else "_current"))
				host = preview.game
				if not check(is_instance_valid(host), "comparison opens the real game " + gun): continue
				var run: Trial = host.campaign
				check(not host.save_enabled and host.debug_session, "isolated player progress " + gun)
				check(int(run.s.clears) == 2 and run.s.phase == "reward" and run.model.s.deck == reward_deck, "same earned second victory " + gun)
				check(run.reward_options() == offers and run.part_rewards() == ([part] if enabled else []), "normal offers plus only the trial part " + gun)
				check(host.find_child("Credits", true, false).is_visible_in_tree(), "credits stay selectable " + gun)
				if enabled:
					if gun == "single" and extent == Vector2i(1008, 454):
						await tap("city_reward_trim")
						await tap("Confirm")
						await tap("Skip")
					var offer := host.find_child("city_reward_" + part, true, false) as Button
					if check(offer != null, "part is rendered " + gun):
						var shelf := offer.get_parent().get_parent() as ScrollContainer
						check(shelf.get_global_rect().encloses(offer.get_global_rect()), "part is visible before scrolling " + gun)
					await tap("city_reward_" + part)
					check(host.find_child("Confirm", true, false).text == "파츠 회수", "part uses the standard reward action " + gun)
					await capture("reward_" + gun + "_" + suffix)
					await tap("Confirm")
				else:
					check(host.find_child("city_reward_" + part, true, false) == null, "control keeps the existing reward " + gun)
					await capture("current_" + gun + "_" + suffix)
					await tap("Skip")
				check(run.s.phase == "map" and run.equipped_parts() == ([part] if enabled else []), "chosen part is really equipped " + gun)
				check(run.model.s.deck == reward_deck and not run.reward(part), "deck unchanged and no duplicate claim " + gun)
				var node_id := run.next_normal_encounter()
				await tap("map_node_%d" % node_id)
				await tap("city_enter_%d" % node_id)
				if check(is_instance_valid(host.campaign_hud), "real next combat " + gun):
					check(int(host.model.s.encounter_id) == node_id and host.model.s.equipped_parts == run.equipped_parts(), "actual combat uses the chosen loadout " + gun)
					await capture("combat_" + gun + ("_trial_" if enabled else "_current_") + suffix)
					if extent == Vector2i(1280, 800): await play_first_actions(gun, part, enabled)
				await return_to_chooser(preview)
		if extent != Vector2i(1170, 540): await play_investments(preview, suffix)
	check(not FileAccess.file_exists(Campaign.SAVE), "trial leaves the campaign save alone")
	preview.free()
	print("EARLY PARTS TRIAL UI checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func play_first_actions(gun: String, part: String, enabled: bool) -> void:
	var history: int = host.model.s.history.size()
	for move in ACTIONS[gun]:
		var hud: Control = host.campaign_hud
		if not is_instance_valid(hud): break
		hud.board.speed_scale = 0.01
		if move is int:
			hud.select_budget(move, false)
			await tap("Fire")
		else:
			await tap(move)
	var found := false
	for event in host.model.s.history.slice(history):
		if event.action != "fire": continue
		for shot in event.detail.results:
			if shot.get("part_effects", []).any(func(effect): return str(effect.id) == part): found = true
	check(found == enabled, "the expected part fires on the real HUD " + gun)

func return_to_chooser(preview: Control) -> void:
	var back := InputEventKey.new()
	back.keycode = KEY_F8
	back.pressed = true
	root.push_input(back)
	await settle()
	check(preview.chooser.visible and not is_instance_valid(preview.game), "F8 returns to comparison")

func play_investments(preview: Control, suffix: String) -> void:
	var checkpoint: Dictionary = {}
	for choice in ["Keep", "Upgrade", "Buy"]:
		await choose_mode(preview, "Investment")
		if not check(is_instance_valid(preview.shop_menu) and preview.shop_run != null, "earned second-region shop opens"): return
		var balance := int(preview.shop_run.s.credits)
		if choice == "Keep":
			checkpoint = preview.shop_run.s.duplicate(true)
			await capture("investment_" + suffix)
		check(preview.shop_run.s == checkpoint, "all investments open the same earned shop state")
		var extra_id: String = str(preview.shop_plan.purchase)
		var price := int(preview.shop_run.s.offers[preview._shop_offer()].price) if choice == "Buy" else Trial.StrikerUpgrade.PRICE if choice == "Upgrade" else 0
		await choose_mode(preview, choice)
		host = preview.game
		if not check(is_instance_valid(host) and is_instance_valid(host.campaign_hud), "checkout enters the same real combat"): return
		check(int(host.campaign.s.credits) == balance - price, "only the chosen price is charged " + choice)
		check(Trial.StrikerUpgrade.upgraded(host.model.s) == (choice == "Upgrade"), "only the chosen upgrade is applied")
		check(host.campaign.equipped_parts().has(extra_id) == (choice == "Buy"), "native buy equips the actual extra part")
		var combo: Label = host.find_child("ComboLine", true, false)
		check(combo.text.contains("×3.5" if choice == "Upgrade" else "×3"), "battle HUD shows the correct third-shot value")
		await capture("investment_combat_" + choice.to_lower() + "_" + suffix)
		if choice == "Upgrade" and suffix == "1280x800":
			var hud: Control = host.campaign_hud
			hud.board.speed_scale = 0.01
			await tap("Reload")
			hud.select_budget(3, false)
			var forecast: Dictionary = Forecast.analyze(host.model.s, true)
			await tap("Fire")
			var shots: Array = host.model.s.history.back().detail.results
			check(shots.size() == 3 and float(shots[2].get("part_factor", 1)) == 3.5, "actual third shot uses ×3.5")
			check(forecast.shots.size() == 3 and int(forecast.shots[2].get("damage", -1)) == int(shots[2].damage), "forecast matches the actual third shot")
		await return_to_chooser(preview)
