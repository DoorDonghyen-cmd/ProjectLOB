extends Control
## Authored equipment room. Selection changes bindings without rebuilding the page.
const Content = preload("res://redesign/content.gd")
const CampaignContent = preload("res://redesign/campaign_content.gd")
const PixelSkin = preload("res://redesign/combat_pixel_skin.gd")
const OutfitArt = preload("res://redesign/outfit_art.gd")
const OUTFIT_REGIONS := {"work": Rect2(76, 77, 378, 854), "carrier": Rect2(573, 77, 387, 854), "scout": Rect2(1092, 77, 368, 854)}
const OUTFIT_IMAGE = preload("res://assets/art/equipment_20261011/outfits_v1.png")
@onready var launch: Button = %Launch
var host: Control
var profile: Dictionary

func _ready() -> void:
	%Stage.resized.connect(_fit_art)
	_fit_art.call_deferred()

func _fit_art() -> void:
	# Keep boots on the workshop floor at both short and tall aspect ratios.
	%Backdrop.offset_bottom = (%Stage.get_global_rect().end.y - global_position.y - 16.0) / 0.70

func bind_screen(owner_screen: Control, run_profile: Dictionary) -> void:
	host = owner_screen
	profile = run_profile
	%Heading.text = "훈련 장비" if host.preparation_training else "등반 장비"
	%loadout_back.pressed.connect(host._to_menu)
	%preparation_options.pressed.connect(_options)
	%starting_deck.pressed.connect(_deck_details)
	%weapon_info.pressed.connect(func(): host._weapon_details(host.selected_weapon_id))
	launch.pressed.connect(func(): host._request_start(host.selected_weapon_id, false))
	for id in Content.GUNS:
		var button := find_child("weapon_select_" + id, true, false) as Button
		button.get_node("Name").text = Content.GUNS[id].name
		button.pressed.connect(_select_weapon.bind(id))
	for id in Content.OUTFITS:
		var button := find_child("outfit_select_" + id, true, false) as Button
		var outfit: Dictionary = Content.OUTFITS[id]
		button.set_meta("caption", outfit.name)
		button.get_node("Icon").texture = _outfit_portrait(id)
		button.get_node("Copy/Name").text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.get_node("Copy/Name").custom_minimum_size.x = 0
		button.get_node("Copy/Name").text = outfit.name
		button.get_node("Copy/Stats").text = "가방 %d장 · %s" % [outfit.hand, "교환 없음" if outfit.exchange == 0 else "교환 %d회" % outfit.exchange]
		button.disabled = host.preparation_training and id != "work"
		button.pressed.connect(_select_outfit.bind(id))
	for button in find_children("*", "Button", true, false):
		button.pressed.connect(func(): host.feedback.play("click"))
		button.add_theme_font_size_override("font_size", host._scaled(18))
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			var skin := PixelSkin.box("button", state)
			skin.content_margin_left = 14
			skin.content_margin_right = 14
			button.add_theme_stylebox_override(state, skin)
	for label in find_children("*", "Label", true, false):
		var base: int = label.get_theme_font_size("font_size")
		label.add_theme_font_size_override("font_size", host._scaled(base))
	refresh()
	%OutfitScroll.ensure_control_visible.call_deferred(find_child("outfit_select_" + host.selected_outfit_id, true, false))
	%loadout_back.custom_minimum_size.x = host._scaled(140)
	%preparation_options.custom_minimum_size.x = host._scaled(150)
	_fit_layout.call_deferred()
	host._focus_control.call_deferred(find_child("weapon_select_" + host.selected_weapon_id, true, false))

func _select_weapon(id: String) -> void:
	host.selected_weapon_id = id
	refresh()

func _select_outfit(id: String) -> void:
	host.selected_outfit_id = id
	refresh()

func refresh() -> void:
	var gun: Dictionary = Content.GUNS[host.selected_weapon_id]
	var outfit_id: String = "work" if host.preparation_training else host.selected_outfit_id
	var outfit: Dictionary = Content.OUTFITS[outfit_id]
	%WeaponName.text = gun.name
	%WeaponRole.text = gun.role
	%WeaponIdentity.text = gun.identity
	%WeaponArt.gun_id = host.selected_weapon_id
	%Capacity.text = "탄창  %d칸" % gun.capacity
	%Reload.text = "재장전  %d턴" % gun.reload
	%Heat.text = "열 한계  %d" % gun.heat_limit
	%Cooling.text = "냉각  %d" % gun.reload_cooling
	%FireMode.text = "전탄 연쇄" if gun.mode == "chain" else "단발 발사"
	%OutfitName.text = outfit.name
	%OutfitSummary.text = "가방 %d장   ·   패 교환 %d회" % [outfit.hand, outfit.exchange]
	%OutfitHint.text = "훈련은 기본 작업복을 사용합니다." if host.preparation_training else "신규 4종 테스트 개방 · 목록을 밀어 선택"
	%OutfitPortrait.texture = _outfit_portrait(outfit_id)
	for id in Content.GUNS:
		_style_choice(find_child("weapon_select_" + id, true, false), id == host.selected_weapon_id)
	for id in Content.OUTFITS:
		_style_choice(find_child("outfit_select_" + id, true, false), id == outfit_id)
	launch.name = "start_" + host.selected_weapon_id
	launch.text = "훈련 시작  ›" if host.preparation_training else "등반 시작  ›"
	host._primary_button(launch)
	%SelectionSummary.text = "%s  /  %s" % [gun.name, outfit.name]
	%starting_deck.text = "시작 탄환  %d장  ›" % _start_deck().size()
	%preparation_options.text = "등반 설정" if host.selected_difficulty == 0 else "등반 설정 · 난도 %d" % host.selected_difficulty
	_fit_layout.call_deferred()

