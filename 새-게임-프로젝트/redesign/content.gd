extends RefCounted
## Prototype data is deliberately pathless: legacy CSV overrides cannot alter it.
const AMMO := {
	"basic": {"name": "회수탄", "dmg": 3, "pen": 1, "acc": 6, "effect": "", "value": 0, "text": "재장전마다 3발 복구"},
	"pierce": {"name": "철갑탄", "dmg": 5, "pen": 4, "acc": 4, "effect": "", "value": 0, "text": "장갑에 강하고 회피에 약함"},
	"precise": {"name": "정밀탄", "dmg": 3, "pen": 1, "acc": 10, "effect": "", "value": 0, "text": "회피에 강하고 장갑에 약함"},
	"bore": {"name": "천공 준비탄", "dmg": 1, "pen": 4, "acc": 8, "effect": "pen", "value": 3, "text": "발사하면 다음 1발 관통 +3"},
	"mark": {"name": "조준 준비탄", "dmg": 1, "pen": 1, "acc": 10, "effect": "acc", "value": 4, "text": "발사하면 다음 1발 명중 +4"},
	"charge": {"name": "장약 준비탄", "dmg": 1, "pen": 1, "acc": 8, "effect": "dmg", "value": 4, "text": "발사하면 다음 1발 피해 +4"},
	"push": {"name": "충격탄", "dmg": 2, "pen": 1, "acc": 7, "effect": "push", "value": 2, "text": "명중 시 2m 밀기 · 탄창당 총 2m"},
	"slow": {"name": "점착탄", "dmg": 2, "pen": 2, "acc": 9, "effect": "slow", "value": 2, "text": "명중 시 다음 전진 1회 속도 −2"},
}
const GUNS := {
	"single": {"name": "한 발의 여유", "capacity": 4, "reload": 1, "bonus": 1, "text": "단발 · 피해 +1 · 사격 1턴 / 재장전 1턴"},
	"burst": {"name": "되돌릴 수 없는 네 발", "capacity": 4, "reload": 3, "bonus": 0, "text": "일제 · 전탄 사격 1턴 / 재장전 3턴"},
}
const PARTS := {
	"none": {"name": "파츠 없음", "text": "파츠는 한 개만 장착할 수 있습니다."},
	"lens": {"name": "잔광 조준기", "text": "모든 탄환 명중 +2"},
	"loader": {"name": "회수 가속기", "text": "재장전 비용 −1턴 (최소 1턴)"},
	"supply": {"name": "여분 장약통", "text": "매 장전 회수탄 공급 3 → 4발"},
}
const START_DECK := ["bore", "pierce", "mark", "precise", "push", "charge"]
const ENCOUNTERS := [
	{"name": "01 / 폐기물 승강장", "text": "구형 총은 마지막에 넣은 탄부터 내보낸다.", "enemies": [["runner", 7, 0, 4, 2, 16]]},
	{"name": "02 / 장갑 검문", "text": "장갑은 피해를 깎지 않는다. 관통이 모자라면 전부 막는다.", "enemies": [["wall", 10, 3, 4, 1, 16]]},
	{"name": "03 / 굴절 통로", "text": "얇은 윤곽이 통로를 가른다. 명중 수치를 먼저 읽는다.", "enemies": [["evader", 8, 1, 8, 2, 18]]},
	{"name": "04 / 교차 운반로", "text": "가까운 적이 먼저 맞는다. 밀어내면 다음 표적이 바뀔 수 있다.", "enemies": [["runner", 9, 0, 4, 3, 18], ["wall", 12, 3, 4, 1, 20]]},
	{"name": "05 / 무인 정비층", "text": "표적이 달라져도 준비탄의 효과는 다음 한 발을 따라간다.", "enemies": [["evader", 10, 1, 8, 2, 18], ["runner", 10, 0, 5, 3, 24]]},
	{"name": "06 / 상층 경계", "text": "여기서는 한 탄창을 비운 뒤의 거리까지 남겨야 한다.", "enemies": [["wall", 14, 3, 5, 2, 22], ["evader", 10, 1, 8, 2, 24]]},
	{"name": "07 / 배정되지 않은 자리", "text": "문은 열린다. 그 너머에는 인간의 자리가 배정되어 있지 않다.", "enemies": [["runner", 10, 0, 5, 3, 18], ["wall", 20, 3, 6, 2, 28], ["evader", 10, 1, 8, 2, 30]]},
]
const ENEMY_NAMES := {"runner": "운반 사족체", "wall": "융합 장갑벽", "evader": "굴절 선체"}
const REWARDS := [["slow", "pierce"], ["lens", "supply", "loader"], ["charge", "bore"], ["precise", "push"], ["lens", "supply", "loader"], ["mark", "slow"]]

static func enemies_for(index: int) -> Array:
	var result: Array = []
	for e in ENCOUNTERS[index].enemies:
		result.append({"kind": e[0], "name": ENEMY_NAMES[e[0]], "hp": e[1], "max_hp": e[1], "def": e[2], "eva": e[3], "speed": e[4], "distance": e[5], "slow": 0})
	return result
