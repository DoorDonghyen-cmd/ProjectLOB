extends "res://tests/focus_build_rules.gd"
const Roles=preload("res://redesign/combat_roles.gd")
func modern(rounds: Array,parts: Array=[],gun: String="single"):
 var m=fixture(rounds,parts,gun)
 m.s.combat_roles_version=1;m.s.fire_zones=[]
 return m
func targets(m,count: int,hp: int=1,spacing: int=1)->void:
 var source: Dictionary=m.s.enemies[0].duplicate(true)
 m.s.enemies=[]
 for i in range(count):
  var e: Dictionary=source.duplicate(true);e.hp=hp;e.distance=1000+i*spacing;e.lane=i;m.s.enemies.append(e)
 m.s.encounter_total=count;m.s.deployed=count
func run()->void:
 output=OS.get_environment("QA_OUTPUT_DIR")
 if not output.replace("\\","/").contains("/qa_runtime/playtest_rework_20261103/"):quit(2);return
 for core in ["siege_drive","volley_drive"]:
  for investment in range(3):
   var m=modern(["basic_p3" if core=="siege_drive" else "precise_p2"],[core,"duplex"])
   targets(m,4);m.s.gate_mods.conduction=investment if investment>0 else 1
   if investment==0:m.s.gate_mods.erase("conduction")
   var r:=shot(m)
   var reached: Array=[]
   for event in r.secondary:
    if not reached.has(event.target):reached.append(event.target)
   check(reached.size()<=1+investment,"relay distinct target ceiling "+core)
   if investment==0:check(reached.size()==1 and m.alive_count()==2,"base relay leaves two of four enemies")
   records.append({"core":core,"investment":investment,"targets":reached,"main_damage":r.damage})
 var fire=modern(["bore","basic_p2"])
 targets(fire,3,30,2)
 var r:=shot(fire)
 check(fire.s.enemies[1].hp==28 and fire.s.enemies[2].hp==30,"ground fire only reaches targets inside its distance interval")
 check(fire.s.fire_zones.size()==1 and fire.s.fire_zones[0].left==1,"first enemy action consumes one of two fire ticks")
 check(r.fire_zones[0].left==2,"impact receipt retains initial flame duration")
 var before_hp: int=fire.s.enemies[0].hp
 check(fire.cool_magazine(),"cooling advances persistent ground fire")
 check(fire.s.fire_zones.is_empty() and before_hp-fire.s.enemies[0].hp==2,"ground and attached burn never double-stack")
 restore_check(fire)
 var ignite=modern(["bore","basic_p2"],["inferno","coil"])
 var strong:=shot(ignite)
 check(strong.fire_zones[0].left==4 and strong.fire_zones[0].damage==4,"fire core and coil change duration and zone damage")
 var slow=modern(["disrupt","basic_p2"])
 slow.s.enemies[0].speed=4
 var blocked:=shot(slow)
 check(blocked.slowed==2 and slow.s.enemies[0].distance==998 and slow.s.enemies[0].slow_left==1,"disrupt slows ordinary approach on first enemy action")
 slow.cool_magazine();check(slow.s.enemies[0].distance==996 and slow.s.enemies[0].slow_left==0,"slow expires after its second action")
 check(Roles.slow(slow.s.enemies[0],2)==0,"same enemy cannot be slowed indefinitely")
 restore_check(slow)
 for gun in Content.GUNS:
  var a=modern(["basic_p1","basic_p1","basic_p1","basic_p1","basic_p1"],[],gun)
  a.s.fire_heat_trial.rounds=0;a.s.gate_mods={"cadence":2,"efficiency":2}
  var base:=int(Model.MagazineTrial.WEAPON_PULSES[gun])
  check(Model.MagazineTrial.pulse(a.s)==base+2,"investment raises actual weapon firing ceiling "+gun)
  check(Content.heat_delta("charge_hot",a.s)==3,"heat card advertises reduced base cost")
  var fired:=verify_fire(a)
  if gun not in ["heavy","amplifier"]:check(fired.results.size()==mini(5,base+2),"extra selected rounds really fire "+gun)
 for outfit in Content.OUTFITS:
  var c=Campaign.new();c.start("single",21,0,"balanced",4,outfit,true)
  check(c.minimum_deck()==Roles.MINIMUM[outfit] and c.model.deck_limit()==Roles.CARRY[outfit],"outfit bounds match new-run rules")
  var saved: Dictionary={"campaign":c.s,"combat":c.model.s,"profile":c.profile}
  var restored=Campaign.new();check(restored.restore_state(canonical(saved)),"every outfit new run saves")
  for upgrade in range(3):
   c.s.region=upgrade
   check(c.can_grow_bag(),"each outfit may invest in storage independent of old hand size")
   c._grow_bag();restore_check(c.model)
  check(not c.can_grow_bag() and c.model.deck_limit()==Roles.CARRY[outfit]+6,"three storage investments cap every outfit")
 var fresh=Campaign.new();fresh.start("burst",21,0,"balanced",4,"carrier",true)
 fresh.s.combat_roles_version=1;fresh.model.s.combat_roles_version=1 # Historical investment contract; current compatible-core filter is tested separately.
 for id in ["cadence","efficiency","conduction"]:
  check(Model.Gates.options(fresh.model.s).has(id),"new investment offered "+id)
  var state: Dictionary=fresh.model.s.duplicate(true);state.gate_mods[id]=2
  check(Model.Gates.valid(state),"new investment save validates")
  state.erase("combat_roles_version");check(not Model.Gates.valid(state),"old run cannot silently gain new investment")
 check(Focus.opening_options(fresh.model.s).has("bore") and Focus.opening_options(fresh.model.s).has("arc"),"area and control packages are accessible at first reward")
 check(Focus.package("bore")==["bore","bore","disrupt"],"incendiary package supplies approach control")
 var amplifier=Campaign.new();amplifier.start("amplifier",21,0,"balanced",4,"carrier",true)
 check(not Model.Gates.options(amplifier.model.s).has("cadence"),"kill-chain gun never offers a no-effect firing-cap investment")
 var bad: Dictionary=fresh.model.s.duplicate(true);bad.fire_zones=[{"center":1,"radius":2,"left":99,"damage":2}]
 check(not Model.new().restore_state(bad),"malformed zone rejected")
 bad=fresh.model.s.duplicate(true);bad.enemies[0].slow_left=2
 check(not Model.new().restore_state(bad),"slow without usage flag rejected")
 # Historical exact-resolver comparison uses the recorded source before this change.
 var legacy_script=load("res://../qa_runtime/playtest_rework_20261103/before/새-게임-프로젝트/redesign/model.gd")
 for gun in ["single","burst","scatter","heavy","amplifier"]:
  var m=fixture(["bore","disrupt","precise_p2","basic_p2"],["volley_drive"],gun)
  var old=legacy_script.new();check(old.restore_state(canonical(m.s)),"old model restores fixture")
  for action in ["fire","cool_magazine","fire"]:
   check(old.call(action)==m.call(action) and canonical(old.s)==canonical(m.s),"historical combat result unchanged "+gun+"/"+action)
 FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"records":records},"  "))
 print("PLAYTEST REWORK COMPLETE checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
