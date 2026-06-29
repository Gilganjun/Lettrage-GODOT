shader_type canvas_item;

uniform float shimmer_time = 0.0;
uniform float shimmer_strength = 0.035;
uniform float highlight_strength = 0.22;
uniform float ripple_scale = 8.0;

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
		p = p * 2.03 + vec2(1.7, 2.3);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;
	float t = shimmer_time;

	vec2 flow = vec2(t * 0.37, -t * 0.29);
	vec2 warp;
	warp.x = sin(uv.y * 9.17 + t * 1.731) * 0.42;
	warp.x += sin(uv.x * 13.91 - t * 1.193 + uv.y * 2.7) * 0.28;
	warp.y = cos(uv.x * 10.53 + t * 0.967) * 0.34;
	warp.y += sin(uv.y * 15.37 + t * 1.409) * 0.22;
	warp += (vec2(
		fbm(uv * ripple_scale + flow),
		fbm(uv * ripple_scale * 1.3 - flow * 0.8 + vec2(2.4, 1.8))
	) - 0.5) * 1.2;

	vec2 warped_uv = clamp(uv + warp * shimmer_strength, vec2(0.002), vec2(0.998));
	vec4 base = texture(TEXTURE, warped_uv);

	// Blend offset FBM samples (not multiply) to keep caustics soft without square tiles.
	float caustic_a = fbm(uv * vec2(ripple_scale * 1.1, ripple_scale * 0.85) + flow);
	float caustic_b = fbm(uv * vec2(ripple_scale * 1.4, ripple_scale * 1.2) + flow + vec2(3.7, 2.1));
	float caustic = smoothstep(0.52, 0.88, mix(caustic_a, caustic_b, 0.5)) * highlight_strength;

	float glint = fbm(uv * vec2(20.0, 15.0) + vec2(t * 0.51, -t * 0.43) + vec2(5.0, 2.5));
	glint = smoothstep(0.78, 0.98, glint) * highlight_strength * 0.55;

	base.rgb += vec3(1.0, 0.82, 0.42) * (caustic + glint) * base.a;
	COLOR = base;
}
