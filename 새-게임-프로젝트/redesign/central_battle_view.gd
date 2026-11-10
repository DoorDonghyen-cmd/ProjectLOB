extends "res://redesign/samples/ranged_battle_view.gd"
const Guard=preload("res://redesign/central_guard.gd")
const GuardArt=preload("res://redesign/central_art.gd")
const CUTOUT=preload("res://redesign/monster_alpha_cutout.gdshader")
var guard_sprites:Dictionary={}
var reserve_sprites:Dictionary={}
var issuing := -1
var issued_order := ""

func sync(state:Dictionary,prediction:Dictionary={}) -> void:
	super.sync(state,prediction)
	issuing=-1;issued_order=""

func _threat_radius(index:int) -> float:
	if not Ranged.is_projectile(index) and index>=0 and index<enemies.size() and Guard.active(enemies[index]):
		return maxf(enemy_hud_width(index)*0.5+8.0,GuardArt.radius(str(enemies[index].species))+10.0)
	return super._threat_radius(index)

func concept_rect(index:int) -> Rect2:
	var pose:=GuardArt.pose(str(enemies[index].species))
	return Rect2((enemy_feet(index)+_actor_offset(index)+(pose.source.position-pose.anchor)*pose.scale).round(),pose.source.size*pose.scale)

func enemy_head_y(index:int) -> float:
	if Guard.active(enemies[index]):return enemy_feet(index).y-float(GuardArt.data()[str(enemies[index].species)].height)-4
	return super.enemy_head_y(index)

func enemy_hud_width(index:int) -> float:
	return 200.0 if Guard.leader(enemies[index]) else super.enemy_hud_width(index)

func enemy_position(index:int) -> Vector2:
	if not Ranged.is_projectile(index) and index>=0 and index<enemies.size() and Guard.active(enemies[index]):
		return enemy_feet(index)-Vector2(0,float(GuardArt.data()[str(enemies[index].species)].height)*0.5)
	return super.enemy_position(index)

func intent_rect(index:int) -> Rect2:
	var plaque:=enemy_plaque(index)
	var width:=minf(210.0,size.x-32)
	return Rect2(clampf(plaque.get_center().x-width*0.5,16,size.x-width-16),maxf(0,plaque.position.y-18),width,18)

func new_sprite() -> Sprite2D:
	var sprite:=Sprite2D.new()
	sprite.centered=false;sprite.region_enabled=true;sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var material:=ShaderMaterial.new();material.shader=CUTOUT;sprite.material=material
	add_child(sprite);return sprite

func _draw_enemy_actor(index:int,foot:Vector2,lift:float,stride:float) -> void:
	if not Guard.active(enemies[index]):super._draw_enemy_actor(index,foot,lift,stride);return
	if not guard_sprites.has(index):guard_sprites[index]=new_sprite()
	var actor:Sprite2D=guard_sprites[index]
	var pose:=GuardArt.pose(str(enemies[index].species))
	var base:=concept_rect(index)
	var rect:=actor_rect(index,base)
	actor.texture=pose.texture;actor.region_rect=pose.source
	actor.position=(finish_camera()*rect.position).round()
	actor.scale=Vector2.ONE*pose.scale*finish_camera().get_scale()*rect.size/base.size
	actor.z_index = actor_layer(index)
	actor.modulate=actor_tint(index);actor.show()
	ActorArtStyle.apply(actor.material,float(pose.scale),cohesive_actor_art)
	var count:=int(enemies[index].barrier)
	for segment in range(count):
		var x:=rect.position.x-5-segment*5
		var y:=rect.position.y+rect.size.y*0.3
		draw_polyline(PackedVector2Array([Vector2(x+4,y),Vector2(x,y),Vector2(x,y+32),Vector2(x+4,y+32)]),Color("91bdbd"),2,false)
	if issuing==index:
		var color:=Color("d7b67c") if issued_order=="advance" else Color("91bdbd")
		var center:=rect.get_center()
		for side in [-1,1]:
			var x:float=center.x+side*(rect.size.x*0.5+9)
			draw_line(Vector2(x,center.y-12),Vector2(x,center.y+12),color,3)

func _draw_reinforcement_actor(index:int,rect:Rect2) -> void:
	if not Guard.active(reinforcements[index]):super._draw_reinforcement_actor(index,rect);return
	if not reserve_sprites.has(index):reserve_sprites[index]=new_sprite()
	var actor:Sprite2D=reserve_sprites[index]
	var pose:=GuardArt.pose(str(reinforcements[index].species))
	var ratio:=minf(24/pose.source.size.x,22/pose.source.size.y)
	actor.texture=pose.texture;actor.region_rect=pose.source
	actor.position=(rect.position+(rect.size-pose.source.size*ratio)*0.5).round()
	actor.scale=Vector2.ONE*ratio;actor.modulate=Color("a7b6b5");actor.show()

func actor_pick_rect(index: int) -> Rect2:
	if Guard.active(enemies[index]): return concept_rect(index)
	return super.actor_pick_rect(index)

func _draw_damage_readouts(canvas:CanvasItem=null) -> void:
	if canvas!=null:super._draw_damage_readouts(canvas)

func _draw() -> void:
	for sprite in guard_sprites.values():sprite.hide()
	for sprite in reserve_sprites.values():sprite.hide()
	super._draw()
	if not is_instance_valid(readout_layer):
		readout_layer=preload("res://redesign/combat_readout_layer.gd").new()
		readout_layer.board=self;readout_layer.z_index=1;add_child(readout_layer)
	readout_layer.queue_redraw()
	for index in _alive_indices():
		var enemy:Dictionary=enemies[index]
		if not Guard.leader(enemy):continue
		if payoff_tier<=0 or fast_forward:
			_draw_hud_text(Vector2(16,28),("관문 · " if enemy.rank=="boss" else "정예 · ")+str(enemy.name),HORIZONTAL_ALIGNMENT_LEFT,260,20,Color("cfb67e"))
		var rect:=intent_rect(index)
		var text:=Guard.intent(enemy, false) if issuing!=index else "전진 지시" if issued_order=="advance" else "본체·전열 차폐"
		_draw_hud_text(rect.position+Vector2(0,15),text,HORIZONTAL_ALIGNMENT_CENTER,rect.size.x,15,Color("dfc993") if enemy.command_order=="advance" else Color("a6c3c2"))

func _play_pull(event:Dictionary) -> void:
	var source:=int(event.get("source",-1))
	if source>=0 and Guard.leader(enemies[source]) and issuing!=source:
		issuing=source;issued_order="advance"
		caption="전진 지시 · 이동형 +2m"
		await _animate(0.28,func(_t:float):pass)
	await super._play_pull(event)

func _before_enemy_movement(events:Array) -> void:
	for event in events:
		if event.kind=="central_command":
			if event.released and issuing!=int(event.target):
				issuing=int(event.target);issued_order=str(event.order)
				caption="전진 지시 · 이동형 +2m" if issued_order=="advance" else "차폐 지시 · 본체와 전열 1기"
				await _animate(0.28,func(_t:float):pass)
			visual_events.append(event.duplicate(true))
		elif event.kind=="central_shield":
			enemies[int(event.target)].barrier=int(event.barrier)
			visual_events.append(event.duplicate(true))

func _after_advance_tick(events:Array) -> void:
	await super._after_advance_tick(events)
	for event in events:
		if event.kind=="central_command":
			enemies[int(event.target)].command_order=event.next_order
			enemies[int(event.target)].command_left=int(event.left)
	issuing=-1;issued_order=""
