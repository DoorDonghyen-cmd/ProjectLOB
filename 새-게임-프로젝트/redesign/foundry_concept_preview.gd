extends Control
## Art-only review: no campaign/model/save calls and no combat stats implied.
const REGISTER := "res://assets/art/foundry_concepts_20261022/registration.json"
const LEADERS := "res://assets/art/foundry_leaders_20261023/registration.json"
const FONT = preload("res://redesign/combat_pixel_font.tres")
const SKIN = preload("res://redesign/combat_pixel_skin.gd")
var standalone := false
var return_focus: WeakRef
var stage
var modes: Array[Button] = []
var groups: Array[Button] = []
var ordinary_items: Array = []
var leader_items: Array = []

class Stage extends "res://redesign/samples/tower_battle_view.gd":
	var catalogue := true
	var items: Array = []
	var actors: Array[Sprite2D] = []
	var drawn_rects: Array[Rect2] = []
	var feet_points: Array[Vector2] = []
	func _ready() -> void:
		super._ready()
		tower_texture = preload("res://assets/art/tower_sample_20261003/residential_tower.png")
		character_size_multiplier = 0.65
		character_reference_height = 350
		display_state = {"gun":"single","outfit":"work"}
		rebuild_actors()
	func rebuild_actors() -> void:
		for actor in actors:
			remove_child(actor)
			actor.queue_free()
		actors.clear()
		for item in items:
			var path := str(item.file)
			if not path.begins_with("res://"): path = "res://assets/art/foundry_concepts_20261022/"+path
			var source_image := Image.load_from_file(path)
			var actor := Sprite2D.new()
			actor.texture = ImageTexture.create_from_image(source_image)
			actor.centered = false
			actor.region_enabled = true
			var bounds: Array = item.source
			actor.region_rect = Rect2(bounds[0],bounds[1],bounds[2],bounds[3])
			actor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			var cutout := ShaderMaterial.new()
			cutout.shader = preload("res://redesign/monster_alpha_cutout.gdshader")
			actor.material = cutout
			add_child(actor)
			actors.append(actor)
		queue_redraw()
	func _draw() -> void:
		if catalogue: draw_rect(Rect2(Vector2.ZERO,size),Color("15252b"))
		else:
			character_reference_height = 240.0 if get_viewport_rect().size.y<960 else 350.0
			super._draw()
		if actors.size()!=items.size() or items.is_empty(): return
		drawn_rects.clear()
		feet_points.clear()
		var baseline := size.y*0.72 if catalogue else player_feet().y
		var count := float(items.size())
		var max_span := 1.0
		var max_height := 1.0
		for item in items:
			var source: Array = item.source
			var anchor: Array = item.feet
			var scale_value := float(item.height)/float(source[3])
			max_span = maxf(max_span,2.0*maxf(float(anchor[0])-float(source[0]),float(source[0])+float(source[2])-float(anchor[0]))*scale_value)
			max_height = maxf(max_height,float(item.height))
		var factor := minf(2.4,(size.x/count-36.0)/max_span) if catalogue else 1.0
		factor = minf(factor,(baseline-48.0)/max_height)
		if catalogue: draw_line(Vector2(16,baseline+1),Vector2(size.x-16,baseline+1),Color("435659"),1)
		for i in range(items.size()):
			var item: Dictionary = items[i]
			var source: Array = item.source
			var anchor: Array = item.feet
			var scale_value: float = float(item.height)/float(source[3])*factor
			var battle_x := lerpf(0.40,0.87,float(i)/maxf(1.0,count-1.0))
			var foot := Vector2(size.x*(float(i)+0.5)/count if catalogue else size.x*battle_x,baseline).round()
			var actor: Sprite2D = actors[i]
			actor.position = (foot-Vector2(float(anchor[0])-float(source[0]),float(anchor[1])-float(source[1]))*scale_value).round()
			actor.scale = Vector2.ONE*scale_value
			var rect := Rect2(actor.position,Vector2(source[2],source[3])*scale_value)
			drawn_rects.append(rect)
			feet_points.append(foot)
			var label_width := size.x/count-12.0 if catalogue else size.x*0.22
			var label_x := foot.x-label_width*0.5
			draw_string(FONT,Vector2(label_x,baseline+30),str(item.name),HORIZONTAL_ALIGNMENT_CENTER,label_width,22 if catalogue else 18,Color("d3d9cd"))
			if catalogue: draw_string(FONT,Vector2(label_x,baseline+62),str(item.role),HORIZONTAL_ALIGNMENT_CENTER,label_width,16,Color("92a6a3"))
		if not catalogue: draw_string(FONT,Vector2(20,30),"전투 크기 비교 · 주거 배경은 화풍 비교용",HORIZONTAL_ALIGNMENT_LEFT,size.x-40,18,Color("c2cbbf"))

