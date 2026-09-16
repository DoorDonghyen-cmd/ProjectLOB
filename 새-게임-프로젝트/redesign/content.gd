extends RefCounted
## Damage is transparent; scatter alone chooses a random primary target.
## Every round exposes two numbers, one attribute, and at most one effect.
const AMMO := {
	"basic": {"name": "회수탄", "dmg": 4, "pen": 0, "attribute": "physical", "effect": "", "value": 0, "text": "항상 보급되는 물리 기본탄. 재장전할 때 공급 상한까지 복구됩니다."},
	"pierce": {"name": "철갑탄", "dmg": 3, "pen": 3, "attribute": "physical", "effect": "", "value": 0, "text": "높은 관통으로 장갑을 곧바로 뚫는 물리탄입니다."},
	"push": {"name": "충격탄", "dmg": 3, "pen": 0, "attribute": "physical", "effect": "push", "value": 2, "text": "적을 2m 밀어 거리를 벌리고 다음 표적을 바꿉니다. 탄창당 총 2m까지 밀 수 있습니다."},
	"bore": {"name": "소이탄", "dmg": 2, "pen": 1, "attribute": "fire", "effect": "burn", "value": 3, "text": "생존한 적에게 화상 3을 남깁니다. 화상은 적의 전진 직전에 1피해를 주고 1 감소합니다."},
	"charge": {"name": "증폭탄", "dmg": 1, "pen": 0, "attribute": "physical", "effect": "boost", "value": 2, "text": "다음 2발의 타격당 피해를 +2 합니다. 연발탄의 두 타격에도 각각 적용됩니다."},
	"precise": {"name": "연발탄", "dmg": 2, "pen": 0, "attribute": "physical", "effect": "double", "value": 2, "text": "같은 적을 2회 타격합니다. 증폭 피해도 두 타격에 각각 적용됩니다."},
	"arc": {"name": "전격탄", "dmg": 3, "pen": 1, "attribute": "electric", "effect": "arc", "value": 2, "text": "주 표적을 공격한 뒤 가장 가까운 다른 생존 적에게 고정 2피해를 전이합니다."},
}

const GUNS := {
	"single": {"name": "보행자", "role": "기본 직접 화력", "capacity": 4, "reload": 1, "bonus": 1, "mode": "chain", "identity": "모든 탄환 기본 피해 +1", "recommendation": "증폭 → 연발 · 다양한 탄환 조합", "text": "전탄 연쇄 · 기본 피해 +1 · 사격 1턴 / 재장전 1턴"},
	"burst": {"name": "쇄도", "role": "집중 적중", "capacity": 4, "reload": 2, "bonus": 0, "mode": "chain", "identity": "같은 적 3회 적중마다 추가 피해 4", "recommendation": "증폭 → 연발 · 3번째 타격 계산", "text": "전탄 연쇄 · 주 타격 3회마다 고정 추가 피해 4 · 재장전 2턴"},
	"scatter": {"name": "산개", "role": "무작위 분산", "capacity": 5, "reload": 2, "bonus": 0, "mode": "chain", "identity": "탄환마다 무작위 표적 · 넉넉한 탄창", "recommendation": "표적별 확률 · 분산 피해와 전격", "text": "전탄 연쇄 · 생존 적 중 균등 무작위 표적 · 탄창 5칸 / 재장전 2턴"},
	"heavy": {"name": "압쇄", "role": "속성 특화", "capacity": 4, "reload": 1, "bonus": 0, "mode": "chain", "identity": "화상 턴당 피해 2 · 전이 피해 3", "recommendation": "소이 지속 피해 · 전격 전이", "text": "전탄 연쇄 · 소이 화상 피해 2 / 전격 전이 피해 3 · 재장전 1턴"},
	"amplifier": {"name": "증강", "role": "한 발 효과 강화", "capacity": 3, "reload": 1, "bonus": 0, "mode": "single", "identity": "단발 · 탄환 성능 2배", "recommendation": "증폭 +4 · 연발 4×2 · 충격 4m", "text": "단발 · 기본 피해/관통과 효과 강도 2배 · 연발 2타/지속 기간 유지 · 재장전 1턴"},
}

