shader_type canvas_item;

uniform vec4 letter_color : source_color = vec4(1.0, 0.85, 0.35, 1.0);
uniform bool preserve_original_colors = false;
uniform vec4 inner_ring_color : source_color = vec4(1.0, 1.0, 0.96, 1.0);
uniform float inner_ring_width : hint_range(0.0, 4.0, 1.0) = 2.0;
uniform bool inner_ring_enabled = true;
uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float outline_width : hint_range(0.0, 8.0, 1.0) = 5.0;
uniform bool outline_enabled = true;
uniform vec4 glow_color : source_color = vec4(1.0, 0.94, 0.72, 0.9);
uniform float glow_width : hint_range(0.0, 14.0, 1.0) = 10.0;
uniform bool glow_enabled = true;
uniform float fill_brightness : hint_range(0.8, 1.5, 0.02) = 1.25;
uniform float fill_saturation : hint_range(0.8, 1.5, 0.02) = 1.18;
uniform float shade_floor : hint_range(0.5, 1.2, 0.02) = 0.92;
uniform float min_output_luminance : hint_range(0.0, 0.8, 0.02) = 0.50;

float max_alpha_at(vec2 uv, vec2 px) {
	float m = 0.0;
	m = max(m, texture(TEXTURE, uv + vec2(px.x, 0.0)).a);
	m = max(m, texture(TEXTURE, uv + vec2(-px.x, 0.0)).a);
	m = max(m, texture(TEXTURE, uv + vec2(0.0, px.y)).a);
	m = max(m, texture(TEXTURE, uv + vec2(0.0, -px.y)).a);
	m = max(m, texture(TEXTURE, uv + vec2(px.x, px.y)).a);
	m = max(m, texture(TEXTURE, uv + vec2(-px.x, px.y)).a);
	m = max(m, texture(TEXTURE, uv + vec2(px.x, -px.y)).a);
	m = max(m, texture(TEXTURE, uv + vec2(-px.x, -px.y)).a);
	return m;
}

float nearest_letter_distance(vec2 uv, vec2 px) {
	if (max_alpha_at(uv, px * 1.0) > 0.10) {
		return 1.0;
	}
	if (max_alpha_at(uv, px * 2.0) > 0.10) {
		return 2.0;
	}
	if (max_alpha_at(uv, px * 3.0) > 0.10) {
		return 3.0;
	}
	if (max_alpha_at(uv, px * 4.0) > 0.10) {
		return 4.0;
	}
	if (max_alpha_at(uv, px * 5.0) > 0.10) {
		return 5.0;
	}
	if (max_alpha_at(uv, px * 6.0) > 0.10) {
		return 6.0;
	}
	if (max_alpha_at(uv, px * 7.0) > 0.10) {
		return 7.0;
	}
	if (max_alpha_at(uv, px * 8.0) > 0.10) {
		return 8.0;
	}
	if (max_alpha_at(uv, px * 9.0) > 0.10) {
		return 9.0;
	}
	if (max_alpha_at(uv, px * 10.0) > 0.10) {
		return 10.0;
	}
	if (max_alpha_at(uv, px * 11.0) > 0.10) {
		return 11.0;
	}
	if (max_alpha_at(uv, px * 12.0) > 0.10) {
		return 12.0;
	}
	if (max_alpha_at(uv, px * 13.0) > 0.10) {
		return 13.0;
	}
	if (max_alpha_at(uv, px * 14.0) > 0.10) {
		return 14.0;
	}
	return 999.0;
}

vec3 saturate_rgb(vec3 rgb, float amount) {
	float lum = dot(rgb, vec3(0.299, 0.587, 0.114));
	return mix(vec3(lum), rgb, amount);
}

vec3 enforce_min_luminance(vec3 rgb, float min_lum) {
	if (min_lum <= 0.0) {
		return rgb;
	}
	float lum = dot(rgb, vec3(0.299, 0.587, 0.114));
	if (lum >= min_lum || lum < 0.0001) {
		return rgb;
	}
	return min(rgb * (min_lum / lum), vec3(1.0));
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float alpha = tex.a;

	if (alpha < 0.001) {
		float dist = nearest_letter_distance(UV, TEXTURE_PIXEL_SIZE);
		if (inner_ring_enabled && inner_ring_width > 0.0 && dist <= inner_ring_width) {
			COLOR = inner_ring_color;
			return;
		}
		if (outline_enabled && outline_width > 0.0 && dist <= outline_width) {
			COLOR = outline_color;
			return;
		}
		if (glow_enabled && glow_width > 0.0 && dist <= glow_width) {
			float fade_start = max(outline_width, inner_ring_width) + 0.5;
			float strength = 1.0;
			if (dist > fade_start) {
				strength = 1.0 - clamp((dist - fade_start) / max(glow_width - fade_start, 1.0), 0.0, 1.0);
			}
			COLOR = glow_color;
			COLOR.a *= mix(0.65, 1.0, strength);
			return;
		}
		discard;
	} else {
		if (preserve_original_colors) {
			vec3 rgb = min(tex.rgb * fill_brightness, vec3(1.0));
			rgb = saturate_rgb(rgb, fill_saturation);
			rgb = enforce_min_luminance(rgb, min_output_luminance);
			COLOR = vec4(rgb, alpha);
		} else {
			float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
			float peak = max(max(tex.r, tex.g), tex.b);
			float shade = mix(lum, peak, 0.55);
			shade = pow(shade, 0.78);
			vec3 tinted = letter_color.rgb * mix(shade_floor, 1.35, shade) * fill_brightness;
			tinted = min(tinted, vec3(1.0));
			tinted = saturate_rgb(tinted, fill_saturation);
			tinted = enforce_min_luminance(tinted, min_output_luminance);
			COLOR = vec4(tinted, alpha);
		}
	}
}
