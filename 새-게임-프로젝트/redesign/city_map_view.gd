extends Control
const Art = preload("res://redesign/world_art.gd")
const Facility = preload("res://redesign/map_facility.tscn")
const RESIDENTIAL = preload("res://assets/art/map_residential_20261009/residential_shaft.png")
signal entered(id: int)
signal selected(id: int)
signal inspected(id: int)
const Data = preload("res://redesign/campaign_content.gd")
const COLORS := {"combat": Color("a4b4ba"), "elite": Color("ec9677"), "workshop": Color("d6bb84"), "boss": Color("f2a38d"), "shop": Color("e4cc84"), "supply": Color("a9bfdf"), "event": Color("baace4"), "bypass": Color("8dbfc9")}
var nodes: Array = []
var available: Array = []
var visited: Array = []
var current := 0
var floors := 6
var positions: Dictionary = {}
var selection := 0
var reachable: Array = []
var modern := false
var residential := false

func select_room(id: int) -> void:
	if selection == id: return
	selection = id
	reachable = [id]
	for item in nodes:
		if reachable.has(int(item.id)):
			for next_id in item.next:
				if not reachable.has(int(next_id)): reachable.append(int(next_id))
	for i in range(nodes.size()):
		get_child(i).refresh(int(nodes[i].id) == id)
	queue_redraw()

func setup(campaign) -> void:
	nodes = campaign.current_nodes()
	available = campaign.choices().map(func(item): return int(item.id))
	visited = campaign.s.visited.map(func(id): return int(id))
	current = int(campaign.s.node)
	floors = int(campaign.region_info().floors)
	modern = int(campaign.s.get("map_version", 1)) >= 2
	residential = int(campaign.s.region) == 0
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	custom_minimum_size.y = maxi(450, floors * 90 + 24)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	clip_contents = true
	resized.connect(_layout)
	for item in nodes:
		var button := Facility.instantiate()
		button.name = "map_node_" + str(item.id)
		var role := Data.room_kind(item)
		var caption := Data.kind_name(role) + (" +" if item.route == "duct" else "")
		button.configure(role, caption, available.has(int(item.id)), int(item.id) == current, visited.has(int(item.id)))
		button.tooltip_text = str(item.name)
		button.pressed.connect(func():
			select_room(int(item.id))
			if available.has(int(item.id)): selected.emit(int(item.id))
			else: inspected.emit(int(item.id))
		)
		add_child(button)
	_layout.call_deferred()

func _layout() -> void:
	positions.clear()
	var spacing := (size.y - 24) / float(floors)
	var width := minf(112, (size.x - 32) / 4.4)
	for i in range(nodes.size()):
		var item: Dictionary = nodes[i]
		var single := 0
		for other in nodes:
			if int(other.floor) == int(item.floor): single += 1
		var ratio := (float(item.lane) + 0.5) / 4.0 if modern else (0.26 if int(item.lane) == 0 else 0.74)
		var graph_width := minf(1000, size.x - 32)
		var x := (size.x - graph_width) * 0.5 + graph_width * (0.5 if single == 1 else ratio)
		var y := 12 + (floors - int(item.floor) + 0.5) * spacing
		positions[int(item.id)] = Vector2(x, y)
		var button := get_child(i) as Button
		button.position = Vector2(x - width / 2, y - 39)
		button.size = Vector2(width, 78)
	queue_redraw()

func _draw() -> void:
	Art.cover(self, RESIDENTIAL if residential else Art.texture("city_overview"), Rect2(Vector2.ZERO, size))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.045, 0.06, 0.22 if residential else 0.80))
	# One translucent chart surface groups the route graph, while the shaft
	# stays visible through it and beside it. Individual facilities stay unboxed.
	var chart_width := minf(1040, size.x - 8)
	var chart := Rect2(Vector2((size.x - chart_width) * 0.5, 4), Vector2(chart_width, size.y - 8))
	draw_rect(chart, Color(0.035, 0.075, 0.10, 0.52))
	draw_rect(chart, Color(0.38, 0.51, 0.56, 0.38), false, 1)
	for item in nodes:
		for target in nodes:
			if not item.next.has(target.id): continue
			if not positions.has(int(item.id)) or not positions.has(int(target.id)): continue
			var active: bool = int(item.id) == current and available.has(int(target.id))
			var preview := reachable.has(int(item.id)) and reachable.has(int(target.id))
			var traveled := visited.has(int(item.id)) and visited.has(int(target.id))
			var color := Color("edc47a") if active else (Color("b5a786") if preview else (Color("72868b") if traveled else Color("4b6673")))
			# Clip the original diagonal to each target's edge. Joining only top/bottom
			# makes branches look horizontal and falsely connects adjacent facilities.
			var origin: Vector2 = positions[int(item.id)]
			var destination: Vector2 = positions[int(target.id)]
			var direction := (destination - origin).normalized()
			var half_width: float = get_child(0).size.x * 0.5
			var edge := minf(half_width / maxf(absf(direction.x), 0.001), 39.0 / maxf(absf(direction.y), 0.001))
			var start := origin + direction * edge
			var end := destination - direction * edge
			draw_line(start, end, Color("0b1720"), 7, false)
			draw_line(start, end, color, 3 if active or preview else 2, false)
			if active or preview:
				var midpoint := (start + end) * 0.5
				draw_rect(Rect2(midpoint.round() - Vector2(2, 2), Vector2(4, 4)), color)
