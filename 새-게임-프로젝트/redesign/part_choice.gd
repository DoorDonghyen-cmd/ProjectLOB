extends RefCounted
## Read-only choice information from the current run; no state writes.
const Ammo=preload("res://redesign/content.gd")
const Engines=preload("res://redesign/damage_engines.gd")
static func effect(id: String,state: Dictionary)->String:
 if not Engines.IDS.has(id):return str(Ammo.part_spec(id,state).get("upside",""))
 var value:=Engines.value(state,id)
 match id:
  "volley_drive":return value+" · 처치 뒤 남은 타격 전이"
  "siege_drive":return value+" · 처치 뒤 초과 피해 전이"
  "thermal_drive":
   var burn:=Ammo.Roles.burn_growth(state,[id])
   return value+" · 열 한계 충격파"+(" · 화상 +%d"%burn if burn>0 else "")
 return value
static func family_count(state: Dictionary,family: String)->int:
 return state.get("deck",[]).filter(func(id):return Ammo.source_id(str(id))==family).size()
static func fit(id: String,state: Dictionary)->String:
 match id:
  "inferno":
   var count:=family_count(state,"bore")
   return "소이탄 %d장 · 기폭탄 %d장"%[count,family_count(state,"detonate")] if count>0 else "현재 소이탄 없음 · 소이탄을 확보해야 불길을 남깁니다."
  "momentum":return "차단탄 %d장 · 충격탄 %d장"%[family_count(state,"disrupt"),family_count(state,"push")]
  "arc_splitter":return "전격탄 %d장 · 전격의 전이만 강화합니다."%family_count(state,"arc")
 return ""
static func deltas(before: Dictionary,after: Dictionary)->PackedStringArray:
 var lines: PackedStringArray=[]
 var a:=Ammo.equipped_parts(before);var b:=Ammo.equipped_parts(after)
 if family_count(before,"bore")>0:
  var burn_a:=Ammo.burn_damage(before);var burn_b:=Ammo.burn_damage(after)
  if burn_a!=burn_b:lines.append("화상 피해 / 행동  %d → %d"%[burn_a,burn_b])
  if Ammo.Roles.enabled(before):
   var ground_a:=burn_a+(2 if a.has("coil") else 0);var ground_b:=burn_b+(2 if b.has("coil") else 0)
   if ground_a!=ground_b:lines.append("불길 피해 / 행동  %d → %d"%[ground_a,ground_b])
   if Ammo.Roles.fire_duration(a)!=Ammo.Roles.fire_duration(b):lines.append("불길 지속  %d → %d행동"%[Ammo.Roles.fire_duration(a),Ammo.Roles.fire_duration(b)])
   if Ammo.Roles.fire_radius(before,a)!=Ammo.Roles.fire_radius(after,b):lines.append("불길 범위  앞뒤 %d → %dm"%[Ammo.Roles.fire_radius(before,a),Ammo.Roles.fire_radius(after,b)])
 var removed: Array=a.filter(func(id):return Engines.IDS.has(id) and not b.has(id))
 if not removed.is_empty():
  var id: String=removed[0]
  lines.append("성장 %d/%d 기록 보존 · 다시 장착하면 복구"%[Engines.level(before,id),Engines.Growth.limit(before)])
 return lines
