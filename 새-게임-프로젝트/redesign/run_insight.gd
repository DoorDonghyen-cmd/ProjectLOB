extends RefCounted
## Converts already-public combat state into compact debrief and reward guidance.
## It never predicts hidden rolls or mutates the run.
const Content = preload("res://redesign/content.gd")

static func combat_report(state: Dictionary, floor_filter: int = -1) -> Dictionary:
	var report := {"shots": 0, "direct": 0, "burn": 0, "arc": 0, "spread": 0, "focus": 0, "boost_hits": 0, "push": 0, "kills": 0, "heat_peak": 0, "heat_added": 0, "cooled": 0, "vented": 0, "kill_cooled": 0, "chain_cooled": 0, "heat_used_shots": 0, "overheats": 0, "forced_reloads": 0}
	for entry_value in state.get("history", []):
		var entry: Dictionary = entry_value
		if floor_filter >= 0 and int(entry.get("floor", -1)) != floor_filter:
			continue
		var detail: Dictionary = entry.get("detail", {})
		if str(entry.get("action", "")) == "fire":
			# The nested reload is also a standalone history entry. Count the
			# automatic action here once; burn damage below uses standalone events.
			report.heat_peak = maxi(int(report.heat_peak), int(detail.get("heat_peak", 0)))
			if bool(detail.get("overheated", false)): report.overheats += 1
			if not detail.get("forced_reload", {}).is_empty(): report.forced_reloads += 1
			for shot_value in detail.get("results", []):
				var shot: Dictionary = shot_value
				report.shots += 1
				report.heat_added += int(shot.get("heat_added", 0))
				report.cooled += int(shot.get("cooled", 0))
				report.vented += int(shot.get("vented", 0))
				report.kill_cooled += int(shot.get("kill_cooled", 0))
				report.chain_cooled += int(shot.get("chain_cooled", 0))
				var used_heat := int(shot.get("thermal_bonus", 0)) > 0 or int(shot.get("vent_bonus", 0)) > 0
				for effect in shot.get("part_effects", []):
					if str(effect.get("id", "")) == "ember_core": used_heat = true
				if used_heat and int(shot.get("hits", 1)) > int(shot.get("blocked_hits", 0)): report.heat_used_shots += 1
				report.direct += int(shot.get("damage", 0))
				report.focus += int(shot.get("focus_damage", 0))
				report.push += int(shot.get("push", 0))
				if int(shot.get("math", {}).get("boost", 0)) > 0:
					report.boost_hits += int(shot.get("hits", 1))
				if int(shot.get("hp", 1)) <= 0 and not bool(shot.get("intercept", false)):
					report.kills += 1
				for secondary_value in shot.get("secondary", []):
					var secondary: Dictionary = secondary_value
					if str(secondary.get("kind", "arc")) == "spread": report.spread += int(secondary.get("damage", 0))
					else: report.arc += int(secondary.get("damage", 0))
					if int(secondary.get("hp", 1)) <= 0 and not bool(secondary.get("intercept", false)):
						report.kills += 1
		for event_value in detail.get("advance_events", []):
			var event: Dictionary = event_value
			if str(event.get("kind", "")) == "burn":
				report.burn += int(event.get("damage", 0))
				if int(event.get("hp", 1)) <= 0:
					report.kills += 1
	return report

static func combat_report_line(state: Dictionary, floor_filter: int = -1) -> String:
	var report := combat_report(state, floor_filter)
	var items: PackedStringArray = ["직접 %d" % int(report.direct)]
	if int(report.boost_hits) > 0: items.append("증폭 타격 %d" % int(report.boost_hits))
	if int(report.burn) > 0: items.append("화상 %d" % int(report.burn))
	if int(report.focus) > 0: items.append("집중 추가 %d" % int(report.focus))
	if int(report.arc) > 0: items.append("전이 %d" % int(report.arc))
	if int(report.spread) > 0: items.append("확산 %d" % int(report.spread))
	if int(report.push) > 0: items.append("밀기 %dm" % int(report.push))
	if int(report.kills) > 0: items.append("처치 %d" % int(report.kills))
	return "교전 기록 · " + " · ".join(items)

static func heat_report_tip(report: Dictionary) -> String:
	return "최고 열은 각 탄의 효과와 처치 냉각 적용 후 기록합니다.\n냉각 %d = 냉각탄 %d + 열방출탄 %d + 순환펌프 %d + 연쇄 방열 %d. 재장전 냉각은 제외합니다.\n열 보너스가 적용된 탄 %d발. 추가 HP 피해량과는 다릅니다.\n과열 %d회 중 강제 재장전 %d회. 과열한 발로 전투가 끝나면 강제 재장전은 생략됩니다." % [report.cooled, int(report.cooled) - int(report.vented) - int(report.kill_cooled) - int(report.get("chain_cooled", 0)), report.vented, report.kill_cooled, int(report.get("chain_cooled", 0)), report.heat_used_shots, report.overheats, report.forced_reloads]

