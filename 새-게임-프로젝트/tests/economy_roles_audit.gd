extends SceneTree
const Campaign=preload("res://redesign/campaign.gd")
func _initialize()->void:run.call_deferred()
func paths(rooms: Array)->Dictionary:
	var values: Dictionary={}
	for room in rooms:
		var counts: Array=[1 if room.kind=="shop" else 0,1 if room.get("workshop",false) else 0,1 if room.kind=="supply" and not room.get("workshop",false) else 0,1 if room.kind=="combat" else 0]
		var lo: Array=[999,999,999,999];var hi: Array=[-1,-1,-1,-1]
		if room.floor==1:lo=counts.duplicate();hi=counts.duplicate()
		for previous in rooms:
			if not previous.next.has(room.id):continue
			for i in range(4):lo[i]=mini(lo[i],values[previous.id].lo[i]+counts[i]);hi[i]=maxi(hi[i],values[previous.id].hi[i]+counts[i])
		values[room.id]={"lo":lo,"hi":hi}
	return values[rooms.back().id]
func run()->void:
	var output:=OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\","/").contains("/qa_runtime/economy_roles_20261103/"):quit(2);return
	var graph: Array=[];var outfits: Array=[]
	for region in range(5):
		var row:={"region":region+1,"seeds":200,"some_path_without_shop":0,"some_path_without_workshop":0,"no_path_with_workshop":0,"minimum_fights":99}
		for seed_value in range(200):
			var b:=paths(Campaign.Content.nodes(region,seed_value,4))
			if b.lo[0]==0:row.some_path_without_shop+=1
			if b.lo[1]==0:row.some_path_without_workshop+=1
			if b.hi[1]==0:row.no_path_with_workshop+=1
			row.minimum_fights=mini(row.minimum_fights,b.lo[3])
		graph.append(row)
	for outfit in Campaign.Ammo.OUTFITS:
		for gun in Campaign.Ammo.GUNS:
			var c=Campaign.new();c.start(gun,17,0,"balanced",4,outfit,true)
			outfits.append({"outfit":outfit,"gun":gun,"start":c.model.s.deck.size(),"min":c.minimum_deck(),"max":c.model.deck_limit(),"magazine":c.model.capacity(),"exchange":Campaign.Ammo.exchange_capacity(c.model.s)})
	FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"graphs":graph,"outfits":outfits},"  "))
	for row in graph:print(row)
	print("ECONOMY ROLES COMPLETE failures=0");quit()
