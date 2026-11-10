extends "res://redesign/rewards/screen.gd"

const Readability = preload("res://redesign/ui_readability.gd")

enum Sample { ELITE, FULL_BAG, CORE }

var sample := Sample.ELITE
var claimed := false
var checks := 0
var failures := 0

func _ready() -> void:
	super._ready()
	get_window().size_changed.connect(fit_window)
	fit_window()
	Input.emulate_mouse_from_touch = true
	load_sample(Sample.ELITE)
	var output := OS.get_environment("LOB_REWARD_CAPTURE")
	if not output.is_empty():
		capture_review.call_deferred(output)

func fit_window() -> void:
	var window := get_window()
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	window.content_scale_factor = Readability.scale_for(window.size)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_F1: load_sample(Sample.ELITE)
		KEY_F2: load_sample(Sample.FULL_BAG)
		KEY_F3: load_sample(Sample.CORE)
		KEY_ESCAPE:
			if choosing_outgoing:
				cancel_exchange()

func load_sample(next: Sample) -> void:
	sample = next
	run = Campaign.new()
	run.start("burst", 251025, 0, "balanced", Campaign.Content.RouteMap.VERSION, "carrier", true)
	run.s.departure_step = 3
	run.s.region = 1 if sample == Sample.FULL_BAG else 0
	if sample != Sample.CORE:
		run.s.clears = 2
		run.s.opening_reward_step = 2
		run.s.parts = ["volley_drive"]
		run.s.equipped_parts = ["volley_drive"]
		run.model.s.deck = Focus.replace_opening(run.model.s.deck, "precise")
	var nodes := run.current_nodes()
	var matches := nodes.filter(func(node): return node.kind == "combat" and bool(node.get("elite", false)) == (sample == Sample.ELITE))
	var target: Dictionary = matches[0]
	if sample == Sample.FULL_BAG:
		while run.model.s.deck.size() < run.model.deck_limit():
			run.model.s.deck.append("basic_p1")
	if int(target.floor) > 1:
		var parent: Dictionary = nodes.filter(func(node): return node.next.has(target.id))[0]
		run.s.node = parent.id
		run.s.floor = parent.floor
	if not run.enter(int(target.id)):
		push_error("Reward sample could not enter its battle node.")
		return
	# Stage victory using the real encounter. Only review state is changed.
	run.model.s.phase = "won"
	run.sync_combat()
	claimed = false
	present()

func reset_choices(_preferred: String = "") -> void:
	var ids := run.reward_options()
	var preferred := "third_striker"
	if sample == Sample.FULL_BAG and not ids.is_empty():
		preferred = str(ids.back())
	super.reset_choices(preferred)

func confirm() -> void:
	if claimed:
		load_sample(sample)
		return
	super.confirm()

func claim(id: String, removed: String = "") -> void:
	if not run.reward(id, removed):
		return
	if run.s.phase == "reward":
		reset_choices()
		return
	claimed = true
	choosing_outgoing = false
	%Section.text = "회수 완료" if id != "skip" else "전리품 보류"
	%Item.text = title_for(id) if Data.AMMO.has(id) or Data.PARTS.has(id) else "%d Cr" % run.credit_reward() if id == "credits" else "전투 종료"
	%Gain.text = "가방에 추가됨" if Data.AMMO.has(id) and removed.is_empty() else "교체됨 · " + title_for(removed) if not removed.is_empty() else "장착 완료" if run.is_equipped(id) else "보관함에 추가됨" if Data.PARTS.has(id) else ""
	%Status.text = ""
	%Exchange.hide()
	%Item.show()
	%Gain.show()
	%Pages.hide()
	%Cost.hide()
	%Fit.hide()
	%Skip.hide()
	%Credits.hide()
	%Confirm.text = "시안 다시 보기"
	for card in cards.values():
		card.disabled = true

