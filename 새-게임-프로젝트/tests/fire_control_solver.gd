extends RefCounted
const Model=preload("res://redesign/model.gd")
const Search=preload("res://tests/weapon_magazine_solver.gd")
const Original=preload("res://tests/campaign_magazine_solver.gd")
var candidate_limit:=700
func clone(model):
	var copy=Model.new();copy.s=Model.simulation_state(model.s);return copy
func solve(model,width: int=4,depth_limit: int=18)->Array:
	# Try the original full-pulse option first, then include shorter prefixes.
	var old:=Search.solve(model.s,32,48)
	if not old.is_empty():return old.map(func(a):return {"action":"reload" if a=="swap" else a,"rounds":0})
	var result:=ranged(model.s,maxi(40,width*8),maxi(48,depth_limit*2),false)
	if result.is_empty():result=ranged(model.s,96,72,true)
	if result.is_empty():result=ranged(model.s,384,100,true)
	return result
func ranged(state: Dictionary,width: int,depth_limit: int,ejection: bool)->Array:
	var beam: Array=[{"state":state,"path":[]}]
	for depth in range(depth_limit):
		var next: Array=[];var seen: Dictionary={}
		for branch in beam:
			var base=Model.new();base.s=branch.state
			var options: Array=[]
			for action in Search.actions(base):
				if action=="fire":
					var max_rounds: int=mini(base.s.magazine.size(),int(Model.MagazineTrial.WEAPON_PULSES[base.s.gun])+Model.Roles.pulse_bonus(base.s)+(1 if base.s.gun=="heavy" else 0))
					for amount in range(max_rounds,0,-1):options.append({"action":"fire","rounds":amount})
				else:options.append({"action":action})
			if ejection and base.ejection_remaining()>0:
				for index in range(mini(3,base.s.magazine.size())):options.append({"action":"eject","indices":[index]})
			for option in options:
				var m=clone(base)
				if option.action=="fire":m.s.fire_heat_trial.rounds=int(option.rounds)
				if not (m.eject_magazine_rounds(option.indices) if option.action=="eject" else Search.command(m,option.action)):continue
				var step: Dictionary=option.duplicate(true)
				if step.action=="swap":step.action="reload"
				var path: Array=branch.path+[step]
				if m.s.phase in ["reward","won"]:return path
				if m.s.phase=="lost":continue
				var key:=JSON.stringify([m.s.enemies,m.s.reinforcements,m.s.projectiles,m.s.magazine,m.s.draw,m.s.hand,m.s.discard,m.s.heat,m.s.buff,m.s.push_left,m.s.get("sustained_attacks",0),m.s.previous_kill,m.s.get("engine",{}),m._recent_part_rounds(),m.s.get("emergency_uses",0),m.s.get("magazine_ejected",0),m.s.target_rng_state,m.s.get("gate_chain",0),m.s.get("gate_charge",0),m.s.get("fire_zones",[])])
				if Model.WeaponRoles.enabled(m.s): key+=JSON.stringify([m.s.weapon_role_trial,m.s.rng_state])
				if seen.has(key):continue
				seen[key]=true;next.append({"state":m.s,"path":path,"score":Search.score(m.s)})
		next.sort_custom(func(a,b):return a.score>b.score)
		if next.size()>width:next.resize(width)
		beam=next
		if beam.is_empty():break
	return []
