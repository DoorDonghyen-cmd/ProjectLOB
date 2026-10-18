extends "res://tests/heat_rules_runner.gd"
const Variants = preload("res://redesign/ammo_variants.gd")
var comparisons: Array = []

func snapshot(c) -> Dictionary:
	return JSON.parse_string(JSON.stringify({"campaign":c.s,"combat":c.model.s,"profile":c.profile}))

func orders(available: Array, prefix: Array = []) -> Array:
	var result: Array = [prefix] if not prefix.is_empty() else []
	if prefix.size() >= 4: return result
	for id in available:
		var rest := available.duplicate();rest.erase(id)
		result.append_array(orders(rest,prefix+[id]))
	return result

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/ammo_identity/"): quit(1);return
	var immutable := JSON.stringify(Ammo.AMMO)
	for family in Variants.FAMILIES:
		var prior_heat := 0
		for power in range(1,6):
			var id := Variants.key(family,power)
			check(Ammo.AMMO[id].dmg==power and Ammo.heat_cost(id)>prior_heat,"base power/heat increase together")
			prior_heat=Ammo.heat_cost(id)
			for tune in Variants.TUNES:
				var root_id := Variants.key(family,power,tune)
				check(Ammo.source_id(root_id)==family,"power/modification retains build family")
				check(Ammo.compression_source(Ammo.field_id(root_id))==root_id,"compression remembers exact profile")
				var m=fixture([root_id,root_id],[['runner',1000,0,0,60]])
				m.s.field_compression_left=1
				check(m.field_compress(root_id),"equal profiles compress")
				check(Model.new().restore_state(JSON.parse_string(JSON.stringify(m.s))),"planned profile compression restores")
				check(m.confirm(),"temporary profile confirms")
				check(Model.new().restore_state(JSON.parse_string(JSON.stringify(m.s))),"magazine profile compression restores")
				check(m.fire(),"temporary profile fires")
				check(m.s.field_compression.is_empty() and m.s.deck.count(root_id)==2,"temporary restores original copies")
				check(Model.new().restore_state(JSON.parse_string(JSON.stringify(m.s))),"fired profile compression conserves inventory")
				m=fixture([root_id,root_id]);m.s.field_compression_left=1
				m.field_compress(root_id)
				check(m.undo() and m.s.hand.count(root_id)==2 and m.s.field_compression_left==1,"undo returns exact copies and charge")
			for gun in Ammo.GUNS:
				var m=fixture([id,'charge'],[['runner',1000,2,0,60]],gun)
				fire(m,['charge',id])
	var mixed=fixture(['pierce_p2','pierce_p3']);mixed.s.field_compression_left=1
	check(not mixed.field_compress('pierce_p2'),"different powers cannot be silently merged")
	var c=Campaign.new();c.start('single',731042,0,'balanced',1)
	c.s.floor=3;c.s.node=301;c.s.visited=[101,201,301]
	check(c.enter(401),'legal shop entry')
	c.s.credits=100
	c.model.s.deck=['basic_p2','basic_p2','pierce_p2','pierce_p2','precise_p2','precise_p2','charge','charge','cool','cool']
	check(c.tune(0,'power') and c.model.s.deck.count('basic_p2')==1 and c.model.s.deck.count('basic_p2_power')==1 and c.s.credits==88,'tune affects exactly one copy at stated price')
	check(not c.tune(1,'cool') and c.s.credits==88,'one service per visit')
	check(c.save('user://identity_shop.json')==OK,'atomic shop save')
	var restored=Campaign.new()
	check(restored.restore('user://identity_shop.json') and restored.s.shop_tuned and not restored.tune(1,'cool'),'service lock and exact deck survive restore')
	check(c.reroll() and not c.tune(1,'cool'),'reroll cannot reset service')
	c.s.shop_tuned=false
	check(not c.tune(0,'cool') and not c.tune(-1,'power') and not c.tune(100,'power') and not c.tune(1,'bad'),'reject retune and invalid commands')
	check(c.tune(2,'cool') and c.model.s.deck.count('pierce_p2_cool')==1,'cooling changes one copy')
	check(c.shop_compress('precise_p2') and c.model.s.deck.has('precise_p2_c'),'permanent compression is separate service')
	check(c.save('user://identity_shop.json')==OK and restored.restore('user://identity_shop.json'),'compressed and tuned collection persists')
	for version in [0,1,2]:
		var old := snapshot(c);old.campaign.discovery_version=version
		check(Campaign.new().restore_state(old),'supported discovery revision restores')
	for outfit in Ammo.OUTFITS:
		for gun in Ammo.GUNS:
			var campaign=Campaign.new();campaign.start(gun,731042,0,'balanced',Data.RouteMap.VERSION,outfit)
			check(campaign.enter(int(campaign.choices()[0].id)), 'profile campaign opening')
			check(Campaign.new().restore_state(snapshot(campaign)), 'new starter restores at supported hand size')
	# No false history accumulation across reloads; the actual single-shot gun uses the same last-attack context.
	var chamber=fixture(['basic_p1','pierce_p1'],[['runner',1000,0,0,60]],'amplifier')
	chamber.s.equipped_parts=['ordinary_chain']
	var first := fire(chamber,['basic_p1','pierce_p1'])
	check(first[0].ordinary_bonus==0 and chamber.fire() and chamber.s.history.back().detail.results[0].ordinary_bonus==2,'single-shot weapon carries sequence until final attack')
	check(chamber.reload_magazine(),'reload after final attack')
	chamber.s.hand=['basic_p1'];chamber.s.draw=chamber.s.deck.duplicate();chamber.s.draw.erase('basic_p1');chamber.s.discard=[]
	var reset := fire(chamber,['basic_p1'])
	check(reset[0].ordinary_bonus==0,'reload resets family bonus')
	var seen: Array=[]
	for depth in [1,2,3,5,8]:
		var node := {'id':depth*100+1,'region':0,'floor':depth,'kind':'shop','elite':false}
		for seed_value in range(100):
			var rewards := Data.rewards(node,seed_value,c.model.s.deck,['ordinary_chain'],2)
			check(rewards==Data.rewards(node,seed_value,c.model.s.deck,['ordinary_chain'],2),'profile rewards deterministic')
			var stock := Data.offers(node,seed_value,0,'single',[],[],[],[],2)
			for id in rewards+[stock[0].id]:
				check(Ammo.source_id(id) not in ['sequence','prepare','disrupt'],'retired roles absent from new acquisition')
				if Ammo.AMMO[id].get('profile',false):
					check(int(Ammo.AMMO[id].power)<= (3 if depth<5 else 5),'opening excludes high-power profiles')
					if not seen.has(id): seen.append(id)
	check(seen.size()==15,'all fifteen untuned profiles can be discovered')
	for setup in [[['basic_p1','pierce_p1','precise_p1','cool'],4],[['basic_p1','basic_p2','basic_p3'],0]]:
		var m=fixture(setup[0],[['runner',1000,0,0,60]])
		m.s.equipped_parts=['ordinary_chain']
		var shots := fire(m,setup[0])
		var bonus := 0
		for shot in shots: bonus+=int(shot.get('ordinary_bonus',0))
		check(bonus==setup[1],'last attack counts families, not ranks; trailing support excluded')
	# Same hand, target and hot-state budget. Enumerate legal actions instead of handpicking a winner.
	var hand: Array=['basic_p1','basic_p5','precise_p1','pierce_p4','charge']
	var candidates := orders(hand)
	for core in ['volley_drive','thermal_drive','siege_drive']:
		var best := {'core':core,'damage':-1,'order':[],'peak':0}
		for order in candidates:
			var m=fixture(hand,[['runner',1000,0,0,60]])
			m.s.equipped_parts=[core];m.s.engine.levels[core]=4
			if not Ammo.valid_stack(order,m.capacity()): continue
			var accepted:=true
			for id in Ammo.loading_order(order):
				if not m.load_round(id): accepted=false;break
			if not accepted or not m.confirm() or not m.fire(): continue
			var detail: Dictionary=m.s.history.back().detail
			if not detail.forced_reload.is_empty(): continue
			var damage:=1000-int(m.s.enemies[0].hp)
			if damage>int(best.damage): best={'core':core,'damage':damage,'order':order,'peak':detail.heat_peak}
		comparisons.append(best)
	check(comparisons[0].order!=comparisons[2].order,'same hand favors different legal selections under different cores')
	check(JSON.stringify(Ammo.AMMO)==immutable,'play and modifications never mutate shared definitions')
	var file=FileAccess.open(OS.get_environment('QA_OUTPUT_DIR').path_join('comparisons.json'),FileAccess.WRITE)
	file.store_string(JSON.stringify(comparisons,'  '));file.close()
	print('AMMO IDENTITY RULES COMPLETE checks=%d failures=%d' % [checks,failures])
	quit(0 if failures==0 else 1)
