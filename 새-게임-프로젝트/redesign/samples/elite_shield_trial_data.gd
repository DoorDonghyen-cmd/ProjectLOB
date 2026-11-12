extends RefCounted

const Campaign = preload("res://redesign/campaign.gd")
const Data = preload("res://redesign/campaign_content.gd")
const House = preload("res://redesign/noble_house.gd")
const Setup = preload("res://redesign/samples/campaign_trial_setup.gd")
const ROUNDS := ["basic_p2", "basic_p2", "pierce", "precise", "pierce", "basic_p2"]

static func enter_elite(gun: String = "single") -> RefCounted:
	var campaign = Campaign.new()
	campaign.start(gun, 731042, 0, "balanced", Data.RouteMap.VERSION, "carrier", true)
	for region in range(3):
		campaign.s.region = region
		var prior := Setup.path_to(campaign.current_nodes(), func(room): return room.kind == "boss")
		if prior.is_empty(): return null
		campaign.s.visited.append_array(prior)
	campaign.s.region = 3
	var route := Setup.path_to(campaign.current_nodes(), func(room): return room.kind == "combat" and bool(room.get("elite", false)))
	if route.is_empty(): return null
	if route.size() > 1:
		campaign.s.visited.append_array(route.slice(0, -1))
		campaign.s.node = route[-2]
		campaign.s.floor = campaign.node().floor
	if not campaign.enter(int(route.back())): return null
	return campaign

static func make(variant: String, rounds: Array = ROUNDS, gun: String = "single") -> RefCounted:
	var campaign := enter_elite(gun)
	if campaign == null: return null
	var model = campaign.model
	var elite := Data._enemy(House.unit(House.ELITE, 18, 19))
	elite.shield_trial = variant
	if variant == House.PIERCE_ONLY: elite.shield_open_left = House.SHIELD_OPEN_DELAY
	model.s.enemies = [elite, Data._enemy(House.unit(House.LABOR, 7, 24))]
	model.s.reinforcements = []
	model.s.encounter_total = model.s.enemies.size()
	model.s.deployed = model.s.enemies.size()
	model.assign_opening_lanes()
	Setup.load_magazine(model, rounds)
	return campaign
