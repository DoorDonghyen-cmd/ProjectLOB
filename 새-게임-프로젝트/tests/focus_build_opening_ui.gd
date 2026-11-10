extends "res://tests/campaign_magazine_ui.gd"

const Preview = preload("res://redesign/samples/opening_build/preview.tscn")
const Opening = preload("res://tests/focus_build_opening.gd")
const Solver = preload("res://tests/fire_control_solver.gd")

func play_battle() -> void:
	var path := Solver.new().solve(host.model)
	check(not path.is_empty(), "legal first battle route")
	for step in path:
		var hud: Control = host.campaign_hud
		hud.board.speed_scale = 0.01
		var action := str(step.action)
		if action == "fire":
			var rounds := int(step.get("rounds", 0))
			hud.select_budget(rounds if rounds > 0 else hud.maximum_budget())
		if action == "eject":
			for index in step.indices: await tap("Select%d" % int(index))
			await tap("EjectToggle")
		else:
			await tap({"fire":"Fire", "cool":"Cool", "reload":"Reload", "emergency":"Reload"}[action])
	check(host.campaign.s.phase == "reward", "touch-played win opens the earned reward")

func run() -> void:
	output = OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\", "/").contains("/qa_runtime/opening_build_20261108/"): quit(2); return
	var preview := Preview.instantiate()
	root.add_child(preview)
	await settle()
	await capture("comparison_menu")
	var first_state: Dictionary = {}
	for option in range(4):
		var uses_parts := option > 0
		var start: Button = preview.find_child(["CoreStart", "PartsStart", "SupportStart", "FollowUpStart"][option], true, false)
		start.pressed.emit()
		host = preview.game
		await settle()
		check(not host.save_enabled and host.debug_session, "preview avoids main profile writes")
		var initial: Dictionary = canonical(host.model.s)
		if uses_parts: check(initial == first_state, "same initial combat model in A and B")
		else: first_state = initial
		check(host._campaign_action("enter", Opening.first_choice(host.campaign)), "actual first node is available")
		await settle()
		await play_battle()
		var name: String = ["A_core", "B_parts", "C_parts", "D_parts"][option]
		var section: Label = host.find_child("Section", true, false)
		check(section.text.begins_with("첫 파츠" if uses_parts else "성장 코어"), "accurate live reward label " + name)
		await capture(name)
		if option == 1:
			root.size = Vector2i(844, 390)
			await settle()
			await capture("B_parts_844")
		var part := "sequencer" if uses_parts else "volley_drive"
		await tap("city_reward_" + part)
		await tap("Confirm")
		check(host.campaign.equipped_parts() == [part] and host.campaign.first_ammo_reward(), "real reward equips starter and opens the package " + name)
		await tap("city_reward_precise_p2")
		await tap("Confirm")
		check(host.campaign.s.phase == "map" and host.model.s.deck.count("precise_p2") == 2 and host.model.s.deck.has("charge"), "same package after both starters")
		if option >= 2:
			check(host._campaign_action("enter", Opening.first_choice(host.campaign)), "enters same second combat")
			await settle()
			check(host.model.s.magazine.has("charge") and host.model.s.magazine.has("precise_p2"), "support and main round appear in live magazine")
			await capture(name + "_magazine")
		if option == 3:
			await play_battle()
			section = host.find_child("Section", true, false)
			check(section.text == "전투 보상 · 1개 선택", "mixed reward communicates single choice")
			check(host.find_child("Credits", true, false).is_visible_in_tree(), "credit remains an alternative to part or ammunition")
			await capture("D_second_reward_844")
			await tap("city_reward_radiator")
			root.size = Vector2i(1280, 800)
			await settle()
			await capture("D_second_reward")
			await tap("Confirm")
			check(host.campaign.s.phase == "map" and host.campaign.equipped_parts().has("radiator"), "follow-up part works through actual reward UI")
		var reset := InputEventKey.new()
		reset.keycode = KEY_F8
		reset.pressed = true
		root.push_input(reset)
		await settle()
		check(preview.chooser.visible and not is_instance_valid(preview.game), "F8 opens A/B comparison again")
	check(not FileAccess.file_exists(Campaign.SAVE), "no run saved in comparison")
	preview.free()
	print("FOCUS BUILD COMPLETE checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
