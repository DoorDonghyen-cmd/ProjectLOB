extends RefCounted
## Presentation/identity change for new runs; established first-region numbers stay intact.
const LEADER := "slum_leader"
const SPECIES := {
	"runner":{"id":"slum_thief","name":"길목 도둑","rule":"가벼운 장비로 빠르게 접근합니다. 남은 거리와 재장전 시간을 확인하세요."},
	"wall":{"id":"slum_plate","name":"철판 약탈자","rule":"폐철판이 매 타격의 피해를 줄입니다. 관통·파쇄·화상으로 대응하세요."},
	"evader":{"id":"slum_battery","name":"전지 약탈자","rule":"노출된 축전지가 전기에 약합니다. 전기 속성의 주 타격에 추가 피해 2를 받습니다."},
	"spitter":{"id":"slum_gunner","name":"압력총 사수","rule":"2턴 준비 후 압력탄을 발사합니다. 가장 가까워진 압력탄은 다음 탄으로 요격합니다. 사수를 처치해도 발사된 탄은 남습니다."},
}

static func human(enemy: Dictionary) -> bool:
	return str(enemy.get("species","")).begins_with("slum_")

static func identify(enemy: Dictionary) -> void:
	if str(enemy.get("species","")) == "closure_watch": return
	if str(enemy.get("species","")) == "resonant_eavesback":
		enemy.species = LEADER
		enemy.name = "약탈단 두목"
	elif SPECIES.has(str(enemy.kind)):
		var spec: Dictionary = SPECIES[str(enemy.kind)]
		enemy.species = spec.id
		enemy.name = spec.name
		if str(enemy.kind) == "wall" and bool(enemy.get("stance",false)): enemy.name = "교대 방패병"

static func rule(enemy: Dictionary) -> String:
	if str(enemy.get("species","")) == LEADER:
		return "3턴마다 신호를 보내 다른 전열 적을 2m 추가 전진시킵니다. 차단으로 준비를 멈추거나 호위를 먼저 줄이세요."
	if not human(enemy): return ""
	return str(SPECIES.get(str(enemy.kind),{}).get("rule",""))
