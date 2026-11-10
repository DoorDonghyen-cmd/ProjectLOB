extends RefCounted
## First-region pacing for roster 12. Existing campaigns keep their authored packs.
const VERSION := 12
const Ammo = preload("res://redesign/content.gd")
const PROFILES := {
	"sweep": {"name":"흩어진 약탈단", "hint":"가벼운 전열 4명 · 증원 없음. 처치 후 남는 타격과 피해를 이어 보세요."},
	"breach": {"name":"교대 방패 진지", "hint":"장갑 6과 0이 적 행동마다 교대합니다. 재장전 시간에 맞춰 개방을 노리거나 관통·화상으로 돌파하세요."},
	"ambush": {"name":"사수 매복", "hint":"사수가 맨 앞에서 발사 준비 중입니다. 먼저 제압하거나 압력탄 요격을 준비하세요."},
	"payoff": {"name":"모여든 약탈단", "hint":"가벼운 전열 4명 · 증원 없음. 정비한 조합으로 한 번에 정리할 기회입니다."},
}

static func role(node: Dictionary) -> String:
	if int(node.get("region",-1)) != 0 or node.get("kind","") != "combat" or node.get("elite",false): return ""
	match int(node.get("floor",0)):
		2: return "sweep"
		3: return "ambush"
		4,5: return "breach"
		6: return "payoff"
	return ""

static func decorate(nodes: Array) -> Array:
	var result := nodes.duplicate(true)
	for node in result:
		var key := role(node)
		if key.is_empty(): continue
		node.rhythm_role = key
		node.name = PROFILES[key].name
	return result

static func hint(node: Dictionary) -> String:
	return str(PROFILES.get(str(node.get("rhythm_role","")),{}).get("hint",""))

static func rows(node: Dictionary, fallback: Array) -> Array:
	match role(node):
		"sweep": return [["runner",2,0,2,24],["runner",3,0,2,28],["runner",3,0,2,32],["runner",4,0,2,36]]
		"breach": return [["wall",16,6,1,36,{"stance":true,"stance_def":6,"stance_closed":true}],["runner",3,0,2,44]]
		"ambush": return [["spitter",9,0,0,30],["runner",3,0,2,36],["runner",3,0,2,40]]
		"payoff": return [["runner",3,0,2,26],["runner",4,0,2,30],["evader",4,0,1,34],["runner",5,0,2,38]]
	return fallback

static func rewards(node: Dictionary, deck: Array, fallback: Array) -> Array:
	# The second mandatory fight offers a partner for the first earned special.
	# It is still one optional acquisition, with the normal replacement/carry cost.
	if role(node) != "sweep": return fallback
	var partners := {"charge":"precise_p2", "precise":"charge", "pierce":"charge", "arc":"charge", "bore":"push", "push":"bore"}
	var partner := ""
	var first_family := ""
	for id in deck:
		var family := Ammo.source_id(str(id))
		if partners.has(family):
			partner = str(partners[family])
			first_family = family
			break
	if partner.is_empty(): return fallback
	# Burn needs enough earned copies through later gates. Keep its original
	# build-fitting offer first; push is a tactical alternative, not a replacement.
	if first_family == "bore" and not fallback.is_empty() and Ammo.source_id(str(fallback[0])) != "push": return [fallback[0],partner]
	var result: Array = [partner]
	for id in fallback:
		if Ammo.source_id(str(id)) != Ammo.source_id(partner): result.append(id)
	if result.size() == 1: result.append("pierce_p2" if partner == "charge" else "charge")
	return result.slice(0,2)
