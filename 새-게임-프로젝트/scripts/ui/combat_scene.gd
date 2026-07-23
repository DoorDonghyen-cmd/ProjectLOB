extends Control

## ═══════════════════════════════════════════════════
## 전투 및 런 제어용 메인 씬 라우터 (리팩토링 버전)
## ═══════════════════════════════════════════════════

# ── 프리로드 리소스 ──
var _gun_revolver: GunData = preload("res://resources/guns/revolver.tres")
var _gun_shotgun: GunData = preload("res://resources/guns/shotgun.tres")
var _gun_smg: GunData = preload("res://resources/guns/smg.tres")
var _gun_dmr: GunData = preload("res://resources/guns/dmr.tres")
var _gun_heavy: GunData = preload("res://resources/guns/heavy.tres")
var _gun_trickster: GunData = preload("res://resources/guns/trickster.tres")
var _gun_gambler: GunData = preload("res://resources/guns/gambler.tres")
var _gun_stance_hunter: GunData = preload("res://resources/guns/stance_hunter.tres")

var _bullets_basic: BulletData = preload("res://resources/bullets/basic_pistol.tres")
var _bullets_ap: BulletData = preload("res://resources/bullets/shred_rifle.tres")
var _bullets_kb: BulletData = preload("res://resources/bullets/knockback_pistol.tres")

var _enemy_rusher: EnemyData = preload("res://resources/enemies/rusher.tres")
var _enemy_tank: EnemyData = preload("res://resources/enemies/tank.tres")
var _enemy_dodger: EnemyData = preload("res://resources/enemies/dodger.tres")
var _enemy_drone: EnemyData = preload("res://resources/enemies/sentry_drone.tres")
var _enemy_caster: EnemyData = preload("res://resources/enemies/caster.tres")
var _enemy_absorber: EnemyData = preload("res://resources/enemies/absorber_mech.tres")
var _enemy_stalker: EnemyData = preload("res://resources/enemies/nano_stalker.tres")
var _enemy_scrambler: EnemyData = preload("res://resources/enemies/scrambler_drone.tres")
var _enemy_neuro_caster: EnemyData = preload("res://resources/enemies/neuro_caster.tres")
# ── 보스 몬스터 ──
var _boss_director: EnemyData = preload("res://resources/enemies/boss_director.tres")
var _boss_seraph: EnemyData = preload("res://resources/enemies/boss_seraph.tres")
var _boss_omega: EnemyData = preload("res://resources/enemies/boss_omega.tres")
var _boss_lob_core: EnemyData = preload("res://resources/enemies/boss_lob_core.tres")
var _bullets_heavy: BulletData = preload("res://resources/bullets/heavy_dmr.tres")
var _font_neodgm: Font = load("res://assets/fonts/NeoDunggeunmoPro-Regular.ttf")

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

var _current_node: RunManager.RunNode = null
const C_NEON_GOLD := Color(0.83, 0.69, 0.22, 1.0)

# ── 매니저 인스턴스 ──
var _cm: CombatManager
var _rm: RunManager = RunManager.new()

# ── 오버레이 스크립트 인스턴스 ──
var _title_overlay: TitleOverlay
var _map_overlay: MapOverlay
var _maintenance_overlay: MaintenanceOverlay
var _loadout_overlay: LoadoutOverlay
var _section_selector_overlay: Control
var _bullet_gallery_overlay: BulletGalleryOverlay
var _monster_gallery_overlay: MonsterGalleryOverlay
var _combat_margin: MarginContainer
var _combat_overlay: Control
var _debriefing_overlay: DebriefingOverlay
var _camera: Camera2D

# ── 현재 상태 ──
var _current_gun_data: GunData
var _is_shortcut_mode: bool = false


