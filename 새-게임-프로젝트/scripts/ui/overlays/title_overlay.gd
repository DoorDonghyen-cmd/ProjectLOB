class_name TitleOverlay
extends PanelContainer

## ═══════════════════════════════════════════════════
## 타이틀 및 영구 메타 상점 오버레이
## ═══════════════════════════════════════════════════

const DataLoader = preload("res://scripts/core/data_loader.gd")
const PlaytestLoggerScript = preload("res://scripts/core/playtest_logger.gd")

var parent_scene: Control
var run_manager: RunManager

var _meta_credit_label: Label
var _lore_fragment_label: Label
var _meta_backpack_btn: Button
var _meta_hp_armor_btn: Button
var _meta_discount_btn: Button
var _meta_vault_btn: Button

var _dev_test_panel: PanelContainer
var _reset_confirmation: ConfirmationDialog
var _reset_result_dialog: AcceptDialog
var _weapon_unlock_result_dialog: AcceptDialog
var _ascension_unlock_result_dialog: AcceptDialog


func initialize(p_scene: Control, rm: RunManager) -> void:
	parent_scene = p_scene
	run_manager = rm
	
	# 풀 화면 오버레이 스타일 적용
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.08, 0.95)
	add_theme_stylebox_override("panel", style)
	
	_build_ui()
	_refresh_shop_ui()


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_top", 36)
	margin.add_theme_constant_override("margin_bottom", 36)
	add_child(margin)
	
	_build_dev_test_panel()

	var main_hbox := HBoxContainer.new()
	main_hbox.add_theme_constant_override("separation", 32)
	margin.add_child(main_hbox)

	# ── 좌측: 메인 로고 및 시작 버튼 ──
	var left_vbox := VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 16)
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.size_flags_stretch_ratio = 0.4
	left_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_hbox.add_child(left_vbox)

	var logo: Label = parent_scene.make_label(" Last on Board ", 42, parent_scene.C_ACCENT)
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_vbox.add_child(logo)

	_meta_credit_label = parent_scene.make_label("보유 크레딧: 100", 22, parent_scene.C_WARNING)
	_meta_credit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_vbox.add_child(_meta_credit_label)
	
	_lore_fragment_label = parent_scene.make_label("기밀 정보 복원율: 0 / 20", 14, parent_scene.C_SUCCESS)
	_lore_fragment_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_vbox.add_child(_lore_fragment_label)

	# 빈 스페이스를 두어 시작 버튼이 하단에 예쁘게 깔리도록 함
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.add_child(spacer)

	var start_run_btn: Button = parent_scene.make_button("🚀 상승 개시 (런 시작)", _on_start_run_pressed, parent_scene.C_ACCENT)
	start_run_btn.custom_minimum_size = Vector2(0, 56)
	left_vbox.add_child(start_run_btn)

	var parts_test_btn: Button = parent_scene.make_button("🛠️ 개발자 테스트", _on_dev_test_pressed, parent_scene.C_WARNING)
	parts_test_btn.custom_minimum_size = Vector2(0, 40)
	left_vbox.add_child(parts_test_btn)

	# ── 우측: 영구 업그레이드 상점 및 게임 설정 ──
	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 14)
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_stretch_ratio = 0.6
	main_hbox.add_child(right_vbox)

	# ── 메타 해금 상점 패널 ──
	var shop_panel: PanelContainer = parent_scene.make_panel(parent_scene.C_PANEL_DARK)
	right_vbox.add_child(shop_panel)

	var shop_margin := MarginContainer.new()
	shop_margin.add_theme_constant_override("margin_left", 16)
	shop_margin.add_theme_constant_override("margin_right", 16)
	shop_margin.add_theme_constant_override("margin_top", 10)
	shop_margin.add_theme_constant_override("margin_bottom", 10)
	shop_panel.add_child(shop_margin)

	var shop_vbox := VBoxContainer.new()
	shop_vbox.add_theme_constant_override("separation", 6)
	shop_margin.add_child(shop_vbox)

	var shop_title: Label = parent_scene.make_label(" 영구 메타 업그레이드 상점", 18, parent_scene.C_DIM)
	shop_vbox.add_child(shop_title)

	_meta_backpack_btn = parent_scene.make_button("전술 백팩 (시작 전술탄 +1) Lv.0 -> Lv.1 (40 Cr)", _on_upgrade_backpack_pressed, parent_scene.C_PANEL)
	_meta_backpack_btn.custom_minimum_size = Vector2(0, 36)
	shop_vbox.add_child(_meta_backpack_btn)

	_meta_hp_armor_btn = parent_scene.make_button("나노 피하 아머 Lv.0 -> Lv.1 (50 Cr)", _on_upgrade_hp_armor_pressed, parent_scene.C_PANEL)
	_meta_hp_armor_btn.custom_minimum_size = Vector2(0, 36)
	shop_vbox.add_child(_meta_hp_armor_btn)

	_meta_discount_btn = parent_scene.make_button("암시장 커넥션 해금 (30 Cr)", _on_upgrade_discount_pressed, parent_scene.C_PANEL)
	_meta_discount_btn.custom_minimum_size = Vector2(0, 36)
	shop_vbox.add_child(_meta_discount_btn)

	_meta_vault_btn = parent_scene.make_button("전술 금고 해금 (30 Cr)", _on_upgrade_vault_pressed, parent_scene.C_PANEL)
	_meta_vault_btn.custom_minimum_size = Vector2(0, 36)
	shop_vbox.add_child(_meta_vault_btn)

	# 무기 설정은 요원 작전 준비실(LoadoutOverlay)로 통합되어 있습니다.




