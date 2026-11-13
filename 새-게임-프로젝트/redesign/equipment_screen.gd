extends Control
## Authored equipment room. Selection changes bindings without rebuilding the page.
const Content = preload("res://redesign/content.gd")
const CampaignContent = preload("res://redesign/campaign_content.gd")
const EquipmentSkin = preload("res://redesign/equipment/skin.gd")
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
	if not host.preferences.dev_tools(): host.selected_tag_build = false
	%Heading.text = "훈련 장비" if host.preparation_training else "등반 장비"
	%loadout_back.pressed.connect(host._to_menu)
	%preparation_options.pressed.connect(_options)
	%starting_deck.pressed.connect(_deck_details)
	%weapon_info.pressed.connect(func(): host._weapon_details(host.selected_weapon_id))
	launch.pressed.connect(func(): host._request_start(host.selected_weapon_id, false))
	for id in Content.GUNS:
		var button := find_child("weapon_select_" + id, true, false) as Button
		button.get_node("Name").text = Content.GUNS[id].name
		button.disabled=host.preparation_training and id in Content.WeaponRoles.KINDS
		button.pressed.connect(_select_weapon.bind(id))
	for id in Content.OUTFITS:
		var button := find_child("outfit_select_" + id, true, false) as Button
		var outfit: Dictionary = Content.OUTFITS[id]
		button.set_meta("caption", outfit.name)
		var name_label: Label = button.get_node("Content/Copy/Name")
		var stats: Label = button.get_node("Content/Copy/Stats")
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.custom_minimum_size.x = 0
		name_label.text = outfit.name
		stats.text = "탄약 최대 %d발" % Content.Roles.CARRY[id]
		if host.preparation_training: stats.text = "손패 %d · 교환 %d회" % [outfit.hand, outfit.exchange]
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
	%WeaponScroll.ensure_control_visible.call_deferred(find_child("weapon_select_"+id,true,false))

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
		%WeaponIdentity.text = {"single":"공격탄 피해 +1","burst":"같은 적 3회 적중 시 +4","scatter":"탄마다 무작위 표적","heavy":"과열 뒤 1발 강행","amplifier":"단발 효과 2배 · 처치 연속","rewinder":"냉각 때 잔탄 역순 · 첫 발 ×3","deadbolt":"무작위 1발 ×3·봉인"}[host.selected_weapon_id]
		%OutfitSummary.text = "덱 %d~%d발 · 시작 %d발 · 공방 확장 +6" % [Content.Roles.MINIMUM[outfit_id],Content.Roles.CARRY[outfit_id],preload("res://redesign/magazine_build.gd").start_deck(host.selected_weapon_id).size()]
		%Reload.text = "교체  적 %d행동" % maxi(2,int(gun.reload))
		%Cooling.text = "냉각  적 1행동"
		%Heat.text = "열 한계  %d" % gun.heat_limit
		%FireMode.text = {"single":"사격 1~2발","burst":"사격 1~3발","scatter":"사격 1~3발","heavy":"기본 사격 1~3발","amplifier":"사격 1발 · 처치 시 연속","rewinder":"사격 1~3발","deadbolt":"사격 1~3발"}[host.selected_weapon_id]
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
	if host.selected_tag_build and not host.preparation_training: %preparation_options.text += " · 태그"
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
	if button.disabled: button.tooltip_text = "탄창 사격 모드에서 사용하는 총기입니다." if str(button.name).begins_with("weapon_select_") else "훈련은 기본 작업복을 사용합니다."

func _start_deck() -> Array:
	if host.preparation_training: return Content.cycle_start_deck(Content.COURSE_GRANTS[0])
	# New climbs use the leaner magazine-build start deck (magazine_build.gd).
	return preload("res://redesign/magazine_build.gd").start_deck(host.selected_weapon_id)

func _outfit_capacity(id: String) -> String:
	var expanded:=Content.Roles.carry({"outfit":id,"bag_upgrades":Content.Roles.BAG_STEPS})
	return "덱 %d~%d발 · 공방 확장 시 최대 %d발" % [Content.Roles.MINIMUM[id],Content.Roles.CARRY[id],expanded]

