extends RefCounted
const Campaign=preload("res://redesign/campaign.gd")
const Data=preload("res://redesign/campaign_content.gd")
const Content=preload("res://redesign/content.gd")
const SPECS:={
	"plain":{"rounds":["basic_p2"],"parts":[],"family":"plain"},
	"add":{"rounds":["charge","basic_p2"],"parts":[],"family":"add"},
	"opening":{"rounds":["basic_p2"],"parts":["opening"],"family":"multiply"},
	"third":{"rounds":["basic_p2","basic_p2","basic_p2"],"parts":["third_striker"],"family":"multiply"},
	"stacked":{"rounds":["basic_p2","charge","pierce_p2"],"parts":["third_striker","afterburner","siege_drive"],"family":"multiply"},
	"thermal":{"rounds":["basic_p2"],"parts":["thermal_drive"],"family":"thermal"},
	"blocked":{"rounds":["basic_p2"],"parts":["opening"],"family":"muted"},
	"kill":{"rounds":["basic_p2"],"parts":["opening"],"family":"multiply"},
	"arc":{"rounds":["arc"],"parts":["arc_splitter"],"family":"plain"},
	"tag_add":{"rounds":["pierce_p2"],"parts":["tag_single_add"],"family":"add"},
	"tag_multiplier":{"rounds":["pierce_p2"],"parts":["tag_single_mult","tag_copy"],"family":"multiply"},
}

static func make(kind: String):
	# Controlled illustrations, separate from acquired campaign evidence.
	var spec:Dictionary=SPECS[kind]
	var tags_enabled := kind.begins_with("tag_")
	var c=Campaign.new();c.start("rewinder" if tags_enabled else "single",17,0,"balanced",4,"carrier",true);c.enter(101)
	c.s.parts=spec.parts.duplicate();c.s.equipped_parts=spec.parts.duplicate()
	var m=c.model;m.s.equipped_parts=spec.parts.duplicate();m.s.part="none"
	if tags_enabled: m.s.tag_build_version = m.TagBuild.VERSION
	else: m.s.erase("growth_structure_version")
	m.s.deck=spec.rounds.duplicate()
	while m.s.deck.size()<14:m.s.deck.append("basic_p2")
	m.begin_encounter()
	m.s.magazine=spec.rounds.duplicate();m.s.magazine_loaded=spec.rounds.duplicate();m.s.hand=[]
	m.s.draw=m.s.deck.duplicate()
	for id in spec.rounds:m.s.draw.erase(id)
	m.s.phase="ready";m.s.magazine_ejected=0;m.s.fire_heat_trial.rounds=1
	m.s.enemies=[Data._enemy(["runner",500,0,1,30]),Data._enemy(["runner",500,0,1,34])]
	m.s.reinforcements=[];m.s.projectiles=[];m.s.encounter_total=2;m.s.deployed=2;m.assign_opening_lanes()
	if kind=="thermal":m.s.heat=ceili(Content.heat_limit(m.s)/2.0)
	if kind=="blocked":m.s.enemies[0].barrier=1
	if kind=="kill":m.s.enemies[0].hp=6;m.s.enemies[0].max_hp=6
	m._record("load",{"load_order":spec.rounds.duplicate(),"whole_magazine":true})
	return c