func _refresh_shop_ui() -> void:
	if _lore_fragment_label:
		_lore_fragment_label.text = "기밀 정보 복원율: %d / 20" % RunManager.meta_lore_fragments.size()
		
	_meta_credit_label.text = "보유 크레딧: %d" % RunManager.meta_credits
	_meta_backpack_btn.text = "전술 백팩 (시작 전술탄 +1) Lv.%d -> Lv.%d (40 Cr)" % [
		RunManager.meta_backpack_lvl,
		mini(RunManager.meta_backpack_lvl + 1, 3)
	]
	_meta_backpack_btn.disabled = RunManager.meta_backpack_lvl >= 3 or RunManager.meta_credits < 40
	
	_meta_hp_armor_btn.text = "나노 피하 아머 (HP 버퍼) Lv.%d -> Lv.%d (50 Cr)" % [
		RunManager.meta_hp_armor_lvl,
		mini(RunManager.meta_hp_armor_lvl + 1, 2)
	]
	_meta_hp_armor_btn.disabled = RunManager.meta_hp_armor_lvl >= 2 or RunManager.meta_credits < 50
	
	if RunManager.meta_discount_unlocked:
		_meta_discount_btn.text = "암시장 커넥션 (폐기 무료화) [해금 완료]"
		_meta_discount_btn.disabled = true
	else:
		_meta_discount_btn.text = "암시장 커넥션 해금 (30 Cr)"
		_meta_discount_btn.disabled = RunManager.meta_credits < 30

	var vault_cost := 0
	match RunManager.meta_vault_lvl:
		0: vault_cost = 30
		1: vault_cost = 45
		2: vault_cost = 60
		
	if RunManager.meta_vault_lvl >= 3:
		_meta_vault_btn.text = "전술 금고 (크레딧 이월) Lv.3 [최대 레벨]"
		_meta_vault_btn.disabled = true
	else:
		_meta_vault_btn.text = "전술 금고 (크레딧 이월) Lv.%d -> Lv.%d (%d Cr)" % [
			RunManager.meta_vault_lvl,
			RunManager.meta_vault_lvl + 1,
			vault_cost
		]
		_meta_vault_btn.disabled = RunManager.meta_credits < vault_cost


func _on_upgrade_backpack_pressed() -> void:
	if RunManager.upgrade_meta_backpack():
		_refresh_shop_ui()


func _on_upgrade_hp_armor_pressed() -> void:
	if RunManager.upgrade_meta_hp_armor():
		_refresh_shop_ui()


func _on_upgrade_discount_pressed() -> void:
	if RunManager.upgrade_meta_discount():
		_refresh_shop_ui()


func _on_upgrade_vault_pressed() -> void:
	if RunManager.upgrade_meta_vault():
		_refresh_shop_ui()


func _on_start_run_pressed() -> void:
	parent_scene.show_section_selector()


func _on_dev_test_pressed() -> void:
	if _dev_test_panel:
		_dev_test_panel.visible = true


