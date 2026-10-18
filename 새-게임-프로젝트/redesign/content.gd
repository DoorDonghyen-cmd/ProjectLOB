extends RefCounted
## Damage is transparent; scatter alone chooses a random primary target.
## Every round exposes two numbers, one attribute, and at most one effect.
const Variants = preload("res://redesign/ammo_variants.gd")
const BASE_AMMO := {
	"prepare": {"heat": 2, "name": "예약탄", "dmg": 0, "pen": 0, "attribute": "physical", "effect": "prepare", "value": 1, "text": "뒤의 탄환 1발을 다음 재장전 패로 예약합니다. 현장 압축탄은 제외하며 예약은 최대 3장. 탄을 복제하지 않습니다."},
	"disrupt": {"heat": 2, "name": "차단탄", "dmg": 0, "pen": 0, "attribute": "electric", "effect": "disrupt", "value": 1, "text": "생존 표적의 발사 준비·충전을 1턴 멈춥니다. 이동과 이미 발사된 압력탄에는 영향이 없으며, 적마다 한 번만 차단할 수 있습니다."},
	"spread": {"heat": 2, "name": "불씨탄", "dmg": 0, "pen": 0, "attribute": "fire", "effect": "spread", "value": 2, "text": "표적의 화상 최대 2를 가장 가까운 다른 생존 적에게 옮깁니다. 원래 표적의 화상은 옮긴 만큼 줄어듭니다. 압력탄은 제외합니다."},
	"sequence": {"heat": 3, "name": "연계탄", "dmg": 1, "pen": 1, "attribute": "physical", "effect": "sequence", "value": 2, "text": "이번 탄창에서 앞서 발사한 다른 탄종 하나마다 피해 +2, 최대 3종. 같은 탄과 그 압축형은 한 종류로 셉니다."},
	"vent": {"heat": 0, "name": "열방출탄", "dmg": 1, "pen": 1, "attribute": "physical", "effect": "vent", "value": 2, "heat_spend": 4, "anchor": "last", "text": "가장 먼저 장전하며 마지막에 발사합니다. 발사 직전 열을 최대 4 소모하고, 소모한 열 1마다 직접 피해 +2. 앞에서 과열되면 발사되지 않습니다."},
	"thermal": {"heat": 4, "name": "고열탄", "dmg": 1, "pen": 1, "attribute": "physical", "effect": "thermal", "value": 4, "text": "발사 직전 열이 무기 한계의 절반 이상이면 직접 피해 +4. 자신의 발열로는 조건을 채우지 못합니다."},
	"basic": {"heat": 1, "name": "기본탄", "dmg": 2, "pen": 0, "attribute": "physical", "effect": "", "value": 0, "text": "발열 1의 물리 탄환. 덱에서 한 장씩 뽑고, 사용 후 버린 더미로 이동합니다."},
	"pierce": {"heat": 3, "name": "철갑탄", "dmg": 2, "pen": 3, "attribute": "physical", "effect": "", "value": 0, "text": "높은 관통으로 장갑을 곧바로 뚫는 물리탄입니다."},
	"push": {"heat": 2, "name": "충격탄", "dmg": 1, "pen": 0, "attribute": "physical", "effect": "push", "value": 2, "text": "적을 2m 밀어 거리를 벌리고 다음 표적을 바꿉니다. 탄창당 총 2m까지 밀 수 있습니다."},
	"bore": {"heat": 2, "name": "소이탄", "dmg": 1, "pen": 1, "attribute": "fire", "effect": "burn", "value": 3, "text": "생존한 적에게 화상 3을 남깁니다. 화상은 적의 전진 직전에 1피해를 주고 1 감소합니다."},
	"charge": {"heat": 3, "name": "증폭탄", "dmg": 0, "pen": 0, "attribute": "physical", "effect": "boost", "value": 3, "boost_rounds": 1, "text": "다음 공격탄 1발의 타격당 피해 +3. 지원탄은 소비하지 않습니다. 일반·잔열 증폭은 마지막 효과로 교체됩니다. 연타의 각 타격에 적용됩니다."},
	"charge_heat": {"heat": 1, "name": "잔열 증폭탄", "dmg": 0, "pen": 0, "attribute": "physical", "effect": "boost", "value": 6, "boost_rounds": 1, "boost_hot": true, "text": "다음 공격 직전 열이 무기 한계의 절반 이상이면 타격당 피해 +6. 낮으면 강화 없이 소비합니다. 공격 자체의 발열은 조건에서 제외. 일반 증폭과 교체되며 냉각 순서에 주의."},
	"charge_hot": {"heat": 5, "name": "배율탄", "dmg": 0, "pen": 0, "attribute": "physical", "effect": "boost", "value": 0, "boost_factor": 2, "boost_rounds": 1, "boost_heat": 3, "text": "다음 공격탄의 타격당 피해 ×2. 증폭을 더한 뒤 배율을 적용하고 장갑을 차감합니다. 강화받은 공격은 추가 발열 +3. 같은 배율은 중첩되지 않습니다. 준비 발열 5."},
	"precise": {"heat": 4, "name": "연타탄", "dmg": 2, "pen": 0, "attribute": "physical", "effect": "double", "value": 2, "text": "같은 적을 2회 타격합니다. 증폭 피해도 두 타격에 각각 적용됩니다."},
	"arc": {"heat": 3, "name": "전격탄", "dmg": 2, "pen": 1, "attribute": "electric", "effect": "arc", "value": 2, "text": "주 표적을 공격한 뒤 가장 가까운 다른 생존 적에게 고정 2피해를 전이합니다."},
	"shatter": {"heat": 1, "name": "파쇄탄", "dmg": 0, "pen": 0, "attribute": "physical", "effect": "shatter", "value": 3, "text": "직접 피해 없이 장갑을 3 낮춥니다. 배리어를 소모하지 않고 장갑에 적용됩니다. 후속 탄환 모두가 낮아진 장갑을 공격합니다."},
	"detonate": {"heat": 3, "name": "기폭탄", "dmg": 0, "pen": 0, "attribute": "fire", "effect": "detonate", "value": 1, "text": "타격 후 남은 화상의 총 피해를 즉시 입히고 화상을 없앱니다. 기폭 피해는 장갑과 배리어를 무시합니다. 먼저 소이탄으로 불을 붙이세요."},
	"chase": {"heat": 3, "name": "추격탄", "dmg": 1, "pen": 1, "attribute": "physical", "effect": "chase", "value": 4, "text": "이 탄창의 직전 탄환이 적을 처치했다면 피해 +4. 전이 처치도 인정하며, 압력탄 요격과 턴 종료 화상 처치는 인정하지 않습니다."},
	"bypass": {"heat": 2, "name": "우회탄", "dmg": 2, "pen": 1, "attribute": "physical", "effect": "bypass", "value": 1, "text": "가장 앞선 적을 건너뛰고 두 번째 적을 공격합니다. 산개는 앞 적을 제외한 적 중 무작위. 적이 하나면 그 적을 공격하고, 최근접 압력탄은 먼저 요격합니다."},
	"cool": {"heat": 0, "name": "냉각탄", "dmg": 0, "pen": 0, "attribute": "physical", "effect": "cool", "value": 3, "text": "현재 열을 3 낮춥니다. 직접 피해가 없고 강화 효과를 소비하지 않습니다. 과열에 도달하기 전에 배치하세요. 열은 0 아래로 내려가지 않습니다."},
	# Compressed rounds keep the family name. Their silhouette and magazine fit
	# communicate the variant in combat; prose lives only in inspection surfaces.
	"pierce_c": {"heat": 5, "name": "철갑탄", "dmg": 5, "pen": 6, "attribute": "physical", "effect": "", "value": 0, "compressed": true, "source": "pierce", "slot_cost": 2, "anchor": "", "text": "두 철갑탄을 한 발에 집약합니다. 탄창 2칸을 차지하지만 높은 장갑을 한 번에 관통합니다."},
	"push_c": {"heat": 4, "name": "충격탄", "dmg": 2, "pen": 0, "attribute": "physical", "effect": "push", "value": 3, "push_budget_bonus": 1, "compressed": true, "source": "push", "slot_cost": 1, "anchor": "last", "text": "가장 먼저 장전하며 마지막에 발사합니다. 강한 충격으로 적의 다음 접근 거리를 벌립니다."},
	"bore_c": {"heat": 4, "name": "소이탄", "dmg": 1, "pen": 1, "attribute": "fire", "effect": "burn", "value": 6, "compressed": true, "source": "bore", "slot_cost": 2, "anchor": "", "text": "탄창 2칸을 차지하고 화상을 한 발에 최대치까지 축적합니다."},
	"charge_c": {"heat": 5, "name": "증폭탄", "dmg": 0, "pen": 0, "attribute": "physical", "effect": "boost", "value": 4, "boost_rounds": 2, "compressed": true, "source": "charge", "slot_cost": 1, "anchor": "last", "text": "가장 먼저 장전하며 마지막에 발사합니다. 남긴 증폭은 다음 탄창의 첫 공격탄 두 발로 이어집니다. 지원탄은 소비하지 않으며 다른 증폭과 더해집니다."},
	"precise_c": {"heat": 6, "name": "연타탄", "dmg": 3, "pen": 0, "attribute": "physical", "effect": "double", "value": 3, "hits": 3, "compressed": true, "source": "precise", "slot_cost": 1, "anchor": "first", "text": "가장 마지막에 장전하며 첫 발로 같은 적을 3회 타격합니다."},
	"arc_c": {"heat": 6, "name": "전격탄", "dmg": 4, "pen": 1, "attribute": "electric", "effect": "arc", "value": 2, "arc_targets": 99, "compressed": true, "source": "arc", "slot_cost": 1, "anchor": "first", "text": "가장 마지막에 장전하며 첫 발로 주 표적을 제외한 모든 생존 적에게 전이합니다."},
	# Field-compressed rounds are encounter-only mirrors. They use the same combat
	# profile and fittings as permanent compression, then split back into the two
	# source rounds when fired or discarded.
	"pierce_f": {"heat": 5, "name": "철갑탄", "dmg": 5, "pen": 6, "attribute": "physical", "effect": "", "value": 0, "compressed": true, "temporary": true, "source": "pierce", "slot_cost": 2, "anchor": "", "text": "이번 교전에서 두 철갑탄을 한 발에 임시 집약합니다."},
	"push_f": {"heat": 4, "name": "충격탄", "dmg": 2, "pen": 0, "attribute": "physical", "effect": "push", "value": 3, "push_budget_bonus": 1, "compressed": true, "temporary": true, "source": "push", "slot_cost": 1, "anchor": "last", "text": "이번 교전에서 두 충격탄을 마지막 한 발로 임시 집약합니다."},
	"bore_f": {"heat": 4, "name": "소이탄", "dmg": 1, "pen": 1, "attribute": "fire", "effect": "burn", "value": 6, "compressed": true, "temporary": true, "source": "bore", "slot_cost": 2, "anchor": "", "text": "이번 교전에서 두 소이탄을 한 발에 임시 집약합니다."},
	"charge_f": {"heat": 5, "name": "증폭탄", "dmg": 0, "pen": 0, "attribute": "physical", "effect": "boost", "value": 4, "boost_rounds": 2, "compressed": true, "temporary": true, "source": "charge", "slot_cost": 1, "anchor": "last", "text": "이번 교전에서 두 증폭탄을 마지막 한 발로 임시 집약합니다."},
	"precise_f": {"heat": 6, "name": "연타탄", "dmg": 3, "pen": 0, "attribute": "physical", "effect": "double", "value": 3, "hits": 3, "compressed": true, "temporary": true, "source": "precise", "slot_cost": 1, "anchor": "first", "text": "이번 교전에서 두 연타탄을 첫 한 발로 임시 집약합니다."},
	"arc_f": {"heat": 6, "name": "전격탄", "dmg": 4, "pen": 1, "attribute": "electric", "effect": "arc", "value": 2, "arc_targets": 99, "compressed": true, "temporary": true, "source": "arc", "slot_cost": 1, "anchor": "first", "text": "이번 교전에서 두 전격탄을 첫 한 발로 임시 집약합니다."},
	# Advanced profiles preserve each family; field copies use identical rules.
	"prepare_c": {"heat": 3, "name": "예약탄", "dmg": 0, "pen": 0, "attribute": "physical", "effect": "prepare", "value": 2, "text": "뒤의 전술탄 2발을 다음 패로 예약합니다. 탄창 2칸을 차지하며 총 예약 한도 3장은 유지됩니다.", "slot_cost": 2, "compressed": true, "source": "prepare"},
	"prepare_f": {"heat": 3, "name": "예약탄", "dmg": 0, "pen": 0, "attribute": "physical", "effect": "prepare", "value": 2, "text": "임시 고급 · 발사 또는 재장전 시 원본 두 장으로 복원. 뒤의 전술탄 2발을 다음 패로 예약합니다. 탄창 2칸을 차지하며 총 예약 한도 3장은 유지됩니다.", "slot_cost": 2, "compressed": true, "source": "prepare", "temporary": true},
	"disrupt_c": {"heat": 4, "name": "차단탄", "dmg": 0, "pen": 0, "attribute": "electric", "effect": "disrupt", "value": 2, "text": "첫 발 고정. 생존 표적의 발사 준비·충전을 2턴 멈춥니다. 이동과 이미 발사된 탄에는 효과가 없고 적마다 한 번만 적용합니다.", "anchor": "first", "compressed": true, "source": "disrupt"},
	"disrupt_f": {"heat": 4, "name": "차단탄", "dmg": 0, "pen": 0, "attribute": "electric", "effect": "disrupt", "value": 2, "text": "임시 고급 · 발사 또는 재장전 시 원본 두 장으로 복원. 첫 발 고정. 생존 표적의 발사 준비·충전을 2턴 멈춥니다. 이동과 이미 발사된 탄에는 효과가 없고 적마다 한 번만 적용합니다.", "anchor": "first", "compressed": true, "source": "disrupt", "temporary": true},
	"spread_c": {"heat": 4, "name": "불씨탄", "dmg": 0, "pen": 0, "attribute": "fire", "effect": "spread", "value": 4, "text": "화상 최대 4를 가장 가까운 다른 생존 적에게 옮깁니다. 탄창 2칸을 차지하며 원래 적의 화상은 옮긴 만큼 줄어듭니다.", "slot_cost": 2, "compressed": true, "source": "spread"},
	"spread_f": {"heat": 4, "name": "불씨탄", "dmg": 0, "pen": 0, "attribute": "fire", "effect": "spread", "value": 4, "text": "임시 고급 · 발사 또는 재장전 시 원본 두 장으로 복원. 화상 최대 4를 가장 가까운 다른 생존 적에게 옮깁니다. 탄창 2칸을 차지하며 원래 적의 화상은 옮긴 만큼 줄어듭니다.", "slot_cost": 2, "compressed": true, "source": "spread", "temporary": true},
	"sequence_c": {"heat": 5, "name": "연계탄", "dmg": 1, "pen": 1, "attribute": "physical", "effect": "sequence", "value": 3, "text": "마지막 발 고정. 앞서 발사한 다른 탄종마다 피해 +3, 최대 3종. 높은 발열을 감당할 공간을 남겨야 합니다.", "anchor": "last", "compressed": true, "source": "sequence"},
	"sequence_f": {"heat": 5, "name": "연계탄", "dmg": 1, "pen": 1, "attribute": "physical", "effect": "sequence", "value": 3, "text": "임시 고급 · 발사 또는 재장전 시 원본 두 장으로 복원. 마지막 발 고정. 앞서 발사한 다른 탄종마다 피해 +3, 최대 3종. 높은 발열을 감당할 공간을 남겨야 합니다.", "anchor": "last", "compressed": true, "source": "sequence", "temporary": true},
	"vent_c": {"heat": 0, "name": "열방출탄", "dmg": 1, "pen": 1, "attribute": "physical", "effect": "vent", "value": 3, "heat_spend": 6, "anchor": "last", "text": "마지막 발 고정·탄창 2칸. 발사 직전 열을 최대 6 소모하고 열 1마다 피해 +3. 앞에서 과열되면 발사할 수 없습니다.", "slot_cost": 2, "compressed": true, "source": "vent"},
	"vent_f": {"heat": 0, "name": "열방출탄", "dmg": 1, "pen": 1, "attribute": "physical", "effect": "vent", "value": 3, "heat_spend": 6, "anchor": "last", "text": "임시 고급 · 발사 또는 재장전 시 원본 두 장으로 복원. 마지막 발 고정·탄창 2칸. 발사 직전 열을 최대 6 소모하고 열 1마다 피해 +3. 앞에서 과열되면 발사할 수 없습니다.", "slot_cost": 2, "compressed": true, "source": "vent", "temporary": true},
	"thermal_c": {"heat": 6, "name": "고열탄", "dmg": 3, "pen": 1, "attribute": "physical", "effect": "thermal", "value": 6, "text": "발사 직전 열이 무기 한계의 절반 이상이면 피해 +6. 발열 6으로 강제 재장전 위험이 커집니다. 자신의 발열로 조건을 채우지 않습니다.", "compressed": true, "source": "thermal"},
	"thermal_f": {"heat": 6, "name": "고열탄", "dmg": 3, "pen": 1, "attribute": "physical", "effect": "thermal", "value": 6, "text": "임시 고급 · 발사 또는 재장전 시 원본 두 장으로 복원. 발사 직전 열이 무기 한계의 절반 이상이면 피해 +6. 발열 6으로 강제 재장전 위험이 커집니다. 자신의 발열로 조건을 채우지 않습니다.", "compressed": true, "source": "thermal", "temporary": true},
	"shatter_c": {"heat": 3, "name": "파쇄탄", "dmg": 0, "pen": 0, "attribute": "physical", "effect": "shatter", "value": 5, "text": "첫 발 고정. 직접 피해 없이 장갑을 5 낮춥니다. 배리어를 소모하지 않고 장갑에 적용됩니다.", "anchor": "first", "compressed": true, "source": "shatter"},
	"shatter_f": {"heat": 3, "name": "파쇄탄", "dmg": 0, "pen": 0, "attribute": "physical", "effect": "shatter", "value": 5, "text": "임시 고급 · 발사 또는 재장전 시 원본 두 장으로 복원. 첫 발 고정. 직접 피해 없이 장갑을 5 낮춥니다. 배리어를 소모하지 않고 장갑에 적용됩니다.", "anchor": "first", "compressed": true, "source": "shatter", "temporary": true},
	"detonate_c": {"heat": 5, "name": "기폭탄", "dmg": 0, "pen": 0, "attribute": "fire", "effect": "detonate", "value": 1, "text": "마지막 발 고정. 남은 화상의 총 피해를 두 배로 기폭하고 화상을 없앱니다. 장갑·배리어를 무시하지만 화상이 없으면 기폭 피해도 없습니다.", "detonate_scale": 2, "anchor": "last", "compressed": true, "source": "detonate"},
	"detonate_f": {"heat": 5, "name": "기폭탄", "dmg": 0, "pen": 0, "attribute": "fire", "effect": "detonate", "value": 1, "text": "임시 고급 · 발사 또는 재장전 시 원본 두 장으로 복원. 마지막 발 고정. 남은 화상의 총 피해를 두 배로 기폭하고 화상을 없앱니다. 장갑·배리어를 무시하지만 화상이 없으면 기폭 피해도 없습니다.", "detonate_scale": 2, "anchor": "last", "compressed": true, "source": "detonate", "temporary": true},
	"chase_c": {"heat": 5, "name": "추격탄", "dmg": 2, "pen": 1, "attribute": "physical", "effect": "chase", "value": 7, "text": "직전 탄환이 적을 처치했다면 피해 +7. 발열 5. 전이 처치는 인정하며 요격·턴 종료 화상 처치는 제외합니다.", "compressed": true, "source": "chase"},
	"chase_f": {"heat": 5, "name": "추격탄", "dmg": 2, "pen": 1, "attribute": "physical", "effect": "chase", "value": 7, "text": "임시 고급 · 발사 또는 재장전 시 원본 두 장으로 복원. 직전 탄환이 적을 처치했다면 피해 +7. 발열 5. 전이 처치는 인정하며 요격·턴 종료 화상 처치는 제외합니다.", "compressed": true, "source": "chase", "temporary": true},
	"bypass_c": {"heat": 4, "name": "우회탄", "dmg": 4, "pen": 2, "attribute": "physical", "effect": "bypass", "value": 1, "text": "첫 발 고정. 앞 적을 건너뛰어 두 번째 적을 공격합니다. 발열 4. 산개는 앞 적을 제외한 무작위 표적, 최근접 압력탄 요격은 우선합니다.", "anchor": "first", "compressed": true, "source": "bypass"},
	"bypass_f": {"heat": 4, "name": "우회탄", "dmg": 4, "pen": 2, "attribute": "physical", "effect": "bypass", "value": 1, "text": "임시 고급 · 발사 또는 재장전 시 원본 두 장으로 복원. 첫 발 고정. 앞 적을 건너뛰어 두 번째 적을 공격합니다. 발열 4. 산개는 앞 적을 제외한 무작위 표적, 최근접 압력탄 요격은 우선합니다.", "anchor": "first", "compressed": true, "source": "bypass", "temporary": true},
	"cool_c": {"heat": 0, "name": "냉각탄", "dmg": 0, "pen": 0, "attribute": "physical", "effect": "cool", "value": 5, "text": "첫 발 고정. 현재 열을 5 낮춥니다. 중간 발열을 식히는 용도로 배치할 수 없고 직접 피해가 없고 강화 효과를 소비하지 않습니다.", "anchor": "first", "compressed": true, "source": "cool"},
	"cool_f": {"heat": 0, "name": "냉각탄", "dmg": 0, "pen": 0, "attribute": "physical", "effect": "cool", "value": 5, "text": "임시 고급 · 발사 또는 재장전 시 원본 두 장으로 복원. 첫 발 고정. 현재 열을 5 낮춥니다. 중간 발열을 식히는 용도로 배치할 수 없고 직접 피해가 없고 강화 효과를 소비하지 않습니다.", "anchor": "first", "compressed": true, "source": "cool", "temporary": true},
}

