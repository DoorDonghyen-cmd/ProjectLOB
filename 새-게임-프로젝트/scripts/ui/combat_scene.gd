extends Control

const CampaignContentScript := preload("res://scripts/core/campaign_content.gd")
const EnemyRosterScript := preload("res://scripts/core/enemy_roster.gd")
const ItemCatalogScript := preload("res://scripts/core/item_catalog.gd")
const RandomStreamsScript := preload("res://scripts/core/random_streams.gd")

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
var _gun_suppressor: GunData = preload("res://resources/guns/suppressor.tres")

var _bullets_basic: BulletData = preload("res://resources/bullets/cal_9mm.tres")
var _bullets_ap: BulletData = preload("res://resources/bullets/shred.tres")
var _bullets_kb: BulletData = preload("res://resources/bullets/impact.tres")

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
var _bullets_heavy: BulletData = preload("res://resources/bullets/pierce.tres")
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
var _is_guidance_shortcut: bool = false
var _qa_gameplay_seed: int = 0
var _qa_session_id: String = ""


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


func configure_qa_run(gameplay_seed: int, session_id: String) -> void:
	_qa_gameplay_seed = gameplay_seed
	_qa_session_id = session_id


func trigger_camera_shake(intensity: float = 8.0, duration: float = 0.2) -> void:
	if not _camera:
		return
	var tween := create_tween()
	for i in range(5):
		var offset := Vector2(
			RandomStreamsScript.fx_float_range(-intensity, intensity),
			RandomStreamsScript.fx_float_range(-intensity, intensity)
		)
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
	# 호출자가 이미 숨겼더라도 여기서 한 번 더 보장한다.
	# 화면 전환의 책임을 호출자에게만 맡기면, 다른 경로로 들어왔을 때 브리핑이 남는다.
	if _section_selector_overlay:
		_section_selector_overlay.visible = false
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


## 개발자 메뉴의 전체 초기화 진입점.
## 영구 세이브와 현재 런을 지운 뒤 첫 실행의 기본 총기·타이틀 상태로 돌아간다.
func trigger_reset_all_progress() -> Error:
	var result := _rm.reset_all_progress()
	_is_shortcut_mode = false
	_current_node = null
	_current_gun_data = _gun_revolver
	_show_title_screen()
	return result


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


## 전술 기관단총의 연계→공격 연발 체인을 직접 확인하는 개발자 전투.
func trigger_tempo_full_auto_test() -> void:
	_is_shortcut_mode = true
	_title_overlay.visible = false
	_current_gun_data = _gun_smg

	_rm.start_new_run("section_a", _current_gun_data, _bullets_basic, _bullets_ap, _bullets_kb)

	_combat_margin.visible = true
	if _combat_overlay:
		_combat_overlay.visible = true
		_combat_overlay.clear_combat_log()
		_combat_overlay.add_combat_log(
			"[color=#ffff66]🛠️ 기관단총 연발 체인 테스트 시작! 공격탄을 먼저, 연계탄을 나중에 넣으십시오.[/color]")

	var enemy_list: Array[EnemyData] = [_enemy_rusher, _enemy_tank]
	_start_combat_phase(enemy_list)


## 연발(제압형) 전투 테스트.
## 정본: docs/gdd/21_fire_mode.md
##
## 연발의 세 가지 성격이 한 판에 다 나오도록 구성한다:
##   ① 다수전 특화 — 앞의 적이 죽으면 남은 탄이 다음 적으로 이월된다
##   ② 적재 퍼즐   — 중장갑을 뚫으려면 파쇄탄을 **앞쪽(먼저 나가는 자리)**에 깔아야 한다
##   ③ 리로드 공백 — 5발 쏟고 3턴 무방비. 그동안 적이 계속 다가온다
func trigger_full_auto_test() -> void:
	_is_shortcut_mode = true
	_title_overlay.visible = false
	_current_gun_data = _gun_suppressor

	_rm.start_new_run(
		RunManager.SECTION_ORDER[0], _current_gun_data,
		_bullets_basic, _bullets_ap, _bullets_kb,
		_qa_gameplay_seed, _qa_session_id)

	_combat_margin.visible = true
	if _combat_overlay:
		_combat_overlay.visible = true
		_combat_overlay.clear_combat_log()
		_combat_overlay.add_combat_log("[color=#ffff66]🛠️ 연발 전투 테스트 — 제압형(Suppressor)[/color]")
		_combat_overlay.add_combat_log("[color=#88ff88]· 발사하면 탄창 5발이 [b]한 턴에[/b] 전부 나갑니다. 중간에 멈출 수 없습니다.[/color]")
		_combat_overlay.add_combat_log("[color=#88ff88]· 앞의 적이 쓰러지면 남은 탄이 [b]다음 적[/b]으로 이어집니다.[/color]")
		_combat_overlay.add_combat_log("[color=#ffcc44]· 중장갑(탱크)이 섞여 있습니다 — 파쇄탄을 먼저 나가는 자리에 깔아 보세요.[/color]")
		_combat_overlay.add_combat_log("[color=#ff8888]· 쏟아붓고 나면 재장전 3턴 동안 무방비입니다.[/color]")

	# 돌격 2 + 중장갑 1 — ①과 ②를 동시에 요구하는 최소 구성
	var enemy_list: Array[EnemyData] = [_enemy_rusher, _enemy_rusher, _enemy_tank]
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


