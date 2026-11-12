extends "res://tests/fire_heat_rules.gd"
const Cases=preload("res://tests/surface_fx_cases.gd")
const Surface=preload("res://redesign/surface_feedback.gd")
const VFX=preload("res://redesign/combat_vfx.gd")
const RangedData=preload("res://redesign/samples/ranged_sample_data.gd")

func check_rear_transfer() -> void:
	for id in ["arc", "arc_c", "arc_f", "spread", "spread_c", "spread_f"]:
		var is_arc: bool = id.begins_with("arc")
		for rear_alive in [true, false]:
			var model = Cases.make("arc" if is_arc else "transfer").model
			model.s.equipped_parts = []
			model.s.enemies.append(model.s.enemies[2].duplicate(true))
			for i in range(4):
				model.s.enemies[i].distance = [20, 30, 30, 40][i]
				model.s.enemies[i].burn = 4 if i == 1 else 0
			if not rear_alive: model.s.enemies[3].hp = 0
			var shot: Dictionary = model._shot(id, 1)
			var targets: Array = shot.secondary.map(func(event): return event.target)
			check(targets == ([3] if rear_alive else []), "only living enemies strictly behind the hit may receive " + id)
			check(model.s.enemies[0].hp == 500 and model.s.enemies[0].burn == 0 and model.s.enemies[2].hp == 500 and model.s.enemies[2].burn == 0, "front and same-distance enemies unaffected by " + id)
			if is_arc:
				check(shot.damage > 0, "arc direct damage is independent of transfer " + id)
			else:
				var moved := Content.effect_value(id, model.s) if rear_alive else 0
				check(shot.transferred == moved and model.s.enemies[1].burn == 4 - moved and model.s.enemies[3].burn == moved, "burn stacks are preserved for " + id)
	for id in ["arc_c", "arc_f"]:
		var model = Cases.make("arc").model
		model.s.enemies.append(model.s.enemies[2].duplicate(true))
		for i in range(4): model.s.enemies[i].distance = [20, 30, 42, 35][i]
		var shot: Dictionary = model._shot(id, 1)
		check(shot.secondary.map(func(event): return event.target) == [3, 2], "compressed arc transfers in rear distance order " + id)
	for kind in ["arc", "transfer"]:
		for target in [0, 2]:
			var model = Cases.make(kind).model
			model.s.gun = "scatter"
			model.s.equipped_parts = []
			for i in range(3):
				model.s.enemies[i].distance = 40 if i == 2 else 30
				model.s.enemies[i].burn = 4 if kind == "transfer" else 0
			var rng := RandomNumberGenerator.new()
			for seed_value in range(100):
				rng.seed = seed_value
				var state_before := rng.state
				if rng.randi_range(0, 2) != target: continue
				model.s.target_rng_state = str(state_before)
				break
			var preview := Forecast.analyze(model.s, true)
			check(preview.shots[0].targets.size() == 3, "scatter previews each living primary target " + kind)
			if kind == "transfer":
				check(is_equal_approx(preview.shots[0].effect_probability, 2.0 / 3.0), "scatter forecasts no burn transfer when the last enemy is hit")
			var shot: Dictionary = verify_fire(model).results[0]
			check(shot.target == target and shot.secondary.map(func(event): return event.target) == ([2] if target == 0 else []), "scatter follows the actual hit distance " + kind)
	for enemy_in_front in [true, false]:
		var model = Model.new()
		RangedData.seed_model(model, 1)
		if enemy_in_front: model.s.enemies[0].distance = 6
		check(model.load_round("arc") and model.confirm(), "projectile fixture loads a real arc round")
		var shot: Dictionary = verify_fire(model).results[0]
		check(shot.get("intercept", false) != enemy_in_front and shot.secondary.map(func(event): return event.target) == ([1] if enemy_in_front else [0]), "arc skips projectiles as a destination but still chains on a direct intercept")

func run() -> void:
	output=OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\","/").contains("/qa_runtime/surface_fx_20261106/"):quit(2);return
	check_rear_transfer()
	var profiles:Dictionary={}
	for kind in Cases.SPECS:
		var c=Cases.make(kind);var detail:=verify_fire(c.model);var packet:Dictionary=detail.results[0]
		var before:=JSON.stringify(packet);var profile:=Surface.resolve(packet)
		check(JSON.stringify(packet)==before,"surface mapping is read only "+kind);profiles[kind]=profile
		match kind:
			"plain":check(profile.contact and not profile.metal and not profile.shield,"unarmored contact")
			"metal":check(profile.metal,"actual armor contact")
			"chips":check(profile.chips,"only actual armor removal emits chips")
			"shield":check(profile.shield and not profile.broken and not profile.contact,"shield catches the complete hit")
			"shield_break","power_shield":check(profile.shield and profile.broken and not profile.contact,"broken shield is not multiplied HP damage")
			"partial":check(profile.shield and profile.contact,"mixed blocked and HP hits preserve both reactions")
			"fire":check(profile.fire and not packet.fire_zones.is_empty(),"actual ignition and floor interval")
			"arc":check(not packet.secondary.is_empty(),"actual arc follow-ups exist")
			"transfer":
				check(not packet.secondary.is_empty() and packet.secondary[0].damage==0,"burn moves stacks without inventing damage")
				check(Surface.resolve(packet.secondary[0],"burn_transfer").transfer,"actual moved fire uses ember transport")
			"support":check(not profile.contact and not profile.shield and not profile.fire,"preparation has no attack burst")
		for event in detail.advance_events:
			if event.kind=="burn":check(Surface.resolve(event,"burn").burn,"each real burn tick owns its visual pulse")
	for start in [Vector2(10,20),Vector2(120,50)]:
		for finish in [start,Vector2(30,40),Vector2(600,20)]:
			check(VFX.ember_point(start,finish,0).is_equal_approx(start) and VFX.ember_point(start,finish,1).is_equal_approx(finish),"embers preserve actual source/destination")
			check(VFX.arc_points(start,finish,0.2)[0].is_equal_approx(start.snapped(Vector2(2,2))),"arc begins at actual source")
	for width in [0,1,64,600,5000]:
		var tiles:=Surface.zone_layout(12,12+width,200)
		check(tiles.size()<=14,"floor fire has bounded draw count")
		for point in tiles:check(point.x>=12 and point.x<=12+width,"flames stay inside actual interval")
	for spec in [[Surface.SHIELD,Vector2i(740,520),Vector2i(148,104),23],[Surface.METAL,Vector2i(760,600),Vector2i(152,100),29]]:
		var image:Image=spec[0].get_image();check(image.get_size()==spec[1],"compact baked surface atlas")
		var index:int=spec[3]-1
		var last:=image.get_region(Rect2i(Vector2i(index%5,index/5)*spec[2],spec[2]))
		check(last.get_used_rect().size==Vector2i.ZERO,"one-shot surface ends transparent")
	FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"profiles":profiles},"  "))
	print("SURFACE FX RULES COMPLETE checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
