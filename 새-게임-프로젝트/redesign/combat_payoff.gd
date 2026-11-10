extends RefCounted
## Read only resolved impacts. Never award a kill for a projectile or repeated entry.
const Content = preload("res://redesign/content.gd")
const ImpactStyle=preload("res://redesign/impact_style.gd")
const COLORS := {"volley":Color("9bcbd0"),"siege":Color("edc47a"),"thermal":Color("ed9167"),"boost":Color("b8d7b2"),"armor":Color("ced4c8"),"plain":Color("c3c8bd")}

# A signature names an observed effect, never a simulated 'damage without this part'.
static func signature(shot: Dictionary) -> Dictionary:
	var ids: Array = []
	for effect in shot.get("part_effects",[]):
		if Content.PARTS.has(str(effect.id)) and not ids.has(str(effect.id)): ids.append(str(effect.id))
	var kind := "plain"
	var title := ""
	var rank := 0
	var direct_hits := int(shot.get("hits",0))
	for impact in shot.get("secondary",[]):
		if str(impact.get("kind",""))=="relay": direct_hits+=1
	if ids.has("afterburner"):
		kind="siege";title="후미 점화 ×%d" % int(shot.part_factor) if int(shot.get("part_factor",1))>1 else "후미 점화 +3";rank=8
	elif ids.has("duplex"):
		kind="volley";title="복열 · %d회 타격" % direct_hits;rank=7
	elif ids.has("thermal_drive"):
		kind="thermal";title="열압 ×%.2f" % (int(shot.get("engine_percent",100))/100.0);rank=6
	elif ids.has("siege_drive"):
		kind="siege";title="돌파 ×%.2f" % (int(shot.get("engine_percent",100))/100.0);rank=6
	elif ids.has("volley_drive"):
		kind="volley" if direct_hits>1 else "boost";title="연쇄 구동";rank=5
	elif ids.has("breaker") or ids.has("lens") or int(shot.get("armor_removed",0))>0:
		kind="armor";title="장갑 파쇄" if int(shot.get("armor_removed",0))>0 else "보호 파쇄" if ids.has("breaker") else "관통 강화";rank=4
	elif ids.has("sequencer"):
		kind="boost";title="증폭 시퀀서";rank=3
	elif not ids.is_empty():
		kind="boost";title=str(Content.PARTS[ids[0]].name);rank=2
	elif int(describe(shot).damage)>0 and (int(shot.get("math",{}).get("boost",0))>0 or int(shot.get("math",{}).get("factor",1))>1):
		kind="boost";title="강화탄 적중";rank=1
	var style:=ImpactStyle.resolve(shot)
	var color:Color=style.color if style.active and style.family!="plain" else COLORS[kind]
	return {"kind":kind,"title":title,"rank":rank,"color":color,"parts":ids}

static func receipt(results: Array) -> Dictionary:
	if results.is_empty(): return {}
	var damage := 0
	var killed: Array = []
	var parts: Array = []
	var best := signature({})
	for shot in results:
		var payoff := describe(shot)
		damage += int(payoff.damage)
		for target in payoff.targets:
			if not killed.has(target): killed.append(target)
		var observed := signature(shot)
		if int(observed.rank)>int(best.rank): best=observed
		for id in observed.parts:
			if not parts.has(id): parts.append(id)
	var names: PackedStringArray = []
	for id in parts: names.append(str(Content.PARTS[id].name))
	var summary := "%d피해 · %d기 처치" % [damage,killed.size()]
	var detail := summary
	if damage == 0 and killed.is_empty():
		var readout := preload("res://redesign/damage_readout.gd").entry(results.back())
		detail = str(readout.number) + " · " + str(readout.label)
	return {"damage":damage,"kills":killed.size(),"shots":results.size(),"signature":best,"parts":parts,"names":" · ".join(names),"summary":summary,"detail":detail}

static func last_receipt(state: Dictionary) -> Dictionary:
	# Only traverse this action's tail. Never copy the growing run history.
	var history: Array = state.get("history",[])
	for i in range(history.size()-1,-1,-1):
		var event: Dictionary = history[i]
		if str(event.get("action","")) in ["encounter","reload","emergency_resupply"]: return {}
		if str(event.get("action",""))=="fire": return receipt(event.get("detail",{}).get("results",[]))
	return {}

static func describe(shot: Dictionary) -> Dictionary:
	var damage := 0
	var killed: Array = []
	var impacts: Array = [shot]+shot.get("secondary",[])
	for impact in impacts:
		damage += int(impact.get("damage",0))
		var target := int(impact.get("target",-1))
		if target>=0 and target<10000 and int(impact.get("damage",0))>0 and int(impact.get("hp",1))<=0 and not killed.has(target): killed.append(target)
	var tier := 2 if killed.size()>=2 else 1 if damage>=20 else 0
	return {"damage":damage,"kills":killed.size(),"targets":killed,"tier":tier}