func verify(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: ", label)

func render_frame() -> void:
	for step in range(6):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

func touch(button: Button) -> void:
	verify(button.is_visible_in_tree() and not button.disabled, "touch target available")
	var point := button.get_global_transform_with_canvas() * (button.size * 0.5)
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.position = point
		event.pressed = pressed
		get_viewport().push_input(event, true)
		await get_tree().process_frame
	await render_frame()

func press_key(key: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.pressed = pressed
		get_viewport().push_input(event, true)
		await get_tree().process_frame
	await render_frame()

func capture(output: String, name: String, extent: Vector2i) -> void:
	if reveal != null and reveal.is_running():
		await reveal.finished
	await render_frame()
	var frame := get_viewport().get_texture().get_image()
	verify(frame.get_size() == extent, "capture pixel size")
	verify(frame.save_png(output.path_join(name + ".png")) == OK, "capture saved")
	verify(get_viewport_rect().grow(1).encloses(%Tray.get_global_rect()), "tray within visible area")
	verify(%Tray.get_global_rect().encloses(%Confirm.get_global_rect()), "action within tray")

func capture_review(output: String) -> void:
	for extent in [Vector2i(1280, 800), Vector2i(1008, 454), Vector2i(2340, 1080)]:
		get_window().size = extent
		var suffix := "%dx%d" % [extent.x, extent.y]
		load_sample(Sample.ELITE)
		verify(run.node().elite and run.part_rewards().has(selected), "actual elite and actual part choice")
		var part := selected
		await capture(output, "elite_" + suffix, extent)
		var hero_bounds: Rect2 = %Hero.get_global_rect()
		var tray_bounds: Rect2 = %Tray.get_global_rect()
		var alternative := str(run.part_rewards().filter(func(id): return id != part)[0])
		var original_parts: Array = run.s.parts.duplicate()
		await touch(cards[alternative])
		verify(selected == alternative and run.s.parts == original_parts, "inspection changes only the selection")
		await touch(cards[part])
		await touch(%Confirm)
		verify(run.s.phase == "map" and run.s.parts.has(part) and run.is_equipped(part), "elite part enters real build")
		await press_key(KEY_F2)
		verify(sample == Sample.FULL_BAG, "F2 opens the full bag fixture")
		verify(hero_bounds.is_equal_approx(%Hero.get_global_rect()) and tray_bounds.is_equal_approx(%Tray.get_global_rect()), "ammo offers use the same stage and tray proportions")
		var deck: Array = run.model.s.deck.duplicate()
		var incoming := selected
		verify(not run.can_acquire_ammo(incoming) and run.reward_options().has(incoming), "full bag has real ammo offer")
		await touch(%Confirm)
		verify(choosing_outgoing and %Confirm.disabled and not cards.is_empty(), "full bag waits for outgoing ammo")
		var old := str(cards.keys()[0])
		await touch(cards[old])
		await capture(output, "exchange_" + suffix, extent)
		verify(hero_bounds.is_equal_approx(%Hero.get_global_rect()) and tray_bounds.is_equal_approx(%Tray.get_global_rect()), "exchange uses the elite stage and tray proportions")
		verify(not %Choices.get_h_scroll_bar().visible and %Choices.get_global_rect().encloses(%Offers.get_global_rect()), "first three exchange cards fit without clipping")
		await touch(%NextPage)
		verify(exchange_page == 1 and not cards.has(old) and outgoing == old, "next page keeps the selected round")
		var next_round := str(cards.keys()[0])
		await touch(cards[next_round])
		verify(outgoing == next_round and run.model.s.deck == deck, "later candidates are selectable without modifying the deck")
		await touch(%PrevPage)
		verify(exchange_page == 0 and cards.has(old), "previous page returns to the first choices")
		await touch(%Skip)
		verify(not choosing_outgoing and run.model.s.deck == deck and selected == incoming, "cancel returns to the same offer and preserves the exact deck")
		await touch(%Confirm)
		await touch(cards[old])
		await touch(%Confirm)
		verify(run.s.phase == "map" and not choosing_outgoing and run.model.s.deck.size() == deck.size(), "one-for-one reward closes the exchange")
		verify(run.model.s.deck.count(incoming) == deck.count(incoming) + 1 and run.model.s.deck.count(old) == deck.count(old) - 1, "one incoming and one outgoing")
		await press_key(KEY_F3)
		verify(run.engine_reward(), "opening core is real campaign state")
		await capture(output, "core_" + suffix, extent)
		verify(hero_bounds.is_equal_approx(%Hero.get_global_rect()) and tray_bounds.is_equal_approx(%Tray.get_global_rect()), "core uses the same stage and tray proportions")
		await touch(%Confirm)
		verify(run.first_ammo_reward(), "core leads to the real opening package")
		var package_deck: Array = Focus.replace_opening(run.model.s.deck, selected)
		await touch(%Confirm)
		verify(run.s.phase == "map" and run.model.s.deck == package_deck, "opening package claims the actual rounds")
	await press_key(KEY_F1)
	verify(sample == Sample.ELITE, "F1 returns to the elite fixture")
	var credits_before: int = run.s.credits
	var credit_reward := run.credit_reward()
	await touch(%Credits)
	verify(run.s.phase == "map" and run.s.credits == credits_before + credit_reward, "credits are an alternative to part")
	load_sample(Sample.ELITE)
	await render_frame()
	credits_before = run.s.credits
	await touch(%Skip)
	verify(run.s.phase == "map" and run.s.credits == credits_before and run.s.parts.size() == 1, "skip grants no reward")
	print("REWARD REVIEW COMPLETE checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)