# Compare with/without this part, including existing capacity/reload modifiers.
# Already equipped parts show their contribution rather than adding them twice.
static func _part_states(id: String, state: Dictionary) -> Array:
	var before := state.duplicate(false)
	before.part = "none"
	before.equipped_parts = Content.equipped_parts(state)
	before.equipped_parts.erase(id)
	var after := before.duplicate(false)
	after.equipped_parts = before.equipped_parts.duplicate()
	if Content.is_core_part(id):
		after.equipped_parts = after.equipped_parts.filter(func(p): return not Content.is_core_part(str(p)))
	after.equipped_parts.append(id)
	return [before, after]

static func threat_data(enemies: Array) -> Dictionary:
	var data := {"count": enemies.size(), "max_armor": 0, "max_speed": 0, "contact_turns": _contact_turns(enemies), "barrier": 0, "charge": false, "stance": false}
	for enemy_value in enemies:
		var enemy: Dictionary = enemy_value
		data.max_armor = maxi(int(data.max_armor), int(enemy.get("def", 0)))
		var speed := maxi(1, int(enemy.get("speed", 1)))
		data.max_speed = maxi(int(data.max_speed), speed)
		data.barrier += int(enemy.get("barrier", 0))
		data.charge = bool(data.charge) or int(enemy.get("charge_max", 0)) > 0
		data.stance = bool(data.stance) or bool(enemy.get("stance", false))
	return data

static func _contact_turns(enemies: Array) -> int:
	if enemies.is_empty(): return 0
	var rows: Array = enemies.duplicate(true)
	for turn in range(1, 100):
		for source_index in range(rows.size()):
			var source: Dictionary = rows[source_index]
			if int(source.get("hp", 0)) <= 0 or int(source.get("charge_max", 0)) <= 0 or int(source.get("jammed", 0)) > 0: continue
			source.charge = int(source.get("charge", 0)) + 1
			if int(source.charge) >= int(source.charge_max):
				source.charge = 0
				for target_index in range(rows.size()):
					if target_index == source_index or int(rows[target_index].get("hp", 0)) <= 0: continue
					rows[target_index].distance = maxi(0, int(rows[target_index].distance) - int(source.get("charge_pull", 2)))
					if int(rows[target_index].distance) == 0: return turn
		for enemy in rows:
			if int(enemy.get("hp", 0)) <= 0: continue
			enemy.distance = maxi(0, int(enemy.distance) - int(enemy.speed))
			if int(enemy.distance) == 0: return turn
			if int(enemy.get("jammed", 0)) > 0: enemy.jammed = int(enemy.jammed) - 1
	return 99

static func threat_line(enemies: Array) -> String:
	var data := threat_data(enemies)
	var locks: PackedStringArray = []
	if int(data.barrier) > 0: locks.append("◆%d" % int(data.barrier))
	if bool(data.charge): locks.append("충전")
	if bool(data.stance): locks.append("교대 장갑")
	return "위협 · %d개체 · 장갑 최대 %d · 접촉 최소 %d턴%s" % [data.count, data.max_armor, data.contact_turns, " · " + "/".join(locks) if not locks.is_empty() else ""]

