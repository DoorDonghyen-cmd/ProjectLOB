@tool
extends Control
const Data = preload("res://redesign/campaign_content.gd")
const Place = preload("res://redesign/pipe_map/place.tscn")
const MapMaterial = preload("res://redesign/pipe_map/material.gd")
signal selected(id: int)
signal inspected(id: int)
var nodes: Array = []
var available: Array = []
var visited: Array = []
var accessible: Array = []
var reachable: Array = []
var positions: Dictionary = {}
var paths: Array = []
var selection := 0
var current := 0
var floors := 8
var region_index := 0
var modern := true
var feedback_scale := 1.0
var gate_id := 0
var viewport_height := 400.0
var tick := 0.0
var flow_step := 0

func _ready() -> void:
	resized.connect(_layout)
	set_process(false)

func setup(campaign) -> void:
	for child in get_children(): remove_child(child); child.queue_free()
	nodes = campaign.current_nodes()
	available = campaign.choices().map(func(n): return int(n.id))
	# JSON restores numbers as floats; Array.has/find require matching types.
	# Normalize this view's IDs so saved journeys retain their visited trail.
	visited = campaign.s.visited.map(func(id): return int(id))
	current = int(campaign.s.node)
	floors = int(campaign.region_info().floors)
	region_index = int(campaign.s.region)
	modern = int(campaign.s.get("map_version", 1)) >= 2
	accessible = descendants(available)
	for item in nodes:
		if str(item.kind) == "boss": gate_id = int(item.id); continue
		var button := Place.instantiate()
		button.name = "map_node_" + str(item.id)
		button.feedback_scale = feedback_scale
		button.tooltip_text = str(item.name)
		add_child(button)
		button.configure(Data.room_kind(item), place_state(int(item.id)), str(item.route) == "duct")
		button.pressed.connect(func():
			select_room(int(item.id))
			if available.has(int(item.id)): selected.emit(int(item.id))
			else: inspected.emit(int(item.id)))
	set_process(feedback_scale > 0)
	_layout()

func descendants(starts: Array) -> Array:
	var result: Array = []
	var pending := starts.duplicate()
	while not pending.is_empty():
		var id: int = int(pending.pop_back())
		if result.has(id): continue
		result.append(id)
		for item in nodes:
			if int(item.id) == id: pending.append_array(item.next); break
	return result

func place_state(id: int) -> String:
	if id == current: return "current"
	if available.has(id): return "reach"
	if visited.has(id): return "visited"
	return "later" if accessible.has(id) else "off"

func select_room(id: int) -> void:
	selection = id
	reachable = descendants([id]) if accessible.has(id) else []
	for button in get_children():
		var node_id := int(str(button.name).trim_prefix("map_node_"))
		button.preview = reachable.has(node_id)
		button.refresh(node_id == id)
	_layout()

func _even(value: float) -> float: return roundf(value / 2.0) * 2.0
func _half(item: Dictionary) -> float: return 24.0 if Data.room_kind(item) == "elite" else 20.0
func _row_half(depth: int) -> float:
	var result := 20.0
	for item in nodes:
		if int(item.floor) == depth: result = maxf(result, _half(item))
	return result

func _layout() -> void:
	if nodes.is_empty(): return
	var rows := floors - 1
	var row_y := {rows: 28.0}
	var fit := floorf((viewport_height - 58.0) / maxf(1, rows - 1) / 2.0) * 2.0
	for f in range(rows - 1, 0, -1): row_y[f] = float(row_y[f+1]) + maxf(fit, _row_half(f) + _row_half(f+1) + 24.0)
	custom_minimum_size.y = float(row_y[1]) + 30.0
	positions.clear()
	for item in nodes:
		if int(item.id) == gate_id: continue
		var ratio: float = (float(item.lane)+0.5)/4.0 if modern else (0.26 if int(item.lane)==0 else 0.74)
		positions[int(item.id)] = Vector2(_even(size.x * ratio), row_y[int(item.floor)])
		var button := get_node_or_null("map_node_"+str(item.id)) as Control
		if button != null: button.position = positions[int(item.id)] - Vector2(30,22); button.size = Vector2(60,44)
	paths.clear()
	for item in nodes:
		var id := int(item.id)
		if id == gate_id: continue
		var origin: Vector2 = positions[id]
		if int(item.floor) == 1:
			_add_path(0,id,PackedVector2Array([Vector2(origin.x,custom_minimum_size.y),origin+Vector2(0,_half(item))]))
		for target_id in item.next:
			var target: Dictionary = {}
			for candidate in nodes:
				if int(candidate.id)==int(target_id): target=candidate; break
			if target.is_empty(): continue
			if int(target_id)==gate_id:
				_add_path(id,int(target_id),PackedVector2Array([origin-Vector2(0,_half(item)),Vector2(origin.x,0)])); continue
			var destination: Vector2 = positions[int(target_id)]
			if item.get("shortcuts",[]).has(target_id):
				_add_path(id,int(target_id),shortcut_path(origin,destination),true); continue
			var direction := signf(destination.x-origin.x)
			var a := origin + Vector2(direction*12,-_half(item))
			var b := destination + Vector2(-direction*12,_half(target))
			var mid := _even((a.y+b.y)*0.5) + (-6.0 if int(item.lane)%2 else 6.0)
			var line := PackedVector2Array([a,b]) if direction==0 else PackedVector2Array([a,Vector2(a.x,mid+4),Vector2(a.x+direction*4,mid),Vector2(b.x-direction*4,mid),Vector2(b.x,mid-4),b])
			_add_path(id,int(target_id),line)
	paths.sort_custom(func(a,b): return ["off","later","preview","open","trail","pick"].find(a.state)<["off","later","preview","open","trail","pick"].find(b.state))
	queue_redraw()