const BASE_COMPRESSIONS := {
	"prepare": "prepare_c",
	"disrupt": "disrupt_c",
	"spread": "spread_c",
	"sequence": "sequence_c",
	"vent": "vent_c",
	"thermal": "thermal_c",
	"shatter": "shatter_c",
	"detonate": "detonate_c",
	"chase": "chase_c",
	"bypass": "bypass_c",
	"cool": "cool_c",

	"pierce": "pierce_c",
	"push": "push_c",
	"bore": "bore_c",
	"charge": "charge_c",
	"precise": "precise_c",
	"arc": "arc_c",
}

const BASE_FIELD_COMPRESSIONS := {
	"prepare": "prepare_f",
	"disrupt": "disrupt_f",
	"spread": "spread_f",
	"sequence": "sequence_f",
	"vent": "vent_f",
	"thermal": "thermal_f",
	"shatter": "shatter_f",
	"detonate": "detonate_f",
	"chase": "chase_f",
	"bypass": "bypass_f",
	"cool": "cool_f",

	"pierce": "pierce_f",
	"push": "push_f",
	"bore": "bore_f",
	"charge": "charge_f",
	"precise": "precise_f",
	"arc": "arc_f",
}

static var AMMO: Dictionary = Variants.build(BASE_AMMO)
static var COMPRESSIONS: Dictionary = Variants.compressions(BASE_COMPRESSIONS)
static var FIELD_COMPRESSIONS: Dictionary = Variants.compressions(BASE_FIELD_COMPRESSIONS, true)

