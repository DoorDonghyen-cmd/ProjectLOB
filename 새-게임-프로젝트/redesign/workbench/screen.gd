extends Control
## Approved workbench composition, bound to the existing campaign commands.
const Ammo = preload("res://redesign/content.gd")
const Campaign = preload("res://redesign/campaign.gd")
const Comparison = preload("res://redesign/ammo_comparison.gd")
const Readability = preload("res://redesign/readability.gd")
const Actors = preload("res://redesign/service_actor_catalog.gd")
const Item = preload("res://redesign/workbench/item.tscn")
const Candidate = preload("res://redesign/workbench/candidate.tscn")
const Upgrade = preload("res://redesign/ammo_upgrade.gd")
const DarkPrimary = preload("res://redesign/ui/dark_primary.tres")
const MODES = {0:"탄종 교체", 1:"탄환 강화", 3:"덱 정리", 4:"가방 확장"}
var host
var presenter
var campaign
var mode := 1
var selected := ""
var incoming := ""
var upgrade_open := false
var offers: Array = []
var proposal: Dictionary = {}
var committing := false
@onready var content: VBoxContainer = $Inspector/Inset/BodyScroll/Content
@onready var slots: HBoxContainer = $Inventory/Inset/Rows/InventoryScroll/Slots
@onready var candidates: HBoxContainer = $Options/Candidates/CandidateScroll/Slots

func _feedback_transaction(event: Dictionary, effects) -> void:
	if str(event.command) in ["equip","replace_part"]:
		effects.pulse($Header/Menu,"installed")
		return
	if str(event.command) not in ["resolve","tune","shop_refine","shop_compress"]:return
	effects.pulse($Header/Budget,"complete")
	effects.pulse($Inspector,"complete")
	var added:Array=effects.added_ids(event.before.deck,event.after.deck)
	for item in slots.get_children():
		if added.has(item.get_meta("ammo")):effects.pulse(item,"upgraded")

func configure(screen, owner) -> void:
	host = screen
	presenter = owner
	campaign = host.campaign
	$Room/Actor.profile = Actors.resolve(str(campaign.model.s.get("outfit", "work")), "workshop").profile
	offers = campaign.workshop_ammo_options()
	for child in slots.get_children():
		slots.remove_child(child)
		child.queue_free()
	var counts: Dictionary = {}
	for id in campaign.model.s.deck: counts[id] = int(counts.get(id, 0)) + 1
	for id in counts:
		var item := _item(str(id), int(counts[id]), slots, "Owned_")
		item.pressed.connect(_select.bind(str(id)))
	for id in offers:
		var item := _item(str(id), 1, candidates, "Candidate_")
		item.pressed.connect(_receive.bind(str(id)))
	for i in MODES: get_node("Tabs/Tab%d" % i).pressed.connect(_mode.bind(i))
	$Header/Exit.pressed.connect(_leave)
	$Header/Menu.pressed.connect(func(): $UtilityMenu.visible = not $UtilityMenu.visible)
	$UtilityMenu/Actions/CloseMenu.pressed.connect(func(): $UtilityMenu.hide())
	for entry in [["Build", presenter.deck], ["Archive", presenter.archive], ["Settings", host._settings], ["ReturnTitle", host._to_menu]]:
		get_node("UtilityMenu/Actions/" + str(entry[0])).pressed.connect(_utility.bind(entry[1]))
	$Inspector/Inset/Actions/Apply.pressed.connect(_apply)
	$Inspector/Inset/Actions/Cancel.pressed.connect(_cancel)
	for dialog in $UpgradeLayer.get_children():
		dialog.closed.connect(_upgrade_closed)
		dialog.selection_changed.connect(_upgrade_selected)
	var memory: Dictionary = presenter.workbench_memory
	if memory.get("owner") == campaign and memory.get("node") == campaign.s.node:
		mode = int(memory.get("mode", 1))
		if not MODES.has(mode): mode = 1
		upgrade_open = bool(memory.get("upgrade_open", false)) and not campaign.s.resolved
		selected = str(memory.get("selected", ""))
		incoming = str(memory.get("incoming", ""))
		if not campaign.model.s.deck.has(selected): selected = ""
		if not offers.has(incoming): incoming = ""
		_refresh()
	else: _mode(mode)
	if upgrade_open: _open_upgrade.call_deferred()