static func reward_impact(id: String, state: Dictionary, next_enemies: Array) -> String:
	var threat := threat_data(next_enemies)
	if Content.AMMO.has(id):
		match id if id == "charge_hot" else Content.source_id(id):
			"prepare": return "뒤 %d발을 다음 패로 · 탄창 %d칸에서 준비할 자리 확보" % [Content.effect_value(id, state), Content.capacity(state)]
			"disrupt": return "특수 행동 %d턴 정지 · 적마다 한 번" % Content.effect_value(id, state)
			"spread": return "소이 뒤에서 화상을 옆 적으로 이동 · 지속 피해 빌드"
			"sequence": return "앞선 다른 탄종×%d · 긴 탄창과 저발열 조합" % Content.effect_value(id, state)
			"shatter": return "장갑 −%d · 연타 앞에 배치" % Content.effect_value(id, state)
			"detonate": return "남은 화상 ×%d 기폭 · 화상 소모" % int(Content.AMMO[id].get("detonate_scale", 1))
			"chase": return "처치 다음에 배치 · 피해 +%d" % Content.effect_value(id, state)
			"bypass": return "앞 적을 건너뛰어 원거리 본체를 먼저 공격"
			"vent": return "마지막 발 · 열 최대 %d → 피해 +%d" % [int(Content.AMMO[id].heat_spend), int(Content.AMMO[id].heat_spend) * Content.effect_value(id, state)]
			"thermal": return "발사 전 열 %d↑ → 피해 +%d" % [Content.hot_threshold(state), Content.effect_value(id, state)]
			"cool": return ("첫 발 고정 · 열 −%d" if Content.anchor(id) == "first" else "과열 전에 배치 · 열 −%d") % Content.effect_value(id, state)
			"charge_hot": return "다음 공격 %s · 강화 공격 열 +3" % Content.boost_label(id, state)
			"charge_heat": return "공격 직전 열 %d↑ → +%d · 냉각과 경쟁" % [Content.hot_threshold(state), Content.effect_value(id,state)]
			"bore":
				return "화상 %d피해 × %d턴 · 덱 %d장" % [Content.burn_damage(state), Content.burn_amount(id, state), state.get("deck", []).count(id) + 1]
			"pierce":
				return "관통 %d" % Content.penetration(id, state) + (" · 다음 장갑 최대 %d" % int(threat.max_armor) if not next_enemies.is_empty() else " · 장갑이 두꺼운 적에게")
			"push":
				return "주 표적 +%dm · 탄창당 총 %dm" % [Content.effect_value(id, state), Content.push_budget(state)]
			"charge":
				return "%s 공격 %d발 +%d" % ["다음 탄창" if Content.is_compressed(id) else "다음", Content.boost_rounds(id), Content.effect_value(id,state)]
			"precise":
				var hits := Content.hit_count(id, state)
				return "%d타격 · 증폭 시 추가 피해 +%d" % [hits, Content.effect_value("charge", state) * hits] if state.get("deck", []).has("charge") else "같은 적을 %d회 타격" % hits
			"arc":
				return "전이 피해 %d · 다른 생존 적이 필요" % Content.effect_value(id, state)
	elif Content.PARTS.has(id):
		var states := _part_states(id, state)
		var before: Dictionary = states[0]
		var after: Dictionary = states[1]
		match id:
			"ordinary_chain": return "마지막 공격 · 앞선 다른 탄종당 +2 · 최대 +6"
			"compression_sink": return "일반 → 압축 발열 −2 · 열 한계 %d→%d" % [Content.heat_limit(before), Content.heat_limit(after)]
			"cooling_breech": return "탄창 %d→%d · 재장전 냉각 %d→%d" % [Content.capacity(before), Content.capacity(after), Content.reload_cooling(before), Content.reload_cooling(after)]
			"chain_sink": return "세 번째 발 냉각 −3 · 열 한계 %d→%d" % [Content.heat_limit(before), Content.heat_limit(after)]
			"indexer": return "예약탄 뒤 %d→%d장 예약 · 뒤에 탄창 공간 필요" % [Content.effect_value("prepare", before), Content.effect_value("prepare", after)]
			"radiator":
				return "열 한계 %d→%d · 고열 조건 %d→%d" % [Content.heat_limit(before), Content.heat_limit(after), Content.hot_threshold(before), Content.hot_threshold(after)]
			"reclaimer":
				return "적을 처치한 탄 열 −2 · 과열 판정 전에 냉각"
			"ember_core":
				return "열 %d부터 타격당 +2 · 열 한계 %d→%d" % [Content.hot_threshold(after), Content.heat_limit(before), Content.heat_limit(after)]
			"lens":
				return "관통 있는 탄만 관통 +2" + (" · 다음 장갑 최대 %d" % int(threat.max_armor) if not next_enemies.is_empty() else "")
			"loader":
				var base := int(Content.GUNS[state.get("gun", "single")].reload)
				return "기본 재장전 %d→%d턴 · 과열 시 추가 1턴" % [maxi(1, base + Content.reload_modifier(before)), maxi(1, base + Content.reload_modifier(after))]
			"supply":
				return "탄창 %d→%d칸 · 순서 1발 확장" % [Content.capacity(before), Content.capacity(after)]
			"coil":
				return "소이탄 화상 %d→%d턴 · 턴당 %d피해" % [Content.burn_amount("bore", before), Content.burn_amount("bore", after), Content.burn_damage(after)]
			"capacitor":
				return "전격탄 전이 피해 +1 · 현재 %d장" % family_count(state, "arc")
			"rammer":
				return "충격탄 밀치기·한도 +1m · 현재 %d장" % family_count(state, "push")
			"sequencer":
				return "증폭탄 강화량 +1 · 발수 유지 · 현재 %d장" % family_count(state, "charge")
			"duplex":
				return "연타탄 타격 +1 · 현재 %d장" % family_count(state, "precise")
			"igniter":
				return "화상 중인 적 직접 피해 +2 · 소이 %d장" % family_count(state, "bore")
			"breaker":
				return "타격마다 배리어 1칸 추가 파쇄 · 연타 %d장" % family_count(state, "precise")
			"executioner":
				return "HP 5 이하 적 직접 피해 +2"
			"reserve":
				return "패 교환 +1회 · 조합 탐색" if Content.uses_ammo_cards(state) else "탄창마다 패 교환 +1회 · 기본탄 보급 +2"
			"opening":
				return "탄창 첫 발 직접 피해 +2"
			"afterburner":
				return "마지막 발 피해 +3 · 재장전 +1턴"
			"field_press":
				return "교전마다 현장 압축 +1회 · 탄창 −2칸"
			"overbore":
				return "2칸 공격탄 피해 +3·관통 +2 · 탄창 −1칸"
			"inferno":
				return "소이 화상 +2 · 재장전 +1턴"
			"arc_splitter":
				return "전이 피해 +2·대상 +1 · 직접 피해 −1"
			"momentum":
				return "밀치기·한도 +2m · 직접 피해 −1"
			"triad":
				return "서로 다른 3번째 탄 피해 +5 · 기본탄 피해 −1"
	return "현재 구성에 적용"

