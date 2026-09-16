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
				if int(shot.get("hp", 1)) <= 0:
					report.kills += 1
				for secondary_value in shot.get("secondary", []):
					var secondary: Dictionary = secondary_value
					if str(secondary.get("kind", "arc")) == "spread": report.spread += int(secondary.get("damage", 0))
					else: report.arc += int(secondary.get("damage", 0))
					if int(secondary.get("hp", 1)) <= 0:
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
	var data := {"count": enemies.size(), "max_armor": 0, "max_speed": 0, "contact_turns": 0}
	for enemy_value in enemies:
		var enemy: Dictionary = enemy_value
		data.max_armor = maxi(int(data.max_armor), int(enemy.get("def", 0)))
		var speed := maxi(1, int(enemy.get("speed", 1)))
		data.max_speed = maxi(int(data.max_speed), speed)
		var contact := ceili(float(int(enemy.get("distance", 0))) / float(speed))
		if int(data.contact_turns) == 0 or contact < int(data.contact_turns):
			data.contact_turns = contact
	return data

static func threat_line(enemies: Array) -> String:
	var data := threat_data(enemies)
	return "위협 · %d개체 · 장갑 최대 %d · 접촉 최소 %d턴" % [data.count, data.max_armor, data.contact_turns]

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
				return "2타격 · 증폭 시 추가 피해 +%d" % (Content.effect_value("charge", state) * 2) if state.get("deck", []).has("charge") else "같은 적을 2회 타격"
			"arc":
				return "전이 피해 %d · 다른 생존 적이 필요" % Content.effect_value(id, state)
	elif Content.PARTS.has(id):
		match id:
			"lens":
				return "모든 탄 관통 +1 · 다음 장갑 최대 %d" % int(threat.max_armor)
			"loader":
				var before := int(Content.GUNS[state.get("gun", "single")].reload)
				return "재장전 %d→%d턴" % [before, maxi(1, before - 1)]
			"supply":
				var before := int(Content.GUNS[state.get("gun", "single")].capacity)
				return "탄창 %d→%d칸 · 순서 1발 확장" % [before, before + 1]
			"coil":
				return "소이탄 화상 3→4 · 현재 %d장" % state.get("deck", []).count("bore")
	return "현재 구성에 적용"

static func deck_summary(deck: Array) -> String:
	var seen: Array = []
	var items: PackedStringArray = []
	for id_value in deck:
		var id := str(id_value)
		if seen.has(id) or not Content.AMMO.has(id):
			continue
		seen.append(id)
		items.append("%s ×%d" % [Content.AMMO[id].name, deck.count(id)])
	return " · ".join(items) if not items.is_empty() else "없음"
