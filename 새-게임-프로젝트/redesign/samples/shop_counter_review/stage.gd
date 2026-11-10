@tool
extends Control

const ROOM = preload("res://assets/art/service_background_grouped_20261025/shop.png")
const TABLE_Y := 0.531
const DISPLAY_X := [0.416, 0.545, 0.674]

func _ready() -> void:
	resized.connect(place_display)
	place_display.call_deferred()

func place_display() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var artwork := ROOM.get_size()
	var factor := maxf(size.x / artwork.x, size.y / artwork.y)
	var painted := artwork * factor
	var offset := ((size - painted) * 0.5).round()
	var counter_y := roundf(offset.y + painted.y * TABLE_Y)
	for index in range(3):
		var slot: Button = get_node("Offer%d" % index)
		var x := roundf(offset.x + painted.x * DISPLAY_X[index])
		slot.position = Vector2(x - slot.size.x / 2.0, counter_y - 69.0).round()
