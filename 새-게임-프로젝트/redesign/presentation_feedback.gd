extends Node
## Presentation only: no combat mutation or use of the simulation RNG.
signal cue_played(cue: String)
const CUES := ["click", "load", "confirm", "fire", "fire_power", "hit", "armor", "overheat", "reload", "cool", "ready", "reward"]
const VOICES := 6
var players: Array[AudioStreamPlayer] = []
var streams: Dictionary = {}
var last_played: Dictionary = {}
var volume := 0.5
var motion := "normal"
var skipped := false
var trace: Array[String] = []
var flow_key := ""
var transition: Tween
var transition_target: Control
var next_voice := 0

func _ready() -> void:
	for cue in CUES:
		streams[cue] = load("res://assets/audio/feedback/%s.wav" % cue)
	for index in range(VOICES):
		var player := AudioStreamPlayer.new()
		add_child(player)
		players.append(player)

func configure(data: Dictionary) -> void:
	volume = clampf(float(data.get("effects_volume", 0.5)), 0.0, 1.0)
	motion = str(data.get("motion", "normal"))
	for player in players:
		player.volume_db = linear_to_db(maxf(volume * 0.55, 0.00001))
	if volume <= 0: stop_audio()
	if motion == "instant": finish_transition()

func play(cue: String, combat: bool = false) -> void:
	if volume <= 0 or not streams.has(cue) or (combat and (skipped or motion == "instant")): return
	var now := Time.get_ticks_msec()
	if now - int(last_played.get(cue, -1000)) < 60: return
	last_played[cue] = now
	var voice: AudioStreamPlayer = players[next_voice]
	for available in players:
		if not available.playing:
			voice = available
			break
	next_voice = (players.find(voice) + 1) % VOICES
	voice.stop()
	voice.stream = streams[cue]
	voice.play()
	trace.append(cue)
	if trace.size() > 64: trace.pop_front()
	cue_played.emit(cue)

func stop_audio() -> void:
	for player in players: player.stop()

func begin_action() -> void:
	skipped = false

func skip_action() -> void:
	skipped = true
	stop_audio()

func shot(result: Dictionary) -> void:
	var powerful: bool = int(result.get("math", {}).get("boost", 0)) > 0 or int(result.get("detonation", 0)) > 0
	powerful = powerful or int(result.get("engine_percent",100))>100 or int(preload("res://redesign/combat_payoff.gd").describe(result).tier)>0
	play("fire_power" if powerful else "fire", true)

func impact(result: Dictionary) -> void:
	if int(result.get("armor_removed", 0)) > 0: play("armor", true)
	elif int(result.get("damage", 0)) > 0: play("hit", true)
	if int(preload("res://redesign/combat_payoff.gd").describe(result).tier)==2: play("fire_power",true)

func heat_event(event: Dictionary) -> void:
	match str(event.get("kind", "")):
		"overheat_lock": play("overheat", true)
		"reload_turn", "cooling_turn":
			if int(event.get("turn", 0)) == 0: play("reload", true)
		"heat_removed", "kill_cooling": play("cool", true)
		"reload_complete": play("ready", true)

func enter(key: String, target: Control, reward: bool = false) -> void:
	if key == flow_key: return
	var initial := flow_key.is_empty()
	flow_key = key
	finish_transition()
	if initial: return
	if reward: play("reward")
	if motion == "instant": return
	transition_target = target
	target.modulate.a = 0.72
	transition = create_tween()
	transition.tween_property(target, "modulate:a", 1.0, 0.09 if motion == "fast" else 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func finish_transition() -> void:
	if transition != null and transition.is_valid(): transition.kill()
	if is_instance_valid(transition_target): transition_target.modulate.a = 1.0
