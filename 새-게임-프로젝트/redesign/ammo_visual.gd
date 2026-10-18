extends Control
const Content = preload("res://redesign/content.gd")
const ATTRIBUTE_NAMES := {"physical": "물리", "fire": "화염", "electric": "전기"}
const ATTRIBUTE_COLORS := {"physical": Color("cbd3d2"), "fire": Color("f29a5b"), "electric": Color("63dce8")}
const BASE_COLORS := {"charge_heat": Color("ce936b"),"prepare": Color("b9cca5"), "disrupt": Color("83bbda"), "spread": Color("f2aa73"), "sequence": Color("dfc883"), "vent": Color("9bbfd2"), "thermal": Color("e8a271"), "shatter": ATTRIBUTE_COLORS.physical, "detonate": ATTRIBUTE_COLORS.fire, "chase": ATTRIBUTE_COLORS.physical, "bypass": ATTRIBUTE_COLORS.physical, "cool": Color("96b9d0"), "basic": ATTRIBUTE_COLORS.physical, "pierce": ATTRIBUTE_COLORS.physical, "precise": ATTRIBUTE_COLORS.physical, "bore": ATTRIBUTE_COLORS.fire, "charge": ATTRIBUTE_COLORS.physical, "charge_hot": Color("ed9167"), "push": ATTRIBUTE_COLORS.physical, "arc": ATTRIBUTE_COLORS.electric, "pierce_c": ATTRIBUTE_COLORS.physical, "precise_c": ATTRIBUTE_COLORS.physical, "bore_c": ATTRIBUTE_COLORS.fire, "charge_c": ATTRIBUTE_COLORS.physical, "push_c": ATTRIBUTE_COLORS.physical, "arc_c": ATTRIBUTE_COLORS.electric, "pierce_f": ATTRIBUTE_COLORS.physical, "precise_f": ATTRIBUTE_COLORS.physical, "bore_f": ATTRIBUTE_COLORS.fire, "charge_f": ATTRIBUTE_COLORS.physical, "push_f": ATTRIBUTE_COLORS.physical, "arc_f": ATTRIBUTE_COLORS.electric, "prepare_c": Color("b9cca5"), "prepare_f": Color("b9cca5"), "disrupt_c": Color("83bbda"), "disrupt_f": Color("83bbda"), "spread_c": Color("f2aa73"), "spread_f": Color("f2aa73"), "sequence_c": Color("dfc883"), "sequence_f": Color("dfc883"), "vent_c": Color("9bbfd2"), "vent_f": Color("9bbfd2"), "thermal_c": Color("e8a271"), "thermal_f": Color("e8a271"), "shatter_c": ATTRIBUTE_COLORS.physical, "shatter_f": ATTRIBUTE_COLORS.physical, "detonate_c": ATTRIBUTE_COLORS.fire, "detonate_f": ATTRIBUTE_COLORS.fire, "chase_c": ATTRIBUTE_COLORS.physical, "chase_f": ATTRIBUTE_COLORS.physical, "bypass_c": ATTRIBUTE_COLORS.physical, "bypass_f": ATTRIBUTE_COLORS.physical, "cool_c": Color("96b9d0"), "cool_f": Color("96b9d0")}
const BASE_SHORT := {"charge_heat": "잔열","prepare": "예약", "disrupt": "차단", "spread": "불씨", "sequence": "연계", "vent": "열방출", "thermal": "고열", "shatter": "파쇄", "detonate": "기폭", "chase": "추격", "bypass": "우회", "cool": "냉각", "basic": "기본", "pierce": "철갑", "precise": "연타", "bore": "소이", "charge": "증폭", "charge_hot": "배율", "push": "충격", "arc": "전격", "pierce_c": "철갑", "precise_c": "연타", "bore_c": "소이", "charge_c": "증폭", "push_c": "충격", "arc_c": "전격", "pierce_f": "철갑", "precise_f": "연타", "bore_f": "소이", "charge_f": "증폭", "push_f": "충격", "arc_f": "전격", "prepare_c": "예약", "prepare_f": "예약", "disrupt_c": "차단", "disrupt_f": "차단", "spread_c": "불씨", "spread_f": "불씨", "sequence_c": "연계", "sequence_f": "연계", "vent_c": "열방출", "vent_f": "열방출", "thermal_c": "고열", "thermal_f": "고열", "shatter_c": "파쇄", "shatter_f": "파쇄", "detonate_c": "기폭", "detonate_f": "기폭", "chase_c": "추격", "chase_f": "추격", "bypass_c": "우회", "bypass_f": "우회", "cool_c": "냉각", "cool_f": "냉각"}
const BASE_HINT := {"charge_heat": "고열 공격 +6 · 냉각 순서 주의","prepare": "뒤 전술탄을 다음 패로 예약", "disrupt": "준비 정지 · 적마다 한 번", "spread": "화상을 다른 적에게 이동", "sequence": "앞선 다른 탄종마다 강화", "vent": "마지막 발 · 열을 피해로 전환", "thermal": "높은 열에서 강해지는 탄", "shatter": "장갑 −3 · 후속 타격 지원", "detonate": "남은 화상을 즉시 피해로", "chase": "직전 탄 처치 시 피해 +4", "bypass": "앞 적을 건너뛰어 공격", "cool": "현재 열 −3 · 과열 전에 배치", "basic": "낮은 발열의 물리 탄환", "pierce": "높은 관통", "precise": "같은 적 2회 타격", "bore": "화상 +3", "charge": "다음 공격 +3 · 재증폭은 교체", "charge_hot": "다음 공격 ×2 · 강화 공격 열 +3", "push": "2m 밀어 거리 확보", "arc": "다른 적에게 2피해 전이", "pierce_c": "두 칸에 관통 집중", "precise_c": "첫 발 · 같은 적 3회", "bore_c": "두 칸에 화상 집중", "charge_c": "마지막 발 · 다음 탄창 증폭", "push_c": "마지막 발 · 강한 넉백", "arc_c": "첫 발 · 모든 다른 적 전이", "pierce_f": "두 칸에 관통 집중", "precise_f": "첫 발 · 같은 적 3회", "bore_f": "두 칸에 화상 집중", "charge_f": "마지막 발 · 다음 탄창 증폭", "push_f": "마지막 발 · 강한 넉백", "arc_f": "첫 발 · 모든 다른 적 전이", "prepare_c": "뒤 전술탄을 다음 패로 예약", "prepare_f": "뒤 전술탄을 다음 패로 예약", "disrupt_c": "준비 정지 · 적마다 한 번", "disrupt_f": "준비 정지 · 적마다 한 번", "spread_c": "화상을 다른 적에게 이동", "spread_f": "화상을 다른 적에게 이동", "sequence_c": "앞선 다른 탄종마다 강화", "sequence_f": "앞선 다른 탄종마다 강화", "vent_c": "마지막 발 · 열을 피해로 전환", "vent_f": "마지막 발 · 열을 피해로 전환", "thermal_c": "높은 열에서 강해지는 탄", "thermal_f": "높은 열에서 강해지는 탄", "shatter_c": "장갑 −3 · 후속 타격 지원", "shatter_f": "장갑 −3 · 후속 타격 지원", "detonate_c": "남은 화상을 즉시 피해로", "detonate_f": "남은 화상을 즉시 피해로", "chase_c": "직전 탄 처치 시 피해 +4", "chase_f": "직전 탄 처치 시 피해 +4", "bypass_c": "앞 적을 건너뛰어 공격", "bypass_f": "앞 적을 건너뛰어 공격", "cool_c": "현재 열 −3 · 과열 전에 배치", "cool_f": "현재 열 −3 · 과열 전에 배치"}
var ammo_id := "basic"

