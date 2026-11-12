extends RefCounted
## Read only the applied receipt, never inventory, preview totals or random rolls.
const COLORS := {"plain":Color("e6e8d4"),"add":Color("edc47a"),"multiply":Color("cbb0ee"),"thermal":Color("ed9167"),"volley":Color("9bcbd0"),"armor":Color("ced4c8"),"fire":Color("e99b73"),"muted":Color("a7bbc4")}

static func resolve(result: Dictionary, kind: String="shot", launch_attack: bool=false) -> Dictionary:
	var amount:=int(result.get("damage",0))
	var math:Dictionary=result.get("math",{})
	var sources:Array=[]
	for effect in result.get("part_effects",[]):
		var id:=str(effect.get("id",""))
		if not id.is_empty() and not sources.has(id):sources.append(id)
	var family:="plain"
	var operator:="plain"
	var rank:=0
	var channels:=0
	var part_bonus := maxi(int(math.get("part_bonus", 0)), int(math.get("tag_add", 0)))
	var added := (
		int(math.get("boost", 0)) + part_bonus + int(result.get("thermal_bonus", 0))
		+ int(result.get("vent_bonus", 0)) + int(result.get("chase_bonus", 0))
	) > 0
	if int(math.get("factor",1))>1:channels+=1
	if int(math.get("weapon_factor",1))>1:channels+=1
	if int(result.get("part_factor",math.get("part_factor",1)))>1:channels+=1
	if int(result.get("engine_percent",math.get("engine_percent",100)))>100:channels+=1
	if int(result.get("overdrive_percent",math.get("overdrive_percent",100)))>100:channels+=1
	if int(result.get("gate_percent",math.get("gate_percent",100)))>100:channels+=1
	if int(math.get("tag_percent",100))>100:channels+=1
	if not launch_attack and (amount<=0 or result.get("intercept",false)):
		family="muted"
	elif kind!="shot":
		# Follow-ups are their own effects, not new positional activations.
		family="fire" if kind in ["burn","burn_transfer","heat_wave"] or result.get("ground",false) else "volley" if kind in ["arc","spread","relay","followup"] else "add" if kind=="overflow" else "plain"
		operator="secondary"
	elif channels>0:
		family="multiply";operator="multiply";rank=1
		var part_factor:=int(result.get("part_factor",math.get("part_factor",1)))
		if part_factor>=3 or int(math.get("factor",1))>=3 or int(math.get("tag_percent",100))>=300:rank=2
		if channels>=2 or part_factor>=6:rank=3
		if int(result.get("overdrive_percent",100))>100 or (str(result.get("engine_id",""))=="thermal_drive" and int(result.get("engine_percent",100))>100):family="thermal"
	elif int(result.get("hits",1))>1 or int(result.get("focus_damage",0))>0:
		family="volley";operator="repeat";rank=1
	elif added:
		family="add";operator="add";rank=1
	elif int(result.get("armor_removed",0))>0 or sources.has("lens") or sources.has("breaker"):
		family="armor";operator="armor";rank=1
	elif int(result.get("burn_added",0))>0 or int(result.get("detonation",0))>0:
		family="fire"
	return {"family":family,"operator":operator,"color":COLORS[family],"rank":rank,"channels":channels,"sources":sources,"added":added,"active":launch_attack or (amount>0 and not result.get("intercept",false))}

static func number_marks(canvas: CanvasItem, item: Dictionary, font: Font, alpha: float) -> void:
	var entry:Dictionary=item.entry
	var style:Dictionary=entry.get("style",{})
	if not style.get("active",false):return
	var op:=str(style.get("operator","plain"))
	if op not in ["multiply","add","repeat"]:return
	var color:=Color(entry.color,alpha)
	var width:float=font.get_string_size(entry.number,HORIZONTAL_ALIGNMENT_LEFT,-1,item.font_size).x
	var center:float=item.baseline.x+item.bounds.size.x*0.5
	var left:float=maxf(item.bounds.position.x+2,center-width*0.5-10)
	var right:float=minf(item.bounds.end.x-4,center+width*0.5+6)
	var top:float=item.baseline.y-font.get_ascent(item.font_size)+4
	if op=="multiply":
		var bottom:float=item.baseline.y-2
		for x in [left,right]:
			for y in [top,bottom]:
				canvas.draw_rect(Rect2(Vector2(x,y).round(),Vector2(4,2)),color)
				canvas.draw_rect(Rect2(Vector2(x,y-2 if y==bottom else y).round(),Vector2(2,4)),color)
	elif op=="add":
		var y:float=item.baseline.y-font.get_ascent(item.font_size)*0.45
		canvas.draw_rect(Rect2(Vector2(left-1,y).round(),Vector2(6,2)),color)
		canvas.draw_rect(Rect2(Vector2(left+1,y-2).round(),Vector2(2,6)),color)
	else:
		for dx in [0,4]:canvas.draw_rect(Rect2(Vector2(left+dx,top+8).round(),Vector2(2,8)),color)
