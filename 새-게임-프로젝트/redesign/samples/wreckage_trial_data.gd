extends RefCounted

const Campaign = preload("res://redesign/campaign.gd")
const Data = preload("res://redesign/campaign_content.gd")
const Workers = preload("res://redesign/foundry_workers.gd")
const Wreckage = preload("res://redesign/wreckage.gd")
const Setup = preload("res://redesign/samples/campaign_trial_setup.gd")
const ROUNDS := ["basic_p2", "basic_p2", "pierce", "basic_p2", "precise", "basic_p2"]

static func make(gun: String = "single", rounds: Array = ROUNDS) -> RefCounted:
	var campaign = Campaign.new()
	campaign.start(gun, 731042, 0, "balanced", Data.RouteMap.VERSION, "carrier", true)
	# A synthetic but legal visited prefix lets the trial use normal campaign saves.
	campaign.s.visited = Setup.path_to(campaign.current_nodes(), func(room): return room.kind == "boss")
	if campaign.s.visited.is_empty(): return null
	campaign.s.region = 1
	var rooms: Array = campaign.choices().filter(func(room): return room.kind == "combat")
	if rooms.is_empty() or not campaign.enter(int(rooms[0].id)): return null
	var model = campaign.model
	model.s.enemies = [Data._enemy(Workers.worker(Wreckage.SPECIES, 2, 12)), Data._enemy(Workers.worker("ash_catcher", 11, 20))]
	model.s.enemies[0].wreckage = -1
	model.s.reinforcements = []
	model.s.encounter_total = model.s.enemies.size()
	model.s.deployed = model.s.enemies.size()
	model.assign_opening_lanes()
	Setup.load_magazine(model, rounds)
	return campaign
