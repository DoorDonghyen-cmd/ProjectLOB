extends RefCounted
## Native current-rule encounter packs. Only case 0 is a naturally reached opening.
## Later packs/decks/parts are explicit controlled comparison fixtures, not a run.
const Campaign=preload("res://redesign/campaign.gd")
const Model=preload("res://redesign/model.gd")
const TITLES := ["첫 교전", "정예 · 비교 구성", "관문 · 비교 구성"]
const PROFILES := ["deadbolt","rewinder","control"]
const SEED := 17

static func build(profile: String, index: int):
	var campaign=Campaign.new()
	campaign.start("burst",SEED,0,"balanced",4,"carrier",true)
	if profile!="control":
		if not Model.WeaponRoles.activate(campaign.model.s,profile): return null
	if index==0:
		if not campaign.advance_departure(true) or not campaign.enter(101): return null
	else:
		var selected: Dictionary={}
		for entry in campaign.current_nodes():
			if (index==1 and entry.get("elite",false)) or (index==2 and entry.kind=="boss"):
				selected=entry;break
		if selected.is_empty(): return null
		campaign.s.parts=["third_striker"]
		campaign.s.equipped_parts=["third_striker"]
		campaign.model.s.deck=["charge","precise_p2","disrupt","bore","cool","basic_p2","basic_p2","basic_p2","basic_p2","basic_p2","charge","precise_p2","disrupt","bore","cool","basic_p2","basic_p2","basic_p2","basic_p2","basic_p2"]
		campaign.s.node=selected.id;campaign.s.floor=selected.floor
		campaign._begin_combat(selected)
	return campaign.model
