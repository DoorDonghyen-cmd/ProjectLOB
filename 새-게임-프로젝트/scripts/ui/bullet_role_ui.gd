class_name BulletRoleUI
extends RefCounted

## 탄환의 덱 구성 역할을 화면 전반에서 같은 용어·색으로 표시하는 정본.
## CSV/.tres에는 기계 판독용 영문 role을 저장하고, 사용자 문구는 여기서만 관리한다.

const STANDALONE := "standalone"
const SETTER := "setter"
const PAYLOAD := "payload"
const UTILITY := "utility"
const VALID_ROLES := [STANDALONE, SETTER, PAYLOAD, UTILITY]


static func normalize(value: String) -> String:
	var normalized := value.strip_edges().to_lower()
	return normalized if normalized in VALID_ROLES else STANDALONE


static func label(value: String) -> String:
	match normalize(value):
		SETTER:
			return "셋업"
		PAYLOAD:
			return "페이로드"
		UTILITY:
			return "유틸"
		_:
			return "독립"


static func badge_text(value: String) -> String:
	return "[%s]" % label(value)


static func color(value: String) -> Color:
	match normalize(value):
		SETTER:
			return Color(0.35, 0.85, 1.0)
		PAYLOAD:
			return Color(1.0, 0.55, 0.25)
		UTILITY:
			return Color(0.35, 0.9, 0.6)
		_:
			return Color(0.72, 0.76, 0.82)


static func hint(value: String) -> String:
	match normalize(value):
		SETTER:
			return "유효 적중 시 뒤따르는 1발을 강화합니다. LIFO에서는 페이로드를 먼저 넣고 셋업을 나중에 넣으십시오."
		PAYLOAD:
			return "셋업 뒤에 발사할 때 큰 보상을 내는 탄환입니다."
		UTILITY:
			return "거리나 적 상태를 조작해 다음 판단을 유리하게 만듭니다."
		_:
			return "다른 탄의 도움 없이도 안정적인 성능을 내는 탄환입니다."


static func is_setup_chain(first_to_fire: BulletData, second_to_fire: BulletData) -> bool:
	return (
		first_to_fire != null
		and second_to_fire != null
		and normalize(first_to_fire.role) == SETTER
		and normalize(second_to_fire.role) == PAYLOAD
	)
