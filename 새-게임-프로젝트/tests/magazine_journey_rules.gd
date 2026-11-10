extends SceneTree
const Journey=preload("res://redesign/magazine_journey.gd")
const Model=Journey.Model
const Solver=preload("res://tests/weapon_magazine_solver.gd")
const Forecast=preload("res://redesign/forecast.gd")
var checks:=0
var failures: Array=[]
var runs: Array=[]
var natural_options: Array=[]
var out:=""
func _initialize():call_deferred("run")
func check(ok: bool,message: String)->bool:
 checks+=1
 if not ok:failures.append(message);push_error(message)
 return ok
func canonical(value):return JSON.parse_string(JSON.stringify(value))
func roundtrip(j)->void:
 check(j.save()==OK,"Atomic journey save")
 var restored=Journey.new()
 check(restored.restore(),"All current phases restore: "+j.phase())
 if restored.campaign.s.is_empty():return
 check(canonical(j.data())==canonical(restored.data()),"Campaign, combat, ownership and RNG survive resume")
 check(canonical(j.entry)==canonical(restored.entry) and canonical(j.results)==canonical(restored.results),"Retry and telemetry survive resume")
func sample_options(j,gun: String)->void:
 var m=j.campaign.model
 if m.s.magazine.size()<3 or Journey.Ammo.AMMO[m.s.magazine[0]].effect!="boost":return
 var prediction: Dictionary=Forecast.analyze(m.s,true)
 for i in range(1,m.s.magazine.size()-1):
  var copy=Model.new();copy.s=Model.simulation_state(m.s)
  if not copy.eject_magazine_rounds([i]):continue
  var alternative: Dictionary=Forecast.analyze(copy.s,true)
  if prediction.get("shots",[]).size()<2 or alternative.get("shots",[]).size()<2:continue
  var first: Dictionary=prediction.shots[0]
  if first.get("boost_granted",0)>0 and alternative.shots[1].get("damage",0)!=prediction.shots[1].get("damage",0):
   natural_options.append({"gun":gun,"node":j.campaign.s.node,"magazine":m.s.magazine.duplicate(),"removed":i,"before_damage":prediction.shots[1].get("damage",0),"after_damage":alternative.shots[1].get("damage",0),"note":"Natural earned order; next-shot comparison, not a winning or optimal policy."})
func play(gun: String,policy: int)->void:
 var j=Journey.new();check(j.start(gun),"Fresh opt-in journey")
 var battles: Array=[]
 var preferred: String={"single":"siege_drive","burst":"volley_drive","scatter":"volley_drive","heavy":"thermal_drive","amplifier":"siege_drive"}[gun]
 for iteration in range(40):
  roundtrip(j)
  if j.phase()=="complete":break
  if j.phase()=="combat":
   var m=j.campaign.model
   check(m.s.deck.size()==m.s.magazine.size()+m.s.draw.size()+m.s.hand.size(),"All owned ammo restored on entry")
   if not j.results.is_empty():check(j.results.back().growth.levels==m.s.engine.levels,"Earned core levels persist into next fight")
   check(m.s.discard.is_empty() and m.ejection_remaining()==2,"Used and ejected ammo reset only for new encounter")
   check(not j.advance() and not j.choose("charge") and not j.skip(),"Cannot skip live combat or earn an unearned reward")
   sample_options(j,gun)
   var initial: Dictionary=m.s.duplicate(true)
   var path: Array=Solver.solve(m.s,48,32)
   battles.append({"node":j.campaign.s.node,"path":path,"deck":m.s.deck.duplicate(),"parts":j.campaign.s.equipped_parts.duplicate()})
   if not check(not path.is_empty(),"Earned path exists "+gun+"/"+str(policy)+"/"+str(j.campaign.s.node)):break
   for action in path:
    var before:=JSON.stringify(m.s)
    var expected: Dictionary=Forecast.analyze(m.s,true) if action=="fire" else {}
    check(JSON.stringify(m.s)==before,"Forecast does not touch live state or RNG")
    check(Solver.command(m,action),"Actual solver command is legal")
    if action=="fire" and gun!="scatter":
     check(expected.enemies==m.s.enemies and expected.projectiles==m.s.projectiles and expected.phase==m.s.phase,"Forecast matches exact next action")
    j.sync();roundtrip(j)
    if j.phase()=="combat":sample_options(j,gun)
   check(j.phase()=="reward","Combat win yields a real reward")
   check(not j.retry(),"Cannot replay a won fight to duplicate rewards")
   if policy==0:FileAccess.open(out.path_join("checkpoint_%s_%d.json"%[gun,int(j.campaign.s.node)]),FileAccess.WRITE).store_string(JSON.stringify({"initial":initial,"path":path,"journey":JSON.parse_string(FileAccess.get_file_as_string(Journey.SAVE))}))
  elif j.phase() in ["reward","supply"]:
   var choices: Array=j.options()
   check(not choices.is_empty(),"Real reward/service options exist")
   var id: String=choices[policy%choices.size()]
   if j.campaign.engine_reward():id=preferred
   var deck: Array=j.campaign.model.s.deck.duplicate()
   var replacement:=j.replacement(id)
   check(not j.choose("not_a_reward"),"Invalid reward rejected")
   if j.campaign.engine_reward() or j.campaign.first_ammo_reward():check(not j.skip(),"Required opening choices cannot silently disappear")
   check(j.choose(id),"Earn the selected reward")
   if Journey.Ammo.AMMO.has(id):
    if not replacement.is_empty():deck[deck.find(replacement)]=id
    else:deck.append(id)
    check(deck==j.campaign.model.s.deck,"Only selected card changes ownership")
   else:check(j.campaign.s.equipped_parts.has(id),"Selected core actually equips")
   check(not j.choose(id),"Same selection cannot be applied twice")
  elif j.phase()=="map":check(j.advance(),"Follow only legal route links")
  else:check(false,"Unexpected journey phase "+j.phase());break
 check(j.phase()=="complete" and j.results.size()==5,"Five won fights reach first gate "+gun+"/"+str(policy))
 check(j.campaign.s.visited==Journey.ROUTE,"Campaign provenance retains connected real route")
 runs.append({"gun":gun,"policy":policy,"complete":j.phase()=="complete","battles":battles,"results":j.results,"acquisitions":j.acquisitions,"growth":j.campaign.model.s.get("engine",{})})
