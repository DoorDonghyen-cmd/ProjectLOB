extends "res://tests/combat_hierarchy_ui_runner.gd"

var recorded: Array[String] = []
var mix_capture: AudioEffectCapture
var mixed_frames := PackedVector2Array()
var mixed_peak := 0.0

func collect_audio() -> void:
	if mix_capture == null: return
	var chunk := mix_capture.get_buffer(mix_capture.get_frames_available())
	for sample in chunk:
		mixed_peak = maxf(mixed_peak, maxf(absf(sample.x), absf(sample.y)))
	if mixed_frames.size() < 44100 * 30: mixed_frames.append_array(chunk)

func preferences_check() -> void:
	var prefs = load("res://redesign/preferences.gd").new()
	var path := "user://audio_preferences_test.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string('{"motion":"fast","text_scale":1.1}')
	file.close()
	check(prefs.load_preferences(path) and prefs.data.effects_volume == 0.5, "legacy settings migrate audio default")
	check(prefs.data.motion == "fast" and prefs.data.text_scale == 1.1, "legacy accessibility unchanged")
	check(prefs.set_value("effects_volume", 0.0, path) == OK, "mute saved")
	check(prefs.load_preferences(path) and prefs.data.effects_volume == 0.0, "mute survives reload")
	check(prefs.set_value("effects_volume", NAN, path) == ERR_INVALID_PARAMETER, "reject nonfinite audio")
	check(prefs.set_value("effects_volume", "loud", path) == ERR_INVALID_PARAMETER, "reject invalid audio type")
	prefs.set_value("effects_volume", 3.0, path)
	check(prefs.load_preferences(path) and prefs.data.effects_volume == 1.0, "volume clamped")

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/presentation_feedback/ui"):
		quit(1); return
	preferences_check()
	root.size = Vector2i(1280, 800)
	screen = load("res://redesign/main.tscn").instantiate()
	screen.save_enabled = false
	root.add_child(screen)
	await settle()
	screen.preferences.data.motion = "normal"
	screen.preferences.data.effects_volume = 0.5
	screen.feedback.configure(screen.preferences.data)
	screen.feedback.cue_played.connect(func(cue: String): recorded.append(cue))
	# Capture the actual mixer before the muted master, keeping QA quiet.
	AudioServer.add_bus()
	var bus := AudioServer.bus_count - 1
	AudioServer.set_bus_name(bus, "QAFeedback")
	mix_capture = AudioEffectCapture.new()
	mix_capture.buffer_length = 2.0
	AudioServer.add_bus_effect(bus, mix_capture)
	AudioServer.set_bus_mute(0, true)
	for player in screen.feedback.players: player.bus = "QAFeedback"
	process_frame.connect(collect_audio)
	await tap("new_run_setup")
	check(screen.page == "loadout", "navigation input works during fade")
	await create_timer(0.2).timeout
	check(is_equal_approx(screen.body.modulate.a, 1.0), "transition returns to full opacity")
	check(recorded.has("click"), "navigation has quiet click")
	var count := recorded.size()
	screen.redraw()
	screen.redraw()
	await settle()
	check(recorded.size() == count, "redraw does not replay cues")
	check(is_equal_approx(screen.body.modulate.a, 1.0), "redraw does not restart fade")
	# Rapid navigation interrupts any old tween and keeps the latest page usable.
	screen._to_menu()
	screen.redraw()
	await tap("new_run_setup")
	await create_timer(0.2).timeout
	check(screen.page == "loadout" and is_equal_approx(screen.body.modulate.a, 1.0), "rapid navigation settles latest page")
	for resolution in [Vector2i(1008, 630), Vector2i(1280, 900), Vector2i(1600, 900)]:
		root.size = resolution
		screen._debug_combat_finish()
		screen.presentation_speed = 0.55
		await settle()
		recorded.clear()
		await tap("load_basic")
		await tap("load_precise")
		await tap("load_charge_hot")
		check(recorded.count("load") == 3, "one insertion cue per loaded card")
		await tap("confirm")
		check(recorded.count("confirm") == 1, "one confirmation latch")
		var oracle = load("res://redesign/model.gd").new()
		oracle.s = screen.model.s.duplicate(true)
		check(oracle.fire(), "oracle fires")
		await tap("fire")
		check(screen.model.s == oracle.s, "sound and transition preserve model/RNG")
		for cue in ["fire", "fire_power", "hit", "overheat", "reload", "ready"]:
			check(recorded.has(cue), "actual combat emits " + cue)
		check(recorded.count("overheat") == 1 and recorded.count("reload") == 1, "forced reload cues not doubled")
		check(not screen.busy, "combat input restored")
		fit()
		await capture("feedback_settled_%d" % resolution.x)
	# Actual cooling, armor and victory paths.
	for fixture in [["cool", "cool"], ["shatter", "armor"], ["basic", "reward"]]:
		await setup_hand([fixture[0]])
		screen.campaign.s.departure_step = 3
		if fixture[0] == "cool": screen.model.s.heat = 6
		if fixture[0] == "shatter": screen.model.s.enemies[0].def = 4
		if fixture[0] == "basic": screen.model.s.enemies[0].hp = 1
		await refresh()
		await tap("load_" + fixture[0])
		await tap("confirm")
		recorded.clear()
		await tap("fire")
		check(recorded.has(fixture[1]), "actual event cue " + fixture[1])
		if fixture[1] == "reward":
			check(screen.campaign.s.phase == "reward", "victory arrives at reward")
			await create_timer(0.2).timeout
			await capture("reward_feedback")
			count = recorded.size()
			screen.redraw()
			await settle()
			check(recorded.size() == count, "reward cue only once on entry")
	# An invalid action cannot play a success cue.
	recorded.clear()
	screen._campaign_action("buy", 999)
	check(recorded.is_empty(), "rejected purchase is silent")
	await tap("city_reward_credits")
	check(screen.campaign.s.phase == "map" and recorded.has("confirm"), "reward claim returns to map with one receipt cue")
	screen._debug_city("shop")
	await settle()
	await tap("city_part_info_1")
	recorded.clear()
	var credits: int = screen.campaign.s.credits
	var price: int = screen.campaign.s.offers[1].price
	await tap("city_compare_buy_1")
	check(recorded.count("confirm") == 1 and screen.campaign.s.credits == credits - price, "successful shop purchase emits one receipt")
	recorded.clear()
	screen._campaign_action("buy", 1)
	check(recorded.is_empty(), "duplicate purchase cannot sound successful")
	# Settings route: real dropdown, saved mute, immediate stopping of active voices.
	screen._settings()
	await settle()
	var volume_option := screen.find_child("EffectsVolumeSetting", true, false) as OptionButton
	check(volume_option != null, "volume control present")
	volume_option.select(0)
	volume_option.item_selected.emit(0)
	check(screen.feedback.volume == 0 and screen.feedback.players.all(func(p): return not p.playing), "mute immediately stops all voices")
	recorded.clear()
	screen.feedback.play("fire")
	check(recorded.is_empty(), "muted actions do not play")
	var prefs = load("res://redesign/preferences.gd").new()
	check(prefs.load_preferences() and prefs.data.effects_volume == 0, "settings mute persisted")
	volume_option.select(2)
	volume_option.item_selected.emit(2)
	check(recorded.has("load"), "volume choice previews sound")
	root.size = Vector2i(1008, 630)
	await settle()
	await capture("settings_audio")
	screen.find_child("SettingsDialog",true,false).get_meta("dialog").queue_free()
	await settle()
	# A voluntary reload uses the same start/completion pair as a forced reload.
	screen._debug_combat_finish()
	await settle()
	recorded.clear()
	await tap("reload")
	check(recorded.count("reload") == 1 and recorded.count("ready") == 1, "voluntary reload uses one latch and completion")
	# Skip must stop voices, suppress remaining combat cues, and recover next action.
	screen._debug_combat_finish()
	await settle()
	await tap("load_charge_hot")
	await tap("confirm")
	screen.find_child("fire",true,false).pressed.emit()
	await process_frame
	screen._skip_animation()
	count = recorded.size()
	check(screen.feedback.players.all(func(p): return not p.playing), "skip stops active voices")
	while screen.busy: await process_frame
	await settle()
	check(recorded.size() == count, "skip suppresses remaining combat cues")
	screen.feedback.begin_action()
	screen.feedback.play("hit", true)
	check(recorded.size() == count + 1, "next action recovers audio")
	# Instant presentation keeps UI sounds but suppresses time-compressed combat audio.
	screen.preferences.data.motion = "instant"
	screen._apply_preferences()
	await settle()
	screen._debug_combat_finish()
	await settle()
	await tap("load_charge_hot")
	await tap("confirm")
	recorded.clear()
	await tap("fire")
	check(recorded.is_empty(), "instant combat has no rapid sound barrage")
	check(is_equal_approx(screen.body.modulate.a, 1.0), "instant transitions retain full opacity")
	check(screen.feedback.players.size() == 6 and screen.feedback.get_child_count() == 6, "bounded reusable voice pool")
	# Stress the complete pool at maximum volume and verify the real mixer stays below clipping.
	screen.feedback.configure({"effects_volume": 1.0, "motion": "normal"})
	screen.feedback.last_played.clear()
	for cue in ["fire", "fire_power", "overheat", "armor", "reload", "reward"]:
		screen.feedback.play(cue)
	await create_timer(0.5).timeout
	check(mixed_peak > 0.001 and mixed_peak < 1.0, "actual audio mixer non-silent and unclipped peak=%f" % mixed_peak)
	print("AUDIO MIX peak=%f frames=%d rate=%d" % [mixed_peak, mixed_frames.size(), int(AudioServer.get_mix_rate())])
	var pcm := PackedByteArray()
	pcm.resize(mixed_frames.size() * 4)
	for index in range(mixed_frames.size()):
		pcm.encode_s16(index*4, roundi(clampf(mixed_frames[index].x, -1, 1)*32767))
		pcm.encode_s16(index*4+2, roundi(clampf(mixed_frames[index].y, -1, 1)*32767))
	var recording := AudioStreamWAV.new()
	recording.format = AudioStreamWAV.FORMAT_16_BITS
	recording.stereo = true
	recording.mix_rate = int(AudioServer.get_mix_rate())
	recording.data = pcm
	check(recording.save_to_wav(OS.get_environment("QA_OUTPUT_DIR").path_join("actual_feedback_mix.wav")) == OK, "actual mixer recording saved")
	process_frame.disconnect(collect_audio)
	screen.queue_free()
	await process_frame
	print("PRESENTATION FEEDBACK COMPLETE checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
