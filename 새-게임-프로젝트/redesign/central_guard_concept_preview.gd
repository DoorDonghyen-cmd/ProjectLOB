extends Control
## Art comparison only. No campaign, model, preferences or save mutations.
const REGISTER := "res://assets/art/central_guard_concepts_20261025/registration.json"
const REGISTER_B := "res://assets/art/central_guard_alt_20261025/registration.json"
const FONT = preload("res://redesign/combat_pixel_font.tres")
const SKIN = preload("res://redesign/combat_pixel_skin.gd")
const TEXTURES := {
	"guard_rusher": preload("res://assets/art/central_guard_concepts_20261025/guard_rusher_v1.png"),
	"guard_heavy": preload("res://assets/art/central_guard_concepts_20261025/guard_heavy_v1.png"),
	"guard_shield": preload("res://assets/art/central_guard_concepts_20261025/guard_shield_v1.png"),
	"guard_artillery": preload("res://assets/art/central_guard_concepts_20261025/guard_artillery_v1.png"),
}
const TEXTURES_B := {
	"guard_rusher": preload("res://assets/art/central_guard_alt_20261025/guard_rusher_b.png"),
	"guard_heavy": preload("res://assets/art/central_guard_alt_20261025/guard_heavy_b.png"),
	"guard_shield": preload("res://assets/art/central_guard_alt_20261025/guard_shield_b.png"),
	"guard_artillery": preload("res://assets/art/central_guard_alt_20261025/guard_artillery_b.png"),
}
var standalone := false
var return_focus: WeakRef
var stage
var modes: Array[Button] = []
var backgrounds: Array[Button] = []
var variants: Array[Button] = []
var variant_items: Array = []

class Stage extends "res://redesign/samples/tower_battle_view.gd":
	var catalogue := true
	var comparison := false
	var items: Array = []
	var all_items: Array = []
	var actors: Array[Sprite2D] = []
	var drawn_rects: Array[Rect2] = []
	var feet_points: Array[Vector2] = []
	func _ready() -> void:
		super._ready()
		set_route_background(4, 1, 10)
		character_size_multiplier = 0.65
		display_state = {"gun":"single","outfit":"work"}
		rebuild_actors()
	func rebuild_actors() -> void:
		for actor in actors:
			remove_child(actor)
			actor.queue_free()
		actors.clear()
		for item in items:
			var actor := Sprite2D.new()
			actor.texture = (TEXTURES_B if item.get("variant","A") == "B" else TEXTURES)[str(item.id)]
			actor.centered = false
			actor.region_enabled = true
			var bounds: Array = item.source
			actor.region_rect = Rect2(bounds[0],bounds[1],bounds[2],bounds[3])
			actor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			var material := ShaderMaterial.new()
			material.shader = preload("res://redesign/monster_alpha_cutout.gdshader")
			actor.material = material
			add_child(actor)
			actors.append(actor)
		queue_redraw()
	func _draw() -> void:
		if catalogue: draw_rect(Rect2(Vector2.ZERO,size),Color("15252b"))
		else:
			character_reference_height = 240.0 if get_viewport_rect().size.y < 960 else 350.0
			super._draw()
		if actors.size() != items.size() or items.is_empty(): return
		drawn_rects.clear()
		feet_points.clear()
		var row_height := size.y/2.0 if comparison else size.y
		var baseline := row_height*0.72 if catalogue else player_feet().y
		var max_span := 1.0
		for item in all_items:
			var bounds: Array = item.source
			var anchor: Array = item.feet
			max_span = maxf(max_span,2.0*maxf(float(anchor[0])-float(bounds[0]),float(bounds[0])+float(bounds[2])-float(anchor[0]))*float(item.height)/float(bounds[3]))
		var factor := minf(2.4,(size.x/4.0-32.0)/max_span) if catalogue else 1.0
		factor = minf(factor,(baseline-50.0)/132.0)
		if catalogue:
			for row in range(2 if comparison else 1):
				var line_y := baseline+row_height*row+1
				draw_line(Vector2(16,line_y),Vector2(size.x-16,line_y),Color("435659"),1)
				if comparison: draw_string(FONT,Vector2(16,row_height*row+26),["A · 태엽형","B · 봉쇄형"][row],HORIZONTAL_ALIGNMENT_LEFT,size.x-32,20,Color("d3d9cd"))
		for i in range(items.size()):
			var item: Dictionary = items[i]
			var bounds: Array = item.source
			var anchor: Array = item.feet
			var scale_value := float(item.height)/float(bounds[3])*factor
			var column := i%4
			var row := i/4 if comparison else 0
			var foot := Vector2(size.x*(float(column)+0.5)/4.0 if catalogue else size.x*(0.40+0.16*column),baseline+row_height*row).round()
			var actor: Sprite2D = actors[i]
			actor.position = (foot-Vector2(float(anchor[0])-float(bounds[0]),float(anchor[1])-float(bounds[1]))*scale_value).round()
			actor.scale = Vector2.ONE*scale_value
			preload("res://redesign/actor_art_style.gd").apply(actor.material,scale_value,not catalogue)
			var rect := Rect2(actor.position,Vector2(bounds[2],bounds[3])*scale_value)
			drawn_rects.append(rect)
			feet_points.append(foot)
			if not catalogue: Pixel.shadow(self,foot+Vector2(0,1),minf(60,rect.size.x*0.5))
			var width := size.x/4.0-12.0 if catalogue else size.x*0.16
			var label_x := foot.x-width*0.5
			draw_string(FONT,Vector2(label_x,foot.y+28),str(item.name),HORIZONTAL_ALIGNMENT_CENTER,width,22 if catalogue else 18,Color("d3d9cd"))
			if catalogue and not comparison:
				draw_string(FONT,Vector2(label_x,foot.y+58),str(item.role),HORIZONTAL_ALIGNMENT_CENTER,width,16,Color("92a6a3"))
		if not catalogue:
			draw_string(FONT,Vector2(20,30),"중앙 통제구 · 현재 주인공과 전투 표시 크기 비교",HORIZONTAL_ALIGNMENT_LEFT,size.x-40,18,Color("c2cbbf"))

