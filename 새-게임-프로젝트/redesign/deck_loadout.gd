extends VBoxContainer
signal tab_changed
var current_tab := "parts"

func _ready() -> void:
	%PartsTab.pressed.connect(show_tab.bind("parts"))
	%AmmoTab.pressed.connect(show_tab.bind("ammo"))
	show_tab("parts")

func show_tab(tab: String) -> void:
	current_tab = "ammo" if tab == "ammo" else "parts"
	%PartsWorkspace.visible = current_tab == "parts"
	%DeckPanel.visible = current_tab == "ammo"
	%PartsTab.button_pressed = current_tab == "parts"
	%AmmoTab.button_pressed = current_tab == "ammo"
	tab_changed.emit()
