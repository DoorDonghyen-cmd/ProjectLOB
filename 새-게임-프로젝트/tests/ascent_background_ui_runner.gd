extends "res://tests/actor_motion_ui_runner.gd"
const Ascent = preload("res://redesign/ascent_background.gd")

func check_bands() -> void:
	for example in [[8,[0,0,0,1,1,1,2,2]], [9,[0,0,0,1,1,1,2,2,2]], [10,[0,0,0,0,1,1,1,2,2,2]], [12,[0,0,0,0,1,1,1,1,2,2,2,2]]]:
		for i in range(example[0]):
			check(Ascent.stage_index(i+1,example[0]) == example[1][i], "height band %d/%d" % [i+1,example[0]])
	check(Ascent.stage_index(0,8) == 0 and Ascent.stage_index(99,8) == 2, "entry and endpoint clamp")
	for version in [1,2]:
		for region in range(5):
			var length := int(Data.info(region,version).floors)
			var per_height := {}
			for node in Data.nodes(region,731042,version):
				var selected := Ascent.profile(region,int(node.floor),length)
				if per_height.has(node.floor): check(per_height[node.floor] == selected, "branches at same height share art")
				per_height[node.floor] = selected
				check(selected.stage >= 0 and selected.stage < 3, "all regions use shared three bands")
				check(selected.ready == (region == 0), "unproduced region art is explicitly fallback")
		var original := Campaign.new()
		original.start("single",731042,0,"balanced",version)
		check(original.enter(int(original.choices()[0].id)), "enter real route for save check")
		var filename := "user://ascent_restore_%d.json" % version
		check(original.save(filename) == OK, "isolated save")
		var restored := Campaign.new()
		check(restored.restore(filename), "restore existing map version")
		check(Ascent.profile(restored.s.region,restored.s.floor,restored.region_info().floors) == Ascent.profile(original.s.region,original.s.floor,original.region_info().floors), "restore selects same background without extra save fields")

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/ascent_background/"):
		quit(1); return
	check_bands()
	screen = load("res://redesign/main.tscn").instantiate()
	screen.save_enabled = false
	screen.presentation_speed = 0.02
	root.add_child(screen)
	await settle()
	for resolution in [Vector2i(1280,900),Vector2i(1008,630),Vector2i(1440,630)]:
		root.size = resolution
		await combat(["basic","pierce","cool"],"single",true)
		var foot: Vector2 = screen.battle_view.player_feet()
		var enemy: Vector2 = screen.battle_view.enemy_feet(0)
		for depth in [1,3,4,6,7,8]:
			screen.campaign.s.floor = depth
			screen.campaign.s.node = screen.campaign.current_nodes().filter(func(room): return int(room.floor) == depth)[0].id
			var model_before := hash(screen.model.s)
			screen.redraw()
			await settle()
			var view = screen.battle_view
			check(view.background_profile.stage == Ascent.stage_index(depth,8), "actual screen uses campaign node height")
			check(hash(screen.model.s) == model_before, "background does not mutate combat or RNG")
			check(view.player_feet() == foot and view.enemy_feet(0) == enemy, "actors and distances keep their ground plane")
			var source: Rect2 = view.background_source_rect()
			check(Rect2(Vector2.ZERO,view.tower_texture.get_size()).encloses(source), "background crop stays inside texture")
			var ground: float = (float(view.source_floor_y) - source.position.y) * view.size.y / source.size.y
			check(absf(ground-foot.y) < 0.01, "registered image floor meets feet")
			fit()
			if depth in [1,4,7]: await capture("stage_%d_%d" % [view.background_profile.stage,resolution.x])
		await tap("load_basic")
		await tap("confirm")
		await tap("fire")
		check(screen.battle_view.background_profile.stage == 2, "firing/redraw retains route stage")
		await tap("reload")
		check(screen.battle_view.background_profile.stage == 2, "reload/redraw retains route stage")
	# Public developer shortcuts offer a quick comparison without changing saves.
	for stage in range(3):
		screen._developer()
		await settle()
		var button := screen.find_child("debug_background_%d" % stage, true, false) as Control
		var parent := button.get_parent()
		while parent != null:
			if parent is ScrollContainer: parent.ensure_control_visible(button)
			parent = parent.get_parent()
		await settle()
		await tap("debug_background_%d" % stage)
		check(screen.debug_session and screen.battle_view.background_profile.stage == stage, "developer shortcut selects stage and preserves saves")
	print("ASCENT BACKGROUND UI COMPLETE checks=%d failures=%d" % [checks,failures])
	quit(1 if failures > 0 else 0)
