extends "res://redesign/city_map_view.gd"
const Symbols = preload("res://redesign/map_chart_symbols.gd")
var accessible: Array = []
var feedback_scale := 1.0
var region_index := 0
const THEMES := [
	{"paper": "1b3038", "edge": "506264", "tint": Color(1, 1, 1)},
	{"paper": "322b29", "edge": "786458", "tint": Color(1, 0.82, 0.70)},
	{"paper": "20332e", "edge": "59736a", "tint": Color(0.76, 1, 0.85)},
	{"paper": "202d3d", "edge": "546d8a", "tint": Color(0.74, 0.86, 1)},
	{"paper": "2a2939", "edge": "706681", "tint": Color(0.91, 0.83, 1)}
]

func setup(campaign) -> void:
	region_index = clampi(int(campaign.s.region), 0, 4)
	super.setup(campaign)
	accessible = available.duplicate()
	for item in nodes:
		if accessible.has(int(item.id)):
			for next_id in item.next:
				if not accessible.has(int(next_id)): accessible.append(int(next_id))
	for i in range(nodes.size()):
		var button = get_child(i)
		button.chart_mode = true
		button.feedback_scale = feedback_scale
		button.on_route = accessible.has(int(nodes[i].id)) or visited.has(int(nodes[i].id))
		button.get_node("Picture").texture = Symbols.role_texture(Data.room_kind(nodes[i]))
		button.refresh(false)

func _layout() -> void:
	positions.clear()
	var graph_width := minf(740, size.x * 0.74)
	var spacing := (size.y - 24) / float(floors)
	for i in range(nodes.size()):
		var item: Dictionary = nodes[i]
		var single := nodes.filter(func(n): return int(n.floor) == int(item.floor)).size() == 1
		var ratio := (float(item.lane) + 0.5) / 4.0 if modern else (0.26 if int(item.lane) == 0 else 0.74)
		var point := Vector2((size.x - graph_width) * 0.5 + graph_width * (0.5 if single else ratio), 12 + (floors - int(item.floor) + 0.5) * spacing).round()
		positions[int(item.id)] = point
		get_child(i).position = point - Vector2(56, 39)
		get_child(i).size = Vector2(112, 78)
	queue_redraw()

func _draw() -> void:
	var palette: Dictionary = THEMES[region_index]
	Art.cover(self, RESIDENTIAL, Rect2(Vector2.ZERO, size), palette.tint)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.045, 0.06, 0.42))
	# A quiet physical chart surface, distinct from the world at its margins.
	var width := minf(940, size.x * 0.88)
	var chart := Rect2(Vector2((size.x - width) * 0.5, 0), Vector2(width, size.y))
	draw_rect(Rect2(chart.position + Vector2(5, 0), chart.size), Color(0, 0, 0, 0.40))
	draw_rect(chart, Color(palette.paper))
	draw_line(chart.position + Vector2(2, 0), chart.position + Vector2(2, size.y), Color(palette.edge), 2, false)
	draw_line(chart.position + Vector2(width - 3, 0), chart.position + Vector2(width - 3, size.y), Color(palette.edge), 2, false)
	# Sparse edge registration marks frame the chart without fake floors/grids.
	for y in range(26, int(size.y), 117):
		draw_line(Vector2(chart.position.x + 8, y), Vector2(chart.position.x + 15, y), Color("3a5158"), 2, false)
		draw_line(Vector2(chart.end.x - 15, y + 32), Vector2(chart.end.x - 8, y + 32), Color("3a5158"), 2, false)
	for item in nodes:
		for target in nodes:
			if not item.next.has(target.id) or not positions.has(int(item.id)) or not positions.has(int(target.id)): continue
			var active: bool = int(item.id) == current and available.has(int(target.id))
			var preview := reachable.has(int(item.id)) and reachable.has(int(target.id))
			var traveled := visited.has(int(item.id)) and visited.has(int(target.id))
			var possible := accessible.has(int(item.id)) and accessible.has(int(target.id))
			var origin: Vector2 = positions[int(item.id)]
			var destination: Vector2 = positions[int(target.id)]
			var direction := (destination - origin).normalized()
			var start := origin + direction * 34
			var end := destination - direction * 34
			var color := Color("d2b479") if active else (Color("8e987f") if preview else (Color("718887") if traveled else (Color("4a6974") if possible else Color("2e454d"))))
			if item.get("shortcuts", []).has(target.id):
				_draw_shortcut(origin, destination, chart, active, traveled, possible)
				continue
			if active or traveled: draw_line(start, end, color, 2, false)
			else: draw_dashed_line(start, end, color, 2 if preview or possible else 1, 7, false)

func shortcut_path(origin: Vector2, destination: Vector2) -> PackedVector2Array:
	# Travel between lanes inside the chart, never out through its left/right edge.
	# The vertical leg sits in a lane gap, clear of the skipped row's icons.
	var graph_width := minf(740, size.x * 0.74)
	var gap := graph_width / 4.0
	var ideal := (origin.x + destination.x) * 0.5
	var lane_x := size.x * 0.5
	for candidate in [size.x * 0.5 - gap, size.x * 0.5, size.x * 0.5 + gap]:
		if absf(candidate - ideal) < absf(lane_x - ideal): lane_x = candidate
	return PackedVector2Array([
		origin + Vector2(0, -36), Vector2(origin.x, origin.y - 46),
		Vector2(lane_x, origin.y - 46), Vector2(lane_x, destination.y + 46),
		Vector2(destination.x, destination.y + 46), destination + Vector2(0, 36)])

func _draw_shortcut(origin: Vector2, destination: Vector2, _chart: Rect2, active: bool, traveled: bool, possible: bool) -> void:
	var points := shortcut_path(origin, destination)
	var color := Color("d2b479") if active else Color("718887") if traveled else Color("648990") if possible else Color("3c565c")
	for i in range(points.size() - 1):
		draw_dashed_line(points[i], points[i + 1], color, 3 if active else 2, 4, false)
	var end := points[points.size() - 1]
	draw_line(end + Vector2(-5, 6), end, color, 2, false)
	draw_line(end, end + Vector2(5, 6), color, 2, false)
	# Name the unusual connection where it crosses the skipped row. Not a button.
	var mark := Vector2(points[2].x, (origin.y + destination.y) * 0.5)
	var font := preload("res://redesign/combat_pixel_font.tres")
	draw_rect(Rect2(mark - Vector2(46, 12), Vector2(92, 24)), Color(THEMES[region_index].paper))
	draw_string(font, mark + Vector2(-46, 6), "전투 생략", HORIZONTAL_ALIGNMENT_CENTER, 92, 16, color)
