extends SceneTree
const Data = preload("res://redesign/campaign_content.gd")
const Background = preload("res://redesign/ascent_background.gd")

func _initialize() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/region_concept_review/"):
		quit(1);return
	var regions: Array=[]
	for region in range(5):
		var report: Dictionary={"region":region+1,"name":Data.info(region,3).name,"depth":Data.info(region,3).floors,"normal":{},"elite":{},"boss":{},"samples":0,"formation_roles":[],"total_counts":[],"background_ready":Background.profile(region,1,Data.info(region,3).floors).ready}
		for seed_value in range(731042,731052):
			for room in Data.nodes(region,seed_value,3):
				if room.kind not in ["combat","boss"]:continue
				var pack:=Data.encounter_pack(room,seed_value,"single",0,0,7)
				report.samples+=1
				var group: String="boss" if room.kind=="boss" else "elite" if room.get("elite",false) else "normal"
				var kinds: Array=[]
				for enemy in pack.active+pack.reserve:
					if not kinds.has(enemy.kind):kinds.append(enemy.kind)
					var key: String=str(enemy.get("species",enemy.kind))+"/"+str(enemy.name)
					if not report[group].has(key):report[group][key]={"name":enemy.name,"role":enemy.kind,"species":enemy.get("species",""),"rank":enemy.get("rank",""),"hp":enemy.hp,"armor":enemy.def,"barrier":enemy.get("barrier",0),"charge":enemy.get("charge_max",0),"pull":enemy.get("charge_pull",0),"ranged":enemy.get("ranged_phase",""),"seen":0}
					report[group][key].seen+=1
				if group=="normal":
					if not report.formation_roles.has(kinds.size()):report.formation_roles.append(kinds.size())
					if not report.total_counts.has(pack.total):report.total_counts.append(pack.total)
		regions.append(report)
	var file=FileAccess.open(OS.get_environment("QA_OUTPUT_DIR").path_join("audit.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"note":"Generated map/formation inventory only. No playthrough or difficulty validation. roster7/map3, difficulty0, 10 seeds per region.","regions":regions},"  "));file.close()
	for report in regions:print(report.region," ",report.name," samples=",report.samples," normal=",report.normal.keys()," kinds_per_fight=",report.formation_roles," total=",report.total_counts," background=",report.background_ready)
	print("REGION REVIEW COMPLETE")
	quit()
