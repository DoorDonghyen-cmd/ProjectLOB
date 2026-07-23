class_name LoadoutOverlay
extends PanelContainer

## ═══════════════════════════════════════════════════
## 요원 작전 준비실 (Agent Tactical Loadout - HTML 이식 버전)
## ═══════════════════════════════════════════════════

var parent_scene: Control
var run_manager: RunManager

# ── 총기 리소스 데이터들 ──
var _gun_revolver: GunData
var _gun_shotgun: GunData
var _gun_smg: GunData
var _gun_dmr: GunData
var _gun_heavy: GunData
var _gun_trickster: GunData
var _gun_gambler: GunData
var _gun_stance_hunter: GunData

# ── 선택 상태 변수 ──
var selected_weapon_key: String = "workhorse"
var selected_section_key: String = "section_a"
# ── UI 노드 레퍼런스 ──
var _weapon_cards: Dictionary = {}
var _target_zone_label: Label

var _gun_icon_rect: TextureRect
var _cap_slots_hbox: HBoxContainer
var _lbl_ammo_size: Label
var _lbl_prev_size: Label
var _lbl_calibers: Label
var _lbl_passive_desc: Label
var _lbl_penalty_desc: Label
var _btn_start_run: Button
var _bonus_popup: PanelContainer

# ── 테마 컬러 ──
const C_BG_CHARCOAL := Color(0.07, 0.07, 0.08, 0.98)
const C_PANEL_BG := Color(0.1, 0.1, 0.13, 1.0)
const C_BORDER := Color(0.2, 0.2, 0.25, 1.0)
const C_NEON_GOLD := Color(0.83, 0.69, 0.22, 1.0)
const C_NEON_GOLD_DIM := Color(0.83, 0.69, 0.22, 0.25)
const C_ALERT_RED := Color(1.0, 0.27, 0.27, 1.0)
const C_ALERT_RED_BG := Color(1.0, 0.27, 0.27, 0.08)

# ⚠️ 계층 이름·층수는 MapGenerator.section_info()가 유일한 출처다.
#    여기에 상수 테이블로 복사하지 말 것 — 과거 복사본이 세계관 개정·층수 압축을
#    따라가지 못해 화면에만 구버전이 남았다. (2026-07-24)

