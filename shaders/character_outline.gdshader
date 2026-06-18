shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(1.0, 0.82, 0.45, 0.85);
uniform float outline_width : hint_range(0.0, 8.0, 1.0) = 3.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float alpha = tex.a;
	if (alpha < 0.05) {
		float neighbor_a = 0.0;
		vec2 px = TEXTURE_PIXEL_SIZE * outline_width;
		neighbor_a = max(neighbor_a, texture(TEXTURE, UV + vec2(px.x, 0.0)).a);
		neighbor_a = max(neighbor_a, texture(TEXTURE, UV + vec2(-px.x, 0.0)).a);
		neighbor_a = max(neighbor_a, texture(TEXTURE, UV + vec2(0.0, px.y)).a);
		neighbor_a = max(neighbor_a, texture(TEXTURE, UV + vec2(0.0, -px.y)).a);
		neighbor_a = max(neighbor_a, texture(TEXTURE, UV + vec2(px.x, px.y)).a);
		neighbor_a = max(neighbor_a, texture(TEXTURE, UV + vec2(-px.x, px.y)).a);
		neighbor_a = max(neighbor_a, texture(TEXTURE, UV + vec2(px.x, -px.y)).a);
		neighbor_a = max(neighbor_a, texture(TEXTURE, UV + vec2(-px.x, -px.y)).a);
		if (neighbor_a > 0.2) {
			COLOR = outline_color;
		} else {
			discard;
		}
	} else {
		COLOR = tex;
	}
}
