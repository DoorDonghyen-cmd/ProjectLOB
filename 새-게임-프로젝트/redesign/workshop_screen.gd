extends VBoxContainer
## Existing two-column workshop. Scene owns placement; this script binds choices.
var host: Control

func configure(screen: Control, presenter) -> void:
	host = screen
	var campaign = host.campaign
	var ammo = presenter.Ammo
	var place := $ServiceLocation
	place.configure("정비 공방", "무료 작업 1회", str(campaign.s.get("outfit", "work")))
	place.use_decision_layout(float(host.preferences.data.get("text_scale", 1.0)))
	# This screen uses named typography roles rather than the legacy size rounding.
	for path in ["Copy/PlaceTitle", "Copy/PlaceHint"]:
		place.get_node(path).remove_theme_font_size_override("font_size")
	var can_tune: bool = host.model.s.deck.any(func(id): return not ammo.Variants.tuned(id, ammo.AMMO, "power").is_empty())
	var refit := $WorkshopOperations/Refit
	refit.visible = host.model.Reserve.inventory_enabled(host.model.s)
	_bind(refit, "city_workshop_refit", presenter.workshop_refit, campaign.workshop_ammo_options().is_empty())
	_bind($WorkshopOperations/Compress, "city_workshop_press", presenter.workshop_choices.bind("compress"), campaign.compressible_ids().is_empty())
	_bind($WorkshopOperations/Tune, "city_workshop_tune", presenter.tune_choices, not can_tune)
	$WorkshopOperations/Trim.get_node("Content/Description").text = "탄환 한 장 제거 · 최소 %d장 유지" % campaign.minimum_deck()
	_bind($WorkshopOperations/Trim, "city_workshop_trim", presenter.workshop_choices.bind("remove"), host.model.s.deck.size() <= campaign.minimum_deck())
	$WorkshopOperations/Bag.get_node("Content/Description").text = campaign.bag_growth_hint()
	_bind($WorkshopOperations/Bag, "city_workshop_bag", presenter.action.bind("resolve", "bag"), not campaign.can_grow_bag())
	var leave: Button = $PlaceFooter/city_service_skip
	_connect(leave, presenter.action.bind("resolve", "skip"))

func _bind(card: Control, key: String, callback: Callable, unavailable: bool) -> void:
	var button: Button = card.get_node("Content/Actions/Action")
	button.name = key
	button.disabled = unavailable or host.busy
	_connect(button, callback)

func _connect(button: Button, callback: Callable) -> void:
	button.pressed.connect(func(): host.feedback.play("click"))
	button.pressed.connect(callback)

