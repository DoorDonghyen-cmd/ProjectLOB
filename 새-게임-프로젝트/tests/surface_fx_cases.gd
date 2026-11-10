extends RefCounted
const Cases=preload("res://tests/impact_parts_cases.gd")
const Content=preload("res://redesign/content.gd")
const SPECS:={
	"plain":{"id":"basic_p2"},
	"push":{"id":"push"},
	"metal":{"id":"basic_p2","armor":3},
	"chips":{"id":"shatter","armor":3},
	"shield":{"id":"basic_p2","barrier":2},
	"shield_break":{"id":"basic_p2","barrier":1},
	"partial":{"id":"precise_p2","barrier":1},
	"power_shield":{"id":"basic_p2","barrier":1,"parts":["opening"]},
	"multiply":{"id":"basic_p2","parts":["opening"]},
	"arc":{"id":"arc","parts":["arc_splitter"]},
	"fire":{"id":"bore"},
	"transfer":{"id":"spread","burn":4},
	"burn":{"id":"cool","burn":3},
	"support":{"id":"charge_hot"},
	"slow":{"id":"disrupt"},
}
static func make(kind: String):
	var spec:Dictionary=SPECS[kind]
	var c=Cases.make("plain");var m=c.model
	var parts:Array=spec.get("parts",[]).duplicate()
	c.s.parts=parts.duplicate();c.s.equipped_parts=parts.duplicate();m.s.equipped_parts=parts.duplicate()
	m.s.deck=[spec.id]
	while m.s.deck.size()<14:m.s.deck.append("basic_p2")
	m.begin_encounter();m.s.magazine=[spec.id];m.s.magazine_loaded=[spec.id];m.s.hand=[]
	m.s.draw=m.s.deck.duplicate();m.s.draw.erase(spec.id)
	m.s.phase="ready";m.s.magazine_ejected=0;m.s.fire_heat_trial.rounds=1
	m.s.enemies=[Cases.Data._enemy(["runner",500,int(spec.get("armor",0)),1,30]),Cases.Data._enemy(["runner",500,0,1,32]),Cases.Data._enemy(["runner",500,0,1,37])]
	m.s.enemies[0].barrier=int(spec.get("barrier",0));m.s.enemies[0].barrier_max=int(spec.get("barrier",0));m.s.enemies[0].burn=int(spec.get("burn",0))
	m.s.projectiles=[];m.s.reinforcements=[];m.s.encounter_total=3;m.s.deployed=3;m.assign_opening_lanes()
	m._record("load",{"load_order":[spec.id],"whole_magazine":true})
	return c
