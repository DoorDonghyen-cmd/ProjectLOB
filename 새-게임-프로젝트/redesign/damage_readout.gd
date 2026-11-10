extends RefCounted
const ImpactStyle=preload("res://redesign/impact_style.gd")
## Presentation vocabulary from resolved combat events; never invent individual hits.
static func entry(result: Dictionary, kind: String = "shot") -> Dictionary:
	var amount := int(result.get("damage",0))
	var boost := int(result.get("math",{}).get("boost",0)) + int(result.get("thermal_bonus",0)) + int(result.get("vent_bonus",0))
	var factor := int(result.get("math", {}).get("factor", 1))
	var label := ""
	var number := str(amount)
	var color := Color("e6e8d4")
	var strong := amount > 0 and (boost > 0 or factor > 1 or int(result.get("detonation",0)) > 0 or int(result.get("focus_damage",0)) > 0 or int(result.get("chase_bonus",0)) > 0)
	if kind in ["relay","overflow"]: label = "연쇄" if kind=="relay" else "돌파"; strong = amount>0
	elif kind == "followup": label = "후속 피해"; strong = amount>0
	elif kind == "heat_wave": label = "열압"; strong = amount>0
	elif int(result.get("overdrive_percent",100))>100: label = "강행 ×%.2f" % (int(result.overdrive_percent)/100.0); strong = amount>0
	elif int(result.get("part_factor",1))>1: label = str(result.get("position_label", "후미 결산 ×%d" % int(result.part_factor))); strong = amount>0
	elif int(result.get("engine_percent",100))>100: label = "화력 ×%.2f" % (int(result.engine_percent)/100.0); strong = amount>0
	elif kind == "burn": label = "화상"; color = Color("e99b73")
	elif kind == "arc": label = "전이"; color = Color("9acbd0")
	elif kind == "spread": label = "확산"; color = Color("9acbd0")
	elif kind == "burn_transfer": label = "화상 이동"; color = Color("e99b73")
	elif int(result.get("detonation",0)) > 0: label = "기폭"
	elif int(result.get("focus_damage",0)) > 0: label = "집중"
	elif factor > 1: label = "강화 ×%d" % factor
	elif boost > 0: label = "증폭 +%d" % boost
	elif int(result.get("chase_bonus",0)) > 0: label = "추격"
	if kind == "shot" and int(result.get("hits",1)) > 1:
		label = (label + " · " if not label.is_empty() else "") + "%d연타" % int(result.hits)
	if result.get("boost_hot_failed",false): label = (label + " · " if not label.is_empty() else "") + "잔열 부족"
	if strong: color = Color("edc47a")
	if result.get("intercept",false): number = "요격"; label = ""
	elif amount <= 0:
		if int(result.get("blocked_hits",0)) > 0: number = "막힘"
		elif int(result.get("boost_factor_granted",1)) > 1: number = "×%d" % int(result.boost_factor_granted); label = "공격 열 +%d" % int(result.get("boost_heat",0)) if int(result.get("boost_heat",0)) > 0 else "다음 공격 강화"
		elif int(result.get("armor_removed",0)) > 0: number = "파쇄"; label = "장갑 −%d" % int(result.armor_removed)
		elif int(result.get("interrupted",0)) > 0: number = "차단"; label = "%d턴" % int(result.interrupted)
		elif int(result.get("transferred",0)) > 0: number = "이동"; label = "화상 %d" % int(result.transferred)
		elif result.get("boost_hot",false): number = "잔열"; label = "고열 공격 +%d" % int(result.get("boost_granted",0))
		elif int(result.get("boost_granted",0)) > 0: number = "증폭"; label = "공격 %d발 +%d" % [int(result.get("boost_rounds", 2)), int(result.boost_granted)]
		elif not result.get("prepared_rounds",[]).is_empty(): number = "예약"; label = "다음 패 %d장" % result.prepared_rounds.size()
		elif int(result.get("cooled",0)) > 0: number = "냉각"; label = "열 −%d" % int(result.cooled)
		elif str(result.get("id", "")) in preload("res://redesign/content.gd").AMMO and not preload("res://redesign/content.gd").is_attack(str(result.id)):
			number = "지원"; label = "효과 없음"
		else: number = "방어" if int(result.get("math",{}).get("armor",0)) > 0 else ("이동" if kind == "burn_transfer" else "0")
		color = Color("a7bbc4")
	if int(result.get("slowed",0))>0:number="경직";label="접근 감속 · %d행동"%int(result.slowed)
	if result.get("ground",false):label="불길";color=Color("e99b73")
	if result.get("boost_replaced",false): label += " · 교체"
	if kind == "shot" and int(result.get("burn_added",0)) > 0:
		if amount <= 0: number = "화상"
		label = "화상 %d/턴 · %d턴" % [int(result.get("burn_tick",0)), int(result.get("burn",0))]
		color = Color("e99b73")
	if result.has("exposure_left") and int(result.get("blocked_hits",0))>0:
		var opened := int(result.get("barrier",0))==0
		if amount<=0 and int(result.get("burn_added",0))==0:
			number="파손" if opened else "차폐"
			label="본체 노출" if opened else "−%d회 · %d 남음"%[int(result.get("barrier_removed",1)),int(result.barrier)]
			color=Color("dfc993") if opened else Color("a6c3c2")
		elif opened: label=(label+" · " if not label.is_empty() else "")+"차폐 파손"
	var kill: bool = amount > 0 and int(result.get("hp",1)) <= 0 and not result.get("intercept",false) and int(result.get("target",-1))>=0 and int(result.get("target",-1))<10000
	if kill: label = (label + " · " if not label.is_empty() else "") + "처치"
	# Importance is visual only: never call this a random critical-hit mechanic.
	var emphasis := 3 if kill else 2 if amount>=12 else 1 if strong else 0
	var label_color:=color
	var style:=ImpactStyle.resolve(result,kind)
	if style.active:
		color=style.color
		if int(result.get("burn_added",0))<=0 and not result.get("ground",false):label_color=color
	# Kill/large-damage importance changes size/marks, retaining effect hue.
	return {"target":int(result.get("target",-1)),"amount":amount,"number":number,"label":label,"color":color,"label_color":label_color,"style":style,"strong":strong,"kill":kill,"kind":kind,"emphasis":emphasis,"ledger":ledger_text(result) if kind == "shot" and amount > 0 else ""}

