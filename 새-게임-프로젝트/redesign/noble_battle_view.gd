extends "res://redesign/samples/ranged_battle_view.gd"
const House = preload("res://redesign/noble_house.gd")
const HouseArt = preload("res://redesign/noble_art.gd")
const CUTOUT = preload("res://redesign/monster_alpha_cutout.gdshader")
var house_sprites: Dictionary = {}
var reserve_sprites: Dictionary = {}
var rearming: Array = []
var break_target := -1
var break_flash := 0.0

func sync(state: Dictionary, prediction: Dictionary = {}) -> void:
	super.sync(state,prediction)
	rearming.clear();break_target=-1;break_flash=0.0

func house_frame(index: int) -> int:
	if rearming.has(index): return 2
	return 1 if House.shielded(enemies[index]) and int(enemies[index].barrier)==0 else 0

func live_pose(index: int) -> Dictionary:
	return HouseArt.pose(str(enemies[index].species),house_frame(index))

func _threat_radius(index: int) -> float:
	if not Ranged.is_projectile(index) and index>=0 and index<enemies.size() and House.active(enemies[index]):
		return maxf(enemy_hud_width(index)*0.5+8.0,HouseArt.radius(str(enemies[index].species))+10.0)
	return super._threat_radius(index)

func concept_rect(index: int) -> Rect2:
	var pose:=live_pose(index)
	return Rect2((enemy_feet(index)+_actor_offset(index)+(pose.source.position-pose.anchor)*pose.scale).round(),pose.source.size*pose.scale)

func enemy_head_y(index: int) -> float:
	if House.active(enemies[index]): return enemy_feet(index).y-float(HouseArt.data()[str(enemies[index].species)].height)-4
	return super.enemy_head_y(index)

func enemy_hud_width(index: int) -> float:
	if House.leader(enemies[index]): return 210.0
	return super.enemy_hud_width(index)

func enemy_position(index: int) -> Vector2:
	if not Ranged.is_projectile(index) and index>=0 and index<enemies.size() and House.active(enemies[index]):
		return enemy_feet(index)-Vector2(0,float(HouseArt.data()[str(enemies[index].species)].height)*0.5)
	return super.enemy_position(index)

func intent_rect(index: int) -> Rect2:
	var plaque:=enemy_plaque(index)
	var width:=minf(226.0,size.x-32)
	return Rect2(clampf(plaque.get_center().x-width*0.5,16,size.x-width-16),maxf(0,plaque.position.y-18),width,18)

func _draw_enemy_actor(index: int, _foot: Vector2, _lift: float, _stride: float) -> void:
	if not House.active(enemies[index]):
		super._draw_enemy_actor(index,_foot,_lift,_stride);return
	if not house_sprites.has(index):
		var sprite:=Polygon2D.new();sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		var cutout:=ShaderMaterial.new();cutout.shader=CUTOUT;sprite.material=cutout
		add_child(sprite);house_sprites[index]=sprite
	var actor:Polygon2D=house_sprites[index]
	var pose:=live_pose(index)
	var base:=concept_rect(index)
	var rect:=actor_rect(index,base)
	var points:=PackedVector2Array()
	for point in pose.uv: points.append((point-pose.source.position)*pose.scale)
	actor.polygon=points;actor.uv=pose.uv;actor.texture=pose.texture
	actor.position=(finish_camera()*rect.position).round()
	actor.scale=finish_camera().get_scale()*rect.size/base.size
	actor.z_index = actor_layer(index)
	actor.modulate=actor_tint(index);actor.show()
	ActorArtStyle.apply(actor.material,float(pose.scale),cohesive_actor_art)
	if House.shielded(enemies[index]): _draw_shield(index,rect)

func _draw_shield(index: int, rect: Rect2) -> void:
	var count:=int(enemies[index].barrier)
	var total:=int(enemies[index].barrier_max)
	var y:=rect.position.y+rect.size.y*0.3
	# Each separated bracket is one remaining hit; physical doors are emitters.
	for segment in range(count):
		var x:=roundf(rect.position.x-5-segment*5)
		var inset:=float(total-segment)*2
		var points:=PackedVector2Array([Vector2(x+4,y-inset),Vector2(x,y-inset),Vector2(x,y+30+inset),Vector2(x+4,y+30+inset)])
		draw_polyline(points,Color("7eacae",0.9),2,false)
	if break_target==index and break_flash>0:
		var center:=Vector2(rect.position.x-6,y+14)
		for side in [-1,1]:
			draw_rect(Rect2((center+Vector2(-12*(1-break_flash),side*(12+16*(1-break_flash)))).round(),Vector2(6,3)),Color("dfc993",break_flash))

