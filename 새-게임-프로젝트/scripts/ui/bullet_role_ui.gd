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
			return "관통"
		SPECIALTY_ACCURACY:
			return "명중"
		SPECIALTY_CONTROL:
			return "제어"
		_:
			return "화력"


static func specialty_badge_text(value: String) -> String:
	return "[%s]" % specialty_label(value)


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
			return "관통 특화: 높은 PEN으로 장갑 게이트를 열지만 화력과 명중은 제한적입니다."
		SPECIALTY_ACCURACY:
			return "명중 특화: 높은 ACC로 회피 게이트를 열지만 화력과 관통은 제한적입니다."
		SPECIALTY_CONTROL:
			return "제어 특화: 넉백·둔화로 거리와 행동 횟수를 확보하며 직접 화력은 낮습니다."
		_:
			return "화력 특화: 열린 명중·관통 게이트를 큰 피해로 결산합니다."


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
	var lines: Array[String] = [
		specialty_hint(bullet.specialty),
		"운용: %s — %s" % [label(bullet.role), hint(bullet.role)],
	]
	var payoff_line := payoff_hint(bullet)
	if not payoff_line.is_empty():
		lines.append(payoff_line)
	var scope_line := scope_hint(bullet.scope)
	if not scope_line.is_empty():
		lines.append(scope_line)
	if not bullet.description.is_empty():
		lines.append(bullet.description)
	return "\n".join(lines)


static func is_link_chain(first_to_fire: BulletData, second_to_fire: BulletData) -> bool:
	return (
		first_to_fire != null
		and second_to_fire != null
		and normalize(first_to_fire.role) == LINK
		and normalize(second_to_fire.role) == ATTACK
	)
