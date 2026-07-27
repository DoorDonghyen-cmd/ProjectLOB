class_name CylinderView
extends VBoxContainer

const BulletRoleUI = preload("res://scripts/ui/bullet_role_ui.gd")

## ═══════════════════════════════════════════════════
## 약실 내 탄환들의 순서(LIFO) 및 실린더 UI 시각화 컴포넌트
## ═══════════════════════════════════════════════════

var parent_scene: Control
var combat_manager: CombatManager

## 연출 재생 중 표시할 잔탄 스냅샷. 비어 있으면 실제 탄창을 그대로 읽는다.
## 연발은 탄창이 한 번에 비므로, 한 발씩 나가는 모습을 보여주려면
## 실제 상태가 아니라 **재생 진행도**를 그려야 한다.
var display_override: Array[BulletData] = []

func initialize(p_scene: Control, cm: CombatManager) -> void:
	parent_scene = p_scene
	combat_manager = cm

func update_cylinder_visuals() -> void:
	# 1. 기존 동적 노드들 클리어
	for child in get_children():
		remove_child(child)
		child.queue_free()
		
	var bullets: Array[BulletData] = []
	if not display_override.is_empty():
		bullets = display_override
	elif combat_manager:
		bullets = combat_manager.magazine.get_loaded_bullets()
		
	if bullets.size() == 0:
		var empty_panel := _create_empty_bullet_card("약실 비어있음")
		add_child(empty_panel)
		return
		
	# 2. 장전된 탄환을 역순(LIFO: 가장 마지막에 넣은 탄환이 최상단)으로 빌드
	var display_count := 0
	for i in range(bullets.size() - 1, -1, -1):
		var bullet: BulletData = bullets[i]
		var is_next: bool = (display_count == 0)
		var is_hidden: bool = (display_count >= 2)
		var has_visible_chain := (
			display_count == 0
			and i > 0
			and BulletRoleUI.is_link_chain(bullet, bullets[i - 1])
		)
		
		# 카드 번호는 격발될 순서(1, 2, 3...)로 표기
		var bullet_card := _create_dynamic_bullet_card(
			bullet, display_count + 1, is_next, is_hidden, has_visible_chain)
		add_child(bullet_card)
		display_count += 1
		
	# [Phase 4] 피드백을 위한 실린더 전체 스케일/회전 탄력 바운싱 연출
	pivot_offset = Vector2(size.x / 2.0, size.y / 2.0)
	
	# 크기 탄력 바운싱 트윈
	var scale_tween := create_tween()
	scale_tween.tween_property(self, "scale", Vector2(1.12, 1.12), 0.07).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	scale_tween.tween_property(self, "scale", Vector2(0.96, 0.96), 0.08).set_trans(Tween.TRANS_CUBIC)
	scale_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.18).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	# 실린더 장탄 느낌의 시계 반대 방향 회전 바운싱 트윈
	var rot_tween := create_tween()
	rot_tween.tween_property(self, "rotation_degrees", -15.0, 0.07).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	rot_tween.tween_property(self, "rotation_degrees", 4.0, 0.08).set_trans(Tween.TRANS_CUBIC)
	rot_tween.tween_property(self, "rotation_degrees", 0.0, 0.18).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _create_dynamic_bullet_card(
	bullet: BulletData,
	index: int,
	is_next: bool,
	is_hidden: bool = false,
	has_visible_chain: bool = false
) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 32)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not is_hidden:
		card.tooltip_text = "%s\n%s" % [BulletRoleUI.hint(bullet.role), bullet.description]
	
	var style := StyleBoxFlat.new()
	if is_next:
		style.bg_color = Color(0.12, 0.22, 0.18, 0.9) # 강조 배경 (성공 색조)
		style.border_width_left = 2; style.border_width_right = 2
		style.border_width_top = 2; style.border_width_bottom = 2
		style.border_color = parent_scene.C_SUCCESS
	else:
		style.bg_color = Color(0.06, 0.08, 0.12, 0.75) # 기본 어두운 배경
		style.border_width_left = 1; style.border_width_right = 1
		style.border_width_top = 1; style.border_width_bottom = 1
		style.border_color = Color(0.13, 0.18, 0.24)
	style.corner_radius_top_left = 4; style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4; style.corner_radius_bottom_right = 4
	card.add_theme_stylebox_override("panel", style)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	card.add_child(margin)
	
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	margin.add_child(hbox)
	
	# 인덱스 또는 NEXT 표시
	var index_lbl: Label
	if is_next:
		index_lbl = parent_scene.make_label("▶", 10.5, parent_scene.C_SUCCESS)
	else:
		index_lbl = parent_scene.make_label(str(index), 10.5, parent_scene.C_DIM)
	hbox.add_child(index_lbl)
	
	# 총알 아이콘 추가 (은폐가 아닐 때에만 렌더링)
	if not is_hidden:
		var icon_tex := _get_bullet_icon(bullet)
		if icon_tex:
			var icon_rect := TextureRect.new()
			icon_rect.texture = icon_tex
			icon_rect.custom_minimum_size = Vector2(18, 18) # 콤팩트 크기
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			icon_rect.modulate = Color(1, 1, 1, 0.9)
			hbox.add_child(icon_rect)
			
	# 탄환 종류 및 구경 표시 (is_hidden 시 은폐)
	var display_name := bullet.display_name
	var name_color := Color.WHITE
	if is_hidden:
		display_name = "???"
		name_color = parent_scene.C_DIM
		
	var name_lbl: Label = parent_scene.make_label(display_name, 11, name_color)
	name_lbl.name = "BulletName"
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# ⚠️ 클립하지 않으면 라벨의 최소 폭 = 전체 텍스트 폭이 되어, 긴 탄 이름
	#    ("12게이지 밀집탄" 등)이 카드를 가로로 밀어내고 실린더 전체가 늘어난다.
	#    클립하면 카드는 컨테이너 폭을 채우되 넘치지 않고, 긴 이름은 …으로 잘린다.
	name_lbl.clip_text = true
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_lbl.custom_minimum_size = Vector2(40, 0)
	name_lbl.tooltip_text = display_name  # 잘려도 전체 이름은 툴팁으로
	hbox.add_child(name_lbl)

	var has_gate := false
	if not is_hidden:
		var role_lbl: Label = parent_scene.make_label(
			BulletRoleUI.badge_text(bullet.role), 9.0, BulletRoleUI.color(bullet.role))
		hbox.add_child(role_lbl)

		# 버프탄은 **어떤 게이트를 여는지** 명시한다 (정본: 22_ammo_expansion §22.0-B 결정 #3).
		# "연계"만으로는 무엇이 강화되는지 안 보인다 — 명중/관통을 직접 표기한다.
		var gate := ""
		match bullet.effect_type:
			Enums.BulletEffect.BUFF_ACC: gate = "⬇명중"
			Enums.BulletEffect.BUFF_PEN: gate = "⬇관통"
			Enums.BulletEffect.DEBUFF_EVA: gate = "⬇회피"
			Enums.BulletEffect.ARMOR_SHRED: gate = "⬇방어"
			Enums.BulletEffect.BUFF_MAG_ACC: gate = "⇢명중"
			Enums.BulletEffect.BUFF_MAG_PEN: gate = "⇢관통"
		if gate != "":
			has_gate = true
			var gate_lbl: Label = parent_scene.make_label(gate, 9.0, Color(0.78, 0.59, 1.0))
			gate_lbl.tooltip_text = bullet.description
			hbox.add_child(gate_lbl)
		elif has_visible_chain:
			var chain_lbl: Label = parent_scene.make_label("⇢ 연계", 9.0, parent_scene.C_SUCCESS)
			chain_lbl.tooltip_text = "현재 연계탄 다음에 공격탄이 발사됩니다."
			hbox.add_child(chain_lbl)

	# 성능 숫자(D/P). 버프탄은 게이트 라벨이 핵심 정보이고 화력탄이 아니므로 생략한다
	# (좁은 실린더 폭에 칩이 넘쳐 UI가 가로로 늘어나는 것을 막는다. 전체 스탯은 툴팁에 있음).
	if not has_gate:
		var stat_str := "D%d P%d" % [bullet.damage, bullet.penetration]
		if is_hidden:
			stat_str = "D? P?"
		var stat_lbl: Label = parent_scene.make_label(stat_str, 9.5, parent_scene.C_DIM)
		hbox.add_child(stat_lbl)

	return card

