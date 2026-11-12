extends SceneTree
## Standalone layout draft. Local selections only, with no campaign or save access.

const FontArt = preload("res://redesign/combat_pixel_font.tres")
const PrimaryTheme = preload("res://redesign/ui/dark_primary.tres")
const Room = preload("res://assets/art/service_background_grouped_20261025/workshop.png")
const WeaponArt = preload("res://redesign/weapon_art.gd")
const PartArt = preload("res://redesign/part_icon_art.gd")
const Data = preload("res://redesign/content.gd")

class PartGlyph extends Control:
	var part := ""
	var factor := 1.0

	func _draw() -> void:
		PartArt.draw(self, part, size * 0.5, Color("a38b61"), factor, false)

class Bench extends Control:
	const INK := Color("e8e0cb")
	const MUTED := Color("aaa391")
	const BRASS := Color("d4b57c")
	const LOSS := Color("d9a38b")
	const LINE := Color("423b2e")
	const FIT := Color("766445")
	const FIXTURE := {"gun": "single", "combat_revision": Data.COMBAT_REVISION, "growth_structure_version": 1}
	const STOCK := ["third_striker", "duplex", "reclaimer", "igniter"]
	const PANEL := Color("161511")
	var mounted: Array[String] = ["opening", "capacitor", "radiator", "rammer", "lens"]
	var inventory: Array[String] = []
	var incoming := "third_striker"
	var slot := 2
	var done := ""
	var compact := false
	var border := 0.0
	var header_h := 0.0
	var right := Rect2()
	var bench := Rect2()
	var tray := Rect2()
	var shelf := Rect2()
	var detail_y := 0.0
	var footer_y := 0.0
	var mat_light: GradientTexture2D
	var gun: Texture2D
	var shadow: ShaderMaterial
	var foreground: ShaderMaterial
	var dynamic: Control
	var selection_scroll := 0

	func _ready() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		inventory.assign(STOCK)
		var surface := Gradient.new()
		surface.colors = PackedColorArray([Color("3b3022"), Color("28251f"), Color("201e19")])
		surface.offsets = PackedFloat32Array([0.0, 0.62, 1.0])
		mat_light = GradientTexture2D.new()
		mat_light.gradient = surface
		mat_light.width = 320
		mat_light.height = 160
		mat_light.fill = GradientTexture2D.FILL_RADIAL
		mat_light.fill_from = Vector2(0.52, 0.33)
		mat_light.fill_to = Vector2(1.0, 0.89)
		gun = WeaponArt.atlas("single")
		foreground = ShaderMaterial.new()
		foreground.shader = preload("res://redesign/monster_alpha_cutout.gdshader")
		foreground.set_shader_parameter("source_pixel_step", 12.0)
		foreground.set_shader_parameter("shadow_lift", 0.58)
		shadow = foreground.duplicate()
		resized.connect(rebuild)
		rebuild()

	func point(x: float, y: float, w: float, h: float) -> Rect2:
		return Rect2(x, y, w, h)

	func rebuild() -> void:
		if size.x < 400.0 or size.y < 300.0:
			return
		compact = size.y < 650.0
		border = 32.0 if not compact else 24.0
		header_h = 67.0 if not compact else 60.0
		var top := header_h + (24.0 if not compact else 12.0)
		var inner_w := size.x - 2.0 * border
		var gap := 22.0 if not compact else 16.0
		var inspect_w := clampf(roundf(inner_w * 0.365), 342.0, 440.0)
		bench = point(border, top, inner_w - inspect_w - gap, size.y - top - border)
		right = point(bench.end.x + gap, top, inspect_w, bench.size.y)
		var tray_h := 114.0 if not compact else 96.0
		tray = point(bench.position.x, bench.end.y - tray_h, bench.size.x, tray_h)
		var rows_h := 196.0 if not compact else 140.0
		shelf = point(right.position.x + 16, right.position.y + 42, right.size.x - 32, rows_h)
		detail_y = shelf.end.y + (40.0 if not compact else 14.0)
		footer_y = right.end.y - (70.0 if not compact else 56.0)
		build_controls()
		queue_redraw()

	func box(bounds: Rect2, fill: Color, stroke: Color = Color.TRANSPARENT) -> void:
		draw_rect(bounds, fill)
		if stroke.a > 0.0:
			draw_rect(bounds.grow(-0.5), stroke, false, 1.0)

	func text(at: Vector2, message: String, px: int = 16, color: Color = INK) -> void:
		draw_string(FontArt, at.round() + Vector2(0, roundf(FontArt.get_ascent(px))), message, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px, color)

	func align_right(x: float, y: float, message: String, color: Color = MUTED) -> void:
		var extent := FontArt.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16)
		text(Vector2(x - extent.x, y), message, 16, color)

	func align_center(x: float, y: float, message: String, color: Color = INK) -> void:
		var extent := FontArt.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16)
		text(Vector2(x - extent.x * 0.5, y), message, 16, color)

	func name_of(part: String) -> String:
		return str(Data.part_spec(part, FIXTURE).name)

	func _draw() -> void:
		if bench.size == Vector2.ZERO:
			return
		var fill_scale := maxf(size.x / Room.get_width(), size.y / Room.get_height())
		var room_size := Room.get_size() * fill_scale
		var room_x := clampf(bench.get_center().x - room_size.x * 0.45, size.x - room_size.x, 0.0)
		draw_texture_rect(Room, Rect2(Vector2(roundf(room_x), 0), room_size.round()), false)
		box(Rect2(Vector2.ZERO, size), Color(0.047, 0.038, 0.026, 0.64))
		box(point(0, 0, size.x, header_h), Color("151611"))
		box(point(0, header_h - 1, size.x, 1), LINE)
		text(Vector2(border, 17 if not compact else 14), "빌드 작업실", 32)
		var tab_x := border + 218
		text(Vector2(tab_x, 24 if not compact else 21), "파츠 구성", 16, BRASS)
		box(point(tab_x - 10, header_h - 4, 94, 2), FIT)
		text(Vector2(tab_x + 118, 24 if not compact else 21), "탄환 덱", 16, MUTED)
		draw_bench()
		draw_inspector()

	func draw_bench() -> void:
		var title_pos := bench.position + Vector2(14, 6)
		box(point(bench.position.x, bench.position.y, bench.size.x, 52), Color(0.06, 0.055, 0.043, 0.83))
		text(title_pos, "리벳", 32)
		text(title_pos + Vector2(94, 9), "사격 1~2발 · 탄창 7칸", 16, MUTED)
		var mat_top := bench.position.y + (100 if not compact else 64)
		var mat_end := tray.position.y - (24 if not compact else 14)
		var mat := point(bench.position.x, mat_top, bench.size.x, mat_end - mat_top)
		box(mat.grow(3), Color("11110f"))
		draw_texture_rect(mat_light, mat, false)
		draw_rect(mat.grow(-0.5), Color("61513a"), false)
		box(point(mat.position.x + 4, mat.position.y + 4, mat.size.x - 8, 1), Color("4a3d2c"))
		box(point(mat.position.x + 4, mat.end.y - 4, mat.size.x - 8, 2), Color("151510"))
		draw_corner(mat.position + Vector2(13, 13), Vector2(1, 1))
		draw_corner(Vector2(mat.end.x - 13, mat.position.y + 13), Vector2(-1, 1))
		draw_corner(Vector2(mat.position.x + 13, mat.end.y - 13), Vector2(1, -1))
		draw_corner(mat.end - Vector2(13, 13), Vector2(-1, -1))
		for y in range(24, int(mat.size.y) - 20, 6):
			for x in range(24, int(mat.size.x) - 20, 7):
				if (x * 7 + y * 17) % 11 < 4:
					box(point(mat.position.x + x, mat.position.y + y, 1, 1), Color(0.73, 0.63, 0.46, 0.085))
		box(tray, Color("181814"), LINE)
		text(tray.position + Vector2(12, 8), "장착 파츠", 16, INK)
		align_right(tray.end.x - 12, tray.position.y + 8, "%d / 5" % mounted.size())

	func draw_corner(at: Vector2, facing: Vector2) -> void:
		var metal := Color("736147")
		draw_line(at, at + Vector2(facing.x * 12, 0), metal)
		draw_line(at, at + Vector2(0, facing.y * 12), metal)

	func draw_inspector() -> void:
		if compact:
			box(right, PANEL, LINE)
			box(point(right.position.x + 16, detail_y - 7, right.size.x - 32, 1), LINE)
		else:
			box(point(right.position.x, right.position.y, right.size.x, shelf.end.y + 12 - right.position.y), PANEL, LINE)
			box(point(right.position.x, detail_y - 11, right.size.x, right.end.y - detail_y + 11), PANEL, LINE)
		text(right.position + Vector2(17, 13), "보유 파츠", 16)
		align_right(right.end.x - 17, right.position.y + 13, "%d개" % inventory.size())
		var x := right.position.x + 17
		if not done.is_empty():
			text(Vector2(x, detail_y + 5), "장착 완료", 16, BRASS)
			text(Vector2(x, detail_y + 38), name_of(done), 32)
			return
		text(Vector2(x, detail_y + 5), "교체 미리보기", 16, BRASS)
		var chosen := name_of(incoming)
		if slot < 0:
			text(Vector2(x, detail_y + 37), chosen, 32)
			text(Vector2(x, detail_y + 79), "교체할 장착 칸을 고르세요.", 16, MUTED)
			return
		var compare_y := detail_y + 40
		if compact:
			text(Vector2(x, compare_y), name_of(mounted[slot]), 16, MUTED)
			text(Vector2(x + 124, compare_y), "→", 16, BRASS)
			text(Vector2(x + 150, compare_y), chosen, 16)
		else:
			var cell_w := floorf((right.size.x - 72.0) * 0.5)
			var removed := point(x, compare_y, cell_w, 100)
			var added := point(right.end.x - 17 - cell_w, compare_y, cell_w, 100)
			draw_compare_part(removed, mounted[slot], false)
			draw_compare_part(added, incoming, true)
			align_center(right.get_center().x, compare_y + 41, "→", BRASS)
		var rule_y := detail_y + (69.0 if compact else 155.0)
		box(point(x, rule_y - 2, right.size.x - 34, 1), LINE)
		if incoming == "third_striker":
			for i in range(3):
				var shell := Vector2(x + 4 + i * 24, rule_y + 16)
				box(Rect2(shell + Vector2(3, 0), Vector2(4, 2)), BRASS if i == 2 else FIT)
				box(Rect2(shell + Vector2(2, 2), Vector2(6, 13)), BRASS if i == 2 else FIT)
				box(Rect2(shell + Vector2(1, 16), Vector2(8, 2)), BRASS if i == 2 else FIT)
			text(Vector2(x + 82, rule_y + 17), "탄창의 세 번째 탄 직접 피해 ×3", 16, INK)
		else:
			text(Vector2(x, rule_y + 17), str(Data.part_spec(incoming, FIXTURE).upside), 16)
		var old_effect := str(Data.part_spec(mounted[slot], FIXTURE).upside)
		var loss_line := "발열 상한  15 → 12" if mounted[slot] == "radiator" else "잃음  " + old_effect
		text(Vector2(x, rule_y + 49), loss_line, 16, LOSS)
		var downside := str(Data.part_spec(incoming, FIXTURE).get("downside", ""))
		if not downside.is_empty():
			text(Vector2(x, rule_y + 70), "대가  " + downside, 16, LOSS)

	func draw_compare_part(bounds: Rect2, id: String, install: bool) -> void:
		box(bounds, Color("25221a") if install else Color("1c1a15"), FIT if install else LINE)
		PartArt.draw(self, id, bounds.get_center() - Vector2(0, 14), BRASS, 2.0, false)
		align_center(bounds.get_center().x, bounds.end.y - 29, name_of(id), INK if install else MUTED)

	func style(fill: Color, stroke: Color, top_width: int = 1) -> StyleBoxFlat:
		var result := StyleBoxFlat.new()
		result.bg_color = fill
		result.border_color = stroke
		result.set_border_width_all(1)
		result.border_width_top = top_width
		result.anti_aliasing = false
		return result

	func button(parent: Node, bounds: Rect2, caption: String, emphasis: bool = false) -> Button:
		var control := Button.new()
		control.text = caption
		control.position = bounds.position
		control.size = bounds.size
		control.add_theme_font_override("font", FontArt)
		control.add_theme_font_size_override("font_size", 16)
		control.add_theme_color_override("font_color", INK)
		control.add_theme_color_override("font_hover_color", INK)
		control.add_theme_color_override("font_pressed_color", INK)
		control.add_theme_stylebox_override("normal", style(Color("25231b") if emphasis else Color("1c1b16"), BRASS if emphasis else LINE, 2 if emphasis else 1))
		control.add_theme_stylebox_override("hover", style(Color("30291e"), FIT))
		control.add_theme_stylebox_override("pressed", style(Color("33291e"), BRASS))
		control.add_theme_stylebox_override("focus", style(Color.TRANSPARENT, BRASS))
		parent.add_child(control)
		return control

	func label_for(parent: Control, message: String, bounds: Rect2, color: Color, alignment: HorizontalAlignment) -> void:
		var label := Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.text = message
		label.position = bounds.position
		label.size = bounds.size
		label.horizontal_alignment = alignment
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_override("font", FontArt)
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", color)
		parent.add_child(label)

	func add_part(parent: Control, part: String, bounds: Rect2, factor: float) -> void:
		var icon := PartGlyph.new()
		icon.part = part
		icon.factor = factor
		icon.position = bounds.position
		icon.size = bounds.size
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(icon)

	func add_weapon(at: Vector2, width: float, is_shadow: bool) -> void:
		var sprite := TextureRect.new()
		sprite.texture = gun
		sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.position = at
		sprite.size = Vector2(width, roundf(width * gun.get_height() / gun.get_width()))
		sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sprite.material = shadow if is_shadow else foreground
		if is_shadow:
			sprite.self_modulate = Color(0.03, 0.028, 0.02, 0.58)
		dynamic.add_child(sprite)

	func build_controls() -> void:
		if is_instance_valid(dynamic):
			remove_child(dynamic)
			dynamic.queue_free()
		dynamic = Control.new()
		dynamic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(dynamic)
		var mat_top := bench.position.y + (100.0 if not compact else 64.0)
		var mat_end := tray.position.y - (24.0 if not compact else 14.0)
		var gun_width := roundf(minf(bench.size.x - (104.0 if not compact else 76.0), (mat_end - mat_top - 32.0) * 2.8))
		var gun_h := roundf(gun_width * gun.get_height() / gun.get_width())
		var at := Vector2(roundf(bench.get_center().x - gun_width * 0.5), roundf((mat_end + mat_top - gun_h) * 0.5))
		add_weapon(at + Vector2(5, 9), gun_width, true)
		add_weapon(at, gun_width, false)
		var close := button(dynamic, point(size.x - border - 88, 8 if compact else 11, 88, 44), "닫기")
		close.pressed.connect(func(): get_tree().quit())
		var slot_w := floorf((tray.size.x - 24.0 - 8.0 * 4.0) / 5.0)
		var slot_height := tray.size.y - 40
		for i in range(mounted.size()):
			var id := mounted[i]
			var bounds := point(tray.position.x + 12.0 + i * (slot_w + 8.0), tray.position.y + 32, slot_w, slot_height)
			var target := button(dynamic, bounds, "", i == slot)
			target.name = "Mount%d" % i
			if i != slot:
				target.add_theme_stylebox_override("normal", style(Color("201e16"), FIT if done.is_empty() else LINE))
			add_part(target, id, point(0, 2, slot_w, slot_height - 22), 1.65 if not compact else 1.25)
			label_for(target, name_of(id), point(0, slot_height - 23, slot_w, 21), INK if i == slot else MUTED, HORIZONTAL_ALIGNMENT_CENTER)
			target.pressed.connect(choose_slot.bind(i), CONNECT_DEFERRED)
		var scroll := ScrollContainer.new()
		scroll.position = shelf.position
		scroll.size = shelf.size
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.follow_focus = true
		dynamic.add_child(scroll)
		var bar := scroll.get_v_scroll_bar()
		var track := style(Color("1a1813"), LINE)
		track.content_margin_left = 4
		track.content_margin_right = 4
		bar.add_theme_stylebox_override("scroll", track)
		bar.add_theme_stylebox_override("grabber", style(Color("5b5140"), FIT))
		bar.add_theme_stylebox_override("grabber_highlight", style(Color("716149"), BRASS))
		bar.add_theme_stylebox_override("grabber_pressed", style(Color("716149"), BRASS))
		var list := VBoxContainer.new()
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_theme_constant_override("separation", 4)
		scroll.add_child(list)
		for id in inventory:
			var row_w := shelf.size.x - (12 if compact else 0)
			var row_h := 44 if compact else 45
			var item := button(list, point(0, 0, row_w, row_h), "", id == incoming and done.is_empty())
			item.name = id
			item.custom_minimum_size.y = row_h
			var value := str(Data.part_spec(id, FIXTURE).value)
			add_part(item, id, point(6, 0, 41, row_h), 1.18)
			label_for(item, name_of(id), point(56, 0, row_w - 170, row_h), INK, HORIZONTAL_ALIGNMENT_LEFT)
			label_for(item, value, point(row_w - 115, 0, 102, row_h), BRASS if id == incoming else MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
			item.pressed.connect(choose_part.bind(id, scroll), CONNECT_DEFERRED)
		scroll.set_deferred("scroll_vertical", selection_scroll)
		var action := Button.new()
		action.name = "Apply"
		action.theme = PrimaryTheme
		action.text = "교체 장착" if done.is_empty() else "장착됨"
		action.position = Vector2(right.end.x - 167, footer_y)
		action.size = Vector2(150, 46 if compact else 50)
		action.disabled = slot < 0 or not done.is_empty()
		action.pressed.connect(apply_part, CONNECT_DEFERRED)
		dynamic.add_child(action)
		box_footer()

	func box_footer() -> void:
		var divider := ColorRect.new()
		divider.color = LINE
		divider.position = Vector2(right.position.x + 16, footer_y - 9)
		divider.size = Vector2(right.size.x - 32, 1)
		divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dynamic.add_child(divider)

	func choose_part(id: String, scroll: ScrollContainer) -> void:
		selection_scroll = scroll.scroll_vertical
		incoming = id
		slot = -1
		done = ""
		rebuild()

	func choose_slot(index: int) -> void:
		if not done.is_empty():
			return
		slot = index
		rebuild()

	func apply_part() -> void:
		if slot < 0 or not done.is_empty():
			return
		inventory[inventory.find(incoming)] = mounted[slot]
		mounted[slot] = incoming
		done = incoming
		rebuild()

func _initialize() -> void:
	run.call_deferred()

func settle() -> void:
	for frame in range(7):
		await process_frame
	await RenderingServer.frame_post_draw

func tap(control: Control) -> void:
	var target := control.get_global_rect().get_center()
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.position = target
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
	await settle()

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var is_preview := args.has("--preview")
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.min_size = Vector2i(1008, 512)
	root.title = "ORVASK · 파츠 장착 시안"
	root.size = Vector2i(1170, 540) if args.has("--mobile") else Vector2i(1280, 800)
	Input.emulate_mouse_from_touch = true
	var view := Bench.new()
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(view)
	if is_preview:
		return
	var output := OS.get_environment("QA_OUTPUT_DIR")
	if output.is_empty():
		quit(2)
		return
	for extent in [Vector2i(1280, 800), Vector2i(1170, 540)]:
		root.size = extent
		await settle()
		assert(view.size == Vector2(extent) and view.compact == (extent.y == 540))
		var file := "desktop_1280x800.png" if extent.x == 1280 else "galaxy_1170x540.png"
		var captured := root.get_texture().get_image()
		if captured.get_size() != extent or captured.save_png(output.path_join(file)) != OK:
			quit(2)
			return
	await tap(view.dynamic.find_child("duplex", true, false))
	assert(view.slot == -1 and view.incoming == "duplex" and view.dynamic.find_child("Apply", true, false).disabled)
	await tap(view.dynamic.find_child("Mount2", true, false))
	assert(view.slot == 2 and not view.dynamic.find_child("Apply", true, false).disabled)
	await tap(view.dynamic.find_child("Apply", true, false))
	assert(view.mounted[2] == "duplex" and view.inventory.has("radiator") and view.done == "duplex")
	print("PART MOUNT LAYOUT PASS: both captures; choose part, choose slot, apply")
	quit()