func _draw_reinforcement_actor(index: int, rect: Rect2) -> void:
	if not House.active(reinforcements[index]): super._draw_reinforcement_actor(index,rect);return
	if not reserve_sprites.has(index):
		var sprite:=Sprite2D.new();sprite.centered=false;sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		var cutout:=ShaderMaterial.new();cutout.shader=CUTOUT;sprite.material=cutout
		add_child(sprite);reserve_sprites[index]=sprite
	var actor:Sprite2D=reserve_sprites[index]
	var pose:=HouseArt.pose(str(reinforcements[index].species))
	var ratio:=minf(24/pose.source.size.x,22/pose.source.size.y)
	actor.texture=pose.texture;actor.region_enabled=true;actor.region_rect=pose.source
	actor.position=(rect.position+(rect.size-pose.source.size*ratio)*0.5).round()
	actor.scale=Vector2.ONE*ratio;actor.modulate=Color("a7b6b5");actor.show()

func actor_pick_rect(index: int) -> Rect2:
	if House.active(enemies[index]): return concept_rect(index)
	return super.actor_pick_rect(index)

func _draw_damage_readouts(canvas: CanvasItem = null) -> void:
	if canvas!=null: super._draw_damage_readouts(canvas)

func _draw() -> void:
	for sprite in house_sprites.values(): sprite.hide()
	for sprite in reserve_sprites.values(): sprite.hide()
	super._draw()
	if not is_instance_valid(readout_layer):
		readout_layer=preload("res://redesign/combat_readout_layer.gd").new()
		readout_layer.board=self;readout_layer.z_index=1;add_child(readout_layer)
	readout_layer.queue_redraw()
	for index in _alive_indices():
		var enemy:Dictionary=enemies[index]
		if House.leader(enemy) and not enemy.has("shield_trial"):
			_draw_hud_text(Vector2(16,28),("관문 · " if enemy.rank=="boss" else "정예 · ")+str(enemy.name),HORIZONTAL_ALIGNMENT_LEFT,260,20,Color("cfb67e"))
		if House.shielded(enemy) and (int(enemy.barrier)==0 or House.leader(enemy)):
			var rect:=intent_rect(index)
			var text:=House.intent(enemy, false)
			if rearming.has(index): text="재차폐 · 전진"
			_draw_hud_text(rect.position+Vector2(0,15),text,HORIZONTAL_ALIGNMENT_CENTER,rect.size.x,15,Color("dfc993") if int(enemy.barrier)==0 else Color("a6c3c2"))

func _hold_impact(result: Dictionary) -> void:
	await super._hold_impact(result)
	if int(result.get("barrier_before",0))>0 and int(result.get("barrier",0))==0 and result.has("exposure_left"):
		break_target=int(result.target);break_flash=1.0
		caption="차폐 파손 · 본체 노출"
		visual_events.append({"kind":"noble_break","target":break_target,"left":result.exposure_left})
		await _animate(0.28,func(t:float):break_flash=1.0-t)
		break_target=-1

func _before_enemy_movement(events: Array) -> void:
	rearming.clear()
	for event in events:
		if str(event.kind)!="noble_state": continue
		var index:=int(event.target)
		if event.action=="rearm":
			rearming.append(index)
			caption="차폐 재가동 · %dm 전진"%int(event.step)
			await _animate(0.26,func(_t:float):pass)
		else:
			enemies[index].barrier=int(event.barrier)
			enemies[index].exposure_left=int(event.exposure_left)
			if event.action == "timed_open": caption = "차폐 개방 · 본체 노출"
		if event.has("shield_open_left"): enemies[index].shield_open_left = int(event.shield_open_left)
		visual_events.append(event.duplicate(true))

func _after_advance_tick(events: Array) -> void:
	await super._after_advance_tick(events)
	for event in events:
		if str(event.kind)=="noble_state":
			enemies[int(event.target)].barrier=int(event.barrier)
			enemies[int(event.target)].exposure_left=int(event.exposure_left)
	if not rearming.is_empty(): await _animate(0.18,func(_t:float):pass)
	rearming.clear()
