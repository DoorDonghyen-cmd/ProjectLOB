extends "res://tests/garden_background_ui_runner.gd"

func _init() -> void:
	preview_script = preload("res://redesign/central_preview.gd")
	region_index = 4
	suite = "central"
	asset_directory = "central_ascent_20261024"
	actor_renderer = "ranged_battle_view.gd"
	finish_encounter = "boss"

func district_checks() -> void:
	check(screen.campaign.node().kind == "boss", "final finish used actual boss node")
	root.size = Vector2i(1008, 630); await settle()
	await tap("city_reward_skip")
	check(screen.campaign.restoration_pending(), "final reward opens supply restoration")
	await capture("restoration_1008")
	await tap("story_restore")
	check(screen.campaign.s.restoration_done, "restore control reaches homecoming")
	await capture("homecoming_1008")
	await tap("story_results")
	check(screen.campaign.s.phase == "won" and screen.campaign.s.settled, "results finish without changing gameplay")
	await capture("results_1008")
