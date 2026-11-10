extends Control
## Isolated visual comparison. No campaign, model or save access.
const FONT = preload("res://redesign/combat_pixel_font.tres")
const ACTOR = preload("res://redesign/weapon_actor.gd")
const Content = preload("res://redesign/content.gd")
const GUNS := ["single", "burst", "scatter", "heavy", "amplifier"]
const OUTFITS := ["work", "expedition", "heatworker", "hoist", "recovery"]
const OUTFIT_NAMES := ["작업복", "원정복", "방열복", "인양 장구", "회수 장구"]
var actors: Array = []
var viewports: Array[SubViewport] = []
var stage: Control
var before := false
var action := "aim"
var outfit_index := 0
var comparison_button: Button
var outfit_button: Button

class Stage extends Control:
	var owner_preview: Control
	var textures: Array[Texture2D] = []
	var actors: Array = []
	var before := false
	const FONT = preload("res://redesign/combat_pixel_font.tres")
	func _draw() -> void:
		var col := size.x / 5.0
		for divider in range(1,5): draw_line(Vector2(col*divider,18),Vector2(col*divider,size.y-20),Color("344447"),2)
		for i in range(5):
			var x := i*col
			var gun: String = owner_preview.GUNS[i]
			var title: String = owner_preview.Content.GUNS[gun].name
			var subtitle: String = owner_preview.Content.GUNS[gun].role
			draw_string(FONT,Vector2(x+28,35),title,HORIZONTAL_ALIGNMENT_LEFT,-1,32,Color("d3c8ab"))
			draw_string(FONT,Vector2(x+28,65),subtitle,HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color("91a5a3"))
			var profile: Dictionary = ACTOR.WEAPONS[gun]
			var bounds: Rect2 = profile.bounds
			var factor := minf((col-30)/bounds.size.x,175.0/bounds.size.y) * float(profile.get("catalog_scale",1.0))
			var destination := Rect2(Vector2(x+(col-bounds.size.x*factor)*0.5,95+(175-bounds.size.y*factor)*0.5),bounds.size*factor)
			draw_texture_rect_region(profile.image,destination,bounds)
			draw_string(FONT,Vector2(x+28,300),"파지 · "+owner_preview.pose_name(),HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color("91a5a3"))
			# Render the existing body and front-finger layers at inspection size.
			draw_texture_rect_region(textures[i],Rect2(x+40,305,175,168),Rect2(105,0,500,480))
			draw_line(Vector2(x+18,485),Vector2(x+col-18,485),Color("344447"),2)
			# The body itself is ~95px high, close to the 1280px combat capture.
			draw_texture_rect(textures[i],Rect2(x+8,490,230.4,153.6),false)
			draw_string(FONT,Vector2(x+28,270),"원본 밀도" if before else "전투 밀도",HORIZONTAL_ALIGNMENT_LEFT,col-56,18,Color("aeb7ac"))

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().root.content_scale_size = Vector2i(1280,820)
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_tree().root.min_size = Vector2i(960,615)
	var background := ColorRect.new()
	background.color = Color("142126")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var header := Label.new()
	header.text = "ORVASK  /  무기·파지 검수"
	header.position = Vector2(32,18)
	header.add_theme_font_override("font",FONT)
	header.add_theme_font_size_override("font_size",26)
	add_child(header)
	var note := Label.new()
	note.text = "본편 적용 · 아래는 전투 크기"
	note.position = Vector2(870,23)
	note.add_theme_font_override("font",FONT)
	note.add_theme_font_size_override("font_size",18)
	note.modulate = Color("9baca7")
	add_child(note)
	stage = Stage.new()
	stage.owner_preview = self
	stage.position = Vector2(16,72)
	stage.size = Vector2(1248,630)
	stage.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var cutout := ShaderMaterial.new()
	cutout.shader = preload("res://redesign/monster_alpha_cutout.gdshader")
	stage.material = cutout
	add_child(stage)
	var buttons := HBoxContainer.new()
	buttons.position = Vector2(28,724)
	buttons.add_theme_constant_override("separation",10)
	add_child(buttons)
	for item in [["대기","idle"],["조준","aim"],["반동","recoil"],["장전 열기","reload_open"],["장전 닫기","reload_seat"],["냉각","cooling"]]:
		_button(buttons,item[0],func(): set_pose(item[1]))
	comparison_button = _button(buttons,"원본 밀도",toggle_before)
	outfit_button = _button(buttons,OUTFIT_NAMES[0],cycle_outfit)
	_button(buttons,"닫기",func(): get_tree().quit())
	rebuild()

func _button(parent: Control, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(100,48)
	button.add_theme_font_override("font",FONT)
	button.add_theme_font_size_override("font_size",20)
	parent.add_child(button)
	button.pressed.connect(callback)
	return button

func rebuild() -> void:
	for viewport in viewports: viewport.queue_free()
	viewports.clear()
	actors.clear()
	stage.textures.clear()
	for gun in GUNS:
		var viewport = load("res://redesign/weapon_actor.tscn").instantiate()
		var actor = viewport.get_node("Actor")
		actor.coarse_weapons = not before
		actor.set_outfit(OUTFITS[outfit_index])
		actor.configure(gun,action,0.8 if action=="recoil" else 0.0,0.4 if action=="reload_open" else 0.8,0.75 if action=="cooling" else 0.0)
		add_child(viewport)
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		viewports.append(viewport)
		actors.append(actor)
		stage.textures.append(viewport.get_texture())
	stage.before = before
	stage.queue_redraw()

func set_pose(id: String) -> void:
	action = id
	rebuild()

func toggle_before() -> void:
	before = not before
	comparison_button.text = "전투 밀도" if before else "원본 밀도"
	rebuild()

func cycle_outfit() -> void:
	outfit_index = (outfit_index+1)%OUTFITS.size()
	outfit_button.text = OUTFIT_NAMES[outfit_index]
	rebuild()

func pose_name() -> String:
	return {"idle":"대기","aim":"조준","recoil":"반동","reload_open":"장전 열기","reload_seat":"장전 닫기","cooling":"냉각"}[action]

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"): get_tree().quit()
