extends RefCounted
## Damage is transparent; scatter alone chooses a random primary target.
## Every round exposes two numbers, one attribute, and at most one effect.
const AMMO := {
	"basic": {"name": "회수탄", "dmg": 2, "pen": 0, "attribute": "physical", "effect": "", "value": 0, "text": "재장전 때 복구되는 보조 화력입니다. 전술탄의 처치선과 순서를 이어 주는 탄환입니다."},
	"pierce": {"name": "철갑탄", "dmg": 3, "pen": 3, "attribute": "physical", "effect": "", "value": 0, "text": "높은 관통으로 장갑을 곧바로 뚫는 물리탄입니다."},
	"push": {"name": "충격탄", "dmg": 3, "pen": 0, "attribute": "physical", "effect": "push", "value": 2, "text": "적을 2m 밀어 거리를 벌리고 다음 표적을 바꿉니다. 탄창당 총 2m까지 밀 수 있습니다."},
	"bore": {"name": "소이탄", "dmg": 2, "pen": 1, "attribute": "fire", "effect": "burn", "value": 3, "text": "생존한 적에게 화상 3을 남깁니다. 화상은 적의 전진 직전에 1피해를 주고 1 감소합니다."},
	"charge": {"name": "증폭탄", "dmg": 1, "pen": 0, "attribute": "physical", "effect": "boost", "value": 2, "text": "다음 2발의 타격당 피해를 +2 합니다. 연발탄의 두 타격에도 각각 적용됩니다."},
	"precise": {"name": "연발탄", "dmg": 2, "pen": 0, "attribute": "physical", "effect": "double", "value": 2, "text": "같은 적을 2회 타격합니다. 증폭 피해도 두 타격에 각각 적용됩니다."},
	"arc": {"name": "전격탄", "dmg": 3, "pen": 1, "attribute": "electric", "effect": "arc", "value": 2, "text": "주 표적을 공격한 뒤 가장 가까운 다른 생존 적에게 고정 2피해를 전이합니다."},
	# Compressed rounds keep the family name. Their silhouette and magazine fit
	# communicate the variant in combat; prose lives only in inspection surfaces.
	"pierce_c": {"name": "철갑탄", "dmg": 5, "pen": 6, "attribute": "physical", "effect": "", "value": 0, "compressed": true, "source": "pierce", "slot_cost": 2, "anchor": "", "text": "두 철갑탄을 한 발에 집약합니다. 탄창 2칸을 차지하지만 높은 장갑을 한 번에 관통합니다."},
	"push_c": {"name": "충격탄", "dmg": 5, "pen": 0, "attribute": "physical", "effect": "push", "value": 3, "push_budget_bonus": 1, "compressed": true, "source": "push", "slot_cost": 1, "anchor": "last", "text": "마지막 발에 자동 고정됩니다. 강한 충격으로 적의 다음 접근 거리를 벌립니다."},
	"bore_c": {"name": "소이탄", "dmg": 3, "pen": 1, "attribute": "fire", "effect": "burn", "value": 6, "compressed": true, "source": "bore", "slot_cost": 2, "anchor": "", "text": "탄창 2칸을 차지하고 화상을 한 발에 최대치까지 축적합니다."},
	"charge_c": {"name": "증폭탄", "dmg": 1, "pen": 0, "attribute": "physical", "effect": "boost", "value": 4, "compressed": true, "source": "charge", "slot_cost": 1, "anchor": "last", "text": "마지막 발에 자동 고정됩니다. 남긴 증폭은 다음 탄창의 첫 두 발로 이어집니다."},
	"precise_c": {"name": "연발탄", "dmg": 3, "pen": 0, "attribute": "physical", "effect": "double", "value": 3, "hits": 3, "compressed": true, "source": "precise", "slot_cost": 1, "anchor": "first", "text": "첫 발에 자동 고정되어 같은 적을 3회 타격합니다."},
	"arc_c": {"name": "전격탄", "dmg": 4, "pen": 1, "attribute": "electric", "effect": "arc", "value": 2, "arc_targets": 99, "compressed": true, "source": "arc", "slot_cost": 1, "anchor": "first", "text": "첫 발에 자동 고정되어 주 표적을 제외한 모든 생존 적에게 전이합니다."},
	# Field-compressed rounds are encounter-only mirrors. They use the same combat
	# profile and fittings as permanent compression, then split back into the two
	# source rounds when fired or discarded.
	"pierce_f": {"name": "철갑탄", "dmg": 5, "pen": 6, "attribute": "physical", "effect": "", "value": 0, "compressed": true, "temporary": true, "source": "pierce", "slot_cost": 2, "anchor": "", "text": "이번 교전에서 두 철갑탄을 한 발에 임시 집약합니다."},
	"push_f": {"name": "충격탄", "dmg": 5, "pen": 0, "attribute": "physical", "effect": "push", "value": 3, "push_budget_bonus": 1, "compressed": true, "temporary": true, "source": "push", "slot_cost": 1, "anchor": "last", "text": "이번 교전에서 두 충격탄을 마지막 한 발로 임시 집약합니다."},
	"bore_f": {"name": "소이탄", "dmg": 3, "pen": 1, "attribute": "fire", "effect": "burn", "value": 6, "compressed": true, "temporary": true, "source": "bore", "slot_cost": 2, "anchor": "", "text": "이번 교전에서 두 소이탄을 한 발에 임시 집약합니다."},
	"charge_f": {"name": "증폭탄", "dmg": 1, "pen": 0, "attribute": "physical", "effect": "boost", "value": 4, "compressed": true, "temporary": true, "source": "charge", "slot_cost": 1, "anchor": "last", "text": "이번 교전에서 두 증폭탄을 마지막 한 발로 임시 집약합니다."},
	"precise_f": {"name": "연발탄", "dmg": 3, "pen": 0, "attribute": "physical", "effect": "double", "value": 3, "hits": 3, "compressed": true, "temporary": true, "source": "precise", "slot_cost": 1, "anchor": "first", "text": "이번 교전에서 두 연발탄을 첫 한 발로 임시 집약합니다."},
	"arc_f": {"name": "전격탄", "dmg": 4, "pen": 1, "attribute": "electric", "effect": "arc", "value": 2, "arc_targets": 99, "compressed": true, "temporary": true, "source": "arc", "slot_cost": 1, "anchor": "first", "text": "이번 교전에서 두 전격탄을 첫 한 발로 임시 집약합니다."},
}