func _utility(callback: Callable) -> void:
	$UtilityMenu.hide()
	callback.call()

func _input(event: InputEvent) -> void:
	if $UtilityMenu.visible and event.is_action_pressed("ui_cancel"):
		$UtilityMenu.hide()
		get_viewport().set_input_as_handled()

func _item(id: String, count: int, parent: Node, prefix: String) -> Button:
	var item: Button = (Candidate if prefix == "Candidate_" else Item).instantiate()
	item.name = prefix + id
	parent.add_child(item)
	item.set_meta("ammo", id)
	item.get_node("Content/Icon").item_id = id
	item.get_node("Content/Name").text = Ammo.AMMO[id].name
	item.get_node("Content/Count").text = "%s · %d발" % [Comparison.power(id, campaign.model.s), count]
	item.tooltip_text = "%s\n%s\n발열 %s · 탄창 %d칸" % [Ammo.AMMO[id].name, Readability.description(id, campaign.model.s), Ammo.heat_label(id, campaign.model.s), Ammo.slot_cost(id)]
	return item

func _mode(index: int) -> void:
	mode = index if MODES.has(index) else 1
	if not offers.has(incoming): incoming = str(offers[0]) if not offers.is_empty() else ""
	if not campaign.model.s.deck.has(selected): selected = ""
	# Prefer a usable owned round; every owned round remains inspectable.
	var available := _available_sources()
	if not available.is_empty() and not available.has(selected): selected = str(available[0])
	if selected.is_empty() and not campaign.model.s.deck.is_empty(): selected = str(campaign.model.s.deck[0])
	_refresh()

func _available_sources() -> Array:
	if campaign.s.resolved: return []
	match mode:
		0: return campaign.replaceable_ammo().filter(func(id): return campaign.can_acquire_ammo(incoming, str(id)))
		1: return campaign.compressible_ids()
		3: return campaign.model.s.deck if campaign.model.s.deck.size() > campaign.minimum_deck() else []
	return []

func _select(id: String) -> void:
	selected = id
	_refresh()

func _receive(id: String) -> void:
	incoming = id
	_refresh()

func _cancel() -> void:
	selected = ""
	incoming = ""
	_refresh()

func _preview(source: String) -> Dictionary:
	var result := {"valid":false, "reason":"탄환을 선택하세요.", "target":source, "command":"resolve", "value":"", "extra":source, "replacement":""}
	if campaign.s.resolved:
		result.reason = "이번 정비를 마쳤습니다."
		return result
	if mode != 4 and not campaign.model.s.deck.has(source): return result
	# Data-only sandbox: public domain commands, no disk I/O and no live references.
	var sandbox = Campaign.new()
	sandbox.s = campaign.s.duplicate(true)
	sandbox.model.s = campaign.model.s.duplicate(true)
	sandbox.profile = campaign.profile.duplicate(true)
	match mode:
		0:
			result.value = "refit"
			result.extra = incoming
			result.replacement = source
			result.target = incoming
			result.reason = "받을 탄과 내보낼 탄을 각각 선택하세요."
			if not incoming.is_empty() and source == incoming: result.reason = "서로 다른 탄환을 선택하세요."
			elif not campaign.replaceable_ammo().has(source): result.reason = "이 탄환은 교체할 수 없습니다."
			result.valid = sandbox.resolve("refit", incoming, source)
		1:
			result.value = "compress"
			result.target = Ammo.compressed_id(source)
			result.reason = "같은 성능의 탄환이 2발 필요합니다."
			if result.target.is_empty(): result.reason = "이 탄환은 압축할 수 없습니다."
			elif campaign.model.s.deck.size() <= campaign.minimum_deck(): result.reason = "최소 보유 %d발을 유지해야 합니다." % campaign.minimum_deck()
			result.valid = sandbox.resolve("compress", source)
		3:
			result.value = "remove"
			result.reason = "최소 보유 %d발을 유지해야 합니다." % campaign.minimum_deck()
			result.valid = sandbox.resolve("remove", source)
		4:
			result.value = "bag"
			result.extra = ""
			result.reason = campaign.bag_growth_hint()
			result.valid = sandbox.resolve("bag")
	if result.valid:
		result.after = sandbox.model.s
		result.limit = sandbox.model.deck_limit()
	return result

