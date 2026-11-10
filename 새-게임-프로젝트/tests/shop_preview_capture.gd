extends SceneTree
var view
var failures := 0
var checks := 0
var output := ""

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)

func settle() -> void:
	for i in range(6): await process_frame

func capture(name: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name + ".png"))

func tap(name: String) -> void:
	var button: Button = view.field(name)
	check(not button.disabled and button.is_visible_in_tree(), "button available " + name)
	var at := button.get_global_rect().get_center()
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = at
	event.pressed = true
	root.push_input(event, true)
	await process_frame
	event = InputEventScreenTouch.new()
	event.index = 0
	event.position = at
	event.pressed = false
	root.push_input(event, true)
	await settle()

func bounds(node: Node) -> void:
	if node is Control and node.is_visible_in_tree():
		var r: Rect2 = node.get_global_rect()
		check(view.get_global_rect().grow(1).encloses(r), "inside viewport " + str(node.get_path()))
	for child in node.get_children(): bounds(child)

func run() -> void:
	output = OS.get_environment("QA_OUTPUT_DIR")
	if output.is_empty(): output = "D:/ProjectLoB/worktrees/core-redesign/qa_runtime/shop_preview"
	DirAccess.make_dir_recursive_absolute(output)
	view = load("res://redesign/samples/shop_wireframe_preview.tscn").instantiate()
	root.add_child(view)
	for resolution in [Vector2i(1600,900), Vector2i(1280,800), Vector2i(1280,576)]:
		root.size = resolution
		view.reset()
		await settle()
		bounds(view)
		await capture("shop_ammo_%dx%d" % [resolution.x,resolution.y])
		await tap("Details")
		check(view.field("RulesText").is_visible_in_tree(), "details opens full rules")
		check(not view.field("AmmoRow0").is_visible_in_tree(), "details hides bag choices")
		bounds(view)
		await capture("shop_details_%dx%d" % [resolution.x,resolution.y])
		await tap("CloseOverlay")
		check(not view.field("Overlay").visible and view.campaign.s.credits == 75, "details closes without spending")
		await tap("Offer1")
		check(view.selected == 1, "touch selects magazine")
		check(view.field("Change").text == "탄창   4 → 5칸", "purchase preview includes not-yet-owned part")
		await capture("shop_part_%dx%d" % [resolution.x,resolution.y])
		await tap("Buy")
		check(view.campaign.s.credits == 45 and view.campaign.s.equipped_parts.has("supply"), "purchase connected to production model")
		check(view.field("Buy").disabled, "sold item cannot buy twice")
	view.reset(); root.size = Vector2i(1600,900); await settle()
	await tap("Replace")
	await capture("shop_replace")
	await tap("AmmoRow0")
	check(view.campaign.model.s.deck.size() == 20 and view.campaign.model.s.deck.count("basic_p1") == 7, "replacement removes chosen profile only")
	check(view.campaign.model.s.deck.count("precise_p1") == 3 and view.campaign.s.credits == 63, "replacement adds one exact offer and deducts price")
	await capture("shop_purchased")
	view.reset(); view.campaign.s.credits = 5; view.refresh(); await settle()
	check(view.field("Buy").disabled, "unaffordable disabled")
	await capture("shop_insufficient")
	view.reset(); await tap("Slot0")
	check(not view.field("Buy").visible, "equipped inspector has no purchase")
	await tap("Offer0"); await tap("Charge")
	check(view.campaign.s.compressor_charges == 2 and view.campaign.s.credits == 57, "charge purchase")
	await tap("Reroll")
	check(view.campaign.s.credits == 54, "reroll uses actual visit price")
	await capture("shop_rerolled")
	bounds(view)
	view.reset()
	for i in range(12): view.campaign.model.s.deck.append("basic_p1")
	view.refresh(); await settle()
	check(view.field("Buy").disabled and not view.field("Replace").disabled, "full reserve requires exchange")
	await capture("shop_full_deck")
	view.reset()
	view.campaign.s.parts.append_array(["supply", "ordinary_chain", "loader"])
	view.campaign.s.equipped_parts = view.campaign.s.parts.duplicate()
	view.campaign._sync_equipped_parts()
	view.select_offer(2); await settle()
	check(view.field("Buy").text.contains("구매 후 보관"), "full loadout preview stores item")
	var pen_before: int = view.Data.penetration("pierce_p2", view.campaign.model.s)
	await tap("Buy")
	check(view.campaign.s.parts.has("lens") and not view.campaign.s.equipped_parts.has("lens"), "full loadout stores purchased part")
	check(view.Data.penetration("pierce_p2", view.campaign.model.s) == pen_before, "stored part gives no active bonus")
	print("SHOP PREVIEW COMPLETE checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