# ── 총기 프로필 데이터 맵 (GDD/HTML 기반 정합성 스펙) ──
const WEAPON_PROFILES := {
	"workhorse": {
		"res_key": "revolver",
		"display_name_kor": "표준형",
		"display_name_eng": "WORKHORSE",
		"emoji": "🔫",
		"cap": 4,
		"ammo": 5,
		"prev": 2,
		"calibers": "[9mm] [45ACP] [전 구경]",
		"passive": "- 균형잡힌 스탯 / 범용 파츠 시너지 우수\n- 표준 LIFO 디펜스의 탄탄한 기초 제공",
		"penalty": "- 특화된 극딜/넉백 유틸리티 부재\n- 시그니처 혜택이 없는 것 자체가 리스크",
		"unlock_desc": ""
	},
	"marksman": {
		"res_key": "dmr",
		"display_name_kor": "저격형",
		"display_name_eng": "MARKSMAN",
		"emoji": "🎯",
		"cap": 4,
		"ammo": 3,
		"prev": 2,
		"calibers": "[9mm] [5.56mm] [저격전용]",
		"passive": "- 패시브 ACC+4 가산 보너스\n- 첫 탄 격발 시 적의 EVA(회피) 무시 확정 명중",
		"penalty": "- 탄창 슬롯 3칸으로 좁아 연계 빌드 한계\n- 근거리 (DIST 1 이하) 격발 시 DMG 감소 취약",
		"unlock_desc": "[원거리 통제] 평균 처치 거리 4.0 이상으로 완주"
	},
	"bruiser": {
		"res_key": "shotgun",
		"display_name_kor": "돌격형",
		"display_name_eng": "BRUISER",
		"emoji": "💥",
		"cap": 5,
		"ammo": 5,
		"prev": 2,
		"calibers": "[12Gauge] [Slug] [전 구경]",
		"passive": "- 포인트블랭크 고유 파츠 기본 탑재 (근접 DMG 폭증)\n- 격발 당 근접 타격 넉백 거리 극대화 (+1 KB)",
		"penalty": "- 기본 명중(ACC) 보정 게이트가 매우 낮음\n- 원거리 (DIST 4 이상) 타겟 대상 명중률 하락",
		"unlock_desc": "[처치 연쇄] 한 턴 3마리 이상의 적 처치"
	},
	"tempo": {
		"res_key": "smg",
		"display_name_kor": "속사형",
		"display_name_eng": "TEMPO",
		"emoji": "⚡",
		"cap": 4,
		"ammo": 6,
		"prev": 2,
		"calibers": "[9mm] [5.56mm] [속사전용]",
		"passive": "- 리듬 챔버 혜택 일부 내장 (Combo 연타 DMG+)\n- 9mm 권총탄 계열 연사 시 추가 탄 공급 보너스",
		"penalty": "- 대구경 고화력 7.62mm 탄환 사용 불가능\n- 기본 관통(PEN) 게이트가 낮아 중장갑 좀비에 취약",
		"unlock_desc": "[계획 규율] 납탄(중간 삽탄) 격발 없이 완주"
	},
	"heavy": {
		"res_key": "heavy",
		"display_name_kor": "중장형",
		"display_name_eng": "HEAVY",
		"emoji": "💣",
		"cap": 4,
		"ammo": 6,
		"prev": 1,
		"calibers": "[7.62mm] [대구경] [전 구경]",
		"passive": "- 패시브 PEN+1 / DMG+1 / 넉백+1 버프 제공\n- 관통 게이트 통과 시 초과 PEN만큼 뒤 적 관통타격",
		"penalty": "- 예고창이 1개로 엄격 차단되어 기억력 의존\n- 조준 불안정 패시브 ACC -1 감쇄 패널티",
		"unlock_desc": "[시스템 파훼] 관통 피해 없이 파쇄만으로 탱커 처치"
	},
	"trickster": {
		"res_key": "trickster",
		"display_name_kor": "곡예형",
		"display_name_eng": "TRICKSTER",
		"emoji": "🎪",
		"cap": 3,
		"ammo": 4,
		"prev": 3,
		"calibers": "[9mm] [45ACP] [전 구경]",
		"passive": "- 예고창 3개로 뛰어난 가시성 제공\n- 턴당 1회 맨 위 탄을 맨 아래로 보내는 이젝트 사용 가능",
		"penalty": "- 일반 개조 슬롯이 3칸으로 극도 제한\n- 이젝트 기믹으로 밀려난 탄환 격발 시 DMG -1 감쇄",
		"unlock_desc": "[완벽 실행] 한 전투를 빗나감/0데미지 없이 클리어"
	},
	"gambler": {
		"res_key": "gambler",
		"display_name_kor": "도박형",
		"display_name_eng": "GAMBLER",
		"emoji": "🎲",
		"cap": 5,
		"ammo": 5,
		"prev": 0,
		"calibers": "[전 구경 지원]",
		"passive": "- 패시브 DMG+2 및 5칸의 넓은 개조 슬롯 지원\n- 탄창 내 아래에 깊숙이 묻힌 탄일수록 격발 위력 증가",
		"penalty": "- 예고창 0개로 블라인드 (발사 직전 1발만 명중 예고)\n- 탄창 관리 실수를 하면 빌드가 꼬이기 쉬움",
		"unlock_desc": "[리스크 감수] 무손실 (근접 1m 허용 없이) 완주"
	},
	"stance_hunter": {
		"res_key": "stance_hunter",
		"display_name_kor": "태세사냥꾼",
		"display_name_eng": "STANCE HUNTER",
		"emoji": "🏹",
		"cap": 4,
		"ammo": 5,
		"prev": 2,
		"calibers": "[전 구경 지원]",
		"passive": "- 태세 예지 내장 (적 태세 전환 1턴 미리 예고)\n- 적의 태세 전환 턴에 모든 게이트 무시 (확정 명중/관통)",
		"penalty": "- 태세 전환이 없는 적을 상대할 때는 시그니처 혜택 소멸\n- 낮은 범용성에 따른 빌드 불안정성",
		"unlock_desc": "[시스템 파훼] 슬로우 없이 태세 전환 병사 처치"
	}
}


