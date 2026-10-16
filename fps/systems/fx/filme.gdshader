shader_type canvas_item;
// Pós-processamento leve "filme de guerra": vinheta, granulado animado e leve tom
// verde-acinzentado. Um único passe sobre a tela (barato na GPU integrada).

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float grain = 0.045;
uniform float vignette = 0.38;
uniform vec3 tint = vec3(0.98, 1.0, 0.94);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec3 color = texture(screen_texture, SCREEN_UV).rgb * tint;
	vec2 centered = SCREEN_UV - 0.5;
	float v = 1.0 - dot(centered, centered) * vignette * 2.2;
	color *= clamp(v, 0.0, 1.0);
	float n = hash(floor(FRAGCOORD.xy / 1.5) + fract(TIME * 7.13) * 91.7) - 0.5;
	// Granulado mais visível nos tons médios, como em película.
	float lum = dot(color, vec3(0.299, 0.587, 0.114));
	color += n * grain * (1.0 - abs(lum - 0.5) * 1.2);
	COLOR = vec4(color, 1.0);
}