const COMPRESSIONS := {
	"pierce": "pierce_c",
	"push": "push_c",
	"bore": "bore_c",
	"charge": "charge_c",
	"precise": "precise_c",
	"arc": "arc_c",
}

const FIELD_COMPRESSIONS := {
	"pierce": "pierce_f",
	"push": "push_f",
	"bore": "bore_f",
	"charge": "charge_f",
	"precise": "precise_f",
	"arc": "arc_f",
}

const GUNS := {
	"single": {"name": "보행자", "role": "전술탄 조합 입문", "capacity": 4, "reload": 1, "bonus": 2, "basic_bonus": 1, "mode": "chain", "identity": "전술탄 피해 +2 · 회수탄 +1", "recommendation": "약점탄과 증폭 연계를 섞는 안정형", "text": "전탄 연쇄 · 전술탄 피해 +2 / 회수탄 +1 · 재장전 1턴"},
	"burst": {"name": "쇄도", "role": "집중 적중", "capacity": 4, "reload": 2, "bonus": 0, "mode": "chain", "identity": "같은 적 3회 적중마다 추가 피해 4", "recommendation": "증폭 → 연발 · 3번째 타격 계산", "text": "전탄 연쇄 · 주 타격 3회마다 고정 추가 피해 4 · 재장전 2턴"},
	"scatter": {"name": "산개", "role": "무작위 분산", "capacity": 5, "reload": 2, "bonus": 0, "mode": "chain", "identity": "탄환마다 무작위 표적 · 넉넉한 탄창", "recommendation": "표적별 확률 · 분산 피해와 전격", "text": "전탄 연쇄 · 생존 적 중 균등 무작위 표적 · 탄창 5칸 / 재장전 2턴"},
	"heavy": {"name": "압쇄", "role": "속성 특화", "capacity": 4, "reload": 1, "bonus": 0, "mode": "chain", "identity": "화상 턴당 피해 2 · 전이 피해 3", "recommendation": "소이 지속 피해 · 전격 전이", "text": "전탄 연쇄 · 소이 화상 피해 2 / 전격 전이 피해 3 · 재장전 1턴"},
	"amplifier": {"name": "증강", "role": "한 발 효과 강화", "capacity": 3, "reload": 1, "bonus": 0, "mode": "single", "identity": "단발 · 탄환 성능 2배", "recommendation": "증폭 +4 · 연발 4×2 · 충격 4m", "text": "단발 · 기본 피해/관통과 효과 강도 2배 · 연발 2타/지속 기간 유지 · 재장전 1턴"},
}

