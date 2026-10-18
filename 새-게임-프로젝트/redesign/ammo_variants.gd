extends RefCounted
## Immutable per-card profiles. Replacing one deck entry upgrades one copy only.
const FAMILIES := ["basic", "pierce", "precise"]
const HEAT := [1, 2, 3, 5, 7]
const TUNES := ["", "power", "cool"]

static func key(family: String, power: int, tune: String = "") -> String:
	return "%s_p%d%s" % [family, power, "_" + tune if not tune.is_empty() else ""]

static func build(base: Dictionary) -> Dictionary:
	var result: Dictionary = base.duplicate(true)
	for family in FAMILIES:
		for power in range(1, 6):
			for tune in TUNES:
				var id := key(family, power, tune)
				var heat := int(HEAT[power - 1]) + (1 if family == "pierce" else 2 if family == "precise" else 0)
				var spec: Dictionary = base[family].duplicate(true)
				spec.merge({"source":family,"power":power,"tune":tune,"profile":true},true)
				spec.dmg = power + (1 if tune == "power" else 0)
				spec.heat = maxi(1,heat - (1 if tune == "cool" else 0))
				if family == "basic": spec.text = "물리 탄환. 위력이 높을수록 발열이 커집니다. 사용 후 버린 더미로 이동합니다."
				result[id] = spec
				var compressed: Dictionary = base.get(family + "_c",spec).duplicate(true)
				compressed.merge({"source":family,"power":power,"tune":tune,"profile":true,"compressed":true,"compression_source":id},true)
				compressed.dmg = (power + 1 if family == "precise" else power * 2 + 1) + (1 if tune == "power" else 0)
				compressed.heat = maxi(1,(heat + 2 if family == "precise" else heat * 2 - 1) - (1 if tune == "cool" else 0))
				if family == "basic":
					compressed.slot_cost=2
					compressed.text="탄창 2칸에 두 기본탄의 화력을 한 발로 집약합니다."
				result[id + "_c"] = compressed
				var temporary := compressed.duplicate(true)
				temporary.temporary=true
				result[id + "_f"] = temporary
	return result

static func compressions(base: Dictionary, temporary: bool = false) -> Dictionary:
	var result: Dictionary = base.duplicate()
	for family in FAMILIES:
		for power in range(1,6):
			for tune in TUNES:
				var id := key(family,power,tune)
				result[id] = id + ("_f" if temporary else "_c")
	return result

static func tuned(id: String, specs: Dictionary, tune: String) -> String:
	var spec: Dictionary = specs.get(id,{})
	if tune not in ["power","cool"] or not spec.get("profile",false) or spec.get("temporary",false) or not str(spec.get("tune","")).is_empty(): return ""
	if tune=="cool" and int(spec.heat)<=1: return ""
	return key(str(spec.source),int(spec.power),tune) + ("_c" if spec.get("compressed",false) else "")

static func start_deck(deck: Array) -> Array:
	var result: Array=[]
	var counts: Dictionary={}
	for id in deck:
		if not FAMILIES.has(id): result.append(id);continue
		var occurrence:=int(counts.get(id,0))
		counts[id]=occurrence+1
		# Repeated profiles still allow compression; the third basic is a light alternative.
		result.append(key(id,1 if id=="basic" and occurrence>=2 else 2))
	return result

static func offer(id: String, specs: Dictionary, random: RandomNumberGenerator, node: Dictionary) -> String:
	var spec: Dictionary=specs[id]
	var family:=str(spec.get("source",id))
	if not FAMILIES.has(family): return id
	var maximum:=3 if int(node.get("region",0))==0 and int(node.get("floor",1))<5 else 5
	return key(family,random.randi_range(1,maximum)) + ("_c" if spec.get("compressed",false) else "")
