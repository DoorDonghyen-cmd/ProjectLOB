extends "res://tests/fire_heat_rules.gd"
const Search=preload("res://tests/weapon_magazine_solver.gd")
const MODES:=[
	{"name":"baseline","input":"fixed","reload":"legacy","damage":false},
	{"name":"range_only","input":"range","reload":"legacy","damage":false},
	{"name":"keep_heat","input":"range","reload":"none","damage":false},
	{"name":"small_cool","input":"range","reload":"small","damage":false},
	{"name":"heat_damage","input":"range","reload":"none","damage":true}]
func choices(m)->Array:
	var result: Array=[]
	for action in Search.actions(m):
		if action=="fire" and Trial.range_enabled(m.s):
			var maximum: int=mini(m.s.magazine.size(),int(Model.MagazineTrial.WEAPON_PULSES[m.s.gun])+(1 if m.s.gun=="heavy" else 0))
			for budget in range(maximum,0,-1):result.append({"action":"fire","budget":budget})
		else:result.append({"action":action})
	return result
func execute(m,option: Dictionary)->bool:
	if option.action=="fire":m.s.fire_heat_trial.rounds=int(option.get("budget",0))
	return Search.command(m,option.action)
func solve_trial(state: Dictionary,width: int=24,depth_limit: int=36)->Array:
	var beam: Array=[{"state":state,"path":[]}]
	for depth in range(depth_limit):
		var next: Array=[];var seen: Dictionary={}
		for branch in beam:
			var base=Model.new();base.s=branch.state
			for option in choices(base):
				var m=Model.new();m.s=Model.simulation_state(base.s)
				if not execute(m,option):continue
				var path: Array=branch.path+[option]
				if m.s.phase in ["won","reward"]:return path
				if m.s.phase=="lost":continue
				var key:=JSON.stringify([m.s.enemies,m.s.reinforcements,m.s.projectiles,m.s.magazine,m.s.draw,m.s.hand,m.s.discard,m.s.heat,m.s.buff,m.s.push_left,m.s.get("sustained_attacks",0),m.s.previous_kill,m.s.get("engine",{}),m._recent_part_rounds(),m.s.get("emergency_uses",0),m.s.target_rng_state])
				if seen.has(key):continue
				seen[key]=true
				next.append({"state":m.s,"path":path,"score":Search.score(m.s)})
		next.sort_custom(func(a,b):return a.score>b.score)
		if next.size()>width:next.resize(width)
		beam=next
		if beam.is_empty():break
	return []
func damage_total(state: Dictionary)->int:
	var total:=0
	for enemy in state.enemies+state.reinforcements:total+=int(enemy.hp)
	return total
func compare_hot_choices(state: Dictionary)->void:
	# The state is reached by actual inputs from an earned checkpoint.
	if state.phase!="ready" or state.heat<=0:return
	var rows: Array=[]
	for mode in MODES:
		var m=model(state,mode.reload,mode.damage,mode.input)
		for option in choices(m):
			var copy=Model.new();copy.s=m.s.duplicate(true)
			if not execute(copy,option):continue
			rows.append({"mode":mode.name,"option":option,"heat":copy.s.heat,"streak":Content.Sustained.count(copy.s),"turns":copy.s.turns-state.turns,"phase":copy.s.phase,"damage":damage_total(state)-damage_total(copy.s),"remaining":copy.s.magazine.size()})
	records.append({"kind":"same_hot_state","gun":state.gun,"node":state.encounter_id,"start_heat":state.heat,"start_streak":Content.Sustained.count(state),"state":state.duplicate(true),"options":rows})
func run()->void:
	if not setup():return
	for row in openings:
		for mode in MODES:
			var m=model(row.state,mode.reload,mode.damage,mode.input)
			var path:=solve_trial(m.s)
			if path.is_empty():path=solve_trial(m.s,64,60)
			var heat_penalized:=0;var hot_sample:=false
			var actions: Dictionary={}
			var initial_turns: int=m.s.turns
			for option in path:
				if mode.name=="baseline" and not hot_sample and m.s.heat>=ceili(Content.heat_limit(m.s)*0.5):
					compare_hot_choices(m.s);hot_sample=true
				check(execute(m,option),"searched path replays as legal command")
				actions[option.action]=int(actions.get(option.action,0))+1
				if option.action=="fire":
					for shot in m.s.history.back().detail.results:
						if int(shot.math.get("heat_percent",100))<100:heat_penalized+=1
			var won: bool=m.s.phase in ["won","reward"]
			check(won,"comparison fixture has a legally replayed winning path")
			records.append({"kind":"route","gun":row.gun,"node":row.node,"mode":mode.name,"won":won,"turns":int(m.s.turns)-initial_turns,"spent":m.s.discard.size(),"actions":actions,"penalized":heat_penalized,"path":path})
			print("MATRIX ",row.gun," ",row.node," ",mode.name," won=",won," turns=",int(m.s.turns)-initial_turns)
			# Search bounds are disclosed; a failed search is not proof of no solution.
			FileAccess.open(output.path_join("progress.json"),FileAccess.WRITE).store_string(JSON.stringify(records,"  "))
			await process_frame
	finish()