const PARTS := {
	"none": {"name": "빈 파츠 슬롯", "kind": "empty", "effect": "장착", "value": "0 / 5", "role": "전투 사이 무료 교체", "upside": "", "downside": "", "text": "파츠를 최대 5개 장착할 수 있습니다. 코어 파츠는 한 개만 장착합니다."},
	"lens": {"name": "가속 총열", "kind": "module", "effect": "관통", "value": "+2", "role": "장갑 대응", "upside": "관통 +2", "downside": "", "text": "모든 탄환 관통 +2. 장갑 적에게 회수탄과 속성탄도 유효하게 만듭니다."},
	"loader": {"name": "회수 가속기", "kind": "module", "effect": "재장전", "value": "−1턴", "role": "빠른 순환", "upside": "재장전 −1턴", "downside": "", "text": "재장전 비용 −1턴 (최소 1턴)."},
	"supply": {"name": "확장 탄창", "kind": "module", "effect": "탄창 · 회수탄", "value": "+1 · +1", "role": "긴 연쇄", "upside": "탄창·회수탄 +1", "downside": "", "text": "탄창과 회수탄 공급 +1발. 더 긴 순서를 설계합니다."},
	"coil": {"name": "열축전 코일", "kind": "module", "effect": "화상", "value": "+1", "role": "지속 피해", "upside": "화상 +1", "downside": "", "text": "소이탄이 남기는 화상 +1."},
	"capacitor": {"name": "전이 축전기", "kind": "module", "effect": "전이", "value": "+1 피해", "role": "다수전 전이", "upside": "전이 피해 +1", "downside": "", "text": "전격탄의 전이 피해 +1. 많은 적을 동시에 정리하는 빌드를 강화합니다."},
	"rammer": {"name": "충격 가이드", "kind": "module", "effect": "밀치기", "value": "+1m", "role": "거리 제어", "upside": "밀치기·한도 +1m", "downside": "", "text": "충격탄 밀치기와 탄창당 밀치기 한도 +1m."},
	"sequencer": {"name": "증폭 시퀀서", "kind": "module", "effect": "증폭", "value": "+1 ×2발", "role": "순서 증폭", "upside": "증폭 피해 +1", "downside": "", "text": "증폭탄이 뒤의 두 발에 주는 피해 +1."},
	"duplex": {"name": "복열 노리쇠", "kind": "module", "effect": "연발", "value": "+1 타격", "role": "배리어 · 집중", "upside": "연발 타격 +1", "downside": "", "text": "연발탄 타격 +1. 배리어와 쇄도 집중을 빠르게 전개합니다."},
	"igniter": {"name": "점화 약실", "kind": "module", "effect": "점화 추격", "value": "+2 피해", "role": "소이 후속", "upside": "화상 중인 적 피해 +2", "downside": "", "text": "화상 중인 적을 직접 타격할 때 피해 +2."},
	"breaker": {"name": "배리어 파쇄기", "kind": "module", "effect": "배리어", "value": "+1 파쇄", "role": "다중 타격", "upside": "타격당 배리어 1칸 추가 제거", "downside": "", "text": "각 타격이 배리어를 한 칸 더 제거합니다. 연발탄과 결합하면 빠르게 보호막을 걷어 냅니다."},
	"executioner": {"name": "처형 조준기", "kind": "module", "effect": "마무리", "value": "+2 피해", "role": "처치선 보정", "upside": "HP 5 이하 적 피해 +2", "downside": "", "text": "발사 직전 HP가 5 이하인 적에게 직접 피해 +2."},
	"reserve": {"name": "예비 급탄기", "kind": "module", "effect": "회수탄", "value": "+2 보급", "role": "기본탄 완충", "upside": "회수탄 보급 +2", "downside": "", "text": "탄창 크기는 유지하고 교전 시작과 재장전 때 회수탄을 2발 더 보급합니다."},
	"opening": {"name": "선두 격발기", "kind": "module", "effect": "첫 발", "value": "+2 피해", "role": "선두 설계", "upside": "탄창 첫 발 피해 +2", "downside": "", "text": "장전한 탄창의 첫 발 직접 피해 +2. 어떤 탄을 선두에 놓을지 결정합니다."},
	"afterburner": {"name": "후미 점화기", "kind": "module", "effect": "마지막 발", "value": "+3 피해", "role": "후미 결산", "upside": "탄창 마지막 발 피해 +3", "downside": "재장전 +1턴", "text": "탄창 마지막 발 직접 피해 +3. 재장전 비용이 1턴 증가합니다."},
	"field_press": {"name": "야전 압축기", "kind": "core", "effect": "현장 압축", "value": "+1회", "role": "압축 빌드", "upside": "교전마다 현장 압축 +1회", "downside": "탄창 −2칸", "text": "교전 시작마다 현장 압축 기회 +1. 대신 탄창 슬롯을 2칸 잃습니다."},
	"overbore": {"name": "과구경 총열", "kind": "core", "effect": "피해 · 관통", "value": "+2 · +2", "role": "짧은 고화력", "upside": "피해·관통 +2", "downside": "탄창 −1칸", "text": "모든 직접 피해와 관통 +2. 대신 탄창 슬롯을 1칸 잃습니다."},
	"inferno": {"name": "열폭주 노심", "kind": "core", "effect": "화상", "value": "+2", "role": "고열 소이", "upside": "화상 +2", "downside": "재장전 +1턴", "text": "소이탄 화상 +2. 열을 식히느라 재장전 비용이 1턴 증가합니다."},
	"arc_splitter": {"name": "분기 전이기", "kind": "core", "effect": "전이", "value": "+2 · 대상+1", "role": "물량 정리", "upside": "전이 피해 +2 · 대상 +1", "downside": "직접 피해 −1", "text": "전격탄 전이 피해 +2, 전이 대상 +1. 대신 모든 직접 피해 −1."},
	"momentum": {"name": "충격 피스톤", "kind": "core", "effect": "밀치기", "value": "+2m", "role": "극단 거리 제어", "upside": "밀치기·한도 +2m", "downside": "직접 피해 −1", "text": "충격탄 밀치기와 탄창당 한도 +2m. 대신 모든 직접 피해 −1."},
	"triad": {"name": "삼중 시퀀서", "kind": "core", "effect": "서로 다른 3발", "value": "+5 피해", "role": "혼합 순서", "upside": "서로 다른 3번째 탄 피해 +5", "downside": "회수탄 피해 −1", "text": "직전 두 발과 서로 다른 탄종을 세 번째로 발사하면 직접 피해 +5. 회수탄 직접 피해 −1."},
}

