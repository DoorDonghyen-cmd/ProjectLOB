extends Node
## Observe resolved presentation events only. Never predict, spend ammo or roll RNG.
const Content=preload("res://redesign/content.gd")
const Preferences=preload("res://redesign/preferences.gd")
const Sound=preload("res://redesign/presentation_feedback.gd")
const MOTIONS=["normal","fast","instant"]
const MOTION_NAMES=["기본","빠르게","즉시"]
var ui: Control
var preferences=Preferences.new()
var sound=Sound.new()
var action_kind: String=""
var action_active: bool=false
var observed_phase: String=""
var shown_stack: Array=[]
var shots_shown:=0
var remaining_before:=0
var swap_empty:=false
var swap_ready:=false
var magazine_tween: Tween
var heat_tween: Tween

func bind(surface: Control)->void:
 ui=surface
 add_child(sound)
 preferences.load_preferences()
 configure()
 ui.board.shot_started.connect(shot)
 ui.board.shot_impacted.connect(impact)
 ui.board.feedback_changed.connect(heat_event)
 ui.node("EffectsVolume").pressed.connect(change_volume)
 ui.node("CombatMotion").pressed.connect(change_motion)
 tree_exiting.connect(sound.stop_audio)

func configure()->void:
 sound.configure(preferences.data)
 ui.board.speed_scale=preferences.motion_scale()
 ui.board.reduced_feedback=preferences.data.motion=="instant"
 ui.node("EffectsVolume").text="효과음 · "+("끄기" if preferences.data.effects_volume<=0 else "%d%%"%roundi(preferences.data.effects_volume*100))
 ui.node("CombatMotion").text="전투 연출 · "+MOTION_NAMES[MOTIONS.find(str(preferences.data.motion))]
 for id in ["EffectsVolume","CombatMotion"]:
  var button: Button=ui.node(id)
  button.accessibility_name=button.text
  button.get_node(id+"Frame").sync()

func save_setting(key: String,value: Variant)->void:
 if ui.busy:return
 var error: Error=preferences.set_value(key,value)
 ui.node("FeedbackStatus").visible=error!=OK
 configure()

func change_volume()->void:
 save_setting("effects_volume",float((roundi(preferences.data.effects_volume*4)+1)%5)/4.0)
 sound.play("click")

func change_motion()->void:
 save_setting("motion",MOTIONS[(MOTIONS.find(str(preferences.data.motion))+1)%MOTIONS.size()])

func begin_action()->void:
 action_active=true
 action_kind=str(ui.model.s.history.back().action) if not ui.model.s.history.is_empty() else ""
 # Whole-magazine replacement records reload, then its automatic load.
 # The public command is still a replacement throughout both records.
 if action_kind=="load" and ui.model.s.history.size()>1 and str(ui.model.s.history[-2].action)=="reload":action_kind="reload"
 sound.begin_action()
 stop_magazine_motion()
 shown_stack=ui.hud.observed_stack.duplicate()
 shots_shown=0;swap_empty=false;swap_ready=false
 remaining_before=ui.hud.observed_remaining
 # The model is already resolved here; the board still holds the pre-action state.
 show_heat(int(ui.board.heat_debt))

func shot(result: Dictionary)->void:
 if not action_active:return
 sound.shot(result)
 # One result is one spent cartridge, even when it hits multiple targets/times.
 if action_kind=="fire" and shots_shown<shown_stack.size():
  show_round(shots_shown,"")
  shots_shown+=1
  ui.node("MagazineTitle").text="탄창 %d / %d"%[shown_stack.size()-shots_shown,ui.model.capacity()]
  ui.node("Bag").text="남은 %d발"%maxi(0,remaining_before-shots_shown)
 show_heat(int(result.get("heat_before",ui.board.heat_debt)))

func impact(result: Dictionary)->void:
 if not action_active:return
 sound.impact(result)
 show_heat(int(result.get("heat_after",ui.board.heat_debt)))

func heat_event(event: Dictionary)->void:
 if not action_active:return
 var kind: String=str(event.get("kind",""))
 # Cooling shares the board's timed enemy-action pipeline with reloading.
 # Keep its sound tied to the real command, including forced cooling after fire.
 if kind in ["reload_turn","cooling_turn"] and action_kind in ["cool","fire"]:
  if int(event.get("turn",0))==0:sound.play("cool",true)
 elif kind!="reload_complete" or str(event.get("phase",""))=="ready":
  sound.heat_event(event)
 if event.has("heat"):show_heat(int(event.heat))
 if action_kind=="reload":
  if kind=="reload_turn" and not swap_empty:empty_magazine()
  elif kind=="turn_complete" and int(event.get("turn",-1))==ui.board.reload_base-1 and ui.model.s.phase=="ready":seat_magazine()
  elif kind=="reload_complete" and not swap_ready and str(event.get("phase",""))=="ready":seat_magazine()
 if kind in ["heat_added","overheat_lock","cooling_turn","reload_complete"]:heat_pulse()

