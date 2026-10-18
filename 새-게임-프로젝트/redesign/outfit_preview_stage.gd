@tool
extends Control
const BACKGROUND = preload("res://assets/art/tower_sample_20261003/residential_tower.png")
var magnification := 1.0
var animation := ""
var elapsed := 0.0
var gun := "single"
var current_pose := "idle"
@onready var viewport: SubViewport = $WeaponActorViewport
@onready var actor: Node2D = $WeaponActorViewport/Actor

func _ready() -> void:
	resized.connect(queue_redraw)
	if not Engine.is_editor_hint(): choose_pose("idle")

func choose_gun(id: String) -> void:
	gun = id
	choose_pose(current_pose)

func choose_pose(id: String) -> void:
	animation = ""
	current_pose = id
	actor.configure(gun, id, 0.0, -1.0, 0.7 if id == "cooling" else 0.0)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	queue_redraw()

func play_action(id: String) -> void:
	animation = id
	elapsed = 0.0

func _process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	if animation.is_empty(): return
	elapsed += delta
	if animation == "fire":
		if elapsed >= 0.6:
			choose_pose("aim")
			return
		current_pose = "recoil" if elapsed < 0.14 else "aim"
		actor.configure(gun, current_pose, maxf(0.0, 1.0 - elapsed / 0.3))
	else:
		var progress := elapsed / 1.6
		if progress >= 1.0:
			choose_pose("aim")
			return
		current_pose = "reload_open" if progress < 0.5 else "reload_seat"
		actor.configure(gun, current_pose, 0.0, progress)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	queue_redraw()

func foot_position() -> Vector2:
	return Vector2(size.x * 0.30, size.y - 24).round()

func figure_scale() -> float:
	return 110.0 / 447.0 * magnification

func _draw() -> void:
	if size.x <= 0 or size.y <= 0: return
	var scale_value := maxf(size.x / BACKGROUND.get_width(), (size.y - 24) / 720.0)
	var source_size := size / scale_value
	draw_texture_rect_region(BACKGROUND, Rect2(Vector2.ZERO, size), Rect2(0, 720.0 - (size.y - 24) / scale_value, source_size.x, source_size.y))
	if not is_instance_valid(viewport): return
	var factor := figure_scale()
	var foot := foot_position()
	draw_ellipse_shadow(foot)
	draw_texture_rect(viewport.get_texture(), Rect2((foot - actor.FOOT * factor).round(), (Vector2(viewport.size) * factor).round()), false)

func draw_ellipse_shadow(foot: Vector2) -> void:
	draw_rect(Rect2(foot + Vector2(-21, -1) * magnification, Vector2(44, 4) * magnification), Color(0.03, 0.05, 0.055, 0.5))
