extends RefCounted
## Opt-in five-fight route. All ownership/rewards/growth use the real campaign.
const Campaign = preload("res://redesign/campaign.gd")
const Model = preload("res://redesign/model.gd")
const Ammo = preload("res://redesign/content.gd")
const Approach = preload("res://redesign/combat_approach_trial.gd")
const VERSION := 1
const SEED := 731042
const ROUTE := [101,201,302,401,501,602,702,802]
const FIGHTS := [101,201,401,602,802]
const SAVE := "user://magazine_journey_v1.json"
var campaign = Campaign.new()
var entry: Dictionary = {}
var results: Array = []
var acquisitions: Array = []

func start(gun: String) -> bool:
 if not Ammo.GUNS.has(gun): return false
 campaign = Campaign.new(); campaign.start(gun,SEED,0,"balanced",3,"work")
 campaign.model.s.magazine_trial_version = 1
 campaign.model.s.weapon_magazine_version = 1
 entry={}; results=[]; acquisitions=[]
 return advance()

func data() -> Dictionary:
 return {"campaign":campaign.s.duplicate(true),"combat":campaign.model.s.duplicate(true),"profile":campaign.profile.duplicate(true)}

func phase() -> String:
 return "complete" if campaign.s.phase == "gate" else str(campaign.s.phase)

func fight_number() -> int:
 return mini(5,int(campaign.s.clears)+1) if phase()=="combat" else maxi(1,int(campaign.s.clears))

func advance() -> bool:
 if phase() != "map": return false
 for _step in range(ROUTE.size()):
  var index: int=campaign.s.visited.size()
  if index>=ROUTE.size(): return false
  # Encounter-scoped flags must never leak into the next room.
  campaign.model.s.erase("approach_trial_version"); campaign.model.s.erase("approach_trial_role")
  if not campaign.enter(ROUTE[index]): return false
  if phase()=="event":
   if not campaign.resolve("skip") or not campaign.leave(): return false
   continue
  if phase()=="combat":
   var role: String={201:"sweep",401:"breach",602:"payoff",802:"boss"}.get(int(campaign.s.node),"")
   if not role.is_empty() and not Approach.apply_opening(campaign.model.s,role): return false
   if not campaign.model.trial_load_magazine(): return false
   entry=data()
  else: campaign.normalize_for_save()
  return true
 return false

func sync() -> void:
 if phase()!="combat": return
 campaign.sync_combat()
 if phase() in ["reward","lost"]:
  var s: Dictionary=campaign.model.s
  var initial: Dictionary=entry.combat
  results.append({"node":campaign.s.node,"won":phase()=="reward","turns":int(s.turns)-int(initial.turns),"shots":int(s.shots)-int(initial.shots),"used":s.discard.size(),"ejected":_ejected(s,initial),"deck":s.deck.duplicate(),"growth":s.get("engine",{}).duplicate(true)})

func _ejected(s: Dictionary, initial: Dictionary) -> int:
 var count:=0
 for h in s.history.slice(initial.history.size()):
  if h.action=="eject": count+=h.detail.get("rounds",[]).size()
 return count

func options() -> Array:
 if phase()=="reward":
  var parts: Array=campaign.part_rewards()
  return parts if not parts.is_empty() else campaign.reward_options()
 if phase()=="supply" and not campaign.s.resolved: return campaign.workshop_ammo_options().slice(0,3)
 return []

func replacement(id: String) -> String:
 if not Ammo.AMMO.has(id): return ""
 if phase()!="supply" and campaign.can_acquire_ammo(id): return ""
 var basics: Array=campaign.replaceable_basics()
 return str(basics[0]) if not basics.is_empty() else ""

func choose(id: String) -> bool:
 if not options().has(id): return false
 var replacing:=replacement(id)
 var source:=phase()
 var ok: bool=campaign.reward(id,replacing) if source=="reward" else campaign.resolve("refit",id,replacing)
 if not ok: return false
 acquisitions.append({"node":campaign.s.node,"id":id,"replaced":replacing,"source":source})
 if source=="supply": campaign.leave()
 campaign.normalize_for_save()
 return true

