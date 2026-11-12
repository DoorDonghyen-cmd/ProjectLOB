extends "res://tests/navigation_ui_runner.gd"
## End-to-end title input and save safety. Never run against player storage.
const ButtonFrame = preload("res://redesign/ui/button_frame.gd")

func run() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").contains("/qa_runtime/title/ui/"):
		quit(2)
		return
	output = OS.get_environment("QA_OUTPUT_DIR")
	check_shared_action_frames()
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
		check_title_primary(screen.find_child("new_run_setup", true, false))
		check(not screen.find_child("guide", true, false).visible, "fresh title offers the guide once")
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
		check(screen.find_child("SaveCaption", true, false).text == "출발 전 · 우리 동네 정비소", "saved opening points to the departure scene")
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
	check(screen.find_child("SaveCaption", true, false).text == "정상 · 공급 복구", "unfinished restoration names its next screen")
	await touch("new_run_setup")
	await touch("start_single")
	confirmation = screen.find_child("NewRunConfirmation", true, false)
	check(confirmation != null, "unfinished restoration protected from replacement")
	if confirmation != null: confirmation.canceled.emit()
	await settle()
	await check_saved_shop()
	screen.queue_free()
	await process_frame
	print("TITLE UI COMPLETE checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)

func check_shared_action_frames() -> void:
	var rewards := preload("res://redesign/rewards/screen.tscn").instantiate() as Control
	var subjects := [
		[preload("res://redesign/equipment/theme.tres"), &"EquipmentPrimary"],
		[preload("res://redesign/workbench/theme.tres"), &"PrimaryButton"],
		[preload("res://redesign/samples/shop_terminal_review/theme.tres"), &"ConsolePurchase"],
		[rewards.theme, &"Claim"],
		[preload("res://redesign/ui/dark_primary.tres"), &""],
	]
	for subject in subjects:
		var button := Button.new()
		button.theme = subject[0]
		button.theme_type_variation = subject[1]
		button.hide()
		root.add_child(button)
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			var frame := button.get_theme_stylebox(state) as StyleBoxFlat
			var edge_width := 2 if state == "focus" else 1
			check(frame != null and frame.get_script() == ButtonFrame and frame.corner_radius_top_left == 4 and frame.border_width_top == edge_width and frame.border_width_bottom == 2, "%s %s uses the shared shape" % [subject[1], state])
		if button.theme_type_variation.is_empty(): check_title_primary(button)
		else: check(button.get_theme_color("font_focus_color").get_luminance() < 0.15, "%s keeps dark text when focused" % subject[1])
		button.free()
	rewards.free()

func check_title_primary(button: Button) -> void:
	var face := button.get_theme_stylebox("normal") as StyleBoxFlat
	check(face != null and face.bg_color.is_equal_approx(Color("252b23")) and face.get("brass_accent").is_equal_approx(Color("aa9361")), "title primary uses dark iron and brass edges")
	check(button.get_theme_color("font_focus_color").is_equal_approx(Color("ece0c8")), "title primary keeps ivory text when focused")

func check_saved_shop() -> void:
	var path := OS.get_environment("QA_BUILD_DIR").path_join("shop_single_17_r2_n10502.json")
	var run_save = Campaign.new()
	var loaded: bool = run_save.restore_state(JSON.parse_string(FileAccess.get_file_as_string(path)))
	check(loaded and run_save.s.phase == "shop", "saved shop fixture is a real mid-run destination")
	if not loaded: return
	check(run_save.save() == OK, "shop fixture is saved in the isolated profile")
	var original := FileAccess.get_file_as_string(Campaign.SAVE)
	screen.preferences.data.guide_seen = false
	for resolution in [Vector2i(1280, 800), Vector2i(1008, 454), Vector2i(844, 390)]:
		root.size = resolution
		screen._to_menu()
		await settle()
		for key in ["resume", "new_run_setup", "settings", "SaveCaption", "resume_training", "guide"]: bounds(key)
		var caption := screen.find_child("SaveCaption", true, false) as Label
		var resume := screen.find_child("resume", true, false) as Button
		var new_run := screen.find_child("new_run_setup", true, false) as Button
		var footer := screen.find_child("Footer", true, false) as Control
		var settings := screen.find_child("settings", true, false) as Button
		check(caption.text == "축열 주조장 5층 · 상점" and caption.get_theme_font("font").get_string_size(caption.text, HORIZONTAL_ALIGNMENT_LEFT, -1, caption.get_theme_font_size("font_size")).x <= caption.size.x, "shop destination fits without truncation")
		check(resume.theme != new_run.theme and new_run.theme == settings.theme, "one primary action in the saved title")
		check_title_primary(resume)
		check(not screen.find_child("first_guide", true, false).visible and settings.get_global_rect().end.y <= footer.get_global_rect().position.y, "returning title keeps guide and settings separate")
		await capture("resume_shop_%dx%d" % [resolution.x, resolution.y])
	await touch("resume")
	check(screen.campaign.s.phase == "shop" and screen.campaign.s.node == run_save.s.node, "touch continues to the advertised shop")
	check(FileAccess.get_file_as_string(Campaign.SAVE) == original, "continue caption and opening the shop do not rewrite the save")

func winning_fixture():
	# Since 2026-11-08 the ending uses the earned win of the 2026-11-06 full climb
	# (QA_BUILD_DIR/won_single_17.json, restoration pending). The walk below no longer
	# reaches the end with newer phases and is kept only as a fallback.
	var earned_path := OS.get_environment("QA_BUILD_DIR").path_join("won_single_17.json")
	if FileAccess.file_exists(earned_path):
		var earned = Campaign.new()
		check(earned.restore_state(JSON.parse_string(FileAccess.get_file_as_string(earned_path))) and earned.s.phase == "won" and earned.restoration_pending(), "valid ending fixture reached through actual campaign flow")
		return earned
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