## 모바일 미지 노드 2탭과 연계→결산 예고·Tempo 2탄창 호흡을 한 흐름에서 확인한다.
## 첫 화면은 2층 미지 노드이며, 진입하면 연계 6종·결산 2종이 든 장전 화면으로 이어진다.
func trigger_scan_guidance_test() -> void:
	_is_shortcut_mode = true
	_is_guidance_shortcut = true
	_title_overlay.visible = false
	_current_gun_data = _gun_smg
	_rm.start_new_run("section_a", _current_gun_data, _bullets_basic, _bullets_ap, _bullets_kb)

	_rm.deck.clear()
	for bullet_id in [
		"marker", "borer", "jammer", "shred", "guide", "align", "chain", "crosscal"
	]:
		var bullet: BulletData = load("res://resources/bullets/%s.tres" % bullet_id)
		if bullet != null:
			_rm.deck.append(bullet.duplicate())

	# 1층 101에서 2층 미지 노드 202로 향하는 고정 QA 상태.
	_rm.current_floor = 2
	_rm.current_node_id = 101
	var unknown: RunManager.RunNode = _rm.map_nodes.get(202)
	if unknown != null:
		unknown.hidden_type = "매복 구획 (전투)"
		unknown.scan_hint = "스캔: 고속·장갑·회피 혼성 대열 감지 (연계·결산 QA)"
	_show_map_screen()


## 기본탄 성향과 ACC/PEN/DMG/CTRL 전술탄 카드, 다음 1발 강화 효과를 즉시 확인한다.
func trigger_ammo_specialty_test() -> void:
	_is_shortcut_mode = true
	_title_overlay.visible = false
	_current_gun_data = _gun_revolver
	_rm.start_new_run("section_a", _current_gun_data, _bullets_basic, _bullets_ap, _bullets_kb)

	_rm.deck.clear()
	for bullet_id in [
		"cal_9mm", "cal_556", "cal_12g",
		"marker", "borer", "chain", "impact", "finale",
	]:
		var bullet: BulletData = load("res://resources/bullets/%s.tres" % bullet_id)
		if bullet != null:
			_rm.deck.append(bullet.duplicate())

	_start_combat_phase([_enemy_tank, _enemy_dodger, _enemy_rusher] as Array[EnemyData])
	if _combat_overlay:
		_combat_overlay.clear_combat_log()
		_combat_overlay.add_combat_log(
			"[color=#ffff66]🛠️ 탄환 전문축 QA — [ACC] [PEN] [DMG] [CTRL] · [기본탄][/color]")
		_combat_overlay.add_combat_log(
			"[color=#88ff88]· 기본탄 성향과 전술탄의 전문축·효과 한 줄을 비교하십시오.[/color]")
		_combat_overlay.add_combat_log(
			"[color=#ffcc44]· 표식/천공/장약 증폭탄의 다음 1발 ACC/PEN/DMG 강화를 확인하십시오.[/color]")


