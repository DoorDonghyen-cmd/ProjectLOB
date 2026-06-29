class_name DragDropTube extends PanelContainer

var overlay_ref

func initialize(ref) -> void:
	overlay_ref = ref
	clip_contents = true  # Prevent vertical overflow from expanding the parent
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.3)
	style.set_border_width_all(1)
	style.border_color = Color(0.2, 0.4, 0.6, 0.5)
	add_theme_stylebox_override("panel", style)
	
func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	return data is BulletData
	
func _drop_data(at_position: Vector2, data: Variant) -> void:
	if data is BulletData:
		overlay_ref._on_loading_add_bullet(data)
