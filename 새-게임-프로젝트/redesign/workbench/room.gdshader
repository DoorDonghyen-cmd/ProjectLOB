shader_type canvas_item;
// Concept-only material. Original art files and live room materials are untouched.
void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float value = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	vec3 warm = value * vec3(1.10, 0.99, 0.83);
	COLOR = vec4(mix(source.rgb, warm, 0.78), source.a) * COLOR;
}