## 개발자 테스트 팝업 패널 빌드
func _build_dev_test_panel() -> void:
	_dev_test_panel = PanelContainer.new()
	_dev_test_panel.custom_minimum_size = Vector2(720, 380) # 3열 슬롯 가로 와이드 비율
	_dev_test_panel.visible = false
	
	# 화면 정중앙 팝업 스타일
	_dev_test_panel.set_anchors_preset(Control.PRESET_CENTER)
	_dev_test_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_dev_test_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.98) # 어두운 패널
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = parent_scene.C_WARNING # 금색/노란색 테두리
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	_dev_test_panel.add_theme_stylebox_override("panel", style)
	
	add_child(_dev_test_panel)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	_dev_test_panel.add_child(margin)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)
	
	vbox.add_child(parent_scene.make_label("🛠️ 개발자 디버그 테스트", 16, parent_scene.C_WARNING))
	
	# 3열 바둑판식 슬롯 GridContainer 생성
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(grid)
	
	# 1. 무기고 3탭 단말기 테스트 숏컷 버튼
	var btn_parts = parent_scene.make_button("🛠️ 무기고 3탭 단말기 테스트", func():
		_dev_test_panel.visible = false
		parent_scene.trigger_parts_test_ui()
	, parent_scene.C_ACCENT)
	btn_parts.custom_minimum_size = Vector2(0, 36)
	btn_parts.add_theme_font_size_override("font_size", 11)
	btn_parts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(btn_parts)
	
	# 2. 요원 준비실 UI 테스트 숏컷 버튼
	var btn_loadout = parent_scene.make_button("🎒 요원 준비실 UI 테스트", func():
		_dev_test_panel.visible = false
		parent_scene.trigger_loadout_test_ui()
	, parent_scene.C_ACCENT)
	btn_loadout.custom_minimum_size = Vector2(0, 36)
	btn_loadout.add_theme_font_size_override("font_size", 11)
	btn_loadout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(btn_loadout)
	
	# 3. 탄환 이미지 갤러리 테스트 숏컷 버튼
	var btn_gallery = parent_scene.make_button("🔴 탄환 이미지 갤러리 테스트", func():
		_dev_test_panel.visible = false
		parent_scene.trigger_bullet_gallery_ui()
	, parent_scene.C_ACCENT)
	btn_gallery.custom_minimum_size = Vector2(0, 36)
	btn_gallery.add_theme_font_size_override("font_size", 11)
	btn_gallery.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(btn_gallery)
	
	# 3-2. 몬스터 이미지 갤러리 테스트 숏컷 버튼
	var btn_monster_gallery = parent_scene.make_button("👾 몬스터 갤러리 테스트", func():
		_dev_test_panel.visible = false
		parent_scene.trigger_monster_gallery_ui()
	, parent_scene.C_ACCENT)
	btn_monster_gallery.custom_minimum_size = Vector2(0, 36)
	btn_monster_gallery.add_theme_font_size_override("font_size", 11)
	btn_monster_gallery.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(btn_monster_gallery)
	
	# 4. 기관단총 연발 체인 테스트
	var btn_tempo_full_auto = parent_scene.make_button("⚡ 연발 체인 테스트 (기관단총)", func():
		_dev_test_panel.visible = false
		parent_scene.trigger_tempo_full_auto_test()
	, parent_scene.C_ACCENT)
	btn_tempo_full_auto.custom_minimum_size = Vector2(0, 36)
	btn_tempo_full_auto.add_theme_font_size_override("font_size", 11)
	btn_tempo_full_auto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(btn_tempo_full_auto)

	# 4-1. 연발(제압형) 전투 테스트 — 다수전 이월 + 적재 퍼즐 + 리로드 공백
	var btn_full_auto = parent_scene.make_button("🌪 연발 전투 테스트 (제압형)", func():
		_dev_test_panel.visible = false
		parent_scene.trigger_full_auto_test()
	, parent_scene.C_ACCENT)
	btn_full_auto.custom_minimum_size = Vector2(0, 36)
	btn_full_auto.add_theme_font_size_override("font_size", 11)
	btn_full_auto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(btn_full_auto)

	# 4-2. 🔥 새 전투 UI 데모 (v2) 실행 버튼
	var btn_v2_ui = parent_scene.make_button("🔥 새 전투 UI 데모 (v2)", func():
		_dev_test_panel.visible = false
		parent_scene.trigger_v2_ui_test()
	, parent_scene.C_SUCCESS)
	btn_v2_ui.custom_minimum_size = Vector2(0, 36)
	btn_v2_ui.add_theme_font_size_override("font_size", 11)
	btn_v2_ui.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(btn_v2_ui)

	# 모바일 스캔과 연계→결산 예고, Tempo 2탄창 호흡을 한 흐름에서 확인하는 통합 QA.
	var btn_guidance_ui = parent_scene.make_button("🔎 스캔·연계·결산 QA", func():
		_dev_test_panel.visible = false
		parent_scene.trigger_scan_guidance_test()
	, parent_scene.C_SUCCESS)
	btn_guidance_ui.name = "ScanAmmoGuidanceTestButton"
	btn_guidance_ui.custom_minimum_size = Vector2(0, 36)
	btn_guidance_ui.add_theme_font_size_override("font_size", 11)
	btn_guidance_ui.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(btn_guidance_ui)

	var btn_ammo_specialty = parent_scene.make_button("🎯 탄환 전문축 QA", func():
		_dev_test_panel.visible = false
		parent_scene.trigger_ammo_specialty_test()
	, parent_scene.C_SUCCESS)
	btn_ammo_specialty.name = "AmmoSpecialtyTestButton"
	btn_ammo_specialty.tooltip_text = "기본탄과 ACC·PEN·DMG·CTRL 전술탄 배지, 다음 1발 강화를 즉시 확인합니다."
	btn_ammo_specialty.custom_minimum_size = Vector2(0, 36)
	btn_ammo_specialty.add_theme_font_size_override("font_size", 11)
	btn_ammo_specialty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(btn_ammo_specialty)

	# 계층을 다시 오르지 않고 동일한 Workhorse 탄약으로 상층 4체 편성을 비교한다.
	var btn_management_roster = parent_scene.make_button("🏢 관리 계층 편성 QA", func():
		_dev_test_panel.visible = false
		parent_scene.trigger_upper_roster_test("section_d")
	, parent_scene.C_SUCCESS)
	btn_management_roster.name = "ManagementRosterTestButton"
	btn_management_roster.tooltip_text = "관리 계층 종반 대표 4체 편성을 Workhorse 공통 탄약으로 즉시 시작합니다."
	btn_management_roster.custom_minimum_size = Vector2(0, 36)
	btn_management_roster.add_theme_font_size_override("font_size", 11)
	btn_management_roster.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(btn_management_roster)

	var btn_apex_roster = parent_scene.make_button("🔺 정점 편성 QA", func():
		_dev_test_panel.visible = false
		parent_scene.trigger_upper_roster_test("section_e")
	, parent_scene.C_SUCCESS)
	btn_apex_roster.name = "ApexRosterTestButton"
	btn_apex_roster.tooltip_text = "정점 종반 대표 4체 편성을 Workhorse 공통 탄약으로 즉시 시작합니다."
	btn_apex_roster.custom_minimum_size = Vector2(0, 36)
	btn_apex_roster.add_theme_font_size_override("font_size", 11)
	btn_apex_roster.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(btn_apex_roster)
	
	# 4-3. ♻️ 덱 순환(버림/소멸) 테스트 실행 버튼
	var btn_pile_test = parent_scene.make_button("♻️ 덱 순환 테스트 실행", func():
		_dev_test_panel.visible = false
		parent_scene.trigger_v2_ui_test()
		
		# 데모 시작 후 즉시 임의의 탄환 소멸/버림 상태 모의 적용 (지연 호출)
		var t = parent_scene.get_tree().create_timer(0.2)
		t.timeout.connect(func():
			var main_scene = parent_scene
			var cm = main_scene.get_node_or_null("CombatManager")
			if not cm:
				cm = main_scene.get_tree().root.find_child("CombatManager", true, false)
			
			if cm and cm.draw_pile.size() >= 3:
				var disc_b = cm.draw_pile.pop_back()
				cm.discard_pile.append(disc_b)
				
				var ex_b1 = cm.draw_pile.pop_back()
				cm.exile_pile.append(ex_b1)
				
				var ex_b2 = cm.draw_pile.pop_back()
				cm.exile_pile.append(ex_b2)
				
				cm.piles_updated.emit(cm.draw_pile, cm.discard_pile, cm.exile_pile)
				cm.combat_log.emit("⚙️ [디버그 테스트] 임의로 탄환 1발 버림, 2발 소멸 처리되었습니다. (서랍 탭에서 확인 가능)")
		)
	, parent_scene.C_SUCCESS)
	btn_pile_test.custom_minimum_size = Vector2(0, 36)
	btn_pile_test.add_theme_font_size_override("font_size", 11)
	btn_pile_test.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(btn_pile_test)
	
	# 4-4. 💥 [Visual] 격발/반동/파티클 테스트 실행 버튼
	var btn_effect_test = parent_scene.make_button("💥 격발/반동/파티클 테스트", func():
		_dev_test_panel.visible = false
		parent_scene.trigger_v2_ui_test()
		
		var t = parent_scene.get_tree().create_timer(0.4)
		t.timeout.connect(func():
			var main_scene = parent_scene
			var overlay = main_scene.get_node_or_null("CombatOverlayV2")
			if not overlay:
				overlay = main_scene.get_tree().root.find_child("CombatOverlayV2", true, false)
			
			if overlay and overlay.has_method("_on_bullet_fired"):
				var test_bullet = overlay._bullets_basic
				# bullet, hit, damage
				overlay._on_bullet_fired(test_bullet, true, 8)
				overlay.add_combat_log("⚙️ [디버그 테스트] 격발 및 파티클 연쇄 연출이 테스트되었습니다.")
		)
	, parent_scene.C_SUCCESS)
	btn_effect_test.custom_minimum_size = Vector2(0, 36)
	btn_effect_test.add_theme_font_size_override("font_size", 11)
	btn_effect_test.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(btn_effect_test)
	
	# 4-4-2. ♻️ [Visual] 탄환 반환 플로팅 테스트 실행 버튼
	var btn_refund_test = parent_scene.make_button("♻️ 탄환 반환 플로팅 테스트", func():
		_dev_test_panel.visible = false
		parent_scene.trigger_v2_ui_test()
		
		var t = parent_scene.get_tree().create_timer(0.4)
		t.timeout.connect(func():
			var main_scene = parent_scene
			var overlay = main_scene.get_node_or_null("CombatOverlayV2")
			if not overlay:
				overlay = main_scene.get_tree().root.find_child("CombatOverlayV2", true, false)
			
			if overlay and overlay.has_method("_on_bullet_fired"):
				var test_bullet = overlay._bullets_basic
				# bullet, hit, damage
				overlay._on_bullet_fired(test_bullet, true, 5)
				overlay.add_combat_log("⚙️ [디버그 테스트] 탄환 적중 반환 UI 플로팅 연출이 테스트되었습니다.")
		)
	, parent_scene.C_SUCCESS)
	btn_refund_test.custom_minimum_size = Vector2(0, 36)
	btn_refund_test.add_theme_font_size_override("font_size", 11)
	btn_refund_test.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(btn_refund_test)
	
	# 4-5. 👾 [Visual] 몬스터 전진 트윈 테스트 실행 버튼
	var btn_move_test = parent_scene.make_button("👾 몬스터 전진 트윈 테스트", func():
		_dev_test_panel.visible = false
		parent_scene.trigger_v2_ui_test()
		
		var t = parent_scene.get_tree().create_timer(0.4)
		t.timeout.connect(func():
			var main_scene = parent_scene
			var cm = main_scene.get_node_or_null("CombatManager")
			if not cm:
				cm = main_scene.get_tree().root.find_child("CombatManager", true, false)
			var overlay = main_scene.get_node_or_null("CombatOverlayV2")
			if not overlay:
				overlay = main_scene.get_tree().root.find_child("CombatOverlayV2", true, false)
				
			if cm and overlay and cm.enemy:
				var origin_dist = cm.enemy.current_distance
				cm.enemy.current_distance = max(1, origin_dist - 3)
				
				if overlay._track_control:
					overlay._track_control.update_enemy_position_and_scale()
					overlay._track_control.update_distance_display(cm.enemy)
					overlay.add_combat_log("⚙️ [디버그 테스트] 적 3m 전진에 의한 뒤뚱거림 이동 트윈이 테스트되었습니다.")
					
				var t_restore = parent_scene.get_tree().create_timer(1.5)
				t_restore.timeout.connect(func():
					cm.enemy.current_distance = origin_dist
					if overlay._track_control:
						overlay._track_control.update_enemy_position_and_scale()
						overlay._track_control.update_distance_display(cm.enemy)
				)
		)
	, parent_scene.C_SUCCESS)
	btn_move_test.custom_minimum_size = Vector2(0, 36)
	btn_move_test.add_theme_font_size_override("font_size", 11)
	btn_move_test.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(btn_move_test)
	
	# 5. 해금 및 보상 테스트 숏컷 버튼
	var btn_unlock_test = parent_scene.make_button("🔑 해금 및 보상 테스트", func():
		_dev_test_panel.visible = false
		RunManager.meta_tactical_data_cores += 10

		# ⚠️ 해금 대상을 하드코딩하지 않는다. 준비실 목록에서 읽어야
		#    총기를 추가할 때마다 이 버튼이 어긋나지 않는다.
		#    (과거 marksman·tempo 2종만 박혀 있어 이후 추가된 총기는 해금되지 않았다.)
		for weapon_key in LoadoutOverlay.WEAPON_PROFILES.keys():
			if not RunManager.meta_unlocked_weapons.has(weapon_key):
				RunManager.meta_unlocked_weapons.append(String(weapon_key))

		# 전 계층 해금
		RunManager.meta_unlocked_sections = [] as Array[String]
		for sec in RunManager.SECTION_ORDER:
			RunManager.meta_unlocked_sections.append(String(sec))

		# 기밀 정보 파편 19개 수집 상태 프리셋
		# (20개가 아니라 19개인 것은 의도적 — 결말의 심화 파편이 아직 안 뜨는 상태를 본다)
		RunManager.meta_lore_fragments.clear()
		for i in range(1, 20):
			RunManager.meta_lore_fragments.append(i)

		print("디버그: TDC +10, 무기 %d종 전체 해금, 전 계층 해금, 기밀 파편 19/20 프리셋 완료." %
			LoadoutOverlay.WEAPON_PROFILES.size())
		_refresh_shop_ui()
		parent_scene.trigger_loadout_test_ui()
	, parent_scene.C_WARNING)
	btn_unlock_test.custom_minimum_size = Vector2(0, 36)
	btn_unlock_test.add_theme_font_size_override("font_size", 11)
	btn_unlock_test.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(btn_unlock_test)

	# 다른 메타 진행도를 건드리지 않고 모든 무기만 영구 해금한다.
	var btn_unlock_all_weapons = parent_scene.make_button("🔓 모든 무기 해금", func():
		_on_unlock_all_weapons_pressed()
	, parent_scene.C_WARNING)
	btn_unlock_all_weapons.name = "UnlockAllWeaponsButton"
	btn_unlock_all_weapons.tooltip_text = "준비실의 모든 무기를 영구 해금합니다. '전부 초기화'로 되돌릴 수 있습니다."
	btn_unlock_all_weapons.custom_minimum_size = Vector2(0, 36)
	btn_unlock_all_weapons.add_theme_font_size_override("font_size", 11)
	btn_unlock_all_weapons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(btn_unlock_all_weapons)

	# 실제 플레이 튜닝 시 10회 완주 없이 원하는 승천 등급을 즉시 비교한다.
	var btn_unlock_all_ascension = parent_scene.make_button("🔺 모든 승천 해금", func():
		_on_unlock_all_ascension_pressed()
	, parent_scene.C_WARNING)
	btn_unlock_all_ascension.name = "UnlockAllAscensionButton"
	btn_unlock_all_ascension.tooltip_text = "승천 0~10등급을 모두 선택할 수 있게 영구 해금합니다. 현재 적용 등급은 바꾸지 않습니다."
	btn_unlock_all_ascension.custom_minimum_size = Vector2(0, 36)
	btn_unlock_all_ascension.add_theme_font_size_override("font_size", 11)
	btn_unlock_all_ascension.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(btn_unlock_all_ascension)
	
	# 6. 📊 밸런스 매트릭스 뷰 버튼
	var btn_matrix = parent_scene.make_button("📊 밸런스 매트릭스 뷰", func():
		_show_balance_matrix_popup()
	, parent_scene.C_ACCENT)
	btn_matrix.custom_minimum_size = Vector2(0, 36)
	btn_matrix.add_theme_font_size_override("font_size", 11)
	btn_matrix.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(btn_matrix)

	# 플레이테스트 JSON을 바로 공유할 수 있게 로컬 저장 폴더를 연다.
	var btn_playtest_logs = parent_scene.make_button("🗂 플레이테스트 로그", func():
		var error := PlaytestLoggerScript.open_log_directory()
		if error != OK:
			push_warning("플레이테스트 로그 폴더 열기 실패: %d" % error)
	, parent_scene.C_ACCENT)
	btn_playtest_logs.name = "OpenPlaytestLogFolderButton"
	btn_playtest_logs.tooltip_text = "런별 전투·탄환·파츠 활용 내역이 저장된 JSON 폴더를 엽니다."
	btn_playtest_logs.custom_minimum_size = Vector2(0, 36)
	btn_playtest_logs.add_theme_font_size_override("font_size", 11)
	btn_playtest_logs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(btn_playtest_logs)
	
	# 7. 🗺️ 모든 작전 구역 해금 디버그 숏컷
	var btn_unlock_zones = parent_scene.make_button("🔓 모든 작전 지역 해금", func():
		RunManager.meta_unlocked_sections = ["section_a", "section_b", "section_c", "section_d", "section_e"]
		print("디버그: 모든 작전 침투 구역 해금 완료!")
	, parent_scene.C_WARNING)
	btn_unlock_zones.custom_minimum_size = Vector2(0, 36)
	btn_unlock_zones.add_theme_font_size_override("font_size", 11)
	btn_unlock_zones.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(btn_unlock_zones)
	
	# 8. 🔒 작전 구역 초기화 디버그 숏컷
	var btn_lock_zones = parent_scene.make_button("🔒 작전 구역 초기화", func():
		RunManager.meta_unlocked_sections = ["section_a"]
		print("디버그: 계층 해금 초기화 완료 (최하 계층만 활성)!")
	, parent_scene.C_WARNING)
	btn_lock_zones.custom_minimum_size = Vector2(0, 36)
	btn_lock_zones.add_theme_font_size_override("font_size", 11)
	btn_lock_zones.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(btn_lock_zones)

	# 9. 모든 런·영구 메타·세이브 초기화
	var btn_reset_all = parent_scene.make_button("🧹 전부 초기화", func():
		_reset_confirmation.popup_centered()
	, parent_scene.C_DANGER)
	btn_reset_all.name = "ResetAllProgressButton"
	btn_reset_all.tooltip_text = "현재 런과 크레딧·업그레이드·해금·승천·세이브를 첫 실행 상태로 되돌립니다."
	btn_reset_all.custom_minimum_size = Vector2(0, 36)
	btn_reset_all.add_theme_font_size_override("font_size", 11)
	btn_reset_all.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(btn_reset_all)

	_reset_confirmation = ConfirmationDialog.new()
	_reset_confirmation.name = "ResetAllProgressConfirmation"
	_reset_confirmation.title = "전체 데이터 초기화"
	_reset_confirmation.dialog_text = (
		"현재 런과 모든 영구 진행 데이터를 삭제합니다.\n"
		+ "크레딧·업그레이드·무기/계층 해금·로어·승천은 복구할 수 없습니다."
	)
	_reset_confirmation.ok_button_text = "전부 초기화"
	_reset_confirmation.cancel_button_text = "취소"
	_reset_confirmation.confirmed.connect(_on_reset_all_confirmed)
	add_child(_reset_confirmation)

	_reset_result_dialog = AcceptDialog.new()
	_reset_result_dialog.name = "ResetAllProgressResult"
	_reset_result_dialog.title = "전체 데이터 초기화"
	add_child(_reset_result_dialog)

	_weapon_unlock_result_dialog = AcceptDialog.new()
	_weapon_unlock_result_dialog.name = "UnlockAllWeaponsResult"
	_weapon_unlock_result_dialog.title = "모든 무기 해금"
	add_child(_weapon_unlock_result_dialog)

	_ascension_unlock_result_dialog = AcceptDialog.new()
	_ascension_unlock_result_dialog.name = "UnlockAllAscensionResult"
	_ascension_unlock_result_dialog.title = "모든 승천 해금"
	add_child(_ascension_unlock_result_dialog)
	
	# ── 보스 전투 테스트 숏컷 ──
	# 보스 #1: 디렉터 강 (구역 1 보스)
	var btn_boss1 = parent_scene.make_button("🔴 보스: 디렉터 강", func():
		_dev_test_panel.visible = false
		parent_scene.trigger_boss_test("boss_director")
	, parent_scene.C_DANGER)
	btn_boss1.custom_minimum_size = Vector2(0, 36)
	btn_boss1.add_theme_font_size_override("font_size", 11)
	btn_boss1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(btn_boss1)
	
	# 보스 #2: 세라프 방어 프로토콜 (구역 2 보스)
	var btn_boss2 = parent_scene.make_button("🟡 보스: 세라프 방어 프로토콜", func():
		_dev_test_panel.visible = false
		parent_scene.trigger_boss_test("boss_seraph")
	, parent_scene.C_DANGER)
	btn_boss2.custom_minimum_size = Vector2(0, 36)
	btn_boss2.add_theme_font_size_override("font_size", 11)
	btn_boss2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(btn_boss2)
	
	# 보스 #3: 적합성 개조체 Ω (구역 3 보스)
	var btn_boss3 = parent_scene.make_button("🟠 보스: 적합성 개조체 Ω", func():
		_dev_test_panel.visible = false
		parent_scene.trigger_boss_test("boss_omega")
	, parent_scene.C_DANGER)
	btn_boss3.custom_minimum_size = Vector2(0, 36)
	btn_boss3.add_theme_font_size_override("font_size", 11)
	btn_boss3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(btn_boss3)
	
	# 최종 보스: L.O.B 코어
	var btn_boss4 = parent_scene.make_button("🔵 최종: L.O.B 코어", func():
		_dev_test_panel.visible = false
		parent_scene.trigger_boss_test("boss_lob_core")
	, parent_scene.C_DANGER)
	btn_boss4.custom_minimum_size = Vector2(0, 36)
	btn_boss4.add_theme_font_size_override("font_size", 11)
	btn_boss4.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(btn_boss4)
	
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)
	
	# 닫기 버튼
	var btn_close = parent_scene.make_button("❌ 닫기", func():
		_dev_test_panel.visible = false
	, parent_scene.C_DANGER)
	btn_close.custom_minimum_size = Vector2(240, 36)
	btn_close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(btn_close)


