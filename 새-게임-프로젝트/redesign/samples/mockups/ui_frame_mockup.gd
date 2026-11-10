extends Control
## Layout mockups for the shared screen frame proposed by the 2026-10-31 UI
## layout review. Presentation only: reads copied state and never issues game
## commands. One top bar, one primary-action colour, one selected-card face and
## one place template are shared by every screen built here.

const FONT = preload("res://redesign/combat_pixel_font.tres")
const Content = preload("res://redesign/content.gd")
const AmmoArt = preload("res://redesign/ammo_art.gd")
const Visual = preload("res://redesign/ammo_visual.gd")
const EnemyThreat = preload("res://redesign/enemy_threat.gd")
const StatusIcons = preload("res://redesign/enemy_status_icons.gd")
const Symbols = preload("res://redesign/map_chart_symbols.gd")
const MapData = preload("res://redesign/campaign_content.gd")
const ShopIcon = preload("res://redesign/samples/shop_preview_icon.gd")

const KIT_DIR := "res://assets/art/combat_feedkit_20261031/"
# [atlas resource, nine-patch margins (l,t,r,b in source px), display scale]
const KIT := {
	"tray": ["tray", [90, 24, 55, 104], 1.0 / 3.0],
	"active": ["active", [150, 64, 46, 132], 0.4],
	"standby": ["standby", [150, 64, 46, 132], 0.4],
	"fire": ["fire", [84, 32, 48, 30], 0.5],
	"cool": ["cool", [84, 32, 48, 30], 0.5],
	"reload": ["reload", [84, 32, 48, 30], 0.5],
	"slate": ["cool", [84, 32, 48, 30], 0.5],
	"heat": ["heat", [62, 24, 44, 40], 0.25],
	"modal": ["modal", [84, 44, 60, 136], 1.0 / 3.0],
}
# Content inset in display px (l,t,r,b), clear of the fixed hardware.
const PAD := {
	"tray": [28, 8, 14, 12], "active": [24, 26, 10, 10], "standby": [24, 26, 10, 10],
	"fire": [36, 4, 12, 6], "cool": [36, 4, 12, 6], "reload": [36, 4, 12, 6], "slate": [36, 4, 12, 6],
	"heat": [16, 5, 8, 6], "modal": [26, 16, 18, 16],
}

const BG := Color("0e151b")
const BAND := Color("091015")
const INK := Color("f2eee3")
const DARK_INK := Color("25261f")
const SUB := Color("acbbc1")
const DIM := Color("6f8087")
const GOLD := Color("edc47a")
const CYAN := Color("78c9ed")
const IVORY := Color("e9dfc6")
const DANGER := Color("ee8777")

static var _slate: ShaderMaterial


class KitFrame extends Container:
	## Steel-kit nine-patch behind content. The art is drawn at a fixed downscale
	## so the hardware keeps one pixel density at every frame size.
	var art: NinePatchRect
	var art_scale := 1.0
	var pad: Array = [0, 0, 0, 0]

	func _notification(what: int) -> void:
		if what != NOTIFICATION_SORT_CHILDREN: return
		for child in get_children():
			if not child is Control: continue
			if child == art:
				art.position = Vector2.ZERO
				art.scale = Vector2.ONE * art_scale
				art.size = size / art_scale
			else:
				fit_child_in_rect(child, Rect2(pad[0], pad[1], maxf(0, size.x - pad[0] - pad[2]), maxf(0, size.y - pad[1] - pad[3])))

	func _get_minimum_size() -> Vector2:
		var result := Vector2.ZERO
		for child in get_children():
			if child is Control and child != art and child.visible:
				result = result.max(child.get_combined_minimum_size())
		return result + Vector2(pad[0] + pad[2], pad[1] + pad[3])


class AmmoFace extends Control:
	## Card face inside a feed tile: name, round, main stat, heat.
	var id := ""
	var state: Dictionary = {}
	var active := false
	var order := 0
	var locked := false

	func _draw() -> void:
		var ink: Color = DARK_INK if active else INK
		var sub: Color = Color("5d5a4c") if active else SUB
		if locked:
			_label("잠김", Vector2(0, size.y * 0.5 + 6), size.x, 15, DIM)
			return
		_label(str(Content.AMMO[id].name), Vector2(0, 15), size.x - (20 if order > 0 else 0), 17, ink)
		AmmoArt.draw(self, id, Rect2(0, 22, 22, 40))
		var stat: Dictionary = Content.primary_stat(id, state)
		_label(str(stat.label), Vector2(30, 36), size.x - 30, 13, sub)
		_label(str(stat.value), Vector2(30, 62), size.x - 30, 25, ink)
		var heat := "열 " + Content.heat_label(id, state)
		_label(heat, Vector2(0, size.y - 2), size.x, 13, Color("8a5a3c") if active else Color("d29b78"))
		if order > 0:
			draw_rect(Rect2(size.x - 18, 2, 18, 18), DARK_INK)
			_label(str(order), Vector2(size.x - 13, 16), 14, 14, IVORY)

	func _label(value: String, at: Vector2, width: float, px: int, color: Color) -> void:
		var font_size := px
		while font_size > 11 and FONT.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width: font_size -= 1
		draw_string(FONT, at.round(), value, HORIZONTAL_ALIGNMENT_LEFT, maxf(0, width), font_size, color)


