extends "res://tests/campaign_magazine_rules.gd"
var covered: Dictionary={}
func clone_campaign(c):
 var copy=Campaign.new()
 check(copy.restore_state(JSON.parse_string(JSON.stringify({"campaign":c.s,"combat":c.model.s,"profile":c.profile}))),"branch restores from earned campaign")
 return copy
func branch_checks(c)->void:
 if c.s.phase=="shop" and not covered.has("shop"):
  var copy=clone_campaign(c)
  var credits: int=copy.s.credits
  check(not copy.buy_compressor_charge() and copy.s.credits==credits,"removed service cannot spend money")
  check(copy.reroll(),"new magazine shop reroll")
  check(not copy.s.offers.any(func(o):return o.id in ["reserve","field_press"]),"reroll excludes manual-only modules")
  roundtrip(copy);covered.shop=true
 if c.s.phase=="supply" and c.node().get("workshop",false) and not covered.has("compression"):
  var copy=clone_campaign(c)
  var options: Array=copy.compressible_ids()
  if not options.is_empty():
   var id: String=options[0];var count: int=copy.model.s.deck.size()
   check(copy.resolve("compress",id),"permanent workshop compression remains available")
   check(copy.model.s.deck.size()==count-1 and copy.model.s.deck.has(Ammo.compressed_id(id)),"compression conserves two originals as one advanced round")
   roundtrip(copy);covered.compression=true
 if c.s.phase!="map" or covered.has("ambush"):return
 for option in c.choices():
  if option.kind!="event":continue
  for choice in Campaign.Encounters.scene(option.event).choices:
   if Campaign.Encounters.outcome(option.event,choice.id,int(c.s.seed),int(option.id)).get("type","")!="combat":continue
   if int(c.s.credits)<int(choice.cost):continue
   var copy=clone_campaign(c)
   check(copy.enter(int(option.id)),"legal event branch entry")
   check(copy.resolve("encounter",choice.id),"event reveals ambush")
   check(copy.resolve("fight"),"event starts magazine encounter")
   check(copy.model.s.phase=="ready" and not copy.model.s.magazine.is_empty(),"ambush automatically loads whole magazine")
   roundtrip(copy)
   snapshot(copy,"ambush_opening")
   var path: Array=solver.solve(copy.model,4,18)
   check(not path.is_empty(),"earned event fight has legal victory path")
   for step in path:command(copy,step)
   check(copy.s.phase=="reward" and copy.s.encounter.stage=="cleared","event victory joins main reward flow")
   covered.ambush=true;return

func _run()->void:
 if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/campaign_magazine_20261101/"):quit(2);return
 output=OS.get_environment("QA_OUTPUT_DIR")
 solver=preload("res://tests/campaign_magazine_solver.gd").new()
 var report: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(output.get_base_dir().path_join("rules/balance.json")))
 var route: Array=[]
 for endpoint in report.endpoints:
  if endpoint.gun=="single" and endpoint.won:route=endpoint.commands;break
 check(not route.is_empty(),"verified full route available")
 var c=Campaign.new();c.start("single",731042,0,"balanced",3,"carrier",true)
 for step in route:
  branch_checks(c)
  command(c,step.duplicate(true))
  if covered.size()==3:break
 check(covered.has("shop") and covered.has("compression") and covered.has("ambush"),"shop workshop and event combat covered")
 var invalid=JSON.parse_string(JSON.stringify({"campaign":c.s,"combat":c.model.s,"profile":c.profile}))
 invalid.combat.weapon_magazine_version=0
 check(not Campaign.new().restore_state(invalid),"mismatched campaign/combat rule flags rejected")
 var file=FileAccess.open(output.path_join("result.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"covered":covered},"  "));file.close()
 print("CAMPAIGN CONTRACTS COMPLETE checks=%d failures=%d"%[checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
