class_name BulletRoleUI
extends RefCounted

## 탄환의 덱 구성 역할을 화면 전반에서 같은 용어·색으로 표시하는 정본.
## CSV/.tres에는 기계 판독용 영문 role을 저장하고, 사용자 문구는 여기서만 관리한다.

const ATTACK := "attack"
const LINK := "link"
const CONTROL := "control"
const PAYOFF := "payoff"
const VALID_ROLES := [ATTACK, LINK, CONTROL]
const SPECIALTY_DAMAGE := "damage"
const SPECIALTY_PENETRATION := "penetration"
const SPECIALTY_ACCURACY := "accuracy"
const SPECIALTY_CONTROL := "control"
const VALID_SPECIALTIES := [
	SPECIALTY_DAMAGE, SPECIALTY_PENETRATION, SPECIALTY_ACCURACY, SPECIALTY_CONTROL,
]
const SCOPE_NONE := "none"
const SCOPE_NEXT_SHOT := "next_shot"
const SCOPE_TARGET := "target"
const SCOPE_REMAINING_MAG := "remaining_mag"


static func normalize(value: String) -> String:
	var normalized := value.strip_edges().to_lower()
	match normalized:
		ATTACK, "standalone", "payload":
			return ATTACK
		LINK, "setter":
			return LINK
		CONTROL, "utility":
			return CONTROL
		_:
			return ATTACK


static func label(value: String) -> String:
	match normalize(value):
		LINK:
			return "연계"
		CONTROL:
			return "제어"
		_:
			return "공격"


static func badge_text(value: String) -> String:
	return "[%s]" % label(value)


static func normalize_specialty(value: String) -> String:
	var normalized := value.strip_edges().to_lower()
	return normalized if normalized in VALID_SPECIALTIES else SPECIALTY_DAMAGE


static func specialty_label(value: String) -> String:
	match normalize_specialty(value):
		SPECIALTY_PENETRATION:
			return "장갑 파훼"
		SPECIALTY_ACCURACY:
			return "명중 보정"
		SPECIALTY_CONTROL:
			return "거리 제어"
		_:
			return "피해 증폭"


static func specialty_code(value: String) -> String:
	match normalize_specialty(value):
		SPECIALTY_PENETRATION:
			return "PEN"
		SPECIALTY_ACCURACY:
			return "ACC"
		SPECIALTY_CONTROL:
			return "CTRL"
		_:
			return "DMG"


static func specialty_short_label(value: String) -> String:
	match normalize_specialty(value):
		SPECIALTY_PENETRATION:
			return "관통"
		SPECIALTY_ACCURACY:
			return "명중"
		SPECIALTY_CONTROL:
			return "제어"
		_:
			return "화력"


## 색을 보지 못해도 전문축을 구분하는 카드 공용 기호.
static func specialty_symbol(value: String) -> String:
	match normalize_specialty(value):
		SPECIALTY_PENETRATION:
			return "◆"
		SPECIALTY_ACCURACY:
			return "◎"
		SPECIALTY_CONTROL:
			return "↔"
		_:
			return "✦"


static func visual_role_text(bullet: BulletData) -> String:
	if bullet == null:
		return ""
	var text := "%s %s" % [specialty_symbol(bullet.specialty), specialty_short_label(bullet.specialty)]
	return "%s · 기본" % text if bullet.is_basic else text


## 원시 스탯 이름보다 먼저 읽히는 한 문장 효용.
static func primary_outcome_text(bullet: BulletData) -> String:
	if bullet == null:
		return ""
	match normalize_specialty(bullet.specialty):
		SPECIALTY_ACCURACY:
			return "회피 %d까지 명중" % bullet.accuracy
		SPECIALTY_PENETRATION:
			return "방어 %d까지 관통" % bullet.penetration
		SPECIALTY_CONTROL:
			if bullet.knockback > 0:
				return "명중 시 거리 +%dm" % bullet.knockback
			if bullet.slow > 0:
				return "다음 이동 속도 -%d" % bullet.slow
			return "적 행동·거리를 제어"
		_:
			return "관통 성공 시 피해 %d" % bullet.damage