func _ready() -> void:
	standalone = get_parent()==get_tree().root
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_meta("lob_modal",true)
	z_index = 100
	mouse_filter = Control.MOUSE_FILTER_STOP
	var focused := get_viewport().gui_get_focus_owner()
	if focused!=null: return_focus = weakref(focused)
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
	title.text = "축열 주조장 · 노동 자동인형"
	title.add_theme_font_override("font",FONT)
	title.add_theme_font_size_override("font_size",28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	button(heading,"닫기","CloseFoundryConcepts",close)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation",12)
	column.add_child(tabs)
	for i in range(2):
		var tab := button(tabs,["일반 4종","정예 · 보스"][i],["FoundryOrdinary","FoundryLeaders"][i],select_group.bind(i))
		tab.toggle_mode = true
		groups.append(tab)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_child(spacer)
	for i in range(2):
		var tab := button(tabs,["확대 비교","전투 크기"][i],["FoundryConceptCatalogue","FoundryConceptBattle"][i],select_mode.bind(i))
		tab.toggle_mode = true
		modes.append(tab)
	stage = Stage.new()
	stage.name = "FoundryConceptStage"
	ordinary_items = JSON.parse_string(FileAccess.get_file_as_string(REGISTER)).items
	leader_items = JSON.parse_string(FileAccess.get_file_as_string(LEADERS)).items
	stage.items = [ordinary_items[1]]+leader_items
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(stage)
	var note := Label.new()
	note.text = "외형 시안 · 본편 미적용 · 정지 자세 비교"
	note.add_theme_font_override("font",FONT)
	note.add_theme_font_size_override("font_size",18)
	note.add_theme_color_override("font_color",Color("8fa5a6"))
	column.add_child(note)
	select_mode(0)
	groups[1].set_pressed_no_signal(true)
	groups[1].grab_focus()

func button(parent: Node, text_value: String, key: String, callback: Callable) -> Button:
	var control := Button.new()
	control.text = text_value
	control.name = key
	control.custom_minimum_size = Vector2(156,48)
	control.add_theme_font_override("font",FONT)
	control.add_theme_font_size_override("font_size",20)
	for state in ["normal","hover","pressed","disabled","focus"]: control.add_theme_stylebox_override(state,SKIN.box("button",state))
	control.pressed.connect(callback)
	parent.add_child(control)
	return control

func select_mode(index: int) -> void:
	stage.catalogue = index==0
	for i in range(modes.size()): modes[i].set_pressed_no_signal(i==index)
	stage.queue_redraw()

func select_group(index: int) -> void:
	stage.items = ordinary_items if index==0 else [ordinary_items[1]]+leader_items
	for i in range(groups.size()): groups[i].set_pressed_no_signal(i==index)
	stage.rebuild_actors()

func close() -> void:
	if standalone: get_tree().quit();return
	if return_focus!=null and is_instance_valid(return_focus.get_ref()): return_focus.get_ref().grab_focus()
	queue_free()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