func _ready() -> void:
	RunManager.load_meta()   # 메타 영속 데이터 로드 (세이브 없으면 기본값 유지)
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
	_title_overlay.anchor_left = 0.0
	_title_overlay.anchor_top = 0.0
	_title_overlay.anchor_right = 1.0
	_title_overlay.anchor_bottom = 1.0
	_title_overlay.offset_left = 0
	_title_overlay.offset_top = 0
	_title_overlay.offset_right = 0
	_title_overlay.offset_bottom = 0
	_title_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title_overlay.initialize(self, _rm)
	
	# 2. Map Overlay 생성
	_map_overlay = MapOverlay.new()
	add_child(_map_overlay)
	_map_overlay.anchor_left = 0.0
	_map_overlay.anchor_top = 0.0
	_map_overlay.anchor_right = 1.0
	_map_overlay.anchor_bottom = 1.0
	_map_overlay.offset_left = 0
	_map_overlay.offset_top = 0
	_map_overlay.offset_right = 0
	_map_overlay.offset_bottom = 0
	_map_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map_overlay.initialize(self, _rm)
	_map_overlay.visible = false

	# 3. Maintenance Overlay 생성
	_maintenance_overlay = MaintenanceOverlay.new()
	add_child(_maintenance_overlay)
	_maintenance_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_maintenance_overlay.initialize(self, _rm)
	_maintenance_overlay.visible = false

	# 3-2. Loadout Overlay 생성
	_loadout_overlay = LoadoutOverlay.new()
	add_child(_loadout_overlay)
	_loadout_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_loadout_overlay.initialize(self, _rm)
	_loadout_overlay.visible = false

	# 3-2-2. Section Selector Overlay 생성
	_section_selector_overlay = preload("res://scripts/ui/overlays/section_selector_overlay.gd").new()
	add_child(_section_selector_overlay)
	_section_selector_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_section_selector_overlay.initialize(self, _rm)
	_section_selector_overlay.visible = false

	# 3-3. Bullet Gallery Overlay 생성
	_bullet_gallery_overlay = BulletGalleryOverlay.new()
	add_child(_bullet_gallery_overlay)
	_bullet_gallery_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bullet_gallery_overlay.initialize(self)
	_bullet_gallery_overlay.visible = false

	# 3-4. Monster Gallery Overlay 생성
	_monster_gallery_overlay = MonsterGalleryOverlay.new()
	add_child(_monster_gallery_overlay)
	_monster_gallery_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_monster_gallery_overlay.initialize(self)
	_monster_gallery_overlay.visible = false

	# 4. Debriefing Overlay 생성
	_debriefing_overlay = DebriefingOverlay.new()
	add_child(_debriefing_overlay)
	_debriefing_overlay.anchor_left = 0.0
	_debriefing_overlay.anchor_top = 0.0
	_debriefing_overlay.anchor_right = 1.0
	_debriefing_overlay.anchor_bottom = 1.0
	_debriefing_overlay.offset_left = 0
	_debriefing_overlay.offset_top = 0
	_debriefing_overlay.offset_right = 0
	_debriefing_overlay.offset_bottom = 0
	_debriefing_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_debriefing_overlay.initialize(self, _rm)
	_debriefing_overlay.visible = false

	# 5. Combat Overlay 생성 (마진 컨테이너 내부에 들어감)
	_combat_margin = MarginContainer.new()
	_combat_margin.add_theme_constant_override("margin_left", 24)
	_combat_margin.add_theme_constant_override("margin_right", 24)
	_combat_margin.add_theme_constant_override("margin_top", 40)
	_combat_margin.add_theme_constant_override("margin_bottom", 24)
	add_child(_combat_margin)
	
	_combat_margin.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_FILL
	_combat_margin.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_FILL
	_combat_margin.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_combat_margin.grow_vertical = Control.GROW_DIRECTION_BOTH
	_combat_margin.anchor_left = 0.0
	_combat_margin.anchor_top = 0.0
	_combat_margin.anchor_right = 1.0
	_combat_margin.anchor_bottom = 1.0
	_combat_margin.offset_left = 0
	_combat_margin.offset_top = 0
	_combat_margin.offset_right = 0
	_combat_margin.offset_bottom = 0
	_combat_margin.set_anchors_preset(PRESET_FULL_RECT)
	
	_combat_overlay = preload("res://scenes/ui/overlays/combat_overlay_v2.tscn").instantiate()
	_combat_margin.add_child(_combat_overlay)
	_combat_overlay.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_FILL
	_combat_overlay.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_FILL
	_combat_overlay.initialize(self, _rm)
	_combat_margin.visible = false


# ── 외부 연동 헬퍼들 ──

func set_current_gun(gun: GunData) -> void:
	_current_gun_data = gun


func trigger_camera_shake(intensity: float = 8.0, duration: float = 0.2) -> void:
	if not _camera:
		return
	var tween := create_tween()
	for i in range(5):
		var offset := Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		tween.tween_property(_camera, "offset", offset, duration / 6.0)
	tween.tween_property(_camera, "offset", Vector2.ZERO, duration / 6.0)


func start_run_from_title() -> void:
	if _combat_overlay:
		_combat_overlay.queue_free()
		_combat_overlay = null
	_rm.start_new_run("section_a", _current_gun_data, _bullets_basic, _bullets_ap, _bullets_kb)
	_title_overlay.visible = false
	_show_map_screen()