func _create_empty_bullet_card(text: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 32)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.08, 0.4)
	style.border_width_left = 1; style.border_width_right = 1
	style.border_width_top = 1; style.border_width_bottom = 1
	style.border_color = Color(0.18, 0.18, 0.18)
	style.corner_radius_top_left = 4; style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4; style.corner_radius_bottom_right = 4
	card.add_theme_stylebox_override("panel", style)
	
	var lbl: Label = parent_scene.make_label(text, 11.5, parent_scene.C_DIM)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card.add_child(lbl)
	
	return card

func _get_bullet_icon(bullet: BulletData) -> Texture2D:
	if not bullet: return null
	if bullet.icon: return bullet.icon
	
	var r_path = bullet.resource_path.get_file().get_basename().to_lower()
	var img_path := "res://assets/textures/bullets/basic_bullet_icon.png"
	
	if "ap" in r_path or "piercing" in r_path:
		img_path = "res://assets/textures/bullets/armor_piercing_icon.png"
	elif "slug" in r_path or "heavy" in r_path:
		img_path = "res://assets/textures/bullets/knockback_slug_icon.png"
	elif "tactical" in r_path or "shot" in r_path or "strike" in r_path or "critical" in r_path or "rhythm" in r_path:
		img_path = "res://assets/textures/bullets/tactical_bullet_icon.png"
		
	if ResourceLoader.exists(img_path):
		return load(img_path) as Texture2D
	return null
