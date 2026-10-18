extends "res://redesign/samples/residential_creatures_view.gd"
## Production actors reuse the approved art and the actual combat event stream.
const ChallengeArt = preload("res://redesign/challenge_art.gd")
const Challenges = preload("res://redesign/residential_challenges.gd")
var challenge_pulse := 0.0
var challenge_target := -1
var readout_layer: Node2D

func _draw_damage_readouts(canvas: CanvasItem = null) -> void:
	# Parent canvas is below Sprite2D children; the dedicated child draws last.
	if canvas != null: super._draw_damage_readouts(canvas)

func concept_rect(index: int) -> Rect2:
	if not Challenges.named(enemies[index]): return super.concept_rect(index)
	var pose := ChallengeArt.pose(enemies[index],challenge_target == index)
	return Rect2((enemy_feet(index) + _actor_offset(index) - pose.anchor * pose.scale).round(),pose.source.size * pose.scale)

func enemy_head_y(index: int) -> float:
	if Ranged.is_gatekeeper(enemies[index]): return enemy_feet(index).y - 148.0
	if Challenges.named(enemies[index]): return enemy_feet(index).y - 124.0
	return super.enemy_head_y(index)

func enemy_hud_width(index: int) -> float:
	if Ranged.is_gatekeeper(enemies[index]): return 280.0
	return super.enemy_hud_width(index)

func enemy_position(index: int) -> Vector2:
	if not Ranged.is_projectile(index) and index >= 0 and index < enemies.size() and Challenges.named(enemies[index]):
		return enemy_feet(index) - Vector2(0,69)
	return super.enemy_position(index)

func _draw_enemy_actor(index: int, foot: Vector2, lift: float, stride: float) -> void:
	if not Challenges.named(enemies[index]):
		super._draw_enemy_actor(index,foot,lift,stride)
		return
	if not creature_sprites.has(index):
		var sprite := Sprite2D.new()
		sprite.centered = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var cutout := ShaderMaterial.new()
		cutout.shader = CUTOUT
		sprite.material = cutout
		add_child(sprite)
		creature_sprites[index] = sprite
	var sprite: Sprite2D = creature_sprites[index]
	var pose := ChallengeArt.pose(enemies[index],challenge_target == index)
	var rect := actor_rect(index,concept_rect(index))
	if challenge_target == index and actor_motion_enabled() and not fast_forward:
		var squash := roundf(sin(challenge_pulse * PI) * 3.0)
		rect.position.y += squash
		rect.size.y -= squash
	sprite.texture = pose.texture
	sprite.region_enabled = true
	sprite.region_rect = pose.source
	sprite.position = (finish_camera() * rect.position).round()
	sprite.scale = finish_camera().get_scale() * rect.size / pose.source.size
	sprite.modulate = actor_tint(index)
	sprite.show()

func _draw() -> void:
	super._draw()
	if not is_instance_valid(readout_layer):
		readout_layer = preload("res://redesign/combat_readout_layer.gd").new()
		readout_layer.board = self
		readout_layer.z_index = 1
		add_child(readout_layer)
	readout_layer.queue_redraw()
	for index in _alive_indices():
		if not Challenges.named(enemies[index]): continue
		var title := ("정예 · " if str(enemies[index].get("rank","")) == "elite" else "관문 · ") + str(enemies[index].name)
		_draw_hud_text(Vector2(16,28),title,HORIZONTAL_ALIGNMENT_LEFT,260,20,Color("cfb67e"))
		var intent := Ranged.intent(enemies[index]) if Ranged.is_gatekeeper(enemies[index]) else "호위 추가 접근 · %d턴" % (int(enemies[index].charge_max)-int(enemies[index].charge))
		if int(enemies[index].get("jammed",0)) > 0: intent = "준비 정지 · %d턴" % int(enemies[index].jammed)
		_draw_hud_text(Vector2(16,53),intent,HORIZONTAL_ALIGNMENT_LEFT,260,17,Color("9eaaa4"))
		break
	if challenge_target >= 0 and challenge_pulse > 0.0 and actor_motion_enabled() and not fast_forward:
		draw_set_transform_matrix(finish_camera())
		var center := enemy_feet(challenge_target) - Vector2(0,64)
		var radius := roundf(28 + challenge_pulse * 42)
		var tint := Color("c4a370")
		tint.a = (1.0-challenge_pulse) * 0.7
		for side in [-1,1]:
			draw_polyline(PackedVector2Array([center+Vector2(side*(radius-6),-20),center+Vector2(side*radius,-14),center+Vector2(side*radius,14),center+Vector2(side*(radius-6),20)]),tint,2,false)
		draw_set_transform_matrix(Transform2D.IDENTITY)

func _after_advance_tick(events: Array) -> void:
	await super._after_advance_tick(events)
	for event in events:
		if str(event.kind) == "gatekeeper_state":
			var index := int(event.target)
			var previous := str(enemies[index].ranged_phase)
			enemies[index].ranged_phase = str(event.phase)
			enemies[index].ranged_left = int(event.left)
			enemies[index].def = int(event.def)
			visual_events.append(event.duplicate(true))
			if previous != str(event.phase):
				challenge_target = index
				await _animate(0.22,func(t: float): challenge_pulse = t)
	challenge_target = -1
	challenge_pulse = 0.0

func _charge_released(event: Dictionary) -> void:
	if str(enemies[int(event.target)].get("species","")) != Challenges.ELITE: return
	challenge_target = int(event.target)
	visual_events.append({"kind":"resonance","target":challenge_target})
	await _animate(0.3,func(t: float): challenge_pulse = t)
	challenge_target = -1
	challenge_pulse = 0.0

func _enemy_at(point: Vector2) -> int:
	for index in _alive_indices():
		if Challenges.named(enemies[index]) and concept_rect(index).has_point(point): return index
	return super._enemy_at(point)

func _contact_kind(kind: String) -> bool:
	return kind in ["runner", "wall", "evader"]

func actor_rect(index: int, rect: Rect2) -> Rect2:
	var result := super.actor_rect(index, rect)
	if not actor_motion_enabled() or fast_forward: return rect
	var kind := str(enemies[index].kind)
	var squeeze := 0.0
	if kind == "runner" and moving_indices.has(index):
		squeeze = roundf(absf(sin(march_phase)) * 3.0)
	elif kind == "evader":
		# Heavy water sac settles on the same planted foot line.
		squeeze = roundf((sin(actor_clock * 1.7 + index) + 1.0) * 0.5)
	if attacking_indices.has(index): squeeze += roundf(sin(attack_time / 0.16 * PI) * 5.0)
	result.position += Vector2(-squeeze * 0.5, squeeze)
	result.size += Vector2(squeeze, -squeeze)
	return result
