extends SceneTree

const Campaign = preload("res://redesign/campaign.gd")
const Screen = preload("res://redesign/main.tscn")
const IDS = ["work", "carrier", "scout", "heatworker", "hoist", "recovery", "expedition"]
const FOLDER = "/combat_outfit_blocks_20261107/"

class Board extends Node2D:
	const FONT = preload("res://assets/fonts/NeoDunggeunmoPro-Regular.ttf")
	const NAMES = ["기본 작업복", "운반복", "정찰복", "방열복", "인양 장구", "회수 장구", "원정복"]
	const CROP = Rect2(67, 450, 126, 120)
	var frames: Array[ImageTexture] = []
	var states := ["데드볼트 조준", "데드볼트 재장전", "스파이크 조준"]
	var style := "E"

	func extent() -> Vector2i:
		return Vector2i(1170, 108 + states.size() * 128)

	func _draw() -> void:
		var ink := Color("#e5d8c0")
		var sub := Color("#a8a39a")
		draw_rect(Rect2(Vector2.ZERO, Vector2(extent())), Color("#15191b"))
		draw_string(FONT, Vector2(23, 33), "전투 복장 7종  /  운반복 %s안 적용" % style, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, ink)
		draw_string(FONT, Vector2(23, 59), "주거구 · Godot 전투 화면에서 같은 크기로 비교", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, sub)
		for row in range(states.size()):
			var y := 98 + row * 128
			draw_string(FONT, Vector2(23, y + 64), states[row], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, sub)
			for col in range(NAMES.size()):
				var x := 180 + col * 138
				if row == 0:
					draw_string(FONT, Vector2(x, 91), NAMES[col], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ink)
				draw_texture_rect_region(frames[row * NAMES.size() + col], Rect2(Vector2(x, y), CROP.size), CROP)

var host: Control
var output := OS.get_environment("OUTFIT_STYLE_REPORT")
var use_grid := OS.get_environment("OUTFIT_STYLE_GRID") == "1"

func _initialize() -> void:
	run.call_deferred()

func settle() -> void:
	for index in range(5):
		await process_frame
	await RenderingServer.frame_post_draw

func mount(outfit: String, gun: String) -> Control:
	if is_instance_valid(host):
		host.free()
	var campaign = Campaign.new()
	campaign.start(gun, 17, 0, "balanced", 4, outfit, true)
	if not campaign.advance_departure(true) or not campaign.enter(101):
		return null
	host = Screen.instantiate()
	host.save_enabled = false
	root.add_child(host)
	host.campaign = campaign
	host.model = campaign.model
	host.page = "run"
	host.redraw()
	var battle: Control = host.campaign_hud.board
	battle.reduced_feedback = true
	battle.set_process(false)
	battle._update_weapon_actor()
	battle.weapon_viewport.get_node("Actor").use_outfit_grid = use_grid
	battle.weapon_viewport.get_node("Actor").queue_redraw()
	return battle

func actor_matches(battle: Control, outfit: String, gun: String, pose: String) -> bool:
	if battle == null:
		return false
	var actor: Node2D = battle.weapon_viewport.get_node("Actor")
	return actor.outfit_id == outfit and actor.gun_id == gun and actor.pose_id == pose and actor.body_texture().resource_path.contains(FOLDER) and actor.outfit_grid_region().has_area() == use_grid

func run() -> void:
	if output.is_empty() or not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/combat_outfit_style_20261107/"):
		quit(2)
		return
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_factor = 1
	root.size = Vector2i(1280, 800)
	var combat_images: Array[ImageTexture] = []
	var recoil_images: Array[ImageTexture] = []
	var reload_images: Array[ImageTexture] = []
	var pistol_images: Array[ImageTexture] = []
	for id in IDS:
		var battle := mount(id, "deadbolt")
		await settle()
		if not actor_matches(battle, id, "deadbolt", "aim"):
			push_error("Long aim source mismatch: " + id)
			quit(3)
			return
		var shot := root.get_texture().get_image()
		combat_images.append(ImageTexture.create_from_image(shot))
		if id in ["carrier", "heatworker"]:
			if shot.save_png(output.path_join("battle_" + id + ".png")) != OK:
				quit(4)
				return
		if use_grid:
			battle.reduced_feedback = false
			battle.hero_action = "fire"
			battle.flash = 0.65
			battle._update_weapon_actor()
			battle.queue_redraw()
			await settle()
			if not actor_matches(battle, id, "deadbolt", "recoil"):
				push_error("Long recoil source mismatch: " + id)
				quit(9)
				return
			recoil_images.append(ImageTexture.create_from_image(root.get_texture().get_image()))
			battle.flash = 0.0
			battle.reduced_feedback = true
		battle.hero_action = "reload"
		battle.hero_reload_progress = 0.65
		battle._update_weapon_actor()
		battle.queue_redraw()
		await settle()
		if not actor_matches(battle, id, "deadbolt", "reload_seat"):
			push_error("Long reload source mismatch: " + id)
			quit(5)
			return
		reload_images.append(ImageTexture.create_from_image(root.get_texture().get_image()))
		battle = mount(id, "amplifier")
		await settle()
		if not actor_matches(battle, id, "amplifier", "aim"):
			push_error("Pistol aim source mismatch: " + id)
			quit(6)
			return
		pistol_images.append(ImageTexture.create_from_image(root.get_texture().get_image()))

	root.size = Vector2i(1170, 540)
	var mobile_battle := mount("expedition", "single")
	await settle()
	if not actor_matches(mobile_battle, "expedition", "single", "aim"):
		quit(7)
		return
	if root.get_texture().get_image().save_png(output.path_join("battle_expedition_1170x540.png")) != OK:
		quit(8)
		return
	var sheet := SubViewport.new()
	var board := Board.new()
	if use_grid:
		board.style = "G"
		board.states.insert(1, "데드볼트 반동")
	board.frames = combat_images + recoil_images + reload_images + pistol_images
	sheet.size = board.extent()
	sheet.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(sheet)
	sheet.add_child(board)
	sheet.render_target_update_mode = SubViewport.UPDATE_ONCE
	await settle()
	var result := sheet.get_texture().get_image().save_png(output.path_join("outfits.png"))
	print("OUTFIT STYLE CAPTURE shots=", board.frames.size(), " result=", result)
	quit(result)
