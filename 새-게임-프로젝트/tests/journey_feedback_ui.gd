extends "res://tests/combat_hud_flow.gd"
## Real touch commands, resolved events and the audio mixer; isolated player saves.
var cues: Array=[]
var heat_events: Array=[]
var turn_events: Array=[]
var mix_capture: AudioEffectCapture
var mixed_frames:=PackedVector2Array()
var mixed_peak:=0.0
var bus: int
var heat_capture_pending:=false

func collect_audio()->void:
 var chunk:=mix_capture.get_buffer(mix_capture.get_frames_available())
 for sample in chunk:mixed_peak=maxf(mixed_peak,maxf(absf(sample.x),absf(sample.y)))
 if mixed_frames.size()<int(AudioServer.get_mix_rate())*45:mixed_frames.append_array(chunk)

func attach()->void:
 for player in preview.hud.feedback.sound.players:player.bus="QAJourneyFeedback"
 preview.hud.feedback.sound.cue_played.connect(func(cue):cues.append(cue))
 preview.board.feedback_changed.connect(observe_heat)

func observe_heat(event: Dictionary)->void:
 if event.kind in ["enemy_turn","reload_turn","cooling_turn","turn_complete"]:turn_events.append(event.duplicate(true))
 if not event.has("heat"):return
 check(preview.node("HeatCells").current==int(event.heat),"Gauge follows resolved event: "+str(event.kind))
 check(preview.node("HeatCells").peak==int(event.heat),"Playback never displays final-state forecast early")
 heat_events.append(event.duplicate(true))
 if event.kind=="heat_added" and not heat_capture_pending:
  heat_capture_pending=true
  capture_live_heat.call_deferred()

func capture_live_heat()->void:
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(out.path_join("heat_during_fire.png"))==OK,"Capture heat during actual animation")

func clear_events()->void:
 cues.clear();heat_events.clear();turn_events.clear()

func settings_layout()->void:
 for id in ["EffectsVolume","CombatMotion"]:
  preview.node("MenuScroll").ensure_control_visible(preview.node(id));await settle()
  fits(id)
  check(preview.node("MenuScroll").get_global_rect().encloses(preview.node(id).get_global_rect()),"Settings scroll into usable touch area")

