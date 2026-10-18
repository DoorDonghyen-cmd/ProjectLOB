extends SceneTree
## Isolated narrative navigation/save coverage; combat completion below is a fixture.
const Campaign = preload("res://redesign/campaign.gd")
const Data = preload("res://redesign/campaign_content.gd")
const Story = preload("res://redesign/city_story.gd")
var screen: Control
var checks := 0
var failures: Array[String] = []
var output := ""

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: " + label)

func settle() -> void:
	for i in range(6): await process_frame
	await RenderingServer.frame_post_draw

func tap(key: String) -> void:
	var button := screen.find_child(key, true, false) as Button
	check(button != null and button.is_visible_in_tree() and not button.disabled, "usable " + key)
	if button == null or button.disabled: return
	var ancestor := button.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(button)
			break
		ancestor = ancestor.get_parent()
	await settle()
	var point := root.get_final_transform() * (button.get_screen_transform() * (button.size * 0.5) - Vector2(DisplayServer.window_get_position()))
	for held in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.position = point
		event.pressed = held
		Input.parse_input_event(event)
		await process_frame
	await settle()

func capture(label: String, primary: String = "") -> void:
	await settle()
	check(screen.body.size.x <= screen.size.x + 1, "horizontal bounds " + label)
	if not primary.is_empty():
		var button := screen.find_child(primary, true, false) as Control
		check(button != null and button.get_global_rect().end.y <= screen.size.y + 1, "primary visible without scroll " + label)
	check(root.get_texture().get_image().save_png(output.path_join(label + ".png")) == OK, "capture " + label)

func roundtrip(campaign):
	check(campaign.save() == OK, "atomic save " + str(campaign.s.phase))
	var loaded = Campaign.new()
	check(loaded.restore(), "restore " + str(campaign.s.phase))
	check(JSON.stringify(loaded.s) == JSON.stringify(JSON.parse_string(JSON.stringify(campaign.s))), "narrative exact roundtrip")
	return loaded

func winning_fixture():
	var campaign = Campaign.new()
	campaign.start("single", 731042)
	campaign.advance_departure(true)
	var guard := 0
	while campaign.s.phase != "won" and guard < 200:
		guard += 1
		match str(campaign.s.phase):
			"map": check(campaign.enter(int(campaign.choices()[0].id)), "fixture legal route")
			"combat":
				for enemy in campaign.model.s.enemies: enemy.hp = 0
				campaign.model.s.reinforcements = []
				campaign.model.s.phase = "reward"
				campaign.sync_combat()
			"reward": check(campaign.reward("skip"), "fixture reward")
			"gate": check(campaign.gate("credits"), "fixture gate")
			"shop", "bypass": check(campaign.leave(), "fixture leave")
			"supply", "event": check(campaign.resolve("skip") and campaign.leave(), "fixture service")
	check(campaign.s.phase == "won", "fixture reaches normal winning state")
	return roundtrip(campaign)

