extends "res://redesign/samples/ranged_battle_view.gd"
## Current workers use authored poses; older formations retain their original rendering.
const Foundry = preload("res://redesign/foundry_roster.gd")
const Workers = preload("res://redesign/foundry_workers.gd")
const WorkerArt = preload("res://redesign/foundry_art.gd")
const CUTOUT = preload("res://redesign/monster_alpha_cutout.gdshader")
var command_source := -1
var command_target := -1
var command_amount := 0
var machine_sprites: Dictionary = {}
var reserve_sprites: Dictionary = {}
var surge_targets: Array = []
var anticipating := -1
var firing_machine := -1

func art_factor(index: int) -> float:
	# Leave an explicit overhead lane for HP and the windup warning.
	var species:=str(enemies[index].species)
	var height:=float(WorkerArt.data()[species].height)
	return minf(1.0,(148.0 if species==Workers.BOSS else 140.0 if species==Workers.ELITE else 132.0)/height)

func live_pose(index: int) -> Dictionary:
	var pose:=WorkerArt.pose(str(enemies[index].species),machine_frame(index))
	pose.scale*=art_factor(index)
	return pose

func sync(state: Dictionary, prediction: Dictionary = {}) -> void:
	super.sync(state,prediction)
	surge_targets.clear();anticipating=-1;firing_machine=-1
	for sprite in machine_sprites.values(): sprite.hide()
	for sprite in reserve_sprites.values(): sprite.hide()

func machine_frame(index: int) -> int:
	var enemy: Dictionary = enemies[index]
	# Static telegraph remains readable with motion disabled.
	if anticipating==index: return 1
	if firing_machine==index or surge_targets.has(index): return 2
	if Workers.winding(enemy): return 1 if int(enemy.windup)>0 and not bool(enemy.recovering) else 0
	if str(enemy.get("species",""))=="pressure_worker":
		return 1 if str(enemy.get("ranged_phase",""))=="prepare" and int(enemy.get("ranged_left",2))<=1 else 0
	return 0

func _threat_radius(index: int) -> float:
	if not Ranged.is_projectile(index) and index>=0 and index<enemies.size() and Workers.active(enemies[index]):
		return maxf(42.0,WorkerArt.radius(str(enemies[index].species))*art_factor(index))
	return super._threat_radius(index)

func concept_rect(index: int) -> Rect2:
	var pose := live_pose(index)
	return Rect2((enemy_feet(index)+_actor_offset(index)+(pose.source.position-pose.anchor)*pose.scale).round(),pose.source.size*pose.scale)

func enemy_head_y(index: int) -> float:
	if Workers.active(enemies[index]): return enemy_feet(index).y-float(WorkerArt.data()[str(enemies[index].species)].height)*art_factor(index)
	return super.enemy_head_y(index)

func enemy_hud_width(index: int) -> float:
	if Workers.winding(enemies[index]): return 216.0
	return super.enemy_hud_width(index)

func enemy_position(index: int) -> Vector2:
	if not Ranged.is_projectile(index) and index>=0 and index<enemies.size() and Workers.active(enemies[index]):
		return enemy_feet(index)-Vector2(0,float(WorkerArt.data()[str(enemies[index].species)].height)*art_factor(index)*0.52)
	return super.enemy_position(index)

func _draw_enemy_actor(index: int, foot: Vector2, lift: float, stride: float) -> void:
	if not Workers.active(enemies[index]):
		super._draw_enemy_actor(index,foot,lift,stride)
		return
	if not machine_sprites.has(index):
		var sprite := Polygon2D.new()
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var cutout := ShaderMaterial.new();cutout.shader=CUTOUT;sprite.material=cutout
		add_child(sprite);machine_sprites[index]=sprite
	var actor: Polygon2D = machine_sprites[index]
	var pose := live_pose(index)
	var base := concept_rect(index)
	var rect := actor_rect(index,base)
	var points := PackedVector2Array()
	for point in pose.uv: points.append((point-pose.source.position)*pose.scale)
	actor.polygon=points;actor.uv=pose.uv;actor.texture=pose.texture
	actor.position=(finish_camera()*rect.position).round()
	actor.scale=finish_camera().get_scale()*rect.size/base.size
	actor.z_index = actor_layer(index)
	actor.modulate=actor_tint(index)
	ActorArtStyle.apply(actor.material, float(pose.scale), cohesive_actor_art)
	actor.show()

func _draw_reinforcement_actor(index: int, rect: Rect2) -> void:
	if not Workers.active(reinforcements[index]):
		super._draw_reinforcement_actor(index,rect)
		return
	if not reserve_sprites.has(index):
		var sprite := Sprite2D.new();sprite.centered=false
		sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		var cutout := ShaderMaterial.new();cutout.shader=CUTOUT;sprite.material=cutout
		add_child(sprite);reserve_sprites[index]=sprite
	var actor: Sprite2D = reserve_sprites[index]
	var pose := WorkerArt.pose(str(reinforcements[index].species))
	var ratio := minf(24.0/pose.source.size.x,22.0/pose.source.size.y)
	actor.texture=pose.texture;actor.region_enabled=true;actor.region_rect=pose.source
	actor.position=(rect.position+(rect.size-pose.source.size*ratio)*0.5).round()
	actor.scale=Vector2.ONE*ratio;actor.modulate=Color("a7b6b5");actor.show()

