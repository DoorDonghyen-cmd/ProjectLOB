class_name EnemyTrackView
extends Control

## ═══════════════════════════════════════════════════
## 다중 적 트랙 배치 및 스케일링/위험도 표시 컴포넌트
## ═══════════════════════════════════════════════════

var parent_scene: Control
var combat_manager: CombatManager
var distance_label: Label
var top_log_toast: Label

var enemy_sprites: Dictionary = {}
var global_max_dist: float = 24.0

func initialize(p_scene: Control, cm: CombatManager, dist_lbl: Label, toast_lbl: Label) -> void:
	parent_scene = p_scene
	combat_manager = cm
	distance_label = dist_lbl
	top_log_toast = toast_lbl

func setup_encounter(enemy_list: Array) -> void:
	# 이전 몬스터 노드 정리
	for key in enemy_sprites.keys():
		var es = enemy_sprites[key]
		if is_instance_valid(es):
			es.queue_free()
	enemy_sprites.clear()
	
	# 수평 트랙 상에 적 리스트 생성 및 정렬
	for enemy in enemy_list:
		var es := TextureRect.new()
		if enemy.data and enemy.data.icon:
			es.texture = enemy.data.icon
		else:
			es.texture = load("res://assets/sprites/zombie_sheet.png")
			if es.texture:
				var atlas := AtlasTexture.new()
				atlas.atlas = es.texture
				atlas.region = Rect2(0, 0, 380, 380)
				es.texture = atlas
				
		es.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		es.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		es.layout_mode = 1
		es.custom_minimum_size = Vector2(80, 80)
		es.pivot_offset = Vector2(40, 40)
		es.mouse_filter = Control.MOUSE_FILTER_STOP
		
		add_child(es)
		enemy_sprites[enemy] = es
		
		_build_enemy_badge(es, enemy)
		
		# [Phase 4] 적 대기 숨쉬기/흐느적거림 무한 트윈 루프 적용
		(func(sprite: TextureRect):
			var delay_offset := randf() * 0.5
			# 1. 좌우 흔들림 트윈 (회전)
			var rot_tween := sprite.create_tween().set_loops()
			rot_tween.tween_property(sprite, "rotation_degrees", 2.2, 0.8 + delay_offset).set_trans(Tween.TRANS_SINE)
			rot_tween.tween_property(sprite, "rotation_degrees", -2.2, 0.8 + delay_offset).set_trans(Tween.TRANS_SINE)
			
			# 2. 상하 숨쉬기 트윈 (스케일)
			var scale_tween := sprite.create_tween().set_loops()
			scale_tween.tween_property(sprite, "scale", Vector2(0.84, 0.76), 0.7 + delay_offset).set_trans(Tween.TRANS_SINE)
			scale_tween.tween_property(sprite, "scale", Vector2(0.76, 0.84), 0.7 + delay_offset).set_trans(Tween.TRANS_SINE)
		).call(es)
		
	global_max_dist = 24.0
	var max_found := 0
	for e in enemy_list:
		if e.start_distance > max_found:
			max_found = e.start_distance
	if max_found > 0:
		global_max_dist = maxf(float(max_found) + 2.0, 24.0)
		
	update_enemy_position_and_scale()
	
	var nearest = combat_manager.enemy if combat_manager else null
	if nearest:
		update_distance_display(nearest)

func connect_enemy_gui_input(callback: Callable) -> void:
	for enemy in enemy_sprites.keys():
		var es = enemy_sprites[enemy]
		if is_instance_valid(es):
			es.gui_input.connect(func(event): callback.call(event, enemy))

## 적 표시 배치 (2026-07-25 개편):
##   - 머리 위(y ≈ -18): **HP 프로그레스 바** — 남은 체력을 한눈에
##   - 발 아래(y ≈ 84): 아키타입 배지 + 방어 + 회피 — "무엇을 뚫어야 하는가"
## HP는 즉각적 정보(얼마나 남았나)라 위, 관통 판단 정보(방어/회피)는 아래로 분리한다.
const _BADGE_ROW_Y := 84.0
const _HP_BAR_Y := -18.0
const _HP_BAR_W := 76.0
const _FOCUS_LABEL_Y := -42.0