func trigger_parts_test_ui() -> void:
	_is_shortcut_mode = true
	_title_overlay.visible = false
	if _rm:
		_rm.current_gun = _gun_revolver
		_rm.credits = 75
		_rm.backpack_items.clear()
		var rc_part = load("res://resources/parts/rhythm_chamber.tres")
		if rc_part: _rm.backpack_items.append(rc_part)
		var pb_part = load("res://resources/parts/point_blank.tres")
		if pb_part: _rm.backpack_items.append(pb_part)
		
	var test_node = RunManager.RunNode.new(999, "무기 캐비닛 (테스트)", "숏컷 테스트 구역", [])
	_start_maintenance_phase(test_node)


func show_section_selector() -> void:
	_title_overlay.visible = false
	if _section_selector_overlay:
		_section_selector_overlay.refresh_unlocked_sections()
		_section_selector_overlay.visible = true


func handle_section_selector_closed() -> void:
	_is_shortcut_mode = false
	_show_title_screen()


func show_loadout_screen(section_key: String) -> void:
	_title_overlay.visible = false
	if _section_selector_overlay:
		_section_selector_overlay.visible = false
	if _loadout_overlay:
		_loadout_overlay.open_loadout_overlay(section_key)


func trigger_loadout_test_ui() -> void:
	_is_shortcut_mode = true
	_title_overlay.visible = false
	_loadout_overlay.open_loadout_overlay("section_a")


func trigger_bullet_gallery_ui() -> void:
	_is_shortcut_mode = true
	_title_overlay.visible = false
	_bullet_gallery_overlay.open_gallery()


func handle_gallery_closed() -> void:
	_is_shortcut_mode = false
	_show_title_screen()


func trigger_monster_gallery_ui() -> void:
	_is_shortcut_mode = true
	_title_overlay.visible = false
	_monster_gallery_overlay.open_gallery()


func handle_monster_gallery_closed() -> void:
	_is_shortcut_mode = false
	_show_title_screen()


func trigger_double_tap_test() -> void:
	_is_shortcut_mode = true
	_title_overlay.visible = false
	_current_gun_data = _gun_smg
	
	_rm.start_new_run("section_a", _current_gun_data, _bullets_basic, _bullets_ap, _bullets_kb)
	
	_combat_margin.visible = true
	if _combat_overlay:
		_combat_overlay.visible = true
		_combat_overlay.clear_combat_log()
		_combat_overlay.add_combat_log("[color=#ffff66]🛠️ 더블탭 전투 테스트 시작! (속사형 SMG 탑재)[/color]")
	
	var enemy_list: Array[EnemyData] = [_enemy_rusher, _enemy_tank]
	_start_combat_phase(enemy_list)


func trigger_v2_ui_test() -> void:
	_is_shortcut_mode = true
	_title_overlay.visible = false
	_current_gun_data = _gun_smg
	
	_rm.start_new_run("section_a", _current_gun_data, _bullets_basic, _bullets_ap, _bullets_kb)
	
	if _combat_overlay:
		_combat_overlay.queue_free()
		
	_combat_overlay = preload("res://scenes/ui/overlays/combat_overlay_v2.tscn").instantiate()
	_combat_margin.add_child(_combat_overlay)
	_combat_overlay.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_FILL
	_combat_overlay.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_FILL
	_combat_overlay.initialize(self, _rm)
	
	_combat_margin.visible = true
	if _combat_overlay:
		_combat_overlay.visible = true
		_combat_overlay.clear_combat_log()
		_combat_overlay.add_combat_log("[color=#37e0ac]🔥 목업 기반 신규 전투 UI V2 데모 모드 개시![/color]")
	
	var enemy_list: Array[EnemyData] = [_enemy_rusher, _enemy_tank, _enemy_dodger, _enemy_drone, _enemy_caster]
	_start_combat_phase(enemy_list)