const GUNS := {
	"single": {"reload_cooling": 8, "heat_limit": 12, "name": "보행자", "role": "전술탄 조합 입문", "capacity": 4, "reload": 1, "bonus": 1, "basic_bonus": 1, "mode": "chain", "identity": "공격탄 피해 +1 · 재장전 1턴", "recommendation": "약점탄과 증폭 연계를 섞는 안정형", "text": "전탄 연쇄 · 공격탄 피해 +1 / 기본탄 +1 · 증폭·파쇄·냉각 제외 · 재장전 1턴"},
	"burst": {"reload_cooling": 9, "heat_limit": 14, "name": "쇄도", "role": "집중 적중", "capacity": 4, "reload": 2, "bonus": 0, "mode": "chain", "identity": "같은 적 3회 적중마다 추가 피해 4", "recommendation": "증폭 → 연타 · 3번째 타격 계산", "text": "전탄 연쇄 · 주 타격 3회마다 고정 추가 피해 4 · 재장전 2턴"},
	"scatter": {"reload_cooling": 12, "heat_limit": 16, "name": "산개", "role": "무작위 분산", "capacity": 5, "reload": 2, "bonus": 0, "mode": "chain", "identity": "탄환마다 무작위 표적 · 넉넉한 탄창", "recommendation": "표적별 확률 · 분산 피해와 전격", "text": "전탄 연쇄 · 생존 적 중 균등 무작위 표적 · 탄창 5칸 / 재장전 2턴"},
	"heavy": {"reload_cooling": 6, "heat_limit": 13, "name": "압쇄", "role": "속성 특화", "capacity": 4, "reload": 1, "bonus": 0, "mode": "chain", "identity": "화상 턴당 피해 2 · 전이 피해 3", "recommendation": "소이 지속 피해 · 전격 전이", "text": "전탄 연쇄 · 소이 화상 피해 2 / 전격 전이 피해 3 · 재장전 1턴"},
	"amplifier": {"reload_cooling": 7, "heat_limit": 10, "name": "증강", "role": "한 발 효과 강화", "capacity": 3, "reload": 1, "bonus": 0, "mode": "single", "identity": "단발 2배 · 처치 시 연속", "recommendation": "증폭 +6 · 연타 4×2 · 충격 4m", "text": "1발 발사 · 주 표적 처치 시 계속 · 기본 피해/관통과 효과 강도 2배 · 타격 수/지속 기간 유지 · 재장전 1턴"},
}

