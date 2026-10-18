extends RefCounted
## Public build relationships; suggestions are not an automatic loadout choice.
const Ammo = preload("res://redesign/content.gd")
const FAMILIES := {
	"volley_drive":"화력 성장", "thermal_drive":"화력 성장", "siege_drive":"화력 성장",
	"lens": "조합 보상",
	"coil": "조합 보상",
	"inferno": "조합 보상",
	"igniter": "조합 보상",
	"capacitor": "조합 보상",
	"arc_splitter": "조합 보상",
	"rammer": "조합 보상",
	"momentum": "조합 보상",
	"sequencer": "조합 보상",
	"duplex": "조합 보상",
	"breaker": "조합 보상",
	"executioner": "조합 보상",
	"opening": "순서 보상",
	"afterburner": "순서 보상",
	"triad": "순서 보상",
	"ordinary_chain": "순서 보상",
	"radiator": "발열 운용",
	"reclaimer": "발열 운용",
	"ember_core": "발열 운용",
	"chain_sink": "발열 운용",
	"loader": "패 순환",
	"reserve": "패 순환",
	"indexer": "패 순환",
	"cooling_breech": "패 순환",
	"supply": "압축·탄창",
	"field_press": "압축·탄창",
	"overbore": "압축·탄창",
	"compression_sink": "압축·탄창",
}
const LINKS := {
	"cooling_breech": ["prepare", "thermal"], "chain_sink": ["sequence", "charge", "precise"], "indexer": ["prepare"], "supply": ["sequence", "prepare", "charge"],
	"radiator": ["charge_hot", "precise", "thermal"], "reclaimer": ["chase", "precise", "arc"], "ember_core": ["thermal", "vent", "precise"],
	"coil": ["bore", "detonate", "spread"], "inferno": ["bore", "push", "detonate", "spread"], "igniter": ["bore", "precise", "detonate", "spread"],
	"capacitor": ["arc"], "arc_splitter": ["arc"], "rammer": ["push"], "momentum": ["push", "bore"],
	"sequencer": ["charge", "precise"], "duplex": ["precise"], "breaker": ["precise"],
	"opening": ["precise"], "afterburner": ["precise"], "executioner": ["precise", "chase"]
}

static func family(id: String) -> String:
	return str(FAMILIES.get(id, "빌드"))

static func connection(id: String, state: Dictionary) -> String:
	if preload("res://redesign/damage_engines.gd").IDS.has(id): return preload("res://redesign/damage_engines.gd").progress(state,id)
	var counts: Dictionary = {}
	for round_id in state.get("deck", []):
		var source := Ammo.source_id(str(round_id))
		counts[source] = int(counts.get(source, 0)) + 1
	var uses_heat := counts.has("thermal") or Ammo.has_part(state, "ember_core")
	if id == "ordinary_chain":
		var kinds: Array = []
		for round_id in state.get("deck", []):
			var family := Ammo.source_id(str(round_id))
			if not kinds.has(family): kinds.append(family)
		return "보유 %d종 · 마지막 공격에 다른 탄종당 +2" % kinds.size()
	if id == "compression_sink":
		var compressed: int = state.get("deck", []).filter(func(round_id): return Ammo.is_compressed(str(round_id))).size()
		return "일반 → 압축 · 보유 %d장" % compressed
	if id == "overbore":
		var heavy: int = state.get("deck", []).filter(func(round_id): return Ammo.is_heavy_attack(str(round_id))).size()
		return "2칸 공격탄 %d장 · 한 발 집중" % heavy if heavy > 0 else "2칸 공격탄 필요 · 기본탄 제외"
	if id == "lens":
		var piercing: int = state.get("deck", []).filter(func(round_id): return int(Ammo.AMMO[round_id].pen) > 0).size()
		return "관통 보유 탄 %d장 · 파쇄로 장갑을 연 뒤 연결" % piercing if piercing > 0 else "관통탄 필요 · 기본탄 제외"
	if id == "cooling_breech": return "탄창을 줄여 재장전마다 열을 더 낮춤 · 고열 유지와는 상충"
	if id == "chain_sink": return "탄창 %d칸 · 세 번째 발 전에 과열되지 않도록 순서를 설계" % Ammo.capacity(state)
	if id == "indexer": return "예약탄 뒤의 전술탄도 다음 패로 · 뒤에 장전할 공간 필요" if counts.has("prepare") else "예약탄을 확보하면 다음 패 조합 강화"
	if id == "supply": return "탄창 +1 · 패 크기는 복장에 따름 · 열 한계는 그대로"
	if id == "radiator": return "과열을 늦춤 · 고열 보너스가 시작되는 열도 높아짐" if uses_heat else "과열을 늦춰 고발열탄을 더 조합"
	if id == "reclaimer": return "처치로 연쇄 유지 · 냉각 후 고열 조건을 다시 확인" if uses_heat else "적 처치 → 열 −2 · 탄 하나당 한 번"
	if id == "ember_core":
		var candidate := state.duplicate(false)
		candidate.equipped_parts = Ammo.equipped_parts(state)
		if not candidate.equipped_parts.has(id): candidate.equipped_parts.append(id)
		return "열 %d부터 타격당 +2 · 냉각 위치와 처치선을 비교" % Ammo.hot_threshold(candidate)
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
