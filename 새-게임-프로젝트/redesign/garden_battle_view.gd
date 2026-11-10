extends "res://redesign/residential_battle_view.gd"
const Hunters = preload("res://redesign/garden_hunters.gd")
const HunterArt = preload("res://redesign/garden_art.gd")
var hunter_sprites: Dictionary = {}
var anticipating := -1
var leaping: Array = []

func sync(state: Dictionary, prediction: Dictionary = {}) -> void:
	super.sync(state,prediction)
	anticipating=-1;leaping.clear()

func hunter_frame(index: int) -> int:
	if anticipating==index: return 1
	if leaping.has(index): return 2
	return 1 if int(enemies[index].leap_left)==1 and not enemies[index].recovering else 0

func _threat_radius(index: int) -> float:
	if not Ranged.is_projectile(index) and index>=0 and index<enemies.size() and Hunters.active(enemies[index]):
		return maxf(42.0,HunterArt.radius(str(enemies[index].species)))
	return super._threat_radius(index)

func concept_rect(index: int) -> Rect2:
	if not Hunters.active(enemies[index]): return super.concept_rect(index)
	var pose:=HunterArt.pose(str(enemies[index].species),hunter_frame(index))
	return Rect2((enemy_feet(index)+_actor_offset(index)+(pose.source.position-pose.anchor)*pose.scale).round(),pose.source.size*pose.scale)

func enemy_head_y(index: int) -> float:
	if Hunters.active(enemies[index]): return enemy_feet(index).y-float(HunterArt.data()[str(enemies[index].species)].height)
	return super.enemy_head_y(index)

func enemy_hud_width(index: int) -> float:
	if Hunters.active(enemies[index]): return 210.0
	return super.enemy_hud_width(index)

func enemy_position(index: int) -> Vector2:
	if not Ranged.is_projectile(index) and index>=0 and index<enemies.size() and Hunters.active(enemies[index]):
		return enemy_feet(index)-Vector2(0,float(HunterArt.data()[str(enemies[index].species)].height)*0.5)
	return super.enemy_position(index)

func _draw_enemy_actor(index: int, foot: Vector2, lift: float, stride: float) -> void:
	if not Hunters.active(enemies[index]):
		super._draw_enemy_actor(index,foot,lift,stride);return
	if not hunter_sprites.has(index):
		var actor:=Polygon2D.new()
		actor.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		var cutout:=ShaderMaterial.new();cutout.shader=CUTOUT;actor.material=cutout
		add_child(actor);hunter_sprites[index]=actor
	var actor: Polygon2D=hunter_sprites[index]
	var pose:=HunterArt.pose(str(enemies[index].species),hunter_frame(index))
	var base:=concept_rect(index)
	var rect:=actor_rect(index,base)
	var points:=PackedVector2Array()
	for point in pose.uv: points.append((point-pose.source.position)*pose.scale)
	actor.polygon=points;actor.uv=pose.uv;actor.texture=pose.texture
	actor.position=(finish_camera()*rect.position).round()
	actor.scale=finish_camera().get_scale()*rect.size/base.size
	actor.z_index = actor_layer(index)
	actor.modulate=actor_tint(index);actor.show()
	ActorArtStyle.apply(actor.material, float(pose.scale), cohesive_actor_art)

func _draw_reinforcement_actor(index: int, rect: Rect2) -> void:
	# Named leaders are first in their finite pack; no hidden recurring summons.
	if not Hunters.active(reinforcements[index]): super._draw_reinforcement_actor(index,rect)

func actor_pick_rect(index: int) -> Rect2:
	if Hunters.active(enemies[index]): return concept_rect(index)
	return super.actor_pick_rect(index)

func challenge_intent(index: int) -> String:
	if Hunters.active(enemies[index]):
		if anticipating==index or leaping.has(index): return "도약 · 접근"
		return Hunters.intent(enemies[index], false)
	return super.challenge_intent(index)

func _draw() -> void:
	for sprite in hunter_sprites.values(): sprite.hide()
	super._draw()
	for index in _alive_indices():
		if not Hunters.active(enemies[index]): continue
		_draw_hud_text(Vector2(16,28),("정예 · " if enemies[index].rank=="elite" else "관문 · ")+str(enemies[index].name),HORIZONTAL_ALIGNMENT_LEFT,260,20,Color("cfb67e"))
		var rect:=intent_rect(index)
		_draw_hud_text(rect.position+Vector2(0,14),challenge_intent(index),HORIZONTAL_ALIGNMENT_CENTER,rect.size.x,15,Color("d8b37b") if hunter_frame(index)>0 else Color("c2ccc1"))

func _before_enemy_movement(events: Array) -> void:
	leaping.clear()
	for event in events:
		if str(event.kind) == "brood_call":
			enemies[int(event.target)].summon_left = int(event.left)
			enemies[int(event.target)].summon_done = bool(event.released)
			visual_events.append(event.duplicate(true))
			if event.released:
				caption = "포효 · 증원 호출"
				await _animate(0.28,func(_t:float):pass)
		if str(event.kind)!="garden_state": continue
		var index:=int(event.target)
		enemies[index].leap_left=int(event.left)
		enemies[index].recovering=bool(event.recovering)
		visual_events.append(event.duplicate(true))
		if event.action=="leap":
			enemies[index].garden_leaping=true
			anticipating=index
			caption="다리 접기 · %dm 도약" % int(event.step)
			await _animate(0.32,func(_t:float):pass)
			anticipating=-1;leaping.append(index)

func _after_advance_tick(events: Array) -> void:
	await super._after_advance_tick(events)
	if not leaping.is_empty():
		await _animate(0.16,func(_t:float):pass)
		for index in leaping: enemies[index].erase("garden_leaping")
		leaping.clear()
		caption="착지 · 다음 행동 숨고르기"
		await _animate(0.20,func(_t:float):pass)
