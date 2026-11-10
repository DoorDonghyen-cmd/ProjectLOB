extends "res://tests/playtest_revision_ui_runner.gd"
## Desktop profiling of production views and isolated, real autosaves.
## These CPU/frame samples are not measurements of an Android device.
var measurements: Array = []
var geometry: Dictionary = {}

func median(values: Array) -> float:
	values.sort()
	return float(values[values.size() / 2])

func idle_sample(view: Control, label: String) -> void:
	await settle()
	var draws := {"count": 0}
	var count_draw := func(): draws.count += 1
	view.draw.connect(count_draw)
	var times: Array = []
	var render_calls: Array = []
	var start := Time.get_ticks_usec()
	var previous := start
	for i in 120:
		await process_frame
		var now := Time.get_ticks_usec()
		times.append(float(now - previous) / 1000.0)
		previous = now
		render_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	view.draw.disconnect(count_draw)
	var duration := float(Time.get_ticks_usec() - start) / 1000000.0
	var row := {"label": label, "redraws_per_second": draws.count / duration,
		"frame_median_ms": median(times), "frame_p95_ms": times[113],
		"render_calls_median": median(render_calls),
		"nodes": get_node_count(), "static_memory_bytes": OS.get_static_memory_usage()}
	measurements.append(row)
	print(JSON.stringify(row))

func record_geometry(label: String) -> void:
	var view = screen.battle_view
	var rows: Array = []
	for i in view._alive_indices():
		var foot: Vector2 = view.enemy_feet(i)
		var plaque: Rect2 = view.enemy_plaque(i)
		rows.append([i, foot.x, foot.y, plaque.position.x, plaque.position.y, plaque.size.x, plaque.size.y])
	for projectile in view.projectiles:
		if int(projectile.hp) > 0:
			var position: Vector2 = view.enemy_position(view.Ranged.target_id(projectile))
			rows.append([view.Ranged.target_id(projectile), position.x, position.y])
	geometry[label] = rows

func profile_case(gun: String, late: bool) -> void:
	await load_record(gun, late)
	var label := gun + ("_late" if late else "_early")
	var save_times: Array = []
	var before: String = JSON.stringify(screen.model.s)
	for i in 7:
		var start := Time.get_ticks_usec()
		check(screen.campaign.save("user://mobile_profile.json") == OK, "isolated atomic save " + label)
		save_times.append(float(Time.get_ticks_usec() - start) / 1000.0)
	check(before == JSON.stringify(screen.model.s), "combat save preserves every field " + label)
	var restored := Campaign.new()
	check(restored.restore("user://mobile_profile.json"), "real disk save restores " + label)
	check(JSON.stringify(restored.model.s.history) == JSON.stringify(screen.model.s.history), "full history survives " + label)
	var first_save: float = save_times[0]
	measurements.append({"label": label + "_save", "first_ms": first_save, "median_ms": median(save_times), "bytes": FileAccess.get_file_as_bytes("user://mobile_profile.json").size()})
	for resolution in [Vector2i(1280,800), Vector2i(1008,630), Vector2i(1440,630)]:
		root.size = resolution
		await settle()
		var view = screen.battle_view
		var prefix := label + "_" + str(resolution.x)
		record_geometry(prefix)
		# In-place movement, ties, a defeated actor and a projectile exercise stale caches.
		var original_enemies: Array = view.enemies.duplicate(true)
		var original_projectiles: Array = view.projectiles.duplicate(true)
		for i in view.enemies.size(): view.enemies[i].distance = 12.0
		record_geometry(prefix + "_tie")
		view.enemies[0].distance = 5.5
		record_geometry(prefix + "_move")
		view.enemies[0].hp = 0
		record_geometry(prefix + "_death")
		view.projectiles = [{"uid": 2, "hp": 2, "distance": 7.0, "speed": 2}]
		record_geometry(prefix + "_projectile")
		view.enemies = original_enemies
		view.projectiles = original_projectiles
	root.size = Vector2i(1280,800)
	await settle()
	await idle_sample(screen.battle_view, label + "_cold")
	screen.battle_view.heat_debt = 6
	await idle_sample(screen.battle_view, label + "_warm")
	var nodes_before := get_node_count()
	for i in 15:
		screen.redraw()
		await settle()
	check(get_node_count() == nodes_before, "repeated redraw frees old nodes " + label)

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/playtest_revision_20261026/mobile_ui/"):
		quit(2); return
	screen = load("res://redesign/main.tscn").instantiate()
	screen.save_enabled = false
	screen.presentation_speed = 0.04
	root.add_child(screen)
	await settle()
	for gun in ["burst", "scatter"]:
		for late in [false, true]: await profile_case(gun, late)
	# The movement redesign intentionally replaces the old packed coordinates.
	# Compare unchanged entities within each mutation, not a superseded screenshot.
	for label in geometry:
		if not str(label).ends_with("_tie"): continue
		var prefix := str(label).trim_suffix("_tie")
		for row in geometry[label]:
			if int(row[0]) == 0: continue
			for suffix in ["_move", "_death", "_projectile"]:
				var matches: Array = geometry[prefix + suffix].filter(func(other): return other[0] == row[0])
				check(matches.size() == 1 and matches[0][1] == row[1] and matches[0][2] == row[2], "stationary actor stays fixed after another threat changes")
	screen._open_preparation(false)
	await settle()
	await idle_sample(screen.find_child("OutfitPortrait", true, false), "equipment_idle")
	await capture("equipment_idle")
	var result := {"platform": OS.get_name(), "max_fps": Engine.max_fps, "rows": measurements, "geometry": geometry, "checks": checks, "failures": failures}
	FileAccess.open(OS.get_environment("QA_OUTPUT_DIR").path_join("metrics.json"), FileAccess.WRITE).store_string(JSON.stringify(result, "  "))
	print("PLAYTEST REVISION MOBILE UI COMPLETE checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