## 🛠️ 보스 전투 테스트 — 개발자 테스트 메뉴에서 보스전을 즉시 실행한다.
## boss_id에 따라 해당 보스와 호위 대열을 조합하여 전투를 개시한다.
func trigger_boss_test(boss_id: String) -> void:
	_is_shortcut_mode = true
	_title_overlay.visible = false
	_current_gun_data = _gun_smg
	
	_rm.start_new_run("section_a", _current_gun_data, _bullets_basic, _bullets_ap, _bullets_kb)
	
	if _combat_overlay:
		_combat_overlay.queue_free()
		
	_combat_overlay = preload("res://scenes/ui/overlays/combat_overlay_v2.tscn").instantiate()
	_combat_margin.add_child(_combat_overlay)
	_combat_overlay.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_FILL
	_combat_overlay.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_FILL
	_combat_overlay.initialize(self, _rm)
	
	_combat_margin.visible = true
	if _combat_overlay:
		_combat_overlay.visible = true
		_combat_overlay.clear_combat_log()
	
	var enemy_list: Array[EnemyData] = []
	var boss_name := ""
	
	match boss_id:
		"boss_director":
			# 보스 #1: 디렉터 강 (단독 보스전)
			enemy_list = [_boss_director]
			boss_name = "디렉터 강"
		"boss_seraph":
			# 보스 #2: 세라프 프로토콜 (호위: rusher + tank)
			enemy_list = [_enemy_rusher, _enemy_tank, _boss_seraph]
			boss_name = "세라프 프로토콜"
		"boss_omega":
			# 보스 #3: 실험체 Ω (단독 보스전)
			enemy_list = [_boss_omega]
			boss_name = "실험체 Ω"
		"boss_lob_core":
			# 최종 보스: L.O.B 코어 (호위: rusher + dodger + tank)
			enemy_list = [_enemy_rusher, _enemy_dodger, _enemy_tank, _boss_lob_core]
			boss_name = "L.O.B 코어"
		_:
			enemy_list = [_boss_director]
			boss_name = "보스 테스트"
	
	_combat_overlay.add_combat_log("[color=#ff4444]⚠️ 보스전 테스트 개시: %s[/color]" % boss_name)
	_start_combat_phase(enemy_list)


func handle_loadout_finished() -> void:
	if _is_shortcut_mode:
		_is_shortcut_mode = false
		_show_title_screen()
		return
		
	# 실제 런(Run) 개시
	# ⚠️ 연속 런 구조: 런은 항상 최하층(section_a)에서 시작해 해금된 최고 계층까지 이어진다.
	#    구역 선택은 시작 지점을 고르는 것이 아니라 온보딩 램프(런 길이)를 나타낸다.
	#    정본: docs/gdd/20_ascension_intention.md §3
	_rm.start_new_run(RunManager.SECTION_ORDER[0], _current_gun_data, _bullets_basic, _bullets_ap, _bullets_kb)
	_show_map_screen()


