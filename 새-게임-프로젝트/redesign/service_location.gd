@tool
extends HBoxContainer
const Actors = preload("res://redesign/service_actor_catalog.gd")
@export_enum("workshop", "shop", "supply") var place_kind := "workshop"
@export var compact_counter := false
var decision_layout := false
var narrative_layout := false
var requested_outfit := "work"
var displayed_outfit := "work"
var outfit_fallback := false
## Shared authored place composition. Art never intercepts scrolling or clicks.
func _ready() -> void:
	resized.connect(_fit_height)
	_fit_height()

func _fit_height() -> void:
	if decision_layout:
		custom_minimum_size.y = 200 if place_kind == "shop" else 184
		return
	if compact_counter:
		custom_minimum_size.y = 168
		return
	# Preserve the entire panorama, including boots and bench, at mobile widths.
	custom_minimum_size.y = clampf((size.x - 240.0) / 3.0, 168.0, 320.0)

func configure(title: String, hint: String, outfit: String = "work") -> void:
	%PlaceTitle.text = title
	%PlaceHint.text = hint

	set_outfit(outfit)

func set_outfit(outfit: String) -> void:
	var selection := Actors.resolve(outfit, place_kind)
	requested_outfit = selection.requested
	displayed_outfit = selection.displayed
	outfit_fallback = selection.fallback
	%PlaceActor.profile = selection.profile

## Compact decision header: preserve the complete 3:1 artwork and actor registration.
## The copy gets the remaining width instead of squeezing choices below a panorama.
func use_decision_layout(text_scale: float = 1.0, narrative: bool = false) -> void:
	decision_layout = true
	narrative_layout = narrative
	add_theme_constant_override("separation", 24)
	var art: TextureRect = %PlaceArt
	art.custom_minimum_size = Vector2(600, 200) if place_kind == "shop" else Vector2(552, 184)
	art.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var copy: VBoxContainer = $Copy
	copy.custom_minimum_size.x = 320
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 10)
	%PlaceTitle.add_theme_font_size_override("font_size", roundi(28 * text_scale))
	%PlaceHint.add_theme_font_size_override("font_size", roundi(19 * text_scale))
	%PlaceActions.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_fit_height()
