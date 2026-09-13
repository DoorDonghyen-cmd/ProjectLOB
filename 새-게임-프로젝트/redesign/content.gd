extends RefCounted
## Public situations vary; shot resolution never rolls dice.
const AMMO := {
	"basic": {"name": "회수탄", "dmg": 4, "pen": 0, "acc": 6, "effect": "", "value": 0, "text": "항상 보급되는 기본탄. 균열로 장갑을 낮추면 더 강해집니다."},
	"bore": {"name": "균열탄", "dmg": 2, "pen": 1, "acc": 8, "effect": "crack", "value": 2, "text": "피격 적에게 균열 +2 (최대 3). 균열당 장갑 −1, 파쇄 전까지 유지."},
	"pierce": {"name": "파쇄탄", "dmg": 5, "pen": 2, "acc": 6, "effect": "shatter", "value": 2, "text": "적의 균열을 모두 소비하고 균열당 피해 +2. 소비 전 낮아진 장갑으로 계산."},
	"precise": {"name": "연속탄", "dmg": 2, "pen": 0, "acc": 9, "effect": "double", "value": 2, "text": "같은 적에게 2회 타격. 균열과 축전의 이득도 두 타격에 각각 적용."},
	"mark": {"name": "유도탄", "dmg": 2, "pen": 0, "acc": 10, "effect": "acc", "value": 4, "text": "다음 2발 명중 +4. 축전과 함께 유지되며 재장전하면 사라집니다."},
	"charge": {"name": "축전탄", "dmg": 1, "pen": 0, "acc": 8, "effect": "dmg", "value": 2, "text": "다음 2발의 타격당 피해 +2. 연속탄의 두 타격 모두 강화합니다."},
	"push": {"name": "충격탄", "dmg": 3, "pen": 0, "acc": 7, "effect": "push", "value": 2, "text": "적을 2m 밀어 다음 표적을 바꿉니다. 탄창당 총 2m까지."},
	"slow": {"name": "점착탄", "dmg": 3, "pen": 1, "acc": 9, "effect": "slow", "value": 2, "text": "다음 전진 1회 속도 −2. 사격 또는 재장전 시간을 벌어 줍니다."},
	"arc": {"name": "도약탄", "dmg": 3, "pen": 1, "acc": 8, "effect": "arc", "value": 3, "text": "다른 가장 가까운 적에게 고정 1피해. 주 표적에 균열이 있으면 3피해. 균열 유지."},
	"finish": {"name": "수확탄", "dmg": 3, "pen": 1, "acc": 7, "effect": "finish", "value": 4, "text": "발사 직전 적 체력이 절반 이하면 피해 +4. 준비 공격 뒤에 배치하세요."},
}
const GUNS := {
	"single": {"name": "보행자", "capacity": 4, "reload": 1, "bonus": 1, "text": "단발 · 타격당 피해 +1 · 사격 1턴 / 재장전 1턴"},
	"burst": {"name": "쇄도", "capacity": 4, "reload": 3, "bonus": 0, "text": "일제 · 한 탄창을 1턴에 발사 / 재장전 3턴"},
}
const PARTS := {
	"none": {"name": "파츠 없음", "text": "파츠는 한 개만 장착할 수 있습니다."},
	"lens": {"name": "추적 렌즈", "text": "모든 탄환 명중 +2. 회피 적을 상대로 스침 피해 감소를 줄입니다."},
	"loader": {"name": "회수 가속기", "text": "재장전 비용 −1턴 (최소 1턴)."},
	"supply": {"name": "확장 탄창", "text": "탄창과 기본탄 공급 4 → 5발. 더 긴 연계를 설계합니다."},
	"coil": {"name": "균열 코일", "text": "모든 적이 균열 1을 가진 채 전투 시작. 파쇄·도약·연속탄과 연계."},
}
const START_DECK := ["bore", "pierce", "mark", "precise", "push", "charge", "slow", "arc", "finish", "bore"]
const ENEMY_NAMES := {"runner": "운반 사족체", "wall": "융합 장갑벽", "evader": "굴절 선체"}
const ENCOUNTERS := [
	{"name": "01 / 폐기물 승강장", "text": "먼저 균열을 남길까, 축전으로 다음 두 발을 강화할까?"},
	{"name": "02 / 장갑 검문", "text": "균열은 남겨서 여러 발에 활용하거나 파쇄탄으로 소비할 수 있다."},
	{"name": "03 / 굴절 통로", "text": "명중이 모자라도 스침 피해는 남는다. 유도탄은 두 발을 돕는다."},
	{"name": "04 / 교차 운반로", "text": "밀기와 처치로 다음 표적이 바뀐다. 균열은 맞은 적에게 남는다."},
	{"name": "05 / 무인 정비층", "text": "축전은 연속탄을, 균열은 도약탄을 강화한다."},
	{"name": "06 / 상층 경계", "text": "지금 처치할까, 균열을 남기고 재장전할까?"},
	{"name": "07 / 배정되지 않은 자리", "text": "문은 열린다. 그 너머에는 인간의 자리가 배정되어 있지 않다."},
]
# kind, HP, armor, evasion, speed, distance. Three formations per floor.
const FORMATIONS := [
	[[["wall", 12, 2, 4, 1, 18]], [["runner", 13, 1, 5, 2, 20]], [["evader", 11, 0, 8, 2, 22]]],
	[[["wall", 17, 3, 4, 1, 20]], [["wall", 12, 2, 4, 1, 20], ["runner", 6, 0, 4, 2, 24]], [["wall", 16, 3, 5, 2, 24]]],
	[[["evader", 15, 1, 8, 2, 24]], [["evader", 10, 1, 8, 2, 22], ["runner", 7, 0, 5, 2, 26]], [["evader", 16, 0, 9, 2, 24]]],
	[[["runner", 11, 1, 5, 2, 22], ["wall", 16, 3, 4, 1, 23]], [["wall", 14, 3, 4, 1, 22], ["evader", 11, 1, 8, 2, 24]], [["runner", 12, 0, 5, 3, 26], ["runner", 14, 1, 6, 2, 28]]],
	[[["evader", 13, 1, 8, 2, 26], ["wall", 17, 3, 5, 2, 28]], [["runner", 13, 1, 5, 3, 26], ["evader", 14, 1, 9, 2, 28]], [["wall", 19, 3, 4, 1, 23], ["runner", 12, 0, 5, 3, 28]]],
	[[["wall", 20, 3, 5, 2, 28], ["evader", 16, 1, 8, 2, 30]], [["runner", 14, 1, 6, 3, 28], ["wall", 22, 3, 4, 2, 30]], [["evader", 17, 1, 9, 2, 27], ["runner", 18, 1, 5, 2, 30]]],
	[[["runner", 12, 1, 5, 3, 27], ["wall", 22, 3, 5, 2, 29], ["evader", 14, 1, 8, 2, 31]], [["wall", 20, 3, 5, 2, 26], ["runner", 13, 0, 6, 3, 29], ["evader", 15, 1, 9, 2, 31]], [["evader", 14, 1, 9, 2, 26], ["wall", 22, 3, 4, 2, 29], ["runner", 14, 1, 5, 3, 31]]],
]

static func enemies_for(index: int, run_seed: int = 0) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed + index * 104729 + 700001
	var variant := rng.randi_range(0, 2)
	var offset := rng.randi_range(0, 1)
	var result: Array = []
	for e in FORMATIONS[index][variant]:
		result.append({"kind": e[0], "name": ENEMY_NAMES[e[0]], "hp": e[1], "max_hp": e[1], "def": e[2], "eva": e[3], "speed": e[4], "distance": e[5] + offset, "slow": 0, "crack": 0})
	return result

static func rewards_for(index: int, run_seed: int, gun: String) -> Array:
	if index >= ENCOUNTERS.size() - 1: return []
	var pool: Array = ["lens", "loader", "supply", "coil"] if index in [1, 4] else ["bore", "pierce", "precise", "mark", "charge", "push", "slow", "arc", "finish"]
	if gun == "single": pool.erase("loader")
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed + index * 65537 + 900001
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var value = pool[i]
		pool[i] = pool[j]
		pool[j] = value
	return pool.slice(0, 3)
