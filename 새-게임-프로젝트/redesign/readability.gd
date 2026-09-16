extends RefCounted
## Format public values and evidence emitted by the actual resolver. No damage oracle here.
const Content = preload("res://redesign/content.gd")
const Forecast = preload("res://redesign/forecast.gd")
const AmmoVisual = preload("res://redesign/ammo_visual.gd")

static func description(id: String, state: Dictionary) -> String:
	if state.get("course", false) and int(state.floor) == 0:
		if id == "basic": return "재장전할 때 다시 채워지는 물리 기본탄입니다."
		if id == "charge": return "다음 2발의 피해 +2. 증폭탄을 앞에 놓으세요."
	return Content.AMMO[id].text

static func stats(id: String, state: Dictionary, full: bool = false) -> String:
	var spec: Dictionary = Content.AMMO[id]
	var damage := str(int(spec.dmg) + int(Content.GUNS[state.gun].bonus))
	if spec.effect == "double": damage += "×2"
	var result := "피해 " + damage
	var visible := Content.axes(state)
	if full or visible.armor: result += "  관통 %d" % Content.penetration(id, state)
	result += "  ·  " + str(AmmoVisual.ATTRIBUTE_NAMES[spec.attribute])
	return result

static func explain(shot: Dictionary) -> String:
	if shot.is_empty(): return "탄환을 넣으면 실제 피해와 계산 근거를 보여 줍니다."
	if not shot.has("math"): return str(shot.get("text", ""))
	var m: Dictionary = shot.math
	var line := "%s · %d피해  HP %d → %d" % [Forecast.tag(shot.target), shot.damage, m.hp_before, shot.hp]
	var equation := "피해 %d" % m.base
	if m.boost > 0: equation += " + 증폭 %d" % m.boost
	if int(m.get("overflow", 0)) > 0: equation += " + 초과관통 %d" % m.overflow
	if m.armor > 0: equation += " − 장갑 %d" % m.armor
	equation += " = %d" % m.per_hit
	if int(m.raw) - int(m.armor) < 1: equation += " (최소 1)"
	if m.hits > 1: equation += " · %d회" % m.hits
	line += "\n" + equation
	var reasons: PackedStringArray = []
	if m.armor_before > 0:
		reasons.append("장갑%d − 관통%d → 남은%d" % [m.armor_before, shot.pen, m.armor])
	if int(m.per_hit) * int(m.hits) > int(m.hp_before): reasons.append("남은 HP까지만 피해")
	if int(shot.get("burn_added", 0)) > 0: reasons.append("화상 +%d → %d" % [shot.burn_added, shot.burn])
	if int(shot.get("push", 0)) > 0: reasons.append("거리 +%dm" % shot.push)
	for other in shot.get("secondary", []):
		if str(other.get("kind", "arc")) == "spread":
			reasons.append("%s 확산 %d피해 (절반%d − 장갑%d, %d회) · HP%d" % [Forecast.tag(other.target), other.damage, other.raw, other.armor, other.hits, other.hp])
		else: reasons.append("%s 전이 %d피해 (고정) · HP%d" % [Forecast.tag(other.target), other.damage, other.hp])
	if not reasons.is_empty(): line += "\n" + " · ".join(reasons)
	return line

static func enemy_stats(enemy: Dictionary, state: Dictionary, full: bool = false) -> String:
	var visible := Content.axes(state)
	var parts: PackedStringArray = []
	if full or visible.armor: parts.append("장갑%d" % enemy.def)
	parts.append("접근%dm" % enemy.speed)
	if int(enemy.get("burn", 0)) > 0: parts.append("화상%d" % enemy.burn)
	return "  ".join(parts)
