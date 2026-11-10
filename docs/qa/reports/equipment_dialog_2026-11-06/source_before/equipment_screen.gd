extends Control
## Authored equipment room. Selection changes bindings without rebuilding the page.
const Content = preload("res://redesign/content.gd")
const CampaignContent = preload("res://redesign/campaign_content.gd")
const EquipmentSkin = preload("res://redesign/equipment/skin.gd")
const WeaponActor = preload("res://redesign/weapon_actor.gd")
const Reserve = preload("res://redesign/ammo_reserve.gd")
@onready var launch: Button = %Launch
var host: Control
var profile: Dictionary

func _ready() -> void:
	%Stage.resized.connect(_fit_art)
	%SelectionScroll.get_v_scroll_bar().value_changed.connect(func(_value: float): _fit_art())
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
		var icon := button.get_node("Icon") as TextureRect
		icon.material = icon.material.duplicate()
		icon.material.set_shader_parameter("shadow_lift", 0.65)
		button.get_node("Copy/Name").text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.get_node("Copy/Name").custom_minimum_size.x = 0
		button.get_node("Copy/Name").text = outfit.name
		button.get_node("Copy/Stats").text = "탄약 최대 %d발" % Content.Roles.CARRY[id]
		if host.preparation_training: button.get_node("Copy/Stats").text = "손패 %d · 교환 %d회" % [outfit.hand, outfit.exchange]
		button.disabled = host.preparation_training and id != "work"
		button.pressed.connect(_select_outfit.bind(id))
	for button in find_children("*", "Button", true, false):
		button.pressed.connect(func(): host.feedback.play("click"))
		button.add_theme_font_size_override("font_size", host._scaled(18))
	for label in find_children("*", "Label", true, false):
		var base: int = label.get_theme_font_size("font_size")
		label.add_theme_font_size_override("font_size", host._scaled(base))
	refresh()
	%OutfitScroll.ensure_control_visible.call_deferred(find_child("outfit_select_" + host.selected_outfit_id, true, false))
	%loadout_back.custom_minimum_size.x = host._scaled(150)
	%preparation_options.custom_minimum_size.x = host._scaled(150)
	_fit_layout.call_deferred()
	host._focus_control.call_deferred(find_child("weapon_select_" + host.selected_weapon_id, true, false))

func _select_weapon(id: String) -> void:
	host.selected_weapon_id = id
	refresh()

func _select_outfit(id: String) -> void:
	host.selected_outfit_id = id
	refresh()
	%OutfitScroll.ensure_control_visible.call_deferred(find_child("outfit_select_" + id,true,false))

func refresh() -> void:
	var gun: Dictionary = Content.weapon_spec({"gun":host.selected_weapon_id,"weapon_version":1,"combat_revision":0 if host.preparation_training else Content.COMBAT_REVISION})
	var outfit_id: String = "work" if host.preparation_training else host.selected_outfit_id
	var outfit: Dictionary = Content.OUTFITS[outfit_id]
	%WeaponName.text = gun.name
	%WeaponRole.text = gun.role
	%WeaponIdentity.text = gun.identity
	%WeaponArt.gun_id = host.selected_weapon_id
	%Capacity.text = "탄창  %d칸" % (int(gun.capacity) + (0 if host.preparation_training else 3))
	%Reload.text = "재장전  %d턴" % gun.reload
	%Heat.text = "열 한계  %d" % gun.heat_limit
	%Cooling.text = "냉각  %d" % gun.reload_cooling
	%FireMode.text = "전탄 연쇄" if gun.mode == "chain" else "단발 발사"
	if not host.preparation_training:
		%Reload.text="탄창 교체  적 %d행동"%maxi(2,int(gun.reload))
		%Cooling.text="냉각  열 0 · 적 1행동"
		%FireMode.text="처치 연속" if host.selected_weapon_id=="amplifier" else "시작 최대 %d발"%preload("res://redesign/magazine_trial.gd").WEAPON_PULSES[host.selected_weapon_id]
	%OutfitName.text = outfit.name
	%OutfitSummary.text = "손패 %d장 · 교환 %d회" % [outfit.hand, outfit.exchange]
	if not host.preparation_training:
		%WeaponIdentity.text = {"single":"공격탄 피해 +1","burst":"같은 적 3회 적중 시 +4","scatter":"탄마다 무작위 표적","heavy":"과열 뒤 1발 강행","amplifier":"단발 효과 2배 · 처치 연속"}[host.selected_weapon_id]
		%OutfitSummary.text = "덱 %d~%d발 · 시작 %d발 · 정비 최대 +6" % [Content.Roles.MINIMUM[outfit_id],Content.Roles.CARRY[outfit_id],preload("res://redesign/magazine_build.gd").start_deck(host.selected_weapon_id).size()]
		%Reload.text = "교체  %d턴" % maxi(2,int(gun.reload))
		%Cooling.text = "냉각  1턴 · 열 0"
		%Heat.text = "발열 상한  %d" % gun.heat_limit
		%FireMode.text = {"single":"사격 1~2발","burst":"사격 1~3발","scatter":"사격 1~3발","heavy":"기본 사격 1~3발","amplifier":"사격 1발 · 처치 시 연속"}[host.selected_weapon_id]
		if host.selected_weapon_id=="amplifier":%WeaponIdentity.text="단발 피해·효과 ×2"
	%OutfitHint.text = "훈련은 기본 작업복을 사용합니다." if host.preparation_training else ""
	%OutfitHint.visible = host.preparation_training
	%OutfitPortrait.set_loadout(outfit_id, host.selected_weapon_id)
	for id in Content.GUNS:
		_style_choice(find_child("weapon_select_" + id, true, false), id == host.selected_weapon_id)
	for id in Content.OUTFITS:
		var button:=find_child("outfit_select_" + id, true, false) as Button
		_style_choice(button, id == outfit_id)
		if not host.preparation_training:button.tooltip_text=Content.OUTFITS[id].name+"\n"+_outfit_capacity(id)
	launch.name = "start_" + host.selected_weapon_id
	launch.text = "훈련 시작  ›" if host.preparation_training else "등반 시작  ›"
	%SelectionSummary.text = "%s  /  %s" % [gun.name, outfit.name]
	%starting_deck.text = "시작 탄환  %d장  ›" % _start_deck().size()
	%preparation_options.text = "등반 설정" if host.selected_difficulty == 0 else "등반 설정 · 난도 %d" % host.selected_difficulty
	_fit_layout.call_deferred()