static var COLORS: Dictionary = _expanded(BASE_COLORS)
static var SHORT: Dictionary = _expanded(BASE_SHORT)
static var HINT: Dictionary = _hints()

static func _hints() -> Dictionary:
	var result := _expanded(BASE_HINT)
	for id in Content.AMMO:
		if Content.AMMO[id].get("profile",false):
			result[id] = {"basic":"물리 탄환", "pierce":"장갑 관통", "precise":"연속 타격"}[Content.source_id(id)]
	return result

static func _expanded(base: Dictionary) -> Dictionary:
	var result: Dictionary=base.duplicate()
	for id in Content.AMMO:
		if not result.has(id): result[id]=base.get(Content.source_id(id),base.basic)
	return result

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	round_icon(self, size * 0.5, ammo_id, 0.7)

static func round_icon(canvas: CanvasItem, position: Vector2, id: String, scale_factor: float = 1.0) -> void:
	# Runtime lookup avoids a preload cycle with the shared palette/grade renderer.
	load("res://redesign/ammo_art.gd").draw(canvas,id,Rect2(position-Vector2(15,43)*scale_factor,Vector2(30,86)*scale_factor))

static func heat_icon(canvas: CanvasItem, position: Vector2, scale_factor: float = 1.0, color: Color = Color("ed9167")) -> void:
	# Hollow stem and stepped bulb read as temperature, distinct from fire damage.
	# Shared by ammo costs and the weapon gauge; no box or font glyph dependency.
	for block in [Rect2(-4,-9,6,2), Rect2(-6,-7,2,10), Rect2(2,-7,2,10),
		Rect2(-8,3,2,6), Rect2(4,3,2,6), Rect2(-6,9,10,2),
		Rect2(-2,-3,2,8), Rect2(-4,5,6,4), Rect2(6,-7,2,2), Rect2(6,-1,2,2)]:
		var start: Vector2 = (position + block.position * scale_factor).round()
		var finish: Vector2 = (position + block.end * scale_factor).round()
		canvas.draw_rect(Rect2(start, finish-start), color)

# Grade is carried by two short blue notches, not the attribute tint or focus border.
static func grade_mark(canvas: CanvasItem, origin: Vector2, id: String, alpha: float = 1.0) -> void:
	var advanced := Content.grade(id) == 1
	var color := Color("8eb2db", alpha) if advanced else Color("7e8c8d", alpha)
	if Content.grade(id) < 0: return
	for i in range(2 if advanced else 1):
		canvas.draw_rect(Rect2(origin + Vector2(i * 13, 0), Vector2(10, 3)), color)
	if Content.is_temporary(id):
		canvas.draw_rect(Rect2(origin + Vector2(27, 0), Vector2(3, 3)), Color("d4b77d", alpha))
