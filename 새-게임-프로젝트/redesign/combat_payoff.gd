extends RefCounted
## Read only resolved impacts. Never award a kill for a projectile or repeated entry.
static func describe(shot: Dictionary) -> Dictionary:
	var damage := 0
	var killed: Array = []
	var impacts: Array = [shot]+shot.get("secondary",[])
	for impact in impacts:
		damage += int(impact.get("damage",0))
		var target := int(impact.get("target",-1))
		if target>=0 and target<10000 and int(impact.get("damage",0))>0 and int(impact.get("hp",1))<=0 and not killed.has(target): killed.append(target)
	var tier := 2 if killed.size()>=2 else 1 if damage>=20 else 0
	return {"damage":damage,"kills":killed.size(),"targets":killed,"tier":tier}
