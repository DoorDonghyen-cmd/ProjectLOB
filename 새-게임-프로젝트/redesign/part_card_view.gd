@tool
extends Control
## Icon-first part card shared by shops, rewards, and equipment summaries.
const Content = preload("res://redesign/content.gd")
const FONT = preload("res://redesign/combat_pixel_font.tres")
const PixelSkin = preload("res://redesign/combat_pixel_skin.gd")

const INK := Color("e7e4d9")
const MUTED := Color("94a9ae")
const CHIP := Color("12212a")
const COLORS := {
	"volley_drive":Color("c9b47a"), "thermal_drive":Color("db9e75"), "siege_drive":Color("a9bdc1"),
	"ordinary_chain": Color("b9c6a3"), "compression_sink": Color("9db9d2"),
	"cooling_breech": Color("a1c6cf"), "chain_sink": Color("b8b1d3"), "indexer": Color("b9cca5"),
	"radiator": Color("96b9d0"),
	"reclaimer": Color("94c4ba"),
	"ember_core": Color("ed9167"),
	"none": Color("667982"),
	"lens": Color("79b6f2"),
	"loader": Color("a9dfbf"),
	"supply": Color("e4bd72"),
	"coil": Color("f29a5b"),
	"capacitor": Color("63dce8"),
	"rammer": Color("c5a3e8"),
	"sequencer": Color("f0cf68"),
	"duplex": Color("e887b7"),
	"igniter": Color("ff8b52"),
	"breaker": Color("87a9ff"),
	"executioner": Color("ef6f75"),
	"reserve": Color("95d5a4"),
	"opening": Color("71d4ff"),
	"afterburner": Color("ffb357"),
	"field_press": Color("ffd86b"),
	"overbore": Color("ffd86b"),
	"inferno": Color("ffd86b"),
	"arc_splitter": Color("ffd86b"),
	"momentum": Color("ffd86b"),
	"triad": Color("ffd86b"),
}

@export var part_id := "none"
var state: Dictionary = {}
var equipped := false
var compact := false
@export var mini := false
@export var portrait := false
var slot_number := 1
var selected_visual := false
var outgoing_visual := false
var interaction: BaseButton
const Tag = preload("res://redesign/ammo_card_face.gd")

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if get_parent() is BaseButton:
		interaction = get_parent()
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for event in [interaction.mouse_entered,interaction.mouse_exited,interaction.focus_entered,interaction.focus_exited,interaction.button_down,interaction.button_up]: event.connect(queue_redraw)
	queue_redraw()

func setup(id: String, current_state: Dictionary, is_equipped: bool = false, is_compact: bool = false, is_mini: bool = false) -> void:
	part_id = id if Content.PARTS.has(id) else "none"
	state = current_state
	equipped = is_equipped
	compact = is_compact
	mini = is_mini
	tooltip_text = Content.part_grade_summary(part_id) + "\n" + str(Content.PARTS[part_id].text)
	var progress := preload("res://redesign/damage_engines.gd").progress(state,part_id)
	if not progress.is_empty(): tooltip_text += "\n" + progress
	queue_redraw()

func effect_title() -> String:
	return str(Content.PARTS[part_id].get("effect", "장착 슬롯"))

func effect_value() -> String:
	return preload("res://redesign/damage_engines.gd").value(state,part_id) if preload("res://redesign/damage_engines.gd").IDS.has(part_id) else str(Content.PARTS[part_id].get("value", "비어 있음"))

func role_text() -> String:
	return "성장 %d/8" % preload("res://redesign/damage_engines.gd").level(state,part_id) if preload("res://redesign/damage_engines.gd").IDS.has(part_id) else str(Content.PARTS[part_id].get("role", "전투 사이 무료 교체"))

