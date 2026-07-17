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
		
		# [Phase 4] 좀비 대기 숨쉬기/흐느적거림 무한 트윈 루프 적용
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

func _build_enemy_badge(es: TextureRect, enemy: EnemyInstance) -> void:
	var badge_panel := PanelContainer.new()
	badge_panel.name = "BadgePanel"
	badge_panel.custom_minimum_size = Vector2(24, 24)
	badge_panel.position = Vector2(28, -28)
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
	
	# 신규 방어도 배지 (자물쇠 배지 바로 옆에 배치)
	var def_panel := PanelContainer.new()
	def_panel.name = "DefPanel"
	def_panel.custom_minimum_size = Vector2(36, 24)
	def_panel.position = Vector2(56, -28) # 28 + 24 + 4 = 56
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

func update_penetration_indicators(next_bullet: BulletData) -> void:
	var total_pen: int = 0
	var has_bullet: bool = false
	if next_bullet:
		has_bullet = true
		total_pen = next_bullet.penetration
		var b_csv: Dictionary = DataLoader.get_bullet(next_bullet.resource_path.get_file().get_basename())
		if not b_csv.is_empty():
			total_pen = b_csv.penetration
			
		var current_gun = combat_manager.gun if combat_manager else null
		if current_gun:
			var g_csv: Dictionary = DataLoader.get_gun(current_gun.resource_path.get_file().get_basename())
			var pen_bonus: int = current_gun.passive_pen_bonus
			if not g_csv.is_empty():
				pen_bonus = g_csv.passive_pen_bonus
			total_pen += pen_bonus

	var c_dim = parent_scene.C_DIM if parent_scene and "C_DIM" in parent_scene else Color(0.55, 0.55, 0.65)
	var c_success = parent_scene.C_SUCCESS if parent_scene and "C_SUCCESS" in parent_scene else Color(0.30, 1.0, 0.50)
	var c_danger = parent_scene.C_DANGER if parent_scene and "C_DANGER" in parent_scene else Color(1.0, 0.30, 0.30)

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
				var can_pierce: bool = total_pen >= enemy.current_def
				if can_pierce:
					new_style.bg_color = c_success.darkened(0.4)
					new_style.border_color = c_success
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

