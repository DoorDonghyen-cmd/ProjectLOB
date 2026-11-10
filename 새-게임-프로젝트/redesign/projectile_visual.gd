extends RefCounted
## Compact stepped metal slugs. The rightmost point is the actual impact point;
## no casing or additional pellet is drawn. Colours follow the approved ammo art.
const COPPER:=[Color("56382e"),Color("bb7851"),Color("e4b783")]
const STEEL:=[Color("303e48"),Color("81949e"),Color("ced4c8")]
const Enhanced=preload("res://redesign/enhanced_shot_fx.gd")

static func spec(source: String, attack: bool) -> Dictionary:
	var shape:="round"
	var extent:=Vector2(20,8)
	match source:
		"pierce","bypass":shape="needle";extent=Vector2(26,6)
		"precise","arc","spread":shape="banded";extent=Vector2(20,10)
		"push","shatter","disrupt":shape="blunt";extent=Vector2(18,10)
		"bore","thermal","detonate","vent":shape="incendiary";extent=Vector2(22,10)
		"chase","sequence":shape="needle";extent=Vector2(22,8)
	if not attack:shape="capsule";extent=Vector2(16,8)
	return {"shape":shape,"size":extent,"steel":source in ["pierce","bypass","shatter","push","disrupt"],"source":source}

static func geometry(origin: Vector2, target: Vector2, progress: float, data: Dictionary, reduced: bool) -> Dictionary:
	var travel:=origin.distance_to(target)*clampf(progress,0,1)
	var direction:=(target-origin).normalized()
	var size_value:Vector2=data.projectile.size
	if reduced:size_value=Vector2(minf(size_value.x,16),minf(size_value.y,8))
	var body_length:=minf(travel,size_value.x)
	var tier := int(data.get("tier", Enhanced.Tier.STANDARD))
	var tail_limit := Enhanced.trail_limit(tier) if tier != Enhanced.Tier.STANDARD else minf(14, float(data.length) * 0.3) + int(data.rank) * 2
	var tail_length := minf(maxf(0, travel - body_length), 0.0 if reduced else tail_limit)
	var head:=origin+direction*travel
	var rear:=head-direction*body_length
	return {"head":head,"rear":rear,"tail":rear-direction*tail_length,"direction":direction,"angle":direction.angle(),"length":body_length+tail_length,"body_length":body_length,"body_size":Vector2(body_length,size_value.y),"tail_length":tail_length}

static func draw(canvas: CanvasItem, path: Dictionary, data: Dictionary, reduced: bool, camera: Transform2D) -> void:
	if path.body_length<1:return
	var color:Color=data.color
	if path.tail_length>0:
		var tier := int(data.get("tier", Enhanced.Tier.STANDARD))
		if tier == Enhanced.Tier.STANDARD:
			canvas.draw_line(path.tail.round(),path.rear.round(),Color(color,0.38 if data.attack else 0.2),2,false)
		else:
			Enhanced.draw_trail(canvas, path, path.tail_length, tier, color, camera)
	# Nose is at (0,0); the stepped body grows out from the muzzle, never behind it.
	canvas.draw_set_transform_matrix(camera*Transform2D(float(path.angle),path.head.round()))
	var length:float=path.body_size.x
	var radius:float=path.body_size.y*0.5
	var nose:=minf(length,8.0 if data.projectile.shape=="needle" else 6.0)
	var cut:=minf(nose,2.0)
	var outline:=PackedVector2Array([Vector2(-length,-radius),Vector2(-nose,-radius),Vector2(-nose,-radius+2),Vector2(-cut,-2),Vector2(0,-1),Vector2(0,1),Vector2(-cut,2),Vector2(-nose,radius-2),Vector2(-nose,radius),Vector2(-length,radius)])
	if data.projectile.shape in ["blunt","capsule"]:
		outline=PackedVector2Array([Vector2(-length,-radius),Vector2(-2,-radius),Vector2(0,-radius+2),Vector2(0,radius-2),Vector2(-2,radius),Vector2(-length,radius)])
	var ramp:Array=STEEL if data.projectile.steel else COPPER
	if not data.attack:ramp=[Color("34444c"),Color("7d9098"),Color("a7bbc4")]
	canvas.draw_colored_polygon(outline,ramp[0])
	var inner:=Transform2D(0,Vector2(0,0)).scaled(Vector2(0.82,0.66))
	canvas.draw_colored_polygon(inner*outline,ramp[1])
	if length>=6:
		canvas.draw_rect(Rect2(-length+2,-2,maxf(1,length-nose-2),1),ramp[2])
		if data.projectile.shape=="incendiary":canvas.draw_rect(Rect2(-nose,-2,3,4),Color("e99462"))
		if data.projectile.shape=="banded":canvas.draw_rect(Rect2(-length+5,-radius+1,2,radius*2-2),ramp[0])
		# Applied effect hue is an inset band, preserving the metal body colour.
		if int(data.rank)>0 or not data.attack:
			canvas.draw_rect(Rect2(-length+2,-radius+1,2,radius*2-2),color)
			if int(data.rank)>=2 and not reduced:canvas.draw_rect(Rect2(-length+5,-radius+1,1,radius*2-2),color)
	canvas.draw_set_transform_matrix(camera)
