extends "res://redesign/samples/combat_magazine_journey.gd"
const Hud=preload("res://redesign/samples/hud/combat_hud_presenter.gd")
const Flow=preload("res://redesign/samples/hud/journey_flow_presenter.gd")
var hud
var flow
var flow_input_locked: bool=false
func _ready()->void:
 hud=Hud.new(self);hud.bind()
 flow=Flow.new(self);flow.bind()
 super._ready()
func refresh()->void:
 super.refresh()
 if hud!=null:hud.render()
func lock_actions()->void:
 super.lock_actions()
 if hud!=null:hud.lock()
func close_detail()->void:
 super.close_detail()
 if hud!=null:hud.sync_focus()
func show_detail(title: String,body: String)->void:
 super.show_detail(title,hud.help_body(title,body))
func select_ejection(index: int)->void: hud.choose_round(index)
func toggle_ejection()->void: hud.remove_selected()
func _input(event: InputEvent)->void:
 if hud!=null:hud.pointer_input(event)
func _unhandled_key_input(event: InputEvent)->void:
 if event.is_action_pressed("ui_cancel") and hud.back():get_viewport().set_input_as_handled()
func refresh_panel()->void:
 super.refresh_panel()
 if flow!=null:flow.render()
 if flow_input_locked:
  node("JourneyConfirm").disabled=true
  node("JourneyCancel").disabled=true
 else:node("JourneyCancel").disabled=false
 if flow!=null:flow.sync_focus_order()
 if hud!=null:hud.sync_focus()
func show_route()->void:open_panel("route")
func confirm_panel()->void:
 if flow_input_locked or busy or not node("JourneyPanel").visible or node("JourneyConfirm").disabled:return
 flow_input_locked=true
 super.confirm_panel()
 await release_flow_input()
func cancel_panel()->void:
 if flow_input_locked:return
 flow_input_locked=true
 super.cancel_panel()
 await release_flow_input()
func release_flow_input()->void:
 await get_tree().create_timer(0.3).timeout
 flow_input_locked=false
 refresh_panel()
