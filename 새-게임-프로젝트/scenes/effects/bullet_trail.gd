extends Line2D

func _ready() -> void:
	var tween: Tween = create_tween()
	# 빛나는 선명한 색상에서 빠르게 투명하게 사라짐
	tween.tween_property(self, "default_color:a", 0.0, 0.12)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)
	tween.tween_callback(queue_free)