func _build_enemy_badge(es: TextureRect, enemy: EnemyInstance) -> void:
	# ── HP 바 (머리 위) ──
	# PanelContainer는 자식 크기를 자동 재배치해 피격 시 수동 폭 갱신과 충돌한다.
	# 일반 Panel이 배경만 그리고 HpFill의 폭은 _refresh_hp_bar가 단독으로 관리한다.
	var hp_bg := Panel.new()
	hp_bg.name = "HpBarBG"
	hp_bg.custom_minimum_size = Vector2(_HP_BAR_W, 9)
	hp_bg.size = Vector2(_HP_BAR_W, 9)
	hp_bg.position = Vector2((80.0 - _HP_BAR_W) / 2.0, _HP_BAR_Y)
	hp_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	es.add_child(hp_bg)

	var hp_bg_style := StyleBoxFlat.new()
	hp_bg_style.bg_color = Color(0.06, 0.07, 0.1, 0.9)
	hp_bg_style.border_width_left = 1; hp_bg_style.border_width_right = 1
	hp_bg_style.border_width_top = 1; hp_bg_style.border_width_bottom = 1
	hp_bg_style.border_color = Color(0.2, 0.23, 0.29, 0.95)
	hp_bg_style.corner_radius_top_left = 3; hp_bg_style.corner_radius_top_right = 3
	hp_bg_style.corner_radius_bottom_left = 3; hp_bg_style.corner_radius_bottom_right = 3
	hp_bg.add_theme_stylebox_override("panel", hp_bg_style)

	# 채워지는 막대 — 앵커로 좌측에 붙이고 offset_right로 비율을 만든다.
	var hp_fill := ColorRect.new()
	hp_fill.name = "HpFill"
	hp_fill.color = parent_scene.C_SUCCESS if parent_scene and "C_SUCCESS" in parent_scene else Color(0.3, 1.0, 0.5)
	hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_fill.anchor_left = 0.0; hp_fill.anchor_top = 0.0
	hp_fill.anchor_right = 1.0; hp_fill.anchor_bottom = 1.0
	hp_fill.offset_left = 2; hp_fill.offset_top = 2
	hp_fill.offset_right = -2; hp_fill.offset_bottom = -2
	hp_bg.add_child(hp_fill)

	# HP 바 내 수치는 표기하지 않는다 — 막대 길이만으로 충분하고, 작은 숫자는 잡음이다.
	_refresh_hp_bar(es, enemy)

	# 경량탄 집중 스택. 실제 스택이 생길 때만 켜서 평상시 화면 잡음을 막는다.
	var focus_label: Label = parent_scene.make_label("", 11, Color(1.0, 0.82, 0.28))
	focus_label.name = "FocusLabel"
	focus_label.position = Vector2(5, _FOCUS_LABEL_Y)
	focus_label.size = Vector2(70, 18)
	focus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	focus_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_label.visible = false
	es.add_child(focus_label)

	# 다음 탄의 계열 보조 타격 대상 예고. 직선 관통과 산탄 확산을 색·기호로 구분한다.
	var family_hint: Label = parent_scene.make_label("", 10, Color.WHITE)
	family_hint.name = "FamilyPreviewLabel"
	family_hint.position = Vector2(5, 106)
	family_hint.size = Vector2(70, 18)
	family_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	family_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	family_hint.visible = false
	es.add_child(family_hint)

	# ── 아키타입 배지 (발 아래) ──
	var badge_panel := PanelContainer.new()
	badge_panel.name = "BadgePanel"
	badge_panel.custom_minimum_size = Vector2(24, 24)
	badge_panel.position = Vector2(8, _BADGE_ROW_Y)
	es.add_child(badge_panel)
	
	var badge_style := StyleBoxFlat.new()
	badge_style.corner_radius_top_left = 12
	badge_style.corner_radius_top_right = 12
	badge_style.corner_radius_bottom_left = 12
	badge_style.corner_radius_bottom_right = 12
	
	var txt := "?"
	var color := Color.GRAY
	match enemy.data.archetype:
		Enums.EnemyArchetype.RUSHER:
			txt = "돌"
			color = parent_scene.C_DANGER
		Enums.EnemyArchetype.TANK:
			txt = "방"
			color = parent_scene.C_ACCENT
		Enums.EnemyArchetype.DODGER:
			txt = "회"
			color = parent_scene.C_SUCCESS
		Enums.EnemyArchetype.SCRAMBLER:
			txt = "스"
			color = parent_scene.C_NEON_GOLD
		_:
			txt = "술"
			color = parent_scene.C_WARNING
			
	badge_style.bg_color = color.darkened(0.3)
	badge_style.border_width_left = 1
	badge_style.border_width_right = 1
	badge_style.border_width_top = 1
	badge_style.border_width_bottom = 1
	badge_style.border_color = color
	badge_panel.add_theme_stylebox_override("panel", badge_style)
	
	var lbl: Label = parent_scene.make_label(txt, 11, Color.WHITE)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge_panel.add_child(lbl)
	
	# 방어도 배지 (아키타입 배지 오른쪽, 발 아래 줄)
	var def_panel := PanelContainer.new()
	def_panel.name = "DefPanel"
	def_panel.custom_minimum_size = Vector2(36, 24)
	def_panel.position = Vector2(36, _BADGE_ROW_Y) # 8 + 24 + 4 = 36
	es.add_child(def_panel)
	
	var def_style := StyleBoxFlat.new()
	def_style.bg_color = Color(0.08, 0.09, 0.13, 0.85)
	def_style.border_width_left = 1; def_style.border_width_right = 1
	def_style.border_width_top = 1; def_style.border_width_bottom = 1
	def_style.border_color = Color(0.24, 0.29, 0.36, 0.9)
	def_style.corner_radius_top_left = 6; def_style.corner_radius_top_right = 6
	def_style.corner_radius_bottom_left = 6; def_style.corner_radius_bottom_right = 6
	def_panel.add_theme_stylebox_override("panel", def_style)
	
	var def_hbox := HBoxContainer.new()
	def_hbox.name = "DefHBox"
	def_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	def_hbox.add_theme_constant_override("separation", 2)
	def_panel.add_child(def_hbox)
	
	var def_icon: Label = parent_scene.make_label("🛡️", 9, Color.WHITE)
	def_hbox.add_child(def_icon)
	
	var def_lbl: Label = parent_scene.make_label(str(enemy.current_def), 10, Color.WHITE)
	def_lbl.name = "DefLabel"
	def_hbox.add_child(def_lbl)

	# 회피 배지 (방어 배지 오른쪽). 회피 0인 적은 표시하지 않아 잡음을 줄인다.
	var eva_panel := PanelContainer.new()
	eva_panel.name = "EvaPanel"
	eva_panel.custom_minimum_size = Vector2(36, 24)
	eva_panel.position = Vector2(76, _BADGE_ROW_Y) # 36 + 36 + 4 = 76
	eva_panel.visible = enemy.data.evasion > 0
	es.add_child(eva_panel)

	var eva_style := StyleBoxFlat.new()
	eva_style.bg_color = Color(0.08, 0.11, 0.09, 0.85)
	eva_style.border_width_left = 1; eva_style.border_width_right = 1
	eva_style.border_width_top = 1; eva_style.border_width_bottom = 1
	eva_style.border_color = (parent_scene.C_SUCCESS if parent_scene and "C_SUCCESS" in parent_scene else Color(0.3, 1.0, 0.5))
	eva_style.corner_radius_top_left = 6; eva_style.corner_radius_top_right = 6
	eva_style.corner_radius_bottom_left = 6; eva_style.corner_radius_bottom_right = 6
	eva_panel.add_theme_stylebox_override("panel", eva_style)

	var eva_hbox := HBoxContainer.new()
	eva_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	eva_hbox.add_theme_constant_override("separation", 2)
	eva_panel.add_child(eva_hbox)
	eva_hbox.add_child(parent_scene.make_label("💨", 9, Color.WHITE))
	eva_hbox.add_child(parent_scene.make_label(str(enemy.data.evasion), 10, Color.WHITE))

	# 타겟 지시기 (최근접 링)
	var ring_style := StyleBoxFlat.new()
	ring_style.bg_color = Color(0,0,0,0)
	ring_style.border_width_left = 2
	ring_style.border_width_right = 2
	ring_style.border_width_top = 2
	ring_style.border_width_bottom = 2
	ring_style.border_color = parent_scene.C_DANGER
	ring_style.corner_radius_top_left = 40
	ring_style.corner_radius_top_right = 40
	ring_style.corner_radius_bottom_left = 40
	ring_style.corner_radius_bottom_right = 40
	
	var ring_panel := PanelContainer.new()
	ring_panel.name = "RingPanel"
	ring_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	ring_panel.add_theme_stylebox_override("panel", ring_style)
	es.add_child(ring_panel)
	ring_panel.visible = false

