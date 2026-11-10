extends RefCounted
## Versioned per campaign; old runs never gain a new firing cost on resume.
const VERSION := 1

static func enabled(state: Dictionary) -> bool:
	return int(state.get("sustained_version", 0)) == VERSION

static func count(state: Dictionary) -> int:
	return int(state.get("sustained_attacks", 0)) if enabled(state) else 0

static func next_extra(state: Dictionary) -> int:
	return mini(2, count(state) / 2) if enabled(state) else 0

static func reset(state: Dictionary) -> void:
	if enabled(state): state.sustained_attacks = 0

static func fire(state: Dictionary, attack: bool, clears: bool) -> int:
	if not enabled(state): return 0
	if clears:
		reset(state)
		return 0
	if not attack: return 0
	var extra := next_extra(state)
	state.sustained_attacks = mini(1000000, count(state) + 1)
	return extra

static func valid(state: Dictionary) -> bool:
	var value = state.get("sustained_attacks", 0)
	if not value is int and not value is float: return false
	if not is_finite(float(value)) or value < 0 or value > 1000000 or value != int(value): return false
	if not enabled(state): return int(value) == 0
	if not state.has("sustained_attacks") or int(value) > int(state.get("shots", 0)): return false
	return int(value) == 0 or str(state.get("phase", "")) == "ready"

static func rules() -> String:
	return "연속 공격 1~2발: 기본 열 · 3~4발: 열 +1 · 5발째부터: 열 +2\n냉각탄·열방출탄·재장전으로 초기화. 지원탄과 사격 버튼 재입력은 끊지 않습니다. 다회 타격도 탄환 한 발로 셉니다."
