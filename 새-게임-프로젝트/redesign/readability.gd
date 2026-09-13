extends RefCounted
## Format public values and evidence emitted by the actual resolver. No damage oracle here.
const Content = preload("res://redesign/content.gd")
const Forecast = preload("res://redesign/forecast.gd")

static func description(id: String, state: Dictionary) -> String:
	if state.get("course", false) and int(state.floor) == 0:
		if id == "basic": return "재장전할 때 다시 채워지는 기본 공격탄입니다."
		if id == "charge": return "다음 2발의 위력 +2. 강화탄을 앞에 놓으세요."
	return Content.AMMO[id].text

static func stats(id: String, state: Dictionary, full: bool = false) -> String:
	var spec: Dictionary = Content.AMMO[id]
	var power := str(int(spec.dmg) + int(Content.GUNS[state.gun].bonus))
	if spec.effect == "double": power += "×2"
	var result := "위력 " + power
	var visible := Content.axes(state)
	if full or visible.armor: result += "  관통 %d" % spec.pen
	if full or visible.accuracy: result += "  명중 %d" % (int(spec.acc) + (2 if state.part == "lens" else 0))
	return result

static func explain(shot: Dictionary) -> String:
	if shot.is_empty(): return "탄환을 넣으면 실제 피해와 계산 근거를 보여 줍니다."
	if not shot.has("math"): return str(shot.get("text", ""))
	var m: Dictionary = shot.math
	var line := "%s · %d피해  HP %d → %d" % [Forecast.tag(shot.target), shot.damage, m.hp_before, shot.hp]
	var equation := "위력 %d" % m.base
	if m.boost > 0: equation += " + 강화 %d" % m.boost
	if m.special > 0: equation += " + %s %d" % ["파쇄" if shot.id == "pierce" else "마무리", m.special]
	if m.armor > 0: equation += " − 장갑 %d" % m.armor
	if m.evasion > 0: equation += " − 스침 %d" % m.evasion
	equation += " = %d" % m.per_hit
	if int(m.raw) - int(m.armor) - int(m.evasion) < 1: equation += " (최소 1)"
	if m.hits > 1: equation += " · %d회" % m.hits
	line += "\n" + equation
	var reasons: PackedStringArray = []
	if m.armor_before > 0:
		reasons.append("장갑%d − 균열%d − 관통%d → 남은%d" % [m.armor_before, m.crack_before, shot.pen, m.armor])
	if m.evasion > 0:
		reasons.append("명중%d < 회피%d → 스침%d" % [shot.acc, m.evasion_before, m.evasion])
	if int(m.per_hit) * int(m.hits) > int(m.hp_before): reasons.append("남은 HP까지만 피해")
	for other in shot.get("secondary", []): reasons.append("%s 도약 %d피해 (고정)" % [Forecast.tag(other.target), other.damage])
	if not reasons.is_empty(): line += "\n" + " · ".join(reasons)
	return line

static func enemy_stats(enemy: Dictionary, state: Dictionary, full: bool = false) -> String:
	var visible := Content.axes(state)
	var parts: PackedStringArray = []
	if full or visible.armor: parts.append("장갑%d" % maxi(0, int(enemy.def) - int(enemy.get("crack", 0))))
	if full or visible.accuracy: parts.append("회피%d" % enemy.eva)
	parts.append("접근%dm" % maxi(0, int(enemy.speed) - int(enemy.slow)))
	return "  ".join(parts)
