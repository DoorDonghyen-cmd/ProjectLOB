@tool
extends HBoxContainer
## Keep the previous five-card width while the authored row gains more choices.
## The ScrollContainer owns touch scrolling/focus; the launch footer stays fixed.
@export_range(1,8) var visible_cards := 5
func _ready() -> void:
	get_parent().resized.connect(_fit_cards)
	_fit_cards.call_deferred()
func _fit_cards() -> void:
	var viewport_width: float=get_parent().size.x
	if viewport_width<=0: return
	var width:=floorf((viewport_width-get_theme_constant("separation")*(visible_cards-1))/visible_cards)
	for child in get_children():
		if child is Button: child.custom_minimum_size=Vector2(maxf(120,width),92)
