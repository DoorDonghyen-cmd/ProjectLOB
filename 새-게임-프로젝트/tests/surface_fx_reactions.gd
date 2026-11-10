extends "res://tests/campaign_magazine_ui.gd"

const Cases = preload("res://tests/surface_fx_cases.gd")
var watching := false
var label := ""
var frames := {}
var last_move := false
var held_clock := -1.0
var held_frames := 0

func marker_pixels(board) -> int:
	var foot: Vector2 = board.enemy_feet(0)
	var transform: Transform2D = board.get_global_transform_with_canvas() * board.finish_camera()
	var rect := Rect2i(transform * Rect2(foot + Vector2(-33, 4), Vector2(66, 10)))
	var image := root.get_texture().get_image()
	rect = rect.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	var count := 0
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if image.get_pixel(x, y).is_equal_approx(board.SLOW_MARK): count += 1
	return count

func record(key: String) -> void:
	frames[key] = root.get_texture().get_image()

func post_draw() -> void:
	if not watching or not is_instance_valid(host.campaign_hud): return
	var board = host.campaign_hud.board
	if board.finish_active and not board.bullet.is_empty() and not frames.has("finish_approach"):
		check(board.damage_popups.is_empty(), "terminal camera starts before damage is shown")
		record("finish_approach")
	if board.hit_stop_active:
		held_frames += 1
		if held_clock < 0.0: held_clock = board.actor_clock
		check(is_equal_approx(board.actor_clock, held_clock) and board.visual_clock_scale() == 0.0, "hit stop freezes the battlefield clock")
		check(is_equal_approx(Engine.time_scale, 1.0), "hit stop leaves engine time alone")
		if not frames.has("hold"): record("hold")
	if board.float_target == 0 and board.pulse < 0.25 and not frames.has("impact"):
		var offset: Vector2 = board._actor_offset(0)
		if board.reduced_feedback: check(offset == Vector2.ZERO and board.stagger_target < 0, "instant feedback skips the body reaction")
		elif label == "slow": check(offset.y > 0.0 and board.stagger_target == 0, "slow application has a distinct stagger even without HP damage")
		elif label == "plain": check(offset.x > 0.0 and offset.y == 0.0, "plain impact has a horizontal flinch")
		elif label == "power_shield": check(offset == Vector2.ZERO, "blocked damage does not flinch the enemy")
		elif label == "finish": check(board.finish_active and board.finish_camera().get_scale().x > 1.0, "finisher keeps its own zoom and impact")
		record("impact")
	if last_move and board.moving_indices.has(0) and board.reload_progress > 0.25 and not frames.has("last_move"):
		check(int(board.enemies[0].slow_left) == 1 and marker_pixels(board) >= 8, "marker is drawn throughout the final slowed move")
		record("last_move")

func exercise(kind: String, resolution: Vector2i, reduced: bool = false) -> void:
	root.size = resolution
	label = kind
	frames.clear()
	held_clock = -1.0
	held_frames = 0
	last_move = false
	var campaign = Cases.make("multiply" if kind == "finish" else kind)
	if kind == "finish":
		campaign.model.s.enemies.resize(1)
		campaign.model.s.enemies[0].hp = 1
		campaign.model.s.encounter_total = 1
		campaign.model.s.deployed = 1
	for index in range(campaign.model.s.enemies.size()):
		campaign.model.s.enemies[index].distance = 23 + index * 8
		campaign.model.s.enemies[index].speed = 4
	await mount(campaign)
	host.save_enabled = false
	var board = host.campaign_hud.board
	board.speed_scale = 1.0
	board.reduced_feedback = reduced
	host.campaign_hud.select_budget(1)
	var oracle = Model.new()
	oracle.s = campaign.model.s.duplicate(true)
	check(oracle.fire(), "oracle accepts the same shot")
	watching = true
	await tap("Fire")
	check(canonical(campaign.model.s) == canonical(oracle.s), "replay preserves the full combat model and RNG")
	check(frames.has("impact"), "native impact was rendered")
	check(held_frames > 0 if kind == "multiply" and not reduced else held_frames == 0, "hit stop is reserved for strong damaging shots in normal motion")
	if kind == "finish":
		check(frames.has("finish_approach") and campaign.s.phase == "reward", "strong finisher flows into campaign reward without an extra hit stop")
	else:
		check(not board.hit_stop_active and board.stagger_target == -1 and board.visual_clock_scale() == 1.0, "impact motion resets after the shot")
	if kind == "slow":
		check(int(board.enemies[0].slow_left) == 1 and marker_pixels(board) >= 8, "settled slow remains visible under the target")
		record("slowed")
		last_move = true
		check(oracle.cool_magazine(), "oracle accepts the cooling action")
		await tap("Cool")
		check(frames.has("last_move"), "final slowed movement was rendered")
		check(int(board.enemies[0].slow_left) == 0 and marker_pixels(board) == 0, "marker disappears on expiry")
		check(canonical(campaign.model.s) == canonical(oracle.s), "slow expiry preserves model distance and RNG")
		record("expired")
	watching = false
	var variant := kind + ("_reduced" if reduced else "")
	for key in frames:
		frames[key].save_png(output.path_join(variant + "_" + key + ".png"))

func run() -> void:
	output = OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\", "/").contains("/qa_runtime/enemy_hit_feedback_20261108/"):
		quit(2)
		return
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_factor = 1
	RenderingServer.frame_post_draw.connect(post_draw)
	await exercise("plain", Vector2i(1280, 800))
	await exercise("multiply", Vector2i(1280, 800))
	await exercise("power_shield", Vector2i(1280, 800))
	await exercise("slow", Vector2i(1280, 800))
	await exercise("slow", Vector2i(1008, 454), true)
	await exercise("multiply", Vector2i(1008, 454), true)
	await exercise("finish", Vector2i(1008, 454))
	RenderingServer.frame_post_draw.disconnect(post_draw)
	if is_instance_valid(host): host.free()
	print("SURFACE FX REACTIONS COMPLETE checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
