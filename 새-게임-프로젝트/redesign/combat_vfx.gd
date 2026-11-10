extends RefCounted
## Local, deterministic pixel geometry. Never consumes the model's random stream.
const GRID := Vector2(2, 2)

static func armor(canvas: CanvasItem, origin: Vector2, progress: float) -> void:
	var t := clampf(progress, 0.0, 1.0)
	for i in range(6):
		var side := -1.0 if i % 2 == 0 else 1.0
		var spread:=1.0-pow(1.0-t,2)
		var travel := Vector2(side*(24+i*10)*spread,-12*t+60*t*t)
		var p := (origin+Vector2(0,8)+travel).snapped(GRID)
		var rotation:=Transform2D((i-2)*0.2+t*(i%3+1)*side,p)
		var plate:=rotation*PackedVector2Array([Vector2(-6,-4),Vector2(5,-4),Vector2(6,1),Vector2(-3,4)])
		canvas.draw_colored_polygon(plate,Color("7c8580",1.0-t))
		canvas.draw_line(plate[0].round(),plate[1].round(),Color("e2d6b2",1.0-t),2,false)
	if t < 0.28:
		canvas.draw_polyline(PackedVector2Array([origin+Vector2(-12,-10), origin+Vector2(-4,-10), origin+Vector2(-4,0), origin+Vector2(4,0), origin+Vector2(4,10), origin+Vector2(12,10)]), Color("e0d5b5"), 2, false)

static func arc_points(start: Vector2, finish: Vector2, progress: float) -> PackedVector2Array:
	var points:=PackedVector2Array([start.snapped(GRID)])
	var direction:=(finish-start).normalized()
	var side:=direction.orthogonal()
	var distance:=start.distance_to(finish)
	var reach:=minf(24,maxf(14,distance*0.12)) if distance>10 else distance*0.4
	var bends:=[0.0,-1.0,0.8,-0.6,1.0,-0.4,0.0]
	for i in range(1,bends.size()):
		var point:Vector2=(start.lerp(finish,float(i)/(bends.size()-1))+side*bends[i]*reach*(1.0 if progress<0.38 else -0.55)).snapped(GRID)
		points.append(Vector2(point.x,points[-1].y));points.append(point)
	return points

static func arc(canvas: CanvasItem, start: Vector2, finish: Vector2, progress: float, reduced: bool) -> void:
	if progress>=0.85:return
	if reduced:
		canvas.draw_line(start.round(),finish.round(),Color("9bbfc4",(1.0-progress)*0.6),2,false)
		return
	var points:=arc_points(start,finish,progress)
	canvas.draw_polyline(points,Color("324e63",(1.0-progress)*0.7),6,false)
	canvas.draw_polyline(points,Color("a9d0d2",1.0-progress),2,false)
	if progress<0.22:
		for index in [4,8]:
			var branch:Vector2=points[index]
			canvas.draw_polyline(PackedVector2Array([branch,branch+Vector2(4,-8),branch+Vector2(10,-12)]),Color("a9d0d2",0.65),2,false)
	for side in [-1,1]:
		var at:Vector2=(finish+Vector2(side*(4+progress*14),-8*progress)).snapped(GRID)
		canvas.draw_line(at,at+Vector2(side*4,-4),Color("d0e1d8",1.0-progress),2,false)

static func ember_point(start: Vector2, finish: Vector2, progress: float) -> Vector2:
	var t:=clampf(progress,0,1)
	return start.lerp(finish,t)+Vector2(0,-sin(t*PI)*minf(36,start.distance_to(finish)*0.22))

static func ember_link(canvas: CanvasItem, start: Vector2, finish: Vector2, progress: float, count: int, reduced: bool) -> void:
	if reduced:
		var middle:=ember_point(start,finish,0.5)
		canvas.draw_polyline(PackedVector2Array([start.round(),middle.round(),finish.round()]),Color("dd9d6f",(1.0-progress)*0.5),2,false)
		return
	for i in range(clampi(count,1,3)):
		var t:float=(progress-i*0.07)/0.72
		if t<0 or t>1:continue
		var at:=ember_point(start,finish,t).snapped(GRID)
		var tail:=ember_point(start,finish,maxf(0,t-0.055)).snapped(GRID)
		canvas.draw_line(tail,at,Color("9b5e3e",0.7),4,false)
		canvas.draw_rect(Rect2(at-Vector2(3,3),Vector2(6,6)),Color("df9460"))
		canvas.draw_rect(Rect2(at-Vector2(1,2),Vector2(2,3)),Color("f0d2a1"))

static func steam(canvas: CanvasItem, muzzle: Vector2, progress: float) -> void:
	for i in range(5):
		var age := clampf((progress-float(i)*0.065)/0.74, 0.0, 1.0)
		if age <= 0 or age >= 1: continue
		var p := (muzzle + Vector2(-18 + i*5 + age*(i-2)*5, -8-age*36)).snapped(GRID)
		var width := 6.0 + floorf(age*3)*2
		var color := Color("a8bbbd", (1.0-age)*0.65)
		canvas.draw_rect(Rect2(p, Vector2(width,4)), color)
		canvas.draw_rect(Rect2(p+Vector2(2,-2), Vector2(width-4,8)), color)