func _on_unlock_all_weapons_pressed() -> void:
	var added_count := 0
	for weapon_key_variant in LoadoutOverlay.WEAPON_PROFILES.keys():
		var weapon_key := String(weapon_key_variant)
		if not RunManager.meta_unlocked_weapons.has(weapon_key):
			RunManager.meta_unlocked_weapons.append(weapon_key)
			added_count += 1

	var result := RunManager.save_meta()
	_refresh_shop_ui()
	if result == OK:
		_weapon_unlock_result_dialog.dialog_text = (
			"모든 무기 %d종을 사용할 수 있습니다.\n이번에 새로 해금: %d종"
			% [LoadoutOverlay.WEAPON_PROFILES.size(), added_count]
		)
		print("디버그: 모든 무기 %d종 영구 해금 완료 (신규 %d종)." % [
			LoadoutOverlay.WEAPON_PROFILES.size(), added_count])
	else:
		_weapon_unlock_result_dialog.dialog_text = (
			"메모리에는 반영했지만 세이브 파일 갱신에 실패했습니다.\n오류 코드: %d" % result
		)
		push_error("모든 무기 해금 세이브 처리 실패: %d" % result)
	_weapon_unlock_result_dialog.popup_centered()


func _on_unlock_all_ascension_pressed() -> void:
	var previous_unlocked := RunManager.meta_ascension_unlocked
	RunManager.meta_ascension_unlocked = Ascension.MAX_LEVEL
	# 비교 중이던 등급을 갑자기 바꾸지 않는다. 해금 범위만 넓힌다.
	RunManager.meta_ascension_level = clampi(
		RunManager.meta_ascension_level, 0, RunManager.meta_ascension_unlocked)

	var result := RunManager.save_meta()
	if result == OK:
		_ascension_unlock_result_dialog.dialog_text = (
			"승천 0~%d등급을 모두 선택할 수 있습니다.\n현재 적용 등급: %d (변경 없음)"
			% [Ascension.MAX_LEVEL, RunManager.meta_ascension_level]
		)
		print("디버그: 승천 %d등급 전체 영구 해금 완료 (기존 %d등급)." % [
			Ascension.MAX_LEVEL, previous_unlocked])
	else:
		_ascension_unlock_result_dialog.dialog_text = (
			"메모리에는 반영했지만 세이브 파일 갱신에 실패했습니다.\n오류 코드: %d" % result
		)
		push_error("모든 승천 해금 세이브 처리 실패: %d" % result)
	_ascension_unlock_result_dialog.popup_centered()