func initialize(p_scene: Control, rm: RunManager) -> void:
	parent_scene = p_scene
	run_manager = rm
	
	# 무기 리소스 프리로드 캐싱
	_gun_revolver = parent_scene._gun_revolver
	_gun_shotgun = parent_scene._gun_shotgun
	_gun_smg = parent_scene._gun_smg
	_gun_dmr = parent_scene._gun_dmr
	_gun_heavy = parent_scene._gun_heavy
	_gun_trickster = parent_scene._gun_trickster
	_gun_gambler = parent_scene._gun_gambler
	_gun_stance_hunter = parent_scene._gun_stance_hunter
	
	# 풀 화면 오버레이 설정
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(960, 540)
	
	var style := StyleBoxFlat.new()
	style.bg_color = C_BG_CHARCOAL
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = C_NEON_GOLD
	add_theme_stylebox_override("panel", style)
	
	_build_ui()
	_build_starting_bonus_popup()


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(margin)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(main_vbox)

	# ── 헤더 (Header) ──
	var header_hbox := HBoxContainer.new()
	header_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(header_hbox)
	
	var title_lbl = parent_scene.make_label("🛠️ AGENT TACTICAL LOADOUT", 20, C_NEON_GOLD)
	header_hbox.add_child(title_lbl)
	
	_target_zone_label = parent_scene.make_label("", 14, parent_scene.C_TEXT)
	header_hbox.add_child(_target_zone_label)
	
	# 스캔라인 디스플레이 연출용 실선
	var scan_line = ColorRect.new()
	scan_line.color = C_NEON_GOLD_DIM
	scan_line.custom_minimum_size = Vector2(0, 2)
	scan_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scan_line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header_hbox.add_child(scan_line)
	
	# 구분선
	var separator = ColorRect.new()
	separator.color = C_NEON_GOLD
	separator.custom_minimum_size = Vector2(0, 2)
	main_vbox.add_child(separator)

	# ── 메인 좌우 분리 레이아웃 (HBox) ──
	var split_hbox := HBoxContainer.new()
	split_hbox.add_theme_constant_override("separation", 16)
	split_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(split_hbox)

	# A) 좌측 패널 (로스터 및 무기 선택 - 38% 폭)
	var left_panel := VBoxContainer.new()
	left_panel.add_theme_constant_override("separation", 8)
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_stretch_ratio = 0.38
	split_hbox.add_child(left_panel)
	
	left_panel.add_child(parent_scene.make_label("▶ FIREARM SELECTION", 12, parent_scene.C_DIM))
	
	# 총기 카드 선택 리스트 (VBox + ScrollContainer)
	var weapon_scroll := ScrollContainer.new()
	weapon_scroll.custom_minimum_size = Vector2(0, 240)
	weapon_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	weapon_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	weapon_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	left_panel.add_child(weapon_scroll)
	
	var weapon_list_vbox := VBoxContainer.new()
	weapon_list_vbox.add_theme_constant_override("separation", 6)
	weapon_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weapon_scroll.add_child(weapon_list_vbox)
	
	for w_key in WEAPON_PROFILES.keys():
		var profile = WEAPON_PROFILES[w_key]
		var is_unlocked := RunManager.meta_unlocked_weapons.has(w_key)
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(0, 48)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.focus_mode = Control.FOCUS_NONE # 포커스 획득 시 하얗게 오버레이되는 버그 차단
		
		if not is_unlocked:
			card.modulate = Color(1.0, 1.0, 1.0, 0.45)
			
		weapon_list_vbox.add_child(card)
		_weapon_cards[w_key] = card
		
		# 여백용 마진
		var inner_margin := MarginContainer.new()
		inner_margin.add_theme_constant_override("margin_left", 8)
		inner_margin.add_theme_constant_override("margin_right", 8)
		inner_margin.add_theme_constant_override("margin_top", 4)
		inner_margin.add_theme_constant_override("margin_bottom", 4)
		inner_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_child(inner_margin)
		
		var inner_hbox := HBoxContainer.new()
		inner_hbox.add_theme_constant_override("separation", 12)
		inner_margin.add_child(inner_hbox)
		
		var icon_text = profile.emoji
		if not is_unlocked:
			icon_text = "🔒"
		var icon_lbl = parent_scene.make_label(icon_text, 18, parent_scene.C_TEXT)
		inner_hbox.add_child(icon_lbl)
		
		var name_vbox := VBoxContainer.new()
		name_vbox.add_theme_constant_override("separation", 0)
		name_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		inner_hbox.add_child(name_vbox)
		
		var display_name = profile.display_name_kor
		if not is_unlocked:
			display_name += " (잠김)"
		var name_kor = parent_scene.make_label(display_name, 13, parent_scene.C_TEXT)
		name_vbox.add_child(name_kor)
		
		var name_eng = parent_scene.make_label(profile.display_name_eng, 10, C_NEON_GOLD)
		name_vbox.add_child(name_eng)
		
		# 마우스 클릭 이벤트 이미테이션
		card.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_select_weapon(w_key)
		)

	# B) 우측 패널 (전술 상세 명세 - 62% 폭)
	var right_panel := PanelContainer.new()
	_apply_custom_panel_style(right_panel, C_PANEL_BG, Color(0.2, 0.2, 0.25))
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_stretch_ratio = 0.62
	split_hbox.add_child(right_panel)
	
	var right_margin := MarginContainer.new()
	right_margin.add_theme_constant_override("margin_left", 16)
	right_margin.add_theme_constant_override("margin_right", 16)
	right_margin.add_theme_constant_override("margin_top", 12)
	right_margin.add_theme_constant_override("margin_bottom", 12)
	right_panel.add_child(right_margin)
	
	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 6)
	right_margin.add_child(right_vbox)

	# B1) 총기 렌더링 박스
	var render_box = PanelContainer.new()
	render_box.custom_minimum_size = Vector2(0, 80)
	_apply_custom_panel_style(render_box, Color.BLACK, Color(0.25, 0.25, 0.28))
	right_vbox.add_child(render_box)
	
	_gun_icon_rect = TextureRect.new()
	_gun_icon_rect.custom_minimum_size = Vector2(160, 60)
	_gun_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_gun_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_gun_icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_gun_icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	render_box.add_child(_gun_icon_rect)

	# B2) CAPACITY SLOTS 로우
	var cap_row := HBoxContainer.new()
	right_vbox.add_child(cap_row)
	cap_row.add_child(parent_scene.make_label("■ CAPACITY SLOTS", 11, parent_scene.C_DIM))
	
	_cap_slots_hbox = HBoxContainer.new()
	_cap_slots_hbox.add_theme_constant_override("separation", 4)
	_cap_slots_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cap_slots_hbox.alignment = BoxContainer.ALIGNMENT_END
	cap_row.add_child(_cap_slots_hbox)

	# B3) AMMO SIZE 로우
	var ammo_row := HBoxContainer.new()
	right_vbox.add_child(ammo_row)
	ammo_row.add_child(parent_scene.make_label("■ AMMO SIZE", 11, parent_scene.C_DIM))
	
	var ammo_val_hbox := HBoxContainer.new()
	ammo_val_hbox.add_theme_constant_override("separation", 6)
	ammo_val_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ammo_val_hbox.alignment = BoxContainer.ALIGNMENT_END
	ammo_row.add_child(ammo_val_hbox)
	
	_lbl_ammo_size = parent_scene.make_label("4", 11, parent_scene.C_TEXT)
	ammo_val_hbox.add_child(_lbl_ammo_size)
	
	# B4) PREVIEW SIZE 로우
	var prev_row := HBoxContainer.new()
	right_vbox.add_child(prev_row)
	prev_row.add_child(parent_scene.make_label("■ PREVIEW SIZE", 11, parent_scene.C_DIM))
	
	var prev_val_hbox := HBoxContainer.new()
	prev_val_hbox.add_theme_constant_override("separation", 6)
	prev_val_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prev_val_hbox.alignment = BoxContainer.ALIGNMENT_END
	prev_row.add_child(prev_val_hbox)
	
	_lbl_prev_size = parent_scene.make_label("2", 11, parent_scene.C_TEXT)
	prev_val_hbox.add_child(_lbl_prev_size)
	
	# B5) CALIBERS 로우
	var cal_row := HBoxContainer.new()
	right_vbox.add_child(cal_row)
	cal_row.add_child(parent_scene.make_label("■ CALIBERS", 11, parent_scene.C_DIM))
	
	_lbl_calibers = parent_scene.make_label("[9mm]", 11, C_NEON_GOLD)
	_lbl_calibers.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_calibers.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_RIGHT
	cal_row.add_child(_lbl_calibers)

	# B6) SIGNATURE PASSIVE RULE 박스
	var passive_panel := PanelContainer.new()
	_apply_custom_panel_style(passive_panel, Color(0, 0, 0, 0.4), C_NEON_GOLD)
	passive_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_child(passive_panel)
	
	var pass_margin := MarginContainer.new()
	pass_margin.add_theme_constant_override("margin_left", 8)
	pass_margin.add_theme_constant_override("margin_right", 8)
	pass_margin.add_theme_constant_override("margin_top", 6)
	pass_margin.add_theme_constant_override("margin_bottom", 6)
	passive_panel.add_child(pass_margin)
	
	var pass_vbox := VBoxContainer.new()
	pass_vbox.add_theme_constant_override("separation", 2)
	pass_margin.add_child(pass_vbox)
	pass_vbox.add_child(parent_scene.make_label("▶ SIGNATURE PASSIVE RULE", 10, C_NEON_GOLD))
	
	_lbl_passive_desc = parent_scene.make_label("", 10, parent_scene.C_TEXT)
	_lbl_passive_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pass_vbox.add_child(_lbl_passive_desc)

	# B7) CRITICAL PENALTY RISK 박스
	var penalty_panel := PanelContainer.new()
	_apply_custom_panel_style(penalty_panel, C_ALERT_RED_BG, C_ALERT_RED)
	penalty_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_child(penalty_panel)
	
	var pen_margin := MarginContainer.new()
	pen_margin.add_theme_constant_override("margin_left", 8)
	pen_margin.add_theme_constant_override("margin_right", 8)
	pen_margin.add_theme_constant_override("margin_top", 6)
	pen_margin.add_theme_constant_override("margin_bottom", 6)
	penalty_panel.add_child(pen_margin)
	
	var pen_vbox := VBoxContainer.new()
	pen_vbox.add_theme_constant_override("separation", 2)
	pen_margin.add_child(pen_vbox)
	pen_vbox.add_child(parent_scene.make_label("⚠️ CRITICAL PENALTY RISK", 10, C_ALERT_RED))
	
	_lbl_penalty_desc = parent_scene.make_label("", 10, parent_scene.C_TEXT)
	_lbl_penalty_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pen_vbox.add_child(_lbl_penalty_desc)

	# ── 하단 작전 개시 바 ──
	var action_bar := PanelContainer.new()
	action_bar.custom_minimum_size = Vector2(0, 48)
	_apply_custom_panel_style(action_bar, Color.BLACK, C_NEON_GOLD)
	main_vbox.add_child(action_bar)
	
	_btn_start_run = parent_scene.make_button("🚀 봉쇄 구역 작전 개시 (Proceed)", _on_start_run_pressed, C_NEON_GOLD)
	_btn_start_run.custom_minimum_size = Vector2(0, 44)
	_btn_start_run.add_theme_font_size_override("font_size", 14)
	action_bar.add_child(_btn_start_run)

	# 초기 바인딩 시점 트리거
	_select_weapon("workhorse")
	_select_section(selected_section_key)


