extends "res://tests/navigation_ui_runner.gd"
## End-to-end title input and save safety. Never run against player storage.
func run() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").contains("/qa_runtime/title/ui/"):
		quit(2)
		return
	output = OS.get_environment("QA_OUTPUT_DIR")
	check(OS.get_user_data_dir().replace("\\", "/").ends_with("/Roaming/Godot/app_userdata/Last on Board - Core Redesign"), "renamed title keeps Windows save directory")
	for path in [Campaign.SAVE, "user://chain_run_v2.json", "user://redesign_preferences_v1.json"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	screen = load("res://redesign/main.tscn").instantiate()
	screen.save_enabled = false
	root.add_child(screen)
	await settle()
	for resolution in [Vector2i(1280, 800), Vector2i(1008, 630), Vector2i(1440, 630)]:
		root.size = resolution
		await settle()
		screen._to_menu()
		await settle()
		for key in ["TitleHero", "new_run_setup", "settings", "first_guide", "training_setup", "city_archive", "rules", "dev"]: bounds(key)
		check(not screen.find_child("resume", true, false).visible, "fresh save has no false continue")
		check(not screen.main_scroll.get_v_scroll_bar().visible and not screen.main_scroll.get_h_scroll_bar().visible, "title needs no page scroll")
		await create_timer(0.25).timeout
		await capture("fresh_" + str(resolution.x))
		await check_idle(resolution)
		await touch("settings")
		check(screen.find_child("SettingsDialog", true, false) != null, "touch opens settings")
		var settings = screen.find_child("SettingsDialog", true, false).get_meta("dialog")
		settings.close()
		await settle()
		check(root.gui_get_focus_owner() == screen.find_child("settings", true, false), "settings restores menu focus")
		await touch("new_run_setup")
		check(screen.page == "loadout", "touch opens gun preparation")
		await touch("loadout_back")
		check(screen.page == "menu", "preparation returns to title")
		await touch("training_setup")
		check(screen.preparation_training and screen.page == "loadout", "training accessible")
		await touch("loadout_back")
	var saved = Campaign.new()
	saved.start("burst", 818127)
	check(saved.save() == OK, "fixture saved in old save directory")
	var original := FileAccess.get_file_as_string(Campaign.SAVE)
	screen.preferences.data.guide_seen = true
	screen.preferences.data.text_scale = 1.1
	screen.preferences.data.motion = "instant"
	for resolution in [Vector2i(1280,800), Vector2i(1008,630), Vector2i(1440,630)]:
		root.size = resolution
		await settle()
		screen._to_menu()
		await settle()
		for key in ["resume", "new_run_setup", "settings", "SaveCaption"]: bounds(key)
		check(root.gui_get_focus_owner() == screen.find_child("resume", true, false), "continue gets default focus")
		check(not screen.find_child("first_guide", true, false).visible, "read guide no longer promoted")
		var plate = screen.find_child("Backdrop", true, false)
		check(not plate.material.get_shader_parameter("animate_light"), "instant motion disables ambient light")
		var idle = screen.find_child("IdleSprite", true, false)
		check(not idle.is_playing() and idle.frame == 0, "instant motion holds title actor at resting pose")
		await capture("continue_" + str(resolution.x))
	await touch("resume")
	check(screen.page == "run" and int(screen.campaign.s.seed) == 818127 and screen.campaign.s.gun == "burst", "continue restores actual campaign")
	check(FileAccess.get_file_as_string(Campaign.SAVE) == original, "viewing and resuming does not rewrite save")
	screen._to_menu()
	await settle()
	await touch("new_run_setup")
	await touch("start_single")
	var confirmation = screen.find_child("NewRunConfirmation", true, false)
	check(confirmation != null, "new campaign asks before replacing active save")
	if confirmation != null: confirmation.canceled.emit()
	await settle()
	check(FileAccess.get_file_as_string(Campaign.SAVE) == original, "cancel preserves original campaign byte for byte")
	screen._to_menu()
	await settle()
	var training = screen.Model.new()
	training.start("single", 818128, true)
	check(training.save_run(screen.SAVE) == OK, "training fixture saved")
	screen._to_menu()
	await settle()
	bounds("resume_training")
	await touch("resume_training")
	check(screen.page == "run" and screen.campaign == null and int(screen.model.s.seed) == 818128, "training continue restores separate run")
	screen._to_menu()
	await settle()
	# Broken saves remain visible as a warning and are never silently rewritten.
	var corrupt := FileAccess.open(Campaign.SAVE, FileAccess.WRITE)
	corrupt.store_string("{broken")
	corrupt.close()
	screen._to_menu()
	await settle()
	bounds("SaveWarning")
	check(not screen.find_child("resume", true, false).visible, "invalid save never offers continue")
	check(FileAccess.get_file_as_string(Campaign.SAVE) == "{broken", "invalid save preserved")
	await capture("invalid_save")
	check(saved.save() == OK, "restore isolated fixture")
	# The ending still needs a final action even after settlement.
	saved = winning_fixture()
	check(saved.save() == OK, "ending fixture saved")
	screen._to_menu()
	await settle()
	var ending = screen.find_child("resume", true, false)
	check(ending.visible and ending.text.begins_with("정상"), "unfinished restoration stays on main action")
	await touch("new_run_setup")
	await touch("start_single")
	confirmation = screen.find_child("NewRunConfirmation", true, false)
	check(confirmation != null, "unfinished restoration protected from replacement")
	if confirmation != null: confirmation.canceled.emit()
	await settle()
	screen.queue_free()
	await process_frame
	print("TITLE UI COMPLETE checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)

func winning_fixture():
	var fixture = Campaign.new()
	fixture.start("single", 731042)
	fixture.advance_departure(true)
	var guard := 0
	while fixture.s.phase != "won" and guard < 200:
		guard += 1
		match str(fixture.s.phase):
			"map": fixture.enter(int(fixture.choices()[0].id))
			"combat":
				# Terminal combat fixture only; this is a menu/save test, not a balance result.
				for enemy in fixture.model.s.enemies: enemy.hp = 0
				fixture.model.s.reinforcements = []
				fixture.model.s.phase = "reward"
				fixture.sync_combat()
			"reward": fixture.reward("skip")
			"gate": fixture.gate("credits")
			"shop", "bypass": fixture.leave()
			"supply", "event":
				fixture.resolve("skip")
				fixture.leave()
	check(fixture.s.phase == "won", "valid ending fixture reached through actual campaign flow")
	return fixture

func check_idle(resolution: Vector2i) -> void:
	var actor = screen.find_child("Reclaimer", true, false)
	var sprite = actor.find_child("IdleSprite", true, false) as AnimatedSprite2D
	check(sprite != null and sprite.is_playing(), "title idle starts in normal mode")
	if sprite == null: return
	var foot: Vector2 = sprite.global_position
	var textures := {}
	for frame in range(sprite.sprite_frames.get_frame_count(&"rest")):
		sprite.stop()
		sprite.set_frame_and_progress(frame, 0.0)
		await settle()
		var atlas = sprite.sprite_frames.get_frame_texture(&"rest", frame) as AtlasTexture
		textures[atlas.region] = true
		check(Rect2(Vector2.ZERO, atlas.atlas.get_size()).encloses(atlas.region), "idle atlas cell fits source")
		check(sprite.global_position.is_equal_approx(foot), "idle keeps world foot anchor")
		check(is_equal_approx(foot.y, actor.get_global_rect().end.y), "idle planted on title platform")
		if frame == 4: await capture("cap_gesture_" + str(resolution.x))
	check(textures.size() == 4, "idle includes four distinct authored poses")
	if resolution.x == 1280:
		sprite.play(&"rest")
		var seen := {}
		var stop_at := Time.get_ticks_msec() + 7600
		while Time.get_ticks_msec() < stop_at:
			seen[sprite.frame] = true
			await process_frame
		check(seen.size() == 7, "real-time player advances through complete idle cycle")
	actor.set_motion_enabled(false)
	await create_timer(0.15).timeout
	check(not sprite.is_playing() and sprite.frame == 0, "reduced motion resets and freezes pose")
	actor.set_motion_enabled(true)
