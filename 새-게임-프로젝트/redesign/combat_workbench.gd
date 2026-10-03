extends VBoxContainer

const COMPACT_WIDTH := 900.0

@onready var tactical_grid: GridContainer = %TacticalGrid
@onready var ammo_grid: GridContainer = %AmmoGrid

func _ready() -> void:
	get_viewport().size_changed.connect(_fit_to_viewport)
	_fit_to_viewport()

func _fit_to_viewport() -> void:
	if not is_inside_tree(): return
	var compact := get_tree().root.size.x < COMPACT_WIDTH
	tactical_grid.columns = 1
	ammo_grid.columns = 3 if compact else 6

func arrange_combat() -> void:
	# A single reading path: battlefield -> firing rail -> available rounds.
	# Resolve scene-owned nodes before reparenting them within this scene.
	var queue: PanelContainer = %QueuePanel
	var candidates: PanelContainer = %CandidatesPanel
	var column := queue.get_node("QueueColumn") as VBoxContainer
	var heading: Label = %QueueHeading
	var edits: HBoxContainer = %EditActions
	var magazine: VBoxContainer = %MagazineHost
	var actions: VBoxContainer = %CombatActions
	var result: Label = %ForecastLabel
	var prompt: Label = %DecisionPrompt
	var hand_controls: HBoxContainer = %HandControls
	var compress: HBoxContainer = %CompressionActions
	var hand_header := candidates.get_node("CandidatesColumn/HandHeader") as HBoxContainer
	%CombatSteps.hide()
	tactical_grid.move_child(queue, 0)
	queue.size_flags_vertical = Control.SIZE_FILL
	candidates.size_flags_vertical = Control.SIZE_FILL
	tactical_grid.size_flags_vertical = Control.SIZE_FILL
	column.add_theme_constant_override("separation", 4)
	var rail_header := HBoxContainer.new()
	rail_header.name = "FiringRailHeader"
	column.add_child(rail_header)
	column.move_child(rail_header, 0)
	heading.reparent(rail_header)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edits.reparent(rail_header)
	# Wrapped button labels otherwise report a near-zero minimum width and
	# grow vertically when they share a header with an expanding label.
	for button in edits.get_children():
		if button is Button:
			button.custom_minimum_size.x = maxf(100, button.custom_minimum_size.x)
			button.size_flags_horizontal = Control.SIZE_FILL
	var rail := HBoxContainer.new()
	rail.name = "FiringRail"
	rail.add_theme_constant_override("separation", 12)
	column.add_child(rail)
	column.move_child(rail, 1)
	magazine.reparent(rail)
	magazine.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.reparent(rail)
	actions.custom_minimum_size.x = 220
	actions.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	result.custom_minimum_size.y = 26
	# Keep the editing/ready rail footprint stable while button contents change.
	rail.custom_minimum_size.y = 92
	actions.add_theme_constant_override("separation", 4)
	if hand_controls.get_parent() != hand_header: hand_controls.reparent(hand_header)
	hand_controls.size_flags_horizontal = Control.SIZE_SHRINK_END
	compress.reparent(hand_header)
	compress.size_flags_horizontal = Control.SIZE_SHRINK_END
	compress.visible = compress.get_child_count() > 0
	prompt.hide()
	_fit_to_viewport()