func _fit_layout() -> void:
	var stage_min := maxf(%SelectedWeaponPanel.get_combined_minimum_size().y, %OutfitSelection.get_combined_minimum_size().y) + 8.0
	%Stage.custom_minimum_size.y = maxf(256.0, stage_min)
	# The authored middle scroll owns overflow; header and launch stay outside it.
	# Never force the whole screen taller than the host's safe area.

func _style_choice(button: Button, chosen: bool) -> void:
	button.set_pressed_no_signal(chosen)
	EquipmentSkin.apply_choice(button, chosen)
	button.tooltip_text = ("선택됨 · " if chosen else "선택 · ") + button.get_meta("caption", "")
	if button.disabled: button.tooltip_text = "훈련은 기본 작업복을 사용합니다."

func _start_deck() -> Array:
	if host.preparation_training: return Content.cycle_start_deck(Content.COURSE_GRANTS[0])
	# New climbs use the leaner magazine-build start deck (magazine_build.gd).
	return preload("res://redesign/magazine_build.gd").start_deck(host.selected_weapon_id)

func _outfit_capacity(id: String) -> String:
	var expanded:=Content.Roles.carry({"outfit":id,"bag_upgrades":Content.Roles.BAG_STEPS})
	return "최소 유지 %d발 · 보유 상한 %d발 · 정비 후 최대 %d발" % [Content.Roles.MINIMUM[id],Content.Roles.CARRY[id],expanded]

func _deck_details() -> void:
	var column: VBoxContainer = host._dialog("시작 탄환 · " + str(Content.GUNS[host.selected_weapon_id].name), false)
	column.name = "StartingDeckPreview"
	if not host.preparation_training:
		var capacity: Label=host._label(column,Content.OUTFITS[host.selected_outfit_id].name+" · "+_outfit_capacity(host.selected_outfit_id),18,host.MUTED)
		capacity.name="OutfitCapacityRule"
	if not host.preparation_training: host._label(column,"기본탄으로 출발 · 첫 승리 후 코어와 특수탄 선택",18,host.MUTED)
	if not host.preparation_training: host._label(column,"덱을 섞어 탄창을 채웁니다. 탄창 교체 시 미사용 탄은 예비 뒤로 돌아갑니다. 사용·빼낸 탄은 다음 전투에 복구됩니다.",18,host.MUTED)
	if not host.preparation_training: host._label(column,"특수탄 획득 후에는 보유 특수탄 중 무작위 1장이 첫 탄창 후보에 포함됩니다. 탄환을 선택하고 빼내면 뒤 탄이 앞으로 당겨집니다.",18,host.MUTED)
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
	return WeaponActor.portrait(id)
