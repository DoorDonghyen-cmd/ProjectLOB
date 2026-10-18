@tool
extends Control
## Foreground hero shares the room's contain transform, including letterboxing.
@export var profile: Resource:
	set(value):
		profile = value
		queue_redraw()
@export var room_foot := Vector2(0.49, 0.852)
@export var room_height := 0.535

func _ready() -> void:
	resized.connect(queue_redraw)

func image_rect() -> Rect2:
	var parent := get_parent() as TextureRect
	if parent == null or parent.texture == null: return Rect2()
	var canvas: Vector2 = parent.texture.get_size()
	var factor: float = minf(size.x / canvas.x, size.y / canvas.y)
	return Rect2((size - canvas * factor) * 0.5, canvas * factor)

func actor_rect() -> Rect2:
	if profile == null or profile.texture == null or profile.source_rect.size.y <= 0: return Rect2()
	var area := image_rect()
	var source: Rect2 = profile.source_rect
	var dimensions: Vector2 = source.size * (area.size.y * room_height / source.size.y)
	var foot: Vector2 = area.position + area.size * room_foot
	return Rect2(foot - dimensions * profile.foot_in_source, dimensions)

func _draw() -> void:
	if profile == null or profile.texture == null: return
	draw_texture_rect_region(profile.texture, actor_rect(), profile.source_rect)
