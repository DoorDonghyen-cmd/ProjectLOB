shader_type canvas_item;
uniform bool animate_light = true;
void fragment() {
	vec4 plate = texture(TEXTURE, UV);
	float amber = step(plate.b * 1.55, plate.r) * step(0.38, plate.r);
	float breath = animate_light ? sin(TIME * 1.3) * 0.018 : 0.0;
	COLOR = vec4(plate.rgb * (1.0 + amber * breath), plate.a);
}