func _show_title_screen() -> void:
	if _combat_overlay:
		_combat_overlay.queue_free()
		_combat_overlay = null
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
	_current_node = selected_node
	_rm.current_node_id = selected_node.id
	var old_floor = _rm.current_floor
	var new_floor = selected_node.id / 100
	_rm.current_floor = new_floor
	
	if new_floor > old_floor + 1:
		_map_overlay.trigger_floor_skip_effect(old_floor, new_floor)
		
	var msg := _rm.select_route(route)
	
	# 미지 노드 위험 완충망 처리
	var triggered_safeguard := false
	# ⚠️ hidden_type 문자열은 map_generator.gd의 ??? 노드 생성부와 정확히 일치해야 한다.
	if selected_node.type_name.begins_with("???") and selected_node.hidden_type == "매복 구획 (전투)":
		if randf() < 0.3:
			triggered_safeguard = true
			if randf() < 0.5:
				_trigger_safehouse_event()
			else:
				_trigger_blackmarket_event()
				
	if triggered_safeguard:
		return
		
	var target_type := selected_node.type_name
	if selected_node.type_name.begins_with("???"):
		target_type = selected_node.hidden_type
		
	if target_type.contains("전투") or target_type.contains("보스") or target_type.contains("Boss"):
		# 전투 로그 출력을 위해 Combat Overlay 및 컨테이너를 준비해 둠
		_combat_margin.visible = true
		if _combat_overlay:
			_combat_overlay.visible = true
			_combat_overlay.clear_combat_log()
			_combat_overlay.add_combat_log("[color=#ffff66]%s[/color]" % msg)
		var enemy_list: Array = []
		var floor_num := _rm.current_floor
		var section := _rm.current_section
		
		if selected_node.type_name.contains("보스") or selected_node.type_name.contains("Boss") or selected_node.type_name.contains("boss"):
			if section == "section_a":
				# 지하 주차장 보스: 탱크 + 회피 (1지역 보스 유형)
				enemy_list = [_enemy_tank, _enemy_dodger]
			elif section == "section_b":
				# 사무동 하층 보스: 탱크 + 술사
				enemy_list = [_enemy_tank, _enemy_caster]
			elif section == "section_c":
				# 연구소 중층 보스: 흡수(스펀지) + 술사
				enemy_list = [_enemy_absorber, _enemy_caster]
			else:
				# 펜트하우스/무한루프 보스
				if floor_num <= 5:
					enemy_list = [_enemy_tank, _enemy_neuro_caster]
				elif floor_num <= 10:
					enemy_list = [_enemy_absorber, _enemy_rusher, _enemy_neuro_caster]
				else:
					enemy_list = [_enemy_absorber, _enemy_stalker, _enemy_neuro_caster, _enemy_scrambler]
		else:
			# 일반전 스폰 분기
			if section == "section_a":
				# 지하 주차장: 입문 (1~10층) - 기본 3종만 스폰
				if floor_num <= 3:
					enemy_list = [_enemy_rusher] if randf() < 0.5 else [_enemy_rusher, _enemy_dodger]
				elif floor_num <= 6:
					enemy_list = [_enemy_rusher, _enemy_tank] if randf() < 0.5 else [_enemy_dodger, _enemy_tank]
				else:
					enemy_list = [_enemy_rusher, _enemy_tank, _enemy_dodger]
			elif section == "section_b":
				# 사무동 하층: 초급 (1~12층) - 술사(Caster), 드론(Drone) 유입
				if floor_num <= 4:
					enemy_list = [_enemy_rusher, _enemy_dodger]
				elif floor_num <= 8:
					enemy_list = [_enemy_rusher, _enemy_tank, _enemy_drone]
				else:
					enemy_list = [_enemy_tank, _enemy_caster, _enemy_drone]
			elif section == "section_c":
				# 연구소 중층: 중급 (1~12층) - 스펀지(Absorber) 유입
				if floor_num <= 4:
					enemy_list = [_enemy_rusher, _enemy_tank, _enemy_dodger]
				elif floor_num <= 8:
					enemy_list = [_enemy_tank, _enemy_caster, _enemy_drone]
				else:
					enemy_list = [_enemy_absorber, _enemy_rusher, _enemy_caster]
			else:
				# 펜트하우스 & 무한 루프: 상급/도전 (기존 하드코딩된 전체 층 테이블 활용)
				if floor_num <= 3:
					enemy_list = [_enemy_rusher] if randf() < 0.5 else [_enemy_rusher, _enemy_dodger]
				elif floor_num <= 6:
					var r := randf()
					if r < 0.33:
						enemy_list = [_enemy_rusher, _enemy_tank]
					elif r < 0.66:
						enemy_list = [_enemy_rusher, _enemy_drone, _enemy_caster]
					else:
						enemy_list = [_enemy_scrambler, _enemy_dodger]
				elif floor_num <= 10:
					var r := randf()
					if r < 0.33:
						enemy_list = [_enemy_tank, _enemy_dodger, _enemy_caster]
					elif r < 0.66:
						enemy_list = [_enemy_scrambler, _enemy_drone, _enemy_caster]
					else:
						enemy_list = [_enemy_stalker, _enemy_scrambler, _enemy_tank]
				else:
					var r := randf()
					if r < 0.33:
						enemy_list = [_enemy_absorber, _enemy_scrambler, _enemy_neuro_caster]
					elif r < 0.66:
						enemy_list = [_enemy_tank, _enemy_stalker, _enemy_caster]
					else:
						enemy_list = [_enemy_rusher, _enemy_stalker, _enemy_drone, _enemy_neuro_caster]
				
		_start_combat_phase(enemy_list)
	else:
		_combat_margin.visible = false
		if _combat_overlay:
			_combat_overlay.visible = false
		_start_maintenance_phase(selected_node)


func _start_combat_phase(enemy_datas: Array) -> void:
	if _cm:
		_cm.queue_free()
	_cm = CombatManager.new()
	_cm.name = "CombatManager"
	add_child(_cm)
	
	if not is_instance_valid(_combat_overlay):
		_combat_overlay = preload("res://scenes/ui/overlays/combat_overlay_v2.tscn").instantiate()
		_combat_margin.add_child(_combat_overlay)
		_combat_overlay.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_FILL
		_combat_overlay.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_FILL
		_combat_overlay.initialize(self, _rm)
		
	_combat_margin.visible = true
	_combat_overlay.visible = true
	
	var typed_enemies: Array[EnemyData] = []
	typed_enemies.assign(enemy_datas)
	
	_combat_overlay.start_combat(_current_gun_data, typed_enemies, _cm)


