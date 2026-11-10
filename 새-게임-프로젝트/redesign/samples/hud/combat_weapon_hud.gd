extends "res://redesign/samples/combat_weapon_magazine.gd"
const Hud=preload("res://redesign/samples/hud/combat_hud_presenter.gd")
const Trial=preload("res://redesign/fire_heat_trial.gd")
var hud
var drag
func _ready()->void:
 drag=preload("res://redesign/samples/fire_heat/drag.gd").new(self)
 hud=Hud.new(self);hud.bind()
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
func select_ejection(index: int)->void:
 if drag!=null and drag.suppress_tap():return
 hud.choose_round(index)
func toggle_ejection()->void: hud.remove_selected()
func _input(event: InputEvent)->void:
 if drag!=null and model!=null and not model.s.is_empty() and drag.handle(event):get_viewport().set_input_as_handled();return
 if hud!=null:hud.pointer_input(event)
func _process(delta: float)->void:
 if drag!=null:drag.tick(delta)
func _notification(what: int)->void:
 if what==NOTIFICATION_APPLICATION_FOCUS_OUT and drag!=null:drag.cancel()
func maximum_budget()->int:
 var normal: int=Model.MagazineTrial.WEAPON_PULSES[model.s.gun]+Model.Roles.pulse_bonus(model.s)
 if model.s.gun=="heavy":normal+=1
 return maxi(1,mini(normal,model.s.magazine.size()))
func current_budget()->int:
 var selected:=Trial.budget(model.s)
 return mini(selected,maximum_budget()) if selected>0 else maximum_budget()
func select_budget(amount: int,save: bool=true)->void:
 if busy or not Trial.range_enabled(model.s) or model.s.phase!="ready":return
 eject_mode=false;eject_selected.clear();hud.focused_round=-1
 model.s.fire_heat_trial.rounds=clampi(amount,1,maximum_budget())
 refresh()
 if save:persist()
func _unhandled_key_input(event: InputEvent)->void:
 if event.is_action_pressed("ui_cancel") and hud.back():get_viewport().set_input_as_handled()
