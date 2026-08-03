extends RefCounted
## 고정 구경 프로필 회귀 검증.
## 구경은 런 중 교체하는 빌드 축이 아니라 총기 선택 시 고정되는 탄도 성향이며,
## 해당 총기의 기반탄에는 중복 적용하지 않고 공용 전술탄에만 적용한다.

const CaliberProfilesScript := preload("res://scripts/core/caliber_profiles.gd")
const DamageCalculatorScript := preload("res://scripts/core/damage_calculator.gd")

const GUN_PATHS := {
	Enums.WeaponClass.PISTOL: "res://resources/guns/revolver.tres",
	Enums.WeaponClass.SMG: "res://resources/guns/gambler.tres",
	Enums.WeaponClass.RIFLE: "res://resources/guns/suppressor.tres",
	Enums.WeaponClass.DMR: "res://resources/guns/dmr.tres",
	Enums.WeaponClass.SHOTGUN: "res://resources/guns/shotgun.tres",
}


static func _assert_stats(t, actual: Dictionary, expected: Dictionary, label: String) -> void:
	for stat in ["damage", "penetration", "accuracy", "knockback"]:
		t.eq(actual[stat], expected[stat], "%s %s" % [label, stat.to_upper()])


static func _all_bullets() -> Array[BulletData]:
	var bullets: Array[BulletData] = []
	for file_name in DirAccess.get_files_at("res://resources/bullets"):
		if not file_name.ends_with(".tres"):
			continue
		var resource = load("res://resources/bullets/%s" % file_name)
		if resource is BulletData:
			bullets.append(resource)
	return bullets