const MAX_EQUIPPED_PARTS := 5

const START_DECK := ["bore", "pierce", "precise", "charge", "push", "arc", "bore", "charge", "pierce", "precise"]
const GUN_DECKS := {
	"scatter": ["charge", "precise", "arc", "bore", "push", "pierce", "bore", "charge", "precise", "arc"],
	"heavy": ["bore", "arc", "charge", "bore", "push", "pierce", "bore", "charge", "precise", "arc"],
	"amplifier": ["charge", "precise", "push", "pierce", "bore", "arc", "charge", "precise", "push", "pierce"],
}

const ENEMY_NAMES := {
	"runner": "운반 사족체",
	"wall": "융합 장갑벽",
	"evader": "전도 선체",
	"caster": "신경 교란 부유체",
	"absorber": "흡수 장갑 구체",
	"stance": "태세 교란 드론",
}
const ENEMY_RULES := {
	"runner": "빠른 접근 · 충격탄으로 시간을 벌 수 있습니다.",
	"wall": "높은 장갑 · 관통이 남는 장갑만큼 피해 감소를 줄입니다.",
	"evader": "전도 선체 · 전격탄 주 타격에 추가 피해 2를 받습니다.",
	"caster": "3턴 충전 · 완료 시 자신을 제외한 모든 적을 2m 끌어당깁니다.",
	"absorber": "배리어 · 직접 타격을 수치와 관계없이 먼저 흡수합니다. 화상과 전이는 통과합니다.",
	"stance": "교대 장갑 · 적 전진 뒤 장갑이 4와 0 사이를 오갑니다.",
}
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

