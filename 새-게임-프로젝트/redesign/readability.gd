extends RefCounted
## Format public values and evidence emitted by the actual resolver. No damage oracle here.
const Content = preload("res://redesign/content.gd")
const Forecast = preload("res://redesign/forecast.gd")
const AmmoVisual = preload("res://redesign/ammo_visual.gd")
const Reserve = preload("res://redesign/ammo_reserve.gd")

static func cycle_text(state: Dictionary) -> String:
	return "사용한 탄은 이번 전투에 돌아오지 않으며, 다음 전투에서 보유 탄약이 복구됩니다." if Reserve.enabled(state) else "사용 후 버린 더미로 이동하며 덱이 비면 다시 섞습니다."

## What one round is and does (launch pass 2026-11-12). One line of grade and power, then the
## round's own effect. Heat and slots are on the card and in each screen's own number row, and
## the consecutive-fire heat rule is in 게임 규칙 and on the heat gauge, so neither is repeated
## under every round.
static func description(id: String, state: Dictionary) -> String:
	var head := Content.grade_detail(id)
	if not Content.profile_detail(id).is_empty(): head += " · " + Content.profile_detail(id)
	var body := _description(id, state)
	if Content.is_compressed(id):
		body = body.replace("\n" + Content.compression_cost_text(id, state), "")
		if Content.anchor(id) == "first": body += "\n탄창 맨 앞에 장전됩니다."
		elif Content.anchor(id) == "last": body += "\n탄창 맨 뒤에 장전됩니다."
	var text := head + "\n" + body
	# Tag build runs: the round's tags and what the equipped tag parts do to it, first.
	var Tags = preload("res://redesign/tag_build.gd")
	if Tags.enabled(state): text = Tags.round_summary(state, id, Content.active_parts(state)) + "\n\n" + text
	return text

