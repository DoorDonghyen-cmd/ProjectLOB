@tool
extends TextureRect
## Shared production sprites for the showcase and selection rail; originals retained.
const ART := {
	"single": preload("res://assets/art/weapons_20261011/single_v1.tres"),
	"burst": preload("res://assets/art/weapons_20261011/burst_v1.tres"),
	"scatter": preload("res://assets/art/weapons_20261011/scatter_v1.tres"),
	"heavy": preload("res://assets/art/weapons_20261011/heavy_v1.tres"),
	"amplifier": preload("res://assets/art/weapons_20261011/amplifier_v1.tres"),
}
@export_enum("single", "burst", "scatter", "heavy", "amplifier") var gun_id := "single":
	set(value):
		gun_id = value
		if is_node_ready(): _refresh()

func _ready() -> void:
	_refresh()

func _refresh() -> void:
	texture = ART.get(gun_id, ART.single)
