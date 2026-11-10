extends "res://redesign/results/screen.gd"

const Campaign = preload("res://redesign/campaign.gd")
const REPLAY := "res://../qa_runtime/core_choice_20261103/climb_fresh17/"
const SCENARIOS := ["won", "lost"]

var runs: Dictionary = {}
var capture_checks := 0
var failures: PackedStringArray = []

func _ready() -> void:
	super._ready()
	archive_requested.connect(show_action.bind(%Archive.text))
	new_run_requested.connect(show_action.bind(%NewRun.text))
	var victory = restore("won_heavy_17")
	var defeat = restore("combat_heavy_17_r4_n30501")
	if victory == null or defeat == null:
		%ActionNote.text = "QA 기록을 불러올 수 없습니다."
		if not OS.get_environment("LOB_RESULTS_CAPTURE").is_empty():
			get_tree().quit(2)
		return
	if victory.restoration_pending():
		victory.restore_supply()
	# Let enemies advance via real magazine changes, from an earned QA checkpoint.
	for attempt in range(12):
		if defeat.s.phase != "combat" or not defeat.model.reload_magazine():
			break
		defeat.sync_combat()
	if victory.s.phase != "won" or defeat.s.phase != "lost":
		push_error("Results review requires real terminal phases.")
		get_tree().quit(2)
		return
	runs = {"won": victory, "lost": defeat}
	show_scenario("won")
	var output := OS.get_environment("LOB_RESULTS_CAPTURE")
	if not output.is_empty():
		capture_all.call_deferred(output)

func restore(file: String):
	var data = JSON.parse_string(FileAccess.get_file_as_string(REPLAY + file + ".json"))
	if not data is Dictionary:
		return null
	var run := Campaign.new()
	return run if run.restore_state(data) else null

func show_scenario(key: String) -> void:
	present(runs[key])
	set_details(false)

func show_action(action: String) -> void:
	%ActionNote.text = "시안 · %s" % action

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and not runs.is_empty():
		match event.keycode:
			KEY_F1: show_scenario("won")
			KEY_F2: show_scenario("lost")
			KEY_ESCAPE:
				if %Details.visible:
					set_details(false)

func verify(condition: bool, context: String) -> void:
	capture_checks += 1
	if not condition:
		failures.append(context)
		push_error(context)

func capture_all(output: String) -> void:
	var window := get_window()
	Input.emulate_mouse_from_touch = true
	verify(str(runs.won.s.phase) == "won", "victory restored")
	verify(str(runs.lost.s.phase) == "lost", "defeat reached through magazine commands")
	verify(runs.lost.model.s.loss_reason == "projectile", "recorded cause matches the failed encounter")
	verify(loss_line({"loss_reason": "ammo"}) == "사용할 탄약이 모두 소진됐습니다.", "ammo message")
	verify(loss_line({"loss_reason": "projectile"}) == "적의 발사체가 사격선에 닿았습니다.", "projectile message")
	for extent in [Vector2i(1280, 800), Vector2i(2340, 1080), Vector2i(2160, 1032)]:
		window.size = extent
		for key in SCENARIOS:
			show_scenario(key)
			var context := "%s_%dx%d" % [key, extent.x, extent.y]
			if key == "lost":
				var stage: Control = %Stage
				verify(stage.actor == null and stage.tint == stage.LOSS_LIGHT, context + " empty stage starts lit")
				await stage.light_fade.finished
				verify(stage.tint.is_equal_approx(stage.LOSS_DUSK), context + " dusk settles")
			await draw_frame()
			verify(%NewRun.get_global_rect().size.x < %Record.size.x * 0.6, context + " action sized by content")
			verify(%Stage.size.x > 0.0 and %Record.size.x > 0.0, context + " composition fits")
			verify(%RoundIcon.visible and not %RoundDamage.text.is_empty(), context + " actual shot record")
			verify_visible_text(context)
			await save_frame(output, context, extent)
			await touch(%DetailsButton)
			await draw_frame()
			verify(%Details.visible and not %Summary.visible, context + " detail opens")
			verify(%DeckSummary.get_global_rect().end.y <= %DetailsButton.get_global_rect().position.y, context + " details clear actions")
			if key == "won":
				verify_visible_text(context + " details")
				await save_frame(output, "details_%dx%d" % [extent.x, extent.y], extent)
			await touch(%DetailsButton)
			verify(%Summary.visible and not %Details.visible, context + " detail closes")
			var before := JSON.stringify([runs[key].s, runs[key].model.s, runs[key].profile])
			for action: Button in [%NewRun, %Archive]:
				await touch(action)
				verify(%ActionNote.text == "시안 · " + action.text, context + " preview action " + str(action.name))
			verify(JSON.stringify([runs[key].s, runs[key].model.s, runs[key].profile]) == before, context + " preview actions preserve terminal run")
	verify(not FileAccess.file_exists(Campaign.SAVE), "no campaign save written in isolated user directory")
	print("RESULTS REVIEW checks=%d failures=%d" % [capture_checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

func draw_frame() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

func save_frame(output: String, name: String, extent: Vector2i) -> void:
	var image := get_viewport().get_texture().get_image()
	verify(image.get_size() == extent, name + " exact screenshot size")
	verify(image.save_png(output.path_join(name + ".png")) == OK, name + " screenshot saved")


func touch(button: Button) -> void:
	var point := button.get_global_transform_with_canvas() * (button.size * 0.5)
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.position = point
		event.pressed = pressed
		get_viewport().push_input(event, true)
		await get_tree().process_frame

func verify_visible_text(context: String) -> void:
	for item in find_children("*", "Control", true, false):
		if not (item is Label or item is Button) or not item.is_visible_in_tree() or item.text.is_empty():
			continue
		var font: Font = item.get_theme_font("font")
		for character in item.text.replace("\n", ""):
			if not font.has_char(character.unicode_at(0)):
				verify(false, "%s missing glyph %s in %s" % [context, character, item.name])
		verify(get_viewport_rect().encloses(item.get_global_rect()), "%s visible %s" % [context, item.name])
		if item is Button:
			verify(item.size.y >= 44.0, "%s touch height %s" % [context, item.name])
