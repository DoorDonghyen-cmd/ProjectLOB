extends Node
## Review-only material study; the actual authored equipment layout/bindings remain.
const INK=Color("e1dccc")
const MUTED=Color("a5a294")
const BRASS=Color("bea36b")
var view:Control
var host:Control
var margins:Dictionary={}

func bind(target:Control,owner_screen:Control) -> void:
	view=target;host=owner_screen
	for button in view.find_children("*","Button",true,false):
		var entries:Dictionary={}
		for state in ["normal","hover","pressed","hover_pressed","disabled","focus"]:
			var box:StyleBox=button.get_theme_stylebox(state)
			entries[state]=[box.get_content_margin(SIDE_LEFT),box.get_content_margin(SIDE_TOP),box.get_content_margin(SIDE_RIGHT),box.get_content_margin(SIDE_BOTTOM)]
		margins[button.get_instance_id()]=entries
		button.pressed.connect(refresh.call_deferred)
		var trim=load(get_script().resource_path.get_base_dir().path_join("trim.gd")).new()
		trim.name="EquipmentEdgeStudy";button.add_child(trim);button.move_child(trim,0)
	var hint:Label=view.find_child("OutfitHint",true,false)
	hint.custom_minimum_size.y=hint.get_combined_minimum_size().y
	refresh()

func box(button:Button,state:String,choice:bool,selected:bool,primary:bool) -> StyleBoxFlat:
	var result:=StyleBoxFlat.new();result.anti_aliasing=false
	result.corner_detail=1
	result.corner_radius_top_left=4;result.corner_radius_top_right=4
	result.corner_radius_bottom_left=4;result.corner_radius_bottom_right=4
	result.bg_color=Color("1b1e1be8")
	result.border_color=Color("45483e")
	result.border_width_top=1;result.border_width_left=1;result.border_width_right=1;result.border_width_bottom=2
	if state in ["hover","pressed","hover_pressed"]:result.bg_color=Color("30342bef");result.border_color=BRASS
	if choice:
		result.bg_color=Color("171b17ed")
		if selected:result.bg_color=Color("312e23ef");result.border_color=BRASS;result.border_width_left=3
		if state=="hover":result.bg_color=Color("292e25f0")
	if primary:
		result.bg_color=BRASS;result.border_color=Color("e4d3a8");result.border_width_top=2;result.border_width_bottom=2
		if state=="hover":result.bg_color=Color("cdb580")
		if state in ["pressed","hover_pressed"]:result.bg_color=Color("9d875b")
	if state=="disabled":result.bg_color=Color("1a1d1be0");result.border_color=Color("363b32")
	if state=="focus":
		result.bg_color=Color.TRANSPARENT;result.border_color=Color("daca9e")
		result.border_width_left=2;result.border_width_top=2;result.border_width_right=2;result.border_width_bottom=2
	var entry:Array=margins[button.get_instance_id()][state]
	result.content_margin_left=entry[0];result.content_margin_top=entry[1];result.content_margin_right=entry[2];result.content_margin_bottom=entry[3]
	return result

func refresh() -> void:
	if not is_instance_valid(view):return
	for label in view.find_children("*","Label",true,false):label.add_theme_color_override("font_color",INK)
	for id in ["WeaponRole","WeaponHeading","OutfitHeading","SelectionSummary"]:
		view.find_child(id,true,false).add_theme_color_override("font_color",MUTED)
	view.find_child("WeaponRole",true,false).add_theme_color_override("font_color",BRASS)
	for button in view.find_children("*","Button",true,false):
		var choice:bool=button.name.begins_with("weapon_select_") or button.name.begins_with("outfit_select_")
		var selected:bool=choice and button.button_pressed
		var primary:bool=button==view.launch
		button.modulate=Color.WHITE
		for state in ["normal","hover","pressed","hover_pressed","disabled","focus"]:button.add_theme_stylebox_override(state,box(button,state,choice,selected,primary))
		for state in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color"]:button.add_theme_color_override(state,Color("181b15") if primary else INK)
		button.add_theme_color_override("font_disabled_color",Color("787d6c"))
		for label in button.find_children("*","Label",true,false):label.add_theme_color_override("font_color",INK if selected else MUTED)
		var note:Label=button.get_node_or_null("Copy/Stats")
		if note!=null:note.add_theme_color_override("font_color",BRASS if selected else Color("8b9080"))
	view.find_child("OutfitHint",true,false).text=""
