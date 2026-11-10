extends RefCounted
const Model=preload("res://redesign/model.gd")
const Search=preload("res://tests/weapon_magazine_solver.gd")
var candidate_limit:=700
func clone(model):
 var result=Model.new();result.s=Model.simulation_state(model.s);return result
func solve(model,width:=4,depth_limit:=18)->Array:
 var path:=_solve_once(model,width,depth_limit)
 # Magazine build v2 fights span several magazines; give shallow searches one deeper retry.
 if path.is_empty() and width<DEEP_WIDTH:path=_solve_once(model,DEEP_WIDTH,DEEP_DEPTH)
 return path

const DEEP_WIDTH:=24
const DEEP_DEPTH:=40
func _solve_once(model,width:int,depth_limit:int)->Array:
 var path:=Search.solve(model.s,maxi(32,width*8),maxi(48,depth_limit*2))
 if path.is_empty():return solve_with_ejection(model.s,maxi(48,width*8),maxi(48,depth_limit*2))
 return path.map(func(action):return {"action":"reload" if action=="swap" else action})

func solve_with_ejection(state: Dictionary,width: int,depth_limit: int)->Array:
 var beam: Array=[{"state":state,"path":[]}]
 for depth in range(depth_limit):
  var next: Array=[];var seen: Dictionary={}
  for branch in beam:
   var base=Model.new();base.s=branch.state
   var options: Array=Search.actions(base).map(func(action):return {"action":action})
   if base.ejection_remaining()>0:
    # Only advance the imminent pulse; removing later rounds has no immediate
    # benefit and can be deferred until they reach the front.
    for index in range(mini(3,base.s.magazine.size())):
     options.append({"action":"eject","indices":[index]})
   for option in options:
    var trial=Model.new();trial.s=Model.simulation_state(base.s)
    var accepted: bool=trial.eject_magazine_rounds(option.indices) if option.action=="eject" else Search.command(trial,option.action)
    if not accepted:continue
    var step: Dictionary=option.duplicate(true)
    if step.action=="swap":step.action="reload"
    var path: Array=branch.path+[step]
    if trial.s.phase in ["won","reward"]:return path
    if trial.s.phase=="lost":continue
    var key:=JSON.stringify([trial.s.enemies,trial.s.reinforcements,trial.s.projectiles,trial.s.magazine,trial.s.draw,trial.s.hand,trial.s.discard,trial.s.heat,trial.s.buff,trial.s.push_left,trial.s.get("sustained_attacks",0),trial.s.previous_kill,trial.s.get("engine",{}),trial._recent_part_rounds(),trial.s.get("emergency_uses",0),trial.s.get("magazine_ejected",0),trial.s.get("target_rng_state","")])
    if seen.has(key):continue
    seen[key]=true
    next.append({"state":trial.s,"path":path,"score":Search.score(trial.s)})
  next.sort_custom(func(a,b):return a.score>b.score)
  if next.size()>width:next.resize(width)
  beam=next
  if beam.is_empty():break
 return []
