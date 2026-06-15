shader_type canvas_item;

uniform vec4 letter_color : source_color = vec4(1.0, 0.85, 0.35, 1.0);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float alpha = tex.a;
	if (alpha < 0.001) {
		discard;
	}
	// Letter art is warm yellow-gold; use luminance as a shading mask so any hue reads cleanly.
	float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	float peak = max(max(tex.r, tex.g), tex.b);
	float shade = mix(lum, peak, 0.5);
	shade = pow(shade, 0.85);
	vec3 tinted = letter_color.rgb * mix(0.4, 1.2, shade);
	COLOR = vec4(tinted, alpha);
}