func _fit_layout() -> void:
	var stage_min := maxf(%SelectedWeaponPanel.get_combined_minimum_size().y, %OutfitSelection.get_combined_minimum_size().y) + 8.0
	%Stage.custom_minimum_size.y = maxf(336.0, stage_min)
	# At accessibility text sizes, allow touch scrolling instead of overlapping.
	custom_minimum_size.y = maxf(host.size.y, $Margin/Layout.get_combined_minimum_size().y + 36.0)

func _style_choice(button: Button, chosen: bool) -> void:
	button.set_pressed_no_signal(chosen)
	button.add_theme_stylebox_override("normal", PixelSkin.box("well", "selected" if chosen else "normal"))
	button.add_theme_stylebox_override("pressed", PixelSkin.box("well", "selected"))
	button.add_theme_stylebox_override("hover", PixelSkin.box("well", "hover"))
	button.add_theme_stylebox_override("focus", PixelSkin.box("well", "focus"))
	button.modulate = Color.WHITE if chosen else Color("a8b5b5")
	button.tooltip_text = ("선택됨 · " if chosen else "선택 · ") + button.get_meta("caption", "")
	if button.disabled: button.tooltip_text = "훈련은 기본 작업복을 사용합니다."

func _start_deck() -> Array:
	if host.preparation_training: return Content.cycle_start_deck(Content.COURSE_GRANTS[0])
	return CampaignContent.Acquisition.start_deck()

func _deck_details() -> void:
	var column: VBoxContainer = host._dialog("시작 탄환 · " + str(Content.GUNS[host.selected_weapon_id].name), false)
	column.name = "StartingDeckPreview"
	if not host.preparation_training: host._label(column,"기본탄으로 출발 · 첫 승리 후 코어와 특수탄 선택",18,host.MUTED)
	var deck := _start_deck()
	var seen: Array = []
	for id in deck:
		if seen.has(id): continue
		seen.append(id)
		var row: HBoxContainer = host._row(column)
		var caption: Label = host._label(row, "%s ×%d" % [Content.AMMO[id].name, deck.count(id)], 21)
		caption.name = "StartingRound_" + str(id)
		host._label(row, preload("res://redesign/readability.gd").stats(id,{"gun":host.selected_weapon_id},true), 18, host.MUTED)

func _options() -> void:
	var column: VBoxContainer = host._dialog("등반 설정", false)
	column.name = "PreparationOptions"
	var dialog: Control = column.get_meta("dialog")
	if not host.preparation_training:
		host._label(column, "첫 특수탄 보급 선호", 22)
		host._label(column, "시작 덱은 기본탄입니다. 첫 승리 후 후보에 선호 탄종이 포함됩니다.", 17, host.MUTED)
		var choices: HBoxContainer = host._row(column)
		choices.name = "LoadoutSelection"
		for id in profile.unlocks:
			var button: Button = host._button(choices, str(CampaignContent.LOADOUTS[id].name), "loadout_select_" + id, func():
				host.selected_loadout_id = id
				dialog.close()
				refresh()
				_options.call_deferred()
			)
			if id == host.selected_loadout_id: host._primary_button(button)
		host._label(column, "난도 · 등반 성공 시 다음 난도가 해금됩니다", 18, host.MUTED)
		host.difficulty_option = SpinBox.new()
		host.difficulty_option.name = "CityDifficulty"
		host.difficulty_option.custom_minimum_size = Vector2(120, 52)
		host.difficulty_option.max_value = int(profile.ascension)
		host.difficulty_option.value = host.selected_difficulty
		host.difficulty_option.editable = int(profile.ascension) > 0
		host.difficulty_option.value_changed.connect(func(value: float): host.selected_difficulty = int(value); refresh())
		column.add_child(host.difficulty_option)
	host._label(column, "시드 · 같은 번호는 같은 경로로 시작합니다", 18, host.MUTED)
	var row: HBoxContainer = host._row(column)
	host.seed_input = LineEdit.new()
	host.seed_input.name = "Seed"
	host.seed_input.custom_minimum_size = Vector2(180, 52)
	host.seed_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.seed_input.text = host.preparation_seed
	host.seed_input.text_changed.connect(func(value: String): host.preparation_seed = value)
	row.add_child(host.seed_input)
	host._button(row, "새 시드", "randomize_seed", func():
		host.preparation_seed = str(int(Time.get_ticks_usec()) % 1000000)
		host.seed_input.text = host.preparation_seed
	)


func _outfit_portrait(id: String) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	if OutfitArt.BODIES.has(id):
		atlas.atlas = OutfitArt.BODIES[id].pistol
		atlas.region = Rect2(140, 14, 290, 482)
	else:
		atlas.atlas = OUTFIT_IMAGE
		atlas.region = OUTFIT_REGIONS[id]
	return atlas