func _refresh() -> void:
	if campaign == null: return
	var done: bool = campaign.s.resolved
	presenter.workbench_memory = {"owner":campaign, "node":campaign.s.node, "mode":mode, "upgrade_open":upgrade_open, "selected":selected, "incoming":incoming}
	for i in MODES:
		var tab: Button = get_node("Tabs/Tab%d" % i)
		tab.set_pressed_no_signal(i == mode)
		tab.disabled = done
	for item in slots.get_children():
		item.set_pressed_no_signal(item.get_meta("ammo") == selected and mode != 4 and not done)
		item.disabled = done or mode == 4
	for item in candidates.get_children(): item.set_pressed_no_signal(item.get_meta("ammo") == incoming)
	$Options/Candidates.visible = mode == 0 and not done
	$Header/Budget.text = ("정비 완료" if done else "무료 정비 1회") + " · %d Cr" % campaign.s.credits
	$Header/Exit.text = "나가기" if done else "작업 없이 나가기"
	$Inventory/Inset/Rows/Title.text = ("내보낼 탄 · " if mode == 0 and not done else "") + "보유 탄약 %d / %d" % [campaign.model.s.deck.size(), campaign.model.deck_limit()]
	content.get_node("Title").text = "정비 완료" if done else MODES[mode]
	content.get_node("Name").text = str(Ammo.AMMO.get(selected, {}).get("name", ""))
	content.get_node("Name").visible = mode != 4 and not done and not selected.is_empty()
	proposal = _preview(selected)
	var pairs: Array = []
	var detail := ""
	var n: int = campaign.model.s.deck.size()
	var action: String = {0:"탄종 교체",1:"강화 상세",3:"1발 제거",4:"가방 확장"}[mode]
	if done:
		detail = str(campaign.s.message)
		action = "지도로 나가기"
	elif proposal.valid:
		var target := str(proposal.target)
		match mode:
			0, 1:
				var a: Dictionary = Ammo.primary_stat(selected, campaign.model.s)
				var b: Dictionary = Ammo.primary_stat(target, campaign.model.s)
				var recipe := "2발 → 1발" if mode == 1 else "1발 → 1발"
				pairs = [["작업", recipe], [a.label, "%s → %s" % [a.value, b.value] if a.label == b.label else str(a.value) + " → " + str(b.label) + " " + str(b.value)], ["발열", Ammo.heat_label(selected, campaign.model.s) + " → " + Ammo.heat_label(target, campaign.model.s)], ["보유 탄약", "%d → %d발" % [n, proposal.after.deck.size()]]]
				detail = ("받을 탄: %s\n" % Ammo.AMMO[target].name if mode == 0 else "") + _round_rules(selected, target)
				detail = detail.strip_edges()
			3:
				pairs = [["제거", "1발"], ["보유 수량", "%d → %d발" % [campaign.model.s.deck.count(selected), proposal.after.deck.count(selected)]], ["보유 탄약", "%d → %d발" % [n, n-1]], ["최소 보유", "%d발" % campaign.minimum_deck()]]
			4:
				pairs = [["휴대 상한", "%d → %d발" % [campaign.model.deck_limit(), proposal.limit]], ["보유 탄약", "%d발 유지" % n], ["탄약 지급", "없음"]]
	if not done and mode == 1 and proposal.valid:
		pairs = Upgrade.comparison(selected, str(proposal.target), campaign.model.s, n, proposal.after.deck.size()).map(func(row): return [row[0],str(row[1])+" → "+str(row[2])])
		detail = "탄 수 · 발사 횟수 2 → 1\n" + _round_rules(selected, str(proposal.target))
		detail = detail.strip_edges()
	for i in range(4):
		var key: Label = content.get_node("Stats/Key%d" % i)
		var value: Label = content.get_node("Stats/Value%d" % i)
		key.visible = i < pairs.size()
		value.visible = i < pairs.size()
		if i < pairs.size():
			key.text = str(pairs[i][0])
			value.text = str(pairs[i][1])
	content.get_node("Detail").text = detail
	content.get_node("Detail").visible = not detail.is_empty()
	content.get_node("Condition").text = proposal.reason
	content.get_node("Condition").visible = not done and not proposal.valid
	if not host.save_error.is_empty():
		content.get_node("Condition").text = host.save_error
		content.get_node("Condition").visible = true
	var apply: Button = $Inspector/Inset/Actions/Apply
	var commits_work := not done and mode != 1
	apply.theme = DarkPrimary if commits_work else null
	apply.theme_type_variation = &"" if commits_work else &"PrimaryButton"
	apply.text = action
	apply.disabled = not done and not proposal.valid
	if mode == 1 and not done:
		apply.disabled = selected.is_empty()
	$Inspector/Inset/Actions/Cancel.visible = not done and mode != 4
	$Inspector/Inset/Actions/Cancel.disabled = selected.is_empty() and incoming.is_empty() and mode != 4
	$Inspector/Inset/BodyScroll.scroll_vertical = 0