## 관리·정점의 대표 4체 일반전을 즉시 비교하는 수동 플레이테스트 진입점.
## 편성은 EnemyRoster의 실제 종반 후보를 그대로 쓰고, Workhorse와 동일 전술탄 묶음으로
## 계층 간 탄환 순서·거리 압력 차이만 비교한다.
func trigger_upper_roster_test(section: String) -> void:
	if not EnemyRosterScript.UPPER_QA_ENCOUNTER_IDS.has(section):
		push_warning("상층 편성 QA를 지원하지 않는 계층: %s" % section)
		return

	_is_shortcut_mode = true
	_title_overlay.visible = false
	_current_gun_data = _gun_revolver
	_rm.start_new_run(section, _current_gun_data, _bullets_basic, _bullets_ap, _bullets_kb)

	# 같은 전술탄 풀로 관리/정점을 번갈아 플레이해 편성 차이만 비교한다.
	_rm.deck.clear()
	for bullet_id in [
		"marker", "borer", "jammer", "shred", "guide", "align",
		"chain", "crosscal", "pierce", "finale", "impact",
	]:
		var bullet: BulletData = load("res://resources/bullets/%s.tres" % bullet_id)
		if bullet != null:
			_rm.deck.append(bullet.duplicate())

	var enemy_list: Array[EnemyData] = EnemyRosterScript.load_upper_qa_encounter(section)
	_start_combat_phase(enemy_list)
	if _combat_overlay:
		var section_name := str(MapGenerator.section_info(section).get("name", section))
		_combat_overlay.clear_combat_log()
		_combat_overlay.add_combat_log(
			"[color=#ffff66]🛠️ %s 종반 4체 편성 QA — Workhorse 공통 탄약[/color]" % section_name)
		_combat_overlay.add_combat_log(
			"[color=#88ff88]· 적의 거리·게이트를 읽고 마지막에 넣은 탄부터 발사되도록 순서를 설계하십시오.[/color]")
		_combat_overlay.add_combat_log(
			"[color=#ffcc44]· 승패보다 첫 위협 제거 시점, 긴급 격퇴 사용 시점, 재장전 가능 여부를 비교하십시오.[/color]")


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
	
	var section := CampaignContentScript.section_for_boss(boss_id)
	var enemy_list: Array[EnemyData] = CampaignContentScript.load_gate_encounter(section)
	var boss_name: String = str({
		"boss_director": "디렉터 강",
		"boss_seraph": "세라프 방어 프로토콜",
		"boss_omega": "적합성 개조체 Ω",
		"boss_lob_core": "L.O.B 코어",
	}.get(boss_id, "보스 테스트"))
	
	_combat_overlay.add_combat_log("[color=#ff4444]⚠️ 보스전 테스트 개시: %s[/color]" % boss_name)
	_start_combat_phase(enemy_list)


func handle_loadout_finished() -> void:
	if _is_shortcut_mode:
		_is_shortcut_mode = false
		_show_title_screen()
		return
		
	# 실제 런(Run) 개시
	# ⚠️ 연속 런 구조: 런은 항상 최하층(section_a)에서 시작해 정점까지 35층을 이어 오른다.
	#    잠긴 계층은 바로 아래 관문을 돌파하는 순간 해금되며 런을 끊지 않는다.
	#    정본: docs/gdd/20_ascension_intention.md §3
	_rm.start_new_run(
		RunManager.SECTION_ORDER[0], _current_gun_data,
		_bullets_basic, _bullets_ap, _bullets_kb,
		_qa_gameplay_seed, _qa_session_id)
	_show_map_screen()


func _show_title_screen() -> void:
	_is_guidance_shortcut = false
	if _combat_overlay:
		_combat_overlay.queue_free()
		_combat_overlay = null
	_title_overlay.visible = true
	_map_overlay.visible = false
	_maintenance_overlay.visible = false
	_loadout_overlay.visible = false
	_section_selector_overlay.visible = false
	_bullet_gallery_overlay.visible = false
	_monster_gallery_overlay.visible = false
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
	if not _is_guidance_shortcut \
			and selected_node.type_name.begins_with("???") \
			and selected_node.hidden_type == "매복 구획 (전투)":
		if RandomStreamsScript.gameplay_float("event") < 0.3:
			triggered_safeguard = true
			if RandomStreamsScript.gameplay_float("event") < 0.5:
				_trigger_safehouse_event()
			else:
				_trigger_blackmarket_event()
				
	if triggered_safeguard:
		return
		
	var target_type := selected_node.type_name
	if selected_node.type_name.begins_with("???"):
		target_type = selected_node.hidden_type
		
	var is_major_gate := CampaignContentScript.is_major_gate_type(target_type)
	if target_type.contains("전투") or is_major_gate:
		# 전투 로그 출력을 위해 Combat Overlay 및 컨테이너를 준비해 둠
		_combat_margin.visible = true
		if _combat_overlay:
			_combat_overlay.visible = true
			_combat_overlay.clear_combat_log()
			_combat_overlay.add_combat_log("[color=#ffff66]%s[/color]" % msg)
		var enemy_list: Array = []
		var floor_num := _rm.current_floor
		var section := _rm.current_section

		if _is_guidance_shortcut:
			enemy_list = [_enemy_rusher, _enemy_dodger, _enemy_tank]
		
		# 관문 편성은 CampaignContent가 단일 정본이다.
		# A/B/C/E는 보스 4종, D는 기존 자물쇠를 종합한 정예 관문으로 구성한다.
		if _is_guidance_shortcut:
			pass
		elif is_major_gate:
			enemy_list = CampaignContentScript.load_gate_encounter(section)
		else:
			# 일반전 편성은 EnemyRoster가 단일 정본이다. 구간은 계층 층수에 비례하며,
			# 관리 계층과 정점은 서로 다른 후보 풀을 사용한다.
			var tier := MapGenerator.floor_tier(section, floor_num)
			enemy_list = EnemyRosterScript.load_regular_encounter(section, tier)
			enemy_list = _increase_regular_enemy_density(section, tier, enemy_list)

		_start_combat_phase(enemy_list)
	else:
		_combat_margin.visible = false
		if _combat_overlay:
			_combat_overlay.visible = false
		_start_maintenance_phase(selected_node)


