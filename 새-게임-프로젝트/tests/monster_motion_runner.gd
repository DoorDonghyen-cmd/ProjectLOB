extends "res://tests/frontend_ui_runner.gd"
const Motion = preload("res://redesign/monster_animation.gd")
var observing := false
var seen: Dictionary = {}
var captures: Dictionary = {}
var taking_capture := false
var ground_errors := 0

func observe() -> void:
	if not observing or not is_instance_valid(screen.battle_view): return
	var view = screen.battle_view
	var tag: String = view.monster_tag(0)
	seen[tag] = true
	if tag == "walk": seen["walk_frame_%d" % Motion.index_of(view.monster_frame(0))] = true
	var bounds: Rect2 = view.concept_rect(0)
	if absf(bounds.end.y-view.enemy_feet(0).y) > 0.02: ground_errors += 1
	var key := "%s_%d" % [tag,root.size.x]
	if tag == "walk" and Motion.index_of(view.monster_frame(0)) != 1: return
	if captures.has(key) or taking_capture: return
	taking_capture = true
	await RenderingServer.frame_post_draw
	if is_instance_valid(view) and view.monster_tag(0) == tag:
		root.get_texture().get_image().save_png(output.path_join(key+".png"))
		captures[key] = true
	taking_capture = false

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/monster_motion/"):
		quit(1); return
	output = OS.get_environment("QA_OUTPUT_DIR")
	DirAccess.make_dir_recursive_absolute(output)
	check(Motion.index_of(Motion.frame("walk",0.17)) == 0, "walk first authored duration")
	check(Motion.index_of(Motion.frame("walk",0.19)) == 1, "walk advances at exported 180ms")
	check(Motion.index_of(Motion.frame("walk",0.37)) == 0, "walk loops using exported timing")
	check(Motion.index_of(Motion.frame("hit",10)) == 2, "nonlooping hit holds last frame")
	process_frame.connect(observe)
	screen = load("res://redesign/main.tscn").instantiate()
	screen.save_enabled = false
	root.add_child(screen)
	await settle()
	for resolution in [Vector2i(1008,630), Vector2i(1280,800), Vector2i(1440,630)]:
		root.size = resolution
		screen._debug_eavesback()
		await settle()
		var view = screen.battle_view
		view.speed_scale = 0.85
		seen.clear()
		observing = true
		await settle()
		var m = screen.model
		m.load_round("pierce"); m.confirm()
		var before: Dictionary = m.s.duplicate(true)
		m.fire()
		var after: Dictionary = m.s.duplicate(true)
		var detail: Dictionary = m.s.history.back().detail
		await view.play_action(before,after,detail.results,detail.advance_events,false,detail.get("deployments",[]))
		await settle()
		check(seen.has("idle") and seen.has("hit") and seen.has("walk"), "actual fire replays idle hit walk")
		check(seen.has("walk_frame_0") and seen.has("walk_frame_1"), "both authored walking frames actually sampled")
		check(view.enemies == after.enemies and m.s == after, "animated replay preserves final enemies and model")
		check(view.monster_tag(0) == "idle", "normal action returns idle")
		for tag in ["idle","walk","hit","attack"]:
			var rect := Motion.visible_rect(Motion.frame(tag,0.2),view.enemy_feet(0))
			check(Rect2(Vector2.ZERO,view.size).encloses(rect), "pose fits battlefield: "+tag)
			check(rect.position.y > view.enemy_plaque(0).end.y, "pose clears HP: "+tag)
		# A genuine collision during a paid reload triggers the shove pose.
		m.s.enemies[0].distance = 1
		before = m.s.duplicate(true)
		m.reload_magazine()
		after = m.s.duplicate(true)
		check(after.phase == "lost", "contact fixture is a real model loss")
		await view.play_action(before,after,[],m.last_reload_detail.advance_events,true)
		await settle()
		check(seen.has("attack"), "contact event shows attack pose")
		check(view.visual_events.any(func(e): return e.kind == "monster_contact"), "contact explicitly recorded")
		check(view.attacking_indices.is_empty(), "contact pose resets")
		check(m.s == after and view.enemies == after.enemies, "contact replay leaves state untouched")
		observing = false
		for mode in ["reduced", "skip"]:
			view.reduced_feedback = mode == "reduced"
			view.fast_forward = mode == "skip"
			await view.play_action(before,after,[],m.last_reload_detail.advance_events,true)
			check(view.monster_tag(0) == "idle" and view.attacking_indices.is_empty(), "reset on "+mode)
			check(view.enemies == after.enemies and m.s == after, "outcome preserved on "+mode)
		view.reduced_feedback = false
		view.fast_forward = false
		view.sync(before)
		view.float_target = 0
		view.actor_hit_strength = 0.7
		view.enemies[0].hp = 0
		view.pulse = 0.8
		view.queue_redraw()
		await settle()
		check(view.creature_sprites[0].modulate.a < 0.3, "shader retains death fade modulation")
		await capture("defeat_%d" % resolution.x)
		view.sync(before)
		await settle()
		check(view.monster_tag(0) == "idle", "sync clears transient pose")
	check(ground_errors == 0, "all observed frames grounded")
	screen._debug_city("map")
	await settle()
	check(not screen.model.s.has("monster_animation"), "animation never serialized in gameplay state")
	screen.free()
	print("MONSTER MOTION COMPLETE checks=%d failures=%d" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