func _on_reset_all_confirmed() -> void:
	_dev_test_panel.visible = false
	var result: Error = parent_scene.trigger_reset_all_progress()
	_refresh_shop_ui()
	if result == OK:
		_reset_result_dialog.dialog_text = "모든 데이터가 초기 상태로 복원되었습니다."
		print("디버그: 현재 런·영구 메타·세이브 전체 초기화 완료.")
	else:
		_reset_result_dialog.dialog_text = (
			"메모리는 초기화했지만 세이브 파일 갱신에 실패했습니다.\n오류 코드: %d" % result
		)
		push_error("전체 데이터 초기화 세이브 처리 실패: %d" % result)
	_reset_result_dialog.popup_centered()


## 📊 밸런스 기대 발수 매트릭스 팝업 렌더링
func _show_balance_matrix_popup() -> void:
	# 리로딩 보장
	DataLoader._loaded = false
	DataLoader.ensure_loaded()
	
	var popup := PanelContainer.new()
	popup.custom_minimum_size = Vector2(800, 520)
	popup.set_anchors_preset(Control.PRESET_CENTER)
	popup.grow_horizontal = Control.GROW_DIRECTION_BOTH
	popup.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08, 0.98)
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_color = parent_scene.C_ACCENT
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	popup.add_theme_stylebox_override("panel", style)
	
	add_child(popup)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	popup.add_child(margin)
	
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	margin.add_child(layout)
	
	# 상단 헤더
	var title_lbl: Label = parent_scene.make_label("📊 L.O.B 전술 밸런스 검증 매트릭스 (CSV 연동)", 22, parent_scene.C_ACCENT)
	layout.add_child(title_lbl)
	
	var desc_lbl := Label.new()
	desc_lbl.text = "현재 CSV 스탯 기준 시뮬레이션 결과입니다. (각 칸 = 뚫림/막힘 + 기대 처치 사격 발수)"
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.add_theme_color_override("font_color", parent_scene.C_DIM)
	layout.add_child(desc_lbl)
	
	# 그리드 콘테이너 (표 구성)
	var grid := GridContainer.new()
	# 열 수 = 1(적 이름) + 탄환 종류 개수
	var bullets: Array = DataLoader.get_all_bullets()
	grid.columns = 1 + bullets.size()
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(grid)
	
	# 1. 그리드 가로 헤더 그리기
	var corner: Label = parent_scene.make_label("적 아키타입 \\ 탄환", 13, parent_scene.C_NEON_GOLD)
	corner.custom_minimum_size = Vector2(160, 0)
	grid.add_child(corner)
	
	for b in bullets:
		var b_hdr: Label = parent_scene.make_label("%s\n(DMG:%d/PEN:%d/ACC:%d)" % [
			b.display_name.split(" ")[0], b.damage, b.penetration, b.accuracy
		], 12, parent_scene.C_NEON_GOLD)
		b_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b_hdr.custom_minimum_size = Vector2(140, 0)
		grid.add_child(b_hdr)
		
	# 2. 그리드 데이터 행 그리기
	var enemies: Array = DataLoader.get_all_enemies()
	for e in enemies:
		# 첫 열: 적 이름 및 기본 스탯
		var e_lbl: Label = parent_scene.make_label("%s\n(HP:%d/DEF:%d/EVA:%d)" % [
			e.display_name, e.max_hp, e.defense, e.evasion
		], 12, parent_scene.C_TEXT)
		e_lbl.custom_minimum_size = Vector2(160, 0)
		grid.add_child(e_lbl)
		
		# 각 탄환별 계산
		for b in bullets:
			var acc: int = b.accuracy
			var eva: int = e.evasion
			var pen: int = b.penetration
			var def: int = e.defense
			
			var is_hit = acc >= eva
			var is_pen = pen >= def
			
			var cell_text := ""
			var cell_color: Color = parent_scene.C_TEXT
			
			# 스펀지 아키타입(4) 여부
			var is_sponge: bool = (e.archetype == 4)
			
			if not is_hit:
				cell_text = "❌ 회피 (0%)"
				cell_color = parent_scene.C_DANGER
			elif not is_pen:
				cell_text = "🛡️ 도탄 (막힘)"
				cell_color = Color(0.9, 0.45, 0.2)
			else:
				# 명중하고 관통 성공
				var shots := 0
				if is_sponge:
					# 스펀지는 데미지 무관하게 배리어 3칸(위험도 4는 4칸이지만 디폴트 3 시뮬) 차감 처치
					shots = 3
				else:
					shots = ceil(float(e.max_hp) / float(b.damage))
				cell_text = "🎯 통과 (%d발)" % shots
				cell_color = parent_scene.C_SUCCESS
				
			var cell_lbl: Label = parent_scene.make_label(cell_text, 12, cell_color)
			cell_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			grid.add_child(cell_lbl)
			
	# 하단 닫기 버튼
	var btn_close_popup = parent_scene.make_button("❌ 시뮬레이션 닫기", func():
		popup.queue_free()
	, parent_scene.C_DANGER)
	btn_close_popup.custom_minimum_size = Vector2(180, 40)
	btn_close_popup.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	layout.add_child(btn_close_popup)
