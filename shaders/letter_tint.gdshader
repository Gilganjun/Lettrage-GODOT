shader_type canvas_item;

uniform vec4 letter_color : source_color = vec4(1.0, 0.85, 0.35, 1.0);
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float outline_width : hint_range(0.0, 6.0, 1.0) = 2.0;
uniform bool outline_enabled = true;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float alpha = tex.a;

	if (alpha < 0.001) {
		float neighbor_a = 0.0;
		if (outline_enabled && outline_width > 0.0) {
			vec2 px = TEXTURE_PIXEL_SIZE * outline_width;
			neighbor_a = max(neighbor_a, texture(TEXTURE, UV + vec2(px.x, 0.0)).a);
			neighbor_a = max(neighbor_a, texture(TEXTURE, UV + vec2(-px.x, 0.0)).a);
			neighbor_a = max(neighbor_a, texture(TEXTURE, UV + vec2(0.0, px.y)).a);
			neighbor_a = max(neighbor_a, texture(TEXTURE, UV + vec2(0.0, -px.y)).a);
		}
		if (neighbor_a > 0.12) {
			COLOR = outline_color;
		} else {
			discard;
		}
	} else {
		float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
		float peak = max(max(tex.r, tex.g), tex.b);
		float shade = mix(lum, peak, 0.5);
		shade = pow(shade, 0.85);
		vec3 tinted = letter_color.rgb * mix(0.4, 1.2, shade);
		COLOR = vec4(tinted, alpha);
	}
}
