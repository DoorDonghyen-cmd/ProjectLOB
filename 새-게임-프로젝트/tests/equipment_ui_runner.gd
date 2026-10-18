extends "res://tests/navigation_ui_runner.gd"
## Real touch selection, actual launch bindings, modal routing and viewport bounds.
func close_dialog() -> void:
	await touch("DialogClose")

func run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/equipment/"):
		quit(2)
		return
	output = OS.get_environment("QA_OUTPUT_DIR")
	# The path guard above makes fixture cleanup safe and the suite repeatable.
	if FileAccess.file_exists(Campaign.SAVE): DirAccess.remove_absolute(ProjectSettings.globalize_path(Campaign.SAVE))
	screen = load("res://redesign/main.tscn").instantiate()
	screen.save_enabled = false
	root.add_child(screen)
	await settle()
	for resolution in [Vector2i(1280, 800), Vector2i(1008, 630), Vector2i(1440, 630)]:
		root.size = resolution
		root.content_scale_size = resolution
		await settle()
		screen._to_menu()
		await settle()
		await touch("new_run_setup")
		check(screen.page == "loadout", "title enters equipment")
		for id in Content.GUNS:
			await touch("weapon_select_" + id)
			check(screen.selected_weapon_id == id, "touch selects gun " + id)
			bounds("start_" + id)
			bounds("SelectedWeaponPanel")
			check((screen.find_child("Heat", true, false) as Label).text.ends_with(str(Content.GUNS[id].heat_limit)), "gun heat binding")
			await touch("starting_deck")
			for ammo in Content.start_deck(id):
				var caption := screen.find_child("StartingRound_" + str(ammo), true, false) as Label
				check(caption != null and caption.text.ends_with("×%d" % Content.start_deck(id).count(ammo)), "deck matches actual gun")
			await close_dialog()
		for id in Content.OUTFITS:
			await touch("outfit_select_" + id)
			check(screen.selected_outfit_id == id, "touch selects outfit " + id)
			var atlas: AtlasTexture = screen.find_child("OutfitPortrait", true, false).texture
			check(atlas.atlas == screen.find_child("EquipmentScreen", true, false)._outfit_portrait(id).atlas, "outfit portrait changes")
			bounds("OutfitSelection")
			bounds("weapon_select_amplifier")
			await capture("equipment_%s_%s" % [resolution.x, id])
		await touch("preparation_options")
		screen.seed_input.text = "817263"
		screen.seed_input.text_changed.emit("817263")
		await close_dialog()
		await touch("weapon_select_burst")
		check(screen.preparation_seed == "817263" and screen.selected_outfit_id == Content.OUTFITS.keys()[-1], "gun changes preserve seed and outfit")
		check(not screen.main_scroll.get_v_scroll_bar().visible, "equipment fits " + str(resolution))
		check(not screen.main_scroll.get_h_scroll_bar().visible, "no horizontal scroll")
	# Launch every legal pair through the UI and inspect the actual campaign model.
	for gun in Content.GUNS:
		for outfit in Content.OUTFITS:
			screen._open_preparation(false)
			await settle()
			await touch("weapon_select_" + gun)
			await touch("outfit_select_" + outfit)
			await touch("start_" + gun)
			check(screen.page == "run" and screen.campaign.s.gun == gun, "launch selected gun")
			check(screen.campaign.s.outfit == outfit and screen.model.s.outfit == outfit, "launch selected outfit")
			check(Content.exchange_capacity(screen.model.s) == Content.OUTFITS[outfit].exchange, "outfit exchanges applied")
	# Unlocked supplies and difficulty remain available in the secondary layer.
	var saved = Campaign.new()
	saved.profile.unlocks = ["balanced", "amplify", "thermal", "voltage"]
	saved.profile.ascension = 3
	saved.start("burst", 9182)
	check(saved.save() == OK, "fixture stored only in isolated QA")
	screen._open_preparation(false)
	await settle()
	await touch("preparation_options")
	await touch("loadout_select_thermal")
	check(screen.selected_loadout_id == "thermal", "secondary supply selectable")
	screen.difficulty_option.value = 2
	await close_dialog()
	await touch("starting_deck")
	check(screen.find_child("StartingRound_bore", true, false) != null, "thermal deck rendered")
	await close_dialog()
	await touch("start_" + screen.selected_weapon_id)
	check(screen.find_child("NewRunConfirmation", true, false) != null, "existing run protected")
	await touch("DialogCancel")
	var preserved = Campaign.new()
	check(preserved.restore() and int(preserved.s.seed) == 9182, "cancel preserves save")
	await touch("start_" + screen.selected_weapon_id)
	await touch("DialogConfirm")
	check(screen.campaign.s.loadout == "thermal" and int(screen.campaign.s.difficulty) == 2, "confirmed launch applies supply and difficulty")
	# Large text / short logical landscape must not overlap action rows.
	root.size = Vector2i(1008, 630)
	root.content_scale_size = Vector2i(1008, 630)
	screen.preferences.data.text_scale = 1.2
	screen._open_preparation(false)
	await settle()
	for id in Content.GUNS:
		await touch("weapon_select_" + id)
		screen.main_scroll.scroll_vertical = 0
		await settle()
		screen.main_scroll.ensure_control_visible(screen.find_child("start_" + id, true, false))
		await settle()
		bounds("start_" + id)
		var details: Control = screen.find_child("starting_deck", true, false)
		var rail: Control = screen.find_child("WeaponHeading", true, false)
		check(details.get_global_rect().end.y <= rail.get_global_rect().position.y, "large text does not overlap gun rail")
	await capture("equipment_large_text")
	screen._open_preparation(true)
	await settle()
	check((screen.find_child("outfit_select_carrier", true, false) as Button).disabled, "training does not promise unsupported outfit")
	await touch("start_" + screen.selected_weapon_id)
	check(screen.campaign == null and screen.model.s.outfit == "work", "training baseline preserved")
	print("EQUIPMENT UI COMPLETE checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)

func touch(key: String) -> void:
	var control := screen.find_child(key, true, false) as Control
	if control != null:
		var parent := control.get_parent()
		while parent != null:
			if parent is ScrollContainer: parent.ensure_control_visible(control)
			parent = parent.get_parent()
		await settle()
	await super.touch(key)
