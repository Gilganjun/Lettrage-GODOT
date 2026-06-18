shader_type canvas_item;

uniform vec2 blur_step = vec2(0.003, 0.003);

void fragment() {
	vec2 uv = UV;
	vec2 px = blur_step;

	vec4 col = texture(TEXTURE, uv) * 0.2270270270;
	col += texture(TEXTURE, uv + vec2(px.x, 0.0)) * 0.1945945946;
	col += texture(TEXTURE, uv - vec2(px.x, 0.0)) * 0.1945945946;
	col += texture(TEXTURE, uv + vec2(0.0, px.y)) * 0.1945945946;
	col += texture(TEXTURE, uv - vec2(0.0, px.y)) * 0.1945945946;
	col += texture(TEXTURE, uv + px) * 0.1216216216;
	col += texture(TEXTURE, uv - px) * 0.1216216216;
	col += texture(TEXTURE, uv + vec2(px.x, -px.y)) * 0.1216216216;
	col += texture(TEXTURE, uv + vec2(-px.x, px.y)) * 0.1216216216;

	COLOR = col * COLOR;
}