# Equipment rules stay independent from visual outfit assets.
const MAX_BAG_CAPACITY := 10
const BAG_VERSION := 2
const LEGACY_OUTFIT_HAND := {"work": 6, "carrier": 7, "scout": 5}
const OUTFITS := {
	"work": {"name": "기본 작업복", "hand": 5, "exchange": 1, "role": "균형 있는 준비", "text": "5장 중 고르고, 필요 없는 탄을 1회 교환합니다."},
	"carrier": {"name": "운반용 외투", "hand": 6, "exchange": 0, "role": "넓은 선택 · 교환 없음", "text": "6장을 한 번에 확인합니다. 복장 기본 패 교환은 없습니다."},
	"scout": {"name": "정찰용 작업복", "hand": 4, "exchange": 2, "role": "작은 가방 · 빠른 탐색", "text": "4장 중 고르고, 필요 없는 탄을 최대 2회 교환합니다."},
	"heatworker": {"name": "배관공 방열복", "hand": 7, "exchange": 0, "role": "넓은 수납 · 교환 없음", "text": "7장을 한 번에 확인합니다. 복장 기본 패 교환은 없습니다."},
	"hoist": {"name": "승강로 인양 장구", "hand": 8, "exchange": 0, "role": "넓은 수납 · 교환 없음", "text": "8장을 한 번에 확인합니다. 복장 기본 패 교환은 없습니다."},
	"recovery": {"name": "봉쇄구역 회수 장구", "hand": 9, "exchange": 0, "role": "넓은 수납 · 교환 없음", "text": "9장을 한 번에 확인합니다. 복장 기본 패 교환은 없습니다."},
	"expedition": {"name": "밀폐형 원정복", "hand": 10, "exchange": 0, "role": "넓은 수납 · 교환 없음", "text": "10장을 한 번에 확인합니다. 복장 기본 패 교환은 없습니다."},
}

static func valid_bag_state(state: Dictionary) -> bool:
	if not state.has("bag_version"): return not state.has("bag_upgrades")
	if not state.bag_version is int and not state.bag_version is float: return false
	if state.bag_version != BAG_VERSION or not OUTFITS.has(state.get("outfit", "")): return false
	var upgrades = state.get("bag_upgrades", -1)
	if not upgrades is int and not upgrades is float: return false
	return upgrades == int(upgrades) and upgrades >= 0 and upgrades <= MAX_BAG_CAPACITY - int(OUTFITS[state.outfit].hand)

static func outfit_name(state: Dictionary) -> String:
	return str(OUTFITS[state.outfit].name) if OUTFITS.has(state.get("outfit", "")) else "기존 가방"

