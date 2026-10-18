extends "res://tests/ammo_expansion_ui_runner.gd"

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/actor_cohesion/"):
		quit(1)
		return
	var stage := OS.get_environment("QA_ART_STAGE")
	screen = load("res://redesign/main.tscn").instantiate()
	screen.save_enabled = false
	screen.presentation_speed = 0.03
	root.add_child(screen)
	await settle()
	for resolution in [Vector2i(1280, 900), Vector2i(1008, 630), Vector2i(1440, 630)]:
		root.size = resolution
		await combat(["bore", "spread", "pierce", "disrupt", "cool", "sequence"], "single", true)
		screen.model.s.enemies = [Data._enemy(["spitter", 20, 0, 0, 24])]
		screen.model.assign_opening_lanes()
		screen.model.s.encounter_total = 1
		screen.model.s.deployed = 1
		screen.redraw()
		await settle()
		fit()
		check(screen.battle_view.player_feet().y == screen.battle_view.enemy_feet(0).y, "hero and toad share ground")
		if stage == "after":
			check(screen.battle_view.toad_frame(screen.model.s.enemies[0]) == 0, "rest uses contracted throat")
			check(screen.battle_view.toad_rect(0).end.y == screen.battle_view.enemy_feet(0).y, "atlas frame is grounded")
			check(screen.battle_view.toad_rect(0).position.y > screen.battle_view.enemy_plaque(0).end.y, "toad body clears status plaque")
		await capture(stage + "_rest_%d" % resolution.x)
		# One actual turn fills the throat; the next launches its projectile.
		await tap("load_basic")
		await tap("confirm")
		await tap("fire")
		check(screen.model.s.enemies[0].ranged_left == 1, "actual preparation countdown")
		check(screen.last_presentation.shown_enemies == screen.model.s.enemies, "actor presentation matches preparation state")
		if stage == "after": check(screen.battle_view.toad_frame(screen.model.s.enemies[0]) == 1, "prepared turn uses inflated throat")
		await capture(stage + "_charged_%d" % resolution.x)
		await tap("reload")
		check(screen.model.s.projectiles.size() == 1, "actual launch creates projectile")
		if stage == "after": check(screen.battle_view.toad_frame(screen.model.s.enemies[0]) == 0, "launch returns throat to rest")
		await capture(stage + "_launched_%d" % resolution.x)
		fit()
		if stage == "after":
			var toad_hp_before: int = screen.model.s.enemies[0].hp
			await tap("load_basic")
			await tap("confirm")
			await tap("fire")
			check(preload("res://redesign/ranged.gd").active(screen.model.s).is_empty(), "public fire intercepts launched pressure shot")
			check(screen.model.s.enemies[0].hp == toad_hp_before, "interception hits the projectile rather than its owner")
			check(screen.battle_view.projectiles == screen.model.s.projectiles, "interception presentation matches actual threats")
	# Four live actors, status labels and hit feedback remain in their lanes.
	root.size = Vector2i(1008, 630)
	await combat(["disrupt", "pierce", "bore", "cool"], "amplifier", true)
	screen.model.s.enemies = [Data._enemy(["spitter", 30, 0, 0, 14]), Data._enemy(["wall", 25, 4, 1, 18]), Data._enemy(["spitter", 20, 0, 0, 24]), Data._enemy(["runner", 12, 0, 1, 30])]
	screen.model.assign_opening_lanes()
	screen.model.s.encounter_total = 4
	screen.model.s.deployed = 4
	screen.redraw()
	await settle()
	fit()
	await capture(stage + "_four_actors")
	await tap("load_disrupt")
	await tap("confirm")
	await tap("fire")
	check(screen.model.s.enemies[0].jammed == 1, "throat does not advance during interruption")
	check(screen.last_presentation.shown_enemies == screen.model.s.enemies, "new art preserves hit and interruption state")
	await capture(stage + "_interrupted")
	if stage == "after":
		# Every replacement must remain selectable and readable alongside its peers.
		for resolution in [Vector2i(1280, 900), Vector2i(1008, 630), Vector2i(1440, 630)]:
			root.size = resolution
			for kinds in [["runner", "wall", "evader", "spitter"], ["caster", "absorber", "stance", "spitter"]]:
				await combat(["pierce", "arc", "disrupt", "cool"], "single", true)
				screen.model.s.enemies = []
				for i in range(kinds.size()):
					screen.model.s.enemies.append(Data._enemy([kinds[i], 30, 0, 0, 14 + i * 5]))
				screen.model.assign_opening_lanes()
				screen.model.s.encounter_total = 4
				screen.model.s.deployed = 4
				screen.model.s.reinforcements = [Data._enemy(["spitter", 20, 0, 0, 28]), Data._enemy(["wall", 20, 3, 1, 28]), Data._enemy(["caster", 20, 0, 1, 28])]
				screen.redraw()
				await settle()
				fit()
				for i in range(kinds.size()):
					var view = screen.battle_view
					check(view.Pixel.texture(kinds[i]) != null, "reinforcement thumbnail exists " + kinds[i])
					var lift := 18.0 if kinds[i] in ["caster", "absorber", "stance"] else 0.0
					var anchor: Vector2 = view.enemy_feet(i) - Vector2(0, lift)
					var bounds: Rect2 = view.toad_rect(i) if kinds[i] == "spitter" else view.Pixel.sprite_rect(kinds[i], anchor)
					check(Rect2(Vector2.ZERO, view.size).encloses(bounds), "actor stays in battlefield " + kinds[i])
					check(bounds.position.y >= view.enemy_plaque(i).end.y, "actor clears plaque " + kinds[i])
					check(is_equal_approx(bounds.end.y, anchor.y), "actor keeps ground or hover anchor " + kinds[i])
					check(view._enemy_at(bounds.get_center()) == i, "actor inspection hit area " + kinds[i])
				await capture("after_roster_%s_%d" % [kinds[0], resolution.x])
	screen.queue_free()
	await process_frame
	print("ACTOR COHESION UI COMPLETE checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
