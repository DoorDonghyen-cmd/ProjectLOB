class_name AmmoGuidance
extends RefCounted

## 현재 LIFO 탄열과 최근접 강제 타깃만 사용해 연계탄의 게이트 기여와
## 결산탄의 조건 충족·예상 주 피해를 설명한다.
## 처치·재타깃·집중·조건부 파츠를 대신 풀지 않아 플레이어의 순서 설계는 남긴다.

const DamageCalculatorScript := preload("res://scripts/core/damage_calculator.gd")
const BulletRoleUIScript := preload("res://scripts/ui/bullet_role_ui.gd")


static func preview_entries(
	loaded_bullets: Array[BulletData],
	gun: GunData,
	target: EnemyInstance
) -> Array[Dictionary]:
	var fire_order: Array[BulletData] = []
	for i in range(loaded_bullets.size() - 1, -1, -1):
		fire_order.append(loaded_bullets[i])

	var entries: Array[Dictionary] = []
	var accuracy_bonuses: Array[int] = []
	var penetration_bonuses: Array[int] = []
	var damage_bonuses: Array[int] = []
	var adjacent_accuracy_bonuses: Array[int] = []
	var adjacent_penetration_bonuses: Array[int] = []
	accuracy_bonuses.resize(fire_order.size())
	penetration_bonuses.resize(fire_order.size())
	damage_bonuses.resize(fire_order.size())
	adjacent_accuracy_bonuses.resize(fire_order.size())
	adjacent_penetration_bonuses.resize(fire_order.size())
	accuracy_bonuses.fill(0)
	penetration_bonuses.fill(0)
	damage_bonuses.fill(0)
	adjacent_accuracy_bonuses.fill(0)
	adjacent_penetration_bonuses.fill(0)
	var previous_effective := false
	var previous_specialty := ""
	for index in range(fire_order.size()):
		var bullet := fire_order[index]
		if bullet == null:
			continue

		if BulletRoleUIScript.normalize(bullet.role) == BulletRoleUIScript.LINK:
			var axis := _effect_axis(bullet.effect_type)
			if not axis.is_empty():
				entries.append(_preview_link(
					bullet, index, fire_order, gun, target, axis,
					accuracy_bonuses, penetration_bonuses, damage_bonuses,
					adjacent_accuracy_bonuses, adjacent_penetration_bonuses))

		var stats := DamageCalculatorScript.effective_stats(bullet, gun)
		stats.damage += damage_bonuses[index]
		var hit := target != null \
			and int(stats.accuracy) + accuracy_bonuses[index] >= target.current_evasion
		var penetrated := target != null \
			and int(stats.penetration) + penetration_bonuses[index] >= target.current_def
		if BulletRoleUIScript.is_payoff(bullet):
			entries.append(_preview_payoff(
				bullet, stats, target, previous_effective, previous_specialty,
				hit, penetrated, accuracy_bonuses[index], penetration_bonuses[index],
				adjacent_accuracy_bonuses[index], adjacent_penetration_bonuses[index]))
		previous_effective = hit and penetrated
		previous_specialty = BulletRoleUIScript.normalize_specialty(bullet.specialty)
	return entries


static func summary_text(
	loaded_bullets: Array[BulletData],
	gun: GunData,
	target: EnemyInstance
) -> String:
	var entries := preview_entries(loaded_bullets, gun, target)
	var lines: Array[String] = []
	for entry in entries:
		lines.append(str(entry.text))
	return "\n".join(lines)


static func _preview_link(
	link: BulletData,
	index: int,
	fire_order: Array[BulletData],
	gun: GunData,
	target: EnemyInstance,
	axis: String,
	accuracy_bonuses: Array[int],
	penetration_bonuses: Array[int],
	damage_bonuses: Array[int],
	adjacent_accuracy_bonuses: Array[int],
	adjacent_penetration_bonuses: Array[int]
) -> Dictionary:
	var axis_label: String = str({
		"accuracy": "명중", "penetration": "관통", "damage": "피해"
	}.get(axis, ""))
	var result := {
		"kind": "link",
		"bullet_name": link.display_name,
		"axis": axis,
		"axis_label": axis_label,
		"converted": 0,
		"triggered": false,
		"text": "",
	}
	if target == null:
		result.text = "%s: 현재 대열 없음" % link.display_name
		return result

	if not _can_trigger(
		link, gun, target, accuracy_bonuses[index], penetration_bonuses[index]):
		result.text = "%s: 발동 불가 · 선행탄 게이트 실패" % link.display_name
		return result
	result.triggered = true

	var affected := _affected_indices(link.scope, index, fire_order.size())
	var gate := target.current_evasion if axis == "accuracy" else target.current_def
	var converted := 0
	for affected_index in affected:
		var bullet := fire_order[affected_index]
		if bullet == null:
			continue
		var stats := DamageCalculatorScript.effective_stats(bullet, gun)
		var before := int(stats.damage) + damage_bonuses[affected_index]
		if axis == "accuracy":
			before = int(stats.accuracy) + accuracy_bonuses[affected_index]
		elif axis == "penetration":
			before = int(stats.penetration) + penetration_bonuses[affected_index]
		var after := before + maxi(link.effect_value, 0)
		if axis == "damage":
			converted += 1
		elif before < gate and after >= gate:
			converted += 1
		if axis == "accuracy":
			accuracy_bonuses[affected_index] += maxi(link.effect_value, 0)
			if BulletRoleUIScript.normalize_scope(link.scope) == BulletRoleUIScript.SCOPE_NEXT_SHOT:
				adjacent_accuracy_bonuses[affected_index] += maxi(link.effect_value, 0)
		elif axis == "penetration":
			penetration_bonuses[affected_index] += maxi(link.effect_value, 0)
			if BulletRoleUIScript.normalize_scope(link.scope) == BulletRoleUIScript.SCOPE_NEXT_SHOT:
				adjacent_penetration_bonuses[affected_index] += maxi(link.effect_value, 0)
		else:
			damage_bonuses[affected_index] += maxi(link.effect_value, 0)

	result.converted = converted
	if axis == "damage":
		result.text = "%s: 다음 %d발 피해 +%d" % [
			link.display_name, converted, maxi(link.effect_value, 0)
		]
	else:
		result.text = (
			"%s: %s 전환 %d발" % [link.display_name, axis_label, converted]
			if converted > 0
			else "%s: 현재 대열 게이트 전환 없음" % link.display_name
		)
	return result


