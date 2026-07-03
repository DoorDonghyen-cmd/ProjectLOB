class_name TitleOverlay
extends PanelContainer

## ═══════════════════════════════════════════════════
## 타이틀 및 영구 메타 상점 오버레이
## ═══════════════════════════════════════════════════

const DataLoader = preload("res://scripts/core/data_loader.gd")

var parent_scene: Control
var run_manager: RunManager

var _meta_credit_label: Label
var _lore_fragment_label: Label
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
	
	_lore_fragment_label = parent_scene.make_label("기밀 정보 복원율: 0 / 20", 14, parent_scene.C_SUCCESS)
	_lore_fragment_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_vbox.add_child(_lore_fragment_label)

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
	if _lore_fragment_label:
		_lore_fragment_label.text = "기밀 정보 복원율: %d / 20" % RunManager.meta_lore_fragments.size()
		
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
	_dev_test_panel.custom_minimum_size = Vector2(340, 330)
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
	
	# 3-2. 몬스터 이미지 갤러리 테스트 숏컷 버튼
	var btn_monster_gallery = parent_scene.make_button("👾 몬스터 갤러리 테스트", func():
		_dev_test_panel.visible = false
		parent_scene.trigger_monster_gallery_ui()
	, parent_scene.C_ACCENT)
	btn_monster_gallery.custom_minimum_size = Vector2(0, 40)
	btn_monster_gallery.add_theme_font_size_override("font_size", 13)
	vbox.add_child(btn_monster_gallery)
	
	# 4. 더블탭 전투 테스트 숏컷 버튼
	var btn_double_tap = parent_scene.make_button("🔫 더블탭 전투 테스트", func():
		_dev_test_panel.visible = false
		parent_scene.trigger_double_tap_test()
	, parent_scene.C_ACCENT)
	btn_double_tap.custom_minimum_size = Vector2(0, 40)
	btn_double_tap.add_theme_font_size_override("font_size", 13)
	vbox.add_child(btn_double_tap)
	
	# 5. 해금 및 보상 테스트 숏컷 버튼
	var btn_unlock_test = parent_scene.make_button("🔑 해금 및 보상 테스트", func():
		_dev_test_panel.visible = false
		# 데이터 코어 10개 증가 및 2개 무기 해금
		RunManager.meta_tactical_data_cores += 10
		if not RunManager.meta_unlocked_weapons.has("marksman"):
			RunManager.meta_unlocked_weapons.append("marksman")
		if not RunManager.meta_unlocked_weapons.has("tempo"):
			RunManager.meta_unlocked_weapons.append("tempo")
		
		# 기밀 정보 파편 19개 수집 상태 프리셋 (엔딩 및 도감 테스트 가시화)
		RunManager.meta_lore_fragments = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19]
		
		# 준비실을 열기 전에 알림
		print("디버그: TDC 10개 가산, 2개 무기 해금 및 기밀 파편 19개(1~19F)가 테스트 프리셋되었습니다.")
		_refresh_shop_ui()
		parent_scene.trigger_loadout_test_ui()
	, parent_scene.C_WARNING)
	btn_unlock_test.custom_minimum_size = Vector2(0, 40)
	btn_unlock_test.add_theme_font_size_override("font_size", 13)
	vbox.add_child(btn_unlock_test)
	
	# 6. 📊 밸런스 매트릭스 뷰 버튼
	var btn_matrix = parent_scene.make_button("📊 밸런스 매트릭스 뷰", func():
		_show_balance_matrix_popup()
	, parent_scene.C_ACCENT)
	btn_matrix.custom_minimum_size = Vector2(0, 40)
	btn_matrix.add_theme_font_size_override("font_size", 13)
	vbox.add_child(btn_matrix)
	
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)
	
	# 닫기 버튼
	var btn_close = parent_scene.make_button("❌ 닫기", func():
		_dev_test_panel.visible = false
	, parent_scene.C_DANGER)
	btn_close.custom_minimum_size = Vector2(0, 36)
	vbox.add_child(btn_close)


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