## HP 바를 현재 체력에 맞춰 갱신한다.
## ⚠️ 스택 스펀지(앱소버)는 HP가 아니라 배리어 셀로 버티므로, 그 경우 배리어 비율을 그린다.
##    안 그러면 배리어가 남았는데 HP 바가 가득 차 있어 "왜 안 죽지?"가 된다.
func _refresh_hp_bar(es: TextureRect, enemy: EnemyInstance, durability_override: int = -1) -> void:
	var hp_bg = es.get_node_or_null("HpBarBG")
	if not hp_bg:
		return
	var fill = hp_bg.get_node_or_null("HpFill") as ColorRect
	if not fill:
		return

	var ratio := 0.0
	var col := Color(0.3, 1.0, 0.5)  # 초록

	if enemy.is_stack_sponge:
		var cur: int = durability_override if durability_override >= 0 else enemy.barrier_cells
		var maxc: int = maxi(enemy.max_barrier_cells, 1)
		ratio = clampf(float(cur) / float(maxc), 0.0, 1.0)
		col = Color(0.4, 0.7, 1.0)  # 배리어 = 청색
	else:
		var cur: int = durability_override if durability_override >= 0 else enemy.current_hp
		var maxh: int = maxi(enemy.max_hp, 1)
		ratio = clampf(float(cur) / float(maxh), 0.0, 1.0)
		# 체력이 낮을수록 초록 → 노랑 → 빨강
		if ratio <= 0.3:
			col = Color(1.0, 0.3, 0.3)
		elif ratio <= 0.6:
			col = Color(1.0, 0.8, 0.25)

	fill.color = col
	# 앵커 기반 폭: 오른쪽 offset을 배경 폭에 비례해 당긴다.
	var inner_w: float = _HP_BAR_W - 4.0
	fill.offset_right = -2.0 - inner_w * (1.0 - ratio)


