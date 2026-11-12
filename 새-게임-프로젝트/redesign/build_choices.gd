extends RefCounted
## Acquisition follows owned ammunition as well as the equipped core. No set bonus.
const Ammo=preload("res://redesign/content.gd")
const Focus=preload("res://redesign/focus_build.gd")
const MODULES:={
	"bore":["coil","igniter","rammer","compression_sink","radiator"],
	"arc":["capacitor","reclaimer","rammer","chain_sink"],
	"precise":["duplex","sequencer","third_striker","breaker","reclaimer","resonator","tally"],
	"pierce":["lens","third_striker","afterburner","opening","sequencer"],
	"vent":["chain_sink","afterburner","ember_core","compression_sink"],
	"push":["rammer","coil","igniter","radiator"]}
const SIGNATURE:={"bore":"coil","arc":"capacitor","precise":"third_striker","pierce":"third_striker","vent":"chain_sink","push":"rammer"}
static func family(state: Dictionary)->String:return Ammo.source_id(Focus.main_round(state)) if not Focus.main_round(state).is_empty() else ""
static func modules(pool: Array,state: Dictionary)->Array:
	var wanted: Array=MODULES.get(family(state),[]).duplicate()
	# Tag build: tag parts fit any main round through its tags.
	if preload("res://redesign/tag_build.gd").enabled(state): wanted.append_array(tag_modules(state))
	if state.get("deck",[]).any(func(id):return Ammo.source_id(str(id))=="disrupt") and not wanted.has("rammer"):wanted.append("rammer")
	if Ammo.equipped_parts(state).any(func(id):return id in ["volley_drive","siege_drive"]) and not wanted.has("capacitor"):wanted.append("capacitor")
	return pool.filter(func(id):return wanted.has(id) and not Ammo.is_core_part(id))
## Tag parts that read a tag the main round carries, plus the tag-free ones
## (conditional multipliers, magazine variety, copy).
static func tag_modules(state: Dictionary)->Array:
	var Tags=preload("res://redesign/tag_build.gd")
	var main:=Focus.main_round(state)
	var carried: Array=Tags.tags(state,main) if not main.is_empty() else []
	return Tags.PARTS.keys().filter(func(id):return not Tags.PARTS[id].has("tag") or carried.has(str(Tags.PARTS[id].tag)))
static func signature(state: Dictionary)->String:return str(SIGNATURE.get(family(state),""))
static func role(id: String)->String:
	if id in ["coil","inferno","igniter"]:return "불길"
	if id in ["momentum","rammer"]:return "제어"
	if id in ["arc_splitter","capacitor","reclaimer"]:return "전이"
	if id in ["third_striker","opening","afterburner","sequencer","duplex","lens","resonator"]:return "직접 화력"
	if id=="tally":return "성장"
	return "운용"
static func shop_ammo(state: Dictionary,node: Dictionary,revision: int)->String:
	var main:=Focus.main_round(state)
	if main.is_empty():return ""
	var supports: Array=Focus.supports_for(state,Ammo.source_id(main))
	var slot:=posmod(int(node.id)+int(state.seed)+revision,3)
	if slot==1:
		var upgraded:=Focus.upgrade(main)
		if not upgraded.is_empty():return upgraded
	if slot==2:
		var fewest:=1000000;var candidates: Array=[]
		for id in supports:
			var count: int=state.deck.filter(func(held):return Ammo.source_id(str(held))==Ammo.source_id(id)).size()
			if count<fewest:fewest=count;candidates=[id]
			elif count==fewest:candidates.append(id)
		if not candidates.is_empty():return candidates[posmod(int(node.id)+revision,candidates.size())]
	return main
