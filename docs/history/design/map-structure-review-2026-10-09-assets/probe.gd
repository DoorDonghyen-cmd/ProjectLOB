extends SceneTree
const Data = preload("res://redesign/campaign_content.gd")
const Campaign = preload("res://redesign/campaign.gd")
func _initialize():
    var report := []
    for region in range(5):
        var signatures := {}
        var types := {}
        var seed_count := 100
        for seed_value in range(seed_count):
            var campaign = Campaign.new()
            campaign.start("single", seed_value)
            campaign.s.region = region
            var topology := []
            var kinds := []
            for node in campaign.current_nodes():
                campaign.s.floor = node.floor
                campaign.s.node = node.id
                campaign.s.phase = "map"
                topology.append([node.id, campaign.choices().map(func(n): return n.id)])
                kinds.append([node.id, node.kind])
            signatures[JSON.stringify(topology)] = true
            types[JSON.stringify(kinds)] = true
        var campaign = Campaign.new()
        campaign.start("single", 1)
        campaign.s.region = region
        var paths := []
        walk(campaign, [], 0, paths)
        var counts := paths.map(func(p): return p.decisions)
        var combats := paths.map(func(p): return p.combats)
        report.append({"region":region,"name":Data.info(region).name,"floors":Data.info(region).floors,"map_nodes":campaign.current_nodes().size(),"seeds":seed_count,"distinct_topologies":signatures.size(),"distinct_room_type_layouts":types.size(),"paths":paths.size(),"choice_points_min":counts.min(),"choice_points_max":counts.max(),"combat_including_boss_min":combats.min(),"combat_including_boss_max":combats.max()})
    var file := FileAccess.open(OS.get_environment("QA_OUTPUT_DIR").path_join("map_report.json"), FileAccess.WRITE)
    file.store_string(JSON.stringify(report,"\t"))
    file.close()
    print(JSON.stringify(report))
    quit()
func walk(campaign, path: Array, decisions: int, result: Array):
    var choices: Array = campaign.choices()
    if choices.is_empty():
        result.append({"decisions":decisions,"combats":path.filter(func(n): return n.kind in ["combat","boss"]).size()})
        return
    var floor_before = campaign.s.floor
    var node_before = campaign.s.node
    for node in choices:
        campaign.s.floor = node.floor
        campaign.s.node = node.id
        var next := path.duplicate()
        next.append(node)
        walk(campaign,next,decisions + (1 if choices.size()>1 else 0),result)
    campaign.s.floor = floor_before
    campaign.s.node = node_before