func boundaries()->void:
 var j=Journey.new();check(j.start("single"),"Boundary run starts")
 var opening: Dictionary=canonical(j.data())
 check(j.campaign.model.eject_magazine_rounds([1]),"Real middle ejection")
 check(j._ejected(j.campaign.model.s,j.entry.combat)==1,"Ejection telemetry uses real recorded rounds")
 roundtrip(j)
 check(j.retry() and canonical(j.data())==opening,"Retry restores exact entry before ejection")
 check(j.campaign.model.fire(),"Real shot before retry")
 check(j.retry() and canonical(j.data())==opening,"Retry restores all original RNG and budgets")
 for i in range(60):
  if j.phase()!="combat":break
  if j.campaign.model.s.heat>0:j.campaign.model.cool_magazine()
  else:j.campaign.model.reload_magazine()
  j.sync()
 check(j.phase()=="lost","Waiting for real enemy produces loss")
 roundtrip(j)
 check(j.retry() and canonical(j.data())==opening and j.results.is_empty(),"Defeat retry reverses settlement and stale result")
 j.save();var good: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Journey.SAVE))
 for mutation in ["version","seed","route","entry","results"]:
  var bad:=good.duplicate(true)
  match mutation:
   "version":bad.version=2
   "seed":bad.current.campaign.seed="17"
   "route":bad.current.campaign.visited=[102]
   "entry":bad.entry.combat.gun="heavy"
   "results":bad.results=[{}]
  check(not Journey.new().restore_state(bad),"Corrupt journey rejected: "+mutation)
 var old=load("res://../qa_runtime/magazine_journey_20261031/source_before/새-게임-프로젝트/redesign/campaign.gd")
 for gun in Journey.Ammo.GUNS:
  var before=old.new();before.start(gun,731042)
  var after=Journey.Campaign.new();after.start(gun,731042)
  check(before.save("user://legacy_before.json")==OK and after.save("user://legacy_after.json")==OK,"Original and refactored save succeed")
  check(canonical(JSON.parse_string(FileAccess.get_file_as_string("user://legacy_before.json")))==canonical(JSON.parse_string(FileAccess.get_file_as_string("user://legacy_after.json"))),"Legacy serialization is unchanged")
  check(not Model.MagazineTrial.enabled(after.model.s),"Main campaign remains unmodified")
func run()->void:
 out=OS.get_environment("QA_OUTPUT_DIR")
 if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/magazine_journey_20261031/"):quit(2);return
 boundaries()
 for gun in Journey.Ammo.GUNS:
  for policy in range(3):play(gun,policy)
 FileAccess.open(out.path_join("rules.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"runs":runs,"natural_ejection_options":natural_options,"note":"Fixed route seed 731042. Bounded hidden-RNG search shows feasibility, not human win rate or balanced reward choices."},"  "))
 print("JOURNEY RULES COMPLETE checks=%d failures=%d runs=%d natural_options=%d"%[checks,failures.size(),runs.size(),natural_options.size()]);quit(0 if failures.is_empty() else 1)

