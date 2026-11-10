extends SceneTree

const Campaign = preload("res://redesign/campaign.gd")
const Screen = preload("res://redesign/main.tscn")
const ActorScene = preload("res://redesign/weapon_actor.tscn")

class StudyActor extends "res://redesign/weapon_actor.gd":
	var study_body: Texture2D

	func body_texture() -> Texture2D:
		if outfit_id == "carrier" and gun_id == "deadbolt" and pose_id == "aim" and study_body:
			return study_body
		return super.body_texture()

class Comparison extends Node2D:
	const FONT = preload("res://assets/fonts/NeoDunggeunmoPro-Regular.ttf")
	const CROP = Rect2(65, 423, 138, 153)
	const TITLES = ["A  현재", "B  윤곽·명암", "C  도트 묶음", "D  PixelOE"]
	const NOTES = ["기준 화면", "짙은 선과 밝은 면 완화", "기존 색을 큰 면으로", "48색 · 윤곽 추가 없음"]
	var shots: Array[ImageTexture] = []
	var full_scene := false
	var material_focus := false

	func _draw() -> void:
		var paper := Color("#ddd2bd")
		var quiet := Color("#a29e90")
		if full_scene:
			draw_rect(Rect2(0, 0, 1316, 876), Color("#131717"))
			for index in range(4):
				var origin := Vector2(12 + (index % 2) * 652, 14 + floori(index / 2.0) * 432)
				draw_string(FONT, origin + Vector2(0, 15), TITLES[index], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, paper)
				draw_texture_rect(shots[index], Rect2(origin + Vector2(0, 24), Vector2(640, 400)), false)
			return
		draw_rect(Rect2(0, 0, 1184, 396 if material_focus else 440), Color("#131717"))
		var heading := "주거구 전투  /  도트 색면 비교" if material_focus else "주거구 전투  /  운반복 조준 비교"
		var caption := "Godot 1280 × 800   ·   같은 전투 화면을 2배 확대" if material_focus else "Godot 1280 × 800   ·   같은 위치를 2배 확대"
		draw_string(FONT, Vector2(24, 34), heading, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, paper)
		draw_string(FONT, Vector2(24, 60), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, quiet)
		var titles := ["A  현재", "D  PixelOE", "E  부위별 색면", "몬스터  /  기준"] if material_focus else TITLES
		var notes := ["기준 화면", "이전 PixelOE 전체 보정", "장비·옷감만 크게 묶음", "같은 화면 · 같은 배율"] if material_focus else NOTES
		var shot_indices := [0, 3, 4, 0] if material_focus else [0, 1, 2, 3]
		for index in range(4):
			var x := 24 + index * 288
			var crop := CROP
			if material_focus:
				crop = Rect2(932 if index == 3 else 65, 445, 138, 131)
			draw_string(FONT, Vector2(x, 94), titles[index], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, paper)
			draw_texture_rect_region(shots[shot_indices[index]], Rect2(Vector2(x, 106), crop.size * 2), crop)
			draw_string(FONT, Vector2(x, 125 + crop.size.y * 2), notes[index], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, quiet)

var report := OS.get_environment("HERO_STUDY_REPORT")
var inputs := OS.get_environment("HERO_STUDY_INPUTS")

func _initialize() -> void:
	run.call_deferred()

func wait_render() -> void:
	for index in range(6):
		await process_frame
	await RenderingServer.frame_post_draw

func run() -> void:
	if report.is_empty() or inputs.is_empty():
		quit(2)
		return
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_factor = 1
	root.size = Vector2i(1280, 800)
	var campaign = Campaign.new()
	campaign.start("deadbolt", 17, 0, "balanced", 4, "carrier", true)
	if not campaign.advance_departure(true) or not campaign.enter(101):
		quit(3)
		return
	var host = Screen.instantiate()
	host.save_enabled = false
	root.add_child(host)
	host.campaign = campaign
	host.model = campaign.model
	host.page = "run"
	host.redraw()
	var board: Control = host.campaign_hud.board
	board.reduced_feedback = true
	board.set_process(false)
	board._update_weapon_actor()
	await wait_render()

	var state := JSON.stringify([campaign.s, campaign.model.s])
	var native_actor: Node2D = board.weapon_viewport.get_node("Actor")
	if native_actor.outfit_id != "carrier" or native_actor.gun_id != "deadbolt" or native_actor.pose_id != "aim":
		push_error("Study needs the registered carrier / deadbolt / aim pose")
		quit(4)
		return
	var comparison := Comparison.new()
	if not take_shot("a", comparison):
		quit(5)
		return

	var study_view: SubViewport = ActorScene.instantiate()
	var placeholder: Node2D = study_view.get_node("Actor")
	var study_actor := StudyActor.new()
	study_actor.name = "Actor"
	study_actor.material = placeholder.material
	study_actor.texture_filter = placeholder.texture_filter
	placeholder.free()
	study_view.add_child(study_actor)
	board.weapon_viewport.free()
	board.weapon_viewport = study_view
	board.add_child(study_view)
	board._update_weapon_actor()

	for id in ["b", "c", "d", "e"]:
		var body := Image.load_from_file(inputs.path_join("body_" + id + ".png"))
		if body == null:
			quit(6)
			return
		study_actor.study_body = ImageTexture.create_from_image(body)
		study_actor.queue_redraw()
		study_view.render_target_update_mode = SubViewport.UPDATE_ONCE
		board.queue_redraw()
		await wait_render()
		if not take_shot(id, comparison):
			quit(7)
			return

	if JSON.stringify([campaign.s, campaign.model.s]) != state:
		push_error("Campaign or combat state changed during the comparison")
		quit(8)
		return
	var sheet := SubViewport.new()
	sheet.size = Vector2i(1184, 440)
	sheet.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(sheet)
	sheet.add_child(comparison)
	sheet.render_target_update_mode = SubViewport.UPDATE_ONCE
	await wait_render()
	var result := sheet.get_texture().get_image().save_png(report.path_join("comparison.png"))
	if result == OK:
		comparison.full_scene = true
		sheet.size = Vector2i(1316, 876)
		comparison.queue_redraw()
		sheet.render_target_update_mode = SubViewport.UPDATE_ONCE
		await wait_render()
		result = sheet.get_texture().get_image().save_png(report.path_join("full_comparison.png"))
	if result == OK:
		comparison.full_scene = false
		comparison.material_focus = true
		sheet.size = Vector2i(1184, 396)
		comparison.queue_redraw()
		sheet.render_target_update_mode = SubViewport.UPDATE_ONCE
		await wait_render()
		result = sheet.get_texture().get_image().save_png(report.path_join("material_comparison.png"))
	print("HERO STYLE COMPARE COMPLETE result=", result)
	quit(result)

func take_shot(id: String, comparison: Comparison) -> bool:
	var shot := root.get_texture().get_image()
	if shot.get_size() != Vector2i(1280, 800):
		push_error("Unexpected render size: %s" % shot.get_size())
		return false
	comparison.shots.append(ImageTexture.create_from_image(shot))
	return shot.save_png(report.path_join(id + ".png")) == OK
