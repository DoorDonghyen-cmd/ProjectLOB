extends SceneTree

const Campaign = preload("res://redesign/campaign.gd")
const Screen = preload("res://redesign/main.tscn")
const ActorScene = preload("res://redesign/weapon_actor.tscn")
const CELL = 2
const PALETTE = [
	Color("#181e20"), Color("#282b2c"), Color("#293640"), Color("#384750"), Color("#4a5758"),
	Color("#3f3930"), Color("#585044"), Color("#716552"), Color("#817163"), Color("#9a8068"),
	Color("#b49a7c"), Color("#624033"), Color("#8f4836"), Color("#aa6144"), Color("#875c38"),
	Color("#b1824b"), Color("#d8a665"), Color("#f2bb77"), Color("#f0deb3"), Color("#f8edd6"),
]

class WeaponOnly extends "res://redesign/weapon_actor.gd":
	func _draw() -> void:
		if is_instance_valid(weapon_layer_viewport):
			var extent := Vector2(weapon_layer_viewport.size) * weapon_pixel_step
			draw_texture_rect(weapon_layer_viewport.get_texture(), Rect2(Vector2.ZERO, extent), false)

class GridReadout extends "res://redesign/campaign_hud/line_readout.gd":
	var body: ImageTexture
	var hands: ImageTexture
	var grid: Rect2
	var weapon: Rect2

	func draw_player(foot: Vector2) -> void:
		view.Pixel.shadow(view, foot + Vector2(0, 1), 21 * view.actor_factor())
		view.draw_texture_rect(body, grid, false)
		view.draw_texture_rect(view.weapon_viewport.get_texture(), weapon, false)
		view.draw_texture_rect(hands, grid, false)

class Comparison extends Node2D:
	const FONT = preload("res://assets/fonts/NeoDunggeunmoPro-Regular.ttf")
	const SIZE = Vector2i(1000, 443)
	var e: ImageTexture
	var f: ImageTexture
	var palette: Array[Color]
	var contour := false

	func _draw() -> void:
		var ink := Color("#e8dac0")
		var muted := Color("#a8a392")
		draw_rect(Rect2(Vector2.ZERO, Vector2(SIZE)), Color("#15191a"))
		var title := "주거구 전투  /  캐릭터 외곽선 비교" if contour else "주거구 전투  /  도트 격자와 팔레트"
		draw_string(FONT, Vector2(28, 37), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, ink)
		draw_string(FONT, Vector2(28, 65), "Godot 1280 × 800   ·   같은 장면에서 2배 확대", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, muted)
		var titles := ["F  기존 외곽선", "G  외곽선 완화", "몬스터  /  기준"] if contour else ["E  현재 운반복", "F  고정 격자 + 팔레트", "몬스터  /  기준"]
		for index in range(3):
			var x := 28 + index * 322
			var crop := Rect2(929 if index == 2 else 62, 445, 150, 131)
			draw_string(FONT, Vector2(x, 101), titles[index], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, ink)
			draw_texture_rect_region(f if index == 1 else e, Rect2(x, 114, 300, 262), crop)
		var left := "고정 격자 · 기존 색" if contour else "부위별 도트 묶음"
		var middle := "바깥의 짙은 도트만 완화" if contour else "전투 2px 격자 · 사용 %d색" % palette.size()
		draw_string(FONT, Vector2(28, 405), left, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, muted)
		draw_string(FONT, Vector2(350, 405), middle, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, muted)
		draw_string(FONT, Vector2(672, 405), "같은 화면 · 같은 배율", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, muted)
		for index in range(palette.size()):
			draw_rect(Rect2(350 + index * 14, 416, 13, 13), palette[index])

var output := OS.get_environment("HERO_GRID_REPORT")
var contour_source := OS.get_environment("HERO_GRID_CONTOUR_SOURCE")
const SIDES := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

func _initialize() -> void:
	run.call_deferred()

func settle() -> void:
	for index in range(6):
		await process_frame
	await RenderingServer.frame_post_draw

func nearest(color: Color) -> int:
	var closest := 0
	var distance := INF
	for index in range(PALETTE.size()):
		var candidate: Color = PALETTE[index]
		var dr := color.r - candidate.r
		var dg := color.g - candidate.g
		var db := color.b - candidate.b
		var difference := dr * dr * 3.0 + dg * dg * 4.0 + db * db * 2.0
		if difference < distance:
			distance = difference
			closest = index
	return closest