func _draw_damage_readouts(canvas: CanvasItem = null) -> void:
	if canvas!=null: super._draw_damage_readouts(canvas)

func actor_pick_rect(index: int) -> Rect2:
	if Workers.active(enemies[index]): return concept_rect(index)
	return super.actor_pick_rect(index)

func challenge_intent(index: int) -> String:
	if anticipating==index or surge_targets.has(index): return "축압 해제 · 돌진"
	return Foundry.intent(enemies[index],_alive_indices().filter(func(i):return i!=index).size(), false)

func enemy_plaque(index: int) -> Rect2:
	var rect:=super.enemy_plaque(index)
	if Foundry.named(enemies[index]):rect.position.y=maxf(16.0,rect.position.y)
	return rect

func intent_rect(index: int) -> Rect2:
	var width:=minf(310.0,size.x-32.0)
	var plaque:=enemy_plaque(index)
	return Rect2(clampf(plaque.get_center().x-width*0.5,16.0,size.x-width-16.0),maxf(0,plaque.position.y-16.0),width,16)

func _draw() -> void:
	for sprite in machine_sprites.values(): sprite.hide()
	for sprite in reserve_sprites.values(): sprite.hide()
	super._draw()
	if not is_instance_valid(readout_layer):
		readout_layer=preload("res://redesign/combat_readout_layer.gd").new()
		readout_layer.board=self;readout_layer.z_index=1;add_child(readout_layer)
	readout_layer.queue_redraw()
	for index in _alive_indices():
		if not Foundry.named(enemies[index]):continue
		var title:=("관문 · " if str(enemies[index].rank)=="boss" else "정예 · ")+str(enemies[index].name)
		_draw_hud_text(Vector2(16,28),title,HORIZONTAL_ALIGNMENT_LEFT,260,20,Color("cfb67e"))
		var rect:=intent_rect(index)
		_draw_hud_text(rect.position+Vector2(0,14),challenge_intent(index),HORIZONTAL_ALIGNMENT_CENTER,rect.size.x,15,Color("d8b37b"))
	if command_source>=0 and command_target>=0:
		draw_set_transform_matrix(finish_camera())
		var source:=enemy_position(command_source)
		var target_point:=enemy_position(command_target)
		draw_polyline(PackedVector2Array([source,Vector2(target_point.x,source.y),target_point]),Color("d8b37b"),3,false)
		draw_set_transform_matrix(Transform2D.IDENTITY)
		_draw_hud_text(Vector2(target_point.x-60,enemy_head_y(command_target)-12),"독려 · 접근",HORIZONTAL_ALIGNMENT_CENTER,120,21,Color("e2ba7c"))

func _before_enemy_movement(events: Array) -> void:
	surge_targets.clear()
	for event in events:
		if str(event.kind)!="foundry_state": continue
		var index := int(event.target)
		enemies[index].windup=int(event.windup)
		enemies[index].recovering=bool(event.recovering)
		if event.has("armor"): enemies[index].def = int(event.armor)
		visual_events.append(event.duplicate(true))
		if str(event.action)=="surge":
			anticipating=index
			caption="축압 해제 · 본체 %dm 전진" % int(event.step)
			await _animate(0.28,func(_t:float):pass)
			anticipating=-1
			surge_targets.append(index)
			visual_events.append({"kind":"foundry_surge","target":index,"step":int(event.step)})

func _after_advance_tick(events: Array) -> void:
	for event in events:
		if str(event.kind)=="projectile_launch" and Workers.active(enemies[int(event.source)]):
			firing_machine=int(event.source)
	await super._after_advance_tick(events)
	if not surge_targets.is_empty(): await _animate(0.18,func(_t:float):pass)
	surge_targets.clear();firing_machine=-1

func _charge_released(event: Dictionary) -> void:
	if not Foundry.named(enemies[int(event.target)]):return
	caption="독려 · 호위 추가 접근"
	visual_events.append({"kind":"foundry_command","target":event.target})
	await _animate(0.35,func(_t:float):pass)

func _play_pull(event: Dictionary) -> void:
	if not Foundry.named(enemies[int(event.source)]):
		await super._play_pull(event)
		return
	command_source=int(event.source);command_target=int(event.target);command_amount=int(event.amount)
	visual_events.append({"kind":"foundry_link","source":command_source,"target":command_target,"amount":command_amount})
	await _animate(0.5,func(t:float):
		enemies[command_target].distance=lerpf(float(event.from),float(event.to),t*t*(3.0-2.0*t))
	)
	command_source=-1;command_target=-1