static func run(t) -> void:
	t.section("CaliberProfiles(fixed identity)")

	t.eq(CaliberProfilesScript.STANDARD_CLASSES.size(), 3, "플레이어 기본 학습 규격은 3종")
	t.eq(CaliberProfilesScript.ENHANCED_CLASSES.size(), 2, "같은 탄종의 강화 규격은 2종")
	t.check(CaliberProfilesScript.is_standard_class(Enums.WeaponClass.PISTOL), "9mm는 표준 규격")
	t.check(CaliberProfilesScript.is_standard_class(Enums.WeaponClass.RIFLE), "5.56mm는 표준 규격")
	t.check(CaliberProfilesScript.is_standard_class(Enums.WeaponClass.SHOTGUN), "12게이지는 표준 규격")
	t.check(CaliberProfilesScript.is_enhanced_class(Enums.WeaponClass.SMG), ".45ACP는 경량탄 강화 규격")
	t.check(CaliberProfilesScript.is_enhanced_class(Enums.WeaponClass.DMR), "7.62mm는 소총탄 강화 규격")
	t.eq(
		CaliberProfilesScript.short_label_for_class(Enums.WeaponClass.PISTOL),
		"표준 규격 · 경량탄 (9mm)",
		"표준 규격 UI 라벨"
	)
	t.eq(
		CaliberProfilesScript.short_label_for_class(Enums.WeaponClass.DMR),
		"강화 규격 · 소총탄 (7.62mm)",
		"강화 규격 UI 라벨"
	)
	var expected_names := {
		Enums.WeaponClass.PISTOL: ["경량탄", "9mm"],
		Enums.WeaponClass.RIFLE: ["소총탄", "5.56mm"],
		Enums.WeaponClass.SHOTGUN: ["산탄", "12게이지"],
		Enums.WeaponClass.SMG: ["경량탄", ".45ACP"],
		Enums.WeaponClass.DMR: ["소총탄", "7.62mm"],
	}
	for weapon_class in expected_names:
		var named_profile := CaliberProfilesScript.profile_for_class(weapon_class)
		t.eq(named_profile.name, expected_names[weapon_class][0], "플레이어 우선 규격명")
		t.eq(named_profile.technical_name, expected_names[weapon_class][1], "보조 기술 규격명")
		var native_bullet: BulletData = load({
			Enums.WeaponClass.PISTOL: "res://resources/bullets/cal_9mm.tres",
			Enums.WeaponClass.RIFLE: "res://resources/bullets/cal_556.tres",
			Enums.WeaponClass.SHOTGUN: "res://resources/bullets/cal_12g.tres",
			Enums.WeaponClass.SMG: "res://resources/bullets/cal_45acp.tres",
			Enums.WeaponClass.DMR: "res://resources/bullets/cal_762.tres",
		}[weapon_class])
		t.eq(native_bullet.display_name, expected_names[weapon_class][0], "기반탄 카드 역할명")

	var expected_profiles := {
		Enums.WeaponClass.PISTOL: {"damage": 0, "penetration": 0, "accuracy": 1, "knockback": 0},
		Enums.WeaponClass.SMG: {"damage": 1, "penetration": 0, "accuracy": 0, "knockback": 0},
		Enums.WeaponClass.RIFLE: {"damage": 0, "penetration": 1, "accuracy": 0, "knockback": 0},
		Enums.WeaponClass.DMR: {"damage": 1, "penetration": 1, "accuracy": -1, "knockback": 0},
		Enums.WeaponClass.SHOTGUN: {"damage": 1, "penetration": -1, "accuracy": -1, "knockback": 0},
	}
	for weapon_class in expected_profiles:
		var profile := CaliberProfilesScript.profile_for_class(weapon_class)
		for stat in expected_profiles[weapon_class]:
			t.eq(
				profile[stat],
				expected_profiles[weapon_class][stat],
				"%s 고정 프로필 %s" % [profile.name, stat.to_upper()]
			)

	var marker: BulletData = load("res://resources/bullets/marker.tres")
	_assert_stats(t, DamageCalculatorScript.effective_stats(marker, load(GUN_PATHS[Enums.WeaponClass.PISTOL])),
		{"damage": 2, "penetration": 1, "accuracy": 9, "knockback": 0}, "9mm+표식탄")
	_assert_stats(t, DamageCalculatorScript.effective_stats(marker, load(GUN_PATHS[Enums.WeaponClass.SMG])),
		{"damage": 3, "penetration": 1, "accuracy": 8, "knockback": 0}, ".45ACP+표식탄")
	_assert_stats(t, DamageCalculatorScript.effective_stats(marker, load(GUN_PATHS[Enums.WeaponClass.RIFLE])),
		{"damage": 2, "penetration": 2, "accuracy": 8, "knockback": 0}, "5.56mm+표식탄")
	_assert_stats(t, DamageCalculatorScript.effective_stats(marker, load(GUN_PATHS[Enums.WeaponClass.DMR])),
		{"damage": 3, "penetration": 2, "accuracy": 8, "knockback": 0}, "7.62mm+표식탄")
	_assert_stats(t, DamageCalculatorScript.effective_stats(marker, load(GUN_PATHS[Enums.WeaponClass.SHOTGUN])),
		{"damage": 3, "penetration": 0, "accuracy": 7, "knockback": 1}, "12게이지+표식탄")

	# 샷건 넉백 +1은 총기 자체 성향이다. 구경 프로필이 또 더해져 +2가 되면 안 된다.
	t.eq(
		CaliberProfilesScript.bonus_for(marker, load(GUN_PATHS[Enums.WeaponClass.SHOTGUN]), "knockback"),
		0,
		"12게이지 프로필은 샷건 총기 넉백을 중복 가산하지 않음"
	)

	# 구체 구경 기반탄에는 프로필을 다시 더하지 않는다.
	var native_9mm: BulletData = load("res://resources/bullets/cal_9mm.tres")
	var native_45: BulletData = load("res://resources/bullets/cal_45acp.tres")
	var revolver: GunData = load(GUN_PATHS[Enums.WeaponClass.PISTOL])
	var gambler: GunData = load(GUN_PATHS[Enums.WeaponClass.SMG])
	var tempo: GunData = load("res://resources/guns/smg.tres")
	t.eq(CaliberProfilesScript.line_damage_for_gun(revolver, 0), 1,
		"소총 후열 기본 스침 피해는 주 피해와 무관하게 1")
	t.eq(CaliberProfilesScript.line_damage_for_gun(revolver, 0, true), 2,
		"Heavy 초과 PEN의 첫 후열 스침 피해는 2")
	t.eq(CaliberProfilesScript.shotgun_damage_for_distance(5, 3), 5,
		"산탄 3m 이내 주 피해 유지")
	t.eq(CaliberProfilesScript.shotgun_damage_for_distance(5, 4), 3,
		"산탄 4m 이상 주 피해 2 감쇠")
	t.eq(CaliberProfilesScript.shotgun_damage_for_distance(1, 8), 1,
		"산탄 원거리 유효 피해 최소 1 보장")
	t.eq(DamageCalculatorScript.effective_stats(native_9mm, revolver).accuracy, 8,
		"9mm 기반탄에는 전술탄 ACC 프로필을 중복 적용하지 않음")
	t.eq(DamageCalculatorScript.effective_stats(native_45, gambler).damage, 3,
		".45ACP 기반탄 DMG 3을 프로필로 중복 가산하지 않음")
	t.eq(DamageCalculatorScript.effective_stats(native_45, tempo).damage, 2,
		"Tempo 고유 DMG -1은 .45ACP 기반탄에 정상 적용")

	# 5개 무기 클래스는 플레이어가 학습하는 3개 탄종 계열로 합쳐진다.
	t.eq(
		CaliberProfilesScript.family_for_class(Enums.WeaponClass.PISTOL),
		Enums.AmmoFamily.LIGHT,
		"9mm → 경량탄 계열"
	)
	t.eq(
		CaliberProfilesScript.family_for_class(Enums.WeaponClass.SMG),
		Enums.AmmoFamily.LIGHT,
		".45 ACP → 경량탄 계열"
	)
	t.eq(
		CaliberProfilesScript.family_for_class(Enums.WeaponClass.RIFLE),
		Enums.AmmoFamily.RIFLE,
		"5.56mm → 소총탄 계열"
	)
	t.eq(
		CaliberProfilesScript.family_for_class(Enums.WeaponClass.DMR),
		Enums.AmmoFamily.RIFLE,
		"7.62mm → 소총탄 계열"
	)
	t.eq(
		CaliberProfilesScript.family_for_class(Enums.WeaponClass.SHOTGUN),
		Enums.AmmoFamily.SHOTGUN,
		"12게이지 → 산탄 계열"
	)

	# 기본탄은 고정 보급 슬롯 전용이며 보상 드래프트는 공용 전술탄 14종으로 고정된다.
	var bullets := _all_bullets()
	t.eq(bullets.size(), 19, "현행 탄환 리소스 19종 로드")
	for weapon_class in GUN_PATHS:
		var run_manager := RunManager.new()
		run_manager.current_gun = load(GUN_PATHS[weapon_class])
		var eligible: Array[BulletData] = []
		for bullet in bullets:
			if run_manager.bullet_is_draft_eligible(bullet):
				eligible.append(bullet)
		t.eq(eligible.size(), 14,
			"%s 드래프트는 공용 전술탄 14종" % CaliberProfilesScript.profile_for_class(weapon_class).name)
		t.check(eligible.all(func(b: BulletData) -> bool: return not b.is_basic),
			"기본탄은 드래프트 후보에서 제외")
		t.check(eligible.all(func(b: BulletData) -> bool:
			return b.weapon_class == Enums.WeaponClass.UNIVERSAL or b.weapon_class == weapon_class),
			"다른 구경 기반탄은 드래프트 후보에서 제외")

	# 맵의 구경 게이트도 표시명 휴리스틱이 아니라 고정 프로필 클래스를 읽는다.
	var gate_for_dmr := RunManager.RunNode.new(1, "hidden", "7.62 gate", [] as Array[String])
	gate_for_dmr.is_hidden = true
	gate_for_dmr.unlock_condition_type = "caliber_762"
	var dmr_run := RunManager.new()
	dmr_run.current_gun = load(GUN_PATHS[Enums.WeaponClass.DMR])
	dmr_run.section_maps = {"test": {"map_nodes": {1: gate_for_dmr}}}
	dmr_run.update_conditional_paths()
	t.check(not gate_for_dmr.is_hidden, "7.62 고정 프로필 DMR은 구경 보안 게이트 개방")

	var gate_for_heavy := RunManager.RunNode.new(2, "hidden", "7.62 gate", [] as Array[String])
	gate_for_heavy.is_hidden = true
	gate_for_heavy.unlock_condition_type = "caliber_762"
	var heavy_run := RunManager.new()
	heavy_run.current_gun = load("res://resources/guns/heavy.tres")
	heavy_run.section_maps = {"test": {"map_nodes": {2: gate_for_heavy}}}
	heavy_run.update_conditional_paths()
	t.check(gate_for_heavy.is_hidden, "5.56 고정 프로필 Heavy는 7.62 게이트를 열지 않음")
