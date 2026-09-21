extends Control
signal entered(id: int)
signal inspected(id: int)
const Data = preload("res://redesign/campaign_content.gd")
const FONT = preload("res://assets/fonts/NeoDunggeunmoPro-Regular.ttf")
const COLORS := {"combat": Color("a4b4ba"), "boss": Color("f2a38d"), "shop": Color("e4cc84"), "supply": Color("a9dfbf"), "event": Color("baace4"), "bypass": Color("8dbfc9")}
var nodes: Array = []
var available: Array = []
var visited: Array = []
var current := 0
var floors := 6
var positions: Dictionary = {}

func setup(campaign) -> void:
	nodes = campaign.current_nodes()
	available = campaign.choices().map(func(item): return int(item.id))
	visited = campaign.s.visited.duplicate()
	current = int(campaign.s.node)
	floors = int(Data.info(int(campaign.s.region)).floors)
	custom_minimum_size.y = maxi(410, floors * 64 + 24)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clip_contents = true
	resized.connect(_layout)
	for item in nodes:
		var button := Button.new()
		button.name = "map_node_" + str(item.id)
		button.text = ("● " if int(item.id) == current else ("✓ " if visited.has(int(item.id)) else "")) + str(item.name)
		button.text += "\n" + Data.kind_name(str(item.kind))
		if available.has(int(item.id)): button.text += " · " + ("계단" if item.route == "stairs" else "환기 −2m")
		button.add_theme_font_size_override("font_size", 16)
		button.add_theme_color_override("font_color", Color("e7e4d9") if available.has(int(item.id)) else (Color("a9dfbf") if visited.has(int(item.id)) else Color("81939c")))
		for state in ["normal", "hover", "pressed", "focus"]:
			var box := StyleBoxFlat.new()
			box.bg_color = Color("243b43") if available.has(int(item.id)) else Color("192b35")
			box.border_color = COLORS[item.kind] if available.has(int(item.id)) or state != "normal" else Color("344c59")
			box.set_border_width_all(2 if available.has(int(item.id)) else 1)
			box.set_corner_radius_all(4)
			box.content_margin_left = 29
			button.add_theme_stylebox_override(state, box)
		button.tooltip_text = Data.hint(item)
		button.pressed.connect(func():
			if available.has(int(item.id)): entered.emit(int(item.id))
			else: inspected.emit(int(item.id))
		)
		add_child(button)
		var badge := Badge.new()
		badge.kind = item.kind
		badge.color = COLORS[item.kind] if available.has(int(item.id)) else Color("6e8995")
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.position = Vector2(10, 12)
		badge.size = Vector2(20, 20)
		button.add_child(badge)
	_layout.call_deferred()

func _layout() -> void:
	positions.clear()
	var spacing := (size.y - 24) / float(floors)
	var width := minf(270, (size.x - 130) * 0.41)
	for i in range(nodes.size()):
		var item: Dictionary = nodes[i]
		var single := 0
		for other in nodes:
			if int(other.floor) == int(item.floor): single += 1
		var x := size.x * (0.5 if single == 1 else (0.31 if int(item.lane) == 0 else 0.71))
		var y := 12 + (floors - int(item.floor) + 0.5) * spacing
		positions[int(item.id)] = Vector2(x, y)
		var button := get_child(i) as Button
		button.position = Vector2(x - width / 2, y - 26)
		button.size = Vector2(width, 52)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("14232c"))
	var spacing := (size.y - 24) / float(floors)
	for f in range(1, floors + 1):
		var y := 12 + (floors - f + 0.5) * spacing
		draw_line(Vector2(70, y + spacing / 2), Vector2(size.x - 12, y + spacing / 2), Color("24343d"), 1)
		draw_string(FONT, Vector2(16, y + 5), "%02dF" % f, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("a4b4ba"))
	for item in nodes:
		for target in nodes:
			if int(target.floor) != int(item.floor) + 1: continue
			var target_count := 0
			for other in nodes:
				if int(other.floor) == int(target.floor): target_count += 1
			if int(item.lane) == 1 and int(target.lane) == 0 and target_count > 1: continue
			if not positions.has(int(item.id)) or not positions.has(int(target.id)): continue
			var active: bool = int(item.id) == current and available.has(int(target.id))
			draw_line(positions[int(item.id)] - Vector2(0, 26), positions[int(target.id)] + Vector2(0, 26), Color("a9dfbf") if active else Color("354653"), 3 if active else 1, true)

class Badge extends Control:
	var kind := "combat"
	var color := Color.WHITE
	func _draw() -> void:
		match kind:
			"combat":
				draw_line(Vector2(3, 3), Vector2(17, 17), color, 3)
				draw_line(Vector2(17, 3), Vector2(3, 17), color, 3)
			"boss":
				draw_colored_polygon(PackedVector2Array([Vector2(10, 0), Vector2(20, 10), Vector2(10, 20), Vector2(0, 10)]), color)
			"shop":
				draw_rect(Rect2(1, 3, 18, 12), color, false, 2)
				draw_line(Vector2(5, 19), Vector2(15, 19), color, 2)
			"supply":
				draw_rect(Rect2(1, 4, 18, 14), color, false, 2)
				draw_line(Vector2(10, 7), Vector2(10, 15), color, 2)
				draw_line(Vector2(6, 11), Vector2(14, 11), color, 2)
			"event":
				draw_circle(Vector2(10, 10), 8, color, false, 2)
				draw_line(Vector2(10, 4), Vector2(10, 11), color, 2)
				draw_circle(Vector2(10, 15), 1, color)
			"bypass":
				draw_line(Vector2(1, 10), Vector2(18, 10), color, 2)
				draw_line(Vector2(12, 4), Vector2(18, 10), color, 2)
				draw_line(Vector2(12, 16), Vector2(18, 10), color, 2)