static func _preview_payoff(
	bullet: BulletData,
	stats: Dictionary,
	target: EnemyInstance,
	previous_effective: bool,
	previous_specialty: String,
	hit: bool,
	penetrated: bool,
	accuracy_bonus: int,
	penetration_bonus: int,
	adjacent_accuracy_bonus: int,
	adjacent_penetration_bonus: int
) -> Dictionary:
	var result := {
		"kind": "payoff",
		"bullet_name": bullet.display_name,
		"triggered": false,
		"critical": false,
		"expected_damage": 0,
		"bonus_damage": maxi(bullet.effect_value, 0),
		"text": "",
	}
	var condition_met := false
	match bullet.effect_type:
		Enums.BulletEffect.COMBO:
			condition_met = previous_effective
		Enums.BulletEffect.CALIBER_DIFF:
			condition_met = not previous_specialty.is_empty() \
				and previous_specialty != BulletRoleUIScript.normalize_specialty(bullet.specialty)

	if not condition_met:
		var need := (
			"직전 유효 적중 필요"
			if bullet.effect_type == Enums.BulletEffect.COMBO
			else "전문축 교대 필요"
		)
		result.text = "%s: 결산 실패 · %s" % [bullet.display_name, need]
		return result

	result.triggered = true
	if target == null:
		result.text = "%s: 발동 조건 충족 · 현재 대열 없음" % bullet.display_name
		return result
	if not hit:
		result.text = "%s: 발동 조건 충족 · 현재 대상 빗나감 예상" % bullet.display_name
		return result
	if not penetrated:
		result.text = "%s: 발동 조건 충족 · 현재 대상 도탄 예상" % bullet.display_name
		return result

	var hit_without_adjacent := (
		int(stats.accuracy) + accuracy_bonus - adjacent_accuracy_bonus
		>= target.current_evasion
	)
	var penetrated_without_adjacent := (
		int(stats.penetration) + penetration_bonus - adjacent_penetration_bonus
		>= target.current_def
	)
	var critical := not hit_without_adjacent or not penetrated_without_adjacent
	var expected_damage := int(stats.damage) + maxi(bullet.effect_value, 0)
	if critical:
		expected_damage = floori(float(expected_damage) * 1.5)
	result.critical = critical
	result.expected_damage = expected_damage
	var detail := "결산 +%d" % maxi(bullet.effect_value, 0)
	if critical:
		detail += " · 게이트 개방 ×1.5"
	result.text = "%s: 결산 성공 · 예상 주 피해 %d (%s)" % [
		bullet.display_name, expected_damage, detail]
	return result


static func _can_trigger(
	link: BulletData,
	gun: GunData,
	target: EnemyInstance,
	accuracy_bonus: int = 0,
	penetration_bonus: int = 0
) -> bool:
	var stats := DamageCalculatorScript.effective_stats(link, gun)
	var hits := int(stats.accuracy) + accuracy_bonus >= target.current_evasion
	match link.trigger.strip_edges().to_lower():
		"on_effective_hit":
			return hits and int(stats.penetration) + penetration_bonus >= target.current_def
		"on_hit":
			return hits
		_:
			return true


static func _affected_indices(scope: String, index: int, size: int) -> Array[int]:
	var result: Array[int] = []
	if index + 1 >= size:
		return result
	match BulletRoleUIScript.normalize_scope(scope):
		BulletRoleUIScript.SCOPE_NEXT_SHOT:
			result.append(index + 1)
		BulletRoleUIScript.SCOPE_TARGET, BulletRoleUIScript.SCOPE_REMAINING_MAG:
			for i in range(index + 1, size):
				result.append(i)
	return result


static func _effect_axis(effect_type: int) -> String:
	match effect_type:
		Enums.BulletEffect.BUFF_ACC, Enums.BulletEffect.DEBUFF_EVA, Enums.BulletEffect.BUFF_MAG_ACC:
			return "accuracy"
		Enums.BulletEffect.BUFF_PEN, Enums.BulletEffect.ARMOR_SHRED, Enums.BulletEffect.BUFF_MAG_PEN:
			return "penetration"
		Enums.BulletEffect.BUFF_DMG:
			return "damage"
		_:
			return ""