func show_round(index: int,id: String)->void:
 var occupied:=not id.is_empty()
 var face: Control=ui.node("Face%d"%index)
 face.modulate=Color.WHITE;face.offset_top=8;face.offset_bottom=0
 var carrier: NinePatchRect=ui.node("RoundArt%d"%index)
 carrier.texture=ui.hud.StandbyCarrier if occupied else ui.hud.EmptyCarrier
 carrier.modulate=Color.WHITE if occupied else Color(0.4,0.4,0.4,1)
 for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:carrier.set_patch_margin(side,12 if occupied else 8)
 for prefix in ["Name","Value","Cost","Icon"]:ui.node(prefix+str(index)).visible=occupied
 ui.node("Index%d"%index).hide()
 if not occupied:return
 ui.node("Name%d"%index).text=Content.AMMO[id].name
 ui.node("Value%d"%index).text=str(Content.primary_stat(id,ui.model.s).value).replace("−","-")
 ui.node("Cost%d"%index).text="열 "+Content.heat_label(id,ui.model.s).replace("−","-")
 ui.node("Icon%d"%index).item_id=id

func stop_magazine_motion()->void:
 if magazine_tween!=null and magazine_tween.is_valid():magazine_tween.kill()
 magazine_tween=null

func empty_magazine()->void:
 swap_empty=true
 ui.node("MagazineTitle").text="탄창 분리"
 if ui.board.reduced_feedback:
  clear_sockets();return
 magazine_tween=create_tween().set_parallel(true)
 for i in range(ui.slot_count):
  var face: Control=ui.node("Face%d"%i)
  magazine_tween.tween_property(face,"modulate:a",0.0,0.12*ui.board.speed_scale)
  magazine_tween.tween_property(face,"position:y",16.0,0.12*ui.board.speed_scale)
 magazine_tween.chain().tween_callback(clear_sockets)

func clear_sockets()->void:
 for i in range(ui.slot_count):show_round(i,"")
 ui.node("MagazineTitle").text="새 탄창 장전 중"

func seat_magazine()->void:
 stop_magazine_motion();swap_ready=true
 var stack: Array=ui.model.s.magazine
 for i in range(ui.slot_count):show_round(i,str(stack[i]) if i<stack.size() else "")
 ui.node("MagazineTitle").text="장전 완료 · %d / %d"%[stack.size(),ui.model.capacity()]
 if ui.board.reduced_feedback:return
 # A single grouped seating motion, independent of deck size. No extra wait.
 magazine_tween=create_tween().set_parallel(true)
 for i in range(stack.size()):
  var face: Control=ui.node("Face%d"%i)
  face.modulate=Color("f3cf73");face.position.y=16
  magazine_tween.tween_property(face,"position:y",8.0,0.16*ui.board.speed_scale)
  magazine_tween.tween_property(face,"modulate",Color.WHITE,0.16*ui.board.speed_scale)

func heat_pulse()->void:
 if heat_tween!=null and heat_tween.is_valid():heat_tween.kill()
 var group: Control=ui.node("HeatGroup")
 group.modulate=Color.WHITE
 if ui.board.reduced_feedback:return
 var cooling: bool=action_kind=="cool" or ui.board.cooling_cost>0
 group.modulate=Color("80e6e4") if cooling else Color("ff9b6a")
 heat_tween=create_tween()
 heat_tween.tween_property(group,"modulate",Color.WHITE,0.22*ui.board.speed_scale)

func show_heat(heat: int)->void:
 var limit: int=Content.heat_limit(ui.model.s)
 ui.node("HeatLabel").text="%d / %d"%[heat,limit]
 ui.node("HeatBar").max_value=limit
 ui.node("HeatBar").value=heat
 ui.node("HeatPreview").max_value=limit
 ui.node("HeatPreview").value=heat
 ui.node("HeatCells").display(heat,limit,heat,heat>=limit)
 ui.node("HeatWarning").visible=heat>=limit
 ui.node("HeatGroup").tooltip_text="발열 %d / %d"%[heat,limit]

func sync_phase()->void:
 if ui.busy:return
 stop_magazine_motion()
 for i in range(ui.slot_count):ui.node("Face%d"%i).modulate=Color.WHITE
 if heat_tween!=null and heat_tween.is_valid():heat_tween.kill()
 ui.node("HeatGroup").modulate=Color.WHITE
 action_active=false
 var phase: String=str(ui.model.s.phase)
 # Refreshing, reopening a menu, or restoring a won encounter is silent.
 if observed_phase in ["plan","ready"] and phase in ["reward","won"]:sound.play("reward")
 observed_phase=phase
