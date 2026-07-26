class_name BulletRoleUI
extends RefCounted

## 탄환의 덱 구성 역할을 화면 전반에서 같은 용어·색으로 표시하는 정본.
## CSV/.tres에는 기계 판독용 영문 role을 저장하고, 사용자 문구는 여기서만 관리한다.

const ATTACK := "attack"
const LINK := "link"
const CONTROL := "control"
const VALID_ROLES := [ATTACK, LINK, CONTROL]


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


static func is_link_chain(first_to_fire: BulletData, second_to_fire: BulletData) -> bool:
	return (
		first_to_fire != null
		and second_to_fire != null
		and normalize(first_to_fire.role) == LINK
		and normalize(second_to_fire.role) == ATTACK
	)
