@tool
extends VBoxContainer
const Art = preload("res://redesign/pipe_map/art.gd")
const MapMaterial = preload("res://redesign/pipe_map/material.gd")
var region := 0
var progress := 0.0
func configure(current_region: int, depth: float) -> void:
	region = current_region
	progress = clampf(depth,0,1)
	for i in range(5):
		var row := get_node("Zone"+str(i))
		row.get_node("Icon").texture = Art.region_mark(i, "open" if i<region else "current" if i==region else "closed")
		row.get_node("Copy/State").text = "공급 연결" if i<region else "지금 여기" if i==region else "닫힘"
		row.get_node("Icon").modulate = MapMaterial.TRAIL if i<region else MapMaterial.PICK if i==region else MapMaterial.FUTURE
		row.get_node("Copy/Name").modulate = MapMaterial.INK if i==region else MapMaterial.MUTED
	queue_redraw()
func _draw() -> void:
	if not has_node("Home"): return
	var top: float = $ControlRoom.position.y+14
	var bottom: float = $Home.position.y+14
	draw_dashed_line(Vector2(14,top),Vector2(14,bottom),MapMaterial.OFF,2,4,false)
	var here: float = get_node("Zone"+str(region)).position.y+14
	var next: float = get_node("Zone"+str(region+1)).position.y+14 if region<4 else top
	var end: float = lerpf(here,next,progress)
	draw_line(Vector2(14,bottom),Vector2(14,end),MapMaterial.TRAIL,4,false)
	draw_rect(Rect2(8,end-2,12,4),MapMaterial.PICK)
	# Keep the supply line out of each stencil's negative space; the open coupling
	# supplies its own short shaft at the bottom of the mark.
	for stop in ["ControlRoom","Zone4","Zone3","Zone2","Zone1","Zone0","Home"]:
		var row: Control=get_node(stop)
		var icon: Control=row.get_node("Icon")
		draw_rect(Rect2(row.position+icon.position,icon.size),MapMaterial.BACKGROUND)
func _ready() -> void: resized.connect(queue_redraw); sort_children.connect(queue_redraw)