func _start_maintenance_phase(node: RunManager.RunNode) -> void:
	_maintenance_overlay.start_maintenance_phase(node)


func handle_maintenance_finished() -> void:
	if _is_shortcut_mode:
		_is_shortcut_mode = false
		_show_title_screen()
		return

	_rm.record_node_clear(_current_node)
		
	# ── 기밀 파편 수집 연동 ──
	if _current_node:
		var fid := 0
		if _current_node.id == 302:
			fid = 4
		elif _current_node.id == 602:
			fid = 11
		elif _current_node.id == 802:
			fid = 18
		else:
			if randf() < 0.10:
				var uncollected: Array[int] = []
				for i in range(1, 21):
					if not RunManager.meta_lore_fragments.has(i):
						uncollected.append(i)
				if not uncollected.is_empty():
					fid = uncollected.pick_random()
					
		if fid > 0:
			if _rm.collect_lore_fragment(fid):
				print("📥 [정비실 정보 복원] 기밀 파편 #%d번 복원!" % fid)

	_advance_floor_or_finish()


func handle_combat_finished(is_dead: bool) -> void:
	_combat_margin.visible = false
	if _combat_overlay:
		_combat_overlay.visible = false
	if _is_shortcut_mode:
		_is_shortcut_mode = false
		_show_title_screen()
		return
		
	# 전투 통계 이전
	if _cm:
		_rm.run_stats.lead_bullets_fired += _cm.battle_stats.lead_bullets_fired
		_rm.run_stats.max_kills_in_single_turn = max(_rm.run_stats.max_kills_in_single_turn, _cm.battle_stats.max_kills_in_single_turn)
		_rm.run_stats.total_kills += _cm.battle_stats.total_kills
		_rm.run_stats.total_kill_dist_sum += _cm.battle_stats.total_kill_dist_sum
		_rm.run_stats.tanks_killed_by_shred_only += _cm.battle_stats.shred_only_tank_kills
		_rm.run_stats.stance_shifts_killed_without_slow += _cm.battle_stats.stance_kills_without_slow
		
		# 최소 접근 거리
		if _cm.battle_stats.min_dist_allowed < _rm.run_stats.min_dist_allowed:
			_rm.run_stats.min_dist_allowed = _cm.battle_stats.min_dist_allowed
			
		# 완벽 실행 (빗나감과 0뎀 타격이 없고, 최소 1킬 이상 처치)
		if _cm.battle_stats.misses == 0 and _cm.battle_stats.zero_damage_hits == 0 and _cm.battle_stats.total_kills > 0:
			_rm.run_stats.perfect_battles_count += 1

	if is_dead:
		_show_debriefing(false)
		return

	_rm.record_node_clear(_current_node)
		
	# ── 기밀 파편 수집 연동 ──
	if _current_node:
		var fid := 0
		if _current_node.id == 302:
			fid = 4 # 3층 보안 무기고 확정
		elif _current_node.id == 602:
			fid = 11 # 6층 가스 제어실 확정
		elif _current_node.id == 802:
			fid = 18 # 8층 약실 조율실 확정
		else:
			if randf() < 0.30:
				var uncollected: Array[int] = []
				for i in range(1, 21):
					if not RunManager.meta_lore_fragments.has(i):
						uncollected.append(i)
				if not uncollected.is_empty():
					fid = uncollected.pick_random()
					
		if fid > 0:
			if _rm.collect_lore_fragment(fid):
				if _combat_overlay:
					_combat_overlay.add_combat_log("[color=#00ff66]📥 [기밀 정보 복원] 우회로 또는 적 데이터 분석을 통해 기밀 파편 #%d번을 회수했습니다![/color]" % fid)

	_advance_floor_or_finish()


