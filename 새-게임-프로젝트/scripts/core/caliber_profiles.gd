class_name CaliberProfiles
extends RefCounted

const CATEGORY_STANDARD := "standard"
const CATEGORY_SIGNATURE := "signature"

## 플레이어가 처음부터 배우는 공통 규격은 3종만 유지한다.
## .45ACP와 7.62mm는 해당 총기를 해금했을 때 함께 배우는 전용 규격이다.
const STANDARD_CLASSES := [
	Enums.WeaponClass.PISTOL,
	Enums.WeaponClass.RIFLE,
	Enums.WeaponClass.SHOTGUN,
]
const SIGNATURE_CLASSES := [
	Enums.WeaponClass.SMG,
	Enums.WeaponClass.DMR,
]

## 총기의 구경은 런 중 바꾸는 빌드 축이 아니라, 모든 공용 전술탄에 적용되는 고정 탄도 성향이다.
## 기반탄 5종은 CSV 자체에 이미 구경 성향이 들어 있으므로 프로필을 중복 적용하지 않는다.
const PROFILES := {
	Enums.WeaponClass.PISTOL: {
		"name": "경량탄",
		"technical_name": "9mm",
		"category": CATEGORY_STANDARD,
		"damage": 0, "penetration": 0, "accuracy": 1, "knockback": 0,
		"summary": "전술탄 ACC +1",
	},
	Enums.WeaponClass.SMG: {
		"name": "중량탄",
		"technical_name": ".45ACP",
		"category": CATEGORY_SIGNATURE,
		"damage": 1, "penetration": 0, "accuracy": 0, "knockback": 0,
		"summary": "전술탄 DMG +1",
	},
	Enums.WeaponClass.RIFLE: {
		"name": "소총탄",
		"technical_name": "5.56mm",
		"category": CATEGORY_STANDARD,
		"damage": 0, "penetration": 1, "accuracy": 0, "knockback": 0,
		"summary": "전술탄 PEN +1",
	},
	Enums.WeaponClass.DMR: {
		"name": "저격탄",
		"technical_name": "7.62mm",
		"category": CATEGORY_SIGNATURE,
		"damage": 1, "penetration": 1, "accuracy": -1, "knockback": 0,
		"summary": "전술탄 DMG/PEN +1 · ACC -1",
	},
	Enums.WeaponClass.SHOTGUN: {
		"name": "산탄",
		"technical_name": "12게이지",
		"category": CATEGORY_STANDARD,
		"damage": 1, "penetration": -1, "accuracy": -1, "knockback": 0,
		"summary": "전술탄 DMG +1 · PEN/ACC -1",
	},
}


static func profile_for_class(weapon_class: int) -> Dictionary:
	return PROFILES.get(weapon_class, {
		"name": "공용",
		"technical_name": "",
		"category": "",
		"damage": 0, "penetration": 0, "accuracy": 0, "knockback": 0,
		"summary": "구경 보정 없음",
	})


static func profile_for_gun(gun: GunData) -> Dictionary:
	if gun == null:
		return profile_for_class(Enums.WeaponClass.UNIVERSAL)
	return profile_for_class(gun.weapon_class)


static func bonus_for(bullet: BulletData, gun: GunData, stat: String) -> int:
	if bullet == null or gun == null or bullet.weapon_class != Enums.WeaponClass.UNIVERSAL:
		return 0
	return int(profile_for_gun(gun).get(stat, 0))


static func is_standard_class(weapon_class: int) -> bool:
	return weapon_class in STANDARD_CLASSES


static func is_signature_class(weapon_class: int) -> bool:
	return weapon_class in SIGNATURE_CLASSES


static func category_label_for_class(weapon_class: int) -> String:
	if is_standard_class(weapon_class):
		return "표준 규격"
	if is_signature_class(weapon_class):
		return "전용 규격"
	return "공용 전술탄"


static func short_label_for_class(weapon_class: int) -> String:
	if weapon_class == Enums.WeaponClass.UNIVERSAL:
		return category_label_for_class(weapon_class)
	var profile := profile_for_class(weapon_class)
	return "%s · %s (%s)" % [
		category_label_for_class(weapon_class),
		profile.name,
		profile.technical_name,
	]


static func display_text(gun: GunData) -> String:
	var profile := profile_for_gun(gun)
	if gun == null:
		return "[공용 전술탄] 현재 총기의 탄도 성향 적용"
	return "[%s] %s" % [short_label_for_class(gun.weapon_class), profile.summary]
