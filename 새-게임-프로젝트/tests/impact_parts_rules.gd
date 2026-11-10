extends "res://tests/focus_build_rules.gd"
const Style=preload("res://redesign/impact_style.gd")
const Readout=preload("res://redesign/damage_readout.gd")
const FX=preload("res://redesign/firing_vfx.gd")
const Tier=preload("res://redesign/enhanced_shot_fx.gd").Tier

func inspect_packet(packet: Dictionary, expected: String, label: String) -> Dictionary:
	var before:=JSON.stringify(packet)
	var entry:=Readout.entry(packet)
	check(entry.style.family==expected,label+" colour cause")
	check(JSON.stringify(packet)==before,label+" never mutates receipt")
	check(entry.amount==int(packet.damage),label+" exact HP damage")
	return entry

func run() -> void:
	output=OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\","/").contains("/qa_runtime/impact_parts_20261106/"):quit(2);return
	var normal:=shot(fixture(["basic_p2"],[]))
	var base:=inspect_packet(normal,"plain","ordinary")
	var first:=shot(fixture(["basic_p2"],["opening"]))
	var opening:=inspect_packet(first,"multiply","first shot part")
	check(opening.color!=base.color and opening.style.operator=="multiply","position multiplier differs at same numeric tier")
	check(preload("res://redesign/combat_payoff.gd").signature(first).color==opening.color,"part activation banner uses the same resolved hue")
	var loaded=fixture(["basic_p2","basic_p2","basic_p2"],["third_striker"])
	inspect_packet(shot(loaded),"plain","third part inactive first shot")
	inspect_packet(shot(loaded),"plain","third part inactive second shot")
	var third:=shot(loaded)
	var payoff:=inspect_packet(third,"multiply","actual third shot")
	check(third.part_factor==3 and payoff.style.rank==2,"real third shot is distinct multiplier")
	var stacked=fixture(["basic_p2","charge","pierce_p2"],["third_striker","afterburner","siege_drive"])
	shot(stacked);shot(stacked);var stack:=shot(stacked)
	check(inspect_packet(stack,"multiply","stacked product").style.rank==3,"multiple applied channels get layered tier")
	var sum=fixture(["charge","basic_p2"],[]);shot(sum)
	var added := shot(sum)
	inspect_packet(added,"add","actual support addition")
	inspect_packet(shot(fixture(["precise_p2"],["duplex"])),"volley","extra actual hits")
	var warm=fixture(["basic_p2"],["thermal_drive"]);warm.s.heat=ceili(Content.heat_limit(warm.s)/2.0)
	inspect_packet(shot(warm),"thermal","actual thermal multiplier")
	var dead:=first.duplicate(true);dead.hp=0
	check(Readout.entry(dead).color==opening.color,"kill retains multiplier hue")
	var large:=normal.duplicate(true);large.damage=400
	check(Readout.entry(large).style.operator=="plain" and Readout.entry(large).color==base.color,"large base damage never invents multiplication")
	var blocked:=first.duplicate(true);blocked.damage=0;blocked.blocked_hits=1
	check(not Readout.entry(blocked).style.active,"blocked multiplier never produces hit burst")
	var intercepted:=first.duplicate(true);intercepted.intercept=true;intercepted.target=10000
	check(not Readout.entry(intercepted).style.active and Readout.entry(intercepted).number=="요격","interception stays its own event")
	var granting=fixture(["charge_hot"],[]);var grant:=shot(granting)
	check(not Readout.entry(grant).style.active,"support preparation never imitates multiplied impact")
	var arc:=Readout.entry({"target":1,"damage":19,"hp":0,"part_factor":9},"arc")
	check(arc.style.family=="volley" and arc.style.operator=="secondary","secondary kill does not retrigger primary multiplier")
	var fire:=first.duplicate(true);fire.burn_added=2;fire.burn_tick=4;fire.burn=2
	check(Readout.entry(fire).color==opening.color and Readout.entry(fire).label_color!=opening.color,"burn status does not erase multiplier number hue")
	var old:=Readout.entry({"damage":6,"hp":2,"target":0})
	check(old.style.family=="plain","old receipt remains readable")
	check(FX.profile("single", added).tier == Tier.TRACER, "A for real added damage")
	check(FX.profile("single", first).tier == Tier.EMBERS, "B for a single ×2")
	check(FX.profile("single", third).tier == Tier.SHOCKWAVE, "C for a single ×3")
	check(FX.profile("single", stack).tier == Tier.SHOCKWAVE, "C for stacked multipliers")
	var deadbolt = fixture(["basic_p2"], [], "deadbolt")
	Model.WeaponRoles.on_load(deadbolt.s, Content.is_attack)
	var sealed := shot(deadbolt)
	check(int(sealed.weapon_factor) == 3 and FX.profile("deadbolt", sealed).tier == Tier.SHOCKWAVE, "C for a real ×3 sealed cartridge")
	var grown = fixture(["basic_p2"], ["siege_drive"])
	grown.s.engine.levels.siege_drive = 7
	var grown_shot := shot(grown)
	check(int(grown_shot.engine_percent) >= 300 and FX.profile("single", grown_shot).tier == Tier.SHOCKWAVE, "C for a core multiplier above ×3")
	var partial := first.duplicate(true)
	partial.blocked_hits = 1
	check(FX.profile("single", partial).tier == Tier.EMBERS, "partial shield still shows the multiplier that dealt damage")
	var blast_only := blocked.duplicate(true)
	blast_only.merge({"id":"detonate", "damage":6, "detonation":6}, true)
	var projectile_hit := intercepted.duplicate(true)
	projectile_hit.intercept = false
	for unenhanced in [normal, large, blocked, blast_only, intercepted, projectile_hit, grant, {"id":"basic_p2","damage":6}]:
		check(FX.profile("single", unenhanced).tier == Tier.STANDARD, "no enhanced visuals without enhanced HP damage")
	FileAccess.open(output.path_join("packets.json"),FileAccess.WRITE).store_string(JSON.stringify({"plain":normal,"opening":first,"third":third,"stacked":stack},"  "))
	print("IMPACT PARTS RULES COMPLETE checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