## 런타임에 오버레이를 열고 초기 바인딩 수행
func open_loadout_overlay(section_key: String) -> void:
	visible = true
	_select_weapon(selected_weapon_key)
	_select_section(section_key)
	
	if RunManager.starting_bonus_available and _bonus_popup:
		_bonus_popup.visible = true
		_btn_start_run.disabled = true


## 무기 선택 로직
func _select_weapon(w_key: String) -> void:
	selected_weapon_key = w_key
	
	# 좌측 카드 비주얼 선택 강조 갱신
	for key in _weapon_cards.keys():
		var card: PanelContainer = _weapon_cards[key]
		if key == w_key:
			_apply_custom_panel_style(card, Color(0.25, 0.20, 0.12, 0.95), C_NEON_GOLD)
		else:
			_apply_custom_panel_style(card, C_PANEL_BG, Color(0.2, 0.2, 0.25))
			
	_refresh_stats_ui()


## 스탯 수치 리프레시
func _refresh_stats_ui() -> void:
	var profile = WEAPON_PROFILES[selected_weapon_key]
	
	# 1. 픽셀아트 총기 이미지 바인딩
	var target_gun: GunData = null
	match profile.res_key:
		"revolver": target_gun = _gun_revolver
		"shotgun": target_gun = _gun_shotgun
		"smg": target_gun = _gun_smg
		"dmr": target_gun = _gun_dmr
		
	if target_gun:
		_gun_icon_rect.texture = target_gun.icon
		
	# 2. CAPACITY SLOTS 렌더링
	for child in _cap_slots_hbox.get_children():
		child.queue_free()
		
	var base_cap: int = profile.cap
	for i in range(base_cap):
		var cap_box = PanelContainer.new()
		cap_box.custom_minimum_size = Vector2(16, 16)
		_apply_custom_panel_style(cap_box, Color(0.83, 0.69, 0.22, 0.2), C_NEON_GOLD)
		_cap_slots_hbox.add_child(cap_box)
		
	# 3. AMMO SIZE 스탯
	var base_ammo: int = profile.ammo
	_lbl_ammo_size.text = str(base_ammo)
		
	# 4. PREVIEW SIZE 스탯
	var base_prev: int = profile.prev
	_lbl_prev_size.text = str(base_prev)
		
	# 5. 구경 및 설명 텍스트
	_lbl_calibers.text = profile.calibers
	
	var is_unlocked := RunManager.meta_unlocked_weapons.has(selected_weapon_key)
	if is_unlocked:
		_lbl_passive_desc.text = profile.passive
		_lbl_penalty_desc.text = profile.penalty
		_btn_start_run.disabled = false
	else:
		_lbl_passive_desc.text = "🔒 잠김: 이 무기는 아직 사용할 수 없습니다.\n해금 조건: " + profile.unlock_desc
		_lbl_penalty_desc.text = "이전 작전(런)에서 위의 도전 과제를 완료하면 영구 해금됩니다."
		_btn_start_run.disabled = true


