extends RefCounted
## Converts already-public combat state into compact debrief and reward guidance.
## It never predicts hidden rolls or mutates the run.
const Content = preload("res://redesign/content.gd")

static func combat_report(state: Dictionary, floor_filter: int = -1) -> Dictionary:
	var report := {"shots": 0, "direct": 0, "burn": 0, "arc": 0, "spread": 0, "focus": 0, "boost_hits": 0, "push": 0, "kills": 0}
	for entry_value in state.get("history", []):
		var entry: Dictionary = entry_value
		if floor_filter >= 0 and int(entry.get("floor", -1)) != floor_filter:
			continue
		var detail: Dictionary = entry.get("detail", {})
		if str(entry.get("action", "")) == "fire":
			for shot_value in detail.get("results", []):
				var shot: Dictionary = shot_value
				report.shots += 1
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
			if int(source.get("hp", 0)) <= 0 or int(source.get("charge_max", 0)) <= 0: continue
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
		match id:
			"bore":
				return "화상 %d피해 × %d턴 · 덱 %d장" % [Content.burn_damage(state), Content.burn_amount(id, state), state.get("deck", []).count(id) + 1]
			"pierce":
				return "관통 %d · 다음 장갑 최대 %d" % [Content.penetration(id, state), int(threat.max_armor)]
			"push":
				return "주 표적 +%dm · 탄창당 총 %dm" % [Content.effect_value(id, state), Content.push_budget(state)]
			"charge":
				return "뒤 2발의 타격당 피해 +%d" % Content.effect_value(id, state)
			"precise":
				var hits := Content.hit_count(id, state)
				return "%d타격 · 증폭 시 추가 피해 +%d" % [hits, Content.effect_value("charge", state) * hits] if state.get("deck", []).has("charge") else "같은 적을 %d회 타격" % hits
			"arc":
				return "전이 피해 %d · 다른 생존 적이 필요" % Content.effect_value(id, state)
	elif Content.PARTS.has(id):
		match id:
			"lens":
				return "모든 탄 관통 +2 · 다음 장갑 최대 %d" % int(threat.max_armor)
			"loader":
				var before := int(Content.GUNS[state.get("gun", "single")].reload)
				return "재장전 %d→%d턴" % [before, maxi(1, before - 1)]
			"supply":
				var before := int(Content.GUNS[state.get("gun", "single")].capacity)
				return "탄창 %d→%d칸 · 순서 1발 확장" % [before, before + 1]
			"coil":
				return "소이탄 화상 3→4 · 현재 %d장" % state.get("deck", []).count("bore")
			"capacitor":
				return "전격탄 전이 피해 +1 · 현재 %d장" % state.get("deck", []).count("arc")
			"rammer":
				return "충격탄 밀치기·한도 +1m · 현재 %d장" % state.get("deck", []).count("push")
			"sequencer":
				return "증폭탄 후속 피해 +1×2발 · 현재 %d장" % state.get("deck", []).count("charge")
			"duplex":
				return "연발탄 타격 +1 · 현재 %d장" % state.get("deck", []).count("precise")
			"igniter":
				return "화상 중인 적 직접 피해 +2 · 소이 %d장" % state.get("deck", []).count("bore")
			"breaker":
				return "타격마다 배리어 1칸 추가 파쇄 · 연발 %d장" % state.get("deck", []).count("precise")
			"executioner":
				return "HP 5 이하 적 직접 피해 +2"
			"reserve":
				return "탄창마다 패 교환 +1회 · 회수탄 보급 +2"
			"opening":
				return "탄창 첫 발 직접 피해 +2"
			"afterburner":
				return "마지막 발 피해 +3 · 재장전 +1턴"
			"field_press":
				return "교전마다 현장 압축 +1회 · 탄창 −2칸"
			"overbore":
				return "모든 피해·관통 +2 · 탄창 −1칸"
			"inferno":
				return "소이 화상 +2 · 재장전 +1턴"
			"arc_splitter":
				return "전이 피해 +2·대상 +1 · 직접 피해 −1"
			"momentum":
				return "밀치기·한도 +2m · 직접 피해 −1"
			"triad":
				return "서로 다른 3번째 탄 피해 +5 · 회수탄 피해 −1"
	return "현재 구성에 적용"

static func deck_summary(deck: Array) -> String:
	var seen: Array = []
	var items: PackedStringArray = []
	for id_value in deck:
		var id := str(id_value)
		if seen.has(id) or not Content.AMMO.has(id):
			continue
		seen.append(id)
		items.append("%s%s ×%d" % [Content.AMMO[id].name, " ◆" if Content.is_compressed(id) else "", deck.count(id)])
	return " · ".join(items) if not items.is_empty() else "없음"

static func loss_advice(state: Dictionary) -> String:
	var alive: Array = []
	for enemy_value in state.get("enemies", []):
		var enemy: Dictionary = enemy_value
		if int(enemy.get("hp", 0)) > 0: alive.append(enemy)
	if alive.is_empty(): return "마지막 행동의 탄환 순서와 발사 예상을 다시 확인하세요."
	alive.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.distance) < int(b.distance))
	var threat: Dictionary = alive[0]
	var reasons: PackedStringArray = ["%s가 %dm에서 접촉했습니다." % [threat.name, threat.distance]]
	if int(threat.get("barrier", 0)) > 0:
		reasons.append("연발탄처럼 타격 수가 많은 탄으로 배리어를 먼저 제거하세요.")
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