const PARTS := {
	"none": {"name": "파츠 없음", "text": "파츠는 한 개만 장착할 수 있습니다."},
	"lens": {"name": "가속 총열", "text": "모든 탄환 관통 +1. 장갑이 남기는 피해 감소를 줄입니다."},
	"loader": {"name": "회수 가속기", "text": "재장전 비용 −1턴 (최소 1턴)."},
	"supply": {"name": "확장 탄창", "text": "탄창과 회수탄 공급 +1발. 더 긴 순서를 설계합니다."},
	"coil": {"name": "열축전 코일", "text": "소이탄이 남기는 화상 +1."},
}

const START_DECK := ["bore", "pierce", "precise", "charge", "push", "arc", "bore", "charge", "pierce", "precise"]
const GUN_DECKS := {
	"scatter": ["charge", "precise", "arc", "bore", "push", "pierce", "bore", "charge", "precise", "arc"],
	"heavy": ["bore", "arc", "charge", "bore", "push", "pierce", "bore", "charge", "precise", "arc"],
	"amplifier": ["charge", "precise", "push", "pierce", "bore", "arc", "charge", "precise", "push", "pierce"],
}

const ENEMY_NAMES := {"runner": "운반 사족체", "wall": "융합 장갑벽", "evader": "전도 선체"}
const ENCOUNTERS := [
	{"name": "01 / 폐기물 승강장", "text": "증폭탄을 먼저 넣어 뒤의 두 발을 증폭할까?"},
	{"name": "02 / 장갑 검문", "text": "장갑은 피해를 줄인다. 철갑탄의 관통으로 남는 장갑을 없애세요."},
	{"name": "03 / 열처리 통로", "text": "소이탄을 일찍 발사하면 화상이 여러 번 전진을 막아 줍니다."},
	{"name": "04 / 압축 운반로", "text": "증폭 뒤 연발탄은 증폭 피해를 두 번 적용합니다."},
	{"name": "05 / 무인 정비층", "text": "충격탄으로 거리를 벌리고 다음 표적 순서를 바꾸세요."},
	{"name": "06 / 전도 경계", "text": "전격탄은 가장 가까운 다른 적에게 피해를 전이합니다."},
	{"name": "07 / 배정되지 않은 자리", "text": "문은 열린다. 그 너머에는 인간의 자리가 배정되어 있지 않다."},
]

# kind, HP, armor, speed, distance. Three formations per floor.
const FORMATIONS := [
	[[["wall", 12, 2, 1, 18]], [["runner", 13, 1, 2, 20]], [["evader", 11, 0, 2, 22]]],
	[[["wall", 17, 3, 1, 20]], [["wall", 12, 2, 1, 20], ["runner", 6, 0, 2, 24]], [["wall", 16, 3, 2, 24]]],
	[[["evader", 15, 1, 2, 24]], [["evader", 10, 1, 2, 22], ["runner", 7, 0, 2, 26]], [["evader", 16, 0, 2, 24]]],
	[[["runner", 11, 1, 2, 22], ["wall", 16, 3, 1, 23]], [["wall", 14, 3, 1, 22], ["evader", 11, 1, 2, 24]], [["runner", 12, 0, 3, 26], ["runner", 14, 1, 2, 28]]],
	[[["runner", 10, 2, 3, 12], ["wall", 17, 3, 2, 23]], [["runner", 13, 1, 4, 16], ["evader", 14, 1, 2, 24]], [["wall", 19, 3, 1, 21], ["runner", 12, 0, 4, 18]]],
	[[["runner", 8, 0, 3, 16], ["evader", 5, 0, 2, 18], ["wall", 14, 3, 1, 23]], [["runner", 10, 1, 3, 17], ["wall", 15, 3, 2, 21], ["evader", 5, 0, 2, 19]], [["evader", 8, 1, 2, 16], ["runner", 6, 0, 3, 18], ["wall", 16, 3, 1, 23]]],
	[[["runner", 12, 1, 3, 27], ["wall", 22, 3, 2, 29], ["evader", 14, 1, 2, 31]], [["wall", 20, 3, 2, 26], ["runner", 13, 0, 3, 29], ["evader", 15, 1, 2, 31]], [["evader", 14, 1, 2, 26], ["wall", 22, 3, 2, 29], ["runner", 14, 1, 3, 31]]],
]

const COURSE_GRANTS := [["charge", "charge"], ["pierce"], ["bore"], ["precise"], ["push"], ["arc"], []]
const LESSONS := [
	"피해 → HP · 증폭탄 뒤의 두 발이 강해집니다",
	"관통 → 장갑 · 철갑탄은 장갑 감소를 줄입니다",
	"화상은 적의 전진 직전에 1피해를 줍니다",
	"연발탄은 두 번 공격 · 증폭도 두 번 적용됩니다",
	"충격탄은 2m 밀어 거리와 다음 표적을 바꿉니다",
	"전격탄은 가장 가까운 다른 적에게 2피해를 전이합니다",
	"마지막 교전 · 피해·거리·속성을 한 순서로 설계하세요",
]