class EnemyTags extends Control:
	## Proposed enemy readout: each tag sits directly above its own body, stacks
	## upward when neighbours collide, stays inside the board, and crowded
	## bodies share a numbered badge with their tag.
	var view: Control
	const W := 108.0
	const H := 48.0

	func _draw() -> void:
		if view == null: return
		var alive: Array = view._alive_indices()
		alive.sort_custom(func(a, b): return view.enemy_feet(a).x < view.enemy_feet(b).x)
		var badges := {}
		var counter := 0
		for group in view.crowded_groups():
			var members: Array = group.members.duplicate()
			members.sort_custom(func(a, b): return view.enemy_feet(a).x < view.enemy_feet(b).x)
			for index in members:
				counter += 1
				badges[int(index)] = counter
		# Named leaders keep the board's own intent line; their tag hangs under it
		# so the line reads as the tag header. Everyone else avoids those tags.
		var placed: Array = []
		var named: Array = alive.filter(func(i): return _named(i))
		var plain: Array = alive.filter(func(i): return not _named(i))
		var layout := {}
		for index in named:
			var intent_rect: Rect2 = view.intent_rect(index)
			var header_width := FONT.get_string_size(str(view.challenge_intent(index)), HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 18
			var width := maxf(tag_width(index, badges.get(index, 0)), header_width)
			var rect := Rect2(clampf(intent_rect.get_center().x - width * 0.5, 4, size.x - width - 4), intent_rect.position.y - 2, width, H + 20)
			placed.append(rect)
			layout[index] = [rect, 20.0]
		for index in plain:
			var feet: Vector2 = view.enemy_feet(index)
			var head: float = view.enemy_head_y(index)
			var width := tag_width(index, badges.get(index, 0))
			var rect := Rect2(clampf(feet.x - width * 0.5, 4, size.x - width - 4), head - 8 - H, width, H)
			var guard := 0
			while placed.any(func(other: Rect2): return other.grow(3).intersects(rect)) and guard < 8:
				rect.position.y -= H + 6
				guard += 1
			if rect.position.y < 4: rect.position.y = 4
			placed.append(rect)
			layout[index] = [rect, 0.0]
		for index in alive:
			var rect: Rect2 = layout[index][0]
			var feet: Vector2 = view.enemy_feet(index)
			var head: float = view.enemy_head_y(index)
			if rect.end.y < head - 12 or absf(rect.get_center().x - feet.x) > 10:
				var anchor_x := clampf(feet.x, rect.position.x + 8, rect.end.x - 8)
				draw_line(Vector2(anchor_x, rect.end.y).round(), Vector2(feet.x, head - 4).round(), Color("8fa3aa"), 1.0)
		for index in alive:
			_draw_tag(index, layout[index][0], badges.get(index, 0), layout[index][1])
			if badges.has(index):
				var feet: Vector2 = view.enemy_feet(index)
				_badge(Vector2(feet.x - 8, feet.y + 6), badges[index])

	func _named(index: int) -> bool:
		return view.has_method("intent_rect") and str(view.enemies[index].get("rank", "")) in ["elite", "boss"]

	func tag_width(index: int, badge: int) -> float:
		var e: Dictionary = view.enemies[index]
		var width := 9.0 + (20.0 if badge > 0 else 0.0) + 20.0 + FONT.get_string_size(str(int(e.hp)), HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x + 10.0
		var cells: Array = view.enemy_status_layout(index).cells
		for i in range(mini(cells.size(), 2)):
			width += 20.0 + FONT.get_string_size(str(cells[i].entry.value), HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		var threat: Dictionary = view.threat_readouts.get(index, {})
		var line := 18.0 + FONT.get_string_size(str(threat.get("text", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		return ceilf(maxf(W, maxf(width + 6.0, line)))

	func _draw_tag(index: int, frame_rect: Rect2, badge: int, header: float) -> void:
		var e: Dictionary = view.enemies[index]
		var threat: Dictionary = view.threat_readouts.get(index, {})
		var tone: Color = EnemyThreat.COLORS.get(threat.get("tone", "quiet"), SUB)
		var rect := Rect2(frame_rect.position + Vector2(0, header), frame_rect.size - Vector2(0, header))
		draw_rect(rect, Color(0.035, 0.06, 0.075, 0.86))
		draw_rect(frame_rect, Color("4d6168") if header == 0.0 else Color("8a7650"), false, 1.0)
		draw_rect(Rect2(rect.position, Vector2(3, rect.size.y)), tone)
		var x := rect.position.x + 9
		if badge > 0:
			_badge(rect.position + Vector2(8, 5), badge)
			x += 20
		draw_string(FONT, Vector2(x, rect.position.y + 20).round(), "HP", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, SUB)
		draw_string(FONT, Vector2(x + 20, rect.position.y + 21).round(), str(int(e.hp)), HORIZONTAL_ALIGNMENT_LEFT, -1, 21, INK)
		var cells: Array = view.enemy_status_layout(index).cells
		var icon_x := rect.end.x - 6
		for i in range(mini(cells.size(), 2) - 1, -1, -1):
			var entry: Dictionary = cells[i].entry
			var value := str(entry.value)
			var width := FONT.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			icon_x -= width + 18
			StatusIcons.draw_icon(self, Vector2(icon_x, rect.position.y + 6), str(entry.icon), 2, true)
			draw_string(FONT, Vector2(icon_x + 15, rect.position.y + 20).round(), value, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, StatusIcons.COLORS.get(entry.icon, SUB))
			icon_x -= 2
		var bar := Rect2(rect.position + Vector2(9, 26), Vector2(rect.size.x - 16, 4))
		draw_rect(bar, Color("2b3d42"))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(float(e.hp) / maxf(1, e.max_hp), 0, 1), 4)), Color("a0b79b"))
		var text := str(threat.get("text", ""))
		draw_string(FONT, (rect.position + Vector2(9, 44)).round(), text, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 14, 13, tone)

	func _badge(at: Vector2, value: int) -> void:
		draw_rect(Rect2(at, Vector2(16, 16)), GOLD)
		draw_string(FONT, (at + Vector2(4, 13)).round(), str(value), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, DARK_INK)


class MapChart extends Control:
	## The whole current region at once: no partial first row, four readable
	## node states (current, reachable, visited, later) and one selected plate.
	var nodes: Array = []
	var available: Array = []
	var visited: Array = []
	var current := 0
	var selected := 0
	var floors := 9

	func node_point(item: Dictionary) -> Vector2:
		var top := 30.0
		var bottom := size.y - 30.0
		var row := (float(item.floor) - 1.0) / maxf(1.0, float(floors) - 1.0)
		var single := nodes.filter(func(n): return int(n.floor) == int(item.floor)).size() == 1
		var ratio := 0.5 if single else (float(item.lane) + 0.5) / 4.0
		var width := minf(size.x - 60, 620.0)
		return Vector2((size.x - width) * 0.5 + width * ratio, lerpf(bottom, top, row)).round()

	func _draw() -> void:
		var by_id := {}
		for item in nodes: by_id[int(item.id)] = item
		for item in nodes:
			for next_id in item.next:
				if not by_id.has(int(next_id)): continue
				var a := node_point(item)
				var b := node_point(by_id[int(next_id)])
				var open: bool = int(item.id) == current and available.has(int(next_id))
				var trail: bool = visited.has(int(item.id)) and (visited.has(int(next_id)) or int(next_id) == current)
				var color := GOLD if open else (Color("7f9a96") if trail else Color("4f666d"))
				draw_line(a, b, color, 3.0 if open else 2.0)
		for item in nodes:
			var id := int(item.id)
			var p := node_point(item)
			var kind := MapData.room_kind(item)
			var icon: Texture2D = Symbols.role_texture(kind)
			var reach := available.has(id)
			var rect := Rect2(p - Vector2(19, 19), Vector2(38, 38))
			if id == selected:
				draw_rect(rect.grow(7), IVORY)
				draw_texture_rect(icon, rect, false, DARK_INK)
			elif reach:
				draw_rect(rect.grow(6), Color("1d2c33"))
				draw_rect(rect.grow(6), GOLD, false, 2.0)
				draw_texture_rect(icon, rect, false, INK)
			elif id == current:
				draw_rect(rect.grow(6), Color("1d2c33"))
				draw_rect(rect.grow(6), CYAN, false, 2.0)
				draw_texture_rect(icon, rect, false, Color("9fb4b9"))
				draw_string(FONT, p + Vector2(-14, 40), "현재", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, CYAN)
			elif visited.has(id):
				draw_texture_rect(icon, rect.grow(-4), false, Color("6f8a86", 0.75))
			else:
				draw_texture_rect(icon, rect.grow(-6), false, Color("9aaaac", 0.72))
			if str(item.get("route", "")) == "duct":
				draw_string(FONT, p + Vector2(22, -12), "+", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, DANGER)


# --- shared primitives -------------------------------------------------------

static func slate_material() -> ShaderMaterial:
	if _slate == null:
		var shader := Shader.new()
		shader.code = "shader_type canvas_item;\nvoid fragment() {\n\tfloat g = dot(COLOR.rgb, vec3(0.3, 0.55, 0.15));\n\tCOLOR = vec4(vec3(g) * vec3(0.82, 0.9, 0.96), COLOR.a);\n}\n"
		_slate = ShaderMaterial.new()
		_slate.shader = shader
	return _slate


static func text(value: String, px: int, color: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", px)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


static func para(value: String, px: int, color: Color) -> Label:
	var label := text(value, px, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	return label


static func frame(kind: String) -> KitFrame:
	var spec: Array = KIT[kind]
	var result := KitFrame.new()
	var art := NinePatchRect.new()
	art.texture = load(KIT_DIR + str(spec[0]) + ".tres")
	var m: Array = spec[1]
	art.patch_margin_left = m[0]
	art.patch_margin_top = m[1]
	art.patch_margin_right = m[2]
	art.patch_margin_bottom = m[3]
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if kind == "slate": art.material = slate_material()
	result.art = art
	result.art_scale = spec[2]
	result.pad = PAD[kind]
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_child(art)
	return result


static func box(vertical: bool, gap: int = 8) -> BoxContainer:
	var result: BoxContainer = VBoxContainer.new() if vertical else HBoxContainer.new()
	result.add_theme_constant_override("separation", gap)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result


static func spacer(horizontal: bool = true) -> Control:
	var result := Control.new()
	if horizontal: result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else: result.size_flags_vertical = Control.SIZE_EXPAND_FILL
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result


## Button tiers: fire = the one primary action per screen, slate = secondary,
## cool/reload = combat-only functions, disabled = dimmed slate without brackets.
static func button(title: String, kind: String, sub: String = "", width: float = 0.0, height: float = 40.0, disabled: bool = false) -> KitFrame:
	var result := frame(kind)
	var column := box(true, 0)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	var ink := DIM if disabled else INK
	column.add_child(text(title, 21 if height >= 54 else 17, ink, HORIZONTAL_ALIGNMENT_CENTER))
	if sub != "": column.add_child(text(sub, 13, Color(ink, 0.8), HORIZONTAL_ALIGNMENT_CENTER))
	result.add_child(column)
	result.custom_minimum_size = Vector2(width, height)
	if disabled: result.modulate = Color(1, 1, 1, 0.6)
	return result


static func resource(label: String, value: String, color: Color) -> Control:
	var row := box(false, 5)
	var mark := ColorRect.new()
	mark.color = color
	mark.custom_minimum_size = Vector2(8, 8)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(mark)
	row.add_child(text(label, 14, SUB))
	row.add_child(text(value, 17, color))
	return row


## The one top bar shared by every screen: where you are, what you hold, menu.
static func top_bar(place: String, progress: String, extra: Array = [], resources: Array = []) -> Control:
	var band := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = BAND
	style.border_color = Color("26343c")
	style.border_width_bottom = 2
	style.content_margin_left = 16
	style.content_margin_right = 10
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	band.add_theme_stylebox_override("panel", style)
	var row := box(false, 14)
	row.add_child(text(place, 21, INK))
	row.add_child(text(progress, 15, SUB))
	for item in extra: row.add_child(item)
	row.add_child(spacer())
	var shown: Array = resources if not resources.is_empty() else [["Cr", "75", GOLD], ["코어", "1/2", CYAN], ["탄약", "20/30", SUB]]
	for entry in shown: row.add_child(resource(entry[0], entry[1], entry[2]))
	row.add_child(button("빌드", "slate", "", 78, 34))
	row.add_child(button("메뉴", "slate", "", 78, 34))
	band.add_child(row)
	return band


static func ammo_card(id: String, state: Dictionary, active: bool, order: int = 0, width: float = 120.0, locked: bool = false) -> KitFrame:
	var result := frame("active" if active else "standby")
	var face := AmmoFace.new()
	face.id = id
	face.state = state
	face.active = active
	face.order = order
	face.locked = locked
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_child(face)
	result.custom_minimum_size = Vector2(width, 112)
	if locked: result.modulate = Color(1, 1, 1, 0.45)
	return result


static func picture(texture: Texture2D, crop_center: Vector2 = Vector2(0.5, 0.5)) -> Control:
	var holder := Control.new()
	holder.clip_contents = true
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var image := TextureRect.new()
	image.texture = texture
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.set_anchors_preset(Control.PRESET_FULL_RECT)
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(image)
	return holder


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _clear() -> VBoxContainer:
	for child in get_children(): child.queue_free()
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var root := box(true, 0)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	return root


func _body(root: VBoxContainer, gap: int = 12) -> MarginContainer:
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 12 if side != "top" else 10)
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(margin)
	return margin


# --- 1. common frame sheet ---------------------------------------------------

func show_kit(state: Dictionary) -> void:
	var root := _clear()
	root.add_child(top_bar("공통 화면 틀", "모든 화면이 같은 상단바를 씁니다"))
	var body := _body(root)
	var columns := box(false, 12)
	body.add_child(columns)
	var buttons := _section("버튼 등급 — 화면당 주 행동 하나", columns, 1.0)
	for entry in [["이동", "fire", "주 행동 · 화면마다 한 곳, 오른쪽 아래"], ["자세히", "slate", "보조 행동"], ["냉각", "cool", "전투 전용 기능 색"], ["탄창 교체", "reload", "전투 전용 기능 색"], ["선택한 뒤 확정", "slate", "비활성 · 괄호 없이 어둡게"]]:
		var row := box(false, 12)
		var item := button(entry[0], entry[1], "", 150, 44, entry[0] == "선택한 뒤 확정")
		row.add_child(item)
		var note := text(entry[2], 15, SUB)
		note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(note)
		buttons.add_child(row)
	var cards := _section("카드 상태 — 선택은 상아색 면 하나", columns, 1.1)
	var card_row := box(false, 10)
	card_row.add_child(_captioned(ammo_card("basic", state, false, 0, 118), "기본"))
	card_row.add_child(_captioned(ammo_card("pierce", state, true, 0, 118), "선택"))
	card_row.add_child(_captioned(ammo_card("basic", state, false, 0, 118, true), "잠김"))
	cards.add_child(card_row)
	var focus_row := box(false, 10)
	var focused := ammo_card("arc", state, false, 0, 118)
	var brackets := _brackets()
	focused.add_child(brackets)
	focus_row.add_child(_captioned(focused, "초점(패드·키보드)"))
	focus_row.add_child(para("모서리 괄호는 키보드·패드 초점에만 씁니다. 터치 화면의 선택은 상아색 면 하나로 표시합니다.", 15, SUB))
	focus_row.get_child(1).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.add_child(focus_row)
	var type := _section("글자 위계 — 도트 글꼴 한 종류", columns, 0.9)
	type.add_child(text("제목 · 탄약고", 26, INK))
	type.add_child(text("소제목 · 가져갈 탄환", 21, INK))
	type.add_child(text("본문 · 한 장을 받을 수 있습니다", 17, INK))
	type.add_child(text("보조 · 열 +2 · 보유 0장", 15, SUB))
	type.add_child(text("수치 강조 · 12 Cr", 19, GOLD))
	type.add_child(text("위험 · 적이 도달하면 패배", 15, DANGER))
	type.add_child(spacer(false))
	type.add_child(para("NeoDunggeunmo 하나로 통일. Noto Sans는 쓰지 않습니다.", 14, DIM))


func _section(title: String, parent: Control, ratio: float) -> VBoxContainer:
	var panel := frame("modal")
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = ratio
	parent.add_child(panel)
	var column := box(true, 10)
	column.add_child(text(title, 17, GOLD))
	panel.add_child(column)
	return column


func _captioned(item: Control, caption: String) -> Control:
	var column := box(true, 4)
	column.add_child(item)
	column.add_child(text(caption, 14, SUB, HORIZONTAL_ALIGNMENT_CENTER))
	return column


func _brackets() -> Control:
	var marks := Control.new()
	marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marks.draw.connect(func():
		var r := Rect2(Vector2(-22, -24), marks.size + Vector2(30, 32))
		for corner in [r.position, Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), r.end]:
			var sx := 1.0 if corner.x == r.position.x else -1.0
			var sy := 1.0 if corner.y == r.position.y else -1.0
			marks.draw_rect(Rect2(corner + Vector2(0 if sx > 0 else -12, 0 if sy > 0 else -2), Vector2(12, 2)), GOLD)
			marks.draw_rect(Rect2(corner + Vector2(0 if sx > 0 else -2, 0 if sy > 0 else -12), Vector2(2, 12)), GOLD)
	)
	return marks


# --- 2. main-run combat ------------------------------------------------------

func show_combat(view: Control, state: Dictionary, place: String, progress: String, forecast: Dictionary) -> void:
	var root := _clear()
	var weapon := button(str(Content.weapon_spec(state).get("name", "리벳")), "slate", "", 96, 34)
	root.add_child(top_bar(place, progress, [weapon], [["Cr", "75", GOLD], ["코어", "1/2", CYAN], ["탄약", "%d장" % state.get("draw", []).size(), SUB]]))
	var stage := Control.new()
	stage.clip_contents = true
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(stage)
	view.get_parent().remove_child(view)
	stage.add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.custom_minimum_size = Vector2.ZERO
	view.readout_layer.visible = false
	for item in view.info_buttons + view.reserve_buttons: item.visible = false
	var tags := EnemyTags.new()
	tags.view = view
	tags.z_index = 50
	tags.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tags.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(tags)
	view.resized.connect(tags.queue_redraw)
	var dock := PanelContainer.new()
	var dock_style := StyleBoxFlat.new()
	dock_style.bg_color = BAND
	dock_style.border_color = Color("26343c")
	dock_style.border_width_top = 2
	dock_style.content_margin_left = 12
	dock_style.content_margin_right = 12
	dock_style.content_margin_top = 8
	dock_style.content_margin_bottom = 10
	dock.add_theme_stylebox_override("panel", dock_style)
	root.add_child(dock)
	var lower := box(true, 8)
	dock.add_child(lower)
	var hand: Array = state.get("hand", [])
	var plan: Array = state.get("plan", [])
	var rail_size := int(Content.weapon_spec(state).capacity) + int(state.get("capacity_bonus", 0))
	# Loaded cards stay in place in the hand; mark their firing order.
	var orders := {}
	for slot in range(plan.size()):
		for i in range(hand.size()):
			if str(hand[i]) == str(plan[slot]) and not orders.has(i):
				orders[i] = slot + 1
				break
	# Row 1: firing order as slim chips + heat in one strip.
	var strip := box(false, 8)
	strip.custom_minimum_size.y = 32
	strip.add_child(text("발사 순서", 15, SUB))
	for slot in range(rail_size):
		var chip := PanelContainer.new()
		var chip_style := StyleBoxFlat.new()
		var filled := slot < plan.size()
		chip_style.bg_color = IVORY if filled else Color("121c22")
		chip_style.border_color = Color("c9bd9f") if filled else Color("33474d")
		chip_style.set_border_width_all(1)
		chip_style.content_margin_left = 8
		chip_style.content_margin_right = 8
		chip.add_theme_stylebox_override("panel", chip_style)
		chip.custom_minimum_size = Vector2(96, 30)
		var label := ("%d  %s" % [slot + 1, Content.AMMO[plan[slot]].name]) if filled else str(slot + 1)
		chip.add_child(text(label, 14, DARK_INK if filled else DIM))
		strip.add_child(chip)
	strip.add_child(spacer())
	strip.add_child(text("발열", 15, SUB))
	var gauge := frame("heat")
	gauge.custom_minimum_size = Vector2(220, 20)
	gauge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var heat_now := int(state.get("heat", 0))
	var heat_limit := Content.heat_limit(state)
	var fill := Control.new()
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var heat_range: Dictionary = forecast.get("heat", {})
	var planned := int(heat_range.get("peak_max", heat_range.get("peak", heat_now)))
	if planned == heat_now:
		for id in plan: planned += Content.heat_delta(id, state)
	fill.draw.connect(func():
		var w := fill.size.x
		fill.draw_rect(Rect2(0, 0, w * clampf(float(planned) / heat_limit, 0, 1), fill.size.y), Color("edc47a", 0.35))
		fill.draw_rect(Rect2(0, 0, w * clampf(float(heat_now) / heat_limit, 0, 1), fill.size.y), Color("e08a5c"))
	)
	gauge.add_child(fill)
	strip.add_child(gauge)
	strip.add_child(text("%d / %d" % [heat_now, heat_limit], 17, INK))
	strip.add_child(text("사격 후 %d" % planned, 14, GOLD))
	lower.add_child(strip)
	# Row 2: hand, this-shot forecast, actions. Locked capacity is not drawn as slots.
	var row := box(false, 8)
	var width := size.x if size.x > 0 else 1440.0
	var card_width := clampf((width - 640.0) / maxf(1, hand.size()), 100.0, 136.0)
	for i in range(hand.size()):
		row.add_child(ammo_card(hand[i], state, orders.has(i), int(orders.get(i, 0)), card_width))
	var outlook := frame("modal")
	outlook.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outlook.custom_minimum_size = Vector2(150, 112)
	var outlook_column := box(true, 2)
	outlook_column.add_child(text("이번 사격", 14, SUB))
	var before: Array = state.get("enemies", [])
	var after: Array = forecast.get("enemies", [])
	if forecast.get("random", false) or after.is_empty():
		outlook_column.add_child(text("무작위 표적", 20, GOLD))
		outlook_column.add_child(text("표적별 확률은 탄 상세에서", 13, SUB))
	else:
		var dealt := 0
		var kills := 0
		for i in range(mini(before.size(), after.size())):
			dealt += maxi(0, int(before[i].hp) - maxi(0, int(after[i].hp)))
			if int(before[i].hp) > 0 and int(after[i].hp) <= 0: kills += 1
		outlook_column.add_child(text("피해 %d · 처치 %d기" % [dealt, kills], 20, GOLD))
		outlook_column.add_child(text(" → ".join(plan.map(func(id): return str(Content.AMMO[id].name))), 13, SUB))
	outlook_column.add_child(spacer(false))
	outlook_column.add_child(text("예비 탄 %d장 · 패 교환 0회" % state.get("draw", []).size(), 13, DIM))
	outlook.add_child(outlook_column)
	row.add_child(outlook)
	var actions := box(true, 6)
	actions.custom_minimum_size.x = 236
	actions.add_child(button("재장전 · 냉각 %d" % int(Content.weapon_spec(state).reload_cooling), "cool", "열 %d → 0 · 적 1턴" % heat_now, 236, 48))
	actions.add_child(button("%d발 사격" % plan.size(), "fire", "적 %d행동" % maxi(1, int(forecast.get("turns", 1))), 236, 58))
	row.add_child(actions)
	lower.add_child(row)


# --- 3. map -------------------------------------------------------------------

func show_map(campaign, region_art: Texture2D) -> void:
	var root := _clear()
	root.add_child(top_bar(str(campaign.region_info().get("name", "승강장·주거 통로")), "1구역 지도"))
	var body := _body(root)
	var columns := box(false, 12)
	body.add_child(columns)
	var map_panel := frame("modal")
	map_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_panel.size_flags_stretch_ratio = 1.9
	columns.add_child(map_panel)
	var map_stack := Control.new()
	map_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_panel.add_child(map_stack)
	var backdrop := picture(region_art)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.modulate = Color(1, 1, 1, 0.10)
	map_stack.add_child(backdrop)
	var chart := MapChart.new()
	chart.nodes = campaign.current_nodes()
	chart.available = campaign.choices().map(func(item): return int(item.id))
	chart.visited = campaign.s.visited.map(func(id): return int(id))
	chart.current = int(campaign.s.node)
	chart.floors = int(campaign.region_info().floors)
	chart.selected = chart.available[0] if not chart.available.is_empty() else 0
	chart.set_anchors_preset(Control.PRESET_FULL_RECT)
	chart.offset_bottom = -26
	chart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_stack.add_child(chart)
	var legend := box(false, 16)
	legend.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	legend.offset_top = -22
	legend.alignment = BoxContainer.ALIGNMENT_CENTER
	for entry in [["선택", IVORY], ["갈 수 있음", GOLD], ["현재", CYAN], ["지나옴", Color("6f8a86")], ["이후", Color("8a9a9c", 0.6)]]:
		legend.add_child(resource(entry[0], "", entry[1]))
	map_stack.add_child(legend)
	var side_panel := frame("modal")
	side_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_panel.size_flags_stretch_ratio = 1.0
	columns.add_child(side_panel)
	var side := box(true, 10)
	side_panel.add_child(side)
	var picked: Dictionary = {}
	for item in chart.nodes:
		if int(item.id) == chart.selected: picked = item
	var kind := MapData.room_kind(picked) if not picked.is_empty() else "combat"
	side.add_child(text("선택한 장소", 15, SUB))
	var head := box(false, 12)
	var icon := TextureRect.new()
	icon.texture = Symbols.role_texture(kind)
	icon.custom_minimum_size = Vector2(56, 56)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.add_child(icon)
	var names := box(true, 2)
	names.add_child(text(str(picked.get("name", "순찰 구역")), 23, INK))
	names.add_child(text(MapData.kind_name(kind), 15, GOLD))
	head.add_child(names)
	side.add_child(head)
	var hint := MapData.hint(picked) if not picked.is_empty() else ""
	for line in [["얻는 것", "승리 후 탄환 3종 중 1장"], ["위험", hint if hint != "" else "적 2기 · 접근 18m"], ["이후 길", "갈래 %d곳으로 이어짐" % picked.get("next", []).size()]]:
		var info := box(false, 10)
		var key := text(line[0], 15, SUB)
		key.custom_minimum_size.x = 64
		info.add_child(key)
		var value := para(line[1], 16, INK)
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(value)
		side.add_child(info)
	side.add_child(spacer(false))
	var build := frame("standby")
	var build_column := box(true, 4)
	build_column.add_child(text("현재 빌드", 14, SUB))
	var state: Dictionary = campaign.model.s if campaign.model != null else {}
	var spec: Dictionary = Content.weapon_spec(state) if not state.is_empty() else {}
	build_column.add_child(text("%s · 탄창 %d칸 · 열 한계 %d" % [spec.get("name", "래칫"), int(spec.get("capacity", 4)), int(spec.get("heat_limit", 14))], 16, INK))
	build_column.add_child(text("덱 20장 · 파츠 0/5 · 코어 미장착", 15, SUB))
	build.add_child(build_column)
	side.add_child(build)
	var actions := box(false, 8)
	var detail := button("자세히", "slate", "", 0, 50)
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(detail)
	var go := button("이동", "fire", "", 0, 50)
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	go.size_flags_stretch_ratio = 1.6
	actions.add_child(go)
	side.add_child(actions)


# --- 4. place template (encounter, supply, workshop, reward) -----------------

## options: [{title, detail, icon (ammo id or ""), selected}]
func show_place(place: String, progress: String, art: Texture2D, title: String, lead: String, prompt: String, options: Array, state: Dictionary, primary: String, secondary: String, outcome: String = "") -> void:
	var root := _clear()
	root.add_child(top_bar(place, progress))
	var body := _body(root)
	var columns := box(false, 14)
	body.add_child(columns)
	var scene := Control.new()
	scene.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scene.size_flags_stretch_ratio = 1.0
	scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columns.add_child(scene)
	var image := picture(art)
	image.set_anchors_preset(Control.PRESET_FULL_RECT)
	scene.add_child(image)
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.05, 0.07, 0.0)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scene.add_child(shade)
	var caption := frame("modal")
	caption.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	caption.offset_left = 10
	caption.offset_right = -10
	caption.offset_top = -96
	caption.offset_bottom = -10
	var caption_column := box(true, 4)
	caption_column.add_child(text(title, 24, GOLD))
	caption_column.add_child(para(lead, 15, INK))
	caption.add_child(caption_column)
	scene.add_child(caption)
	var right := box(true, 8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.05
	columns.add_child(right)
	right.add_child(text(prompt, 19, INK))
	for option in options:
		var selected: bool = option.get("selected", false)
		var card := frame("active" if selected else "standby")
		card.custom_minimum_size.y = 104
		var line := box(false, 12)
		var icon_id := str(option.get("icon", ""))
		if icon_id != "":
			var art_holder := Control.new()
			art_holder.custom_minimum_size = Vector2(30, 56)
			art_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
			art_holder.draw.connect(func(): AmmoArt.draw(art_holder, icon_id, Rect2(Vector2.ZERO, art_holder.size)))
			line.add_child(art_holder)
		var words := box(true, 2)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.alignment = BoxContainer.ALIGNMENT_CENTER
		words.add_child(text(str(option.title), 21, DARK_INK if selected else INK))
		words.add_child(text(str(option.detail), 16, Color("5d5a4c") if selected else SUB))
		line.add_child(words)
		if option.has("tag"): line.add_child(text(str(option.tag), 19, Color("8a5a3c") if selected else GOLD))
		card.add_child(line)
		right.add_child(card)
	right.add_child(spacer(false))
	if outcome != "":
		var result := frame("modal")
		var result_column := box(true, 2)
		result_column.add_child(text("선택하면", 14, SUB))
		result_column.add_child(text(outcome, 19, GOLD))
		result.add_child(result_column)
		right.add_child(result)
	var actions := box(false, 8)
	var skip := button(secondary, "slate", "", 0, 50)
	skip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(skip)
	var confirm := button(primary, "fire", "", 0, 50)
	confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm.size_flags_stretch_ratio = 1.4
	actions.add_child(confirm)
	right.add_child(actions)


# --- 5. shop -----------------------------------------------------------------

## products: [{kind: "ammo"/"part", id, name, stat, note, price, owned}]
func show_shop(state: Dictionary, art: Texture2D, products: Array, selected: int) -> void:
	var root := _clear()
	root.add_child(top_bar("승강장 정비소", "상점"))
	var body := _body(root)
	var columns := box(false, 12)
	body.add_child(columns)
	var left := box(true, 8)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 2.0
	columns.add_child(left)
	var scene := picture(art)
	scene.custom_minimum_size.y = 150
	scene.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(scene)
	var quote := frame("modal")
	quote.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	quote.offset_left = -440
	quote.offset_top = -92
	quote.offset_right = -10
	quote.offset_bottom = -10
	var quote_column := box(true, 2)
	quote_column.add_child(text("정비소 주인", 14, GOLD))
	quote_column.add_child(para("“안쪽 문은 열어 둬요. 거기까지 난방이 가야 해서.”", 15, INK))
	quote.add_child(quote_column)
	scene.add_child(quote)
	var heading := box(false, 8)
	heading.add_child(text("오늘의 물건", 19, INK))
	heading.add_child(spacer())
	heading.add_child(button("새 진열 · 3 Cr", "slate", "", 150, 34))
	left.add_child(heading)
	var shelf := box(false, 10)
	shelf.custom_minimum_size.y = 236
	left.add_child(shelf)
	for i in range(products.size()):
		var product: Dictionary = products[i]
		var on := i == selected
		var card := frame("active" if on else "standby")
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var column := box(true, 4)
		var top := box(false, 6)
		top.add_child(text(str(product.category), 13, Color("5d5a4c") if on else SUB))
		top.add_child(spacer())
		top.add_child(text(str(product.price), 17, Color("8a5a3c") if on else GOLD))
		column.add_child(top)
		var icon: Control
		if product.kind == "ammo":
			icon = Control.new()
			var ammo_id := str(product.id)
			icon.draw.connect(func(): AmmoArt.draw(icon, ammo_id, Rect2(icon.size.x * 0.5 - 15, 2, 30, icon.size.y - 4)))
		else:
			icon = ShopIcon.new()
			icon.is_part = true
			icon.item_id = str(product.id)
		icon.custom_minimum_size.y = 84
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(icon)
		column.add_child(text(str(product.name), 21, DARK_INK if on else INK))
		column.add_child(text(str(product.stat), 17, Color("8a5a3c") if on else GOLD))
		column.add_child(text(str(product.owned), 14, Color("5d5a4c") if on else DIM))
		card.add_child(column)
		shelf.add_child(card)
	var tools := box(false, 8)
	tools.add_child(button("탄환 가방 20/30", "slate", "", 170, 38))
	tools.add_child(button("압축 충전 1/2 · 18 Cr", "slate", "", 210, 38))
	tools.add_child(spacer())
	left.add_child(tools)
	var right := box(true, 8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.0
	columns.add_child(right)
	var detail := frame("modal")
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var detail_column := box(true, 6)
	var pick: Dictionary = products[selected]
	detail_column.add_child(text(str(pick.name), 23, INK))
	detail_column.add_child(text(str(pick.stat), 17, GOLD))
	detail_column.add_child(para(str(pick.note), 15, SUB))
	detail_column.add_child(spacer(false))
	detail_column.add_child(text("구매 후 변화", 14, SUB))
	for change in pick.get("changes", []):
		var change_row := box(false, 8)
		var key := text(str(change[0]), 15, SUB)
		key.custom_minimum_size.x = 72
		change_row.add_child(key)
		change_row.add_child(text(str(change[1]), 17, INK))
		detail_column.add_child(change_row)
	detail_column.add_child(spacer(false))
	detail_column.add_child(button("%s · 한 장 추가" % pick.price, "fire", "", 0, 52))
	var after := box(false, 8)
	var swap := button("보유 탄과 교체", "slate", "", 0, 38)
	swap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	after.add_child(swap)
	after.add_child(text("구매 후 63 Cr", 14, SUB))
	detail_column.add_child(after)
	detail.add_child(detail_column)
	right.add_child(detail)
	var gear := frame("modal")
	var gear_column := box(true, 6)
	var gear_head := box(false, 8)
	gear_head.add_child(text("장착 파츠 0/5", 15, SUB))
	gear_head.add_child(spacer())
	gear_head.add_child(text("코어 미장착", 14, DIM))
	gear_column.add_child(gear_head)
	var slots := box(false, 6)
	for i in range(5):
		var slot := ColorRect.new()
		slot.color = Color("121c22")
		slot.custom_minimum_size = Vector2(0, 30)
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slots.add_child(slot)
	gear_column.add_child(slots)
	gear.add_child(gear_column)
	right.add_child(gear)
	right.add_child(button("지도로 계속", "slate", "", 0, 42))
