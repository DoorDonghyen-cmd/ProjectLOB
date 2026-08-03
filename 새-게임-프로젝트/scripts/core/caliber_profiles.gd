class_name CaliberProfiles
extends RefCounted

const CATEGORY_STANDARD := "standard"
const CATEGORY_ENHANCED := "enhanced"

## 플레이어가 처음부터 배우는 공통 규격은 3종만 유지한다.
## .45ACP와 7.62mm는 별도 탄종이 아니라 해당 계열의 강화 기술 규격이다.
const STANDARD_CLASSES := [
	Enums.WeaponClass.PISTOL,
	Enums.WeaponClass.RIFLE,
	Enums.WeaponClass.SHOTGUN,
]
const ENHANCED_CLASSES := [
	Enums.WeaponClass.SMG,
	Enums.WeaponClass.DMR,
]
## 레거시 호출 호환. 신규 코드는 ENHANCED_CLASSES/is_enhanced_class를 사용한다.
const SIGNATURE_CLASSES := ENHANCED_CLASSES

const FOCUS_THRESHOLD := 3
const SHOTGUN_MAX_RANGE := 3
const SHOTGUN_LONG_RANGE_DAMAGE_PENALTY := 2
const RIFLE_REAR_DAMAGE := 1
const HEAVY_FIRST_REAR_DAMAGE := 2

## 총기의 구경은 런 중 바꾸는 빌드 축이 아니라, 모든 공용 전술탄에 적용되는 고정 탄도 성향이다.
## 기반탄 5종은 CSV 자체에 이미 구경 성향이 들어 있으므로 프로필을 중복 적용하지 않는다.
const PROFILES := {
	Enums.WeaponClass.PISTOL: {
		"name": "경량탄",
		"technical_name": "9mm",
		"category": CATEGORY_STANDARD,
		"family": Enums.AmmoFamily.LIGHT,
		"grade": Enums.AmmoGrade.STANDARD,
		"focus_bonus": 1,
		"line_depth": 0,
		"scatter_count": 0,
		"scatter_radius": 0,
		"damage": 0, "penetration": 0, "accuracy": 1, "knockback": 0,
		"summary": "집중 3회 시 피해 +1 · 전술탄 ACC +1",
	},
	Enums.WeaponClass.SMG: {
		"name": "경량탄",
		"technical_name": ".45ACP",
		"category": CATEGORY_ENHANCED,
		"family": Enums.AmmoFamily.LIGHT,
		"grade": Enums.AmmoGrade.ENHANCED,
		"focus_bonus": 2,
		"line_depth": 0,
		"scatter_count": 0,
		"scatter_radius": 0,
		"damage": 1, "penetration": 0, "accuracy": 0, "knockback": 0,
		"summary": "집중 3회 시 피해 +2 · 전술탄 DMG +1",
	},
	Enums.WeaponClass.RIFLE: {
		"name": "소총탄",
		"technical_name": "5.56mm",
		"category": CATEGORY_STANDARD,
		"family": Enums.AmmoFamily.RIFLE,
		"grade": Enums.AmmoGrade.STANDARD,
		"focus_bonus": 0,
		"line_depth": 1,
		"scatter_count": 0,
		"scatter_radius": 0,
		"damage": 0, "penetration": 1, "accuracy": 0, "knockback": 0,
		"summary": "후열 1명 스침 피해 1 · 전술탄 PEN +1",
	},
	Enums.WeaponClass.DMR: {
		"name": "소총탄",
		"technical_name": "7.62mm",
		"category": CATEGORY_ENHANCED,
		"family": Enums.AmmoFamily.RIFLE,
		"grade": Enums.AmmoGrade.ENHANCED,
		"focus_bonus": 0,
		"line_depth": 3,
		"scatter_count": 0,
		"scatter_radius": 0,
		"damage": 1, "penetration": 1, "accuracy": -1, "knockback": 0,
		"summary": "후열 3명 스침 피해 각 1 · 전술탄 DMG/PEN +1 · ACC -1",
	},
	Enums.WeaponClass.SHOTGUN: {
		"name": "산탄",
		"technical_name": "12게이지",
		"category": CATEGORY_STANDARD,
		"family": Enums.AmmoFamily.SHOTGUN,
		"grade": Enums.AmmoGrade.STANDARD,
		"focus_bonus": 0,
		"line_depth": 0,
		"scatter_count": 1,
		"scatter_radius": 1,
		"damage": 1, "penetration": -1, "accuracy": -1, "knockback": 0,
		"summary": "3m 이내 군집 1명 50% 확산 · 4m 이상 주 피해 -2 · 전술탄 DMG +1 · PEN/ACC -1",
	},
}


