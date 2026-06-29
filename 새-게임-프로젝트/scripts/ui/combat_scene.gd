extends Control

## ═══════════════════════════════════════════════════
## 전투 및 런 제어용 메인 씬 라우터 (리팩토링 버전)
## ═══════════════════════════════════════════════════

# ── 프리로드 리소스 ──
var _gun_revolver: GunData = preload("res://resources/guns/revolver.tres")
var _gun_shotgun: GunData = preload("res://resources/guns/shotgun.tres")
var _gun_smg: GunData = preload("res://resources/guns/smg.tres")
var _gun_dmr: GunData = preload("res://resources/guns/dmr.tres")

var _bullets_basic: BulletData = preload("res://resources/bullets/basic_bullet.tres")
var _bullets_ap: BulletData = preload("res://resources/bullets/armor_piercing.tres")
var _bullets_kb: BulletData = preload("res://resources/bullets/knockback_slug.tres")

var _enemy_rusher: EnemyData = preload("res://resources/enemies/rusher.tres")
var _enemy_tank: EnemyData = preload("res://resources/enemies/tank.tres")
var _enemy_dodger: EnemyData = preload("res://resources/enemies/dodger.tres")
var _enemy_drone: EnemyData = preload("res://resources/enemies/sentry_drone.tres")
var _enemy_caster: EnemyData = preload("res://resources/enemies/caster.tres")
var _bullets_heavy: BulletData = preload("res://resources/bullets/heavy_bullet.tres")

# ── 색상 상수 ──
const C_BG := Color(0.06, 0.06, 0.10)
const C_PANEL := Color(0.12, 0.12, 0.18)
const C_PANEL_DARK := Color(0.09, 0.09, 0.14)
const C_TEXT := Color(0.88, 0.88, 0.92)
const C_DIM := Color(0.55, 0.55, 0.65)
const C_ACCENT := Color(0.35, 0.70, 1.0)
const C_DANGER := Color(1.0, 0.30, 0.30)
const C_SUCCESS := Color(0.30, 1.0, 0.50)
const C_WARNING := Color(1.0, 0.80, 0.25)
const C_HP_BAR := Color(0.85, 0.20, 0.20)
const C_DIST_SAFE := Color(0.25, 0.75, 0.40)
const C_DIST_WARN := Color(0.90, 0.75, 0.15)
const C_DIST_DANGER := Color(0.95, 0.25, 0.20)

# ── 매니저 인스턴스 ──
var _cm: CombatManager
var _rm: RunManager = RunManager.new()

# ── 오버레이 스크립트 인스턴스 ──
var _title_overlay: TitleOverlay
var _map_overlay: MapOverlay
var _maintenance_overlay: MaintenanceOverlay
var _combat_margin: MarginContainer
var _combat_overlay: CombatOverlay
var _debriefing_overlay: DebriefingOverlay
var _camera: Camera2D

# ── 현재 상태 ──
var _current_gun_data: GunData


func _ready() -> void:
	_current_gun_data = _gun_revolver
	_build_ui()
	_show_title_screen()


func _build_ui() -> void:
	# 카메라 (화면 흔들림 이펙트용)
	_camera = Camera2D.new()
	_camera.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	add_child(_camera)
	
	# 배경
	var bg := ColorRect.new()
	bg.color = C_BG
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)

	# 1. Title Overlay 생성
	_title_overlay = TitleOverlay.new()
	add_child(_title_overlay)
	_title_overlay.initialize(self, _rm)
	
	# 2. Map Overlay 생성
	_map_overlay = MapOverlay.new()
	add_child(_map_overlay)
	_map_overlay.initialize(self, _rm)
	_map_overlay.visible = false

	# 3. Maintenance Overlay 생성
	_maintenance_overlay = MaintenanceOverlay.new()
	add_child(_maintenance_overlay)
	_maintenance_overlay.initialize(self, _rm)
	_maintenance_overlay.visible = false

	# 4. Debriefing Overlay 생성
	_debriefing_overlay = DebriefingOverlay.new()
	add_child(_debriefing_overlay)
	_debriefing_overlay.initialize(self, _rm)
	_debriefing_overlay.visible = false

	# 5. Combat Overlay 생성 (마진 컨테이너 내부에 들어감)
	_combat_margin = MarginContainer.new()
	_combat_margin.set_anchors_preset(PRESET_FULL_RECT)
	_combat_margin.add_theme_constant_override("margin_left", 24)
	_combat_margin.add_theme_constant_override("margin_right", 24)
	_combat_margin.add_theme_constant_override("margin_top", 40)
	_combat_margin.add_theme_constant_override("margin_bottom", 24)
	add_child(_combat_margin)
	
	_combat_overlay = preload("res://scenes/ui/overlays/combat_overlay.tscn").instantiate()
	_combat_margin.add_child(_combat_overlay)
	_combat_overlay.initialize(self, _rm)
	_combat_margin.visible = false


