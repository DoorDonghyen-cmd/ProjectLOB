@tool
extends Control
## Compact public ammo language: fixed stat glyphs, signed effect glyph, and numbers.
const Content = preload("res://redesign/content.gd")
const AmmoVisual = preload("res://redesign/ammo_visual.gd")
var FONT = preload("res://redesign/combat_pixel_font.tres")
const Face = preload("res://redesign/ammo_card_face.gd")

const INK := Color("e7e4d9")
const MUTED := Color("94a9ae")
const CHIP := Color("12212a")
const DAMAGE := Color("e4bd72")
const PENETRATION := Color("98becb")

@export var ammo_id := "basic"
@export var showcase_ui := false
@export var offer_action := false
@export var hand_skin := false
var interaction: BaseButton
var count := 0
var state: Dictionary = {"gun":"single", "floor":0, "course":false, "ammo_cycle":1, "equipped_parts":[]}
var is_disabled := false
var compression_ready := false
var context_text := ""
var context_positive := false
var compact_ui := false
var combat_skin := false
var selected_visual := false
var synergy: Dictionary = {}

func _ready() -> void:
	var parent := get_parent()
	while parent != null:
		if parent is BaseButton:
			interaction = parent
			break
		parent = parent.get_parent()
	if interaction != null:
		for event in [interaction.mouse_entered,interaction.mouse_exited,interaction.focus_entered,interaction.focus_exited,interaction.button_down,interaction.button_up]:
			event.connect(queue_redraw)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if get_parent() is BaseButton: set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	queue_redraw()

func setup(id: String, available: int, current_state: Dictionary, disabled: bool = false, can_compress: bool = false, current_context: String = "", positive_context: bool = false) -> void:
	ammo_id = id
	count = available
	state = current_state
	is_disabled = disabled
	compression_ready = can_compress
	context_text = current_context
	context_positive = positive_context
	queue_redraw()

func stat_items() -> Array:
	if state.is_empty() or not Content.AMMO.has(ammo_id): return []
	var spec: Dictionary = Content.AMMO[ammo_id]
	var damage := str(Content.damage(ammo_id, state))
	if str(spec.effect) == "double": damage += "×%d" % Content.hit_count(ammo_id, state)
	var result: Array = [{"kind": "damage", "value": damage}] if Content.is_attack(ammo_id) else [effect_data()]
	var axes: Dictionary = Content.axes(state)
	if axes.armor: result.append({"kind": "penetration", "value": str(Content.penetration(ammo_id, state))})
	return result

func attribute_data() -> Dictionary:
	if not Content.AMMO.has(ammo_id): return {}
	var attribute := str(Content.AMMO[ammo_id].attribute)
	return {"kind": attribute, "name": AmmoVisual.ATTRIBUTE_NAMES[attribute], "color": AmmoVisual.ATTRIBUTE_COLORS[attribute]}

func effect_data() -> Dictionary:
	if state.is_empty(): return {}
	if ammo_id == "basic": return {} if Content.uses_ammo_cards(state) else {"kind": "reload", "value": str(Content.supply_capacity(state))}
	var spec: Dictionary = Content.AMMO[ammo_id]
	match str(spec.effect):
		"prepare": return {"kind": "reload", "value": "%d장" % Content.effect_value(ammo_id, state)}
		"disrupt": return {"kind": "electric", "value": "%d턴" % Content.effect_value(ammo_id, state)}
		"spread": return {"kind": "fire", "value": "→%d" % Content.effect_value(ammo_id, state)}
		"sequence": return {"kind": "boost", "value": "+%d×종" % Content.effect_value(ammo_id, state)}
		"burn": return {"kind": "fire", "value": "%d×%d" % [Content.burn_damage(state), Content.burn_amount(ammo_id, state)]}
		"shatter": return {"kind": "penetration", "value": "−%d" % Content.effect_value(ammo_id, state)}
		"detonate": return {"kind": "fire", "value": "→"}
		"chase": return {"kind": "damage", "value": "+%d" % Content.effect_value(ammo_id, state)}
		"bypass": return {"kind": "push", "value": "↗"}
		"cool": return {"kind": "reload", "value": "−%d" % Content.effect_value(ammo_id, state)}
		"vent": return {"kind": "damage", "value": "열×%d" % Content.effect_value(ammo_id, state)}
		"thermal": return {"kind": "damage", "value": "+%d" % Content.effect_value(ammo_id, state)}
		"double": return {"kind": "double", "value": "×%d" % Content.hit_count(ammo_id, state)}
		"boost": return {"kind": "boost", "value": Content.boost_label(ammo_id, state)}
		"push": return {"kind": "push", "value": "+%dm" % Content.effect_value(ammo_id, state)}
		"arc": return {"kind": "electric", "value": "%d%s" % [Content.effect_value(ammo_id, state), "↗↗" if int(spec.get("arc_targets", 1)) > 1 else "↗"]}
	return {}

