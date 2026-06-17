shader_type canvas_item;

uniform vec4 sky_top : source_color = vec4(0.03, 0.05, 0.11, 1.0);
uniform vec4 sky_mid : source_color = vec4(0.06, 0.04, 0.09, 1.0);
uniform vec4 sky_bottom : source_color = vec4(0.10, 0.05, 0.04, 1.0);
uniform vec4 nebula_cool : source_color = vec4(0.08, 0.22, 0.28, 1.0);
uniform vec4 nebula_warm : source_color = vec4(0.42, 0.14, 0.05, 1.0);
uniform float time_scale : hint_range(0.0, 2.0, 0.01) = 0.28;
uniform float star_brightness : hint_range(0.2, 2.0, 0.05) = 1.05;

float hash21(vec2 p) {
	p = fract(p * vec2(234.34, 435.345));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

float star_layer(vec2 uv, float scale, float threshold, float t) {
	vec2 gv = uv * scale;
	vec2 id = floor(gv);
	vec2 f = fract(gv);
	float n = hash21(id);
	float star = step(threshold, n);
	vec2 offset = vec2(hash21(id + 13.7), hash21(id + 42.1)) - 0.5;
	float d = length(f - 0.5 - offset * 0.35);
	float twinkle = 0.65 + 0.35 * sin(t * (2.0 + n * 8.0) + n * 40.0);
	float core = smoothstep(0.12, 0.0, d);
	float glow = smoothstep(0.35, 0.0, d) * 0.35;
	return star * (core + glow) * twinkle;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 world = FRAGCOORD.xy * 0.0022;
	float t = TIME * time_scale;
	float h = clamp(uv.y, 0.0, 1.0);

	vec3 col = mix(sky_top.rgb, sky_mid.rgb, smoothstep(0.0, 0.55, h));
	col = mix(col, sky_bottom.rgb, smoothstep(0.45, 1.0, h));

	float mist = fbm(world * 1.6 + vec2(t * 0.04, t * 0.02));
	float aurora = fbm(world * 2.8 - vec2(t * 0.03, t * 0.05) + vec2(0.0, 1.4));
	col += nebula_cool.rgb * pow(mist, 2.2) * 0.18 * (1.0 - h * 0.6);
	col += nebula_warm.rgb * pow(aurora, 2.5) * 0.14 * smoothstep(0.2, 0.9, h);

	float stars = 0.0;
	stars += star_layer(world, 95.0, 0.992, t);
	stars += star_layer(world + vec2(17.3, 9.1), 140.0, 0.996, t + 1.7);
	stars += star_layer(world + vec2(5.9, 31.2), 210.0, 0.9985, t + 3.1);
	col += vec3(0.92, 0.95, 1.0) * stars * star_brightness;

	float dust = fbm(world * 18.0 + vec2(t * 0.12, -t * 0.08));
	col += vec3(0.18, 0.12, 0.22) * pow(dust, 4.0) * 0.08;

	COLOR = vec4(col, 1.0);
}
