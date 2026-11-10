extends "res://redesign/samples/gate_review/preview.gd"

const ALARM := Color("ffad50")
const SIGNAL := "차단문 개방 신호"

var lamp_response: Tween

func _ready() -> void:
	%Replay.pressed.connect(load_gate)
	%Gate.resized.connect(place_gate_signs)
	super._ready()
	place_gate_signs.call_deferred()

func departure_control() -> Button:
	return %GateExit

func refresh() -> void:
	super.refresh()
	var departed := mode == Mode.DEPARTED
	%Departure.hide()
	%GateExit.visible = mode == Mode.SERVICE and not traveling
	%GateExit.disabled = traveling or not run.gate_ready()
	%Replay.visible = departed
	%DoorDestination.text = %Destination.text
	%DoorStatus.text = SIGNAL if traveling else %GateState.text
	%DoorLamp.color = ALARM if traveling else Color("eac17c") if run.gate_ready() else Color("a3734c")
	%AlarmLeft.visible = traveling
	%AlarmRight.visible = traveling
	%Gate.operator_at_work = true
	%Gate.station_power = 0.56
	for panel in workstation_panels():
		panel.visible = not traveling and not departed
	if not traveling and not departed:
		%Blackout.hide()
		%Blackout.modulate.a = 0.0
	%Gate.queue_redraw()
	place_gate_signs.call_deferred()

func workstation_panels() -> Array[Control]:
	return [$HeaderShade, $Header, $Stages, $Inspector, %Shelf]

func place_gate_signs() -> void:
	var aperture: Rect2 = %Gate.door_opening()
	if not aperture.has_area():
		return
	var plaque: Control = %DoorPlaque
	plaque.position = Vector2(
		clampf(roundf(aperture.get_center().x - plaque.size.x * 0.5), 16.0, size.x - plaque.size.x - 16.0),
		maxf(119.0, roundf(aperture.position.y - plaque.size.y - 18.0))
	)

func apply() -> void:
	var log_size: int = run.s.log.size()
	super.apply()
	if run.s.log.size() <= log_size:
		return
	if lamp_response != null:
		lamp_response.kill()
	%Gate.station_power = 1.0
	lamp_response = create_tween()
	lamp_response.tween_property(%Gate, "station_power", 0.56, 0.34)

func animate_departure() -> void:
	if lamp_response != null:
		lamp_response.kill()
	%AlarmLeft.modulate.a = 0.25
	%AlarmRight.modulate.a = 0.25
	var signal_light := create_tween().set_parallel()
	signal_light.tween_property(%AlarmLeft, "modulate:a", 1.0, 0.14)
	signal_light.tween_property(%AlarmRight, "modulate:a", 1.0, 0.14)
	signal_light.chain().tween_interval(0.24)
	await signal_light.finished
	var output := OS.get_environment("LOB_GATE_CAPTURE")
	if not output.is_empty():
		await capture_alarm(output)
	%Blackout.show()
	var fade := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fade.tween_property(%Blackout, "modulate:a", 1.0, 0.28)
	await fade.finished
	await RenderingServer.frame_post_draw

func departure_visual_complete() -> bool:
	return %Blackout.visible and is_equal_approx(%Blackout.modulate.a, 1.0) and is_zero_approx(%Gate.travel)

func capture_alarm(output: String) -> void:
	await RenderingServer.frame_post_draw
	var frame := get_viewport().get_texture().get_image()
	var extent := frame.get_size()
	var filename := "alarm_%dx%d.png" % [extent.x, extent.y]
	verify(frame.save_png(output.path_join(filename)) == OK, "alarm capture saved")
	verify(traveling and run.gate_ready() and not %Blackout.visible and %DoorStatus.text == SIGNAL, "opening signal appears before blackout or region change")
	verify(is_zero_approx(%Gate.travel) and %Gate.operator_at_work, "closed door and work pose hold during the signal")

func capture(output: String, name: String, extent: Vector2i) -> void:
	await super.capture(output, name, extent)
	var marker: Rect2 = %DoorPlaque.get_global_rect()
	var bounds := get_viewport_rect().grow(1)
	verify(bounds.encloses(marker) and %DoorDestination.text == %Destination.text, "destination is visible on the gate")
	if mode == Mode.SERVICE:
		var exit := departure_control()
		verify(exit.visible and marker.encloses(exit.get_global_rect()) and not $Inspector.get_global_rect().intersects(exit.get_global_rect()), "departure sits on the destination plate")
		verify(%Gate.operator_at_work and %Gate.station_power > 0.0, "work pose and station indicator are active")
	elif mode == Mode.DEPARTED:
		verify(not $Inspector.visible and not %Shelf.visible and not $Header.visible, "work interface leaves the stage")
		verify(%DoorDestination.text == run.region_info().name and departure_visual_complete(), "real next region is committed under black with the door closed")
		if extent == Vector2i(1280, 800):
			await touch(%Replay)
			verify(mode == Mode.MODS and not %Blackout.visible and not %AlarmLeft.visible, "replay restores the predeparture scene")
