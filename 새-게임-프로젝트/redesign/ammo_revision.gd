extends RefCounted
## Round rework from the naming review (2026-11-12, user: "전부 진행해 줘" on
## docs/direction/ammo-naming.md). New runs only (model.s.ammo_revision_version).
##  3. 연계탄 said almost the same as the 교차 사격 rule (+2 per other kind fired before).
##     Now it raises the 교차 step by +2 (max +3, mix_combo.gd), so the rounds after it hit harder.
##  4. 예약탄 reserved rounds for the next HAND, which magazine combat does not have (its
##     next-load record was cleared on every load). Now it takes the round behind it out of
##     the magazine and loads it at the very front of the next magazine (max 3, held_front).
const VERSION := 1
const SEQUENCE_STEP := 2
const HELD_LIMIT := 3

static func enabled(state: Dictionary) -> bool:
	return int(state.get("ammo_revision_version", 0)) == VERSION

static func text(id: String, state: Dictionary) -> String:
	if not enabled(state): return ""
	var family := str(preload("res://redesign/content.gd").source_id(id))
	if family == "sequence": return "쏘면 교차 사격 단계 +%d(최대 +3). 이 탄 뒤에 다른 계열 공격탄을 이어 쏘면 교차 피해가 커집니다. 이 탄도 지금 단계만큼 교차 피해를 받습니다." % SEQUENCE_STEP
	if family == "prepare": return "바로 뒤의 탄 1발을 탄창에서 빼 두었다가, 다음 탄창 맨 앞에 먼저 넣습니다(최대 %d발). 강한 탄을 다음 탄창 첫 발로 아끼거나, 과열 직전의 탄을 미룹니다." % HELD_LIMIT
	return ""

static func valid(state: Dictionary) -> bool:
	var version = state.get("ammo_revision_version", 0)
	if not ((version is int or version is float) and int(version) == version and int(version) >= 0 and int(version) <= VERSION): return false
	if not state.has("held_front"): return true
	var held = state.held_front
	if not held is Array or held.size() > HELD_LIMIT or (int(version) == 0 and not held.is_empty()): return false
	for id in held:
		if not preload("res://redesign/content.gd").AMMO.has(str(id)): return false
	return true
