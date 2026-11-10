extends RefCounted
const Balance=preload("res://redesign/run_balance.gd")
## New-run roles and investments. No dependency on Content/Model (shared by both).
const VERSION:=3
const SPECIALIST_VERSION:=1
const MINIMUM:={"scout":8,"work":10,"carrier":12,"heatworker":10,"hoist":14,"recovery":12,"expedition":14}
const CARRY:={"scout":22,"work":26,"carrier":32,"heatworker":28,"hoist":34,"recovery":30,"expedition":36}
const BAG_STEPS:=3
static func enabled(state: Dictionary)->bool:return int(state.get("combat_roles_version",0)) in [1,2,3]
static func builds(state: Dictionary)->bool:return int(state.get("combat_roles_version",0))==3
static func specialists(state: Dictionary)->bool:return int(state.get("specialist_core_version",0))==SPECIALIST_VERSION
static func burn_growth_step(state: Dictionary)->int:return Balance.BURN_GROWTH_STEP if Balance.enabled(state) else 2
static func coil_ground_bonus(state: Dictionary)->int:return Balance.COIL_GROUND_BONUS if Balance.enabled(state) else 2
static func burn_growth(state: Dictionary,parts: Array)->int:
	if builds(state) and parts.has("inferno"):
		return 2+(int(state.get("engine",{}).get("levels",{}).get("thermal_drive",0))/burn_growth_step(state) if specialists(state) else 0)
	if int(state.get("combat_roles_version",0))<2 or not parts.has("thermal_drive"):return 0
	return int(state.get("engine",{}).get("levels",{}).get("thermal_drive",0))/burn_growth_step(state)
static func level(state: Dictionary,id: String)->int:return int(state.get("gate_mods",{}).get(id,0)) if enabled(state) else 0
static func minimum(state: Dictionary)->int:return int(MINIMUM.get(state.get("outfit","work"),10)) if enabled(state) else 8
static func carry(state: Dictionary)->int:return int(CARRY.get(state.get("outfit","work"),26))+2*mini(BAG_STEPS,int(state.get("bag_upgrades",0)))
static func relay_limit(state: Dictionary,parts: Array)->int:return 1+level(state,"conduction")+(1 if parts.has("capacitor" if builds(state) else "arc_splitter") else 0) if enabled(state) else 10000
static func fire_radius(state: Dictionary,parts: Array)->int:return 3 if builds(state) and parts.has("inferno") else 2
static func slow_duration(state: Dictionary,compressed: bool,parts: Array)->int:return (3 if compressed else 2)+(1 if builds(state) and parts.has("momentum") else 0)
static func control_bonus(state: Dictionary,parts: Array,enemy: Dictionary)->int:return 2 if builds(state) and parts.has("rammer") and int(enemy.get("slow_left",0))>0 else 0
static func pulse_bonus(state: Dictionary)->int:return level(state,"cadence")
static func base_heat(state: Dictionary,base: int)->int:return maxi(1,base-level(state,"efficiency")) if enabled(state) and base>0 else base
static func fire_duration(parts: Array,state: Dictionary={})->int:return (Balance.SPECIALIST_FIRE_DURATION if Balance.enabled(state) else 4) if parts.has("inferno") else 2
static func ignite(state: Dictionary,center: int,damage: int,parts: Array)->void:
	if not enabled(state):return
	if not state.has("fire_zones"):state.fire_zones=[]
	var zone:={"center":center,"radius":fire_radius(state,parts),"left":fire_duration(parts,state),"damage":damage+(coil_ground_bonus(state) if parts.has("coil") else 0)}
	for prior in state.fire_zones:
		if int(prior.center)==center:prior.left=maxi(prior.left,zone.left);prior.damage=maxi(prior.damage,zone.damage);return
	if state.fire_zones.size()>=3:state.fire_zones.pop_front()
	state.fire_zones.append(zone)
static func zone_damage(state: Dictionary,distance: int)->int:
	var result:=0
	for zone in state.get("fire_zones",[]):
		if absi(distance-int(zone.center))<=int(zone.radius):result=maxi(result,int(zone.damage))
	return result
static func tick(state: Dictionary)->void:
	for zone in state.get("fire_zones",[]):zone.left-=1
	if state.has("fire_zones"):state.fire_zones=state.fire_zones.filter(func(zone):return int(zone.left)>0)
static func slow(enemy: Dictionary,duration: int)->int:
	if int(enemy.hp)<=0 or bool(enemy.get("slow_used",false)) or int(enemy.speed)<=0:return 0
	enemy.slow_left=duration;enemy.slow_used=true;return duration
static func movement(enemy: Dictionary,step: int)->int:
	if int(enemy.get("slow_left",0))<=0:return step
	enemy.slow_left-=1
	return maxi(1,ceili(step*0.5)) if step>0 else 0
static func whole(value: Variant,low: int,high: int)->bool:
	return (value is int or value is float) and is_finite(value) and floorf(value)==value and value>=low and value<=high
static func valid(state: Dictionary)->bool:
	if not whole(state.get("specialist_core_version",0),0,SPECIALIST_VERSION):return false
	if specialists(state) and not builds(state):return false
	if not whole(state.get("combat_roles_version",0),0,VERSION):return false
	if not enabled(state):return not state.has("fire_zones")
	if int(state.get("focus_build_version",0))!=1 or not state.get("fire_zones") is Array or state.fire_zones.size()>3:return false
	for zone in state.fire_zones:
		if not zone is Dictionary or zone.size()!=4:return false
		for key in ["center","radius","left","damage"]:
			if not zone.has(key) or not whole(zone[key],0 if key=="center" else 1,1000000 if key=="center" else (3 if builds(state) else 2) if key=="radius" else 4 if key=="left" else 100):return false
	if not state.get("enemies",[]) is Array or not state.get("reinforcements",[]) is Array:return false
	for enemy in state.get("enemies",[])+state.get("reinforcements",[]):
		if not enemy is Dictionary:return false
		if not whole(enemy.get("slow_left",0),0,4 if builds(state) else 3) or not enemy.get("slow_used",false) is bool:return false
		if int(enemy.get("slow_left",0))>0 and not enemy.get("slow_used",false):return false
	return true
