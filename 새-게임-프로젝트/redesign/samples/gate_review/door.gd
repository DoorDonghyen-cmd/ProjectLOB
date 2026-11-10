@tool
extends Control

const Actor = preload("res://redesign/weapon_actor.gd")

@export var backdrop: Texture2D
@export var threshold := Rect2(0.29, 0.25, 0.42, 0.48)
@export var operator_visible := false
@export var operator_position := Vector2(0.49, 0.79)
@export var work_profile: Resource
@export var station_indicator := Vector2.ZERO
var operator_texture: Texture2D
var operator_at_work := false
var station_power := 0.0:
	set(value):
		station_power = value
		queue_redraw()
var release_ready := false
var travel := 0.0:
	set(value):
		travel = value
		queue_redraw()

func _ready() -> void:
	resized.connect(queue_redraw)
	if operator_visible:
		operator_texture = Actor.portrait("carrier")

func image_bounds() -> Rect2:
	if backdrop == null or size.x <= 0.0 or size.y <= 0.0:
		return Rect2()
	var source := backdrop.get_size()
	var factor := maxf(size.x / source.x, size.y / source.y)
	var extent := (source * factor).round()
	var origin := ((size - extent) * 0.5).floor()
	if operator_visible:
		origin.y = roundf(clampf(size.y - 116.0 - operator_position.y * extent.y, minf(0.0, size.y - extent.y), 0.0))
	return Rect2(origin, extent)

func door_opening() -> Rect2:
	var bounds := image_bounds()
	return Rect2((bounds.position + threshold.position * bounds.size).round(), (threshold.size * bounds.size).round())

func _draw() -> void:
	var bounds := image_bounds()
	if not bounds.has_area():
		return
	draw_texture_rect(backdrop, bounds, false)
	var opening := door_opening()
	var half := floorf(opening.size.x * 0.5)
	var slide := floorf(travel * half)
	draw_leaf(opening, opening.position.x - slide, half)
	draw_leaf(opening, opening.position.x + half + slide, opening.size.x - half)
	if travel < 0.02:
		var mid := opening.position.x + half
		var latch := Rect2(mid - 16, opening.get_center().y - 12, 32, 24)
		draw_rect(latch, Color("20201d"))
		draw_rect(latch.grow(-4), Color("6e5f43"))
		draw_rect(Rect2(mid - 3, latch.position.y + 9, 6, 6), Color("f0b867") if release_ready else Color("9b603c"))
	if operator_visible:
		if station_indicator != Vector2.ZERO:
			var lamp := (bounds.position + station_indicator * bounds.size).round()
			draw_rect(Rect2(lamp - Vector2(5, 5), Vector2(10, 10)), Color("8a572d").lerp(Color("ffb951"), station_power))
			draw_rect(Rect2(lamp - Vector2(3, 3), Vector2(6, 6)), Color("3b3023").lerp(Color("ffe6a2"), station_power))
		var spot := operator_position
		if operator_at_work:
			spot.x = lerpf(operator_position.x, 0.60, clampf((size.x - 990.0) / 290.0, 0.0, 1.0))
		draw_operator((bounds.position + spot * bounds.size).round())
		return
	for row in range(12):
		var falloff := 1.0 - float(row) / 12.0
		draw_rect(Rect2(0, row * 10, size.x, 10), Color(0.045, 0.04, 0.035, 0.52 * falloff))
		draw_rect(Rect2(0, size.y - (row + 1) * 11, size.x, 11), Color(0.045, 0.04, 0.035, 0.94 * falloff))

func draw_operator(foot: Vector2) -> void:
	if operator_texture == null:
		return
	if operator_at_work and work_profile != null:
		var source: Rect2 = work_profile.source_rect
		var height := clampf(size.y * 0.35, 100.0, 256.0)
		var figure := (source.size * (height / source.size.y)).round()
		var origin: Vector2 = (foot - figure * work_profile.foot_in_source).round()
		draw_operator_shadow(foot, figure.x)
		draw_texture_rect_region(work_profile.texture, Rect2(origin, figure), source, Color("d5b796"))
		return
	var height := clampf(size.y * 0.28, 96.0, 194.0)
	var figure := (operator_texture.get_size() * (height / operator_texture.get_height())).round()
	draw_operator_shadow(foot, figure.x)
	var origin := (foot - Vector2(figure.x * 0.5, figure.y)).round()
	draw_texture_rect(operator_texture, Rect2(origin, figure), false, Color("d5b796"))

func draw_operator_shadow(foot: Vector2, width: float) -> void:
	draw_set_transform(foot, 0.0, Vector2(1.0, 0.15))
	draw_circle(Vector2.ZERO, width * 0.43, Color(0.05, 0.035, 0.025, 0.65))
	draw_set_transform(Vector2.ZERO)

func draw_leaf(opening: Rect2, x: float, width: float) -> void:
	var y := opening.position.y
	var h := opening.size.y
	draw_clipped(Rect2(x, y, width, h), opening, Color("24211d"))
	draw_clipped(Rect2(x + 4, y + 5, width - 8, h - 10), opening, Color("514333"))
	draw_clipped(Rect2(x + 8, y + 12, width - 17, h - 24), opening, Color("39312a"))
	for column in [0.22, 0.76]:
		var rib := floorf(x + width * column)
		draw_clipped(Rect2(rib, y + 12, 12, h - 24), opening, Color("332d26"))
		draw_clipped(Rect2(rib, y + 12, 3, h - 24), opening, Color("584839"))
	for step in [0.23, 0.55, 0.80]:
		var row := floorf(y + h * step)
		draw_clipped(Rect2(x + 5, row, width - 10, 3), opening, Color("6c5137"))
		draw_clipped(Rect2(x + 5, row + 3, width - 10, 8), opening, Color("47372a"))
		draw_clipped(Rect2(x + 5, row + 11, width - 10, 4), opening, Color("2b241e"))
		for column in [0.12, 0.50, 0.88]:
			var bolt := floorf(x + width * column)
			draw_clipped(Rect2(bolt, row + 5, 5, 4), opening, Color("a4774d"))
	draw_clipped(Rect2(x + 8, y + h - 24, width - 17, 5), opening, Color("7d5635"))
	draw_clipped(Rect2(x + width - 3, y, 3, h), opening, Color("201f1b"))

func draw_clipped(area: Rect2, aperture: Rect2, ink: Color) -> void:
	var visible_area := area.intersection(aperture)
	if visible_area.has_area():
		draw_rect(visible_area, ink)