func effect_text() -> String:
	var spec: Dictionary = Content.AMMO[ammo_id]
	match str(spec.effect):
		"prepare": return "뒤 %d장 → 다음 패" % Content.effect_value(ammo_id, state)
		"disrupt": return "준비 정지 %d턴" % Content.effect_value(ammo_id, state)
		"spread": return "화상 이동 최대 %d" % Content.effect_value(ammo_id, state)
		"sequence": return "탄종×%d · 최대3" % Content.effect_value(ammo_id, state)
		"burn": return "매 턴 %d · %d턴" % [Content.burn_damage(state), Content.burn_amount(ammo_id, state)]
		"boost":
			if bool(spec.get("boost_hot",false)): return "공격 직전 열 %d↑" % Content.hot_threshold(state)
			if int(spec.get("boost_heat",0)) > 0: return "강화 공격 열 +%d" % int(spec.boost_heat)
			return "다음 탄창 · 공격 %d발" % Content.boost_rounds(ammo_id) if Content.is_compressed(ammo_id) else "공격 1발 · 재증폭 교체"
		"push": return "%dm 밀치기" % Content.effect_value(ammo_id, state)
		"arc":
			var targets := int(spec.get("arc_targets", 1)) + Content.arc_target_bonus(state)
			return "%s 전이 %d" % ["전체" if targets >= 99 else ("옆 적" if targets == 1 else "%d명" % targets), Content.effect_value(ammo_id, state)]
		"double": return "같은 적 연타"
		"shatter": return "장갑 −%d" % Content.effect_value(ammo_id, state)
		"detonate": return "화상 피해 ×2 기폭" if int(spec.get("detonate_scale", 1)) == 2 else "남은 화상 → 피해"
		"chase": return "직전 처치 → +%d" % Content.effect_value(ammo_id, state)
		"bypass": return "앞 적 건너뛰기"
		"cool": return "열 −%d" % Content.effect_value(ammo_id, state)
		"vent": return "끝 · 열→피해×%d" % Content.effect_value(ammo_id, state)
		"thermal": return "열 %d↑ · 피해 +%d" % [Content.hot_threshold(state), Content.effect_value(ammo_id, state)]
	if Content.AMMO[ammo_id].get("profile",false) and Content.source_id(ammo_id) == "basic": return "물리 탄환"
	if ammo_id == "basic": return "낮은 발열" if Content.uses_ammo_cards(state) else "재장전 시 보급"
	return "장갑을 뚫는 탄"

func footer_text() -> String:
	if combat_skin and is_disabled:
		match context_text:
			"장전한 탄": return "장전됨"
			"공간 부족": return "탄창 공간 부족"
			"장전 확정 상태": return "발사 대기 중"
	if is_disabled and context_text in ["먼저 장전", "선두 탄 회수"]: return context_text
	return effect_text()

func heat_text() -> String:
	return Content.heat_label(ammo_id, state)