func _round_rules(source: String, target: String) -> String:
	# The workbench shows the selected round's effect, not the whole combat manual.
	var text := "" if Ammo.source_id(target) == "basic" else Readability._description(target, campaign.model.s)
	if Ammo.slot_cost(source) != Ammo.slot_cost(target):
		text += "\n탄창 %d → %d칸" % [Ammo.slot_cost(source), Ammo.slot_cost(target)]
	if Ammo.source_id(target) == "basic" and Ammo.anchor(source) != Ammo.anchor(target):
		match Ammo.anchor(target):
			"first": text += "\n첫 발 고정"
			"last": text += "\n마지막 발 고정"
			_: text += "\n발사 순서 제한 없음"
	return text

func _apply() -> void:
	if committing or host.busy: return
	if campaign.s.resolved:
		_leave()
		return
	if mode == 1:
		if not selected.is_empty(): _open_upgrade()
		return
	proposal = _preview(selected)
	if not proposal.valid:
		_refresh()
		return
	committing = true
	host._campaign_action(str(proposal.command), proposal.value, str(proposal.extra), str(proposal.replacement))
	committing = false
	# A rejected stale command leaves the view alive; show the current restriction.
	if is_inside_tree(): _refresh()

func _leave() -> void:
	if committing or host.busy: return
	committing = true
	if not campaign.s.resolved: host._campaign_action("resolve", "skip")
	host._campaign_action("leave")
	committing = false

func _open_upgrade() -> void:
	if not is_inside_tree() or campaign.s.resolved or host.busy: return
	upgrade_open = true
	$UtilityMenu.hide()
	upgrade_dialog().open(campaign, selected, _commit_upgrade, $Inspector/Inset/Actions/Apply)
	_refresh()

func upgrade_dialog():
	var extent := get_viewport().get_visible_rect().size
	return $UpgradeLayer/SmallUpgrade if extent.x < 1008 or extent.y < 454 else $UpgradeLayer/Upgrade

func _upgrade_selected(id: String) -> void:
	selected = id
	_refresh()

func _upgrade_closed() -> void:
	upgrade_open = false
	if is_inside_tree(): _refresh()

func _commit_upgrade(id: String) -> bool:
	if committing or host.busy or not Upgrade.inspect(campaign, id).valid: return false
	committing = true
	upgrade_open = false
	presenter.workbench_memory.upgrade_open = false
	var accepted: bool = host._campaign_action("resolve", "compress", id)
	committing = false
	return accepted
