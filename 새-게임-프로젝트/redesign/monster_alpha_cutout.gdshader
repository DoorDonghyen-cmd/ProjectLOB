shader_type canvas_item;
// Opt-in world-actor grouping; UI and existing cutouts retain their defaults.
uniform float source_pixel_step = 0.0;
uniform float shadow_lift : hint_range(0.0, 1.0) = 0.0;
// Generated art retains a diffuse alpha fringe. Reject it at presentation time;
// keep sprite modulation independent so death fades remain continuous.
varying vec4 actor_tint;
void vertex() { actor_tint = COLOR; }
void fragment() {
    vec2 sample_uv = UV;
    if (source_pixel_step > 1.0) {
        vec2 cell = TEXTURE_PIXEL_SIZE * source_pixel_step;
        sample_uv = (floor(UV / cell) + vec2(0.5)) * cell;
    }
    vec4 sprite = texture(TEXTURE, sample_uv);
    if (sprite.a < 0.5) { discard; }
    float dark = 1.0 - smoothstep(0.06, 0.24, max(max(sprite.r, sprite.g), sprite.b));
    sprite.rgb = mix(sprite.rgb, max(sprite.rgb, vec3(0.105, 0.135, 0.14)), dark * shadow_lift);
    COLOR = vec4(sprite.rgb, 1.0) * actor_tint;
}
