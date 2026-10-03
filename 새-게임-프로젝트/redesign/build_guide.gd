extends RefCounted
## Public build relationships; suggestions are not an automatic loadout choice.
const Ammo = preload("res://redesign/content.gd")
const FAMILIES := {
	"lens": "장갑", "overbore": "장갑", "breaker": "보호",
	"coil": "화상", "inferno": "화상", "igniter": "화상",
	"capacitor": "전이", "arc_splitter": "전이",
	"rammer": "거리", "momentum": "거리",
	"sequencer": "증폭", "duplex": "연발", "opening": "순서", "afterburner": "순서", "triad": "순서",
	"loader": "순환", "reserve": "순환", "supply": "탄창", "field_press": "압축", "executioner": "처치"
}
const LINKS := {
	"coil": ["bore"], "inferno": ["bore", "push"], "igniter": ["bore", "precise"],
	"capacitor": ["arc"], "arc_splitter": ["arc"], "rammer": ["push"], "momentum": ["push", "bore"],
	"sequencer": ["charge", "precise"], "duplex": ["precise"], "breaker": ["precise"],
	"opening": ["precise"], "afterburner": ["precise"], "executioner": ["precise"]
}

static func family(id: String) -> String:
	return str(FAMILIES.get(id, "빌드"))

static func connection(id: String, state: Dictionary) -> String:
	var counts: Dictionary = {}
	for round_id in state.get("deck", []):
		var source := Ammo.source_id(str(round_id))
		counts[source] = int(counts.get(source, 0)) + 1
	if id == "triad": return "탄종 %d가지 · 서로 다른 세 발의 순서를 설계" % counts.size()
	if id == "field_press":
		var pairs := 0
		for source in Ammo.COMPRESSIONS:
			pairs += int(state.get("deck", []).count(source)) / 2
		return "압축 후보 %d쌍 · 두 발을 동시에 손에 모아 사용" % pairs
	if id == "reserve": return "패 교환 %d → %d회 · 덱의 다른 탄을 찾아 조합" % [Ammo.exchange_capacity(state), Ammo.exchange_capacity(state) if Ammo.has_part(state, id) else Ammo.exchange_capacity(state) + 1]
	if not LINKS.has(id): return str(Ammo.PARTS[id].role) + " · 특정 탄종 없이 적용"
	var found: PackedStringArray = []
	for source in LINKS[id]:
		if int(counts.get(source, 0)) > 0: found.append("%s %d장" % [Ammo.AMMO[source].name, counts[source]])
	return "연결 예 · " + " / ".join(found) if not found.is_empty() else "연결할 탄환을 먼저 확보하세요"