const PARTS := {
	"volley_drive": {"grade": 1, "name": "연쇄 구동핵", "kind": "core", "effect": "타격 성장", "value": "타격 +1 · 잔타 연결", "role": "여러 타격을 전열로", "upside": "타격당 피해 +1 · 남은 타격은 최근접 적으로", "downside": "다회 타격탄 열 +1", "text": "초기 보너스는 직접 타격당 피해 +1. 표적 처치 후 남은 타격은 최근접 표적으로 이어집니다(대상의 장갑·배리어 적용, 속성 효과 재발동 없음). 다회 타격탄 열 +1. 한 전투에서 피해 타격 3회 후 승리하면 추가 피해 +1 성장, 최대 +9. 이번 등반에 유지."},
	"thermal_drive": {"grade": 1, "name": "열압 구동핵", "kind": "core", "effect": "고열 배율 성장", "value": "고열 ×1.50", "heat_limit": -2, "role": "잔열을 큰 화력으로", "upside": "고열 직접 피해 ×1.50 · 열 한계에서 충격파", "downside": "열 한계 −2", "text": "발사 직전 열이 한계의 절반 이상이면 직접 타격 피해를 초기 ×1.50(장갑 차감 전, 소수점 버림)로 강화합니다. 고열 직접 피해를 주고 승리하면 배율 +0.25 성장, 최대 ×3.50. 전투당 1회 성장, 이번 등반 유지. 자신의 발열로 고열 조건을 채우지 않습니다. 고열 공격이 열 한계에 도달해 직접 피해를 주면, 나머지 전열에 장갑 차감 전 1회 타격 피해의 절반을 충격파로 전달합니다. 충격파는 각 대상의 장갑을 적용하고 배리어에 막힙니다. 열 한계 −2."},
	"siege_drive": {"grade": 1, "name": "돌파 구동핵", "kind": "core", "effect": "단타 배율 성장", "value": "단타 ×2.00 · 관통 잔량", "capacity": -1, "role": "큰 한 발로 전열 돌파", "upside": "1회 타격 탄 피해 ×2 · 초과 피해 전달", "downside": "탄창 −1칸", "text": "1회 타격 공격탄의 초기 직접 피해 배율 ×2.00. 처치한 적의 초과 피해를 최근접 표적으로 전달하며 장갑을 다시 차감합니다. 배리어는 잔량을 막습니다. 한 탄의 직접 피해(전달 포함) 8 이상 후 승리하면 배율 +0.25, 최대 ×4.00. 전투당 1회 성장, 이번 등반 유지. 탄창 −1칸. 기폭·전이 피해는 배율/전달 제외."},
	"ordinary_chain": {"grade": 1, "name": "교차 급탄기", "kind": "module", "effect": "마지막 공격 강화", "value": "최대 +6", "role": "탄종 집약", "upside": "마지막 공격탄: 앞선 다른 탄종마다 피해 +2", "downside": "", "text": "탄창의 마지막 공격탄에 앞서 발사한 다른 탄종마다 타격당 피해 +2, 최대 +6. 위력·개조·압축이 달라도 같은 탄종으로 셉니다. 뒤의 지원탄은 마지막 공격 판정에 영향을 주지 않습니다."},
	"compression_sink": {"grade": 1, "name": "압축 안정기", "kind": "module", "effect": "일반탄 다음 압축", "value": "발열 −2", "heat_limit": -1, "role": "압축탄 준비", "upside": "일반탄 직후 압축탄 발열 −2", "downside": "열 한계 −1", "text": "같은 탄창에서 일반 전술탄 바로 다음에 쏘는 영구·임시 압축탄의 발생 열 −2(최소 0). 기본탄은 준비에 포함하지 않습니다. 열 한계 −1, 점유 칸·첫/마지막 발 제약은 유지합니다."},
	"cooling_breech": {"grade": 1, "name": "냉각 약실", "kind": "core", "effect": "재장전 냉각", "value": "+4", "capacity": -1, "reload_cooling": 4, "role": "짧은 탄창 순환", "upside": "재장전 냉각 +4", "downside": "탄창 −1칸", "text": "탄창 −1칸, 일반 재장전 냉각 +4. 무기의 재장전 턴은 그대로이며 짧은 사격을 자주 순환하는 구성입니다."},
	"chain_sink": {"grade": 1, "name": "연쇄 방열기", "kind": "module", "effect": "세 번째 발 냉각", "value": "열 −3", "heat_limit": -1, "third_cooling": 3, "role": "긴 탄창의 연결점", "upside": "탄창 세 번째 탄 열 −3", "downside": "열 한계 −1", "text": "탄창의 세 번째 탄이 발사되면 과열 판정 전에 열 −3. 대신 열 한계 −1. 세 번째 발에 도달하지 못하면 냉각되지 않습니다."},
	"indexer": {"grade": 1, "name": "예약 급탄기", "kind": "module", "effect": "예약탄", "value": "예약 +1장", "prepare_bonus": 1, "role": "다음 패 조합", "upside": "예약탄이 예약하는 탄 +1장", "downside": "", "text": "예약탄 뒤에서 다음 패로 예약할 전술탄 +1장. 예약탄 뒤에 실제로 장전한 탄만 대상으로 하며 총 예약은 최대 3장입니다."},
	"radiator": {"grade": 0, "name": "확장 방열판", "kind": "module", "effect": "열 한계", "value": "+3", "heat_limit": 3, "role": "안정적인 연쇄", "upside": "열 한계 +3", "downside": "", "text": "총기의 열 한계 +3. 더 많은 고발열탄을 한 번의 사격에 조합할 수 있습니다."},
	"reclaimer": {"grade": 1, "name": "회수 순환펌프", "kind": "module", "effect": "처치 냉각", "value": "열 −2", "cool_on_kill": 2, "role": "처치로 연쇄 유지", "upside": "처치한 탄 열 −2", "downside": "", "text": "탄환의 직접 타격·기폭·전이로 적을 처치하면 열 −2. 한 탄에 한 번, 과열 판정 전에 적용합니다. 요격과 턴 경과 화상은 제외합니다."},
	"ember_core": {"grade": 2, "name": "잔열 노심", "kind": "core", "effect": "고열 화력", "value": "피해 +2", "heat_limit": -2, "hot_damage": 2, "role": "한계 직전의 화력", "upside": "절반 열 이상에서 피해 +2", "downside": "열 한계 −2", "text": "발사 직전 열이 최종 열 한계의 절반 이상이면 타격당 피해 +2. 대신 열 한계 −2. 자신의 발열로 조건을 채우지 못합니다."},
	"none": {"grade": -1, "name": "빈 파츠 슬롯", "kind": "empty", "effect": "장착", "value": "0 / 5", "role": "전투 사이 무료 교체", "upside": "", "downside": "", "text": "파츠를 최대 5개 장착할 수 있습니다. 코어 파츠는 한 개만 장착합니다."},
	"lens": {"grade": 0, "name": "가속 총열", "kind": "module", "effect": "관통탄 강화", "value": "관통 +2", "role": "관통탄 특화", "upside": "원래 관통이 있는 탄 관통 +2", "downside": "", "text": "탄환 자체 관통이 1 이상인 탄의 관통 +2. 기본탄이나 관통 없는 탄에 새 관통을 부여하지 않습니다. 철갑·우회 등 관통탄을 강화합니다."},
	"loader": {"grade": 1, "name": "회수 가속기", "kind": "module", "effect": "재장전", "value": "−1턴", "role": "빠른 순환", "upside": "재장전 −1턴", "downside": "", "text": "재장전 비용 −1턴 (최소 1턴)."},
	"supply": {"grade": 1, "name": "확장 탄창", "kind": "module", "effect": "탄창", "value": "+1칸", "role": "긴 연쇄", "upside": "탄창 +1칸", "downside": "", "text": "탄창 +1칸. 뽑은 탄환으로 더 긴 순서를 설계합니다. 가방 크기는 늘어나지 않습니다."},
	"coil": {"grade": 0, "name": "열축전 코일", "kind": "module", "effect": "화상", "value": "+1", "role": "지속 피해", "upside": "화상 +1", "downside": "", "text": "소이탄이 남기는 화상 +1. 불씨탄의 화상 이동 한도 +1."},
	"capacitor": {"grade": 0, "name": "전이 축전기", "kind": "module", "effect": "전이", "value": "+1 피해", "role": "다수전 전이", "upside": "전이 피해 +1", "downside": "", "text": "전격탄의 전이 피해 +1. 많은 적을 동시에 정리하는 빌드를 강화합니다."},
	"rammer": {"grade": 0, "name": "충격 가이드", "kind": "module", "effect": "밀치기", "value": "+1m", "role": "거리 제어", "upside": "밀치기·한도 +1m", "downside": "", "text": "충격탄 밀치기와 탄창당 밀치기 한도 +1m."},
	"sequencer": {"grade": 1, "name": "증폭 시퀀서", "kind": "module", "effect": "증폭", "value": "증폭 +1", "role": "순서 증폭", "upside": "증폭 피해 +1", "downside": "", "text": "증폭탄의 타격당 추가 피해 +1. 적용 발수는 탄환을 따릅니다."},
	"duplex": {"grade": 1, "name": "복열 노리쇠", "kind": "module", "effect": "연타", "value": "+1 타격", "role": "배리어 · 집중", "upside": "연타 타격 +1", "downside": "", "text": "연타탄 타격 +1. 배리어와 쇄도 집중을 빠르게 전개합니다."},
	"igniter": {"grade": 1, "name": "점화 약실", "kind": "module", "effect": "점화 추격", "value": "+2 피해", "role": "소이 후속", "upside": "화상 중인 적 피해 +2", "downside": "", "text": "화상 중인 적을 직접 타격할 때 피해 +2."},
	"breaker": {"grade": 0, "name": "배리어 파쇄기", "kind": "module", "effect": "배리어", "value": "+1 파쇄", "role": "다중 타격", "upside": "타격당 배리어 1칸 추가 제거", "downside": "", "text": "각 타격이 배리어를 한 칸 더 제거합니다. 연타탄과 결합하면 빠르게 보호막을 걷어 냅니다."},
	"executioner": {"grade": 0, "name": "처형 조준기", "kind": "module", "effect": "마무리", "value": "+2 피해", "role": "처치선 보정", "upside": "HP 5 이하 적 피해 +2", "downside": "", "text": "발사 직전 HP가 5 이하인 적에게 직접 피해 +2."},
	"reserve": {"grade": 0, "name": "예비 급탄기", "kind": "module", "effect": "패 교환", "value": "+1회", "role": "조합 탐색", "upside": "패 교환 +1회", "downside": "", "text": "교전 시작과 재장전마다 복장의 패 교환 횟수 +1회. 운반용 외투도 1회 교환할 수 있습니다."},
	"opening": {"grade": 1, "name": "선두 격발기", "kind": "module", "effect": "첫 발", "value": "+2 피해", "role": "선두 설계", "upside": "탄창 첫 발 피해 +2", "downside": "", "text": "장전한 탄창의 첫 발 직접 피해 +2. 어떤 탄을 선두에 놓을지 결정합니다."},
	"afterburner": {"grade": 1, "name": "후미 점화기", "kind": "module", "effect": "마지막 발", "value": "+3 피해", "role": "후미 결산", "upside": "탄창 마지막 발 피해 +3", "downside": "재장전 +1턴", "text": "탄창 마지막 발 직접 피해 +3. 재장전 비용이 1턴 증가합니다."},
	"field_press": {"grade": 2, "name": "야전 압축기", "kind": "core", "effect": "현장 압축", "value": "+1회", "role": "압축 빌드", "upside": "교전마다 현장 압축 +1회", "downside": "탄창 −2칸", "text": "교전 시작마다 현장 압축 기회 +1. 대신 탄창 슬롯을 2칸 잃습니다."},
	"overbore": {"grade": 2, "name": "과구경 총열", "kind": "core", "effect": "2칸 공격탄", "value": "피해 +3 · 관통 +2", "role": "중량 압축탄", "upside": "2칸 공격탄 피해 +3 · 관통 +2", "downside": "탄창 −1칸", "text": "2칸을 차지하고 기본 피해가 있는 탄의 타격당 피해 +3·관통 +2. 탄창 −1칸. 1칸 탄과 기본 피해 0인 예약탄 등은 강화하지 않습니다."},
	"inferno": {"grade": 2, "name": "열폭주 노심", "kind": "core", "effect": "화상", "value": "+2", "role": "고열 소이", "upside": "화상 +2", "downside": "재장전 +1턴", "text": "소이탄 화상과 불씨탄의 화상 이동 한도 +2. 재장전 비용 +1턴."},
	"arc_splitter": {"grade": 2, "name": "분기 전이기", "kind": "core", "effect": "전이", "value": "+2 · 대상+1", "role": "물량 정리", "upside": "전이 피해 +2 · 대상 +1", "downside": "직접 피해 −1", "text": "전격탄 전이 피해 +2, 전이 대상 +1. 대신 모든 직접 피해 −1."},
	"momentum": {"grade": 2, "name": "충격 피스톤", "kind": "core", "effect": "밀치기", "value": "+2m", "role": "극단 거리 제어", "upside": "밀치기·한도 +2m", "downside": "직접 피해 −1", "text": "충격탄 밀치기와 탄창당 한도 +2m. 대신 모든 직접 피해 −1."},
	"triad": {"grade": 2, "name": "삼중 시퀀서", "kind": "core", "effect": "서로 다른 3발", "value": "+5 피해", "role": "혼합 순서", "upside": "서로 다른 3번째 탄 피해 +5", "downside": "기본탄 피해 −1", "text": "직전 두 발과 서로 다른 탄종을 세 번째로 발사하면 직접 피해 +5. 기본탄 직접 피해 −1."},
}

