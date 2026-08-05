class_name ItemCatalog
extends RefCounted

## 상점·스타팅 보증·이벤트 보상이 공유하는 정식 아이템 카탈로그.
## 디렉터리 전수 탐색은 고유 파츠, 보류 중인 컨버전 킷, 기본 보급탄을 우회하므로 금지한다.

const SHOP_BULLET_IDS := [
	"marker", "borer", "jammer", "shred", "guide", "align",
	"ap", "pierce", "chain", "finale", "opener", "crosscal",
	"impact", "adhesive",
]

const GENERAL_PART_PATHS := [
	"res://resources/parts/rhythm_chamber.tres",
	"res://resources/parts/deep_loader.tres",
	"res://resources/parts/recoil_push.tres",
	"res://resources/parts/shred_muzzle.tres",
	"res://resources/parts/interrupter.tres",
	"res://resources/parts/underflow.tres",
	"res://resources/parts/chaser.tres",
	"res://resources/parts/long_shot.tres",
	"res://resources/parts/executioner.tres",
	"res://resources/parts/high_precision.tres",
	"res://resources/parts/armor_piercing.tres",
	"res://resources/parts/versatile_chamber.tres",
	"res://resources/parts/target_indicator.tres",
	"res://resources/parts/chain_acc.tres",
	"res://resources/parts/inertia_fire.tres",
	"res://resources/parts/blind_fire.tres",
	"res://resources/parts/quick_load.tres",
	"res://resources/parts/stance_foresight.tres",
	"res://resources/parts/stance_lock.tres",
	"res://resources/parts/scope.tres",
]

## 플레이테스트 피드백에 따라 재설계 전까지 모든 보상 경로에서 비활성이다.
const CONVERSION_KITS_ENABLED := false
const CONVERSION_KIT_PATHS := [
	"res://resources/parts/conversion_pistol.tres",
	"res://resources/parts/conversion_smg.tres",
	"res://resources/parts/conversion_rifle.tres",
	"res://resources/parts/conversion_dmr.tres",
	"res://resources/parts/conversion_shotgun.tres",
]


static func general_parts(tier: int = 0, excluded_ids: Dictionary = {}) -> Array[PartData]:
	var result: Array[PartData] = []
	for path in GENERAL_PART_PATHS:
		var part := load(path) as PartData
		if part == null or part.is_conversion_kit():
			continue
		if tier > 0 and part.tier != tier:
			continue
		if excluded_ids.has(part.part_id):
			continue
		result.append(part)
	return result


static func tactical_bullets(gun: GunData = null) -> Array[BulletData]:
	var result: Array[BulletData] = []
	for bullet_id in SHOP_BULLET_IDS:
		var bullet := load("res://resources/bullets/%s.tres" % bullet_id) as BulletData
		if bullet == null or bullet.is_basic:
			continue
		if gun != null and bullet.weapon_class != Enums.WeaponClass.UNIVERSAL \
			and bullet.weapon_class != gun.weapon_class:
			continue
		result.append(bullet)
	return result


static func owned_part_ids(run_manager: RunManager) -> Dictionary:
	var owned := {}
	if run_manager == null:
		return owned
	for part in run_manager.equipped_parts:
		if part != null:
			owned[part.part_id] = true
	for item in run_manager.backpack_items:
		if item is PartData:
			owned[item.part_id] = true
	if run_manager.hold_part != null:
		owned[run_manager.hold_part.part_id] = true
	return owned