## 탄종 행동이 실제 전투에서 드러나도록 일반전 밀도를 단계적으로 높인다.
## 첫 구역 초반과 보스 편성은 건드리지 않으며, 1차 조정의 상한은 4체다.
## roll 인자는 자동 테스트에서 2~3체/3~4체 분기를 결정론적으로 검증할 때 사용한다.
func _increase_regular_enemy_density(
	section: String,
	tier: int,
	enemy_list: Array,
	roll: float = -1.0
) -> Array:
	var result: Array = enemy_list.duplicate()
	var density_roll := RandomStreamsScript.gameplay_float("encounter") \
		if roll < 0.0 else clampf(roll, 0.0, 1.0)
	var target_count := EnemyRosterScript.target_count(section, tier, result.size(), density_roll)
	var candidates: Array = EnemyRosterScript.load_density_candidates(section)

	# 같은 적을 중복 추가하지 않아 기존 편성의 역할 조합을 보존한다.
	for candidate in candidates:
		if result.size() >= target_count:
			break
		if not result.has(candidate):
			result.append(candidate)
	return result


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
			if RandomStreamsScript.gameplay_float("reward") < 0.10:
				var uncollected: Array[int] = []
				for i in range(1, 21):
					if not RunManager.meta_lore_fragments.has(i):
						uncollected.append(i)
				if not uncollected.is_empty():
					fid = int(RandomStreamsScript.gameplay_pick(uncollected, "reward"))
					
		if fid > 0:
			if _rm.collect_lore_fragment(fid):
				print("📥 [정비실 정보 복원] 기밀 파편 #%d번 복원!" % fid)

	_advance_floor_or_finish()


func handle_combat_finished(is_dead: bool) -> void:
	_combat_margin.visible = false
	if _combat_overlay:
		_combat_overlay.visible = false
	if _is_shortcut_mode:
		if _cm:
			_rm.record_playtest_encounter(_cm.build_playtest_report())
		_rm.finish_playtest_log("debug_finished")
		_is_shortcut_mode = false
		_is_guidance_shortcut = false
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
		_rm.run_stats.magazine_emptied_wins += _cm.battle_stats.magazine_emptied_wins
		
		# 최소 접근 거리
		if _cm.battle_stats.min_dist_allowed < _rm.run_stats.min_dist_allowed:
			_rm.run_stats.min_dist_allowed = _cm.battle_stats.min_dist_allowed
		if _cm.battle_stats.min_dist_ratio < _rm.run_stats.min_dist_ratio:
			_rm.run_stats.min_dist_ratio = _cm.battle_stats.min_dist_ratio
			
		# 완벽 실행 (빗나감과 0뎀 타격이 없고, 최소 1킬 이상 처치)
		if _cm.battle_stats.misses == 0 and _cm.battle_stats.zero_damage_hits == 0 and _cm.battle_stats.total_kills > 0:
			_rm.run_stats.perfect_battles_count += 1

		var log_error := _rm.record_playtest_encounter(_cm.build_playtest_report())
		if log_error != OK:
			push_warning("플레이테스트 전투 로그 저장 실패: %d" % log_error)

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
			if RandomStreamsScript.gameplay_float("reward") < 0.30:
				var uncollected: Array[int] = []
				for i in range(1, 21):
					if not RunManager.meta_lore_fragments.has(i):
						uncollected.append(i)
				if not uncollected.is_empty():
					fid = int(RandomStreamsScript.gameplay_pick(uncollected, "reward"))
					
		if fid > 0:
			if _rm.collect_lore_fragment(fid):
				if _combat_overlay:
					_combat_overlay.add_combat_log("[color=#00ff66]📥 [기밀 정보 복원] 우회로 또는 적 데이터 분석을 통해 기밀 파편 #%d번을 회수했습니다![/color]" % fid)

	_advance_floor_or_finish()


