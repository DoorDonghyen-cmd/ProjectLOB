extends Control
## Authored title layout; runtime only binds save state, actions and preferences.
const Campaign = preload("res://redesign/campaign.gd")
const Content = preload("res://redesign/content.gd")
const Regions = preload("res://redesign/campaign_content.gd")
var host: Control

func _ready() -> void:
	resized.connect(_fit_art)
	_fit_art()

func _fit_art() -> void:
	var native: Vector2 = %Backdrop.texture.get_size()
	var factor := maxf(size.x / native.x, size.y / native.y)
	%ArtFrame.size = (native * factor).ceil()
	%ArtFrame.position = ((size - %ArtFrame.size) * 0.5).floor()

func bind_screen(owner_screen: Control, saved_run, has_save: bool, training_saved: bool) -> void:
	host = owner_screen
	var can_resume: bool = has_save and (not saved_run.s.settled or saved_run.restoration_pending())
	%resume.visible = can_resume
	%SaveCaption.visible = can_resume
	%resume_training.visible = training_saved
	%first_guide.visible = not bool(host.preferences.data.get("guide_seen", false))
	if can_resume:
		%resume.text = "정상 제어실로  ›" if saved_run.restoration_pending() else "등반 계속  ›"
		%SaveCaption.text = "%s · %s" % [Regions.info(int(saved_run.s.region)).name, Content.GUNS[saved_run.s.gun].name]
	var actions := {
		"resume": host._resume, "new_run_setup": host._open_preparation.bind(false),
		"settings": host._settings, "training_setup": host._open_preparation.bind(true),
		"resume_training": host._resume_training, "city_archive": host._city_archive,
		"guide": host._guide, "first_guide": host._guide, "rules": host._rules, "dev": host._developer,
	}
	for key in actions:
		var button := find_child(key, true, false) as Button
		button.add_theme_font_size_override("font_size", host._scaled(20 if key in ["resume", "new_run_setup", "settings"] else 17))
		button.pressed.connect(func(): host.feedback.play("click"))
		button.pressed.connect(actions[key])
		if key in ["resume", "new_run_setup", "settings"]:
			button.add_theme_color_override("font_color", Color("d4ddd5"))
			for state in ["normal", "hover", "pressed", "disabled", "focus"]:
				button.add_theme_stylebox_override(state, host._console_style("button", state))
	host._primary_button(%resume if can_resume else %new_run_setup)
	var warnings: Array[String] = []
	if FileAccess.file_exists(Campaign.SAVE) and not has_save:
		warnings.append("등반 저장을 읽을 수 없습니다. 원본은 보존됩니다.")
	if FileAccess.file_exists(host.SAVE) and not training_saved:
		warnings.append("훈련 저장을 읽을 수 없습니다. 원본은 보존됩니다.")
	%SaveWarning.text = "\n".join(warnings)
	%SaveWarning.visible = not warnings.is_empty()
	for label in [%Tagline, %SaveCaption, %SaveWarning]:
		label.add_theme_font_size_override("font_size", host._scaled(17))
	(%Backdrop.material as ShaderMaterial).set_shader_parameter("animate_light", host.preferences.data.get("motion", "normal") != "instant")
	%Reclaimer.set_motion_enabled(host.preferences.data.get("motion", "normal") != "instant")
	host._focus_control.call_deferred(%resume if can_resume else %new_run_setup)