func shortcut_path(origin: Vector2, destination: Vector2) -> PackedVector2Array:
	# Route through a lane gap, away from the node in the skipped row.
	var gap := size.x / (4.0 if modern else 2.0)
	var lane_x := size.x * 0.5
	for candidate in [size.x*0.5-gap,size.x*0.5,size.x*0.5+gap]:
		if absf(candidate-(origin.x+destination.x)*0.5)<absf(lane_x-(origin.x+destination.x)*0.5): lane_x=candidate
	return PackedVector2Array([origin+Vector2(0,-24),origin+Vector2(0,-32),Vector2(_even(lane_x),origin.y-32),Vector2(_even(lane_x),destination.y+32),destination+Vector2(0,32),destination+Vector2(0,24)])

func _add_path(from: int, to: int, points: PackedVector2Array, shortcut: bool=false) -> void:
	var index := visited.find(from)
	var state := "off"
	if (from==0 and not visited.is_empty() and int(visited[0])==to) or (index>=0 and index+1<visited.size() and int(visited[index+1])==to): state="trail"
	elif from==current and available.has(to): state="pick" if selection==to else "open"
	elif accessible.has(from) and accessible.has(to): state="preview" if reachable.has(from) else "later"
	paths.append({"from":from,"to":to,"points":points,"state":state,"shortcut":shortcut})

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	tick += delta
	if tick>=0.125: tick=0; flow_step=(flow_step+1)%4; queue_redraw()

func _draw() -> void:
	for x in range(0,int(size.x),64): draw_line(Vector2(x,0),Vector2(x,size.y),Color("5b61571f"),1,false)
	for y in range(0,int(size.y),64): draw_line(Vector2(0,y),Vector2(size.x,y),Color("5b61571f"),1,false)
	for path in paths:
		var color: Color = MapMaterial.PATHS[path.state]
		var width := 6.0 if path.state in ["trail","pick"] else 4.0 if path.state=="open" else 2.0
		var points: PackedVector2Array = path.points
		if path.state in ["trail","pick","open"]: draw_polyline(points,Color("30291a") if path.state=="trail" else Color("24271c"),width+4,false)
		for i in range(points.size()-1):
			if path.shortcut or path.state=="off": draw_dashed_line(points[i],points[i+1],color,width,4,false)
			else: draw_line(points[i],points[i+1],color,width,false)
			if path.state=="pick" and feedback_scale>0:
				var length := points[i].distance_to(points[i+1])
				for step in range(flow_step*2,int(length),8):
						draw_rect(Rect2((points[i].move_toward(points[i+1],step)-Vector2.ONE).round(),Vector2(2,2)),MapMaterial.INK)
		# One upward chevron on the longest vertical leg makes direction readable
		# without adding arrows to every future branch.
		if path.state in ["trail","pick","open"]:
			var longest:=0.0
			var arrow:=Vector2.ZERO
			for i in range(points.size()-1):
				var length:=points[i].distance_to(points[i+1])
				if is_equal_approx(points[i].x,points[i+1].x) and length>longest:
					longest=length;arrow=((points[i]+points[i+1])*0.5).round()
			if longest>=20:
				var chevron:=PackedVector2Array([arrow+Vector2(-6,3),arrow+Vector2(0,-3),arrow+Vector2(6,3)])
				draw_polyline(chevron,MapMaterial.BACKGROUND,6,false)
				draw_polyline(chevron,color,2,false)
		if path.shortcut:
			var mark := (points[2]+points[3])*0.5
			draw_rect(Rect2(mark-Vector2(38,12),Vector2(76,24)),MapMaterial.BACKGROUND)
			draw_string(preload("res://redesign/combat_pixel_font.tres"),mark+Vector2(-38,6),"전투 생략",HORIZONTAL_ALIGNMENT_CENTER,76,16,color)
	# Two small collars belong to each location, not each edge: merging paths stay quiet.
	for item in nodes:
		var id := int(item.id)
		if not positions.has(id): continue
		var color := MapMaterial.OFF if place_state(id)=="off" else MapMaterial.METAL
		if id==selection: color=MapMaterial.PICK
		elif id==current: color=MapMaterial.BRASS
		var p: Vector2=positions[id]
		for sign_y in [-1,1]:
			draw_line(p+Vector2(-4,sign_y*_half(item)),p+Vector2(4,sign_y*_half(item)),color,2,false)