## 다음 층으로 진행한다. 계층의 최종층을 넘으면 **다음 계층으로 이어지고**,
## 더 오를 계층이 없으면 그때 런을 완주 처리한다.
##
## ⚠️ 연속 런 구조 (docs/gdd/20_ascension_intention.md §3)
##   - 한 런 = 1계층부터 **해금된 최고 계층**까지 연속. 계층이 바뀌어도 런은 끊기지 않는다.
##   - 덱·파츠·가방·크레딧은 계층을 넘어 그대로 누적된다(start_new_run을 다시 부르지 않음).
##   - 구역 순차 해금은 난이도 사다리가 아니라 **런 길이 램프**로 작동한다.
## ⚠️ 구역마다 층수가 다르므로 반드시 section_info를 참조할 것.
##    과거 `> 15` 하드코딩 탓에 층수가 적은 계층이 완주되지 않고 존재하지 않는 층의
##    빈 맵으로 이동해 진행이 막히는 버그가 있었다.
func _advance_floor_or_finish() -> void:
	_rm.current_floor += 1
	var max_floor: int = int(MapGenerator.section_info(_rm.current_section).floors)
	if _rm.current_floor <= max_floor:
		_show_map_screen()
		return

	# 계층 완주 — 다음 계층이 해금돼 있으면 이어서 오른다.
	var next_section := _rm.get_next_unlocked_section()
	if next_section == "":
		_show_debriefing(true)  # 더 오를 곳이 없다 = 런 완주
	else:
		_advance_to_next_section(next_section)


## 다음 계층으로 진입한다. 런 자원(덱·파츠·크레딧)은 유지된다.
func _advance_to_next_section(next_section: String) -> void:
	var prev_name: String = MapGenerator.section_info(_rm.current_section).name
	var next_name: String = MapGenerator.section_info(next_section).name

	_rm.enter_section(next_section)

	if _combat_overlay:
		_combat_overlay.visible = false
	_map_overlay.visible = false

	_show_section_transition(prev_name, next_name)


## 계층 전환 연출 — 한 계층을 돌파하고 상위 계층으로 오르는 순간을 표시한다.
## 런은 끊기지 않으므로 정산 없이 "계속 오른다"는 감각만 전달한다.
func _show_section_transition(prev_name: String, next_name: String) -> void:
	var popup := PanelContainer.new()
	popup.set_anchors_preset(Control.PRESET_CENTER)
	popup.custom_minimum_size = Vector2(460, 0)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.11, 0.98)
	style.set_border_width_all(2)
	style.border_color = C_ACCENT
	style.corner_radius_top_left = 6; style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6; style.corner_radius_bottom_right = 6
	popup.add_theme_stylebox_override("panel", style)
	add_child(popup)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	popup.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)

	var title = make_label("▲ 상위 계층 진입", 18, C_ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var lv: int = MapGenerator.absolute_level(_rm.current_section, 1)
	var body := "[%s] 돌파 — 위로 향하는 통로가 열렸습니다.\n\n" % prev_name
	body += "▶ [b]%s[/b] (LV.%04d)\n\n" % [next_name, lv]
	body += "장비와 물자는 그대로 유지됩니다."

	var desc = make_label(body, 12, C_TEXT)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(desc)

	var btn = make_button("계속 오른다 ▲", func():
		popup.queue_free()
		_show_map_screen()
	, C_SUCCESS)
	btn.custom_minimum_size = Vector2(180, 40)
	vbox.add_child(btn)


func _show_debriefing(won: bool) -> void:
	if _combat_overlay:
		_combat_overlay.queue_free()
		_combat_overlay = null
	_debriefing_overlay.show_debriefing(won)


func handle_debrief_confirmed() -> void:
	_show_title_screen()


# ═══════════════════════════════════════════════════
# UI 팩토리 헬퍼들 (하위 오버레이가 사용함)
# ═══════════════════════════════════════════════════

func make_label(text: String, size: int = 24, color: Color = C_TEXT) -> Label:
	var label := Label.new()
	label.text = text
	if _font_neodgm != null:
		label.add_theme_font_override("font", _font_neodgm)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func make_button(text: String, callback: Callable, color: Color = C_ACCENT) -> Button:
	var btn := Button.new()
	btn.text = text
	if _font_neodgm != null:
		btn.add_theme_font_override("font", _font_neodgm)
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

func _trigger_safehouse_event() -> void:
	# 안전 가옥 (Safe House)
	# HP 버퍼 +1 회복 (최대치 한도 내)
	var max_hp = 1 + RunManager.meta_hp_armor_lvl
	_rm.hp_buffer = mini(_rm.hp_buffer + 1, max_hp)
	var recovered_bullets = _rm.recover_discarded_bullets()
	
	var popup := PanelContainer.new()
	popup.custom_minimum_size = Vector2(460, 240)
	add_child(popup)
	popup.set_anchors_preset(Control.PRESET_CENTER)
	popup.grow_horizontal = Control.GROW_DIRECTION_BOTH
	popup.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08, 0.98)
	style.border_width_left = 2; style.border_width_right = 2
	style.border_width_top = 2; style.border_width_bottom = 2
	style.border_color = C_SUCCESS
	style.corner_radius_top_left = 6; style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6; style.corner_radius_bottom_right = 6
	popup.add_theme_stylebox_override("panel", style)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	popup.add_child(margin)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)
	
	var title = make_label("🏡 [위험 완충] 안전 가옥 조우", 18, C_SUCCESS)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	var text_content = "구역 2/3의 연속된 교전 도중 기적적으로 안전 가옥을 발견했습니다.\n"
	text_content += "- [치료] 소실된 HP 버퍼가 1 회복되었습니다. (현재 버퍼: %d)\n" % _rm.hp_buffer
	text_content += "- [복원] 빼내기(Unload)로 잃었던 탄환 %d발이 가방으로 안전 복구되었습니다." % recovered_bullets
	
	var desc = make_label(text_content, 12, C_TEXT)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(desc)
	
	var btn = make_button("작전 계속", func():
		popup.queue_free()
		_advance_floor_or_finish()
	, C_SUCCESS)
	btn.custom_minimum_size = Vector2(160, 36)
	btn.add_theme_font_size_override("font_size", 12)
	vbox.add_child(btn)

