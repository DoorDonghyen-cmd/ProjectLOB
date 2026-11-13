extends "res://tests/campaign_magazine_ui.gd"

const FIXTURES := "res://../qa_runtime/core_choice_20261103/climb_fresh17/"

func restore_fixture(name: String):
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURES + name + ".json"))
	var run := Campaign.new()
	if not check(data is Dictionary and run.restore_state(data), "earned replay restores " + name):
		return null
	return run

func result_view() -> Control:
	return host.body.get_node_or_null("CampaignResults")

func node(id: String) -> Control:
	return result_view().get_node("%" + id)

func state(run) -> String:
	return JSON.stringify([run.s, run.model.s, run.profile])

func dismiss() -> void:
	var cancel := InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	root.push_input(cancel)
	await settle()

func result_bounds(context: String, scrolling_allowed: bool) -> void:
	var view := result_view()
	var viewport := root.get_visible_rect()
	check(host.body.size.x <= viewport.size.x + 1, context + " no horizontal clipping")
	if not scrolling_allowed:
		var scroll: ScrollBar = host.main_scroll.get_v_scroll_bar()
		check(scroll.max_value <= scroll.page + 1, "%s no vertical scroll (%s/%s)" % [context, scroll.max_value, scroll.page])
	for item in view.find_children("*", "Control", true, false):
		if not (item is Label or item is Button) or not item.is_visible_in_tree() or item.text.is_empty():
			continue
		check(view.get_global_rect().grow(1).encloses(item.get_global_rect()), context + " scene contains " + str(item.name))
		if not scrolling_allowed:
			check(viewport.grow(1).encloses(item.get_global_rect()), context + " visible without scroll " + str(item.name))
		var font: Font = item.get_theme_font("font")
		var missing: Array[String] = []
		for character in item.text.replace("\n", ""):
			if not font.has_char(character.unicode_at(0)): missing.append(character)
		check(missing.is_empty(), context + " glyph coverage " + str(item.name))
		check(item.get_theme_font_size("font_size") >= 16, context + " native font " + str(item.name))
		if item is Button:
			check(item.size.y >= 44, context + " touch size " + str(item.name))

func run() -> void:
	output = OS.get_environment("QA_OUTPUT_DIR")
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/results_live_20261104/") or not DirAccess.dir_exists_absolute(output):
		quit(2)
		return
	Input.emulate_mouse_from_touch = true
	# 3120x1440 (1040x480 in game units) added 2026-11-12: the result buttons were under the
	# screen edge on 1440p phones.
	for extent in [Vector2i(1280, 800), Vector2i(2340, 1080), Vector2i(2160, 1032), Vector2i(3120, 1440), Vector2i(1008, 630), Vector2i(844, 390)]:
		var resolution := "%dx%d" % [extent.x, extent.y]
		root.size = extent
		var won = restore_fixture("won_heavy_17")
		if won == null:
			quit(2)
			return
		await mount(won)
		if won.restoration_pending():
			await tap("story_restore")
		await tap("story_results")
		if not check(result_view() != null, resolution + " homecoming opens production result"):
			quit(1)
			return
		check(node("ResultTitle").text == "탑 돌파", "victory headline")
		check(node("CoreName").text != "코어 미장착" and not node("RoundDamage").text.is_empty(), "earned gear and shot")
		check(host.find_child("retry", true, false) == null, "same-route restart absent")
		var can_scroll: bool = extent.y == 390
		result_bounds("victory " + resolution, can_scroll)
		await capture("won_" + resolution)
		var completed := state(won)
		var saved := FileAccess.get_file_as_string(Campaign.SAVE)
		await tap("DetailsButton")
		check(result_view().details_open(), "detail opens")
		result_bounds("details " + resolution, can_scroll)
		await capture("details_" + resolution)
		await tap("Archive")
		check(is_instance_valid(host.workspace_overlay), "production archive opens")
		await tap("workspace_close")
		check(not is_instance_valid(host.workspace_overlay) and result_view().details_open(), "archive returns to expanded result")
		await dismiss()
		check(host.page == "run" and not result_view().details_open(), "cancel collapses details")
		host.preparation_seed = str(won.s.seed)
		await tap("NewRun")
		check(host.page == "loadout" and state(won) == completed, "new challenge prepares without replacing the run")
		check(FileAccess.get_file_as_string(Campaign.SAVE) == saved, "new challenge keeps the saved result until start")
		check(not host.preparation_seed.is_empty() and host.preparation_seed != str(won.s.seed), "new challenge initializes a fresh seed")
		if extent == Vector2i(1280, 800):
			await tap("start_single")
			check(host.campaign != won and host.campaign.absolute_floor() == 0, "confirm starts new challenge at entry")
			check(host.campaign.profile.wins == won.profile.wins, "new run retains completed records")
			var loaded := Campaign.new()
			check(loaded.restore() and loaded.s.seed == host.campaign.s.seed and loaded.s.phase == "map", "confirmed new run saves")
		var lost = restore_fixture("combat_heavy_17_r4_n30501")
		if lost == null:
			quit(2)
			return
		await mount(lost)
		for attempt in range(12):
			if lost.s.phase != "combat":
				break
			host.campaign_hud.board.speed_scale = 0.01
			await tap("Reload")
		if not check(lost.s.phase == "lost" and result_view() != null, "legal combat input opens defeat"):
			quit(1)
			return
		check(node("ResultTitle").text == "돌파 실패" and node("ResultLine").text.contains("발사체"), "recorded cause shown")
		var stage := node("Stage")
		check(stage.light_fade != null, "normal defeat starts a background fade")
		if stage.light_fade != null and stage.light_fade.is_running():
			await stage.light_fade.finished
		await settle()
		check(stage.actor == null and stage.tint.is_equal_approx(stage.LOSS_DUSK), "empty field reaches dusk")
		result_bounds("defeat " + resolution, can_scroll)
		await capture("lost_" + resolution)
		var replay := Campaign.new()
		check(replay.restore() and replay.s.phase == "lost" and replay.model.s.loss_reason == "projectile", "loss persists with cause")
		if extent == Vector2i(1280, 800):
			await tap("DetailsButton")
			root.size = Vector2i(1008, 630)
			await settle()
			check(result_view().details_open(), "resize preserves expanded record")
			check(node("Stage") == stage and not stage.light_fade.is_running(), "resize keeps the result and does not replay defeat animation")
	if is_instance_valid(host):
		host.free()
	await settle()
	print("RESULTS LIVE checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