static func _description(id: String, state: Dictionary) -> String:
	var spec: Dictionary = Content.AMMO[id]
	# 2026-11-12 round rework (ammo_revision.gd): 연계탄 and 예약탄 in new runs.
	var revised := preload("res://redesign/ammo_revision.gd").text(id, state)
	if not revised.is_empty(): return revised
	if Content.Roles.enabled(state) and spec.effect=="disrupt":return "적의 특수 행동을 끊고, 적 %d행동 동안 접근을 절반으로 늦춥니다. 적마다 한 번만 걸립니다."%Content.Roles.slow_duration(state,Content.is_compressed(id),Content.equipped_parts(state))
	if Content.Roles.enabled(state) and spec.effect=="burn":return "표적에 화상 %d턴, 맞은 자리 앞뒤 %dm에 불길 %d행동.\n적 행동마다 화상 %d · 불길 %d피해, 장갑 무시. 겹치면 큰 쪽만 적용됩니다."%[Content.burn_amount(id,state),Content.Roles.fire_radius(state,Content.equipped_parts(state)),Content.Roles.fire_duration(Content.equipped_parts(state),state),Content.burn_damage(state),Content.burn_damage(state)+(Content.Roles.coil_ground_bonus(state) if Content.has_part(state,"coil") else 0)]
	if spec.effect == "burn":
		return "직접 피해 %d · 보호막에 막혀도 화상 %d턴 부여.\n매 적 행동 직전 HP에 %d피해 · 보호막·장갑 무시.\n재장전 중에도 진행. 추가 적중은 기간을 더하며 최대 6턴, 턴당 피해는 중첩되지 않습니다.\n%s" % [Content.damage(id, state), Content.burn_amount(id, state), Content.burn_damage(state), Content.compression_cost_text(id, state)]
	if spec.get("profile",false):
		var rule := "특수 효과 없는 기본 탄환입니다."
		if Content.source_id(id) == "pierce": rule = "관통 %d만큼 장갑을 무시합니다." % Content.penetration(id,state)
		if Content.source_id(id) == "precise": rule = "같은 적을 %d회 타격합니다. 증폭·파츠 피해도 타격마다 적용됩니다." % Content.hit_count(id,state)
		if Content.is_compressed(id): rule += "\n" + Content.compression_cost_text(id,state)
		return rule
	if spec.effect == "boost":
		var rule := "피해 없음 · 다음 공격탄 %d발 %s. " % [Content.boost_rounds(id), Content.boost_label(id, state)]
		if bool(spec.get("boost_hot",false)):
			rule += "공격 직전 열이 %d 이상일 때만 강화하고, 낮으면 효과 없이 사라집니다. " % Content.hot_threshold(state)
		elif int(spec.get("boost_heat",0)) > 0:
			rule += "강화받은 공격의 열 +%d. " % int(spec.boost_heat)
		rule += "배율탄끼리는 나중 것만 남고 증폭탄과는 겹칩니다. " if Content.boost_factor(id, state) > 1 else "증폭탄끼리는 나중 것만 남고 배율탄과는 겹칩니다. "
		rule += "탄창을 한 번 교체해도 이어집니다." if Content.is_compressed(id) else "탄창을 교체하면 사라집니다."
		return rule + ("\n" + Content.compression_cost_text(id, state) if Content.is_compressed(id) else "")
	if spec.effect == "shatter":
		return "피해 없이 장갑 −%d. 증폭 효과는 쓰지 않고 다음 공격탄에 남습니다." % Content.effect_value(id, state) + ("\n" + Content.compression_cost_text(id, state) if Content.is_compressed(id) else "")

	# Magazine game wording (launch pass 2026-11-12): what the round does, without the loading
	# order notes and edge cases written for the hand-loading training mode below.
	if preload("res://redesign/magazine_trial.gd").enabled(state):
		var amount := Content.effect_value(id, state)
		match str(spec.effect):
			"spread": return "표적의 화상을 최대 %d턴만큼 뒤의 가장 가까운 적에게 옮깁니다. 소이탄 다음에 쏘세요." % amount
			"vent": return "쌓인 열을 최대 %d까지 써서 열 1당 피해 +%d." % [int(spec.heat_spend), amount] + (" 과열 직후 강행으로도 쏠 수 있습니다." if Content.reactor_enabled(state) else "")
			"detonate": return ("남은 화상 피해의 2배를" if Content.is_compressed(id) else "남은 화상 피해를") + " 한 번에 터뜨리고 화상을 없앱니다. 장갑·배리어 무시. 소이탄 다음에 쏘세요."
			"chase": return "바로 앞 탄이 적을 처치했다면 피해 +%d." % amount
			"bypass": return "맨 앞 적을 건너뛰고 두 번째 적을 공격합니다. 적이 하나뿐이면 그 적을 공격합니다."
			"cool": return "열을 %d 낮춥니다." % amount + (" 강행 탄으로 써서 한계 아래로 내리면 강제 냉각 없이 끝납니다." if Content.reactor_enabled(state) else "")
		match id:
			"pierce_c": return "관통 %d만큼 장갑을 무시합니다." % Content.penetration(id, state) + (" 탄창 %d칸을 차지합니다." % Content.slot_cost(id) if Content.slot_cost(id) > 1 else "")
			"push_c": return "적을 최대 %dm 밀칩니다." % amount
			"precise_c": return "같은 적을 %d회 타격합니다. 증폭 피해도 타격마다 적용됩니다." % Content.hit_count(id, state)
			"arc_c": return "표적 뒤의 모든 적에게 전이 %d피해(장갑 무시)." % amount
			"basic": return "특수 효과 없는 기본 탄환입니다."
			"pierce": return "관통 %d만큼 장갑을 무시합니다." % Content.penetration(id, state)
	if Content.is_compressed(id) and Content.source_id(id) in ["prepare", "disrupt", "spread", "sequence", "vent", "thermal", "shatter", "detonate", "chase", "bypass", "cool"]:
		var value := Content.effect_value(id, state)
		var rule := ""
		match str(spec.effect):
			"prepare": rule = "뒤의 전술탄 %d발을 다음 재장전 패로 예약. 총 3장 한도, 임시탄 제외. 복제하지 않습니다." % value
			"disrupt": rule = "생존 표적의 발사 준비·충전을 %d턴 정지. 적마다 한 번, 이동·발사된 압력탄에는 효과가 없습니다." % value
			"spread": rule = "화상 최대 %d를 표적 뒤의 가장 가까운 생존 적에게 이동. 원래 적에게서 옮긴 만큼 차감합니다." % value
			"sequence": rule = "앞서 발사한 다른 탄종마다 피해 +%d, 최대 3종. 같은 탄과 압축형은 한 종류입니다." % value
			"vent": rule = "발사 직전 열 최대 %d 소모 · 열 1당 피해 +%d. 앞에서 과열되면 발사되지 않습니다." % [int(spec.heat_spend), value]
			"thermal": rule = "발사 직전 열 %d 이상이면 피해 +%d. 자신의 발열로는 조건을 채우지 않습니다." % [Content.hot_threshold(state), value]
			"shatter": rule = "타격 후 장갑 −%d. 배리어에 막혀도 적용하며 이 탄의 직접 피해는 감소 전 장갑을 적용합니다." % value
			"detonate": rule = "남은 화상의 총 피해 ×2를 즉시 입히고 화상을 제거. 장갑·배리어 무시, 화상 없으면 기폭 피해도 없습니다."
			"chase": rule = "직전 탄이 적을 처치했으면 피해 +%d. 전이 처치는 인정, 요격·턴 종료 화상 처치는 제외합니다." % value
			"bypass": rule = "앞 적을 건너뛰어 두 번째 적을 공격. 스플린터는 앞 적 제외 무작위, 최근접 압력탄 요격 우선."
			"cool": rule = "현재 열 −%d. 첫 발 고정이므로 중간 발열을 식힐 수 없으며 열을 저축하지 않습니다." % value
		return rule + "\n" + Content.compression_cost_text(id, state)
	if Content.is_temporary(id) and not Content.anchor(id).is_empty():
		return ("먼저 압축 장전 · 마지막 발사. " if Content.anchor(id) == "last" else "마지막에 압축 장전 · 첫 발사. ") + str(spec.text)
	if Content.is_compressed(id):
		match id:
			"pierce_c": return "탄창 2칸 · 피해 %d · 관통 %d를 한 발에 집중합니다." % [Content.damage(id, state), Content.penetration(id, state)]
			"push_c": return "먼저 장전 · 마지막 발사 · 적을 최대 %dm 밀칩니다." % Content.effect_value(id, state)
			"precise_c": return "마지막 장전 · 첫 발사 · 같은 적을 %d회 타격합니다." % Content.hit_count(id, state)
			"arc_c": return "마지막 장전 · 첫 발사 · 주 표적 뒤의 모든 생존 적에게 전이 %d피해." % Content.effect_value(id, state)
	if id == "basic": return "발열 1의 물리 탄환. " + cycle_text(state) if Content.uses_ammo_cards(state) else "재장전마다 별도로 보급되는 기본탄입니다."
	if state.get("course", false) and int(state.floor) == 0:
		if id == "basic": return "발열 1의 물리 탄환. 한 장당 한 발이며 사용 후 버린 더미로 이동합니다." if Content.uses_ammo_cards(state) else "재장전할 때 다시 채워지는 물리 기본탄입니다."
	if id == "push": return "적을 %dm 밀칩니다. 탄창당 총 %dm까지 적용됩니다." % [Content.effect_value(id, state), Content.push_budget(state)]
	if id == "precise": return "같은 적을 %d회 타격합니다. 증폭 피해도 타격마다 적용됩니다." % Content.hit_count(id, state)
	if id == "shatter": return "맞힌 뒤 장갑 −%d. 배리어에 막혀도 적용됩니다." % Content.effect_value(id, state)
	if id == "chase": return "바로 앞 탄이 적을 처치했다면 피해 +%d." % Content.effect_value(id, state)
	if id == "vent" and Content.reactor_enabled(state): return "쌓인 열을 최대 %d까지 써서 열 1당 피해 +%d. 과열 직후 강행으로도 쏠 수 있습니다." % [int(spec.heat_spend),Content.effect_value(id, state)]
	if id == "vent": return "쌓인 열을 최대 %d까지 써서 열 1당 피해 +%d." % [int(spec.heat_spend), Content.effect_value(id, state)]
	if id == "cool" and Content.reactor_enabled(state): return "열을 %d 낮춥니다. 강행 탄으로 써서 한계 아래로 내리면 강제 냉각 없이 끝납니다." % Content.effect_value(id, state)
	if id == "cool": return "열을 %d 낮춥니다." % Content.effect_value(id, state)
	if id == "prepare": return "뒤의 전술탄 %d발을 다음 재장전 패로 예약합니다. 현장 압축탄 제외, 전체 예약 최대 3장. 먼저 발사되도록 마지막에 장전하세요. 탄환은 복제하지 않습니다." % Content.effect_value(id, state)
	if id == "disrupt": return "표적의 발사 준비·충전을 %d턴 멈춥니다. 적마다 한 번만 걸립니다." % Content.effect_value(id, state)
	if id == "spread": return "표적의 화상을 최대 %d턴만큼 뒤의 가장 가까운 적에게 옮깁니다. 소이탄 다음에 쏘세요." % Content.effect_value(id, state)
	if id == "sequence": return "이번 탄창에서 앞서 발사한 다른 탄종마다 피해 +%d, 최대 3종. 같은 탄과 압축형은 한 종류이며 연계탄 자신은 제외합니다. 긴 탄창과 다양한 저발열탄에 연결됩니다." % Content.effect_value(id, state)
	if id == "arc": return "표적 뒤의 가장 가까운 적에게 전이 %d피해(장갑 무시). 귀족 거주구의 차폐는 전격탄 두 번으로 걷힙니다." % Content.effect_value(id, state)
	return Content.AMMO[id].text

