extends RefCounted
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
	if result.get("boost_replaced",false): label += " · 교체"
	var kill: bool = amount > 0 and int(result.get("hp",1)) <= 0 and not result.get("intercept",false) and int(result.get("target",-1))>=0 and int(result.get("target",-1))<10000
	if kill: label = (label + " · " if not label.is_empty() else "") + "처치"
	# Importance is visual only: never call this a random critical-hit mechanic.
	var emphasis := 3 if kill else 2 if amount>=12 else 1 if strong else 0
	if kill: color=Color("ffe1a4")
	elif emphasis==2: color=Color("f2c278")
	return {"target":int(result.get("target",-1)),"amount":amount,"number":number,"label":label,"color":color,"strong":strong,"kill":kill,"kind":kind,"emphasis":emphasis}