func run()->void:
 out=OS.get_environment("QA_OUTPUT_DIR")
 if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/combat_hud_20261031/journey_feedback_20261101/"):quit(2);return
 Input.emulate_mouse_from_touch=true
 AudioServer.add_bus();bus=AudioServer.bus_count-1
 AudioServer.set_bus_name(bus,"QAJourneyFeedback")
 mix_capture=AudioEffectCapture.new();mix_capture.buffer_length=2.0
 AudioServer.add_bus_effect(bus,mix_capture);AudioServer.set_bus_mute(0,true)
 process_frame.connect(collect_audio)
 var prefs=load("res://redesign/preferences.gd").new();prefs.reset()
 root.size=Vector2i(1280,800)
 preview=JourneyScene.instantiate();preview.resume_saved=false;root.add_child(preview);await settle();attach()
 check(preview.hud.feedback.sound.players.size()==6,"Fixed six-voice sound pool")
 check(preview.hud.feedback.sound.streams.values().all(func(stream):return stream!=null),"All existing audio resources load")
 for size in [Vector2i(740,360),Vector2i(844,390),Vector2i(1280,800)]:
  root.size=size;await settle()
  var before: Dictionary=canonical(preview.journey.data())
  await tap("Menu");await settings_layout();await capture("menu_%dx%d"%[size.x,size.y])
  await tap("EffectsVolume");await tap("CombatMotion")
  check(canonical(preview.journey.data())==before,"Settings do not change combat, ownership, RNG or journey save")
  await tap("MenuClose")
 # Three motion clicks return to normal. Restore volume for the mixer exercise.
 preview.hud.feedback.save_setting("effects_volume",0.5)
 check(preview.board.speed_scale==1.0 and not preview.board.reduced_feedback,"Normal mode restored through menu")
 clear_events();preview.refresh();preview.refresh();await settle()
 check(cues.is_empty(),"Idle redraws are silent")
 root.size=Vector2i(1280,800);await settle()
 var oracle=preview.Model.new();oracle.s=preview.model.s.duplicate(true);check(oracle.fire(),"Same-state oracle fires")
 await tap("Fire")
 check(canonical(preview.model.s)==canonical(oracle.s),"Feedback preserves full actual combat state and RNG")
 check(cues.has("fire") and cues.has("hit"),"Actual opening shot and impact are audible")
 check(heat_events.any(func(e):return e.kind=="heat_added"),"Actual heat advances during individual shots")
 check(preview.node("HeatCells").current==preview.model.s.heat,"Final gauge returns to actual idle state")
 check(preview.node("HeatCells").peak==int(preview.last_prediction.heat.peak_max),"Idle forecast returns after playback")
 clear_events();await tap("Cool")
 check(cues.count("cool")==1 and not cues.has("reload"),"Retained-magazine cooling is not a magazine-swap sound")
 check(turn_events.filter(func(e):return e.kind=="cooling_turn").size()==1 and not turn_events.any(func(e):return e.kind=="reload_turn"),"Manual cooling keeps the magazine in the visual playback")
 clear_events();await tap("Reload")
 check(cues.count("reload")==1 and cues.count("ready")==1,"Real swap emits one start and one completion")
 var rounds: int=preview.model.s.magazine.size()
 clear_events();await tap("Select1");await tap("EjectToggle")
 check(preview.model.s.magazine.size()==rounds-1 and not cues.has("fire") and not cues.has("hit"),"Ejection never fakes a shot or hit")
 # Retry through the existing public menu, then earn the real first reward.
 await tap("Menu");await tap("Reset");await tap("JourneyConfirm")
 while preview.flow_input_locked:await process_frame
 clear_events()
 for i in range(3):await tap("Fire")
 check(preview.journey.phase()=="reward" and cues.count("reward")==1,"Victory announces the earned reward once")
 var count: int=cues.size()
 preview.refresh();await tap("RewardPick2");preview.refresh();await settle()
 check(cues.size()==count,"Inspecting or redrawing a reward never replays its cue")
 await tap("JourneyConfirm")
 while preview.flow_input_locked:await process_frame
 await tap("RewardPick0");await tap("JourneyConfirm")
 while preview.flow_input_locked:await process_frame
 await tap("JourneyConfirm")
 while preview.flow_input_locked:await process_frame
 clear_events();await tap("Fire")
 check(cues.has("fire_power"),"An actually earned siege core changes the firing sound")
 # Saved settings survive a fresh scene and keep the exact journey checkpoint.
 await tap("Menu");preview.hud.feedback.save_setting("effects_volume",1.0)
 preview.hud.feedback.sound.play("hit",true)
 await tap("EffectsVolume")
 check(preview.hud.feedback.preferences.data.effects_volume==0 and preview.hud.feedback.sound.players.all(func(p):return not p.playing),"Mute stops every live voice")
 await tap("CombatMotion");await tap("CombatMotion")
 check(preview.board.reduced_feedback and preview.board.speed_scale==0.05,"Instant mode reduces motion without altering the model")
 await tap("MenuClose")
 var saved: Dictionary=canonical(preview.journey.data())
 var old_voice=weakref(preview.hud.feedback.sound.players[0])
 preview.queue_free();await settle()
 check(old_voice.get_ref()==null,"Leaving the scene releases audio voices")
 preview=JourneyScene.instantiate();root.add_child(preview);await settle();attach()
 check(preview.resumed and canonical(preview.journey.data())==saved,"Resume preserves exact journey state")
 check(preview.hud.feedback.preferences.data.effects_volume==0 and preview.board.reduced_feedback,"Mute and motion survive reopening")
 clear_events();await tap("Fire")
 check(cues.is_empty(),"Muted actual combat stays silent")
 preview.queue_free();await settle()
 # The independent comparison uses the same bridge. Natural consecutive boss
 # shots trigger overheat; no heat or ammo values are injected for this check.
 prefs.reset()
 preview=Scene.instantiate();preview.resume_saved=false;root.add_child(preview);await settle();attach()
 preview.case_index=1;preview.mount(false);await settle();clear_events()
 var forced:=false
 for i in range(3):
  clear_events()
  await tap("Fire")
  if not preview.model.s.history.back().detail.get("forced_cooling",{}).is_empty():forced=true;break
 var detail: Dictionary=preview.model.s.history.back().detail
 var cooling: Dictionary=detail.get("forced_cooling",{})
 check(forced and cues.has("overheat") and cues.has("cool"),"Natural overheat is followed by cooling, without a fake swap")
 check(turn_events.filter(func(e):return e.kind=="enemy_turn").size()==1,"Only one enemy action belongs to the firing stage")
 check(turn_events.filter(func(e):return e.kind in ["reload_turn","cooling_turn"]).size()==int(cooling.get("elapsed",-1)),"Every actual forced-cooling approach is animated")
 check(not turn_events.any(func(e):return e.kind=="reload_turn"),"Forced cooling never presents a magazine replacement")
 check(preview.board.cooling_cost==0,"Cooling presentation state resets after the action")
 var completed: Array=turn_events.filter(func(e):return e.kind=="turn_complete")
 check(not completed.is_empty() and canonical(completed.back().shown_enemies)==canonical(preview.model.s.enemies),"Last cooling movement reaches the resolved enemies without teleporting")
 check(not cues.has("reload"),"Forced cooling preserves magazine identity in sound")
 check(not preview.busy and not preview.node("Menu").disabled,"Controls recover after forced cooling")
 # Instant suppresses combat cues even with sound enabled.
 preview.mount(false);preview.hud.feedback.save_setting("motion","instant");clear_events();await tap("Fire")
 check(cues.is_empty(),"Instant mode suppresses combat audio independently of volume")
 check(not FileAccess.file_exists(Journey.Campaign.SAVE),"Feedback never creates a campaign save")
 await create_timer(0.3).timeout;collect_audio()
 check(mixed_peak>0.001 and mixed_peak<1.0,"Actual mixer is non-silent and unclipped")
 var bytes:=PackedByteArray();bytes.resize(mixed_frames.size()*4)
 for i in range(mixed_frames.size()):
  bytes.encode_s16(i*4,roundi(clampf(mixed_frames[i].x,-1,1)*32767))
  bytes.encode_s16(i*4+2,roundi(clampf(mixed_frames[i].y,-1,1)*32767))
 var recording:=AudioStreamWAV.new();recording.format=AudioStreamWAV.FORMAT_16_BITS
 recording.mix_rate=int(AudioServer.get_mix_rate());recording.stereo=true;recording.data=bytes
 check(recording.save_to_wav(out.path_join("actual_feedback_mix.wav"))==OK,"Save real mixed audio evidence")
 FileAccess.open(out.path_join("feedback.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"mixed_peak":mixed_peak,"mixed_frames":mixed_frames.size()},"  "))
 print("JOURNEY FEEDBACK COMPLETE checks=%d failures=%d peak=%f"%[checks,failures.size(),mixed_peak])
 preview.queue_free();await settle();quit(0 if failures.is_empty() else 1)
