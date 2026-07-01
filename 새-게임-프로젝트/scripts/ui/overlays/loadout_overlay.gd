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
var active_relics := {
	"gloves": false,
	"valve": false,
	"goggles": false
}

# ── UI 노드 레퍼런스 ──
var _weapon_cards: Dictionary = {}
var _relic_cards: Dictionary = {}

var _gun_icon_rect: TextureRect
var _cap_slots_hbox: HBoxContainer
var _lbl_ammo_size: Label
var _lbl_ammo_buff: Label
var _lbl_prev_size: Label
var _lbl_prev_buff: Label
var _lbl_calibers: Label
var _lbl_passive_desc: Label
var _lbl_penalty_desc: Label
var _btn_start_run: Button

# ── 테마 컬러 ──
const C_BG_CHARCOAL := Color(0.07, 0.07, 0.08, 0.98)
const C_PANEL_BG := Color(0.1, 0.1, 0.13, 1.0)
const C_BORDER := Color(0.2, 0.2, 0.25, 1.0)
const C_NEON_GOLD := Color(0.83, 0.69, 0.22, 1.0)
const C_NEON_GOLD_DIM := Color(0.83, 0.69, 0.22, 0.25)
const C_ALERT_RED := Color(1.0, 0.27, 0.27, 1.0)
const C_ALERT_RED_BG := Color(1.0, 0.27, 0.27, 0.08)
const C_BUFF_GREEN := Color(0.0, 1.0, 0.0, 1.0)

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
		"penalty": "- 특화된 극딜/넉백 유틸리티 부재\n- 시그니처 혜택이 없는 것 자체가 리스크"
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
		"penalty": "- 탄창 슬롯 3칸으로 좁아 연계 빌드 한계\n- 근거리 (DIST 1 이하) 격발 시 DMG 감소 취약"
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
		"passive": "- 포인트블랭크 렐릭 기본 탑재 (근접 DMG 폭증)\n- 격발 당 근접 타격 넉백 거리 극대화 (+1 KB)",
		"penalty": "- 기본 명중(ACC) 보정 게이트가 매우 낮음\n- 원거리 (DIST 4 이상) 타겟 대상 명중률 하락"
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
		"penalty": "- 대구경 고화력 7.62mm 탄환 사용 불가능\n- 기본 관통(PEN) 게이트가 낮아 중장갑 좀비에 취약"
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
		"penalty": "- 예고창이 1개로 엄격 차단되어 기억력 의존\n- 조준 불안정 패시브 ACC -1 감쇄 패널티"
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
		"penalty": "- 일반 개조 슬롯이 3칸으로 극도 제한\n- 이젝트 기믹으로 밀려난 탄환 격발 시 DMG -1 감쇄"
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
		"penalty": "- 예고창 0개로 블라인드 (발사 직전 1발만 명중 예고)\n- 탄창 관리 실수를 하면 빌드가 꼬이기 쉬움"
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
		"penalty": "- 태세 전환이 없는 적을 상대할 때는 시그니처 혜택 소멸\n- 낮은 범용성에 따른 빌드 불안정성"
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
	main_vbox.add_child(header_hbox)
	
	var title_lbl = parent_scene.make_label("🛠️ AGENT TACTICAL LOADOUT", 20, C_NEON_GOLD)
	header_hbox.add_child(title_lbl)
	
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
	split_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(split_hbox)

	# A) 좌측 패널 (로스터 선택 및 렐릭 - 38% 폭)
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
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(0, 48)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.focus_mode = Control.FOCUS_NONE # 포커스 획득 시 하얗게 오버레이되는 버그 차단
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
		
		var icon_lbl = parent_scene.make_label(profile.emoji, 18, parent_scene.C_TEXT)
		inner_hbox.add_child(icon_lbl)
		
		var name_vbox := VBoxContainer.new()
		name_vbox.add_theme_constant_override("separation", 0)
		name_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		inner_hbox.add_child(name_vbox)
		
		var name_kor = parent_scene.make_label(profile.display_name_kor, 13, parent_scene.C_TEXT)
		name_vbox.add_child(name_kor)
		
		var name_eng = parent_scene.make_label(profile.display_name_eng, 10, C_NEON_GOLD)
		name_vbox.add_child(name_eng)
		
		# 마우스 클릭 이벤트 이미테이션
		card.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_select_weapon(w_key)
		)

	# 렐릭 섹션
	left_panel.add_child(parent_scene.make_label("▶ TACTICAL RELICS", 12, parent_scene.C_DIM))
	
	var relic_panel_bg := PanelContainer.new()
	_apply_custom_panel_style(relic_panel_bg, C_PANEL_BG, Color(0.2, 0.2, 0.25))
	left_panel.add_child(relic_panel_bg)
	
	var relic_margin := MarginContainer.new()
	relic_margin.add_theme_constant_override("margin_left", 8)
	relic_margin.add_theme_constant_override("margin_right", 8)
	relic_margin.add_theme_constant_override("margin_top", 6)
	relic_margin.add_theme_constant_override("margin_bottom", 6)
	relic_panel_bg.add_child(relic_margin)
	
	var relic_hbox := HBoxContainer.new()
	relic_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	relic_hbox.add_theme_constant_override("separation", 24)
	relic_margin.add_child(relic_hbox)
	
	var relic_defs = [
		{"key": "gloves", "emoji": "🧤", "name": "전술 장갑", "tip": "재장전 턴 감소"},
		{"key": "valve", "emoji": "🎛️", "name": "압력 밸브", "tip": "무기 탄창 +2"},
		{"key": "goggles", "emoji": "🥽", "name": "스마트 고글", "tip": "예고창 시야 +1"}
	]
	
	for r_def in relic_defs:
		var r_key = r_def.key
		var r_vbox := VBoxContainer.new()
		r_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		r_vbox.add_theme_constant_override("separation", 4)
		r_vbox.mouse_filter = Control.MOUSE_FILTER_STOP
		relic_hbox.add_child(r_vbox)
		_relic_cards[r_key] = r_vbox
		
		# 아이콘 테두리용 패널
		var icon_panel := PanelContainer.new()
		icon_panel.custom_minimum_size = Vector2(36, 36)
		_apply_custom_panel_style(icon_panel, Color.BLACK, Color(0.3, 0.3, 0.3))
		r_vbox.add_child(icon_panel)
		
		var r_icon_lbl = parent_scene.make_label(r_def.emoji, 14, parent_scene.C_TEXT)
		r_icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		r_icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon_panel.add_child(r_icon_lbl)
		
		var r_name_lbl = parent_scene.make_label(r_def.name, 9, Color(0.66, 0.66, 0.7))
		r_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		r_vbox.add_child(r_name_lbl)
		
		r_vbox.tooltip_text = r_def.tip
		
		# 클릭 시 토글
		r_vbox.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_toggle_relic(r_key)
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
	
	_lbl_ammo_buff = parent_scene.make_label("", 10, C_BUFF_GREEN)
	ammo_val_hbox.add_child(_lbl_ammo_buff)

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
	
	_lbl_prev_buff = parent_scene.make_label("", 10, C_BUFF_GREEN)
	prev_val_hbox.add_child(_lbl_prev_buff)

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