## 동기 전투 정산과 별개로, 탄환 도착 시점의 HP/배리어 스냅샷을 화면에 반영한다.
func refresh_hp_bar_to(enemy: EnemyInstance, remaining_durability: int) -> void:
	var es = enemy_sprites.get(enemy)
	if is_instance_valid(es):
		_refresh_hp_bar(es, enemy, remaining_durability)


## 모든 적의 HP 바를 즉시 갱신한다. 피격·태세 변화 등 체력이 바뀌는 순간에 호출한다.
func refresh_all_hp_bars() -> void:
	for enemy in enemy_sprites.keys():
		var es = enemy_sprites[enemy]
		if is_instance_valid(es) and not enemy.is_dead():
			_refresh_hp_bar(es, enemy)


## 경량탄의 적별 집중 스택을 머리 위에 표시한다.
## 폭발 순간에는 3/3을 잠깐 보여 준 뒤 다음 프레임부터 0으로 숨긴다.
func update_focus(
	enemy: EnemyInstance,
	stacks: int,
	threshold: int,
	triggered: bool = false
) -> void:
	var es = enemy_sprites.get(enemy)
	if not is_instance_valid(es):
		return
	var label := es.get_node_or_null("FocusLabel") as Label
	if label == null:
		return
	label.visible = triggered or stacks > 0
	label.text = "집중 %d/%d%s" % [
		threshold if triggered else stacks,
		threshold,
		" ✦" if triggered else "",
	]
	label.add_theme_color_override(
		"font_color",
		Color(1.0, 0.94, 0.48) if triggered else Color(1.0, 0.72, 0.24)
	)
	if triggered:
		label.modulate = Color(1.45, 1.45, 1.45, 1.0)
		var tween := label.create_tween()
		tween.tween_property(label, "modulate", Color.WHITE, 0.22)
		tween.tween_interval(0.28)
		tween.tween_callback(func():
			if is_instance_valid(label):
				label.visible = false
		)


