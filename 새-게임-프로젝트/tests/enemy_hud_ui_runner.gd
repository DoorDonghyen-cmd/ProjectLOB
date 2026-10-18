extends "res://tests/eavesback_ui_runner.gd"
const Icons = preload("res://redesign/enemy_status_icons.gd")

func touch_slot(index: int) -> void:
	var view: Control = screen.magazine_view
	var entry: Dictionary = view.layout()[index]
	var center := Vector2((float(entry.start) + float(entry.cost) * 0.5) * view.size.x / view.capacity, view.size.y * 0.5)
	var point: Vector2 = root.get_final_transform() * (view.get_screen_transform() * center - Vector2(DisplayServer.window_get_position()))
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.position = point
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await settle()

func hud_pixels(index: int) -> PackedByteArray:
	var view: Control = screen.battle_view
	var local: Rect2 = view.enemy_plaque(index)
	var physical: Rect2 = root.get_final_transform() * view.get_global_transform() * local
	return root.get_texture().get_image().get_region(Rect2i(physical)).get_data()

func hud_fit() -> void:
	fit()
	var view = screen.battle_view
	for i in view._alive_indices():
		var hud: Rect2 = view.enemy_plaque(i)
		var status: Dictionary = view.enemy_status_layout(i)
		var hp_bounds := Rect2(Vector2(31, float(status.extra)), Vector2(view.FONT.get_string_size(str(int(view.enemies[i].hp)), HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x, 30))
		var occupied: Array[Rect2] = []
		for cell in status.cells:
			var bounds := Rect2(Vector2(float(cell.x), float(status.extra) + 4 - int(cell.row) * 28), Vector2(float(cell.width), 24))
			check(Rect2(Vector2.ZERO, hud.size).encloses(bounds), "status stays inside touch area")
			check(not bounds.intersects(hp_bounds), "status clears current HP digits")
			for previous in occupied: check(not bounds.intersects(previous), "status icons do not overlap")
			occupied.append(bounds)
		check(status.cells.size() == Icons.entries(view.enemies[i]).size(), "all active statuses remain visible")
		var distance: Rect2 = view.distance_label_rect(i)
		check(Rect2(Vector2.ZERO, view.size).encloses(distance), "distance stays inside field")
		check(distance.position.y >= view.enemy_feet(i).y + 4, "distance clears feet and target brackets")
		check(view._enemy_at(distance.get_center()) == i, "ground distance opens the same enemy")
		if not view.reinforcements.is_empty():
			var reserve: Rect2 = view.reinforcement_strip_rect()
			check(not distance.intersects(reserve), "distance clears reinforcement strip")
		for j in view._alive_indices():
			check(is_equal_approx(distance.position.y, view.distance_label_rect(j).position.y), "distance shares stable ground baseline")
			if i != j: check(not distance.intersects(view.distance_label_rect(j)), "distance labels stay separate")
		var old_clock: float = view.actor_clock
		var old_motion: float = view.march_phase
		view.actor_clock += 0.7
		view.march_phase = 1.0
		check(distance.is_equal_approx(view.distance_label_rect(i)), "animation cannot move distance baseline")
		view.actor_clock = old_clock
		view.march_phase = old_motion
		check(Rect2(Vector2.ZERO, view.size).encloses(hud), "HUD inside field")
		check(hud.end.y <= view.enemy_head_y(i), "HUD above actual head")
		check(hud.size.x >= 140 and hud.size.y >= 44, "touchable HUD")
		for j in view._alive_indices():
			if i != j: check(not hud.intersects(view.enemy_plaque(j)), "neighbour HUD stays separate")
		var button: Button = view.get_node("enemy_info_%d" % i)
		check(button.position.is_equal_approx(hud.position) and button.size.is_equal_approx(hud.size), "touch target follows head")
		var point: Vector2 = view._damage_position(view.enemy_position(i))
		var number := Rect2(point - Vector2(0, view.FONT.get_ascent(view._damage_font_size())), Vector2(160, view.FONT.get_height(view._damage_font_size())))
		for j in view._alive_indices(): check(not number.intersects(view.enemy_plaque(j)), "impact clears head HUD")
	for projectile in view.projectiles:
		var label: Rect2 = view.projectile_label_rect(projectile)
		for i in view._alive_indices(): check(not label.intersects(view.enemy_plaque(i)), "projectile deadline clears head HUD")

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/eavesback/hud"):
		quit(1)
		return
	screen = load("res://redesign/main.tscn").instantiate()
	screen.save_enabled = false
	screen.presentation_speed = 0.02
	root.add_child(screen)
	await settle()
	for resolution in [Vector2i(1280, 900), Vector2i(1008, 630), Vector2i(1440, 630)]:
		root.size = resolution
		screen._debug_eavesback(true)
		await settle()
		hud_fit()
		check(Icons.entries(screen.model.s.enemies[0]).is_empty(), "plain enemy has no meaningless status")
		check(Icons.entries(screen.model.s.enemies[1])[0].icon == "armor", "armour glyph")
		check(Icons.entries(screen.model.s.enemies[2])[0].icon == "weak_electric", "weakness glyph")
		check(Icons.entries(screen.model.s.enemies[3])[0].icon == "aim", "ranged timer glyph")
		var before: PackedByteArray = hud_pixels(0)
		await capture("idle_%d" % resolution.x)
		await tap("load_pierce")
		check(screen.combat_forecast.enemies[0].hp < screen.model.s.enemies[0].hp, "real forecast differs from current HP")
		check(before == hud_pixels(0), "loading damage does not change overhead pixels")
		await tap("confirm")
		check(before == hud_pixels(0), "confirmed damage does not tint or change overhead HP")
		await touch_slot(0)
		check(screen.find_child("SlotDetails",true,false) != null,"ready slot opens calculation")
		await capture("slot_detail_%d" % resolution.x)
		await tap("workspace_close")
		check(screen.battle_view.preview_targets == [0], "slot touch identifies actual monster without a letter")
		check(screen.battle_view._enemy_text(0).begins_with(str(screen.model.s.enemies[0].name)), "tooltip starts with monster name without letter")
		check(not screen.magazine_view.compact_lines(screen.full_forecast, 0)[0].contains("A"), "firing rail uses damage without letter")
		await capture("ready_%d" % resolution.x)
		await tap("enemy_info_2")
		var details := screen.find_child("EnemyDetails", true, false)
		check(details != null and int(details.get_meta("enemy_index")) == 2, "touch opens correct enemy")
		if details == null:
			await capture("failed_touch_%d" % resolution.x)
			quit(1)
			return
		var legend := false
		for label in details.find_children("*", "Label", true, false):
			if label.text.contains("전기 약점"): legend = true
			check(not label.text.contains("예상 HP"), "detail has no projected HP")
		check(legend, "weakness icon has readable legend on mobile")
		await capture("detail_%d" % resolution.x)
		await tap("workspace_close")
		await tap("fire")
		check(screen.battle_view.enemies == screen.model.s.enemies, "HUD uses actual hit result")
		hud_fit()
		await tap("reload")
		hud_fit()
		await capture("reload_%d" % resolution.x)
		# Real standard-art bounds and multi-status cards, not only concept sprites.
		screen._debug_city("map")
		screen.campaign.enter(int(screen.campaign.choices()[0].id))
		screen.model = screen.campaign.model
		screen.model.s.enemies = [Data._enemy(["wall", 30, 3, 1, 14]), Data._enemy(["absorber", 24, 0, 1, 19]), Data._enemy(["stance", 28, 3, 1, 24]), Data._enemy(["spitter", 18, 0, 0, 29])]
		screen.model.s.enemies[0].burn = 3
		screen.model.s.enemies[1].jammed = 1
		screen.model.s.reinforcements = []
		screen.model.s.encounter_total = 4
		screen.model.s.deployed = 4
		screen.model.assign_opening_lanes()
		screen.redraw()
		await settle()
		hud_fit()
		await capture("statuses_%d" % resolution.x)
		# Random predictions must not reappear in the overhead layer.
		screen.model.s.gun = "scatter"
		screen.model.s.hand = ["arc", "pierce", "cool", "bore", "charge"]
		screen.hand_layout_key = ""
		screen.redraw()
		await settle()
		before = hud_pixels(0)
		await tap("load_arc")
		check(before == hud_pixels(0), "random forecast never changes overhead pixels")
		await touch_slot(0)
		check(screen.battle_view.preview_targets.size() == 4, "random shot marks all possible monsters")
		await capture("random_%d" % resolution.x)
		screen._debug_eavesback(true)
		screen.model.s.enemies[0].distance = 3
		screen.model.s.reinforcements = [Data._enemy(["runner", 12, 0, 2, 24]), Data._enemy(["wall", 24, 3, 1, 28])]
		screen.model.s.encounter_total = 6
		screen.redraw()
		await settle()
		hud_fit()
		await capture("distance_reserve_%d" % resolution.x)
		# Three-digit HP and simultaneous persistent/temporary statuses force wrapping.
		screen.model.s.enemies[1].hp = 128
		screen.model.s.enemies[1].max_hp = 128
		screen.model.s.enemies[1].weakness = "electric"
		screen.model.s.enemies[1].burn = 3
		screen.model.s.enemies[1].jammed = 2
		screen.redraw()
		await settle()
		hud_fit()
		check(screen.battle_view.enemy_status_layout(1).extra > 0, "crowded statuses wrap above health bar")
		await capture("wrapped_%d" % resolution.x)
	check(not screen.save_enabled, "player save remains isolated")
	screen.queue_free()
	await process_frame
	print("ENEMY HUD UI COMPLETE checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