## Calculation line (2026-11-08): per-hit base + additions, then each multiplier, e.g.
## "2+7 ×3 · 공명×1~3". Empty for a plain shot with nothing added or multiplied.
## Built from the shot's existing math record, so nothing new is stored in saves.
static func ledger_text(result: Dictionary) -> String:
	var math: Dictionary = result.get("math", {})
	if not math.has("subtotal") or int(math.get("raw", 0)) <= 0: return ""
	var base := int(math.get("base", 0))
	var add := int(math.subtotal) - base
	var mults: Array = []
	for key in ["factor", "part_factor", "weapon_factor"]:
		if int(math.get(key, 1)) > 1: mults.append(float(math[key]))
	for key in ["engine_percent", "gate_percent", "overdrive_percent"]:
		var percent := int(math.get(key, 100))
		if percent != 100: mults.append(percent / 100.0)
	var resonant := false
	for effect in result.get("part_effects", []):
		if str(effect.get("id", "")) == "resonator": resonant = true
	if add == 0 and mults.is_empty() and not resonant: return ""
	var text := str(base)
	if add != 0: text += ("+%d" if add > 0 else "%d") % add
	for value in mults:
		var factor := ("%.2f" % float(value)).rstrip("0").rstrip(".")
		text += " ×" + factor
	var hits := maxi(1, int(result.get("hits", 1)))
	if resonant: text += " 공명×1~%d" % hits
	elif hits > 1: text += " ×%d타" % hits
	# The full calculated total (before armor), so overkill is visible too.
	var total := int(math.raw) * (hits * (hits + 1) / 2 if resonant else hits)
	if total > 0: text += " = %d" % total
	return text
