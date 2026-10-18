extends "res://tests/ammo_expansion_ui_runner.gd"

var seen: Dictionary = {}
var captured: Dictionary = {}
var recording := false
var capturing := false
var frames := 0
var order_errors := 0
var ground_errors := 0
var recoil_observed: Dictionary = {}
var reload_strokes: Dictionary = {}

func observe() -> void:
	if not recording or not is_instance_valid(screen) or screen.battle_view == null: return
	var view = screen.battle_view
	frames += 1
	var pose: String = view.hero_pose()
	var key := pose
	if view.hero_action == "cooling": key = "cooling"
	if view.march_phase != 0.0: seen["approach"] = true
	if view.actor_hit_strength > 0.0: seen["hit"] = true
	if view.float_target >= 0 and view.float_target < view.enemies.size() and int(view.enemies[view.float_target].hp) <= 0:
		seen["defeat"] = true
		key = "defeat"
	seen[pose] = true
	seen[key] = true
	var gun := str(view.display_state.get("gun", "single"))
	if view.hero_action == "fire" and view.flash > 0.5 and view._recoil().length() >= 1.0:
		recoil_observed[gun] = true
	if view.hero_action == "reload":
		if not reload_strokes.has(gun): reload_strokes[gun] = {}
		var actor = view.weapon_viewport.get_node("Actor")
		reload_strokes[gun][roundi(actor.reload_amount * 10)] = true
	for a in view._alive_indices():
		for b in view._alive_indices():
			if float(view.enemies[a].distance) < float(view.enemies[b].distance) and view.enemy_feet(a).x >= view.enemy_feet(b).x: order_errors += 1
		var kind := str(view.enemies[a].kind)
		if kind == "spitter":
			if absf(view.toad_rect(a).end.y - view.enemy_feet(a).y) > 1.0: ground_errors += 1
		elif kind not in ["caster", "absorber", "stance"]:
			var rect: Rect2 = view.actor_rect(a, view.Pixel.sprite_rect(kind, view.enemy_feet(a)))
			if absf(rect.end.y - view.enemy_feet(a).y) > 1.0: ground_errors += 1
	if view.hero_action == "reload": key += "_p%d" % floori(view.hero_reload_progress * 4)
	var id := "%s_%s_%d" % [gun, key, root.size.x]
	if captured.has(id) or capturing: return
	capturing = true
	await RenderingServer.frame_post_draw
	if is_instance_valid(view) and view.hero_pose() == pose:
		var result := root.get_texture().get_image().save_png(OS.get_environment("QA_OUTPUT_DIR").path_join(id + ".png"))
		check(result == OK, "capture actual animation " + id)
		captured[id] = true
	capturing = false

func set_enemies(rows: Array) -> void:
	screen.model.s.enemies = []
	for row in rows: screen.model.s.enemies.append(Data._enemy(row))
	screen.model.assign_opening_lanes()
	screen.model.s.projectiles = []
	screen.model.s.reinforcements = []
	screen.model.s.encounter_total = rows.size()
	screen.model.s.deployed = rows.size()
	screen.redraw()
	await settle()

func press_without_wait(key: String) -> void:
	var button := screen.find_child(key, true, false) as Button
	check(button != null and not button.disabled, "input without waiting " + key)
	if button == null or button.disabled: return
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = button.get_global_rect().get_center()
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame

func rendered_actor(viewport: SubViewport) -> int:
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	return hash(viewport.get_texture().get_image().get_data())

