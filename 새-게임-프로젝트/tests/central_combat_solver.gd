extends "res://tests/city_combat_solver.gd"
var best_state: Dictionary = {}
var best_path: Array = []

func score(model) -> float:
	# Score the whole finite encounter, including reserves. Slot replacement and
	# a leader reissuing shields must not erase kill credit or farm strip credit.
	var value := 0.0
	for enemy in model.s.enemies + model.s.get("reinforcements", []):
		if int(enemy.hp) <= 0: continue
		value -= float(enemy.hp) * 10.0 + 75.0 + float(enemy.get("barrier", 0)) * 12.0
		value += mini(25.0, float(enemy.distance) / maxi(1, int(enemy.speed))) * 0.5
		value += int(enemy.burn) * 3.0
	for projectile in model.Ranged.active(model.s):
		value -= float(projectile.hp) * 7.0 + 15.0
	value -= model.s.discard.size() * 2.0 + int(model.s.turns) * 0.4
	return value
## Also considers a legal empty reload. The older search always spent an attack
## before waiting, so it could miss opening a closed first gate without wasting ammo.
func solve(model,width:int=4,max_depth:int=18) -> Array:
	best_state=model.s.duplicate(true);best_path=[]
	var beam:Array=[{"model":clone(model),"path":[]}]
	for depth in range(max_depth):
		var next:Array=[]
		var seen:Dictionary={}
		for branch in beam:
			var base=clone(branch.model)
			var prefix:Array=branch.path.duplicate(true)
			if base.s.phase=="ready" and not base.can_emergency_resupply():
				base.reload_magazine();prefix.append({"action":"reload"})
			if base.s.phase in ["reward","won"]:return prefix
			if base.s.phase=="lost":continue
			var waiting=clone(base)
			if waiting.reload_magazine():
				var wait_path:Array=prefix.duplicate(true);wait_path.append({"action":"reload"})
				if waiting.s.phase in ["reward","won"]:return wait_path
				if waiting.s.phase!="lost":next.append({"model":waiting,"path":wait_path,"score":score(waiting)})
			if base.can_emergency_resupply():
				base.emergency_resupply();prefix.append({"action":"emergency"})
				if base.s.phase in ["reward","won"]:return prefix
				if base.s.phase=="lost":continue
			candidates=[];enumerate(base)
			for stack in candidates:
				explored+=1
				var simulation=clone(base)
				var path:Array=prefix.duplicate(true)
				for id in stack:
					simulation.load_round(id);path.append({"action":"load","id":id})
				simulation.confirm();path.append({"action":"confirm"})
				while simulation.s.phase=="ready" and not simulation.s.magazine.is_empty():
					simulation.fire();path.append({"action":"fire"})
					if simulation.s.phase in ["reward","won"]:return path
					if simulation.s.phase=="lost":break
					if score(simulation)>score_state(best_state):
						best_state=simulation.s.duplicate(true);best_path=path.duplicate(true)
					var key:=JSON.stringify([simulation.s.enemies,simulation.s.hand,simulation.s.draw,simulation.s.discard,simulation.s.magazine,simulation.s.rng_state,simulation.s.target_rng_state,simulation.s.buff,simulation.s.push_left,simulation.s.get("reinforcements",[]),simulation.s.get("heat",0),simulation.s.get("sustained_version",0),simulation.s.get("sustained_attacks",0),simulation.s.get("legacy_reload_penalty",0),simulation.s.get("projectiles",[]),simulation.s.get("previous_kill",false),simulation.s.get("gate_charge",0),simulation.s.get("gate_chain",0)])
					if seen.has(key):continue
					seen[key]=true
					next.append({"model":clone(simulation),"path":path.duplicate(true),"score":score(simulation)})
					if next.size()>width*8:
						next.sort_custom(func(a,b):return a.score>b.score);next.resize(width)
		next.sort_custom(func(a,b):return a.score>b.score)
		if next.size()>width:next.resize(width)
		beam=next
		if beam.is_empty():break
	return []

func score_state(state: Dictionary) -> float:
	var model=Model.new();model.s=state
	return score(model)