## 🚀 작전 개시 액션
func _on_start_run_pressed() -> void:
	# 선택된 무기 리소스를 실시간으로 parent_scene에 등록
	var target_gun: GunData = null
	var profile = WEAPON_PROFILES[selected_weapon_key]
	match profile.res_key:
		"revolver": target_gun = _gun_revolver
		"shotgun": target_gun = _gun_shotgun
		"smg": target_gun = _gun_smg
		"dmr": target_gun = _gun_dmr
		"heavy": target_gun = _gun_heavy
		"trickster": target_gun = _gun_trickster
		"gambler": target_gun = _gun_gambler
		"stance_hunter": target_gun = _gun_stance_hunter
		
	if target_gun:
		parent_scene.set_current_gun(target_gun)
		
	visible = false
	parent_scene.handle_loadout_finished()


## 공통 테마 스타일 도우미
func _apply_custom_panel_style(panel: PanelContainer, bg: Color, border: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = border
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	panel.add_theme_stylebox_override("panel", style)

func _build_starting_bonus_popup() -> void:
	_bonus_popup = PanelContainer.new()
	_bonus_popup.custom_minimum_size = Vector2(460, 240)
	_bonus_popup.visible = false
	
	add_child(_bonus_popup)
	
	_bonus_popup.set_anchors_preset(Control.PRESET_CENTER)
	_bonus_popup.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_bonus_popup.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	_apply_custom_panel_style(_bonus_popup, Color(0.08, 0.08, 0.12, 0.98), C_NEON_GOLD)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	_bonus_popup.add_child(margin)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)
	
	var title = parent_scene.make_label("📥 본부 작전 스타팅 보증 보급", 18, C_NEON_GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	var desc = parent_scene.make_label("이전 작전의 구역 1 돌파를 격려하여\n본부에서 다음 보너스 중 1개를 지원합니다.", 12, parent_scene.C_TEXT)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(desc)
	
	var btn_hbox := HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 16)
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_hbox)
	
	var btn_cr = parent_scene.make_button("💳 보급금 (+50 Cr)", _on_bonus_credits_selected, parent_scene.C_SUCCESS)
	btn_cr.custom_minimum_size = Vector2(180, 44)
	btn_cr.add_theme_font_size_override("font_size", 12)
	btn_hbox.add_child(btn_cr)
	
	var btn_part = parent_scene.make_button("🛠️ 무작위 1티어 파츠", _on_bonus_part_selected, parent_scene.C_WARNING)
	btn_part.custom_minimum_size = Vector2(180, 44)
	btn_part.add_theme_font_size_override("font_size", 12)
	btn_hbox.add_child(btn_part)

