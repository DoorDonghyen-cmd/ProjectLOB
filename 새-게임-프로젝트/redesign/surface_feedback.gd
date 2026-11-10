extends RefCounted
## Applied receipts only: a blocked attack is a shield contact, not an HP burst.
const METAL=preload("res://assets/art/surface_fx_20261106/metal.png")
const SHIELD=preload("res://assets/art/surface_fx_20261106/shield.png")
const FIRE=preload("res://assets/art/surface_fx_20261106/fire.png")
const FIRE_COLOR:=Color("e99b73")

static func resolve(packet: Dictionary, kind: String="shot") -> Dictionary:
	var math:Dictionary=packet.get("math",{})
	var damage:=int(packet.get("damage",0))
	var shield:=int(packet.get("blocked_hits",0))>0 or int(packet.get("barrier_removed",0))>0
	var chips:=int(packet.get("armor_removed",0))>0
	var metal:=chips or int(math.get("armor",0))>0 or int(math.get("armor_before",packet.get("armor",0)))>0
	var burn:=kind=="burn" and damage>0
	var transferred:=kind in ["burn_transfer","spread"] and int(packet.get("transferred",0))>0
	var fire:=burn or transferred or int(packet.get("burn_added",0))>0
	var hit:bool=damage>0 and not bool(packet.get("intercept",false))
	return {"kind":kind,"contact":hit,"shield":shield,"broken":shield and int(packet.get("barrier",1))==0,"metal":metal,"chips":chips,"fire":fire,"burn":burn,"transfer":transferred,"ground":bool(packet.get("ground",false)),"intercept":bool(packet.get("intercept",false))}

static func frame(index: int, cell: Vector2, columns: int) -> Rect2:
	return Rect2(Vector2(index%columns,index/columns)*cell,cell)

static func fire(canvas: CanvasItem, foot: Vector2, clock: float, scale_value: float=1.0, alpha: float=1.0, reduced: bool=false) -> void:
	if alpha<=0:return
	if reduced:
		canvas.draw_polyline(PackedVector2Array([foot+Vector2(-4,-3),foot+Vector2(-4,-9),foot+Vector2(0,-13),foot+Vector2(4,-7),foot+Vector2(4,-3)]),Color(FIRE_COLOR,alpha*0.65),2,false)
		return
	var index:=posmod(floori(clock*12),12)
	canvas.draw_texture_rect_region(FIRE,Rect2((foot-Vector2(32,56)*scale_value).round(),(Vector2(64,64)*scale_value).round()),frame(index,Vector2(64,64),4),Color(1,1,1,alpha))

static func draw(canvas: CanvasItem, point: Vector2, progress: float, info: Dictionary, reduced: bool, camera: Transform2D) -> void:
	if info.is_empty() or progress>=1:return
	var alpha:=1.0-clampf(progress,0,1)
	if info.shield:
		if reduced:
			canvas.draw_polyline(PackedVector2Array([point+Vector2(3,-12),point+Vector2(-5,-6),point+Vector2(-5,6),point+Vector2(3,12)]),Color("a9c6c4",alpha),2,false)
		else:
			# Mirror the player-facing source dome to catch fire arriving from left.
			var transform:=Transform2D(0,Vector2(-0.9,0.9),0,point.round())
			canvas.draw_set_transform_matrix(camera*transform)
			var index:=mini(22,floori(progress*23))
			canvas.draw_texture_rect_region(SHIELD,Rect2(-Vector2(65.719707,66.905276),Vector2(148,104)),frame(index,Vector2(148,104),5),Color.WHITE)
			canvas.draw_set_transform_matrix(camera)
			if info.broken:
				for side in [-1,1]:
					var at:Vector2=(point+Vector2(4+progress*14,side*(9+progress*23))).snapped(Vector2(2,2))
					canvas.draw_polyline(PackedVector2Array([at+Vector2(-5,-4),at+Vector2(1,-4),at+Vector2(5,3)]),Color("b2cfcd",alpha),2,false)
	if info.contact and not info.burn and not reduced:
		var scale_value:=0.62 if info.metal else 0.40
		var index:=mini(28,floori(progress*29))
		canvas.draw_texture_rect_region(METAL,Rect2((point-Vector2(116,60)*scale_value).round(),(Vector2(152,100)*scale_value).round()),frame(index,Vector2(152,100),5),Color(1,1,1,0.95 if info.metal else 0.75))
		if info.metal:
			# Ricochets escape the numeric glyph footprint, away from the surface.
			for i in range(4):
				var direction:=Vector2.from_angle(PI-0.7+i*0.46)
				var start:Vector2=(point+direction*(14+progress*42)).snapped(Vector2(2,2))
				canvas.draw_line(start,(start+direction*(3+7*alpha)).snapped(Vector2(2,2)),Color("d9c99f",alpha),2,false)
	if info.intercept and progress<0.5:
		for side in [-1,1]:canvas.draw_rect(Rect2((point+Vector2(-progress*20,side*progress*14)).round(),Vector2(4,2)),Color("d6d4ba",alpha))
	if info.fire:
		fire(canvas,point+Vector2(0,12),progress,0.9 if info.burn else 0.7,alpha,reduced)

static func zone_layout(left: float, right: float, foot_y: float) -> Array:
	var result:Array=[]
	if right<=left:return result
	var count:=clampi(ceili((right-left)/24.0),1,14)
	for i in range(count):result.append(Vector2(lerpf(left,right,(i+0.5)/count),foot_y).round())
	return result

static func ground_fire(canvas: CanvasItem, left: float, right: float, foot_y: float, clock: float, remaining: int, reduced: bool) -> void:
	if right<=left:return
	canvas.draw_rect(Rect2(left,foot_y-2,right-left,3),Color("513c30"))
	var points:=zone_layout(left,right,foot_y)
	for i in range(points.size()):
		var point:Vector2=points[i]
		canvas.draw_rect(Rect2(point+Vector2(-8,0),Vector2(16,2)),Color("9a633f"))
		fire(canvas,point,clock+i*0.13,0.68+float(i%3)*0.08,0.85,reduced)
	for tick in range(mini(remaining,8)):canvas.draw_rect(Rect2(left+tick*6,foot_y+4,4,2),Color("e5b46f"))
