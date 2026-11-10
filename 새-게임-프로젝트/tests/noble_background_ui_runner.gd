extends "res://tests/garden_background_ui_runner.gd"

func _init() -> void:
	preview_script = preload("res://redesign/noble_preview.gd")
	region_index = 3
	suite = "noble"
	asset_directory = "noble_ascent_20261024"
	actor_renderer = "noble_battle_view.gd"
	finish_encounter = "boss"