func sample_source(point: Vector2, weapon: Rect2, viewport: Vector2, offset: Vector2, scale_value: float) -> Vector2:
	return ((point - weapon.position) * viewport / weapon.size - offset) / scale_value

func fill_grid(actor: Node2D, result: GridReadout, image: Image, viewport: Vector2) -> Dictionary:
	var frame: Dictionary = actor.frame_for(actor.outfit_id, actor.gun_id, actor.pose_id)
	var source: Rect2 = frame.source
	var offset: Vector2 = actor.FOOT - frame.foot * frame.scale
	var logical_size := Vector2i(result.grid.size) / CELL
	var body := Image.create_empty(logical_size.x, logical_size.y, false, Image.FORMAT_RGBA8)
	var hands := Image.create_empty(logical_size.x, logical_size.y, false, Image.FORMAT_RGBA8)
	var foreground: Array[Rect2] = actor.registered_hands()
	var used: Dictionary = {}
	for y in range(logical_size.y):
		for x in range(logical_size.x):
			var corner := result.grid.position + Vector2(x, y) * CELL
			var votes: Dictionary = {}
			var covered := 0
			var center := -1
			for dy in [0.33, 1.0, 1.67]:
				for dx in [0.33, 1.0, 1.67]:
					var relative := sample_source(corner + Vector2(dx, dy), result.weapon, viewport, offset, frame.scale)
					var point := relative + source.position
					if not source.has_point(point):
						continue
					var color := image.get_pixelv(Vector2i(point.floor()))
					if color.a < 0.5:
						continue
					var index := nearest(color)
					votes[index] = int(votes.get(index, 0)) + 1
					covered += 1
					if dx == 1.0 and dy == 1.0:
						center = index
			if covered < 5:
				continue
			var choice: int = center if center >= 0 else int(votes.keys()[0])
			for index: int in votes:
				if votes[index] > votes[choice]:
					choice = index
			body.set_pixel(x, y, PALETTE[choice])
			used[choice] = true
			var middle := sample_source(corner + Vector2.ONE, result.weapon, viewport, offset, frame.scale)
			for hand: Rect2 in foreground:
				if hand.has_point(middle):
					hands.set_pixel(x, y, PALETTE[choice])
					break
	result.body = ImageTexture.create_from_image(body)
	result.hands = ImageTexture.create_from_image(hands)
	return {"used": used, "body": body, "hands": hands}

func exterior_air(body: Image) -> Dictionary:
	var bounds := Rect2i(Vector2i.ZERO, body.get_size())
	var open: Array[Vector2i] = [Vector2i.ZERO]
	var seen := {Vector2i.ZERO: true}
	var cursor := 0
	while cursor < open.size():
		var point := open[cursor]
		cursor += 1
		for step: Vector2i in SIDES:
			var next := point + step
			if bounds.has_point(next) and not seen.has(next) and body.get_pixelv(next).a == 0.0:
				seen[next] = true
				open.append(next)
	return seen

func soften_exterior(body: Image, hands: Image) -> Dictionary:
	var air := exterior_air(body)
	var result := body.duplicate() as Image
	var bounds := Rect2i(Vector2i.ZERO, body.get_size())
	var boots := body.get_used_rect().end.y - 2
	var changed := 0
	for y in range(1, boots):
		for x in range(1, body.get_width() - 1):
			var point := Vector2i(x, y)
			var color := body.get_pixelv(point)
			if color.a == 0.0 or color.v > 0.18 or hands.get_pixelv(point).a > 0.0:
				continue
			var exposed := false
			for step: Vector2i in SIDES:
				exposed = exposed or air.has(point + step)
			if not exposed:
				continue
			var neighbor := Color.BLACK
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var candidate := point + Vector2i(dx, dy)
					if bounds.has_point(candidate):
						var sample := body.get_pixelv(candidate)
						if sample.a > 0.0 and sample.v > neighbor.v:
							neighbor = sample
			# Keep the rim in the same muted shadow range as the patrol monsters.
			var rim := Color("#303539")
			if neighbor.r > neighbor.b + 0.075:
				rim = Color("#3c3630")
			elif neighbor.b > neighbor.r + 0.045:
				rim = Color("#303a42")
			result.set_pixelv(point, rim)
			changed += 1
	return {"body": result, "changed": changed}