func run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/story/"):
		printerr("Story QA requires isolated qa_runtime/story storage.")
		quit(2)
		return
	output = OS.get_environment("QA_OUTPUT_DIR")
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 900)
	screen = load("res://redesign/main.tscn").instantiate()
	screen.save_enabled = false
	root.add_child(screen)
	await settle()
	await capture("title")
	for dimensions in [Vector2i(1280, 900), Vector2i(1008, 630), Vector2i(1440, 630)]:
		root.size = dimensions
		await settle()
		screen.preferences.data.text_scale = 1.1 if dimensions.x == 1008 else 1.0
		screen._open_preparation(false)
		await settle()
		await tap("start_single")
		check(screen.campaign.departure_pending(), "new run enters personal opening")
		var combat_before := [screen.model.s.deck.duplicate(), screen.model.s.rng_state, screen.model.s.turns]
		for step in range(3):
			check(int(screen.campaign.s.departure_step) == step, "opening step " + str(step))
			await capture("opening_%d_%d" % [dimensions.x, step], "story_next")
			var restored = roundtrip(screen.campaign)
			check(restored.departure_pending(), "resume incomplete opening")
			if step == 1:
				screen._to_menu()
				await settle()
				await tap("resume")
				check(int(screen.campaign.s.departure_step) == 1, "continue button resumes at repaired valve")
			await tap("story_next")
		check(not screen.campaign.departure_pending(), "opening reaches map")
		check(screen.model.s.deck == combat_before[0] and screen.model.s.rng_state == combat_before[1] and int(screen.model.s.turns) == int(combat_before[2]), "opening never advances combat or deck RNG")
		await capture("map_%d" % dimensions.x)
		# A continuing save must not re-open the departure sequence.
		screen.campaign = roundtrip(screen.campaign)
		screen.model = screen.campaign.model
		screen.redraw()
		await settle()
		check(screen.find_child("CityMap", true, false) != null, "map resumes after opening")
		# Full shop story is present at entrance; reading never blocks trading.
		screen._debug_city("shop")
		await settle()
		await capture("shop_%d" % dimensions.x)
		for region in range(5):
			screen.campaign.s.region = region
			screen.campaign.s.node = region * 10000 + 401
			screen.redraw()
			await settle()
			var state_before := JSON.stringify(screen.campaign.s)
			var prose := screen.find_child("ShopStoryText", true, false) as Label
			check(prose != null and prose.text == Story.SHOPS[region].story, "full shop story on arrival")
			await capture("resident_%d_%d" % [dimensions.x, region])
			check(not is_instance_valid(screen.workspace_overlay), "story does not block trading")
			check(state_before == JSON.stringify(screen.campaign.s), "talk is free and does not alter stock/route")
		var won = winning_fixture()
		check(won.restoration_pending(), "victory awaits manual restoration")
		screen.campaign = won
		screen.model = won.model
		screen.debug_session = false
		screen.page = "run"
		screen.redraw()
		await settle()
		await capture("control_room_%d" % dimensions.x, "story_restore")
		screen._to_menu()
		await settle()
		await tap("resume")
		check(screen.campaign.restoration_pending(), "settled victory can resume final action")
		var awards := JSON.stringify(screen.campaign.profile)
		await tap("story_restore")
		check(screen.campaign.s.restoration_done, "restore button resolves ending")
		check(JSON.stringify(screen.campaign.profile) == awards, "restoration never pays victory twice")
		check(not screen.campaign.restore_supply(), "repeated restoration rejected")
		check(roundtrip(screen.campaign).s.restoration_done, "restored ending persists")
		await capture("homecoming_%d" % dimensions.x, "story_results")
		await tap("story_results")
		await capture("results_%d" % dimensions.x)
	# Current records keep acquired IDs; pre-narrative saves skip the new prologue.
	var legacy = Campaign.new()
	legacy.start("single", 82)
	legacy.profile.lore = [1, 8, 19, 20]
	legacy.save()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Campaign.SAVE))
	data.campaign.erase("departure_step")
	data.campaign.erase("restoration_done")
	var restored = Campaign.new()
	check(restored.restore_state(data), "legacy save without story fields loads")
	check(not restored.departure_pending() and restored.profile.lore.map(func(id): return int(id)) == [1, 8, 19, 20], "legacy discovery and location retained")
	var old_win = winning_fixture()
	old_win.save()
	var completed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Campaign.SAVE))
	completed.campaign.erase("departure_step")
	completed.campaign.erase("restoration_done")
	var old_loaded = Campaign.new()
	check(old_loaded.restore_state(completed) and not old_loaded.restoration_pending(), "older completed runs stay completed")
	for bad in [-1, 4, 1.5, "1", true]:
		var invalid: Dictionary = data.duplicate(true)
		invalid.campaign.departure_step = bad
		check(not Campaign.new().restore_state(invalid), "malformed story step rejected")
	data.campaign.restoration_done = true
	check(not Campaign.new().restore_state(data), "premature restoration state rejected")
	check(Story.ENTRIES.size() == 20, "all twenty record IDs retained")
	for id in range(1, 21): check(not str(Story.entry(id).text).is_empty(), "record text " + str(id))
	screen.campaign = legacy
	screen.model = legacy.model
	screen.page = "run"
	screen.redraw()
	await settle()
	await tap("story_skip")
	check(not legacy.departure_pending(), "skip leads directly to map")
	screen.city_ui.archive()
	await settle()
	check(screen.find_child("city_lore_8", true, false) != null, "acquired current record available")
	check((screen.find_child("city_lore_locked_2", true, false) as Button).disabled, "unacquired record stays locked")
	await tap("city_lore_8")
	check(screen.find_child("StoryRecordText", true, false) != null, "record touch opens actual text")
	await capture("record_8")
	await tap("story_record_back")
	check(screen.find_child("city_lore_8", true, false) != null, "record returns to archive")
	await tap("workspace_close")
	await tap("menu")
	var saved_before := FileAccess.get_file_as_string(Campaign.SAVE)
	screen.save_enabled = true
	# Use the real preview entry; its debug-session guard must protect an active save.
	screen._debug_city("departure")
	await settle()
	check(screen.debug_session and screen.campaign.departure_pending(), "departure preview uses isolated developer session")
	await tap("story_next")
	check(FileAccess.get_file_as_string(Campaign.SAVE) == saved_before, "preview does not overwrite real progression")
	var report := {"checks": checks, "failures": failures, "note": "Narrative/save/UI checks. Combat victories in this runner are fixtures, not combat QA."}
	var file := FileAccess.open(output.path_join("story_report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("STORY FLOW COMPLETE checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
