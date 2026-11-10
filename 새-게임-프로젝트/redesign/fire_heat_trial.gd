extends RefCounted
## Shared rules. New campaigns opt into the selected profile; old saves stay unchanged.
const KEY:="fire_heat_trial"
const VERSION:=1
const CAMPAIGN_VERSION:=1
const INPUTS:=["fixed","range"]
const RELOADS:=["legacy","none","small"]
const SMALL_COOLING:=2
const HOT_PERCENT:=80

static func activate_campaign(state: Dictionary)->void:
	state.fire_control_version=CAMPAIGN_VERSION
	state[KEY]={"version":VERSION,"input":"range","reload":"none","damage":false,"rounds":0}

static func config(state: Dictionary)->Dictionary:return state.get(KEY,{})
static func enabled(state: Dictionary)->bool:return int(config(state).get("version",0))==VERSION
static func range_enabled(state: Dictionary)->bool:return enabled(state) and config(state).get("input","")=="range"
static func separate_reload(state: Dictionary)->bool:return enabled(state) and config(state).get("reload","")!="legacy"
static func budget(state: Dictionary)->int:return int(config(state).get("rounds",0)) if range_enabled(state) else 0
static func cap(state: Dictionary,normal: int)->int:
	var requested:=budget(state)
	return mini(normal,requested) if requested>0 else normal
static func may_overdrive(state: Dictionary,fired: int)->bool:return budget(state)==0 or fired<budget(state)
static func reload_amount(state: Dictionary,part_bonus: int)->int:
	return (SMALL_COOLING if config(state).get("reload","")=="small" else 0)+part_bonus
static func threshold(limit: int)->int:return ceili(limit*0.75)
static func damage_percent(state: Dictionary,heat_before: int,limit: int)->int:
	return HOT_PERCENT if enabled(state) and bool(config(state).get("damage",false)) and heat_before>=threshold(limit) else 100
static func scaled_damage(raw: int,percent: int)->int:
	return maxi(1,raw*percent/100) if raw>0 else 0

static func valid(state: Dictionary)->bool:
	var campaign=state.get("fire_control_version",0)
	if not campaign is int and not campaign is float:return false
	if campaign!=0 and campaign!=CAMPAIGN_VERSION:return false
	if campaign==CAMPAIGN_VERSION:
		if not state.get(KEY) is Dictionary:return false
		if state[KEY].get("input")!="range" or state[KEY].get("reload")!="none" or state[KEY].get("damage")!=false:return false
	if not state.has(KEY):return true
	if not state[KEY] is Dictionary:return false
	var value: Dictionary=state[KEY]
	if value.size()!=5:return false
	if not value.get("version") is int and not value.get("version") is float:return false
	if value.version!=VERSION:return false
	if value.get("input") not in INPUTS or value.get("reload") not in RELOADS:return false
	if not value.get("damage") is bool:return false
	var rounds=value.get("rounds")
	if not rounds is int and not rounds is float:return false
	if not is_finite(float(rounds)) or rounds<0 or rounds>64 or int(rounds)!=rounds:return false
	return int(state.get("magazine_trial_version",0))==1 and int(state.get("weapon_magazine_version",0))==1
