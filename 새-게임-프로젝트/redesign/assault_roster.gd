extends RefCounted
## Authored populations, independent of player growth. Four visible lanes stay fixed.
static func rows(node: Dictionary, random: RandomNumberGenerator, legacy: Array) -> Array:
	var region := int(node.region)
	var depth := int(node.floor)
	if region==0:
		if depth==1: return legacy
		if node.kind=="boss":
			return [["wall",14,2,1,25],["runner",3,0,2,27],["runner",3,0,2,30],["evader",4,0,1,33],
				["runner",4,0,2,28],["spitter",7,0,0,33],["runner",4,0,2,30],["evader",5,0,1,33]]
		if depth==2:
			return [["runner",3,0,2,23],["runner",3,0,2,26],["wall",7,3,1,30],["runner",4,0,2,33]]
		if depth==3:
			return [["runner",3,0,2,23],["runner",3,0,2,26],["spitter",6,0,0,31],["evader",4,0,1,33],
				["runner",4,0,2,29],["evader",4,0,1,33]]
		var opening: Array = [
			[["runner",4,0,2,24],["evader",4,0,1,27],["wall",7,2,1,30],["runner",4,0,2,33]],
			[["evader",4,0,1,24],["runner",4,0,2,27],["wall",7,3,1,30],["runner",4,0,2,33]]
		][random.randi_range(0,1)].duplicate(true)
		opening.append_array([["runner",4,0,2,28],["runner",4,0,2,30],["spitter",6,0,0,33],["evader",5,0,1,34]])
		return opening
	# Higher regions retain their characteristic anchor and mechanics. Light escorts
	# provide a payoff around it; new reserves are never spawned nearer for strong builds.
	var result := legacy.duplicate(true)
	for i in range(1,result.size()):
		if str(result[i][0]) in ["runner","evader"]: result[i][1] = mini(int(result[i][1]),4+mini(region,2))
	while result.size()<8:
		result.append(["runner" if result.size()%2==0 else "evader",4+mini(region,2),0,2,32+mini(region,2)])
	return result
