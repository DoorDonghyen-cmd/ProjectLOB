extends RefCounted
## Discovery only: these labels never award damage or change the combat state.
const Content = preload("res://redesign/content.gd")
const Model = preload("res://redesign/model.gd")
const Forecast = preload("res://redesign/forecast.gd")

static func relation(first: String, second: String, state: Dictionary = {}) -> Dictionary:
	var a: Dictionary = Content.AMMO[first]
	var b: Dictionary = Content.AMMO[second]
	if a.effect == "boost" and Content.is_attack(second) and (b.effect == "double" or Content.penetration(second,state) >= 2 or b.effect in ["chase","thermal","vent","sequence"]):
		return {"kind":"boost", "label":"여러 타격 강화" if b.effect == "double" else ("강화 피해 관통" if int(b.pen) > 0 else "후속 피해 강화")}
	if a.effect == "shatter" and Content.is_attack(second): return {"kind":"armor", "label":"장갑 개방"}
	if a.effect == "burn":
		match str(b.effect):
			"detonate": return {"kind":"detonate", "label":"화상 즉시 결산"}
			"spread": return {"kind":"spread", "label":"화상 나눠 붙이기"}
			"push": return {"kind":"burn_time", "label":"화상 시간 확보"}
			"disrupt": return {"kind":"burn_delay", "label":"발사 늦추며 화상"}
	if Content.is_attack(first) and b.effect == "chase": return {"kind":"kill", "label":"처치 후 후속 강화"}
	if a.effect == "prepare" and not Content.is_temporary(second): return {"kind":"prepare", "label":"다음 패로 예약"}
	if a.effect == "cool" and Content.heat_cost(second) >= 2: return {"kind":"cool", "label":"후속 발열 여유"}
	if Content.heat_cost(first) > 0:
		if b.effect == "thermal": return {"kind":"hot", "label":"잔열로 피해 강화"}
		if b.effect == "vent": return {"kind":"vent", "label":"잔열을 피해로 전환"}
	if b.effect == "sequence" and Content.source_id(first) != Content.source_id(second): return {"kind":"sequence", "label":"다른 탄종 결산"}
	return {}

static func witnessed(link: Dictionary, before: Dictionary, after: Dictionary) -> bool:
	var same := int(before.target) == int(after.target)
	match str(link.kind):
		"boost":
			if int(after.damage) <= 0 or (before.get("boost_hot",false) and after.get("boost_hot_failed",false)): return false
			return int(after.math.get("boost",0)) > 0 or int(after.math.get("factor",1)) > 1
		"armor": return same and int(before.get("armor_removed",0)) > 0 and int(before.math.armor_before) > int(after.pen) and int(after.damage) > 0
		"detonate": return same and int(after.get("detonation",0)) > 0
		"spread": return same and int(after.get("transferred",0)) > 0
		"burn_time": return same and int(before.get("burn_added",0)) > 0 and int(after.get("push",0)) > 0 and int(after.hp) > 0
		"burn_delay": return same and int(before.get("burn_added",0)) > 0 and int(after.get("interrupted",0)) > 0
		"kill": return int(after.get("chase_bonus",0)) > 0
		"prepare": return before.get("prepared_rounds",[]).has(str(after.id))
		"cool": return int(before.get("cooled",0)) > 0 and not bool(after.get("overheated",false)) and not bool(after.get("boost_hot_failed",false)) and (str(Content.AMMO[str(after.id)].effect) != "thermal" or int(after.get("thermal_bonus",0)) > 0)
		"hot": return int(before.get("heat_added",0)) > 0 and int(after.get("thermal_bonus",0)) > 0
		"vent": return int(before.get("heat_added",0)) > 0 and int(after.get("vented",0)) > 0
		"sequence": return int(after.get("sequence_bonus",0)) > 0
	return false

static func evaluate(state: Dictionary, order: Array, index: int) -> Dictionary:
	if not Content.valid_stack(order,Content.capacity(state)): return {}
	var link := relation(str(order[index]),str(order[index+1]),state)
	if link.is_empty(): return {}
	if link.kind == "armor" and not state.enemies.any(func(e): return int(e.hp) > 0 and int(e.def) > 0): return {}
	if link.kind == "cool" and index == 0 and int(state.get("heat",0)) == 0: return {}
	var copy := state.duplicate(true)
	copy.plan = order.duplicate()
	copy.plan_load_order = Content.loading_order(order)
	# Scatter candidates are possibilities, not predictions from a secret RNG.
	# Its full exact forecast is already calculated asynchronously by the rail.
	var conditional: bool = state.gun == "scatter"
	if not conditional:
		var preview := Forecast.analyze(copy)
		if preview.shots.size() <= index+1: return {}
		if not witnessed(link,preview.shots[index],preview.shots[index+1]): return {}
		var next: Dictionary = preview.shots[index+1]
		link.damage = int(next.damage)
		if link.kind == "boost":
			link.label = "%d회 강화 적용" % int(next.hits) if int(next.hits) > 1 else ("강화 피해 관통" if int(next.pen) > 0 and int(next.math.armor_before) > 0 else "후속 피해 강화")
		link.warning = "과열 예상" if float(preview.heat.get("overheat_probability",0)) > 0 else ""
		if str(preview.phase) == "lost": link.warning = "사격 후 패배 위험"
		link.later_action = int(preview.shots[index].action) != int(preview.shots[index+1].action)
	link.conditional = conditional
	link.first = str(order[index])
	link.second = str(order[index+1])
	link.order = order.duplicate()
	return link

static func hand_hints(state: Dictionary) -> Dictionary:
	var hints := {}
	if state.get("phase", "") != "plan" or state.plan.is_empty(): return hints
	var model := Model.new()
	model.s = state
	for id_value in state.hand:
		var id := str(id_value)
		if hints.has(id) or not model.can_load(id): continue
		var order: Array = state.plan.duplicate()
		order.push_front(id)
		var link := evaluate(state,order,0)
		if not link.is_empty():
			link.move = false
			hints[id] = link
			continue
		order = state.plan.duplicate()
		order.append(id)
		link = evaluate(state,order,order.size()-2)
		if not link.is_empty():
			link.move = true
			hints[id] = link
	return hints

static func hand_pairs(state: Dictionary) -> Array:
	var result: Array = []
	if state.get("phase", "") != "plan": return result
	var model := Model.new()
	model.s = state
	var ids: Array = []
	for id in state.hand:
		if model.available(str(id)) > 0 and not ids.has(id): ids.append(id)
	for first in ids:
		for second in ids:
			if first == second: continue
			var link := evaluate(state,[first,second],0)
			if not link.is_empty(): result.append(link)
	return result

static func text(link: Dictionary) -> String:
	if link.is_empty(): return ""
	var result := "%s → %s · %s" % [Content.AMMO[link.first].name,Content.AMMO[link.second].name,link.label]
	if link.has("damage") and int(link.damage) > 0: result += " · 후속 %d피해" % int(link.damage)
	if link.get("conditional",false): result += " · 표적/발열 조건에 따라 달라짐"
	if link.get("later_action",false): result += " · 다음 사격까지 진행 필요"
	if not str(link.get("warning","")).is_empty(): result += " · " + str(link.warning)
	return result
