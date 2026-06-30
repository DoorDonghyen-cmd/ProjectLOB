class_name TitleOverlay
extends PanelContainer

## ═══════════════════════════════════════════════════
## 타이틀 및 영구 메타 상점 오버레이
## ═══════════════════════════════════════════════════

var parent_scene: Control
var run_manager: RunManager

var _meta_credit_label: Label
var _meta_backpack_btn: Button
var _meta_hp_armor_btn: Button
var _meta_discount_btn: Button

var _dev_test_panel: PanelContainer


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

	# 빈 스페이스를 두어 시작 버튼이 하단에 예쁘게 깔리도록 함
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.add_child(spacer)

	var start_run_btn: Button = parent_scene.make_button("🚀 봉쇄 빌딩 진입 (런 시작)", _on_start_run_pressed, parent_scene.C_ACCENT)
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

	_meta_backpack_btn = parent_scene.make_button("전술 전개 백팩 Lv.0 -> Lv.1 (40 Cr)", _on_upgrade_backpack_pressed, parent_scene.C_PANEL)
	_meta_backpack_btn.custom_minimum_size = Vector2(0, 36)
	shop_vbox.add_child(_meta_backpack_btn)

	_meta_hp_armor_btn = parent_scene.make_button("나노 피하 아머 Lv.0 -> Lv.1 (50 Cr)", _on_upgrade_hp_armor_pressed, parent_scene.C_PANEL)
	_meta_hp_armor_btn.custom_minimum_size = Vector2(0, 36)
	shop_vbox.add_child(_meta_hp_armor_btn)

	_meta_discount_btn = parent_scene.make_button("암시장 커넥션 해금 (30 Cr)", _on_upgrade_discount_pressed, parent_scene.C_PANEL)
	_meta_discount_btn.custom_minimum_size = Vector2(0, 36)
	shop_vbox.add_child(_meta_discount_btn)

	# 메타 해금 상점 아래의 무기 및 렐릭 설정란은 로드아웃 오버레이로 통합되어 이곳에서 제거되었습니다.




func _refresh_shop_ui() -> void:
	_meta_credit_label.text = "보유 크레딧: %d" % RunManager.meta_credits
	_meta_backpack_btn.text = "전술 백팩 (시작 덱 용량) Lv.%d -> Lv.%d (40 Cr)" % [
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


func _on_upgrade_backpack_pressed() -> void:
	if RunManager.upgrade_meta_backpack():
		_refresh_shop_ui()


func _on_upgrade_hp_armor_pressed() -> void:
	if RunManager.upgrade_meta_hp_armor():
		_refresh_shop_ui()


func _on_upgrade_discount_pressed() -> void:
	if RunManager.upgrade_meta_discount():
		_refresh_shop_ui()


func _on_start_run_pressed() -> void:
	parent_scene.show_loadout_screen()


func _on_dev_test_pressed() -> void:
	if _dev_test_panel:
		_dev_test_panel.visible = true


## 개발자 테스트 팝업 패널 빌드
func _build_dev_test_panel() -> void:
	_dev_test_panel = PanelContainer.new()
	_dev_test_panel.custom_minimum_size = Vector2(340, 240)
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
	vbox.add_theme_constant_override("separation", 14)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)
	
	vbox.add_child(parent_scene.make_label("🛠️ 개발자 디버그 테스트", 20, parent_scene.C_WARNING))
	
	# 1. 파츠 개조 UI 테스트 숏컷 버튼
	var btn_parts = parent_scene.make_button("🔧 파츠 개조 UI 테스트", func():
		_dev_test_panel.visible = false
		parent_scene.trigger_parts_test_ui()
	, parent_scene.C_ACCENT)
	btn_parts.custom_minimum_size = Vector2(0, 40)
	vbox.add_child(btn_parts)
	
	# 2. 요원 준비실 UI 테스트 숏컷 버튼
	var btn_loadout = parent_scene.make_button("🎒 요원 준비실 UI 테스트", func():
		_dev_test_panel.visible = false
		parent_scene.trigger_loadout_test_ui()
	, parent_scene.C_ACCENT)
	btn_loadout.custom_minimum_size = Vector2(0, 40)
	btn_loadout.add_theme_font_size_override("font_size", 13)
	vbox.add_child(btn_loadout)
	
	# 3. 탄환 이미지 갤러리 테스트 숏컷 버튼
	var btn_gallery = parent_scene.make_button("🔴 탄환 이미지 갤러리 테스트", func():
		_dev_test_panel.visible = false
		parent_scene.trigger_bullet_gallery_ui()
	, parent_scene.C_ACCENT)
	btn_gallery.custom_minimum_size = Vector2(0, 40)
	btn_gallery.add_theme_font_size_override("font_size", 13)
	vbox.add_child(btn_gallery)
	
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)
	
	# 닫기 버튼
	var btn_close = parent_scene.make_button("❌ 닫기", func():
		_dev_test_panel.visible = false
	, parent_scene.C_DANGER)
	btn_close.custom_minimum_size = Vector2(0, 36)
	vbox.add_child(btn_close)