func header_title_width() -> float:
	return size.x - 42 - ceilf(FONT.get_string_size(heat_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x)

func _draw() -> void:
	if Engine.is_editor_hint() and state.is_empty():
		state = {"gun":"single", "floor":0, "course":false, "ammo_cycle":1, "equipped_parts":[]}
	if state.is_empty() or not Content.AMMO.has(ammo_id): return
	if hand_skin: preload("res://redesign/ammo_hand_face.gd").draw(self)
	else: Face.draw(self)

func _draw_compression_link() -> void:
	var cyan := Color("92c9c6")
	var faint := cyan
	faint.a = 0.32
	# Cyan corner rails make the whole card read as draggable without adding a
	# badge word. Two linked diamonds are the pair/combine instruction.
	for corner in [
		[Vector2(3, 17), Vector2(3, 4), Vector2(16, 4)],
		[Vector2(size.x - 17, 4), Vector2(size.x - 4, 4), Vector2(size.x - 4, 17)],
		[Vector2(3, size.y - 17), Vector2(3, size.y - 4), Vector2(16, size.y - 4)],
		[Vector2(size.x - 17, size.y - 4), Vector2(size.x - 4, size.y - 4), Vector2(size.x - 4, size.y - 17)],
	]:
		draw_polyline(PackedVector2Array(corner), faint, 2.0, false)
	var left := Vector2(54, 84) if compact_ui else Vector2(size.x - 20, 18)
	var right := left + Vector2(6, 6)
	_draw_diamond(left, cyan)
	_draw_diamond(right, cyan)
	draw_line(left + Vector2(3, 3), right - Vector2(3, 3), cyan, 2.0, false)

func _draw_diamond(center: Vector2, color: Color) -> void:
	var points := PackedVector2Array([
		center + Vector2(0, -4), center + Vector2(4, 0),
		center + Vector2(0, 4), center + Vector2(-4, 0),
		center + Vector2(0, -4),
	])
	draw_polyline(points, color, 1.5, false)

func _draw_fit(color: Color) -> void:
	var origin := Vector2(17, 100) if compact_ui else Vector2(12, 36)
	for i in range(2):
		var filled := Content.slot_cost(ammo_id) == 2 or (i == 0 and Content.anchor(ammo_id) == "first") or (i == 1 and Content.anchor(ammo_id) == "last")
		draw_rect(Rect2(origin + Vector2(i * 16, 0), Vector2(12, 6)), color if filled else MUTED.darkened(0.65))

func _stat_color(kind: String) -> Color:
	match kind:
		"damage": return DAMAGE
		"penetration": return PENETRATION
	return MUTED

func _draw_icon(kind: String, center: Vector2, color: Color) -> void:
	var c := center.round()
	match kind:
		"damage", "boost":
			draw_rect(Rect2(c - Vector2(2, 2), Vector2(5, 5)), color)
			for direction in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
				draw_line(c + direction * 4, c + direction * 7, color, 2.0, false)
		"penetration":
			_draw_shield(c - Vector2(2, 0), color, false)
			draw_line(c + Vector2(-5, 0), c + Vector2(7, 0), color, 2.0, false)
			draw_line(c + Vector2(4, -3), c + Vector2(7, 0), color, 2.0, false)
			draw_line(c + Vector2(4, 3), c + Vector2(7, 0), color, 2.0, false)
		"double":
			_draw_round_mark(c + Vector2(-3, 2), color)
			_draw_round_mark(c + Vector2(3, -2), color)
		"push":
			draw_line(c + Vector2(-7, 0), c + Vector2(7, 0), color, 2.0, false)
			draw_line(c + Vector2(3, -4), c + Vector2(7, 0), color, 2.0, false)
			draw_line(c + Vector2(3, 4), c + Vector2(7, 0), color, 2.0, false)
		"fire":
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -8), c + Vector2(6, 0), c + Vector2(3, 7), c + Vector2(-4, 6), c + Vector2(-6, 0)]), color)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -3), c + Vector2(3, 2), c + Vector2(0, 5), c + Vector2(-2, 2)]), CHIP)
		"electric":
			draw_colored_polygon(PackedVector2Array([c + Vector2(1, -9), c + Vector2(-5, 1), c, c + Vector2(-2, 9), c + Vector2(6, -2), c + Vector2(1, -2)]), color)
		"physical":
			draw_rect(Rect2(c + Vector2(-6, -3), Vector2(9, 7)), color)
			draw_colored_polygon(PackedVector2Array([c + Vector2(3, -3), c + Vector2(8, 0), c + Vector2(3, 4)]), color)
		"reload":
			draw_arc(c, 6, -PI * 0.25, PI * 1.55, 12, color, 2.0, false)
			draw_line(c + Vector2(4, -6), c + Vector2(8, -5), color, 2.0, false)
			draw_line(c + Vector2(4, -6), c + Vector2(6, -2), color, 2.0, false)

func _draw_shield(center: Vector2, color: Color, cracked: bool) -> void:
	var points := PackedVector2Array([center + Vector2(-6, -6), center + Vector2(6, -6), center + Vector2(5, 2), center + Vector2(0, 7), center + Vector2(-5, 2), center + Vector2(-6, -6)])
	draw_polyline(points, color, 2.0, false)
	if cracked:
		draw_polyline(PackedVector2Array([center + Vector2(1, -5), center + Vector2(-2, -1), center + Vector2(2, 1), center + Vector2(-1, 6)]), color, 2.0, false)

func _draw_round_mark(center: Vector2, color: Color) -> void:
	draw_rect(Rect2(center + Vector2(-5, -2), Vector2(8, 5)), color)
	draw_colored_polygon(PackedVector2Array([center + Vector2(3, -2), center + Vector2(7, 0), center + Vector2(3, 3)]), color)