func update_enemy_position_and_scale() -> void:
	if not combat_manager:
		return
		
	var nearest = combat_manager.enemy
	
	for e in enemy_sprites.keys():
		var es = enemy_sprites[e]
		if not is_instance_valid(es) or e.is_dead():
			if is_instance_valid(es):
				es.visible = false
			continue
			
		es.visible = true
		var dist: int = e.current_distance
		var ratio: float = float(dist) / global_max_dist if global_max_dist > 0.0 else 0.0
		
		# [절대 규칙] anchor_left = 거리 / 최대거리로 수평 자유 배치
		var min_anchor := 0.16
		var anchor_ratio := min_anchor + ratio * (0.88 - min_anchor)
		
		# [Phase 4] 전진 이동 시 부드러운 트윈 및 뒤뚱거림 모션 구현
		var old_anchor = es.anchor_left
		if abs(old_anchor - anchor_ratio) > 0.001:
			# 이전 이동 트윈 중복 제거
			if es.has_meta("move_tween"):
				var old_tween = es.get_meta("move_tween")
				if old_tween and old_tween.is_valid():
					old_tween.kill()
			
			var move_tween = es.create_tween().set_parallel(true)
			move_tween.tween_property(es, "anchor_left", anchor_ratio, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			move_tween.tween_property(es, "anchor_right", anchor_ratio, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			es.set_meta("move_tween", move_tween)
			
			# 전진하는 동안 뒤뚱거림(회전 흔들림) 트윈 병행
			var side := 1.0 if randf() > 0.5 else -1.0
			var rot_tween = es.create_tween()
			rot_tween.tween_property(es, "rotation_degrees", 8.0 * side, 0.12).set_trans(Tween.TRANS_SINE)
			rot_tween.tween_property(es, "rotation_degrees", -6.0 * side, 0.12).set_trans(Tween.TRANS_SINE)
			rot_tween.tween_property(es, "rotation_degrees", 0.0, 0.11).set_trans(Tween.TRANS_SINE)
		else:
			# 즉시 반영 (첫 셋업 시 등)
			es.anchor_left = anchor_ratio
			es.anchor_right = anchor_ratio
			
		es.anchor_top = 0.75
		es.anchor_bottom = 0.75
		
		# 중심점이 앵커에 오도록 마진 오프셋 계산 (80px 크기)
		es.offset_left = -40
		es.offset_right = 40
		es.offset_top = -40
		es.offset_bottom = 40
		
		# 타겟 링 표시 갱신
		var ring = es.get_node_or_null("RingPanel")
		if ring:
			ring.visible = (e == nearest)

func update_distance_display(enemy: EnemyInstance) -> void:
	if not enemy or enemy.is_dead():
		distance_label.text = "- m"
		return
		
	var dist := enemy.current_distance
	distance_label.text = "%d m" % dist
	
	# 생사선 위험 연출 분기
	if dist <= 3:
		distance_label.add_theme_color_override("font_color", parent_scene.C_DANGER)
		top_log_toast.text = "⚠ 즉사 위험! 다음 턴 진입 시 사망합니다!"
		top_log_toast.add_theme_color_override("font_color", parent_scene.C_DANGER)
	elif dist <= 6:
		distance_label.add_theme_color_override("font_color", parent_scene.C_WARNING)
		top_log_toast.text = "상황 대기 중"
		top_log_toast.add_theme_color_override("font_color", parent_scene.C_SUCCESS)
	else:
		distance_label.add_theme_color_override("font_color", parent_scene.C_DIST_SAFE)
		top_log_toast.text = "상황 대기 중"
		top_log_toast.add_theme_color_override("font_color", parent_scene.C_SUCCESS)

## 다음 탄이 각 적의 **두 게이트(명중·관통)**를 넘는지 배지 색으로 표시한다.
## ⚠️ 유효 스탯은 CombatManager.preview_next_shot()가 정본 — 버프까지 반영된 값이다.
##    여기서 다시 계산하지 않는다(중복 계산은 반드시 어긋난다).
func update_penetration_indicators(_next_bullet: BulletData) -> void:
	var preview: Dictionary = combat_manager.preview_next_shot() if combat_manager else {}
	var has_bullet: bool = not preview.is_empty()
	var total_pen: int = int(preview.get("pen", 0))
	var total_acc: int = int(preview.get("acc", 0))
	var line_targets: Array = preview.get("line_targets", [])
	var scatter_targets: Array = preview.get("scatter_targets", [])

	var c_dim = parent_scene.C_DIM if parent_scene and "C_DIM" in parent_scene else Color(0.55, 0.55, 0.65)
	var c_success = parent_scene.C_SUCCESS if parent_scene and "C_SUCCESS" in parent_scene else Color(0.30, 1.0, 0.50)
	var c_danger = parent_scene.C_DANGER if parent_scene and "C_DANGER" in parent_scene else Color(1.0, 0.30, 0.30)
	var c_critical := Color(1.0, 0.78, 0.25)

	for enemy in enemy_sprites.keys():
		var es = enemy_sprites[enemy]
		if not is_instance_valid(es) or enemy.is_dead():
			continue
			
		var badge_panel = es.get_node_or_null("BadgePanel")
		if badge_panel:
			var new_style := StyleBoxFlat.new()
			new_style.corner_radius_top_left = 12
			new_style.corner_radius_top_right = 12
			new_style.corner_radius_bottom_left = 12
			new_style.corner_radius_bottom_right = 12
			new_style.border_width_left = 1
			new_style.border_width_right = 1
			new_style.border_width_top = 1
			new_style.border_width_bottom = 1
			
			if not has_bullet:
				new_style.bg_color = c_dim.darkened(0.4)
				new_style.border_color = c_dim
			else:
				# 명중과 관통 **둘 다** 넘어야 실제로 맞는다. 하나라도 막히면 빨강.
				var clears: bool = total_acc >= enemy.current_evasion and total_pen >= enemy.current_def
				if clears:
					var clear_color: Color = c_critical if bool(preview.get("critical", false)) else c_success
					new_style.bg_color = clear_color.darkened(0.4)
					new_style.border_color = clear_color
				else:
					new_style.bg_color = c_danger.darkened(0.4)
					new_style.border_color = c_danger
			badge_panel.add_theme_stylebox_override("panel", new_style)
			
		# 실시간 방어력 수치 갱신
		var def_panel = es.get_node_or_null("DefPanel")
		if def_panel:
			var def_lbl = def_panel.get_node_or_null("DefHBox/DefLabel") as Label
			if def_lbl:
				def_lbl.text = str(enemy.current_def)

		var family_hint := es.get_node_or_null("FamilyPreviewLabel") as Label
		if family_hint:
			family_hint.visible = false
			if enemy in line_targets:
				family_hint.text = "➜ 관통"
				family_hint.add_theme_color_override("font_color", Color(0.35, 0.86, 1.0))
				family_hint.visible = true
			elif enemy in scatter_targets:
				family_hint.text = "◁ 확산"
				family_hint.add_theme_color_override("font_color", Color(1.0, 0.58, 0.22))
				family_hint.visible = true

		# HP 바 갱신
		_refresh_hp_bar(es, enemy)