func _draw() -> void:
	if not Content.PARTS.has(part_id): return
	var w := size.x
	var h := size.y
	var disabled := interaction != null and interaction.disabled
	var focused := interaction != null and not disabled and (interaction.is_hovered() or interaction.has_focus())
	var selected := selected_visual or focused
	var y := 2.0 if interaction != null and interaction.is_pressed() and not disabled else 0.0
	var accent: Color = COLORS.get(part_id,Color("a7b7ac")).lerp(Color("c6c5ac"),0.4)
	if part_id == "none":
		draw_style_box(PixelSkin.box("well"),Rect2(2,2,w-4,h-4))
		for x in [w*0.5-17,w*0.5+11]: draw_rect(Rect2(x,h*0.43,6,12),Color("465c5d"))
		if not mini: Tag.text(self,"빈 장착대",Vector2(8,h-22),w-16,15,Color("91a39d"),true)
		return
	Tag.surface(self,Rect2(0,y,w,h-y),selected,disabled)
	_draw_grade(Vector2(12,5+y))
	if outgoing_visual:
		for x in [3.0,w-5]: draw_rect(Rect2(x,10,2,h-24),Color("e6a580"))
	if portrait:
		# A device seated on mounting rails, with its own stamped specification plate.
		draw_rect(Rect2(9,12+y,w-18,76),Color("162b30"))
		for x in [19.0,w-24]:
			draw_rect(Rect2(x,34+y,5,35),Color("435b58"))
			draw_rect(Rect2(x+1,38+y,2,19),Color("75867b"))
		_draw_part_icon(Vector2(w*0.5,52+y),accent,1.0)
		if Content.is_core_part(part_id): Tag.text(self,"코어",Vector2(w-45,24+y),34,13,Color("dac28b"))
		Tag.text(self,str(Content.PARTS[part_id].name),Vector2(9,105+y),w-18,19,Color("e9e2cc"),true)
		draw_rect(Rect2(9,114+y,w-18,h-125-y),Color("c6c5ac"))
		Tag.text(self,effect_value(),Vector2(15,136+y),w-30,23,Color("203236"),true)
		var note := "교체 대상" if outgoing_visual else effect_title()
		Tag.text(self,note,Vector2(13,h-13+y),w-26,12,Color("203236"),true)
	else:
		var icon_w := 57.0 if mini else 80.0
		draw_rect(Rect2(9,12+y,icon_w-9,h-27),Color("162b30"))
		_draw_part_icon(Vector2((icon_w+9)*0.5,h*0.5+y),accent,0.58 if mini else 1.0)
		var title := str(Content.PARTS[part_id].name)
		Tag.text(self,title,Vector2(icon_w+9,28+y),w-icon_w-21,17 if mini else 21,Color("e9e2cc"))
		Tag.text(self,effect_value(),Vector2(icon_w+9,50+y),w-icon_w-21,15 if mini else 24,accent)
		if not mini:
			var downside := str(Content.PARTS[part_id].get("downside",""))
			var note := "대가 · "+downside if not downside.is_empty() else effect_title()
			Tag.text(self,note,Vector2(icon_w+9,h-15+y),w-icon_w-21,15,Color("e6a580") if not downside.is_empty() else Color("a5b4ac"))

func _draw_grade(at: Vector2) -> void:
	# One/two/three short bars are readable without coloring the entire card.
	for i in range(Content.part_grade(part_id) + 1):
		draw_rect(Rect2(at + Vector2(i * 8, 0), Vector2(5, 6)), Content.part_grade_color(part_id))

func _draw_part_icon(p: Vector2, accent: Color, scale_factor: float) -> void:
	preload("res://redesign/part_icon_art.gd").draw(self, part_id, p, accent, scale_factor)