## 카드 본문용 발동 조건 → 결과 문장. 기존 effect_summary는 레거시 축약 UI를 위해 유지한다.
static func effect_outcome_text(bullet: BulletData) -> String:
	if bullet == null:
		return ""
	var value := maxi(bullet.effect_value, 0)
	match bullet.effect_type:
		Enums.BulletEffect.BUFF_ACC:
			return "적중 시 → 다음 1발 명중 +%d" % value
		Enums.BulletEffect.BUFF_PEN:
			return "적중 시 → 다음 1발 관통 +%d" % value
		Enums.BulletEffect.BUFF_DMG:
			return "적중 시 → 다음 1발 피해 +%d" % value
		Enums.BulletEffect.DEBUFF_EVA:
			return "명중 시 → 대상 회피 -%d" % value
		Enums.BulletEffect.ARMOR_SHRED:
			return "명중 시 → 대상 방어 -%d" % value
		Enums.BulletEffect.BUFF_MAG_ACC:
			return "적중 시 → 남은 탄창 명중 +%d" % value
		Enums.BulletEffect.BUFF_MAG_PEN:
			return "적중 시 → 남은 탄창 관통 +%d" % value
		Enums.BulletEffect.COMBO:
			return "직전 유효 적중 시 피해 +%d" % value
		Enums.BulletEffect.LAST_SHOT:
			return "마지막 발이면 피해 +%d" % value
		Enums.BulletEffect.CALIBER_DIFF:
			return "전문축 교대 시 피해 +%d" % value
		Enums.BulletEffect.OPENING_SHOT:
			return "첫 발이면 거리 +%dm" % value
		Enums.BulletEffect.PIERCE:
			return "유효 적중 시 → 후열 1명 관통"
		_:
			return ""


static func secondary_stats_text(bullet: BulletData) -> String:
	if bullet == null:
		return ""
	match normalize_specialty(bullet.specialty):
		SPECIALTY_ACCURACY:
			return "피해 %d · 관통 %d" % [bullet.damage, bullet.penetration]
		SPECIALTY_PENETRATION:
			return "피해 %d · 명중 %d" % [bullet.damage, bullet.accuracy]
		SPECIALTY_DAMAGE:
			return "명중 %d · 관통 %d" % [bullet.accuracy, bullet.penetration]
		_:
			return "피해 %d · 명중 %d · 관통 %d" % [
				bullet.damage, bullet.accuracy, bullet.penetration]


static func specialty_badge_text(value: String) -> String:
	return "[%s %s]" % [specialty_code(value), specialty_label(value)]


static func compact_specialty_badge_text(value: String) -> String:
	return "[%s]" % specialty_code(value)


static func basic_trait_label(bullet: BulletData) -> String:
	if bullet == null:
		return ""
	match normalize_specialty(bullet.specialty):
		SPECIALTY_PENETRATION:
			return "고관통"
		SPECIALTY_ACCURACY:
			return "고명중"
		_:
			return "고화력"


static func primary_badge_text(bullet: BulletData, compact: bool = false) -> String:
	if bullet == null:
		return ""
	if bullet.is_basic:
		return "[기본탄]" if compact else "[기본탄] %s" % basic_trait_label(bullet)
	return compact_specialty_badge_text(bullet.specialty) \
		if compact else specialty_badge_text(bullet.specialty)


static func primary_color(bullet: BulletData) -> Color:
	if bullet == null or bullet.is_basic:
		return Color(0.72, 0.78, 0.86)
	return specialty_color(bullet.specialty)


static func specialty_color(value: String) -> Color:
	match normalize_specialty(value):
		SPECIALTY_PENETRATION:
			return Color(0.32, 0.68, 1.0)
		SPECIALTY_ACCURACY:
			return Color(1.0, 0.82, 0.28)
		SPECIALTY_CONTROL:
			return Color(0.35, 0.9, 0.72)
		_:
			return Color(1.0, 0.35, 0.3)


static func specialty_hint(value: String) -> String:
	match normalize_specialty(value):
		SPECIALTY_PENETRATION:
			return "PEN 장갑 파훼: 높은 관통으로 장갑 게이트를 엽니다."
		SPECIALTY_ACCURACY:
			return "ACC 명중 보정: 높은 명중으로 회피 게이트를 엽니다."
		SPECIALTY_CONTROL:
			return "CTRL 거리 제어: 넉백·둔화로 안전 거리와 행동 횟수를 확보합니다."
		_:
			return "DMG 피해 증폭: 열린 명중·관통 게이트를 더 큰 주 피해로 전환합니다."


static func effect_summary(bullet: BulletData) -> String:
	if bullet == null:
		return ""
	var value := maxi(bullet.effect_value, 0)
	match bullet.effect_type:
		Enums.BulletEffect.BUFF_ACC:
			return "다음 1발 ACC +%d" % value
		Enums.BulletEffect.BUFF_PEN:
			return "다음 1발 PEN +%d" % value
		Enums.BulletEffect.BUFF_DMG:
			return "다음 1발 DMG +%d" % value
		Enums.BulletEffect.DEBUFF_EVA:
			return "대상 EVA -%d" % value
		Enums.BulletEffect.ARMOR_SHRED:
			return "대상 DEF -%d" % value
		Enums.BulletEffect.BUFF_MAG_ACC:
			return "남은 탄창 ACC +%d" % value
		Enums.BulletEffect.BUFF_MAG_PEN:
			return "남은 탄창 PEN +%d" % value
		Enums.BulletEffect.COMBO:
			return "직전 유효 적중 시 이 탄 DMG +%d" % value
		Enums.BulletEffect.LAST_SHOT:
			return "마지막 발: 이 탄 DMG +%d" % value
		Enums.BulletEffect.CALIBER_DIFF:
			return "전문축 교대: 이 탄 DMG +%d" % value
		Enums.BulletEffect.OPENING_SHOT:
			return "첫 발: KB +%d" % value
		_:
			return ""


