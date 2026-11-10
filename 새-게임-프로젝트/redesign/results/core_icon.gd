@tool
extends Control

const Icon = preload("res://redesign/part_icon_art.gd")
var part_id := "inferno"

func _draw() -> void:
	Icon.draw(self, part_id, (size * 0.5).round(), Color("dfb087"), 2.0)

