shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(1.0, 0.88, 0.55, 0.45);
uniform float glow_width : hint_range(0.0, 16.0, 1.0) = 11.0;
uniform vec4 rim_color : source_color = vec4(1.0, 0.95, 0.78, 0.35);
uniform float rim_width : hint_range(0.0, 6.0, 1.0) = 2.5;
uniform float fill_brightness : hint_range(1.0, 1.2, 0.01) = 1.06;
uniform float fill_saturation : hint_range(1.0, 1.2, 0.01) = 1.05;

float max_alpha_at(sampler2D tex, vec2 uv, vec2 px) {
	float m = 0.0;
	m = max(m, texture(tex, uv + vec2(px.x, 0.0)).a);
	m = max(m, texture(tex, uv + vec2(-px.x, 0.0)).a);
	m = max(m, texture(tex, uv + vec2(0.0, px.y)).a);
	m = max(m, texture(tex, uv + vec2(0.0, -px.y)).a);
	m = max(m, texture(tex, uv + vec2(px.x, px.y)).a);
	m = max(m, texture(tex, uv + vec2(-px.x, px.y)).a);
	m = max(m, texture(tex, uv + vec2(px.x, -px.y)).a);
	m = max(m, texture(tex, uv + vec2(-px.x, -px.y)).a);
	return m;
}

float nearest_opaque_distance(sampler2D tex, vec2 uv, vec2 px) {
	if (max_alpha_at(tex, uv, px * 1.0) > 0.12) {
		return 1.0;
	}
	if (max_alpha_at(tex, uv, px * 2.0) > 0.12) {
		return 2.0;
	}
	if (max_alpha_at(tex, uv, px * 3.0) > 0.12) {
		return 3.0;
	}
	if (max_alpha_at(tex, uv, px * 4.0) > 0.12) {
		return 4.0;
	}
	if (max_alpha_at(tex, uv, px * 5.0) > 0.12) {
		return 5.0;
	}
	if (max_alpha_at(tex, uv, px * 6.0) > 0.12) {
		return 6.0;
	}
	if (max_alpha_at(tex, uv, px * 7.0) > 0.12) {
		return 7.0;
	}
	if (max_alpha_at(tex, uv, px * 8.0) > 0.12) {
		return 8.0;
	}
	if (max_alpha_at(tex, uv, px * 9.0) > 0.12) {
		return 9.0;
	}
	if (max_alpha_at(tex, uv, px * 10.0) > 0.12) {
		return 10.0;
	}
	if (max_alpha_at(tex, uv, px * 11.0) > 0.12) {
		return 11.0;
	}
	if (max_alpha_at(tex, uv, px * 12.0) > 0.12) {
		return 12.0;
	}
	return 999.0;
}

vec3 saturate_rgb(vec3 rgb, float amount) {
	float lum = dot(rgb, vec3(0.299, 0.587, 0.114));
	return mix(vec3(lum), rgb, amount);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float alpha = tex.a;

	if (alpha < 0.001) {
		if (glow_width <= 0.0) {
			discard;
		}
		float dist = nearest_opaque_distance(TEXTURE, UV, TEXTURE_PIXEL_SIZE);
		if (dist > glow_width) {
			discard;
		}
		float strength = 1.0 - smoothstep(0.0, glow_width, dist);
		strength = pow(strength, 1.35);
		COLOR = glow_color;
		COLOR.a *= strength;
	} else {
		vec3 rgb = min(tex.rgb * fill_brightness, vec3(1.0));
		rgb = saturate_rgb(rgb, fill_saturation);

		vec2 px = TEXTURE_PIXEL_SIZE * rim_width;
		float above = texture(TEXTURE, UV + vec2(0.0, -px.y)).a;
		float left = texture(TEXTURE, UV + vec2(-px.x, 0.0)).a;
		float right = texture(TEXTURE, UV + vec2(px.x, 0.0)).a;
		float edge_up = (1.0 - above) * alpha;
		float edge_side = (2.0 - left - right) * 0.5 * alpha;
		float rim = clamp(edge_up * 0.75 + edge_side * 0.25, 0.0, 1.0);
		rgb = mix(rgb, rim_color.rgb, rim * rim_color.a);

		COLOR = vec4(rgb, alpha);
	}
}