static func is_payoff(bullet: BulletData) -> bool:
	return bullet != null and bullet.effect_type in [
		Enums.BulletEffect.COMBO,
		Enums.BulletEffect.CALIBER_DIFF,
	]


static func payoff_badge_text(bullet: BulletData) -> String:
	return "[결산]" if is_payoff(bullet) else ""


static func payoff_color() -> Color:
	return Color(1.0, 0.35, 0.78)


static func payoff_hint(bullet: BulletData) -> String:
	if not is_payoff(bullet):
		return ""
	match bullet.effect_type:
		Enums.BulletEffect.COMBO:
			return "결산탄: 직전 탄의 유효 적중을 조건부 추가 피해로 환산합니다."
		Enums.BulletEffect.CALIBER_DIFF:
			return "결산탄: 직전 탄과의 전문축 교대를 조건부 추가 피해로 환산합니다."
		_:
			return ""


static func color(value: String) -> Color:
	match normalize(value):
		LINK:
			return Color(0.35, 0.85, 1.0)
		CONTROL:
			return Color(0.35, 0.9, 0.6)
		_:
			return Color(1.0, 0.65, 0.3)


static func hint(value: String) -> String:
	match normalize(value):
		LINK:
			return "뒤따르는 공격탄의 게이트를 열거나 적을 약화합니다. LIFO에서는 공격탄을 먼저 넣고 연계탄을 나중에 넣으십시오."
		CONTROL:
			return "거리나 적 상태를 조작해 다음 판단을 유리하게 만듭니다."
		_:
			return "일반 적에게 단독으로 작동하며 연계탄을 받으면 대응 범위가 넓어집니다."


static func normalize_scope(value: String) -> String:
	var normalized := value.strip_edges().to_lower()
	match normalized:
		SCOPE_NEXT_SHOT, SCOPE_TARGET, SCOPE_REMAINING_MAG:
			return normalized
		_:
			return SCOPE_NONE


static func scope_label(value: String) -> String:
	match normalize_scope(value):
		SCOPE_NEXT_SHOT:
			return "다음 1발"
		SCOPE_TARGET:
			return "대상 지속"
		SCOPE_REMAINING_MAG:
			return "잔여 탄창"
		_:
			return ""


static func scope_badge_text(value: String) -> String:
	var scope := scope_label(value)
	return "[%s]" % scope if not scope.is_empty() else ""


static func compact_scope_badge_text(value: String) -> String:
	match normalize_scope(value):
		SCOPE_NEXT_SHOT:
			return "[1발]"
		SCOPE_TARGET:
			return "[대상]"
		SCOPE_REMAINING_MAG:
			return "[잔탄]"
		_:
			return ""


static func scope_hint(value: String) -> String:
	match normalize_scope(value):
		SCOPE_NEXT_SHOT:
			return "효과 범위: 바로 뒤에 발사되는 1발"
		SCOPE_TARGET:
			return "효과 범위: 명중한 대상에게 교전 동안 지속"
		SCOPE_REMAINING_MAG:
			return "효과 범위: 발동 뒤 탄창에 남은 모든 탄환"
		_:
			return ""


static func tooltip(bullet: BulletData) -> String:
	if bullet == null:
		return ""
	var identity := (
		"기본 보급탄 · %s 성향" % basic_trait_label(bullet)
		if bullet.is_basic
		else specialty_hint(bullet.specialty)
	)
	var lines: Array[String] = [identity]
	var effect_line := effect_summary(bullet)
	if not effect_line.is_empty():
		lines.append("효과: %s" % effect_line)
	var payoff_line := payoff_hint(bullet)
	if not payoff_line.is_empty():
		lines.append(payoff_line)
	var scope_line := scope_hint(bullet.scope)
	if not scope_line.is_empty():
		lines.append(scope_line)
	if not bullet.description.is_empty():
		lines.append(bullet.description)
	lines.append("운용 분류: %s" % label(bullet.role))
	return "\n".join(lines)


static func is_link_chain(first_to_fire: BulletData, second_to_fire: BulletData) -> bool:
	return (
		first_to_fire != null
		and second_to_fire != null
		and normalize(first_to_fire.role) == LINK
		and normalize(second_to_fire.role) == ATTACK
	)
