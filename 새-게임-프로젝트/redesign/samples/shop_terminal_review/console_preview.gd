extends "res://redesign/samples/shop_terminal_review/preview.gd"

const IDLE_WAIT := 2.4
const IDLE_TRAVEL := 3.6
const ChassisLayout = preload("res://redesign/samples/shop_terminal_review/console_chassis.gd")

var screen_sweep: Tween
var idle_sweep: Tween

func _ready() -> void:
	bind_console_controls()
	super._ready()
	sync_glass_size()
	restart_idle_sweep()

func bind_console_controls() -> void:
	%PartsButton.pressed.connect(open_parts)
	%PartsPane.parts_changed.connect(refresh)
	%ScreenGlass.resized.connect(sync_glass_size)
	%ScreenGlass.visibility_changed.connect(restart_idle_sweep)

func motion_enabled() -> bool:
	return true

func sync_glass_size() -> void:
	%ScreenGlass.material.set_shader_parameter("glass_size", %ScreenGlass.size)

func restart_idle_sweep() -> void:
	if idle_sweep != null:
		idle_sweep.kill()
		idle_sweep = null
	var glass: ShaderMaterial = %ScreenGlass.material
	glass.set_shader_parameter("idle_progress", 1.0)
	if not %ScreenGlass.is_visible_in_tree() or not motion_enabled():
		return
	idle_sweep = create_tween().set_loops()
	idle_sweep.tween_interval(IDLE_WAIT)
	idle_sweep.tween_method(func(progress: float): glass.set_shader_parameter("idle_progress", progress), 0.0, 1.0, IDLE_TRAVEL)

func fit_area(safe: Rect2) -> void:
	super.fit_area(safe)
	var frame: Control = %Composition
	var trim := maxf(0.0, (frame.offset_bottom - frame.offset_top - 548.0) * 0.5)
	frame.offset_top += trim
	frame.offset_bottom -= trim
	var height := frame.offset_bottom - frame.offset_top
	var compact := height < 416.0
	var receiver_shift := ChassisLayout.receiver_shift(height)
	%ModeKeys.offset_top = 207.0 + receiver_shift
	%ModeKeys.offset_bottom = 313.0 + receiver_shift
	var funds: Control = %ConsoleWallet.get_parent()
	funds.offset_top = 113.0 + receiver_shift
	funds.offset_bottom = 175.0 + receiver_shift
	%Display.offset_bottom = -20.0 if compact else -30.0
	if compact:
		%Display.offset_top = 16.0
		%Display.add_theme_constant_override("separation", 3)
		%ItemArt.custom_minimum_size = Vector2(68, 46)
	%Stock.add_theme_constant_override("separation", 14 if compact else 25)
	var inventory: Control = %Stage.get_parent()
	inventory.custom_minimum_size.x = 222.0 if compact else 272.0
	%Checkout.add_theme_constant_override("separation", 3 if compact else 7)
	%Balance.get_parent().add_theme_constant_override("separation", 2 if compact else 5)
	%Effect.max_lines_visible = 2 if compact else -1
	%RecordCopy.custom_minimum_size.x = minf(660.0, frame.offset_right - frame.offset_left - 333.0)

func refresh() -> void:
	super.refresh()
	%ConsoleWallet.text = %Wallet.text
	sync_console_actions()

func sync_console_actions() -> void:
	# Controls remain on their physical keys; browsing modes only change availability.
	%Buy.disabled = %Buy.disabled or not %Stock.visible
	%PartsButton.disabled = %PartsPane.visible
	%StockTab.visible = not %Stock.visible

func show_record(open: bool) -> void:
	var changed: bool = %Chassis.record_active != open or %PartsPane.visible
	%PartsPane.hide()
	super.show_record(open)
	if not changed:
		return
	refresh_glass()

func open_parts() -> void:
	if run == null:
		return
	var offer := current_offer()
	var preferred := str(offer.id) if offer.get("type", "") == "part" else ""
	show_record(false)
	%Stock.hide()
	%Reroll.hide()
	%Charge.hide()
	%Feedback.hide()
	%RecordSpacer.show()
	%PartsButton.disabled = true
	%StockTab.set_pressed_no_signal(false)
	%PartsPane.show()
	%PartsPane.open(run, preferred)
	sync_console_actions()
	refresh_glass()

func _unhandled_key_input(event: InputEvent) -> void:
	if %PartsPane.is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		show_record(false)
		%PartsButton.grab_focus()
		get_viewport().set_input_as_handled()
		return
	super._unhandled_key_input(event)

