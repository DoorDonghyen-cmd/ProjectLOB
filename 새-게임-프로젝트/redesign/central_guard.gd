extends RefCounted
## Roster 11. Finite formations and a single public command every three actions.
const VERSION := 11
const RUSHER := "guard_rusher"
const HEAVY := "guard_heavy"
const SHIELD := "guard_shield"
const ARTILLERY := "guard_artillery"
const CAPTAIN := "guard_captain"
const RULER := "tower_ruler"
const NAMES := {RUSHER:"친위 돌격병",HEAVY:"친위 중장병",SHIELD:"친위 방패병",ARTILLERY:"친위 포격병",CAPTAIN:"친위대장",RULER:"탑의 지배자"}
const CAPACITY := {RUSHER:1,HEAVY:1,SHIELD:2,ARTILLERY:1,CAPTAIN:2,RULER:3}
const PERIOD := 3
const ADVANCE := 2

static func active(enemy: Dictionary) -> bool:
	return int(enemy.get("central_version",0)) in [1,2] and NAMES.has(str(enemy.get("species","")))

static func period(enemy: Dictionary) -> int:
	return 2 if int(enemy.get("central_version",1))>=2 else PERIOD

static func revise(rows: Array) -> Array:
	var result := rows.duplicate(true)
	for row in result:
		if row.size()<6 or not row[5].has("central_version"): continue
		row[5].central_version=2
		if str(row[5].species)==HEAVY: row[2]=3;row[1]-=2
		if row[5].has("command_left"): row[5].command_left=2
	return result

static func leader(enemy: Dictionary) -> bool:
	return active(enemy) and str(enemy.species) in [CAPTAIN,RULER]

static func unit(id: String, hp: int, distance: int, revision: int = 1) -> Array:
	var kind := "spitter" if id==ARTILLERY else "wall" if id==HEAVY else "absorber" if id in [SHIELD,CAPTAIN,RULER] else "runner"
	var data := {"species":id,"name":NAMES[id],"central_version":revision,"barrier_max":CAPACITY[id],"barrier":CAPACITY[id] if id in [SHIELD,CAPTAIN,RULER] else 0}
	if id in [CAPTAIN,RULER]: data.merge({"rank":"boss" if id==RULER else "elite","command_left":period(data),"command_order":"advance"})
	return [kind,hp,(3 if revision>=2 else 1) if id==HEAVY else 0,0 if id==ARTILLERY else 2 if id==RUSHER else 1,distance,data]

static func rows(node: Dictionary, random: RandomNumberGenerator, fallback: Array) -> Array:
	if int(node.region)!=4: return fallback
	if node.kind=="boss":
		# Command + shields + closing guards form the final exam. A second ranged
		# interception clock made low-draw builds spend too many finite rounds.
		return [unit(RULER,80,56),unit(RUSHER,8,46),unit(SHIELD,12,48),unit(HEAVY,18,60),unit(HEAVY,20,48),unit(RUSHER,9,52),unit(SHIELD,12,52),unit(RUSHER,9,54)]
	if node.get("elite",false):
		return [unit(CAPTAIN,38,54),unit(RUSHER,8,44),unit(HEAVY,18,48),unit(SHIELD,12,50),unit(RUSHER,8,50),unit(HEAVY,18,52),unit(RUSHER,9,54)]
	var stage := mini(2,maxi(0,(int(node.floor)-1)/3))
	var result: Array
	if random.randi_range(0,1)==0:
		result=[unit(RUSHER,8+stage,44),unit(HEAVY,18+2*stage,44),unit(RUSHER,8+stage,50),unit(HEAVY,18+stage,50),unit(RUSHER,8+stage,50),unit(HEAVY,18+stage,52)]
	else:
		result=[unit(RUSHER,7+stage,44),unit(SHIELD,11+stage,44),unit(ARTILLERY,11+stage,58),unit(SHIELD,11+stage,50),unit(RUSHER,8+stage,50),unit(SHIELD,11+stage,52)]
	if stage==2: result.append(unit(RUSHER,9,54))
	return result