static func enemy_rule(enemy: Dictionary) -> String:
	var kind := str(enemy.get("kind", ""))
	var parts: PackedStringArray = []
	if int(enemy.get("barrier_max", 0)) > 0:
		parts.append("배리어 %d/%d" % [int(enemy.get("barrier", 0)), int(enemy.barrier_max)])
	if int(enemy.get("charge_max", 0)) > 0:
		parts.append("충전 %d/%d · 완료 시 다른 적 −%dm" % [int(enemy.get("charge", 0)), int(enemy.charge_max), int(enemy.get("charge_pull", 2))])
	if bool(enemy.get("stance", false)):
		parts.append("태세 장갑 %d → %d" % [int(enemy.def), 0 if bool(enemy.get("stance_closed", true)) else int(enemy.get("stance_def", 4))])
	if not parts.is_empty():
		return " · ".join(parts)
	return str(ENEMY_RULES.get(kind, ""))

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

static func equipped_parts(state: Dictionary) -> Array:
	var result: Array = []
	for value in state.get("equipped_parts", []):
		var id := str(value)
		if PARTS.has(id) and id != "none" and not result.has(id): result.append(id)
	var legacy := str(state.get("part", "none"))
	if PARTS.has(legacy) and legacy != "none" and not result.has(legacy): result.append(legacy)
	return result

static func has_part(state: Dictionary, id: String) -> bool:
	return equipped_parts(state).has(id)

static func is_core_part(id: String) -> bool:
	return PARTS.has(id) and str(PARTS[id].get("kind", "module")) == "core"

static func valid_part_set(gun: String, ids: Array) -> bool:
	if ids.size() > MAX_EQUIPPED_PARTS: return false
	var seen: Array = []
	var cores := 0
	for value in ids:
		var id := str(value)
		if id == "none" or seen.has(id) or not accepts_part(gun, id): return false
		seen.append(id)
		if is_core_part(id): cores += 1
	return cores <= 1

static func damage(id: String, state: Dictionary) -> int:
	var gun: Dictionary = GUNS[state.gun]
	var bonus := int(gun.get("basic_bonus", gun.bonus)) if id == "basic" else int(gun.bonus)
	var result := int(AMMO[id].dmg) * multiplier(state) + bonus
	if has_part(state, "overbore"): result += 2
	if has_part(state, "arc_splitter"): result -= 1
	if has_part(state, "momentum"): result -= 1
	if id == "basic" and has_part(state, "triad"): result -= 1
	return maxi(0, result)

static func penetration(id: String, state: Dictionary) -> int:
	return int(AMMO[id].pen) * multiplier(state) + (2 if has_part(state, "lens") else 0) + (2 if has_part(state, "overbore") else 0)

static func effect_value(id: String, state: Dictionary) -> int:
	var effect := str(AMMO[id].effect)
	var value := int(AMMO[id].value) * multiplier(state)
	if effect == "arc" and state.get("gun", "") == "heavy": value = 3
	if effect == "arc" and has_part(state, "capacitor"): value += 1
	if effect == "arc" and has_part(state, "arc_splitter"): value += 2
	if effect == "push" and has_part(state, "rammer"): value += 1
	if effect == "push" and has_part(state, "momentum"): value += 2
	if effect == "boost" and has_part(state, "sequencer"): value += 1
	return value

static func burn_damage(state: Dictionary) -> int:
	return 2 if state.get("gun", "") in ["heavy", "amplifier"] else 1

static func push_budget(state: Dictionary) -> int:
	return 2 * multiplier(state) + (1 if has_part(state, "rammer") else 0) + (2 if has_part(state, "momentum") else 0)

static func hit_count(id: String, state: Dictionary) -> int:
	var hits := int(AMMO[id].get("hits", 2 if str(AMMO[id].effect) == "double" else 1))
	if source_id(id) == "precise" and has_part(state, "duplex"): hits += 1
	return hits

