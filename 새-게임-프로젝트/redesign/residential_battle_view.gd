extends "res://redesign/samples/residential_creatures_view.gd"
## Production actors reuse the approved art and the actual combat event stream.
const ChallengeArt = preload("res://redesign/challenge_art.gd")
const Challenges = preload("res://redesign/residential_challenges.gd")
var challenge_pulse := 0.0
var challenge_target := -1
var pulled_target := -1
var pulled_amount := 0

func challenge_intent(index: int) -> String:
	var enemy: Dictionary = enemies[index]
	if int(enemy.get("jammed",0)) > 0: return "준비 정지 · %d턴" % int(enemy.jammed)
	if Ranged.is_gatekeeper(enemy):
		match str(enemy.ranged_phase):
			"guard": return "문판 닫힘 · 장갑 %d · %d턴" % [int(enemy.def),int(enemy.ranged_left)]
			"prepare": return ("문판 열림 · 2연발 %d턴" if Ranged.BossSkills.salvo(enemy) else "문판 열림 · 장갑 0 · 발사 %d턴") % int(enemy.ranged_left)
			"burst": return "연속 발사 · 다음 압력탄 1턴"
			"waiting": return "압력탄 요격 · 본체 무방비"
			"recover": return "회복 중 · 장갑 0 · %d턴" % int(enemy.ranged_left)
	var escorts := _alive_indices().filter(func(i): return i != index).size()
	var action := "지휘" if str(enemy.get("species",""))=="slum_leader" else "공명"
	return "호위 없음 · %s 무효" % action if escorts == 0 else "%s %d턴 · 호위 접근" % [action,int(enemy.charge_max)-int(enemy.charge)]

func intent_rect(index: int) -> Rect2:
	var width := minf(294.0, size.x-32.0)
	var plaque := enemy_plaque(index)
	return Rect2(clampf(plaque.get_center().x-width*0.5,16.0,size.x-width-16.0),maxf(0.0,plaque.position.y-16.0),width,16)

func enemy_plaque(index: int) -> Rect2:
	var rect := super.enemy_plaque(index)
	if Challenges.named(enemies[index]): rect.position.y = maxf(16.0,rect.position.y)
	return rect

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
	sprite.z_index = actor_layer(index)
	sprite.modulate = actor_tint(index)
	ActorArtStyle.apply(sprite.material, float(pose.scale), cohesive_actor_art)
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
		var intent := challenge_intent(index)
		var label_rect := intent_rect(index)
		var tint := Color("d8b37b") if str(enemies[index].get("ranged_phase","")) == "prepare" else Color("c2ccc1")
		_draw_hud_text(label_rect.position+Vector2(0,14),intent,HORIZONTAL_ALIGNMENT_CENTER,label_rect.size.x,15,tint)
	if pulled_target >= 0 and challenge_target >= 0:
		draw_set_transform_matrix(finish_camera())
		var source := enemy_feet(challenge_target)-Vector2(0,74)
		var target := enemy_feet(pulled_target)-Vector2(0,45)
		draw_polyline(PackedVector2Array([source,Vector2(target.x,source.y),target]),Color("d8b37b"),3,false)
		draw_set_transform_matrix(Transform2D.IDENTITY)
		var action := "지휘" if str(enemies[challenge_target].get("species",""))=="slum_leader" else "공명"
		_draw_hud_text(Vector2(enemy_position(pulled_target).x-60,enemy_head_y(pulled_target)-12),"%s · 접근" % action,HORIZONTAL_ALIGNMENT_CENTER,120,21,Color("e2ba7c"))
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
			if event.has("salvo_left"): enemies[index].salvo_left = int(event.salvo_left)
			visual_events.append(event.duplicate(true))
			if previous != str(event.phase):
				challenge_target = index
				await _animate(0.65,func(t: float): challenge_pulse = t)
	challenge_target = -1
	challenge_pulse = 0.0

func _charge_released(event: Dictionary) -> void:
	if not Challenges.commander(enemies[int(event.target)]): return
	challenge_target = int(event.target)
	visual_events.append({"kind":"command" if str(enemies[challenge_target].species)=="slum_leader" else "resonance","target":challenge_target})
	await _animate(0.55,func(t: float): challenge_pulse = t)
	challenge_target = -1
	challenge_pulse = 0.0

func _play_pull(event: Dictionary) -> void:
	var source := int(event.source)
	if not Challenges.commander(enemies[source]):
		await super._play_pull(event)
		return
	challenge_target = source
	pulled_target = int(event.target)
	pulled_amount = int(event.amount)
	var human := str(enemies[source].get("species",""))=="slum_leader"
	caption = "지휘 · 호위 추가 접근" if human else "공명 · 호위 추가 접근"
	visual_events.append({"kind":"command_link" if human else "resonance_link","source":source,"target":pulled_target,"amount":pulled_amount})
	await _animate(0.5,func(t: float):
		challenge_pulse = t
		enemies[pulled_target].distance = lerpf(float(event.from),float(event.to),t*t*(3.0-2.0*t))
	)
	pulled_target = -1
	challenge_target = -1
	challenge_pulse = 0.0

func actor_pick_rect(index: int) -> Rect2:
	if Challenges.named(enemies[index]): return concept_rect(index)
	return super.actor_pick_rect(index)

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
