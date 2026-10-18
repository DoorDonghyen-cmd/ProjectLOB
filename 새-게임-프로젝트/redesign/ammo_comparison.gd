extends RefCounted
## Compare the actual equipped-weapon values, without equating support with damage.
const Ammo = preload("res://redesign/content.gd")

static func power(id: String, state: Dictionary) -> String:
	var stat: Dictionary = Ammo.primary_stat(id,state)
	return str(stat.label)+" "+str(stat.value)

static func changes(before: String, after: String, state: Dictionary) -> String:
	var a: Dictionary = Ammo.primary_stat(before,state)
	var b: Dictionary = Ammo.primary_stat(after,state)
	var result := "%s %s → %s"%[a.label,a.value,b.value] if a.label==b.label else power(before,state)+" → "+power(after,state)
	if Ammo.penetration(before,state)!=Ammo.penetration(after,state):
		result+=" · 관통 %d → %d"%[Ammo.penetration(before,state),Ammo.penetration(after,state)]
	return result

static func costs(before: String, after: String, state: Dictionary) -> String:
	var result:="발열 %s → %s"%[Ammo.heat_label(before,state),Ammo.heat_label(after,state)]
	result+=" · 탄창 %d → %d칸"%[Ammo.slot_cost(before),Ammo.slot_cost(after)]
	var anchor:=Ammo.anchor(after)
	if anchor=="first": result+=" · 첫 발 고정"
	elif anchor=="last": result+=" · 마지막 발 고정"
	return result
