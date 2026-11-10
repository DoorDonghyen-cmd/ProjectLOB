@tool
extends Button
const MapMaterial = preload("res://redesign/pipe_map/material.gd")
const Art = preload("res://redesign/pipe_map/art.gd")
var state := "later"
var preview := false
var feedback_scale := 1.0
var selection_feedback: Tween

static func icon(role: String, detail: bool = false) -> Texture2D:
	return Art.symbol(role, detail)

func configure(role: String, value: String, risk: bool = false) -> void:
	state = value
	$Picture.texture = icon(role)
	var half := 22.0 if role == "elite" else 18.0
	$Picture.set_anchors_preset(Control.PRESET_CENTER)
	$Picture.offset_left=-half; $Picture.offset_top=-half
	$Picture.offset_right=half; $Picture.offset_bottom=half
	$Risk.visible = risk or role == "elite"
	$Risk.text = "+" if risk else "·"
	$Status.text = "●" if state == "current" else "✓" if state == "visited" else ""
	refresh(false)

func refresh(selected: bool) -> void:
	var changed := selected and not button_pressed
	set_pressed_no_signal(selected)
	var color := MapMaterial.OPEN if state == "reach" else MapMaterial.PICK if state == "current" else MapMaterial.TRAIL if state == "visited" else MapMaterial.OFF if state == "off" else MapMaterial.PREVIEW if preview else MapMaterial.FUTURE
	if selected: color = MapMaterial.INK
	if selection_feedback != null and selection_feedback.is_valid(): selection_feedback.kill()
	selection_feedback = null
	$Picture.modulate = color
	if changed and feedback_scale > 0 and is_inside_tree() and not Engine.is_editor_hint():
		$Picture.modulate = color.lightened(0.35)
		selection_feedback = create_tween()
		selection_feedback.tween_property($Picture, "modulate", color, 0.18 * feedback_scale)
	queue_redraw()

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if button_pressed: draw_style_box(MapMaterial.SELECTION, rect)
	elif state == "reach":
		for p in [Vector2.ZERO, Vector2(size.x,0), size, Vector2(0,size.y)]:
			var dx: float = 1 if p.x == 0 else -1
			var dy: float = 1 if p.y == 0 else -1
			draw_line(p + Vector2(dx,dy), p + Vector2(dx*10,dy), MapMaterial.OPEN, 2, false)
			draw_line(p + Vector2(dx,dy), p + Vector2(dx,dy*10), MapMaterial.OPEN, 2, false)
	if state == "current":
		draw_rect(rect.grow(-2),MapMaterial.PICK,false,4)
	elif state == "visited":
		var corner:=size-Vector2(13,9)
		draw_polyline(PackedVector2Array([corner+Vector2(-4,0),corner+Vector2(0,4),corner+Vector2(8,-4)]),MapMaterial.TRAIL,2,false)
	if has_focus(): draw_rect(rect.grow(-2), MapMaterial.INK, false, 2)

func _ready() -> void:
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
