extends Node
## Observe public UI and accepted commands. Never execute, retry or delay a command.
signal transaction_shown(event: Dictionary)
const Response=preload("res://redesign/ui/interaction_response.gd")
const COMMANDS:=["buy","reroll","buy_compressor","reward","gate","gate_production","gate_copy","gate_bag","shop_refine","shop_compress","tune","equip","replace_part","resolve"]
var host
var last_motion:=""
var transactions:Array=[]
var delivering:Dictionary={}

func _ready() -> void:
	host=get_parent()
	get_tree().node_added.connect(_added)
	for node in host.find_children("*","Button",true,false):_bind(node)

func _added(node: Node) -> void:
	if node is Button and host.is_ancestor_of(node):_bind.call_deferred(node)

func _bind(button: Variant) -> void:
	if not is_instance_valid(button) or not button.is_inside_tree() or button.is_queued_for_deletion():return
	var script:Script=button.get_script()
	if script!=null and (script.resource_path.contains("/pipe_map/") or script.resource_path.ends_with("/map_facility.gd")):return
	response(button)

func response(control: Control):
	var existing=control.get_node_or_null("InteractionResponse")
	if existing!=null:
		existing.feedback=self;existing.surface=control
		return existing
	var view=Response.new();view.name="InteractionResponse";view.surface=control;view.feedback=self
	control.add_child(view)
	return view

func motion() -> String:
	var value:String=str(host.preferences.data.motion)
	var adapter=host.campaign_hud
	if is_instance_valid(adapter) and adapter.hud!=null and adapter.hud.feedback!=null:value=str(adapter.hud.feedback.preferences.data.motion)
	if value!=last_motion:
		last_motion=value
		for node in host.find_children("InteractionResponse","Node2D",true,false):node.halt()
	return value

func watches(command: String, value: Variant) -> bool:
	return COMMANDS.has(command) and not (command in ["resolve","reward","gate"] and str(value)=="skip")

func snapshot(campaign) -> Dictionary:
	return {"credits":int(campaign.s.credits),"equipped":campaign.equipped_parts().duplicate(),"parts":campaign.s.parts.duplicate(),"deck":campaign.model.s.deck.duplicate()}

func context() -> String:
	return "%s/%d/%s/%s/%s"%[host.page,host.campaign.get_instance_id(),host.campaign.s.node,host.campaign.s.phase,host.campaign.s.get("shop_revision",0)] if host.campaign!=null else ""

func accepted(command: String, value: Variant, extra: String, before: Dictionary) -> void:
	if not watches(command,value):return
	var event:Dictionary={"command":command,"value":value,"extra":extra,"before":before,"after":snapshot(host.campaign),"context":context(),"targets":[]}
	_deliver.call_deferred(event)

func _deliver(event: Dictionary) -> void:
	if not is_inside_tree() or event.context!=context():return
	delivering=event
	for node in host.find_children("*","Control",true,false):
		if node.is_visible_in_tree() and node.has_method("_feedback_transaction"):node._feedback_transaction(event,self)
	if event.targets.is_empty():
		# The existing shared gate/map status, not a new popup or invented text.
		var status=host.find_child("RunStatusBar",true,false)
		if status!=null:pulse(status,"complete")
	transactions.append(event)
	if transactions.size()>32:transactions.pop_front()
	transaction_shown.emit(event)
	delivering={}

func pulse(control: Control, role: String="complete") -> void:
	if control==null or not control.is_inside_tree() or not control.is_visible_in_tree():return
	response(control).pulse(role)
	if not delivering.is_empty():delivering.targets.append(str(control.get_path()))

static func added_ids(before: Array, after: Array) -> Array:
	var remaining:=before.duplicate();var added:Array=[]
	for id in after:
		if remaining.has(id):remaining.erase(id)
		elif not added.has(id):added.append(id)
	return added
