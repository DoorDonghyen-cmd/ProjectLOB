extends Control
## Title-only idle. A shared ground anchor keeps the generated poses planted.
func _ready() -> void:
	resized.connect(_fit)
	_fit()

func _fit() -> void:
	var factor := size.y / 560.0
	%IdleSprite.scale = Vector2.ONE * factor
	%IdleSprite.position = Vector2(size.x * (210.0 / 360.0), size.y)

func set_motion_enabled(enabled: bool) -> void:
	if enabled:
		%IdleSprite.play(&"rest")
	else:
		%IdleSprite.stop()
		%IdleSprite.set_frame_and_progress(0, 0.0)
