shader_type canvas_item;
render_mode unshaded;

uniform vec2 glass_size = vec2(817.0, 512.0);
uniform float sweep_progress : hint_range(0.0, 1.0) = 1.0;
uniform float idle_progress : hint_range(0.0, 1.0) = 1.0;
uniform float scanline_strength : hint_range(0.0, 0.35) = 0.20;
uniform vec4 phosphor : source_color = vec4(0.67, 0.61, 0.43, 1.0);
uniform vec4 shadow : source_color = vec4(0.035, 0.045, 0.04, 1.0);

void fragment() {
	vec2 position = UV * 2.0 - 1.0;
	vec2 corner_distance = min(UV, 1.0 - UV) * glass_size;
	float glass_mask = step(9.0, corner_distance.x + corner_distance.y);

	vec2 rim_curve = position * position * position;
	float vignette = smoothstep(0.40, 1.68, dot(rim_curve, rim_curve));
	float scanline = step(2.0, mod(floor(UV.y * glass_size.y), 3.0));
	float darkening = vignette * 0.23 + scanline * scanline_strength;

	vec2 tube_center = (position + vec2(0.19, 0.15)) * vec2(0.66, 0.90);
	float phosphor_glow = (1.0 - smoothstep(0.06, 1.12, dot(tube_center, tube_center))) * 0.082;
	float reflection = (1.0 - smoothstep(0.025, 0.15, UV.y)) * (1.0 - smoothstep(0.19, 0.78, UV.x)) * 0.047;
	float sweep_y = mix(-0.08, 1.08, sweep_progress);
	float sweep = (1.0 - smoothstep(0.004, 0.045, abs(UV.y - sweep_y))) * 0.13;
	float idle_y = mix(-0.10, 1.10, idle_progress);
	float idle_band = (1.0 - smoothstep(0.008, 0.076, abs(UV.y - idle_y))) * 0.048;
	float light = phosphor_glow * (1.0 - vignette) + reflection + sweep + idle_band;

	float opacity = darkening + light;
	vec3 tint = (shadow.rgb * darkening + phosphor.rgb * light) / max(opacity, 0.001);
	COLOR = vec4(tint, opacity * glass_mask);
}