# ── 외부 연동 헬퍼들 ──

func set_current_gun(gun: GunData) -> void:
	_current_gun_data = gun


func force_goggles_on_title() -> void:
	if _title_overlay:
		_title_overlay.chk_goggles.button_pressed = true


func is_goggles_enabled() -> bool:
	return _title_overlay and _title_overlay.chk_goggles.button_pressed


func trigger_camera_shake(intensity: float = 8.0, duration: float = 0.2) -> void:
	if not _camera:
		return
	var tween := create_tween()
	for i in range(5):
		var offset := Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		tween.tween_property(_camera, "offset", offset, duration / 6.0)
	tween.tween_property(_camera, "offset", Vector2.ZERO, duration / 6.0)


func start_run_from_title() -> void:
	_rm.start_new_run(_bullets_basic, _bullets_ap, _bullets_kb)
	_title_overlay.visible = false
	_show_map_screen()


func _show_title_screen() -> void:
	_title_overlay.visible = true
	_map_overlay.visible = false
	_maintenance_overlay.visible = false
	_debriefing_overlay.visible = false
	_combat_margin.visible = false
	_title_overlay._refresh_shop_ui()


func _show_map_screen() -> void:
	_map_overlay.show_map_screen()


# ── 라우터 콜백들 ──

func handle_route_selected(selected_node: RunManager.RunNode, route: String) -> void:
	var msg := _rm.select_route(route)
	
	if selected_node.type_name.contains("전투") or selected_node.type_name.contains("보스"):
		# 전투 로그 출력을 위해 Combat Overlay 및 컨테이너를 준비해 둠
		_combat_margin.visible = true
		_combat_overlay.visible = true
		_combat_overlay.clear_combat_log()
		_combat_overlay.add_combat_log("[color=#ffff66]%s[/color]" % msg)
		var enemy_list: Array[EnemyData] = []
		var floor_num := _rm.current_floor
		
		if selected_node.type_name.contains("보스"):
			# 보스전: 층이 높아질수록 편대가 강화됨
			if floor_num <= 5:
				enemy_list = [_enemy_tank, _enemy_caster]
			elif floor_num <= 10:
				enemy_list = [_enemy_tank, _enemy_rusher, _enemy_caster]
			elif floor_num <= 15:
				enemy_list = [_enemy_tank, _enemy_dodger, _enemy_caster, _enemy_drone]
			else:
				enemy_list = [_enemy_tank, _enemy_rusher, _enemy_caster, _enemy_dodger]
		else:
			# 일반전: 층(current_floor) 구간별 난이도 점진적 증가
			if floor_num <= 3:
				# 1~3층: 1~2마리 (쉬움)
				if randf() < 0.5:
					enemy_list = [_enemy_rusher]
				else:
					enemy_list = [_enemy_rusher, _enemy_dodger]
			elif floor_num <= 6:
				# 4~6층: 2~3마리 (보통)
				if randf() < 0.5:
					enemy_list = [_enemy_rusher, _enemy_tank]
				else:
					enemy_list = [_enemy_rusher, _enemy_drone, _enemy_caster]
			elif floor_num <= 10:
				# 7~10층: 3마리 (어려움)
				if randf() < 0.5:
					enemy_list = [_enemy_tank, _enemy_dodger, _enemy_caster]
				else:
					enemy_list = [_enemy_rusher, _enemy_drone, _enemy_caster]
			elif floor_num <= 15:
				# 11~15층: 3~4마리 (매우 어려움)
				if randf() < 0.5:
					enemy_list = [_enemy_tank, _enemy_tank, _enemy_caster]
				else:
					enemy_list = [_enemy_rusher, _enemy_dodger, _enemy_drone, _enemy_caster]
			else:
				# 16~19층: 4마리 고정 (극한)
				if randf() < 0.5:
					enemy_list = [_enemy_tank, _enemy_rusher, _enemy_dodger, _enemy_caster]
				else:
					enemy_list = [_enemy_tank, _enemy_drone, _enemy_caster, _enemy_dodger]
				
		_start_combat_phase(enemy_list)
	else:
		_combat_margin.visible = false
		_combat_overlay.visible = false
		_start_maintenance_phase(selected_node)


