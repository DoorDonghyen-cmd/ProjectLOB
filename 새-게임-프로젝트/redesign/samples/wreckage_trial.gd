extends SceneTree

const Trial = preload("res://redesign/samples/wreckage_trial_data.gd")

func _initialize() -> void:
	open_trial.call_deferred()

func open_trial() -> void:
	var save_path := ProjectSettings.globalize_path("user://").replace("\\", "/")
	if not save_path.contains("/qa_runtime/wreckage_trial/"):
		push_error("The wreckage trial needs its isolated launcher")
		quit(2)
		return
	var campaign := Trial.make()
	if campaign == null:
		push_error("Could not enter the foundry trial")
		quit(2)
		return
	var screen: Control = load("res://redesign/main.tscn").instantiate()
	screen.save_enabled = false
	root.add_child(screen)
	screen.campaign = campaign
	screen.model = campaign.model
	screen.page = "run"
	screen.redraw()
	DisplayServer.window_set_title("ORVASK · 금형공 잔해 시험")
