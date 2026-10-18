extends Control
## Short clipped response, never changes container size, target rect or gameplay clock.
var amount := 0.0
var ink := Color("b8d4bf")
var reduced_motion := false
var action_ink := Color("d4ddd5")
var response_tween: Tween
var step_current := 0
var step_total := 0

static func steps(button: Button, current: int, total: int) -> void:
	if button == null or not button.has_node("UIImpulse"): return
	var view := button.get_node("UIImpulse")
	view.step_current = current
	view.step_total = total
	view.queue_redraw()

static func install(button: Button) -> void:
	if button.has_node("UIImpulse"): return
	var view: Control = load("res://redesign/ui_impulse.gd").new()
	view.name = "UIImpulse"
	var ancestor: Node = button
	while ancestor != null:
		if "preferences" in ancestor:
			view.reduced_motion = str(ancestor.preferences.data.motion) == "instant"
			break
		ancestor = ancestor.get_parent()
	button.add_child(view)
	button.button_down.connect(func(): view.play(view.action_ink))

static func flash(button: Button, color: Color) -> void:
	if button != null and button.has_node("UIImpulse"): button.get_node("UIImpulse").play(color)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true

func play(color: Color) -> void:
	if is_instance_valid(response_tween): response_tween.kill()
	amount = 0.0 if reduced_motion else 1.0
	ink = color
	queue_redraw()
	if reduced_motion: return
	response_tween = create_tween()
	response_tween.tween_method(func(value: float): amount = value; queue_redraw(),1.0,0.0,0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _draw() -> void:
	if step_total > 0:
		var cell_width := floorf((size.x-20) / step_total)
		for i in range(step_total):
			var color := Color("9abdc8") if i < step_current else Color("425e65")
			draw_rect(Rect2(10+i*cell_width,size.y-5,cell_width-3,3),color)
	if amount <= 0: return
	var width := floorf((size.x-16)*(1.0-amount))
	if step_total == 0: draw_rect(Rect2(8,size.y-5,width,3),Color(ink,amount))
	for x in [4.0,size.x-8]: draw_rect(Rect2(x,6,4,size.y-12),Color(ink,amount*0.7))
