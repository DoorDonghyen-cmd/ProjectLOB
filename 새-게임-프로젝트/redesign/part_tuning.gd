extends RefCounted
## Part fixes after the overheat cost (2026-11-11, user: "1,2 진행해 줘" on the part review,
## docs/qa/reports/part_review_2026-11-11/README.md). Runs with the overheat cost only
## (overheat_cost.gd); older saves keep the old rules.
##  1. Broken parts: 야전 압축기 is not offered (field compression exists only in hand combat);
##     냉각 약실 rewards a manual cool: the first attack round of the next fire gets +3 per hit.
##  2. Double costs: the swap-cost penalties of parts (후미 점화기·열폭주 노심 +1) no longer
##     lengthen forced cooling; 회수 가속기 (−1) still shortens it;
##     잔열 노심 heat limit −2 → −1; 연타 공명기 no longer adds heat.
const Overheat = preload("res://redesign/overheat_cost.gd")
const BREECH_BONUS := 3
const RETIRED_OFFERS := ["field_press"]

static func enabled(state: Dictionary) -> bool:
	return Overheat.enabled(state)

## Heat limit change of a part (ember_core −2 → −1 here).
static func heat_limit_fix(state: Dictionary, part: String) -> int:
	return 1 if enabled(state) and part == "ember_core" else 0

static func resonator_heats(state: Dictionary) -> bool:
	return not enabled(state)

## 냉각 약실: the last action of this fight was a manual cool.
static func breech_ready(state: Dictionary, parts: Array) -> bool:
	if not enabled(state) or not parts.has("cooling_breech"): return false
	var history: Array = state.get("history", [])
	return not history.is_empty() and str(history.back().get("action", "")) == "cool"

## 3. Weak parts, bigger numbers (2026-11-11, "3,4 진행해주고"): the review found +1·+2 and
##    "HP 5 이하" changed nothing against 15~80 HP enemies.
##    가속 총열: also +2 damage per hit for rounds with their own pierce.
##    처형 조준기: HP 30% 이하 (was HP 5 이하), +4 (was +2).
##    충격 피스톤: no −1 direct damage. 후미 점화기: no +1 swap turn. 잔열 노심: +3 (was +2).
static func executes(state: Dictionary, hp: int, max_hp: int) -> bool:
	return hp * 10 <= max_hp * 3 if enabled(state) else hp <= 5

static func execute_bonus(state: Dictionary) -> int:
	return 4 if enabled(state) else 2

static func lens_damage(state: Dictionary) -> int:
	return 2 if enabled(state) else 0

static func momentum_penalty(state: Dictionary) -> int:
	return 0 if enabled(state) else 1

static func afterburner_swap(state: Dictionary) -> int:
	return 0 if enabled(state) else 1

static func ember_extra(state: Dictionary) -> int:
	return 1 if enabled(state) else 0

static func offerable(state: Dictionary, part: String) -> bool:
	return not (enabled(state) and RETIRED_OFFERS.has(part))