func skip() -> bool:
 if phase()=="reward" and not campaign.engine_reward() and not campaign.first_ammo_reward():
  if not campaign.reward("skip"): return false
 elif phase()=="supply" and not campaign.s.resolved:
  if not campaign.resolve("skip") or not campaign.leave(): return false
 else: return false
 campaign.normalize_for_save()
 return true

func retry() -> bool:
 if phase() not in ["combat","lost"] or entry.is_empty(): return false
 var restored=Campaign.new()
 if not restored.restore_state(entry): return false
 if phase()=="lost" and not results.is_empty(): results.pop_back()
 campaign=restored
 return true

func save(path: String=SAVE) -> Error:
 var file:=FileAccess.open(path+".tmp",FileAccess.WRITE)
 if file==null: return FileAccess.get_open_error()
 file.store_string(JSON.stringify({"format":"lob_magazine_journey","version":VERSION,"current":data(),"entry":entry,"results":results,"acquisitions":acquisitions}))
 file.close()
 return DirAccess.rename_absolute(path+".tmp",path)

func restore(path: String=SAVE) -> bool:
 if not FileAccess.file_exists(path): return false
 var decoded: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
 return decoded is Dictionary and restore_state(decoded)

func _valid_campaign(c) -> bool:
 var s: Dictionary=c.s
 if s.seed!=str(SEED) or int(s.map_version)!=3 or int(s.region)!=0 or s.gun not in Ammo.GUNS: return false
 if s.phase not in ["combat","reward","map","supply","gate","lost"]: return false
 if s.visited.is_empty() or s.visited.size()>ROUTE.size(): return false
 for i in range(s.visited.size()):
  if int(s.visited[i])!=ROUTE[i]: return false
 if not Model.MagazineTrial.weapons_enabled(c.model.s): return false
 if int(c.model.s.get("encounter_id",0)) not in FIGHTS: return false
 if s.phase in ["combat","reward","lost","gate"] and int(s.node)!=int(c.model.s.encounter_id): return false
 var finished:=FIGHTS.find(int(c.model.s.encounter_id))
 if s.phase not in ["combat","lost"]: finished+=1
 if int(s.clears)!=finished: return false
 return true

func restore_state(value: Dictionary) -> bool:
 if value.get("format","")!="lob_magazine_journey" or not Campaign._whole(value.get("version"),1,1): return false
 if not value.get("current") is Dictionary or not value.get("entry") is Dictionary or not value.get("results") is Array or not value.get("acquisitions") is Array: return false
 var restored=Campaign.new(); var opening=Campaign.new()
 if not restored.restore_state(value.current) or not opening.restore_state(value.entry): return false
 if not _valid_campaign(restored) or not _valid_campaign(opening) or opening.s.phase!="combat": return false
 if restored.s.gun!=opening.s.gun or int(restored.model.s.encounter_id)!=int(opening.s.node): return false
 if value.results.size()!=int(restored.s.clears)+(1 if restored.s.phase=="lost" else 0): return false
 if restored.s.phase in ["combat","lost"]:
  if restored.s.visited!=opening.s.visited or restored.model.s.deck!=opening.model.s.deck or restored.s.equipped_parts!=opening.s.equipped_parts: return false
 for i in range(value.results.size()):
  var row: Variant=value.results[i]
  if not row is Dictionary or not row.get("won") is bool: return false
  if int(row.get("node",0))!=FIGHTS[i] or row.won!=(i<int(restored.s.clears)): return false
  for key in ["node","turns","shots","used","ejected"]:
   if not Campaign._whole(row.get(key),0,100000): return false
 for row in value.acquisitions:
  if not row is Dictionary or not row.get("id") is String or not row.get("replaced") is String or row.get("source","") not in ["reward","supply"]: return false
  if not Ammo.AMMO.has(row.id) and not Ammo.PARTS.has(row.id): return false
 campaign=restored; entry=value.entry.duplicate(true); results=value.results.duplicate(true); acquisitions=value.acquisitions.duplicate(true)
 return true