static func lesson(state: Dictionary) -> String:
	match int(state.floor):
		2: return "화상은 전진 직전에 턴당 %d피해를 줍니다" % burn_damage(state)
		4: return "충격탄은 %dm 밀어 거리를 벌립니다" % effect_value("push", state)
		5: return "전격탄은 다른 생존 적에게 %d피해를 전이합니다" % effect_value("arc", state)
	return LESSONS[int(state.floor)]

static func course_pool(index: int) -> Array:
	var result: Array = []
	for stage in range(index + 1):
		for id in COURSE_GRANTS[stage]:
			if not result.has(id): result.append(id)
	return result

static func axes(state: Dictionary) -> Dictionary:
	return {"armor": not state.get("course", false) or int(state.floor) >= 1}

static func multiplier(state: Dictionary) -> int:
	return 2 if state.get("gun", "single") == "amplifier" else 1

static func damage(id: String, state: Dictionary) -> int:
	return int(AMMO[id].dmg) * multiplier(state) + int(GUNS[state.gun].bonus)

static func penetration(id: String, state: Dictionary) -> int:
	return int(AMMO[id].pen) * multiplier(state) + (1 if state.get("part", "none") == "lens" else 0)

static func effect_value(id: String, state: Dictionary) -> int:
	if id == "arc" and state.get("gun", "") == "heavy": return 3
	return int(AMMO[id].value) * multiplier(state)

static func burn_damage(state: Dictionary) -> int:
	return 2 if state.get("gun", "") in ["heavy", "amplifier"] else 1

static func push_budget(state: Dictionary) -> int:
	return 2 * multiplier(state)

static func chains(state: Dictionary) -> bool:
	return str(GUNS[state.gun].mode) == "chain"

static func capacity(state: Dictionary) -> int:
	return int(GUNS[state.gun].capacity) + int(state.get("capacity_bonus", 0)) + (1 if state.get("part", "none") == "supply" else 0)

static func start_deck(gun: String) -> Array:
	return GUN_DECKS.get(gun, START_DECK).duplicate()

static func accepts_part(gun: String, part: String) -> bool:
	return PARTS.has(part) and (part != "loader" or int(GUNS[gun].reload) > 1)

static func burn_amount(id: String, state: Dictionary) -> int:
	if str(AMMO[id].effect) != "burn": return 0
	return int(AMMO[id].value) + (1 if state.get("part", "none") == "coil" else 0)

static func enemies_for(index: int, run_seed: int = 0, course: bool = false, gun: String = "single") -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed + index * 104729 + 700001
	var variant := rng.randi_range(0, 2)
	var offset := 0 if course else rng.randi_range(0, 1)
	var result: Array = []
	var formation: Array = FORMATIONS[index][variant]
	if course and index < 6:
		formation = [
			[["runner", 16 if gun == "single" else 17, 0, 2, 22]],
			[["wall", 17, 3, 1, 22]],
			[["wall", 18, 2, 2, 26]],
			[["runner", 18, 1, 2, 25]],
			[["runner", 8, 2, 3, 6], ["wall", 12, 2, 1, 16]],
			[["runner", 6, 0, 2, 12], ["evader", 2, 0, 2, 14], ["wall", 10, 2, 1, 18]],
		][index]
	for e in formation:
		result.append({"kind": e[0], "name": ENEMY_NAMES[e[0]], "hp": e[1], "max_hp": e[1], "def": e[2], "speed": e[3], "distance": e[4] + offset, "burn": 0})
	return result

static func rewards_for(index: int, run_seed: int, gun: String, course: bool = false) -> Array:
	if index >= ENCOUNTERS.size() - 1: return []
	var pool: Array = ["lens", "loader", "supply", "coil"] if index in [1, 4] else ["bore", "pierce", "precise", "charge", "push", "arc"]
	if course and index != 4: pool = course_pool(index)
	if not accepts_part(gun, "loader"): pool.erase("loader")
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed + index * 65537 + 900001
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var value = pool[i]
		pool[i] = pool[j]
		pool[j] = value
	return pool.slice(0, 3)