func check_rendered_mechanics() -> void:
	# Compare actual GPU pixels with a constant body pose, not just state names.
	var viewport = load("res://redesign/weapon_actor.tscn").instantiate()
	root.add_child(viewport)
	var actor = viewport.get_node("Actor")
	for gun in actor.WEAPONS:
		actor.configure(gun, "aim", 0.0)
		var rest: int = await rendered_actor(viewport)
		actor.configure(gun, "aim", 1.0)
		check(rest != await rendered_actor(viewport), "visible gun recoil independent of pose " + gun)
		actor.configure(gun, "reload_open", 0.0, 0.0)
		var closed: int = await rendered_actor(viewport)
		actor.configure(gun, "reload_open", 0.0, 0.4)
		check(closed != await rendered_actor(viewport), "rendered part extraction " + gun)
		actor.configure(gun, "reload_open", 0.0, 0.95)
		check(closed == await rendered_actor(viewport), "rendered part seats completely " + gun)
	# Compare both render paths after live gun switches, including disabled cache.
	for gun in actor.WEAPONS:
		actor.configure(gun, "aim", 0.0, -1.0, 0.0)
		actor.coarse_burst = false
		var original: int = await rendered_actor(viewport)
		actor.coarse_burst = true
		var coarse: int = await rendered_actor(viewport)
		check(original != coarse if gun == "burst" else original == coarse, "density changes only burst pixels " + gun)
	actor.configure("burst", "aim", 0.0, -1.0, 0.0)
	var cold: int = await rendered_actor(viewport)
	actor.configure("burst", "aim", 0.0, -1.0, 1.0)
	check(cold != await rendered_actor(viewport), "coarse weapon heat updates")
	actor.configure("burst", "aim", 0.0, -1.0, 0.0)
	check(cold == await rendered_actor(viewport), "coarse weapon cooling restores exact pixels")
	viewport.queue_free()
	await process_frame

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/actor_motion/"):
		quit(1)
		return
	screen = load("res://redesign/main.tscn").instantiate()
	screen.save_enabled = false
	screen.presentation_speed = 0.8
	root.add_child(screen)
	await settle()
	await check_rendered_mechanics()
	process_frame.connect(observe)
	for resolution in [Vector2i(1280, 900), Vector2i(1008, 630), Vector2i(1440, 630)]:
		root.size = resolution
		await combat(["push", "pierce", "cool", "disrupt"], "single", true)
		await set_enemies([["runner", 60, 0, 1, 20], ["wall", 60, 3, 1, 24], ["spitter", 60, 0, 0, 28]])
		seen.clear()
		recording = true
		await settle()
		fit()
		check(screen.battle_view.hero_pose() == "idle", "planning uses accepted idle")
		await tap("load_push")
		await tap("confirm")
		check(screen.battle_view.hero_pose() == "aim", "public confirm aims equipped weapon")
		var view = screen.battle_view
		for gun in view.WeaponActor.WEAPONS:
			for action in view.WeaponActor.POSES[view.WeaponActor.family(gun)]:
				var muzzle: Vector2 = view.WeaponActor.muzzle(gun, action, view.player_feet(), view.character_scale())
				check(Rect2(Vector2.ZERO, view.size).has_point(muzzle), "registered muzzle within battlefield " + gun + "/" + action)
				var frame: Dictionary = view.WeaponActor.pose(gun, action)
				var grip: Vector2 = view.WeaponActor.weapon_transform(gun, action) * view.WeaponActor.WEAPONS[gun].grip
				check(grip.distance_to(view.WeaponActor.FOOT - frame.foot + frame.grip) < 0.01, "grip anchored to hand " + gun + "/" + action)
		await tap("fire")
		check(screen.last_presentation.shown_enemies == screen.model.s.enemies, "firing state agrees with model")
		await tap("reload")
		check(screen.last_presentation.shown_enemies == screen.model.s.enemies, "reload state agrees with model")
		check(screen.battle_view.hero_pose() == "idle", "reload returns to idle")
		check(screen.battle_view.moving_indices.is_empty(), "movement resets")
		for key in ["idle", "aim", "recoil", "reload_open", "reload_seat", "approach", "hit"]:
			check(seen.has(key), "public flow includes " + key + str(resolution))
		recording = false
	# Both pistol users and all long guns must render and finish a real action.
	for gun in ["amplifier", "scatter", "heavy"]:
		await combat(["basic", "pierce", "cool"], gun, true)
		await set_enemies([["wall", 80, 3, 1, 30]])
		seen.clear()
		recording = true
		await tap("load_basic")
		await tap("confirm")
		check(screen.battle_view.weapon_viewport.get_node("Actor").gun_id == gun, "equipped art " + gun)
		await tap("fire")
		await tap("reload")
		check(seen.has("recoil") and seen.has("reload_open") and seen.has("reload_seat"), "complete weapon motion " + gun)
		check(screen.last_presentation.shown_enemies == screen.model.s.enemies, "weapon presentation agrees with model " + gun)
		recording = false
	# A stationary ranged enemy must not suppress the reload arm sequence.
	await combat(["basic", "cool", "pierce"], "single", true)
	await set_enemies([["spitter", 80, 0, 0, 30]])
	seen.clear()
	recording = true
	await tap("load_basic")
	await tap("confirm")
	await tap("fire")
	await tap("reload")
	check(seen.has("reload_open") and seen.has("reload_seat"), "reload animates without ground movement")
	recording = false
	# The two-turn weapon spans one reload sequence across both actual turns.
	await combat(["basic", "pierce", "cool"], "burst", true)
	await set_enemies([["wall", 80, 3, 1, 30]])
	seen.clear()
	recording = true
	await tap("load_basic")
	await tap("confirm")
	await tap("fire")
	var turns_before: int = screen.model.s.turns
	await tap("reload")
	check(screen.model.s.turns - turns_before == 2, "burst reload retains two actual turns")
	check(seen.has("reload_open") and seen.has("reload_seat") and screen.battle_view.hero_pose() == "idle", "two-turn reload completes all poses")
	recording = false
	# Force the real overheat path using a deterministic near-limit fixture.
	await combat(["pierce", "cool"], "single", true)
	await set_enemies([["wall", 80, 3, 1, 30]])
	screen.model.s.heat = Ammo.heat_limit(screen.model.s) - 1
	screen.redraw()
	await settle()
	seen.clear()
	recording = true
	await tap("load_pierce")
	await tap("confirm")
	await tap("fire")
	check(seen.has("cooling"), "forced reload exposes additional cooling pose")
	check(screen.model.s.heat == 0 and screen.model.s.phase == "plan", "forced reload finishes cooled and playable")
	check(screen.battle_view.hero_pose() == "idle", "cooling returns to idle")
	recording = false
	# Actual lethal shot retains an anchored fading actor only during impact.
	await combat(["pierce", "cool"], "single", true)
	await set_enemies([["runner", 1, 0, 1, 15], ["wall", 60, 3, 1, 24]])
	seen.clear()
	recording = true
	await tap("load_pierce")
	await tap("confirm")
	await tap("fire")
	check(seen.has("defeat"), "lethal shot renders defeat reaction")
	check(screen.battle_view.float_target == -1 and screen.model.s.enemies[0].hp == 0, "defeat presentation cleans up")
	recording = false
	# Reduced feedback freezes secondary movement and suppresses recoil frames.
	var view = screen.battle_view
	view.reduced_feedback = true
	var clock_before: float = view.actor_clock
	var rect: Rect2 = view.Pixel.sprite_rect("wall", view.enemy_feet(1))
	await settle()
	check(view.actor_clock == clock_before and view.actor_rect(1, rect) == rect, "reduced feedback freezes ambient motion")
	view.hero_action = "fire"
	view.flash = 1.0
	check(view.hero_pose() == "aim", "reduced feedback omits recoil pose")
	view.sync(screen.model.s)
	check(view.hero_action == "idle" and view.moving_indices.is_empty(), "sync resets animation state")
	# Skip through public input without altering the already resolved action.
	await combat(["pierce", "push", "cool"], "single", true)
	await set_enemies([["wall", 80, 3, 1, 30]])
	for id in ["pierce", "push", "cool"]: await tap("load_" + id)
	await tap("confirm")
	await press_without_wait("fire")
	check(screen.busy, "skip fixture has an active action")
	var resolved: Dictionary = screen.model.s.duplicate(true)
	await tap("skip_animation")
	check(screen.model.s == resolved, "skip preserves resolved state")
	check(screen.battle_view.hero_pose() == "idle" and screen.battle_view.actor_hit_strength == 0.0 and screen.battle_view.float_target == -1, "skip cleans up pose and impact")
	check(frames > 0 and order_errors == 0 and ground_errors == 0, "all observed frames preserve distance order and ground")
	for gun in ["single", "amplifier", "burst", "scatter", "heavy"]:
		check(recoil_observed.has(gun), "actual firing has baseline recoil " + gun)
		check(reload_strokes.get(gun, {}).size() >= 5, "actual reload has continuous part travel " + gun)
	print("MOTION observed_frames=%d order_errors=%d ground_errors=%d" % [frames, order_errors, ground_errors])
	while capturing: await process_frame
	screen.queue_free()
	await process_frame
	print("ACTOR MOTION UI COMPLETE checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