static func profile_for_class(weapon_class: int) -> Dictionary:
	return PROFILES.get(weapon_class, {
		"name": "공용",
		"technical_name": "",
		"category": "",
		"family": Enums.AmmoFamily.UNIVERSAL,
		"grade": Enums.AmmoGrade.UNIVERSAL,
		"focus_bonus": 0,
		"line_depth": 0,
		"scatter_count": 0,
		"scatter_radius": 0,
		"damage": 0, "penetration": 0, "accuracy": 0, "knockback": 0,
		"summary": "탄종 보정 없음",
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
	return is_enhanced_class(weapon_class)


static func is_enhanced_class(weapon_class: int) -> bool:
	return weapon_class in ENHANCED_CLASSES


static func family_for_class(weapon_class: int) -> int:
	return int(profile_for_class(weapon_class).get("family", Enums.AmmoFamily.UNIVERSAL))


static func family_for_gun(gun: GunData) -> int:
	if gun == null:
		return Enums.AmmoFamily.UNIVERSAL
	return family_for_class(gun.weapon_class)


static func grade_for_class(weapon_class: int) -> int:
	return int(profile_for_class(weapon_class).get("grade", Enums.AmmoGrade.UNIVERSAL))


static func focus_bonus_for_gun(gun: GunData) -> int:
	return int(profile_for_gun(gun).get("focus_bonus", 0))


static func line_depth_for_gun(gun: GunData, bullet: BulletData = null) -> int:
	var depth := int(profile_for_gun(gun).get("line_depth", 0))
	if bullet != null and bullet.effect_type == Enums.BulletEffect.PIERCE:
		depth += maxi(bullet.effect_value, 1)
	return depth


static func line_damage_for_gun(_gun: GunData, depth_index: int, heavy_boost: bool = false) -> int:
	if depth_index < 0:
		return 0
	if heavy_boost and depth_index == 0:
		return HEAVY_FIRST_REAR_DAMAGE
	## 주 대상 피해·크리티컬·조건부 화력이 후열 수만큼 복제되지 않도록 고정 스침 피해를 쓴다.
	## 관통탄으로 늘어난 깊이와 비소총 계열의 단발 관통도 같은 값을 사용한다.
	return RIFLE_REAR_DAMAGE


static func shotgun_damage_for_distance(base_damage: int, distance: int) -> int:
	if base_damage <= 0:
		return 0
	if distance <= SHOTGUN_MAX_RANGE:
		return base_damage
	return maxi(base_damage - SHOTGUN_LONG_RANGE_DAMAGE_PENALTY, 1)


static func scatter_count_for_gun(gun: GunData, spread_part: bool = false) -> int:
	var count := int(profile_for_gun(gun).get("scatter_count", 0))
	return count + (1 if spread_part and count > 0 else 0)


static func scatter_radius_for_gun(gun: GunData, spread_part: bool = false) -> int:
	var radius := int(profile_for_gun(gun).get("scatter_radius", 0))
	return radius + (1 if spread_part and radius > 0 else 0)


static func collateral_damage(base_damage: int, ratio: float) -> int:
	if base_damage <= 0 or ratio <= 0.0:
		return 0
	return maxi(1, floori(float(base_damage) * ratio))


static func category_label_for_class(weapon_class: int) -> String:
	if is_standard_class(weapon_class):
		return "표준 규격"
	if is_enhanced_class(weapon_class):
		return "강화 규격"
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