static func weakness_bonus(id: String, enemy: Dictionary) -> int:
	return 2 if str(enemy.get("weakness", "")) == str(AMMO[id].attribute) else 0

static func chains(state: Dictionary) -> bool:
	return str(GUNS[state.gun].mode) == "chain"

static func capacity(state: Dictionary) -> int:
	var result := int(GUNS[state.gun].capacity) + int(state.get("capacity_bonus", 0))
	if has_part(state, "supply"): result += 1
	if has_part(state, "field_press"): result -= 2
	if has_part(state, "overbore"): result -= 1
	return maxi(1, result)

static func supply_capacity(state: Dictionary) -> int:
	return capacity(state) + (2 if has_part(state, "reserve") else 0)

static func reload_modifier(state: Dictionary) -> int:
	var value := -1 if has_part(state, "loader") else 0
	if has_part(state, "afterburner"): value += 1
	if has_part(state, "inferno"): value += 1
	return value

static func field_compression_bonus(state: Dictionary) -> int:
	return 1 if has_part(state, "field_press") else 0

static func arc_target_bonus(state: Dictionary) -> int:
	return 1 if has_part(state, "arc_splitter") else 0

static func start_deck(gun: String) -> Array:
	return GUN_DECKS.get(gun, START_DECK).duplicate()

static func accepts_part(gun: String, part: String) -> bool:
	return PARTS.has(part) and (part != "loader" or int(GUNS[gun].reload) > 1)

static func burn_amount(id: String, state: Dictionary) -> int:
	if str(AMMO[id].effect) != "burn": return 0
	var amount := int(AMMO[id].value)
	if has_part(state, "coil"): amount += 1
	if has_part(state, "inferno"): amount += 2
	return mini(6, amount)

static func is_compressed(id: String) -> bool:
	return AMMO.has(id) and bool(AMMO[id].get("compressed", false))

static func source_id(id: String) -> String:
	return str(AMMO[id].get("source", id)) if AMMO.has(id) else id

static func compressed_id(id: String) -> String:
	return str(COMPRESSIONS.get(id, ""))

static func field_id(id: String) -> String:
	return str(FIELD_COMPRESSIONS.get(id, ""))

static func is_temporary(id: String) -> bool:
	return AMMO.has(id) and bool(AMMO[id].get("temporary", false))

static func slot_cost(id: String) -> int:
	return int(AMMO[id].get("slot_cost", 1)) if AMMO.has(id) else 1

static func anchor(id: String) -> String:
	return str(AMMO[id].get("anchor", "")) if AMMO.has(id) else ""

static func slots_used(stack: Array) -> int:
	var total := 0
	for id in stack: total += slot_cost(str(id))
	return total

static func insertion_index(stack: Array, id: String) -> int:
	var rule := anchor(id)
	if rule == "first": return 0
	if rule == "last": return stack.size()
	for i in range(stack.size()):
		if anchor(str(stack[i])) == "last": return i
	return stack.size()

static func can_insert(stack: Array, id: String, capacity_value: int) -> bool:
	if not AMMO.has(id) or slots_used(stack) + slot_cost(id) > capacity_value: return false
	var rule := anchor(id)
	if rule.is_empty(): return true
	for loaded in stack:
		if anchor(str(loaded)) == rule: return false
	return true

static func valid_stack(stack: Array, capacity_value: int) -> bool:
	if slots_used(stack) > capacity_value: return false
	var first_seen := false
	var last_seen := false
	for i in range(stack.size()):
		var id := str(stack[i])
		if not AMMO.has(id): return false
		match anchor(id):
			"first":
				if first_seen or i != 0: return false
				first_seen = true
			"last":
				if last_seen or i != stack.size() - 1: return false
				last_seen = true
	return true

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
		var enemy := {"kind": e[0], "name": ENEMY_NAMES[e[0]], "hp": e[1], "max_hp": e[1], "def": e[2], "speed": e[3], "distance": e[4] + offset, "burn": 0, "lane": result.size()}
		if str(e[0]) == "evader": enemy.weakness = "electric"
		result.append(enemy)
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