func _on_bonus_credits_selected() -> void:
	if run_manager:
		run_manager.credits += 50
		print("디버그: 스타팅 보증 크레딧 +50 Cr 획득!")
	_close_bonus_popup()

func _on_bonus_part_selected() -> void:
	if run_manager:
		var path := "res://resources/parts/"
		var dir := DirAccess.open(path)
		var parts_pool: Array[PartData] = []
		if dir:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name != "":
				if not dir.current_is_dir() and not file_name.is_empty() and not file_name.ends_with(".import"):
					if file_name.ends_with(".tres") or file_name.ends_with(".tres.remap") or file_name.ends_with(".res") or file_name.ends_with(".res.remap"):
						var clean_name = file_name.replace(".remap", "")
						var res = load(path + clean_name)
						if res is PartData:
							parts_pool.append(res)
				file_name = dir.get_next()
			dir.list_dir_end()
			
		if not parts_pool.is_empty():
			var chosen = parts_pool.pick_random().duplicate() as PartData
			var success = run_manager.add_to_backpack(chosen)
			if success:
				print("디버그: 스타팅 보증 무작위 1티어 파츠 획득! (%s)" % chosen.display_name)
			else:
				run_manager.credits += 50
				print("디버그: 가방이 가득 차 파츠 대신 +50 Cr로 보증금이 대체 지급되었습니다.")
		else:
			run_manager.credits += 50
			print("디버그: 파츠 풀이 비어있어 +50 Cr로 대체 지급되었습니다.")
	_close_bonus_popup()

func _close_bonus_popup() -> void:
	if _bonus_popup:
		_bonus_popup.visible = false
	RunManager.starting_bonus_available = false
	_refresh_stats_ui()


## 🗺️ 시작 계층 표기 연동.
## 연속 런에서 시작 계층은 항상 최하 계층이므로 선택이 아니라 확인용 표기다.
func _select_section(sec_key: String) -> void:
	selected_section_key = sec_key
	var info: Dictionary = MapGenerator.section_info(sec_key)
	if _target_zone_label:
		_target_zone_label.text = " [진입: %s LV.%d]" % [
			str(info.name), MapGenerator.absolute_level(sec_key, 1)]
