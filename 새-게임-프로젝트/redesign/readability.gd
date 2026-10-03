extends RefCounted
## Format public values and evidence emitted by the actual resolver. No damage oracle here.
const Content = preload("res://redesign/content.gd")
const Forecast = preload("res://redesign/forecast.gd")
const AmmoVisual = preload("res://redesign/ammo_visual.gd")

static func description(id: String, state: Dictionary) -> String:
	var spec: Dictionary = Content.AMMO[id]
	if Content.heat_cost(id) > 0:
		return "고출력 · 다음 2발의 타격당 피해 +%d. 발사하면 다음 재장전 +%d턴. 재장전 완료 시 해소." % [Content.effect_value(id, state), Content.heat_cost(id)]
	if Content.is_compressed(id):
		match id:
			"pierce_c": return "탄창 2칸 · 피해 %d · 관통 %d를 한 발에 집중합니다." % [Content.damage(id, state), Content.penetration(id, state)]
			"push_c": return "마지막 발 자동 배치 · 적을 최대 %dm 밀칩니다." % Content.effect_value(id, state)
			"bore_c": return "탄창 2칸 · 화상 %d턴 · 전진 직전에 턴당 %d피해." % [Content.burn_amount(id, state), Content.burn_damage(state)]
			"charge_c": return "마지막 발 자동 배치 · 다음 탄창까지 이어지는 2발 피해 +%d." % Content.effect_value(id, state)
			"precise_c": return "첫 발 자동 배치 · 같은 적을 %d회 타격합니다." % Content.hit_count(id, state)
			"arc_c": return "첫 발 자동 배치 · 주 표적 외 모든 생존 적에게 전이 %d피해." % Content.effect_value(id, state)
	if state.get("course", false) and int(state.floor) == 0:
		if id == "basic": return "재장전할 때 다시 채워지는 물리 기본탄입니다."
		if id == "charge": return "다음 2발의 피해 +%d. 증폭탄을 앞에 놓으세요." % Content.effect_value(id, state)
	if id == "charge": return "다음 2발의 타격당 피해 +%d. 연발의 두 타격에 각각 적용됩니다." % Content.effect_value(id, state)
	if id == "push": return "적을 %dm 밀칩니다. 탄창당 총 %dm까지 적용됩니다." % [Content.effect_value(id, state), Content.push_budget(state)]
	if id == "bore": return "화상 %d턴 · 전진 직전에 턴당 %d피해. 화상으로 처치한 적은 전진하지 않습니다." % [Content.burn_amount(id, state), Content.burn_damage(state)]
	if id == "precise": return "같은 적을 %d회 타격합니다. 증폭 피해도 타격마다 적용됩니다." % Content.hit_count(id, state)
	if id == "arc": return "주 표적 공격 후 가장 가까운 다른 생존 적에게 전이 %d피해." % Content.effect_value(id, state)
	return Content.AMMO[id].text

static func stats(id: String, state: Dictionary, full: bool = false) -> String:
	var spec: Dictionary = Content.AMMO[id]
	var damage := str(Content.damage(id, state))
	if spec.effect == "double": damage += "×%d" % Content.hit_count(id, state)
	var result := "피해 " + damage
	var visible := Content.axes(state)
	if full or visible.armor: result += "  관통 %d" % Content.penetration(id, state)
	result += "  ·  " + str(AmmoVisual.ATTRIBUTE_NAMES[spec.attribute])
	return result

static func explain(shot: Dictionary) -> String:
	if shot.is_empty(): return "탄환을 넣으면 실제 피해와 계산 근거를 보여 줍니다."
	if shot.get("random", false):
		var targets: PackedStringArray = []
		for candidate in shot.targets:
			targets.append("%s %d%%" % [Forecast.tag(candidate.target), floori(minf(1.0, float(candidate.probability) + 0.0000001) * 100)])
		return "무작위 · 주 피해 %d~%d\n%s\n전이·화상은 최종 HP 범위에 포함됩니다." % [shot.damage_min, shot.damage_max, " / ".join(targets)]
	if not shot.has("math"): return str(shot.get("text", ""))
	var m: Dictionary = shot.math
	var line := "%s · %d피해  HP %d → %d" % [Forecast.tag(shot.target), shot.damage, m.hp_before, shot.hp]
	var equation := "피해 %d" % m.base
	if m.boost > 0: equation += " + 증폭 %d" % m.boost
	if int(m.get("weakness", 0)) > 0: equation += " + 약점 %d" % int(m.weakness)
	if int(m.get("overflow", 0)) > 0: equation += " + 초과관통 %d" % m.overflow
	if m.armor > 0: equation += " − 장갑 %d" % m.armor
	equation += " = %d" % m.per_hit
	if int(m.raw) - int(m.armor) < 1: equation += " (최소 1)"
	if m.hits > 1: equation += " · %d회" % m.hits
	if int(m.get("focus", 0)) > 0: equation += " + 집중 %d" % m.focus
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
	if int(enemy.get("barrier_max", 0)) > 0: parts.append("◆%d/%d" % [enemy.get("barrier", 0), enemy.barrier_max])
	if int(enemy.get("charge_max", 0)) > 0: parts.append("충%d/%d" % [enemy.get("charge", 0), enemy.charge_max])
	if bool(enemy.get("stance", false)): parts.append("장%d→%d" % [enemy.def, 0 if bool(enemy.get("stance_closed", true)) else int(enemy.get("stance_def", 4))])
	elif full or visible.armor: parts.append("장갑%d" % enemy.def)
	parts.append("접근%dm" % enemy.speed)
	if int(enemy.get("burn", 0)) > 0: parts.append("화상%d" % enemy.burn)
	if state.get("gun", "") == "burst": parts.append("적중%d/3" % int(enemy.get("focus_hits", 0)))
	return "  ".join(parts)