func run() -> void:
	if output.is_empty() or not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/hero_grid_20261108/"):
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
	board.weapon_viewport.get_node("Actor").use_outfit_grid = false
	board.weapon_viewport.get_node("Actor").queue_redraw()
	await settle()
	var state := JSON.stringify([campaign.s, campaign.model.s])
	var actor: Node2D = board.weapon_viewport.get_node("Actor")
	if actor.outfit_id != "carrier" or actor.gun_id != "deadbolt" or actor.pose_id != "aim":
		quit(4)
		return
	var e := root.get_texture().get_image()
	var trial := GridReadout.new(board)
	var foot: Vector2 = board.player_feet()
	var viewport := Vector2(board.weapon_viewport.size)
	var factor: float = board.character_scale() * actor.BODY_SCALE
	trial.weapon = Rect2((foot - actor.FOOT * factor).round(), (viewport * factor).round())
	var origin := (trial.weapon.position / CELL).floor() * CELL
	var end := (trial.weapon.end / CELL).ceil() * CELL
	trial.grid = Rect2(origin, end - origin)
	var transform := board.get_global_transform_with_canvas()
	if transform.get_scale() != Vector2.ONE or transform.origin != transform.origin.round():
		push_error("Comparison needs a native, pixel-aligned board")
		quit(5)
		return
	var comparison := Comparison.new()
	var body_cells: Image
	var hand_cells: Image
	var changed := 0
	if contour_source.is_empty():
		var source: Image = actor.body_texture().get_image()
		if source.is_compressed():
			source.decompress()
		var palette_result := fill_grid(actor, trial, source, viewport)
		body_cells = palette_result.body
		hand_cells = palette_result.hands
		for index in range(PALETTE.size()):
			if palette_result.used.has(index):
				comparison.palette.append(PALETTE[index])
	else:
		comparison.contour = true
		e = Image.load_from_file(contour_source.path_join("f_grid.png"))
		var original := Image.load_from_file(contour_source.path_join("f_body_cells.png"))
		hand_cells = Image.load_from_file(contour_source.path_join("f_hand_cells.png"))
		if e == null or original == null or hand_cells == null or original.get_size() * CELL != Vector2i(trial.grid.size) or hand_cells.get_size() != original.get_size():
			quit(8)
			return
		var rim := soften_exterior(original, hand_cells)
		body_cells = rim.body
		changed = rim.changed
		trial.body = ImageTexture.create_from_image(body_cells)
		trial.hands = ImageTexture.create_from_image(hand_cells)

	var replacement := ActorScene.instantiate() as SubViewport
	var placeholder: Node2D = replacement.get_node("Actor")
	var weapon := WeaponOnly.new()
	weapon.name = "Actor"
	weapon.material = placeholder.material
	weapon.texture_filter = placeholder.texture_filter
	placeholder.free()
	replacement.add_child(weapon)
	board.weapon_viewport.free()
	board.weapon_viewport = replacement
	board.add_child(replacement)
	board.line_readout = trial
	board._update_weapon_actor()
	board.queue_redraw()
	await settle()
	var f := root.get_texture().get_image()
	if JSON.stringify([campaign.s, campaign.model.s]) != state:
		quit(6)
		return
	var entries := [[f, "g_contour"], [body_cells, "g_body_cells"]] if comparison.contour else [[e, "e_current"], [f, "f_grid"], [body_cells, "f_body_cells"], [hand_cells, "f_hand_cells"]]
	for entry in entries:
		if entry[0].save_png(output.path_join(entry[1] + ".png")) != OK:
			quit(7)
			return
	comparison.e = ImageTexture.create_from_image(e)
	comparison.f = ImageTexture.create_from_image(f)
	var sheet := SubViewport.new()
	sheet.size = Comparison.SIZE
	sheet.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(sheet)
	sheet.add_child(comparison)
	sheet.render_target_update_mode = SubViewport.UPDATE_ONCE
	await settle()
	var result := sheet.get_texture().get_image().save_png(output.path_join("comparison.png"))
	print("HERO GRID COMPLETE colors=", comparison.palette.size(), " contour_cells=", changed, " used=", body_cells.get_used_rect(),
		" grid_screen_origin=", transform * trial.grid.position, " weapon_screen_rect=", transform * trial.weapon, " result=", result)
	quit(result)
