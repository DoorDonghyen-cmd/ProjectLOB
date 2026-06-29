class_name DragCard extends PanelContainer

var bullet_data: BulletData
var overlay_ref

func _get_bullet_icon(bullet_name: String) -> Texture2D:
	if "armor" in bullet_name.to_lower():
		return load("res://assets/textures/bullets/armor_piercing_icon.png") as Texture2D
	elif "knockback" in bullet_name.to_lower() or "slug" in bullet_name.to_lower():
		return load("res://assets/textures/bullets/knockback_slug_icon.png") as Texture2D
	return load("res://assets/textures/bullets/basic_bullet_icon.png") as Texture2D

func initialize(b_data: BulletData, ref, count: int) -> void:
	bullet_data = b_data
	overlay_ref = ref
	custom_minimum_size = Vector2(80, 110)
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# 카드 백그라운드 스킨 지정 (각진 네온 프레임 - V10)
	var style := StyleBoxTexture.new()
	style.texture = load("res://assets/sprites/ammo_card_frame.png") as Texture2D
	add_theme_stylebox_override("panel", style)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vbox)
	
	# 탄환 스프라이트 텍스처
	var tex: Texture2D = _get_bullet_icon(bullet_data.display_name)
	if tex:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.custom_minimum_size = Vector2(40, 40)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(tr)
		
	var name_lbl := Label.new()
	name_lbl.text = bullet_data.display_name.split(" ")[0]
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 10)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_lbl)
	
	var stats_lbl := Label.new()
	if count > 1:
		stats_lbl.text = "x%d\nD:%d A:%d" % [count, bullet_data.damage, bullet_data.accuracy]
	else:
		stats_lbl.text = "D:%d A:%d" % [bullet_data.damage, bullet_data.accuracy]
	stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_lbl.add_theme_font_size_override("font_size", 9)
	stats_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	stats_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(stats_lbl)

func _get_drag_data(at_position: Vector2) -> Variant:
	# 마우스 드래그용 프리뷰 설정
	var preview := PanelContainer.new()
	preview.custom_minimum_size = custom_minimum_size
	preview.add_theme_stylebox_override("panel", get_theme_stylebox("panel"))
	preview.modulate = Color(1.0, 1.0, 1.0, 0.7)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	preview.add_child(vbox)
	
	var tex: Texture2D = _get_bullet_icon(bullet_data.display_name)
	if tex:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.custom_minimum_size = Vector2(36, 36)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		# 드래그 미리보기 이미지도 90도 회전
		tr.pivot_offset = Vector2(18, 18)
		tr.rotation_degrees = 90.0
		vbox.add_child(tr)
		
	set_drag_preview(preview)
	return bullet_data

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if overlay_ref and overlay_ref.has_method("_on_loading_add_bullet"):
			# 가방 패널에서 카드 클릭 시 바로 탄창에 추가
			overlay_ref._on_loading_add_bullet(bullet_data)
