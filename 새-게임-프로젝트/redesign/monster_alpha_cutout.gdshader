shader_type canvas_item;
// Generated art retains a diffuse alpha fringe. Reject it at presentation time;
// keep sprite modulation independent so death fades remain continuous.
varying vec4 actor_tint;
void vertex() { actor_tint = COLOR; }
void fragment() {
    vec4 sprite = texture(TEXTURE, UV);
    if (sprite.a < 0.5) { discard; }
    COLOR = vec4(sprite.rgb, 1.0) * actor_tint;
}