static func stats(id: String, state: Dictionary, full: bool = false) -> String:
	var spec: Dictionary = Content.AMMO[id]
	var damage := str(Content.damage(id, state))
	if spec.effect == "double": damage += "×%d" % Content.hit_count(id, state)
	var primary := Content.primary_stat(id, state)
	var result := "%s %s · %s" % [primary.label, primary.value, Content.ammo_role(id)]
	var visible := Content.axes(state)
	if full or visible.armor: result += "  관통 %d" % Content.penetration(id, state)
	result += "  열 " + Content.heat_label(id, state)
	result += "  ·  " + str(AmmoVisual.ATTRIBUTE_NAMES[spec.attribute])
	return result

static func explain(shot: Dictionary, enemies: Array = []) -> String:
	var text := _explain(shot, enemies)
	if shot.get("sustained_active",false) and Content.AMMO.has(str(shot.get("id",""))):
		if str(Content.AMMO[str(shot.id)].effect) in ["cool","vent"]:
			text += "\n발사 시 연속 공격 초기화"
		elif Content.is_attack(str(shot.id)):
			text += "\n발사 시 연속 %d번째 공격 · 추가 열 +%d" % [int(shot.get("sustained_before",0))+1,int(shot.get("sustained_heat",0))]
	return text

static func _explain(shot: Dictionary, enemies: Array = []) -> String:
	if shot.is_empty(): return "탄환을 넣으면 실제 피해와 계산 근거를 보여 줍니다."
	if shot.get("random", false):
		var targets: PackedStringArray = []
		for candidate in shot.targets:
			targets.append("%s %d%%" % [Forecast.tag(candidate.target, enemies), floori(minf(1.0, float(candidate.probability) + 0.0000001) * 100)])
		return "무작위 · 주 피해 %d~%d\n%s\n전이·화상은 최종 HP 범위에 포함됩니다." % [shot.damage_min, shot.damage_max, " / ".join(targets)]
	if not shot.has("math"): return str(shot.get("text", ""))
	var m: Dictionary = shot.math
	var line := "%s · %d피해  HP %d → %d" % [Forecast.tag(shot.target, enemies), shot.damage, m.hp_before, shot.hp]
	var equation := "피해 %d" % m.base
	if int(m.get("thermal", 0)) > 0: equation += " + 고열 %d" % int(m.thermal)
	if int(m.get("vent", 0)) > 0: equation += " + 열 전환 %d" % int(m.vent)
	if int(m.get("sequence", 0)) > 0: equation += " + 연계탄 %d" % int(m.sequence)
	if m.boost > 0: equation += " + 증폭 %d" % m.boost
	if int(m.get("chase", 0)) > 0: equation += " + 추격 %d" % int(m.chase)
	if int(m.get("part_bonus", 0)) > 0: equation += " + 파츠 %d" % int(m.part_bonus)
	if int(m.get("weakness", 0)) > 0: equation += " + 약점 %d" % int(m.weakness)
	if int(m.get("overflow", 0)) > 0: equation += " + 초과관통 %d" % m.overflow
	if int(m.get("factor", 1)) > 1: equation = "(" + equation + ") ×%d" % int(m.factor)
	if float(m.get("part_factor", 1)) > 1.0:
		var position_label := str(shot.get("position_label", ""))
		var factor := ("%.2f" % float(m.part_factor)).rstrip("0").rstrip(".")
		equation = "(%s) ×%s(%s)" % [equation, factor, "파츠" if not position_label.is_empty() else "후미"]
	if int(m.get("engine_percent", 100)) != 100: equation = "(" + equation + ") ×%.2f" % (int(m.engine_percent)/100.0)
	if int(m.get("tag_percent", 100)) != 100: equation = "(" + equation + ") ×%.2f 태그" % (int(m.tag_percent)/100.0)
	if int(m.get("gate_percent",100))>100: equation += " ×%.2f(연쇄)" % (int(m.gate_percent)/100.0)
	if int(m.get("overdrive_percent",100))>100: equation = "(" + equation + ") ×%.2f(강행)" % (int(m.overdrive_percent)/100.0)
	if int(m.get("engine_percent",100))!=100 or int(m.get("gate_percent",100))!=100 or int(m.get("overdrive_percent",100))!=100: equation += " (버림)"
	var charged := int(m.get("gate_charge",0))>0
	if charged: equation += " + 축열 %d" % int(m.gate_charge)
	if m.armor > 0:
		if m.has("armor_percent"): equation = "(" + equation + ") ×%d%% (장갑%d, 버림)" % [100-int(m.armor_percent),m.armor]
		else: equation += " − 장갑 %d" % m.armor
	equation += " = %d" % int(m.get("first_hit",m.per_hit))
	if charged:
		equation += " (첫 타격)"
		if m.hits>1: equation += " · 이후 %d × %d회" % [m.per_hit,m.hits-1]
	else:
		var reduced := floori(int(m.raw)*(100-int(m.armor_percent))/100.0) if m.has("armor_percent") else int(m.raw)-int(m.armor)
		if int(m.raw) > 0 and reduced < 1: equation += " (최소 1)"
		if m.hits > 1: equation += " · %d회" % m.hits
	if int(m.get("focus", 0)) > 0: equation += " + 집중 %d" % m.focus
	line += "\n" + equation
	var reasons: PackedStringArray = []
	if not shot.get("prepared_rounds", []).is_empty():
		var names: PackedStringArray = []
		for id in shot.prepared_rounds: names.append(Content.AMMO[id].name)
		reasons.append("다음 패 예약 · " + "/".join(names))
	if int(shot.get("interrupted", 0)) > 0: reasons.append("특수 행동 %d턴 정지 · 이 적 차단 소진" % shot.interrupted)
	if int(shot.get("detonation", 0)) > 0: reasons.append("남은 화상 기폭 %d피해 · 화상 소모" % int(shot.detonation))
	if int(shot.get("armor_removed", 0)) > 0: reasons.append("후속 장갑 −%d" % int(shot.armor_removed))
	if int(shot.get("cooled", 0)) > 0: reasons.append("열 −%d" % int(shot.cooled))
	if m.armor_before > 0:
		reasons.append("장갑%d − 관통%d → 남은%d" % [m.armor_before, shot.pen, m.armor])
	if int(m.get("first_hit",m.per_hit)) + int(m.per_hit) * maxi(0,int(m.hits)-1) > int(m.hp_before): reasons.append("남은 HP까지만 피해")
	if bool(shot.get("gate_chain_earned",false)): reasons.append("직접 처치 · 다음 탄 연쇄 ×%.2f" % (int(shot.gate_next_percent)/100.0))
	if int(shot.get("burn_added", 0)) > 0: reasons.append("화상 +%d → %d" % [shot.burn_added, shot.burn])
	if int(shot.get("push", 0)) > 0: reasons.append("거리 +%dm" % shot.push)
	for other in shot.get("secondary", []):
		if other.has("wreckage_hit"):
			reasons.append("잔해 −%d칸" % int(other.wreckage_hit))
		elif str(other.get("kind", "arc")) == "burn_transfer":
			reasons.append("%s에게 화상 %d 이동" % [Forecast.tag(other.target, enemies), other.transferred])
		elif str(other.get("kind", "arc")) == "spread":
			reasons.append("%s 확산 %d피해 (절반%d − 장갑%d, %d회) · HP%d" % [Forecast.tag(other.target, enemies), other.damage, other.raw, other.armor, other.hits, other.hp])
		elif str(other.get("kind", "arc")) in ["relay", "overflow"]:
			reasons.append("%s %s %d피해 · HP%d%s" % [Forecast.tag(other.target,enemies), "잔타 연결" if other.kind == "relay" else "돌파", other.damage, other.hp, " · 배리어 차단" if int(other.get("blocked_hits",0))>0 else ""])
		elif str(other.get("kind",""))=="heat_wave":
			var mitigation := " ×%d%%" % (100-int(other.armor_percent)) if other.has("armor_percent") else " − 장갑%d" % int(other.armor)
			reasons.append("%s 열압 %d피해 (절반%d%s) · HP%d%s" % [Forecast.tag(other.target,enemies),other.damage,other.raw,mitigation,other.hp," · 배리어 차단" if int(other.get("blocked_hits",0))>0 else ""])
		else: reasons.append("%s 전이 %d피해 (고정) · HP%d" % [Forecast.tag(other.target, enemies), other.damage, other.hp])
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
	if int(enemy.get("burn", 0)) > 0: parts.append("화상 %d/턴 · %d턴" % [Content.burn_damage(state), enemy.burn])
	if state.get("gun", "") == "burst": parts.append("적중%d/3" % int(enemy.get("focus_hits", 0)))
	return "  ".join(parts)