func _deck_details() -> void:
	var column: VBoxContainer = host._dialog("시작 탄환 · " + str(Content.GUNS[host.selected_weapon_id].name), false)
	column.name = "StartingDeckPreview"
	# Launch pass (2026-11-12): the deck first, then the two facts a first run needs.
	var deck := _start_deck()
	var seen: Array = []
	for id in deck:
		if seen.has(id): continue
		seen.append(id)
		var row: HBoxContainer = host._row(column)
		var caption: Label = host._label(row, "%s ×%d" % [Content.AMMO[id].name, deck.count(id)], 21)
		caption.name = "StartingRound_" + str(id)
		if host.preparation_training:
			host._label(row, preload("res://redesign/readability.gd").stats(id,{"gun":host.selected_weapon_id},true), 18, host.MUTED)
		else:
			var state := {"gun":host.selected_weapon_id,"weapon_version":1,"combat_revision":Content.COMBAT_REVISION}
			var stat: Dictionary = Content.primary_stat(id, state)
			host._label(row, "%s %s · 열 %s" % [stat.label, stat.value, Content.heat_label(id, state)], 18, host.MUTED)
	if not host.preparation_training:
		host._label(column,"전투가 끝나면 쓴 탄이 모두 돌아옵니다. 첫 승리 보상에서 주력 탄을 고릅니다.",18,host.MUTED)
		var capacity: Label=host._label(column,Content.OUTFITS[host.selected_outfit_id].name+" · "+_outfit_capacity(host.selected_outfit_id),18,host.MUTED)
		capacity.name="OutfitCapacityRule"

func _pick_scheme(tags: bool, dialog: Control) -> void:
	host.selected_tag_build = tags
	dialog.close()
	refresh()
	_options.call_deferred()

func _options() -> void:
	var column: VBoxContainer = host._dialog("등반 설정", false)
	column.name = "PreparationOptions"
	var dialog: Control = column.get_meta("dialog")
	if not host.preparation_training:
		if CampaignContent.SUPPLY_PREFERENCE_VISIBLE:
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
		# Difficulty (launch pass 2026-11-12): a − / + stepper instead of a number box.
		var highest := int(profile.ascension)
		var difficulty: HBoxContainer = host._row(column)
		difficulty.name = "CityDifficulty"
		var level: Label = host._label(difficulty, "난도 %d" % host.selected_difficulty, 22)
		level.name = "DifficultyValue"
		level.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if highest > 0:
			for entry in [["−", "difficulty_less", -1], ["+", "difficulty_more", 1]]:
				var step: Button = host._button(difficulty, str(entry[0]), str(entry[1]), func():
					host.selected_difficulty = clampi(host.selected_difficulty + int(entry[2]), 0, highest)
					dialog.close()
					refresh()
					_options.call_deferred()
				)
				step.custom_minimum_size = Vector2(72, 52)
				step.size_flags_horizontal = Control.SIZE_SHRINK_END
				step.disabled = host.selected_difficulty + int(entry[2]) < 0 or host.selected_difficulty + int(entry[2]) > highest
		# What the level changes (launch_balance.gd: enemy HP; campaign_content.gd: start distance;
		# campaign.gd: fight credits).
		var chosen: int = host.selected_difficulty
		var effect: Label = host._label(column, "기본 난도" if chosen == 0 else "적 체력 +%d%%(첫 구역) ~ +%d%%(마지막 구역) · 시작 거리 −%dm · 전투 보상 −%d Cr" % [preload("res://redesign/launch_balance.gd").harden_percent(chosen, 0) - 100, preload("res://redesign/launch_balance.gd").harden_percent(chosen, 4) - 100, mini(4, chosen / 2), chosen], 18)
		effect.name = "DifficultyEffect"
		effect.visible = highest > 0
		host._label(column, "최고 난도 %d까지 선택할 수 있습니다." % highest if highest > 0 else "등반에 성공하면 다음 난도가 열립니다.", 17, host.MUTED)
		# Tag-based rounds and parts prototype (2026-11-10, tag_build.gd): a comparison build,
		# shown only with the developer switch (title_screen.gd).
		if host.preferences.dev_tools():
			host._label(column, "개발 도구 · 탄환·파츠 구성 비교", 18, host.MUTED)
			var schemes: HBoxContainer = host._row(column)
			schemes.name = "PartSchemeSelection"
			for entry in [[false, "현재 구성", "part_scheme_current"], [true, "태그 시험판", "part_scheme_tags"]]:
				var scheme_button: Button = host._button(schemes, str(entry[1]), str(entry[2]), _pick_scheme.bind(bool(entry[0]), dialog))
				if bool(entry[0]) == host.selected_tag_build: host._primary_button(scheme_button)
	host._label(column, "시드 · 같은 번호는 같은 지도로 시작합니다", 18, host.MUTED)
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