const MAX_EQUIPPED_PARTS := 5

const TACTICAL_AMMO := ["charge", "precise", "pierce", "bore", "push", "arc", "shatter", "detonate", "chase", "bypass", "cool", "charge_hot", "vent", "thermal", "prepare", "disrupt", "spread", "sequence", "charge_heat"]
const START_DECK := ["charge", "precise", "pierce", "push", "charge", "precise", "pierce", "push", "charge", "precise"]
const GUN_DECKS := {
	"burst": ["charge", "precise", "pierce", "charge", "precise", "pierce", "charge", "precise", "pierce", "precise"],
	"scatter": ["charge", "precise", "arc", "pierce", "charge", "precise", "arc", "pierce", "arc", "precise"],
	"heavy": ["bore", "arc", "push", "pierce", "bore", "arc", "push", "pierce", "bore", "arc"],
	"amplifier": ["charge", "precise", "push", "pierce", "charge", "precise", "push", "pierce", "charge", "pierce"],
}

const ENEMY_NAMES := {
	"spitter": "압력두꺼비",
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
	"evader": "전도 선체 · 전기 속성의 주 타격에 추가 피해 2를 받습니다.",
	"caster": "3턴 충전 · 완료 시 자신을 제외한 모든 적을 2m 끌어당깁니다.",
	"absorber": "배리어 · 직접 타격을 수치와 관계없이 먼저 흡수합니다. 화상과 전이는 통과합니다.",
	"stance": "교대 장갑 · 적 전진 뒤 장갑이 4와 0 사이를 오갑니다.",
}
const ENCOUNTERS := [
	{"name": "01 / 폐기물 승강장", "text": "증폭탄을 마지막에 넣어 먼저 발사하고, 바로 다음 탄을 증폭할까?"},
	{"name": "02 / 장갑 검문", "text": "장갑은 피해를 줄인다. 철갑탄의 관통으로 남는 장갑을 없애세요."},
	{"name": "03 / 열처리 통로", "text": "소이탄을 일찍 발사하면 화상이 여러 번 전진을 막아 줍니다."},
	{"name": "04 / 압축 운반로", "text": "증폭 뒤 연타탄은 증폭 피해를 두 번 적용합니다."},
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
	"피해 → HP · 증폭탄 바로 뒤의 한 발이 강해집니다",
	"관통 → 장갑 · 철갑탄은 장갑 감소를 줄입니다",
	"화상은 적의 전진 직전에 1피해를 줍니다",
	"연타탄은 두 번 공격 · 증폭도 두 번 적용됩니다",
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
	if int(enemy.get("jammed", 0)) > 0: parts.append("특수 행동 차단 %d턴" % int(enemy.jammed))
	elif bool(enemy.get("disrupted", false)): parts.append("차단 소진")
	if preload("res://redesign/ranged.gd").is_gatekeeper(enemy):
		parts.append("문판 방어 2턴 → 개방·발사 준비 2턴. 열린 동안 장갑 0. 압력탄은 HP 1, 매 턴 6m 접근하며 요격할 수 있습니다. 탄 소멸 후 2턴 회복하고 다시 닫습니다.")
		return " · ".join(parts)
	if kind == "spitter":
		parts.append("제자리에서 2턴 준비 후 압력탄 발사 · 압력탄은 HP 1, 매 턴 6m 접근. 생성한 턴에는 이동하지 않으며 가장 가까우면 다음 탄으로 요격합니다. 탄 소멸 후 1턴 회복.")
		return " · ".join(parts)
	if int(enemy.get("barrier_max", 0)) > 0:
		parts.append("배리어 %d/%d" % [int(enemy.get("barrier", 0)), int(enemy.barrier_max)])
	if int(enemy.get("charge_max", 0)) > 0:
		parts.append("충전 %d/%d · 완료 시 다른 적 −%dm" % [int(enemy.get("charge", 0)), int(enemy.charge_max), int(enemy.get("charge_pull", 2))])
	if bool(enemy.get("stance", false)):
		parts.append("태세 장갑 %d → %d" % [int(enemy.def), 0 if bool(enemy.get("stance_closed", true)) else int(enemy.get("stance_def", 4))])
	if not parts.is_empty():
		return " · ".join(parts)
	var species_rule := preload("res://redesign/residential_roster.gd").rule(enemy)
	return species_rule if not species_rule.is_empty() else str(ENEMY_RULES.get(kind, ""))

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

# Grade is acquisition rarity/build scope, independent from the core equipment limit.
static func part_grade(id: String) -> int:
	return int(PARTS.get(id, {}).get("grade", -1))

static func part_grade_name(id: String) -> String:
	var value := part_grade(id)
	return ["일반", "고급", "희귀"][value] if value >= 0 else ""

static func part_grade_color(id: String) -> Color:
	return [Color("9aa9a0"), Color("94b7ce"), Color("c7a476")][maxi(0, part_grade(id))]

static func part_grade_summary(id: String) -> String:
	if part_grade(id) < 0: return "빈 슬롯"
	return part_grade_name(id) + (" · 코어 · 최대 1개 장착" if is_core_part(id) else " · 모듈")

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
	if not is_attack(id): return 0
	var gun: Dictionary = GUNS[state.gun]
	var bonus := int(gun.get("basic_bonus", gun.bonus)) if source_id(id) == "basic" else int(gun.bonus)
	if str(AMMO[id].effect) in ["boost", "shatter", "cool", "prepare", "disrupt", "spread"]: bonus = 0
	var result := int(AMMO[id].dmg) * multiplier(state) + bonus
	if has_part(state, "overbore") and is_heavy_attack(id): result += 3
	if has_part(state, "arc_splitter"): result -= 1
	if has_part(state, "momentum"): result -= 1
	if source_id(id) == "basic" and has_part(state, "triad"): result -= 1
	return maxi(0, result)

static func penetration(id: String, state: Dictionary) -> int:
	return int(AMMO[id].pen) * multiplier(state) + (2 if has_part(state, "lens") and int(AMMO[id].pen) > 0 else 0) + (2 if has_part(state, "overbore") and is_heavy_attack(id) else 0)

static func is_heavy_attack(id: String) -> bool:
	return slot_cost(id) >= 2 and int(AMMO[id].dmg) > 0

static func ordinary_link(previous: String, current: String) -> bool:
	return AMMO.has(previous) and grade(previous) == 0 and grade(current) == 0 and source_id(previous) != source_id(current) and int(AMMO[current].dmg) > 0

static func compression_link(previous: String, current: String) -> bool:
	return AMMO.has(previous) and grade(previous) == 0 and is_compressed(current)

static func is_attack(id: String) -> bool:
	return str(AMMO[id].effect) not in ["boost", "shatter", "cool", "prepare", "disrupt", "spread"]

static func ammo_role(id: String) -> String:
	match str(AMMO[id].effect):
		"boost": return "강화"
		"shatter", "disrupt", "spread", "burn", "push": return "준비"
		"cool", "prepare": return "관리"
		"detonate", "chase", "thermal", "vent", "sequence": return "마무리"
	return "공격"

static func boost_factor(id: String, state: Dictionary) -> int:
	var base := int(AMMO[id].get("boost_factor", 1))
	return 1 + (base - 1) * multiplier(state)

static func boost_label(id: String, state: Dictionary) -> String:
	return "×%d" % boost_factor(id, state) if boost_factor(id, state) > 1 else "+%d" % effect_value(id, state)

static func primary_stat(id: String, state: Dictionary) -> Dictionary:
	var effect := str(AMMO[id].effect)
	var value := effect_value(id, state)
	match effect:
		"boost": return {"label":"고열 공격" if bool(AMMO[id].get("boost_hot",false)) else "다음 공격", "value":boost_label(id, state)}
		"shatter": return {"label":"장갑", "value":"−%d" % value}
		"cool": return {"label":"냉각", "value":"−%d" % value}
		"prepare": return {"label":"예약", "value":"%d장" % value}
		"disrupt": return {"label":"차단", "value":"%d턴" % value}
		"spread": return {"label":"화상 이동", "value":"%d" % value}
	return {"label":"피해", "value":str(damage(id, state)) + ("×%d" % hit_count(id, state) if effect == "double" else "")}

static func boost_rounds(id: String) -> int:
	return int(AMMO.get(id, {}).get("boost_rounds", 0))

static func effect_value(id: String, state: Dictionary) -> int:
	var effect := str(AMMO[id].effect)
	var value := int(AMMO[id].value) * multiplier(state)
	if effect == "arc" and state.get("gun", "") == "heavy": value = 3
	if effect == "arc" and has_part(state, "capacitor"): value += 1
	if effect == "arc" and has_part(state, "arc_splitter"): value += 2
	if effect == "push" and has_part(state, "rammer"): value += 1
	if effect == "push" and has_part(state, "momentum"): value += 2
	if effect == "boost" and int(AMMO[id].get("boost_factor", 1)) == 1 and has_part(state, "sequencer"): value += 1
	if effect == "prepare": value = mini(3, value + (1 if has_part(state, "indexer") else 0))
	if effect == "spread":
		if has_part(state, "coil"): value += 1
		if has_part(state, "inferno"): value += 2
	return value

static func prior_kind_count(prior: Array, current: String) -> int:
	var kinds: Array = []
	for id in prior:
		var kind := source_id(str(id))
		if kind != source_id(current) and not kinds.has(kind): kinds.append(kind)
	return mini(3, kinds.size())

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
	for part in equipped_parts(state): result += int(PARTS[part].get("capacity", 0))
	return maxi(1, result)

static func supply_capacity(state: Dictionary) -> int:
	return 0 if uses_ammo_cards(state) else capacity(state) + (2 if has_part(state, "reserve") else 0)

static func exchange_capacity(state: Dictionary) -> int:
	var base := int(OUTFITS[state.outfit].exchange) if OUTFITS.has(state.get("outfit", "")) else 1
	return base + (1 if has_part(state, "reserve") else 0)

static func reload_modifier(state: Dictionary) -> int:
	var value := -1 if has_part(state, "loader") else 0
	if has_part(state, "afterburner"): value += 1
	if has_part(state, "inferno"): value += 1
	return value

static func heat_cost(id: String) -> int:
	return int(AMMO.get(id, {}).get("heat", 0))

static func hand_capacity(state: Dictionary) -> int:
	if OUTFITS.has(state.get("outfit", "")):
		if int(state.get("bag_version", 0)) != BAG_VERSION: return int(LEGACY_OUTFIT_HAND.get(state.outfit, OUTFITS[state.outfit].hand))
		return mini(MAX_BAG_CAPACITY, int(OUTFITS[state.outfit].hand) + int(state.get("bag_upgrades", 0)))
	# Existing runs without an outfit retain their original hand/slot relationship.
	return maxi(5, capacity(state) + 2)

static func reload_cooling(state: Dictionary) -> int:
	var result := int(GUNS[state.gun].reload_cooling)
	for part in equipped_parts(state): result += int(PARTS[part].get("reload_cooling", 0))
	return maxi(1, result)

static func heat_after_reload(state: Dictionary) -> int:
	var current := int(state.get("heat", 0))
	return 0 if current >= heat_limit(state) else maxi(0, current - reload_cooling(state))

static func heat_limit(state: Dictionary) -> int:
	var limit := int(GUNS[state.get("gun", "single")].heat_limit)
	for part in equipped_parts(state): limit += int(PARTS[part].get("heat_limit", 0))
	return maxi(1, limit)

static func hot_threshold(state: Dictionary) -> int:
	return ceili(heat_limit(state) * 0.5)

static func heat_label(id: String, state: Dictionary) -> String:
	return "0~−%d" % int(AMMO[id].heat_spend) if str(AMMO[id].effect) == "vent" else "%+d" % heat_delta(id, state)

static func heat_delta(id: String, state: Dictionary) -> int:
	return -effect_value(id, state) if str(AMMO[id].effect) == "cool" else heat_cost(id) + part_heat_bonus(id,state)

static func part_heat_bonus(id: String, state: Dictionary) -> int:
	return 1 if is_attack(id) and has_part(state,"volley_drive") and hit_count(id,state)>1 else 0

static func field_compression_bonus(state: Dictionary) -> int:
	return 1 if has_part(state, "field_press") else 0

static func arc_target_bonus(state: Dictionary) -> int:
	return 1 if has_part(state, "arc_splitter") else 0

# Optional marker keeps in-progress legacy runs on their original supply rules.
static func uses_ammo_cards(state: Dictionary) -> bool:
	return int(state.get("ammo_cycle", 0)) == 1

static func cycle_start_deck(tactical: Array) -> Array:
	var result: Array = tactical.slice(0, 7)
	result.append_array(["basic", "basic", "basic"])
	return result

static func start_deck(gun: String) -> Array:
	return cycle_start_deck(GUN_DECKS.get(gun, START_DECK))

static func accepts_part(gun: String, part: String) -> bool:
	return PARTS.has(part) and (part != "loader" or int(GUNS[gun].reload) > 1)

static func burn_amount(id: String, state: Dictionary) -> int:
	if str(AMMO[id].effect) != "burn": return 0
	var amount := int(AMMO[id].value)
	if has_part(state, "coil"): amount += 1
	if has_part(state, "inferno"): amount += 2
	return mini(6, amount)

static func grade(id: String) -> int:
	if source_id(id) == "basic" and not is_compressed(id): return -1
	return 1 if is_compressed(id) or id == "charge_hot" else 0

static func grade_name(id: String) -> String:
	return "기본" if grade(id) < 0 else ("고급" if grade(id) == 1 else "일반")

static func grade_detail(id: String) -> String:
	return grade_name(id) + (" · 임시 압축 · 사용 후 원본 2장 복원" if is_temporary(id) else (" · 영구 압축" if is_compressed(id) else (" · 배율 강화형" if id == "charge_hot" else "")))

static func compression_cost_text(id: String, state: Dictionary = {}) -> String:
	var pieces: PackedStringArray = ["열 " + heat_label(id, state if not state.is_empty() else {"gun": "single"}), "%d칸" % slot_cost(id)]
	if anchor(id) == "first": pieces.append("첫 발 고정")
	elif anchor(id) == "last": pieces.append("마지막 발 고정")
	return " · ".join(pieces)

static func is_compressed(id: String) -> bool:
	return AMMO.has(id) and bool(AMMO[id].get("compressed", false))

static func source_id(id: String) -> String:
	return str(AMMO[id].get("source", id)) if AMMO.has(id) else id

static func compression_source(id: String) -> String:
	return str(AMMO[id].get("compression_source", source_id(id)))

static func profile_detail(id: String) -> String:
	var spec: Dictionary=AMMO[id]
	if not spec.get("profile",false): return ""
	var tune:=str(spec.get("tune",""))
	return "기초 위력 %d/5%s" % [int(spec.power), " · 화력 개조 +1" if tune=="power" else " · 방열 개조 −1" if tune=="cool" else " · 미개조"]

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

static func insertion_index(_stack: Array, _id: String) -> int:
	# Both plan and magazine are in FIRING order. New rounds enter at the muzzle.
	return 0

static func loading_order(firing_order: Array) -> Array:
	var result := firing_order.duplicate()
	result.reverse()
	return result

static func insertion_block_reason(stack: Array, id: String, capacity_value: int) -> String:
	if not AMMO.has(id): return "알 수 없는 탄"
	if anchor(id) == "last" and not stack.is_empty(): return "먼저 장전"
	if not stack.is_empty() and anchor(str(stack[0])) == "first": return "선두 탄 회수"
	if slots_used(stack) + slot_cost(id) > capacity_value: return "공간 부족"
	var proposed := stack.duplicate()
	proposed.push_front(id)
	return "" if valid_stack(proposed, capacity_value) else "위치 제약"

static func can_insert(stack: Array, id: String, capacity_value: int) -> bool:
	return insertion_block_reason(stack, id, capacity_value).is_empty()

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
