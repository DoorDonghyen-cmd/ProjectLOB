extends VBoxContainer

const COMPACT_WIDTH := 900.0
var preferred_battle_height := 0.0
var bottom_margin := 10.0

@onready var tactical_grid: GridContainer = %TacticalGrid
@onready var ammo_grid: GridContainer = %AmmoGrid

func _ready() -> void:
	for preview in find_children("EditorPreview*", "Control", true, false):
		preview.get_parent().remove_child(preview)
		preview.queue_free()
	get_viewport().size_changed.connect(_fit_to_viewport)
	resized.connect(_fit_battle_height.call_deferred)
	resized.connect(queue_redraw)
	sort_children.connect(queue_redraw)
	tactical_grid.sort_children.connect(queue_redraw)
	_fit_to_viewport()

func _draw() -> void:
	if not is_instance_valid(tactical_grid): return
	# One painted-steel deck joins the instruments and the ammunition tray.
	# Open sides and quiet seams avoid another box around every label.
	var deck := Rect2(tactical_grid.position.round(), tactical_grid.size.floor())
	if deck.size.y <= 0: return
	draw_rect(deck, Color("15242a"))
	draw_rect(Rect2(deck.position, Vector2(deck.size.x, 2)), Color("536660"))
	draw_rect(Rect2(deck.position + Vector2(0,2), Vector2(deck.size.x,2)), Color("253a3e"))
	var thermal := get_node_or_null("TacticalGrid/QueuePanel/QueueColumn/ThermalOutcome") as Control
	if thermal != null:
		# Heat and the available rounds share a lower tray; the quiet seam sits
		# above the instrument rather than breaking it away from the hand.
		var top := floorf(thermal.global_position.y - global_position.y) - 4.0
		draw_rect(Rect2(0,top,size.x,deck.end.y-top), Color("18292e"))
		draw_rect(Rect2(12,top,size.x-24,1), Color("394e4e"))
		draw_rect(Rect2(12,top+1,size.x-24,1), Color("102127"))
	draw_rect(Rect2(0,deck.end.y-2,size.x,2), Color("3d514e"))
	for x in [12.0,size.x-32]:
		draw_rect(Rect2(x,deck.position.y,20,2),Color("9b9c7e"))

func _fit_to_viewport() -> void:
	if not is_inside_tree(): return
	tactical_grid.columns = 1
	ammo_grid.columns = 10
	_fit_battle_height.call_deferred()

func _fit_battle_height() -> void:
	if preferred_battle_height <= 0.0 or not is_inside_tree(): return
	var stage := get_node_or_null("BattleHost/BattleView") as Control
	if stage == null: return
	# Fit to the reserved control footprint, independent of loaded/confirmed state.
	# Contextual content is hidden inside stable rows rather than changing their height.
	var other_height := get_combined_minimum_size().y - stage.get_combined_minimum_size().y
	var available := get_viewport_rect().size.y - global_position.y - other_height - bottom_margin
	# Give recovered space to the stage, including taller windows. Actor scale
	# uses character_reference_height and stays independent from this budget.
	var height := floorf(maxf(available, 210.0))
	if not is_equal_approx(stage.custom_minimum_size.y, height):
		stage.custom_minimum_size.y = height

func arrange_combat() -> void:
	# A single reading path: battlefield -> firing rail -> available rounds.
	# The primary layout is authored in the scene; bind only adaptive sizing here.
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
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Wrapped button labels otherwise report a near-zero minimum width and
	# grow vertically when they share a header with an expanding label.
	for button in edits.get_children():
		if button is Button:
			button.custom_minimum_size.x = maxf(100, button.custom_minimum_size.x)
			button.size_flags_horizontal = Control.SIZE_FILL
	var rail := column.get_node("FiringRail") as HBoxContainer
	magazine.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.custom_minimum_size.x = 220
	actions.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	result.custom_minimum_size.y = 26
	# Keep the editing/ready rail footprint stable while button contents change.
	rail.custom_minimum_size.y = 82
	actions.add_theme_constant_override("separation", 4)
	if hand_controls.get_parent() != hand_header: hand_controls.reparent(hand_header)
	hand_header.custom_minimum_size.y = 44
	hand_controls.size_flags_horizontal = Control.SIZE_SHRINK_END
	compress.size_flags_horizontal = Control.SIZE_SHRINK_END
	compress.visible = compress.get_child_count() > 0
	prompt.hide()
	_fit_to_viewport()
