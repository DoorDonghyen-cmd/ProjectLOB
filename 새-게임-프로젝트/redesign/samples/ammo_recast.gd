extends Control
## Standalone art study. Does not load or save the player's campaign or preferences.
const Model = preload("res://redesign/model.gd")
const Content = preload("res://redesign/content.gd")
const Forecast = preload("res://redesign/forecast.gd")
const Face = preload("res://redesign/samples/ammo_recast_face.gd")
var model = Model.new()
const IDS := ["basic_p1","basic_p2","basic_p3","pierce_p1","pierce_p2","precise_p1","precise_p2","charge","cool","arc"]

func _ready() -> void:
	%Battle.compact_ui=true
	%Battle.character_reference_height=240.0
	%Battle.set_route_background(0,0,12)
	for i in range(IDS.size()):
		var button: Button=%Hand.get_child(i)
		button.name="concept_load_"+IDS[i]
		button.pressed.connect(_load.bind(IDS[i]))
		_style(button,false,true)
	for i in range(4):
		%Queue.get_child(i).pressed.connect(_remove.bind(i))
		_style(%Queue.get_child(i),false,true)
	%Fire.pressed.connect(_fire)
	%Reload.pressed.connect(_reload)
	%Reset.pressed.connect(reset)
	%Close.pressed.connect(func(): get_tree().quit())
	for button in [%Fire,%Reload,%Reset,%Close]: _style(button,button==%Fire)
	reset()
	%Hand.get_child(0).grab_focus()

func _style(button: Button, primary: bool, quiet: bool = false) -> void:
	for key in ["normal","hover","pressed","disabled","focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color=Color("a75b3f") if primary else Color("27373b")
		if key=="hover": style.bg_color=style.bg_color.lightened(0.08)
		if key=="disabled": style.bg_color=Color("253034")
		style.border_color=Color("ddb486") if primary else Color("7b8d85")
		style.border_width_top=2
		style.border_width_bottom=4
		style.border_color=style.border_color.darkened(0.3) if key=="pressed" else style.border_color
		style.content_margin_left=12
		style.content_margin_right=12
		if quiet:
			button.add_theme_stylebox_override(key,StyleBoxEmpty.new())
		else: button.add_theme_stylebox_override(key,style)
	button.add_theme_color_override("font_color",Color("f0ddba"))
	button.add_theme_color_override("font_hover_color",Color("fff0ce"))

func reset() -> void:
	model.start("single",817263)
	model.s.bag_upgrades=5
	model.s.deck=IDS.duplicate()
	model.begin_encounter()
	model.s.hand=IDS.duplicate()
	model.s.draw=model.s.deck.duplicate()
	for id in IDS: model.s.draw.erase(id)
	model.load_round("basic_p2")
	model.load_round("charge")
	refresh()

func _load(id: String) -> void:
	model.load_round(id)
	refresh()

func _remove(index: int) -> void:
	model.remove_planned(index)
	refresh()

func _fire() -> void:
	if model.s.phase=="plan": model.confirm()
	else: model.fire()
	refresh()

func _reload() -> void:
	model.reload_magazine()
	refresh()

func refresh() -> void:
	var prediction: Dictionary=Forecast.analyze(model.s)
	%Battle.sync(model.s)
	var rounds: Array=model.s.plan if model.s.phase=="plan" else model.s.magazine
	%Order.text="발사 순서  %d/%d   ·   마지막에 넣은 탄부터"%[rounds.size(),model.capacity()]
	for i in range(4):
		var button: Button=%Queue.get_child(i)
		var face: Control=button.get_node("Face")
		face.ammo_id=str(rounds[i]) if i<rounds.size() else ""
		face.state=model.s
		face.queue_redraw()
		button.disabled=model.s.phase!="plan" or i>=rounds.size()
	for i in range(IDS.size()):
		var button: Button=%Hand.get_child(i)
		var face: Control=button.get_node("Face")
		face.state=model.s
		face.remaining=model.available(IDS[i])
		face.selected=rounds.has(IDS[i])
		button.disabled=not model.can_load(IDS[i])
		button.tooltip_text=str(Content.AMMO[IDS[i]].text)
		var block: String=model.load_block_reason(IDS[i])
		if not block.is_empty(): button.tooltip_text+="\n"+block
		face.modulate=Color("aeb7b2") if button.disabled and not face.selected else Color.WHITE
		face.queue_redraw()
	%Fire.text="장전 확정" if model.s.phase=="plan" else "발사"
	%Fire.disabled=rounds.is_empty() or model.s.phase not in ["plan","ready"]
	%Reload.disabled=model.s.phase not in ["plan","ready"]
	%Reload.text="재장전  ·  냉각 %d\n적 %d턴 진행"%[Content.reload_cooling(model.s),model.reload_cost()]
	var heat: int=model.s.get("heat",0)
	var peak: int=maxi(heat,int(prediction.get("heat",{}).get("peak_max",heat)))
	%Heat.max_value=Content.heat_limit(model.s)
	%Heat.value=peak
	%HeatText.text="발열  %d → %d / %d"%[heat,peak,Content.heat_limit(model.s)]
	%CoolText.text="지금 재장전 시 %d"%int(Forecast.reload_now(model.s,true).get("temperature_after",heat))