func refresh_glass() -> void:
	restart_idle_sweep()
	if not motion_enabled():
		return
	if screen_sweep != null:
		screen_sweep.kill()
	var glass: ShaderMaterial = %ScreenGlass.material
	glass.set_shader_parameter("sweep_progress", 0.0)
	screen_sweep = create_tween()
	screen_sweep.tween_method(func(progress: float): glass.set_shader_parameter("sweep_progress", progress), 0.0, 1.0, 0.19)

func inspect_bounds(context: String) -> void:
	super.inspect_bounds(context)
	verify(%ConsoleWallet.text == "%d Cr" % int(run.s.credits), context + " side readout follows real balance")
	verify(not %Display.get_global_rect().intersects(%ConsoleWallet.get_global_rect()), context + " balance readout is outside the main display")
	verify(not %ScreenGlass.get_global_rect().intersects(%ConsoleWallet.get_global_rect()), context + " CRT treatment is limited to the main display")
	verify(%ScreenGlass.mouse_filter == Control.MOUSE_FILTER_IGNORE, context + " CRT glass passes through touch input")

func frame(output: String, name: String, size_expected: Vector2i) -> void:
	if screen_sweep != null and screen_sweep.is_running():
		await screen_sweep.finished
	await super.frame(output, name, size_expected)

func capture_terminal(output: String) -> void:
	var extent := Vector2i(1280, 800)
	%ScreenGlass.hide()
	verify(idle_sweep == null, "idle sweep stops when the monitor is hidden")
	await frame(output, "clear_stock_1280x800", extent)
	%ScreenGlass.show()
	verify(idle_sweep != null and idle_sweep.is_running(), "visible monitor starts the idle cycle")
	await frame(output, "crt_stock_1280x800", extent)
	await capture_idle_sweep(output, extent)
	await capture_part_mount(output)
	await super.capture_terminal(output)

func capture_idle_sweep(output: String, extent: Vector2i) -> void:
	var glass: ShaderMaterial = %ScreenGlass.material
	await get_tree().create_timer(IDLE_WAIT + 0.20).timeout
	var start := float(glass.get_shader_parameter("idle_progress"))
	verify(start > 0.0 and start < 0.35, "idle sweep starts without switching tabs")
	for index in range(15):
		await frame(output, "idle_sweep_%02d" % index, extent)
		await get_tree().create_timer(0.20).timeout
	verify(float(glass.get_shader_parameter("idle_progress")) > start, "idle sweep travels down the monitor")

func capture_part_mount(output: String) -> void:
	Input.emulate_mouse_from_touch = true
	var mount = %PartsPane
	for extent in [Vector2i(1008, 454), Vector2i(1280, 800), Vector2i(2160, 1032)]:
		get_window().size = extent
		load_example(4)
		await rendered()
		await touch(%Buy)
		verify(run.s.parts.has("lens") and not run.is_equipped("lens"), "a full loadout stores the purchased part")
		var credits: int = run.s.credits
		var equipped: Array = run.equipped_parts()
		await touch(%PartsButton)
		verify(mount.visible and not %Stock.visible and mount.selected_id == "lens", "part management preselects the purchased part")
		var apply: Button = mount.get_node("%Apply")
		var slots: HBoxContainer = mount.get_node("%Slots")
		verify(apply.disabled and mount.outgoing.is_empty(), "replacement waits for a slot to be selected")
		await touch(mount.stored_buttons["thermal_drive"])
		verify(not slots.get_child(0).disabled and slots.get_child(1).disabled, "second core only enables the existing core slot")
		await touch(mount.stored_buttons["lens"])
		await touch(slots.get_child(1))
		verify(mount.outgoing == "coil" and not apply.disabled, "a slot selects the outgoing part")
		verify(mount.get_node("%Gain").visible and mount.get_node("%Loss").visible, "comparison shows the gained and removed effects")
		verify(run.equipped_parts() == equipped, "previewing does not change the loadout")
		inspect_bounds("part replacement")
		await frame(output, "mount_compare_%dx%d" % [extent.x, extent.y], extent)
		await touch(%StockTab)
		verify(not mount.visible and run.equipped_parts() == equipped, "returning to stock cancels unconfirmed replacement")
		await touch(%PartsButton)
		await touch(slots.get_child(1))
		await touch(apply)
		verify(run.is_equipped("lens") and not run.is_equipped("coil") and run.s.parts.has("coil"), "replacement installs the new part and stores the old part")
		verify(run.s.credits == credits and run.equipped_parts() == run.model.s.equipped_parts, "replacement is free and updates the combat model")
		await frame(output, "mount_applied_%dx%d" % [extent.x, extent.y], extent)
		await touch(apply)
		verify(not run.is_equipped("lens") and run.equipped_parts().size() == 4, "removing a mounted part frees the slot")
		await touch(apply)
		verify(run.is_equipped("lens") and run.equipped_parts().size() == 5, "a stored part fits the freed slot")