func _ready() -> void:
	standalone = get_parent() == get_tree().root
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_meta("lob_modal",true)
	z_index = 100
	mouse_filter = Control.MOUSE_FILTER_STOP
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null: return_focus = weakref(focused)
	var background := ColorRect.new()
	background.color = Color("0e191f")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+edge,20)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",12)
	margin.add_child(column)
	var heading := HBoxContainer.new()
	column.add_child(heading)
	var title := Label.new()
	title.text = "중앙 통제구 · 친위대 일반 4종"
	title.add_theme_font_override("font",FONT)
	title.add_theme_font_size_override("font_size",28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	button(heading,"닫기","CloseCentralGuards",close)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation",12)
	column.add_child(tabs)
	for i in range(2):
		var tab := button(tabs,["확대 비교","전투 크기"][i],["GuardCatalogue","GuardBattle"][i],select_mode.bind(i))
		tab.toggle_mode = true
		modes.append(tab)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_child(spacer)
	for i in range(3):
		var tab := button(tabs,["검문 회랑","공급 통제실","중앙 제어핵"][i],"GuardBackground%d"%i,select_background.bind(i))
		tab.toggle_mode = true
		backgrounds.append(tab)
	var variant_row := HBoxContainer.new()
	variant_row.add_theme_constant_override("separation",12)
	column.add_child(variant_row)
	for i in range(3):
		var tab := button(variant_row,["A · 태엽형","B · 봉쇄형","A/B 함께 보기"][i],["GuardVariantA","GuardVariantB","GuardCompare"][i],select_variant.bind(i))
		tab.toggle_mode = true
		variants.append(tab)
	stage = Stage.new()
	stage.name = "CentralGuardStage"
	variant_items = [JSON.parse_string(FileAccess.get_file_as_string(REGISTER)).items,JSON.parse_string(FileAccess.get_file_as_string(REGISTER_B)).items]
	stage.all_items = variant_items[0]+variant_items[1]
	stage.items = variant_items[1]
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(stage)
	var note := Label.new()
	note.text = "외형 시안 · 정지 자세 비교 · 본편 적 편성과 전투 규칙 적용 전"
	note.add_theme_font_override("font",FONT)
	note.add_theme_font_size_override("font_size",18)
	note.add_theme_color_override("font_color",Color("8fa5a6"))
	column.add_child(note)
	select_mode(0)
	variants[1].set_pressed_no_signal(true)
	backgrounds[0].set_pressed_no_signal(true)
	modes[0].grab_focus()

func button(parent: Node, text_value: String, key: String, callback: Callable) -> Button:
	var control := Button.new()
	control.text = text_value
	control.name = key
	control.custom_minimum_size = Vector2(132,48)
	control.add_theme_font_override("font",FONT)
	control.add_theme_font_size_override("font_size",20)
	for state in ["normal","hover","pressed","disabled","focus"]: control.add_theme_stylebox_override(state,SKIN.box("button",state))
	control.pressed.connect(callback)
	parent.add_child(control)
	return control

func select_mode(index: int) -> void:
	if stage.comparison: index = 0
	stage.catalogue = index == 0
	for i in range(modes.size()): modes[i].set_pressed_no_signal(i == index)
	for tab in backgrounds: tab.disabled = index == 0
	stage.queue_redraw()

func select_variant(index: int) -> void:
	stage.comparison = index == 2
	stage.items = stage.all_items if stage.comparison else variant_items[index]
	stage.rebuild_actors()
	modes[1].disabled = stage.comparison
	for i in range(variants.size()): variants[i].set_pressed_no_signal(i == index)
	select_mode(0 if stage.catalogue or stage.comparison else 1)

func select_background(index: int) -> void:
	stage.set_route_background(4,[1,5,8][index],10)
	for i in range(backgrounds.size()): backgrounds[i].set_pressed_no_signal(i == index)

func close() -> void:
	if standalone:
		get_tree().quit()
		return
	if return_focus != null and is_instance_valid(return_focus.get_ref()): return_focus.get_ref().grab_focus()
	queue_free()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