func _trigger_blackmarket_event() -> void:
	# 암시장 상인 (Black Market)
	var popup := PanelContainer.new()
	popup.custom_minimum_size = Vector2(480, 260)
	add_child(popup)
	popup.set_anchors_preset(Control.PRESET_CENTER)
	popup.grow_horizontal = Control.GROW_DIRECTION_BOTH
	popup.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08, 0.98)
	style.border_width_left = 2; style.border_width_right = 2
	style.border_width_top = 2; style.border_width_bottom = 2
	style.border_color = C_WARNING
	style.corner_radius_top_left = 6; style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6; style.corner_radius_bottom_right = 6
	popup.add_theme_stylebox_override("panel", style)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	popup.add_child(margin)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)
	
	var title = make_label("🕵️ [위험 완충] 암시장 상인과 조우", 18, C_WARNING)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	var desc = make_label("교전 위험 지대 사이에서 밀수업자를 만났습니다. (보유 크레딧: %d Cr)" % _rm.credits, 12, C_TEXT)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(desc)
	
	var btn_hbox := HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 12)
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_hbox)
	
	var btn_part = make_button("파츠 밀수 (30 Cr)", func():
		if _rm.spend_credits(30):
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
				_rm.add_to_backpack(chosen)
				print("🕵️ 암시장 파츠 구매: %s" % chosen.display_name)
			popup.queue_free()
			_blackmarket_close_transition()
	, C_WARNING)
	btn_part.custom_minimum_size = Vector2(150, 40)
	btn_part.add_theme_font_size_override("font_size", 11)
	btn_part.disabled = _rm.credits < 30
	btn_hbox.add_child(btn_part)
	
	var btn_bullet = make_button("탄환 밀수 (15 Cr)", func():
		if _rm.spend_credits(15):
			var path := "res://resources/bullets/"
			var dir := DirAccess.open(path)
			var bullets_pool: Array[BulletData] = []
			if dir:
				dir.list_dir_begin()
				var file_name = dir.get_next()
				while file_name != "":
					if not dir.current_is_dir() and not file_name.is_empty() and not file_name.ends_with(".import"):
						if file_name.ends_with(".tres") or file_name.ends_with(".tres.remap") or file_name.ends_with(".res") or file_name.ends_with(".res.remap"):
							var clean_name = file_name.replace(".remap", "")
							var res = load(path + clean_name)
							if res is BulletData:
								bullets_pool.append(res)
					file_name = dir.get_next()
				dir.list_dir_end()
			if not bullets_pool.is_empty():
				var chosen = bullets_pool.pick_random().duplicate() as BulletData
				_rm.add_to_deck(chosen)
				print("🕵️ 암시장 탄환 구매: %s" % chosen.display_name)
			popup.queue_free()
			_blackmarket_close_transition()
	, C_WARNING)
	btn_bullet.custom_minimum_size = Vector2(150, 40)
	btn_bullet.add_theme_font_size_override("font_size", 11)
	btn_bullet.disabled = _rm.credits < 15
	btn_hbox.add_child(btn_bullet)
	
	var btn_pass = make_button("지나친다", func():
		popup.queue_free()
		_blackmarket_close_transition()
	, C_PANEL)
	btn_pass.custom_minimum_size = Vector2(100, 40)
	btn_pass.add_theme_font_size_override("font_size", 11)
	btn_hbox.add_child(btn_pass)

func _blackmarket_close_transition() -> void:
	_advance_floor_or_finish()
