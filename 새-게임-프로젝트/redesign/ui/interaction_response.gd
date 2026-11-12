extends Node2D
## Paint-only child: no minimum size, hit testing, parent movement or input capture.
const ButtonFrame = preload("res://redesign/ui/button_frame.gd")
const PartArt = preload("res://redesign/part_icon_art.gd")
var surface: Control
var feedback
var tween: Tween
var progress:=1.0
var kind:=""
var serial:=0
var flags:=""
var installed_id := ""
var installation_origin := Vector2.ZERO
var size:Vector2:
	get:return surface.size if is_instance_valid(surface) else Vector2.ZERO

func _ready() -> void:
	surface=get_parent() as Control
	tween=null;progress=1.0;kind="";flags="";installed_id="";z_index=0
	# Canvas decoration is deliberately not a Control/Container layout child.
	surface.resized.connect(queue_redraw)
	surface.visibility_changed.connect(_visibility)
	if surface is BaseButton:
		surface.draw.connect(sync)
		surface.theme_changed.connect(queue_redraw)
		surface.mouse_entered.connect(queue_redraw)
		surface.mouse_exited.connect(queue_redraw)
		surface.focus_entered.connect(queue_redraw)
		surface.focus_exited.connect(queue_redraw)
		surface.button_down.connect(queue_redraw)
		surface.button_up.connect(queue_redraw)
		surface.pressed.connect(_committed)
		if surface.toggle_mode:surface.toggled.connect(func(_value):queue_redraw())

func _visibility() -> void:
	if not surface.is_visible_in_tree():halt()
	queue_redraw()

func sync() -> void:
	if not is_instance_valid(feedback):return
	feedback.motion()
	var next:="%s/%s/%s/%s"%[surface.disabled,surface.is_pressed(),surface.has_focus(),surface.is_hovered()]
	if next!=flags:
		flags=next
		if surface.disabled and kind=="input":halt()
		queue_redraw()

func _committed() -> void:
	if not is_instance_valid(feedback):return
	if surface.disabled or surface.is_queued_for_deletion() or not surface.is_visible_in_tree():return
	if feedback.motion()!="instant":pulse("input")

func halt() -> void:
	serial+=1
	if tween!=null and tween.is_valid():tween.kill()
	progress=1.0;kind="";installed_id="";z_index=0;queue_redraw()

func install_part(source: Control, id: String) -> void:
	pulse("installed")
	installed_id = id
	if tween != null and tween.is_running():
		z_index = 5
		tween.tween_callback(halt)
	installation_origin = size * 0.5 - Vector2(0, 18)
	if is_instance_valid(source) and source.is_visible_in_tree():
		var from := source.get_global_transform_with_canvas() * (source.size * 0.5)
		installation_origin = surface.get_global_transform_with_canvas().affine_inverse() * from
	queue_redraw()

func pulse(role: String) -> void:
	var mode:String=feedback.motion()
	halt();kind=role;progress=0.0
	var token:=serial
	if mode=="instant":
		if role=="input":halt();return
		# A stationary confirmation line; no sweep, fade or input wait.
		var receiver:WeakRef=weakref(self)
		get_tree().create_timer(0.28).timeout.connect(func():
			var live=receiver.get_ref()
			if live!=null and live.serial==token:live.halt())
	else:
		tween=create_tween()
		var duration := 0.16 if mode == "fast" else 0.30
		if role == "input": duration = 0.10 if mode == "fast" else 0.18
		elif role == "installed": duration = 0.20 if mode == "fast" else 0.42
		var transition := Tween.TRANS_LINEAR if role == "installed" else Tween.TRANS_QUAD
		tween.tween_method(func(value:float):progress=value;queue_redraw(),0.0,1.0,duration).set_trans(transition).set_ease(Tween.EASE_OUT)
	queue_redraw()

func ink() -> Color:
	# Containers have no font colour of their own. Use their current theme's ink.
	var color:Color=surface.get_theme_color("font_color") if surface.has_theme_color("font_color") else surface.get_theme_color("font_color","Label")
	return color if color.a>=0.1 else Color("d8d5bd")

func _draw() -> void:
	if not is_instance_valid(feedback) or not is_instance_valid(surface) or not surface.is_visible_in_tree() or size.x<8 or size.y<8:return
	var mode:String=feedback.motion()
	var color:=ink()
	var rect:=Rect2(Vector2(2,2),(size-Vector2(4,4)).max(Vector2.ZERO))
	if surface is Button and not surface.has_meta("paints_button_edge"):
		ButtonFrame.paint_brass(self, surface)
	if surface is BaseButton and not surface.disabled:
		if surface.is_pressed():
			draw_line(Vector2(4,4),Vector2(size.x-4,4),Color("101718",0.8),2,false)
			draw_line(Vector2(4,size.y-3),Vector2(size.x-4,size.y-3),Color(color,0.5),2,false)
		elif surface.is_hovered():
			draw_line(Vector2(6,3),Vector2(minf(size.x-6,28),3),Color(color,0.35),2,false)
		if surface.has_focus() and surface.get_theme_stylebox("focus") is StyleBoxEmpty:
			for point in [rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]:
				var direction:=-1.0 if point.x>size.x*0.5 else 1.0
				draw_line(point,point+Vector2(direction*6,0),color,2,false)
	if progress>=1 or kind.is_empty():return
	if kind == "installed":
		_draw_installation(rect, mode)
		return
	var alpha:=0.65 if mode=="instant" else (1.0-progress)*0.75
	if kind=="input":
		if surface is BaseButton and surface.disabled:return
		draw_rect(rect,Color(color,alpha*0.35),false,2)
	else:
		# Below the reading surface: retain the screen's existing ink/material.
		var y:=size.y+1
		draw_line(Vector2(2,y),Vector2(size.x-2,y),Color(color,alpha),2,false)
		if mode!="instant":
			var x:=roundf(lerpf(2,maxf(2,size.x-8),progress))
			draw_line(Vector2(x,y),Vector2(x+6,y),Color(color,alpha),3,false)

func _draw_installation(rect: Rect2, mode: String) -> void:
	var color := Color("dac28e")
	var weight := 1.0 if mode == "instant" else 1.0 - smoothstep(0.58, 1.0, progress)
	draw_rect(rect, Color(color, weight * 0.8), false, 2.0)
	for corner in [rect.position, rect.end]:
		var facing := 1.0 if corner == rect.position else -1.0
		draw_line(corner, corner + Vector2(facing * 9, 0), Color(color, weight), 2.0)
		draw_line(corner, corner + Vector2(0, facing * 7), Color(color, weight), 2.0)
	if mode == "instant" or installed_id.is_empty(): return
	var travel := clampf(progress / 0.64, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - travel, 3.0)
	var destination := size * 0.5 + Vector2(0, 2)
	if travel < 1.0:
		var center := installation_origin.lerp(destination, eased)
		center.y -= sin(travel * PI) * minf(24.0, installation_origin.distance_to(destination) * 0.1)
		var scale_value := lerpf(0.95, 0.72, eased)
		PartArt.draw(self, installed_id, center.round(), color, scale_value, false)
		if travel < 0.8:
			draw_rect(Rect2(center.round() + Vector2(-4, 13), Vector2(8, 2)), Color(color, (1.0 - travel) * 0.75))
	else:
		var seated := (progress - 0.64) / 0.36
		for side in [-1, 1]:
			var point := destination + Vector2(side * (size.x * 0.37 + seated * 8), -4 - seated * 8)
			draw_rect(Rect2(point.round(), Vector2(4, 2)), Color(color, 1.0 - seated))