func _draw_effect_icon(center: Vector2, color: Color, scale_factor: float) -> void:
	draw_set_transform(center, 0.0, Vector2.ONE * scale_factor)
	match part_id:
		"cooling_breech":
			for y in [-8, 0, 8]: draw_rect(Rect2(-10, y - 1, 20, 2), color)
		"ordinary_chain", "compression_sink":
			for x in [-9, 4]: draw_rect(Rect2(x, -7, 5, 14), color, false, 2)
			draw_line(Vector2(-2, 0), Vector2(3, 0), color, 2)
		"chain_sink":
			for x in [-8, 0, 8]:
				if x == 8: draw_rect(Rect2(x - 2, -6, 4, 12), color)
				else: draw_rect(Rect2(x - 2, -6, 4, 12), color, false, 2)
		"indexer":
			draw_rect(Rect2(-10, -8, 7, 15), color, false, 2)
			draw_rect(Rect2(3, -8, 7, 15), color, false, 2)
		"radiator":
			for x in [-8.0, 0.0, 8.0]: draw_rect(Rect2(x - 2, -9, 4, 18), color)
		"reclaimer":
			draw_arc(Vector2.ZERO, 9, 0, PI * 1.7, 12, color, 2.0)
			draw_line(Vector2(-4, 0), Vector2(4, 0), color, 3.0)
		"ember_core":
			draw_rect(Rect2(-8, -8, 16, 16), color, false, 2.0)
			draw_rect(Rect2(-3, -3, 6, 6), color)
		"lens":
			var shield := PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(7, 2), Vector2(0, 10), Vector2(-7, 2), Vector2(-8, -8)])
			draw_polyline(shield, color, 2.5)
			draw_line(Vector2(-12, 0), Vector2(13, 0), color, 2.5)
			draw_line(Vector2(8, -4), Vector2(13, 0), color, 2.5)
			draw_line(Vector2(8, 4), Vector2(13, 0), color, 2.5)
		"loader":
			draw_arc(Vector2.ZERO, 9, -PI * 0.2, PI * 1.45, 16, color, 2.5)
			draw_colored_polygon(PackedVector2Array([Vector2(5, -9), Vector2(13, -9), Vector2(10, -2)]), color)
		"supply":
			for x in [-8.0, 0.0, 8.0]:
				var rect := Rect2(x - 3, -7, 6, 14)
				if x < 8.0: draw_rect(rect, color, true)
				else: draw_rect(rect, color, false, 2.0)
		"coil":
			draw_colored_polygon(PackedVector2Array([Vector2(0, -11), Vector2(8, 0), Vector2(4, 10), Vector2(-5, 8), Vector2(-8, 0)]), color)
		"capacitor":
			draw_colored_polygon(PackedVector2Array([Vector2(-2, -11), Vector2(8, -2), Vector2(2, 0), Vector2(8, 10), Vector2(-8, 1), Vector2(-2, -1)]), color)
		"rammer":
			draw_line(Vector2(-11, 0), Vector2(9, 0), color, 3.0)
			draw_colored_polygon(PackedVector2Array([Vector2(5, -7), Vector2(13, 0), Vector2(5, 7)]), color)
		"sequencer":
			for x in [-8.0, 0.0, 8.0]: draw_circle(Vector2(x, 0), 3, color)
		"duplex":
			draw_line(Vector2(-10, -5), Vector2(10, -5), color, 3.0)
			draw_line(Vector2(-10, 5), Vector2(10, 5), color, 3.0)
		"igniter", "inferno":
			draw_colored_polygon(PackedVector2Array([Vector2(0, -11), Vector2(8, 0), Vector2(4, 10), Vector2(-5, 8), Vector2(-8, 0)]), color)
		"breaker":
			draw_rect(Rect2(-9, -9, 18, 18), color, false, 2.0)
			draw_line(Vector2(-8, 8), Vector2(8, -8), color, 3.0)
		"executioner":
			draw_arc(Vector2.ZERO, 9, 0, TAU, 18, color, 2.0)
			draw_circle(Vector2.ZERO, 3, color)
		"reserve":
			for x in [-6.0, 2.0, 10.0]: draw_rect(Rect2(x - 2, -7, 4, 14), color, true)
		"opening":
			draw_colored_polygon(PackedVector2Array([Vector2(-10, -8), Vector2(11, 0), Vector2(-10, 8)]), color)
		"afterburner":
			draw_line(Vector2(-11, 0), Vector2(7, 0), color, 3.0)
			draw_colored_polygon(PackedVector2Array([Vector2(5, -6), Vector2(12, 0), Vector2(5, 6)]), color)
		"field_press":
			draw_rect(Rect2(-10, -8, 20, 16), color, false, 2.0)
			draw_line(Vector2(-7, 0), Vector2(7, 0), color, 3.0)
		"overbore":
			draw_circle(Vector2.ZERO, 9, Color(color, 0.2))
			draw_arc(Vector2.ZERO, 9, 0, TAU, 18, color, 3.0)
		"arc_splitter":
			draw_line(Vector2(-10, 0), Vector2(0, 0), color, 3.0)
			draw_line(Vector2(0, 0), Vector2(10, -7), color, 3.0)
			draw_line(Vector2(0, 0), Vector2(10, 7), color, 3.0)
		"momentum":
			draw_line(Vector2(-11, 0), Vector2(8, 0), color, 3.0)
			draw_colored_polygon(PackedVector2Array([Vector2(5, -7), Vector2(13, 0), Vector2(5, 7)]), color)
		"triad":
			for x in [-8.0, 0.0, 8.0]: draw_circle(Vector2(x, 0), 3, color)
		_:
			draw_rect(Rect2(-10, -7, 20, 14), color, false, 2.0)
	draw_set_transform(Vector2.ZERO)