## 런타임에 오버레이를 열고 초기 바인딩 수행
func open_loadout_overlay() -> void:
	visible = true
	_select_weapon(selected_weapon_key)


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


## 렐릭 선택 토글
func _toggle_relic(r_key: String) -> void:
	active_relics[r_key] = not active_relics[r_key]
	
	# 비주얼 활성도 강제 조절
	var relic_vbox: VBoxContainer = _relic_cards[r_key]
	var icon_panel: PanelContainer = relic_vbox.get_child(0)
	
	if active_relics[r_key]:
		relic_vbox.modulate = Color.WHITE
		_apply_custom_panel_style(icon_panel, Color(0.25, 0.20, 0.12), C_NEON_GOLD)
	else:
		relic_vbox.modulate = Color(1.0, 1.0, 1.0, 0.5)
		_apply_custom_panel_style(icon_panel, Color.BLACK, Color(0.3, 0.3, 0.3))
		
	_refresh_stats_ui()


## 스탯 수치 리프레시 및 렐릭 시뮬레이션
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
		
	# 2. CAPACITY SLOTS 렌더링 (압력 밸브 장착 시 슬롯 용량 +1)
	for child in _cap_slots_hbox.get_children():
		child.queue_free()
		
	var base_cap: int = profile.cap
	var final_cap := base_cap
	if active_relics.valve:
		final_cap += 1
		
	for i in range(final_cap):
		var cap_box = PanelContainer.new()
		cap_box.custom_minimum_size = Vector2(16, 16)
		
		# 추가 가산된 슬롯은 녹색 테두리로 가시성 분리
		var border = C_BUFF_GREEN if i >= base_cap else C_NEON_GOLD
		var bg = Color(0.0, 1.0, 0.0, 0.1) if i >= base_cap else Color(0.83, 0.69, 0.22, 0.2)
		
		_apply_custom_panel_style(cap_box, bg, border)
		_cap_slots_hbox.add_child(cap_box)
		
	# 3. AMMO SIZE 스탯 (압력 밸브 장착 시 탄창 크기 +2)
	var base_ammo: int = profile.ammo
	_lbl_ammo_size.text = str(base_ammo)
	if active_relics.valve:
		_lbl_ammo_buff.text = "→ %d (+2)" % (base_ammo + 2)
		_lbl_ammo_buff.visible = true
	else:
		_lbl_ammo_buff.visible = false
		
	# 4. PREVIEW SIZE 스탯 (스마트 고글 장착 시 예고창 크기 +1)
	var base_prev: int = profile.prev
	_lbl_prev_size.text = str(base_prev)
	if active_relics.goggles:
		_lbl_prev_buff.text = "→ %d (+1)" % (base_prev + 1)
		_lbl_prev_buff.visible = true
	else:
		_lbl_prev_buff.visible = false
		
	# 5. 구경 및 설명 텍스트
	_lbl_calibers.text = profile.calibers
	_lbl_passive_desc.text = profile.passive
	_lbl_penalty_desc.text = profile.penalty


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
		
	# 렐릭 활성 여부를 타이틀의 체크 버튼 상태에도 연동 동기화해 줌
	parent_scene.sync_relics_from_loadout(active_relics)
	
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
