extends RefCounted
## Run-scoped acquisition and positional payoffs. Old saves opt out.
const Content = preload("res://redesign/content.gd")
const VERSION := 1
const NEW_PART := "third_striker"
const SUPPORT := {
	"precise":["charge", "charge_hot", "shatter"],
	"pierce":["charge", "charge_hot", "cool"],
	"vent":["charge_heat", "charge", "cool"],
	"bore":["detonate", "push", "spread"],
	"arc":["charge", "chase", "cool"],
	"chase":["charge", "precise_p2", "cool"],
	"bypass":["charge", "charge_hot", "cool"]
}

const ROLE_SUPPORT:={"precise":["charge","disrupt","shatter","charge_hot"],"pierce":["charge","disrupt","cool","charge_hot"],"bore":["disrupt","detonate","spread"],"arc":["disrupt","charge","cool"],"vent":["charge_heat","bore","cool"]}
static func supports_for(state: Dictionary,family: String)->Array:
	return ROLE_SUPPORT.get(family,SUPPORT.get(family,["charge","charge_hot","cool"])) if Content.Roles.enabled(state) else SUPPORT.get(family,["charge","charge_hot","cool"])
static func enabled(state: Dictionary) -> bool:
	return int(state.get("focus_build_version", 0)) == VERSION

static func opening_options(state: Dictionary) -> Array:
	var options: Array = ["precise_p2", "pierce_p2", "vent"]
	if Content.Roles.enabled(state):options.append_array(["bore","arc"])
	var parts := Content.equipped_parts(state)
	var preferred := "vent" if parts.has("thermal_drive") else "pierce_p2" if parts.has("siege_drive") else "precise_p2"
	options.erase(preferred)
	options.push_front(preferred)
	return options

static func package(id: String) -> Array:
	return [id, id, "disrupt" if Content.source_id(id) in ["bore","arc"] else "charge_heat" if Content.source_id(id) == "vent" else "charge"]

static func package_text(id: String) -> String:
	return "%s 2장 + %s 1장" % [Content.AMMO[id].name, Content.AMMO[package(id)[2]].name]

static func replace_opening(deck: Array, id: String) -> Array:
	var result := deck.duplicate()
	for incoming in package(id):
		var weakest := -1
		for i in range(result.size()):
			if Content.source_id(str(result[i])) != "basic" or Content.is_compressed(str(result[i])): continue
			if weakest < 0 or int(Content.AMMO[result[i]].dmg) < int(Content.AMMO[result[weakest]].dmg): weakest = i
		if weakest < 0: return []
		result[weakest] = incoming
	return result

static func main_round(state: Dictionary) -> String:
	var counts: Dictionary = {}
	var best: Dictionary = {}
	for value in state.get("deck", []):
		var id := str(value)
		var family := Content.source_id(id)
		if family == "basic" or not Content.is_attack(id) or Content.is_temporary(id): continue
		counts[family] = int(counts.get(family, 0)) + 1
		if not best.has(family) or potency(id) > potency(str(best[family])): best[family] = id
	var families: Array = counts.keys()
	var preferred: Array = []
	var parts := Content.equipped_parts(state)
	if parts.has("volley_drive"): preferred = ["precise"]
	elif parts.has("siege_drive"): preferred = ["pierce", "vent", "chase"]
	elif parts.has("thermal_drive"): preferred = ["vent", "bore"]
	families.sort_custom(func(a, b):
		if counts[a] != counts[b]: return counts[a] > counts[b]
		if preferred.has(a) != preferred.has(b): return preferred.has(a)
		return str(a) < str(b))
	return str(best[families[0]]) if not families.is_empty() else ""

static func potency(id: String) -> int:
	var spec: Dictionary = Content.AMMO[id]
	return int(spec.dmg) * int(spec.get("hits", 2 if spec.effect == "double" else 1)) + int(spec.get("value", 0)) + int(spec.pen)

## A better physical copy is offered, never a silent upgrade to every owned card.
## Existing profile/compression rules carry their normal heat and slot costs.
static func upgrade(id: String) -> String:
	var tuned := Content.Variants.tuned(id, Content.AMMO, "power")
	if not tuned.is_empty(): return tuned
	if Content.COMPRESSIONS.has(id): return Content.compressed_id(id)
	return ""

static func rewards(state: Dictionary, node: Dictionary, fallback: Array) -> Array:
	var main := main_round(state)
	if main.is_empty(): return fallback
	var family := Content.source_id(main)
	var supports: Array = supports_for(state,family)
	var offset := absi(int(node.get("id", 0)) + int(state.get("seed", 0))) % supports.size()
	var result: Array = [main, supports[offset]]
	var improved := upgrade(main)
	if not improved.is_empty() and (int(node.get("region",0)) > 0 or int(node.get("floor",0)) >= 4):
		result.append(improved)
		return result
	for id in fallback:
		if not result.has(id): result.append(id); break
	if result.size() < 3:
		for id in ["arc", "bore", "pierce_p2", "precise_p2"]:
			if not result.has(id): result.append(id); break
	return result

static func offer_label(state: Dictionary, id: String) -> String:
	var main := main_round(state)
	if not main.is_empty() and id == upgrade(main): return "주력 강화 · 새 1장"
	if id == main: return "집중 보충 · 동일 성능 %d장 보유" % state.deck.count(id)
	if not main.is_empty() and supports_for(state,Content.source_id(main)).has(id): return "보조 · " + str(Content.AMMO[main].name)
	return "새 조합" if not state.deck.any(func(owned): return Content.source_id(str(owned)) == Content.source_id(id)) else "다른 선택"