func _start_combat_phase(enemy_datas: Array[EnemyData]) -> void:
	if _cm:
		_cm.queue_free()
	_cm = CombatManager.new()
	_cm.name = "CombatManager"
	add_child(_cm)
	
	# 렐릭 동기화
	var relics: Array[String] = []
	if _title_overlay.chk_gloves.button_pressed: relics.append("tactical_gloves")
	if _title_overlay.chk_valve.button_pressed: relics.append("gas_valve")
	if _title_overlay.chk_goggles.button_pressed: relics.append("smart_sensor_goggles")
	_rm.active_relics = relics
	
	_combat_overlay.start_combat(_current_gun_data, enemy_datas, _cm)


func _start_maintenance_phase(node: RunManager.RunNode) -> void:
	_maintenance_overlay.start_maintenance_phase(node)


func handle_maintenance_finished() -> void:
	_rm.current_floor += 1
	if _rm.current_floor > 20:
		_show_debriefing(true)
	else:
		_show_map_screen()


func handle_combat_finished(is_dead: bool) -> void:
	_combat_margin.visible = false
	_combat_overlay.visible = false
	if is_dead:
		_show_debriefing(false)
		return
		
	_rm.current_floor += 1
	if _rm.current_floor > 20:
		_show_debriefing(true)
	else:
		_show_map_screen()


func _show_debriefing(won: bool) -> void:
	_debriefing_overlay.show_debriefing(won)


func handle_debrief_confirmed() -> void:
	_show_title_screen()


# ═══════════════════════════════════════════════════
# UI 팩토리 헬퍼들 (하위 오버레이가 사용함)
# ═══════════════════════════════════════════════════

func make_label(text: String, size: int = 24, color: Color = C_TEXT) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func make_button(text: String, callback: Callable, color: Color = C_ACCENT) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 22)
	btn.custom_minimum_size = Vector2(0, 52)

	var normal := StyleBoxFlat.new()
	normal.bg_color = color.darkened(0.3)
	normal.corner_radius_bottom_left = 8
	normal.corner_radius_bottom_right = 8
	normal.corner_radius_top_left = 8
	normal.corner_radius_top_right = 8
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	btn.add_theme_stylebox_override("normal", normal)

	var hover := StyleBoxFlat.new()
	hover.bg_color = color.darkened(0.15)
	hover.corner_radius_bottom_left = 8
	hover.corner_radius_bottom_right = 8
	hover.corner_radius_top_left = 8
	hover.corner_radius_top_right = 8
	hover.content_margin_left = 12
	hover.content_margin_right = 12
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = color
	pressed.corner_radius_bottom_left = 8
	pressed.corner_radius_bottom_right = 8
	pressed.corner_radius_top_left = 8
	pressed.corner_radius_top_right = 8
	pressed.content_margin_left = 12
	pressed.content_margin_right = 12
	btn.add_theme_stylebox_override("pressed", pressed)

	var disabled := StyleBoxFlat.new()
	disabled.bg_color = Color(0.2, 0.2, 0.25)
	disabled.corner_radius_bottom_left = 8
	disabled.corner_radius_bottom_right = 8
	disabled.corner_radius_top_left = 8
	disabled.corner_radius_top_right = 8
	disabled.content_margin_left = 12
	disabled.content_margin_right = 12
	btn.add_theme_stylebox_override("disabled", disabled)

	btn.pressed.connect(callback)
	return btn


func make_panel(color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	panel.add_theme_stylebox_override("panel", style)
	return panel


func make_fullscreen_overlay() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.08, 0.95)
	panel.add_theme_stylebox_override("panel", style)
	return panel
