extends VBoxContainer
signal tab_changed
var current_tab := "parts"

func _ready() -> void:
	resized.connect(_fit)
	%PartsTab.pressed.connect(show_tab.bind("parts"))
	%AmmoTab.pressed.connect(show_tab.bind("ammo"))
	show_tab("parts")
	_fit.call_deferred()

func _fit() -> void:
	%PartsWorkspace.vertical = size.x < 1180
	%PartInspector.custom_minimum_size.x = 0 if %PartsWorkspace.vertical else 390
	%EquippedPartGrid.columns = 5 if size.x >= 820 else 3
	%DeckGrid.columns = maxi(1,mini(3,int((size.x-24)/260)))

func show_tab(tab: String) -> void:
	current_tab = "ammo" if tab == "ammo" else "parts"
	%PartsWorkspace.visible = current_tab == "parts"
	%DeckPanel.visible = current_tab == "ammo"
	%PartsTab.button_pressed = current_tab == "parts"
	%AmmoTab.button_pressed = current_tab == "ammo"
	tab_changed.emit()