## 다음 층으로 진행한다. 계층의 최종층을 넘으면 다음 계층을 해금해 이어지고,
## 정점을 돌파했을 때만 런을 완주 처리한다.
##
## ⚠️ 연속 런 구조 (docs/gdd/20_ascension_intention.md §3)
##   - 한 런 = 1계층부터 정점까지 35층 연속. 계층이 바뀌어도 런은 끊기지 않는다.
##   - 덱·파츠·가방·크레딧은 계층을 넘어 그대로 누적된다(start_new_run을 다시 부르지 않음).
##   - 구역 순차 해금은 관문 돌파 기록이며 런 종료 조건이 아니다.
## ⚠️ 구역마다 층수가 다르므로 반드시 section_info를 참조할 것.
##    과거 `> 15` 하드코딩 탓에 층수가 적은 계층이 완주되지 않고 존재하지 않는 층의
##    빈 맵으로 이동해 진행이 막히는 버그가 있었다.
func _advance_floor_or_finish() -> void:
	_rm.current_floor += 1
	var max_floor: int = int(MapGenerator.section_info(_rm.current_section).floors)
	if _rm.current_floor <= max_floor:
		_show_map_screen()
		return

	# 계층 완주 — 정점이 아니라면 다음 계층을 즉시 해금하고 같은 런으로 이어간다.
	var next_section := _rm.get_next_section()
	if next_section == "":
		_show_debriefing(true)  # 정점 돌파 = 런 완주
	else:
		_rm.check_section_unlocks(true)
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
	var log_error := _rm.finish_playtest_log("won" if won else "lost")
	if log_error != OK:
		push_warning("플레이테스트 런 로그 마감 실패: %d" % log_error)
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

func _blackmarket_part_candidates() -> Array[PartData]:
	return ItemCatalogScript.general_parts(0, ItemCatalogScript.owned_part_ids(_rm))


func _blackmarket_bullet_candidates() -> Array[BulletData]:
	return ItemCatalogScript.tactical_bullets(_rm.current_gun)


func _purchase_blackmarket_part(cost: int = 30) -> bool:
	if _rm == null or _rm.backpack_items.size() >= RunManager.BACKPACK_CAPACITY:
		return false
	var candidates := _blackmarket_part_candidates()
	if candidates.is_empty() or not _rm.spend_credits(cost):
		return false
	var chosen := (RandomStreamsScript.gameplay_pick(candidates, "shop") as PartData).duplicate() as PartData
	if not _rm.add_to_backpack(chosen):
		_rm.credits += cost
		return false
	print("🕵️ 암시장 파츠 구매: %s" % chosen.display_name)
	return true


func _purchase_blackmarket_bullet(cost: int = 15) -> bool:
	if _rm == null:
		return false
	var candidates := _blackmarket_bullet_candidates()
	if candidates.is_empty() or not _rm.spend_credits(cost):
		return false
	var chosen := (RandomStreamsScript.gameplay_pick(candidates, "shop") as BulletData).duplicate() as BulletData
	_rm.add_to_deck(chosen)
	print("🕵️ 암시장 탄환 구매: %s" % chosen.display_name)
	return true


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
		if _purchase_blackmarket_part():
			popup.queue_free()
			_blackmarket_close_transition()
		else:
			desc.text = "가방 공간·크레딧·획득 가능한 파츠를 확인하십시오. 결제되지 않았습니다."
	, C_WARNING)
	btn_part.custom_minimum_size = Vector2(150, 40)
	btn_part.add_theme_font_size_override("font_size", 11)
	btn_part.disabled = _rm.credits < 30 \
		or _rm.backpack_items.size() >= RunManager.BACKPACK_CAPACITY \
		or _blackmarket_part_candidates().is_empty()
	btn_hbox.add_child(btn_part)
	
	var btn_bullet = make_button("탄환 밀수 (15 Cr)", func():
		if _purchase_blackmarket_bullet():
			popup.queue_free()
			_blackmarket_close_transition()
		else:
			desc.text = "크레딧 또는 현재 총기와 호환되는 전술탄 후보를 확인하십시오. 결제되지 않았습니다."
	, C_WARNING)
	btn_bullet.custom_minimum_size = Vector2(150, 40)
	btn_bullet.add_theme_font_size_override("font_size", 11)
	btn_bullet.disabled = _rm.credits < 15 or _blackmarket_bullet_candidates().is_empty()
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
