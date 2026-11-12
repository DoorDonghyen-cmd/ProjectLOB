extends SceneTree

const Trial = preload("res://redesign/samples/elite_shield_trial_data.gd")

func _initialize() -> void:
	open_trial.call_deferred()

func open_trial() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/elite_shield_trial/"):
		push_error("The elite shield trial needs its isolated launcher")
		quit(2)
		return
	var variant := OS.get_environment("QA_SHIELD_VARIANT")
	var campaign := Trial.make(Trial.House.PIERCE_ONLY if variant == "strict" else Trial.House.PIERCE_WEAK)
	if campaign == null:
		push_error("Could not enter the elite shield trial")
		quit(2)
		return
	var screen: Control = load("res://redesign/main.tscn").instantiate()
	screen.save_enabled = false
	root.add_child(screen)
	screen.campaign = campaign
	screen.model = campaign.model
	screen.page = "run"
	screen.redraw()
	DisplayServer.window_set_title("ORVASK · 수석 시종 차폐 시험")
