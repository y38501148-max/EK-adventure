shader_type canvas_item;

uniform float edge_softness : hint_range(0.0, 0.05) = 0.012;

void fragment() {
	vec2 centered_uv = UV - vec2(0.5);
	float distance_from_center = length(centered_uv);
	float alpha = 1.0 - smoothstep(0.5 - edge_softness, 0.5, distance_from_center);
	COLOR = texture(TEXTURE, UV);
	COLOR.a *= alpha;
}
