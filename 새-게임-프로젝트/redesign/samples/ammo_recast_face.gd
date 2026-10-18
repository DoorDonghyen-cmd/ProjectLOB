@tool
extends Control
## Visual study only. All numerals still come from the current ammunition model.
const Content = preload("res://redesign/content.gd")
const FONT = preload("res://redesign/combat_pixel_font.tres")
const Sheet = preload("res://assets/art/ammo_recast_20261017/cartridges_v4.png")
const Visual = preload("res://redesign/ammo_visual.gd")
const Regions := {
	"basic": Rect2(171,151,209,361), "pierce": Rect2(682,68,174,444),
	"precise": Rect2(1114,188,301,324), "charge": Rect2(163,548,216,408),
	"cool": Rect2(659,578,219,378), "arc": Rect2(1141,580,247,376)
}
const Accents := {"basic":"b9a581", "pierce":"bfc1a7", "precise":"ae795f", "charge":"c69b54", "cool":"93b3bc", "arc":"b88479"}
@export var ammo_id := "basic_p2"
@export var rail := false
var state: Dictionary = {"gun":"single", "floor":0, "course":false, "equipped_parts":[], "ammo_cycle":1}
var selected := false
var remaining := 1
var parent_button: Button

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if get_parent() is Button:
		parent_button = get_parent()
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for event in [parent_button.mouse_entered, parent_button.mouse_exited, parent_button.focus_entered, parent_button.focus_exited, parent_button.button_down, parent_button.button_up]:
			event.connect(queue_redraw)

func label(value: String, at: Vector2, width: float, pixels: int, color: Color, center: bool = false) -> void:
	draw_string(FONT, at.round(), value, HORIZONTAL_ALIGNMENT_CENTER if center else HORIZONTAL_ALIGNMENT_LEFT, width, pixels, color)

static func icon(canvas: CanvasItem, id: String, rect: Rect2, display_scale: float = 1.0) -> void:
	var key := Content.source_id(id)
	if not Regions.has(key): return
	var region: Rect2 = Regions[key]
	var factor := minf(rect.size.x / region.size.x, rect.size.y / region.size.y)
	var extent := (region.size * factor * display_scale).floor()
	canvas.draw_texture_rect_region(Sheet, Rect2((rect.get_center()-extent*0.5).round(),extent),region)

func _draw() -> void:
	var w := size.x
	var h := size.y
	var focus := selected or (parent_button != null and (parent_button.has_focus() or parent_button.is_hovered()))
	var pressed := parent_button != null and parent_button.is_pressed()
	var ink := Color("ded5bb")
	var muted := Color("9ca7a3")
	var y := 2.0 if pressed else 0.0
	var source := Content.source_id(ammo_id) if not ammo_id.is_empty() else ""
	var accent := Color(Accents.get(source,"8c9995"))
	if rail:
		draw_rect(Rect2(0,0,w,h),Color("101b20"))
		draw_rect(Rect2(0,h-2,w,2),Color("536361") if not ammo_id.is_empty() else Color("2c3e42"))
		if ammo_id.is_empty():
			label("—",Vector2(0,h*0.62),w,20,muted,true)
		else:
			icon(self,ammo_id,Rect2(12,5,28,h-10))
			label(Visual.SHORT[ammo_id],Vector2(50,26),w-58,19,ink)
			var stat: Dictionary=Content.primary_stat(ammo_id,state)
			label(str(stat.label)+" "+str(stat.value),Vector2(50,49),w-58,16,accent)
		return
	# Quiet enamel face: the cartridge, not a surrounding mechanical frame, owns the area.
	draw_rect(Rect2(0,4+y,w,h-4-y),Color("080e12"))
	draw_rect(Rect2(0,y,w,h-5),Color("253337") if focus else Color("1a272c"))
	draw_rect(Rect2(0,y,w,2),Color("c5d3bd") if focus else Color("526260"))
	draw_rect(Rect2(9,30+y,22,2),accent)
	if focus:
		for x in [0.0,w-2]: draw_rect(Rect2(x,y,2,h-5),Color("a6baa7"))
	label(str(Content.AMMO[ammo_id].name),Vector2(9,23+y),w-18,19,ink)
	# A compact face keeps ten separate cards visible, without shrinking the type.
	icon(self,ammo_id,Rect2(9,39+y,31,57))
	var stat: Dictionary=Content.primary_stat(ammo_id,state)
	var text_x := 48.0
	label(str(stat.label),Vector2(text_x,53+y),w-text_x-7,14,muted)
	label(str(stat.value),Vector2(text_x,82+y),w-text_x-7,28,ink)
	var secondary := ""
	if source=="pierce": secondary="관통%d"%Content.penetration(ammo_id,state)
	elif source=="charge": secondary="다음1발"
	elif source=="precise": secondary="같은 적"
	elif source=="arc": secondary="전이%d"%Content.effect_value(ammo_id,state)
	var thermal := Color("d29b78") if source!="cool" else Color("96bac4")
	Visual.heat_icon(self,Vector2(14,h-18+y),0.65,thermal)
	label(Content.heat_label(ammo_id,state),Vector2(25,h-12+y),28,16,thermal)
	label(secondary,Vector2(58,h-12+y),w-63,14,accent)
	if selected:
		label("✓",Vector2(w-21,23+y),16,15,Color("c5d3bd"))
