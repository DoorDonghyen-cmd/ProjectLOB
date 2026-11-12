@tool
extends Control

const Parts = preload("res://redesign/part_icon_art.gd")
const AmmoArt = preload("res://redesign/ammo_art.gd")
const ICONS := {
	"cadence": "supply", "efficiency": "cooling_breech", "thermal": "cooling_breech",
	"conduction": "arc_splitter", "chain": "ordinary_chain", "growth": "siege_drive",
	"bag": "reserve", "copy": "duplex", "mastery": "sequencer", "mastery_support": "radiator", "drive": "siege_drive",
}

@export var item_id := "cadence":
	set(value):
		item_id = value
		queue_redraw()
var ammo := false:
	set(value):
		ammo = value
		queue_redraw()

func _ready() -> void:
	resized.connect(queue_redraw)

func _draw() -> void:
	var point := (size * 0.5).floor()
	if ammo:
		AmmoArt.draw(self, item_id, Rect2(point - Vector2(14, 18), Vector2(28, 36)))
	elif item_id == "production":
		for offset in [-13, 0, 13]:
			AmmoArt.draw(self, "precise", Rect2(point + Vector2(offset - 8, -14), Vector2(16, 28)))
	else:
		Parts.draw(self, str(ICONS.get(item_id, "supply")), point, Color("c3a772"), 0.65)
