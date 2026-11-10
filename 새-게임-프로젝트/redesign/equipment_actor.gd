@tool
extends Control
## The same composed actor as combat; this view only frames it on the room floor.
const ACTOR_SCENE = preload("res://redesign/weapon_actor.tscn")
const WeaponActor = preload("res://redesign/weapon_actor.gd")
const Pixel = preload("res://redesign/pixel_art.gd")
const SOURCE_RECT := Rect2(80, 0, 480, 496)
@export_range(0.5, 1.0) var preview_scale := 0.85:
	set(value):
		preview_scale = value
		queue_redraw()
@export var editor_portrait: Texture2D
var actor_viewport: SubViewport
var actor: Node2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	resized.connect(queue_redraw)
	if Engine.is_editor_hint():
		queue_redraw()
		return
	actor_viewport = ACTOR_SCENE.instantiate()
	add_child(actor_viewport)
	actor = actor_viewport.get_node("Actor")
	queue_redraw()

func set_loadout(outfit: String, gun: String) -> void:
	actor.set_outfit(outfit)
	actor.configure(gun, "idle", 0.0, -1.0, 0.0)
	queue_redraw()

func display_rect() -> Rect2:
	var factor := minf(size.x / SOURCE_RECT.size.x, size.y / SOURCE_RECT.size.y) * preview_scale
	var extent := SOURCE_RECT.size * factor
	# Align registered boots, not the transparent padding below the source image.
	var foot_y := (WeaponActor.FOOT.y - SOURCE_RECT.position.y) * factor
	return Rect2(Vector2((size.x - extent.x) * 0.5, size.y - foot_y).round(), extent.round())

func _draw() -> void:
	var portrait: Texture2D = actor_viewport.get_texture() if is_instance_valid(actor_viewport) else editor_portrait
	if portrait == null: return
	var rect := display_rect()
	var factor := rect.size.x / SOURCE_RECT.size.x
	var foot := rect.position + (WeaponActor.FOOT - SOURCE_RECT.position) * factor
	Pixel.shadow(self, foot + Vector2(0, 1), 150.0 * factor)
	draw_texture_rect_region(portrait, rect, SOURCE_RECT)