static func advance(state: Dictionary, tick: int, record: bool = true) -> Array:
	var events: Array=[]
	for source_index in range(state.enemies.size()):
		var source: Dictionary=state.enemies[source_index]
		if not leader(source) or int(source.hp)<=0 or int(source.get("jammed",0))>0: continue
		source.command_left-=1
		var released := int(source.command_left)==0
		var order := str(source.command_order)
		if released:
			if order=="advance":
				for i in range(state.enemies.size()):
					var ally: Dictionary=state.enemies[i]
					if not active(ally) or int(ally.hp)<=0 or int(ally.speed)==0: continue
					var before := int(ally.distance)
					ally.distance=maxi(0,before-ADVANCE)
					if record: events.append({"kind":"pull","turn":tick,"source":source_index,"target":i,"from":before,"to":ally.distance,"amount":ADVANCE})
					if int(ally.distance)==0: state.phase="lost"
			else:
				var selected := -1
				for i in range(state.enemies.size()):
					var ally: Dictionary=state.enemies[i]
					if i==source_index or not active(ally) or int(ally.hp)<=0 or int(ally.barrier)>=int(ally.barrier_max): continue
					if selected<0 or int(ally.distance)<int(state.enemies[selected].distance): selected=i
				var targets: Array=[source_index]
				if selected>=0: targets.append(selected)
				for i in targets:
					var ally: Dictionary=state.enemies[i]
					ally.barrier=mini(int(ally.barrier_max),int(ally.barrier)+1) if period(source)==2 else int(ally.barrier_max)
					if record: events.append({"kind":"central_shield","turn":tick,"source":source_index,"target":i,"barrier":int(ally.barrier)})
				source.command_order="advance"
			if order=="advance": source.command_order="shield"
			source.command_left=period(source)
		if record: events.append({"kind":"central_command","turn":tick,"target":source_index,"order":order,"released":released,"next_order":source.command_order,"left":source.command_left})
	return events

static func intent(enemy: Dictionary, show_distance: bool = true) -> String:
	if not leader(enemy): return ""
	if int(enemy.get("jammed",0))>0: return "지휘 정지 %d턴" % int(enemy.jammed)
	return (("전진 +2m" if show_distance else "전진 지시") if enemy.command_order=="advance" else "차폐 +1회" if period(enemy)==2 else "차폐 재지급")+" · %d턴" % int(enemy.command_left)

static func detail(enemy: Dictionary) -> String:
	if not active(enemy): return ""
	var text: String={RUSHER:"매 적 행동에 2m 접근합니다. 중장병과 섞인 빠른 표적을 먼저 처리하세요.",HEAVY:"높은 체력과 장갑 1을 지닌 전열입니다. 관통·단타·화상을 사용할 수 있습니다.",SHIELD:"차폐 2회를 소모하면 본체가 드러납니다. 스스로 복구하지 않습니다.",ARTILLERY:"제자리에서 요격 가능한 압력탄을 발사합니다. 포격병을 처치해도 이미 발사된 탄은 남습니다.",CAPTAIN:"3행동마다 전진과 차폐 지시를 번갈아 수행합니다.",RULER:"3행동마다 전진과 차폐 지시를 번갈아 수행합니다. 유한 호위만 동반하며 체력 제한이나 강제 무적 국면은 없습니다."}[str(enemy.species)]
	if leader(enemy): text+="\n전진: 본체와 살아 있는 이동형 친위대가 각 2m 추가 접근합니다. 차폐: 본체와 차폐가 부족한 가장 가까운 친위대 1기의 차폐를 최대로 채웁니다. 후속 대기 적과 압력탄에는 지시가 닿지 않습니다. 차단탄으로 지휘 시계를 늦출 수 있습니다.\n"+intent(enemy)
	if int(enemy.get("central_version",1))>=2:
		text=text.replace("장갑 1","장갑 3").replace("3행동마다","2행동마다").replace("차폐를 최대로 채웁니다","차폐를 최대치를 넘지 않게 1회씩 보충합니다")
	return text+"\n차폐는 일반 타격 1회, 전기 주 타격 2회씩 소모됩니다. 파쇄 파츠는 1회를 더 제거합니다. 마지막 차폐까지 직접 피해를 막고, 남은 연타는 HP에 들어갑니다. 화상은 차폐를 우회합니다."

static func valid(enemy: Dictionary) -> bool:
	if not enemy.has("central_version"): return not NAMES.has(str(enemy.get("species","")))
	var number=preload("res://redesign/foundry_workers.gd")
	if not number.number(enemy.central_version,1,2) or not active(enemy): return false
	for key in ["noble_version","garden_version","foundry_version","exposure_left","stance","charge_max"]:
		if enemy.has(key): return false
	var id := str(enemy.species)
	if not number.number(enemy.get("barrier_max",-1),CAPACITY[id],CAPACITY[id]) or not number.number(enemy.get("barrier",-1),0,CAPACITY[id]): return false
	var expected := unit(id,1,1,int(enemy.central_version))
	if str(enemy.get("kind",""))!=expected[0] or not number.number(enemy.get("def",-1),0,expected[2]) or int(enemy.get("speed",-1))!=expected[3]: return false
	if leader(enemy):
		if not number.number(enemy.get("command_left",-1),1,period(enemy)) or not enemy.get("command_order","") in ["advance","shield"]: return false
		if enemy.get("rank","")!=("boss" if id==RULER else "elite"): return false
	elif enemy.has("command_left") or enemy.has("command_order"): return false
	return true
