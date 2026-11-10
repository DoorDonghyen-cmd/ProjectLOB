@tool
extends Control
## Shared production sprites for the showcase and selection rail; originals retained.
const Art = preload("res://redesign/weapon_art.gd")
@export var texture: Texture2D
@export var art_limit := Vector2(298, 106)

@export_enum("single", "burst", "scatter", "heavy", "amplifier", "rewinder", "deadbolt") var gun_id := "single":
	set(value):
		gun_id = value
		if is_node_ready(): _refresh()

func _ready() -> void:
	resized.connect(queue_redraw)
	_refresh()

func _refresh() -> void:
	texture = Art.atlas(gun_id)
	var surface := ShaderMaterial.new()
	surface.shader = preload("res://redesign/monster_alpha_cutout.gdshader")
	# A shared 128-column material sample keeps enlarged catalog art from looking
	# more finely engraved than the outfit portrait; the original remains intact.
	surface.set_shader_parameter("source_pixel_step", maxf(1.0, roundf(texture.region.size.x / 128.0)))
	surface.set_shader_parameter("shadow_lift", 0.65)
	material = surface
	queue_redraw()

func art_rect() -> Rect2:
	if texture == null:
		return Rect2()
	var source := texture.get_size()
	var extent := size.min(art_limit)
	var factor := minf(extent.x / source.x, extent.y / source.y)
	var art_size := source * factor
	return Rect2(((size - art_size) * 0.5).round(), art_size)

func _draw() -> void:
	if texture != null:
		draw_texture_rect(texture, art_rect(), false)