static func family_count(state: Dictionary, source: String) -> int:
	return state.get("deck", []).filter(func(id): return Content.source_id(str(id)) == source).size()

static func deck_summary(deck: Array) -> String:
	var seen: Array = []
	var items: PackedStringArray = []
	for id_value in deck:
		var id := str(id_value)
		if not Content.AMMO.has(id): continue
		var key := _summary_key(id)
		if seen.has(key): continue
		seen.append(key)
		var count := deck.filter(func(round_id): return _summary_key(str(round_id)) == key).size()
		items.append("%s%s ×%d" % [Content.AMMO[id].name, " ◆" if Content.is_compressed(id) else "", count])
	return " · ".join(items) if not items.is_empty() else "없음"

static func _summary_key(id: String) -> String:
	return Content.source_id(id) + ("_c" if Content.is_compressed(id) else "") if Content.AMMO.get(id,{}).get("profile",false) else id

static func loss_advice(state: Dictionary) -> String:
	var last: Dictionary = {}
	var history: Array = state.get("history", [])
	for index in range(history.size() - 1, -1, -1):
		var event: Dictionary = history[index]
		if str(event.get("action", "")) in ["fire", "reload"]:
			last = event
			break
	var detail: Dictionary = last.get("detail", {})
	var forced: Dictionary = detail.get("forced_reload", {})
	var on_forced_reload := str(forced.get("phase", "")) == "lost"
	var context := "과열 후 강제 재장전 중 " if on_forced_reload else ("재장전 중 " if str(last.get("action", "")) == "reload" else "")
	if str(state.get("loss_reason", "")) == "projectile":
		return context + "압력탄이 도달했습니다. " + ("과열 전에 냉각탄이 발사되도록 배치해 요격할 시간을 남기세요." if on_forced_reload else "비행 중인 압력탄을 먼저 요격하세요. 발사체는 원거리 적을 처치해도 남습니다.")
	var alive: Array = []
	for enemy_value in state.get("enemies", []):
		var enemy: Dictionary = enemy_value
		if int(enemy.get("hp", 0)) > 0: alive.append(enemy)
	if alive.is_empty(): return "마지막 행동의 탄환 순서와 발사 예상을 다시 확인하세요."
	alive.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.distance) < int(b.distance))
	var threat: Dictionary = alive[0]
	if int(threat.distance) != 0: return "마지막 행동의 탄환 순서와 발사 예상을 다시 확인하세요."
	var reasons: PackedStringArray = [context + "%s가 도달했습니다." % threat.name]
	if on_forced_reload:
		reasons.append("냉각탄을 과열 전에 배치하거나 이번 탄창을 짧게 구성하세요. 강제 재장전은 기본 %d턴 + 냉각 1턴입니다." % (int(forced.get("cost", 1)) - int(forced.get("heat_paid", 0))))
		return " ".join(reasons)
	if int(threat.get("barrier", 0)) > 0:
		reasons.append("연타탄처럼 타격 수가 많은 탄으로 배리어를 먼저 제거하세요.")
	elif bool(threat.get("stance", false)) and int(threat.get("def", 0)) > 0:
		reasons.append("장갑 0 태세가 되는 다음 턴에 강한 탄을 배치하세요.")
	elif int(threat.get("def", 0)) >= 2:
		reasons.append("철갑탄을 앞쪽에 두거나 관통 파츠를 준비하세요.")
	elif int(threat.get("charge_max", 0)) > 0:
		reasons.append("충전 완료 전에 부유체를 처치할 짧은 순서를 만드세요.")
	elif int(state.get("reloads", 0)) >= 2:
		reasons.append("재장전 전에 처치하거나 충격탄으로 재장전 시간을 확보하세요.")
	else:
		reasons.append("충격탄으로 거리를 벌리거나 소이탄을 일찍 넣어 전진 전에 피해를 누적하세요.")
	return " ".join(reasons)
