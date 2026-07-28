class_name Ascension
extends RefCounted

## ═══════════════════════════════════════════════════
## 승천 (Ascension) — 클리어 이후의 난이도 사다리
##
## 설계 정본: docs/gdd/20_ascension_intention.md
##
## **누적(cumulative)** — 등급 N은 1~N의 조건이 전부 동시에 적용된다.
## 등급이 곧 난이도라는 신뢰가 유지되어야 하므로, 개별 등급이 더하는 조건은 **작아야** 한다.
##
## ⚠️ 조건 설계의 3원칙 (§4)
##   1. **양적으로 조인다** — 자원·시간을 완만하게. 기존 파라미터를 쓰므로 구현 비용도 낮다.
##   2. **적 DEF/EVA는 건드리지 않는다** — 이진 관통 게이트라 절벽이 된다.
##      DEF 4→5면 PEN 4 탄이 20% 약해지는 게 아니라 **완전 무효(0)**가 되어 특정 빌드만 죽는다.
##   3. **총기 중립** — 리로드 턴/탄창 크기처럼 클래스별 체감이 다른 값은 금지.
##      (리로드 +1턴: 연발 33% vs 단발 12% 페널티)
##
## ⚠️ 공정성 바닥선 (§6): 최고 등급에서도 완벽한 플레이는 이길 수 있어야 한다.
##    "효율 실패로 죽는 것은 공정, 완벽히 했는데 자원이 모자라 죽는 것은 부당."
## ═══════════════════════════════════════════════════

## 최고 등급. 슬더스의 20단계는 본작 스코프에 과하다고 판단해 10단계로 확정(§2).
const MAX_LEVEL := 10

## 등급별로 **새로 추가되는** 조건. 누적이므로 등급 N에서는 1~N이 전부 적용된다.
##
## 배치 원칙:
##   - 앞쪽에 큰 것을 넣으면 영원히 누적되어 후반이 감당 불가능해진다 → 작은 것부터
##   - 메타 파워(HP아머 +2 / 가방 +3 / 금고)를 상쇄하도록 분산 배치(§5)
##   - 기본탄은 전 난이도에서 총기 고정 보급이므로 승천도 보급 계약을 깨지 않는다
const TIERS := [
	{
		"level": 1, "title": "가벼운 짐",
		"desc": "시작 아머 −1",
		"effects": {"armor_delta": -1},
	},
	{
		"level": 2, "title": "얇은 배급",
		"desc": "크레딧 수입 −20%",
		"effects": {"credit_mult": 0.8},
	},
	{
		"level": 3, "title": "빈 주머니",
		"desc": "시작 덱 −1발",
		"effects": {"deck_delta": -1},
	},
	{
		"level": 4, "title": "좁은 통로",
		"desc": "교전 시작 거리 −1m",
		"effects": {"start_dist_delta": -1},
	},
	{
		"level": 5, "title": "빨라진 것들",
		"desc": "적 SPD +1",
		"effects": {"enemy_spd_delta": 1},
	},
	{
		"level": 6, "title": "마른 보급",
		"desc": "드래프트 선택지 3 → 2장",
		"effects": {"draft_slots_delta": -1},
	},
	{
		"level": 7, "title": "무거운 짐",
		"desc": "시작 아머 −1 (누적 −2)",
		"effects": {"armor_delta": -1},
	},
	{
		"level": 8, "title": "더 좁은 통로",
		"desc": "교전 시작 거리 −1m (누적 −2m)",
		# 기본탄 보급 계약을 예외 처리하지 않고 기존 총기 중립 거리 레버를 한 번 더 누적한다.
		"effects": {"start_dist_delta": -1},
	},
	{
		"level": 9, "title": "더 빈 주머니",
		"desc": "시작 덱 −1발 (누적 −2)",
		"effects": {"deck_delta": -1},
	},
	{
		"level": 10, "title": "정점의 무게",
		"desc": "크레딧 수입 −20% (누적 −40%) · 적 SPD +1 (누적 +2)",
		"effects": {"credit_mult": 0.8, "enemy_spd_delta": 1},
	},
]


## 등급 N에서 누적 적용되는 효과의 합. level 0이면 전부 기본값.
##
## ⚠️ 곱연산(credit_mult)과 합연산(delta)을 구분해 누적한다.
##    크레딧을 합연산으로 하면 등급이 오를수록 0 이하로 떨어져 수입이 사라진다.
static func effects_for(level: int) -> Dictionary:
	var acc := {
		"armor_delta": 0,
		"credit_mult": 1.0,
		"deck_delta": 0,
		"start_dist_delta": 0,
		"enemy_spd_delta": 0,
		"draft_slots_delta": 0,
	}
	var lv: int = clampi(level, 0, MAX_LEVEL)
	for tier in TIERS:
		if int(tier.level) > lv:
			break
		var eff: Dictionary = tier.effects
		for key in eff.keys():
			match key:
				"credit_mult":
					acc.credit_mult *= float(eff[key])
				_:
					acc[key] = int(acc[key]) + int(eff[key])
	return acc


## 해당 등급까지 누적된 조건을 사람이 읽는 목록으로. UI(브리핑·타이틀)에서 쓴다.
static func active_conditions(level: int) -> Array[String]:
	var out: Array[String] = []
	var lv: int = clampi(level, 0, MAX_LEVEL)
	for tier in TIERS:
		if int(tier.level) > lv:
			break
		out.append("%d. %s — %s" % [int(tier.level), str(tier.title), str(tier.desc)])
	return out


static func tier_title(level: int) -> String:
	for tier in TIERS:
		if int(tier.level) == level:
			return str(tier.title)
	return ""
