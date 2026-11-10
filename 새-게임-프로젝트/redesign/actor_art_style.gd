extends RefCounted
## Screen-scale grouping for authored world actors, separate from tactical UI.
static func apply(material: ShaderMaterial, source_scale: float, enabled: bool = true) -> void:
	material.set_shader_parameter("source_pixel_step", maxf(1.0, roundf(1.5 / maxf(0.01, source_scale))) if enabled else 0.0)
	material.set_shader_parameter("shadow_lift", 0.65 if enabled else 0.0)
